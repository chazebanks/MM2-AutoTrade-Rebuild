local P=dofile(arg[1] or "pdiddler/pdiddler4_supreme_policy_v7_VERIFIED_STEPS.lua")
local n=0
local function test(name,fn) fn(); n=n+1; print("PASS "..name) end
local plan={ok=true,key="rawA",rawTotal=58,rawProfit=42,givenExitScore=3,givenRisk=0,units=1,picks={{page="godly",id="rawA",qty=1}}}
local live={rawTotal=58,unresolved={},counts={["godly:rawA"]=1}}
test("proposal does not count as verified late improvement",function()
 local s={};P.negotiate(s,"sig",50,{plan},0,false,true,100)
 local action=P.negotiate(s,"sig",50,{plan},10,false,true,100)
 assert(action=="improve");assert(s.steps==0,"step consumed before verification")
 assert(P.negotiate(s,"sig",50,{plan},11,false,true,100)=="pending-verification")
 assert(P.confirmConcession(s,"sig",plan,live,11));assert(s.steps==1)
 assert(not P.confirmConcession(s,"sig",plan,live,12),"duplicate verification counted twice")
end)
test("wrong actual counts cannot commit a concession",function()
 local s={};P.negotiate(s,"sig",50,{plan},0,false,true,100);P.negotiate(s,"sig",50,{plan},10,false,true,100)
 assert(not P.confirmConcession(s,"sig",plan,{rawTotal=58,unresolved={},counts={}},11));assert(s.steps==0)
 P.cancelConcession(s);assert(P.negotiate(s,"sig",50,{plan},30,false,true,100)=="unverified-hold")
end)
test("changed opponent invalidates old pending proposal",function()
 local s={};P.negotiate(s,"old",50,{plan},0,false,true,100);P.negotiate(s,"old",50,{plan},10,false,true,100)
 P.negotiate(s,"new",50,{plan},11,false,true,100)
 assert(not P.confirmConcession(s,"old",plan,live,12));assert(s.steps==0)
end)
print("PASS "..n.." verified-negotiation tests")
