-- successful stack v3: P1 + P2 + known-good scanner v6
local function loadModule(url,label)
    local ok,src=pcall(function() return game:HttpGet(url,true) end)
    if not ok or type(src)~="string" or src=="" then
        error("[PDIDDLER] "..tostring(label).." HTTP load failed: "..tostring(src))
    end
    local fn,err=loadstring(src)
    if not fn then error("[PDIDDLER] "..tostring(label).." compile failed: "..tostring(err)) end
    local okRun,result=pcall(fn)
    if not okRun then error("[PDIDDLER] "..tostring(label).." init failed: "..tostring(result)) end
    return result
end

local p1=loadModule(
 "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/af4a646aa751571bace8eeb2b305ba16cebcad2f/pdiddler/pdiddler1_KNOWN_GOOD.lua",
 "Part 1"
)
local ok1,res1=pcall(p1.run)
if not ok1 then error("[PDIDDLER] Part 1 run failed: "..tostring(res1)) end
if res1~=true then warn("[PDIDDLER] Part 1 blocked server"); return false end

local p2=loadModule(
 "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/b097c1862db4cff7394d6a5e6764d34191df3283/pdiddler/pdiddler2_KNOWN_GOOD.lua",
 "Part 2"
)
local ok2,res2=pcall(p2.run)
if not ok2 then error("[PDIDDLER] Part 2 run failed: "..tostring(res2)) end
if res2~=true then warn("[PDIDDLER] Part 2 failed"); return false end

loadModule(
 "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/ab6582d3576c3a9fed95dd5e17360fcc9c3f4d89/pdiddler/pdiddler3_scanner_KNOWN_GOOD_v6.lua",
 "Part 3 scanner v6"
)

print("[PDIDDLER] Successful stack active: P1 + P2 + scanner v6")
return true
