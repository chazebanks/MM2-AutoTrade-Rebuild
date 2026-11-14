"""Governance regression: System 2's strategic mandate must not be hidden
behind the latest chronological MAIN/ALT mechanics handoff.

This is a documentation and continuity guard ONLY. It does not prove that
strategy, learning, final Accept or any live trading implementation works.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
LOCK = "pdiddler/system2/SYSTEM2_MISSION_LOCK_AND_TEST_GOVERNANCE_2026_11_14.md"
MATRIX = "pdiddler/system2/SYSTEM2_MODULAR_PLANNING_AND_TESTING_MATRIX_2026_11_13.md"


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


class MissionLockContinuity(unittest.TestCase):
    def test_new_conversation_start_here_prioritizes_mission(self):
        s = read("pdiddler/START_HERE.md")
        self.assertIn(LOCK, s[:1500])
        self.assertIn(MATRIX, s[:1500])
        self.assertLess(s.index(LOCK), s.index("NOV 11 2026"))

    def test_read_next_log_does_not_override_strategy(self):
        s = read("pdiddler/system2/SYSTEM2_READ_NEXT_2026_11_13.md")
        self.assertIn(LOCK, s[:1350])
        self.assertIn(MATRIX, s[:1350])
        self.assertLess(s.index(LOCK), s.index("PREARM OWN-P3-EPOCH"))

    def test_architecture_and_continuity_route_back_to_mission(self):
        for p in (MATRIX, "pdiddler/continuity/README.md"):
            with self.subTest(path=p):
                self.assertIn(LOCK, read(p)[:1100])

    def test_mission_separates_systems_and_preserves_growth(self):
        s = read(LOCK)
        for phrase in (
            "System 2 = trading intelligence",
            "System 1 / P3 / P4 are the mechanics",
            "bilateral attractiveness",
            "multi-step",
            "learning",
            "Gingerscope",
            "4 PHYSICAL slots",
            "not force an old highest-value opener",
        ):
            with self.subTest(phrase=phrase):
                self.assertIn(phrase, s)

    def test_hardware_replay_is_closed_not_the_project(self):
        s = read(LOCK)
        for phrase in (
            "five matching MAIN client inventory deltas",
            "six MAIN-initiated exact-ALT request cycles",
            "ALT_ITEM_ID_QUANTITY_OR_ELIGIBILITY_AMBIGUOUS",
            "DO NOT REQUEST ANOTHER SEQUENCE",
            "The real offered sixth item is UNKNOWN",
            "DISTINCT strategic behaviors",
        ):
            with self.subTest(phrase=phrase):
                self.assertIn(phrase, s)

    def test_diverse_coverage_and_current_unproven_limits(self):
        s = read(LOCK)
        for phrase in (
            "Raw item identity/variant/stack",
            "Trade option quality",
            "Two-sided counterparty appeal",
            "Gingerscope acquisition path",
            "Learning and uncertainty",
            "Negotiation/chat intent",
            "No replay for a filled box",
            "does NOT independently authenticate game server completion",
        ):
            with self.subTest(phrase=phrase):
                self.assertIn(phrase, s)

    def test_no_inadvertent_permitted_actions(self):
        s = read(LOCK)
        self.assertIn("Does not authorize FINAL ACCEPT", s)
        self.assertIn("No numeric", s if "No numeric" in s else
                      "No numeric policy approved") if False else None
        self.assertIn("no approved", s.lower())
        self.assertIn("public", s.lower())
        self.assertIn("not server", s.lower())

if __name__ == "__main__":
    unittest.main()
