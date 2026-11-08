"""Stage59 actual Lua role-neutral own baseline binding.

A visible, exact-party trade may start own receipt collection when the
opponent's scanner record is stale/absent. It MUST still reject missing
trade GUI or unknown partner. No offer identification, accepting, settlement
or clipboard authority is gained from this liveness fix.
"""
from pathlib import Path
import subprocess
import shutil
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
NEW=ROOT/"pdiddler/new_part4/STAGE59_RESULT_DELTA_ROLE_NEUTRAL_BASELINE.lua"
OLD=ROOT/"pdiddler/new_part4/STAGE59_RESULT_DELTA_120S_PROBE.lua"

DRIVER=r'''
local newSource,oldSource=arg[1],arg[2]
local text=function(p)
 local f=assert(io.open(p,"r"));local s=f:read("*a");f:close();return s
end
local modules={
 p4_native_observer=[==[
return {new=function(cfg)
 _G.lastOpponentCachePresent=(cfg.opponentInventory~=nil)
 return cfg
end,capture=function(cfg)
 return {tradeOpen=false,session=cfg.session},{}
end}
]==],
 p4_observer_contract=[==[
return {normalize=function()return {},{}end}
]==],
 p4_stage28_accept_timeline=[==[
return {new=function(id,t)return {session=id,startedAt=t}end,
 ingest=function(self,o)
  if o.tradeOpen==false then return "CLOSED_UNKNOWN"end
  return "HOLD"
 end,
 summary=function()return {
  closureStatus="closed_unknown",
  ourAcceptIndicatorEverVisible=false,
  theirAcceptIndicatorEverVisible=false,
  bothAcceptedStableObserved=false,offerMutationAfterAccept=false,
  }end}
]==],
 STAGE59_POSTCLOSE_LEDGER_120S=[==[
return {new=function(sc,t,opt)return {calls=0}end,
 before=function(self,own)
  if type(own)~="table"then return "INCOMPLETE"end
  self.calls=self.calls+1;return "OBSERVED"
 end,
 close=function()return "OBSERVED"end,
 after=function(self,own,t,sc,idx)
  if type(own)~="table" then return "INCOMPLETE"end
  self.calls=self.calls+1;return "OBSERVED"
 end,
 summary=function(self)
  return {
   schema="gingerscope-stage29-post-close-own-inventory-v1",
   status="ELIGIBLE_DELTA_UNATTRIBUTED",
   beforeObserved=self.calls>=1,
   postReadbacksObserved=self.calls-1,
   windowClosureObserved=self.calls>=2,
   changedEligibleTypes=1,
   gainedEligibleCopies=1,lostEligibleCopies=0,
   rawWeaponInventoryChanged=true,
   }
 end}
]==],
 p4_stage30_client_signal_census=[==[
return {
 new=function()return {signals={},signalReceipts=0,postCloseSignalReceipts=0}end,
 catalog=function()return true,"OK"end,
 closed=function()end,
 finish=function(self)self.final=true end,
 summary=function(self)return self end,
 received=function()end,
 partnerDeparture=function()end,
}
]==],
 p4_stage32_result_correlation=[==[
return {evaluate=function()
 return {
  status="ELIGIBLE_DELTA_WITHOUT_RESULT_NAMED_RECEIPT",
  reason="own-inventory-change-cause-unverified",
  completeTradeSignalSeen=false,endTradeSignalSeen=false,
  declineTradeSignalSeen=false,partnerDepartureObserved=false,
  }
 end}
]==],
 STAGE25_SCANNER_ONLY_BOOT=[==[
return {status="SCANNER_ONLY_NO_TRADE_AUTHORITY",
 rawScanner={
  getRecord=function()
   if _G.partnerCacheOK then return _G.partnerRecord end
   return nil
  end,
  getVerificationState=function()
   if _G.partnerCacheOK then return _G.partnerVerification end
   return nil
  end,
  getOwnInventory=function()
   return {own=true}
  end,
 }}
]==],
}
local currentTime=0
local realClock=os.clock
os.clock=function()
 currentTime=currentTime+0.2
 return currentTime
end
local oldPrint=print
print=function()end
local clipboardCopies=0
local function signal()
 return {Connect=function(_,fn)
  return {Disconnect=function()end}
 end}
end
local function scenario(path,cached,guiShown,partnerKnown,oldSourceCase)
 local env={}
 getgenv=function()return env end
 _G.partnerCacheOK=cached
 _G.lastOpponentCachePresent=nil
 local calls=0
 setclipboard=function()clipboardCopies=clipboardCopies+1 end
 local players={PlayerRemoving=signal()}
 local me={Name="main-account",UserId=101,Parent=players}
 local partner={Name="venossgaming90190",UserId=202,Parent=players}
 _G.partnerRecord={player=partner,inv={fingerprint="anon"},scanProof={
  jobId="ANON_LOCAL_JOB",playerUserId=202,fingerprint="anon",
  completedAtMono=currentTime}}
 _G.partnerVerification={player=partner,record=_G.partnerRecord,
  scanning=false,retryScheduled=false}
 players.LocalPlayer=me
 function players:GetPlayers()return {me,partner}end
 function players:GetPlayerByUserId(n)if n==202 then return partner end end
 local pg={Name="PlayerGui"}
 function pg:IsA()return false end
 local screen={Name="TradeGUI",Enabled=true,Parent=pg}
 function screen:IsA(name)return name=="ScreenGui"end
 local container={Name="Container",Parent=screen,Visible=true}
 function container:IsA(name)return name=="GuiObject"end
 local root={Name="Trade",Parent=container,Visible=true}
 function root:IsA(name)return name=="GuiObject"end
 local side={Name="TheirOffer"}
 local username={Text=partnerKnown and "(venossgaming90190)" or "(UNKNOWN_PLAYER)"}
 function side:FindFirstChild(name)
  if name=="Username"then return username end
 end
 function root:FindFirstChild(name)
  if name=="TheirOffer"then return side end
 end
 function container:FindFirstChild(name)
  if name=="Trade"and guiShown then return root end
 end
 function screen:FindFirstChild(name)
  if name=="Container"then return container end
 end
 function pg:FindFirstChild(name)
  if name=="TradeGUI"then return screen end
 end
 function me:FindFirstChildOfClass(name)
  if name=="PlayerGui"then return pg end
 end
 local events={}
 for _,name in ipairs({"CompleteTrade","EndTrade","DeclineTrade"})do
  events[#events+1]={Name=name,IsA=function(_,kind)
   return kind=="RemoteEvent"
  end,OnClientEvent=signal()}
 end
 local tradeFolder={GetDescendants=function()return events end}
 local replicated={FindFirstChild=function(_,name)
  if name=="Trade"then return tradeFolder end
 end}
 local jsonOut=0
 game={
  PlaceId=142823291,JobId="ANON_LOCAL_JOB",
  GetService=function(_,name)
   if name=="Players"then return players end
   if name=="ReplicatedStorage"then return replicated end
   if name=="HttpService"then
    return {JSONEncode=function(_,v)jsonOut=jsonOut+1;return "{}" end}
   end
  end,
  HttpGet=function(_,url)
   for name,code in pairs(modules)do
    if url:find("/"..name..".lua",1,true) then
     return code.."\n--"..string.rep("f",100)
    end
   end
   error("unexpected source: "..tostring(url))
  end
 }
 task={spawn=function(fn)fn()end,wait=function(seconds)
  currentTime=currentTime+(seconds or 0.2)
 end}
 loadstring=load
 local ok,state=pcall(function()return assert(loadfile(path))()end)
 assert(ok,state)
 assert(type(state)=="table")
 if oldSourceCase then
  assert(state.reportReady==true and
   state.result.stopReason=="NO_SCANNED_TRADE_WINDOW_OR_JOB_CHANGED",
   "original 120s source should stay READY when opponent cache is stale")
  assert(clipboardCopies==1,"old source had an unsafe nested auto-copy")
  return state
 elseif not guiShown then
  assert(state.reportReady==true and
   state.result.stopReason=="NO_SCANNED_TRADE_WINDOW_OR_JOB_CHANGED",
    "without trade GUI must never start a false baseline")
  assert(state.partnerCacheAtBaseline==nil)
  assert(state.awaitReason=="NO_VISIBLE_TRADE")
 elseif not partnerKnown then
  assert(state.reportReady==true and
   state.result.stopReason=="NO_SCANNED_TRADE_WINDOW_OR_JOB_CHANGED",
    "unmatched display label must never bind baseline")
  assert(state.partnerCacheAtBaseline==nil)
  assert(state.awaitReason=="PARTNER_LABEL_UNRESOLVED")
 else
  assert(state.reportReady==true and
   state.result.stopReason=="TWO_POST_CLOSE_READS_FINISHED",
    "visible exact trade must collect terminal own before/after. stop="..
     tostring(state.result and state.result.stopReason).." status="..
     tostring(state.result and state.result.status))
  assert(state.partnerCacheAtBaseline==cached,
    "cache presence must be reflected, not invented")
  assert(state.result.partnerCacheAtBaseline==cached)
  assert(state.result.postReadbacksObserved==2)
  assert(_G.lastOpponentCachePresent==cached,
    "native observer must know opponent inventory is unavailable")
  assert(state.result.serverCompletionProven==false)
  assert(state.result.authorizesAccept==false)
  assert(state.result.mayReportProfit==false)
  assert(state.result.tradeOutcome=="UNKNOWN")
 end
 assert(clipboardCopies==0,"passive observer must never write OS clipboard")
 return state
end
local function test(label,fn)
 local ok,why=pcall(fn)
 if not ok then error(label..": "..tostring(why))end
end
test("stale opponent inventory, exact recipient",function()
 scenario(newSource,false,true,true)
end)
test("fresh verified opponent cache, exact recipient",function()
 scenario(newSource,true,true,true)
end)
test("missing window prevents binding",function()
 scenario(newSource,false,false,true)
end)
test("unknown partner prevents binding",function()
 scenario(newSource,false,true,false)
end)
-- The old Stage59-only observer must reproduce the root cause: it never
-- binds without the other player's current scanner record.
test("old source exact root cause control",function()
 scenario(oldSource,false,true,true,true)
end)
oldPrint("STAGE59_ROLE_NEUTRAL_BASELINE_REAL_LUA_5_CASES_PASS")
'''
class Stage59RoleNeutralBaselineTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("lua5.4"),"CI installs Lua5.4")
    def test_actual_lua_role_neutral_baseline_guards(self):
        with tempfile.TemporaryDirectory(prefix="stage59_role_neutral_") as td:
            drv=Path(td)/"driver.lua";drv.write_text(DRIVER)
            out=subprocess.run(["lua5.4",str(drv),str(NEW),str(OLD)],
                               cwd=ROOT,text=True,capture_output=True,timeout=50)
        self.assertEqual(out.returncode,0,out.stdout+"\n"+out.stderr)
        self.assertIn("STAGE59_ROLE_NEUTRAL_BASELINE_REAL_LUA_5_CASES_PASS",out.stdout)
    def test_source_tiny_diff_and_immutable_economic_limits(self):
        source=NEW.read_text()
        original=OLD.read_text()
        self.assertIn('if root and partner then',source)
        self.assertIn('local their=(root and partner) and partnerInventory(partner) or nil',source)
        self.assertIn('if root and partner and their then',original)
        self.assertIn('S.partnerCacheAtBaseline=(their~=nil)',source)
        self.assertIn('S.awaitReason="PARTNER_LABEL_UNRESOLVED"',source)
        self.assertIn('data.partnerCacheAtBaseline=S.partnerCacheAtBaseline',source)
        self.assertNotIn('pcall(setclipboard,json)',source)
        for token in ("serverCompletionProven=false","authorizesTrade=false",
                      "authorizesAccept=false","mayReportProfit=false"):
            self.assertIn(token,source)
        for unsafe in (":FireServer(",":InvokeServer(",":PostAsync(",
                       "TeleportToPlaceInstance("):
            self.assertNotIn(unsafe,source)
if __name__=="__main__":
    unittest.main()
