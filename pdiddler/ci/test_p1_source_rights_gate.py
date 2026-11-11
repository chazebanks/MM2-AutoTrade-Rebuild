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


if __name__ == "__main__":
    unittest.main()
