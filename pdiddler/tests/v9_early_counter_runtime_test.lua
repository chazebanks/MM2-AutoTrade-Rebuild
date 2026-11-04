-- V9 integrated production P4 runtime, using original V5 Roblox fixture.
-- The native Accept gate intentionally never becomes ready here: any prompt
-- +94 -> +65 mutation must therefore come from the EARLY stage, not sweetening.
local passed=0
local function test(name,fn)
    local ok,err=pcall(fn)
    if not ok then error("FAIL "..name..": "..tostring(err),0) end
    passed=passed+1
    print("PASS "..name)
end
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function scenario()
    local f=fixture()
    local A=f:item("A",56)
    local B=f:item("B",85)
    local C=f:item("C",120)
    f.own.items={A,B,C}
    f.rows["godly:A"].demand=2
    f.rows["godly:A"].stability="Fluctuating"
    f.rows["godly:B"].demand=6
    f.rows["godly:B"].stability="Stable"
    f.rows["godly:C"].demand=6.1
    f.rows["godly:C"].stability="Stable"
    f.partnerInv.items={f:item("T",150),f:item("U",100)}
    f.rows["godly:T"].demand=4
    -- Reachable opener is normally demand-biased. Force a weak but legal
    -- opening quote here to isolate early response to their revealed items.
    f.market={};for k,v in pairs(POLICY) do f.market[k]=v end
    f.market.selectOpener=function() return A,"fixture-weak-opening-offer" end
    f.policy=f.market
    return f
end
test("real P4 opens weak quote then promptly counters +94 to +65 during countdown",function()
    local f=scenario()
    f:start()
    f:advance(3.4)
    eq(f:total(),56)
    f:setTheir({f.partnerInv.items[1]})
    f:advance(8)
    eq(f:total(),85)
    eq(f.offers,2)
    eq(f.accepts,0)
end)
test("early adjustment happens before native readiness is ever true",function()
    local f=scenario()
    f:start()
    f:advance(3.4)
    f:setTheir({f.partnerInv.items[1]})
    f:advance(8)
    eq(f:total(),85)
    assert((f.nativeChecks or 0)>0,"native gate was not observed after early mutation")
    eq(f.nativeReadyEver,false)
end)
test("same opponent offer cannot repeatedly trigger early concessions",function()
    local f=scenario()
    f:start()
    f:advance(3.4)
    f:setTheir({f.partnerInv.items[1]})
    f:advance(9)
    eq(f:total(),85)
    local old=f.offers
    f:advance(16)
    eq(f.offers,old)
    eq(f:total(),85)
end)
test("no better market appeal means current safe quote stays unchanged",function()
    local f=scenario()
    f.rows["godly:B"].demand=2
    f.rows["godly:B"].stability="Fluctuating"
    f.rows["godly:C"].demand=2
    f.rows["godly:C"].stability="Fluctuating"
    f:start()
    f:advance(3.4)
    f:setTheir({f.partnerInv.items[1]})
    f:advance(9)
    eq(f:total(),56)
    eq(f.offers,1)
end)
test("opponent already Accepted freezes early quote adjustment",function()
    local f=scenario()
    f:start()
    f:advance(3.4)
    f:setTheir({f.partnerInv.items[1]})
    f.accepted.Visible=true
    f:advance(8)
    eq(f:total(),56)
    eq(f.accepts,0)
end)
test("missing market confidence cannot authorize an early trade mutation",function()
    local f=scenario()
    f:start()
    f:advance(3.4)
    f.rows["godly:A"].verified=false
    f:setTheir({f.partnerInv.items[1]})
    f:advance(8)
    eq(f:total(),56)
end)
test("policy exception holds offer with no repeated mutation",function()
    local f=scenario()
    f.early={choose=function() error("synthetic policy fault") end}
    f:start()
    f:advance(3.4)
    f:setTheir({f.partnerInv.items[1]})
    f:advance(8)
    eq(f:total(),56)
    eq(f.offers,1)
    eq(f.accepts,0)
end)
print("RESULT "..passed.." V9 fully integrated Part4 Roblox-fixture tests passed")
