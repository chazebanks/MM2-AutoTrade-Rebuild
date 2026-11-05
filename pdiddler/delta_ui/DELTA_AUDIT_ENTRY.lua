local env=(getgenv and getgenv()) or _G
local url="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/5422928b0fa538802bd3d13f0a8dc89c77e15a82/pdiddler/pdiddler_V15_8_DELTA_UI_AUDIT_AUTOBOOT_v1.lua"
env.PDIDDLER_V15_8_AUTOBOOT_URL=url
loadstring(game:HttpGet(url,true))()
