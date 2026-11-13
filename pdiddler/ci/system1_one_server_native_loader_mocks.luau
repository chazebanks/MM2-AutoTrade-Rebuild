-- Execute actual combined single-server loader under Lune's fake Roblox job.
-- This is specifically about orchestration, immutable sources and terminal
-- receipt. Distinct proven Step1/Step2 original guarded remotes are covered
-- by their individual sibling native tests.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local native=fs.readFile("pdiddler/system1/SYSTEM1_ONE_SERVER_COMBINED_NATIVE.lua")
local controller=fs.readFile(
 "pdiddler/system1/system1_one_server_transition_controller.lua")
local tests=0
local function eq(a,b,why)
 tests+=1
 assert(a==b,why..": "..tostring(a).." vs "..tostring(b))
end
local function passedStep1()
 local names={"ALT_REPLACES_ITEM","ALT_STACK_X1_TO_X2","ALT_CLEAR_THEN_NEW"}
 local rounds={}
 for i,name in ipairs(names)do
  rounds[i]={round=i,scenarioId=name,
    status="CLIENT_SEQUENCE_PASS",clientWindowClosed=true}
 end
 return{
  status="CLIENT_TEST_SEQUENCE_COMPLETE",phase="DONE",
  reason="ALL_THREE_RECOVERY_CLIENT_SCENARIOS_VERIFIED",
  completedRounds=3,maxRounds=3,recoveryBatchAuthorized=true,
  authorizesAccept=false,finalAcceptEverAttempted=false,
  serverCompletionProven=false,verifiedCompletedTrades=0,
  possibleSideEffect=false,rounds=rounds,
  actions={requestsStarted=3,offersClientVisible=6,
   removalsAttempted=6,declinesAttempted=3,
   clientClosedWindows=3,adaptiveReoffersAttempted=3},
 }
end
local function passedStep2()
 return{
  status="PUBLIC_CLIENT_ROTATION_HANDOFF_PASS",phase="DONE",
  reason="TWO_DISTINCT_CONTACTS_AND_BOUND_CLIENT_CLOSE_PROVEN",
  targetBudget=3,attemptedDistinctContacts=3,
  provenBoundClientCloses=2,
  publicRequestDiagnostic={originalP3SentConfirmed=3},
  authorizesAccept=false,authorizesOffer=false,
  finalAcceptEverAttempted=false,actualOffers=0,actualTeleports=0,
  serverCompletionProven=false,verifiedCompletedTrades=0,
  possibleSideEffect=false,
 }
end
local STEP1=[[
local E=getgenv()
E.TEST_LOAD_SEQUENCE[#E.TEST_LOAD_SEQUENCE+1]="STAGE1"
return {
 status=function()return E.TEST_STAGE1_STATE end,
 stop=function()E.TEST_STEP1_STOP_COUNT+=1;return true end,
}
]]
local STEP1_FAIL=[[
local E=getgenv()
local H=game:GetService("HttpService")
E.PDIDDLER_SYSTEM1_MAIN_AUTO_LAST_JSON=H:JSONEncode({
 schema="gingerscope-system1-step1-alt-recovery-native-v1",
 status="STOPPED",phase="SETUP",reason="OWN_PROFILE_READ_TIMEOUT",
 round=0,completedRounds=0,lastAction="BEFORE_ARM",
 possibleSideEffect=false,
})
return nil
]]
local STEP2=[[
local E=getgenv()
local token=E.PDIDDLER_SYSTEM1_COMBINED_TRANSITION_TOKEN
if type(token)~="table" or token.used==true or
 token.retiredP3Epoch~=E.PDIDDLER_OUTGOING_SESSION then return nil end
token.used=true
E.TEST_LOAD_SEQUENCE[#E.TEST_LOAD_SEQUENCE+1]="STAGE2"
return {
 status=function()return E.TEST_STAGE2_STATE end,
 stop=function()E.TEST_STEP2_STOP_COUNT+=1;return true end,
}
]]
local function large(script)
 return script..("-- padded immutable fake HTTP response for size gate\n"):rep(400)
end
local function event()return {Connect=function()return {Disconnect=function()end}end}end
local function fakeNode(class,name)
 local n={ClassName=class,Name=name,Parent=nil,children={},
  Enabled=true,Visible=true,Text=""}
 function n:IsA(kind)
  if self.ClassName==kind then return true end
  if kind=="GuiObject" then
   return self.ClassName=="Frame" or self.ClassName=="TextLabel" or
    self.ClassName=="TextButton"
  end
  return false
 end
 function n:FindFirstChild(id)return self.children[id]end
 function n:GetDescendants()
  local out={}
  local function walk(parent)
   for _,v in pairs(parent.children)do
    out[#out+1]=v;walk(v)
   end
  end
  walk(self);return out
 end
 function n:add(obj)
  obj.Parent=self
  self.children[obj.Name]=obj
  return obj
 end
 return n
end
local function fixture(options)
 options=options or {}
 local clock=0
 local jobs={}
 local clips={}
 local urls={}
 local prints={}
 local errors={}
 local P={Name="MAIN_CLIENT"}
 function P:IsA(kind)return kind=="Player"end
 local PG=fakeNode("PlayerGui","PlayerGui")
 PG.Parent=P
 function P:FindFirstChildOfClass(kind)
  return kind=="PlayerGui" and PG or nil
 end
 local place=142823291
 local Players={LocalPlayer=P}
 local ALT={Name="venossgaming90190",UserId=2,Parent=Players}
 function Players:FindFirstChild(name)
  if name==ALT.Name and ALT.Parent==self then return ALT end
  return nil
 end
 function Players:GetPlayerByUserId(id)
  if id==ALT.UserId and ALT.Parent==self then return ALT end
  return nil
 end
 local Workspace={CurrentCamera={}}
 local game={
  PlaceId=place,JobId="SAME_TEST_JOB",
  GetService=function(_,name)
   if name=="Players" then return Players end
   if name=="Workspace" then return Workspace end
   if name=="HttpService" then
    return {
     GenerateGUID=function()return "12345678-1234-1234-1234-123456789012"end,
     JSONEncode=function(_,v)return serde.encode("json",v)end,
     JSONDecode=function(_,v)return serde.decode("json",v)end,
    }
   end
  end,
  HttpGet=function(_,url)
   urls[#urls+1]=url
   if url:find("one_server_transition_controller.lua",1,true) then
    return controller
   elseif url:find("SYSTEM1_STEP1_ALT_DYNAMIC_RECOVERY_NATIVE.lua",1,true) then
    return large(options.failStep1 and STEP1_FAIL or STEP1)
   elseif url:find("SYSTEM1_COMBINED_STEP2_BOUND_EPOCH_NATIVE.lua",1,true) then
    return large(STEP2)
   end
   error("Unapproved source")
  end,
 }
 local E={TEST_LOAD_SEQUENCE={},TEST_STAGE1_STATE={phase="PREPARING"},
  TEST_STAGE2_STATE={phase="PREPARING"},
  TEST_STEP1_STOP_COUNT=0,TEST_STEP2_STOP_COUNT=0}
 local env={
  game=game,getgenv=function()return E end,
  os={clock=function()return clock end},
  warn=function(...)errors[#errors+1]={...}end,
  print=function(...)prints[#prints+1]={...}end,
  setclipboard=function(txt)clips[#clips+1]=txt end,
 }
 env.loadstring=function(src)
  return luau.load(src,{environment=env,injectGlobals=true})
 end
 local taskApi={}
 taskApi.spawn=function(fn)
  local co=coroutine.create(fn);jobs[#jobs+1]=co;return co
 end
 taskApi.wait=function(delta)
  return coroutine.yield(delta)
 end
 env.task=taskApi
 local f=luau.load(native,{environment=env,injectGlobals=true})
 local runner=f()
 local function tick()
  clock+=0.25
  local snapshot={}
  for _,co in ipairs(jobs)do snapshot[#snapshot+1]=co end
  for _,co in ipairs(snapshot)do
   if coroutine.status(co)~="dead" then
    local ok,msg=coroutine.resume(co)
    assert(ok,"Combined native coroutine failed: "..tostring(msg))
   end
  end
  local remaining={}
  for _,co in ipairs(jobs)do
   if coroutine.status(co)~="dead" then remaining[#remaining+1]=co end
  end
  jobs=remaining
 end
 return{env=env,global=E,runner=runner,game=game,gui=PG,
  players=Players,alt=ALT,world=Workspace,
  errors=errors,clips=clips,urls=urls,prints=prints,tick=tick}
end
do
 local x=fixture()
 eq(type(x.runner),"table","combined native loader constructed")
 eq(#x.urls,1,"no trade script loaded at cold startup")
 eq(x.runner.status().phase,"PREPARING","preflight starts read-only")
 eq(x.global.TEST_LOAD_SEQUENCE[1],nil,"no Stage1 before stable ALT")
 for _=1,5 do x.tick()end
 eq(x.runner.status().phase,"STEP1","stable ALT, GUI and camera allow Step1")
 eq(#x.urls,2,"original Step1 source loaded once after readiness")
 eq(x.global.TEST_LOAD_SEQUENCE[1],"STAGE1","Step1 first")
 eq(x.global.TEST_LOAD_SEQUENCE[2],nil,"no Step2 prefetch/execution")
 x.global.TEST_STAGE1_STATE=passedStep1()
 x.global.PDIDDLER_OUTGOING_SESSION=8
 x.global.PDIDDLER_SYSTEM1_STEP1_RECOVERY_USED_JOB=x.game.JobId
 for _=1,8 do x.tick()end
 eq(x.runner.status().phase,"STEP2","same JobId transition succeeds")
 eq(x.global.TEST_LOAD_SEQUENCE[2],"STAGE2","Step2 source loaded second")
 eq(#x.urls,3,"only two pinned scripts plus pure controller downloaded")
 eq(x.global.PDIDDLER_OUTGOING_SESSION,8,
  "numeric P3 tombstone never reset/rolled back")
 eq(x.global.PDIDDLER_SYSTEM1_COMBINED_TRANSITION_TOKEN,nil,
  "one-time token consumed and removed")
 eq(x.global.TEST_STEP1_STOP_COUNT,0,"Step1 final remains passed, not cancelled")
 eq(#x.clips,0,"no false completed report before Step2")
 x.global.TEST_STAGE2_STATE=passedStep2()
 x.tick()
 local r=x.runner.status()
 eq(r.status,"ONE_SERVER_SYSTEM1_CLIENT_INTEGRATION_PASS",
  "combined script emits one-server client-only success")
 eq(r.step1ClosedWindows,3,"Step1 3 client closes included")
 eq(r.step2AttemptedDistinctContacts,3,"three public contacts included")
 eq(r.step2VerifiedBoundCloses,2,"two protected P4 closes included")
 eq(r.sameGameJobMaintained,true,"single JobId preserved")
 eq(r.actualTeleports,0,"no hop in runtime")
 eq(r.finalAcceptEverAttempted,false,"no final Accept")
 eq(r.serverCompletionProven,false,"no invented trade settlement")
 eq(#x.clips,1,"clipboard gets one combined summary")
 local report=serde.decode("json",x.clips[1])
 eq(report.runNonce,"12345678-1234-1234-1234-123456789012",
  "sanitized unique run receipt")
 eq(report.status,"ONE_SERVER_SYSTEM1_CLIENT_INTEGRATION_PASS",
  "copied final report matches controller")
 eq(report.gameJobIdNeverReported,true,"never expose exact game JobId")
 eq(x.global.TEST_STEP2_STOP_COUNT,1,"final release closes Step2 owner")
end
do
 local x=fixture()
 for _=1,5 do x.tick()end
 x.global.TEST_STAGE1_STATE=passedStep1()
 x.global.PDIDDLER_OUTGOING_SESSION=8
 x.global.PDIDDLER_SYSTEM1_STEP1_RECOVERY_USED_JOB=x.game.JobId
 x.gui:add(fakeNode("TextLabel","PendingText")).Text="Trade Request Pending"
 for _=1,12 do x.tick()end
 eq(x.runner.status().phase,"QUIESCENCE",
  "visible pending request blocks second P3 session")
 eq(#x.global.TEST_LOAD_SEQUENCE,1,"never send on uncertain old request")
end
do
 local x=fixture()
 for _=1,5 do x.tick()end
 x.global.TEST_STAGE1_STATE=passedStep1()
 x.global.PDIDDLER_OUTGOING_SESSION=8
 x.global.PDIDDLER_SYSTEM1_STEP1_RECOVERY_USED_JOB=x.game.JobId
 local g=x.gui:add(fakeNode("ScreenGui","TradeGUI"))
 g.Enabled=true
 local c=g:add(fakeNode("Frame","Container"))
 c:add(fakeNode("Frame","Trade"))
 for _=1,12 do x.tick()end
 eq(x.runner.status().phase,"QUIESCENCE",
  "still-visible trade root blocks controller handoff")
 eq(#x.global.TEST_LOAD_SEQUENCE,1,"never launch Step2 while trade open")
end
do
 local x=fixture()
 for _=1,5 do x.tick()end
 x.global.TEST_STAGE1_STATE={phase="STOPPED",status="STOPPED"}
 x.tick()
 eq(x.runner.status().status,"STOPPED","first stop prevents public contacts")
 eq(#x.global.TEST_LOAD_SEQUENCE,1,"no second source loaded after fault")
 eq(#x.clips,1,"first terminal diagnostic copied")
end
do
 local x=fixture()
 x.game.JobId="OTHER_SERVER"
 x.tick()
 eq(x.runner.status().status,"STOPPED","server change aborts")
 eq(x.runner.status().reason,"COMBINED_STEP1_PREFLIGHT_NOT_READY",
  "pre-arm job change classified precisely")
 eq(x.runner.status().preflightFailure.reason,"PREFLIGHT_JOB_CHANGED",
  "exact unsafe preflight condition retained")
 eq(#x.global.TEST_LOAD_SEQUENCE,0,"no trader started in changed server")
end

-- Real Step1 already sets its own original terminal JSON on STOP. The
-- combined wrapper must not overwrite the actionable reason with only
-- COMBINED_STEP1_STOPPED, which caused the operator diagnostic blind spot.
do
 local x=fixture()
 for _=1,5 do x.tick()end
 x.global.TEST_STAGE1_STATE={
  status="STOPPED",phase="STOPPED",
  reason="ALT_CHANGED_WHILE_CLEARING_FOR_REOFFER",
  round=2,completedRounds=1,scenarioId="ALT_STACK_X1_TO_X2",
  lastAction="MAIN_REMOVE_OWN_ONE",
  copyAttempted=true,possibleSideEffect=false,
  actions={requestsStarted=2,offersClientVisible=3,
   removalsAttempted=3,declinesAttempted=1,clientClosedWindows=1},
 }
 x.tick()
 local report=x.runner.status()
 eq(report.status,"STOPPED","combined source stops on original child fault")
 eq(report.step1Failure.reason,"ALT_CHANGED_WHILE_CLEARING_FOR_REOFFER",
  "actual loader captures Stage1 source's precise cause")
 eq(report.step1Failure.scenarioId,"ALT_STACK_X1_TO_X2",
  "source round name kept in combined receipt")
 eq(report.step1Failure.completedRounds,1,
  "earlier successful rounds not erased")
 eq(#x.clips,1,"single combined clipboard output")
 local copied=serde.decode("json",x.clips[1])
 eq(copied.step1Failure.reason,report.step1Failure.reason,
  "clipboard contains true child cause, not only generic STOP")
 eq(#x.global.TEST_LOAD_SEQUENCE,1,"no public script launched after Step1 STOP")
end


-- A late ALT joining is a preflight-only event, NEVER a trade retry.
do
 local x=fixture()
 x.alt.Parent=nil
 for _=1,8 do x.tick()end
 eq(x.runner.status().phase,"PREPARING","missing ALT waits before source")
 eq(x.runner.status().reason,"PREFLIGHT_ALT_NOT_PRESENT",
  "no arbitrary ALT substitution")
 eq(#x.global.TEST_LOAD_SEQUENCE,0,"no trade action when ALT absent")
 x.alt.Parent=x.players
 for _=1,5 do x.tick()end
 eq(x.runner.status().phase,"STEP1",
  "stable exact consenting ALT allows original Step1 launch")
 eq(#x.global.TEST_LOAD_SEQUENCE,1,"Stage1 launches exactly once")
end
do
 local x=fixture()
 x.alt.Parent=nil
 for _=1,85 do x.tick()end
 local r=x.runner.status()
 eq(r.status,"STOPPED","ALT never joined before bounded 18-second deadline")
 eq(r.reason,"COMBINED_STEP1_PREFLIGHT_NOT_READY",
  "cannot misreport preflight as completed Stage1 trade")
 eq(r.preflightFailure.reason,"PREFLIGHT_ALT_NOT_PRESENT",
  "precise ALT readiness failure")
 eq(r.preflightFailure.tradeRequestAttempted,false,
  "no request in preflight")
 eq(#x.global.TEST_LOAD_SEQUENCE,0,"did not load original Step1")
 eq(#x.clips,1,"sanitized preflight stop is copied")
end
do
 local x=fixture()
 x.world.CurrentCamera=nil
 for _=1,8 do x.tick()end
 eq(x.runner.status().reason,"PREFLIGHT_CAMERA_NOT_READY",
  "missing camera not treated as trading error")
 eq(#x.global.TEST_LOAD_SEQUENCE,0,"no Step1 without camera")
 x.world.CurrentCamera={}
 for _=1,5 do x.tick()end
 eq(x.runner.status().phase,"STEP1","camera readiness recovered safely")
end
do
 local x=fixture()
 x.gui:add(fakeNode("TextLabel","TradeRequestStatus")).Text=
  "Trade Request Pending"
 for _=1,8 do x.tick()end
 eq(x.runner.status().reason,"PREFLIGHT_REQUEST_POPUP_ACTIVE",
  "pending request means no Step1 yet")
 eq(#x.global.TEST_LOAD_SEQUENCE,0,"preflight never taps Trade")
 x.gui.children.TradeRequestStatus.Parent=nil
 x.gui.children.TradeRequestStatus=nil
 for _=1,5 do x.tick()end
 eq(x.runner.status().phase,"STEP1",
  "after popup clears, stable readiness allows Stage1 once")
end
do
 local x=fixture()
 local g=x.gui:add(fakeNode("ScreenGui","TradeGUI"))
 g.Enabled=true
 g:add(fakeNode("Frame","Container")):add(fakeNode("Frame","Trade"))
 for _=1,8 do x.tick()end
 eq(x.runner.status().reason,"PREFLIGHT_TRADE_WINDOW_ACTIVE",
  "active MM2 trade window blocks Stage1 startup")
 eq(#x.global.TEST_LOAD_SEQUENCE,0,
  "cannot send ALT requests while someone else's trade is open")
 g.Enabled=false
 for _=1,5 do x.tick()end
 eq(x.runner.status().phase,"STEP1","clear UI permits safe startup")
end
do
 local x=fixture()
 x.global.PDIDDLER_AUTOTRADE_ACTIVE=true
 x.tick()
 local r=x.runner.status()
 eq(r.status,"STOPPED","any existing automated trade owner blocks")
 eq(r.preflightFailure.reason,"PREFLIGHT_COMPETING_CONTROLLER",
  "precise competing controller failure")
 eq(#x.global.TEST_LOAD_SEQUENCE,0,"no P3 request on active owner conflict")
end


-- Original Step1 may fail during setup *before* returning the runner.
-- Its first fresh child JSON must survive the combined START failure.
do
 local x=fixture({failStep1=true})
 for _=1,6 do x.tick()end
 local r=x.runner.status()
 eq(r.status,"STOPPED","native combined fails closed if original Step1 returns nil")
 eq(r.reason,"COMBINED_STEP1_PIN_OR_START_FAILED",
  "combined category retained without throwing original error away")
 eq(type(r.step1Failure),"table","child setup error included in combined output")
 eq(r.step1Failure.reason,"OWN_PROFILE_READ_TIMEOUT",
  "real original Step1 setup reason decoded from new sanitized JSON")
 eq(r.step1Failure.phase,"SETUP","correct original setup phase retained")
 eq(r.step1Failure.round,0,"no phantom trade attempt on startup error")
 eq(#x.clips,1,"one combined failure copied")
 local copied=serde.decode("json",x.clips[1])
 eq(copied.step1Failure.reason,"OWN_PROFILE_READ_TIMEOUT",
  "clipboard includes original internal error")
 eq(#x.global.TEST_LOAD_SEQUENCE,0,
  "no Stage1 controller started after original failure")
end

print("SYSTEM1_ONE_SERVER_NATIVE_LOADER_PASS",tests)
