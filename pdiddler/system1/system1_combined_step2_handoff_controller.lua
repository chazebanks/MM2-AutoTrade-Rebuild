-- Combined-only diagnostic fork of the original protected Step2
-- controller. No change to request/offer/decline/accept behavior.
-- System1 Step2 bounded public P3→P4 test orchestrator (injected/pure).
-- No Roblox remotes, item offers, final Accept, server hops, or market data.
-- P3 owns contacted targets and incoming/outgoing requests; P4 only closes
-- an EXACT previously validated paused trade. Missing evidence -> STOP.
local M={}
local function finite(t)
 return type(t)=="number" and t==t and t>=0 and t<math.huge
end
local function count(t)
 return type(t)=="number" and t==math.floor(t) and t>=0 and t<=3
end
local allowedFaults={
 "P3_NOT_ARMED", "P3_CANCEL_UNVERIFIED_STOP", "P3_AMBIGUOUS_SEND_STOP",
 "P3_CARD_FAILURE_WITH_ACTIVE_TRADE_UI",
 "P3_TRADE_TAP_RETURNED_UNCONFIRMED",
 "P3_POST_TAP_PENDING_UI_NOT_SEEN",
 "P3_PENDING_DISAPPEARED_UNCLASSIFIED",
 "P3_CANCEL_AFTER_PENDING_UNVERIFIED",
 "P3_HANDOFF_UNATTRIBUTED", "P3_PLAYER_IDENTITY_CHANGED",
 "P4_BOUND_SNAPSHOT_UNSAFE", "P4_OWN_ITEMS_UNEXPECTED",
 "P4_ROOT_REPLACED", "P4_DECLINE_FAILED_OR_UNCONFIRMED",
 "P3_UNEXPECTED_RESUME", "P3_GATE_STOPPED",
 "P3_PENDING_UI_AT_EXHAUSTION", "P3_DUPLICATE_TARGET",
 "P3_NO_CONSENTED_ELIGIBLE_SNAPSHOT", "P3_SESSION_OR_WATCHDOG_LOST",
 -- Combined-only terminal causes. Every one still STOPs before contacting
 -- another player; no fallback, retries or final Accept.
 "P3_WATCHDOG_BLOCKED", "P3_WATCHDOG_HEARTBEAT_MISSING",
 "P3_SESSION_EPOCH_CHANGED", "P3_SCREEN_OR_OWNER_LOST",
 "P3_OBSERVER_INVALID", "P3_P3_CONTROLLER_MISSING",
}
local allowed={}
for _,v in ipairs(allowedFaults) do allowed[v]=true end
function M.new(api,options)
 if type(api)~="table" or
  type(api.start)~="function" or type(api.inspect)~="function" or
  type(api.declineBound)~="function" or type(api.stop)~="function" or
  type(api.copyReport)~="function" or
  type(options)~="table" or
  options.explicitArm~=true or options.maxTargets~=3 or
  options.noItemOffers~=true or options.noFinalAccept~=true or
  options.noServerHop~=true or not finite(options.testDurationSeconds)
  or options.testDurationSeconds<60 or options.testDurationSeconds>240 then
  return nil,"STEP2_DEFAULT_CLOSED_OR_DEPENDENCY_MISSING"
 end
 local phase="PREPARING"
 local startedAt=nil
 local lastNow=0
 local active=nil
 local stable=0
 local closedCount=0
 local closedTargets={}
 local firstFault=nil
 local copyTried=false
 local reason="AWAIT_PUBLIC_TEST_OPERATOR_ARM"
 local lastAction="NONE"
 local possibleSideEffect=false
 local lastObserved=nil
 local function receipt()
  local observed=lastObserved or {}
  return {
   schema="gingerscope-system1-step2-public-p3p4-client-v1",
   status=phase=="DONE" and "PUBLIC_CLIENT_ROTATION_HANDOFF_PASS"
      or phase=="INCONCLUSIVE" and "CLIENT_ROTATION_ONLY_HANDOFF_NOT_PROVEN"
      or phase=="STOPPED" and "STOPPED" or phase,
   phase=phase,reason=reason,firstFault=firstFault,
   firstFailureEvidence=phase=="STOPPED" and observed.failureEvidence or nil,
   publicRequestDiagnostic={
    preTradeCardSkips=observed.preTradeCardSkips or 0,
    requestTargetsAttempted=observed.requestTargetsAttempted or 0,
    pendingUiEverConfirmed=observed.pendingUiEverConfirmed==true,
    originalP3SentConfirmed=observed.originalP3SentConfirmed or 0,
   },
   targetBudget=3,
   attemptedDistinctContacts=observed.distinctContacts or 0,
   processedTargets=observed.processedTargets or 0,
   frozenTargets=observed.frozenTargets or 0,
   acceptedRequests=observed.acceptedRequests or 0,
   ignoredRequests=observed.ignoredRequests or 0,
   declinedRequests=observed.declinedRequests or 0,
   incomingDeclined=observed.incomingDeclined or 0,
   provenBoundClientCloses=closedCount,
   guardedP4DeclinesAttempted=observed.autoDeclines or 0,
   serverCompletionProven=false,verifiedCompletedTrades=0,
   finalAcceptEverAttempted=false,authorizesAccept=false,
   authorizesOffer=false,actualOffers=0,actualTeleports=0,
   mayReportProfit=false,maySendDiscordWebhook=false,
   mayUseForStrategyLearning=false,tradeOutcome="UNKNOWN",
   copyAttempted=copyTried,possibleSideEffect=possibleSideEffect,
   lastAction=lastAction,clientOnly=true,
  }
 end
 local function stop(why,uncertain)
  if phase=="STOPPED" or phase=="DONE" or phase=="INCONCLUSIVE" then
   return receipt() end
  phase="STOPPED"
  firstFault=allowed[why] and why or "STEP2_UNKNOWN_SAFETY_FAULT"
  reason=firstFault
  possibleSideEffect=uncertain==true
  pcall(api.stop)
  copyTried=true
  pcall(api.copyReport,receipt())
  return receipt()
 end
 local function terminal(why,passed)
  phase=passed and "DONE" or "INCONCLUSIVE"
  reason=why
  pcall(api.stop)
  copyTried=true
  pcall(api.copyReport,receipt())
  return receipt()
 end
 local function validSnapshot(v)
  return type(v)=="table" and v.safe==true and
   count(v.frozenTargets) and count(v.processedTargets) and
   count(v.distinctContacts) and v.processedTargets<=v.frozenTargets and
   v.distinctContacts<=v.processedTargets and
   count(v.acceptedRequests) and
   count(v.ignoredRequests) and count(v.declinedRequests) and
   count(v.incomingDeclined) and
   count(v.preTradeCardSkips) and
   count(v.requestTargetsAttempted) and
   count(v.originalP3SentConfirmed) and
   type(v.pendingUiEverConfirmed)=="boolean" and
   v.clientTradeSettled==false and v.noFinalAccept==true and
   v.noItemsOffered==true and v.noServerHop==true and
   type(v.exhausted)=="boolean" and
   type(v.boundActive)=="boolean" and
   type(v.pendingVisible)=="boolean" and
   type(v.p3Paused)=="boolean" and
   type(v.autoDeclines)=="number" and v.autoDeclines>=0 and
   v.autoDeclines<=3
 end
 local controller={}
 function controller.arm(now)
  if phase~="PREPARING" or not finite(now) then
   return false,"STEP2_ARM_UNAVAILABLE" end
  lastAction="P3_PUBLIC_GATE_AND_SUPERVISOR_ARM"
  local ok,armed=pcall(api.start)
  if not ok or armed~=true then
   stop("P3_NO_CONSENTED_ELIGIBLE_SNAPSHOT")
   return false,"STEP2_P3_START_REJECTED"
  end
  startedAt=now;lastNow=now;phase="RUNNING"
  reason="P3_PUBLIC_ROTATION_RUNNING_P4_CLIENT_ONLY"
  return true,"STEP2_ARMED"
 end
 function controller.tick(now)
  if phase~="RUNNING" then return receipt() end
  if not finite(now) or now<lastNow then
   return stop("P3_SESSION_OR_WATCHDOG_LOST") end
  lastNow=now
  if now-startedAt>options.testDurationSeconds then
   return terminal("PUBLIC_TEST_TIMEOUT_INCOMPLETE",false) end
  local ok,observed=pcall(api.inspect)
  if not ok then
   return stop("P3_SESSION_OR_WATCHDOG_LOST") end
  if not validSnapshot(observed) then
   -- Prior combined script collapsed broken heartbeat/epoch/layout to a
   -- generic fault and discarded read-only first-fault evidence. These
   -- classifications remain terminal and never authorize a request.
   if type(observed)=="table" and
      type(observed.fault)=="string" and allowed[observed.fault] then
    lastObserved=observed
    return stop(observed.fault,observed.possibleSideEffect)
   end
   return stop("P3_OBSERVER_INVALID") end
  lastObserved=observed
  if observed.fault~=nil then
   return stop(observed.fault,observed.possibleSideEffect) end
  if observed.boundActive then
   if not observed.p3Paused or observed.pendingVisible then
    return stop("P3_HANDOFF_UNATTRIBUTED") end
   if observed.ourPhysicalSlots~=0 or
    observed.authenticatedP3Lease~=true or
    observed.safeP4Snapshot~=true or
    observed.unchangedTradeRoot~=true or
    type(observed.partnerUserId)~="number" then
    return stop("P4_BOUND_SNAPSHOT_UNSAFE") end
   if closedTargets[observed.partnerUserId] then
    return stop("P3_DUPLICATE_TARGET") end
   if active==nil or active.id~=observed.partnerUserId or
      active.root~=observed.root then
    if active~=nil then return stop("P4_ROOT_REPLACED") end
    active={id=observed.partnerUserId,root=observed.root}
    stable=1
    return receipt()
   end
   stable+=1
   if stable>=2 then
    -- Bound root and our empty offer proved twice. This only DECLINES.
    lastAction="P4_DECLINE_EXACT_BOUND_EMPTY_OWN_OFFER"
    local good,declined=pcall(api.declineBound,observed)
    if not good or declined~=true then
     return stop("P4_DECLINE_FAILED_OR_UNCONFIRMED",true) end
    closedTargets[observed.partnerUserId]=true
    closedCount+=1
    active=nil
    stable=0
   end
   return receipt()
  end
  if active~=nil then
   return stop("P3_UNEXPECTED_RESUME") end
  if observed.exhausted then
   if observed.pendingVisible or observed.p3Paused then
    return stop("P3_PENDING_UI_AT_EXHAUSTION") end
   if observed.distinctContacts>=2 and closedCount>=1 then
    return terminal("TWO_DISTINCT_CONTACTS_AND_BOUND_CLIENT_CLOSE_PROVEN",true)
   end
   return terminal("PUBLIC_ROTATION_HANDOFF_INCOMPLETE",false)
  end
  return receipt()
 end
 function controller.stop()
  lastAction="OPERATOR_STOP"
  return stop("P3_GATE_STOPPED")
 end
 function controller.status()return receipt()end
 function controller.copyNow()
  copyTried=true
  pcall(api.copyReport,receipt())
  return receipt()
 end
 return controller,nil
end
return M
