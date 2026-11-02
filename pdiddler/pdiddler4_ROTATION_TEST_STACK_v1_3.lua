-- pdiddler Part 4 ROTATION TEST STACK v1.3
-- Frozen Parts 1 and 2.
-- Scanner logic retained; bridge only exposes own inventory through same value pipeline.
-- Part 3 rotates automatically after every active trade closes.
-- Part 4:
--   empty + accepted => immediate decline
--   empty + no action => 15s decline
--   once THEIR OFFER becomes non-empty => 60s Case 3 test window
--   balancer runs during that window
--   after 60s => decline and return to Part 3 rotation
--   if partner closes/cancels sooner => return to Part 3 immediately
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
    "Part 3 scanner + Part 4 bridge"
)

local part4=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/cdc1e2960b4a1920a3848c1617cb11c797edd5fa/pdiddler/pdiddler4_balancer_ROTATING_v1_3.lua",
    "Part 4 rotating balancer v1.3"
)

local outgoing=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/3ff25d62e2b31f84b942ca800be29fd246f7eaf1/pdiddler/pdiddler3_outgoing_ROTATING_v6.lua",
    "Part 3 rotating outgoing v6"
)

-- Arm Part 4 FIRST so there is no handoff gap if a request is accepted quickly.
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

print("[PDIDDLER TEST] PART 4 ROTATION STACK v1.3 ACTIVE")
print("[PDIDDLER TEST] Case 1: accepted empty => immediate decline")
print("[PDIDDLER TEST] Case 2: empty/no action => 15s decline")
print("[PDIDDLER TEST] Case 3: first non-empty offer starts ONE 60s test window")
print("[PDIDDLER TEST] partner cancel/close => immediate Part 3 resume")
print("[PDIDDLER TEST] 60s expiry => decline => Part 3 rotates")
print("[PDIDDLER TEST] FINAL ITEM-TRADE ACCEPT IS DISABLED")

return {
    scanner=scanner,
    outgoing=outController,
    part4=p4Controller,
}
