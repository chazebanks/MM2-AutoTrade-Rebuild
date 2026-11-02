-- pdiddler Part 4 VIDEO-FIX TEST STACK v1.6
-- Fixes confirmed from 2026-11-02 recording:
--   1) closest-safe-profit planner (no more cheapest-item-first 80-vs-8 behavior)
--   2) extreme overpay normalization into a realistic preferred profit band
--   3) Part 4 exclusively owns active-trade main status
--   4) stale/leaving targets revalidated before card click AND before Trade tap
--   5) partner cancel/close returns immediately to Part 3 rotation
-- Existing safety remains:
--   accepted-empty => immediate decline
--   never-offers => 15s decline
--   first real offer => one 60s Case 3 test window
--   FINAL ITEM-TRADE ACCEPT IS DISABLED.

local ENV=(getgenv and getgenv()) or _G

-- Invalidate old P3/P4 callbacks before starting this test generation.
ENV.PDIDDLER_OUTGOING_SESSION=(tonumber(ENV.PDIDDLER_OUTGOING_SESSION) or 0)+1
ENV.PDIDDLER_PART4_SESSION=(tonumber(ENV.PDIDDLER_PART4_SESSION) or 0)+1
ENV.PDIDDLER_STATUS_OWNER=nil

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
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/b91df6e47ee39482a2bde3ef0ff454877b34142c/pdiddler/pdiddler3_scanner_MODULE_v6_5_PART4_STATUS_BRIDGE.lua",
    "Part 3 scanner + Part 4 status/own-inventory bridge"
)

local part4=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/d378538083441779cd5a282d4e799c84e2df10c4/pdiddler/pdiddler4_balancer_ROTATING_v1_6.lua",
    "Part 4 video-fix balancer v1.6"
)

local outgoing=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/f3589d3d1f02e2222a12b2af66f75a52c6699a2a/pdiddler/pdiddler3_outgoing_ROTATING_v7.lua",
    "Part 3 rotating outgoing v7"
)

-- Arm Part 4 before outgoing requests so fast accepts cannot create a handoff gap.
local ok4,p4Controller=pcall(function()
    return part4.run(scanner)
end)
if not ok4 then
    error("[PDIDDLER TEST] Part 4 failed to arm: "..tostring(p4Controller))
end

local okOut,outController=pcall(function()
    return outgoing.run(scanner)
end)
if not okOut then
    error("[PDIDDLER TEST] Part 3 rotating queue failed: "..tostring(outController))
end

print("[PDIDDLER TEST] VIDEO-FIX STACK v1.6 ACTIVE")
print("[PDIDDLER TEST] planner = closest safe profitable offer")
print("[PDIDDLER TEST] profit plans beat controlled-overpay upgrade plans")
print("[PDIDDLER TEST] extreme profit normalized into preferred band when possible")
print("[PDIDDLER TEST] Part 4 owns active-trade status")
print("[PDIDDLER TEST] stale targets revalidated before physical taps")
print("[PDIDDLER TEST] partner cancel/close => Part 3 resumes")
print("[PDIDDLER TEST] FINAL ITEM-TRADE ACCEPT IS DISABLED")

return {
    scanner=scanner,
    outgoing=outController,
    part4=p4Controller,
}
