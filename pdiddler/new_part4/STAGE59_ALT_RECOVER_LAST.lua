-- Stage59 LOCAL RECEIPT RECOVERY ONLY (SENDER).
-- Does not start any trade observer; reads an OPTIONAL previously archived
-- anonymous local report from this device's own executor sandbox.
-- Rejoining cannot recreate a past missing file. No account/game mutations.
local ROLE="SENDER"
local SOURCE="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"..
 "bb70922e06c76233a3e962d4d97a9783bb70f39b/pdiddler/new_part4/STAGE59_GUIDED_DUAL_CLIENT_WITNESS.lua"
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
return fn(ROLE,"PHONE_RECOVER")
