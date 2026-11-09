"""Hypothesis properties for the ACTUAL PR134 sanitized replay engine.

This tests model invariants and adversarial transitions; it neither creates a
new replay implementation nor exercises actual Roblox/Delta trading code.
"""
from __future__ import annotations

from copy import deepcopy
import importlib.util
from pathlib import Path
import unittest

from hypothesis import HealthCheck, given, settings, strategies as st
from hypothesis.stateful import RuleBasedStateMachine, initialize, invariant, rule

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "gingerscope_sanitized_replay_under_test", ROOT / "scripts/replay_trade_events.py"
)
assert SPEC and SPEC.loader
R = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(R)
RUN = "01234567-89ab-cdef-0123-456789abcdef"


def trace(events):
    return {"schema": R.SOURCE_SCHEMA, "sourceKind": "SYNTHETIC_OFFLINE_TEST",
            "clientRunNonce": RUN, "events": events}


def safe(output):
    for field, expected in R.FALSE_AUTHORITY.items():
        assert output[field] == expected, (field, output[field])
    assert output["readOnly"] is True
    assert output["simulationOnly"] is True
    assert RUN not in repr(output)


class ClientEventReplayMachine(RuleBasedStateMachine):
    @initialize()
    def begin(self):
        self.events = [{"id": "ev_1", "session": "s_1",
                        "tMs": 10, "kind": "OPEN"}]
        self.counter = 1
        self.current_session = "s_1"
        self.prior_session = None
        self.session_index = 1
        self.revision = 0

    def add(self, kind, *, session=None, **extra):
        self.counter += 1
        self.events.append({"id": f"ev_{self.counter}",
                            "session": session or self.current_session,
                            "tMs": self.counter * 10, "kind": kind, **extra})

    @rule(side=st.sampled_from(["OURS", "THEIRS"]))
    def new_offer(self, side):
        self.revision += 1
        self.add("OFFER", side=side, revision=self.revision,
                 signature=f"bundle_{self.counter + 1}")

    @rule(side=st.sampled_from(["OURS", "THEIRS"]), old=st.booleans())
    def observed_accept(self, side, old):
        rev = max(0, self.revision - 1) if old else self.revision
        self.add("ACCEPT", side=side, revision=rev)

    @rule(signal=st.sampled_from(sorted(R.CALLBACKS)), delayed=st.booleans())
    def callback(self, signal, delayed):
        session = (self.prior_session if delayed and self.prior_session
                   else self.current_session)
        self.add("CALLBACK", session=session, signal=signal)

    @rule(gained=st.integers(min_value=0, max_value=3),
          lost=st.integers(min_value=0, max_value=3))
    def inventory_observation(self, gained, lost):
        self.add("INVENTORY_DELTA", gained=gained, lost=lost)

    @rule()
    def closure(self):
        self.add("CLOSE")

    @rule()
    def new_client_session(self):
        self.prior_session = self.current_session
        self.session_index += 1
        self.current_session = f"s_{self.session_index}"
        self.revision = 0
        self.add("OPEN")

    @rule()
    def duplicate_last_delivery(self):
        self.events.append(deepcopy(self.events[-1]))

    @invariant()
    def no_client_event_can_authorize_trade_or_learning(self):
        result = R.replay_trace(trace(self.events))
        safe(result)
        assert result["status"] == "CLIENT_REPLAY_ONLY", result["reason"]


TestClientEventReplayMachine = ClientEventReplayMachine.TestCase
TestClientEventReplayMachine.settings = settings(
    max_examples=75, stateful_step_count=30, deadline=None,
    suppress_health_check=(HealthCheck.too_slow,)
)


class ReplayPropertyTests(unittest.TestCase):
    @settings(max_examples=250, deadline=None)
    @given(st.lists(
        st.sampled_from(["accept", "offer", "callback", "close"]),
        min_size=1, max_size=50))
    def test_arbitrary_safe_arrivals_never_prove_trade(self, kinds):
        events = [{"id": "ev_1", "session": "s_a", "tMs": 0, "kind": "OPEN"}]
        rev = 0
        for i, kind in enumerate(kinds, 2):
            item = {"id": f"ev_{i}", "session": "s_a",
                    "tMs": i * 7, "kind": kind.upper()}
            if kind == "offer":
                rev += 1
                item.update(side="THEIRS", revision=rev, signature=f"bundle_{i}")
            elif kind == "accept":
                item.update(side="OURS", revision=rev)
            elif kind == "callback":
                item["signal"] = "ACCEPT_TRUE"
            events.append(item)
        result = R.replay_trace(trace(events))
        safe(result)
        assert result["status"] == "CLIENT_REPLAY_ONLY"

    @settings(max_examples=250, deadline=None)
    @given(st.one_of(
        st.none(), st.booleans(), st.integers(), st.floats(allow_nan=True),
        st.text(max_size=30), st.lists(st.integers(), max_size=4),
        st.dictionaries(st.text(max_size=4), st.integers(), max_size=3)
    ))
    def test_arbitrary_malformed_event_kind_is_quarantined(self, value):
        # Only an exact string kind is allowed; never crash on unhashable data.
        t = trace([{"id": "ev_1", "session": "s_a", "tMs": 0,
                    "kind": value}])
        result = R.replay_trace(t)
        safe(result)
        assert result["status"] == "QUARANTINED"

    @settings(max_examples=250, deadline=None)
    @given(st.one_of(
        st.none(), st.booleans(), st.integers(), st.floats(allow_nan=True),
        st.text(max_size=30), st.lists(st.integers(), max_size=4),
        st.dictionaries(st.text(max_size=4), st.integers(), max_size=3)
    ))
    def test_untrusted_extra_fields_cannot_grant_authority(self, value):
        t = trace([{"id": "ev_1", "session": "s_a", "tMs": 0,
                    "kind": "OPEN", "serverCompletionProven": value}])
        result = R.replay_trace(t)
        safe(result)
        assert result["status"] == "QUARANTINED"


if __name__ == "__main__":
    unittest.main()
