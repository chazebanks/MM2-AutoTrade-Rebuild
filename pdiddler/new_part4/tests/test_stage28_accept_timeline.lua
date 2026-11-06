-- Stage28 pure client acceptance timeline regression, NO Roblox/remote calls.
local dir=arg[1] or "pdiddler/new_part4"
package.path=dir.."/?.lua;"..package.path
local Timeline=require("p4_stage28_accept_timeline")
local passed=0
local function test(label,fn)
 local ok,reason=pcall(fn)
 if not ok then error("FAILED "..label..": "..tostring(reason)) end
 passed=passed+1
end
local function fixture()
 local s=Timeline.new("job:own:partner:1",100,{minStableGap=0.15})
 local o={session="job:own:partner:1",tradeOpen=true,contextOK=true,
  ourSig="one-local",theirSig="one-opponent",
  ourSlots=1,theirSlots=1,theirResolved=true,
  ourAccepted=false,theirAccepted=false}
 local d={
  ourItems={{id="KnifeA",page="godly",checkerId="11",qty=1,slot=1}},
  theirItems={{id="KnifeB",page="chroma",checkerId="12",qty=1,slot=1}},
  authorizesTrade=false,authorizesAccept=false,provesCompletion=false}
 return s,o,d
end
local function feed(s,o,d,t)
 return Timeline.ingest(s,o,d,t)
end
test("initial open record is not accepted and no trade authority",function()
 local s,o,d=fixture()
 assert(feed(s,o,d,100.1)=="OBSERVED")
 local x=Timeline.summary(s)
 assert(x.status=="NEITHER" and x.observations==1)
 assert(x.authorizesTrade==false and x.authorizesAccept==false)
 assert(x.mayRecordCompletedTrade==false and x.serverCompletionProven==false)
end)
test("their Accept alone stays client-only",function()
 local s,o,d=fixture();feed(s,o,d,100.1)
 o.theirAccepted=true
 assert(feed(s,o,d,100.2)=="OBSERVED")
 assert(Timeline.summary(s).status=="THEIRS_ONLY")
 assert(not s.anyBothAccepted)
end)
test("our Accept alone is not a completed trade",function()
 local s,o,d=fixture();o.ourAccepted=true
 assert(feed(s,o,d,100.1)=="OBSERVED")
 assert(Timeline.summary(s).status=="OURS_ONLY")
 assert(not s.anyBothAccepted)
end)
test("both accepted require separate stable poll",function()
 local s,o,d=fixture()
 o.ourAccepted=true;o.theirAccepted=true
 assert(feed(s,o,d,100.1)=="HOLD")
 assert(Timeline.summary(s).status=="BOTH_ACCEPTED_PENDING")
 assert(feed(s,o,d,100.2)=="HOLD")
 assert(not Timeline.summary(s).bothAcceptedStableObserved)
 assert(feed(s,o,d,100.32)=="OBSERVED")
 assert(Timeline.summary(s).bothAcceptedStableObserved)
 assert(Timeline.summary(s).serverCompletionProven==false)
end)
test("trade closure after both accepted stays CLOSED_UNKNOWN",function()
 local s,o,d=fixture()
 o.ourAccepted=true;o.theirAccepted=true
 feed(s,o,d,100.1);feed(s,o,d,100.3)
 o.tradeOpen=false
 assert(feed(s,o,d,100.4)=="CLOSED_UNKNOWN")
 local summary=Timeline.summary(s)
 assert(summary.bothAcceptedStableObserved==true)
 assert(summary.closureStatus=="closed_unknown")
 assert(summary.closureProvesCompletion==false)
 assert(summary.mayReportProfit==false)
end)
test("closure after no acceptance is still unknown",function()
 local s,o,d=fixture()
 feed(s,o,d,100.1)
 o.tradeOpen=false
 assert(feed(s,o,d,100.2)=="CLOSED_UNKNOWN")
 assert(Timeline.summary(s).closureStatus=="closed_unknown")
end)
test("a closed session cannot be rebound after same-root reopen",function()
 local s,o,d=fixture()
 feed(s,o,d,100.1)
 o.tradeOpen=false;feed(s,o,d,100.2)
 o.tradeOpen=true
 assert(feed(s,o,d,100.3)=="HOLD")
 assert(s.phase=="CLOSED_UNKNOWN")
end)
test("changed own offer after either Accept permanently taints candidate",function()
 local s,o,d=fixture()
 feed(s,o,d,100.1)
 o.ourAccepted=true
 feed(s,o,d,100.2)
 o.ourSig="new-weapon"
 assert(feed(s,o,d,100.3)=="HOLD")
 assert(s.phase=="OFFER_CHANGED_AFTER_ACCEPT")
 assert(Timeline.summary(s).offerMutationAfterAccept)
end)
test("changed opponent offer after both accepted cannot be stable",function()
 local s,o,d=fixture()
 o.ourAccepted=true;o.theirAccepted=true
 feed(s,o,d,100.1)
 o.theirSig="replaced"
 assert(feed(s,o,d,100.3)=="HOLD")
 assert(not Timeline.summary(s).bothAcceptedStableObserved)
 assert(Timeline.summary(s).offerMutationAfterAccept)
end)
test("prior both stable is historical but cannot mint completion after mutation",function()
 local s,o,d=fixture()
 o.ourAccepted=true;o.theirAccepted=true
 feed(s,o,d,100.1);feed(s,o,d,100.3)
 o.theirSig="swapped"
 feed(s,o,d,100.4)
 assert(Timeline.summary(s).bothAcceptedStableObserved)
 assert(not Timeline.summary(s).currentBothAcceptedStable)
 assert(Timeline.summary(s).offerMutationAfterAccept)
 o.tradeOpen=false;feed(s,o,d,100.5)
 assert(not Timeline.summary(s).mayRecordCompletedTrade)
end)
test("unaccepted offer changes reset pending without taint",function()
 local s,o,d=fixture()
 feed(s,o,d,100.1)
 o.ourSig="updated"
 assert(feed(s,o,d,100.2)=="OBSERVED")
 assert(not s.tainted)
 assert(s.phase=="NEITHER")
end)
test("missing accept indicator is not counted as false",function()
 local s,o,d=fixture()
 o.theirAccepted=nil
 assert(feed(s,o,d,100.1)=="HOLD")
 assert(not s.stableEver)
 assert(s.phase=="ACCEPT_UNKNOWN" or s.phase=="UNRESOLVED")
end)
test("missing current resolved opponent identity blocks evidence",function()
 local s,o,d=fixture()
 o.theirResolved=false
 assert(feed(s,o,d,100.1)=="HOLD")
 assert(not s.anyBothAccepted)
end)
test("missing current own identity blocks evidence",function()
 local s,o,d=fixture()
 d.ourItems={}
 assert(feed(s,o,d,100.1)=="HOLD")
 assert(not s.anyBothAccepted)
end)
test("opponent empty, own item offered: both accepted indicators are valid observations",function()
 local s,o,d=fixture()
 o.theirSlots=0;d.theirItems={}
 o.ourAccepted=true;o.theirAccepted=true
 assert(feed(s,o,d,100.1)=="HOLD")
 assert(feed(s,o,d,100.32)=="OBSERVED")
 local result=Timeline.summary(s)
 assert(result.bothAcceptedStableObserved)
 assert(not result.offerMutationAfterAccept)
 assert(not result.serverCompletionProven)
end)
test("local side empty, opponent offers item: both GUI indicators can stabilize",function()
 local s,o,d=fixture()
 o.ourSlots=0;d.ourItems={}
 o.ourAccepted=true;o.theirAccepted=true
 assert(feed(s,o,d,100.1)=="HOLD")
 assert(feed(s,o,d,100.32)=="OBSERVED")
 local result=Timeline.summary(s)
 assert(result.bothAcceptedStableObserved)
 assert(not result.acceptedWithUnresolvedOffer)
 assert(not result.serverCompletionProven)
end)
test("partner Accept with our side empty is valid one-sided evidence",function()
 local s,o,d=fixture()
 o.ourSlots=0;d.ourItems={}
 o.theirAccepted=true
 assert(feed(s,o,d,100.1)=="OBSERVED")
 local report=Timeline.summary(s)
 assert(report.theirAcceptIndicatorEverVisible)
 assert(report.status=="THEIRS_ONLY")
 assert(not report.offerMutationAfterAccept)
 assert(not report.acceptedWithUnresolvedOffer)
 assert(not report.bothAcceptedStableObserved)
end)
test("adding our weapon after partner Accepted counts as an offer mutation",function()
 local s,o,d=fixture()
 o.ourSlots=0;d.ourItems={};o.theirAccepted=true
 assert(feed(s,o,d,100.1)=="OBSERVED")
 o.ourSlots=1;d.ourItems={{
   slot=1,id="KnifeA",page="godly",checkerId="11",qty=1}}
 o.ourSig="newly-added-local-item"
 o.ourAccepted=true
 assert(feed(s,o,d,100.3)=="HOLD")
 assert(feed(s,o,d,100.6)=="HOLD")
 local report=Timeline.summary(s)
 assert(report.offerMutationAfterAccept)
 assert(not report.bothAcceptedStableObserved)
 assert(not report.mayRecordCompletedTrade)
end)
test("both sides empty is unresolved even when accepted indicators appear",function()
 local s,o,d=fixture()
 o.ourSlots=0;d.ourItems={}
 o.theirSlots=0;d.theirItems={}
 o.theirAccepted=true
 assert(feed(s,o,d,100.1)=="HOLD")
 local r=Timeline.summary(s)
 assert(r.status=="UNRESOLVED")
 assert(r.acceptedWithUnresolvedOffer)
 assert(r.theirAcceptIndicatorEverVisible)
 assert(not r.offerMutationAfterAccept)
 assert(not r.bothAcceptedStableObserved)
end)
test("unresolved acceptance history cannot later become a stable bilateral read",function()
 local s,o,d=fixture()
 o.ourSlots=0;d.ourItems={}
 o.theirSlots=0;d.theirItems={}
 o.theirAccepted=true
 feed(s,o,d,100.1)
 o.theirSlots=1;d.theirItems={{
    id="KnifeB",page="chroma",checkerId="12",qty=1,slot=1}}
 o.theirSig="now-one-counterparty-item"
 o.ourAccepted=true
 assert(feed(s,o,d,100.3)=="HOLD")
 assert(feed(s,o,d,100.6)=="HOLD")
 local r=Timeline.summary(s)
 assert(r.acceptedWithUnresolvedOffer)
 assert(not r.bothAcceptedStableObserved)
 assert(not r.offerMutationAfterAccept)
end)
test("unknown tier in observed offer blocks evidence",function()
 local s,o,d=fixture()
 d.theirItems[1].page="vintage"
 assert(feed(s,o,d,100.1)=="HOLD")
end)
test("unknown/ambiguous checker id blocks evidence",function()
 local s,o,d=fixture()
 d.theirItems[1].checkerId="raw-name"
 assert(feed(s,o,d,100.1)=="HOLD")
end)
test("duplicate slot in one side is invalid",function()
 local s,o,d=fixture()
 o.theirSlots=2
 d.theirItems[2]={id="Other",page="godly",checkerId="13",qty=1,slot=1}
 assert(feed(s,o,d,100.1)=="HOLD")
end)
test("invalid quantity cannot be accepted",function()
 local s,o,d=fixture()
 d.theirItems[1].qty=0
 assert(feed(s,o,d,100.1)=="HOLD")
end)
test("wrong bound session terminates and cannot inherit new partner",function()
 local s,o,d=fixture()
 o.session="other-session"
 assert(feed(s,o,d,100.1)=="INVALID")
 assert(Timeline.summary(s).status=="INVALID")
 o.session=s.session
 assert(feed(s,o,d,100.2)=="HOLD")
end)
test("nonmonotonic timestamps terminate timeline",function()
 local s,o,d=fixture()
 feed(s,o,d,100.1)
 assert(feed(s,o,d,100.1)=="INVALID")
 assert(Timeline.summary(s).status=="INVALID")
end)
test("unknown trade-open flag fails closed",function()
 local s,o,d=fixture()
 o.tradeOpen=nil
 assert(feed(s,o,d,100.1)=="INVALID")
end)
test("duplicate evidence has capped anonymized events",function()
 local s,o,d=fixture()
 for i=1,85 do assert(feed(s,o,d,100+i*.2)=="OBSERVED") end
 local x=Timeline.summary(s)
 assert(#x.events==32 and x.observations==85)
 for _,event in ipairs(x.events) do
   assert(event.partner==nil and event.id==nil and event.jobId==nil)
 end
end)
test("market freshness cannot become completion authority",function()
 local s,o,d=fixture();o.marketFresh=false
 o.ourAccepted=true;o.theirAccepted=true
 feed(s,o,d,100.1);feed(s,o,d,100.3)
 assert(s.stableEver)
 local x=Timeline.summary(s)
 assert(not x.authorizesAccept and not x.serverCompletionProven)
end)
test("function never records completed trade even with accepted closure",function()
 local s,o,d=fixture()
 o.ourAccepted=true;o.theirAccepted=true
 feed(s,o,d,100.1);feed(s,o,d,100.3)
 o.tradeOpen=false;feed(s,o,d,100.4)
 local report=Timeline.summary(s)
 assert(report.mayRecordCompletedTrade==false)
 assert(report.mayReportProfit==false)
 assert(report.closureProvesCompletion==false)
end)
test("actual 174-poll one-sided partner acceptance must not report offer mutation",function()
 local s,o,d=fixture()
 o.ourSlots=0;d.ourItems={}
 for i=1,174 do
  if i>=32 then o.theirAccepted=true end
  if i==174 then o.tradeOpen=false end
  local outcome=feed(s,o,d,100+i*.1)
  if i==174 then assert(outcome=="CLOSED_UNKNOWN") end
 end
 local r=Timeline.summary(s)
 assert(r.status=="CLOSED_UNKNOWN")
 assert(r.observations==174)
 assert(r.theirAcceptIndicatorEverVisible)
 assert(not r.ourAcceptIndicatorEverVisible)
 assert(not r.offerMutationAfterAccept)
 assert(not r.acceptedWithUnresolvedOffer)
 assert(not r.bothAcceptedStableObserved)
 assert(r.mayRecordCompletedTrade==false)
 assert(#r.events==32)
end)
print("PASS",passed,"Stage28 pure acceptance/closure read-only timeline regression")
