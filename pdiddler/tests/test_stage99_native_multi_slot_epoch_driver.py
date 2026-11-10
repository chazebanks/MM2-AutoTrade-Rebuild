"""Stage99 native original MM2 Part4 adapter into Stage98 local GUI revision tracker.

The dedicated GitHub workflow pins the exact reviewed original Stage9/Stage98
Lua files by Git blob hash. These test real Lua modules and a mocked GUI, not
an iPad/Delta runtime and not server-authorized trade execution.
"""
from __future__ import annotations
import os
from pathlib import Path
import re
import subprocess
import unittest

RUNNER=Path("pdiddler/tests/test_stage99_native_multi_slot_epoch.lua")
SCRIPT=Path("pdiddler/new_part4/STAGE99_READONLY_MULTI_SLOT_EPOCH.lua")
DEPENDENCIES=("STAGE99_ORIGINAL_STAGE9","STAGE99_ORIGINAL_NATIVE",
              "STAGE99_ORIGINAL_STAGE98")

class NativeStage99(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if os.getenv("STAGE99_REQUIRE_PINNED")!="1":
            raise unittest.SkipTest("Dedicated immutable-source Stage99 CI is required")
        for key in DEPENDENCIES:
            p=os.getenv(key)
            if not p or not Path(p).is_file():
                raise RuntimeError("Pinned original module missing: "+key)

    def test_lua_syntax(self):
        for p in (RUNNER,SCRIPT):
            r=subprocess.run(["luac5.4","-p",str(p)],capture_output=True,
                text=True,timeout=10)
            self.assertEqual(r.returncode,0,r.stdout+r.stderr)

    def test_actual_original_native_gui_manual_sequence_and_negative_cases(self):
        r=subprocess.run(["lua5.4",str(RUNNER)],capture_output=True,text=True,
            timeout=40,env=os.environ.copy())
        self.assertEqual(r.returncode,0,r.stdout+"\n"+r.stderr)
        passed=[x for x in r.stdout.splitlines() if x.startswith("PASS Stage99 ")]
        self.assertGreaterEqual(len(passed),12,r.stdout)
        finals=[x for x in r.stdout.splitlines()
            if x.startswith("STAGE99_ACTUAL_NATIVE_GUI_EPOCH_TESTS_PASS")]
        self.assertEqual(len(finals),1,r.stdout)
        m=re.fullmatch(r"STAGE99_ACTUAL_NATIVE_GUI_EPOCH_TESTS_PASS groups=(\d+)",
            finals[0])
        self.assertIsNotNone(m)
        self.assertEqual(int(m.group(1)),len(passed))

    def test_no_transaction_or_market_authority_in_native_script(self):
        s=SCRIPT.read_text()
        for marker in (
            "PDIDDLER_STAGE99_READONLY_ARMED",
            "WAIT_FOR_MANUAL_TRADE_WINDOW",
            "READY_ADD_FIRST","READY_ADD_SECOND_DIFFERENT","READY_REMOVE_ONE",
            'source("stage9native")','source("stage98")',
            "epochs.observe(","epochs.checkPreview(","epochs.freezePreview(",
            "CLIENT_MULTI_SLOT_ADD_REMOVE_EPOCH_OBSERVED",
            "eventSessionAssociationProven=false,callbackCausalityProven=false",
            "serverTradeRevisionProven=false,serverAttestation=false",
            "actualRequestTaps=0,actualOffers=0,actualAccepts=0",
            "maySendDiscordWebhook=false","currentPricesVerified=false",
            "authorizesTrade=false","authorizesAccept=false",
            "[GINGERSCOPE STAGE99 OFFER EPOCH]"
        ):
            self.assertIn(marker,s,marker)
        for forbidden in (
            ":FireServer(",":InvokeServer(", "OnClientEvent:Connect(",
            "VirtualInputManager", "SendMouseButtonEvent(", "TeleportService",
            "PostAsync(", "HttpPost(", "AcceptTrade(", "DeclineTrade(",
            "getconnections(", "RequestTrade(", "OfferItem("
        ):
            self.assertNotIn(forbidden,s,forbidden)

if __name__=="__main__":
    unittest.main()
