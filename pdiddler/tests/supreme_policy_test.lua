local path="pdiddler/pdiddler4_supreme_policy_v1.lua"
local P=assert(loadfile(path))()
local n=0
local function test(name,fn) fn(); n=n+1; print("PASS "..name) end
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local rows={}
local function item(id,value,qty,demand,stability)
    rows["godly:"..id]={page="godly",id=id,name=id,supremeValue=value,demand=demand or 3,stability=stability or "Stable",verified=true}
    return {page="godly",cat="Weapons",type="Knife",id="raw_"..id,checkerId=id,name=id,value=999999,qty=qty or 1}
end
local profile={get=function(page,id) return rows[page..":"..id] end,isFresh=function() return true end}
local a=item("A",100,1); local b=item("B",115); local c=item("C",114)
local function bundle(items) return P.bundleAssessment(items,"ours",profile) end
test("Supreme replaces stale scanner prices without changing raw identity",function()
    local inv=P.reprice({items={a},unmapped=0,unpriced=0,badQty=0},profile)
    eq(inv.items[1].value,100); eq(inv.items[1].id,"raw_A"); eq(a.value,999999)
end)
test("exactly +15 passes",function() assert(P.tradeDecision(bundle({a}),bundle({b})).ok) end)
test("+14 fails",function() assert(not P.tradeDecision(bundle({a}),bundle({c})).ok) end)
test("exact decimal +15 uses integer cents",function() assert(P.tradeDecision(bundle({item("decimalA",1.06)}),bundle({item("decimalB",16.06)})).ok) end)
test("one cent below profit floor fails",function() assert(not P.tradeDecision(bundle({item("decimalA",1.06)}),bundle({item("decimalB",16.05)})).ok) end)
test("raw loss has no quality upgrade exception",function() assert(not P.tradeDecision(bundle({b}),bundle({a})).ok) end)
test("empty received offer fails",function() assert(not P.tradeDecision(bundle({a}),bundle({})).ok) end)
test("empty own offer fails",function() assert(not P.tradeDecision(bundle({}),bundle({b})).ok) end)
test("unknown identity fails instead of zero",function() assert(not bundle({{page="godly",id="missing",name="A",value=1,qty=1}}).confidence) end)
test("contradictory profile name fails",function() local x=item("X",12); x.name="A"; assert(not bundle({x}).confidence) end)
for _,v in ipairs({0,-1,math.huge,-math.huge,"Priceless"}) do
    test("non-finite or unpriced value rejected "..tostring(v),function() local x=item("bad",v); assert(not bundle({x}).confidence) end)
end
test("NaN rejected",function() local x=item("bad",0/0); assert(not bundle({x}).confidence) end)
for _,qty in ipairs({0,-1,1.5,math.huge,"x2"}) do
    test("invalid inventory quantity rejected "..tostring(qty),function() local x=item("Q",12); x.qty=qty; assert(not bundle({x}).confidence) end)
end
test("stale price profile fails closed",function() local s={get=profile.get,isFresh=function() return false end}; assert(not P.bundleAssessment({a},"ours",s).confidence) end)
test("duplicate inventory rows rejected",function() local r=P.reprice({items={a,a}},profile); assert(r.badQty>0) end)
test("pets and unknown weapon types cannot enter an offer plan",function() local pet=item("pet",1); pet.cat="Pets"; pet.type="Pet"; eq(#P.buildPlans({items={pet}},bundle({b}),profile,P),0) end)
test("equal-value plans preserve stronger-demand inventory",function() local strong=item("strong",100,1,5); local weak=item("weak",100,1,1); local plans=P.buildPlans({items={strong,weak}},bundle({b}),profile,P); eq(plans[1].picks[1].checkerId,"weak") end)
test("normal quantity parser handles blank singleton and grouped counts",function() eq(P.quantity(""),1); eq(P.quantity("x1,234"),1234); eq(P.quantity("X 2"),2) end)
for _,s in ipairs({"x0","x1.5","2?","x1,2","-1","xnan"}) do
    test("malformed slot quantity rejected "..s,function() eq(P.quantity(s),nil) end)
end
test("username comparison preserves underscores and ignores DisplayName",function() assert(P.usernameEqual("Alice_B","alice_b")); assert(not P.usernameEqual("Alice_B","AliceB")); assert(not P.usernameEqual("Alice","Alice123")) end)
test("planner uses real quantities, checker identity and at most four copies",function()
    local x=item("P",30,2); local y=item("Y",40,1); local z=item("Z",115,1)
    local plans=P.buildPlans({items={x,y}},bundle({z}),profile,P)
    assert(#plans>0); eq(plans[1].rawTotal,100); eq(plans[1].units,3)
    for _,plan in ipairs(plans) do assert(plan.units<=4 and plan.rawProfit>=15); for _,pick in ipairs(plan.picks) do assert(pick.id:match("^raw_")) end end
end)
test("unknown items never enter a plan",function() local plans=P.buildPlans({items={{id="unknown",page="godly",qty=1,value=1}}},bundle({b}),profile,P); eq(#plans,0) end)
test("impossible resolved trade has no safe plans",function() local x=item("tooHigh",500); eq(#P.buildPlans({items={x}},bundle({b}),profile,P),0) end)
test("plan match requires exact counts and rejects additional unknown slots",function()
    local plan={rawTotal=100,picks={{page="godly",id="raw_A",qty=1}}}
    assert(P.planMatches(plan,{rawTotal=100,counts={["godly:raw_A"]=1},unresolved={}}))
    assert(not P.planMatches(plan,{rawTotal=100,counts={["godly:raw_A"]=1,["ineligible:foo"]=1},unresolved={}}))
end)
test("bounded planner fails closed when state budget is exhausted",function()
    local items={}; for i=1,8 do items[i]=item("budget"..i,2^i,1) end
    local plans,why=P.buildPlans({items=items},bundle({item("large",1000)}),profile,P,3)
    eq(#plans,0); eq(why,"planner-state-budget")
end)
test("negotiation waits five seconds and selects nearest better safe offer",function()
    local plans={{rawTotal=90},{rawTotal=70},{rawTotal=55}}
    local st={}; eq(P.negotiate(st,"sig",50,plans,0,false),"wait")
    eq(P.negotiate(st,"sig",50,plans,4.99,false),"wait")
    local action,plan=P.negotiate(st,"sig",50,plans,5,false); eq(action,"improve"); eq(plan.rawTotal,55)
end)
test("best safe offer gets final five seconds then declines",function()
    local st={}; eq(P.negotiate(st,"sig",90,{{rawTotal=90}},0,false),"wait")
    eq(P.negotiate(st,"sig",90,{{rawTotal=90}},5,false),"decline")
end)
test("offer mutation resets negotiation",function()
    local st={}; P.negotiate(st,"one",90,{},0,false); eq(P.negotiate(st,"two",90,{},9,false),"wait")
end)
test("partner acceptance stops negotiation changes",function() local st={}; P.negotiate(st,"s",90,{},0,false); eq(P.negotiate(st,"s",90,{},10,true),"hold") end)
test("empty timer restarts after previously nonempty offer",function()
    local st={}; eq(P.observe(st,0,0,false),"wait"); eq(P.observe(st,4,1,false),"active"); eq(P.observe(st,6,0,false),"wait"); eq(P.observe(st,17.9,0,false),"wait"); eq(P.observe(st,18,0,false),"empty-timeout")
end)
test("accepted empty declines immediately",function() eq(P.observe({},0,0,true),"accepted-empty") end)
test("overall sixty seconds is nonresetting from first offer",function() local st={}; P.observe(st,2,1,false); P.observe(st,30,1,false); eq(P.observe(st,62,1,false),"overall-timeout") end)
test("planner agrees with exhaustive four-copy search",function()
    math.randomseed(37)
    for trial=1,20 do
        local list={}; for i=1,9 do list[i]=item("random"..i,math.random(3,70),1) end
        local limit=math.random(50,140); local best=0
        local function visit(start,total,count)
            if total<=limit and total>best then best=total end
            if count==4 then return end
            for i=start,#list do local v=rows["godly:"..list[i].checkerId].supremeValue; if total+v<=limit then visit(i+1,total+v,count+1) end end
        end
        visit(1,0,0)
        local plans=P.buildPlans({items=list},bundle({item("target",limit+15)}),profile,P)
        eq(plans[1] and plans[1].rawTotal or 0,best)
    end
end)
print("PASS "..n.." Supreme policy tests")
