"""Execute the actual sanitized replay model with deterministic client sequences."""
from __future__ import annotations

from copy import deepcopy
import importlib.util
import random
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
MODULE = ROOT / "scripts/replay_trade_events.py"
SPEC = importlib.util.spec_from_file_location("gingerscope_event_replay", MODULE)
assert SPEC and SPEC.loader
R = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(R)

RUN = "01234567-89ab-cdef-0123-456789abcdef"


def event(number, kind, session="s_main", t=None, **extra):
    return {"id": f"event_{number}", "session": session, "tMs": number * 100 if t is None else t,
            "kind": kind, **extra}


def trace(events):
    return {"schema": R.SOURCE_SCHEMA, "sourceKind": "SYNTHETIC_OFFLINE_TEST",
            "clientRunNonce": RUN, "events": events}


def example():
    return trace([
        event(1, "OPEN"),
        event(2, "OFFER", side="THEIRS", revision=1, signature="bundle_a"),
        event(3, "ACCEPT", side="OURS", revision=1),
        event(4, "CALLBACK", signal="ACCEPT_FALSE"),
        event(5, "CALLBACK", signal="ACCEPT_TRUE"),
        event(6, "CLOSE"),
        event(7, "INVENTORY_DELTA", gained=1, lost=0),
    ])


class SanitizedReplayTests(unittest.TestCase):
    def safe(self, output):
        for key, value in R.FALSE_AUTHORITY.items():
            self.assertEqual(output[key], value, key)
        self.assertTrue(output["readOnly"])
        self.assertTrue(output["simulationOnly"])
        self.assertNotIn(RUN, str(output))
        self.assertNotIn("bundle_a", str(output))
        self.assertNotIn("s_main", str(output))

    def test_stage66_shaped_client_pattern_is_not_completion(self):
        result = R.replay_trace(example())
        self.safe(result)
        self.assertEqual(result["status"], "CLIENT_REPLAY_ONLY")
        self.assertEqual(result["clientCallbackObservations"], 2)
        self.assertEqual(result["windowClosures"], 1)
        self.assertEqual(result["postCloseDeltaObservations"], 1)

    def test_new_offer_invalidates_prior_accept(self):
        t = trace([event(1, "OPEN"),
            event(2, "OFFER", side="THEIRS", revision=1, signature="bundle_a"),
            event(3, "ACCEPT", side="OURS", revision=1),
            event(4, "OFFER", side="THEIRS", revision=2, signature="bundle_b"),
            event(5, "ACCEPT", side="OURS", revision=1)])
        x = R.replay_trace(t)
        self.safe(x)
        self.assertEqual(x["acceptanceInvalidations"], 1)
        self.assertEqual(x["staleEvents"], 1)
        self.assertEqual(x["offerMutations"], 2)

    def test_duplicate_event_is_idempotent(self):
        original = example()
        original["events"].insert(3, deepcopy(original["events"][2]))
        x = R.replay_trace(original)
        self.safe(x)
        self.assertEqual(x["duplicateEvents"], 1)
        self.assertEqual(x["uniqueEvents"], 7)
        self.assertEqual(x["clientAcceptObservations"], 1)

    def test_conflicting_duplicate_is_quarantined(self):
        t = example()
        other = deepcopy(t["events"][2])
        other["side"] = "THEIRS"
        t["events"].insert(3, other)
        x = R.replay_trace(t)
        self.safe(x)
        self.assertEqual(x["status"], "QUARANTINED")
        self.assertEqual(x["reason"], "CONFLICTING_DUPLICATE_EVENT")

    def test_reused_offer_revision_is_ambiguous(self):
        t = trace([event(1, "OPEN"),
             event(2, "OFFER", side="OURS", revision=1, signature="bundle_a"),
             event(3, "OFFER", side="THEIRS", revision=1, signature="bundle_b")])
        x = R.replay_trace(t)
        self.safe(x)
        self.assertEqual(x["reason"], "REUSED_OFFER_REVISION")

    def test_delayed_callback_from_prior_session_is_ignored(self):
        t = trace([event(1, "OPEN", "s_old"),
             event(2, "OFFER", "s_old", side="OURS", revision=1, signature="bundle_a"),
             event(3, "OPEN", "s_new"),
             event(4, "CALLBACK", "s_old", signal="ACCEPT_TRUE"),
             event(5, "ACCEPT", "s_old", side="OURS", revision=1),
             event(6, "CLOSE", "s_new")])
        x = R.replay_trace(t)
        self.safe(x)
        self.assertEqual(x["crossSessionEvents"], 3)
        self.assertEqual(x["clientCallbackObservations"], 0)
        self.assertEqual(x["windowClosures"], 1)

    def test_raw_decline_signal_is_not_opponent_rejection(self):
        t = trace([event(1, "OPEN"),
             event(2, "CALLBACK", signal="DECLINE_SIGNAL"), event(3, "CLOSE")])
        x = R.replay_trace(t)
        self.safe(x)
        self.assertEqual(x["ambiguousDeclineSignals"], 1)
        self.assertFalse(x["mayRecordRejectedTrade"])

    def test_privacy_and_authority_field_injections_quarantined(self):
        for key, value in (
            ("serverCompletionProven", True), ("rawWeaponKey", "private_key"),
            ("playerName", "private_user"), ("authorizesAccept", True),
        ):
            with self.subTest(field=key):
                t = example()
                t["events"][1][key] = value
                x = R.replay_trace(t)
                self.safe(x)
                self.assertEqual(x["status"], "QUARANTINED")

    def test_nonmonotonic_arrival_clock_rejected(self):
        t = example()
        t["events"][4]["tMs"] = 1
        x = R.replay_trace(t)
        self.safe(x)
        self.assertEqual(x["reason"], "ARRIVAL_CLOCK_UNTRUSTED")

    def test_replay_is_deterministic(self):
        t = example()
        self.assertEqual(R.replay_trace(t), R.replay_trace(deepcopy(t)))
        self.assertEqual(t["events"][-1]["gained"], 1)

    def test_untrusted_value_types_fail_closed_not_raise(self):
        for bad in ([1], {}, None, False, 7, ""):
            with self.subTest(value=bad):
                t = example()
                t["sourceKind"] = bad
                x = R.replay_trace(t)
                self.safe(x)
                self.assertEqual(x["status"], "QUARANTINED")
                t = example()
                t["events"][1]["kind"] = bad
                self.assertEqual(R.replay_trace(t)["status"], "QUARANTINED")
                t = example()
                t["events"][1]["side"] = bad
                self.assertEqual(R.replay_trace(t)["status"], "QUARANTINED")
                t = example()
                t["events"][3]["signal"] = bad
                self.assertEqual(R.replay_trace(t)["status"], "QUARANTINED")

    def test_bad_counts_and_list_boundaries(self):
        for bad in (True, -1, 1.5, 1001, "1"):
            t = example()
            t["events"][-1]["gained"] = bad
            self.assertEqual(R.replay_trace(t)["status"], "QUARANTINED")
        too_long = trace([event(i, "OPEN") for i in range(1, 258)])
        self.assertEqual(R.replay_trace(too_long)["reason"], "EVENT_LIST_OUT_OF_BOUNDS")

    def test_500_seeded_safe_interleavings(self):
        rng = random.Random(68042026)
        for index in range(500):
            events = [event(1, "OPEN")]
            rev = 0
            for seq in range(2, 2 + rng.randrange(1, 30)):
                choice = rng.choice(("OFFER", "ACCEPT", "CALLBACK", "INVENTORY_DELTA"))
                extras = {}
                if choice == "OFFER":
                    rev += 1
                    extras = {"side": rng.choice(("OURS", "THEIRS")),
                              "revision": rev, "signature": f"bundle_{seq}"}
                elif choice == "ACCEPT":
                    extras = {"side": rng.choice(("OURS", "THEIRS")),
                              "revision": rng.choice((rev, max(0, rev-1)))}
                elif choice == "CALLBACK":
                    extras = {"signal": rng.choice(sorted(R.CALLBACKS))}
                else:
                    extras = {"gained": rng.randrange(3), "lost": rng.randrange(3)}
                events.append(event(seq, choice, **extras))
            events.append(event(99, "CLOSE", t=10_000))
            output = R.replay_trace(trace(events))
            with self.subTest(index=index):
                self.safe(output)
                self.assertEqual(output["status"], "CLIENT_REPLAY_ONLY")


if __name__ == "__main__":
    unittest.main()
