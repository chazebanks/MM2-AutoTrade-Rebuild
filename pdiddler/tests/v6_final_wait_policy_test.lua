-- Regression contract for the V6 final-window negotiation policy.
-- This does not model native MM2 buttons and must never claim to verify them.
local P=dofile("pdiddler/pdiddler4_supreme_policy_v3_FINAL_WAIT.lua")
local passed=0
local function test(name,fn)
    local ok,err=pcall(fn)
    if not ok then error("FAIL "..name.." | "..tostring(err),0) end
    passed=passed+1
    print("PASS "..name)
end
local function eq(a,b) assert(a==b,tostring(a).." != "..tostring(b)) end
local function plan(total,received)
    return {ok=true,rawTotal=total,rawProfit=received-total,units=1,
        givenExitScore=4,key=tostring(total),picks={}}
end
test("no safe improvement gets a FULL separate final 5s window",function()
    local s={}
    local plans={plan(70,100)}
    eq(P.negotiate(s,"sig",70,plans,0,false),"wait")
    eq(P.negotiate(s,"sig",70,plans,4.9,false),"wait")
    eq(P.negotiate(s,"sig",70,plans,5,false),"final-wait")
    eq(P.negotiate(s,"sig",70,plans,9.99,false),"final-wait")
    eq(P.negotiate(s,"sig",70,plans,10,false),"decline")
    eq(s.steps,0)
end)
test("second sweeten yields one last 5s decision window",function()
    local s={signature="s",total=80,steps=2,since=6}
    eq(P.negotiate(s,"s",80,{},6,false),"final-wait")
    eq(P.negotiate(s,"s",80,{},10.99,false),"final-wait")
    eq(P.negotiate(s,"s",80,{},11,false),"decline")
    eq(s.steps,2)
end)
test("partner change invalidates old final countdown and sweeten count",function()
    local s={signature="old",total=70,steps=2,since=0,finalSince=0}
    eq(P.negotiate(s,"new",70,{plan(70,100)},10,false),"wait")
    eq(s.steps,0)
    eq(s.finalSince,nil)
    eq(P.negotiate(s,"new",70,{plan(70,100)},15,false),"final-wait")
    eq(P.negotiate(s,"new",70,{plan(70,100)},19.9,false),"final-wait")
end)
test("manual/partner acceptance freezes countdown and avoids stale decline",function()
    local s={}
    P.negotiate(s,"sig",70,{plan(70,100)},0,false)
    eq(P.negotiate(s,"sig",70,{plan(70,100)},5,false),"final-wait")
    eq(P.negotiate(s,"sig",70,{plan(70,100)},8,true),"hold")
    eq(P.negotiate(s,"sig",70,{plan(70,100)},9,false),"wait")
    eq(P.negotiate(s,"sig",70,{plan(70,100)},13.9,false),"wait")
    eq(P.negotiate(s,"sig",70,{plan(70,100)},14,false),"final-wait")
end)
test("verified local offer change invalidates final countdown",function()
    local s={}
    P.negotiate(s,"sig",70,{plan(70,100)},0,false)
    eq(P.negotiate(s,"sig",70,{plan(70,100)},5,false),"final-wait")
    eq(P.negotiate(s,"sig",69,{plan(69,100)},9,false),"wait")
    eq(s.finalSince,nil)
    eq(P.negotiate(s,"sig",69,{plan(69,100)},14,false),"final-wait")
end)
test("under +15 value cannot appear as sweetening candidate",function()
    local s={}
    local plans={plan(70,100),plan(86,100)}
    eq(P.negotiate(s,"sig",70,plans,0,false),"wait")
    eq(P.negotiate(s,"sig",70,plans,5,false),"final-wait")
    eq(s.steps,0)
end)
test("two improvements are an absolute maximum",function()
    local s={signature="same",total=10,steps=2,since=1}
    local plans={plan(10,200),plan(20,200),plan(30,200),plan(40,200)}
    eq(P.negotiate(s,"same",10,plans,3,false),"final-wait")
    eq(P.negotiate(s,"same",10,plans,6,false),"decline")
    eq(s.steps,2)
end)
print("RESULT "..passed.." final-window policy regressions passed")
