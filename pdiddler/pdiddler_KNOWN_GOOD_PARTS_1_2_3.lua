-- pdiddler KNOWN-GOOD stable stack: Parts 1 + 2 + 3
-- Part 1: bot gate
-- Part 2: Tablet / friend prompt startup
-- Part 3: scanner + purple GUI + outgoing queue + incoming-decline protection
-- ACTIVE ITEM-TRADE FINAL ACCEPT REMAINS DISABLED.

local function loadModule(url,label)
    local ok,src=pcall(function()
        return game:HttpGet(url,true)
    end)

    if not ok or type(src)~="string" or src=="" then
        error("[PDIDDLER] "..tostring(label).." HTTP failed: "..tostring(src))
    end

    local fn,err=loadstring(src)
    if not fn then
        error("[PDIDDLER] "..tostring(label).." compile failed: "..tostring(err))
    end

    local okRun,result=pcall(fn)
    if not okRun then
        error("[PDIDDLER] "..tostring(label).." init failed: "..tostring(result))
    end

    return result
end

local p1=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/af4a646aa751571bace8eeb2b305ba16cebcad2f/pdiddler/pdiddler1_KNOWN_GOOD.lua",
    "Part 1"
)

local ok1,res1=pcall(p1.run)
if not ok1 then
    error("[PDIDDLER] Part 1 run failed: "..tostring(res1))
end
if res1~=true then
    warn("[PDIDDLER] Part 1 blocked this server")
    return false
end

local p2=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/b097c1862db4cff7394d6a5e6764d34191df3283/pdiddler/pdiddler2_KNOWN_GOOD.lua",
    "Part 2"
)

local ok2,res2=pcall(p2.run)
if not ok2 then
    error("[PDIDDLER] Part 2 run failed: "..tostring(res2))
end
if res2~=true then
    warn("[PDIDDLER] Part 2 failed")
    return false
end

local scanner=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/f4289133d58d57d37a5fef04676dd7e4ab204a31/pdiddler/pdiddler3_scanner_MODULE_KNOWN_GOOD_v6_3_PURPLE.lua",
    "Part 3 scanner"
)

local outgoing=loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/5d71e1f4c0a4eb1e0715c75601e7e64cdf78ccc2/pdiddler/pdiddler3_outgoing_KNOWN_GOOD_v5.lua",
    "Part 3 outgoing queue"
)

local ok3,result=pcall(function()
    return outgoing.run(scanner)
end)

if not ok3 then
    error("[PDIDDLER] Part 3 outgoing run failed: "..tostring(result))
end

print("[PDIDDLER] KNOWN-GOOD stable stack ACTIVE: Parts 1 + 2 + 3")
print("[PDIDDLER] FINAL ITEM-TRADE ACCEPT remains DISABLED")

return result
