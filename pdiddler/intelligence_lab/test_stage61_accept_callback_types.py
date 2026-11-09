"""Stage61: real Lua5.4 mocked incoming AcceptTrade callback shape tests.

These fake Roblox signals prove scope/guard and privacy behavior only.
They do NOT authenticate modern MM2 server result semantics.
"""
import random
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/"pdiddler/new_part4/STAGE61_READONLY_ACCEPT_CALLBACK_TYPES.lua"

HARNESS=r"""
local mode=arg[1] or "success-like"
local src=arg[2]
local now=0
local callbacks={}
local disconnected=0
os.clock=function()return now end
warn=function(...) print(...) end
local root={}
local container={FindFirstChild=function(_,name)
 if name=="Trade" then return root end
 return nil
end}
local gui={Enabled=false,Parent=true,
 FindFirstChild=function(_,name)
  if name=="Container" then return container end
  return nil
 end}
local other={Enabled=false,Parent=true,
 FindFirstChild=function(_,name)
  if name=="Container" then return container end
  return nil
 end}
local pg={FindFirstChild=function(_,name)
 if name=="TradeGUI" then return gui end
 if name=="TradeGUI_Phone" then return other end
 return nil
end}
local lp={FindFirstChildOfClass=function(_,name)
 return name=="PlayerGui" and pg or nil
end}
local players={LocalPlayer=lp}
local event={IsA=function(_,klass)return klass=="RemoteEvent" end}
event.OnClientEvent={Connect=function(_,fn)
 callbacks[#callbacks+1]=fn
 return {Disconnect=function()
   disconnected=disconnected+1
 end}
end}
local trade={FindFirstChild=function(_,name)
 if mode=="missing-event" then return nil end
 return name=="AcceptTrade" and event or nil
end}
local rs={FindFirstChild=function(_,name)
 return name=="Trade" and trade or nil
end}
local http={JSONEncode=function(_,r)
 return "status="..r.status
  ..";eventCount="..#r.events
  ..";total="..r.totalReceipts
  ..";settlement="..tostring(r.serverCompletionProven)
end}
game={PlaceId=mode=="wrong-game" and 999 or 142823291,
 JobId="mock-job-one",
 GetService=function(_,name)
  if name=="Players" then return players end
  if name=="ReplicatedStorage" then return rs end
  if name=="HttpService" then return http end
  return nil
 end}
local fired={}
local function fire(kind)
 if fired[kind] then return end
 fired[kind]=true
 for _,callback in ipairs(callbacks) do
  if kind=="pre" then callback(false)
  elseif kind=="first" then callback(false)
  elseif kind=="last" then callback(true, {{"PRIVATE_WEAPON", 4, "weapon"}})
  elseif kind=="late" then callback(true)
  elseif kind=="injection" then callback(true, {{"SECRET_DO_NOT_LOG"}})
  elseif kind=="nil" then callback()
  elseif kind=="true-first" then callback(true)
  elseif kind=="false-second" then callback(false)
  end
 end
end
task={
 spawn=function(f) f() end,
 wait=function(delta)
  now=now+(delta or .1)
  if mode=="pre-event" and now>=0.1 then fire("pre") end
  if mode~="no-gui" and mode~="wrong-game" and now>=.3 then gui.Enabled=true end
  if mode=="two-guis" and now>=.3 then other.Enabled=true end
  if mode=="changed-root" and now>=1.2 then
   root={}
  end
  if mode=="server-change" and now>=1.2 then game.JobId="elsewhere" end
  if now>=1.0 then
   if mode=="reverse" then fire("true-first")
   elseif mode=="nil" then fire("nil")
   elseif mode=="injection" then fire("injection")
   elseif mode~="no-events" and mode~="post-only" and mode~="overflow" then
    fire("first")
   end
  end
  if mode=="overflow" and now>=1.0 and not fired.overflow then
   fired.overflow=true
   for i=1,18 do
    for _,callback in ipairs(callbacks) do callback(i%2==0) end
   end
  end
  if now>=1.3 then
   if mode=="reverse" then fire("false-second")
   elseif mode=="success-like" or mode=="injection" or
       mode=="pre-event" or mode:find("^fuzz:") then fire("last")
   end
  end
  if mode~="no-gui" and now>=1.5 then
   gui.Enabled=false;other.Enabled=false
  end
  if mode=="post-only" and now>=1.9 then fire("late") end
 end
}
-- Use no fake Instance service: the real Lua observer must retain console
-- fallback if a GUI construction API isn't available.
local report=dofile(src)
assert(type(report)=="table")
assert(disconnected<=1)
assert(report.serverCompletionProven==false)
assert(report.serverAttestation==false)
assert(report.authorizesAccept==false)
assert(report.authorizesTrade==false)
assert(report.mayRecordCompletedTrade==false)
assert(report.mayRecordRejectedTrade==false)
assert(report.mayReportProfit==false)
assert(report.mayUseForStrategyLearning==false)
assert(report.tradeOutcome=="UNKNOWN")
for _,sample in ipairs(report.events) do
 for k,v in pairs(sample) do
  assert(not tostring(v):find("PRIVATE_WEAPON",1,true))
  assert(not tostring(v):find("SECRET_DO_NOT_LOG",1,true))
  assert(not tostring(v):find("mock-job-one",1,true))
 end
end
print("TEST_FINAL status="..report.status
 ..";reason="..report.reason
 ..";bound="..tostring(report.guiStableBound)
 ..";closed="..tostring(report.guiClosedObserved)
 ..";events="..tostring(#report.events)
 ..";scoped="..tostring(report.scopedEventCount)
 ..";unbound="..tostring(report.unboundEventCount)
 ..";true="..tostring(report.hadTypeTrue)
 ..";false="..tostring(report.hadTypeFalse)
 ..";compatible="..tostring(report.historicalClientFlagHypothesisCompatible)
 ..";disconnected="..tostring(report.listenersDisconnected)
 ..";discarded="..tostring(report.discardedReceipts))
"""

class Stage61TypeOnlyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.exe=shutil.which("lua5.4") or shutil.which("lua")
        if not cls.exe:
            raise RuntimeError("Stage61 requires installed Lua5.4")
        cls.dir=tempfile.TemporaryDirectory(prefix="stage61_lua_")
        cls.mock=Path(cls.dir.name)/"mock.lua"
        cls.mock.write_text(HARNESS,encoding="utf-8")

    @classmethod
    def tearDownClass(cls):
        cls.dir.cleanup()

    def run_mock(self,mode):
        proc=subprocess.run([self.exe,str(self.mock),mode,str(SOURCE)],
                            capture_output=True,text=True,timeout=9)
        self.assertEqual(proc.returncode,0,(mode,proc.stdout,proc.stderr))
        self.assertIn("[GINGERSCOPE STAGE61 ACCEPT CALLBACK]",proc.stdout)
        self.assertIn("settlement=false",proc.stdout)
        self.assertIn("TEST_FINAL status=",proc.stdout)
        return proc.stdout

    def test_offline_lua_compiles_and_never_invokes_game_actions(self):
        parser=shutil.which("luac5.4") or shutil.which("luac")
        if parser:
            p=subprocess.run([parser,"-p",str(SOURCE)],capture_output=True,text=True)
            self.assertEqual(p.returncode,0,p.stderr)
        s=SOURCE.read_text()
        for forbidden in (":FireServer(",":InvokeServer(",":InvokeClient(",
                          ":FireClient(",":GetFullInventory(",":GetProfileData(",
                          "game:HttpGet(", ".UserId", "getconnections(",
                          "hookmetamethod(","function safeToken"):
            self.assertNotIn(forbidden,s)
        self.assertIn("remote.OnClientEvent:Connect(collect)",s)
        self.assertIn('copy.Activated:Connect(function()',s)
        self.assertIn("M.status==\"INITIALIZING\"",s)
        self.assertIn('tradeOutcome="UNKNOWN"',s)

    def test_historical_false_then_true_callback_pattern_is_client_only(self):
        out=self.run_mock("success-like")
        self.assertIn("status=CLIENT_CALLBACK_SHAPES_CAPTURED_UNATTRIBUTED",out)
        self.assertIn("bound=true",out)
        self.assertIn("closed=true",out)
        self.assertIn("scoped=2",out)
        self.assertIn("true=true",out)
        self.assertIn("false=true",out)
        self.assertIn("compatible=true",out)
        self.assertIn("disconnected=1",out)
        self.assertNotIn("PRIVATE_WEAPON",out)

    def test_reverse_true_then_false_must_not_match_historical_pattern(self):
        out=self.run_mock("reverse")
        self.assertIn("compatible=false",out)
        self.assertIn("scoped=2",out)

    def test_unbound_and_missing_callbacks_never_mint_completion(self):
        out=self.run_mock("pre-event")
        self.assertIn("unbound=1",out)
        self.assertIn("compatible=true",out)
        out=self.run_mock("no-events")
        self.assertIn("status=NO_BOUND_ACCEPT_CALLBACK_RECEIPTS",out)
        self.assertIn("compatible=false",out)
        out=self.run_mock("post-only")
        self.assertIn("status=CLIENT_CALLBACK_SHAPES_CAPTURED_UNATTRIBUTED",out)
        self.assertIn("compatible=false",out)

    def test_invalid_game_root_listener_context_and_bounded_overflow(self):
        out=self.run_mock("wrong-game")
        self.assertIn("reason=WRONG_GAME",out)
        out=self.run_mock("missing-event")
        self.assertIn("reason=ACCEPT_TRADE_EVENT_MISSING",out)
        out=self.run_mock("no-gui")
        self.assertIn("reason=NO_TRADE_GUI_WITHIN_90S",out)
        out=self.run_mock("two-guis")
        self.assertIn("reason=MULTIPLE_TRADE_GUIS",out)
        out=self.run_mock("changed-root")
        self.assertIn("reason=TRADE_ROOT_REPLACED",out)
        out=self.run_mock("server-change")
        self.assertIn("reason=SERVER_CHANGED",out)
        out=self.run_mock("overflow")
        self.assertIn("reason=EVENT_OVERFLOW",out)
        self.assertIn("status=INCOMPLETE",out)

    def test_200_seeded_current_client_payloads_are_never_exported(self):
        rng=random.Random(61061)
        for _ in range(200):
            n=rng.randint(0,10000)
            out=self.run_mock("fuzz:"+str(n))
            self.assertIn("status=CLIENT_CALLBACK_SHAPES_CAPTURED_UNATTRIBUTED",out)
            self.assertNotIn("PRIVATE_WEAPON",out)
            self.assertNotIn("serverCompletionProven=true",out)

if __name__=="__main__":
    unittest.main()
