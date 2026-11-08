-- STAGE59 ALT SENDER: read-only passive evidence.
-- Automatically chooses SENDER: no role-button selection needed.
-- Purple instructions remain visible IN-GAME and panel is draggable.
-- This script NEVER sends trade requests, adds offers, or accepts.
-- Both accounts must be in SAME MM2 server with Delta running on each.
local ROLE="SENDER"
local SOURCE="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"..
 "c9c9fe64bce6563f8580321f7a58073ed27ef0b7/pdiddler/new_part4/STAGE59_GUIDED_DUAL_CLIENT_WITNESS.lua"
if game.PlaceId~=142823291 then
 warn("[STAGE59 ALT] Wrong game: join original MM2 before executing")
 return
end
if type(loadstring)~="function" then
 warn("[STAGE59 ALT] Delta loadstring unavailable; no observer started")
 return
end
local ok,text=pcall(function()return game:HttpGet(SOURCE,true) end)
if not ok or type(text)~="string" or #text<100 then
 warn("[STAGE59 ALT] Unable to fetch pinned read-only observer")
 return
end
local fn,why=loadstring(text,"=STAGE59_ALT_SENDER")
if not fn then
 warn("[STAGE59 ALT] Observer compile failed: "..tostring(why))
 return
end
return fn(ROLE,"PHONE")
