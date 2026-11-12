"""P1 MM2 Index: synthetic, offline schema/coverage/freshness regressions."""
from __future__ import annotations
from copy import deepcopy
from datetime import datetime, timezone
import json
from pathlib import Path
import tempfile
import unittest

from pdiddler.ci import p1_mm2index_research_audit as a


OBSERVED = "2026-11-11T23:59:00Z"
UPDATED = "2026-10-12T00:42:14.608268+00:00"
WORKFLOW = Path(__file__).resolve().parents[2] / ".github/workflows/gingerscope-p1-canonical-archive-research.yml"


def fixture(updated=UPDATED):
    rows = [
        dict(key="gingerscope", name="Gingerscope", slug="gingerscope", value=15475, tier="Ancient",
             confidence="high", observations=862, derivation="chain+quote", chroma=False, set=False),
        dict(key="harvester", name="Harvester", slug="harvester", value=255, tier="Ancient",
             confidence="high", observations=130, derivation="chain", chroma=False, set=False),
        dict(key="icebreaker", name="Icebreaker", slug="icebreaker", value=71, tier="Godly",
             confidence="medium", observations=32, derivation="quote", chroma=False, set=False),
        dict(key="chroma:fang", name="Chroma Fang", slug="chroma-fang", value=33, tier="Chroma",
             confidence="medium", observations=33, derivation="chain", chroma=True, set=False),
        dict(key="chroma:winter_set", name="Chroma Winter Set", slug="chroma-winter-set", value=85,
             tier="Chroma", confidence="medium", observations=11, derivation="chain", chroma=True, set=True),
        dict(key="mystery_unknown", name="Mystery Unknown", slug="mystery-unknown", value=10,
             tier="Unranked", confidence="low", observations=3, derivation="bundle",
             chroma=False, set=False),
    ]
    return {
        "meta": {
            "source": "MM2 Index", "url": "https://mm2index.com",
            "game": "Murder Mystery 2", "unit": "MM2 value units",
            "updated": updated, "count": len(rows), "withheld": 421,
            "license": "CC BY 4.0 — attribution to mm2index.com appreciated",
            "method": "https://mm2index.com/methodology",
        }, "items": rows,
    }


class MM2IndexResearchAuditTests(unittest.TestCase):
    def audit(self, obj=None, observed=OBSERVED):
        return a.audit(fixture() if obj is None else obj, observed_utc=observed)

    def assert_blocked(self, result):
        self.assertFalse(result["mayAdvanceP2"])
        self.assertFalse(result["observedTradesIndependentlyProvenSettled"])
        self.assertFalse(result["providerValuesComparableToSupremeWithoutCalibration"])
        self.assertFalse(result["target"]["gameRawWeaponKeyVerified"])
        self.assertEqual(result["tradeOutcome"], "UNKNOWN")
        self.assertTrue(all(result[k] is False for k in a.DENIED))

    def test_stale_dataset_never_becomes_current_market(self):
        x = self.audit()
        self.assertEqual(x["status"], "BLOCKED_STALE_PROVIDER")
        self.assertEqual(x["reason"], "PROVIDER_SNAPSHOT_EXPIRED_FOR_RESEARCH")
        self.assertGreater(x["ageDays"], 30)
        self.assert_blocked(x)

    def test_fresh_dataset_still_research_only(self):
        x = self.audit(fixture(updated="2026-11-11T00:00:00+00:00"))
        self.assertEqual(x["status"], "RESEARCH_ONLY_NOT_LIVE")
        self.assert_blocked(x)

    def test_gscope_protected_and_post_observations_not_verified_fills(self):
        x = self.audit()
        self.assertEqual(x["target"]["providerKey"], "gingerscope")
        self.assertEqual(x["target"]["observationsFromPostsNotVerifiedFills"], 862)
        self.assertEqual(x["target"]["providerValue"], 15475)
        self.assert_blocked(x)

    def test_only_individual_ancient_godly_chroma_counted(self):
        x = self.audit()
        self.assertEqual(x["tierCountsPublishedOnly"]["Chroma"], 2)
        self.assertEqual(x["individualTradableTierCountsPublishedOnly"],
                         {"Ancient": 2, "Chroma": 1, "Godly": 1})
        self.assertEqual(x["publishedChromaSetsExcludedFromIndividualWeapons"], 1)
        self.assertTrue(x["withheldTierBreakdownUnknown"])
        self.assertEqual(x["totalWithheldUnknownTier"], 421)
        self.assertEqual(x["individualTradableTierConfidenceCountsPublishedOnly"],
                         {"high": 2, "medium": 2})

    def test_duplicate_key_or_slug_rejected(self):
        x = fixture()
        x["items"][1]["key"] = "gingerscope"
        with self.assertRaisesRegex(a.SourceAuditError, "DUPLICATE"):
            self.audit(x)
        x = fixture()
        x["items"][1]["slug"] = "gingerscope"
        with self.assertRaisesRegex(a.SourceAuditError, "DUPLICATE"):
            self.audit(x)

    def test_false_chroma_tag_and_set_tier_conflicts_rejected(self):
        x = fixture()
        x["items"][3]["chroma"] = False
        with self.assertRaisesRegex(a.SourceAuditError, "CHROMA_TIER_CONFLICT"):
            self.audit(x)
        x = fixture()
        x["items"][5]["tier"] = "Set"
        with self.assertRaisesRegex(a.SourceAuditError, "SET_TIER_CONFLICT"):
            self.audit(x)

    def test_no_unranked_item_auto_upcast_to_godly(self):
        x = self.audit()
        self.assertEqual(x["tierCountsPublishedOnly"]["Unranked"], 1)
        self.assertEqual(sum(x["individualTradableTierCountsPublishedOnly"].values()), 4)
        self.assert_blocked(x)

    def test_bad_license_or_provider_rejected(self):
        x = fixture()
        x["meta"]["license"] = "All rights reserved"
        with self.assertRaisesRegex(a.SourceAuditError, "LICENSE"):
            self.audit(x)
        x = fixture()
        x["meta"]["source"] = "Supreme Values"
        with self.assertRaisesRegex(a.SourceAuditError, "PROVIDER_IDENTITY"):
            self.audit(x)

    def test_future_clock_or_missing_tz_rejected(self):
        x = fixture(updated="2026-11-12T00:00:00+00:00")
        with self.assertRaisesRegex(a.SourceAuditError, "FUTURE"):
            self.audit(x)
        x = fixture(updated="2026-10-12T00:42:14")
        with self.assertRaisesRegex(a.SourceAuditError, "PUBLISHER_CLOCK_INVALID"):
            self.audit(x)

    def test_invalid_values_and_duplicate_count_rejected(self):
        for bad in (0, -1, True, "33", float("inf"), float("nan")):
            x = fixture()
            x["items"][2]["value"] = bad
            with self.subTest(bad=str(bad)):
                with self.assertRaisesRegex(a.SourceAuditError, "VALUE_INVALID"):
                    self.audit(x)
        x = fixture()
        x["meta"]["count"] = 99
        with self.assertRaisesRegex(a.SourceAuditError, "COUNT_MISMATCH"):
            self.audit(x)

    def test_missing_target_or_spoofed_tier_rejected(self):
        x = fixture()
        x["items"][0]["key"] = "not-gingerscope"
        with self.assertRaisesRegex(a.SourceAuditError, "TARGET_NOT_PUBLISHED"):
            self.audit(x)
        x = fixture()
        x["items"][0]["tier"] = "Godly"
        with self.assertRaisesRegex(a.SourceAuditError, "TARGET_ITEM_IDENTITY_INCONCLUSIVE"):
            self.audit(x)

    def test_invalid_observation_count_and_confidence(self):
        x = fixture()
        x["items"][0]["observations"] = True
        with self.assertRaisesRegex(a.SourceAuditError, "OBSERVATION_COUNT_INVALID"):
            self.audit(x)
        x = fixture()
        x["items"][0]["confidence"] = "certain"
        with self.assertRaisesRegex(a.SourceAuditError, "CONFIDENCE_INVALID"):
            self.audit(x)

    def test_offline_cli_rejects_invalid_source_without_elevating_permissions(self):
        with tempfile.TemporaryDirectory() as temp:
            source, dest = Path(temp) / "in.json", Path(temp) / "out.json"
            bad = fixture()
            bad["meta"]["license"] = "UNKNOWN"
            source.write_text(json.dumps(bad))
            self.assertEqual(a.main(["--input", str(source), "--output", str(dest)]), 2)
            saved = json.loads(dest.read_text())
            self.assertEqual(saved["status"], "BLOCKED_INVALID_SOURCE")
            self.assertTrue(all(saved[k] is False for k in a.DENIED))

    def test_cli_valid_stale_source_returns_blocked_research_receipt(self):
        with tempfile.TemporaryDirectory() as temp:
            source, dest = Path(temp) / "in.json", Path(temp) / "out.json"
            source.write_text(json.dumps(fixture()))
            self.assertEqual(a.main(["--input", str(source), "--output", str(dest)]), 0)
            saved = json.loads(dest.read_text())
            self.assertEqual(saved["status"], "BLOCKED_STALE_PROVIDER")
            self.assertTrue(all(saved[k] is False for k in a.DENIED))

    def test_active_workflow_tests_p1_auditor_without_market_network(self):
        yml = WORKFLOW.read_text(encoding="utf-8")
        self.assertIn("pdiddler.ci.test_p1_mm2index_research_audit", yml)
        self.assertNotIn("https://mm2index.com/api/values.json", yml)
        self.assertNotIn("curl ", yml)
        self.assertNotIn("requests.get", yml)
        self.assertNotIn("stage111_supreme_readonly_capture --parser", yml)


if __name__ == "__main__":
    unittest.main()
