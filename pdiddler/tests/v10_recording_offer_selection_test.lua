-- V10 regression against Nov 3 live iPad 101-point trade.
local Market=dofile("pdiddler/pdiddler4_supreme_policy_v6_BOUNDED_CONCESSION.lua")
local Early=dofile("pdiddler/pdiddler4_early_counter_policy_v2_BOUNDED_VALUE.lua")
local passed=0
local function test(name,fn)
    local ok,err=pcall(fn)
    if not ok then error("FAIL "..name..": "..tostring(err),0) end
    passed=passed+1;print("PASS "..name)
end
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function item(id,page,value,cat,typ)
    return {id=id,checkerId=id,page=page,name=id,value=value,qty=1,
        cat=cat or "Weapons",type=typ or "Knife"}
end
local rows={}
local function put(id,page,value,demand,stability,typ)
    local it=item(id,page,value,"Weapons",typ)
    rows[page..":"..id]={id=id,page=page,name=id,supremeValue=value,
        verified=true,demand=demand or 1,stability=stability or "Stable"}
    return it
end
-- Their unchanged +101 from the recording:
local theirItems={
    put("Chroma Swirly Gun","chroma",35,1,"Stable","Gun"),
    put("Darkbringer","godly",33,1,"Stable","Gun"),
    put("Iceblaster","godly",33,1,"Stable","Gun"),
}
-- Our actually observed / plausible inventory: 7,13,18,22,23,40,65.
local ownItems={
    put("Boneblade","godly",7),
    put("Jinglegun","godly",13,1,"Stable"),
    put("Plasmabeam","godly",18),
    put("Laser","godly",22,1,"Stable","Gun"),
    put("Green Luger","godly",23,1,"Stable","Gun"),
    put("Chroma Laser","chroma",40,1,"Stable","Gun"),
    put("Ornament","godly",65),
}
-- Fix test item numeric demand to use the exact categorical Supreme values.
rows["godly:Jinglegun"].demand=1
rows["godly:Laser"].demand=1
local profile={get=function(page,id) return rows[page..":"..id] end,
    isFresh=function() return true end}
local inv={items=ownItems,unmapped=0,unpriced=0,badQty=0}
local theirMarket=Market.bundleAssessment(theirItems,"theirs",profile)
local plans,why=Market.buildPlans(inv,theirMarket,profile,Market)
assert(plans and #plans>12,why)
local boneMarket=Market.bundleAssessment({ownItems[1]},"ours",profile)
local ourState={rawTotal=7,unresolved={},counts={["godly:Boneblade"]=1},market=boneMarket}
local theirState={rawTotal=101,unresolved={},market=theirMarket}
test("recording opponent offer is 35+33+33=101 and current profit +94",function()
    eq(theirMarket.rawTotal,101);eq(boneMarket.rawTotal,7)
    eq(theirMarket.exitScore,1);eq(boneMarket.exitScore,1)
    eq(theirMarket.riskPoints,0);eq(boneMarket.riskPoints,0)
    eq(theirMarket.rawTotal-boneMarket.rawTotal,94)
end)
test("V10 early counter chooses a bounded +65-ish offer despite demand=1 tie",function()
    local a,p,m=Early.choose({},"theirs101",ourState,theirState,plans,{accepted=false,localAccepted=false})
    eq(a,"counter")
    assert(p.rawTotal>7 and p.rawTotal<=38.6,p.rawTotal)
    assert(p.rawProfit>=62.4 and p.rawProfit<94,p.rawProfit)
    eq(m.reason,"bounded-value-lift")
    -- The actual inventory also permits Boneblade(7)+Jinglegun(13)+
    -- Plasmabeam(18)=38. This stays inside the 31.6-value max concession
    -- from current 7 while retaining +63, and is preferable to +23.
    eq(p.rawTotal,38);eq(p.rawProfit,63)
end)
test("V10 early cannot fall from +94 to +23 (Ornament+Jinglegun)",function()
    local a,p=Early.choose({},"theirs101",ourState,theirState,plans,{accepted=false,localAccepted=false})
    eq(a,"counter");assert(p.rawTotal<78 and p.rawProfit>23)
end)
test("same opponent offer gets only one early counter",function()
    local state={}
    eq(Early.choose(state,"same",ourState,theirState,plans,{accepted=false,localAccepted=false}),"counter")
    eq(Early.choose(state,"same",ourState,theirState,plans,{accepted=false,localAccepted=false}),"keep")
end)
test("opponent accepted blocks early reoffer",function()
    local state={}
    eq(Early.choose(state,"same",ourState,theirState,plans,{accepted=true,localAccepted=false}),"hold")
    eq(state.spent,false)
end)
test("late +94 concession never exceeds 25% headroom or 20 value",function()
    local p,why,details=Market.selectLateConcession(plans,7,1,101)
    assert(p,why)
    assert(p.rawTotal>7 and p.rawTotal<=26.75)
    assert(p.rawProfit>=74.25 and p.rawProfit>=15)
    assert(details.increment<=19.75)
end)
test("late cannot choose raw offer 78 from raw 7",function()
    local p=Market.selectLateConcession(plans,7,1,101)
    assert(p and p.rawTotal<78,p and p.rawTotal)
end)
test("late from +65 can only sacrifice up to 12.5 (raw 36 -> <=48.5)",function()
    local p,why,details=Market.selectLateConcession(plans,36,2,101)
    assert(p,why)
    assert(p.rawTotal>36 and p.rawTotal<=48.5)
    assert(p.rawProfit>=52.5)
    assert(details.increment<=12.5)
end)
test("later from +26 / 40 on their revised 66 protects small increment",function()
    local p={ok=true,rawTotal=45,rawProfit=21,units=2,givenExitScore=1,givenRisk=0,key="Laser+Green Luger"}
    local chosen,why=Market.selectLateConcession({p},40,1,66)
    -- Headroom 26-15=11; 25%=2.75 < min meaningful 3.2.
    eq(chosen,nil);eq(why,"no-meaningful-safe-increment")
end)
test("late cannot accept a bogus raw profit or below +15",function()
    local p,why=Market.selectLateConcession({
        {ok=true,rawTotal=23,rawProfit=500,units=1,givenExitScore=1,givenRisk=0,key="phantom"},
        {ok=true,rawTotal=87,rawProfit=14,units=1,givenExitScore=1,givenRisk=0,key="unsafe"},
    },7,1,101)
    eq(p,nil);eq(why,"no-meaningful-capped-plan")
end)
test("late wait preserves 9s and only changes after real readiness",function()
    local s={}
    eq(Market.negotiate(s,"101",7,plans,0,false,false,101),"accept-not-ready")
    eq(Market.negotiate(s,"101",7,plans,9,false,false,101),"accept-not-ready")
    local action,p=Market.negotiate(s,"101",7,plans,9.1,false,true,101)
    eq(action,"improve");assert(p.rawProfit>=74.25)
end)
test("first-response planner never immediately selects +15-floor exchange",function()
    local p,why=Market.selectInitialOffer(plans,101)
    assert(p,why)
    assert(p.rawTotal<=60.6 and p.rawProfit>=40.4)
end)
test("first-response fallback retains highest margin when no capped item fits",function()
    local p,why=Market.selectInitialOffer({
        {ok=true,rawTotal=83,rawProfit=18,givenExitScore=1,givenRisk=0,units=2,key="83"}
    },101)
    assert(p,why);eq(p.rawTotal,83);eq(why,"initial-fallback-smallest-safe")
end)
test("final 5s window and two-sweeten cap preserved after full readiness",function()
    local s={signature="sig",total=23,steps=2,since=0}
    eq(Market.negotiate(s,"sig",23,plans,8.9,false,true,101),"wait")
    eq(Market.negotiate(s,"sig",23,plans,9,false,true,101),"final-wait")
    eq(Market.negotiate(s,"sig",23,plans,13.9,false,true,101),"final-wait")
    eq(Market.negotiate(s,"sig",23,plans,14,false,true,101),"decline")
end)
print("RESULT "..passed.." V10 bounded live-recording regressions passed")
