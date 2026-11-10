import os
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LUA = os.environ.get("LUA54", "lua5.4")
STAGE9_NATIVE = os.environ.get("STAGE106_STAGE9_NATIVE")
STAGE9_CONTRACT = os.environ.get("STAGE106_STAGE9_CONTRACT")
STAGE83_REGISTRY = os.environ.get("STAGE106_STAGE83_REGISTRY")
STAGE101_MATCHER = os.environ.get("STAGE106_STAGE101_MATCHER")
STAGE100_OVERLAY = os.environ.get("STAGE106_STAGE100_OVERLAY")
STAGE101_TEST = os.environ.get("STAGE106_STAGE101_TEST")


def run_lua(test, environment):
    result = subprocess.run(
        [LUA, str(test)],
        cwd=ROOT,
        capture_output=True,
        text=True,
        env=environment,
    )
    if result.returncode:
        raise AssertionError(
            f"{test.name} exited {result.returncode}\n"
            f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )
    return result.stdout


class Stage106ReadOnlyWitnessTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if os.environ.get("STAGE106_REQUIRE_PINNED") != "1":
            raise unittest.SkipTest("Stage106 integration only runs with pinned original Lua sources")
        for key in (
            "STAGE106_STAGE9_NATIVE", "STAGE106_STAGE9_CONTRACT",
            "STAGE106_STAGE83_REGISTRY", "STAGE106_STAGE101_MATCHER",
            "STAGE106_STAGE100_OVERLAY", "STAGE106_STAGE101_TEST",
        ):
            path = os.getenv(key)
            if not path or not Path(path).is_file():
                raise RuntimeError("Missing pinned Stage106 source: " + key)

    def test_pinned_stage101_original_source_regressions(self):
        self.assertTrue(STAGE101_TEST, "Stage101 test must be fetched at its pinned SHA")
        output = run_lua(
            Path(STAGE101_TEST),
            {
                **os.environ,
                "STAGE101_MODULE": STAGE101_MATCHER or "",
                "STAGE101_ORIGINAL_STAGE9": STAGE9_CONTRACT or "",
                "STAGE101_ORIGINAL_STAGE83": STAGE83_REGISTRY or "",
            },
        )
        self.assertIn("STAGE101_ORIGINAL_PART4_WEAPON_RECONCILE_PASS", output)

    def test_actual_native_wrapper_with_mock_roblox_and_original_observer(self):
        test = ROOT / "pdiddler/tests/test_stage106_readonly_witness.lua"
        output = run_lua(
            test,
            {
                **os.environ,
                "STAGE106_MODULE": str(
                    ROOT
                    / "pdiddler/new_part4/STAGE106_READONLY_TWO_SIDED_UPDATE_TRADE_WITNESS.lua"
                ),
                "STAGE106_STAGE9_NATIVE": STAGE9_NATIVE or "",
                "STAGE106_STAGE9_CONTRACT": STAGE9_CONTRACT or "",
                "STAGE106_STAGE83_REGISTRY": STAGE83_REGISTRY or "",
                "STAGE106_STAGE101_MATCHER": STAGE101_MATCHER or "",
                "STAGE106_STAGE100_OVERLAY": STAGE100_OVERLAY or "",
            },
        )
        self.assertIn("STAGE106_READONLY_WITNESS_PASS", output)


if __name__ == "__main__":
    unittest.main()
