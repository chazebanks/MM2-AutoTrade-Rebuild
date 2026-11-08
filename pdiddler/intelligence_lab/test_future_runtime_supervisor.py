"""Run actual Lua future runtime supervisor (no Roblox executor required)."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).parent
SCRIPT = ROOT / "future_runtime_supervisor.lua"
TEST = ROOT / "test_future_runtime_supervisor.lua"

class FutureRuntimeSupervisorTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("lua5.4"), "CI installs Lua5.4")
    def test_native_lua_5000_events_and_named_transitions(self):
        p = subprocess.run(["lua5.4", str(TEST), str(SCRIPT)],
                           capture_output=True,text=True,timeout=40)
        self.assertEqual(p.returncode, 0, p.stdout+"\n"+p.stderr)
        self.assertIn("GINGERSCOPE_FUTURE_RUNTIME_LUA_5000_FUZZ_STEPS_PASS",p.stdout)

    def test_no_side_effects_and_read_only_contract(self):
        source=SCRIPT.read_text(encoding="utf-8")
        for forbidden in ("FireServer(", "InvokeServer(", "HttpGet(",
                          "loadstring(", "setclipboard(", "PostAsync(",
                          "TeleportToPlaceInstance(", "AcceptTrade",
                          "game:GetService(", "requests.get("):
            self.assertNotIn(forbidden,source)
        for needed in ('s.authorizesTrade=false','s.authorizesAccept=false',
                       's.serverCompletionProven=false','s.tradeOutcome="UNKNOWN"',
                       'UI_STABILITY_WAIT','STALE_OR_MISSING_EVENT_EPOCH',
                       'HOP_BLOCKED_TRADE_COMBAT_OR_UNVERIFIED',
                       'ALL_PREVIOUS_TRADE_PLANS_INVALIDATED'):
            self.assertIn(needed,source)

    def test_no_wall_clock_or_runtime_calls(self):
        source=SCRIPT.read_text()
        for bad in ("task.wait", "task.spawn", "os.clock(", "os.time(",
                    "RemoteEvent", "RemoteFunction", "HttpService",
                    "discord", "GitHub", "Synapse"):
            self.assertNotIn(bad,source)
if __name__=="__main__":
    unittest.main()
