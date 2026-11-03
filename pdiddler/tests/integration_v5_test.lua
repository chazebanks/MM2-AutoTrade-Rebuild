local F=dofile("pdiddler/tests/integration_fixture.lua")
local P=dofile("pdiddler/pdiddler4_supreme_policy_v2_ADAPTIVE.lua")
local path="pdiddler/pdiddler_FASTGATE_V5_INTEGRATED_TEST_v5_ADAPTIVE.lua"
local passed=0
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function fixture(options)
    local f=F.new(options)
    f.profile={liveReady=true,version="fixture",get=function(_,id) return {page="godly",id=id,name="A",supremeValue=100,demand=3,stability="Stable",verified=true} end,
        coverage=function() return {total=190} end,isFresh=function() return not f.expired end}
    f.scanner.getOwnInventory=function() return {items={{page="godly",cat="Weapons",type="Knife",id="raw_A",checkerId="7",name="A",value=999,qty=1}}} end
    f.scanner.isWhitelisted=function() return true end
    f.sources["pdiddler_supreme_snapshot_2026_11_03_ISSUE4.lua"]=function() return f.profile end
    f.sources["pdiddler4_supreme_policy_v2_ADAPTIVE.lua"]=function() return P end
    f.sources["pdiddler4_balancer_SUPREME_v2_ADAPTIVE.lua"]=function() return {run=function(scanner,profile,logic,planner,telemetry)
        assert(profile==f.profile and logic==P and planner==P and telemetry.build()==nil)
        f.tradingScanner=scanner; f.env.PDIDDLER_PART4_SESSION=1; return f.p4
    end} end
    f.sources["pdiddler3_outgoing_ROTATING_v16_EXACT_IDENTITY.lua"]=function() return {run=function(scanner)
        assert(scanner==f.tradingScanner); f.env.PDIDDLER_OUTGOING_SESSION=1; return f.out
    end} end
    return f
end
local function test(name,fn) fn(); passed=passed+1; print("PASS "..name) end
test("new build injects Supreme policy and preserves frozen inventory",function()
    local f=fixture(); f:run(path); f:advance(20); eq(f.controller.stage,"TRADING"); eq(#f.errors,0)
    local inv=f.tradingScanner.getOwnInventory(); eq(inv.items[1].value,100); eq(inv.total,100); eq(inv.items[1].id,"raw_A"); eq(f.scanner.getOwnInventory().items[1].value,999)
end)
test("stale snapshot blocks before scanner and outgoing startup",function() local f=fixture(); f.expired=true; f:run(path); f:advance(20); eq(f.controller.stage,"ERROR"); eq(f.scannerLoads,nil); eq(f.env.PDIDDLER_OUTGOING_SESSION,nil) end)
test("expiry stops outgoing and hopping while P4 can close a trade",function() local f=fixture(); f:run(path); f:advance(20); f.expired=true; f:advance(25); eq(f.controller.stage,"PRICE_HOLD"); assert(f.outStopped); assert(not f.p4Stopped); eq(f:count("hop"),0) end)
test("new build refuses to steal a V3 owner",function() local f=fixture(); local old={jobId="job",running=true}; f.env.PDIDDLER_INTEGRATION_V3=old; eq(f:run(path),old); f:advance(20); eq(f.scannerLoads,nil) end)
test("corroborated bot still hops before loading prices or scanner",function() local f=fixture({gateState="BOT_PATTERN_FOR_REVIEW"}); f.expired=true; f:run(path); f:advance(25); eq(f:count("hop"),1); eq(f.scannerLoads,nil) end)
test("new build declines no completion claim when trade GUI closes",function() local f=fixture(); f:run(path); f:advance(20); eq(f.controller.completedTrades,nil); eq(f.controller.webhookSender,nil) end)
test("unsupported native capabilities cannot be enabled by old globals",function() local f=fixture(); f.env.PDIDDLER_AUTO_ACCEPT=true; f.env.PDIDDLER_DISCORD_WEBHOOK_URL="runtime-only"; f:run(path); f:advance(20); assert(f.controller.capabilities.autoAccept==false and f.controller.capabilities.completion==false and f.controller.capabilities.discord==false); assert(f.controller.blockers.completion:find("transaction",1,true)) end)
test("V5 refuses a live tested V4 controller",function() local f=fixture(); local old={jobId="job",running=true}; f.env.PDIDDLER_INTEGRATION_V4_SUPREME=old; assert(f:run(path)==old); f:advance(20); assert(f.scannerLoads==nil) end)
print("PASS "..passed.." adaptive loader integration tests")
