"""Behavioral Lua regressions; examples are synthetic, not native URI samples."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]


class Stage36ReferenceSafetyTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("lua5.4"), "Lua 5.4 required")
    def test_reference_safety_in_actual_lua(self):
        result = subprocess.run(
            ["lua5.4", "pdiddler/new_part4/tests/test_stage36_reference_safety.lua",
             "pdiddler/new_part4"],
            cwd=ROOT, capture_output=True, text=True, timeout=14,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Stage36 reference safety: 28 passed, 0 failed", result.stdout)
