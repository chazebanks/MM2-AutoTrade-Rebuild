"""Classify *untrusted client-only* System1 diagnostic receipts.

A client PASS only proves that a preauthorized test scenario progressed to
a closed GUI window. A STOP can prove containment, not completion. Neither
classification ever permits a final Accept, profit, pricing, or learning.
No filesystem, HTTP, Roblox, Discord, or private account access is used.
"""
from __future__ import annotations

SCHEMA = "gingerscope-system1-main-auto-native-v1"
SCENARIOS = (
    "STACK_QTY2",
    "CHROMA_VARIANT",
    "DELAYED_ALT_RESPONSE",
    "ALT_SLOT_COMPACTION",
    "MAIN_SLOT_COMPACTION",
    "FOUR_MAIN_PHYSICAL_SLOTS",
    "NORMAL_ALT_CANCEL",
    "TWO_ALT_REVISIONS",
)
DENIED = (
    "authorizesAccept",
    "serverCompletionProven",
    "mayReportProfit",
    "maySendDiscordWebhook",
    "mayUseForStrategyLearning",
)


def classify_receipt(data: object) -> dict:
    def rejected(reason):
        return {
            "schema": "gingerscope-system1-batch-evidence-check-v1",
            "status": "REJECTED",
            "reason": reason,
            "serverCompletionProven": False,
            "mayAuthorizeTrading": False,
            "verifiedCompletedTrades": 0,
        }

    if type(data) is not dict or data.get("schema") != SCHEMA:
        return rejected("UNKNOWN_OR_MALFORMED_CLIENT_RECEIPT")
    if any(data.get(flag) is not False for flag in DENIED):
        return rejected("RECEIPT_ASSERTS_UNPROVEN_AUTHORITY")
    if data.get("tradeOutcome") != "UNKNOWN":
        return rejected("TRADE_OUTCOME_MUST_REMAIN_UNKNOWN")
    if data.get("finalAcceptEverAttempted") is not False:
        return rejected("FINAL_ACCEPT_CANNOT_BE_ATTESTED")
    if type(data.get("verifiedCompletedTrades")) is not int or data["verifiedCompletedTrades"] != 0:
        return rejected("CLIENT_CANNOT_ATTEST_SETTLED_TRADES")
    rounds = data.get("rounds")
    if type(rounds) is not list or len(rounds) > len(SCENARIOS):
        return rejected("INVALID_ROUND_LEDGER")
    for i,record in enumerate(rounds):
        if (type(record) is not dict or
                type(record.get("round")) is not int or
                record["round"] != i + 1 or
                record.get("scenarioId") != SCENARIOS[i] or
                record.get("status") != "CLIENT_SEQUENCE_PASS" or
                record.get("clientWindowClosed") is not True):
            return rejected("BAD_OR_OUT_OF_ORDER_CLIENT_LEDGER")
    n = len(rounds)
    if type(data.get("completedRounds")) is not int or data["completedRounds"] != n:
        return rejected("COMPLETED_COUNT_DISAGREES_WITH_LEDGER")
    actions = data.get("actions")
    if type(actions) is not dict:
        return rejected("MISSING_ACTION_COUNTERS")
    expected_count_names = ("requestsStarted", "offersAttempted", "offersClientVisible",
                            "removalsAttempted", "declinesAttempted", "clientClosedWindows")
    if any(type(actions.get(key)) is not int or actions[key] < 0 for key in expected_count_names):
        return rejected("NON_INTEGER_OR_NEGATIVE_ACTION_COUNTER")
    if actions["clientClosedWindows"] != n:
        return rejected("CLOSED_WINDOW_COUNT_MISMATCH")
    if (actions["offersClientVisible"] > actions["offersAttempted"] or
            actions["removalsAttempted"] > actions["offersAttempted"]):
        return rejected("IMPOSSIBLE_ACTION_COUNTERS")
    if type(data.get("round")) is not int or not 1 <= data["round"] <= 8:
        return rejected("INVALID_CURRENT_ROUND")
    if type(data.get("requestEpochAttempts")) is not int or data["requestEpochAttempts"] != actions["requestsStarted"]:
        return rejected("EPOCH_COUNT_MISMATCH")
    if data.get("maxRounds") != 8 or data.get("eightTradeBatchAuthorized") is not True:
        return rejected("DIFFERENT_TEST_MODE")

    if data.get("status") == "CLIENT_TEST_SEQUENCE_COMPLETE":
        if (n != 8 or actions["requestsStarted"] != 8 or
                actions["clientClosedWindows"] != 8 or
                actions["offersAttempted"] != 10 or
                actions["offersClientVisible"] != 10 or
                actions["removalsAttempted"] != 10 or
                actions["declinesAttempted"] != 7 or
                data.get("reason") != "ALL_EIGHT_CLIENT_SCENARIOS_VERIFIED" or
                data["round"] != 8):
            return rejected("COMPLETED_BATCH_COUNTERS_INCONSISTENT")
        label = "EIGHT_CLIENT_WINDOWS_ONLY"
    elif data.get("status") == "STOPPED":
        if (n >= 8 or data["round"] != n + 1 or
                actions["requestsStarted"] != n + 1 or
                type(data.get("reason")) is not str or not data["reason"] or
                data.get("firstFailureScenario") != SCENARIOS[n] or
                data.get("phase") != "STOPPED"):
            return rejected("STOP_MISSING_FIRST_FAULT_OR_EPOCH")
        label = "CLIENT_SAFETY_STOP_ONLY"
    else:
        return rejected("NOT_TERMINAL_OR_UNREVIEWED")

    return {
        "schema": "gingerscope-system1-batch-evidence-check-v1",
        "status": label,
        "validatedPriorClientWindows": n,
        "firstFaultScenario": data.get("firstFailureScenario") if label == "CLIENT_SAFETY_STOP_ONLY" else None,
        "reason": "CLIENT_ONLY_NO_SERVER_SETTLEMENT",
        "serverCompletionProven": False,
        "mayAuthorizeTrading": False,
        "verifiedCompletedTrades": 0,
    }
