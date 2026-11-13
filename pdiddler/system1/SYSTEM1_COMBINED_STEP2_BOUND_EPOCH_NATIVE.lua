-- COMBINED TEST: guarded Stage2 fork. Only preflight/transition differs;
-- original standalone Step2 script and all original Part3/P4 modules unchanged.
-- SYSTEM1 STEP2: P3 public-player rotation + P4 bound client-close.
-- No item placement, final Accept, hop, prices, profit, training or Discord.
-- One operator ARM, at most THREE distinct eligible public contacts.
-- WARNING: native Roblox modified-client tests carry account/game-rule risk.
local E=(type(getgenv)=="function" and getgenv()) or _G
local OWNER_KEY="PDIDDLER_SYSTEM1_STEP2_PUBLIC_OWNER"
local USED_KEY="PDIDDLER_SYSTEM1_STEP2_PUBLIC_USED_JOB"
local ORIGINAL_MM2=142823291
local MAIN="a3c209659942e8b45eec5da3555f7cfb83059c59"
local GATE="2db52f96fadd58957a804ebada8f77c3bc7a9228"
local P3="88fccfbd98281c1e47dce506bccf136604bd1485"
local CTRL="4e45ece155a9efb31bdc377a08ed91ea7e4d366a"
local BASE="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
local conflicts={
 "PDIDDLER_PART4_CONTROLLER_ACTIVE",
 "PDIDDLER_OUTGOING_CONTROLLER_ACTIVE",
 "PDIDDLER_AUTOTRADE_ACTIVE",
 "PDIDDLER_SUPERVISED_P3_NATIVE_OWNER",
 "PDIDDLER_SUPERVISED_FOUR_SLOT_PILOT",
 "PDIDDLER_SYSTEM1_MULTITRADE_OWNER",
 "PDIDDLER_SYSTEM1_MAIN_AUTO_OWNER",
 "PDIDDLER_SYSTEM1_STEP1_RECOVERY_OWNER",
}
local function otherController()
 for _,key in ipairs(conflicts)do
  if E[key]~=nil and E[key]~=false then return true end
 end
 return false
end
-- This fork is ONLY called by a source-pinned combined supervisor
-- after exact Step1 3/3 terminal pass and independent quiescence checks.
-- The retired P3 epoch is a monotonic tombstone, not an active request;
-- never reset it to nil or a previous number (ABA would revive callbacks).
local transition=E.PDIDDLER_SYSTEM1_COMBINED_TRANSITION_TOKEN
local transitionValid=type(transition)=="table" and
 transition.job==game.JobId and transition.status=="STEP1_VERIFIED_CLOSED" and
 transition.used==false and transition.source=="SYSTEM1_COMBINED_PINNED" and
 type(E.PDIDDLER_OUTGOING_SESSION)=="number" and
 E.PDIDDLER_OUTGOING_SESSION>=1 and
 E.PDIDDLER_OUTGOING_SESSION==math.floor(E.PDIDDLER_OUTGOING_SESSION) and
 transition.retiredP3Epoch==E.PDIDDLER_OUTGOING_SESSION and
 E.PDIDDLER_SYSTEM1_STEP1_RECOVERY_OWNER==nil and
 E.PDIDDLER_PART4_SESSION==nil
if game.PlaceId~=ORIGINAL_MM2 or
 not transitionValid or
 E[OWNER_KEY]~=nil or E[USED_KEY]==game.JobId or
 otherController() then
 warn("[SYSTEM1 COMBINED STEP2] exact closed Step1 and retired P3 epoch required")
 return nil
end
-- Consume this authorization ONCE, before source loading or GUI creation.
-- Original Part3 fork will advance the epoch when Step2 itself starts.
transition.used=true
E.PDIDDLER_SYSTEM1_COMBINED_TRANSITION_TOKEN=nil
local Players=game:GetService("Players")
local World=game:GetService("Workspace")
local Http=game:GetService("HttpService")
local LP=Players.LocalPlayer
local PG=LP and LP:FindFirstChildOfClass("PlayerGui")
if not LP or not PG or not World.CurrentCamera or
 LP.Parent~=Players then
 warn("[SYSTEM1 STEP2] PlayerGUI unavailable; no action started")
 return nil
end
local function pinned(rev,path,max)
 local ok,src=pcall(function()
  return game:HttpGet(BASE..rev.."/pdiddler/"..path)
 end)
 if not ok or type(src)~="string" or
  #src<80 or #src>(max or 90000) then return nil end
 local compiler=loadstring or load
 if type(compiler)~="function" then return nil end
 local good,mod=pcall(function()return assert(compiler(src))()end)
 return good and type(mod)=="table" and mod or nil
end
local geometry=pinned(MAIN,"new_part4/stage100_screen_prompt_overlay.lua",12000)
local originalIO=pinned(MAIN,"supervised/pdiddler4_tradeio_supervised_v2.lua",25000)
local bridge=pinned(MAIN,"supervised/supervised_p3_p4_handoff.lua",16000)
local coordinator=pinned(MAIN,"supervised/supervised_real_p3_rotation_handoff.lua",16000)
local boot=pinned(MAIN,"supervised/supervised_p3_startup_supervisor.lua",16000)
local watchdogModule=pinned(MAIN,"supervised/supervised_p3_continuous_watchdog.lua",12000)
local scanner=pinned(MAIN,"pdiddler3_scanner_MODULE_v6_5_PART4_STATUS_BRIDGE.lua",95000)
local targetModule=pinned(GATE,"system1/system1_step2_public_target_gate.lua",12000)
local p3Module=pinned(P3,"system1/system1_step2_public_p3_single_send.lua",72000)
local controllerModule=pinned(CTRL,"system1/system1_combined_step2_handoff_controller.lua",12000)
if not geometry or type(geometry.choose)~="function"
 or not originalIO or type(originalIO.new)~="function"
 or not bridge or type(bridge.bind)~="function"
 or not coordinator or type(coordinator.new)~="function"
 or not boot or type(boot.new)~="function"
 or not watchdogModule or type(watchdogModule.new)~="function"
 or not scanner or type(scanner.getWhitelist)~="function"
 or not targetModule or type(targetModule.new)~="function"
 or not p3Module or type(p3Module.run)~="function"
 or not controllerModule or type(controllerModule.new)~="function" then
 warn("[SYSTEM1 STEP2] PINNED_SOURCE_UNAVAILABLE; no requests sent")
 return nil
end
local okIo,io=pcall(originalIO.new,{
 resolveOfferEntry=function()return nil end,
},{})
if not okIo or type(io)~="table" or
 type(io.trade)~="function" or type(io.decline)~="function"
 or type(io.partnerName)~="function" then
 warn("[SYSTEM1 STEP2] PROTECTED_P4_IO_UNAVAILABLE; no requests")
 return nil
end
local runNonce="GUID_UNAVAILABLE"
pcall(function()runNonce=Http:GenerateGUID(false)end)
local owner={job=game.JobId,running=true,armed=false}
E[OWNER_KEY]=owner
local screen={}
local controller=nil
local sup=nil
local watcher=nil
local p3=nil
local targetGate=nil
local autoDeclines=0
local closedIds={}
local handoffFirstAt=nil
local rootFirstSeen=nil
local lastP4DeclineAt=nil
local lastJson=nil
local haltReason=nil
local watchdogBlockReason="NONE"
local watchdogLastStatus="NONE"
local function safeCode(v)
 if type(v)=="string" and #v>0 and #v<=72 and
    v:match("^[A-Z0-9_]+$") then return v end
 return "UNKNOWN"
end
local function writeReceipt(record)
 local copied={}
 for k,v in pairs(record) do copied[k]=v end
 copied.schema="gingerscope-system1-step2-public-p3p4-client-v1"
 copied.runNonce=runNonce
 copied.authorizesAccept=false
 copied.finalAcceptEverAttempted=false
 copied.actualOffers=0
 copied.actualTeleports=0
 copied.serverCompletionProven=false
 copied.verifiedCompletedTrades=0
 copied.tradeOutcome="UNKNOWN"
 local good,json=pcall(Http.JSONEncode,Http,copied)
 if not good or type(json)~="string" then
  warn("[SYSTEM1 STEP2] RESULT_ENCODING_FAILED")
  return false end
 lastJson=json
 E.PDIDDLER_SYSTEM1_STEP2_LAST_JSON=json
 local copy=type(setclipboard)=="function" and setclipboard or
  type(toclipboard)=="function" and toclipboard or
  type(E.setclipboard)=="function" and E.setclipboard
 local ok=false
 if copy then
  local goodCp,result=pcall(copy,json)
  ok=goodCp and result~=false
 end
 print("[SYSTEM1 STEP2 JSON] "..json)
 if screen.copy then screen.copy.Text=ok and "COPIED" or "COPY ERR" end
 return ok
end
local function shutdown()
 if not owner.running then return true end
 owner.running=false
 if watcher then pcall(watcher.stop)end
 if sup then pcall(sup.stop)end
 if targetGate then pcall(targetGate.stop)end
 E[USED_KEY]=owner.job
 E[OWNER_KEY]=nil
 return true
end
local function statusBeforeArm()
 local okay,list=pcall(scanner.getWhitelist)
 if not okay or type(list)~="table" then return 0 end
 local distinct={}
 local n=0
 for _,p in ipairs(list) do
  local uid=type(p)=="userdata" and p.UserId or
    (type(p)=="table" and p.UserId or nil)
  if type(uid)=="number" and uid>0 and
    p~=LP and p.Parent==Players and not distinct[uid] then
   local verified,found=pcall(Players.GetPlayerByUserId,Players,uid)
   if verified and found==p then
    distinct[uid]=true;n+=1
   end
  end
 end
 return n
end
local function tradeRoot()
 local found={}
 for _,name in ipairs({"TradeGUI_Phone","TradeGUI"}) do
  local g=PG:FindFirstChild(name)
  local c=g and g:FindFirstChild("Container")
  local t=c and c:FindFirstChild("Trade")
  if g and t and g.Enabled==true and
   c.Visible==true and t.Visible==true then
   found[#found+1]=t
  end
 end
 if #found>1 then return nil,"MULTIPLE_VISIBLE_TRADE_ROOTS" end
 local t=found[1]
 if t then
  local ours=t:FindFirstChild("YourOffer")
  local theirs=t:FindFirstChild("TheirOffer")
  local a=ours and ours:FindFirstChild("Accepted")
  local b=theirs and theirs:FindFirstChild("Accepted")
  if not a or not b or type(a.Visible)~="boolean" or
   type(b.Visible)~="boolean" or
   a.Visible~=false or b.Visible~=false then
   return nil,"UNEXPECTED_ACCEPTED_STATE"
  end
  if io.trade()~=t then return nil,"ROOT_OBSERVER_MISMATCH" end
 end
 return t,nil
end
local function layoutSafe()
 if not owner.running or
  E[OWNER_KEY]~=owner or game.JobId~=owner.job or
  otherController() or not screen.gui or screen.gui.Parent~=PG or
  not screen.panel or screen.panel.Parent~=screen.gui then
  return false end
 local root,err=tradeRoot()
 if err then return false end
 local camera=World.CurrentCamera
 if not camera then return false end
 local ok,v=pcall(function()return camera.ViewportSize end)
 if not ok or not v then return false end
 local bounds=nil
 if root then
  local yes,p,sz=pcall(function()
   return root.AbsolutePosition,root.AbsoluteSize end)
  if not yes then return false end
  bounds={x=p.X,y=p.Y,w=sz.X,h=sz.Y}
 end
 local chosen=geometry.choose({x=v.X,y=v.Y},bounds,{w=340,h=178})
 if not chosen then return false end
 local moved=pcall(function()
  screen.panel.Position=UDim2.fromOffset(chosen.x,chosen.y)
  screen.panel.Size=UDim2.fromOffset(chosen.w,chosen.h)
  screen.panel.Visible=true
 end)
 return moved==true
end
local uiOk=pcall(function()
 local gui=Instance.new("ScreenGui")
 gui.Name="PDIDDLER_System1_Step2_PublicRotation"
 gui.ResetOnSpawn=false
 gui.IgnoreGuiInset=true
 gui.DisplayOrder=155
 gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
 gui.Parent=PG;screen.gui=gui
 local panel=Instance.new("Frame")
 panel.Name="PublicTestPanel"
 panel.BackgroundColor3=Color3.fromRGB(33,21,52)
 panel.BorderSizePixel=0;panel.Visible=false;panel.ZIndex=10
 panel.Parent=gui;screen.panel=panel
 local stroke=Instance.new("UIStroke")
 stroke.Thickness=1
 stroke.Color=Color3.fromRGB(180,123,244)
 stroke.Parent=panel
 local corner=Instance.new("UICorner")
 corner.CornerRadius=UDim.new(0,10);corner.Parent=panel
 local function label(name,y,h,size)
  local l=Instance.new("TextLabel")
  l.Name=name;l.BackgroundTransparency=1
  l.TextColor3=Color3.fromRGB(255,255,255)
  l.Font=Enum.Font.GothamSemibold;l.TextSize=size
  l.TextWrapped=true
  l.TextXAlignment=Enum.TextXAlignment.Left
  l.TextYAlignment=Enum.TextYAlignment.Top
  l.Position=UDim2.fromOffset(10,y)
  l.Size=UDim2.fromOffset(320,h)
  l.ZIndex=11;l.Parent=panel;return l
 end
 screen.title=label("Step2Title",7,25,14)
 screen.body=label("Step2Directions",33,54,12)
 screen.status=label("Step2Counters",91,22,11)
 screen.warning=label("Step2Risk",117,18,10)
 local function button(name,txt,x,width)
  local b=Instance.new("TextButton")
  b.Name=name;b.Text=txt;b.TextSize=12
  b.Font=Enum.Font.GothamBold
  b.TextColor3=Color3.fromRGB(255,255,255)
  b.BackgroundColor3=Color3.fromRGB(89,53,132)
  b.Position=UDim2.fromOffset(x,143)
  b.Size=UDim2.fromOffset(width,27)
  b.ZIndex=12;b.Parent=panel;return b
 end
 screen.stop=button("StopStep2","STOP",10,56)
 screen.copy=button("CopyStep2","COPY",72,56)
 screen.arm=button("ArmStep2Public3","ARM MAX 3",148,182)
 screen.title.Text="SYSTEM 1 STEP 2 | PUBLIC P3/P4"
 screen.body.Text="P3 scans, sends up to THREE requests. P4 only declines exact accepted test trades. No item offers."
 screen.warning.Text="NO ACCEPT / NO WEAPON OFFERS / NO HOPS"
end)
if not uiOk or not screen.arm or not layoutSafe() then
 shutdown()
 warn("[SYSTEM1 STEP2] GUI_NO_SAFE_LAYOUT; no outgoing requests")
 return nil
end
local function hideScannerOverlay()
 -- The original scanner's own listing can obscure MM2 Trade controls.
 -- Hide presentation only; do not disable the scanner's classification.
 pcall(function()
  local old=PG:FindFirstChild("MM2EligibilityScannerT41")
  if old and old:IsA("ScreenGui") then old.Enabled=false end
 end)
end
local function updatePanel()
 hideScannerOverlay()
 if not screen.gui or screen.gui.Parent~=PG then return end
 if controller then
  local r=controller.status()
  screen.title.Text="STEP 2 | "..r.status
  screen.body.Text=r.reason
  screen.status.Text="Contacts: "..tostring(r.attemptedDistinctContacts)..
   " | Processed: "..tostring(r.processedTargets).."/"..tostring(r.frozenTargets)..
   " | Bound closes: "..tostring(r.provenBoundClientCloses)
  if r.status=="STOPPED" or r.phase=="INCONCLUSIVE" then
   screen.warning.Text="STOP/INCONCLUSIVE — COPY JSON, do not rerun same server"
  elseif r.phase=="DONE" then
   screen.warning.Text="CLIENT ROTATION + HANDOFF PASS | NO FINAL ACCEPT"
  else
   screen.warning.Text="MAIN AUTO P3 REQUESTS; P4 BOUND DECLINE ONLY"
  end
 else
  local eligible=statusBeforeArm()
  screen.status.Text="Whitelisted visible targets: "..tostring(eligible)
  local ready=eligible>=2
  screen.arm.Active=ready
  screen.arm.AutoButtonColor=ready
  screen.arm.BackgroundColor3=ready and
    Color3.fromRGB(89,53,132) or Color3.fromRGB(60,58,69)
  screen.arm.Text=ready and "ARM MAX 3" or "NEED 2 ELIGIBLE"
  screen.warning.Text="One ARM / max 3 / same public lobby; no item trades"
 end
end
local function setupStart()
 if not owner.running or not layoutSafe() or
  io.trade()~=nil or otherController() then return false end
 local g,why=targetModule.new(scanner,Players,LP,{
  publicLobbyTest=true,noFinalAccept=true,noItemOffers=true,
  noServerHop=true,explicitOperatorArm=true,maxTargets=3,
 })
 if not g or type(g.arm)~="function" then return false end
 local allowed=g.arm()
 if allowed~=true then return false end
 targetGate=g
 local capturedP3=nil
 local factory={
  run=function(sc,opts)
   local a=p3Module.run(sc,opts)
   capturedP3=a
   return a
  end,
 }
 local ctx={
  getJobId=function()return game.JobId end,
  getP3Session=function()return E.PDIDDLER_OUTGOING_SESSION end,
  onScreenSafe=function()return layoutSafe() end,
  watchdogReady=function()
   return watcher~=nil and watcher.isReady()==true end,
  noOtherTransactionOwner=function()
   return owner.running and not otherController() and
      E.PDIDDLER_PART4_SESSION==nil end,
  readyCheck=function()
   if not owner.running or not layoutSafe() then return false end
   local st=targetGate and targetGate.status(
     capturedP3 and capturedP3.state.processed)
   return st and st.status~="STOPPED" and st.status~="PREPARING"
  end,
 }
 local ok,new,reason=pcall(boot.new,g.scanner,factory,
  coordinator,bridge,io,Players,LP,ctx)
 if not ok or type(new)~="table" or
  type(capturedP3)~="table" then return false end
 sup=new;p3=capturedP3
 local okWatch,w=pcall(watchdogModule.new,sup,{
  isPaused=function()return p3.isPaused()end,
 },io,{
  getJobId=function()return game.JobId end,
  isLive=function()return owner.running and layoutSafe()end,
  onStatus=function(result)
   if type(result)=="table" then
    watchdogLastStatus=safeCode(result.status)
    if result.status=="BLOCKED" then
     watchdogBlockReason=safeCode(result.reason)
     haltReason="P3_SESSION_OR_WATCHDOG_LOST"
    end
   end
  end,
 },{
  spawn=function(fn)task.spawn(fn)end,
  wait=function(t)task.wait(t)end,
  now=function()return os.clock()end,
 })
 if not okWatch or type(w)~="table" then return false end
 watcher=w
 if watcher.start()~=true then return false end
 local started=os.clock()
 while owner.running and os.clock()-started<2.5 and
   not watcher.isReady() do task.wait(0.05) end
 if not owner.running or not watcher.isReady() then return false end
 local okArm,armed=pcall(sup.arm,{
  explicitUserAuthorization=true,
  allowRealP3RequestRotation=true,
  finalAcceptMustRemainManual=true,
 })
 return okArm and armed==true
end
local function observe()
 local broken={
  safe=false,clientTradeSettled=false,noFinalAccept=true,
  noItemsOffered=true,noServerHop=true,
 }
 -- Every missing supervision proof remains a TERMINAL STOP; the
 -- original inspector collapsed six distinct cases into one generic
 -- event without retaining watchdog status.
 local function failed(code,stage)
  local state=type(p3)=="table" and p3.state or nil
  local watchStatus=nil
  if type(watcher)=="table" and type(watcher.status)=="function" then
   local ok,report=pcall(watcher.status)
   if ok and type(report)=="table" then watchStatus=report end
  end
  local ready=false
  if type(watcher)=="table" and type(watcher.isReady)=="function" then
   local ok,flag=pcall(watcher.isReady)
   ready=ok and flag==true
  end
  broken.fault=code
  broken.possibleSideEffect=type(state)=="table" and
     (state.tradeButtonTapAttempted==true or
      (type(state.sent)=="number" and state.sent>0)) or false
  broken.failureEvidence={
   stage=safeCode(stage),
   watchdogStatus=watchStatus and safeCode(watchStatus.status) or
       watchdogLastStatus,
   watchdogReason=watchdogBlockReason~="NONE" and watchdogBlockReason
       or watchStatus and safeCode(watchStatus.reason) or "UNKNOWN",
   sessionEpochMatches=type(p3)=="table" and
       type(p3.session)=="number" and
       p3.session==E.PDIDDLER_OUTGOING_SESSION,
   watchdogReady=ready,
   observedP3Sends=type(state)=="table" and
       type(state.sent)=="number" and
       math.max(0,math.min(3,state.sent)) or 0,
   tradeButtonTapAttempted=type(state)=="table" and
       state.tradeButtonTapAttempted==true or false,
  }
  return broken
 end
 if not owner.running or not p3 or not watcher then
  return failed("P3_P3_CONTROLLER_MISSING","P3_CONTROLLER_UNAVAILABLE") end
 if type(p3.session)~="number" or
    p3.session~=E.PDIDDLER_OUTGOING_SESSION then
  return failed("P3_SESSION_EPOCH_CHANGED","P3_EPOCH_IDENTITY")end
 if not layoutSafe() then
  return failed("P3_SCREEN_OR_OWNER_LOST","SCREEN_OR_OWNER")end
 if haltReason~=nil then
  return failed("P3_WATCHDOG_BLOCKED","WATCHDOG_BLOCKED_EVENT")end
 if watcher.isReady()~=true then
  return failed("P3_WATCHDOG_HEARTBEAT_MISSING","WATCHDOG_NOT_READY")end
 local state=p3.state
 if type(state)~="table" or type(state.processed)~="table" then
  return failed("P3_OBSERVER_INVALID","P3_STATE_INVALID")end
 local gateOk,status=pcall(targetGate.status,state.processed)
 if not gateOk or type(status)~="table" then
  return failed("P3_OBSERVER_INVALID","PUBLIC_GATE_STATUS_INVALID")end
 local pOk,pending=pcall(p3.pendingVisible)
 local sOk,paused=pcall(p3.isPaused)
 if not pOk or type(pending)~="boolean" or
   not sOk or type(paused)~="boolean" then
  return failed("P3_OBSERVER_INVALID","P3_GUI_PENDING_OR_PAUSE_INVALID")end
 local observed={
  safe=true,noFinalAccept=true,noItemsOffered=true,
  noServerHop=true,clientTradeSettled=false,
  frozenTargets=status.frozenTargets,
  processedTargets=status.processedTargets,
  distinctContacts=0,
  acceptedRequests=state.accepted or 0,
  ignoredRequests=state.ignored or 0,
  declinedRequests=state.declined or 0,
  incomingDeclined=state.incomingDeclined or 0,
  preTradeCardSkips=state.preTradeCardSkipped or 0,
  requestTargetsAttempted=state.requestTargetsAttempted or 0,
  originalP3SentConfirmed=state.sent or 0,
  pendingUiEverConfirmed=state.pendingRequestUiEverConfirmed==true,
  autoDeclines=autoDeclines,
  exhausted=status.status=="EXHAUSTED",
  boundActive=false,pendingVisible=pending,p3Paused=paused,
 }
 local stageCodes={
  TRADE_TAP_RETURNED_UNCONFIRMED="P3_TRADE_TAP_RETURNED_UNCONFIRMED",
  PENDING_UI_MISSING_AFTER_TRADE_TAP="P3_POST_TAP_PENDING_UI_NOT_SEEN",
  PENDING_DISAPPEARED_UNCLASSIFIED="P3_PENDING_DISAPPEARED_UNCLASSIFIED",
  CANCEL_UNVERIFIED="P3_CANCEL_AFTER_PENDING_UNVERIFIED",
  CARD_FAILURE_WITH_ACTIVE_TRADE_UI="P3_CARD_FAILURE_WITH_ACTIVE_TRADE_UI",
 }
 for _,code in pairs(state.processed)do
  if code=="trade-open" or code=="ignored" or code=="declined" then
   observed.distinctContacts+=1
  elseif code=="failed" or code=="unavailable-final" or
      code=="cancel-unverified" then
   observed.fault=stageCodes[state.lastOutcomeCode] or
     "P3_AMBIGUOUS_SEND_STOP"
  end
 end
 if state.failStop==true then
  observed.fault=observed.fault or
    stageCodes[state.lastOutcomeCode] or "P3_AMBIGUOUS_SEND_STOP"
 end
 if observed.fault then
  observed.possibleSideEffect=true
  -- No usernames/IDs or inventory details leave this test.
  local function safeStage(v)
   if type(v)~="string" or #v>64 or
      not v:match("^[A-Z_]+$") then return "UNKNOWN" end
   return v
  end
  observed.failureEvidence={
   stage=safeStage(state.lastRequestStage),
   outcome=safeStage(state.lastOutcomeCode),
   tradeButtonTapAttempted=state.tradeButtonTapAttempted==true,
   tradeButtonTapReturnedTrue=state.tradeButtonTapReturnedTrue==true,
   pendingRequestUiEverConfirmed=state.pendingRequestUiEverConfirmed==true,
   pendingUiVisibleAtStop=pending==true,
   originalP3SentConfirmed=state.sent or 0,
   preTradeCardSkips=state.preTradeCardSkipped or 0,
  }
 end
 if haltReason and observed.fault==nil then
  observed.fault="P3_WATCHDOG_BLOCKED"
  observed.possibleSideEffect=state.tradeButtonTapAttempted==true or
      (type(state.sent)=="number" and state.sent>0)
  observed.failureEvidence={
   stage="WATCHDOG_BLOCKED_AFTER_VALID_SNAPSHOT",
   watchdogStatus=watchdogLastStatus,
   watchdogReason=watchdogBlockReason,
   sessionEpochMatches=p3.session==E.PDIDDLER_OUTGOING_SESSION,
   watchdogReady=watcher.isReady()==true,
   observedP3Sends=state.sent or 0,
   tradeButtonTapAttempted=state.tradeButtonTapAttempted==true,
  }
 end
 if status.status=="STOPPED" then
  observed.fault="P3_GATE_STOPPED" end
 local root,why=tradeRoot()
 if why then
  observed.fault="P4_BOUND_SNAPSHOT_UNSAFE"
  return observed end
 if not root then
  rootFirstSeen=nil
  -- The original P3 watchdog resumes the queue after P4 has safely
  -- closed its exact client window. Allow one bounded dispatch interval.
  if lastP4DeclineAt~=nil and paused then
   if os.clock()-lastP4DeclineAt>2.5 then
    observed.fault="P3_UNEXPECTED_RESUME"
   else
    observed.exhausted=false
   end
  end
  if lastP4DeclineAt~=nil and not paused then
   lastP4DeclineAt=nil
  end
  return observed
 end
 observed.exhausted=false -- no terminal state while any trade root exists
 if rootFirstSeen==nil or rootFirstSeen.root~=root then
  rootFirstSeen={root=root,at=os.clock()}
 end
 local ok,lease,info=pcall(sup.currentBoundReadOnly)
 local valid,snap=false,nil
 if ok and type(lease)=="table" and type(info)=="table"
  and info.status=="P3_BOUND_CANDIDATE_READ_ONLY"
  and type(lease.capture)=="function" then
  local ready,data=pcall(lease.capture)
  valid=ready and type(data)=="table" and
    data.status=="CLIENT_UNPRICED_TWO_SIDED_SNAPSHOT" and
    data.partnerExactClientBound==true and
    data.part3Paused==true and data.authorizesOffer==false
    and data.authorizesAccept==false and
    data.serverCompletionProven==false and
    data.tradeOutcome=="UNKNOWN"
  if valid then snap=data end
 end
 if not valid then
  if os.clock()-rootFirstSeen.at>2 then
   observed.fault="P3_HANDOFF_UNATTRIBUTED"
  end
  return observed
 end
 rootFirstSeen=nil
 local partner=io.partnerName(root)
 local resolved=nil
 for uid,code in pairs(state.processed)do
  if code=="trade-open" and not closedIds[uid] then
   local p=Players:GetPlayerByUserId(uid)
   if p and p.Parent==Players and p.Name==partner and
     targetGate.scanner.isWhitelisted(uid) then
    if resolved then observed.fault="P3_HANDOFF_UNATTRIBUTED";return observed end
    resolved=uid
   end
  end
 end
 if not resolved then observed.fault="P3_HANDOFF_UNATTRIBUTED";return observed end
 observed.boundActive=true
 observed.authenticatedP3Lease=true
 observed.safeP4Snapshot=true
 observed.unchangedTradeRoot=io.trade()==root
 observed.root=root
 observed.partnerUserId=resolved
 observed.ourPhysicalSlots=snap.physicalOwnSlots
 return observed
end
local function declineBound(ob)
 if type(ob)~="table" or not owner.running or
  not sup or not p3 or not ob.root or
  ob.ourPhysicalSlots~=0 or io.trade()~=ob.root or
  p3.isPaused()~=true or not layoutSafe() or
  closedIds[ob.partnerUserId] then return false end
 local ok,lease,info=pcall(sup.currentBoundReadOnly)
 if not ok or type(lease)~="table" or
  type(info)~="table" or
  info.status~="P3_BOUND_CANDIDATE_READ_ONLY" then return false end
 local yes,snap=pcall(lease.capture)
 if not yes or type(snap)~="table" or
  snap.status~="CLIENT_UNPRICED_TWO_SIDED_SNAPSHOT" or
  snap.physicalOwnSlots~=0 or snap.partnerExactClientBound~=true or
  snap.part3Paused~=true or snap.authorizesAccept~=false or
  io.trade()~=ob.root then return false end
 autoDeclines+=1
 local accepted,closed=pcall(io.decline,
   "SYSTEM1_STEP2_PUBLIC_EXACT_BOUND_CLIENT_CLOSE")
 if not accepted or closed~=true or io.trade()~=nil then return false end
 lastP4DeclineAt=os.clock()
 closedIds[ob.partnerUserId]=true
 return true
end
local api={
 start=setupStart,
 inspect=observe,
 declineBound=declineBound,
 stop=shutdown,
 copyReport=writeReceipt,
}
local engine,why=controllerModule.new(api,{
 explicitArm=true,maxTargets=3,noItemOffers=true,
 noFinalAccept=true,noServerHop=true,testDurationSeconds=220,
})
if not engine then
 shutdown()
 warn("[SYSTEM1 STEP2] CONTROLLED_CLIENT_GATE_FAILED")
 return nil
end
controller=engine
screen.arm.Activated:Connect(function()
 if owner.armed or not owner.running or
   statusBeforeArm()<2 then return end
 owner.armed=true
 screen.arm.Visible=false
 local began=controller.arm(os.clock())
 if began~=true then updatePanel();return end
 local scheduled=pcall(function()
  task.spawn(function()
   while owner.running do
    local r=controller.tick(os.clock())
    updatePanel()
    if r.phase=="DONE" or r.phase=="STOPPED" or
       r.phase=="INCONCLUSIVE" then break end
    task.wait(0.15)
   end
   updatePanel()
  end)
 end)
 if not scheduled then controller.stop() end
end)
screen.stop.Activated:Connect(function()
 if controller then controller.stop() else shutdown()end
 updatePanel()
end)
screen.copy.Activated:Connect(function()
 if controller then controller.copyNow()
 elseif lastJson then writeReceipt({status="PREPARING"})
 else writeReceipt({status="PREPARING",reason="NO_CONTACTS_BEFORE_ARM"})end
end)
task.spawn(function()
 while owner.running and not owner.armed do
  hideScannerOverlay()
  if not layoutSafe() then
   shutdown()
   warn("[SYSTEM1 STEP2] UI_LAYOUT_UNSAFE_BEFORE_ARM")
   break
  end
  updatePanel()
  task.wait(0.5)
 end
end)
E.PDIDDLER_SYSTEM1_STEP2_PUBLIC_RUNNER={
 status=function()return controller.status()end,
 stop=function()return controller.stop()end,
 copy=function()return controller.copyNow()end,
}
print("[SYSTEM1 STEP2] Public P3 rotation + P4 read-only bound decline; ARM max3, NO offers/Accept")
return E.PDIDDLER_SYSTEM1_STEP2_PUBLIC_RUNNER
