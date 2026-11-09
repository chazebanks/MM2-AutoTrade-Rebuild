"""Stage62 conservative classifier for one Stage61 client AcceptTrade report.

Read-only, isolated, offline. Never treats a client event as authenticated
MM2 settlement, opponent decline, a completed Discord learner example,
or proof of the weapon/item exchanged. Stage59 records are intentionally
not accepted: their observations were from DIFFERENT real trades.
"""
from __future__ import annotations

import json
import math
import re
from pathlib import Path

SOURCE = "gingerscope-stage61-accept-client-args-v1"
RESULT = "gingerscope-stage62-client-event-evidence-gate-v1"
SOURCE_FIELDS = frozenset((
    "schema", "status", "reason", "readOnly", "tradeOutcome",
    "serverAttestation", "serverCompletionProven",
    "serverTransactionIdAuthenticated", "eventSessionAssociationProven",
    "causalTradeAttributionProven", "exactWeaponIdentityConfirmed",
    "authorizesAccept", "authorizesTrade", "mayRecordCompletedTrade",
    "mayRecordRejectedTrade", "mayReportProfit", "mayUseForStrategyLearning",
    "observedSingleGui", "guiStableBound", "guiClosedObserved",
    "scopedEventCount", "unboundEventCount", "totalReceipts",
    "discardedReceipts", "listenersDisconnected", "hadTypeTrue",
    "hadTypeFalse", "historicalClientFlagHypothesisCompatible", "events",
))
EVENT_FIELDS = frozenset((
    "phase", "firstArg", "secondArg", "secondTableShape", "argCount",
    "elapsedSeconds",
))
FIRST = frozenset(("BOOLEAN_FALSE", "BOOLEAN_TRUE", "NIL", "NO_ARGS", "OTHER"))
SECOND = frozenset(("TABLE", "NIL", "OTHER"))
PHASE = frozenset((
    "PRE_BOUND_UNATTRIBUTED", "DURING_GUI_CLIENT_ONLY",
    "AFTER_CLOSE_UNATTRIBUTED", "OUT_OF_WINDOW",
))
SEQUENCE = re.compile(r"^BOUNDED_SEQUENCE_(?:[1-9]|1[0-6])$")


def _result(status: str, reason: str) -> dict:
    # Intentionally never projects input metadata, even malformed user data.
    return {
        "schema": RESULT,
        "status": status,
        "reason": reason,
        "sourceKind": "ONE_STAGE61_CLIENT_REPORT_ONLY",
        "sourceEvidenceValidated": status == "CLIENT_FALSE_TRUE_CALLBACK_WITH_TABLE_UNATTRIBUTED",
        "clientSuccessLikeSignalObserved":
            status == "CLIENT_FALSE_TRUE_CALLBACK_WITH_TABLE_UNATTRIBUTED",
        "tradeOutcome": "UNKNOWN",
        "readOnly": True,
        "serverAttestation": False,
        "serverCompletionProven": False,
        "serverTransactionIdAuthenticated": False,
        "sameServerJobAuthenticated": False,
        "eventSessionAssociationProven": False,
        "causalTradeAttributionProven": False,
        "exactWeaponIdentityConfirmed": False,
        "operatorConfirmedThisTrade": False,
        "stage59SameTransactionBound": False,
        "mayRecordCompletedTrade": False,
        "mayRecordRejectedTrade": False,
        "mayReportProfit": False,
        "mayUseForStrategyLearning": False,
        "authorizesAccept": False,
        "authorizesTrade": False,
        "discordLearningEligible": False,
    }


def _invalid(reason: str) -> dict:
    return _result("INCONCLUSIVE", reason)


def evaluate(report: object) -> dict:
    """Validate one anonymized Stage61 report, no game calls or session join."""
    if not isinstance(report, dict):
        return _invalid("SOURCE_MISSING_OR_WRONG_TYPE")
    # Treat an extra nested "stage59" field, user IDs, payloads, etc. as
    # contamination rather than silently mapping a second trade into this one.
    if set(report) != SOURCE_FIELDS:
        return _invalid("SOURCE_FIELDS_MISMATCH_OR_CROSS_SESSION_CONTAMINATION")
    if report["schema"] != SOURCE:
        return _invalid("SOURCE_SCHEMA_MISMATCH")
    if report["status"] != "CLIENT_CALLBACK_SHAPES_CAPTURED_UNATTRIBUTED":
        return _invalid("SOURCE_NOT_TERMINAL_CALLBACK_SHAPES")
    if report["reason"] != "CLIENT_EVENT_NAMES_AND_ARGUMENT_TYPES_ONLY":
        return _invalid("SOURCE_RESULT_REASON_MISMATCH")
    if report["readOnly"] is not True or report["tradeOutcome"] != "UNKNOWN":
        return _invalid("SOURCE_AUTHORITY_OR_OUTCOME_MUTATED")
    for key in (
        "serverAttestation", "serverCompletionProven",
        "serverTransactionIdAuthenticated", "eventSessionAssociationProven",
        "causalTradeAttributionProven", "exactWeaponIdentityConfirmed",
        "authorizesAccept", "authorizesTrade", "mayRecordCompletedTrade",
        "mayRecordRejectedTrade", "mayReportProfit", "mayUseForStrategyLearning",
    ):
        if report[key] is not False:
            return _invalid("SOURCE_AUTHORITY_OR_OUTCOME_MUTATED")
    for key in ("observedSingleGui", "guiStableBound", "guiClosedObserved"):
        if report[key] is not True:
            return _invalid("GUI_OR_CLOSURE_UNBOUND")
    if type(report["listenersDisconnected"]) is not int or report["listenersDisconnected"] != 1:
        return _invalid("LISTENER_CLEANUP_UNPROVEN")
    if type(report["discardedReceipts"]) is not int or report["discardedReceipts"] != 0:
        return _invalid("MISSING_OR_OVERFLOWING_CLIENT_EVENTS")
    events = report["events"]
    if not isinstance(events, list) or not (1 <= len(events) <= 12):
        return _invalid("INVALID_CLIENT_EVENT_COUNT")
    for key in ("totalReceipts", "scopedEventCount", "unboundEventCount"):
        if type(report[key]) is not int or report[key] < 0 or report[key] > 12:
            return _invalid("INVALID_SOURCE_EVENT_COUNTER")
    if (report["totalReceipts"] != len(events)
            or report["scopedEventCount"] + report["unboundEventCount"] != len(events)):
        return _invalid("CLIENT_EVENT_COUNTER_MISMATCH")
    for key in ("hadTypeTrue", "hadTypeFalse", "historicalClientFlagHypothesisCompatible"):
        if type(report[key]) is not bool:
            return _invalid("INVALID_SOURCE_BOOLEAN")
    elapsed = -1.0
    scoped_true = scoped_false = False
    seen_false = False
    historically_compatible = False
    for sample in events:
        if not isinstance(sample, dict) or set(sample) != EVENT_FIELDS:
            return _invalid("EVENT_FIELD_CONTAMINATION")
        if (sample["phase"] not in PHASE
                or sample["firstArg"] not in FIRST
                or sample["secondArg"] not in SECOND):
            return _invalid("UNEXPECTED_EVENT_ENUM")
        count = sample["argCount"]
        if type(count) is not int or not (0 <= count <= 16):
            return _invalid("INVALID_ARGUMENT_COUNT")
        if sample["firstArg"] == "NO_ARGS" and count != 0:
            return _invalid("ARGUMENT_SHAPE_CONTRADICTION")
        if sample["firstArg"] != "NO_ARGS" and count == 0:
            return _invalid("ARGUMENT_SHAPE_CONTRADICTION")
        if count < 2 and sample["secondArg"] != "NIL":
            return _invalid("ARGUMENT_SHAPE_CONTRADICTION")
        shape = sample["secondTableShape"]
        if sample["secondArg"] == "TABLE":
            if not isinstance(shape, str) or (
                shape not in ("UNKNOWN_OR_OVERSIZE", "EMPTY_OR_DICTIONARY")
                and SEQUENCE.fullmatch(shape) is None
            ):
                return _invalid("SECOND_ARGUMENT_TABLE_SHAPE_INVALID")
        elif shape != "NOT_TABLE":
            return _invalid("SECOND_ARGUMENT_TABLE_SHAPE_INVALID")
        when = sample["elapsedSeconds"]
        if (type(when) not in (float, int) or not math.isfinite(when)
                or when < 0 or when > 130 or round(when, 1) != when
                or when < elapsed):
            return _invalid("EVENT_TIME_INVALID_OR_OUT_OF_ORDER")
        elapsed = when
        if sample["phase"] in ("DURING_GUI_CLIENT_ONLY", "AFTER_CLOSE_UNATTRIBUTED"):
            if sample["firstArg"] == "BOOLEAN_TRUE":
                scoped_true = True
                if seen_false:
                    historically_compatible = True
            if sample["firstArg"] == "BOOLEAN_FALSE":
                scoped_false = True
                seen_false = True
    if (report["hadTypeTrue"] != scoped_true
            or report["hadTypeFalse"] != scoped_false
            or report["historicalClientFlagHypothesisCompatible"] != historically_compatible):
        return _invalid("SOURCE_SELF_REPORTED_FLAG_CONTRADICTION")
    observed_scoped = sum(
        sample["phase"] in ("DURING_GUI_CLIENT_ONLY", "AFTER_CLOSE_UNATTRIBUTED")
        for sample in events
    )
    if observed_scoped != report["scopedEventCount"]:
        return _invalid("CLIENT_SCOPE_COUNTER_MISMATCH")
    if report["unboundEventCount"] != 0:
        return _invalid("UNBOUND_EVENTS_PRESENT")
    if len(events) != 2 or report["scopedEventCount"] != 2:
        return _invalid("OTHER_OR_EXTRA_CLIENT_CALLBACKS")
    first, second = events
    if (first["phase"] != "DURING_GUI_CLIENT_ONLY"
            or second["phase"] != "DURING_GUI_CLIENT_ONLY"):
        return _invalid("CLIENT_EVENTS_NOT_WITHIN_BOUND_GUI_WINDOW")
    if (first["firstArg"] != "BOOLEAN_FALSE"
            or first["argCount"] != 1
            or first["secondArg"] != "NIL"
            or second["firstArg"] != "BOOLEAN_TRUE"
            or second["argCount"] != 2
            or second["secondArg"] != "TABLE"
            or SEQUENCE.fullmatch(second["secondTableShape"]) is None):
        return _invalid("HISTORICAL_FALSE_TRUE_TABLE_PATTERN_NOT_MET")
    gap = second["elapsedSeconds"] - first["elapsedSeconds"]
    if gap < 0 or gap > 5:
        return _invalid("CLIENT_CALLBACK_GAP_OUT_OF_BOUNDS")
    # Strong *client* observation, still NO settlement/identity/learner authority.
    return _result(
        "CLIENT_FALSE_TRUE_CALLBACK_WITH_TABLE_UNATTRIBUTED",
        "current-client-accept-callback-shape-matches-historical-ui-branch-only",
    )


def main() -> None:
    import sys
    if len(sys.argv) != 2:
        raise SystemExit("Usage: stage62_client_accept_evidence.py <stage61_report.json>")
    print(json.dumps(
        evaluate(json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))),
        sort_keys=True,
    ))


if __name__ == "__main__":
    main()
