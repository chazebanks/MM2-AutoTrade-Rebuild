"""Stage49 exact-Lua-key ownership correspondence and checker-ID trust boundary.

Run the checked-in real Lua auditor through Python (not a Python reimplementation).
A matched Sync, owned profile and scanner row is CLIENT evidence only.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile
import textwrap
import unittest

LAB=Path(__file__).resolve().parent
ROOT=LAB.parents[1]
P4=LAB.parent/"new_part4"
CORE=P4/"p4_stage49_raw_key_ownership_bridge.lua"
TEST=P4/"tests"/"test_stage49_raw_key_ownership_bridge.lua"
SCANNER=LAB.parent/"presentation"/"pdiddler3_scanner_MODULE_v6_10_CURRENT_PRESENTATION.lua"

class Stage49RawKeyTests(unittest.TestCase):
    def test_source_check_against_actual_scanner_api(self):
        code=SCANNER.read_text()
        for clause in (
            'local Sync=req(DB and DB:FindFirstChild("Sync")) or {}',
            'indexItems(Sync.Weapons)',
            'if Sync.Item~=Sync.Weapons then',
            'local owned=type(weapons)=="table" and weapons.Owned',
            'for rawId,count in pairs(owned) do',
            'local id=tostring(rawId)',
            'local meta=Meta["Weapons|"..id]',
            'checkerId=market and market.id or "UNPRICED"',
            'local function checkerResolve(name,opts)',
            'if best and bestScore>=200 and not tied then',
            'local origin="match:"..bestScore',
            'return best,origin',
            'return rec,"alias"',
            'id=id,',
            'rawOwned=0,',
            'return parsed,nil',
        ):
            with self.subTest(clause=clause):
                self.assertIn(clause,code)

    def test_identity_bridge_source_has_literal_not_stringified_ownership_comparison(self):
        code=CORE.read_text()
        for clause in (
            'local owned=rawget(profileOwned,key)',
            'local meta=seen[key]',
            'rawequal',
            'RAW_OWNED_KEY_TYPE_COLLISION',
            'STRING_NUMERIC_KEY_COLLISION',
            'SCANNER_PROFILE_TOTAL_DISAGREES',
            'NUMERIC_KEY_SCANNER_COERCION_UNVERIFIED',
            'SCANNER_OWNED_QUANTITY_MISMATCH',
            'SCANNER_ROW_METADATA_MISMATCH',
            'UNATTESTED_SCANNER_RESOLVER',
        ):
            self.assertIn(clause,code)
        for prohibited in (
            'rawget(profileOwned,tostring(key))',
            'rawget(profileOwned,tonumber(key))',
            'scannerRow.checkerId==',
            'checkerIdentityVerified=true',
            'rawItemIdConfirmed=true',
            'offerKeyOriginVerified=true',
            ':FireServer(',':InvokeServer(',':PostAsync(',
            'GetProfileData(', 'GetFullInventory(',
        ):
            self.assertNotIn(prohibited,code)

    def test_authority_false_contract_is_unconditional(self):
        code=CORE.read_text()
        for flag in (
            'checkerIdentityVerified','offerKeyOriginVerified',
            'uniqueWeaponInstanceProven','rawItemIdConfirmed',
            'rawKeyPresentConfirmed','ownerSideSlotBound',
            'hasAuthenticatedSessionIdentifier','eventSessionAssociationProven',
            'causalAttributionProven','serverAttestation','serverCompletionProven',
            'authorizesTrade','authorizesAccept','mayRecordCompletedTrade',
            'mayReportProfit',
        ):
            self.assertIn(flag+'=false',code)
            self.assertNotIn(flag+'=true',code)
        self.assertIn('tradeOutcome="UNKNOWN"',code)

    def test_offline_no_delta_probe_or_outbound_remotes(self):
        self.assertFalse((P4/"STAGE49_READONLY_NATIVE_PROBE.lua").exists())
        source=CORE.read_text()
        for forbidden in (
            'HttpGet','HttpService','GetService','game.',
            'loadstring','setclipboard','getgenv','hookfunction',
            'RemoteEvent','OnClientEvent','while true',
        ):
            self.assertNotIn(forbidden,source)

    @unittest.skipUnless(shutil.which("lua5.4"),"GitHub CI has Lua5.4")
    def test_python_executes_actual_checked_in_lua_suite(self):
        p=subprocess.run(
            ["lua5.4",str(TEST),str(P4)],cwd=ROOT,
            capture_output=True,text=True,timeout=25)
        self.assertEqual(p.returncode,0,p.stdout+"\n"+p.stderr)
        self.assertIn("Stage49 exact raw-key ownership bridge: 38 passed, 0 failed",p.stdout)

    @unittest.skipUnless(shutil.which("lua5.4"),"GitHub CI has Lua5.4")
    def test_python_runs_500_seeded_actual_lua_key_collision_trials(self):
        lua=textwrap.dedent(r'''
        local M=assert(loadfile(arg[1]))()
        math.randomseed(491107)
        local flags={"checkerIdentityVerified","offerKeyOriginVerified",
         "uniqueWeaponInstanceProven","rawItemIdConfirmed","rawKeyPresentConfirmed",
         "ownerSideSlotBound","hasAuthenticatedSessionIdentifier",
         "eventSessionAssociationProven","causalAttributionProven",
         "serverAttestation","serverCompletionProven","authorizesTrade",
         "authorizesAccept","mayRecordCompletedTrade","mayReportProfit"}
        local successes,failures=0,0
        local function privateFree(t)
         if type(t)=="string" then
          assert(not t:find("PRIVATE",1,true),"raw value leaked")
         elseif type(t)=="table"then
          for k,v in pairs(t)do privateFree(k);privateFree(v)end
         end
        end
        for n=1,500 do
         local key="PRIVATE_RAW_"..n
         local amount=math.random(1,10)
         local offered=math.random(1,10)
         local kind=math.random(1,9)
         local m={ItemName="PrivateName",Rarity="Ancient",ItemType="Knife"}
         local w={[key]=m}
         local sync={Weapons=w,Item=w}
         local owned={[key]=amount}
         local scanner={rawOwned=amount,unmapped=0,badQty=0,items={{
           id=key,cat="Weapons",page="ancient",name="PrivateName",
           type="Knife",qty=amount,checkerId="000000",valueSource="PRIVATE_SRC"}}}
         if kind==1 then scanner.items[1].checkerId="PRIVATE_FAKE_ID"
         elseif kind==2 then scanner.items[1].id="PRIVATE_OTHER"
         elseif kind==3 then scanner.items[1].qty=amount+1
         elseif kind==4 then scanner.items[1].page="godly"
         elseif kind==5 then sync.Weapons["42"]=m;sync.Weapons[42]=m
         elseif kind==6 then owned["7"]=1;owned[7]=2;scanner.rawOwned=amount+3
         elseif kind==7 then scanner.rawOwned=amount+1
         elseif kind==8 then scanner.unmapped=1
         elseif kind==9 then m.ItemName="Mismatched"end
         local r=M.inspect(sync,owned,scanner,key,offered)
         assert(r.readOnly and r.clientOnly and r.tradeOutcome=="UNKNOWN")
         for _,flag in ipairs(flags)do assert(r[flag]==false,flag)end
         if r.rawKeyOwnedClientMatch then
          assert(r.status=="CLIENT_RAW_KEY_OWNERSHIP_CORRESPONDENCE_ONLY")
          assert(offered<=amount and kind==1)
          successes=successes+1
         else failures=failures+1 end
         privateFree(r)
        end
        assert(successes>5 and failures>350)
        print("STAGE49_RANDOMIZED_REAL_LUA 500 ok")
        ''')
        with tempfile.TemporaryDirectory(prefix="stage49_lua_") as temp:
            f=Path(temp)/"probe.lua"
            f.write_text(lua)
            p=subprocess.run(["lua5.4",str(f),str(CORE)],cwd=ROOT,
                capture_output=True,text=True,timeout=20)
        self.assertEqual(p.returncode,0,p.stdout+"\n"+p.stderr)
        self.assertIn("STAGE49_RANDOMIZED_REAL_LUA 500 ok",p.stdout)

if __name__=="__main__":
    unittest.main()
