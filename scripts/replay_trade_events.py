"""Deterministic, sanitized CLIENT trade-event replay. No settlement authority.

This module never opens Roblox, sends a trade, or accepts unredacted client
reports. Stage67 validates a specific raw-client evidence report, and Stage68
handles duplicated client run GUIDs; this simulator only explores temporal
state transitions in a separately defined, non-identifying event vocabulary.
"""
from __future__ import annotations

import json
import re
from typing import Any

SOURCE_SCHEMA = "gingerscope-sanitized-client-events-v1"
RESULT_SCHEMA = "gingerscope-offline-event-replay-v1"
NONCE = re.compile(r"[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\Z")
TOKEN = re.compile(r"[a-z][a-z0-9_]{0,20}\Z")
KIND_FIELDS = {
    "OPEN": frozenset({"id", "session", "tMs", "kind"}),
    "CLOSE": frozenset({"id", "session", "tMs", "kind"}),
    "OFFER": frozenset({"id", "session", "tMs", "kind", "side", "revision", "signature"}),
    "ACCEPT": frozenset({"id", "session", "tMs", "kind", "side", "revision"}),
    "CALLBACK": frozenset({"id", "session", "tMs", "kind", "signal"}),
    "INVENTORY_DELTA": frozenset({"id", "session", "tMs", "kind", "gained", "lost"}),
}
CALLBACKS = frozenset({"ACCEPT_FALSE", "ACCEPT_TRUE", "DECLINE_SIGNAL", "END_TRADE"})
SIDES = frozenset({"OURS", "THEIRS"})
KINDS = frozenset(KIND_FIELDS)
SOURCES = frozenset({"SYNTHETIC_OFFLINE_TEST", "SANITIZED_CLIENT_OBSERVATION"})
FALSE_AUTHORITY = {
    "tradeOutcome": "UNKNOWN",
    "serverCompletionProven": False,
    "serverAttestation": False,
    "serverTransactionIdAuthenticated": False,
    "eventSessionAssociationProven": False,
    "causalTradeAttributionProven": False,
    "exactWeaponIdentityConfirmed": False,
    "mayRecordCompletedTrade": False,
    "mayRecordRejectedTrade": False,
    "mayReportProfit": False,
    "mayUseForStrategyLearning": False,
    "authorizesTrade": False,
    "authorizesAccept": False,
    "discordWebhookSent": False,
}


def _result(status: str, reason: str, **counts: int | bool | None) -> dict[str, Any]:
    result: dict[str, Any] = {
        "schema": RESULT_SCHEMA,
        "status": status,
        "reason": reason,
        "readOnly": True,
        "simulationOnly": True,
        "clientEventsAreUntrusted": True,
        "uniqueEvents": 0,
        "duplicateEvents": 0,
        "staleEvents": 0,
        "crossSessionEvents": 0,
        "offerMutations": 0,
        "acceptanceInvalidations": 0,
        "clientAcceptObservations": 0,
        "clientCallbackObservations": 0,
        "clientInventoryDeltaObservations": 0,
        "postCloseDeltaObservations": 0,
        "ambiguousDeclineSignals": 0,
        "windowClosures": 0,
        "activeSession": False,
        "currentRevision": None,
        **FALSE_AUTHORITY,
    }
    result.update(counts)
    return result


def _nonnegative(value: Any, bound: int) -> bool:
    return type(value) is int and 0 <= value <= bound


def _token(value: Any) -> bool:
    return type(value) is str and bool(TOKEN.fullmatch(value))


def _validate(source: object) -> str | None:
    if type(source) is not dict or set(source) != {
        "schema", "sourceKind", "clientRunNonce", "events"
    }:
        return "SOURCE_FIELDS_UNTRUSTED"
    if (source["schema"] != SOURCE_SCHEMA or type(source["sourceKind"]) is not str
            or source["sourceKind"] not in SOURCES):
        return "SOURCE_SCHEMA_OR_KIND_UNTRUSTED"
    if type(source["clientRunNonce"]) is not str or not NONCE.fullmatch(
        source["clientRunNonce"]
    ):
        return "CLIENT_RUN_NONCE_INVALID"
    events = source["events"]
    if type(events) is not list or not 0 < len(events) <= 256:
        return "EVENT_LIST_OUT_OF_BOUNDS"
    previous = -1
    for event in events:
        if (type(event) is not dict or type(event.get("kind")) is not str
                or event["kind"] not in KINDS):
            return "EVENT_KIND_OR_SHAPE_UNTRUSTED"
        kind = event["kind"]
        if set(event) != KIND_FIELDS[kind]:
            return "EVENT_FIELDS_UNTRUSTED"
        if not _token(event["id"]) or not _token(event["session"]):
            return "EVENT_ID_OR_SESSION_UNTRUSTED"
        t = event["tMs"]
        if not _nonnegative(t, 3_600_000) or t < previous:
            return "ARRIVAL_CLOCK_UNTRUSTED"
        previous = t
        if kind in {"ACCEPT", "OFFER"}:
            if type(event["side"]) is not str or event["side"] not in SIDES or not _nonnegative(
                event["revision"], 1_000_000
            ):
                return "SIDE_OR_REVISION_UNTRUSTED"
            if kind == "OFFER" and not _token(event["signature"]):
                return "OFFER_SIGNATURE_UNTRUSTED"
        elif kind == "CALLBACK" and (type(event["signal"]) is not str
                                    or event["signal"] not in CALLBACKS):
            return "CALLBACK_SIGNAL_UNTRUSTED"
        elif kind == "INVENTORY_DELTA" and (
            not _nonnegative(event["gained"], 1_000)
            or not _nonnegative(event["lost"], 1_000)
        ):
            return "CLIENT_DELTA_UNTRUSTED"
    return None


def replay_trace(source: object) -> dict[str, Any]:
    """Apply observations in captured *arrival* order, not claimed game order.

    All observations remain CLIENT-only, even if the terminal client record
    contains acceptance flags, inventory changes and a closed trade window.
    """
    why = _validate(source)
    if why:
        return _result("QUARANTINED", why)
    assert isinstance(source, dict)
    events = source["events"]
    counts = {
        "uniqueEvents": 0, "duplicateEvents": 0, "staleEvents": 0,
        "crossSessionEvents": 0, "offerMutations": 0,
        "acceptanceInvalidations": 0, "clientAcceptObservations": 0,
        "clientCallbackObservations": 0, "clientInventoryDeltaObservations": 0,
        "postCloseDeltaObservations": 0, "ambiguousDeclineSignals": 0,
        "windowClosures": 0,
    }
    seen: dict[str, str] = {}
    # Client session tokens must be unique within one replay trace.
    # Reopening a closed token would let a delayed callback or inventory
    # readback be misclassified as part of an entirely new trade window.
    opened_sessions: set[str] = set()
    active: str | None = None
    last_closed: str | None = None
    revision = 0
    accepted: set[str] = set()
    for event in events:
        # Duplicate recognition is strictly local to one sanitized replay.
        fingerprint = json.dumps(event, sort_keys=True, separators=(",", ":"))
        key = event["id"]
        if key in seen:
            if seen[key] != fingerprint:
                return _result("QUARANTINED", "CONFLICTING_DUPLICATE_EVENT")
            counts["duplicateEvents"] += 1
            continue
        seen[key] = fingerprint
        counts["uniqueEvents"] += 1
        kind, session = event["kind"], event["session"]
        if kind == "OPEN":
            # An identical redelivery ID was already deduplicated above.
            # A NEW OPEN with a previously used client session token is
            # ambiguous even if a prior CLOSE was observed. Fail closed.
            if session in opened_sessions:
                return _result("QUARANTINED", "REUSED_CLIENT_SESSION_TOKEN")
            opened_sessions.add(session)
            # An overlapping new OPEN supersedes the prior client session.
            if active is not None and active != session:
                counts["crossSessionEvents"] += 1
            active = session
            last_closed = None
            revision = 0
            accepted.clear()
            continue
        if kind == "INVENTORY_DELTA" and last_closed == session and active is None:
            # A post-close readback is observable, not attributable settlement.
            counts["clientInventoryDeltaObservations"] += 1
            counts["postCloseDeltaObservations"] += 1
            continue
        if active != session:
            counts["crossSessionEvents"] += 1
            continue
        if kind == "CLOSE":
            counts["windowClosures"] += 1
            last_closed = session
            active = None
            accepted.clear()
            continue
        if kind == "OFFER":
            new_rev = event["revision"]
            if new_rev < revision:
                counts["staleEvents"] += 1
                continue
            if new_rev == revision:
                return _result("QUARANTINED", "REUSED_OFFER_REVISION")
            if accepted:
                counts["acceptanceInvalidations"] += len(accepted)
            accepted.clear()
            revision = new_rev
            counts["offerMutations"] += 1
        elif kind == "ACCEPT":
            if revision == 0 or event["revision"] != revision:
                counts["staleEvents"] += 1
                continue
            accepted.add(event["side"])
            counts["clientAcceptObservations"] += 1
        elif kind == "CALLBACK":
            counts["clientCallbackObservations"] += 1
            if event["signal"] == "DECLINE_SIGNAL":
                # Raw callback does not identify the actor who declined.
                counts["ambiguousDeclineSignals"] += 1
        elif kind == "INVENTORY_DELTA":
            counts["clientInventoryDeltaObservations"] += 1
    return _result(
        "CLIENT_REPLAY_ONLY", "ORDERED_CLIENT_OBSERVATIONS_NOT_SETTLEMENT",
        **counts, activeSession=(active is not None),
        currentRevision=(revision if active is not None else None),
    )


if __name__ == "__main__":
    import sys
    from pathlib import Path

    if len(sys.argv) != 2:
        raise SystemExit("Usage: replay_trade_events.py <sanitized-event-trace.json>")
    data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    print(json.dumps(replay_trace(data), sort_keys=True))
