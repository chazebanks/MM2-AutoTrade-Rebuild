"""Actual archived 189-key source vs source reconciliation (not a live-market test)."""
from __future__ import annotations

import json
from pathlib import Path
import unittest

from pdiddler.system2.c9_historical_dual_list_reconciliation import (
    HistoricalReconciliationBlocked, checked_sources, git_blob_sha,
    reconcile, verify_reconciled, AGGREGATOR_GIT_BLOB, OFFICIAL_GIT_BLOB,
)

ROOT = Path(__file__).resolve().parents[2] / "pdiddler/system2"
ORIGINAL = (ROOT / "c9_research_public_189_crosswalk.json").read_bytes()
OFFICIAL = (ROOT / "c9_supreme_official_origin_mediated_189_2026_11_15.json").read_bytes()
HISTORICAL_NOW = "2026-11-15T20:19:53Z"


class HistoricalDualListReconciliation(unittest.TestCase):
    def compose(self, mm2=ORIGINAL, supreme=OFFICIAL, at=HISTORICAL_NOW):
        return reconcile(mm2, supreme, evaluated_utc=at)

    def test_immutable_original_github_blob_pins(self):
        self.assertEqual(git_blob_sha(ORIGINAL), AGGREGATOR_GIT_BLOB)
        self.assertEqual(git_blob_sha(OFFICIAL), OFFICIAL_GIT_BLOB)
        self.assertEqual(len(checked_sources(ORIGINAL, OFFICIAL)[0]["items"]), 189)

    def test_official_supreme_replaces_34_stale_aggregated_prices_only(self):
        report = self.compose()
        rows = {row["rawGameKeyCandidate"]: row for row in report["rows"]}
        self.assertEqual(report["legacyAggregatorSupremeConflictsReplaced"], 34)
        self.assertEqual(len(rows), 189)
        self.assertEqual(report["categories"], {"ancient": 15, "godly": 128, "chroma": 46})
        self.assertEqual(rows["Gingerscope"]["supremeOfficialOriginListedViaFirecrawl"], 16000)
        self.assertEqual(rows["Harvester"]["supremeOfficialOriginListedViaFirecrawl"], 275)
        self.assertEqual(rows["Harvester"]["legacyAggregatorSupremeColumnForAuditOnly"], 270)
        self.assertEqual(rows["Icepiercer"]["supremeOfficialOriginListedViaFirecrawl"], 185)
        self.assertEqual(rows["Immortal"]["supremeOfficialOriginListedViaFirecrawl"], 120)
        self.assertEqual(rows["EmberscytheChroma"]["supremeOfficialOriginListedViaFirecrawl"], 12000)
        self.assertEqual(rows["EmberscytheChroma"]["legacyAggregatorSupremeColumnForAuditOnly"], 13000)
        self.assertEqual(rows["FlowerwoodKnife"]["supremeOfficialOriginListedViaFirecrawl"], 235)
        self.assertIsNone(rows["FlowerwoodKnife"]["legacyAggregatorSupremeColumnForAuditOnly"])
        self.assertTrue(rows["FlowerwoodKnife"]["explicitReviewedFlowerwoodAlias"])
        self.assertTrue(rows["Gingerscope"]["outgoingGingerscopeProtected"])
        self.assertEqual(sum(row["outgoingGingerscopeProtected"] for row in rows.values()), 1)
        self.assertEqual(sum(row["legacySupremeDisagreesWithOfficial"] for row in rows.values()), 34)
        self.assertEqual(verify_reconciled(report, ORIGINAL, OFFICIAL)["status"],
                         "HISTORICAL_RECONCILIATION_AUDITED_NOT_LIVE")

    def test_mm2_aggregator_list_not_silently_replaced(self):
        report = self.compose()
        orig = {row["rawGameKeyCandidate"]: row for row in json.loads(ORIGINAL)["items"]}
        for row in report["rows"]:
            old = orig[row["rawGameKeyCandidate"]]
            with self.subTest(key=row["rawGameKeyCandidate"]):
                self.assertEqual(row["mm2ListedViaAggregator"], old["mm2Listed"])
                self.assertEqual(row["aggregatorDemandOrdinal"], old["demandOrdinal"])
                self.assertEqual(row["aggregatorStabilityLabel"], old["stabilityLabel"])
                self.assertIs(row["rawGameItemInstanceAuthenticated"], False)
                self.assertIs(row["measuredTradeLiquidity"], False)

    def test_two_lists_have_separate_descriptive_demand_and_stability(self):
        report = self.compose()
        original = {r["rawGameKeyCandidate"]: r for r in json.loads(ORIGINAL)["items"]}
        supreme = {r["rawGameKeyCandidate"]: r for r in json.loads(OFFICIAL)["rows"]}
        for row in report["rows"]:
            key = row["rawGameKeyCandidate"]
            self.assertEqual(row["supremeDemandOrdinal"], supreme[key]["officialDemand"])
            self.assertEqual(row["supremeStabilityLabel"], supreme[key]["officialStability"])
            self.assertEqual(row["aggregatorDemandOrdinal"], original[key]["demandOrdinal"])
        self.assertFalse(report["bothSourcesIndependentlyPublisherAuthenticated"])
        self.assertFalse(report["safeForLivePricing"])
        self.assertFalse(report["safeForAutonomousTrade"])
        self.assertFalse(report["authorizesTrade"])
        self.assertFalse(report["authorizesAccept"])
        self.assertFalse(report["mayUseForStrategyLearning"])
        self.assertFalse(report["currentMarketFreshnessProven"])
        self.assertIn("NOT independently", report["mm2ListedProvenance"])
        self.assertIn("NOT publisher-signed", report["supremeListedProvenance"])

    def test_current_time_after_six_hours_fails_closed(self):
        for at in ["2026-11-16T03:00:00Z", "2026-11-15T19:00:00Z"]:
            with self.subTest(at=at), self.assertRaises(HistoricalReconciliationBlocked):
                self.compose(at=at)

    def test_legacy_aggregator_source_mutation_denied(self):
        data = json.loads(ORIGINAL)
        data["items"][0]["mm2Listed"] += 1
        edited = json.dumps(data, sort_keys=True).encode()
        with self.assertRaisesRegex(HistoricalReconciliationBlocked, "AGGREGATOR_GIT_BLOB_CHANGED"):
            self.compose(mm2=edited)

    def test_official_source_mutation_denied_even_if_internal_diffs_match(self):
        data = json.loads(OFFICIAL)
        data["rows"][0]["officialSupremeListed"] += 1
        edited = json.dumps(data, sort_keys=True).encode()
        with self.assertRaisesRegex(HistoricalReconciliationBlocked, "SUPREME_GIT_BLOB_CHANGED"):
            self.compose(supreme=edited)

    def test_archived_output_changing_one_price_is_rejected(self):
        report = self.compose()
        report["rows"][0]["supremeOfficialOriginListedViaFirecrawl"] += 1
        with self.assertRaisesRegex(HistoricalReconciliationBlocked, "DATA_OR_PROVENANCE_TAMPERED"):
            verify_reconciled(report, ORIGINAL, OFFICIAL)

    def test_archived_output_laundering_current_trading_is_rejected(self):
        for key, val in [("safeForLivePricing", True), ("authorizesOffer", True),
                         ("mayUseForStrategyLearning", True), ("authorizesAccept", True)]:
            report = self.compose()
            report[key] = val
            with self.subTest(key=key), self.assertRaisesRegex(HistoricalReconciliationBlocked,
                                                                "OUTPUT_UNSAFE_OR_INVALID"):
                verify_reconciled(report, ORIGINAL, OFFICIAL)

    def test_cannot_restamp_historical_receipt_to_current(self):
        report = self.compose()
        report["historicalEvaluationUtc"] = "2026-11-16T03:00:00Z"
        with self.assertRaises(HistoricalReconciliationBlocked):
            verify_reconciled(report, ORIGINAL, OFFICIAL)

    def test_no_private_session_data_or_fake_settlement(self):
        report = self.compose()
        serialized = json.dumps(report, sort_keys=True)
        for key in ["playerUserId", "partnerUserId", "jobId", "leaseId",
                    "webhookUrl", "ownedInventory", "playerUsername", "sessionToken"]:
            self.assertNotIn(key, serialized)
        self.assertIs(report["serverTradeSettlementVerified"], False)
        self.assertIs(report["mayReportProfit"], False)


if __name__ == "__main__":
    unittest.main()
