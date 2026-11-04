-- Pure V15 negotiation regressions. No native trading actions.
local P=dofile('pdiddler/pdiddler4_early_counter_policy_v5_OPPONENT_ADDED.lua')
local passed=0
local function test(label,fn)
    fn()
    passed=passed+1
    print("PASS V15 "..label)
end
local function offer(total,key)
    return {rawTotal=total,unresolved={},counts={["godly:old"]=1},
        market={confidence=true,rawTotal=total,exitScore=1,riskPoints=0},signature=key or tostring(total)}
end
local function theirs(total)
    return {rawTotal=total,unresolved={},
        market={confidence=true,rawTotal=total,exitScore=1,riskPoints=0}}
end
local function candidate(value,received,key)
    return {ok=true,key=key or tostring(value),rawTotal=value,
        rawProfit=received-value,givenExitScore=1,givenRisk=0,units=1,
        picks={{page="godly",id=key or ("test"..tostring(value)),qty=1,
            cat="Weapons",type="Knife",value=value,demand=1,stability="Stable"}}}
end
local function decide(state,signature,anchor,our,their,values,opts)
    local plans={}
    for _,v in ipairs(values or {}) do plans[#plans+1]=candidate(v,their) end
    opts=opts or {}
    -- Lua's `a and false or b` yields b, not false; preserve explicit
    -- native unaccepted state rather than accidentally coercing it to nil.
    local localAccepted=opts.localAccepted
    if localAccepted==nil then localAccepted=false end
    return P.choose(state,signature,offer(our),theirs(their),plans,{
        anchorTotal=anchor,earlyRemaining=opts.allowance or 40,
        accepted=opts.accepted or false,localAccepted=localAccepted})
end
test("no concession on unchanged opponent offer",function()
    local action,_,meta=decide({},"A",200,100,200,{102,105})
    assert(action=="keep" and meta.reason=="net-addition-below-threshold")
end)
test("first five is below the ten-value minimum",function()
    local s={};local action=decide(s,"A",200,100,205,{102,105})
    assert(action=="keep")
    local nextAction,plan=decide(s,"B",200,100,210,{105})
    assert(nextAction=="counter" and plan.rawTotal==105)
end)
test("same-value swap never authorizes more",function()
    local s={}
    assert(decide(s,"variantA",200,100,200,{105})=="keep")
    assert(decide(s,"variantB",200,100,200,{105})=="keep")
end)
test("removing value never authorizes more",function()
    assert(decide({},"R",200,100,190,{101})=="keep")
end)
test("a verified reward resets net-addition baseline",function()
    local a,plan=decide({},"A",200,100,210,{105})
    assert(a=="counter" and plan.rawTotal==105)
    assert(decide({},"B",210,105,215,{108})=="keep")
end)
test("one decision per exact stable generation",function()
    local s={}
    assert(decide(s,"A",200,100,215,{105})=="counter")
    assert(decide(s,"A",200,100,215,{106})=="keep")
end)
test("the half-of-new-value cap rejects excessive concession",function()
    local a,plan=decide({},"A",200,100,215,{108,107})
    assert(a=="counter" and plan.rawTotal==107)
end)
test("the 5 percent branch scales for expensive trades",function()
    assert(decide({},"A",1000,500,1049,{520})=="keep")
    local action,plan=decide({},"B",1000,500,1050,{510})
    assert(action=="counter" and plan.rawTotal==510)
end)
test("unknown or accepted local state freezes all changes",function()
    local plans={candidate(110,250)}
    local unknown=P.choose({},"A",offer(100),theirs(250),plans,
        {anchorTotal=200,earlyRemaining=40,accepted=false,localAccepted=nil})
    assert(unknown=="hold")
    local accepted=decide({},"B",200,100,250,{110},{localAccepted=true})
    assert(accepted=="hold")
end)
test("missing verified anchor fails closed",function()
    local a,_,meta=decide({},"A",nil,100,250,{110})
    assert(a=="hold" and meta.reason=="verified-opponent-anchor-required")
end)
test("zero budget does not spend",function()
    local a=decide({},"A",200,100,250,{110},{allowance=0})
    assert(a=="keep")
end)
test("price floor remains a hard requirement",function()
    local a=decide({},"A",200,100,215,{205})
    assert(a=="keep")
end)
print("TOTAL V15 "..passed.." pure opponent-addition cases")
