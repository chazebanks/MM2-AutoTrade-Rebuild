"""Fail-closed archival policy tests; no game code or trading side effects."""
import json
import unittest
from pathlib import Path

P = Path(__file__).resolve().parents[1] / "strategy" / "growth_policy.json"

class ControlledLossPolicyTest(unittest.TestCase):
    def test_policy_is_decision_only(self):
        data = json.loads(P.read_text())
        self.assertEqual(data["decisionType"], "LONG_TERM_STRATEGY_DIRECTION_ONLY")
        self.assertTrue(data["developmentPermitted"])
        for key in ("deploymentAuthorized","autonomousLossTradesAuthorized"):
            self.assertIs(data[key], False)
        for key in ("separateExplicitDeploymentAuthorizationRequired",
                    "independentlyVerifiedEvidenceRequired","validatedRiskBudgetRequired"):
            self.assertIs(data[key], True)

    def test_no_implicitly_approved_budget(self):
        data = json.loads(P.read_text())
        budget = data["riskBudget"]
        self.assertEqual(budget["approvalStatus"], "NOT_SPECIFIED_NOT_APPROVED")
        for key in ("maxLossPerTrade","maxCumulativeLoss","maxLossFractionPerTrade","maximumFrequency"):
            self.assertIsNone(budget[key])

    def test_critical_safety_topics_are_not_dropped(self):
        data = json.loads(P.read_text())
        denials = " ".join(data["neverAuthorizedByThisDecision"]).lower()
        for term in ("live","accept","gingerscope","discord","+15","highest"):
            self.assertIn(term, denials)
        joined = " ".join(data["requiredEvidence"]).lower()
        for term in ("identity","publisher","liquidity","supervised","authorization"):
            self.assertIn(term, joined)

if __name__ == "__main__":
    unittest.main()
