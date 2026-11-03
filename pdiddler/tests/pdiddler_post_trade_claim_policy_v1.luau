print("MM2 POST-TRADE CLAIM POLICY TEST")

local policy=require("../pdiddler_post_trade_claim_policy_v1")

local pass=0
local function case(name,fn)
    fn()
    pass+=1
    print("PASS "..name)
end
local function eq(a,b,msg)
    assert(a==b,(msg or "eq").." expected="..tostring(b).." got="..tostring(a))
end
local function ok(v,msg) assert(v,msg or "assertion failed") end

case("parse exact claim sequence",function()
    local cur,total=policy.parse("Claim (1/4)")
    eq(cur,1,"current")
    eq(total,4,"total")
end)

case("parse tolerates case and spacing",function()
    local cur,total=policy.parse("  CLAIM ( 3 / 4 ) ")
    eq(cur,3)
    eq(total,4)
end)

case("reject unrelated claim text",function()
    eq(policy.parse("Claim"),nil)
    eq(policy.parse("Daily Claim"),nil)
    eq(policy.parse("Claim reward"),nil)
end)

case("reject impossible indices",function()
    eq(policy.parse("Claim (0/4)"),nil)
    eq(policy.parse("Claim (5/4)"),nil)
    eq(policy.parse("Claim (1/0)"),nil)
end)

case("first valid popup requests one tap",function()
    local s=policy.newSession(10)
    local action,meta=policy.observe(s,"Claim (1/4)",10.1)
    eq(action,"tap")
    eq(meta.current,1)
    eq(meta.total,4)
    eq(meta.attempt,1)
end)

case("same popup is not spam tapped before retry delay",function()
    local s=policy.newSession(20)
    local action=policy.observe(s,"Claim (1/4)",20.1)
    eq(action,"tap")
    policy.noteTap(s,"Claim (1/4)",20.1,true)

    action=policy.observe(s,"Claim (1/4)",20.3)
    eq(action,"wait")
end)

case("same stuck popup gets bounded retry",function()
    local s=policy.newSession(30)
    eq(policy.observe(s,"Claim (1/4)",30.0),"tap")
    policy.noteTap(s,"Claim (1/4)",30.0,true)

    local action,meta=policy.observe(
        s,
        "Claim (1/4)",
        30.0+policy.RetryDelay
    )
    eq(action,"tap")
    eq(meta.attempt,2)
end)

case("same stuck popup stops after max attempts",function()
    local s=policy.newSession(40)
    for attempt=1,policy.MaxAttemptsPerStep do
        local now=40+(attempt-1)*policy.RetryDelay
        local action=policy.observe(s,"Claim (1/4)",now)
        eq(action,"tap","attempt "..attempt)
        policy.noteTap(s,"Claim (1/4)",now,true)
    end

    local action=policy.observe(
        s,
        "Claim (1/4)",
        40+policy.MaxAttemptsPerStep*policy.RetryDelay
    )
    eq(action,"stuck")
end)

case("next claim index resets retry budget",function()
    local s=policy.newSession(50)
    eq(policy.observe(s,"Claim (1/4)",50.0),"tap")
    policy.noteTap(s,"Claim (1/4)",50.0,true)

    local action,meta=policy.observe(s,"Claim (2/4)",50.2)
    eq(action,"tap")
    eq(meta.current,2)
    eq(meta.attempt,1)
end)

case("temporary disappearance does not instantly complete",function()
    local s=policy.newSession(60)
    eq(policy.observe(s,"Claim (1/4)",60.0),"tap")
    policy.noteTap(s,"Claim (1/4)",60.0,true)

    eq(policy.observe(s,nil,60.1),"wait")
end)

case("sequence completes only after popup remains absent",function()
    local s=policy.newSession(70)
    eq(policy.observe(s,"Claim (4/4)",70.0),"tap")
    policy.noteTap(s,"Claim (4/4)",70.0,true)

    local action=policy.observe(
        s,
        nil,
        70.0+policy.AbsentCompleteDelay+0.01
    )
    eq(action,"complete")
end)

case("no popup before any claim never reports complete",function()
    local s=policy.newSession(80)
    eq(policy.observe(s,nil,90),"wait")
    eq(s.seenAny,false)
end)

case("failed physical tap does not consume retry attempt",function()
    local s=policy.newSession(100)
    eq(policy.observe(s,"Claim (1/3)",100),"tap")
    policy.noteTap(s,"Claim (1/3)",100,false)

    local action,meta=policy.observe(s,"Claim (1/3)",100.01)
    eq(action,"tap")
    eq(meta.attempt,1)
end)

assert(pass==13,"expected 13 cases, got "..tostring(pass))
print("PASS post-trade claim policy 13/13")
