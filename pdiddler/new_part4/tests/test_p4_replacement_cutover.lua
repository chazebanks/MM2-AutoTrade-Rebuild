-- Stage 21 Lua 5.4 cutover tests. Every Roblox object is mocked.
local dir=arg[1] or "pdiddler/new_part4"
local P=assert(loadfile(dir.."/P4_REPRICE_ONLY.lua"))()
local E=assert(loadfile(dir.."/P3_ELIGIBILITY_NO_LEGACY_PROFIT.lua"))()
local passed=0
local function test(label,fn)
 local ok,why=pcall(fn)
 if not ok then error(label..": "..tostring(why)) end
 passed=passed+1
end
local function inventory()
 return {fingerprint="fp1",items={{id="A",page="godly",checkerId="11",name="Laser",
     cat="Weapons",type="Gun",qty=2,value=12}},unmapped=0,badQty=0,unpriced=0}
end
local function profile()
 return {version="synthetic",isFresh=function()return true end,
    get=function(page,id)
        assert(page=="godly" and id=="11")
        return {page=page,id=id,name="Laser",supremeValue=22,
            demand=1,stability="Stable",verified=true}
    end}
end
test("repricer preserves exact quantity and replaces raw price",function()
 local inv=inventory()
 local out,why=P.reprice(inv,profile())
 assert(why==nil and out.value==44 and out.total==44)
 assert(out.items[1].qty==2 and out.items[1].value==22)
 assert(inv.items[1].value==12)
 assert(P.buildPlans==nil and P.tradeDecision==nil and P.minimumProfit==nil)
end)
test("unknown source never becomes a guessed zero",function()
 local inv=inventory()
 local p=profile()
 p.get=function() return nil end
 local out,why=P.reprice(inv,p)
 assert(why==nil and #out.items==0 and out.unpriced==1)
 local valid=E.validateInventory(inv,p,P)
 assert(valid==nil)
end)
test("incorrect page/name checker ID never receives trusted quote",function()
 local inv=inventory()
 inv.items[1].name="Vintage Laser"
 local out=P.reprice(inv,profile())
 assert(out.unpriced==1)
end)
test("stale market blocks repricing and request discovery",function()
 local inv=inventory()
 local p=profile()
 p.isFresh=function()return false end
 local _,why=P.reprice(inv,p)
 assert(why=="supreme-profile-stale")
 local state=E.evaluate(inv,inv,p,P)
 assert(state=="unknown")
end)
test("verified counterparty is reachable even without fixed +15",function()
 local inv=inventory()
 local state,why,witness=E.evaluate(inv,inv,profile(),P)
 assert(state=="reachable" and why:find("new-strategy",1,true))
 assert(witness.authorizesTrade==false and witness.authorizesAccept==false)
end)
test("bad quantities never allow request",function()
 local inv=inventory()
 inv.items[1].qty=1.5
 local state=E.evaluate(inv,inventory(),profile(),P)
 assert(state=="unknown")
end)
test("missing eligible inventory is not target",function()
 local inv=inventory()
 inv.items={}
 local state=E.evaluate(inv,inventory(),profile(),P)
 assert(state=="unprofitable")
end)
test("new P4 obeys original run/session/stop API",function()
 local env={}
 getgenv=function()return env end
 loadstring=load
 local lp={UserId=11}
 local players={LocalPlayer=lp}
 function players:GetPlayers()return {lp} end
 local readCount=0
 game={JobId="job-1",
   GetService=function(_,name)assert(name=="Players");return players end,
   HttpGet=function(_,url)
     assert(url:find("new_part4/",1,true))
     local filename=url:match("([^/]+)%.lua$")
     assert(filename=="p4_observer_contract" or filename=="p4_native_observer")
     local f=assert(io.open(dir.."/"..filename..".lua","r"))
     local t=f:read("*a");f:close();readCount=readCount+1
     return t
   end}
 local scheduled={}
 task={spawn=function(fn)scheduled[#scheduled+1]=fn end,
       wait=function()error("no worker execution in contract test")end}
 local scanner={
   getRecord=function()return nil end,
   getOwnInventory=function()return inventory() end,
   claimStatusOwner=function()end,releaseStatusOwner=function()end}
 local m=assert(loadfile(dir.."/PDIDDLER_PART4_REPLACEMENT.lua"))()
 local controller=m.run(scanner,profile())
 assert(controller.kind=="gingerscope-replacement-observer")
 assert(controller.session==1 and env.PDIDDLER_PART4_SESSION==1)
 assert(controller.state.active==false)
 assert(controller.state.authorizesTrade==false)
 assert(controller.state.authorizesAccept==false)
 assert(readCount==2 and #scheduled==1)
 local ok=pcall(m.run,scanner,profile())
 assert(not ok,"second controller must not seize session")
 controller.stop()
 assert(env.PDIDDLER_PART4_SESSION==2)
 assert(not controller.isAlive())
end)
print("PASS",passed,"Stage21 replacement cutover Lua contract tests")
