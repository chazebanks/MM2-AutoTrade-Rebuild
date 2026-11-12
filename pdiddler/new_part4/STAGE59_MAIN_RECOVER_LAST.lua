-- Stage59 LOCAL RECEIPT RECOVERY ONLY (RECEIVER).
-- Does not start any trade observer; reads an OPTIONAL previously archived
-- anonymous local report from this device's own executor sandbox.
-- Rejoining cannot recreate a past missing file. No account/game mutations.
local ROLE="RECEIVER"
local SOURCE="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"..
 "c9c9fe64bce6563f8580321f7a58073ed27ef0b7/pdiddler/new_part4/STAGE59_GUIDED_DUAL_CLIENT_WITNESS.lua"
local got,src=pcall(function()return game:HttpGet(SOURCE,true)end)
if not got or type(src)~="string" or #src<100 then
 warn("[STAGE59 RECOVERY] Source unavailable; no observer or file actions")
 return
end
if type(loadstring)~="function" then
 warn("[STAGE59 RECOVERY] loadstring unavailable; no observer started")
 return
end
local fn,why=loadstring(src,"=stage59-local-report-recovery")
if not fn then warn("[STAGE59 RECOVERY] Compile failed: "..tostring(why));return end
return fn(ROLE,"TABLET_RECOVER")
