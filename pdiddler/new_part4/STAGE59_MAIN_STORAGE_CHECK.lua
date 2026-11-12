-- Stage59 RECEIVER TABLET: NO-TRADE LOCAL STORAGE CHECK.
-- Run once, leave/rejoin, run again; compare previous/current ID.
-- Must NOT be used as evidence of a completed trade.
local SOURCE="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"..
 "0268cee1259e05f40f36cd160f0c9472a7397912/pdiddler/new_part4/STAGE59_LOCAL_STORAGE_CHECK.lua"
local ok,src=pcall(function()return game:HttpGet(SOURCE,true)end)
if not ok or type(src)~="string" or #src<100 then
 warn("[STAGE59 STORAGE] Check source unavailable");return
end
if type(loadstring)~="function" then
 warn("[STAGE59 STORAGE] No executor loadstring");return
end
local runner,why=loadstring(src,"=stage59-storage-check")
if not runner then
 warn("[STAGE59 STORAGE] Compile failed: "..tostring(why));return
end
local entry=runner()
if type(entry)~="function" then
 warn("[STAGE59 STORAGE] Invalid runner");return
end
return entry("RECEIVER","TABLET")
