"""Exercise the supported Stage 7 entry and its export boundaries."""

import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from pdiddler.system2.manual_portfolio_review import DEFAULT_CATALOG
from pdiddler.system2 import qualification_adversarial


CLOCK = "2026-11-25T07:52:05Z"


class AdversarialQualificationTests(unittest.TestCase):
    def test_stage_attempts_a_range_of_unsafe_inputs_without_exporting_raw_evidence(self):
        with TemporaryDirectory() as directory:
            report = qualification_adversarial.run_adversarial(
                Path(directory), clock=CLOCK, catalog=DEFAULT_CATALOG.read_bytes(),
            )
            self.assertEqual(list(Path(directory).iterdir()), [])
        self.assertEqual(report["status"], "PASS")
        self.assertEqual(report["checksPassed"], len(report["checks"]))
        self.assertEqual(set(report["checks"]), {
            "invalid_quantities", "protected_outgoing", "unknown_valuation", "historical_rules_inactive",
            "loss_authority_unapproved", "stale_offer_revision", "unproved_completion", "replayed_gain",
            "unsupported_learning_evidence", "untrusted_market", "conflicting_ownership",
            "expired_ownership_recovery", "one_sided_settlement", "unavailable_dependency",
            "invalid_state_recovery",
        })
        self.assertTrue(all(value is True for value in report["checks"].values()))
        exported = json.dumps(report)
        for internal in ("godly:Fang", "adversarial-reference", "qualification-transaction"):
            self.assertNotIn(internal, exported)

    def test_stage_rejects_invalid_starting_archive_with_sanitized_error(self):
        with TemporaryDirectory() as directory:
            with self.assertRaisesRegex(qualification_adversarial.AdversarialError, "UNTRUSTED_MARKET"):
                qualification_adversarial.run_adversarial(
                    Path(directory), clock=CLOCK, catalog=b'{"private":"do not echo"}',
                )
