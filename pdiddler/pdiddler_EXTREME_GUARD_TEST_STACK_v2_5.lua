-- pdiddler EXTREME GUARD TEST STACK v2.5
--
-- Fixes from the 11:19 / 11:23 recordings:
--   1) a successful physical Trade tap creates one authoritative outgoing owner
--   2) missing local pending UI after 4.5s is diagnostic only; ownership is retained
--   3) the same target is watched for the full 15s response window
--   4) pending/trade/decline signals resolve back to that exact target/UserId
--   5) if a trade opens without pending UI, exact TheirOffer.Username ownership is verified
--   6) after a successful Trade tap, that target is never re-tapped in this server session
--   7) a 15s no-proof timeout protects the target from resend instead of retrying it
--   8) trades that open before the target was actually tapped are not attributed to target
--   9) final timeout boundary re-check prevents missing a trade that opens at 15s
--
-- Retained unchanged:
--   * exact Lobby.Leaderboard performance paths
--   * scanner pause during request/trade critical phases
--   * corrected processed/whitelist diagnostics
--   * pending-owner fallback recovery
--   * Part 4 close-state cleanup
--   * transactional rebalancer
--   * 15s empty-offer rule
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
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/41372d75f053cb125c12847188966a10d51d1f10/pdiddler/pdiddler4_balancer_ROTATING_v2_3_EXTREME_GUARD.lua",
    "Part 4 extreme-overpay guard build"
)

local outgoing=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/9f0637b063c2f65cb1cf6fc1f6ce4ab08b5dda87/pdiddler/pdiddler3_outgoing_ROTATING_v15_UNCERTAIN_OWNER.lua",
    "Part 3 authoritative outgoing ownership build"
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

print("[PDIDDLER TEST] EXTREME GUARD v2.5 ACTIVE")
print("[PDIDDLER TEST] physical Trade tap => one owned 15s request session")
print("[PDIDDLER TEST] 4.5s missing pending UI no longer releases target")
print("[PDIDDLER TEST] late trade-open resolves to exact target UserId")
print("[PDIDDLER TEST] no duplicate Trade tap after successful physical tap")
print("[PDIDDLER TEST] no-proof timeout => NO RESEND THIS SERVER")
print("[PDIDDLER TEST] scanner/performance + outgoing ownership retained")
print("[PDIDDLER TEST] moderate overpay holds; extreme one-sided profit forces upward safe replan")
print("[PDIDDLER TEST] minimum-profit / downgrade / quality safety rules remain active")
print("[PDIDDLER TEST] FINAL ITEM-TRADE ACCEPT IS DISABLED")

return {
    scanner=scanner,
    outgoing=outController,
    part4=p4Controller,
}
