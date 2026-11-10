"""Stage97 Python-controlled actual Lua5.4 native-wrapper mock suite.

Runs original pinned Stage9 observer and source-pinned Stage95/96 inside
fake Roblox GUI and UpdateTrade signal; never connects to a game server.
"""
from __future__ import annotations
import os
from pathlib import Path
import re
import subprocess
import unittest

LUA=Path("pdiddler/tests/test_stage97_readonly_partner_event_mock.lua")
SOURCE=Path("pdiddler/new_part4/STAGE97_READONLY_PARTNER_EVENT_WITNESS.lua")
DEPENDENCIES=("STAGE97_ORIGINAL_STAGE9","STAGE97_ORIGINAL_NATIVE","STAGE97_ORIGINAL_STAGE83")

class Stage97ReadOnlyWitnessTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if os.getenv("STAGE97_PINNED_SOURCES_REQUIRED")!="1":
            raise RuntimeError("Stage97 immutable original sources must be downloaded")
        for key in DEPENDENCIES:
            p=os.getenv(key)
            if not p or not Path(p).is_file():
                raise RuntimeError(f"Unverified dependency {key}")

    def test_live_wrapper_against_roblox_mock_with_negative_cases(self):
        run=subprocess.run(["lua5.4",str(LUA)],capture_output=True,
           text=True,env=os.environ.copy(),timeout=30)
        self.assertEqual(run.returncode,0,run.stdout+"\n"+run.stderr)
        rows=[s for s in run.stdout.splitlines() if s.startswith("PASS Stage97 ")]
        self.assertGreaterEqual(len(rows),9,run.stdout)
        summary=[s for s in run.stdout.splitlines()
            if s.startswith("STAGE97_NATIVE_WRAPPER_MOCK_PASS ")]
        self.assertEqual(len(summary),1,run.stdout)
        m=re.fullmatch(r"STAGE97_NATIVE_WRAPPER_MOCK_PASS groups=(\d+)",summary[0])
        self.assertIsNotNone(m)
        self.assertEqual(int(m.group(1)),len(rows))

    def test_lua_compiler_syntax(self):
        for p in (LUA,SOURCE):
            x=subprocess.run(["luac5.4","-p",str(p)],capture_output=True,text=True,timeout=10)
            self.assertEqual(x.returncode,0,x.stdout+x.stderr)

    def test_no_request_tap_or_offer_accept_native_path(self):
        s=SOURCE.read_text(encoding="utf-8")
        for marker in (
            'PDIDDLER_STAGE97_READONLY_ARMED',
            'exactRoot()', 'source("stage9native")','source("stage96")',
            'remote.OnClientEvent:Connect(function(...)',
            'connection:Disconnect()',
            'R.actualRequestTaps=0' if 'R.actualRequestTaps=0' in s else
                'actualRequestTaps=0',
            'actualOffers=0,actualAccepts=0',
            'eventSessionAssociationProven=false,callbackCausalityProven=false',
            'currentPricesVerified=false','authorizesTrade=false,authorizesAccept=false',
            '[GINGERSCOPE STAGE97 PARTNER EVENT]'
        ):
            self.assertIn(marker,s)
        for forbidden in (
            ':FireServer(', ':InvokeServer(', 'SendMouseButtonEvent(',
            'VirtualInputManager', 'TeleportService', 'PostAsync(',
            'HttpPost(', 'AcceptTrade(', 'DeclineTrade(', 'getconnections(',
            'TradeRequest:FireServer', 'TradeRequest:InvokeServer',
            'R.actualRequestTaps=1', 'actualOffers=1', 'actualAccepts=1'
        ):
            self.assertNotIn(forbidden,s)

if __name__=="__main__":
    unittest.main()
