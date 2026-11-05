-- One entry only. Replaces the old Delta Exit wrapper / V15.8 Auto Execute.
-- Same V15.8 trader; the one-shot exit tap now survives teleport re-entry.
local e=(getgenv and getgenv()) or _G
local u="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/a1b947d5f4c0984ad4091f0ac099577ed24dc94f/pdiddler/pdiddler_V15_8_TELEPORT_AUTOBOOT_DELTA_EXIT_v2.lua"
e.PDIDDLER_V15_8_AUTOBOOT_URL=u
loadstring(game:HttpGet(u,true))()
