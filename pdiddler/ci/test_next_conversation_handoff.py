"""Handoff integrity and non-runtime scope regression; no live MM2 behavior."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
PLAN = "pdiddler/continuity/NEXT_WORKPLAN_2026_11_11.json"
HANDOFF = "pdiddler/NEXT_CONVERSATION_HANDOFF_2026_11_11.md"
CLEANUP = "pdiddler/continuity/LEGACY_CLEANUP_AUDIT_2026_11_11.md"
BASE = "f27002118363a544321bb7f0f1af00c2f2124d1a"
ALLOWED = {
    PLAN, HANDOFF, CLEANUP, "pdiddler/START_HERE.md",
    "pdiddler/continuity/README.md",
    "pdiddler/continuity/current_state.json",
    "pdiddler/continuity/manifest.json",
    "pdiddler/RELEASE_READINESS.json",
    "pdiddler/ci/test_next_conversation_handoff.py",
    ".github/workflows/gingerscope-next-conversation-handoff.yml",
}

def load(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))

def sha(path):
    content = (ROOT / path).read_bytes()
    return hashlib.sha1(b"blob " + str(len(content)).encode() + b"\0" + content).hexdigest()


class HandoffIntegrityTests(unittest.TestCase):
    def test_anchor_and_checkpoint_coherent(self):
        state = load("pdiddler/continuity/current_state.json")
        manifest = load("pdiddler/continuity/manifest.json")
        release = load("pdiddler/RELEASE_READINESS.json")
        plan = load(PLAN)
        self.assertEqual(state["sourceCommit"], BASE)
        self.assertEqual(manifest["baselineCommit"], BASE)
        self.assertEqual(release["checkpointSourceCommit"], BASE)
        self.assertEqual(plan["reviewedMainCommit"], BASE)
        self.assertEqual(state["latestMergedPR"], 233)
        self.assertEqual(plan["latestReviewedMergedPR"], 233)
        self.assertEqual(state["latestStage"], 121)
        self.assertEqual(plan["latestProvenStage"], 121)
        self.assertEqual(state["tradeOutcome"], "UNKNOWN")
        self.assertEqual(plan["historicalCoverage"], "PARTIAL_NOT_ALL_121_STAGES_INDIVIDUALLY_AUDITED")

    def test_index_and_handoff_are_immutable_source_pinned(self):
        manifest = load("pdiddler/continuity/manifest.json")
        for path in (PLAN, HANDOFF, CLEANUP, "pdiddler/START_HERE.md",
                     "pdiddler/continuity/README.md", "pdiddler/RELEASE_READINESS.json"):
            self.assertEqual(manifest["sourceBlobs"][path], sha(path), path)
        self.assertEqual(
            manifest["controlledBlobs"]["pdiddler/continuity/current_state.json"],
            sha("pdiddler/continuity/current_state.json")
        )

    def test_one_issue_next_then_ordered_backlog(self):
        plan = load(PLAN)
        self.assertEqual(plan["currentTask"], "P1")
        self.assertEqual(plan["executionPolicy"], "STRICTLY_SEQUENTIAL_ONE_DISTINCT_ISSUE_AT_A_TIME")
        phases = plan["phases"]
        self.assertEqual([p["id"] for p in phases], ["P1", "P2", "P3", "P4", "P5", "P6"])
        self.assertEqual(phases[0]["status"], "NEXT_RESEARCH_ONLY")
        self.assertEqual(phases[0]["changesAllowed"], "RESEARCH_ONLY_NO_TRADER")
        self.assertTrue(all(p["needs"] and p["deliverables"] and p["acceptance"] for p in phases))
        self.assertTrue(all(p["status"] != "COMPLETED" for p in phases))

    def test_growth_learning_and_action_denials(self):
        plan = load(PLAN)
        state = load("pdiddler/continuity/current_state.json")
        release = load("pdiddler/RELEASE_READINESS.json")
        growth = load("pdiddler/strategy/growth_policy.json")
        self.assertTrue(plan["noLiveScriptChangesAuthorized"])
        for key in ("tradeActionsAuthorized", "automaticAcceptAuthorized", "lossTradingAuthorized"):
            self.assertIs(plan[key], False)
        self.assertEqual(plan["learningEligibleVerifiedRealTradeRows"], 0)
        self.assertEqual(plan["privateArchiveAggregate"], {
            "total":50,"testExcluded":30,"unverifiedClaims":17,"quarantined":3
        })
        self.assertTrue(all(value is False for value in state["authority"].values()))
        for key in ("completeAutonomousSystemProven", "liveAutonomousTradingAuthorized",
                    "autoFinalAcceptAuthorized", "controlledListedValueLossAuthorized",
                    "independentSettlementProven"):
            self.assertIs(release[key], False)
        self.assertEqual(growth["riskBudget"]["approvalStatus"], "NOT_SPECIFIED_NOT_APPROVED")
        self.assertIs(growth["deploymentAuthorized"], False)
        self.assertIs(growth["autonomousLossTradesAuthorized"], False)

    def test_handoff_is_read_first_and_mentions_actual_limitations(self):
        text = (ROOT / HANDOFF).read_text(encoding="utf-8")
        compact = (ROOT / "pdiddler/START_HERE.md").read_text(encoding="utf-8")
        cleanup = (ROOT / CLEANUP).read_text(encoding="utf-8")
        self.assertIn(HANDOFF, compact)
        self.assertIn(PLAN, compact)
        self.assertIn("Stage111", text)
        for term in ("Gingerscope", "four", "learning", "Nov", "Part3/Part4", "UNKNOWN"):
            self.assertIn(term, text)
        self.assertIn("NON-DELETION", cleanup)
        self.assertIn("No branches deleted", cleanup)

    def test_change_scope_is_only_docs_and_ci_not_game_scripts(self):
        result = subprocess.run(
            ["git", "diff", "--name-only", "HEAD^1", "HEAD"],
            cwd=ROOT, capture_output=True, text=True, check=True,
        )
        paths = set(filter(None, result.stdout.splitlines()))
        self.assertTrue(paths, "Expected a reviewable PR diff")
        self.assertTrue(paths.issubset(ALLOWED), f"Unexpected / potentially live change: {paths - ALLOWED}")
        self.assertFalse(any(p.endswith((".lua", ".luau")) for p in paths))
        self.assertFalse(any(p.startswith("pdiddler/new_part4/") for p in paths))


if __name__ == "__main__":
    unittest.main()
