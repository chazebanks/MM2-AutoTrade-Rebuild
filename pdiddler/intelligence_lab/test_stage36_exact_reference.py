"""Execute byte-for-byte core and actual native-launcher behavioral fixtures."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(shutil.which("lua5.4"), "Lua 5.4 required")
class Stage36ExactReferenceTests(unittest.TestCase):
    def run_lua(self, name, marker):
        result = subprocess.run(
            ["lua5.4", f"pdiddler/new_part4/tests/{name}.lua", "pdiddler/new_part4"],
            cwd=ROOT, capture_output=True, text=True, timeout=25,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(marker, result.stdout)
        self.assertIn("0 failed", result.stdout)

    def test_original_reference_comparison(self):
        self.run_lua("test_stage36_exact_reference", "Stage36 exact reference:")

    def test_actual_native_launcher_exact_path(self):
        self.run_lua("test_stage36_exact_native", "Stage36 exact native:")
