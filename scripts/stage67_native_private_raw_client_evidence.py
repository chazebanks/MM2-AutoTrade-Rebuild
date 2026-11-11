"""Stage67: OFFLINE strict audit of one native Stage66 read-only client report.

No Roblox APIs, network, database, Discord or historical trade joins.
Do not treat a source report lacking an observation nonce as deduplicable.
The input is a client-observed event shape plus raw-key primitive equality
with own readbacks. This is not a signed, item-specific server settlement.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

SOURCE = "gingerscope-stage66-one-window-client-accept-delta-v1"
SCHEMA = "gingerscope-stage67-native-raw-client-evidence-audit-v1"

REPORT_KEYS = frozenset("""
eventSessionAssociationProven recordCount coreTerminal readOnly
serverTransactionIdAuthenticated status callbackRowFieldTypes callbackRowShape
serverAttestation authorizesAccept authorizesTrade listenerDisconnected
clientCompatibleFlagPattern schema causalTradeAttributionProven
serverCompletionProven mayRecordCompletedTrade reason tradeOutcome
discardedReceipts mayRecordRejectedTrade privateRawKeyEqualityObserved
privateRawEqualityStatus stablePartnerLabel samples ownReadbacks
ignoredUnboundReceipts guiBound sameBoundWindowClientOnly
exactCallbackWeaponKeyIdentityProven privateRawEqualityReason
clientReciprocalTransferProven mayUseForStrategyLearning mayReportProfit
exactWeaponIdentityConfirmed
""".split())

OWN_KEYS = frozenset("""
rawWeaponInventoryChanged stopReason beforeObserved partnerCacheAtBaseline
gainedEligibleCopies changedEligibleTypes status windowClosureObserved
lostEligibleCopies postReadbacksObserved
""".split())

SAMPLE_KEYS = frozenset("""
secondArg firstArg phase elapsedSeconds argCount secondTableShape
""".split())

FALSE_FLAGS = (
    "eventSessionAssociationProven", "serverTransactionIdAuthenticated",
    "serverAttestation", "authorizesAccept", "authorizesTrade",
    "causalTradeAttributionProven", "serverCompletionProven",
    "mayRecordCompletedTrade", "mayRecordRejectedTrade",
    "exactCallbackWeaponKeyIdentityProven", "clientReciprocalTransferProven",
    "mayUseForStrategyLearning", "mayReportProfit", "exactWeaponIdentityConfirmed",
)

TRUE_FLAGS = (
    "readOnly", "coreTerminal", "listenerDisconnected",
    "clientCompatibleFlagPattern", "privateRawKeyEqualityObserved",
    "stablePartnerLabel", "guiBound", "sameBoundWindowClientOnly",
)

def _output(status: str, reason: str) -> dict:
    # Zero caller-controlled text or item keys are ever emitted.
    passed = status == "CLIENT_PRIVATE_RAW_KEY_EQUALITY_UNATTRIBUTED"
    return {
        "schema": SCHEMA,
        "status": status,
        "reason": reason,
        "clientRawPrimitiveEqualityPatternObserved": passed,
        "evidenceTier": "LOCAL_CLIENT_OBSERVATION_NOT_SETTLEMENT",
        "recordDeduplicationPossible": False,
        "sourceRunNonceObserved": False,
        "distinctTradeObserved": False,
        "independentCounterpartyWitnessObserved": False,
        "operatorConfirmedThisRun": False,
        "serverAttestation": False,
        "serverCompletionProven": False,
        "serverTransactionIdAuthenticated": False,
        "eventSessionAssociationProven": False,
        "causalTradeAttributionProven": False,
        "exactWeaponIdentityConfirmed": False,
        "mayRecordCompletedTrade": False,
        "mayRecordRejectedTrade": False,
        "mayReportProfit": False,
        "mayUseForStrategyLearning": False,
        "authorizesAccept": False,
        "authorizesTrade": False,
        "discordMarketLearningEligible": False,
        "tradeOutcome": "UNKNOWN",
    }

def inconclusive(reason: str) -> dict:
    return _output("INCONCLUSIVE", reason)

def _one_decimal_in_range(v: object) -> bool:
    return (type(v) in (float, int)
            and math.isfinite(v) and 0 <= v <= 150
            and abs(v * 10 - round(v * 10)) < 1e-7)

def evaluate(report: object) -> dict:
    """One report only. Do not accept a batch or a merged Stage59/61/63 report."""
    if not isinstance(report, dict) or set(report) != REPORT_KEYS:
        return inconclusive("REPORT_SCHEMA_OR_UNTRUSTED_FIELDS")

    if report["schema"] != SOURCE:
        return inconclusive("WRONG_SOURCE_SCHEMA")
    if report["status"] != "CLIENT_RAW_RECEIPT_EQUALS_OWN_GAIN_UNATTRIBUTED":
        return inconclusive("WRONG_CLIENT_STATUS")
    if (report["reason"]
            != "private-raw-key-string-equality-is-not-server-settlement-proof"
            or report["tradeOutcome"] != "UNKNOWN"):
        return inconclusive("SOURCE_REASON_OR_OUTCOME_INCONSISTENT")

    for key in FALSE_FLAGS:
        if report[key] is not False:
            return inconclusive("SOURCE_AUTHORITY_FLAG_INCONSISTENT")
    for key in TRUE_FLAGS:
        if report[key] is not True:
            return inconclusive("CLIENT_SCOPE_OR_SCRUB_FLAG_INCONSISTENT")

    if (report["callbackRowFieldTypes"] != ["string", "number", "string"]
            or type(report["callbackRowFieldTypes"]) is not list
            or report["callbackRowShape"] != "TRIPLET_ELEMENT_TYPES_OBSERVED"):
        return inconclusive("NATIVE_RECEIPT_ROW_TYPES_INCONSISTENT")
    if (report["privateRawEqualityStatus"]
            != "PRIVATE_RAW_PRIMITIVE_EQUALITY_CLIENT_ONLY"
            or report["privateRawEqualityReason"]
            != "private-exact-string-equality-is-not-server-transaction-proof"):
        return inconclusive("PRIVATE_EQUALITY_CONTRACT_INCONSISTENT")

    for key, expected in (
        ("recordCount", 2), ("discardedReceipts", 0),
        ("ignoredUnboundReceipts", 0),
    ):
        if type(report[key]) is not int or report[key] != expected:
            return inconclusive("CLIENT_RECEIPT_COUNTS_INCONSISTENT")

    own = report["ownReadbacks"]
    if not isinstance(own, dict) or set(own) != OWN_KEYS:
        return inconclusive("OWN_INVENTORY_SHAPE_UNTRUSTED")
    expected_own = {
        "rawWeaponInventoryChanged": True,
        "stopReason": "TWO_POST_CLOSE_READS_FINISHED",
        "beforeObserved": True,
        "partnerCacheAtBaseline": True,
        "gainedEligibleCopies": 1,
        "changedEligibleTypes": 1,
        "status": "ELIGIBLE_DELTA_WITHOUT_RESULT_NAMED_RECEIPT",
        "windowClosureObserved": True,
        "lostEligibleCopies": 0,
        "postReadbacksObserved": 2,
    }
    for key, required in expected_own.items():
        if type(own[key]) is not type(required) or own[key] != required:
            return inconclusive("OWN_INVENTORY_COUNTS_OR_READBACKS_INCONSISTENT")

    events = report["samples"]
    if type(events) is not list or len(events) != 2:
        return inconclusive("ACCEPT_CALLBACK_COUNT_UNTRUSTED")
    for event in events:
        if not isinstance(event, dict) or set(event) != SAMPLE_KEYS:
            return inconclusive("ACCEPT_CALLBACK_FIELDS_UNTRUSTED")
        if not _one_decimal_in_range(event["elapsedSeconds"]):
            return inconclusive("ACCEPT_CALLBACK_TIME_UNTRUSTED")
        if type(event["argCount"]) is not int:
            return inconclusive("ACCEPT_CALLBACK_ARGCOUNT_UNTRUSTED")
    before, after = events
    if not (
        before["firstArg"] == "BOOLEAN_FALSE"
        and before["secondArg"] == "NIL"
        and before["secondTableShape"] == "NOT_TABLE"
        and before["argCount"] == 1
        and before["phase"] == "WITHIN_BOUND_GUI_CLIENT_ONLY"
        and after["firstArg"] == "BOOLEAN_TRUE"
        and after["secondArg"] == "TABLE"
        and after["secondTableShape"] == "BOUNDED_SEQUENCE_1"
        and after["argCount"] == 2
        and after["phase"] in (
            "WITHIN_BOUND_GUI_CLIENT_ONLY",
            "IMMEDIATE_GUI_CLOSE_CLIENT_ONLY",
        )
    ):
        return inconclusive("ACCEPT_CALLBACK_PATTERN_NOT_PROVEN")
    gap = after["elapsedSeconds"] - before["elapsedSeconds"]
    if gap < 0 or gap > 5:
        return inconclusive("ACCEPT_CALLBACK_NOT_ORDERED_WITHIN_ONE_WINDOW")

    # Pass is only an independently checked report SHAPE.
    # No unique run nonce, participant IDs, verified payout or server result.
    return _output(
        "CLIENT_PRIVATE_RAW_KEY_EQUALITY_UNATTRIBUTED",
        "private-client-callback-key-matches-own-gain-but-not-settlement",
    )

def main() -> None:
    import sys
    if len(sys.argv) != 2:
        raise SystemExit("Usage: stage67_native_private_raw_client_evidence.py <report.json>")
    content = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    print(json.dumps(evaluate(content), sort_keys=True))

if __name__ == "__main__":
    main()
