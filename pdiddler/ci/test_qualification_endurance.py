"""Endurance qualification exercises real SQLite and strategy state."""

from pathlib import Path
from tempfile import TemporaryDirectory
import json
import unittest

from pdiddler.system2.manual_portfolio_review import DEFAULT_CATALOG
from pdiddler.system2.qualification_endurance import EnduranceError, run_endurance


CLOCK = "2026-11-25T07:52:05Z"


class QualificationEnduranceTests(unittest.TestCase):
    def test_repeated_sessions_restart_replay_and_account_without_real_profit(self):
        with TemporaryDirectory() as directory:
            workspace = Path(directory)
            result = run_endurance(workspace, clock=CLOCK, catalog=DEFAULT_CATALOG.read_bytes(), cycles=8)
            self.assertEqual(list(workspace.iterdir()), [])

        self.assertEqual(result["status"], "PASS")
        self.assertEqual(result["evidence_scope"], "CONTROLLED_OFFLINE")
        self.assertEqual(result["session_cycles"], 8)
        self.assertEqual(result["repeated_outcomes"], {
            "CLIENT_WINDOW_CLOSED_UNKNOWN": 2,
            "CORROBORATED_SYNTHETIC_SETTLEMENT": 2,
            "PARTNER_DECLINED": 2,
            "SESSION_INTERRUPTED": 2,
        })
        self.assertEqual(result["recovery"]["interrupted_write_rollbacks"], 1)
        self.assertEqual(result["recovery"]["expired_leases_retired"], 1)
        self.assertEqual(result["recovery"]["repeated_recovery_mutations"], 0)
        self.assertEqual(result["recovery"]["corrupt_database_rejections"], 3)
        self.assertIsNone(result["realized_growth"])
        self.assertFalse(result["authoritative_settlement_verified"])
        exported = json.dumps(result)
        for private_value in ("Fang", "Gingerscope", "session_digest", "owner", "sqlite3-journal"):
            self.assertNotIn(private_value, exported)

    def test_market_resource_limit_and_strategy_evidence_is_measured(self):
        with TemporaryDirectory() as directory:
            result = run_endurance(Path(directory), clock=CLOCK, catalog=DEFAULT_CATALOG.read_bytes(), cycles=1)
        self.assertEqual(result["market"]["historical_cutoff_utc"], "2026-11-25T12:09:59Z")
        self.assertTrue(result["market"]["expired_input_rejected"])
        self.assertTrue(result["market"]["synthetic_edition_changed"])
        self.assertGreater(result["performance"]["portfolio_item_count"], 50)
        self.assertGreater(result["performance"]["planner_pairs_examined"], 5_000)
        self.assertLessEqual(result["performance"]["planner_pairs_examined"],
                             result["performance"]["planner_pair_budget"])
        self.assertTrue(result["performance"]["planner_bounds_reached"])
        self.assertTrue(result["performance"]["oversized_report_rejected"])
        self.assertGreater(result["performance"]["wall_seconds"], 0)
        self.assertGreater(result["performance"]["database_bytes"], 0)
        self.assertGreater(result["strategy"]["phase_count"], 4)
        self.assertEqual(result["strategy"]["separate_measurements"], 6)
        self.assertEqual(result["strategy"]["failed_hypothetical_outcomes"], 1)
        self.assertGreater(result["strategy"]["successful_hypothetical_steps"], 2)

    def test_invalid_cycle_configuration_creates_no_state(self):
        with TemporaryDirectory() as directory:
            workspace = Path(directory)
            for cycles in (False, 0, 129):
                with self.subTest(cycles=cycles), self.assertRaisesRegex(EnduranceError, "cycle_count_invalid"):
                    run_endurance(workspace, clock=CLOCK, catalog=b"bad", cycles=cycles)
            self.assertEqual(list(workspace.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
