-- Stage32: PURE read-only correlation of Stage28/29/30 client evidence.
-- NEVER translates a RemoteEvent name, GUI closure, Accept icon, or local
-- inventory delta into server completion or automated trading permission.
local M={}
local function finite(n)
 return type(n)=="number" and n==n and n>=0 and n<math.huge
end
local allowed={
 NO_ELIGIBLE_DELTA_OBSERVED=true,ELIGIBLE_DELTA_UNATTRIBUTED=true,
 RAW_WEAPON_CHANGE_UNATTRIBUTED=true,POST_READS_DISAGREE=true,
}
local function result(status,reason,t,c,l,names)
 local record={
   schema="gingerscope-stage32-client-signal-and-inventory-correlation-v1",
   status=status,reason=reason,
   completeTradeSignalSeen=names.complete,
   endTradeSignalSeen=names.ended,
   declineTradeSignalSeen=names.declined,
   observedResultNamedReceipts=names.count,
   resultNamedSignalsTruncated=names.truncated,
   bothAcceptedStableObserved=t and t.stableEver==true or false,
   theirAcceptIndicatorEverVisible=t and t.theirAcceptIndicatorEverVisible==true or false,
   ourAcceptIndicatorEverVisible=t and t.ourAcceptIndicatorEverVisible==true or false,
   postCloseInventoryStatus=l and l.status or "NO_READBACK",
   changedEligibleTypes=l and l.changedTypes or nil,
   gainedEligibleCopies=l and l.gainedCount or nil,
   lostEligibleCopies=l and l.lostCount or nil,
   partnerDepartureObserved=c and c.partnerLeft==true or false,
   tradeOutcome="UNKNOWN",causalAttributionProven=false,
   serverAttestation=false,serverCompletionProven=false,
   authorizesTrade=false,authorizesAccept=false,
   mayRecordCompletedTrade=false,mayReportProfit=false,
   reviewOnly=true}
 return record
end
function M.evaluate(t,c,l)
 local n={complete=false,ended=false,declined=false,count=0,truncated=false}
 if type(t)~="table" or type(c)~="table" or type(l)~="table"
   or not t.session or t.session~=c.session or t.session~=l.session
   or not t.terminal or not c.final or not l.terminal then
   return result("INCOMPLETE","evidence-not-terminal-or-session-mismatch",t,c,l,n)
 end
 if t.phase~="CLOSED_UNKNOWN" or c.closure~="CLOSED_UNKNOWN"
   or not finite(t.lastTime) or not finite(c.closedAt)
   or not finite(l.closedAt)
   or math.abs(t.lastTime-c.closedAt)>1
   or math.abs(t.lastTime-l.closedAt)>1 then
   return result("INCOMPLETE","independent-client-closures-not-correlated",t,c,l,n)
 end
 if type(c.events)~="table" or type(c.samples)~="number" then
   return result("INCOMPLETE","client-signal-record-invalid",t,c,l,n)
 end
 n.truncated=c.samples>#c.events
 for _,record in ipairs(c.events) do
   if record.name=="CompleteTrade" then
     n.complete=true;n.count=n.count+1
   elseif record.name=="EndTrade" then
     n.ended=true;n.count=n.count+1
   elseif record.name=="DeclineTrade" then
     n.declined=true;n.count=n.count+1
   end
 end
 if l.status=="POST_READS_DISAGREE" then
   return result("INCOMPLETE","two-post-close-inventory-reads-disagree",t,c,l,n)
 end
 if not allowed[l.status] or l.scans~=3 then
   return result("INCOMPLETE","bounded-complete-inventory-readback-unavailable",t,c,l,n)
 end
 if c.partnerLeft then
   return result("PARTNER_DEPARTURE_OBSERVED","departure-does-not-prove-trade-outcome",t,c,l,n)
 end
 if n.truncated then
   return result("CENSUS_TRUNCATED","result-signal-presence-incomplete",t,c,l,n)
 end
 if n.complete and n.declined then
   return result("CONFLICTING_RESULT_NAMED_RECEIPTS",
      "completed-and-declined-names-not-authenticated",t,c,l,n)
 end
 if n.complete and l.status=="ELIGIBLE_DELTA_UNATTRIBUTED" then
   return result("COMPLETE_NAMED_RECEIPT_AND_UNATTRIBUTED_DELTA",
      "client-signal-and-local-weapon-change-are-not-server-attestation",t,c,l,n)
 end
 if n.complete then
   return result("COMPLETE_NAMED_RECEIPT_WITHOUT_ELIGIBLE_DELTA",
      "client-signal-name-alone-cannot-prove-completion",t,c,l,n)
 end
 if n.ended and l.status=="ELIGIBLE_DELTA_UNATTRIBUTED" then
   return result("END_NAMED_RECEIPT_AND_UNATTRIBUTED_DELTA",
      "client-EndTrade-name-is-not-settlement-proof",t,c,l,n)
 end
 if n.ended then
   return result("END_NAMED_RECEIPT_WITHOUT_ELIGIBLE_DELTA",
      "end-name-is-not-completion-or-decline-proof",t,c,l,n)
 end
 if n.declined then
   return result("DECLINE_NAMED_RECEIPT_ONLY",
      "decline-event-name-does-not-identify-actor-or-settlement",t,c,l,n)
 end
 if l.status=="ELIGIBLE_DELTA_UNATTRIBUTED" then
   return result("ELIGIBLE_DELTA_WITHOUT_RESULT_NAMED_RECEIPT",
      "own-inventory-change-cause-unverified",t,c,l,n)
 end
 return result("NO_RESULT_NAMED_RECEIPT_OBSERVED",
    "no-matching-receipts-not-evidence-of-absence",t,c,l,n)
end
return M
