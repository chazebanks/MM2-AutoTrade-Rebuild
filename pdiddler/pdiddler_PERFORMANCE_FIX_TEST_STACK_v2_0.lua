-- pdiddler PERFORMANCE FIX TEST STACK v2.0
-- Performance-only branch from the current transactional trade build.
--
-- Performance changes:
--   * Part 3 uses MM2's exact TradeRequest frame path for incoming/pending checks
--   * expensive whole-UI descendant scans remain fallback-only
--   * scanner GUI rows/status/summary only write when content actually changes
--   * request-row repair loop reduced from 5 Hz to 1 Hz
--   * periodic inventory refresh work is spread out slightly more
--   * Part 4 accepted-state check uses exact TheirOffer.Accepted node first
--   * Part 4 noncritical poll interval 0.08 -> 0.12
--
-- Trade behavior intentionally unchanged:
--   * current planner/profit thresholds
--   * transactional rebalance/recovery
--   * 15s empty rule
--   * 60s Case 3 window
--   * Part 3 rotation
--   * FINAL ITEM-TRADE ACCEPT DISABLED.

local ENV=(getgenv and getgenv()) or _G

ENV.PDIDDLER_OUTGOING_SESSION=(tonumber(ENV.PDIDDLER_OUTGOING_SESSION) or 0)+1
ENV.PDIDDLER_PART4_SESSION=(tonumber(ENV.PDIDDLER_PART4_SESSION) or 0)+1
ENV.PDIDDLER_STATUS_OWNER=nil

local function loadModule(url,label)
    local ok,src=pcall(function()
        return game:HttpGet(url,true)
    end)

    if not ok or type(src)~="string" or src=="" then
        error("[PDIDDLER PERF] "..tostring(label).." HTTP failed: "..tostring(src))
    end

    local fn,err=loadstring(src)
    if not fn then
        error("[PDIDDLER PERF] "..tostring(label).." compile failed: "..tostring(err))
    end

    local okRun,result=pcall(fn)
    if not okRun then
        error("[PDIDDLER PERF] "..tostring(label).." init failed: "..tostring(result))
    end

    return result
end

local p1=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/af4a646aa751571bace8eeb2b305ba16cebcad2f/pdiddler/pdiddler1_KNOWN_GOOD.lua",
    "Part 1"
)
local ok1,res1=pcall(p1.run)
if not ok1 then error("[PDIDDLER PERF] Part 1 run failed: "..tostring(res1)) end
if res1~=true then warn("[PDIDDLER PERF] Part 1 blocked this server"); return false end

local p2=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/b097c1862db4cff7394d6a5e6764d34191df3283/pdiddler/pdiddler2_KNOWN_GOOD.lua",
    "Part 2"
)
local ok2,res2=pcall(p2.run)
if not ok2 then error("[PDIDDLER PERF] Part 2 run failed: "..tostring(res2)) end
if res2~=true then warn("[PDIDDLER PERF] Part 2 failed"); return false end

local scanner=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/25943d118f067355978b1f9c1a16a030e88ad19e/pdiddler/pdiddler3_scanner_MODULE_v6_6_PERF.lua",
    "Scanner performance build"
)

local part4=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/c756f0a5a7cb8d07ac53c65536bb1a1e26ecd4f4/pdiddler/pdiddler4_balancer_ROTATING_v2_0_PERF.lua",
    "Part 4 performance build"
)

local outgoing=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/1e59d1f1859d86cddb4b013daa7323bf5dd258c1/pdiddler/pdiddler3_outgoing_ROTATING_v8_PERF.lua",
    "Part 3 performance build"
)

local ok4,p4Controller=pcall(function()
    return part4.run(scanner)
end)
if not ok4 then
    error("[PDIDDLER PERF] Part 4 failed to arm: "..tostring(p4Controller))
end

local okOut,outController=pcall(function()
    return outgoing.run(scanner)
end)
if not okOut then
    error("[PDIDDLER PERF] Part 3 failed: "..tostring(outController))
end

print("[PDIDDLER PERF] PERFORMANCE FIX v2.0 ACTIVE")
print("[PDIDDLER PERF] exact MM2 request-frame polling active")
print("[PDIDDLER PERF] repeated GUI/layout writes deduplicated")
print("[PDIDDLER PERF] background UI repair throttled")
print("[PDIDDLER PERF] Part 4 poll rate reduced without changing timers")
print("[PDIDDLER PERF] FINAL ITEM-TRADE ACCEPT IS DISABLED")

return {
    scanner=scanner,
    outgoing=outController,
    part4=p4Controller,
}
