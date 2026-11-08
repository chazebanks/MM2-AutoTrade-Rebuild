"""Stage50: real source checks; Python executes exact native and pure Lua modules."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import textwrap
import unittest

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent.parent
P4=HERE.parent/"new_part4"
CORE=P4/"p4_stage50_preprofile_raw_key.lua"
NATIVE=P4/"STAGE50_READONLY_PREPROFILE_OFFER_KEY_PROBE.lua"
PURE_TEST=P4/"tests"/"test_stage50_preprofile_raw_key.lua"
NATIVE_TEST=P4/"tests"/"test_stage50_preprofile_offer_native.lua"
SCANNER=HERE.parent/"presentation"/"pdiddler3_scanner_MODULE_v6_10_CURRENT_PRESENTATION.lua"

class Stage50ProfileTests(unittest.TestCase):
    def test_actual_game_scanner_profile_source(self):
        s=SCANNER.read_text()
        for clause in (
            'local rf=invFolder and invFolder:FindFirstChild("GetProfileData")',
            'local owned=type(weapons)=="table" and weapons.Owned',
            'for rawId,count in pairs(owned) do',
            'local id=tostring(rawId)',
            'local meta=Meta["Weapons|"..id]',
        ):
            with self.subTest(clause=clause):
                self.assertIn(clause,s)

    def test_native_bounded_read_only_rpc_and_event_gates(self):
        s=NATIVE.read_text()
        for clause in (
            'local PROFILE_PIN="43cd3031127ea769ab608078f4b89b5f90c43fa6"',
            'source(PROFILE_PIN,"p4_stage50_preprofile_raw_key")',
            'local function preOfferProfileRead()',
            'profileReadAttempts=1',
            'task.spawn(function()',
            'rf:InvokeServer()',
            'profileReadTimedOut=true;finish("OWN_PROFILE_READ_TIMEOUT")',
            'if not preOfferProfileRead() then return end',
            'OFFER_CHANGED_DURING_PROFILE_READ',
            'TWO_PHASE_CLIENT_PREPROFILE_RAW_KEY_MATCHED',
            'profileCandidateClientMatched~=true',
            'stage50ClientRawOfferOwnedMatch',
            'UPDATE_TRADE_REMOTE_CHANGED',
            'COMPETING_OWNER',
            'clientState.clientStateMatched~=true',
            'LISTENER_CLEANUP_INCOMPLETE',
            'stage50NotAnAuthenticatedSession=true',
        ):
            with self.subTest(clause=clause):
                self.assertIn(clause,s)
        self.assertEqual(s.count(':InvokeServer()'),1)
        for forbidden in (
            ':FireServer(',':FireClient(',':FireAllClients(',
            ':InvokeClient(',':PostAsync(', 'request({',
            'mouse1click(', 'VirtualInputManager',
            'TeleportToPlaceInstance(', 'getconnections(',
        ):
            self.assertNotIn(forbidden,s)

    def test_pure_key_compare_still_no_trade_authority(self):
        s=CORE.read_text()
        self.assertIn('for k,v in next,rawOwned do',s)
        self.assertIn('PROFILE_STRING_NUMERIC_KEY_COLLISION',s)
        self.assertIn('KEY_NOT_PRESENT_IN_PREPROFILE',s)
        for name in (
            'rawOfferKeyBoundToPreprofile','offerKeyOriginVerified',
            'checkerIdentityVerified','uniqueWeaponInstanceProven',
            'rawItemIdConfirmed','rawKeyPresentConfirmed','ownerSideSlotBound',
            'eventSessionAssociationProven','causalAttributionProven',
            'serverAttestation','serverCompletionProven',
            'authorizesTrade','authorizesAccept',
            'mayRecordCompletedTrade','mayReportProfit',
        ):
            self.assertIn(name+'=false',s)
            self.assertNotIn(name+'=true',s)
        self.assertIn('tradeOutcome="UNKNOWN"',s)

    def test_native_test_has_timeouts_and_clean_late_return(self):
        s=NATIVE_TEST.read_text()
        for marker in (
            'Stage50 native preprofile RPC occurs once before add',
            'Stage50 native profile RPC timeout bounded',
            'Stage50 native late RPC result cannot republish',
            'Stage50 native job change during profile read fails',
            'Stage50 native manual offer before profile bound rejected',
            'Stage50 native missing Batwing raw key refuses before listener',
            'Stage50 native numeric string collision in Owned refuses',
        ):
            self.assertIn(marker,s)

    @unittest.skipUnless(shutil.which('lua5.4'),'GitHub Actions installs Lua 5.4')
    def test_python_executes_real_pure_lua(self):
        p=subprocess.run(['lua5.4',str(PURE_TEST),str(P4)],
            cwd=ROOT,capture_output=True,text=True,timeout=15)
        self.assertEqual(p.returncode,0,p.stdout+'\n'+p.stderr)
        self.assertIn('Stage50 preprofile raw key pure: 26 passed, 0 failed',p.stdout)

    @unittest.skipUnless(shutil.which('lua5.4'),'GitHub Actions installs Lua 5.4')
    def test_python_executes_real_full_native_game_mock(self):
        p=subprocess.run(['lua5.4',str(NATIVE_TEST),str(P4)],
            cwd=ROOT,capture_output=True,text=True,timeout=25)
        self.assertEqual(p.returncode,0,p.stdout+'\n'+p.stderr)
        self.assertIn('Stage50 preprofile add/remove native: 31 passed, 0 failed',p.stdout)

    @unittest.skipUnless(shutil.which('lua5.4'),'GitHub Actions installs Lua 5.4')
    def test_python_randomizes_350_actual_lua_profile_maps(self):
        script=textwrap.dedent(r'''
            local M=assert(loadfile(arg[1]))()
            math.randomseed(501107)
            local nmatch,notmatch=0,0
            local flags={"rawOfferKeyBoundToPreprofile","offerKeyOriginVerified",
             "checkerIdentityVerified","uniqueWeaponInstanceProven",
             "rawItemIdConfirmed","rawKeyPresentConfirmed","ownerSideSlotBound",
             "eventSessionAssociationProven","causalAttributionProven",
             "serverAttestation","serverCompletionProven",
             "authorizesTrade","authorizesAccept","mayRecordCompletedTrade",
             "mayReportProfit"}
            local function noleak(r)
             for k,v in pairs(r)do
              if type(v)=="string"then
               assert(not v:find("SECRET",1,true),"raw key leak")
              end
             end
             for _,name in ipairs(flags)do assert(r[name]==false,name)end
             assert(r.clientOnly and r.readOnly and r.tradeOutcome=="UNKNOWN")
            end
            for i=1,350 do
             local key="SECRET_KEY_"..i
             local k=math.random(1,8)
             local q=math.random(0,4)
             local owned={[key]=q}
             if k==2 then owned[key]=nil
             elseif k==3 then owned[key]="abc"
             elseif k==4 then owned["42"]=1;owned[42]=1
             elseif k==5 then owned.Another=math.huge
             elseif k==6 then owned[key]="2"
             elseif k==7 then owned[key]=1.5
             elseif k==8 then setmetatable(owned,{__index=function()error("unsupported")end})end
             local r=M.inspect(owned,key)
             noleak(r)
             local permitted=(k==1 and q>0) or k==6
             if permitted then
              assert(r.profileCandidateClientMatched==true)
              nmatch=nmatch+1
             else
              assert(r.profileCandidateClientMatched==false)
              notmatch=notmatch+1
             end
            end
            assert(nmatch>20 and notmatch>200)
            print("STAGE50_REAL_LUA_PROFILE_350_PASS")
        ''')
        with tempfile.TemporaryDirectory(prefix='stage50_') as tmp:
            f=Path(tmp)/'cases.lua'
            f.write_text(script)
            p=subprocess.run(['lua5.4',str(f),str(CORE)],
                cwd=ROOT,capture_output=True,text=True,timeout=20)
        self.assertEqual(p.returncode,0,p.stdout+'\n'+p.stderr)
        self.assertIn('STAGE50_REAL_LUA_PROFILE_350_PASS',p.stdout)
if __name__=='__main__':
    unittest.main()
