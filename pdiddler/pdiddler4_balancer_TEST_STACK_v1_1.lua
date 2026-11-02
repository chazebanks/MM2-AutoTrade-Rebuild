-- pdiddler Part 4 balancer TEST STACK v1.1
-- Frozen successful behavior retained: Parts 1, 2, and Part 3 outgoing v5.
-- Scanner copy only adds read-only getOwnInventory() using the same value pipeline.
-- Part 4: highest-item opening + empty safety + market-aware balancer.
-- FINAL ITEM-TRADE ACCEPT IS DISABLED.

local function loadModule(url,label)
    local ok,src=pcall(function()
        return game:HttpGet(url,true)
    end)

    if not ok or type(src)~="string" or src=="" then
        error("[PDIDDLER TEST] "..tostring(label).." HTTP failed: "..tostring(src))
    end

    local fn,err=loadstring(src)
    if not fn then
        error("[PDIDDLER TEST] "..tostring(label).." compile failed: "..tostring(err))
    end

    local okRun,result=pcall(fn)
    if not okRun then
        error("[PDIDDLER TEST] "..tostring(label).." init failed: "..tostring(result))
    end

    return result
end

local p1=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/af4a646aa751571bace8eeb2b305ba16cebcad2f/pdiddler/pdiddler1_KNOWN_GOOD.lua",
    "Part 1"
)
local ok1,res1=pcall(p1.run)
if not ok1 then error("[PDIDDLER TEST] Part 1 run failed: "..tostring(res1)) end
if res1~=true then warn("[PDIDDLER TEST] Part 1 blocked this server"); return false end

local p2=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/b097c1862db4cff7394d6a5e6764d34191df3283/pdiddler/pdiddler2_KNOWN_GOOD.lua",
    "Part 2"
)
local ok2,res2=pcall(p2.run)
if not ok2 then error("[PDIDDLER TEST] Part 2 run failed: "..tostring(res2)) end
if res2~=true then warn("[PDIDDLER TEST] Part 2 failed"); return false end

local scanner=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/c94a7a47bb81a51df196c319baf330f0d601c8df/pdiddler/pdiddler3_scanner_MODULE_v6_4_PART4_BRIDGE.lua",
    "Part 3 scanner + Part 4 read-only bridge"
)

local outgoing=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/5d71e1f4c0a4eb1e0715c75601e7e64cdf78ccc2/pdiddler/pdiddler3_outgoing_KNOWN_GOOD_v5.lua",
    "Part 3 outgoing known-good v5"
)

local part4=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/840c5b146f24ea0893fe9138738a60dfdd9ea145/pdiddler/pdiddler4_balancer_test_v1_1.lua",
    "Part 4 balancer v1.1"
)

local okOut,outController=pcall(function()
    return outgoing.run(scanner)
end)
if not okOut then
    error("[PDIDDLER TEST] Part 3 outgoing failed: "..tostring(outController))
end

local ok4,p4Controller=pcall(function()
    return part4.run(scanner)
end)
if not ok4 then
    error("[PDIDDLER TEST] Part 4 failed to arm: "..tostring(p4Controller))
end

print("[PDIDDLER TEST] PART 4 v1.1 ARMED")
print("[PDIDDLER TEST] highest-value opening offer enabled")
print("[PDIDDLER TEST] accepted-empty immediate decline enabled")
print("[PDIDDLER TEST] 15s empty-offer decline enabled")
print("[PDIDDLER TEST] balanced-aggressive rebalancer enabled")
print("[PDIDDLER TEST] MM2Values stability modifiers snapshot=2026-11-02")
print("[PDIDDLER TEST] FINAL ITEM-TRADE ACCEPT IS DISABLED")

return {
    scanner=scanner,
    outgoing=outController,
    part4=p4Controller,
}
