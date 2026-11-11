"""Test research loss sensitivity without authorizing MM2 gameplay."""
import json
import unittest

from pdiddler.intelligence_lab.quality_loss_sensitivity import (
    CAPS_BPS, FLAGS, audit_learning_claim, break_even_exit_probability,
    repeated_loss_retention, study_candidate,
)

class LossSensitivityTests(unittest.TestCase):
    def setUp(self):
        self.market = {"Emberbow":650, "Immortal":125, "Snowcannon":750, "Gingerscope":16000}
        self.out = [{"key":"Emberbow","quantity":1},{"key":"Immortal","quantity":1}]
        self.inc = [{"key":"Snowcannon","quantity":1}]

    def test_illustrative_25_unit_loss_exceeds_even_3percent_cap(self):
        result=study_candidate(self.out,self.inc,self.market)
        self.assertEqual(result["status"],"SIMULATED")
        self.assertEqual(result["listedLoss"],25)
        self.assertEqual(result["listedLossBasisPointsExact"],"250000/775")
        self.assertEqual([r["capBasisPoints"] for r in result["capScenarios"]],list(CAPS_BPS))
        self.assertFalse(any(r["withinHypotheticalCap"] for r in result["capScenarios"]))
        self.assertIsNone(result["approvedRiskBudget"])

    def test_one_percent_and_three_percent_compound(self):
        self.assertEqual(repeated_loss_retention(100,10),"0.90438207500880449001")
        self.assertEqual(repeated_loss_retention(300,10),"0.73742412689492826049")
        for bps in (-1,10000,True):
            with self.assertRaises(ValueError): repeated_loss_retention(bps,10)

    def test_different_physical_slots_from_stack_copies(self):
        value={"testStack":50,"testReceive":350}
        r=study_candidate([{"key":"testStack","quantity":7}],
                          [{"key":"testReceive","quantity":1}],value)
        self.assertEqual(r["status"],"SIMULATED")
        self.assertEqual(r["outgoingListedValue"],350)
        self.assertEqual(r["listedLoss"],0)
        many=[{"key":"testStack","quantity":1}]*5
        self.assertEqual(study_candidate(many,self.inc,{**value,**self.market})["status"],"BLOCKED")

    def test_gingerscope_cannot_be_outbound(self):
        r=study_candidate([{"key":"Gingerscope","quantity":1}],self.inc,self.market)
        self.assertEqual(r["status"],"BLOCKED")
        self.assertFalse(r["authorizesTrade"])

    def test_reject_malformed_or_unverified_value_inputs(self):
        bads=([{"key":"Emberbow","quantity":True}],
              [{"key":"Emberbow","quantity":0}],
              [{"key":"Unknown","quantity":1}],
              [{"key":"Emberbow","quantity":-1}])
        for offer in bads:
            self.assertEqual(study_candidate(offer,self.inc,self.market)["status"],"BLOCKED")
        self.assertEqual(study_candidate(self.out,self.inc,{"Emberbow":650, "Immortal":125})["status"],"BLOCKED")

    def test_toy_exit_probability_does_not_claim_trading_odds(self):
        r=break_even_exit_probability(775,750,800)
        self.assertEqual(r["requiredHighExitProbability"],"0.5")
        self.assertIsNone(r["estimatedActualHighExitProbability"])
        self.assertEqual(r["observedCompletedTradeSampleSize"],0)
        self.assertEqual(break_even_exit_probability(900,750,800)["feasibility"],"IMPOSSIBLE_IN_TWO_EXIT_MODEL")
        self.assertEqual(break_even_exit_probability(700,750,800)["feasibility"],"BREAK_EVEN_EVEN_AT_LOW_EXIT")

    def test_learning_status_claim_is_not_a_training_label(self):
        for status in ("UNKNOWN","CANCELED","DECLINED","COMPLETED"):
            r=audit_learning_claim(status,True)
            self.assertEqual(r["status"],"QUARANTINED")
            self.assertIsNone(r["approvedTrainingLabel"])
            self.assertFalse(r["mayUseForStrategyLearning"])

    def test_malformed_learning_outcome_fails_closed(self):
        for malformed in (None, False, [], {}, 4):
            result=audit_learning_claim(malformed, True)
            self.assertEqual(result["status"], "BLOCKED")
            self.assertFalse(result["mayUseForStrategyLearning"])

    def test_no_simulation_ever_authorizes_trade(self):
        r=study_candidate(self.out,self.inc,self.market)
        for key in ("authorizesTrade","authorizesOffer","authorizesAccept",
                    "marketQuoteAuthenticated","itemIdentityAuthenticated",
                    "liquidityVerified","acceptanceProbabilityVerified",
                    "mayUseForStrategyLearning","mayReportProfit"):
            self.assertIs(r[key],False)
        self.assertEqual(r["tradeOutcome"],"UNKNOWN")

if __name__=="__main__":
    unittest.main()
