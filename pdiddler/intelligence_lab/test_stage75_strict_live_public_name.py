"""Stage75 actual Lua5.4 tests: strict SOURCE-NAME-only live client census.

Uses a synthetic 1040-entry catalogue, not a player inventory or game server.
"""
from __future__ import annotations
import json
import pathlib
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT=pathlib.Path(__file__).resolve().parents[2]
INDEX=ROOT/"pdiddler/intelligence_lab/stage75_historical_public_name_index.lua"
CORE=ROOT/"pdiddler/intelligence_lab/stage75_strict_live_public_name_comparison.lua"
BOOT=ROOT/"pdiddler/new_part4/STAGE75_NATIVE_STRICT_PUBLIC_NAME_BOOT.lua"
LABEL_RE=re.compile(r'\{page=("(?:\\.|[^"])*"),name=("(?:\\.|[^"])*")\}')
HARN=r'''
local mode=assert(arg[1])
local boot=assert(arg[2])
local engine=assert(dofile(arg[3]))
local index=assert(dofile(arg[4]))
local sync=assert(dofile(arg[5]))
local output,receipts,copyCalls={},0,0
print=function(x)output[#output+1]=tostring(x)end
warn=function(x)output[#output+1]="WARNING "..tostring(x)end
if mode=="bad_source" then index.sourcePublisherCurrent=true end
if mode=="dup_source" then index.rows[190]=index.rows[1] end
if mode=="invalid_item" then sync.Weapons.K0001.ItemID="invalid" end
if mode=="missing_name" then
  sync.Weapons.K0001.ItemName="SYNTHETIC_MISSING"
end
if mode=="chroma_as_base" then
  for _,entry in pairs(sync.Weapons) do
    if entry.ItemName=="Emberbow" and entry.Chroma==true then
      entry.Chroma=false
      break
    end
  end
end
if mode=="dup_entry" then
  local t=sync.Weapons.K0001
  sync.Weapons.SYNTHETIC_DUPLICATE={
   ItemName=t.ItemName,ItemType=t.ItemType,Rarity=t.Rarity,
   Chroma=t.Chroma,ItemID=9999999
  }
end
local v=engine.evaluate(sync,index)
assert(v.authorizesTrade==false and v.authorizesAccept==false)
assert(v.mayUseForStrategyLearning==false)
assert(v.maySendDiscordWebhook==false)
assert(v.sourceFresh==false and v.numericSupremePriceVerified==false)
assert(v.currentPlayerInventoryRead==false)
if mode=="bad_source" or mode=="dup_source" then
  assert(v.status=="INCONCLUSIVE")
elseif mode=="dup_entry" then
  assert(v.status=="CLIENT_CATALOG_COUNT_DRIFT_REVIEW_ONLY")
  assert(v.ambiguousMatches==1)
elseif mode=="invalid_item" then
  assert(v.status=="CLIENT_CATALOG_SHAPE_OR_AMBIGUITY_REVIEW_ONLY")
  assert(v.invalidCatalogEntries==1)
elseif mode=="missing_name" or mode=="chroma_as_base" then
  assert(v.status=="CLIENT_CATALOG_PUBLIC_NAME_ONLY")
  assert(v.strictMatches==187 and v.sourceNamesMissing==3)
else
  assert(v.status=="CLIENT_CATALOG_PUBLIC_NAME_ONLY",v.status)
  assert(v.catalogRows==1040 and v.catalogEligibleRows==200)
  assert(v.sourceRows==190 and v.strictMatches==188)
  assert(v.ambiguousMatches==0 and v.invalidCatalogEntries==0)
  assert(v.sourceNamesMissing==2)
  assert(v.matchedByCategory.ancient==16)
  assert(v.matchedByCategory.godly==126)
  assert(v.matchedByCategory.chroma==46)
  local miss={}
  for _,a in ipairs(v.missingSourceNames) do miss[a.name]=true end
  assert(miss["Battleaxe"] and miss["Battleaxe II"])
end
if mode:sub(1,5)=="core_" or mode=="bad_source"
 or mode=="dup_source" or mode=="invalid_item"
 or mode=="missing_name" or mode=="chroma_as_base" or mode=="dup_entry" then
 io.write("STAGE75 "..mode.." OK\n")
 return
end
local env={}
getgenv=function() return env end
loadstring=load
local originalJob="stage75-test-job"
local playerGui={}
local panelLabel
local guiCount=0
local gamePlayer={}
function gamePlayer:FindFirstChildOfClass(x)
 assert(x=="PlayerGui")
 return playerGui
end
local Players={LocalPlayer=gamePlayer}
local SyncModule={}
local db={}
function db:FindFirstChild(name)
 if name=="Sync" then return SyncModule end
end
local replicated={}
function replicated:FindFirstChild(name)
 if name=="Database" then return db end
end
local http={}
function http:JSONEncode(x)
 assert(x.authorizesTrade==false and x.authorizesAccept==false)
 assert(x.currentPlayerInventoryRead==false)
 assert(x.numericSupremePriceVerified==false)
 receipts=receipts+1
 return "SANITIZED_STAGE75_TEST_JSON"
end
game={PlaceId=142823291,JobId=originalJob}
if mode=="wrong_game" then game.PlaceId=1 end
function game:GetService(name)
 if name=="HttpService" then return http end
 if name=="Players" then return Players end
 if name=="ReplicatedStorage" then return replicated end
 error("service not allowed "..name)
end
function game:HttpGet(url)
 assert(type(url)=="string" and url:find("raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild",1,true))
 local path
 if url:find("stage75_historical_public_name_index.lua",1,true) then path=arg[4]
 elseif url:find("stage75_strict_live_public_name_comparison.lua",1,true) then path=arg[3]
 else error("unexpected unpinned module") end
 local file=assert(io.open(path,"rb"))
 local content=file:read("*a")
 file:close()
 return content
end
require=function(module)
 assert(module==SyncModule,"non-catalog module required")
 if mode=="server_changed" then game.JobId="different-job" end
 return sync
end
Instance={new=function(typ)
 guiCount=guiCount+1
 local obj={Name=typ}
 if typ=="TextLabel" then panelLabel=obj end
 return obj
end}
UDim2={fromOffset=function()return {} end,new=function()return {} end}
Color3={fromRGB=function()return {} end}
Enum={Font={GothamBold=1},TextXAlignment={Left=1},TextYAlignment={Top=1}}
if mode=="clipboard_ok" or mode=="duplicate_run" then
 setclipboard=function(text)
  assert(text=="SANITIZED_STAGE75_TEST_JSON")
  copyCalls=copyCalls+1
 end
elseif mode=="clipboard_throws" or mode=="clipboard_fallback" then
 setclipboard=function()copyCalls=copyCalls+1 error("synthetic failure")end
else setclipboard=nil end
if mode=="clipboard_fallback" then
 toclipboard=function(text)
  assert(text=="SANITIZED_STAGE75_TEST_JSON")
  copyCalls=copyCalls+1
 end
else toclipboard=nil end
if mode=="existing_trade" then env.PDIDDLER_PART4_SESSION=1 end
local state=dofile(boot)
assert(state.authorizesTrade==false and state.authorizesAccept==false)
assert(type(state.report)=="table" and state.report.sourceFresh==false)
assert(receipts==1,"exactly one sanitized report encoding")
local full=0
for _,s in ipairs(output) do
 if s:find("[GINGERSCOPE STAGE75 PUBLIC NAME ONLY]",1,true) then
   full=full+1
   assert(s:find("SANITIZED_STAGE75_TEST_JSON",1,true))
 end
end
assert(full==1,"one report line required")
if mode=="existing_trade" then
 assert(state.status=="ANOTHER_SESSION_PRESENT")
elseif mode=="wrong_game" then
 assert(state.status=="WRONG_GAME")
elseif mode=="server_changed" then
 assert(state.status=="SERVER_CHANGED_ABORT")
else
 assert(state.status=="CLIENT_CATALOG_PUBLIC_NAME_ONLY")
 assert(state.report.strictMatches==188)
 if mode=="clipboard_ok" or mode=="clipboard_fallback" or mode=="duplicate_run" then
  assert(state.clipboardStatus=="COPY_REQUEST_SUCCEEDED")
 else
  assert(state.clipboardStatus=="COPY_UNAVAILABLE" or state.clipboardStatus=="COPY_FAILED")
 end
end
assert(panelLabel and panelLabel.Text and panelLabel.Text:find("OUTGOING PAUSED",1,true),
 "in-game panel must contain visible final no-trading status")
if mode=="duplicate_run" then
 local before=guiCount
 local same=dofile(boot)
 assert(same==state and guiCount==before and receipts==1,
   "same server rerun overwrote GUI or clipboard")
end
io.write("STAGE75 "..mode.." OK\n")
'''
class Stage75Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.lua=shutil.which("lua5.4")
        cls.luac=shutil.which("luac5.4")
        if not cls.lua or not cls.luac:
            raise RuntimeError("Actual Lua5.4 tools required")
        cls.temp=tempfile.TemporaryDirectory(prefix="stage75_")
        root=pathlib.Path(cls.temp.name)
        cls.harness=root/"harness.lua"
        cls.fixture=root/"synthetic_catalog.lua"
        cls.harness.write_text(HARN,encoding="utf-8")
        pairs=[(json.loads(a),json.loads(b)) for a,b in LABEL_RE.findall(
            INDEX.read_text(encoding="utf-8"))]
        if len(pairs)!=190 or len(set(pairs))!=190:
            raise RuntimeError("Source must have 190 unique historical public names")
        # 188 exact names, 2 historical Battleaxe capitalization mismatches,
        # 12 deliberately new eligible source-external entries, 840 commons.
        rows=[]
        n=0
        for page,name in pairs:
            if (page,name) in {("godly","Battleaxe"),("godly","Battleaxe II")}:continue
            n+=1
            shown=name.removeprefix("Chroma ") if page=="chroma" else name
            chroma=page=="chroma"
            rarity="Ancient" if page=="ancient" or (chroma and
                shown in ("Emberscythe","Emberbow")) else "Godly"
            rows.append((f"K{n:04}",shown,rarity,"Gun",chroma,100000+n))
        for i in range(12):
            n+=1
            shown=("BattleAxe","BattleAxe II")[i] if i<2 else "EXTRA_"+str(i)
            rows.append((f"K{n:04}",shown,"Godly","Knife",False,100000+n))
        for i in range(840):
            n+=1
            rows.append((f"K{n:04}","COMMON_"+str(i),"Common","Knife",False,100000+n))
        assert n==1040 and len(rows)==1040
        src=["return {Weapons={"]
        for raw,name,rarity,kind,chroma,itemid in rows:
            src.append(
                f'[{json.dumps(raw)}]={{'
                f'ItemName={json.dumps(name,ensure_ascii=False)},'
                f'Rarity={json.dumps(rarity)},'
                f'ItemType={json.dumps(kind)},'
                f'Chroma={"true" if chroma else "false"},ItemID={itemid}}},'
            )
        src.append("}}")
        cls.fixture.write_text("\n".join(src),encoding="utf-8")
    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()
    def run_mode(self,mode):
        p=subprocess.run([self.lua,str(self.harness),mode,str(BOOT),
                          str(CORE),str(INDEX),str(self.fixture)],
                         capture_output=True,text=True,timeout=8)
        self.assertEqual(p.returncode,0,(mode,p.stdout[-1300:],p.stderr[-1800:]))
        self.assertIn(f"STAGE75 {mode} OK",p.stdout)
    def test_exact_lua_source_compiles_and_contains_no_trade_actions(self):
        for f in (INDEX,CORE,BOOT,self.fixture):
            x=subprocess.run([self.luac,"-p",str(f)],
                             capture_output=True,text=True)
            self.assertEqual(x.returncode,0,(str(f),x.stderr))
        boot=BOOT.read_text(encoding="utf-8")
        self.assertIn("f651b9dc381671b58608cafa06eafd6ab4908a4d",boot)
        self.assertIn("4b8a66d1432446bf6e11b9c9183b0a3232797d73",boot)
        for bad in (":FireServer(",":InvokeServer(","AcceptTrade(",
                    "SendRequest(","OfferItem(","DiscordWebhook("):
            self.assertNotIn(bad,boot)
    def test_188_synthetic_strict_matches(self):
        self.run_mode("core_base")
    def test_source_forgery_and_duplicate_names_fail_closed(self):
        for mode in ("bad_source","dup_source"):self.run_mode(mode)
    def test_ambiguity_and_partial_inventory_metadata(self):
        for mode in ("dup_entry","invalid_item","missing_name",
                     "chroma_as_base"):self.run_mode(mode)
    def test_native_gui_clipboard_request_once(self):
        self.run_mode("clipboard_ok")
    def test_clipboard_api_absent_and_throw_fallback(self):
        for mode in ("clipboard_absent","clipboard_throws",
                     "clipboard_fallback"):self.run_mode(mode)
    def test_new_game_or_trade_session_remain_fail_closed(self):
        for mode in ("wrong_game","existing_trade","server_changed"):
            self.run_mode(mode)
    def test_duplicate_boot_never_replaces_clipboard_or_gui(self):
        self.run_mode("duplicate_run")
if __name__=="__main__":
    unittest.main()
