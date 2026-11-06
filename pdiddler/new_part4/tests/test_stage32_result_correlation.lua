-- Stage32 pure three-stream correlation regression (NO Roblox runtime).
local dir=arg[1] or "pdiddler/new_part4"
package.path=dir.."/?.lua;"..package.path
local J=require("p4_stage32_result_correlation")
local passed=0
local function test(label,fn)
 local ok,why=pcall(fn)
 if not ok then error("FAILED "..label..":"..tostring(why)) end
 passed=passed+1
end
local function fixture()
 local t={session="S1",terminal=true,phase="CLOSED_UNKNOWN",
   lastTime=15,stableEver=false,
   theirAcceptIndicatorEverVisible=false,ourAcceptIndicatorEverVisible=false}
 local c={session="S1",final=true,closure="CLOSED_UNKNOWN",
   closedAt=15,events={},samples=0,partnerLeft=false}
 local l={session="S1",terminal=true,closedAt=15,scans=3,
   status="NO_ELIGIBLE_DELTA_OBSERVED",changedTypes=0,
   gainedCount=0,lostCount=0}
 return t,c,l
end
local function event(c,name)
 c.samples=c.samples+1
 c.events[#c.events+1]={name=name,phase="WHILE_OPEN",elapsed=4}
end
local function boundary(r)
 assert(r.tradeOutcome=="UNKNOWN" and r.serverCompletionProven==false)
 assert(r.serverAttestation==false and r.causalAttributionProven==false)
 assert(r.authorizesTrade==false and r.authorizesAccept==false)
 assert(r.mayRecordCompletedTrade==false and r.mayReportProfit==false)
 assert(r.reviewOnly==true)
end
test("known Stage30 decline scenario is not completion or actor evidence",function()
 local t,c,l=fixture();event(c,"DeclineTrade")
 local r=J.evaluate(t,c,l)
 assert(r.status=="DECLINE_NAMED_RECEIPT_ONLY")
 assert(r.declineTradeSignalSeen and not r.completeTradeSignalSeen)
 boundary(r)
end)
test("CompleteTrade present and real-looking eligible delta still no completion",function()
 local t,c,l=fixture()
 t.stableEver=true;event(c,"CompleteTrade")
 l.status="ELIGIBLE_DELTA_UNATTRIBUTED";l.changedTypes=2
 l.gainedCount=1;l.lostCount=1
 local r=J.evaluate(t,c,l)
 assert(r.status=="COMPLETE_NAMED_RECEIPT_AND_UNATTRIBUTED_DELTA")
 assert(r.bothAcceptedStableObserved and r.completeTradeSignalSeen)
 assert(r.changedEligibleTypes==2 and r.gainedEligibleCopies==1)
 boundary(r)
end)
test("CompleteTrade event with no eligible delta stays nonauthoritative",function()
 local t,c,l=fixture();event(c,"CompleteTrade")
 local r=J.evaluate(t,c,l)
 assert(r.status=="COMPLETE_NAMED_RECEIPT_WITHOUT_ELIGIBLE_DELTA")
 boundary(r)
end)
test("EndTrade without inventory change not success or decline",function()
 local t,c,l=fixture();event(c,"EndTrade")
 local r=J.evaluate(t,c,l)
 assert(r.status=="END_NAMED_RECEIPT_WITHOUT_ELIGIBLE_DELTA")
 boundary(r)
end)
test("EndTrade and delta still not server settlement",function()
 local t,c,l=fixture();event(c,"EndTrade")
 l.status="ELIGIBLE_DELTA_UNATTRIBUTED";l.changedTypes=1
 local r=J.evaluate(t,c,l)
 assert(r.status=="END_NAMED_RECEIPT_AND_UNATTRIBUTED_DELTA")
 boundary(r)
end)
test("CompleteTrade and DeclineTrade conflict fails attribution",function()
 local t,c,l=fixture()
 event(c,"CompleteTrade");event(c,"DeclineTrade")
 l.status="ELIGIBLE_DELTA_UNATTRIBUTED"
 local r=J.evaluate(t,c,l)
 assert(r.status=="CONFLICTING_RESULT_NAMED_RECEIPTS")
 assert(r.observedResultNamedReceipts==2)
 boundary(r)
end)
test("Delta without a result-named signal is unattributed",function()
 local t,c,l=fixture()
 event(c,"UpdateOffers")
 l.status="ELIGIBLE_DELTA_UNATTRIBUTED";l.changedTypes=1
 local r=J.evaluate(t,c,l)
 assert(r.status=="ELIGIBLE_DELTA_WITHOUT_RESULT_NAMED_RECEIPT")
 boundary(r)
end)
test("no signal no delta says only no signal observed",function()
 local t,c,l=fixture()
 local r=J.evaluate(t,c,l)
 assert(r.status=="NO_RESULT_NAMED_RECEIPT_OBSERVED")
 boundary(r)
end)
test("changed session prevents correlation",function()
 local t,c,l=fixture();c.session="S2"
 local r=J.evaluate(t,c,l)
 assert(r.status=="INCOMPLETE")
 boundary(r)
end)
test("only one post-read fails closed",function()
 local t,c,l=fixture()
 l.scans=2;l.terminal=false;l.status="AWAIT_AFTER2"
 local r=J.evaluate(t,c,l)
 assert(r.status=="INCOMPLETE")
 boundary(r)
end)
test("distinct post-close reads disagree fails closed",function()
 local t,c,l=fixture()
 event(c,"CompleteTrade")
 l.status="POST_READS_DISAGREE"
 local r=J.evaluate(t,c,l)
 assert(r.status=="INCOMPLETE")
 boundary(r)
end)
test("unbound or mismatching close time fails",function()
 local t,c,l=fixture();l.closedAt=17
 local r=J.evaluate(t,c,l)
 assert(r.status=="INCOMPLETE")
 boundary(r)
end)
test("late partner departure cannot prove exact trade outcome",function()
 local t,c,l=fixture();c.partnerLeft=true
 event(c,"CompleteTrade")
 local r=J.evaluate(t,c,l)
 assert(r.status=="PARTNER_DEPARTURE_OBSERVED")
 boundary(r)
end)
test("truncated census cannot establish absent result event",function()
 local t,c,l=fixture()
 c.samples=50
 event(c,"UpdateOffers")
 local r=J.evaluate(t,c,l)
 assert(r.status=="CENSUS_TRUNCATED")
 assert(r.resultNamedSignalsTruncated)
 boundary(r)
end)
test("Stable both Accept cannot substitute for remote or inventory evidence",function()
 local t,c,l=fixture();t.stableEver=true
 local r=J.evaluate(t,c,l)
 assert(r.status=="NO_RESULT_NAMED_RECEIPT_OBSERVED")
 assert(r.bothAcceptedStableObserved)
 boundary(r)
end)
test("raw weapon-only change is not client eligible delta",function()
 local t,c,l=fixture();event(c,"EndTrade")
 l.status="RAW_WEAPON_CHANGE_UNATTRIBUTED"
 local r=J.evaluate(t,c,l)
 assert(r.status=="END_NAMED_RECEIPT_WITHOUT_ELIGIBLE_DELTA")
 boundary(r)
end)
test("output does not leak transaction IDs or item identities",function()
 local t,c,l=fixture()
 local r=J.evaluate(t,c,l)
 for _,name in ipairs({"session","partnerId","jobId","accountId",
    "checkerId","itemId","fingerprint","rawOffer","profit"}) do
   assert(r[name]==nil)
 end
 boundary(r)
end)
print("PASS",passed,"Stage32 client-only result-signal inventory correlation")
