local guard=dofile(arg[1])
local NOW=1794159000
local function deepcopy(obj)
 if type(obj)~="table" then return obj end
 local out={}
 for k,v in pairs(obj) do out[deepcopy(k)]=deepcopy(v) end
 return out
end
local function entry(v,d,s)
 return {value=v,demand=d,stability=s,identityLinkEvidence="INDEPENDENT_EXACT"}
end
local function fixture()
 local c={source="SUPREME_DISPLAY_RESEARCH_ONLY",version="SYNTHETIC-V1",
  retrievedAtUnix=NOW-2,publisherUpdatedAtUnix=NOW-200,
  items={own=entry(100,5,"Stable"),receive=entry(105,5,"Stable"),
         illiquid=entry(400,1,"Stable"),falling=entry(250,10,"Declining"),
         stack=entry(60,8,"Stable")}}
 local p={sessionId="S-ABC",jobId="J-123",partnerKey="OPAQUE-EXACT",
  catalogVersion="SYNTHETIC-V1",offerRevision=17,observedAtUnix=NOW-1,
  ours={{index=1,key="own",quantity=1}},
  theirs={{index=1,key="receive",quantity=1}}}
 local o=deepcopy(p)
 o.observedAtUnix=NOW;o.tradeOpen=true;o.exactPartnerBound=true
 o.ourAccepted=false;o.theirAccepted=false;o.offerMutationPending=false
 return p,o,c
end
local function expected(reason,edit)
 local p,o,c=fixture()
 if edit then edit(p,o,c) end
 local r=guard.evaluate(p,o,c,NOW)
 assert(r.status=="REJECTED",reason..": unexpected status "..tostring(r.status))
 assert(r.reason==reason,"wanted "..reason.." got "..tostring(r.reason))
 assert(r.tradeOutcome=="UNKNOWN" and r.serverCompletionProven==false)
 assert(r.authorizesTrade==false and r.authorizesAccept==false)
 assert(r.mayReportProfit==false and r.mayUseForStrategyLearning==false)
 return r
end
local p,o,c=fixture()
local r=guard.evaluate(p,o,c,NOW)
assert(r.status=="RESEARCH_CANDIDATE_ONLY")
assert(r.valueOffered==100 and r.valueRequested==105 and r.projectedListedGain==5)
assert(r.authorizesTrade==false and r.authorizesAccept==false)
assert(r.serverCompletionProven==false and r.mayReportProfit==false)
expected("OFFER_REVISION_CHANGED",function(p,o) o.offerRevision=o.offerRevision+1 end)
expected("OFFER_SLOTS_CHANGED",function(p,o) o.theirs[1].key="own" end)
expected("OFFER_SLOTS_UNREADABLE_OR_EMPTY",function(p,o) o.theirs={} end)
expected("OFFER_MUTATION_PENDING_OR_UNKNOWN",function(p,o) o.offerMutationPending=true end)
expected("ACCEPT_STATE_CHANGED_OR_UNKNOWN",function(p,o) o.theirAccepted=true end)
expected("TRADE_OR_PARTNER_UNVERIFIED",function(p,o) o.exactPartnerBound=false end)
expected("SESSION_PARTNER_OR_CATALOG_CHANGED",function(p,o) o.sessionId="S-OTHER" end)
expected("SESSION_PARTNER_OR_CATALOG_CHANGED",function(p,o) o.jobId="J-OTHER" end)
expected("PUBLISHER_TIMESTAMP_MISSING_OR_EXPIRED",function(p,o,c) c.publisherUpdatedAtUnix=nil end)
expected("PUBLISHER_TIMESTAMP_MISSING_OR_EXPIRED",function(p,o,c) c.publisherUpdatedAtUnix=NOW-200000 end)
expected("RAW_KEY_TO_DISPLAY_ID_UNVERIFIED",function(p,o,c) c.items.receive.identityLinkEvidence="UNPROVEN" end)
expected("RECEIVED_ITEM_LOW_DEMAND",function(p,o,c)
 p.theirs[1].key="illiquid";o.theirs[1].key="illiquid"
end)
expected("RECEIVED_ITEM_UNSTABLE",function(p,o,c)
 p.theirs[1].key="falling";o.theirs[1].key="falling"
end)
expected("PROJECTED_LISTED_GAIN_BELOW_POLICY",function(p,o,c)
 c.items.receive.value=95
end)
expected("OBSERVATION_STALE_OR_CLOCK_INVALID",function(p,o) o.observedAtUnix=NOW-9 end)
expected("OFFER_SLOTS_UNREADABLE_OR_EMPTY",function(p,o)
 p.ours={{index=1,key="own",quantity=1},
  {index=2,key="own",quantity=1},{index=3,key="own",quantity=1},
  {index=4,key="own",quantity=1},{index=5,key="own",quantity=1}}
 o.ours=deepcopy(p.ours)
end)
local s,ss,sc=fixture()
s.ours={{index=1,key="stack",quantity=2}}
ss.ours=deepcopy(s.ours)
s.theirs={{index=1,key="receive",quantity=1},{index=2,key="stack",quantity=1}}
ss.theirs=deepcopy(s.theirs)
local stacked=guard.evaluate(s,ss,sc,NOW)
assert(stacked.projectedListedGain==45 and stacked.status=="RESEARCH_CANDIDATE_ONLY")
local four,observedFour,marketFour=fixture()
for _,side in ipairs({"ours","theirs"}) do
 four[side][1].quantity=4
 observedFour[side]=deepcopy(four[side])
end
assert(guard.evaluate(four,observedFour,marketFour,NOW).projectedListedGain==20)
local many,seenMany,marketMany=fixture()
many.ours={{index=1,key="own",quantity=5}}
many.theirs={{index=1,key="receive",quantity=6}}
seenMany.ours=deepcopy(many.ours)
seenMany.theirs=deepcopy(many.theirs)
local good=guard.evaluate(many,seenMany,marketMany,NOW)
assert(good.status=="RESEARCH_CANDIDATE_ONLY" and good.projectedListedGain==130)
assert(good.valueOffered==500 and good.valueRequested==630)
assert(good.authorizesTrade==false and good.authorizesAccept==false)
local twentyOne,readTwentyOne,marketTwentyOne=fixture()
twentyOne.ours={{index=1,key="stack",quantity=21}}
twentyOne.theirs={{index=1,key="receive",quantity=13}}
readTwentyOne.ours=deepcopy(twentyOne.ours)
readTwentyOne.theirs=deepcopy(twentyOne.theirs)
local stackResult=guard.evaluate(twentyOne,readTwentyOne,marketTwentyOne,NOW)
assert(stackResult.status=="RESEARCH_CANDIDATE_ONLY" and stackResult.projectedListedGain==105)
assert(stackResult.authorizesTrade==false and stackResult.authorizesAccept==false)
expected("OFFER_SLOTS_UNREADABLE_OR_EMPTY",function(p,o)
 p.ours[1].quantity=1000001
 o.ours=deepcopy(p.ours)
end)
expected("PROTECTED_GINGERSCOPE_OUTGOING",function(p,o,c)
 c.items.Gingerscope=entry(16000,5,"Stable")
 c.items.receive.value=25000
 p.ours={{index=1,key="Gingerscope",quantity=1}}
 o.ours=deepcopy(p.ours)
end)
local receiveTarget,seenTarget,marketTarget=fixture()
marketTarget.items.Gingerscope=entry(16000,5,"Stable")
receiveTarget.theirs={{index=1,key="Gingerscope",quantity=1}}
seenTarget.theirs=deepcopy(receiveTarget.theirs)
local target=guard.evaluate(receiveTarget,seenTarget,marketTarget,NOW)
assert(target.status=="RESEARCH_CANDIDATE_ONLY")
assert(target.projectedListedGain==15900)
assert(target.authorizesTrade==false and target.authorizesAccept==false)
math.randomseed(6033)
for i=1,1600 do
 local a,b,m=fixture()
 local mode=i%16
 if mode==0 then b.offerRevision=b.offerRevision+1
 elseif mode==1 then b.partnerKey="OTHER"
 elseif mode==2 then b.jobId="OTHER"
 elseif mode==3 then b.ours[1].key="illiquid"
 elseif mode==4 then b.theirs[1].quantity=b.theirs[1].quantity+1
 elseif mode==5 then a.theirs[1].quantity=a.theirs[1].quantity+1
 elseif mode==6 then b.observedAtUnix=NOW-9
 elseif mode==7 then m.publisherUpdatedAtUnix=NOW-200000
 elseif mode==8 then m.items.receive.identityLinkEvidence="UNPROVEN"
 elseif mode==9 then b.offerMutationPending=true
 elseif mode==10 then b.ourAccepted=true
 elseif mode==11 then b.exactPartnerBound=false
 elseif mode==12 then b.tradeOpen=false
 elseif mode==13 then a.ours[1].index=2
 elseif mode==14 then m.items.receive.demand=0
 elseif mode==15 then m.items.receive.value=math.random(1,94)
 end
 local x=guard.evaluate(a,b,m,NOW)
 assert(x.status=="REJECTED","mutation accepted: "..i)
 assert(x.tradeOutcome=="UNKNOWN" and x.serverCompletionProven==false)
 assert(x.authorizesTrade==false and x.authorizesAccept==false)
end
print("MM2_OFFER_GUARD_LUA_1600_MUTATIONS_AND_NAMED_CASES_PASS")
