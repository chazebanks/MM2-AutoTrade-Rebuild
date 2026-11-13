-- System1 controlled ONE-SERVER ALT recovery -> public P3/P4 transition.
-- Pure injected state machine: no Roblox network, no offers or final Accept.
-- It never resets the original P3 numeric epoch; next controller increments it.
local M={}
local function number(n)
 return type(n)=="number" and n==n and n>=0 and n<math.huge
end
local scenarioNames={
 "ALT_REPLACES_ITEM","ALT_STACK_X1_TO_X2","ALT_CLEAR_THEN_NEW",
}
local function checkedStep1(r)
 if type(r)~="table" or
    r.status~="CLIENT_TEST_SEQUENCE_COMPLETE" or
    r.phase~="DONE" or
    r.reason~="ALL_THREE_RECOVERY_CLIENT_SCENARIOS_VERIFIED" or
    r.completedRounds~=3 or r.maxRounds~=3 or
    r.recoveryBatchAuthorized~=true or
    r.authorizesAccept~=false or
    r.finalAcceptEverAttempted~=false or
    r.serverCompletionProven~=false or
    r.verifiedCompletedTrades~=0 or
    r.possibleSideEffect~=false or
    type(r.actions)~="table" or
    r.actions.requestsStarted~=3 or
    r.actions.offersClientVisible~=6 or
    r.actions.removalsAttempted~=6 or
    r.actions.declinesAttempted~=3 or
    r.actions.clientClosedWindows~=3 or
    r.actions.adaptiveReoffersAttempted~=3 or
    type(r.rounds)~="table" or #r.rounds~=3 then
  return false
 end
 for i,name in ipairs(scenarioNames)do
  local v=r.rounds[i]
  if type(v)~="table" or v.round~=i or
     v.scenarioId~=name or
     v.clientWindowClosed~=true or
     v.status~="CLIENT_SEQUENCE_PASS" then return false end
 end
 return true
end
local function checkedStep2(r)
 return type(r)=="table" and
  r.status=="PUBLIC_CLIENT_ROTATION_HANDOFF_PASS" and
  r.phase=="DONE" and
  r.reason=="TWO_DISTINCT_CONTACTS_AND_BOUND_CLIENT_CLOSE_PROVEN" and
  r.targetBudget==3 and
  number(r.attemptedDistinctContacts) and
  r.attemptedDistinctContacts>=2 and
  r.attemptedDistinctContacts<=3 and
  number(r.provenBoundClientCloses) and
  r.provenBoundClientCloses>=1 and
  r.provenBoundClientCloses<=3 and
  type(r.publicRequestDiagnostic)=="table" and
  number(r.publicRequestDiagnostic.originalP3SentConfirmed) and
  r.publicRequestDiagnostic.originalP3SentConfirmed>=
    r.attemptedDistinctContacts and
  r.authorizesAccept==false and
  r.authorizesOffer==false and
  r.finalAcceptEverAttempted==false and
  r.actualOffers==0 and r.actualTeleports==0 and
  r.serverCompletionProven==false and
  r.verifiedCompletedTrades==0 and
  r.possibleSideEffect==false
end
function M.new(api,opts)
 if type(api)~="table" or
  type(api.launchStep1)~="function" or
  type(api.step1Status)~="function" or
  type(api.quiescent)~="function" or
  type(api.launchStep2)~="function" or
  type(api.step2Status)~="function" or
  type(api.stopActive)~="function" or
  type(api.emit)~="function" or
  type(api.jobMatches)~="function" or
  type(opts)~="table" or
  opts.oneServerOnly~=true or opts.noFinalAccept~=true or
  opts.noItemTransfer~=true or opts.noServerHop~=true then
  return nil,"COMBINED_CONTROLLER_DEFAULT_CLOSED"
 end
 local phase="PREPARING"
 local reason="ONE_SERVER_LOADER_AWAITED"
 local t0=0
 local changedAt=0
 local terminalEmitted=false
 local phase1=nil
 local phase2=nil
 local retirement=nil
 local quiescenceProof=0
 local firstFault=nil
 local step1Failure=nil
 local step2Failure=nil
 local preflightFailure=nil
 -- Preserve no free-form usernames, inventories, GUI text or raw IDs.
 local function enum(v)
  return type(v)=="string" and #v<=72 and
   v:match("^[A-Z0-9_]+$") and v or "UNKNOWN"
 end
 local function num(v,max)
  return type(v)=="number" and v==v and v>=0 and
   v<=max and v==math.floor(v) and v or 0
 end
 local function childFault(r)
  if type(r)~="table" then return {reason="NO_CHILD_RECEIPT"}end
  local actions=type(r.actions)=="table" and r.actions or {}
  local p=type(r.firstFailureEvidence)=="table" and
    r.firstFailureEvidence or {}
  return {
   reason=enum(r.reason),phase=enum(r.phase),
   scenarioId=enum(r.scenarioId),lastAction=enum(r.lastAction),
   round=num(r.round,8),completedRounds=num(r.completedRounds,8),
   requestAttempts=num(actions.requestsStarted,12),
   offersClientVisible=num(actions.offersClientVisible,24),
   removalsAttempted=num(actions.removalsAttempted,24),
   declinesAttempted=num(actions.declinesAttempted,12),
   clientClosedWindows=num(actions.clientClosedWindows,12),
   possibleSideEffect=r.possibleSideEffect==true,
   childCopyAttempted=r.copyAttempted==true,
   firstFailureEvidence={
    expectedQuantity=num(p.expectedQuantity,20),
    observedQuantity=num(p.observedQuantity,20),
    lastClearQuantity=num(p.lastClearQuantity,20),
    sameVisibleName=p.sameVisibleName==true,
    sameChroma=p.sameChroma==true,
    sameSlot=p.sameSlot==true,
    sameClientIdCandidate=p.sameClientIdCandidate==true,
   },
  }
 end
 local function result()
  return {
   schema="gingerscope-system1-one-server-integration-client-v1",
   status=phase=="DONE" and "ONE_SERVER_SYSTEM1_CLIENT_INTEGRATION_PASS"
     or phase=="STOPPED" and "STOPPED"
     or phase=="INCONCLUSIVE" and "INCONCLUSIVE" or phase,
   phase=phase,reason=reason,
   firstFault=firstFault,
   step1Failure=step1Failure,
   step2Failure=step2Failure,
   preflightFailure=preflightFailure,
   step1ThreeWindowsVerified=phase1~=nil,
   step1ClosedWindows=phase1 and 3 or 0,
   step2AttemptedDistinctContacts=phase2 and
    phase2.attemptedDistinctContacts or 0,
   step2VerifiedBoundCloses=phase2 and
    phase2.provenBoundClientCloses or 0,
   sameGameJobMaintained=api.jobMatches()==true,
   reusedOriginalProtectedParts=true,
   combinedScriptsSerialized=true,
   originalP3EpochNeverReset=true,
   quiescenceChecks=quiescenceProof,
   clientOnly=true,actualTeleports=0,
   finalAcceptEverAttempted=false,authorizesAccept=false,
   serverCompletionProven=false,verifiedCompletedTrades=0,
   mayReportProfit=false,maySendDiscordWebhook=false,
   mayUseForStrategyLearning=false,tradeOutcome="UNKNOWN",
  }
 end
 local function finalize(why,pass)
  if phase=="DONE" or phase=="STOPPED" or phase=="INCONCLUSIVE" then
   return result()end
  phase=pass and "DONE" or "INCONCLUSIVE"
  reason=why
  pcall(api.stopActive)
  if not terminalEmitted then
   terminalEmitted=true;pcall(api.emit,result())
  end
  return result()
 end
 local function stop(why,child)
  if phase=="DONE" or phase=="STOPPED" or phase=="INCONCLUSIVE" then
   return result()end
  if why=="COMBINED_STEP1_STOPPED" or
     why=="COMBINED_STEP1_PREARM_STOPPED" or
     why=="COMBINED_STEP1_LEDGER_NOT_VERIFIED" then
   step1Failure=childFault(child)
  elseif why=="COMBINED_STEP2_STOPPED" or
     why=="COMBINED_STEP2_LEDGER_NOT_VERIFIED" then
   step2Failure=childFault(child)
  end
  phase="STOPPED";reason=why;firstFault=why
  pcall(api.stopActive)
  if not terminalEmitted then
   terminalEmitted=true;pcall(api.emit,result())
  end
  return result()
 end
 local C={}
 -- Pre-arm checks never send a request. A bounded timeout must issue its
 -- own precise sanitised fault, without pretending the Step1 controller
 -- was started or invoking a second run in the same server.
 function C.preflightAbort(code,checks)
  if phase~="PREPARING" then return result() end
  preflightFailure={
   reason=enum(code),
   stableReadinessChecks=num(checks,100),
   tradeRequestAttempted=false,
   tradeOfferAttempted=false,
  }
  return stop("COMBINED_STEP1_PREFLIGHT_NOT_READY")
 end
 function C.start(now)
  if phase~="PREPARING" or not number(now) or not api.jobMatches() then
   return false,"COMBINED_INITIAL_START_DENIED" end
  local ok,yes=pcall(api.launchStep1)
  if not ok or yes~=true then
   local sourceFailure=nil
   if type(api.startFailure)=="function" then
    local captured,detail=pcall(api.startFailure)
    if captured then sourceFailure=detail end
   end
   step1Failure=childFault(sourceFailure)
   stop("COMBINED_STEP1_PIN_OR_START_FAILED")
   return false,"COMBINED_STEP1_PIN_OR_START_FAILED"
  end
  t0=now;changedAt=now;phase="STEP1";reason="ARM3_ALT_RECOVERY_FIRST"
  return true,"ONE_SERVER_STARTED_STEP1"
 end
 function C.tick(now)
  if phase=="DONE" or phase=="STOPPED" or phase=="INCONCLUSIVE" or
     phase=="PREPARING" then return result()end
  if not number(now) or not api.jobMatches() then
   return stop("COMBINED_JOB_CHANGED_OR_INVALID_CLOCK")end
  if now<t0 or now-t0>900 then
   return stop("COMBINED_BOUNDED_SESSION_TIMEOUT")end
  if phase=="STEP1" then
   local ok,r=pcall(api.step1Status)
   if not ok or type(r)~="table" then
    return stop("COMBINED_STEP1_STATUS_UNREADABLE")end
   if r.phase=="STOPPED" or r.status=="STOPPED" then
    return stop("COMBINED_STEP1_STOPPED",r)end
   if r.phase=="SELECT_TWO_OWN_ITEMS" and
      r.status=="PREPARING" and
      r.reason~="NO_REQUESTS_UNTIL_ARM_BUTTON" and
      r.reason~="NOT_ARMED" then
    return stop("COMBINED_STEP1_PREARM_STOPPED",r)end
   if r.phase=="DONE" or r.status=="CLIENT_TEST_SEQUENCE_COMPLETE" then
    if not checkedStep1(r) then
     return stop("COMBINED_STEP1_LEDGER_NOT_VERIFIED",r)end
    phase1=r;phase="QUIESCENCE";reason="WAIT_OLD_P3_RETIREMENT"
    changedAt=now
   end
  elseif phase=="QUIESCENCE" then
   if now-changedAt>12 then
    return stop("COMBINED_PRE_STEP2_QUIESCENCE_TIMEOUT")end
   local ok,proof=pcall(api.quiescent)
   if not ok or type(proof)~="table" or proof.safe~=true or
      not number(proof.epoch) or proof.epoch<1 or
      proof.epoch~=math.floor(proof.epoch) then
    -- Do not count uncertain observations. If it stays uncertain, STOP.
    quiescenceProof=0
    return result()
   end
   if retirement and retirement~=proof.epoch then
    return stop("COMBINED_P3_EPOCH_CHANGED_DURING_QUIESCENCE")end
   retirement=proof.epoch
   quiescenceProof+=1
   if quiescenceProof>=4 and now-changedAt>=1 then
    local okay,launched=pcall(api.launchStep2,retirement)
    if not okay or launched~=true then
     return stop("COMBINED_STEP2_TRANSITION_DENIED")end
    phase="STEP2";reason="PUBLIC_P3_ROTATION_THEN_P4_CLOSE"
    changedAt=now
   end
  elseif phase=="STEP2" then
   local ok,r=pcall(api.step2Status)
   if not ok or type(r)~="table" then
    return stop("COMBINED_STEP2_STATUS_UNREADABLE")end
   if r.phase=="STOPPED" or r.status=="STOPPED" then
    return stop("COMBINED_STEP2_STOPPED",r)end
   if r.phase=="INCONCLUSIVE" then
    return finalize("COMBINED_STEP2_NOT_PROVEN",false)end
   if r.phase=="DONE" or r.status=="PUBLIC_CLIENT_ROTATION_HANDOFF_PASS" then
    if not checkedStep2(r) then
     return stop("COMBINED_STEP2_LEDGER_NOT_VERIFIED",r)end
    phase2=r
    return finalize("ALT_RECOVERY_AND_PUBLIC_P3P4_SAME_JOB_PROVEN",true)
   end
   if now-changedAt>320 then
    return finalize("COMBINED_STEP2_NO_DEVICE_COMPLETION",false)end
  end
  return result()
 end
 function C.stop()return stop("OPERATOR_STOPPED_COMBINED_TEST")end
 function C.status()return result()end
 function C.copy()pcall(api.emit,result());return result()end
 return C,nil
end
return M
