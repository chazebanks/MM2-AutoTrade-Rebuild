-- Atomic startup for existing P3 default-closed outgoing fork + P4 observer.
-- Inject only SHA-pinned real modules. Nothing here sends a request/item.
-- It is not a standalone on-device runner: UI and watchdog must be attached
-- independently BEFORE an operator may arm real P3 rotation.
local M={}
local function result(status,reason)
 return {
  schema="pdiddler-p3-atomic-bootstrap-v1",
  status=status,reason=reason,part3RotationAuthorized=false,
  requestOriginBound=false,rawItemIdsAuthenticated=false,
  pricesAuthenticated=false,authorizesOffer=false,authorizesAccept=false,
  serverCompletionProven=false,mayReportProfit=false,
  maySendDiscordWebhook=false,mayUseForStrategyLearning=false,
  tradeOutcome="UNKNOWN",
 }
end
local function trueCall(fn)
 local ok,v=pcall(fn)
 return ok and v==true
end
function M.new(scanner,outgoingFactory,coordinatorModule,bridge,io,
    players,me,ctx)
 if type(scanner)~="table" or
   type(scanner.getRecord)~="function" or
   type(scanner.isWhitelisted)~="function" or
   type(scanner.getWhitelist)~="function" or
   type(scanner.hasPendingWork)~="function" or
   type(outgoingFactory)~="table" or type(outgoingFactory.run)~="function" or
   type(coordinatorModule)~="table" or
   type(coordinatorModule.new)~="function" or
   type(bridge)~="table" or type(bridge.bind)~="function" or
   type(io)~="table" or type(io.trade)~="function" or
   type(io.partnerName)~="function" or
   (type(players)~="table" and type(players)~="userdata") or
   type(players.GetPlayerByUserId)~="function" or
   (type(me)~="table" and type(me)~="userdata") or
   type(ctx)~="table" or
   type(ctx.getJobId)~="function" or
   type(ctx.getP3Session)~="function" or
   type(ctx.onScreenSafe)~="function" or
   type(ctx.watchdogReady)~="function" or
   type(ctx.noOtherTransactionOwner)~="function" or
   type(ctx.readyCheck)~="function" then
  return nil,result("BLOCKED","SUPERVISOR_DEPENDENCIES_INVALID")
 end
 local okJ,job=pcall(ctx.getJobId)
 if not okJ or type(job)~="string" or job=="" then
  return nil,result("BLOCKED","P3_JOB_INVALID")
 end
 local outgoing,coordinator=nil,nil
 local state="INSTALLING"
 local epoch=nil
 local function epochLive()
  if state=="STOPPED" or outgoing==nil then return false end
  local okJ2,j=pcall(ctx.getJobId)
  local okS,e=pcall(ctx.getP3Session)
  return okJ2 and okS and j==job and e==epoch
     and outgoing.session==epoch
 end
 -- The actual gated P3 fork calls this AFTER the explicit operator arm.
 -- INSTALLING and PREPARED must ALWAYS return false.
 local function admission()
  if state~="ARM_PENDING" or coordinator==nil
     or not epochLive() or
     not trueCall(ctx.onScreenSafe) or
     not trueCall(ctx.watchdogReady) or
     not trueCall(ctx.noOtherTransactionOwner) or
     not trueCall(ctx.readyCheck) then
    return false
  end
  if type(outgoing.state)~="table" or
     outgoing.state.active~=nil or
     not trueCall(function()return outgoing.isPaused()==false end) then
    return false
  end
  local okT,trade=pcall(io.trade)
  return okT and trade==nil
 end
 local okRun,p3=pcall(outgoingFactory.run,scanner,{
    requiresExplicitStart=true,readyCheck=admission,
 })
 if not okRun or type(p3)~="table" or
    type(p3.arm)~="function" or type(p3.isArmed)~="function" or
    type(p3.stop)~="function" or type(p3.resume)~="function" or
    type(p3.isPaused)~="function" or type(p3.session)~="number" or
    type(p3.state)~="table" or
    type(p3.state.processed)~="table" then
  if type(p3)=="table" and type(p3.stop)=="function" then
   pcall(p3.stop)
  end
  return nil,result("BLOCKED","DEFAULT_CLOSED_P3_FORK_UNAVAILABLE")
 end
 outgoing=p3
 epoch=p3.session
 local okS,actualEpoch=pcall(ctx.getP3Session)
 if not okS or actualEpoch~=epoch then
  pcall(outgoing.stop)
  state="STOPPED"
  return nil,result("BLOCKED","P3_JOB_OR_EPOCH_CHANGED")
 end
 local okay,observer=pcall(coordinatorModule.new,
     scanner,outgoing,bridge,io,players,me,{
       getJobId=ctx.getJobId,getP3Session=ctx.getP3Session,
     })
 if not okay or type(observer)~="table" or
    type(observer.poll)~="function" or
    type(observer.resumeAfterClose)~="function" or
    type(observer.stop)~="function" then
  pcall(outgoing.stop)
  state="STOPPED"
  return nil,result("BLOCKED","P4_OBSERVER_ATTACH_REFUSED")
 end
 coordinator=observer
 state="PREPARED"
 local supervisor={}
 function supervisor.status()
  if state=="PREPARED" then
   return result("P3_SUPERVISOR_PREPARED_NOT_ARMED",
       "OBSERVATION_ATTACHED_NO_OUTGOING_REQUESTS")
  end
  if state=="ARMED" then
   return result("P3_SUPERVISOR_ARMED_CLIENT_ONLY",
       "P3_CLIENT_REQUESTS_ENABLED_FINAL_ACCEPT_DISABLED")
  end
  return result("BLOCKED","SUPERVISOR_"..state)
 end
 local function readyReason()
  if not epochLive() then return "P3_JOB_OR_EPOCH_CHANGED" end
  if not trueCall(ctx.onScreenSafe) then
   return "P3_ONSCREEN_INSTRUCTIONS_UNAVAILABLE"
  end
  if not trueCall(ctx.watchdogReady) then
   return "P3_WATCHDOG_NOT_READY"
  end
  if not trueCall(ctx.noOtherTransactionOwner) then
   return "P3_ANOTHER_TRANSACTION_OWNER"
  end
  if not trueCall(ctx.readyCheck) then
   return "P3_SCANNER_OR_LOBBY_NOT_READY"
  end
  local okT,trade=pcall(io.trade)
  if not okT or trade~=nil then
   return "P3_TRADE_WINDOW_ALREADY_OPEN"
  end
  if type(outgoing.state)~="table" or
     outgoing.state.active~=nil or
     not trueCall(function()return outgoing.isPaused()==false end) then
   return "P3_QUEUE_ALREADY_BUSY"
  end
  return nil
 end
 function supervisor.arm(approval)
  if state=="STOPPED" then return false,"SUPERVISOR_STOPPED" end
  if state~="PREPARED" then return false,"SUPERVISOR_ALREADY_ARMED" end
  if type(approval)~="table" or
     approval.explicitUserAuthorization~=true or
     approval.allowRealP3RequestRotation~=true or
     approval.finalAcceptMustRemainManual~=true then
   return false,"OPERATOR_AUTHORIZATION_MISSING"
  end
  local why=readyReason()
  if why then return false,why end
  state="ARM_PENDING"
  local ok,yes,reason=pcall(outgoing.arm)
  if not ok or yes~=true then
   state="PREPARED"
   return false,ok and tostring(reason or "P3_ARM_DENIED")
      or "P3_ARM_CALLBACK_FAILED"
  end
  state="ARMED"
  return true,"P3_QUEUE_ARMED_NO_FINAL_ACCEPT"
 end
 function supervisor.poll()
  if state~="ARMED" then return supervisor.status() end
  if not epochLive() then
   supervisor.stop()
   return result("BLOCKED","P3_JOB_OR_EPOCH_CHANGED")
  end
  -- The original P3 start-gate's readyCheck is checked when it arms,
  -- NOT on every subsequent request loop iteration. Close the gap:
  -- a live watchdog must call poll repeatedly while the queue is armed.
  -- Any lost on-screen safety, watchdog, or independent-transaction
  -- protection stops the REAL P3 loop rather than merely logging.
  for _,check in ipairs({
   {ctx.onScreenSafe,"P3_ONSCREEN_INSTRUCTIONS_LOST"},
   {ctx.watchdogReady,"P3_WATCHDOG_LOST"},
   {ctx.noOtherTransactionOwner,"P3_EXTERNAL_CONTROLLER_DETECTED"},
   {ctx.readyCheck,"P3_SCANNER_OR_LOBBY_UNSAFE"},
  }) do
   if not trueCall(check[1]) then
    supervisor.stop()
    return result("BLOCKED",check[2])
   end
  end
  local ok,observed=pcall(coordinator.poll)
  if not ok or type(observed)~="table" or
     type(observed.status)~="string" then
   supervisor.stop()
   return result("BLOCKED","P4_OBSERVER_POLL_FAILED")
  end
  if observed.status=="BLOCKED" then
   supervisor.stop()
   return result("BLOCKED","P4_OBSERVER_UNSAFE_STOPPED")
  end
  return observed
 end
 -- Read-only facade for the real original P3 fork's pause flag.
 -- No caller receives the mutable P3 state or request/Accept controls.
 function supervisor.isP3Paused()
  if state~="ARMED" or not epochLive() then return nil end
  local ok,v=pcall(outgoing.isPaused)
  return ok and type(v)=="boolean" and v or nil
 end
 function supervisor.resumeAfterClose()
  if state~="ARMED" then return false,"SUPERVISOR_NOT_ARMED" end
  if not epochLive() then return false,"P3_JOB_OR_EPOCH_CHANGED" end
  if not trueCall(ctx.onScreenSafe) or
     not trueCall(ctx.watchdogReady) or
     not trueCall(ctx.noOtherTransactionOwner) then
   supervisor.stop()
   return false,"P3_SUPERVISION_LOST_NO_RESUME"
  end
  local ok,yes,reason=pcall(coordinator.resumeAfterClose)
  if not ok or yes~=true then
   return false,ok and tostring(reason or "P4_CLOSE_UNVERIFIED")
      or "P4_RESUME_FAILED"
  end
  return true,"P3_RESUMED_AFTER_CLIENT_TRADE_CLOSED"
 end
 function supervisor.stop()
  if state=="STOPPED" then return false end
  state="STOPPED"
  pcall(outgoing.stop)
  pcall(coordinator.stop)
  return true
 end
 return supervisor,nil
end
return M
