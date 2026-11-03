local P=dofile("pdiddler/pdiddler4_supreme_policy_v2_ADAPTIVE.lua")
local rows={}; local profile={get=function(page,id) return rows[page..":"..id] end,isFresh=function() return true end}
local function item(id,value,demand,stability,qty)
    rows["godly:"..id]={page="godly",id=id,name=id,supremeValue=value,demand=demand or 3,stability=stability or "Stable",verified=true}
    return {page="godly",id="raw_"..id,checkerId=id,name=id,value=value,cat="Weapons",type="Knife",qty=qty or 1}
end
local function inv(items) return {items=items,unmapped=0,unpriced=0,badQty=0} end
local passed,failed=0,0
local function test(name,fn) local ok,err=pcall(fn); if ok then passed=passed+1; print("PASS "..name) else failed=failed+1; print("FAIL "..name..": "..tostring(err)) end end
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
test("opener rejects highest unreachable and prefers reachable demand",function()
    local huge=item("Huge",1000,10); local good=item("Good",70,5); local small=item("Small",30,2)
    local chosen=P.selectOpener(inv({huge,good,small}),inv({item("Partner",100)}),profile)
    eq(chosen.id,good.id)
end)
test("opener does not guess incomplete partner capacity",function() local theirs=inv({item("P",100)}); theirs.unmapped=1; eq(P.selectOpener(inv({item("A",70)}),theirs,profile),nil) end)
test("no feasible opener is explicit",function() eq(P.selectOpener(inv({item("A",1000)}),inv({item("P",30)}),profile),nil) end)
test("Priceless cannot be opener",function() local x=item("Priceless",1); rows["godly:Priceless"].supremeValue=nil; eq(P.selectOpener(inv({x}),inv({item("P",100)}),profile),nil) end)
test("raw canonical ID contradiction stays unpriced",function() local x=item("X",70); x.checkerId="other"; eq(P.selectOpener(inv({x}),inv({item("P",100)}),profile),nil) end)
test("ranking retains initial negotiation headroom instead of max giveaway",function()
    local theirs=P.bundleAssessment({item("T",100)},"theirs",profile)
    local plans=P.buildPlans(inv({item("A",70),item("B",10)}),theirs,profile,P)
    eq(plans[1].rawTotal,70); assert(plans[1].rawTotal<80)
end)
test("same-price DP retains appealing alternatives rather than only weakest demand",function()
    local theirs=P.bundleAssessment({item("T",100)},"theirs",profile)
    local plans=P.buildPlans(inv({item("Weak",70,1),item("Appealing",70,6)}),theirs,profile,P)
    eq(plans[1].picks[1].checkerId,"Appealing")
end)
test("plus 14.99 blocked, plus 15.00 allowed",function()
    local ours=P.bundleAssessment({item("O",1.06)},"ours",profile)
    assert(not P.tradeDecision(ours,P.bundleAssessment({item("Bad",16.05)},"theirs",profile)).ok)
    assert(P.tradeDecision(ours,P.bundleAssessment({item("Good",16.06)},"theirs",profile)).ok)
end)
test("many safe plans permit at most two sweetens then final five seconds",function()
    local plans={}; for n=10,90,10 do plans[#plans+1]={ok=true,rawTotal=n,rawProfit=100-n,units=1,givenExitScore=3,key=tostring(n)} end
    local state={}; eq(P.negotiate(state,"s",10,plans,0,false),"wait")
    local action,one=P.negotiate(state,"s",10,plans,5,false); eq(action,"improve")
    P.negotiate(state,"s",one.rawTotal,plans,5.1,false)
    local act,two=P.negotiate(state,"s",one.rawTotal,plans,10.1,false); eq(act,"improve")
    eq(P.negotiate(state,"s",two.rawTotal,plans,10.2,false),"wait")
    eq(P.negotiate(state,"s",two.rawTotal,plans,15.2,false),"decline"); eq(state.steps,2)
end)
test("changed opponent signature resets steps",function() local state={signature="old",steps=2,total=10,since=0}; eq(P.negotiate(state,"new",10,{},20,false),"wait"); eq(state.steps,0) end)
test("manual Accepted freezes negotiation",function() local state={}; P.negotiate(state,"s",10,{},0,false); eq(P.negotiate(state,"s",10,{},8,true),"hold"); eq(state.steps,0) end)
test("four copies and actual owned quantity remain conservative",function() local a=item("A",10,3,"Stable",20); local plans=P.buildPlans(inv({a}),P.bundleAssessment({item("T",100)},"theirs",profile),profile,P); for _,p in ipairs(plans) do assert(p.units<=4 and p.picks[1].qty<=4) end end)
test("expiry blocks opener selection",function() local expired={get=profile.get,isFresh=function() return false end}; eq(P.selectOpener(inv({item("A",10)}),inv({item("T",100)}),expired),nil) end)
print("RESULT "..passed.." passed, "..failed.." failed")
assert(failed==0)
