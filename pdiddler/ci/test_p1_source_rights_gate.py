"""Offline regression tests: P1 cannot silently resume restricted source capture."""
from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest

from pdiddler.ci import p1_source_rights_gate as gate


REPO = Path(__file__).resolve().parents[2]
WORKFLOW = REPO / ".github" / "workflows" / "gingerscope-p1-canonical-archive-research.yml"


class SourceRightsGateTests(unittest.TestCase):
    def test_explicit_block_and_no_unverified_permission(self):
        result = gate.receipt("2026-11-11T23:59:00Z")
        self.assertEqual(result["status"], "BLOCKED")
        self.assertEqual(result["reason"], "NO_VERIFIED_SOURCE_DATA_REUSE_PERMISSION")
        self.assertFalse(result["permissionEvidenceVerified"])
        self.assertFalse(result["independentPublisherRevisionVerified"])
        self.assertIsNone(result["publisherUpdatedUtc"])

    def test_all_trade_market_learning_and_source_authorities_false(self):
        result = gate.receipt("2026-11-11T23:59:00Z")
        self.assertGreaterEqual(len(gate.DENIED), 15)
        for key in gate.DENIED:
            with self.subTest(key=key):
                self.assertIs(result[key], False)
        self.assertEqual(result["tradeOutcome"], "UNKNOWN")

    def test_source_site_and_research_diagnostics_are_not_mislabeled(self):
        result = gate.receipt()
        self.assertEqual(result["source"], "https://supremevalues.com/tos")
        self.assertIn("SUSPENDED", result["historicalSourceCollectorStatus"])
        self.assertIn("unverified", result["alternative"].lower())
        self.assertNotIn("GRANTED", result["requestRequired"])

    def test_output_remains_plain_json_with_false_flags(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "receipt.json"
            self.assertEqual(gate.main(["--output", str(path)]), 0)
            result = json.loads(path.read_text())
            self.assertEqual(result["status"], "BLOCKED")
            self.assertTrue(all(result[k] is False for k in gate.DENIED))

    def test_workflow_does_not_execute_original_collector_or_transport_probe(self):
        content = WORKFLOW.read_text(encoding="utf-8")
        self.assertNotIn("stage111_supreme_readonly_capture --parser", content)
        self.assertNotIn("p1_supreme_transport_probe --output", content)
        self.assertNotIn("requests.Session(", content)
        self.assertNotIn("source_ancient.html", content)
        self.assertNotIn("supremevalues.com/mm2/ancients", content)

    def test_workflow_runs_local_only_and_has_no_source_download_steps(self):
        content = WORKFLOW.read_text(encoding="utf-8")
        self.assertIn("python3 -m pdiddler.ci.p1_source_rights_gate", content)
        self.assertIn("python3 -m pdiddler.continuity.manager verify", content)
        self.assertIn("permissions:\n  contents: read", content)
        self.assertNotIn("curl ", content)
        self.assertNotIn("pip install requests", content)
        self.assertNotIn("on:\n  push:", content)

    def test_no_public_secret_or_allow_switch(self):
        content = WORKFLOW.read_text(encoding="utf-8")
        self.assertNotIn("secrets.", content)
        self.assertNotIn("SUPREME_API_KEY", content)
        self.assertNotIn("permission_override", content)
        self.assertFalse(hasattr(gate, "grant_permission"))

    def test_diagnostic_does_not_turn_403_into_authority(self):
        from pdiddler.ci.p1_supreme_transport_probe import _status_reason
        self.assertEqual(_status_reason(403), "HTTP_ACCESS_RESTRICTED_403")
        self.assertFalse(gate.receipt()["sourceCaptureAuthorized"])


    # These are synthetic metadata inputs resembling public candidates; they
    # are NEVER permissions, fresh quotations, or a real source-data import.
    @staticmethod
    def candidate(**changes):
        obj = {
            "provider": "synthetic-independent",
            "declaredRights": "CC_BY_4_DECLARED",
            "upstreamProvenance": "INDEPENDENT_CLAIM",
            "timestampMeaning": "PUBLISHER_TIMESTAMP",
            "publisherUpdatedUtc": "2026-11-11T20:00:00Z",
            "identityEvidence": "EXACT_GAME_RAW_KEY_CLAIM",
        }
        obj.update(changes)
        return obj

    def screen(self, **changes):
        return gate.screen_public_candidate(
            self.candidate(**changes), observed_utc="2026-11-11T23:59:00Z")

    def assert_all_authorities_denied(self, result):
        self.assertFalse(result["permissionEvidenceVerified"])
        self.assertFalse(result["providerIndependentProvenanceVerified"])
        self.assertFalse(result["serverSettledTradeEvidenceVerified"])
        self.assertFalse(result["mayAdvanceP2"])
        self.assertEqual(result["tradeOutcome"], "UNKNOWN")
        self.assertTrue(all(result[k] is False for k in gate.DENIED))

    def test_research_candidate_even_with_all_claims_stays_unapproved(self):
        res = self.screen()
        self.assertEqual(res["status"], "RESEARCH_REVIEW_ONLY")
        self.assertEqual(res["blockers"], [])
        self.assert_all_authorities_denied(res)

    def test_explicit_restricted_publisher_is_blocked(self):
        res = self.screen(declaredRights="RESTRICTED")
        self.assertIn("PUBLISHER_RESTRICTS_REUSE", res["blockers"])
        self.assert_all_authorities_denied(res)

    def test_derivative_site_current_display_date_does_not_qualify(self):
        res = self.screen(
            provider="synthetic-derivative-calculator",
            declaredRights="UNKNOWN",
            upstreamProvenance="SUPREME_DERIVED",
            timestampMeaning="DISPLAY_DATE_ONLY",
            publisherUpdatedUtc=None,
            identityEvidence="UNKNOWN")
        self.assertIn("SUPREME_DERIVED_SOURCE_REUSE_NOT_CLEARED", res["blockers"])
        self.assertIn("PUBLISHER_CLOCK_NOT_PROVEN", res["blockers"])
        self.assertIsNone(res["publisherAgeDaysIfProven"])
        self.assert_all_authorities_denied(res)

    def test_api_access_is_not_permission_to_republish_upstream(self):
        res = self.screen(
            declaredRights="API_ACCESS_ONLY", upstreamProvenance="MIXED_DERIVED",
            timestampMeaning="AGGREGATOR_REFRESH",
            identityEvidence="UNKNOWN")
        self.assertIn("UPSTREAM_DATA_REUSE_RIGHTS_NOT_PROVEN", res["blockers"])
        self.assertIn("SUPREME_DERIVED_SOURCE_REUSE_NOT_CLEARED", res["blockers"])
        self.assertIn("PUBLISHER_CLOCK_NOT_PROVEN", res["blockers"])
        self.assert_all_authorities_denied(res)

    def test_declared_cc_by_but_october_version_is_stale(self):
        res = self.screen(
            provider="synthetic-independent-CC-BY",
            publisherUpdatedUtc="2026-10-12T00:42:14Z", identityEvidence="UNKNOWN")
        self.assertIn("RESEARCH_DATA_STALE", res["blockers"])
        self.assertGreater(res["publisherAgeDaysIfProven"], 30)
        self.assert_all_authorities_denied(res)

    def test_same_item_canonical_key_collision_forces_rejection(self):
        res = self.screen(
            provider="synthetic-web-value-list",
            declaredRights="UNKNOWN", identityEvidence="AMBIGUOUS_COLLISION")
        self.assertIn("ITEM_IDENTITY_COLLISION", res["blockers"])
        self.assert_all_authorities_denied(res)

    def test_provider_with_unknown_original_source_never_qualifies(self):
        res = self.screen(
            declaredRights="UNKNOWN", upstreamProvenance="UNKNOWN",
            timestampMeaning="DISPLAY_DATE_ONLY", publisherUpdatedUtc="2026-11-12")
        self.assertIn("REUSE_RIGHTS_NOT_DECLARED", res["blockers"])
        self.assertIn("ORIGINAL_SOURCE_PROVENANCE_UNKNOWN", res["blockers"])
        self.assertIn("PUBLISHER_CLOCK_NOT_PROVEN", res["blockers"])
        self.assert_all_authorities_denied(res)

    def test_future_or_malformed_publisher_time_rejected(self):
        future = self.screen(publisherUpdatedUtc="2026-11-12T06:00:00Z")
        self.assertIn("FUTURE_PUBLISHER_TIME", future["blockers"])
        self.assert_all_authorities_denied(future)
        wrong = self.screen(publisherUpdatedUtc="2026-11-11")
        self.assertIn("PUBLISHER_CLOCK_NOT_PROVEN", wrong["blockers"])
        self.assert_all_authorities_denied(wrong)

    def test_immutably_reject_invalid_metadata_and_observation_clock(self):
        with self.assertRaisesRegex(ValueError, "INVALID_CANDIDATE_OBJECT"):
            gate.screen_public_candidate([], observed_utc="2026-11-11T23:59:00Z")
        with self.assertRaisesRegex(ValueError, "INVALID_CANDIDATE_FIELDS"):
            gate.screen_public_candidate(
                {**self.candidate(), "auth": True}, observed_utc="2026-11-11T23:59:00Z")
        with self.assertRaisesRegex(ValueError, "INVALID_DECLAREDRIGHTS"):
            self.screen(declaredRights="WRITTEN_PERMISSION_PROVEN")
        with self.assertRaisesRegex(ValueError, "INVALID_OBSERVATION_CLOCK"):
            gate.screen_public_candidate(self.candidate(), observed_utc="2026-11-11")



if __name__ == "__main__":
    unittest.main()
