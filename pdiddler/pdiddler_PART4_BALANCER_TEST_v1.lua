-- pdiddler PART 4 BALANCER TEST v1
-- Frozen behavior retained: Parts 1-3 request/scanner mechanics.
-- Part 4 test:
--   highest-value opening item
--   accepted-empty immediate decline
--   empty 15s decline
--   balanced-aggressive profit planner
--   market-quality scoring
--   resumable handoff to Part 3
-- FINAL ITEM-TRADE ACCEPT IS NOT IMPLEMENTED.

local function loadModule(url,label)
    local ok,src=pcall(function()
        return game:HttpGet(url,true)
    end)

    if not ok or type(src)~="string" or src=="" then
        error("[PDIDDLER] "..tostring(label).." HTTP failed: "..tostring(src))
    end

    local fn,err=loadstring(src)

    if not fn then
        error("[PDIDDLER] "..tostring(label).." compile failed: "..tostring(err))
    end

    local okRun,result=pcall(fn)

    if not okRun then
        error("[PDIDDLER] "..tostring(label).." init failed: "..tostring(result))
    end

    return result
end

local p1=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/af4a646aa751571bace8eeb2b305ba16cebcad2f/pdiddler/pdiddler1_KNOWN_GOOD.lua",
    "Part 1"
)

local ok1,res1=pcall(p1.run)
if not ok1 then
    error("[PDIDDLER] Part 1 run failed: "..tostring(res1))
end
if res1~=true then
    warn("[PDIDDLER] Part 1 blocked this server")
    return false
end

local p2=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/b097c1862db4cff7394d6a5e6764d34191df3283/pdiddler/pdiddler2_KNOWN_GOOD.lua",
    "Part 2"
)

local ok2,res2=pcall(p2.run)
if not ok2 then
    error("[PDIDDLER] Part 2 run failed: "..tostring(res2))
end
if res2~=true then
    warn("[PDIDDLER] Part 2 failed")
    return false
end

local scanner=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/d0652acd3833302ace9f55e3ca506d0b63396106/pdiddler/pdiddler3_scanner_PART4_BRIDGE_v6_4.lua",
    "Part 3 scanner Part4 bridge"
)

local outgoingModule=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/00d37c65d3d87685577a80e6674546ff1601aabc/pdiddler/pdiddler3_outgoing_PART4_BRIDGE_v5.lua",
    "Part 3 outgoing Part4 bridge"
)

local market=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/bbc01262c6b7d82981275b8aab73f35e3f600012/pdiddler/pdiddler4_market_v1.lua",
    "Part 4 market"
)

local tradeIOModule=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/c7244c92a79f091a6af950fa34e8e6ebf395a858/pdiddler/pdiddler4_tradeio_v1.lua",
    "Part 4 trade IO"
)

local planner=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/9924126471117241efae41c59306cd7c3d2468f5/pdiddler/pdiddler4_planner_v1.lua",
    "Part 4 planner"
)

local controller=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/d883518faea3ecb44deff45164639d4f1d6a9161/pdiddler/pdiddler4_controller_v1_3.lua",
    "Part 4 controller"
)

local outgoing=outgoingModule.run(scanner)
local tradeIO=tradeIOModule.new(scanner)
local p4=controller.run(
    scanner,
    outgoing,
    tradeIO,
    market,
    planner
)

print("[PDIDDLER] PART 4 BALANCER TEST v1 ACTIVE")
print("[PDIDDLER] final item-trade Accept is COMPLETELY DISABLED")

return {
    scanner=scanner,
    outgoing=outgoing,
    part4=p4,
}
