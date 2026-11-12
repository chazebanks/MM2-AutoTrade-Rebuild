"""Negative coverage of System1 client-only evidence classifier, no secrets."""
import copy
import unittest
from pdiddler.system1.system1_batch_receipt_grader import (
    SCHEMA, SCENARIOS, classify_receipt,
)

def successful_receipt():
    return {
        "schema": SCHEMA, "status": "CLIENT_TEST_SEQUENCE_COMPLETE",
        "reason": "ALL_EIGHT_CLIENT_SCENARIOS_VERIFIED",
        "round": 8, "phase": "DONE", "maxRounds": 8,
        "eightTradeBatchAuthorized": True,
        "completedRounds": 8, "requestEpochAttempts": 8,
        "authorizesAccept": False, "serverCompletionProven": False,
        "mayReportProfit": False, "maySendDiscordWebhook": False,
        "mayUseForStrategyLearning": False, "tradeOutcome": "UNKNOWN",
        "finalAcceptEverAttempted": False, "verifiedCompletedTrades": 0,
        "actions": {
            "requestsStarted": 8, "offersAttempted": 10,
            "offersClientVisible": 10, "removalsAttempted": 10,
            "declinesAttempted": 7, "clientClosedWindows": 8,
        },
        "rounds": [
            {"round": i + 1, "scenarioId": case,
             "status": "CLIENT_SEQUENCE_PASS", "clientWindowClosed": True}
            for i,case in enumerate(SCENARIOS)
        ],
    }

class System1ReceiptVerifierTests(unittest.TestCase):
    def test_valid_full_client_batch_is_not_settlement(self):
        graded = classify_receipt(successful_receipt())
        self.assertEqual(graded["status"], "EIGHT_CLIENT_WINDOWS_ONLY")
        self.assertFalse(graded["mayAuthorizeTrading"])
        self.assertEqual(graded["verifiedCompletedTrades"], 0)

    def test_valid_first_fault_keeps_only_prior_client_windows(self):
        data = successful_receipt()
        data.update(status="STOPPED", reason="ALT_ADDED_UNEXPECTED_EXTRA_SLOTS",
                    round=6, phase="STOPPED", completedRounds=5,
                    requestEpochAttempts=6,
                    firstFailureScenario=SCENARIOS[5])
        data["rounds"] = data["rounds"][:5]
        data["actions"].update(requestsStarted=6, offersAttempted=8,
                               offersClientVisible=4, removalsAttempted=4,
                               declinesAttempted=5, clientClosedWindows=5)
        graded = classify_receipt(data)
        self.assertEqual(graded["status"], "CLIENT_SAFETY_STOP_ONLY")
        self.assertEqual(graded["validatedPriorClientWindows"], 5)
        self.assertEqual(graded["firstFaultScenario"], SCENARIOS[5])
        self.assertEqual(graded["verifiedCompletedTrades"], 0)

    def test_mutated_authority_flags_never_pass(self):
        original = successful_receipt()
        for flag in ("authorizesAccept", "serverCompletionProven", "mayReportProfit",
                     "maySendDiscordWebhook", "mayUseForStrategyLearning"):
            with self.subTest(flag=flag):
                test = copy.deepcopy(original)
                test[flag] = True
                self.assertEqual(classify_receipt(test)["status"], "REJECTED")

    def test_no_fake_completed_trades_or_accept(self):
        for key, value in (("verifiedCompletedTrades", 1),
                           ("finalAcceptEverAttempted", True),
                           ("tradeOutcome", "COMPLETED")):
            with self.subTest(key=key):
                test = successful_receipt()
                test[key] = value
                self.assertEqual(classify_receipt(test)["status"], "REJECTED")

    def test_rejects_ledger_counter_and_case_spoof(self):
        for modifier in (
            lambda d: d["rounds"].__setitem__(0, d["rounds"][1]),
            lambda d: d["rounds"][0].update(clientWindowClosed=False),
            lambda d: d["actions"].update(requestsStarted=9),
            lambda d: d["actions"].update(clientClosedWindows=7),
            lambda d: d["actions"].update(offersClientVisible=11),
            lambda d: d["actions"].update(removalsAttempted=11),
            lambda d: d.update(completedRounds=7),
            lambda d: d.update(reason="ALL_FIVE_CLIENT_ROUNDS_VERIFIED"),
            lambda d: d.update(eightTradeBatchAuthorized=False),
            lambda d: d.update(status="RUNNING"),
        ):
            test = successful_receipt()
            modifier(test)
            self.assertEqual(classify_receipt(test)["status"], "REJECTED")

    def test_wrong_types_and_extra_rounds_fail(self):
        for data in (None, [], {"schema": SCHEMA},
                     dict(successful_receipt(), rounds="8"),
                     dict(successful_receipt(), rounds=[{}] * 9)):
            with self.subTest(data=str(type(data))):
                self.assertEqual(classify_receipt(data)["status"], "REJECTED")

    def test_no_legacy_other_mode_promotion(self):
        data = successful_receipt()
        data["maxRounds"] = 5
        self.assertEqual(classify_receipt(data)["status"], "REJECTED")

if __name__ == "__main__":
    unittest.main()
