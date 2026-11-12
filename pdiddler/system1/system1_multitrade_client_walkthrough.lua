-- System 1: supervised multi-trade, multi-round MAIN/ALT GUI diagnostic.
-- Pure state machine. NO item offers, no request sends, no automatic Accept,
-- Decline or teleport. Caller must supply original guarded P3/P4-compatible
-- manual-consent CLIENT snapshots from a NEW bound lease per trade root.
local M={}
local STEPS={
 {
  {phase="R1_CLOSE",own=0,their=0,change="NONE",
   instruction="MAIN: verify BOTH offers empty. Manually DECLINE trade 1."},
 },
 {
  {phase="R2_ALT_ADD",own=0,their=1,change="THEIR",
   instruction="ALT: ADD ONE cheap weapon. MAIN: leave your offer empty."},
  {phase="R2_ALT_REMOVE",own=0,their=0,change="THEIR",
   instruction="ALT: REMOVE the same weapon. MAIN: no item offers."},
  {phase="R2_CLOSE",own=0,their=0,change="NONE",
   instruction="MAIN: manually DECLINE trade 2 (no final Accept)."},
 },
 {
  {phase="R3_MAIN_ADD",own=1,their=0,change="OWN",
   instruction="MAIN: manually ADD ONE cheap non-Gingerscope weapon."},
  {phase="R3_ALT_ADD",own=1,their=1,change="THEIR",
   instruction="ALT: manually ADD ONE cheap weapon; MAIN keep yours."},
  {phase="R3_ALT_REMOVE",own=1,their=0,change="THEIR",
   instruction="ALT: REMOVE that item. MAIN leave your item in place."},
  {phase="R3_MAIN_REMOVE",own=0,their=0,change="OWN",
   instruction="MAIN: REMOVE your test weapon; confirm both empty."},
  {phase="R3_CLOSE",own=0,their=0,change="NONE",
   instruction="MAIN: manually DECLINE trade 3."},
 },
 {
  {phase="R4_MAIN_TWO",own=2,their=0,change="OWN",
   instruction="MAIN: manually ADD TWO distinct cheap weapons (2 slots)."},
  {phase="R4_ALT_TWO",own=2,their=2,change="THEIR",
   instruction="ALT: manually ADD TWO distinct cheap weapons (2 slots)."},
  {phase="R4_ALT_ONE",own=2,their=1,change="THEIR",
   instruction="ALT: REMOVE ONE of your two weapons. MAIN keep both."},
  {phase="R4_ALT_EMPTY",own=2,their=0,change="THEIR",
   instruction="ALT: REMOVE your remaining weapon. MAIN keep both."},
  {phase="R4_MAIN_EMPTY",own=0,their=0,change="OWN",
   instruction="MAIN: REMOVE BOTH of your weapons (both sides empty)."},
  {phase="R4_CLOSE",own=0,their=0,change="NONE",
   instruction="MAIN: manually DECLINE trade 4."},
 },
}
local function base(r,reason,round,step,phase)
 return {
  schema="gingerscope-system1-supervised-multitrade-client-v1",
  phase=phase,reason=reason,round=round,step=step,
  clientOnly=true,manualConsentOnly=true,readOnly=true,
  p3RequestOriginAuthenticated=false,serverTradeRevisionProven=false,
  rawItemIdsAuthenticated=false,uniqueWeaponInstanceProven=false,
  serverCompletionProven=false,verifiedMarketQuote=false,
  authorizesOffer=false,authorizesTrade=false,authorizesAccept=false,
  mayReportProfit=false,maySendDiscordWebhook=false,
  mayUseForStrategyLearning=false,tradeOutcome="UNKNOWN",
 }
end
local function integer(x,min,max)
 return type(x)=="number" and x==math.floor(x)
    and x>=min and x<=max
end
local function validLabel(s)
 return type(s)=="string" and #s>=1 and #s<=100
    and s:match("^[^%c]+$")~=nil
end
local function normalize(items)
 if type(items)~="table" or getmetatable(items)~=nil
    or #items>4 then return nil end
 local seen,normalized,count={},{},0
 for index,item in pairs(items) do
  count+=1
  if not integer(index,1,4) or index>#items or
     type(item)~="table" or getmetatable(item)~=nil or
     not integer(item.physicalSlot,1,4) or
     not integer(item.quantity,1,1000000) or
     not validLabel(item.displayCandidate) or
     type(item.chromaCandidate)~="boolean" or
     item.rawItemIdAuthenticated~=false or
     (item.internalIdCandidate~=nil and
      (type(item.internalIdCandidate)~="string" or
      #item.internalIdCandidate>100 or
      item.internalIdCandidate:find("[%c]"))) or
     seen[item.physicalSlot] then return nil end
  seen[item.physicalSlot]=true
  normalized[#normalized+1]={
   slot=item.physicalSlot,qty=item.quantity,
   name=item.displayCandidate,chroma=item.chromaCandidate,
   id=item.internalIdCandidate or "",
  }
 end
 if count~=#items then return nil end
 table.sort(normalized,function(a,b)return a.slot<b.slot end)
 return normalized
end
local function same(a,b)
 if type(a)~="table" or type(b)~="table" or #a~=#b then
  return false end
 for i=1,#a do
  local x,y=a[i],b[i]
  if x.slot~=y.slot or x.qty~=y.qty or x.name~=y.name or
     x.chroma~=y.chroma or x.id~=y.id then return false end
 end
 return true
end
local function safeSnap(s)
 if type(s)~="table" or
    s.status~="CLIENT_UNPRICED_TWO_SIDED_SNAPSHOT" or
    s.partnerExactClientBound~=true or
    s.part3Paused~=true or s.part4TradeVisible~=true or
    s.requestOriginBound~=false or
    s.rawItemIdsAuthenticated~=false or
    s.offerRevisionAuthenticated~=false or
    s.pricesAuthenticated~=false or
    s.authorizesOffer~=false or s.authorizesAccept~=false or
    s.serverCompletionProven~=false or
    s.mayReportProfit~=false or s.maySendDiscordWebhook~=false or
    s.tradeOutcome~="UNKNOWN" then return nil end
 local own,other=normalize(s.ours),normalize(s.theirs)
 if not own or not other or s.physicalOwnSlots~=#own
    or s.physicalTheirSlots~=#other then return nil end
 for _,x in ipairs(own) do
  local n=x.name:lower():gsub("[^%w]","")
  local id=x.id:lower():gsub("[^%w]","")
  if n:find("gingerscope",1,true) or
     id:find("gingerscope",1,true) then return nil end
 end
 return {own=own,their=other}
end
function M.new(options)
 if type(options)~="table" or
    not integer(options.maxRounds or 4,1,4) or
    not integer(options.maxWaitSeconds or 90,15,180) then
   return nil,"INVALID_WALKTHROUGH_CONFIG"
 end
 local maxRounds=options.maxRounds or 4
 local timeout=options.maxWaitSeconds or 90
 local round=1
 local phase="WAIT_OPEN"
 local step=0
 local stepStable=0
 local lastSample=nil
 local expectedOwn,expectedTheir=nil,nil
 local root=nil
 local readyForNext=false
 local stopped=false
 local finished=false
 local failedPending=nil
 local passed,failed=0,0
 local complete={}
 local opened=0
 local guiTransitions=0
 local startTime=nil
 local lastTime=0
 local lastReason="WAITING_FOR_MANUAL_TRADE_WINDOW"
 local function snapshot()
  local r=base(nil,lastReason,round,step,phase)
  r.stopped=stopped;r.finished=finished
  r.completedRounds=#complete;r.passedRounds=passed
  r.failedRounds=failed;r.openedTradeWindows=opened
  r.observedStepTransitions=guiTransitions
  r.canNext=readyForNext and not stopped and not finished
  r.maxRounds=maxRounds
  r.rounds={}
  for i,v in ipairs(complete) do
   r.rounds[i]={round=v.round,result=v.result,reason=v.reason,
                observedSteps=v.observedSteps,clientWindowClosed=v.clientWindowClosed}
  end
  if phase=="WAIT_OPEN" then
   r.instruction="ALT: send MANUAL trade request to MAIN. MAIN: accept request only. BOTH start empty."
  elseif phase=="WAIT_EMPTY" then
   r.instruction="MAIN/ALT: keep both offers EMPTY for two checks. No final Accept."
  elseif phase=="REVIEW" then
   r.instruction="Trade window is closed. Check round result, then tap NEXT ROUND."
  elseif phase=="DONE" then
   r.instruction="All rounds finished. Tap STOP / COPY for the sanitized report."
  elseif phase=="BLOCKED" then
   r.instruction="UNSAFE CLIENT OBSERVATION. STOP / COPY. Do not continue this server."
  elseif phase=="WAIT_CLOSE_AFTER_FAIL" then
   r.instruction="Round did not match expected state. MAIN: manually DECLINE, then NEXT ROUND."
  else
   local spec=STEPS[round] and STEPS[round][step]
   r.instruction=spec and spec.instruction or "STOP / COPY: unsupported phase."
  end
  return r
 end
 local function mark(reason)
  lastReason=reason
  startTime=lastTime
  stepStable=0
  lastSample=nil
 end
 local function block(reason)
  phase="BLOCKED";stopped=true;mark(reason)
  return snapshot()
 end
 local function completeRound(ok,reason)
  if ok then passed+=1 else failed+=1 end
  complete[#complete+1]={
   round=round,result=ok and "CLIENT_SEQUENCE_PASS" or "INCOMPLETE",
   reason=reason,observedSteps=step,clientWindowClosed=true,
  }
  root=nil
  readyForNext=true
  phase="REVIEW"
  mark(reason)
  return snapshot()
 end
 local function afterStep(now,own,their)
  guiTransitions+=1
  expectedOwn=own
  expectedTheir=their
  step+=1
  stepStable=0
  lastSample=nil
  startTime=now
  local nextSpec=STEPS[round][step]
  if not nextSpec then return block("INVALID_NEXT_STEP") end
  phase=nextSpec.phase
  lastReason="GUI_STEP_CONFIRMED_CLIENT_ONLY"
  return snapshot()
 end
 local witness={}
 function witness.tick(event)
  if stopped or finished then return snapshot() end
  if type(event)~="table" or type(event.now)~="number" or
     event.now~=event.now or event.now<lastTime or
     event.now>=math.huge then
   return block("NONMONOTONIC_OR_MISSING_CLOCK")
  end
  lastTime=event.now
  if event.sameJob~=true or event.exactPartner~=true or
     event.competingController~=false then
   return block("JOB_PARTNER_OR_TRANSACTION_OWNER_UNSAFE")
  end
  local rootNow=event.root
  if rootNow~=nil and
     (type(rootNow)~="table" and type(rootNow)~="userdata") then
   return block("UNREADABLE_TRADE_ROOT")
  end
  if rootNow==nil then
   if phase=="WAIT_OPEN" or phase=="REVIEW" then
    return snapshot()
   end
   if phase=="WAIT_CLOSE_AFTER_FAIL" then
    return completeRound(false,failedPending or "ROUND_FAILED")
   end
   local spec=STEPS[round][step]
   if spec and spec.phase:match("_CLOSE$") then
    return completeRound(true,"MANUALLY_CLOSED_AFTER_CLIENT_GUI_SEQUENCE")
   end
   return completeRound(false,"CLIENT_TRADE_WINDOW_CLOSED_BEFORE_STEP")
  end
  if phase=="REVIEW" then
   return block("NEW_TRADE_OPENED_BEFORE_OPERATOR_NEXT")
  end
  if phase=="WAIT_OPEN" then
   phase="WAIT_EMPTY"
   root=rootNow
   opened+=1
   mark("CLIENT_TRADE_ROOT_OBSERVED")
  elseif root~=rootNow then
   return block("TRADE_ROOT_CHANGED_DURING_ROUND")
  end
  if type(event.snapshot)~="table" then
   return block("PROTECTED_CLIENT_SNAPSHOT_MISSING")
  end
  local sides=safeSnap(event.snapshot)
  if not sides then return block("PROTECTED_CLIENT_SNAPSHOT_REJECTED") end
  if startTime~=nil and event.now-startTime>timeout then
   phase="WAIT_CLOSE_AFTER_FAIL"
   failedPending="CLIENT_STEP_TIMEOUT"
   lastReason=failedPending
   return snapshot()
  end
  local own,their=sides.own,sides.their
  if phase=="WAIT_EMPTY" then
   if #own~=0 or #their~=0 then
    phase="WAIT_CLOSE_AFTER_FAIL"
    failedPending="TRADE_NOT_EMPTY_ON_OPEN"
    return snapshot()
   end
   stepStable+=1
   if stepStable>=2 then
    expectedOwn=own;expectedTheir=their
    step=1;phase=STEPS[round][1].phase
    mark("EMPTY_INITIAL_TRADE_VERIFIED_CLIENT_ONLY")
   end
   return snapshot()
  end
  if phase=="WAIT_CLOSE_AFTER_FAIL" then return snapshot() end
  local spec=STEPS[round][step]
  if not spec then return block("UNKNOWN_ROUND_PHASE") end
  local unchanging=spec.change=="OWN" and
      same(their,expectedTheir) or
      spec.change=="THEIR" and
      same(own,expectedOwn) or
      spec.change=="NONE" and same(own,expectedOwn) and
         same(their,expectedTheir)
  if not unchanging then
   phase="WAIT_CLOSE_AFTER_FAIL"
   failedPending="UNREQUESTED_OTHER_SIDE_MUTATION"
   lastReason=failedPending
   return snapshot()
  end
  if spec.phase:match("_CLOSE$") then
   return snapshot()
  end
  if #own~=spec.own or #their~=spec.their then
   stepStable=0;lastSample=nil
   return snapshot()
  end
  local sample={own=own,their=their}
  if lastSample and same(lastSample.own,own) and
      same(lastSample.their,their) then
   stepStable+=1
  else
   stepStable=1;lastSample=sample
  end
  if stepStable>=2 then return afterStep(event.now,own,their) end
  return snapshot()
 end
 function witness.next()
  if stopped or finished or not readyForNext or phase~="REVIEW" then
   return false,snapshot()
  end
  readyForNext=false
  if round>=maxRounds then
   finished=true;phase="DONE";mark("MULTIROUND_CLIENT_DIAGNOSTIC_COMPLETE")
  else
   round+=1;step=0;phase="WAIT_OPEN"
   expectedOwn=nil;expectedTheir=nil
   mark("WAITING_FOR_NEXT_MANUAL_TRADE")
  end
  return true,snapshot()
 end
 function witness.stop()
  stopped=true
  if phase~="DONE" then phase="STOPPED" end
  mark("OPERATOR_STOPPED")
  return snapshot()
 end
 function witness.status() return snapshot() end
 return witness,nil
end
return M
