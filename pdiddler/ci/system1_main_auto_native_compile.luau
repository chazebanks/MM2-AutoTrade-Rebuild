-- Offline Luau compilation without calling game/Roblox or performing any side effects.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local paths={
 "pdiddler/system1/SYSTEM1_MAIN_AUTO_FOUR_TRADES_NATIVE.lua",
 "pdiddler/system1/system1_main_auto_failstop_controller.lua",
 "pdiddler/system1/pdiddler3_outgoing_single_send_epoch.lua",
 "pdiddler/ci/system1_main_auto_failstop_mocks.luau",
}
local n=0
for _,path in ipairs(paths) do
 local src=fs.readFile(path)
 assert(type(src)=="string" and #src>100,"cannot read "..path)
 local ok,chunk=pcall(luau.load,src,{injectGlobals=true})
 assert(ok and type(chunk)=="function",
  "native compilation failed "..path.." | "..tostring(chunk))
 n+=1
end
print("SYSTEM1_MAIN_AUTO_NATIVE_LUAU_COMPILE_PASS",n)
