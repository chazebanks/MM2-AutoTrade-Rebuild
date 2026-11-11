"""Release gate protects against mistaken autonomy claims after research milestones."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]

def get(relative):
    return json.loads((ROOT / relative).read_text())

def blob(path):
    contents=path.read_bytes()
    return hashlib.sha1(b"blob "+str(len(contents)).encode()+b"\0"+contents).hexdigest()

class ReleaseReadinessTests(unittest.TestCase):
    def test_no_global_autonomy_claim_from_partial_steps(self):
        p=get("pdiddler/RELEASE_READINESS.json")
        self.assertGreaterEqual(len(p["requiredGates"]),9)
        for flag in ("completeAutonomousSystemProven","liveAutonomousTradingAuthorized",
                     "autoFinalAcceptAuthorized","controlledListedValueLossAuthorized",
                     "independentSettlementProven","approvedNumericRiskBudget",
                     "verifiedRealWorldAcceptanceModel"):
            self.assertIs(p[flag],False,flag)
        self.assertEqual(p["permanentlyProtectedOutboundItem"],"Gingerscope")
        self.assertFalse(any(g["status"]=="VERIFIED_END_TO_END" for g in p["requiredGates"]))

    def test_current_state_is_fresh_and_still_denies_authority(self):
        p=get("pdiddler/RELEASE_READINESS.json")
        state=get("pdiddler/continuity/current_state.json")
        manifest=get("pdiddler/continuity/manifest.json")
        self.assertGreaterEqual(state["latestMergedPR"], 232)
        milestones=state.get("integratedDevelopmentMilestones", [])
        reviewed=[entry["pr"] for entry in milestones]
        self.assertTrue(reviewed)
        self.assertEqual(reviewed, sorted(set(reviewed)))
        self.assertEqual(state["latestMergedPR"], reviewed[-1])
        self.assertEqual(state["sourceCommit"],p["checkpointSourceCommit"])
        self.assertEqual(manifest["baselineCommit"],state["sourceCommit"])
        self.assertEqual(state["tradeOutcome"],"UNKNOWN")
        self.assertFalse(any(state["authority"].values()))

    def test_growth_policy_cannot_be_silently_changed(self):
        growth=get("pdiddler/strategy/growth_policy.json")
        manifest=get("pdiddler/continuity/manifest.json")
        path="pdiddler/strategy/growth_policy.json"
        self.assertEqual(manifest["sourceBlobs"][path],blob(ROOT/path))
        self.assertFalse(growth["deploymentAuthorized"])
        self.assertFalse(growth["autonomousLossTradesAuthorized"])
        self.assertEqual(growth["riskBudget"]["approvalStatus"],"NOT_SPECIFIED_NOT_APPROVED")

    def test_release_checkpoint_is_source_pinned(self):
        manifest=get("pdiddler/continuity/manifest.json")
        for path in ("pdiddler/RELEASE_READINESS.json",
                     "pdiddler/START_HERE.md",
                     "pdiddler/strategy/GROWTH_POLICY_DECISION_2026_11_11.md"):
            self.assertEqual(manifest["sourceBlobs"][path],blob(ROOT/path))

if __name__=="__main__":
    unittest.main()
