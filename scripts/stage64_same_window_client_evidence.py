"""Stage64: conservative OFFLINE validator of one native Stage63 client record.

No API, Roblox, source item IDs, Discord, offers, actual settlement or learning.
Never join records from different trades. A positive output is exclusively
client temporal observation, not server or trade outcome authentication.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

SCHEMA = "gingerscope-stage63-one-window-client-accept-delta-v1"
OUTPUT = "gingerscope-stage64-client-corroboration-audit-v1"
TOP_FIELDS = frozenset((
    "schema", "status", "reason", "readOnly", "tradeOutcome",
    "eventSessionAssociationProven", "causalTradeAttributionProven",
    "serverCompletionProven", "coreTerminal", "serverTransactionIdAuthenticated",
    "ownReadbacks", "mayRecordRejectedTrade", "sameBoundWindowClientOnly",
    "ignoredUnboundReceipts", "serverAttestation", "recordCount",
    "authorizesAccept", "authorizesTrade", "discardedReceipts",
    "samples", "listenerDisconnected", "clientCompatibleFlagPattern",
    "stablePartnerLabel", "guiBound", "clientReciprocalTransferProven",
    "mayRecordCompletedTrade", "mayReportProfit", "mayUseForStrategyLearning",
    "exactWeaponIdentityConfirmed"
))
OWN_FIELDS = frozenset((
    "rawWeaponInventoryChanged", "stopReason", "beforeObserved",
    "partnerCacheAtBaseline", "gainedEligibleCopies", "changedEligibleTypes",
    "status", "windowClosureObserved", "lostEligibleCopies",
    "postReadbacksObserved"
))
EVENT_FIELDS = frozenset((
    "secondArg", "firstArg", "phase", "elapsedSeconds",
    "argCount", "secondTableShape"
))
FLAG_FALSE = (
    "eventSessionAssociationProven", "causalTradeAttributionProven",
    "serverCompletionProven", "serverTransactionIdAuthenticated",
    "mayRecordRejectedTrade", "serverAttestation", "authorizesAccept",
    "authorizesTrade", "clientReciprocalTransferProven",
    "mayRecordCompletedTrade", "mayReportProfit", "mayUseForStrategyLearning",
    "exactWeaponIdentityConfirmed"
)
FLAG_TRUE = (
    "readOnly", "coreTerminal", "sameBoundWindowClientOnly",
    "listenerDisconnected", "clientCompatibleFlagPattern",
    "stablePartnerLabel", "guiBound"
)

def verdict(ok: bool, reason: str) -> dict:
    """All outputs intentionally exclude all caller-input data."""
    return {
        "schema": OUTPUT,
        "status": ("CLIENT_SAME_WINDOW_ACCEPT_PLUS_OWN_GAIN_UNATTRIBUTED"
                   if ok else "INCONCLUSIVE"),
        "reason": reason,
        "clientTemporalCorrelationObserved": ok,
        "operatorConfirmationForThisRunProven": False,
        "serverCompletionProven": False,
        "serverAttestation": False,
        "serverTransactionIdAuthenticated": False,
        "eventSessionAssociationProven": False,
        "causalTradeAttributionProven": False,
        "sameTradeCounterpartyAuthenticated": False,
        "exactWeaponIdentityConfirmed": False,
        "tradeOutcome": "UNKNOWN",
        "authorizesAccept": False,
        "authorizesTrade": False,
        "mayRecordCompletedTrade": False,
        "mayRecordRejectedTrade": False,
        "mayReportProfit": False,
        "mayUseForStrategyLearning": False,
        "discordLearningEligible": False,
    }

def bad(reason: str) -> dict:
    return verdict(False, reason)

def _decimal_tenth(n: object) -> bool:
    return (type(n) in (int, float) and math.isfinite(n) and
            0 <= n <= 150 and abs(n * 10 - round(n * 10)) < 1e-7)

def evaluate(value: object) -> dict:
    if not isinstance(value, dict) or set(value) != TOP_FIELDS:
        return bad("SOURCE_SCHEMA_OR_EXTRA_UNTRUSTED_FIELDS")
    if value["schema"] != SCHEMA or value["status"] != (
        "CLIENT_ACCEPT_FLAG_PLUS_OWN_GAIN_SAME_WINDOW_UNATTRIBUTED"
    ):
        return bad("SOURCE_STATUS_NOT_NATIVE_SAME_WINDOW")
    if value["reason"] != (
        "client-accept-flag-and-own-inventory-delta-do-not-authenticate-settlement"
    ) or value["tradeOutcome"] != "UNKNOWN":
        return bad("SOURCE_REASON_OR_OUTCOME_MUTATED")
    if any(value[k] is not False for k in FLAG_FALSE):
        return bad("UNTRUSTED_AUTHORITY_FLAG")
    if any(value[k] is not True for k in FLAG_TRUE):
        return bad("INCOMPLETE_CLIENT_SCOPE_OR_CLEANUP")
    if any(type(value[k]) is not int or value[k] != expected for k, expected in (
        ("ignoredUnboundReceipts", 0), ("discardedReceipts", 0),
        ("recordCount", 2),
    )):
        return bad("TRUNCATED_REPLAYED_OR_UNBOUND_CLIENT_CALLBACKS")
    own = value["ownReadbacks"]
    if not isinstance(own, dict) or set(own) != OWN_FIELDS:
        return bad("OWN_INVENTORY_SHAPE_OR_PRIVACY_CONTAMINATION")
    for key, exact in (
        ("status", "ELIGIBLE_DELTA_WITHOUT_RESULT_NAMED_RECEIPT"),
        ("stopReason", "TWO_POST_CLOSE_READS_FINISHED"),
        ("beforeObserved", True), ("windowClosureObserved", True),
        ("rawWeaponInventoryChanged", True),
        ("partnerCacheAtBaseline", True),
        ("postReadbacksObserved", 2),
        ("gainedEligibleCopies", 1), ("lostEligibleCopies", 0),
        ("changedEligibleTypes", 1),
    ):
        if type(own.get(key)) is not type(exact) or own[key] != exact:
            return bad("OWN_BASELINE_OR_POSTCLOSE_QUANTITY_UNVERIFIED")
    samples = value["samples"]
    if not isinstance(samples, list) or len(samples) != 2:
        return bad("CLIENT_CALLBACK_COUNT_NOT_TWO")
    for sample in samples:
        if not isinstance(sample, dict) or set(sample) != EVENT_FIELDS:
            return bad("CLIENT_CALLBACK_SHAPE_OR_PRIVACY_CONTAMINATION")
        if sample["phase"] != "WITHIN_BOUND_GUI_CLIENT_ONLY":
            return bad("CLIENT_CALLBACK_NOT_WITHIN_BOUND_WINDOW")
        if not _decimal_tenth(sample["elapsedSeconds"]):
            return bad("INVALID_CLIENT_CALLBACK_TIME")
    a, b = samples
    if not (
        a["firstArg"] == "BOOLEAN_FALSE" and
        a["secondArg"] == "NIL" and
        a["secondTableShape"] == "NOT_TABLE" and
        type(a["argCount"]) is int and a["argCount"] == 1 and
        b["firstArg"] == "BOOLEAN_TRUE" and
        b["secondArg"] == "TABLE" and
        b["secondTableShape"] == "BOUNDED_SEQUENCE_1" and
        type(b["argCount"]) is int and b["argCount"] == 2
    ):
        return bad("HISTORICAL_CLIENT_BOOLEAN_TABLE_ORDER_UNCONFIRMED")
    gap = round(b["elapsedSeconds"] - a["elapsedSeconds"], 8)
    if gap < 0 or gap > 5:
        return bad("CLIENT_CALLBACK_TIME_ORDER_OR_GAP_INVALID")
    # This only recognizes a local observation. It does NOT grant authority.
    return verdict(True, "native-client-same-window-evidence-not-server-attested")

def main() -> None:
    import sys
    if len(sys.argv) != 2:
        raise SystemExit("Usage: stage64_same_window_client_evidence.py <report.json>")
    print(json.dumps(
        evaluate(json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))),
        sort_keys=True,
    ))

if __name__ == "__main__":
    main()
