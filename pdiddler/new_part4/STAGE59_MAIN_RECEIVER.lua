-- STAGE59 MAIN RECEIVER: read-only passive evidence.
-- Automatically chooses RECEIVER: no role-button selection needed.
-- Purple instructions remain visible IN-GAME and panel is draggable.
-- This script NEVER sends trade requests, adds offers, or accepts.
-- Both accounts must be in SAME MM2 server with Delta running on each.
local ROLE="RECEIVER"
local SOURCE="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"..
 "2df50ba19889e880eae1ac313b8b4ed9f36a0c01/pdiddler/new_part4/STAGE59_GUIDED_DUAL_CLIENT_WITNESS.lua"
if game.PlaceId~=142823291 then
 warn("[STAGE59 MAIN] Wrong game: join original MM2 before executing")
 return
end
if type(loadstring)~="function" then
 warn("[STAGE59 MAIN] Delta loadstring unavailable; no observer started")
 return
end
local ok,text=pcall(function()return game:HttpGet(SOURCE,true) end)
if not ok or type(text)~="string" or #text<100 then
 warn("[STAGE59 MAIN] Unable to fetch pinned read-only observer")
 return
end
local fn,why=loadstring(text,"=STAGE59_MAIN_RECEIVER")
if not fn then
 warn("[STAGE59 MAIN] Observer compile failed: "..tostring(why))
 return
end
return fn(ROLE,"TABLET")
