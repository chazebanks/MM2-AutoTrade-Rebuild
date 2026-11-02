-- Part 3 outgoing-request integration TEST v5
-- Known-good: Part 1 + Part 2 + scanner v6 logic
-- UI: purple/black with colored status accents
-- Outgoing: incoming auto-decline + UNAVAILABLE classification for trades-off/busy/loading
-- FINAL ITEM-TRADE ACCEPT IS NOT IMPLEMENTED.

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
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/525bdbad16d732f4a80493704779f5bb98272095/pdiddler/pdiddler3_scanner_MODULE_v6_3_PURPLE.lua",
    "Scanner v6.3 purple bridge"
)

local outgoing=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/376f325cfe2a5b59ba2bfc735b5a95d6b59325d3/pdiddler/pdiddler3_outgoing_test_v5.lua",
    "Outgoing queue v5"
)

local okOut,result=pcall(function()
    return outgoing.run(scanner)
end)

if not okOut then
    error("[PDIDDLER TEST] outgoing queue run failed: "..tostring(result))
end

print("[PDIDDLER TEST] Part 3 outgoing-request subtest v5 ACTIVE")
print("[PDIDDLER TEST] incoming requests are physically DECLINED during outgoing phase")
print("[PDIDDLER TEST] no-pending after Trade = UNAVAILABLE (trades off / busy / loading), not guessed")
print("[PDIDDLER TEST] FINAL ITEM-TRADE ACCEPT remains DISABLED")
return result
