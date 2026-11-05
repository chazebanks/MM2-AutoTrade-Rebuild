local env=(getgenv and getgenv()) or _G
local url="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/45e690a32fba27c5b3af92f317fb0084b32bd55a/pdiddler/pdiddler_V15_8_DELTA_UI_AUDIT_AUTOBOOT_v2.lua"
env.PDIDDLER_V15_8_AUTOBOOT_URL=url
loadstring(game:HttpGet(url,true))()
