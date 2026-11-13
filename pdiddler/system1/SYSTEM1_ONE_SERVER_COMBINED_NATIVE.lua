-- System1 one-original-MM2-JobId combined test: controlled 3/3 ALT recovery
-- then frozen three-contact public P3/P4 client handoff. Two separate ARMs,
-- one LOAD, one SERVER, exactly one live controller at any time.
-- No final Accept, no settled item transfers, no bot avoider or server hop.
local E=(type(getgenv)=="function" and getgenv()) or _G
local KEY="PDIDDLER_SYSTEM1_ONE_SERVER_COMBINED_OWNER"
local USED="PDIDDLER_SYSTEM1_ONE_SERVER_COMBINED_USED_JOB"
local PLACE=142823291
local FIRST="b24661781e72e3dec759960d2f4b423841961c8b"
local SECOND="f2c6b9ab11175885692027658038862da77be1cd"
local CONTROL="2c822f3519739d075eab3ec0f4e76830ad0da715"
local PREFIX="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
local THIS_JOB=game.JobId
local Players=game:GetService("Players")
local Player=Players.LocalPlayer
local PG=Player and Player:FindFirstChildOfClass("PlayerGui")
local Http=game:GetService("HttpService")
local ALT_NAME="venossgaming90190"
if game.PlaceId~=PLACE or not Player or
 type(THIS_JOB)~="string" or #THIS_JOB==0 or
 E[KEY]~=nil or E[USED]==THIS_JOB or
 E.PDIDDLER_OUTGOING_SESSION~=nil or
 E.PDIDDLER_PART4_SESSION~=nil or
 E.PDIDDLER_SYSTEM1_STEP1_RECOVERY_OWNER~=nil or
 E.PDIDDLER_SYSTEM1_STEP2_PUBLIC_OWNER~=nil or
 E.PDIDDLER_SYSTEM1_COMBINED_TRANSITION_TOKEN~=nil then
 warn("[SYSTEM1 ONE SERVER] fresh original MM2 job without other trading controllers required")
 return nil
end
local function pinned(rev,path,min,max)
 local ok,src=pcall(function()
  return game:HttpGet(PREFIX..rev.."/pdiddler/"..path)
 end)
 if not ok or type(src)~="string" or
  #src<(min or 80) or #src>(max or 70000) then
  return nil
 end
 return src
end
local sourceController=pinned(
 CONTROL,"system1/system1_one_server_transition_controller.lua",2000,15000)
local compiler=loadstring or load
if not sourceController or type(compiler)~="function" then
 warn("[SYSTEM1 ONE SERVER] reviewed transition module unavailable")
 return nil
end
local okModule,Controller=pcall(function()
 return assert(compiler(sourceController))()
end)
if not okModule or type(Controller)~="table" or
 type(Controller.new)~="function" then
 warn("[SYSTEM1 ONE SERVER] transition module refused")
 return nil
end
local owner={job=THIS_JOB,running=true,phase="STARTING"}
E[KEY]=owner
local firstRunner=nil
local secondRunner=nil
local stage1LoaderReason="STEP1_SOURCE_NOT_ATTEMPTED"
local priorStep1Json=nil
local lastJson=nil
local runNonce="GUID_UNAVAILABLE"
pcall(function()runNonce=Http:GenerateGUID(false) end)
local function jobMatches()
 return game.JobId==THIS_JOB and game.PlaceId==PLACE and
    E[KEY]==owner and (PG==nil or PG.Parent==Player)
end
local function visible(obj)
 local ok,yes=pcall(function()
  local p=obj
  while p do
   if p:IsA("ScreenGui") and not p.Enabled then return false end
   if p:IsA("GuiObject") and not p.Visible then return false end
   p=p.Parent
  end
  return true
 end)
 return ok and yes==true
end
local function noTradeOrPending()
 local guiNames={"TradeGUI","TradeGUI_Phone"}
 for _,name in ipairs(guiNames)do
  local g=PG:FindFirstChild(name)
  if g and g:IsA("ScreenGui") and g.Enabled then
   local c=g:FindFirstChild("Container")
   local t=c and c:FindFirstChild("Trade")
   if t and visible(t) then return false,"TRADE_WINDOW_ACTIVE" end
  end
 end
 local roots={PG}
 if type(gethui)=="function" then
  local ok,root=pcall(gethui)
  if not ok then return false,"GUI_ROOT_UNREADABLE" end
  if root then roots[#roots+1]=root end
 end
 for _,root in ipairs(roots)do
  local ok,desc=pcall(function()return root:GetDescendants()end)
  if not ok or type(desc)~="table" then
   return false,"GUI_DESCENDANTS_UNREADABLE" end
  for _,v in ipairs(desc)do
   if visible(v) and
     (v:IsA("TextLabel") or v:IsA("TextButton") or
      v:IsA("TextBox")) then
    local yes,txt=pcall(function()return tostring(v.Text or "") end)
    if not yes then return false,"GUI_TEXT_UNREADABLE" end
    local upper=txt:upper()
    if upper:find("TRADE REQUEST PENDING",1,true) or
       upper:find("TRADE REQUEST FROM",1,true) or
       upper:find("INCOMING TRADE REQUEST",1,true) or
       upper:find("SENT YOU A TRADE REQUEST",1,true) then
      return false,"REQUEST_POPUP_ACTIVE"
    end
   end
  end
 end
 return true,"NO_TRADE_OR_PENDING"
end
-- This extra gate runs before executing either of the two original
-- source-pinned trading scripts. It never taps Trade or sends a remote.
-- A short stable readiness interval avoids cold public-server startup races.
local conflictNames={
 "PDIDDLER_PART4_CONTROLLER_ACTIVE",
 "PDIDDLER_OUTGOING_CONTROLLER_ACTIVE",
 "PDIDDLER_AUTOTRADE_ACTIVE",
 "PDIDDLER_SUPERVISED_P3_NATIVE_OWNER",
 "PDIDDLER_SUPERVISED_FOUR_SLOT_PILOT",
 "PDIDDLER_SYSTEM1_MULTITRADE_OWNER",
 "PDIDDLER_SYSTEM1_MAIN_AUTO_OWNER",
}
local function readiness()
 if not jobMatches() then return false,"PREFLIGHT_JOB_CHANGED" end
 if E.PDIDDLER_OUTGOING_SESSION~=nil or
    E.PDIDDLER_PART4_SESSION~=nil or
    E.PDIDDLER_SYSTEM1_STEP1_RECOVERY_OWNER~=nil or
    E.PDIDDLER_SYSTEM1_STEP2_PUBLIC_OWNER~=nil then
  return false,"PREFLIGHT_ACTIVE_SESSION"
 end
 for _,key in ipairs(conflictNames)do
  if E[key]~=nil and E[key]~=false then
   return false,"PREFLIGHT_COMPETING_CONTROLLER" end
 end
 local pgui=Player:FindFirstChildOfClass("PlayerGui")
 if not pgui or pgui.Parent~=Player then
  return false,"PREFLIGHT_PLAYERGUI_NOT_READY" end
 PG=pgui
 local world=game:GetService("Workspace")
 if not world or not world.CurrentCamera then
  return false,"PREFLIGHT_CAMERA_NOT_READY" end
 local alt=Players:FindFirstChild(ALT_NAME)
 if not alt then return false,"PREFLIGHT_ALT_NOT_PRESENT" end
 local ok,found=pcall(function()
  return Players:GetPlayerByUserId(alt.UserId)
 end)
 if not ok or alt==Player or alt.Parent~=Players or
   type(alt.UserId)~="number" or alt.UserId<=0 or
   alt.Name~=ALT_NAME or found~=alt then
  return false,"PREFLIGHT_ALT_IDENTITY_UNVERIFIED" end
 local clear,why=noTradeOrPending()
 if not clear then return false,"PREFLIGHT_"..
    tostring(why or "GUI_UNCLEAR") end
 return true,"PREFLIGHT_READY"
end
local function quiescent()
 if not jobMatches() or not firstRunner then return {safe=false}end
 local r=firstRunner.status()
 if type(r)~="table" or r.phase~="DONE" or
    r.completedRounds~=3 or
    E.PDIDDLER_SYSTEM1_STEP1_RECOVERY_OWNER~=nil or
    E.PDIDDLER_SYSTEM1_STEP1_RECOVERY_USED_JOB~=THIS_JOB or
    E.PDIDDLER_PART4_SESSION~=nil or
    E.PDIDDLER_SYSTEM1_STEP2_PUBLIC_OWNER~=nil then
  return {safe=false}
 end
 local epoch=E.PDIDDLER_OUTGOING_SESSION
 if type(epoch)~="number" or epoch<1 or
    epoch~=math.floor(epoch) or not noTradeOrPending() then
  return {safe=false}
 end
 return {safe=true,epoch=epoch}
end
local function loadScript(rev,path,min,max)
 local src=pinned(rev,path,min,max)
 if not src then return nil,"SOURCE_PINNED_FETCH_FAILED" end
 local okay,res=pcall(function()
  return assert(compiler(src))()
 end)
 if not okay then return nil,"SCRIPT_EXECUTION_FAILED" end
 if type(res)~="table" then return nil,"SCRIPT_RETURNED_NO_RUNNER" end
 return res,nil
end
local function emit(r)
 local data={}
 for k,v in pairs(r)do data[k]=v end
 data.runNonce=runNonce
 data.gameJobIdNeverReported=true
 data.oneServerOnly=true
 data.finalAcceptEverAttempted=false
 data.serverCompletionProven=false
 data.verifiedCompletedTrades=0
 data.tradeOutcome="UNKNOWN"
 local ok,json=pcall(Http.JSONEncode,Http,data)
 if not ok or type(json)~="string" then
  warn("[SYSTEM1 COMBINED] unable to encode sanitized report")
  return false
 end
 lastJson=json
 E.PDIDDLER_SYSTEM1_ONE_SERVER_LAST_JSON=json
 print("[SYSTEM1 COMBINED JSON] "..json)
 local clipboard=type(setclipboard)=="function" and setclipboard or
   type(toclipboard)=="function" and toclipboard or
   type(E.setclipboard)=="function" and E.setclipboard
 if clipboard then pcall(clipboard,json) end
 return true
end
local function launchStep1()
 if not jobMatches() or firstRunner or
    E.PDIDDLER_OUTGOING_SESSION~=nil then
  stage1LoaderReason="STARTUP_SESSION_OR_JOB_INVALID"
  return false
 end
 -- Do not mistake a stale previous-job child JSON for this fresh run.
 priorStep1Json=E.PDIDDLER_SYSTEM1_MAIN_AUTO_LAST_JSON
 local loaded,why=loadScript(
  FIRST,"system1/SYSTEM1_STEP1_ALT_DYNAMIC_RECOVERY_NATIVE.lua",
  15000,70000)
 firstRunner=loaded
 if type(firstRunner)~="table" then
  stage1LoaderReason=why or "SCRIPT_RETURNED_NO_RUNNER"
  return false end
 if type(firstRunner.status)~="function" or
    type(firstRunner.stop)~="function" then
  stage1LoaderReason="RUNNER_API_INCOMPLETE"
  return false end
 return true
end
local function step1StartFailure()
 -- Original Step1 writes its OWN diagnostic JSON when its setup fails.
 -- Decode it only when newly written by THIS attempt, then sanitize it
 -- inside the transition controller's childFault before copying.
 local raw=E.PDIDDLER_SYSTEM1_MAIN_AUTO_LAST_JSON
 if type(raw)=="string" and #raw<=16000 and raw~=priorStep1Json then
  local ok,decoded=pcall(function()return Http:JSONDecode(raw)end)
  if ok and type(decoded)=="table" and decoded.schema==
     "gingerscope-system1-step1-alt-recovery-native-v1" and
     decoded.status=="STOPPED" then
   return decoded
  end
 end
 return{
  status="STOPPED",phase="SETUP",round=0,completedRounds=0,
  lastAction="BEFORE_ARM",reason=stage1LoaderReason,
  possibleSideEffect=false,
 }
end
local function step1VerifiedReceipt()
 -- The pinned ORIGINAL Step1 module serializes terminal evidence with
 -- finalAcceptEverAttempted=false and verifiedCompletedTrades=0. Its
 -- raw controller.status() omits those fields. Verify both independently.
 local raw=E.PDIDDLER_SYSTEM1_MAIN_AUTO_LAST_JSON
 if type(raw)~="string" or #raw>16000 or
    raw==priorStep1Json or not firstRunner then return nil end
 local ok,decoded=pcall(function()return Http:JSONDecode(raw)end)
 if not ok or type(decoded)~="table" or
    decoded.schema~="gingerscope-system1-step1-alt-recovery-native-v1" or
    decoded.status~="CLIENT_TEST_SEQUENCE_COMPLETE" or
    decoded.phase~="DONE" then return nil end
 return decoded
end
local function launchStep2(retiredEpoch)
 if not jobMatches() or secondRunner or
    type(retiredEpoch)~="number" or
    retiredEpoch~=E.PDIDDLER_OUTGOING_SESSION or
    not quiescent().safe then return false end
 -- Part3's last epoch is a retired tombstone. Never clear it or
 -- revert it; this token lets ONLY the pinned combined Step2 fork
 -- advance to a fresh epoch after the old request owner stopped.
 local permit={
  source="SYSTEM1_COMBINED_PINNED",
  job=THIS_JOB,
  status="STEP1_VERIFIED_CLOSED",
  used=false,retiredP3Epoch=retiredEpoch,
 }
 E.PDIDDLER_SYSTEM1_COMBINED_TRANSITION_TOKEN=permit
 secondRunner=loadScript(
   SECOND,"system1/SYSTEM1_COMBINED_STEP2_BOUND_EPOCH_NATIVE.lua",
   15000,70000)
 E.PDIDDLER_SYSTEM1_COMBINED_TRANSITION_TOKEN=nil
 if not secondRunner or permit.used~=true or
    type(secondRunner.status)~="function" or
    type(secondRunner.stop)~="function" or
    E.PDIDDLER_OUTGOING_SESSION~=retiredEpoch then
  return false
 end
 -- Hide Step1 presentation after its successful terminal ledger, not
 -- its controller/receipts; the original Step2 GUI now owns the screen.
 pcall(function()
  local gui=PG:FindFirstChild("PDIDDLER_System1_Step1_ALT_Recovery")
  if gui and gui:IsA("ScreenGui") then gui.Enabled=false end
 end)
 print("[SYSTEM1 ONE SERVER] STEP 1 3/3 locked; Step2 panel now available. ARM MAX 3 once.")
 return true
end
local function stopActive()
 if secondRunner then
  pcall(secondRunner.stop)
 elseif firstRunner then
  pcall(firstRunner.stop)
 end
 E.PDIDDLER_SYSTEM1_COMBINED_TRANSITION_TOKEN=nil
 owner.running=false
 E[USED]=THIS_JOB
 return true
end
local api={
 launchStep1=launchStep1,
 startFailure=step1StartFailure,
 step1Status=function()return firstRunner and firstRunner.status()end,
 step1VerifiedReceipt=step1VerifiedReceipt,
 quiescent=quiescent,
 launchStep2=launchStep2,
 step2Status=function()return secondRunner and secondRunner.status()end,
 jobMatches=jobMatches,
 stopActive=stopActive,
 emit=emit,
}
local engine,why=Controller.new(api,{
 oneServerOnly=true,noFinalAccept=true,
 noItemTransfer=true,noServerHop=true,
})
if not engine then
 E[KEY]=nil
 warn("[SYSTEM1 ONE SERVER] transition controller default closed",why)
 return nil
end
local preflight={lastReason="PREFLIGHT_CHECKS_STARTING",
  stableReadinessChecks=0,checks=0,started=false}
local started=pcall(function()
 task.spawn(function()
  -- Total bounded 18s of read-only validation. We do NOT silently
  -- rerun a stopped Stage1 trade, re-arm P3, or reset session epochs.
  local deadline=os.clock()+18
  while owner.running and not preflight.started do
   local checkOk,ready,why=pcall(readiness)
   if not checkOk then
    -- A transient Roblox GUI/Players lookup exception cannot leave a
    -- half-armed test running forever or permit blind re-entry.
    ready=false
    why="PREFLIGHT_READ_EXCEPTION"
   end
   preflight.lastReason=why
   preflight.checks+=1
   -- A changed JobId or live competing controller is not a cold-start
   -- timing issue. Stop without contacting anybody or waiting 18s.
   if why=="PREFLIGHT_JOB_CHANGED" or
      why=="PREFLIGHT_ACTIVE_SESSION" or
      why=="PREFLIGHT_COMPETING_CONTROLLER" then
    engine.preflightAbort(why,preflight.stableReadinessChecks)
    break
   end
   if ready then
    preflight.stableReadinessChecks+=1
   else
    preflight.stableReadinessChecks=0
   end
   if ready and preflight.stableReadinessChecks>=4 then
    local ok,begin=pcall(engine.start,os.clock())
    if not ok or begin~=true then
     if engine.status().phase~="STOPPED" then
      engine.preflightAbort("PREFLIGHT_STEP1_START_DENIED",
        preflight.stableReadinessChecks)
     end
     break
    end
    preflight.started=true
    print("[SYSTEM1 ONE SERVER] PRECHECK PASSED; original ALT ARM3 GUI loaded.")
    break
   end
   if os.clock()>=deadline then
    engine.preflightAbort(why or "PREFLIGHT_UNKNOWN",
      preflight.stableReadinessChecks)
    break
   end
   task.wait(0.2)
  end
  while owner.running and preflight.started and jobMatches() do
   local good,r=pcall(engine.tick,os.clock())
   if not good or type(r)~="table" then
    engine.stop()
    break
   end
   if r.phase=="STOPPED" or r.phase=="DONE" or
      r.phase=="INCONCLUSIVE" then
    print("[SYSTEM1 ONE SERVER] Final phase",r.phase,r.reason)
    break
   end
   task.wait(0.2)
  end
  if owner.running and not jobMatches() then engine.stop()end
 end)
end)
if not started then
 engine.preflightAbort("PREFLIGHT_WORKER_SCHEDULE_FAILED",0)
end
E.PDIDDLER_SYSTEM1_ONE_SERVER_RUNNER={
 status=function()
  local report=engine.status()
  if report.phase=="PREPARING" then
   report.reason=preflight.lastReason
   report.preflightChecks=preflight.checks
   report.preflightStableChecks=preflight.stableReadinessChecks
  end
  return report
 end,
 stop=function()return engine.stop()end,
 copy=function()return engine.copy()end,
}
print("[SYSTEM1 ONE SERVER] Read-only bounded preflight checking ALT, GUI, camera, trade and other controllers BEFORE loading Step1. One JobId; Step2 after verified 3/3.")
return E.PDIDDLER_SYSTEM1_ONE_SERVER_RUNNER
