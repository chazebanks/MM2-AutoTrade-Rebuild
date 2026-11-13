local fs=require("@lune/fs")
local luau=require("@lune/luau")
local files={
 "pdiddler/system1/system1_one_server_transition_controller.lua",
 "pdiddler/system1/SYSTEM1_ONE_SERVER_COMBINED_NATIVE.lua",
 "pdiddler/system1/SYSTEM1_COMBINED_STEP2_BOUND_EPOCH_NATIVE.lua",
}
for _,path in ipairs(files)do
 local src=fs.readFile(path)
 local yes,compiled=pcall(luau.load,src)
 assert(yes and type(compiled)=="function",
  "Combined Luau compile failed "..path.." "..tostring(compiled))
end
print("SYSTEM1_ONE_SERVER_LUAU_COMPILE_PASS",#files)
