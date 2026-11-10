"""Stage100 native original MM2 Part4 adapter into Stage98 local GUI revision tracker.

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

RUNNER=Path("pdiddler/tests/test_stage100_native_two_sided_epoch.lua")
SCRIPT=Path("pdiddler/new_part4/STAGE100_READONLY_TWO_SIDED_EPOCH.lua")
DEPENDENCIES=("STAGE100_ORIGINAL_STAGE9","STAGE100_ORIGINAL_NATIVE",
              "STAGE100_ORIGINAL_STAGE98")

class NativeStage100(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if os.getenv("STAGE100_REQUIRE_PINNED")!="1":
            raise unittest.SkipTest("Dedicated immutable-source Stage100 CI is required")
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
        passed=[x for x in r.stdout.splitlines() if x.startswith("PASS Stage100 ")]
        self.assertGreaterEqual(len(passed),13,r.stdout)
        finals=[x for x in r.stdout.splitlines()
            if x.startswith("STAGE100_NATIVE_TWO_SIDED_MOCK_PASS")]
        self.assertEqual(len(finals),1,r.stdout)
        m=re.fullmatch(r"STAGE100_NATIVE_TWO_SIDED_MOCK_PASS groups=(\d+)",
            finals[0])
        self.assertIsNotNone(m)
        self.assertEqual(int(m.group(1)),len(passed))

    def test_no_transaction_or_market_authority_in_native_script(self):
        s=SCRIPT.read_text()
        for marker in (
            "PDIDDLER_STAGE100_READONLY_ARMED",
            "WAIT_FOR_MANUAL_TRADE_WINDOW",
            'phase(0,1,"ALT_ADD_ONE")','phase(1,1,"MAIN_ADD_ONE")',
            'phase(1,0,"ALT_REMOVE_ONE")','"[STAGE100] READY_"..name',
            'source("stage9native")','source("stage98")',
            "epochs.observe(","epochs.checkPreview(","epochs.freezePreview(",
            "CLIENT_TWO_SIDED_OFFER_WITHDRAWAL_EPOCH_OBSERVED",
            "eventSessionAssociationProven=false,callbackCausalityProven=false",
            "serverTradeRevisionProven=false,serverAttestation=false",
            "actualRequestTaps=0,actualOffers=0,actualAccepts=0",
            "maySendDiscordWebhook=false","currentPricesVerified=false",
            "authorizesTrade=false","authorizesAccept=false",
            "[GINGERSCOPE STAGE100 TWO SIDED EPOCH]"
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
