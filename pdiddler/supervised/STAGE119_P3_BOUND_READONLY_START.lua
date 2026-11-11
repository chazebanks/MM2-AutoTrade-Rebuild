-- Stage119 V2 actual MAIN iPad loader. Unlike PR225, this preserves the
-- original successful PR221 protected P3 ARM + P4 bound client lease.
-- No request until MAIN physically taps ARM P3 on the purple panel.
local E=(type(getgenv)=="function" and getgenv()) or _G
if game.PlaceId~=142823291 or
   E.PDIDDLER_SUPERVISED_P3_NATIVE_OWNER~=nil or
   E.PDIDDLER_SUPERVISED_P3_USED_JOB==game.JobId or
   E.PDIDDLER_STAGE101_IDENTITY_USED_JOB==game.JobId or
   E.PDIDDLER_STAGE119_P3_USED_JOB==game.JobId or
   E.PDIDDLER_STAGE119_LASTOFFER_OWNER~=nil or
   E.PDIDDLER_STAGE119_LASTOFFER_USED_JOB==game.JobId or
   E.PDIDDLER_SUPERVISED_P3_AUTO_USED_JOB==game.JobId or
   E.PDIDDLER_OUTGOING_SESSION~=nil or
   E.PDIDDLER_PART4_SESSION~=nil or
   E.PDIDDLER_OUTGOING_CONTROLLER_ACTIVE==true or
   E.PDIDDLER_PART4_CONTROLLER_ACTIVE==true or
   E.PDIDDLER_AUTOTRADE_ACTIVE==true then
    warn("[STAGE119 P3] Fresh original MM2 MAIN job and no other P3/P4 script required")
    return nil
end
E.PDIDDLER_P3_STAGE119_LASTOFFER_NATIVE={
    enableNativeSupervisor=true,
    finalAcceptMustRemainManual=true,
    altOnlyTest=true,
    stage119LastOfferReadOnly=true,
    targetName="venossgaming90190"
}
local ok,source=pcall(function()
 return game:HttpGet("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/0e8e88fba07d72a7e1fb51178e0b105c3a647568/pdiddler/supervised/STAGE119_P3_BOUND_READONLY_NATIVE.lua")
end)
if not ok or type(source)~="string" or #source<30000 or
   #source>90000 then
    warn("[STAGE119 P3] Frozen tested native source unavailable")
    return nil
end
local compiler=loadstring or load
if type(compiler)~="function" then return nil end
local success,result=pcall(function()return assert(compiler(source))()end)
if not success then
    warn("[STAGE119 P3] Protected native startup failed; no trade authorized")
    return nil
end
return result
