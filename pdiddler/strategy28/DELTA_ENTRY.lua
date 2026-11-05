local env=(getgenv and getgenv()) or _G
local url="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/ae6c94dbcaf85ee6cc0789840a6a6a24ac7aa24d/pdiddler/pdiddler_V15_7_TELEPORT_AUTOBOOT_v1.lua"
env.PDIDDLER_V15_7_AUTOBOOT_URL=url
loadstring(game:HttpGet(url,true))()
