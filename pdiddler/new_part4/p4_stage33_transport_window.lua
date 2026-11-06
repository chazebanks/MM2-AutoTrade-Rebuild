-- Stage33: PURE read-only window-scoped transport census using existing Stage30 core.
-- Watches only the 16 previously cataloged MM2 Trade RemoteEvent names.
-- Pre-open receipts are unbound; all receipts and inventory changes are client claims.
-- Does NOT grant final Accept, completed-trade journaling, or profit authority.
local M={}
local NAMES={
 "AcceptRequest","AcceptTrade","CancelAccept","CancelRequest",
 "CompleteTrade","DeclineRequest","DeclineTrade","EndTrade",
 "GetRequest","OfferItem","RemoveOffer","RequestSent",
 "SetRequestsEnabled","StartTrade","UpdateOffers","UpdateTrade"
}
local allowed={}
for _,n in ipairs(NAMES) do allowed[n]=true end
local function finite(t)
 return type(t)=="number" and t==t and t>=0 and t<math.huge
end
function M.names()
 local a={}
 for i,n in ipairs(NAMES) do a[i]=n end
 return a
end
function M.new(core,t)
 assert(type(core)=="table" and type(core.new)=="function"
  and type(core.catalog)=="function" and type(core.received)=="function"
  and type(core.closed)=="function" and type(core.finish)=="function"
  and type(core.summary)=="function" and finite(t),
  "Stage30 pure core and monotonic time required")
 return {core=core,started=t,phase="WAIT_OPEN",lastAt=t,
  preOpenCount=0,preOpenNames={},scopedNames={},tail={},
  scopedCount=0,census=nil,closedAt=nil,final=false,reason="await-trade",
  status="INCOMPLETE"}
end
function M.open(s,t)
 if s.final or s.phase~="WAIT_OPEN" then return false,"not-waiting" end
 if not finite(t) or t<s.started then return false,"invalid-time" end
 local c=s.core.new({session="stage33-anonymized-local-window"},t)
 local ok,why=s.core.catalog(c,M.names(),t)
 if not ok then return false,"catalog-failed:"..tostring(why) end
 s.census=c;s.phase="ACTIVE";s.openAt=t;s.lastAt=t
 return true,"bound-window"
end
function M.received(s,n,t)
 if s.final then return false,"finished" end
 if not allowed[n] then return false,"not-in-known-catalog" end
 if not finite(t) or t<s.started then return false,"invalid-time" end
 if s.phase=="WAIT_OPEN" then
  s.preOpenCount=s.preOpenCount+1
  s.preOpenNames[n]=(s.preOpenNames[n] or 0)+1
  return true,"PRE_OPEN_UNBOUND"
 end
 if s.phase~="ACTIVE" and s.phase~="AFTER_CLOSE" then
  return false,"session-not-observable"
 end
 local ok,phase=s.core.received(s.census,n,t)
 if not ok then return false,phase end
 s.scopedCount=s.scopedCount+1
 s.scopedNames[n]=(s.scopedNames[n] or 0)+1
 local v={name=n,phase=phase,elapsed=math.floor((t-s.openAt)*1000+.5)/1000}
 s.tail[#s.tail+1]=v
 if #s.tail>16 then table.remove(s.tail,1) end
 s.lastAt=t
 return true,phase
end
function M.close(s,t)
 if s.final or s.phase~="ACTIVE" then return false,"not-active" end
 if not finite(t) or t<s.openAt then return false,"invalid-time" end
 local ok,why=s.core.closed(s.census,"CLOSED_UNKNOWN",t)
 if not ok then return false,why end
 s.closedAt=t;s.phase="AFTER_CLOSE"
 return true,"closure-observed-only"
end
function M.finish(s,t,normal)
 if s.final then return false,"finished" end
 if not finite(t) or t<s.started then return false,"invalid-time" end
 s.final=true
 -- Post-close grace must be observable for at least 2 seconds.
 local complete=normal==true and s.phase=="AFTER_CLOSE"
  and t-s.closedAt>=2 and t-s.closedAt<=8
 if s.census and not s.census.final then
  s.core.finish(s.census,complete and "OBSERVATION_FINISHED"
   or "SESSION_CHANGED",t)
 end
 s.reason=complete and "bounded-client-signal-census-finished"
  or "window-not-fully-observed"
 s.status=complete and "WINDOW_CLOSED_WITH_CLIENT_CENSUS"
  or "INCOMPLETE"
 s.phase="FINISHED"
 return true,s.status
end
function M.summary(s)
 local c=s.census and s.core.summary(s.census) or nil
 local tail={}
 for i,v in ipairs(s.tail) do
  tail[i]={name=v.name,phase=v.phase,elapsed=v.elapsed}
 end
 local counts={},pre={}
 for n,q in pairs(s.scopedNames) do counts[n]=q end
 for n,q in pairs(s.preOpenNames) do pre[n]=q end
 return {schema="gingerscope-stage33-trade-transport-census-v1",
  status=s.status,reason=s.reason,
  catalogSize=#NAMES,
  preOpenUnboundCount=s.preOpenCount,preOpenUnboundNames=pre,
  scopedReceipts=s.scopedCount,perNameCounts=counts,
  firstReceipts=c and c.signals or {},
  retainedFirstReceipts=c and c.retainedReceipts or 0,
  recentReceipts=tail,retainedRecentReceipts=#tail,
  earlierReceiptsTruncated=s.scopedCount>24,
  postCloseReceipts=c and c.postCloseSignalReceipts or 0,
  clientClosureObserved=s.closedAt~=nil,
  tradeOutcome="UNKNOWN",serverAttestation=false,
  serverCompletionProven=false,causalAttributionProven=false,
  authorizesTrade=false,authorizesAccept=false,
  mayRecordCompletedTrade=false,mayReportProfit=false,
  readOnly=true}
end
return M
