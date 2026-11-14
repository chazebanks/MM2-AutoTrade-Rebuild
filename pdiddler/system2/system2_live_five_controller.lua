-- System 2: FIVE distinct live original-MM2 research scenarios, ONE supervised ARM.
-- Pure Luau/Lua5.4 state machine; only injected, exact-ALT protected P3/P4 APIs.
-- DOES NOT implement market values, Discord transport, chat, learning, or final Accept.
-- Never report live market/Discord/profit completion from client GUI observations.
local M={}
local NAMES={
 "DISCORD_EVENT_PROVENANCE",
 "PARTNER_RESPONSE_REVISIONS",
 "BILATERAL_ALTERNATIVE_COMPARISON",
 "GINGERSCOPE_GROWTH_STRUCTURAL_GATES",
 "RESEARCH_REVISION_TERMINAL_STOP",
}
local function integer(n,a,b)
 return type(n)=="number" and n==math.floor(n) and n>=a and n<=b
end
local function target(s)
 return type(s)=="string" and
  s:lower():gsub("[^%w]",""):find("gingerscope",1,true)~=nil
end
local function side(rows)
 if type(rows)~="table" or getmetatable(rows)~=nil or #rows>4 then return nil end
 local out,slots={},{}
 local count=0
 for k,v in pairs(rows) do
  count=count+1
  if not integer(k,1,4) or k>#rows or type(v)~="table" or
     getmetatable(v)~=nil or not integer(v.physicalSlot,1,4) or
     slots[v.physicalSlot] or not integer(v.quantity,1,1000000) or
     type(v.displayCandidate)~="string" or #v.displayCandidate==0 or
     #v.displayCandidate>100 or v.displayCandidate:find("[%c]") or
     type(v.chromaCandidate)~="boolean" or
     v.rawItemIdAuthenticated~=false or
     (v.internalIdCandidate~=nil and
      (type(v.internalIdCandidate)~="string" or
       #v.internalIdCandidate>100 or v.internalIdCandidate:find("[%c]"))) then return nil end
  slots[v.physicalSlot]=true
  out[#out+1]={slot=v.physicalSlot,qty=v.quantity,
   name=v.displayCandidate,chroma=v.chromaCandidate,
   id=v.internalIdCandidate or ""}
 end
 if count~=#rows then return nil end
 table.sort(out,function(a,b)return a.slot<b.slot end)
 return out
end
local function same(a,b,ignoreSlot)
 if type(a)~="table" or type(b)~="table" or #a~=#b then return false end
 for i=1,#a do
  local x,y=a[i],b[i]
  if (not ignoreSlot and x.slot~=y.slot) or x.qty~=y.qty or
    x.name~=y.name or x.chroma~=y.chroma or x.id~=y.id then return false end
 end
 return true
end
local function survivor(before,after)
 if #after~=#before-1 then return false end
 local used={}
 for _,x in ipairs(after) do
  local matches,match=0,nil
  for i,y in ipairs(before) do
   if x.qty==y.qty and x.name==y.name and
      x.chroma==y.chroma and x.id==y.id then
    matches=matches+1;match=i
   end
  end
  if matches~=1 or used[match] then return false end
  used[match]=true
 end
 return true
end
local function clean(s)
 if type(s)~="table" or
    s.status~="CLIENT_UNPRICED_TWO_SIDED_SNAPSHOT" or
    s.partnerExactClientBound~=true or
    s.part3Paused~=true or s.part4TradeVisible~=true or
    s.requestOriginBound~=false or
    s.authorizesAccept~=false or s.authorizesOffer~=false or
    s.rawItemIdsAuthenticated~=false or s.pricesAuthenticated~=false or
    s.offerRevisionAuthenticated~=false or
    s.serverCompletionProven~=false or
    s.mayReportProfit~=false or s.maySendDiscordWebhook~=false or
    s.tradeOutcome~="UNKNOWN" then return nil end
 local a,b=side(s.ours),side(s.theirs)
 if not a or not b or #a~=s.physicalOwnSlots or #b~=s.physicalTheirSlots then return nil end
 for _,v in ipairs(a) do if target(v.name) or target(v.id) then return nil end end
 return {ours=a,theirs=b}
end
local function statusFor(round)
 if round==1 then return "BLOCKED_PREREQUISITE","LIVE_V2_DISCORD_INGRESS_NOT_VERIFIED" end
 if round==2 then return "LIVE_PASS","CLIENT_PARTNER_REVISION_ATTRIBUTED_NO_LEARNED_PREFERENCE" end
 if round==3 then return "BLOCKED_PREREQUISITE","PUBLISHER_AND_LIQUIDITY_AUTHORITY_UNPROVEN" end
 return "BLOCKED_PREREQUISITE","GROWTH_VALUE_AND_SELLER_WILLINGNESS_UNPROVEN"
end
function M.new(api,opt)
 if type(api)~="table" or type(opt)~="table" or
    opt.exactConsentingAlt~=true or opt.explicitFiveLiveConsent~=true or
    opt.finalAcceptDisabled~=true or opt.offlinePrerequisitesReviewed~=true or
    opt.twoDistinctCheapOwnItemsApproved~=true then
  return nil,"EXPLICIT_LIVE_TEST_CONTRACT_MISSING" end
 for _,fn in ipairs({"startEpoch","inspect","offerApproved","removeOwnOne",
   "decline","endEpoch","stopAll","copyReport","review"}) do
  if type(api[fn])~="function" then return nil,"REQUIRED_PROTECTED_ADAPTER_MISSING" end
 end
 local round,phase,processed,requestEpoch=1,"REQUESTING",0,0
 local root,lease=nil,nil
 local baseline=nil
 local prev,first,latest=nil,nil,nil
 local consecutive=0
 local entered,deadline,lastNow=0,0,-1
 local terminal=false
 local note="ARMED_NOT_STARTED"
 local firstFailure=nil
 local possibleSideEffect=false
 local stages={}
 for i,name in ipairs(NAMES) do
  stages[i]={scenario=name,status="NOT_RUN",reason="NOT_STARTED",
    clientObserved=false,offerRevisionsObserved=0,
    candidateOffersClientObserved=0,researchEvidenceEvaluations=0,
    structuralAlternativesConsidered=0,researchDecisionInvalidated=false,
    sourcePriceVerified=false,
    discordV2Delivered=false,clientOutcomeOnly=true}
 end
 local acts={requestsStarted=0,offersAttempted=0,offersClientVisible=0,
  removalsAttempted=0,declinesAttempted=0,closedWindows=0,finalAccepts=0}
 local lastAction="NONE"
 local function receipt()
  local copiedStages={}
  local passed,blocked=0,0
  for i,s in ipairs(stages) do
   if s.status=="LIVE_PASS" then passed=passed+1 end
   if s.status=="BLOCKED_PREREQUISITE" then blocked=blocked+1 end
   copiedStages[i]={scenario=s.scenario,status=s.status,reason=s.reason,
    clientObserved=s.clientObserved,
    offerRevisionsObserved=s.offerRevisionsObserved,
    candidateOffersClientObserved=s.candidateOffersClientObserved,
    researchEvidenceEvaluations=s.researchEvidenceEvaluations,
    structuralAlternativesConsidered=s.structuralAlternativesConsidered,
    researchDecisionInvalidated=s.researchDecisionInvalidated,
    discordV2Delivered=false,sourcePriceVerified=false,
    clientOutcomeOnly=true}
  end
  return {schema="gingerscope-system2-live-five-native-controller-v1",
   status=terminal and (firstFailure and "STOPPED" or "EXPECTED_TERMINAL_STOP") or "RUNNING",
   phase=phase,round=round,maxRounds=5,
   processedStages=processed,completedStages=passed,
   livePassedStages=passed,blockedPrerequisiteStages=blocked,
   remainingUnprocessedStages=5-processed,
   reason=note,firstFailureScenario=firstFailure,
   scenarios=copiedStages,actions={
    requestsStarted=acts.requestsStarted,offersAttempted=acts.offersAttempted,
    offersClientVisible=acts.offersClientVisible,
    removalsAttempted=acts.removalsAttempted,declinesAttempted=acts.declinesAttempted,
    clientClosedWindows=acts.closedWindows,finalAccepts=acts.finalAccepts},
   lastAction=lastAction,possibleSideEffect=possibleSideEffect,
   singleMainArm=true,actualMM2ClientEvidenceRequired=true,
   syntheticTestRun=false,serverCompletionProven=false,
   realMarketSourceAuthenticated=false,discordV2DeliveryVerified=false,
   verifiedCompletedTrades=0,authorizesOffer=false,authorizesTrade=false,
   authorizesAccept=false,publicFinalAcceptAuthorized=false,
   mayUseForStrategyLearning=false,mayReportProfit=false,
   maySendDiscordWebhook=false,tradeOutcome="UNKNOWN",
   instruction=(phase=="WAIT_OPEN" and "ALT: accept MAIN trade REQUEST, never final Accept.")
   or (phase=="WAIT_ALT_FIRST" and
    (round==4 and "ALT: offer one cheap weapon (quantity may be x2)." or
     "ALT: offer ONE cheap weapon; leave it stable."))
   or (phase=="WAIT_ALT_REVISED" and
    "ALT: REPLACE with a DIFFERENT cheap weapon (remove old first). No final Accept.")
   or (phase=="WAIT_ALT_CLEAR" and
    "ALT: remove ALL offered items. MAIN cleans up automatically.")
   or (phase=="STOPPED" and "STOP. COPY report; only manually close correct open trade.")
   or (phase=="EXPECTED_TERMINAL_STOP" and "EXPECTED STOP after change. COPY and manually Decline.")
   or (phase=="DONE" and "COPY result.")
   or ("MAIN automatic: "..phase..". ALT follow instructions. Never final Accept.")}
 end
 local function publish()
  pcall(api.copyReport,receipt())
 end
 local function stop(why,uncertain)
  if terminal then return receipt() end
  terminal=true;phase="STOPPED";note=why
  firstFailure=NAMES[round]
  stages[round].status="STOPPED";stages[round].reason=why
  if uncertain then possibleSideEffect=true end
  pcall(api.stopAll);publish()
  return receipt()
 end
 local function enter(p,now,why)
  phase=p;entered=now;note=why or "CLIENT_PHASE_ACTIVE"
  consecutive=0;prev=nil
  local seconds=(p=="WAIT_OPEN" and (opt.requestTimeout or 30)) or
   ((p=="WAIT_ALT_FIRST" or p=="WAIT_ALT_REVISED" or p=="WAIT_ALT_CLEAR")
     and (opt.altStepTimeout or 90)) or (opt.actionTimeout or 15)
  deadline=now+seconds
 end
 local function stable(obs)
  if prev and same(obs.ours,prev.ours) and same(obs.theirs,prev.theirs) then
   consecutive=consecutive+1
  else
   consecutive=1
   prev={ours=obs.ours,theirs=obs.theirs}
  end
  return consecutive>=2
 end
 local function assess(kind,ours,observed,revised)
  local ok,evidence=pcall(api.review,kind,ours,observed,revised)
  if not ok or type(evidence)~="table" or
      evidence.schema~="gingerscope-system2-native-client-strategy-evidence-v1" or
      evidence.status~="CLIENT_RESEARCH_EVIDENCE" or
      evidence.clientObservedButUnauthenticated~=true or
      evidence.marketPriceAuthenticated~=false or
      evidence.realDiscordV2Delivered~=false or
      evidence.serverSettlementProven~=false or
      evidence.authorizesOffer~=false or
      evidence.authorizesTrade~=false or
      evidence.authorizesAccept~=false or
      evidence.mayUseForStrategyLearning~=false or
      evidence.tradeOutcome~="UNKNOWN" then
   return false
  end
  local row=stages[round]
  row.researchEvidenceEvaluations=row.researchEvidenceEvaluations+1
  row.structuralAlternativesConsidered=evidence.bilateralClientAlternativeCount or
    evidence.distinctStructuralPathOptions or 0
  row.researchDecisionInvalidated=evidence.firstResearchCandidateInvalidated==true
  return true
 end
 local function request(now)
  requestEpoch=requestEpoch+1
  acts.requestsStarted=acts.requestsStarted+1;lastAction="START_NEW_PROTECTED_P3_EPOCH"
  local ok,yes,newLease=pcall(api.startEpoch,round,requestEpoch)
  if not ok or yes~=true or newLease==nil then return stop("FRESH_P3_EPOCH_FAILED",true) end
  lease=newLease;root=nil;first=nil;latest=nil;baseline=nil
  stages[round].status="RUNNING";stages[round].reason="WAITING_LIVE_CLIENT_EVIDENCE"
  enter("WAIT_OPEN",now,"WAITING_ORIGINAL_MM2_ALT_REQUEST")
  return receipt()
 end
 local function inspect()
  local ok,ob=pcall(api.inspect,round,lease)
  if not ok or type(ob)~="table" or ob.sessionFresh~=true or
      ob.exactPartner~=true or ob.noOtherController~=true or
      ob.p3Status=="BLOCKED" or ob.p3Status=="P3_PAUSED_UNATTRIBUTED" then
   return nil,"P3_PARTNER_OR_LEASE_UNSAFE"
  end
  if ob.root==nil then
   if ob.snapshot~=nil then return nil,"STALE_SNAPSHOT_WITHOUT_ROOT" end
   return {root=nil}
  end
  if type(ob.root)~="table" and type(ob.root)~="userdata" then
   return nil,"INVALID_CLIENT_ROOT"
  end
  local s=clean(ob.snapshot)
  if not s then return nil,"PROTECTED_CLIENT_SNAPSHOT_INVALID" end
  s.root=ob.root
  return s
 end
 local function passRound(now)
  local r,why=statusFor(round)
  stages[round].status=r;stages[round].reason=why
  stages[round].clientObserved=true
  processed=processed+1;acts.closedWindows=acts.closedWindows+1
  local ok,yes=pcall(api.endEpoch,round,lease)
  if not ok or yes~=true then return stop("OLD_PROTECTED_EPOCH_DID_NOT_CLOSE",true) end
  round=round+1
  enter("REQUESTING",now,"NEXT_DIFFERENT_STRATEGY_SCENARIO")
  return request(now)
 end
 local function tick(now)
  if terminal then return receipt() end
  if type(now)~="number" or now~=now or now==math.huge or
    now==-math.huge or now<lastNow then return stop("NONMONOTONIC_TEST_CLOCK") end
  lastNow=now
  if phase=="REQUESTING" then return request(now) end
  if now>deadline then return stop("TIMEOUT_"..phase,false) end
  local ob,err=inspect()
  if not ob then return stop(err,false) end
  if phase=="WAIT_OPEN" then
   if not ob.root then return receipt() end
   root=ob.root;enter("CHECK_EMPTY",now,"CLIENT_WINDOW_BOUND")
   return receipt()
  end
  if phase=="WAIT_CLOSE" then
   if ob.root~=nil then
    if ob.root~=root then return stop("CLOSE_ROOT_REPLACED") end
    return receipt()
   end
   return passRound(now)
  end
  if ob.root~=root then return stop("TRADE_ROOT_CHANGED_OR_CLOSED") end
  if phase=="CHECK_EMPTY" then
   if #ob.ours~=0 or #ob.theirs~=0 then return stop("INITIAL_TRADE_NOT_EMPTY") end
   if not stable(ob) then return receipt() end
   if round==3 or round==4 then
    enter("MAIN_OFFER",now,"SOURCE_GUARDED_BILATERAL_LAYOUT")
   else enter("WAIT_ALT_FIRST",now,"RESEARCH_EVENT_BASELINE") end
   return receipt()
  end
  if phase=="MAIN_OFFER" then
   if #ob.ours~=0 or #ob.theirs~=0 then return stop("MAIN_PREOFFER_CHANGED") end
   local n=round==4 and 2 or 1
   acts.offersAttempted=acts.offersAttempted+n
   lastAction="GUARDED_MAIN_OFFER"
   local ok,r=pcall(api.offerApproved,round,n,lease,1)
   if not ok or type(r)~="table" or
      r.status~="CLIENT_MANUAL_PLAN_VISIBLE_UNATTRIBUTED" or
      r.authorizesAccept~=false or r.serverCompletionProven~=false or
      r.tradeOutcome~="UNKNOWN" or
      r.offerAttempts~=n or r.clientVisibleAddedSlots~=n then
    return stop("GUARDED_OFFER_UNCONFIRMED",true)
   end
   acts.offersClientVisible=acts.offersClientVisible+n
   enter("WAIT_MAIN_VISIBLE",now,"CLIENT_MAIN_OFFER_CONFIRMATION")
   return receipt()
  end
  if phase=="WAIT_MAIN_VISIBLE" then
   local n=round==4 and 2 or 1
   if #ob.ours~=n or #ob.theirs~=0 then return stop("MAIN_OFFER_NOT_RECONCILED",true) end
   if stable(ob) then
    baseline=ob.ours
    enter("WAIT_ALT_FIRST",now,"ALT_COUNTERPARTY_REAL_OFFER")
   end
   return receipt()
  end
  if phase=="WAIT_ALT_FIRST" then
   local n=(round==3 and 1) or (round==4 and 2) or 0
   if #ob.ours~=n or (baseline and not same(ob.ours,baseline)) then
    return stop("MAIN_SIDE_CHANGED_WHILE_ASSESSING") end
   if #ob.theirs>1 then return stop("UNEXPECTED_EXTRA_COUNTERPARTY_SLOTS") end
   if #ob.theirs==0 then return receipt() end
   if not stable(ob) then return receipt() end
   first=ob.theirs
   latest=first
   stages[round].clientObserved=true
   stages[round].candidateOffersClientObserved=1
   if (round==1 or round==4) and
      not assess(round==1 and "EVENT_PROVENANCE" or "GROWTH_STRUCTURE",
        ob.ours,first,nil) then
    return stop("SYSTEM2_CLIENT_RESEARCH_EVALUATION_FAILED")
   end
   if round==2 or round==3 or round==5 then
    enter("WAIT_ALT_REVISED",now,"FIRST_OFFER_RECORDED_RESEARCH_ONLY")
   else
    enter("WAIT_ALT_CLEAR",now,"CLIENT_EVENT_CAPTURABLE_NOT_SETTLEMENT")
   end
   return receipt()
  end
  if phase=="WAIT_ALT_REVISED" then
   local n=round==3 and 1 or 0
   if #ob.ours~=n or (baseline and not same(ob.ours,baseline)) then
    return stop("MAIN_SIDE_CHANGED_DURING_REVISION") end
   if #ob.theirs>1 then return stop("REVISION_UNEXPECTED_EXTRA_SLOTS") end
   if #ob.theirs==0 or same(ob.theirs,first) then
    consecutive=0;prev=nil;return receipt()
   end
   if not stable(ob) then return receipt() end
   latest=ob.theirs
   stages[round].offerRevisionsObserved=1
   stages[round].candidateOffersClientObserved=2
   local scenarioKind=round==2 and "BEHAVIOR_REVISION" or
      (round==3 and "BILATERAL_ALTERNATIVES" or "INVALIDATE_STALE_RESEARCH")
   if not assess(scenarioKind,ob.ours,first,latest) then
    return stop("SYSTEM2_CLIENT_RESEARCH_EVALUATION_FAILED")
   end
   if round==5 then
    -- Deliberate fail-stop: do NOT send a request, offer or Accept after
    -- a previously observed research candidate changes.
    stages[round].clientObserved=true
    stages[round].status="LIVE_PASS"
    stages[round].reason="CLIENT_RESEARCH_PREVIEW_INVALIDATED_ON_REVISION"
    processed=processed+1
    terminal=true;phase="EXPECTED_TERMINAL_STOP"
    note="EXPECTED_REVISION_FAILSTOP_NO_FURTHER_ACTION"
    lastAction="STOP_ON_RESEARCH_REVISION"
    pcall(api.stopAll);publish()
    return receipt()
   end
   enter("WAIT_ALT_CLEAR",now,"STALE_RESEARCH_CANDIDATE_INVALIDATED")
   return receipt()
  end
  if phase=="WAIT_ALT_CLEAR" then
   local n=(round==3 and 1) or (round==4 and 2) or 0
   if #ob.ours~=n or (baseline and not same(ob.ours,baseline)) then
    return stop("MAIN_SIDE_CHANGED_BEFORE_CLEANUP") end
   if #ob.theirs>1 then return stop("EXTRA_COUNTERPARTY_SLOTS_WHILE_CLEARING") end
   if #ob.theirs==1 then
    if not same(ob.theirs,latest) then return stop("UNEXPECTED_NEW_ALT_REVISION") end
    consecutive=0;prev=nil;return receipt()
   end
   if not stable(ob) then return receipt() end
   if n>0 then enter("MAIN_WITHDRAW",now,"GUARDED_OWN_CLEAR_REQUIRED")
   else enter("MAIN_DECLINE",now,"SAFE_BOTH_SIDES_EMPTY") end
   return receipt()
  end
  if phase=="MAIN_WITHDRAW" then
   if #ob.theirs~=0 or #ob.ours<1 or
       (baseline and not same(ob.ours,baseline)) then
    return stop("WITHDRAW_PRECONDITION_CHANGED") end
   lastAction="GUARDED_OWN_WITHDRAW_ONE"
   acts.removalsAttempted=acts.removalsAttempted+1
   local ok,yes=pcall(api.removeOwnOne,round,root,lease,false)
   if not ok or yes~=true then return stop("OWN_WITHDRAW_UNCONFIRMED",true) end
   enter("WAIT_REMOVAL",now,"VERIFY_OWN_SLOT_REMOVED")
   return receipt()
  end
  if phase=="WAIT_REMOVAL" then
   if #ob.theirs~=0 or not baseline then return stop("ALT_CHANGED_DURING_WITHDRAW") end
   if #ob.ours>#baseline then return stop("OWN_SIDE_GREW_DURING_WITHDRAW") end
   if #ob.ours==#baseline then return receipt() end
   if not survivor(baseline,ob.ours) then
    return stop("OWN_SURVIVOR_IDENTITY_AMBIGUOUS") end
   if not stable(ob) then return receipt() end
   baseline=ob.ours
   if #ob.ours==0 then enter("MAIN_DECLINE",now,"ALL_OWN_ITEMS_CLEARED")
   else enter("MAIN_WITHDRAW",now,"WITHDRAW_NEXT_APPROVED_ITEM") end
   return receipt()
  end
  if phase=="MAIN_DECLINE" then
   if #ob.ours~=0 or #ob.theirs~=0 then return stop("DECLINE_SIDES_NOT_EMPTY") end
   lastAction="GUARDED_MAIN_DECLINE"
   acts.declinesAttempted=acts.declinesAttempted+1
   local ok,yes=pcall(api.decline,round,root,lease)
   if not ok or yes~=true then return stop("DECLINE_UNCONFIRMED",true) end
   enter("WAIT_CLOSE",now,"AWAIT_BOUND_WINDOW_CLOSE")
   return receipt()
  end
  return stop("UNHANDLED_SYSTEM2_PHASE",true)
 end
 local busy=false
 return {
  tick=function(now)
   if busy then return stop("REENTRANT_TEST_TICK",true) end
   busy=true
   local ok,out=pcall(tick,now)
   busy=false
   if not ok then return stop("CONTROLLER_EXCEPTION",true) end
   return out
  end,
  stop=function()return stop("OPERATOR_STOPPED",false) end,
  abort=function(code)
   if type(code)~="string" or not code:match("^[A-Z0-9_]+$") or
     #code>100 then code="NATIVE_RUNTIME_FAULT" end
   return stop(code,true)
  end,
  status=receipt,
  copyNow=publish,
 },nil
end
return M
