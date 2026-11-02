-- Performance regression test for Part 4 market bundle caching.
-- The production change this catches:
-- repeated evaluateSide calls with the same canonical offer signature must NOT
-- re-run full bundleAssessment work.

local Cache=require("../pdiddler4_market_bundle_cache_v1")

local calls=0
local lastItems=nil
local fakeLogic={}

function fakeLogic.bundleAssessment(items,side,profile)
    calls+=1
    lastItems=items
    local raw=0
    for _,it in ipairs(items) do
        raw+=(tonumber(it.value) or 0)*(tonumber(it.qty) or 1)
    end
    return {
        rawTotal=raw,
        protectedTotal=raw+(side=="ours" and 5 or 0),
        eligibleCopies=#items,
        confidence=true,
    }
end

local profile={get=function() return {} end}
local cache=Cache.new(profile,fakeLogic,8)

local function eval(sig)
    return {
        signature=sig,
        rawTotal=30,
        protectedTotal=30,
        resolved={
            {page="godly",id="a",name="A",rawValue=10,qty=1,ineligible=false},
            {page="ancient",id="b",name="B",rawValue=20,qty=1,ineligible=false},
            {page="ineligible",id="x",name="X",rawValue=0,qty=1,ineligible=true},
        },
    }
end

local a=eval("godly:a:1:10:1|ancient:b:1:20:1|ineligible:x:1:0:0#slots=3")
local market1,source1=cache.ensure(a,"ours")
assert(source1=="computed","first identical offer must compute market bundle")
assert(calls==1,"first ensure should call bundleAssessment exactly once")
assert(#lastItems==2,"ineligible visible slots must be excluded from market bundle")
assert(a.protectedTotal==35,"OUR protectedTotal should be attached from computed bundle")

local market2,source2=cache.ensure(a,"ours")
assert(source2=="cache","same eval object/signature must hit cache")
assert(calls==1,"same eval must not recompute market bundle")
assert(market2==market1,"cache hit should reuse immutable bundle result")

local b=eval(a.signature)
local market3,source3=cache.ensure(b,"ours")
assert(source3=="cache","new eval object with same canonical signature must hit cache")
assert(calls==1,"same signature across loop iterations must not recompute")
assert(b.protectedTotal==35,"cache hit must attach protectedTotal to fresh eval")

local _,source4=cache.ensure(eval(a.signature),"theirs")
assert(source4=="computed","OUR and THEIR protection semantics require separate cache keys")
assert(calls==2,"opposite side should compute once")

local changed=eval("godly:a:1:10:1|ancient:b:1:20:1#slots=2")
local _,source5=cache.ensure(changed,"ours")
assert(source5=="computed","changed canonical signature must compute fresh market bundle")
assert(calls==3,"changed offer should cause exactly one new market computation")

print("PASS market bundle cache avoids repeated valuation work")
