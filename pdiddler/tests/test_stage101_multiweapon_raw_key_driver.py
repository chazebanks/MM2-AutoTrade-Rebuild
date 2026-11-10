"""Stage101: full two-sided client raw MM2 weapon-key ↔ actual Stage9 GUI
candidate matching. Research-only; Python invokes immutable original Lua files.
"""
from __future__ import annotations
import os
from pathlib import Path
import re
import subprocess
import unittest

MATCHER=Path("pdiddler/intelligence_lab/stage101_multiweapon_raw_key_match.lua")
TEST=Path("pdiddler/tests/test_stage101_multiweapon_raw_key_match.lua")
SOURCES=("STAGE101_MODULE","STAGE101_ORIGINAL_STAGE9","STAGE101_ORIGINAL_STAGE83")

class Stage101WeaponKeys(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if os.getenv("STAGE101_REQUIRE_PINNED")!="1":
            raise unittest.SkipTest("Requires dedicated original-source Stage101 CI")
        for key in SOURCES:
            p=os.getenv(key)
            if not p or not Path(p).is_file():
                raise RuntimeError("Missing reviewed source "+key)

    def test_original_stage9_and_83_real_lua_matcher(self):
        p=subprocess.run(["lua5.4",str(TEST)],capture_output=True,
            text=True,env=os.environ.copy(),timeout=35)
        self.assertEqual(p.returncode,0,p.stdout+"\n"+p.stderr)
        lines=[l for l in p.stdout.splitlines() if l.startswith("PASS Stage101 ")]
        self.assertGreaterEqual(len(lines),15,p.stdout)
        end=[l for l in p.stdout.splitlines()
            if l.startswith("STAGE101_ORIGINAL_PART4_WEAPON_RECONCILE_PASS ")]
        self.assertEqual(len(end),1,p.stdout)
        match=re.fullmatch(
           r"STAGE101_ORIGINAL_PART4_WEAPON_RECONCILE_PASS groups=(\d+) mutants=(\d+)",
           end[0])
        self.assertIsNotNone(match)
        self.assertEqual(int(match.group(1)),len(lines))
        self.assertEqual(int(match.group(2)),500)

    def test_lua_parser(self):
        for path in (MATCHER,TEST):
            p=subprocess.run(["luac5.4","-p",str(path)],capture_output=True,
               text=True,timeout=10)
            self.assertEqual(p.returncode,0,p.stdout+p.stderr)

    def test_raw_key_only_candidate_and_all_game_permissions_denied(self):
        source=MATCHER.read_text()
        for phrase in (
            'CLIENT_MULTISLOT_RAW_KEY_CANDIDATES_MATCH_GUI_UNATTRIBUTED',
            'MULTIPLE_DISTINCT_CLIENT_RAW_KEYS_MATCH_GUI_SLOT',
            'CLIENT_EVENT_COUNT_NOT_EXACTLY_ONE',
            'GUI_AFTER_SNAPSHOT_NOT_STABLE',
            'CLIENT_EVENT_GUI_TIMING_NOT_BOUNDED',
            'marketValueAuthority=false',
            'eventSessionAssociationProven=false,callbackCausalityProven=false',
            'rawItemIdConfirmed=false','authorizesTrade=false',
            'authorizesAccept=false', 'serverCompletionProven=false',
            'currentPricesVerified=false,priceForTradeVerified=false',
            'validForAutomatedTrade=false',
            'validForAutomatedAccept=false',
            'rawKeyServerAuthenticated=false',
            'local function eventSide(',
            'local function matchSide('
        ):
            self.assertIn(phrase,source,phrase)
        for forbidden in (
            ':FireServer(',':InvokeServer(', 'VirtualInputManager',
            'SendMouseButtonEvent(', 'TeleportService','HttpPost(',
            'PostAsync(', 'AcceptTrade(', 'DeclineTrade(',
            'getconnections(', 'game:GetService(', 'loadstring(game:HttpGet('
        ):
            self.assertNotIn(forbidden,source,forbidden)
        for unsafe in ('authorizesTrade=true','authorizesAccept=true',
                       'serverCompletionProven=true'):
            self.assertNotIn(unsafe,source)
        self.assertIn('M.inspect(',source)

if __name__=="__main__":
    unittest.main()
