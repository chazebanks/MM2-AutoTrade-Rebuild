-- SYSTEM1 supervised MAIN automatic test controller: pure, injected adapters.
-- Human authorizes the ENTIRE exact ALT four-round test at startup; ALT manually
-- ACCEPTS REQUESTS and adds/removes items when instructed. MAIN automatically
-- requests a fresh epoch, offers only approved own items, withdraws, DECLINES.
-- Any unexpected event -> terminal STOP, sanitized clipboard receipt.
-- NO FINAL ACCEPT, no market quote, no server settlement, no teaching model.
local M={}
local function report(status,reason,round,phase,completed,attempts,actions)
 return {
  schema="gingerscope-system1-main-auto-failstop-v1",
  status=status,reason=reason,round=round,phase=phase,
  completedRounds=completed,requestEpochAttempts=attempts,
  actions=actions,manualAltOnly=true,automaticMain=true,
  distinctRequestEpochRequired=true,
  authorizesAccept=false,serverCompletionProven=false,
  offerRevisionAuthenticated=false,rawItemIdsAuthenticated=false,
  maySendDiscordWebhook=false,mayUseForStrategyLearning=false,
  mayReportProfit=false,tradeOutcome="UNKNOWN",
 }
end
local function integer(x,a,b)
 return type(x)=="number" and x==math.floor(x) and x>=a and x<=b
end
local function validReceipt(o)
 return type(o)=="table" and o.status=="CLIENT_MANUAL_PLAN_VISIBLE_UNATTRIBUTED"
    and o.authorizesAccept==false and o.serverCompletionProven==false
    and o.tradeOutcome=="UNKNOWN" and
    type(o.offerAttempts)=="number" and
    type(o.clientVisibleAddedSlots)=="number"
end
local function normSide(side)
 if type(side)~="table" or getmetatable(side)~=nil
    or #side>4 then return nil end
 local count=0
 local seen,items={},{}
 for k,v in pairs(side) do
  count+=1
  if not integer(k,1,4) or k>#side or
    type(v)~="table" or getmetatable(v)~=nil or
    not integer(v.physicalSlot,1,4) or
    seen[v.physicalSlot] or
    not integer(v.quantity,1,1000000) or
    type(v.displayCandidate)~="string" or
    #v.displayCandidate<1 or #v.displayCandidate>100 or
    v.displayCandidate:find("[%c]") or
    type(v.chromaCandidate)~="boolean" or
    v.rawItemIdAuthenticated~=false or
    (v.internalIdCandidate~=nil and
      (type(v.internalIdCandidate)~="string" or
       #v.internalIdCandidate>100 or
       v.internalIdCandidate:find("[%c]"))) then return nil end
  seen[v.physicalSlot]=true
  items[#items+1]={
   slot=v.physicalSlot,quantity=v.quantity,
   name=v.displayCandidate,chroma=v.chromaCandidate,
   id=v.internalIdCandidate or "",
  }
 end
 if count~=#side then return nil end
 table.sort(items,function(a,b)return a.slot<b.slot end)
 return items
end
local function sameSide(a,b)
 if type(a)~="table" or type(b)~="table" or #a~=#b then
  return false end
 for i=1,#a do
  local x,y=a[i],b[i]
  if x.slot~=y.slot or x.quantity~=y.quantity or
    x.name~=y.name or x.chroma~=y.chroma or x.id~=y.id then
   return false
  end
 end
 return true
end
-- The physical NewItem index is a GUI position, not a weapon-instance ID.
-- MM2 may compact NewItem2 -> NewItem1 when the earlier slot is removed.
-- Require the one remaining visible candidate to match EXACTLY ONE of the
-- prior two by name/chroma/quantity/visible-id, ignoring slot position only.
-- This is CLIENT-only reconciliation, not authoritative identity proof.
local function sameVisibleCandidate(a,b)
 return a~=nil and b~=nil and a.name==b.name and
   a.chroma==b.chroma and a.quantity==b.quantity and a.id==b.id
end
local function uniqueSurvivor(before,after)
 if type(before)~="table" or type(after)~="table" or
    #before~=2 or #after~=1 then return false,"INVALID_COUNTS" end
 local matches=0
 local oldSlot=nil
 for _,old in ipairs(before) do
  if sameVisibleCandidate(old,after[1]) then
   matches+=1
   oldSlot=old.slot
  end
 end
 if matches>1 then return false,"DUPLICATE_AMBIGUITY" end
 if matches~=1 then return false,"NO_IDENTICAL_CLIENT_CANDIDATE" end
 return true,oldSlot~=after[1].slot and "CLIENT_SLOT_REINDEXED" or
   "CLIENT_SLOT_STABLE"
end

-- GUI NewItem indexes may compact during MAIN's guarded withdrawals as
-- well as ALT's changes. Match every survivor uniquely by visible fields,
-- never using a slot ordinal as an authenticated weapon-instance ID.
local function uniqueAfterOwnRemoval(before,after)
 if type(before)~="table" or type(after)~="table" or
   #before<1 or #before>4 or #after~=#before-1 then
  return false,"INVALID_OWN_WITHDRAW_COUNTS"
 end
 local used={};local reindexed=false
 for _,current in ipairs(after) do
  local count=0;local found=nil
  for i,old in ipairs(before) do
   if sameVisibleCandidate(old,current) then count+=1;found=i end
  end
  if count~=1 or used[found] then
   return false,count>1 and "AMBIGUOUS_OWN_VISIBLE_CANDIDATE"
     or "OWN_SURVIVOR_MISMATCH"
  end
  used[found]=true
  if before[found].slot~=current.slot then reindexed=true end
 end
 return true,reindexed and "CLIENT_SLOT_REINDEXED" or "CLIENT_SLOT_STABLE"
end

local function protected(s)
 return type(s)=="string" and
   s:lower():gsub("[^%w]",""):find("gingerscope",1,true)~=nil
end
local function safeSnap(s)
 if type(s)~="table" or
   s.status~="CLIENT_UNPRICED_TWO_SIDED_SNAPSHOT"
   or s.partnerExactClientBound~=true or s.part3Paused~=true
   or s.part4TradeVisible~=true or s.requestOriginBound~=false
   or s.authorizesAccept~=false or s.authorizesOffer~=false
   or s.rawItemIdsAuthenticated~=false or s.pricesAuthenticated~=false
   or s.offerRevisionAuthenticated~=false
   or s.serverCompletionProven~=false
   or s.mayReportProfit~=false or s.maySendDiscordWebhook~=false
   or s.tradeOutcome~="UNKNOWN" then return nil end
 local ours,theirs=normSide(s.ours),normSide(s.theirs)
 if not ours or not theirs or
    s.physicalOwnSlots~=#ours or
    s.physicalTheirSlots~=#theirs then return nil end
 for _,item in ipairs(ours) do
  if protected(item.name) or protected(item.id) then return nil end
 end
 return {ours=ours,theirs=theirs}
end
local function expectedAltCount(round,stage)
 if round==2 or round==3 or round==5 then
  return stage=="ADD" and 1 or 0 end
 if round==4 then
  if stage=="ADD" then return 2 end
  if stage=="REMOVE_ONE" then return 1 end
  return 0
 end
 return 0
end
-- Only literal audited diagnostic codes may cross this boundary. Never
-- serialize freeform GUI labels, usernames, weapon IDs, or remote errors.
local knownNativeFaults={
 TRADE_PARTNER_NOT_CONSENTING_ALT=true,
 UNEXPECTED_ACCEPTED_STATE=true,
 ORIGINAL_P4_ROOT_CHANGED=true,
 MULTIPLE_VISIBLE_TRADE_ROOTS=true,
 GUI_NO_NONOVERLAPPING_SPACE=true,
 ORIGINAL_P3_P4_CLIENT_SNAPSHOT_REJECTED=true,
 P3_WATCHDOG_LOST=true,
 ALT_LEFT_OR_REPLACED=true,
 JOB_CHANGED=true,
 COMPETING_CONTROLLER_ACTIVE=true,
 P3_SESSION_EPOCH_MISMATCH=true,
 CLIENT_GUI_OR_OPERATOR_SESSION_LOST=true,
}
function M.new(api,options)
 if type(api)~="table" or
   type(api.startEpoch)~="function" or
   type(api.inspect)~="function" or
   type(api.offerApproved)~="function" or
   type(api.removeOwnOne)~="function" or
   type(api.decline)~="function" or
   type(api.endEpoch)~="function" or
   type(api.stopAll)~="function" or
   type(api.copyReport)~="function" or
   type(options)~="table" or
   options.explicitFourRoundConsent~=true or
   options.finalAcceptDisabled~=true or
   options.exactConsentingAlt~=true or
   options.approvedTwoDistinctOwnedItems~=true or
   (options.includeAdaptiveRound==true and
      options.explicitAdaptiveRevisionConsent~=true) or
   (options.includeAdaptiveRound~=nil and
      type(options.includeAdaptiveRound)~="boolean") or
   not integer(options.requestTimeout or 30,15,45) or
   not integer(options.altStepTimeout or 90,15,180) or
   not integer(options.actionTimeout or 8,3,30) then
  return nil,report("BLOCKED","DEPENDENCY_OR_EXPLICIT_APPROVAL_MISSING",
    0,"PREPARING",0,0,{})
 end
 local maxRounds=options.includeAdaptiveRound==true and 5 or 4
 local round=1
 local phase="PREPARING"
 local deadline=nil
 local consumed,completed=0,0
 local rounds={}
 local actions={
  requestsStarted=0,offersAttempted=0,offersClientVisible=0,
  removalsAttempted=0,declinesAttempted=0,clientClosedWindows=0,
  altRevisionsObserved=0,adaptiveReoffersAttempted=0,
  altRemovalSlotReindexesObserved=0,
   ownRemovalSlotReindexesObserved=0,
 }
 local root=nil
 local boundEpoch=nil
 local lastFull=nil
 local stable=0
 local oursPrev=nil
 local theirPrev=nil
 local ownExpected=nil
 local otherExpected=nil
 local stopOnce=false
 local copied=false
 local reason="EXPLICIT_MAIN_AUTO_TEST_PREPARED"
 local lastAction="NONE"
 local possibleSideEffect=false
 local nowLast=0
 local tickBusy=false
 local lastOutcome="UNKNOWN"
 local adaptiveWithdraw=false
 local adaptiveReoffered=false
 local function receipt()
  local r=report(
   phase=="STOPPED" and "STOPPED" or
   phase=="DONE" and "CLIENT_TEST_SEQUENCE_COMPLETE" or "RUNNING",
   reason,round,phase,completed,consumed,{
    requestsStarted=actions.requestsStarted,
    offersAttempted=actions.offersAttempted,
    offersClientVisible=actions.offersClientVisible,
    removalsAttempted=actions.removalsAttempted,
    declinesAttempted=actions.declinesAttempted,
    clientClosedWindows=actions.clientClosedWindows,
    altRevisionsObserved=actions.altRevisionsObserved,
    adaptiveReoffersAttempted=actions.adaptiveReoffersAttempted,
    altRemovalSlotReindexesObserved=actions.altRemovalSlotReindexesObserved,
     ownRemovalSlotReindexesObserved=actions.ownRemovalSlotReindexesObserved,
  })
  r.maxRounds=maxRounds
  r.adaptiveRoundAuthorized=maxRounds==5
  r.lastAction=lastAction
  r.possibleSideEffect=possibleSideEffect
  r.copyAttempted=copied
  r.rounds={}
  for i,v in ipairs(rounds) do
   r.rounds[i]={round=v.round,status=v.status,reason=v.reason,
     clientWindowClosed=v.clientWindowClosed}
  end
  r.instruction=phase=="ALT_REVISE" and
    "ALT: REPLACE your offered item with a DIFFERENT cheap weapon in ONE physical slot. MAIN automatically withdraws."
    or phase=="ALT_CLEAR_FOR_REOFFER" and
    "ALT: REMOVE the remaining offered item. MAIN will reoffer a second approved weapon."
    or phase=="ALT_READD" and
    "ALT: ADD ONE cheap item after MAIN reoffers. Wait for the REMOVE instruction."
    or phase=="WAIT_OPEN" and
    "ALT: accept MAIN's incoming trade REQUEST only. NEVER final Accept."
    or phase=="ALT_ADD" and
    ("ALT: add "..(round==4 and "TWO" or "ONE").." cheap weapons. MAIN automatic.")
    or phase=="ALT_REMOVE_ONE" and
    "ALT: REMOVE ONE of two offered weapons. MAIN automatic."
    or phase=="ALT_REMOVE_ALL" and
    "ALT: REMOVE ALL offered weapons. MAIN automatic."
    or phase=="STOPPED" and
    "MAIN AUTO STOPPED; copy receipt. If trade remains open, manually Decline."
    or phase=="DONE" and
(tostring(maxRounds).." client test windows processed. Report copied. No settlement proven.")
    or "MAIN automatic: "..phase..". ALT: do not press final Accept."
  return r
 end
 local function safeCall(method,...)
  local ok,good,extra=pcall(method,...)
  return ok and good==true,ok and extra or "CALLBACK_THROWN"
 end
 local function pushClipboard()
  copied=true
  local exported=receipt()
  -- Clipboard can be absent on iOS; the native adapter must also print/store
  -- this same sanitized JSON. No raw private items, partners or IDs exported.
  local success=pcall(api.copyReport,exported)
  return success
 end
 local function stop(why,actionUncertain)
  if stopOnce then return receipt() end
  stopOnce=true
  reason=why or "UNSPECIFIED_FAIL_CLOSED"
  phase="STOPPED"
  if actionUncertain==true then possibleSideEffect=true end
  -- Stop sender BEFORE clipboard. Do not attempt a blind decline on wrong root.
  pcall(api.stopAll)
  pushClipboard()
  return receipt()
 end
 local function finished()
  phase="DONE";reason=maxRounds==5 and "ALL_FIVE_CLIENT_ROUNDS_VERIFIED" or
    "ALL_FOUR_CLIENT_ROUNDS_VERIFIED"
  stopOnce=true
  pcall(api.stopAll)
  pushClipboard()
  return receipt()
 end
 local function enter(next,now,why)
  phase=next
  reason=why or "CLIENT_PHASE_ACTIVE"
  local limit=(next=="WAIT_OPEN" and (options.requestTimeout or 30))
   or ((next=="ALT_ADD" or next=="ALT_REMOVE_ONE" or
next=="ALT_REMOVE_ALL" or next=="ALT_REVISE" or
       next=="ALT_CLEAR_FOR_REOFFER" or next=="ALT_READD") and
       (options.altStepTimeout or 90))
   or (options.actionTimeout or 8)
  deadline=now+limit
  stable=0;lastFull=nil
 end
 local function transitionAfterAlt(now)
  if phase=="ALT_ADD" then
   if round==4 then enter("ALT_REMOVE_ONE",now,"ALT_TWO_CLIENT_SLOTS_VERIFIED")
   elseif round==5 then
    enter("ALT_REVISE",now,"AWAIT_AUTHORIZED_ALT_REPLACEMENT")
   else enter("ALT_REMOVE_ALL",now,"ALT_ONE_CLIENT_SLOT_VERIFIED") end
  elseif phase=="ALT_REMOVE_ONE" then
   enter("ALT_REMOVE_ALL",now,"ALT_ONE_OF_TWO_REMOVED")
  else
   if round>=3 then
    adaptiveWithdraw=false
    enter("MAIN_WITHDRAWING",now,"ALT_OFFER_CLEARED")
   else
    enter("MAIN_DECLINING",now,"ALT_OFFER_CLEARED")
   end
  end
 end
 local function actionOnce(name,fn,uncertain)
  lastAction=name
  local ok,yes,detail=pcall(fn)
  if not ok or yes~=true then
   return false,uncertain and "ACTION_FAILED_SIDE_EFFECT_UNKNOWN"
       or "ACTION_FAILED_NO_VERIFIED_EFFECT"
  end
  return true,detail
 end
 local function issueRequest(now)
  if phase~="PREPARING" and phase~="REQUESTING" then
   return stop("INVALID_REQUEST_PHASE")
  end
  -- request one exact ALT per round. New epoch is a required API contract.
  lastAction="P3_START_NEW_EPOCH"
  consumed+=1
  actions.requestsStarted+=1
  local ok,a,b=pcall(api.startEpoch,round,consumed)
  if not ok or a~=true then
   return stop("P3_FRESH_REQUEST_EPOCH_FAILED",true)
  end
  boundEpoch=b
  root=nil;oursPrev=nil;theirPrev=nil
  ownExpected=nil;otherExpected=nil
  adaptiveWithdraw=false;adaptiveReoffered=false
  enter("WAIT_OPEN",now,"WAITING_FRESH_ALT_REQUEST_ACCEPT")
  return receipt()
 end
 local function inspect(now)
  local good,ob=pcall(api.inspect,round,boundEpoch)
  if not good or type(ob)~="table" or
     ob.sessionFresh~=true or ob.exactPartner~=true or
     ob.noOtherController~=true then
   local verified=type(ob)=="table" and ob.errorCode
   return nil,knownNativeFaults[verified] and verified
       or "P3_P4_SESSION_OR_PARTNER_UNSAFE"
  end
  if ob.p3Status=="BLOCKED" or
     ob.p3Status=="P3_PAUSED_UNATTRIBUTED" then
   return nil,"P3_QUEUE_OR_HANDOFF_UNSAFE"
  end
  if ob.root==nil then
   if ob.snapshot~=nil then
    return nil,"NO_ROOT_BUT_STALE_SNAPSHOT"
   end
   return {root=nil,p3Status=ob.p3Status}
  end
  if type(ob.root)~="table" and type(ob.root)~="userdata" then
   return nil,"INVALID_PROTECTED_TRADE_ROOT"
  end
  local safe=safeSnap(ob.snapshot)
  if not safe then return nil,"PROTECTED_CLIENT_SNAPSHOT_INVALID" end
  return {root=ob.root,ours=safe.ours,theirs=safe.theirs}
 end
 local function stepStable(ob,own,other)
  if not sameSide(ob.ours,own) and own~=nil then
   return false,"MAIN_OFFER_UNEXPECTED_CHANGED"
  end
  if not sameSide(ob.theirs,other) and other~=nil then
   return false,"ALT_OFFER_UNEXPECTED_CHANGED"
  end
  local fingerprint={ours=ob.ours,theirs=ob.theirs}
  if lastFull and sameSide(lastFull.ours,fingerprint.ours) and
      sameSide(lastFull.theirs,fingerprint.theirs) then
   stable+=1
  else stable=1;lastFull=fingerprint end
  return stable>=2,nil
 end
 local function onTick(now)
  if phase=="STOPPED" or phase=="DONE" then return receipt() end
  if type(now)~="number" or now<nowLast or now>=math.huge then
   return stop("MISSING_OR_NONMONOTONIC_CLOCK")
  end
  nowLast=now
  if phase=="PREPARING" then return issueRequest(now) end
  if deadline~=nil and now>deadline then
   return stop("TIMEOUT_"..phase,phase=="MAIN_REOFFERING" or
      phase=="MAIN_OFFERING"
      or phase=="MAIN_WITHDRAWING" or phase=="MAIN_DECLINING")
  end
  if phase=="REQUESTING" then return issueRequest(now) end
  local ob,why=inspect(now)
  if not ob then return stop(why) end
  if phase=="WAIT_OPEN" then
   if ob.root==nil then return receipt() end
   if root~=nil then return stop("TRADE_ROOT_WAS_ALREADY_CONSUMED") end
   root=ob.root
   enter("CHECK_EMPTY",now,"FRESH_CLIENT_TRADE_WINDOW_OBSERVED")
   return receipt()
  end
  if phase=="WAIT_CLOSE" then
   if ob.root~=nil then
    if ob.root~=root then return stop("REPLACED_ROOT_DURING_DECLINE") end
    return receipt()
   end
   actions.clientClosedWindows+=1
   completed+=1
   rounds[#rounds+1]={round=round,status="CLIENT_SEQUENCE_PASS",
      reason="AUTOMATIC_DECLINE_CLIENT_WINDOW_CLOSED",clientWindowClosed=true}
   -- The old epoch must be fully stopped before any new original P3 queue.
   local ok,closed=pcall(api.endEpoch,round,boundEpoch)
   if not ok or closed~=true then
    return stop("P3_OLD_EPOCH_DID_NOT_CLOSE")
   end
   if completed==maxRounds then return finished() end
   round+=1
   enter("REQUESTING",now,"REQUEST_NEXT_FRESH_P3_EPOCH")
   return issueRequest(now)
  end
  if ob.root==nil then return stop("TRADE_CLOSED_UNEXPECTEDLY") end
  if ob.root~=root then return stop("TRADE_ROOT_CHANGED") end
  if phase=="CHECK_EMPTY" then
   if #ob.ours~=0 or #ob.theirs~=0 then
    return stop("TRADE_NOT_EMPTY_ON_OPEN")
   end
   local yes=stepStable(ob,{}, {})
   if not yes then return receipt() end
   oursPrev=ob.ours;theirPrev=ob.theirs
   if round==1 then enter("MAIN_DECLINING",now,"ROUND1_EMPTY_VERIFIED")
   elseif round==2 then enter("ALT_ADD",now,"WAIT_ALT_SINGLE_ITEM")
   else enter("MAIN_OFFERING",now,"AUTO_PLACE_PREAPPROVED_ITEMS") end
   return receipt()
  end
  if phase=="MAIN_OFFERING" or phase=="MAIN_REOFFERING" then
   if #ob.ours~=0 or #ob.theirs~=0 then
    return stop("PREOFFER_CLIENT_SIDE_CHANGED") end
   local reoffer=phase=="MAIN_REOFFERING"
   local n=round==4 and not reoffer and 2 or 1
   lastAction=reoffer and "MAIN_GUARDED_ADAPTIVE_REOFFER" or
     "MAIN_GUARDED_OFFER"
   actions.offersAttempted+=n
   if reoffer then actions.adaptiveReoffersAttempted+=1 end
   local ok,receiptOrWhy=pcall(api.offerApproved,round,n,boundEpoch,
      reoffer and 2 or 1)
   if not ok or not validReceipt(receiptOrWhy) or
     receiptOrWhy.offerAttempts~=n or
     receiptOrWhy.clientVisibleAddedSlots~=n then
    return stop("GUARDED_OFFER_FAILED_OR_UNCONFIRMED",true)
   end
   actions.offersClientVisible+=n
   enter(reoffer and "WAIT_MAIN_REOFFER" or "WAIT_MAIN_OFFER",now,
     "GUARDED_MAIN_GUI_SLOTS_AWAIT_STABLE_READ")
   return receipt()
  end
  if phase=="WAIT_MAIN_OFFER" or phase=="WAIT_MAIN_REOFFER" then
   local reoffer=phase=="WAIT_MAIN_REOFFER"
   local n=round==4 and not reoffer and 2 or 1
   if #ob.ours~=n or #ob.theirs~=0 then
    return stop("MAIN_OFFER_GUI_NOT_RECONCILED") end
   local yes=stepStable(ob,nil,{})
   if not yes then return receipt() end
   oursPrev=ob.ours;theirPrev=ob.theirs
   if reoffer then
    adaptiveReoffered=true
    enter("ALT_READD",now,"ADAPTIVE_MAIN_REOFFER_VISIBLE")
   else
    enter("ALT_ADD",now,"MAIN_OFFER_VISIBLE_ALT_CAN_NOW_ACT")
   end
   return receipt()
  end
  if phase=="ALT_REVISE" then
   if round~=5 or not sameSide(ob.ours,oursPrev) then
    return stop("UNAUTHORIZED_MAIN_OFFER_CHANGE") end
   if #ob.theirs>1 then
    return stop("ALT_ADDED_UNEXPECTED_EXTRA_SLOTS") end
   if #ob.theirs~=1 or sameSide(ob.theirs,theirPrev) then
    stable=0;lastFull=nil;return receipt()
   end
   local yes=stepStable(ob,oursPrev,nil)
   if not yes then return receipt() end
   actions.altRevisionsObserved+=1
   theirPrev=ob.theirs
   adaptiveWithdraw=true
   enter("MAIN_WITHDRAWING",now,
      "STABLE_CLIENT_ALT_REVISION_WITHDRAW_OWN_FIRST")
   return receipt()
  end
  if phase=="ALT_CLEAR_FOR_REOFFER" then
   if round~=5 or #ob.ours~=0 then
    return stop("ADAPTIVE_REOFFER_MAIN_NOT_EMPTY") end
   if #ob.theirs>1 then
    return stop("ALT_ADDED_UNEXPECTED_EXTRA_SLOTS") end
   if #ob.theirs==1 then
    if not sameSide(ob.theirs,theirPrev) then
     return stop("ALT_CHANGED_WHILE_CLEARING_FOR_REOFFER") end
    stable=0;lastFull=nil;return receipt()
   end
   local yes=stepStable(ob,{}, {})
   if not yes then return receipt() end
   theirPrev=ob.theirs
   adaptiveWithdraw=false
   enter("MAIN_REOFFERING",now,
      "CLIENT_BOTH_EMPTY_FOR_SECOND_APPROVED_ITEM")
   return receipt()
  end
  if phase=="ALT_ADD" or phase=="ALT_READD" or
      phase=="ALT_REMOVE_ONE" or phase=="ALT_REMOVE_ALL" then
   if not sameSide(ob.ours,oursPrev) then
    return stop("UNAUTHORIZED_MAIN_OFFER_CHANGE") end
   local stage=(phase=="ALT_ADD" or phase=="ALT_READD") and "ADD" or
      phase=="ALT_REMOVE_ONE" and "REMOVE_ONE" or "REMOVE_ALL"
   local want=expectedAltCount(round,stage)
   if #ob.theirs~=want then
    -- A repeated/incorrect ALT count may be a transient manual action;
    -- but any unexpected extra slot is terminal, never trust >2.
    if #ob.theirs> (round==4 and 2 or 1) then
     return stop("ALT_ADDED_UNEXPECTED_EXTRA_SLOTS") end
    stable=0;lastFull=nil;return receipt()
   end
   -- Accept a compacted GUI slot only when the *same unique visible*
   -- candidate survives; never authorize a different name/chroma/quantity.
   if phase=="ALT_REMOVE_ONE" then
    local ok,why=uniqueSurvivor(theirPrev,ob.theirs)
    if not ok then
     return stop(why=="DUPLICATE_AMBIGUITY" and
       "ALT_REMOVAL_SURVIVOR_AMBIGUOUS" or
       "ALT_REPLACED_ITEM_INSTEAD_OF_REMOVING")
    end
   elseif phase=="ALT_REMOVE_ALL" and #ob.theirs==0 then
    -- ALT's full side has become empty, which is expected.
   elseif phase~="ALT_ADD" and phase~="ALT_READD" and
      not sameSide(ob.theirs,theirPrev) then
    return stop("ALT_UNEXPECTED_OFFER_REVISION")
   end
   local yes=stepStable(ob,oursPrev,nil)
   if not yes then return receipt() end
   if phase=="ALT_REMOVE_ONE" then
    local ok,kind=uniqueSurvivor(theirPrev,ob.theirs)
    if not ok then return stop(kind=="DUPLICATE_AMBIGUITY" and
       "ALT_REMOVAL_SURVIVOR_AMBIGUOUS" or
       "ALT_REPLACED_ITEM_INSTEAD_OF_REMOVING") end
    if kind=="CLIENT_SLOT_REINDEXED" then
     actions.altRemovalSlotReindexesObserved+=1
    end
   end
   theirPrev=ob.theirs
   if phase=="ALT_READD" then
    enter("ALT_REMOVE_ALL",now,"ADAPTIVE_ALT_NEW_PROPOSAL_VISIBLE")
   else
    transitionAfterAlt(now)
   end
   return receipt()
  end
  if phase=="MAIN_WITHDRAWING" then
   local expectedTheir=adaptiveWithdraw and theirPrev or {}
   if not sameSide(ob.theirs,expectedTheir) or #ob.ours==0 or
     not sameSide(ob.ours,oursPrev) then
    return stop("MAIN_WITHDRAW_PRECONDITION_FAILED")
   end
   lastAction="MAIN_REMOVE_OWN_ONE"
   actions.removalsAttempted+=1
   local ok,yes=pcall(api.removeOwnOne,round,root,boundEpoch,
      adaptiveWithdraw==true)
   if not ok or yes~=true then
    return stop("MAIN_REMOVAL_CLICK_UNCONFIRMED",true)
   end
   ownExpected=#ob.ours-1
   enter("WAIT_MAIN_WITHDRAW",now,"WAIT_GUI_CONFIRM_ONE_SLOT_REMOVED")
   return receipt()
  end
  if phase=="WAIT_MAIN_WITHDRAW" then
   local expectedTheir=adaptiveWithdraw and theirPrev or {}
   if not sameSide(ob.theirs,expectedTheir) then
    return stop("ALT_CHANGED_DURING_OWN_REMOVAL") end
   if #ob.ours~=ownExpected then
    if #ob.ours > #oursPrev then return stop("OWN_OFFER_GREW_DURING_REMOVAL") end
    return receipt()
   end
   -- Keep only uniquely matched visible survivors after the guarded click.
   -- A valid GUI compaction is not a new weapon; ambiguous substitutions STOP.
   local keep,kind=uniqueAfterOwnRemoval(oursPrev,ob.ours)
   if not keep then
    return stop(kind=="AMBIGUOUS_OWN_VISIBLE_CANDIDATE" and
      "OWN_WITHDRAW_SURVIVOR_AMBIGUOUS" or
      "OWN_SLOT_REPLACED_DURING_REMOVAL")
   end
   if kind=="CLIENT_SLOT_REINDEXED" then
    actions.ownRemovalSlotReindexesObserved+=1
   end
   -- An adaptive withdrawal preserves the already stable ALT offer;
   -- ordinary withdrawal still requires ALT's side to remain empty.
   local yes=stepStable(ob,nil,expectedTheir)
   if not yes then return receipt() end
   oursPrev=ob.ours
   if #ob.ours>0 then
    enter("MAIN_WITHDRAWING",now,"MORE_OWN_ITEMS_TO_REMOVE")
   elseif adaptiveWithdraw then
    enter("ALT_CLEAR_FOR_REOFFER",now,
      "OWN_WITHDRAWN_AFTER_ALT_REVISION")
   else
    enter("MAIN_DECLINING",now,"ALL_OWN_ITEMS_CLEARED")
   end
   return receipt()
  end
  if phase=="MAIN_DECLINING" then
   if #ob.ours~=0 or #ob.theirs~=0 then
    return stop("DECLINE_EXPECTED_BOTH_SIDES_EMPTY") end
   lastAction="MAIN_DECLINE_EXACT_ALT"
   actions.declinesAttempted+=1
   local ok,yes=pcall(api.decline,round,root,boundEpoch)
   if not ok or yes~=true then
    return stop("AUTO_DECLINE_FAILED_OR_UNCONFIRMED",true)
   end
   enter("WAIT_CLOSE",now,"WAIT_AFTER_AUTOMATIC_CLIENT_DECLINE")
   return receipt()
  end
  return stop("UNSUPPORTED_AUTOMATION_PHASE")
 end
 local controller={}
 function controller.tick(now)
  if tickBusy then return stop("CONCURRENT_AUTO_ENGINE_TICK",true) end
  tickBusy=true
  local ok,out=pcall(onTick,now)
  tickBusy=false
  if not ok then return stop("UNHANDLED_AUTO_CONTROLLER_EXCEPTION",true) end
  return out
 end
 function controller.stop()
  lastAction="OPERATOR_STOP_BUTTON"
  return stop("OPERATOR_STOPPED")
 end
 function controller.abort(errorCode)
  -- Native runtime may signal a validated STATIC error, never serialize an
  -- arbitrary partner name, profile value, item label or stack trace.
  local code=type(errorCode)=="string" and
      #errorCode>0 and #errorCode<=90 and
      errorCode:match("^[A-Z0-9_]+$") and errorCode or
      "EXTERNAL_RUNTIME_FAULT"
  lastAction="EXTERNAL_RUNTIME_FAILSTOP"
  return stop(code,true)
 end
 function controller.status()return receipt()end
 function controller.copyNow()return pushClipboard()end
 return controller,nil
end
return M
