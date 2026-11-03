-- V7 delayed sweetening policy contract. Pure Lua 5.4, no Roblox runtime required.
local P=dofile("pdiddler/pdiddler4_supreme_policy_v4_DELAYED_SWEETEN.lua")
local passed=0
local function test(name,fn)
    local ok,err=pcall(fn)
    if not ok then error("FAIL "..name..": "..tostring(err),0) end
    passed=passed+1
    print("PASS "..name)
end
local function eq(a,b) assert(a==b,tostring(a).." != "..tostring(b)) end
local function plan(total,received)
    return {ok=true,rawTotal=total,rawProfit=received-total,units=1,
        givenExitScore=4,key=tostring(total),picks={}}
end
test("9s sweetening and 5s final wait are explicit",function()
    eq(P.sweetenWaitSeconds,9)
    eq(P.finalWaitSeconds,5)
end)
test("first offer leaves approximately 3s beyond observed 6s cooldown",function()
    local s={}
    local plans={plan(70,100),plan(75,100),plan(80,100)}
    eq(P.negotiate(s,"offer",70,plans,0,false),"wait")
    eq(P.negotiate(s,"offer",70,plans,6,false),"wait")
    eq(P.negotiate(s,"offer",70,plans,8.99,false),"wait")
    local action,improved=P.negotiate(s,"offer",70,plans,9,false)
    eq(action,"improve")
    assert(improved.rawTotal>70 and improved.rawProfit>=15)
    eq(s.steps,1)
end)
test("each verified local sweeten requires a NEW 9s window",function()
    local s={}
    local plans={plan(65,100),plan(70,100),plan(75,100),plan(80,100)}
    P.negotiate(s,"offer",65,plans,0,false)
    local action,first=P.negotiate(s,"offer",65,plans,9,false)
    eq(action,"improve")
    eq(P.negotiate(s,"offer",first.rawTotal,plans,9.1,false),"wait")
    eq(P.negotiate(s,"offer",first.rawTotal,plans,18.09,false),"wait")
    local action2,second=P.negotiate(s,"offer",first.rawTotal,plans,18.1,false)
    eq(action2,"improve")
    assert(second.rawTotal>first.rawTotal and second.rawProfit>=15)
    eq(s.steps,2)
    eq(P.negotiate(s,"offer",second.rawTotal,plans,18.2,false),"final-wait")
    eq(P.negotiate(s,"offer",second.rawTotal,plans,23.19,false),"final-wait")
    eq(P.negotiate(s,"offer",second.rawTotal,plans,23.2,false),"decline")
end)
test("no feasible sweeten: 9s initial window plus full 5s final",function()
    local s={}
    local plans={plan(70,100)}
    eq(P.negotiate(s,"offer",70,plans,0,false),"wait")
    eq(P.negotiate(s,"offer",70,plans,8.99,false),"wait")
    eq(P.negotiate(s,"offer",70,plans,9,false),"final-wait")
    eq(P.negotiate(s,"offer",70,plans,13.99,false),"final-wait")
    eq(P.negotiate(s,"offer",70,plans,14,false),"decline")
end)
test("opponent offer change invalidates all older countdowns",function()
    local s={}
    P.negotiate(s,"old",70,{plan(70,100)},0,false)
    eq(P.negotiate(s,"old",70,{plan(70,100)},9,false),"final-wait")
    eq(P.negotiate(s,"new",70,{plan(70,100)},10,false),"wait")
    eq(s.steps,0)
    eq(s.finalSince,nil)
    eq(P.negotiate(s,"new",70,{plan(70,100)},18.99,false),"wait")
end)
test("partner Accepted holds changes and resets full sweeten interval",function()
    local s={}
    local plans={plan(70,100),plan(80,100)}
    P.negotiate(s,"offer",70,plans,0,false)
    eq(P.negotiate(s,"offer",70,plans,8,true),"hold")
    eq(P.negotiate(s,"offer",70,plans,9,false),"wait")
    eq(P.negotiate(s,"offer",70,plans,17.99,false),"wait")
end)
test("unexpected own-side mutation restarts 9s interval",function()
    local s={}
    P.negotiate(s,"offer",70,{plan(70,100)},0,false)
    eq(P.negotiate(s,"offer",70,{plan(70,100)},9,false),"final-wait")
    eq(P.negotiate(s,"offer",69,{plan(69,100)},11,false),"wait")
    eq(P.negotiate(s,"offer",69,{plan(69,100)},19.99,false),"wait")
end)
test("never sweeten below +15 Supreme floor",function()
    local s={}
    local plans={plan(70,100),plan(86,100)}
    P.negotiate(s,"offer",70,plans,0,false)
    eq(P.negotiate(s,"offer",70,plans,9,false),"final-wait")
    eq(s.steps,0)
end)
test("overall timeout independent from sweeten timing",function()
    local s={}
    eq(P.observe(s,0,1,false),"active")
    eq(P.observe(s,59.99,1,false),"active")
    eq(P.observe(s,60,1,false),"overall-timeout")
end)
print("RESULT "..passed.." V7 delayed-sweetening regressions passed")
