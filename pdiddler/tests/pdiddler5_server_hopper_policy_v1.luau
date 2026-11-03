print("MM2 PART 5 SERVER HOPPER POLICY TEST")

local policy=require("../pdiddler5_server_hopper_policy_v1")

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

local function newState()
    return { since=nil }
end

case("true exhaustion starts countdown",function()
    local s,a=policy.stepExhaustion(newState(),100,{
        queueExhausted=true,
        tradableAvailable=false,
        scannerPending=false,
        criticalBusy=false,
    })
    eq(a,"countdown")
    eq(s.since,100)
end)

case("countdown remains active before 45 seconds",function()
    local s={since=100}
    local n,a=policy.stepExhaustion(s,144.99,{
        queueExhausted=true,
        tradableAvailable=false,
        scannerPending=false,
        criticalBusy=false,
    })
    eq(a,"countdown")
    eq(n.since,100)
end)

case("exactly 45 seconds requests final scan",function()
    local s={since=100}
    local n,a=policy.stepExhaustion(s,145,{
        queueExhausted=true,
        tradableAvailable=false,
        scannerPending=false,
        criticalBusy=false,
    })
    eq(a,"final-scan")
    eq(n.since,100)
end)

case("tradable target resets exhaustion timer",function()
    local n,a=policy.stepExhaustion({since=100},130,{
        queueExhausted=false,
        tradableAvailable=true,
        scannerPending=false,
        criticalBusy=false,
    })
    eq(a,"active")
    eq(n.since,nil)
end)

case("scanner pending blocks deadline without resetting since",function()
    local n,a=policy.stepExhaustion({since=100},150,{
        queueExhausted=true,
        tradableAvailable=false,
        scannerPending=true,
        criticalBusy=false,
    })
    eq(a,"blocked")
    eq(n.since,100)
end)

case("critical active work clears exhaustion",function()
    local n,a=policy.stepExhaustion({since=100},150,{
        queueExhausted=false,
        tradableAvailable=false,
        scannerPending=false,
        criticalBusy=true,
    })
    eq(a,"active")
    eq(n.since,nil)
end)

case("11 player servers rank before 10",function()
    local servers={
        {id="tenA",playing=10,maxPlayers=12},
        {id="elevenA",playing=11,maxPlayers=12},
        {id="tenB",playing=10,maxPlayers=12},
        {id="elevenB",playing=11,maxPlayers=12},
    }
    local out=policy.rankCandidates(servers,"current",{})
    eq(#out,4)
    eq(out[1].playing,11)
    eq(out[2].playing,11)
    eq(out[3].playing,10)
    eq(out[4].playing,10)
end)

case("invalid current visited full and lower servers are excluded",function()
    local visited={visited=true}
    local servers={
        {id="current",playing=11,maxPlayers=12},
        {id="visited",playing=11,maxPlayers=12},
        {id="nine",playing=9,maxPlayers=12},
        {id="full",playing=12,maxPlayers=12},
        {id="wrongmax",playing=11,maxPlayers=20},
        {id="",playing=11,maxPlayers=12},
        {id="good",playing=10,maxPlayers=12},
    }
    local out=policy.rankCandidates(servers,"current",visited)
    eq(#out,1)
    eq(out[1].id,"good")
end)

case("duplicate job ids collapse",function()
    local out=policy.rankCandidates({
        {id="dup",playing=11,maxPlayers=12},
        {id="dup",playing=11,maxPlayers=12},
        {id="other",playing=10,maxPlayers=12},
    },"current",{})
    eq(#out,2)
end)

case("candidate ranking does not mutate input order",function()
    local servers={
        {id="ten",playing=10,maxPlayers=12},
        {id="eleven",playing=11,maxPlayers=12},
    }
    local out=policy.rankCandidates(servers,"current",{})
    eq(servers[1].id,"ten")
    eq(servers[2].id,"eleven")
    eq(out[1].id,"eleven")
end)

assert(pass==10,"expected 10 cases, got "..tostring(pass))
print("PASS Part 5 server hopper policy 10/10")
