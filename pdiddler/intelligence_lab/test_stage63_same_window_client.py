"""Stage63: real standalone Lua5.4 wrapper with a MOCK pinned Stage59 core.

Actual Stage59 role-neutral core is independently native-tested in PR104.
This contract tests its public state/result interface and one, shared window;
it does NOT authenticate MM2 settlement or run a real game transfer.
"""
from __future__ import annotations

import random
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
LUA=ROOT/"pdiddler/new_part4/STAGE63_READONLY_CLIENT_ACCEPT_AND_DELTA.lua"
PIN="54b97f65290ce038910436e27600be6a2c4a005e"
CORE_GIT_BLOB="e1324b157126ff3cdc2928595b262e7a64e2150e"

HARNESS=r"""
local mode=arg[1] or "success"
local script=arg[2]
local jobs={}
local now=0
os.clock=function()return now end
warn=function(...)print(...)end
local callback=nil
local disconnected=0
local clipboardWrites=0
local button=nil
local srcCalls=0
local function makeObject(typeName)
 local o={Visible=true,Enabled=true}
 function o:IsA(t)
  return typeName==t or (typeName=="GuiObject" and t=="GuiObject")
 end
 return o
end
local pg=makeObject("PlayerGui")
local gui=makeObject("ScreenGui")
local container=makeObject("GuiObject")
local root=makeObject("GuiObject")
local secondGui=makeObject("ScreenGui")
local secondContainer=makeObject("GuiObject")
local secondRoot=makeObject("GuiObject")
local tag={Text="(ALT-account-not-exported)"}
local side={}
function side:FindFirstChild(n)return n=="Username" and tag or nil end
function root:FindFirstChild(n)return n=="TheirOffer" and side or nil end
function secondRoot:FindFirstChild(n)return n=="TheirOffer" and side or nil end
function gui:FindFirstChild(n)return n=="Container" and container or nil end
function container:FindFirstChild(n)return n=="Trade" and root or nil end
function secondGui:FindFirstChild(n)return n=="Container" and secondContainer or nil end
function secondContainer:FindFirstChild(n)return n=="Trade" and secondRoot or nil end
root.Parent=container;container.Parent=gui;gui.Parent=pg
secondRoot.Parent=secondContainer;secondContainer.Parent=secondGui
secondGui.Parent=pg
gui.Enabled=false;secondGui.Enabled=false
function pg:FindFirstChild(n)
 if n=="TradeGUI" then return gui end
 if n=="TradeGUI_Phone" then return secondGui end
 return nil
end
local me={
 FindFirstChildOfClass=function(_,name)
  return name=="PlayerGui" and pg or nil
 end
}
local players={LocalPlayer=me}
local event={IsA=function(_,typeName)return typeName=="RemoteEvent" end}
event.OnClientEvent={
 Connect=function(_,fn)
  assert(callback==nil)
  callback=fn
  return {Disconnect=function()disconnected=disconnected+1 end}
 end
}
local trade={
 FindFirstChild=function(_,name)
  if mode=="no-remote" then return nil end
  return name=="AcceptTrade" and event or nil
 end
}
local rs={FindFirstChild=function(_,name)
 return name=="Trade" and trade or nil
end}
local http={JSONEncode=function(_,o)
 local row=o.ownReadbacks or {}
 return "status="..tostring(o.status)
  ..";reason="..tostring(o.reason)
  ..";clientPattern="..tostring(o.clientCompatibleFlagPattern)
  ..";sameWindow="..tostring(o.sameBoundWindowClientOnly)
  ..";terminal="..tostring(o.coreTerminal)
  ..";gained="..tostring(row.gainedEligibleCopies)
  ..";lost="..tostring(row.lostEligibleCopies)
  ..";samples="..tostring(#o.samples)
  ..";ignored="..tostring(o.ignoredUnboundReceipts)
  ..";discarded="..tostring(o.discardedReceipts)
  ..";listenerDisconnected="..tostring(o.listenerDisconnected)
  ..";serverCompletionProven="..tostring(o.serverCompletionProven)
  ..";mayUseForStrategyLearning="..tostring(o.mayUseForStrategyLearning)
end}
game={
 PlaceId=mode=="wrong-game" and 999 or 142823291,
 JobId="mock-job",
 GetService=function(_,name)
  if name=="ReplicatedStorage" then return rs end
  if name=="Players" then return players end
  if name=="HttpService" then return http end
  return nil
 end,
 HttpGet=function(_,url,flag)
  srcCalls=srcCalls+1
  assert(url:find("54b97f65290ce038910436e27600be6a2c4a005e",1,true))
  assert(url:find("STAGE59_RESULT_DELTA_ROLE_NEUTRAL_BASELINE.lua",1,true))
  if mode=="core-missing" then return nil end
  return [[
   local S={state="AWAIT_MANUAL_TRADE",reportReady=false}
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
     partnerCacheAtBaseline=false,
     tradeOutcome="UNKNOWN",readOnly=true,serverCompletionProven=false,
     mayRecordCompletedTrade=false,authorizesAccept=false
    }
    if _G.STAGE63_TEST_MODE=="no-gain" then
     S.result.gainedEligibleCopies=0
     S.result.rawWeaponInventoryChanged=false
    elseif _G.STAGE63_TEST_MODE=="two-gains" then
     S.result.gainedEligibleCopies=2
    elseif _G.STAGE63_TEST_MODE=="bad-post-close" then
     S.result.postReadbacksObserved=1
    elseif _G.STAGE63_TEST_MODE=="unsafe-core-flag" then
     S.result.serverCompletionProven=true
    elseif _G.STAGE63_TEST_MODE=="wrong-core-state" then
     S.result.status="INCOMPLETE"
    elseif _G.STAGE63_TEST_MODE=="wrong-core-stop" then
     S.result.stopReason="TIMEOUT"
    end
    S.reportReady=true
    S.state="FINISHED_READ_ONLY"
   end)
   return S
  ]] .. string.rep("\n-- deterministic test fixture padding",220)
 end
}
local env={}
if mode=="older-active" then env.PDIDDLER_STAGE32_RESULT_CORRELATION_PROBE={} end
if mode=="stage61-active" then env.PDIDDLER_STAGE61_ACCEPT_CALLBACK_TYPES={} end
getgenv=function()return env end
loadstring=function(s,name)return load(s,name)end
task={
 spawn=function(fn)
  jobs[#jobs+1]={co=coroutine.create(fn),wake=now}
 end,
 wait=function(t)return coroutine.yield(t or .1)end
}
if mode=="with-gui" or mode=="no-clipboard" then
 UDim2={fromOffset=function(...)return {...}end,new=function(...)return {...}end}
 Color3={fromRGB=function(...)return {...}end}
 Instance={new=function(class)
  local obj={}
  if class=="TextButton" then
   button=obj
   obj.Activated={Connect=function(_,fn)obj.press=fn end}
  end
  return obj
 end}
 if mode=="with-gui" then
  setclipboard=function(text)
   clipboardWrites=clipboardWrites+1
   assert(text:find("[GINGERSCOPE STAGE63 SAME WINDOW]",1,true))
  end
 end
end
_G.STAGE63_TEST_MODE=mode
local report=dofile(script)
assert(type(report)=="table")
local fired={}
local function fire(kind)
 if fired[kind] or type(callback)~="function" then return end
 fired[kind]=true
 if kind=="early" then callback(false)
 elseif kind=="false" then callback(false)
 elseif kind=="true" then callback(true, {{"PRIVATE_ITEM_NAME",1,"PRIVATE_CATEGORY"}})
 elseif kind=="nilsecond" then callback(true)
 elseif kind=="reverse" then callback(true, {{"PRIVATE_ITEM_NAME"}})
 end
end
local limit=5.5
while now<=limit and not (report.status~="INITIALIZING" and
   report.status~="OBSERVING" and not jobs[1]) do
 -- Fake GUI lifecycle follows one manual offer and local close.
 if now>=.33 and now<1.35 then gui.Enabled=true else gui.Enabled=false end
 if mode=="ambiguous-gui" and now>=.9 and now<1.35 then
  secondGui.Enabled=true
 else secondGui.Enabled=false end
 if mode=="changed-partner" and now>=.95 then tag.Text="(OTHER)" end
 if mode=="no-label" and now>=.3 then tag.Text="" end
 if mode=="job-change" and now>=1.0 then game.JobId="different-job" end
 if mode=="pre-accept" and now>=.1 then fire("early") end
 if now>=.81 and mode~="no-events" and
    mode~="true-only" and mode~="reverse" then fire("false") end
 if mode=="reverse" and now>=.81 then fire("reverse") end
 if now>=1.03 and mode~="no-events" and
    mode~="false-only" and mode~="race-close" and
    mode~="late-true" and mode~="reverse" then
  if mode=="nil-second" then fire("nilsecond") else fire("true") end
 end
 if mode=="true-only" and now>=1.03 then fire("true") end
 if mode=="race-close" and now>=1.38 then fire("true") end
 if mode=="late-true" and now>=2.25 then fire("true") end
 if mode=="overflow" and now>=1.07 and not fired.overflow then
  fired.overflow=true
  for i=1,18 do callback(i%2==0) end
 end
 if mode=="reverse" and now>=1.03 then fire("false") end
 for _,job in ipairs(jobs) do
  if job.wake<=now and coroutine.status(job.co)~="dead" then
   local ok,delay=coroutine.resume(job.co)
   assert(ok,delay)
   job.wake=now+(tonumber(delay) or .08)
  end
 end
 now=now+.01
end
if report.status=="OBSERVING" or report.status=="INITIALIZING" then
 error("Stage63 wrapper never reached final status")
end
assert(disconnected<=1)
assert(report.serverCompletionProven==false)
assert(report.serverAttestation==false)
assert(report.eventSessionAssociationProven==false)
assert(report.causalTradeAttributionProven==false)
assert(report.exactWeaponIdentityConfirmed==false)
assert(report.clientReciprocalTransferProven==false)
assert(report.authorizesAccept==false)
assert(report.authorizesTrade==false)
assert(report.mayRecordCompletedTrade==false)
assert(report.mayRecordRejectedTrade==false)
assert(report.mayReportProfit==false)
assert(report.mayUseForStrategyLearning==false)
assert(report.tradeOutcome=="UNKNOWN")
for _,row in ipairs(report.samples) do
 for k,v in pairs(row) do
  assert(not tostring(v):find("PRIVATE_ITEM",1,true))
  assert(not tostring(v):find("OTHER",1,true))
  assert(not tostring(v):find("mock-job",1,true))
 end
end
if mode=="with-gui" then
 assert(button and button.Visible==true)
 assert(clipboardWrites==0,"no spontaneous clipboard writes")
 button.press()
 assert(clipboardWrites==1)
elseif mode=="no-clipboard" then
 assert(button and button.Visible==true)
 assert(clipboardWrites==0)
 button.press()
 assert(clipboardWrites==0)
end
print("STAGE63_TEST state="..report.status
 ..";samples="..#report.samples
 ..";flag="..tostring(report.clientCompatibleFlagPattern)
 ..";core="..tostring(report.coreTerminal)
 ..";stable="..tostring(report.stablePartnerLabel)
 ..";discarded="..tostring(report.discardedReceipts)
 ..";ignored="..tostring(report.ignoredUnboundReceipts)
 ..";disconnect="..tostring(report.listenerDisconnected)
 ..";coreLoads="..srcCalls)
"""

class Stage63OneWindowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.lua=shutil.which("lua5.4")
        if cls.lua is None:
            raise RuntimeError("Real Lua 5.4 needed for Stage63 integration mock")
        cls.temp=tempfile.TemporaryDirectory(prefix="stage63_mock_")
        cls.harness=Path(cls.temp.name)/"harness.lua"
        cls.harness.write_text(HARNESS,encoding="utf-8")

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def run_case(self,mode):
        p=subprocess.run([self.lua,str(self.harness),mode,str(LUA)],
                         capture_output=True,text=True,timeout=8)
        self.assertEqual(p.returncode,0,(mode,p.stdout[-1800:],p.stderr[-1800:]))
        self.assertIn("[GINGERSCOPE STAGE63 SAME WINDOW]",p.stdout)
        self.assertIn("serverCompletionProven=false",p.stdout)
        self.assertIn("mayUseForStrategyLearning=false",p.stdout)
        self.assertNotIn("PRIVATE_ITEM_NAME",p.stdout)
        return p.stdout

    def test_real_lua_compilation_and_immutable_stage59_core_pin(self):
        parse=shutil.which("luac5.4")
        self.assertIsNotNone(parse)
        p=subprocess.run([parse,"-p",str(LUA)],capture_output=True,text=True)
        self.assertEqual(p.returncode,0,p.stderr)
        s=LUA.read_text()
        self.assertIn(PIN,s)
        self.assertIn("STAGE59_RESULT_DELTA_ROLE_NEUTRAL_BASELINE.lua",s)
        for forbidden in (":FireServer(",":InvokeServer(",":FireClient(",
                          ":GetFullInventory(",":GetProfileData(",
                          "getOwnInventory(", ".UserId","DiscordWebhook"):
            self.assertNotIn(forbidden,s)
        self.assertIn("event.OnClientEvent:Connect(onAccept)",s)
        self.assertNotIn("setclipboard(reportLine)",s)

    def test_one_window_true_false_plus_terminal_own_one_gain_only(self):
        out=self.run_case("success")
        self.assertIn("CLIENT_ACCEPT_FLAG_PLUS_OWN_GAIN_SAME_WINDOW_UNATTRIBUTED",out)
        self.assertIn("samples=2;flag=true;core=true;stable=true",out)
        self.assertIn("disconnect=true",out)
        self.assertIn("coreLoads=1",out)

    def test_callback_gui_close_order_may_race_core_poll(self):
        out=self.run_case("race-close")
        self.assertIn("CLIENT_ACCEPT_FLAG_PLUS_OWN_GAIN_SAME_WINDOW_UNATTRIBUTED",out)

    def test_no_delta_and_bad_terminal_readbacks_cannot_promote(self):
        for mode in ("no-gain","two-gains","bad-post-close",
                     "unsafe-core-flag","wrong-core-state","wrong-core-stop"):
            with self.subTest(mode=mode):
                out=self.run_case(mode)
                self.assertIn("STAGE63_TEST state=INCONCLUSIVE",out)

    def test_missing_false_true_reverse_or_no_second_payload(self):
        for mode in ("no-events","false-only","true-only",
                     "reverse","nil-second","late-true"):
            with self.subTest(mode=mode):
                out=self.run_case(mode)
                self.assertIn("STAGE63_TEST state=INCONCLUSIVE",out)

    def test_root_partner_and_join_scope_guards(self):
        for mode in ("changed-partner","ambiguous-gui","no-label",
                     "job-change","pre-accept","overflow"):
            with self.subTest(mode=mode):
                out=self.run_case(mode)
                self.assertNotIn(
                    "STAGE63_TEST state=CLIENT_ACCEPT_FLAG_PLUS_OWN_GAIN",out)

    def test_missing_remote_pinned_core_wrong_game_or_existing_owner(self):
        for mode in ("no-remote","core-missing","wrong-game",
                     "older-active","stage61-active"):
            with self.subTest(mode=mode):
                out=self.run_case(mode)
                self.assertIn("STAGE63_TEST state=INCOMPLETE",out)

    def test_explicit_purple_gui_copy_only_after_completion(self):
        self.assertIn("COPIED current Stage63 report",self.run_case("with-gui"))
        self.assertIn("Clipboard unsupported",self.run_case("no-clipboard"))

    def test_150_seeded_native_simulations_never_gain_authority(self):
        rng=random.Random(6363)
        modes=["success","race-close","no-gain","two-gains",
               "bad-post-close","unsafe-core-flag","wrong-core-state",
               "wrong-core-stop","no-events","false-only","true-only",
               "reverse","nil-second","late-true","changed-partner",
               "ambiguous-gui","no-label","job-change",
               "pre-accept","overflow"]
        for i in range(150):
            mode=rng.choice(modes)
            out=self.run_case(mode)
            self.assertNotIn("serverCompletionProven=true",out,(i,mode))
            self.assertNotIn("mayUseForStrategyLearning=true",out,(i,mode))


if __name__=="__main__":
    unittest.main()
