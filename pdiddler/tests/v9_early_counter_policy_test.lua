-- V9 early counteroffer tests. Pure Lua 5.4, no network or Roblox side effects.
local Early=dofile("pdiddler/pdiddler4_early_counter_policy_v1.lua")
local Market=dofile("pdiddler/pdiddler4_supreme_policy_v5_NATIVE_READY.lua")
local n=0
local function test(name,fn)
    local ok,why=pcall(fn)
    if not ok then error("FAIL "..name..": "..tostring(why),0) end
    n=n+1; print("PASS "..name)
end
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function plan(id,value,marketDemand,risk,qty,theirValue)
    qty=qty or 1
    return {ok=true,key=id,rawTotal=value,rawProfit=(theirValue or 150)-value,
        givenExitScore=marketDemand,givenRisk=risk,units=qty,
        picks={{page="godly",id=id,qty=qty}}}
end
local function live(value,demand,risk,counts)
    return {rawTotal=value,unresolved={},counts=counts or {["godly:Original"]=1},
        market={confidence=true,rawTotal=value,exitScore=demand,riskPoints=risk}}
end
local function call(s,sig,current,theirs,plans,accepted,localAccepted)
    return Early.choose(s,sig,current,theirs,plans,
        {accepted=accepted==true,localAccepted=localAccepted~=nil and localAccepted or false})
end
local theirs=live(150,4,0,{["godly:Target"]=1})
local original=live(56,2,1,{["godly:Original"]=1})
local A=plan("Original",56,2,1)
local B=plan("Attractive",85,6,0)
local C=plan("Expensive",120,6.1,0)
local D=plan("Modest",76,4.3,0)
test("+94 weak current changes to strong +65, not +30",function()
    local a,p,m=call({},"sig",original,theirs,{A,B,C,D})
    eq(a,"counter");eq(p.rawProfit,65);eq(p.key,"Attractive");eq(m.concession,29)
    eq(m.budget,31.6); assert(m.demandGain>=4)
end)
test("market appeal outranks largest theoretical profit",function()
    local action,p=call({},"sig",original,theirs,{A,D,B})
    eq(action,"counter");eq(p.key,"Attractive")
end)
test("same appeal favors higher remaining profit",function()
    local a=plan("SameDemandMore",75,6,0)
    local b=plan("SameDemandLess",85,6.05,0)
    local action,p=call({},"sig",original,theirs,{b,a})
    eq(action,"counter");eq(p.key,"SameDemandMore")
end)
test("no appealing improvement does not donate value",function()
    local a=plan("NoDemandUpgrade",85,2.2,1)
    local action=call({},"sig",original,theirs,{a,A})
    eq(action,"keep")
end)
test("slight extra demand is insufficient to make expensive concession",function()
    local a=plan("TinyAppeal",85,2.99,1)
    local action=call({},"sig",original,theirs,{a})
    eq(action,"keep")
end)
test("risk degradation blocks apparent demand upgrade",function()
    local old=live(56,2,0)
    local a=plan("Wild",85,6,1)
    eq(call({},"sig",old,theirs,{a}),"keep")
end)
test("major stability improvement can justify early response",function()
    local a=plan("StableAlternative",80,2,0)
    local action,p=call({},"sig",original,theirs,{a})
    eq(action,"counter");eq(p.key,"StableAlternative")
end)
test("one deliberate early decision per unchanged opponent offer",function()
    local s={}
    eq(call(s,"sig",original,theirs,{B}),"counter")
    eq(call(s,"sig",original,theirs,{D}),"keep")
    eq(s.generation,1)
end)
test("stable opponent offer change resets one-decision budget",function()
    local s={}
    eq(call(s,"old",original,theirs,{B}),"counter")
    local action,p=call(s,"new",original,theirs,{D})
    eq(action,"counter");eq(p.key,"Modest");eq(s.generation,2)
end)
test("an opponent Accept freezes early counter without consuming it",function()
    local s={}
    eq(call(s,"sig",original,theirs,{B},true,false),"hold")
    eq(s.spent,false)
    eq(call(s,"sig",original,theirs,{B},false,false),"counter")
end)
test("unknown local accepted state freezes mutation",function()
    local s={}
    local action=Early.choose(s,"sig",original,theirs,{B},{accepted=false,localAccepted=nil})
    eq(action,"hold");eq(s.spent,false)
end)
test("unresolved trade items never trigger a replacement",function()
    local current=live(56,2,1)
    current.unresolved={{reason="Chroma ambiguous"}}
    eq(call({},"sig",current,theirs,{B}),"hold")
end)
test("market bundle confidence is mandatory",function()
    local current=live(56,2,1);current.market.confidence=false
    eq(call({},"sig",current,theirs,{B}),"hold")
end)
test("mispriced live totals and phantom margin are rejected",function()
    local cur=live(56,2,1);cur.market.rawTotal=55
    eq(call({},"sig",cur,theirs,{B}),"hold")
    local bad=live(145,2,1)
    eq(call({},"sig",bad,theirs,{B}),"hold")
end)
test("missing/opponent signature cannot consume early budget",function()
    local s={}
    eq(call(s,"",original,theirs,{B}),"hold")
    eq(s.spent,nil)
end)
test("invalid requested quantities and nonweapon pages never counter",function()
    local bad=plan("BadQuantity",85,6,0,5)
    local pet=plan("Pet",85,6,0)
    pet.picks[1].page="pet"
    eq(call({},"sig",original,theirs,{bad,pet}),"keep")
end)
test("multiple verified copies up to four are supported",function()
    local stack=plan("Dupes",84,6,0,4)
    local action,p=call({},"sig",original,theirs,{stack})
    eq(action,"counter");eq(p.units,4)
end)
test("invented profit and +14 offers cannot enter policy",function()
    local phantom=plan("FalseProfit",85,6,0)
    phantom.rawProfit=70
    local near=plan("Insufficient",136,6,0)
    eq(call({},"sig",original,theirs,{phantom,near}),"keep")
end)
test("already-offered exact items are not an early counter",function()
    eq(call({},"sig",original,theirs,{A}),"keep")
end)
test("no current inventory proof or missing plans is a HOLD",function()
    local a=live(56,2,1);a.counts=nil
    eq(call({},"sig",a,theirs,{B}),"hold")
    eq(call({},"sig",original,theirs,nil),"hold")
end)
test("at +15, there is no budget for a bigger giveaway",function()
    local cur=live(135,2,1)
    local offer=plan("SomethingElse",135,6,0)
    -- Market appeal improvement with NO additional concession may be valid.
    eq(call({},"sig",cur,theirs,{offer}),"counter")
    local more=plan("MoreExpensive",136,6,0)
    eq(call({},"sig",cur,theirs,{more}),"keep")
end)
test("actual Supreme buildPlans fixture selects high-demand +65 from +94",function()
    local rows={}
    local function item(id,value,demand,stability)
        rows["godly:"..id]={page="godly",id=id,name=id,
            verified=true,supremeValue=value,demand=demand,stability=stability}
        return {page="godly",id="raw_"..id,checkerId=id,name=id,cat="Weapons",
            type="Knife",qty=1,value=value}
    end
    local ourA=item("Original",56,2,"Fluctuating")
    local ourB=item("Attractive",85,6,"Stable")
    local ourC=item("Expensive",120,6.1,"Stable")
    local target=item("Target",150,4,"Stable")
    local profile={get=function(page,id) return rows[page..":"..id] end,isFresh=function() return true end}
    local inv={items={ourA,ourB,ourC},unmapped=0,unpriced=0,badQty=0}
    local tc=Market.bundleAssessment({target},"theirs",profile)
    local plans,why=Market.buildPlans(inv,tc,profile,Market)
    assert(plans and #plans>=3,why)
    local own=Market.bundleAssessment({ourA},"ours",profile)
    local cur={rawTotal=56,unresolved={},counts={["godly:raw_Original"]=1},market=own}
    local their={rawTotal=150,unresolved={},market=tc}
    local action,candidate=call({},"target-signature",cur,their,plans)
    eq(action,"counter");eq(candidate.rawTotal,85);eq(candidate.rawProfit,65)
    assert(candidate.picks[1].id=="raw_Attractive")
end)
print("RESULT "..n.." V9 early counteroffer tests passed")
