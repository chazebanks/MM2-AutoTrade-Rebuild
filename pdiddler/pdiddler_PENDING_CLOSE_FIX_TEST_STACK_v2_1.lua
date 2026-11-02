-- pdiddler PENDING + CLOSE FIX TEST STACK v2.1
--
-- Fixes from the 10:20 recording:
--   1) late outgoing pending requests are adopted by exact SendingRequest.Username
--   2) anonymous/unowned pending requests are cancelled instead of freezing queue
--   3) a pending for player A can never prove a newly tapped request for player B
--   4) unavailable player cards close immediately while late-pending ownership is retained
--   5) Part 4 module-session validity is separate from trade GUI existence
--   6) normal trade closure writes PROCESSED/CLOSED cleanup instead of stale-session
--
-- Existing behavior retained:
--   * performance optimizations
--   * 15s outgoing response timer
--   * 15s empty-offer rule
--   * 60s Case 3 window
--   * transactional rebalancer/recovery
--   * closest-safe-profit planner
--   * rotation
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
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/25943d118f067355978b1f9c1a16a030e88ad19e/pdiddler/pdiddler3_scanner_MODULE_v6_6_PERF.lua",
    "Scanner performance build"
)

local part4=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/83670f3a9da06a07f1b9f67ca1e0467ea3714d8b/pdiddler/pdiddler4_balancer_ROTATING_v2_1_CLOSE_FIX.lua",
    "Part 4 close-state fix"
)

local outgoing=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/a5fff6e7e567d6c9be7966a4b3925855501978a5/pdiddler/pdiddler3_outgoing_ROTATING_v11_PENDING_OWNER.lua",
    "Part 3 late-pending owner fix"
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

print("[PDIDDLER TEST] PENDING + CLOSE FIX v2.1 ACTIVE")
print("[PDIDDLER TEST] late pending owner adoption active")
print("[PDIDDLER TEST] mismatched pending proof blocked")
print("[PDIDDLER TEST] orphan pending recovery active")
print("[PDIDDLER TEST] deferred player cards close immediately")
print("[PDIDDLER TEST] normal trade close != stale-session")
print("[PDIDDLER TEST] FINAL ITEM-TRADE ACCEPT IS DISABLED")

return {
    scanner=scanner,
    outgoing=outController,
    part4=p4Controller,
}
