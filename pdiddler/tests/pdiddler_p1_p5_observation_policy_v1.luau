print("MM2 P1 P5 OBSERVATION POLICY TEST")

local policy=require("../pdiddler_p1_p5_observation_policy_v1")

local pass=0
local function case(name,fn)
    fn()
    pass+=1
    print("PASS "..name)
end
local function eq(a,b,msg)
    assert(a==b,(msg or "eq").." expected="..tostring(b).." got="..tostring(a))
end

case("observation window is 30 seconds",function()
    eq(policy.ObservationSeconds,30)
end)

case("manual message normalizes exact botted",function()
    eq(policy.normalizeManualMessage("botted"),"botted")
    eq(policy.normalizeManualMessage(" BOTTED "),"botted")
    eq(policy.normalizeManualMessage("botted now"),"botted now")
end)

case("first botted message marks once and preserves remaining",function()
    local s={manualBotted=false}
    local n,changed=policy.markManual(s," BOTTED ",18.4)
    eq(changed,true)
    eq(n.manualBotted,true)
    eq(n.manualRemaining,18.4)
end)

case("repeated botted message dedupes and keeps first snapshot time",function()
    local s={manualBotted=true,manualRemaining=18.4}
    local n,changed=policy.markManual(s,"botted",8.2)
    eq(changed,false)
    eq(n.manualRemaining,18.4)
end)

case("other chat does not mark",function()
    local n,changed=policy.markManual({manualBotted=false},"bot",12)
    eq(changed,false)
    eq(n.manualBotted,false)
end)

case("character loading has highest missing-character result",function()
    eq(policy.actionLabel({character=false}),"Character Loading")
end)

case("dead beats movement",function()
    eq(policy.actionLabel({character=true,health=0,moving=true}),"Dead")
end)

case("sitting beats movement",function()
    eq(policy.actionLabel({character=true,health=100,sit=true,moving=true}),"Sitting")
end)

case("jumping and freefall map from humanoid state",function()
    eq(policy.actionLabel({character=true,health=100,humanoidState="Jumping"}),"Jumping")
    eq(policy.actionLabel({character=true,health=100,humanoidState="Freefall"}),"Freefall")
end)

case("moving then idle fallback",function()
    eq(policy.actionLabel({character=true,health=100,moving=true}),"Moving")
    eq(policy.actionLabel({character=true,health=100,moving=false}),"Idle")
end)

assert(pass==10,"expected 10 cases, got "..tostring(pass))
print("PASS P1 P5 observation policy 10/10")
