-- Part 3 outgoing-request integration TEST v1
-- Known-good: Part 1 + Part 2 + scanner v6
-- Under test: sequential outgoing request queue
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
if res1~=true then
    warn("[PDIDDLER TEST] Part 1 blocked this server")
    return false
end

local p2=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/b097c1862db4cff7394d6a5e6764d34191df3283/pdiddler/pdiddler2_KNOWN_GOOD.lua",
    "Part 2"
)

local ok2,res2=pcall(p2.run)
if not ok2 then error("[PDIDDLER TEST] Part 2 run failed: "..tostring(res2)) end
if res2~=true then
    warn("[PDIDDLER TEST] Part 2 failed")
    return false
end

local scanner=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/cc9a4ce136b16731f0ce5620affeb8c9ee222fe9/pdiddler/pdiddler3_scanner_MODULE_v6_1.lua",
    "Scanner v6.1 bridge"
)

local outgoing=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/ba0ba9b10b5e44d1f11111fdbdd6c0326d72e90b/pdiddler/pdiddler3_outgoing_test_v1.lua",
    "Outgoing queue v1"
)

local okOut,result=pcall(function()
    return outgoing.run(scanner)
end)

if not okOut then
    error("[PDIDDLER TEST] outgoing queue run failed: "..tostring(result))
end

print("[PDIDDLER TEST] Part 3 outgoing-request subtest v1 ACTIVE")
print("[PDIDDLER TEST] FINAL ITEM-TRADE ACCEPT remains DISABLED")

return result
