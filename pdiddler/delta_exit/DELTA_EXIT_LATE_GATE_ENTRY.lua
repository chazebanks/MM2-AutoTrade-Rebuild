-- V15.8 unchanged trader; one late-GATE Delta Exit attempt on each join.
local e=(getgenv and getgenv()) or _G
local u="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/2dd41d38077fca5bb70edb3022358310d9b93516/pdiddler/pdiddler_V15_8_TELEPORT_AUTOBOOT_DELTA_EXIT_v3.lua"
e.PDIDDLER_V15_8_AUTOBOOT_URL=u
loadstring(game:HttpGet(u,true))()
