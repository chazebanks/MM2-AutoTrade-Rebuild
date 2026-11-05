local env=(getgenv and getgenv()) or _G
local url="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/f8b2978c497a5b24b1f4dc446dbf15471b8b4b40/pdiddler/pdiddler_V15_8_TELEPORT_AUTOBOOT_v1.lua"
env.PDIDDLER_V15_8_AUTOBOOT_URL=url
loadstring(game:HttpGet(url,true))()
