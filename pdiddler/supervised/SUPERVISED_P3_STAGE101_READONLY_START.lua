-- Minimal real MAIN iPad entrypoint for the immutable first native two-sided
-- Stage101 client-only identity research. No item-offer/final Accept code.
-- IMPORTANT: this loader prepares P3, which may request a trade with ALT
-- ONLY after MAIN physically taps ARM P3 in its non-overlapping panel.
local E=(type(getgenv)=="function" and getgenv()) or _G
if game.PlaceId~=142823291 or
   E.PDIDDLER_SUPERVISED_P3_NATIVE_OWNER~=nil or
   E.PDIDDLER_SUPERVISED_P3_USED_JOB==game.JobId or
   E.PDIDDLER_STAGE101_IDENTITY_USED_JOB==game.JobId or
   E.PDIDDLER_SUPERVISED_P3_AUTO_USED_JOB==game.JobId then
    warn("[P3 STAGE101] Fresh original MM2 MAIN game job required")
    return nil
end
E.PDIDDLER_P3_STAGE101_IDENTITY_NATIVE={
    enableNativeSupervisor=true,
    finalAcceptMustRemainManual=true,
    altOnlyTest=true,
    stage101IdentityReadOnly=true,
    targetName="venossgaming90190",
}
local url="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"..
 "bb065d00a62b904c298cfd08ff1d2a75a4b509b7/"..
 "pdiddler/supervised/SUPERVISED_P3_STAGE101_IDENTITY_NATIVE.lua"
local ok,runner=pcall(function()
    local source=game:HttpGet(url)
    if type(source)~="string" or #source<2000 or #source>90000 then
        error("FROZEN_STAGE101_NATIVE_SOURCE_MISSING")
    end
    return assert(loadstring(source))()
end)
if not ok or type(runner)~="table" then
    warn("[P3 STAGE101] Protected native identity runner unavailable. No requests authorized.")
    return nil
end
return runner
