local fs=require("@lune/fs")
local luau=require("@lune/luau")
local scripts={
 "pdiddler/system1/system1_step2_public_target_gate.lua",
 "pdiddler/system1/system1_step2_public_p3_single_send.lua",
 "pdiddler/system1/system1_step2_public_handoff_controller.lua",
 "pdiddler/system1/SYSTEM1_STEP2_PUBLIC_P3P4_NATIVE.lua",
}
for _,path in ipairs(scripts)do
 local content=fs.readFile(path)
 local okay,compiler=pcall(luau.load,content)
 assert(okay and type(compiler)=="function",
  "Step2 Luau source fails compilation: "..path.." | "..tostring(compiler))
end
print("SYSTEM1_STEP2_PUBLIC_SOURCE_COMPILE_PASS",#scripts)
