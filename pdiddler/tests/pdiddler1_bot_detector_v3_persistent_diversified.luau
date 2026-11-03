print("MM2 PART 1 V3 PERSISTENT DIVERSIFIED TEST")

local mod=require("../pdiddler1_BOT_DETECTOR_v3_PERSISTENT_DIVERSIFIED")
local d=mod.decision

local pass=0
local function case(name,fn)
    fn()
    pass+=1
    print("PASS "..name)
end
local function eq(a,b,msg)
    assert(a==b,(msg or "eq").." expected="..tostring(b).." got="..tostring(a))
end

case("clean below-threshold lobby does not require confirmation",function()
    eq(d.needsConfirm({bot=false,possibleDiversified=false}),false)
end)

case("threshold bot still requires confirmation",function()
    eq(d.needsConfirm({bot=true,possibleDiversified=false}),true)
end)

case("possible diversified farm now requires confirmation",function()
    eq(d.needsConfirm({bot=false,possibleDiversified=true}),true)
end)

case("persistent diversified pattern rejects even below 60",function()
    local reject,why=d.rejectAfterConfirm(
        {bot=false,possibleDiversified=true},
        {bot=false,possibleDiversified=true}
    )
    eq(reject,true)
    eq(why,"persistent-diversified")
end)

case("borderline diversified signal can clear on second scan",function()
    local reject,why=d.rejectAfterConfirm(
        {bot=false,possibleDiversified=true},
        {bot=false,possibleDiversified=false}
    )
    eq(reject,false)
    eq(why,"cleared")
end)

case("normal threshold-confirmed bot still rejects",function()
    local reject,why=d.rejectAfterConfirm(
        {bot=true,possibleDiversified=false},
        {bot=true,possibleDiversified=false}
    )
    eq(reject,true)
    eq(why,"threshold")
end)

case("first suspicious scan does not poison a clean confirmation",function()
    local reject,why=d.rejectAfterConfirm(
        {bot=true,possibleDiversified=false},
        {bot=false,possibleDiversified=false}
    )
    eq(reject,false)
    eq(why,"cleared")
end)

assert(pass==7,"expected 7 cases, got "..tostring(pass))
print("PASS Part 1 v3 persistent diversified 7/7")
