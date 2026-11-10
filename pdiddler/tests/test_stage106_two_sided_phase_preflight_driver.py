"""Stage106 pure preflight executes unchanged original Stage9/Stage83/Stage101 Lua.
No Roblox, installed executor, item movement, requests or Accept path.
"""
from pathlib import Path
import os
import re
import subprocess
import unittest

SOURCE=Path("pdiddler/intelligence_lab/stage106_two_sided_phase_preflight.lua")
TEST=Path("pdiddler/tests/test_stage106_two_sided_phase_preflight.lua")
ORIGINALS=("STAGE106_ORIGINAL_STAGE9","STAGE106_ORIGINAL_STAGE83",
           "STAGE106_ORIGINAL_STAGE101")

class Stage106PurePreflight(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if os.environ.get("STAGE106_REQUIRE_PINNED")!="1":
            raise unittest.SkipTest("Original Git blobs required for Stage106")
        for key in ORIGINALS:
            path=os.environ.get(key)
            if not path or not Path(path).is_file():
                raise RuntimeError("Missing pinned source "+key)

    def test_original_lua_and_360_mutated_phase_transitions(self):
        r=subprocess.run(["lua5.4",str(TEST)],env=os.environ.copy(),
                         capture_output=True,text=True,timeout=40)
        self.assertEqual(r.returncode,0,r.stdout+"\n"+r.stderr)
        groups=re.findall(r"^PASS Stage106 ",r.stdout,re.MULTILINE)
        self.assertEqual(len(groups),12,r.stdout)
        self.assertIn("STAGE106_PHASE_PREFLIGHT_REAL_ORIGINAL_SOURCE_PASS "
                      "groups=12 mutations=360",r.stdout)
        for secret in ("private_stage106","private_job","Gingerscope",
                       "Scythe","Batwing"):
            self.assertNotIn(secret,r.stdout)

    def test_actual_lua_compiles(self):
        for file in (SOURCE,TEST):
            r=subprocess.run(["luac5.4","-p",str(file)],capture_output=True,
                             text=True,timeout=15)
            self.assertEqual(r.returncode,0,r.stderr+r.stdout)

    def test_no_game_actions_or_any_escalated_authority(self):
        source=SOURCE.read_text()
        for forbidden in (
            "game:GetService(", "FireServer(", "InvokeServer(",
            "HttpGet(", "PostAsync(", "AcceptTrade(", "DeclineTrade(",
            "SendMouseButtonEvent(", "getconnections(", "getgenv(",
            "TeleportService", "setclipboard(", "Discord", "authorizesTrade=true",
            "authorizesAccept=true", "serverCompletionProven=true"
        ):
            self.assertNotIn(forbidden,source,forbidden)
        for term in (
            "stage101.inspect({","CLIENT_RAW_KEY_GUI_CANDIDATE_NOT_PROVEN",
            "LISTENER_PHASE_OR_SINGLE_CALLBACK_NOT_VERIFIED",
            "PROTECTED_GINGERSCOPE_IN_OUR_OFFER",
            "eventSessionAssociationProven=false",
            "callbackCausalityProven=false","authorizesAccept=false",
            "maySendDiscordWebhook=false",
        ):
            self.assertIn(term,source,term)

if __name__=="__main__":
    unittest.main()
