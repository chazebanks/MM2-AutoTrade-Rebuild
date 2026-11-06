"""Real Lua checks of a passive shape observation, never weapon resolution."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
P4 = ROOT / "pdiddler" / "new_part4"


@unittest.skipUnless(shutil.which("lua5.4"), "Lua 5.4 required")
class DirectKeyUpdateShapeTests(unittest.TestCase):
    def run_lua(self, name, marker):
        result = subprocess.run(
            ["lua5.4", str(P4 / "tests" / (name + ".lua")), str(P4)],
            cwd=ROOT, capture_output=True, text=True, timeout=25,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(marker, result.stdout)

    def test_pure_shape_inspector(self):
        self.run_lua("test_trade_update_shape", "synthetic Trade.Update payload shape tests")

    def test_actual_native_launcher(self):
        self.run_lua("test_trade_update_shape_native", "Trade update shape native:")

    def test_compile_without_native_execution(self):
        for name in ("p4_trade_update_shape.lua", "DIRECT_KEY_READONLY_UPDATE_SHAPE_PROBE.lua"):
            result = subprocess.run(
                ["lua5.4", "-e", "assert(loadfile(" + repr(str(P4 / name)) + "))"],
                cwd=ROOT, capture_output=True, text=True, timeout=10,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
