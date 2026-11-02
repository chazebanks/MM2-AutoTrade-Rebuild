-- pdiddler Part 4 TRANSACTION FIX TEST STACK v1.9
-- Video-driven executor fixes only. Planner thresholds/values are unchanged.
--
-- Part 4 transaction guarantees:
--   * exact offer signature + raw-value mutation verification after Remove
--   * x2 quantity changes count as successful mutation even if slot count stays 1
--   * one late-replication guard before a bounded fresh-button retry
--   * opponent offer change aborts the current transaction immediately
--   * any partial/unverified mutation enters RECOVERY; no new plan is stacked
--   * recovery clears OUR offer against a stable current opponent offer
--   * recovery itself is bounded; repeated uncertainty becomes PROTECTED HOLD
--   * after recovery, opponent offer must stabilize again before fresh planning
--   * duplicate stacks verify by exact item counts, not visible-slot count
--
-- Existing behavior retained:
--   * highest-value opening offer
--   * accepted-empty immediate decline
--   * never-offers => 15s decline
--   * first real offer => one 60s Case 3 test window
--   * closest-safe-profit planner and preferred profit band
--   * partner cancel/close => Part 3 resumes rotation
--   * Part 4 owns main status while active
--   * stale Part 3 targets are skipped/revalidated
--   * FINAL ITEM-TRADE ACCEPT IS DISABLED.

local ENV=(getgenv and getgenv()) or _G

-- Kill stale callbacks from earlier test generations.
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
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/6ee2bea96272953c5d88fe27d06c141ae50a8d2c/pdiddler/pdiddler4_balancer_ROTATING_v1_9.lua",
    "Part 4 transactional balancer v1.9"
)

local outgoing=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/f3589d3d1f02e2222a12b2af66f75a52c6699a2a/pdiddler/pdiddler3_outgoing_ROTATING_v7.lua",
    "Part 3 rotating outgoing v7"
)

-- Arm Part 4 first so a fast accepted request has no handoff gap.
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

print("[PDIDDLER TEST] TRANSACTION FIX STACK v1.9 ACTIVE")
print("[PDIDDLER TEST] Remove verification = exact signature/value mutation")
print("[PDIDDLER TEST] stale opponent offer => transaction abort")
print("[PDIDDLER TEST] partial mutation => clean recovery before replanning")
print("[PDIDDLER TEST] duplicate x2 stacks supported in verification")
print("[PDIDDLER TEST] recovery retries are bounded; uncertainty => protected hold")
print("[PDIDDLER TEST] FINAL ITEM-TRADE ACCEPT IS DISABLED")

return {
    scanner=scanner,
    outgoing=outController,
    part4=p4Controller,
}
