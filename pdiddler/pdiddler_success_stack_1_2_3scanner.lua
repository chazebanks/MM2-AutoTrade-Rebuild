-- pdiddler integrated successful stack
-- Order: Part 1 bot gate -> Part 2 startup -> Part 3 scanner known-good
-- Modules stay separate to avoid Luau local-register pressure.

local function loadModule(url)
    local src = game:HttpGet(url, true)
    local fn, err = loadstring(src)
    if not fn then
        error("pdiddler load failed: "..tostring(err))
    end
    return fn()
end

local part1 = loadModule("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/b10de77e1e588e6e1590f048978028bdfd130d4e/pdiddler/pdiddler1.lua")
if type(part1)~="table" or type(part1.run)~="function" then
    error("pdiddler1 module contract invalid")
end

local ok1 = part1.run()
if ok1~=true then
    warn("[PDIDDLER] Part 1 blocked this server; stopping stack")
    return false
end

local part2 = loadModule("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/5eebaf8d1e588e6e1590f048978028bdfd130d4e/pdiddler/pdiddler2.lua")
if type(part2)~="table" or type(part2.run)~="function" then
    error("pdiddler2 module contract invalid")
end

local ok2 = part2.run()
if ok2~=true then
    warn("[PDIDDLER] Part 2 failed; scanner will not start")
    return false
end

-- Scanner self-starts when loaded.
loadModule("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/fda5825bdfa779317e78b4ba00899a75962cda65/pdiddler/pdiddler3_scanner_KNOWN_GOOD_v5.lua")

print("[PDIDDLER] Successful stack active: P1 + P2 + P3 scanner")
return true
