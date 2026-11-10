-- Continuous supervisor watchdog for the REAL default-closed P3 outgoing queue.
-- Start this from a real native on-screen runner BEFORE calling P3 arm.
-- It attaches ONE scheduled task, proves a fresh heartbeat before P3 may
-- request a trade, checks client supervision while armed, and resumes P3
-- ONLY after the original P4 bound trade window is actually closed.
-- No OfferItem/Accept/Decline/request/hop/market/Discord actions here.
local M={}
local function report(status,reason)
 return {
  schema="pdiddler-supervised-p3-watchdog-v1",
  status=status,reason=reason,
  requestOriginBound=false,rawItemIdsAuthenticated=false,
  pricesAuthenticated=false,part3RotationAuthorized=false,
  authorizesOffer=false,authorizesAccept=false,
  serverCompletionProven=false,mayReportProfit=false,
  maySendDiscordWebhook=false,tradeOutcome="UNKNOWN",
 }
end
local function good(fn)
 local ok,v=pcall(fn)
 return ok and v==true
end
function M.new(supervisor,p3,io,ctx,scheduler)
 if type(supervisor)~="table" or
    type(supervisor.status)~="function" or
    type(supervisor.arm)~="function" or
    type(supervisor.poll)~="function" or
    type(supervisor.resumeAfterClose)~="function" or
    type(supervisor.stop)~="function" or
    type(p3)~="table" or
    type(p3.isPaused)~="function" or
    type(io)~="table" or
    type(io.trade)~="function" or
    type(ctx)~="table" or
    type(ctx.getJobId)~="function" or
    type(ctx.isLive)~="function" or
    type(ctx.onStatus)~="function" or
    type(scheduler)~="table" or
    type(scheduler.spawn)~="function" or
    type(scheduler.wait)~="function" or
    type(scheduler.now)~="function" then
  return nil,report("BLOCKED","WATCHDOG_DEPENDENCIES_INVALID")
 end
 local okJob,job=pcall(ctx.getJobId)
 if not okJob or type(job)~="string" or job=="" then
  return nil,report("BLOCKED","WATCHDOG_JOB_INVALID")
 end
 local running=false
 local started=false
 local ticks=0
 local heartbeat=nil
 local lastResult=report("BLOCKED","WATCHDOG_NOT_STARTED")
 local watchdog={}
 local function now()
  local ok,value=pcall(scheduler.now)
  if not ok or type(value)~="number" or
     value~=value or value<0 then return nil end
  return value
 end
 local function sessionLive()
  local ok,v=pcall(ctx.getJobId)
  return ok and v==job and good(ctx.isLive)
 end
 function watchdog.isReady()
  if not running or not started or ticks<1 or not sessionLive() then
   return false
  end
  local current=now()
  return current~=nil and heartbeat~=nil and
     current>=heartbeat and current-heartbeat<=0.55
 end
 function watchdog.status()
  return lastResult
 end
 function watchdog.stop()
  if not running and started then return false end
  running=false
  pcall(supervisor.stop)
  lastResult=report("BLOCKED","WATCHDOG_STOPPED")
  return true
 end
 function watchdog.tick()
  if not running then return report("BLOCKED","WATCHDOG_NOT_RUNNING") end
  if not sessionLive() or now()==nil then
   watchdog.stop()
   lastResult=report("BLOCKED","P3_WATCHDOG_SESSION_LOST")
   return lastResult
  end
  ticks+=1
  heartbeat=now()
  local okS,phase=pcall(supervisor.status)
  if not okS or type(phase)~="table" or
     type(phase.status)~="string" then
   watchdog.stop()
   lastResult=report("BLOCKED","P3_SUPERVISOR_STATUS_UNAVAILABLE")
   return lastResult
  end
  local observed
  if phase.status=="P3_SUPERVISOR_ARMED_CLIENT_ONLY" then
   local okP,paused=pcall(p3.isPaused)
   local okT,trade=pcall(io.trade)
   if not okP or not okT then
    watchdog.stop()
    lastResult=report("BLOCKED","P3_WATCHDOG_TRADE_READ_FAILED")
    return lastResult
   end
   if paused==true and trade==nil then
    -- A stopped P3 queue cannot infer settlement. The *existing* PR207
    -- bound session coordinator verifies closed root before resume.
    local okR,resumed=pcall(supervisor.resumeAfterClose)
    if okR and resumed==true then
     observed=report("P3_RESUMED_AFTER_CLIENT_TRADE_CLOSED",
       "CLIENT_CLOSED_BOUND_TRADE_NO_SETTLEMENT")
    elseif not okR then
     watchdog.stop()
     lastResult=report("BLOCKED","P3_WATCHDOG_RESUME_CALLBACK_FAILED")
     return lastResult
    end
   end
  end
  if not observed then
   local okP,snapshot=pcall(supervisor.poll)
   if not okP or type(snapshot)~="table" or
      type(snapshot.status)~="string" then
    watchdog.stop()
    lastResult=report("BLOCKED","P3_WATCHDOG_POLL_FAILED")
    return lastResult
   end
   observed=snapshot
  end
  lastResult=observed
  local okPublish=pcall(ctx.onStatus,observed)
  if not okPublish then
   watchdog.stop()
   lastResult=report("BLOCKED","P3_WATCHDOG_STATUS_UI_FAILED")
   return lastResult
  end
  if observed.status=="BLOCKED" and
     phase.status=="P3_SUPERVISOR_ARMED_CLIENT_ONLY" then
   watchdog.stop()
   lastResult=observed
   return observed
  end
  return observed
 end
 local function loop()
  while running do
   watchdog.tick()
   if not running then break end
   local waited=pcall(scheduler.wait,0.15)
   if not waited then
    watchdog.stop()
    break
   end
  end
 end
 function watchdog.start()
  if started then return false,"WATCHDOG_ALREADY_STARTED" end
  if not sessionLive() or now()==nil then
   return false,"P3_WATCHDOG_SESSION_LOST"
  end
  started=true
  running=true
  local ok=pcall(scheduler.spawn,loop)
  if not ok then
   watchdog.stop()
   return false,"P3_WATCHDOG_SCHEDULE_FAILED"
  end
  return true,"WATCHDOG_SCHEDULED_NOT_YET_HEARTBEATING"
 end
 return watchdog,nil
end
return M
