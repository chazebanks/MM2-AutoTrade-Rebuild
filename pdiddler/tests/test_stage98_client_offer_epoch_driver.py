"""Stage98 Python-driven execution of real Lua client revision tracker, actual
unchanged Stage9 Amount parser and the prior Stage105 four-slot guard.
No MM2 runtime, game remotes, private inventories or actual market quotes.
"""
from pathlib import Path
import os
import re
import subprocess
import unittest

SOURCE=Path("pdiddler/intelligence_lab/stage98_client_offer_epoch.lua")
TEST=Path("pdiddler/tests/test_stage98_client_offer_epoch.lua")
REQUIRED=("STAGE98_MODULE","STAGE98_ORIGINAL_STAGE9","STAGE98_ORIGINAL_GUARD")

class Stage98LocalRevision(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if os.environ.get("STAGE98_REQUIRE_PINNED")!="1":
            raise unittest.SkipTest("Original-source Stage98 focused suite runs only under dedicated pinned CI")
        for key in REQUIRED:
            p=os.getenv(key)
            if not p or not Path(p).is_file():
                raise RuntimeError("Missing source "+key)

    def test_actual_original_lua_and_700_adversarial_revisions(self):
        result=subprocess.run(["lua5.4",str(TEST)],text=True,
            capture_output=True,env=os.environ.copy(),timeout=40)
        self.assertEqual(result.returncode,0,result.stdout+"\n"+result.stderr)
        passed=[line for line in result.stdout.splitlines()
                if line.startswith("PASS Stage98 ")]
        self.assertGreaterEqual(len(passed),17,result.stdout)
        found=re.findall(r"STAGE98_ORIGINAL_P4_PARSER_REVISIONS_PASS groups=(\d+) mutations=(\d+)",
            result.stdout)
        self.assertEqual(len(found),1,result.stdout)
        self.assertEqual(int(found[0][0]),len(passed))
        self.assertEqual(int(found[0][1]),700)

    def test_lua_lexer_compiler(self):
        for path in (SOURCE,TEST):
            result=subprocess.run(["luac5.4","-p",str(path)],text=True,
                capture_output=True,timeout=10)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)

    def test_observer_remains_client_only_and_cannot_act_or_approve(self):
        source=SOURCE.read_text()
        test=TEST.read_text()
        for term in (
            "M.observe(", "M.noteClientCallback(", "M.freezePreview(",
            "M.checkPreview(", "s.epoch=s.epoch+1",
            "CLIENT_PREVIEW_REVOKED",
            "CLIENT_CALLBACK_WITHOUT_GUI_REVISION",
            "CLIENT_SCOPE_OR_MONOTONIC_CLOCK_CHANGED",
            "FOUR_COPY_CONSERVATIVE_LIMIT_EXCEEDED",
            "serverTradeRevisionProven=false",
            "eventSessionAssociationProven=false,callbackCausalityProven=false",
            "priceForTradeVerified=false", "authorizesTrade=false",
            "authorizesAccept=false", "serverCompletionProven=false"
        ):
            self.assertIn(term,source,term)
        for term in ("Guard.evaluate(","actual prior Stage105","700 deterministic"):
            self.assertIn(term,test,term)
        for forbidden in (
            "FireServer(", "InvokeServer(", "HttpPost(", "PostAsync(",
            "VirtualInputManager", "TeleportService", "SendMouseButtonEvent(",
            "AcceptTrade(", "DeclineTrade(", "loadstring(game:HttpGet(",
            "getconnections(", "getgenv(", "game:GetService("
        ):
            self.assertNotIn(forbidden,source,forbidden)
        self.assertNotIn("authorizesTrade=true",source)
        self.assertNotIn("authorizesAccept=true",source)

if __name__=="__main__":
    unittest.main()
