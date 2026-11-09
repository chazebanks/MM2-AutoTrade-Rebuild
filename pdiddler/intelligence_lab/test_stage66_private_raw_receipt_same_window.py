"""Stage66 mock actual Lua wrapper, using pinned real Stage65 Lua helper.
The private Stage66 core's raw parser is separately tested for exact source
and syntax, but game/network/profile access is mocked: no live MM2 proof.
"""
import os
import random
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
LUA=ROOT/"pdiddler/new_part4/STAGE66_READONLY_ACCEPT_PRIVATE_RAW_EQUALITY.lua"
CORE=ROOT/"pdiddler/new_part4/STAGE66_ROLE_NEUTRAL_PRIVATE_RAW_SNAPSHOTS.lua"
HELPER=Path(os.environ.get("STAGE66_HELPER_PATH","/tmp/stage66_pinned_helper.lua"))
CORE_PIN="79919f199e616e7d03cec1e8bbcfbb99ae60c099"
HELPER_PIN="27263d7e2fe44a0da842b7062eff7c91c6ea3b65"

HARNESS=r"""
local mode=arg[1] or "success"
local script=arg[2]
local helperFile=arg[3]
local now=0
local callback=nil
local disconnected=0
local coreLoads,helperLoads=0,0
local jobs={}
local clipCount=0
local button=nil
os.clock=function()return now end
warn=function(...)print(...)end
local function node(class)
 local obj={Enabled=true,Visible=true}
 function obj:IsA(typeName)
  return typeName==class
 end
 return obj
end
local pg=node("PlayerGui")
local gui=node("ScreenGui")
local container=node("GuiObject")
local root=node("GuiObject")
local secondGui=node("ScreenGui")
local secondContainer=node("GuiObject")
local secondRoot=node("GuiObject")
local tag={Text="(OTHER_ACCOUNT_PRIVATE)"}
local side={FindFirstChild=function(_,name)
 return name=="Username" and tag or nil
end}
function root:FindFirstChild(name)
 return name=="TheirOffer" and side or nil
end
function secondRoot:FindFirstChild(name)
 return name=="TheirOffer" and side or nil
end
function container:FindFirstChild(name)
 return name=="Trade" and root or nil
end
function secondContainer:FindFirstChild(name)
 return name=="Trade" and secondRoot or nil
end
function gui:FindFirstChild(name)
 return name=="Container" and container or nil
end
function secondGui:FindFirstChild(name)
 return name=="Container" and secondContainer or nil
end
function pg:FindFirstChild(name)
 if name=="TradeGUI" then return gui end
 if name=="TradeGUI_Phone" then return secondGui end
 return nil
end
root.Parent=container
container.Parent=gui
gui.Parent=pg
secondRoot.Parent=secondContainer
secondContainer.Parent=secondGui
secondGui.Parent=pg
gui.Enabled=false
secondGui.Enabled=false
local me={FindFirstChildOfClass=function(_,name)
 return name=="PlayerGui" and pg or nil
end}
local event={IsA=function(_,name)return name=="RemoteEvent" end}
event.OnClientEvent={Connect=function(_,fn)
 callback=fn
 return {Disconnect=function()disconnected=disconnected+1 end}
end}
local trade={FindFirstChild=function(_,name)
 if mode=="no-remote" then return nil end
 return name=="AcceptTrade" and event or nil
end}
local rs={FindFirstChild=function(_,name)
 return name=="Trade" and trade or nil
end}
local http={JSONEncode=function(_,r)
 return "status="..tostring(r.status)
  ..";rawEquality="..tostring(r.privateRawKeyEqualityObserved)
  ..";rawStatus="..tostring(r.privateRawEqualityStatus)
  ..";helperReason="..tostring(r.privateRawEqualityReason)
  ..";clientFlag="..tostring(r.clientCompatibleFlagPattern)
  ..";terminal="..tostring(r.coreTerminal)
  ..";eventCount="..tostring(#r.samples)
  ..";callbackType1="..tostring(r.callbackRowFieldTypes[1])
  ..";callbackType2="..tostring(r.callbackRowFieldTypes[2])
  ..";callbackType3="..tostring(r.callbackRowFieldTypes[3])
  ..";serverCompletionProven="..tostring(r.serverCompletionProven)
  ..";mayUseForStrategyLearning="..tostring(r.mayUseForStrategyLearning)
end}
game={
 PlaceId=mode=="wrong-game" and 123 or 142823291,
 JobId="mock-job",
 GetService=function(_,name)
  if name=="ReplicatedStorage" then return rs end
  if name=="HttpService" then return http end
  if name=="Players" then return {LocalPlayer=me} end
  return nil
 end,
 HttpGet=function(_,url,unused)
  if url:find("p4_stage65_private_raw_receipt_equality.lua",1,true) then
   assert(url:find("27263d7e2fe44a0da842b7062eff7c91c6ea3b65",1,true))
   helperLoads=helperLoads+1
   if mode=="no-helper" then return nil end
   local f=assert(io.open(helperFile,"rb"))
   local text=f:read("*a")
   f:close()
   return text
  end
  assert(url:find("STAGE66_ROLE_NEUTRAL_PRIVATE_RAW_SNAPSHOTS.lua",1,true))
  assert(url:find("79919f199e616e7d03cec1e8bbcfbb99ae60c099",1,true))
  coreLoads=coreLoads+1
  if mode=="no-core" then return nil end
  return [[
    local private="PRIVATE_RAW_WEAPON_KEY"
    local S={state="AWAIT_MANUAL_TRADE",reportReady=false,
      privateRawSnapshots={
       before={[private]=1,Other=3,Another=8},
       post1={[private]=2,Other=3,Another=8},
       post2={[private]=2,Other=3,Another=8}
      }
    }
    task.spawn(function()
     task.wait(.33)
     S.state="OBSERVING_CLOSE"
     task.wait(1.02)
     S.state="POST_CLOSE_READS"
     task.wait(2.4)
     S.result={
      schema="gingerscope-stage32-readonly-result-correlation-v1",
      status="ELIGIBLE_DELTA_WITHOUT_RESULT_NAMED_RECEIPT",
      stopReason="TWO_POST_CLOSE_READS_FINISHED",
      beforeObserved=true,windowClosureObserved=true,
      postReadbacksObserved=2,closureStatus="closed_unknown",
      gainedEligibleCopies=1,lostEligibleCopies=0,
      changedEligibleTypes=1,rawWeaponInventoryChanged=true,
      partnerCacheAtBaseline=true,readOnly=true,tradeOutcome="UNKNOWN",
      serverCompletionProven=false,mayRecordCompletedTrade=false,
      authorizesAccept=false
     }
     local m=_G.STAGE66_MODE
     if m=="no-gain" then S.result.gainedEligibleCopies=0
     elseif m=="bad-core-flag" then S.result.serverCompletionProven=true
     elseif m=="stale-core" then S.result.status="INCOMPLETE"
     elseif m=="raw-mismatch" then
      S.privateRawSnapshots.post2[private]=3
     elseif m=="raw-disagree" then
      S.privateRawSnapshots.post1[private]=3
     elseif m=="raw-extra-change" then
      S.privateRawSnapshots.post1.Other=2
      S.privateRawSnapshots.post2.Other=2
     elseif m=="raw-unavailable" then S.privateRawSnapshots={}
     end
     S.reportReady=true
     S.state="FINISHED_READ_ONLY"
    end)
    return S
  ]] .. string.rep("\n-- fixture size; native source has >18000 bytes",200)
 end
}
local env={}
if mode=="old-owner" then env.PDIDDLER_STAGE32_RESULT_CORRELATION_PROBE={} end
getgenv=function()return env end
loadstring=function(text,name)return load(text,name)end
task={
 spawn=function(fn)
  jobs[#jobs+1]={co=coroutine.create(fn),wake=now}
 end,
 wait=function(dt)return coroutine.yield(dt or .1)end
}
_G.STAGE66_MODE=mode
local output=dofile(script)
assert(type(output)=="table")
local fired={}
local function fire(kind)
 if fired[kind] or not callback then return end
 fired[kind]=true
 if kind=="false" then callback(false)
 elseif kind=="true" then
  local raw=(mode=="wrong-callback-key" and "PRIVATE_WRONG")
       or "PRIVATE_RAW_WEAPON_KEY"
  local cat=(mode=="wrong-category" and "Pets") or "Weapons"
  local qty=(mode=="wrong-qty" and 2) or 1
  if mode=="extra-field" then
   callback(true,{{raw,qty,cat,"SECRET_VALUE"}})
  elseif mode=="bad-element-types" then
   callback(true,{{123,"1",cat}})
  else
   callback(true,{{raw,qty,cat}})
  end
 elseif kind=="true-only" then
  callback(true,{{"PRIVATE_RAW_WEAPON_KEY",1,"Weapons"}})
 elseif kind=="reverse" then
  callback(true,{{"PRIVATE_RAW_WEAPON_KEY",1,"Weapons"}})
 elseif kind=="niltrue" then callback(true)
 end
end
for i=1,540 do
 if now>=.33 and now<1.35 then gui.Enabled=true else gui.Enabled=false end
 if mode=="two-guis" and now>=.9 and now<1.35 then secondGui.Enabled=true
 else secondGui.Enabled=false end
 if mode=="partner-changed" and now>=.95 then tag.Text="(REPLACED)" end
 if mode=="job-changed" and now>=1.05 then game.JobId="OTHER" end
 if now>=.84 and mode~="no-events" and mode~="true-only" and
    mode~="reverse" then fire("false") end
 if mode=="reverse" and now>=.84 then fire("reverse") end
 if now>=1.04 and mode~="no-events" and mode~="false-only" and
    mode~="race-close" and mode~="reverse" then
   if mode=="nil-second" then fire("niltrue") else fire("true") end
 end
 if mode=="race-close" and now>=1.39 then fire("true") end
 if mode=="true-only" and now>=1.04 then fire("true-only") end
 if mode=="reverse" and now>=1.04 then fire("false") end
 for _,job in ipairs(jobs) do
  if job.wake<=now and coroutine.status(job.co)~="dead" then
   local ok,delay=coroutine.resume(job.co)
   assert(ok,delay)
   job.wake=now+(tonumber(delay) or .08)
  end
 end
 now=now+.01
end
assert(output.status~="OBSERVING" and output.status~="INITIALIZING")
assert(disconnected<=1)
assert(output.serverCompletionProven==false)
assert(output.serverAttestation==false)
assert(output.eventSessionAssociationProven==false)
assert(output.causalTradeAttributionProven==false)
assert(output.exactWeaponIdentityConfirmed==false)
assert(output.exactCallbackWeaponKeyIdentityProven==false)
assert(output.mayUseForStrategyLearning==false)
assert(output.mayRecordCompletedTrade==false)
assert(output.mayRecordRejectedTrade==false)
assert(output.mayReportProfit==false)
assert(output.authorizesAccept==false)
assert(output.authorizesTrade==false)
assert(output.tradeOutcome=="UNKNOWN")
assert(helperLoads<=1 and coreLoads<=1)
local leaks={"PRIVATE_RAW_WEAPON_KEY","PRIVATE_WRONG","SECRET_VALUE"}
for k,v in pairs(output) do
 if type(v)~="table" then
  for _,private in ipairs(leaks) do
   assert(not tostring(v):find(private,1,true))
  end
 end
end
local success=mode=="success" or mode=="race-close"
if success then
 assert(output.status=="CLIENT_RAW_RECEIPT_EQUALS_OWN_GAIN_UNATTRIBUTED",
   "expected private exact match, got "..tostring(output.status))
 assert(output.privateRawKeyEqualityObserved==true)
 assert(output.callbackRowFieldTypes[1]=="string")
 assert(output.callbackRowFieldTypes[2]=="number")
 assert(output.callbackRowFieldTypes[3]=="string")
elseif mode=="wrong-callback-key" or mode=="wrong-category"
   or mode=="wrong-qty" or mode=="extra-field" or
   mode=="bad-element-types" or mode=="raw-mismatch"
   or mode=="raw-disagree" or mode=="raw-extra-change"
   or mode=="raw-unavailable" then
 assert(output.status=="CLIENT_SUCCESS_LIKE_RAW_KEY_UNRESOLVED",
   "expected local client unresolved")
 assert(output.privateRawKeyEqualityObserved==false)
else
 assert(output.privateRawKeyEqualityObserved==false)
end
print("STAGE66_TEST mode="..mode.." status="..output.status..
 " rawEquality="..tostring(output.privateRawKeyEqualityObserved)..
 " helperLoads="..helperLoads.." coreLoads="..coreLoads..
 " listenerDisconnects="..disconnected)
"""
class Stage66NativeWrapperTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.lua=shutil.which("lua5.4")
        if not cls.lua:
            raise RuntimeError("Install Lua5.4 to test the actual Stage66 wrapper")
        if not HELPER.exists():
            raise RuntimeError(f"Missing pinned Stage65 helper at {HELPER}")
        cls.temp=tempfile.TemporaryDirectory(prefix="stage66_mock_")
        cls.harness=Path(cls.temp.name)/"harness.lua"
        cls.harness.write_text(HARNESS,encoding="utf-8")
    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()
    def run_case(self,mode):
        r=subprocess.run([self.lua,str(self.harness),mode,str(LUA),str(HELPER)],
                         capture_output=True,text=True,timeout=8)
        self.assertEqual(r.returncode,0,(mode,r.stdout[-1700:],r.stderr[-1700:]))
        self.assertIn("[GINGERSCOPE STAGE66 SAME WINDOW]",r.stdout)
        self.assertIn("serverCompletionProven=false",r.stdout)
        self.assertIn("mayUseForStrategyLearning=false",r.stdout)
        for secret in ("PRIVATE_RAW_WEAPON_KEY","PRIVATE_WRONG","SECRET_VALUE"):
            self.assertNotIn(secret,r.stdout)
        return r.stdout
    def test_actual_lua_syntax_and_no_new_remote_invocations(self):
        for path in (LUA, CORE, HELPER):
            result=subprocess.run(["luac5.4","-p",str(path)],
                                  capture_output=True,text=True)
            self.assertEqual(result.returncode,0,(path,result.stderr))
        src=LUA.read_text(encoding="utf-8")
        self.assertIn(CORE_PIN,src)
        self.assertIn(HELPER_PIN,src)
        for x in (":FireServer(",":InvokeServer(",":GetProfileData(",
                  "getOwnInventory(", "DiscordWebhook", "setclipboard(reportLine)"):
            self.assertNotIn(x,src)
        self.assertIn("event.OnClientEvent:Connect(onAccept)",src)
    def test_true_client_private_raw_equality_without_settlement(self):
        for mode in ("success","race-close"):
            with self.subTest(mode=mode):
                out=self.run_case(mode)
                self.assertIn("CLIENT_RAW_RECEIPT_EQUALS_OWN_GAIN_UNATTRIBUTED",out)
                self.assertIn("rawEquality=true helperLoads=1 coreLoads=1",out)
    def test_historical_row_assumption_or_raw_change_rejected(self):
        for mode in ("wrong-callback-key","wrong-category","wrong-qty",
                     "extra-field","bad-element-types","raw-mismatch",
                     "raw-disagree","raw-extra-change","raw-unavailable"):
            with self.subTest(mode=mode):
                out=self.run_case(mode)
                self.assertIn("CLIENT_SUCCESS_LIKE_RAW_KEY_UNRESOLVED",out)
    def test_no_callbacks_fatal_status_or_unsafe_context_fail_closed(self):
        for mode in ("no-events","false-only","true-only","reverse",
                     "nil-second","no-gain","bad-core-flag","stale-core",
                     "two-guis","partner-changed","job-changed"):
            with self.subTest(mode=mode):
                out=self.run_case(mode)
                self.assertNotIn(
                    "STAGE66_TEST mode="+mode+
                    " status=CLIENT_RAW_RECEIPT_EQUALS_OWN_GAIN",out)
    def test_wrong_game_missing_remote_helper_core_and_existing_owner(self):
        for mode in ("wrong-game","no-remote","no-helper","no-core",
                     "old-owner"):
            with self.subTest(mode=mode):
                self.assertIn("status=INCOMPLETE",self.run_case(mode))
    def test_160_seeded_mock_variants_never_authorize_trading(self):
        rng=random.Random(6666)
        modes=("success","race-close","wrong-callback-key","wrong-category",
               "wrong-qty","extra-field","bad-element-types","raw-mismatch",
               "raw-disagree","raw-extra-change","raw-unavailable",
               "no-events","false-only","true-only","reverse","nil-second",
               "no-gain","bad-core-flag","stale-core","two-guis",
               "partner-changed","job-changed")
        for _ in range(160):
            out=self.run_case(rng.choice(modes))
            self.assertNotIn("serverCompletionProven=true",out)
            self.assertNotIn("mayUseForStrategyLearning=true",out)


PARSER_HARNESS=r"""
local mode=arg[1]
local old={seen={"PRIVATE_WEAPONx1","Anotherx3","Ax12x4"},
 rawOwned=8,unmapped=0,badQty=0}
old.fingerprint=table.concat(old.seen,"|")
if mode=="empty" then old.seen={};old.rawOwned=0
elseif mode=="sparse" then old.seen={[1]="PRIVATE_WEAPONx1",[3]="Anotherx3"}
elseif mode=="nonnumeric" then old.seen.X="PRIVATE_WEAPONx1"
elseif mode=="bad-entry" then old.seen[2]="Anotherx?"
elseif mode=="duplicate" then old.seen[2]="PRIVATE_WEAPONx1"
elseif mode=="extra-entry" then old.seen[4]="EXTRAx1"
elseif mode=="bad-total" then old.rawOwned=7
elseif mode=="unmapped" then old.unmapped=1
elseif mode=="bad-qty" then old.badQty=1
elseif mode=="unsafe-raw" then old.seen[2]="\nSECRETx3"
elseif mode=="huge-raw" then old.seen[2]=string.rep("L",129).."x3"
elseif mode=="zero-count" then old.seen[2]="Anotherx0"
elseif mode=="negative-count" then old.seen[2]="Anotherx-1"
elseif mode=="string-syntax" then old.seen[2]="AnotherxONE"
elseif mode=="wrong-fingerprint" then old.fingerprint="not-real"
elseif mode=="bad-metatable" then setmetatable(old.seen,{__index=function()return "x" end})
elseif mode=="fuzz" then
 local n=tonumber(arg[2]) or 0
 local k=n%14
 if k==0 then old.seen[2]=false
 elseif k==1 then old.seen[2]=""
 elseif k==2 then old.seen[2]="Anotherx"
 elseif k==3 then old.seen[2]="Anotherx0"
 elseif k==4 then old.seen[2]="Anotherx-3"
 elseif k==5 then old.seen[4]="ExtraRawx1"
 elseif k==6 then old.unmapped=1
 elseif k==7 then old.badQty=1
 elseif k==8 then old.seen[2]="PRIVATE_WEAPONx1"
 elseif k==9 then old.rawOwned=n%4
 elseif k==10 then old.fingerprint="WRONG"
 elseif k==11 then old.seen[2]=nil
 elseif k==12 then old.seen[2]="Anotherx99999999"
 else old.seen.SECRET="KEY" end
end
-- For invalid mode, update legitimate fingerprint only when testing the
-- raw-token format itself. Otherwise the fingerprint mismatch is sufficient.
if mode~="wrong-fingerprint" and mode~="sparse" and mode~="nonnumeric"
   and mode~="fuzz" and mode~="bad-metatable" then
 local ok,joined=pcall(function()return table.concat(old.seen,"|")end)
 if ok then old.fingerprint=joined end
end
local parsed,why=stage66PrivateRawOwned(old)
if mode=="valid" then
 assert(type(parsed)=="table" and why==nil)
 assert(parsed.PRIVATE_WEAPON==1 and parsed.Another==3 and parsed.Ax12==4)
else
 assert(parsed==nil,"malformed raw profile must not pass "..mode)
 assert(type(why)=="string")
end
print("STAGE66_PARSER mode="..mode.." accepted="..tostring(parsed~=nil))
"""
class Stage66PrivateScannerRawTokenTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.lua=shutil.which("lua5.4")
        source=CORE.read_text(encoding="utf-8")
        start=source.index("local function stage66PrivateRawOwned(inv)")
        end=source.index("local function readOwn(phase)",start)
        func=source[start:end]
        assert "return result,nil" in func
        cls.temp=tempfile.TemporaryDirectory(prefix="stage66_core_raw_")
        cls.file=Path(cls.temp.name)/"parser.lua"
        cls.file.write_text(func+"\n"+PARSER_HARNESS,encoding="utf-8")
    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()
    def run_parser(self,mode,seed=None):
        command=[self.lua,str(self.file),mode]
        if seed is not None:
            command.append(str(seed))
        result=subprocess.run(command,capture_output=True,text=True,timeout=4)
        self.assertEqual(result.returncode,0,(mode,seed,result.stderr))
        self.assertIn("STAGE66_PARSER mode=",result.stdout)
        self.assertNotIn("PRIVATE_WEAPON",result.stdout)
        return result.stdout
    def test_actual_extracted_raw_parser_valid_and_malformed_variants(self):
        self.assertIn("accepted=true",self.run_parser("valid"))
        for mode in ("empty","sparse","nonnumeric","bad-entry",
                     "duplicate","extra-entry","bad-total","unmapped",
                     "bad-qty","unsafe-raw","huge-raw","zero-count",
                     "negative-count","string-syntax","wrong-fingerprint",
                     "bad-metatable"):
            with self.subTest(mode=mode):
                self.assertIn("accepted=false",self.run_parser(mode))
    def test_120_seeded_raw_parser_invalidity_cases(self):
        rng=random.Random(66066)
        for i in range(120):
            seed=rng.randrange(0,100000000)
            with self.subTest(i=i,seed=seed):
                self.assertIn("accepted=false",self.run_parser("fuzz",seed))

if __name__=="__main__":
    unittest.main()
