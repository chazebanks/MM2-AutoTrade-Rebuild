-- pdiddler integrated successful stack v2
-- Order: Part 1 bot gate -> Part 2 startup -> Part 3 scanner known-good
-- Modules remain separate to preserve Luau register headroom.

local function loadModule(url, label)
    local okHttp, src = pcall(function()
        return game:HttpGet(url, true)
    end)

    if not okHttp or type(src) ~= "string" or src == "" then
        error("[PDIDDLER] "..tostring(label).." HTTP load failed: "..tostring(src))
    end

    local fn, err = loadstring(src)
    if not fn then
        error("[PDIDDLER] "..tostring(label).." compile failed: "..tostring(err))
    end

    local okRun, result = pcall(fn)
    if not okRun then
        error("[PDIDDLER] "..tostring(label).." module init failed: "..tostring(result))
    end

    return result
end

local part1 = loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/af4a646aa751571bace8eeb2b305ba16cebcad2f/pdiddler/pdiddler1_KNOWN_GOOD.lua",
    "Part 1"
)

if type(part1) ~= "table" or type(part1.run) ~= "function" then
    error("[PDIDDLER] Part 1 module contract invalid")
end

local ok1, gateResult = pcall(part1.run)
if not ok1 then
    error("[PDIDDLER] Part 1 run failed: "..tostring(gateResult))
end
if gateResult ~= true then
    warn("[PDIDDLER] Part 1 blocked this server; stopping stack")
    return false
end

local part2 = loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/b097c1862db4cff7394d6a5e6764d34191df3283/pdiddler/pdiddler2_KNOWN_GOOD.lua",
    "Part 2"
)

if type(part2) ~= "table" or type(part2.run) ~= "function" then
    error("[PDIDDLER] Part 2 module contract invalid")
end

local ok2, startupResult = pcall(part2.run)
if not ok2 then
    error("[PDIDDLER] Part 2 run failed: "..tostring(startupResult))
end
if startupResult ~= true then
    warn("[PDIDDLER] Part 2 failed; scanner will not start")
    return false
end

loadModule(
    "https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/fda5825bdfa779317e78b4ba00899a75962cda65/pdiddler/pdiddler3_scanner_KNOWN_GOOD_v5.lua",
    "Part 3 scanner"
)

print("[PDIDDLER] Successful stack active: P1 + P2 + P3 scanner")
return true
