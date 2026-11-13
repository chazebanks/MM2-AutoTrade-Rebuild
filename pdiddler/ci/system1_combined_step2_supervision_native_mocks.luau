-- Execute combined-only STEP2 native GUI/loader with retired original P3
-- epoch, actual protected Part4 IO and diagnostic first-fault reasons.
-- Derived from known-good standalone fixture, never changes original file.
-- Execute actual STEP2 native GUI/loader/controller, actual frozen public
-- target gate and ORIGINAL protected P4 decline, with fake P3 transport.
-- Independent P3 original request source is tested in sister CI suite.
-- No real Roblox actions, public players, credentials or network.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local native=fs.readFile("pdiddler/system1/SYSTEM1_COMBINED_STEP2_BOUND_EPOCH_NATIVE.lua")
local content={
 geometry=fs.readFile("pdiddler/new_part4/stage100_screen_prompt_overlay.lua"),
 io=fs.readFile("pdiddler/supervised/pdiddler4_tradeio_supervised_v2.lua"),
 bridge=fs.readFile("pdiddler/supervised/supervised_p3_p4_handoff.lua"),
 gate=fs.readFile("pdiddler/system1/system1_step2_public_target_gate.lua"),
 controller=fs.readFile("pdiddler/system1/system1_combined_step2_handoff_controller.lua"),
}
local BOOT=[[
local M={}
function M.new(scanner,factory,coord,bridge,io,players,me,ctx)
 local E=getgenv()
 E.PDIDDLER_OUTGOING_SESSION=(E.PDIDDLER_OUTGOING_SESSION or 0)+1
 local p3=factory.run(scanner,{requiresExplicitStart=true})
 E.STEP2_FAKE_P3=p3
 local active=false
 local sup={}
 function sup.status()return {status=active and
   "P3_SUPERVISOR_ARMED_CLIENT_ONLY" or "P3_SUPERVISOR_PREPARED_NOT_ARMED"} end
 function sup.arm(x)
  if not ctx.onScreenSafe() or not ctx.watchdogReady() or
   x.explicitUserAuthorization~=true or
   x.allowRealP3RequestRotation~=true or
   x.finalAcceptMustRemainManual~=true then return false end
  active=true;return true
 end
 function sup.isP3Paused()return p3.state.paused end
 function sup.currentBoundReadOnly()
  local t=io.trade()
  if not active or not p3.state.paused or not t then return nil end
  local function capture()
   return {status="CLIENT_UNPRICED_TWO_SIDED_SNAPSHOT",
    partnerExactClientBound=true,part3Paused=true,
    part4TradeVisible=true,physicalOwnSlots=0,physicalTheirSlots=0,
    authorizesOffer=false,authorizesAccept=false,
    rawItemIdsAuthenticated=false,pricesAuthenticated=false,
    offerRevisionAuthenticated=false,serverCompletionProven=false,
    tradeOutcome="UNKNOWN"}
  end
  return {capture=capture},{status="P3_BOUND_CANDIDATE_READ_ONLY"}
 end
 function sup.stop()active=false;p3.state.stopped=true;return true end
 return sup,nil
end
return M
]]
local WATCHDOG=[[
local M={}
function M.new(supervisor,p3,io,ctx,scheduler)
 local E=getgenv()
 local started=false
 local last={status="P3_SUPERVISOR_PREPARED_NOT_ARMED",
  reason="OBSERVATION_ATTACHED_NO_OUTGOING_REQUESTS"}
 E.TEST_WATCHDOG_EMIT=function(why)
  last={status="BLOCKED",reason=why}
  ctx.onStatus(last)
 end
 return {
  start=function()started=true;return true end,
  isReady=function()
   return started and E.TEST_WATCHDOG_NOT_READY~=true end,
  status=function()return last end,
  stop=function()started=false;return true end,
 }
end
return M
]]
local P3=[[
local M={}
function M.run(scanner,options)
 local E=getgenv()
 local state={processed={},paused=false,accepted=0,ignored=0,
  declined=0,incomingDeclined=0,sent=0,failStop=false,
  preTradeCardSkipped=0,requestTargetsAttempted=0,
  pendingRequestUiEverConfirmed=false,lastRequestStage="NOT_STARTED",
  lastOutcomeCode="NONE",tradeButtonTapAttempted=false,
  tradeButtonTapReturnedTrue=false}
 return {
  state=state,session=E.PDIDDLER_OUTGOING_SESSION,
  isPaused=function()return state.paused end,
  pendingVisible=function()return false end,
  stop=function()state.stopped=true end,
 }
end
return M
]]
local SCANNER=[[
local M={}
local function players()
 return game:GetService("Players")
end
function M.getWhitelist()
 local ps=players()
 return {ps:GetPlayerByUserId(2),ps:GetPlayerByUserId(3)}
end
function M.isWhitelisted(uid)
 return uid==2 or uid==3
end
function M.getRecord(uid)
 if M.isWhitelisted(uid) then
  return {player=players():GetPlayerByUserId(uid),state="whitelist"}
 end
end
function M.getOwnInventory()return {items={},rawOwned=0}end
function M.setStatus()end
function M.setRequestState()end
function M.hasPendingWork()return false end
return M
]]
local COORD=[[-- Transport intentionally mocked; authoritative source
-- integration path is covered by the separate original P3 source tests.
-- This placeholder must exceed native loader min-length as a real module.
return {new=function()return {}end}
]]
local tests=0
local function eq(a,b,why)
 tests+=1
 assert(a==b,tostring(why)..": "..tostring(a).." vs "..tostring(b))
end
local function event()
 local self={hooks={}}
 function self:Connect(fn)
  self.hooks[#self.hooks+1]=fn
  return {Disconnect=function()end}
 end
 function self:Fire()
  for _,fn in ipairs(self.hooks)do fn()end
 end
 return self
end
local function vec(x,y)return {X=x,Y=y}end
local function node(class,name)
 local n={ClassName=class,Name=name or class,Visible=true,Enabled=true,
  Active=true,Text="",children={},AbsolutePosition=vec(10,10),
  AbsoluteSize=vec(20,15),Activated=event(),MouseButton1Click=event()}
 function n:IsA(k)
  return self.ClassName==k or
   (k=="GuiObject" and
    (self.ClassName=="Frame" or self.ClassName=="TextButton" or
     self.ClassName=="TextLabel" or self.ClassName=="ScrollingFrame"))
 end
 function n:FindFirstChild(name)
  return self.children[name]
 end
 function n:FindFirstChildOfClass(cls)
  for _,v in pairs(self.children)do
   if v.ClassName==cls then return v end
  end
 end
 function n:GetDescendants()
  local r={}
  local function visit(x)
   for _,child in pairs(x.children)do
    r[#r+1]=child;visit(child)
   end
  end
  visit(self);return r
 end
 function n:put(child)
  self.children[child.Name]=child
  child.Parent=self
  return child
 end
 function n:Activate()self.Activated:Fire();return true end
 return n
end
local function fixture(opts)
 opts=opts or {}
 local now=0
 local pending={}
 local clipboard={}
 local calls={}
 local warnings={}
 local pg=node("PlayerGui","PlayerGui")
 local screen=pg:put(node("ScreenGui","TradeGUI"))
 screen.Enabled=false
 local root=screen:put(node("Frame","Container")):put(node("Frame","Trade"))
 root.AbsolutePosition=vec(470,140)
 root.AbsoluteSize=vec(360,416)
 local own=root:put(node("Frame","YourOffer"))
 own:put(node("Frame","Container"))
 own:put(node("Frame","Accepted")).Visible=false
 local theirs=root:put(node("Frame","TheirOffer"))
 theirs:put(node("Frame","Container"))
 theirs:put(node("Frame","Accepted")).Visible=false
 theirs:put(node("TextLabel","Username")).Text="venossgaming90190"
 local players={}
 local main={Name="MAIN_TEST",UserId=1,Parent=players}
 local alt={Name="venossgaming90190",UserId=2,Parent=players}
 local other={Name="PUBLIC_TEST_B",UserId=3,Parent=players}
 players.LocalPlayer=main
 function main:FindFirstChildOfClass(x)
  if x=="PlayerGui" then return pg end
 end
 function players:GetPlayerByUserId(uid)
  if uid==1 then return main end
  if uid==2 then return alt end
  if uid==3 then return other end
 end
 function players:GetPlayers()return {main,alt,other} end
 local RS=node("ReplicatedStorage")
 local trade=RS:put(node("Folder","Trade"))
 local decline=trade:put(node("RemoteEvent","DeclineTrade"))
 local offers=trade:put(node("RemoteEvent","OfferItem"))
 function decline:FireServer()
  calls[#calls+1]="DECLINE"
  screen.Enabled=false
 end
 function offers:FireServer()
  calls[#calls+1]="UNEXPECTED_OFFER"
 end
 local camera={ViewportSize=vec(1024,768)}
 local services={
  Players=players,Workspace={CurrentCamera=camera},
  ReplicatedStorage=RS,
  GuiService={GetGuiInset=function()return vec(0,0)end},
  VirtualInputManager={SendMouseButtonEvent=function()end},
  HttpService={
   GenerateGUID=function()return "00000000-1111-2222-3333-444444444444"end,
   JSONEncode=function(_,payload)return serde.encode("json",payload)end,
  },
 }
 local urls={}
 local sources={
  ["stage100_screen_prompt_overlay.lua"]=content.geometry,
  ["pdiddler4_tradeio_supervised_v2.lua"]=content.io,
  ["supervised_p3_p4_handoff.lua"]=content.bridge,
  ["supervised_real_p3_rotation_handoff.lua"]=COORD,
  ["supervised_p3_startup_supervisor.lua"]=BOOT,
  ["supervised_p3_continuous_watchdog.lua"]=WATCHDOG,
  ["pdiddler3_scanner_MODULE_v6_5_PART4_STATUS_BRIDGE.lua"]=SCANNER,
  ["system1_step2_public_target_gate.lua"]=content.gate,
  ["system1_step2_public_p3_single_send.lua"]=P3,
  ["system1_combined_step2_handoff_controller.lua"]=content.controller,
 }
 local fakeGame={
  PlaceId=142823291,JobId="STEP2_NATIVE_FAKE_JOB",
  GetService=function(_,k)return services[k]end,
  HttpGet=function(_,url)
   urls[#urls+1]=url
   for basename,text in pairs(sources)do
    if url:find(basename,1,true) then return text end
   end
   error("UNAPPROVED_SOURCE")
  end,
 }
 local made={}
 local inst={}
 function inst.new(cls)
  local o=node(cls)
  made[#made+1]=o
  return o
 end
 local env={}
 env.E={
  -- This must be the true original Stage1 retired numeric epoch, never
  -- reset to nil or copied from another JobId.
  PDIDDLER_OUTGOING_SESSION=8,
  PDIDDLER_SYSTEM1_COMBINED_TRANSITION_TOKEN={
    job="STEP2_NATIVE_FAKE_JOB",
    status="STEP1_VERIFIED_CLOSED",
    source="SYSTEM1_COMBINED_PINNED",
    used=false,retiredP3Epoch=8,
  },
 }
 env.game=fakeGame
 env.getgenv=function()return env.E end
 env.Instance=inst
 env.Color3={fromRGB=function(...)return {...}end}
 env.Enum={
  ZIndexBehavior={Sibling="Sibling"},
  TextXAlignment={Left="Left"},
  TextYAlignment={Top="Top"},
  Font={GothamSemibold="GothamSemibold",GothamBold="GothamBold"},
 }
 env.UDim={new=function(...)return {...}end}
 env.UDim2={fromOffset=function(...)return {...}end}
 env.os={clock=function()return now end}
 env.warn=function(...) 
  local vals={}
  for _,v in ipairs({...})do vals[#vals+1]=tostring(v)end
  warnings[#warnings+1]=table.concat(vals," ")
 end
 env.print=function(...)end
 env.setclipboard=function(v)clipboard[#clipboard+1]=v end
 env.loadstring=function(src)
  return luau.load(src,{environment=env,injectGlobals=true})
 end
 local taskApi={}
 taskApi.spawn=function(fn)
  local co=coroutine.create(fn)
  pending[#pending+1]=co
  return co
 end
 taskApi.wait=function(t)return coroutine.yield(t or 0)end
 env.task=taskApi
 local script=luau.load(native,{environment=env,injectGlobals=true})
 local runner=script()
 local function tick()
  now+=0.15
  local batch={}
  for _,co in ipairs(pending)do batch[#batch+1]=co end
  for _,co in ipairs(batch)do
   if coroutine.status(co)~="dead" then
    local ok,err=coroutine.resume(co)
    assert(ok,"Step2 native coroutine fault: "..tostring(err))
   end
  end
  local next={}
  for _,co in ipairs(pending)do
   if coroutine.status(co)~="dead" then next[#next+1]=co end
  end
  pending=next
 end
 local function named(name)
  for _,o in ipairs(made)do
   if o.Name==name then return o end
  end
 end
 return {
  env=env,runner=runner,screen=screen,tick=tick,named=named,
  calls=calls,clipboard=clipboard,urls=urls,warnings=warnings,
 }
end
do
 local x=fixture()
 if type(x.runner)~="table" then
  error("Step2 loader returned nil. warnings: "..table.concat(x.warnings," | ")..
   " URLs: "..table.concat(x.urls," | "))
 end
 eq(type(x.runner),"table","combined native Step2 passes exact retired epoch token")
 eq(x.env.E.PDIDDLER_SYSTEM1_COMBINED_TRANSITION_TOKEN,nil,
  "one-use combined Step2 preflight consumed token")
 eq(x.env.E.PDIDDLER_OUTGOING_SESSION,8,
  "original Stage1 epoch preserved until new P3 ARM")
 eq(#x.urls,10,"all ten reviewed source dependencies pinned")
 eq(x.runner.status().status,"PREPARING","no P3 contact before ARM")
 eq(x.env.E.STEP2_FAKE_P3,nil,"P3 source not started before ARM")
 eq(#x.calls,0,"no item or decline side effects before ARM")
 for _=1,4 do x.tick()end
 local arm=x.named("ArmStep2Public3")
 eq(type(arm),"table","visible operator ARM button created")
 eq(arm.Active,true,"two eligible candidates permit ARM")
 arm.Activated:Fire()
 eq(type(x.env.E.STEP2_FAKE_P3),"table","P3 transport created only after ARM")
 eq(x.env.E.PDIDDLER_OUTGOING_SESSION,9,
  "new P3 epoch advances retired Stage1 epoch monotonically")
 local p3=x.env.E.STEP2_FAKE_P3
 eq(x.runner.status().status,"RUNNING","public P3/P4 controller arms")
 eq(#x.calls,0,"no direct item/decline remote at ARM")
 for _=1,3 do x.tick()end
 p3.state.processed[3]="ignored"
 p3.state.ignored=1
 p3.state.processed[2]="trade-open"
 p3.state.accepted=1
 p3.state.paused=true
 x.screen.Enabled=true
 for _=1,14 do x.tick()end
 eq(#x.calls,1,"exact original protected P4 DeclineTrade remote")
 eq(x.calls[1],"DECLINE","only safe bound decline, no OfferItem")
 eq(x.screen.Enabled,false,"original protected IO client window closed")
 eq(x.runner.status().provenBoundClientCloses,1,
  "one P3 accepted lease bound then P4 closed")
 p3.state.paused=false -- original watchdog proves resume separately
 for _=1,6 do x.tick()end
 local st=x.runner.status()
 eq(st.status,"PUBLIC_CLIENT_ROTATION_HANDOFF_PASS",
  "two contacted public players + one exact P4 close")
 eq(st.attemptedDistinctContacts,2,"unique public contact ledger")
 eq(st.acceptedRequests,1,"one accepted public P3 request")
 eq(st.ignoredRequests,1,"one ignored public P3 request")
 eq(st.guardedP4DeclinesAttempted,1,"one exact protected P4 decline")
 eq(st.actualOffers,0,"zero offered weapons")
 eq(st.actualTeleports,0,"zero hops")
 eq(st.finalAcceptEverAttempted,false,"never final Accept")
 eq(st.serverCompletionProven,false,"no real trade settlement")
 eq(#x.calls,1,"no second decline or OfferItem on terminal")
 eq(#x.clipboard,1,"one sanitized terminal report copied")
 local report=serde.decode("json",x.clipboard[1])
 eq(report.schema,"gingerscope-system1-step2-public-p3p4-client-v1",
  "new independent Step2 report schema")
 eq(report.verifiedCompletedTrades,0,"no fake completed game trade")
end
do
 local x=fixture()
 for _=1,4 do x.tick()end
 x.named("ArmStep2Public3").Activated:Fire()
 local p3=x.env.E.STEP2_FAKE_P3
 p3.state.processed[2]="ignored";p3.state.processed[3]="ignored"
 p3.state.ignored=2
 for _=1,6 do x.tick()end
 eq(x.runner.status().status,"CLIENT_ROTATION_ONLY_HANDOFF_NOT_PROVEN",
  "two ignored people never falsely prove P4 bound handoff")
 eq(#x.calls,0,"no item or decline action for ignored-only session")
 eq(#x.clipboard,1,"inconclusive receipt saved")
end

-- The previous real one-server report STOPPED at public arm with
-- P3_SESSION_OR_WATCHDOG_LOST and zero verified contacts. The original
-- combined fork could not discriminate a blocked watchdog, missing
-- heartbeat, changed epoch, layout failure, or malformed P3 snapshot.
-- All five STILL STOP and cannot send, offer, decline or retry.
do
 local x=fixture()
 for _=1,4 do x.tick()end
 x.named("ArmStep2Public3").Activated:Fire()
 local p3=x.env.E.STEP2_FAKE_P3
 eq(type(p3),"table","exact combined epoch created before watchdog fault")
 x.env.E.TEST_WATCHDOG_NOT_READY=true
 x.tick()
 local r=x.runner.status()
 eq(r.status,"STOPPED","lost watchdog heartbeat fail closed")
 eq(r.reason,"P3_WATCHDOG_HEARTBEAT_MISSING",
  "precise missing heartbeat not generic session fault")
 eq(r.firstFailureEvidence.stage,"WATCHDOG_NOT_READY",
  "safe source-proven missing heartbeat stage")
 eq(r.firstFailureEvidence.watchdogReady,false,"not-ready flag retained")
 eq(r.firstFailureEvidence.sessionEpochMatches,true,
  "session still correct; watchdog specifically stale")
 eq(r.possibleSideEffect,false,"zero simulated request taps")
 eq(#x.calls,0,"no weapon offer/decline due to watchdog failure")
 eq(#x.clipboard,1,"one copy of original Step2 terminal fault")
end
do
 local x=fixture()
 for _=1,4 do x.tick()end
 x.named("ArmStep2Public3").Activated:Fire()
 x.env.E.TEST_WATCHDOG_EMIT("P3_WATCHDOG_LOST")
 x.tick()
 local r=x.runner.status()
 eq(r.status,"STOPPED","original watchdog emitted BLOCKED")
 eq(r.reason,"P3_WATCHDOG_BLOCKED",
  "explicit supervisor stop correctly identified")
 eq(r.firstFailureEvidence.watchdogReason,"P3_WATCHDOG_LOST",
  "retain original watchdog reason before shutdown overwrites status")
 eq(r.firstFailureEvidence.stage,"WATCHDOG_BLOCKED_EVENT",
  "same-block callback classified")
 eq(#x.calls,0,"no actions after supervisor BLOCKED")
end
do
 local x=fixture()
 for _=1,4 do x.tick()end
 x.named("ArmStep2Public3").Activated:Fire()
 x.env.E.PDIDDLER_OUTGOING_SESSION=10
 x.tick()
 local r=x.runner.status()
 eq(r.status,"STOPPED","altered P3 epoch cannot continue")
 eq(r.reason,"P3_SESSION_EPOCH_CHANGED",
  "original retired epoch cannot be silently reused")
 eq(r.firstFailureEvidence.sessionEpochMatches,false,
  "exact monotonic-session mismatch flagged")
 eq(#x.calls,0,"epoch mismatch forbids remote interactions")
end
do
 local x=fixture()
 for _=1,4 do x.tick()end
 x.named("ArmStep2Public3").Activated:Fire()
 x.named("PublicTestPanel").Parent=nil
 x.tick()
 local r=x.runner.status()
 eq(r.status,"STOPPED","unsafe/missing public UI panel fails closed")
 eq(r.reason,"P3_SCREEN_OR_OWNER_LOST",
  "GUI/owner failure distinct from watchdog heartbeat")
 eq(r.firstFailureEvidence.stage,"SCREEN_OR_OWNER",
  "GUI safety fault captured safely")
 eq(#x.calls,0,"no requests or accepted trades after lost UI")
end
do
 local x=fixture()
 for _=1,4 do x.tick()end
 x.named("ArmStep2Public3").Activated:Fire()
 x.env.E.STEP2_FAKE_P3.state=nil
 x.tick()
 local r=x.runner.status()
 eq(r.status,"STOPPED","malformed P3 state cannot be reused")
 eq(r.reason,"P3_OBSERVER_INVALID",
  "malformed native observation has specific code")
 eq(r.firstFailureEvidence.stage,"P3_STATE_INVALID",
  "malformed P3 state identified")
 eq(#x.calls,0,"zero actions on malformed P3")
end

print("SYSTEM1_COMBINED_STEP2_SUPERVISION_NATIVE_PASS",tests)
