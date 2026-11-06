-- Stage28: pure READ-ONLY Stage9 acceptance/closure timeline.
-- Neither an accepted icon nor TradeGUI closure proves server completion.
-- Never calls Roblox, Accept, Decline, an inventory remote, or a webhook.
local M={}
local function integer(v,lo,hi)
 return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge
   and v==math.floor(v) and v>=lo and v<=hi
end
local function timeOK(v)
 return type(v)=="number" and v==v and v>=0 and v<math.huge
end
local function canonical(r)
 return type(r)=="table" and integer(r.slot,1,4)
   and type(r.page)=="string"
   and (r.page=="godly" or r.page=="ancient" or r.page=="chroma")
   and type(r.checkerId)=="string" and r.checkerId:match("^%d+$")
   and #r.checkerId<=8 and integer(r.qty,1,1000000)
   and type(r.id)=="string" and r.id~=""
end
local function validSide(rows,slots)
 if not integer(slots,0,4) or type(rows)~="table"
    or #rows~=slots then return false end
 local seen={}
 for _,r in ipairs(rows) do
  if not canonical(r) or seen[r.slot] then return false end
  seen[r.slot]=true
 end
 return true
end
local function acceptLabel(ours,theirs)
 if ours==nil or theirs==nil then return "UNKNOWN" end
 if ours and theirs then return "BOTH" end
 if ours then return "OURS_ONLY" end
 if theirs then return "THEIRS_ONLY" end
 return "NEITHER"
end
local function event(s,kind,t)
 if #s.events>=32 then table.remove(s.events,1) end
 s.events[#s.events+1]={kind=kind,t=t-s.startedAt}
end
local function invalidate(s,reason,clock)
 s.phase="INVALID"
 s.reason=reason;s.terminal=true
 s.bothAcceptedStable=false
 event(s,"EVIDENCE_INVALID",clock)
 return "INVALID",reason
end
function M.new(session,firstTime,config)
 assert(type(session)=="string" and session~="","session required")
 assert(timeOK(firstTime),"monotonic start required")
 config=config or {}
 local gap=config.minStableGap or 0.15
 assert(timeOK(gap) and gap>=0.1 and gap<=1,"stable gap invalid")
 return {session=session,startedAt=firstTime,lastTime=nil,
  minStableGap=gap,phase="WAITING",reason="await-trade",
  terminal=false,events={},frames=0,
  lastSignature=nil,lastAccept=nil,hadAnyAccept=false,
  anyBothAccepted=false,bothAcceptedStable=false,
  ourAcceptIndicatorEverVisible=false,theirAcceptIndicatorEverVisible=false,
  anyAcceptIndicatorUnknown=false,
  stableEver=false,pendingSince=nil,
  tainted=false,everResolved=false,closed=false,closureStatus=nil}
end
function M.ingest(s,o,diag,t)
 assert(type(s)=="table" and s.session,"timeline required")
 if s.terminal then return "HOLD","session-terminal" end
 if not timeOK(t) or t<s.startedAt
    or (s.lastTime and t<=s.lastTime) then
    return invalidate(s,"clock-nonmonotonic",timeOK(t) and t or s.startedAt)
 end
 s.lastTime=t;s.frames=s.frames+1
 if type(o)~="table" or o.session~=s.session then
  return invalidate(s,"observer-session-mismatch",t)
 end
 if o.tradeOpen~=true then
  if o.tradeOpen~=false then
   return invalidate(s,"trade-open-unknown",t)
  end
  s.closed=true;s.terminal=true;s.phase="CLOSED_UNKNOWN"
  s.closureStatus="closed_unknown"
  s.reason="trade-window-closed-not-server-completion"
  event(s,"CLOSED_UNKNOWN",t)
  return "CLOSED_UNKNOWN",s.reason
 end
 -- Observe native icons independently of whether an actual bilateral
 -- exchange is resolved. This is GUI presence ONLY, never quote authority.
 if o.contextOK==true then
  if o.ourAccepted==true then s.ourAcceptIndicatorEverVisible=true end
  if o.theirAccepted==true then s.theirAcceptIndicatorEverVisible=true end
  if type(o.ourAccepted)~="boolean"
    or type(o.theirAccepted)~="boolean" then
   s.anyAcceptIndicatorUnknown=true
  end
 end
 if s.everResolved and o.contextOK~=true then
  return invalidate(s,"bound-trade-context-lost",t)
 end
 if o.contextOK~=true or type(o.ourSig)~="string"
    or type(o.theirSig)~="string" or o.ourSig==""
    or o.theirSig=="" or type(diag)~="table"
    or not validSide(diag.ourItems,o.ourSlots)
    or not validSide(diag.theirItems,o.theirSlots)
    or o.theirResolved~=true
    or o.ourSlots==0 or o.theirSlots==0 then
    s.phase="UNRESOLVED";s.reason="current-offers-not-fully-resolved"
    s.pendingSince=nil
    s.bothAcceptedStable=false
    event(s,"UNRESOLVED",t)
    return "HOLD",s.reason
 end
 s.everResolved=true
 local ours,theirs=o.ourAccepted,o.theirAccepted
 if type(ours)~="boolean" or type(theirs)~="boolean" then
    s.phase="ACCEPT_UNKNOWN";s.reason="native-accept-indicator-unknown"
    s.pendingSince=nil;s.bothAcceptedStable=false
    event(s,"ACCEPT_UNKNOWN",t)
    return "HOLD",s.reason
 end
 local signature=o.ourSig.."\0"..o.theirSig
 if s.lastSignature and signature~=s.lastSignature then
    if s.hadAnyAccept or ours or theirs then
       s.tainted=true
       s.phase="OFFER_CHANGED_AFTER_ACCEPT"
       s.reason="offer-mutated-after-accepted-state"
       s.bothAcceptedStable=false;s.pendingSince=nil
       event(s,"OFFER_CHANGED_AFTER_ACCEPT",t)
    else
       s.pendingSince=nil;s.bothAcceptedStable=false
       event(s,"OFFER_CHANGED_BEFORE_ACCEPT",t)
    end
 end
 s.lastSignature=signature
 local label=acceptLabel(ours,theirs)
 s.lastAccept=label
 if ours or theirs then s.hadAnyAccept=true end
 if s.tainted then
    s.phase="OFFER_CHANGED_AFTER_ACCEPT"
    s.reason="accepted-state-invalidated-by-offer-change"
    return "HOLD",s.reason
 end
 if label=="BOTH" then
    s.anyBothAccepted=true
    if s.pendingSince and t-s.pendingSince>=s.minStableGap then
       s.phase="BOTH_ACCEPTED_STABLE"
       s.reason="two-client-indicators-only-no-completion-proof"
       s.bothAcceptedStable=true;s.stableEver=true
       event(s,"BOTH_ACCEPTED_STABLE",t)
       return "OBSERVED",s.reason
    end
    if not s.pendingSince then s.pendingSince=t end
    s.phase="BOTH_ACCEPTED_PENDING"
    s.reason="await-independent-second-client-poll"
    event(s,"BOTH_ACCEPTED_PENDING",t)
    return "HOLD",s.reason
 end
 s.pendingSince=nil;s.bothAcceptedStable=false
 s.phase=label
 s.reason="accepted-state-client-observation-only"
 event(s,label,t)
 return "OBSERVED",s.reason
end
function M.summary(s)
 assert(type(s)=="table" and s.session,"timeline required")
 local history={}
 for i,r in ipairs(s.events) do history[i]={kind=r.kind,elapsed=r.t} end
 return {schema="gingerscope-stage28-acceptance-timeline-v1",
   status=s.phase,reason=s.reason,observations=s.frames,
   bothAcceptedEverObserved=s.anyBothAccepted,
   bothAcceptedStableObserved=s.stableEver,
   ourAcceptIndicatorEverVisible=s.ourAcceptIndicatorEverVisible,
   theirAcceptIndicatorEverVisible=s.theirAcceptIndicatorEverVisible,
   anyAcceptIndicatorUnknown=s.anyAcceptIndicatorUnknown,
   currentBothAcceptedStable=s.bothAcceptedStable,
   offerMutationAfterAccept=s.tainted,
   closureStatus=s.closureStatus or "not-closed",
   closureProvesCompletion=false,
   serverAttestation=false,
   serverCompletionProven=false,
   mayRecordCompletedTrade=false,
   mayReportProfit=false,
   authorizesTrade=false,authorizesAccept=false,
   reviewOnly=true,events=history}
end
return M
