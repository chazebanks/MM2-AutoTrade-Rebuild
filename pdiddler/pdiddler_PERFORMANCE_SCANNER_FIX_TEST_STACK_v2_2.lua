-- pdiddler PERFORMANCE/SCANNER FIX TEST STACK v2.2
--
-- Changes from the 10:45 recording:
--   1) Part 3 uses verified MM2 phone paths under MainGUI.Lobby.Leaderboard
--   2) exact PlayerList/Popup/Username/Trade paths are normal path
--   3) expensive PlayerGui descendant scans are compatibility fallback only
--   4) scanner pauses all non-initial inventory reads during outgoing request work
--   5) scanner pauses during active Part 4 trades / visible trade GUI
--   6) if a refresh already started, it pauses before the next inventory RPC
--   7) new-player/retry inventory reads defer during critical trade phases
--   8) queue diagnostics report real processed count + current whitelist count
--
-- Retained:
--   * pending-owner adoption/recovery
--   * trade-close cleanup fix
--   * transactional rebalancer
--   * 15s outgoing timer
--   * 15s empty-offer timer
--   * 60s Case 3 window
--   * closest-safe-profit planner
--   * FINAL ITEM-TRADE ACCEPT DISABLED.

local ENV=(getgenv and getgenv()) or _G

ENV.PDIDDLER_OUTGOING_SESSION=(tonumber(ENV.PDIDDLER_OUTGOING_SESSION) or 0)+1
ENV.PDIDDLER_PART4_SESSION=(tonumber(ENV.PDIDDLER_PART4_SESSION) or 0)+1
ENV.PDIDDLER_OUTGOING_BUSY_SESSION=nil
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
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/3c48b49c1e750d91bfbf088fbc737185bddf39be/pdiddler/pdiddler3_scanner_MODULE_v6_8_CRITICAL_PAUSE.lua",
    "Scanner critical-phase pause build"
)

local part4=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/83670f3a9da06a07f1b9f67ca1e0467ea3714d8b/pdiddler/pdiddler4_balancer_ROTATING_v2_1_CLOSE_FIX.lua",
    "Part 4 close-state build"
)

local outgoing=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/8a7afa700f0c6cd8fb6aa5fa8ac9978d46f40fa7/pdiddler/pdiddler3_outgoing_ROTATING_v12_EXACT_UI_PERF.lua",
    "Part 3 exact-UI performance build"
)

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
    error("[PDIDDLER TEST] Part 3 failed: "..tostring(outController))
end

print("[PDIDDLER TEST] PERFORMANCE/SCANNER FIX v2.2 ACTIVE")
print("[PDIDDLER TEST] verified Lobby.Leaderboard direct paths active")
print("[PDIDDLER TEST] scanner pauses inventory RPCs during request/trade critical phases")
print("[PDIDDLER TEST] queue processed/whitelist diagnostics corrected")
print("[PDIDDLER TEST] pending-owner + trade-close fixes retained")
print("[PDIDDLER TEST] FINAL ITEM-TRADE ACCEPT IS DISABLED")

return {
    scanner=scanner,
    outgoing=outController,
    part4=p4Controller,
}
