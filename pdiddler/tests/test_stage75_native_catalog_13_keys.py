"""Actual Lua5.4 Stage75 read-only 13-key native catalogue checks and UI/clipboard.

No MM2 account, player inventory or trade is required. The only new native
evidence in a future manual run will be the client game-catalogue fields.
"""
from __future__ import annotations

import importlib.util
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
LUA_SOURCE=ROOT/"pdiddler/new_part4/STAGE75_READONLY_13_KEY_CATALOG_PROBE.lua"
SCRIPT=LUA_SOURCE.read_text(encoding="utf-8")
DB=Path(os.getenv("STAGE75_PINNED_THIRD_PARTY_DB",
                "/tmp/stage75_oct18_public_db.lua"))
SOURCE_BLOB="2be54c3f5c6b715844728c01a65cc2f24a55c02d"
TARGETS=re.findall(
    r'^\s*\{raw="([^"\n]+)",name="([^"\n]+)",kind="([^"\n]+)",'
    r'rarity="([^"\n]+)",chroma=(true|false)\},$',
    SCRIPT,re.M,
)
LUA_HARNESS=r'''
local mode=assert(arg[1])
local path=assert(arg[2])
local targetRows=assert(loadfile(arg[3]))()
local msgs, uiLabels, copies, warnings={}, {}, {}, {}
local gameplayCalls, numberOfGameCatalogueGets, syncRequireCalls=0,0,0
local env={}
getgenv=function()return env end
setclipboard=nil
toclipboard=nil
if mode~="copy_fail" then
  setclipboard=function(v)copies[#copies+1]=v end
end
print=function(v)msgs[#msgs+1]=tostring(v)end
warn=function(v)warnings[#warnings+1]=tostring(v)end
local function fakeNode(class)
  local n={ClassName=class,Activated={Connect=function()end}}
  function n:Destroy()n.Parent=nil end
  function n:IsA(k)return class==k end
  if class=="TextLabel" then uiLabels[#uiLabels+1]=n end
  return n
end
if mode~="no_gui" then
  Instance={new=fakeNode}
else Instance=nil end
local function dummy()return {} end
UDim2={fromOffset=dummy,new=dummy}
UDim={new=dummy}
Vector2={new=dummy}
Color3={fromRGB=dummy}
Enum={Font={GothamBold="GothamBold",Gotham="Gotham"},
  TextXAlignment={Left="Left"},TextYAlignment={Top="Top"}}
local pg={}
function pg:FindFirstChild(name) return nil end
local lp={}
function lp:FindFirstChildOfClass(cls)if cls=="PlayerGui" then return pg end end
local players={LocalPlayer=lp}
local gameDB={}
local syncModule={}
function gameDB:FindFirstChild(n)
  if n=="Sync" then return syncModule end
end
local rs={}
function rs:FindFirstChild(n)
  if n=="Database" then return gameDB end
end
local http={}
function http:JSONEncode(report)
  assert(type(report)=="table")
  assert(report.jobId==nil,"sensitive server ID was included")
  assert(report.authorizesTrade==false and report.authorizesAccept==false)
  assert(report.currentPricesVerified==false and report.rawToSupremeCheckerVerified==false)
  assert(report.authenticatedServerInventory==false and report.serverAttestation==false)
  assert(report.mayUseForStrategyLearning==false and report.maySendDiscordWebhook==false)
  return "SYNTHETIC_"..report.status
end
game={PlaceId=142823291,JobId="synthetic-unit-job"}
if mode=="wrong_game" then game.PlaceId=1234567 end
function game:GetService(n)
  if n=="Players" then return players end
  if n=="ReplicatedStorage" then return rs end
  if n=="HttpService" then return http end
  error("Unexpected service "..n)
end
local weapons={}
local itemIds={}
for i,target in ipairs(targetRows) do
  if not itemIds[target.name] then itemIds[target.name]=9000+i end
  weapons[target.raw]={
    ItemName=target.name,
    ItemType=target.kind,
    Rarity=target.rarity,
    Chroma=target.chroma,
    ItemID=itemIds[target.name],
  }
end
if mode=="missing" then weapons["EmberbowChroma"]=nil end
if mode=="wrong_name" then weapons["Gingerscope"].ItemName="NOT_THE_GINGERSCOPE" end
if mode=="wrong_chroma" then
  weapons["Emberbow"].Chroma=true
  weapons["EmberbowChroma"].Chroma=false
end
if mode=="invalid_field" then weapons["Mortal"].Chroma="true" end
if mode=="one_no_item_id" then weapons["Emberbow"].ItemID=nil end
if mode=="other_session" then env.PDIDDLER_OUTGOING_SESSION={active=true} end
local sync={Weapons=setmetatable({},{
  __index=function(_,key)numberOfGameCatalogueGets=numberOfGameCatalogueGets+1;return weapons[key]end
})}
require=function(m)
  assert(m==syncModule,"Unexpected module require")
  syncRequireCalls=syncRequireCalls+1
  if mode=="require_failure" then error("synthetic module failure") end
  if mode=="server_changed" then game.JobId="another-job" end
  return sync
end
local first=assert(dofile(path))
if mode=="duplicate" then
  local second=assert(dofile(path))
  assert(first==second,"duplicate run must reuse same session")
end
assert(first.expectedTargets==13)
assert(first.authorizesAccept==false and first.authorizesTrade==false)
assert(first.currentPricesVerified==false)
assert(first.mayRecordCompletedTrade==false and first.mayReportProfit==false)
local count=0
for _,line in ipairs(msgs) do
  if line:find("[GINGERSCOPE STAGE75 CLIENT CATALOG] ",1,true) then
    count=count+1
    assert(line:find("SYNTHETIC_",1,true))
  end
end
assert(count==1,"expected exactly one sanitized report, not "..count)
if mode=="wrong_game" then
  assert(first.status=="WRONG_GAME")
  assert(first.examinedTargets==0 and syncRequireCalls==0)
elseif mode=="other_session" then
  assert(first.status=="OTHER_SESSION_ACTIVE_REJOIN_REQUIRED")
  assert(first.examinedTargets==0 and syncRequireCalls==0)
elseif mode=="require_failure" then
  assert(first.status=="SYNC_CATALOG_UNAVAILABLE")
  assert(first.examinedTargets==0 and syncRequireCalls==1)
elseif mode=="server_changed" then
  assert(first.status=="SERVER_CHANGED")
  assert(first.examinedTargets==0)
else
  assert(first.gameCatalogueClientObserved==true)
  assert(first.examinedTargets==13 and #first.testResults==13)
  assert(numberOfGameCatalogueGets==13,"must read exactly 13 keys, no full census")
  assert(syncRequireCalls==1)
  assert(first.overlappingItemIdPairs==(mode=="one_no_item_id" and 4 or 5))
  if mode=="missing" then
    assert(first.status=="PARTIAL_CLIENT_CATALOG_FIELDS_UNVERIFIED")
    assert(first.exactTargets==12 and first.missingTargets==1)
  elseif mode=="wrong_name" then
    assert(first.status=="PARTIAL_CLIENT_CATALOG_FIELDS_UNVERIFIED")
    assert(first.exactTargets==12 and first.mismatchedTargets==1)
  elseif mode=="wrong_chroma" then
    assert(first.status=="PARTIAL_CLIENT_CATALOG_FIELDS_UNVERIFIED")
    assert(first.exactTargets==11 and first.mismatchedTargets==2)
  elseif mode=="invalid_field" then
    assert(first.status=="PARTIAL_CLIENT_CATALOG_FIELDS_UNVERIFIED")
    assert(first.exactTargets==12 and first.malformedTargets==1)
  else
    assert(first.status=="EXACT_13_PUBLIC_CATALOG_FIELDS_CLIENT_ONLY")
    assert(first.exactTargets==13)
  end
end
assert(gameplayCalls==0,"should never touch a trade remote or MM2 GUI")
if mode=="copy_fail" then
  assert(#copies==0 and first.clipboardAttemptSucceeded==false)
else
  assert(#copies==1 and first.clipboardAttemptSucceeded==true)
end
if mode~="no_gui" then
  assert(#uiLabels>=2,"expected in-game guidance title and body")
  local body=uiLabels[2].Text
  assert(body:find("NO TRADING",1,true) or body:find("COPY FAILED",1,true)
     or body:find("COPY SENT",1,true),
    "in-game result status not shown")
else
  assert(#uiLabels==0)
end
io.write("STAGE75_NATIVE "..mode.." OK\n")
'''
def targets_to_lua(rows: list[tuple[str,str,str,str,str]]) -> str:
    def q(s):
        assert re.fullmatch(r"[A-Za-z0-9_ \-]+",s),s
        return '"'+s+'"'
    out=["return {"]
    for raw,name,kind,rarity,chroma in rows:
        out.append("  {raw="+q(raw)+",name="+q(name)+",kind="+q(kind)+
                   ",rarity="+q(rarity)+",chroma="+chroma+"},")
    return "\n".join(out)+"\n}\n"

class Stage75NativeLuaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.lua=shutil.which("lua5.4")
        cls.luac=shutil.which("luac5.4")
        if not cls.lua or not cls.luac:
            raise RuntimeError("Real Lua5.4 compiler and runner required")
        if len(TARGETS)!=13 or len({x[0] for x in TARGETS})!=13:
            raise RuntimeError("Expected 13 unique static public raw game keys")
        cls.tmp=tempfile.TemporaryDirectory(prefix="stage75_mock_")
        cls.harness=Path(cls.tmp.name)/"runner.lua"
        cls.fixture=Path(cls.tmp.name)/"target.lua"
        cls.harness.write_text(LUA_HARNESS,encoding="utf-8")
        cls.fixture.write_text(targets_to_lua(TARGETS),encoding="utf-8")
    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()
    def run_case(self,mode):
        proc=subprocess.run(
            [self.lua,str(self.harness),mode,str(LUA_SOURCE),str(self.fixture)],
            text=True,capture_output=True,timeout=12
        )
        self.assertEqual(proc.returncode,0,(mode,proc.stdout,proc.stderr))
        self.assertIn(f"STAGE75_NATIVE {mode} OK",proc.stdout)
    def test_real_lua_compiles(self):
        c=subprocess.run([self.luac,"-p",str(LUA_SOURCE)],text=True,capture_output=True)
        self.assertEqual(c.returncode,0,c.stderr)
    def test_exact_13_and_five_shared_art_asset_ids(self):
        self.run_case("exact")
    def test_api_copy_failure_console_fallback(self):
        self.run_case("copy_fail")
    def test_gui_unavailable_console_fallback(self):
        self.run_case("no_gui")
    def test_missing_target_is_partial_not_verified(self):
        self.run_case("missing")
    def test_wrong_name_does_not_auto_correct(self):
        self.run_case("wrong_name")
    def test_wrong_chroma_rejects_base_variant_swaps(self):
        self.run_case("wrong_chroma")
    def test_malformed_chroma_flag_rejected(self):
        self.run_case("invalid_field")
    def test_item_art_id_absence_does_not_infer_or_reject_identity(self):
        self.run_case("one_no_item_id")
    def test_wrong_game_never_loads_game_module(self):
        self.run_case("wrong_game")
    def test_another_session_does_not_start_diagnostic(self):
        self.run_case("other_session")
    def test_require_failure_fails_closed(self):
        self.run_case("require_failure")
    def test_server_change_aborts_before_field_check(self):
        self.run_case("server_changed")
    def test_second_execute_is_idempotent_no_duplicate_copy(self):
        self.run_case("duplicate")
    def test_no_inventory_or_trade_methods_in_code(self):
        for forbidden in ('FireServer','InvokeServer','Weapons.Owned',
                          'GetPlayers(', 'GetPlayerInventory(', 'TradeGUI',
                          'AcceptTrade', 'CompleteTrade', 'WaitForChild("Trade"'):
            self.assertNotIn(forbidden,SCRIPT)
        self.assertNotIn("pairs(sync.Weapons)",SCRIPT)
        self.assertIn("sync.Weapons[target.raw]",SCRIPT)
        self.assertIn("No inventory, trading, player names, prices",SCRIPT)

class Stage75PublicProvenanceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not DB.is_file():
            if os.environ.get("STAGE75_REQUIRE_PINNED_SOURCE")=="1":
                raise RuntimeError("Pinned Oct18 public catalogue required")
            raise unittest.SkipTest("Public source downloaded only by isolated Stage75 CI")
        cls.data=DB.read_bytes()
    def test_all_13_literal_targets_match_pinned_oct18_raw_source(self):
        import hashlib
        blob=hashlib.sha1(b"blob "+str(len(self.data)).encode()+b"\0"+self.data).hexdigest()
        self.assertEqual(blob,SOURCE_BLOB)
        self.assertEqual(len(TARGETS),13)
        content=self.data.decode("utf-8")
        for raw,name,kind,rarity,chroma in TARGETS:
            with self.subTest(raw=raw):
                block=re.search(
                    r'(?m)^  \["'+re.escape(raw)+
                    r'"\]\s*=\s*\{\s*\n([\s\S]*?)^  \},?',content)
                self.assertIsNotNone(block)
                fields={}
                for field,value in re.findall(
                    r'(?m)^    \["(ItemName|ItemType|Rarity|Chroma)"\]'
                    r'\s*=\s*("[^"\n]*"|true|false)\s*,?\s*$',
                    block.group(1)):
                    self.assertNotIn(field,fields)
                    fields[field]=value[1:-1] if value.startswith('"') else value
                self.assertEqual(fields["ItemName"],name)
                self.assertEqual(fields["ItemType"],kind)
                self.assertEqual(fields["Rarity"],rarity)
                self.assertEqual(fields.get("Chroma","false"),chroma)
    def test_public_raw_targets_include_ancient_chromas(self):
        got={r[0]:(r[3],r[4]) for r in TARGETS}
        self.assertEqual(got["EmberbowChroma"],("Ancient","true"))
        self.assertEqual(got["EmberscytheChroma"],("Ancient","true"))
        self.assertEqual(got["BattleAxe"],("Godly","false"))
        self.assertEqual(got["BattleAxe2"],("Godly","false"))
        self.assertEqual(got["Gingerscope"],("Ancient","false"))

if __name__=="__main__":
    unittest.main()
