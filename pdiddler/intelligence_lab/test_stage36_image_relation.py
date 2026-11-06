"""Execute the proposed passive representation diagnostic, never a live trade."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
P4 = ROOT / "pdiddler" / "new_part4"


@unittest.skipUnless(shutil.which("lua5.4"), "Lua 5.4 required")
class Stage36ImageRelationTests(unittest.TestCase):
    def run_lua(self, name, marker):
        result = subprocess.run(
            ["lua5.4", str(P4 / "tests" / (name + ".lua")), str(P4)],
            cwd=ROOT, capture_output=True, text=True, timeout=25,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(marker, result.stdout)
        self.assertIn("0 failed", result.stdout)

    def test_pure_diagnostic(self):
        self.run_lua("test_stage36_image_relation", "Stage36 image relation:")

    def test_actual_passive_launcher(self):
        self.run_lua("test_stage36_image_relation_native", "Stage36 image relation native:")

    def test_pure_and_native_compile_without_game_execution(self):
        for name in ("p4_stage36_image_relation.lua",
                     "STAGE36_READONLY_IMAGE_RELATION_PROBE.lua"):
            result = subprocess.run(
                ["lua5.4", "-e", "assert(loadfile(" + repr(str(P4 / name)) + "))"],
                cwd=ROOT, capture_output=True, text=True, timeout=10,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
