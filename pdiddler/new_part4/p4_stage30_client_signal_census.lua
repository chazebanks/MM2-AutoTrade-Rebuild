-- Stage30: pure read-only client-side MM2 trade signal evidence.
-- Native RemoteEvent OnClientEvent receipt is NOT server trade completion.
-- Stores only bounded sanitized *event names*, timing and receipt counts.
-- No payload values, player identifiers, item IDs or server calls.
local M={}
local function finite(v)
 return type(v)=="number" and v==v and v>=0 and v<math.huge
end
local function name(v)
 return type(v)=="string" and #v>0 and #v<=48
  and v:match("^[%w_%-]+$")~=nil
end
local function countRows(t)
 local n=0
 for _ in pairs(t) do n=n+1 end
 return n
end
function M.new(scope,t)
 assert(type(scope)=="table" and type(scope.session)=="string"
   and scope.session~="" and finite(t),"bound trade scope needed")
 return {session=scope.session,started=t,closedAt=nil,
  final=false,closure="NOT_OBSERVED",partnerLeft=false,
  errors={},events={},names={},listeners=0,
  namesRejected=0,samples=0,postCloseSignals=0,
  status="OBSERVING_CLIENT_SIGNALS",
  authorizesAccept=false,serverCompletionProven=false}
end
function M.catalog(s,remoteNames,t)
 if s.final then return false,"finished" end
 if not finite(t) or t<s.started or type(remoteNames)~="table"
    or #remoteNames>32 then return false,"catalog-invalid" end
 local catalog={}
 for i,n in ipairs(remoteNames) do
  if not name(n) or catalog[n] then
   return false,"catalog-ambiguous-or-untrusted"
  end
  catalog[n]=true
 end
 s.names=catalog;s.listeners=#remoteNames
 return true,"catalog-only"
end
function M.received(s,n,t)
 if s.final then return false,"finished" end
 if not name(n) or not s.names[n] then
  s.namesRejected=s.namesRejected+1
  return false,"not-a-bound-trade-event"
 end
 if not finite(t) or t<s.started then
  s.errors[#s.errors+1]="invalid-event-time"
  return false,"invalid-event-time"
 end
 s.samples=s.samples+1
 local phase=s.closedAt and "AFTER_CLOSE" or "WHILE_OPEN"
 if s.closedAt then s.postCloseSignals=s.postCloseSignals+1 end
 if #s.events<24 then
  s.events[#s.events+1]={name=n,phase=phase,elapsed=math.floor((t-s.started)*1000+.5)/1000}
 end
 return true,phase
end
function M.partnerDeparture(s,t)
 if s.final then return false,"finished" end
 if not finite(t) or t<s.started then return false,"invalid-time" end
 s.partnerLeft=true
 return true,"partner-departure-client-observed-only"
end
function M.closed(s,reason,t)
 if s.final or s.closedAt then return false,"already-closed" end
 if reason~="CLOSED_UNKNOWN" or not finite(t) or t<s.started then
  s.status="INVALID";s.final=true
  return false,"invalid-session-close"
 end
 s.closedAt=t;s.closure="CLOSED_UNKNOWN"
 s.status="POST_CLOSE_SIGNAL_GRACE"
 return true,"gui-closure-client-observed-only"
end
function M.finish(s,reason,t)
 if s.final then return false,"finished" end
 if not finite(t) or t<s.started then return false,"invalid-time" end
 if s.closedAt and t<s.closedAt then return false,"preclosure-finish" end
 s.final=true
 if reason=="WINDOW_TIMED_OUT" or reason=="SESSION_CHANGED" then
  s.status="INCOMPLETE"
 elseif s.closedAt then
  s.status="CLOSED_WITH_CLIENT_SIGNAL_CENSUS"
 else
  s.status="INCOMPLETE"
 end
 return true,s.status
end
function M.summary(s)
 local names={}
 for n in pairs(s.names) do names[#names+1]=n end
 table.sort(names)
 local records={}
 for i,e in ipairs(s.events) do
  records[i]={name=e.name,phase=e.phase,elapsed=e.elapsed}
 end
 return {schema="gingerscope-stage30-client-trade-signal-census-v1",
  status=s.status,closureStatus=s.closure,
  catalogRemoteEvents=s.listeners,
  catalogNames=names,
  signalReceipts=s.samples,retainedReceipts=#records,
  postCloseSignalReceipts=s.postCloseSignals,
  ignoredUnboundSignals=s.namesRejected,
  partnerDepartureObserved=s.partnerLeft,
  signals=records,
  clientSignalsDoNotEstablishTradeOutcome=true,
  tradeOutcome="UNKNOWN",serverAttestation=false,
  serverCompletionProven=false,authorizesTrade=false,
  authorizesAccept=false,mayRecordCompletedTrade=false,
  mayReportProfit=false,reviewOnly=true}
end
return M
