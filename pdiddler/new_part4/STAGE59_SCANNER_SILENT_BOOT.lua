-- Stage59 scanner-only bootstrap fork, no independent clipboard diagnostic.
-- Reuses the existing Stage24 Part3 scanner, repricer and presentation.
-- Does not instantiate P3 outgoing, Part4, P5 hopper, Accept, Discord or
-- any economic permit. Do NOT inject into an already running pdiddler stack.
-- Scanner itself reads MM2 inventory and displays existing GUI; no trade RPC.
-- Original November4 profile remains EXPIRED, and must never become a quote.
local E=(getgenv and getgenv()) or _G
local KEY="PDIDDLER_STAGE25_SCANNER_ONLY"
local JOB=game.JobId
if E.PDIDDLER_ALLOW_SCANNER_ONLY_TEST~=true then
    warn("[GINGERSCOPE STAGE25] scanner-only test not armed; no actions")
    return nil
end
if game.PlaceId~=142823291 then
    warn("[GINGERSCOPE STAGE25] wrong game; no actions")
    return nil
end
local old=E[KEY]
if type(old)=="table" and old.jobId==JOB then
    warn("[GINGERSCOPE STAGE25] scanner already loaded or partially initialized; rejoin to reset")
    return old
end
for _,name in ipairs({
    "PDIDDLER_GINGERSCOPE_REPLACEMENT_PREVIEW",
    "PDIDDLER_INTEGRATION_V15_8_VALUE_FIRST",
    "PDIDDLER_INTEGRATION_V15_7_INVENTORY_GROWTH",
    "PDIDDLER_INTEGRATION_V15_6_IMMEDIATE_SAFETY",
    "PDIDDLER_PART4_CONTROLLER",
    "PDIDDLER_PART5_CONTROLLER",
    "PDIDDLER_OUTGOING_CONTROLLER",
    "PDIDDLER_OUTGOING_SESSION",
    "PDIDDLER_PART4_SESSION",
    "PDIDDLER_HOPPING_SESSION",
}) do
    if E[name]~=nil then
        warn("[GINGERSCOPE STAGE25] another stack/session exists; rejoin to test in isolation")
        return nil
    end
end
local ROOT="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
local PINS={
    profile={"snapshots/pdiddler_supreme_snapshot_2026_11_06.lua",
        "d9d7970f281f725ff21d1a409495fcc197e3d2dc"},
    strict={"new_part4/P4_REPRICE_ONLY.lua",
        "daf42166b9a713b69b0a8c93708ff13e86b36283"},
    scannerView={"presentation/pdiddler3_scanner_view_v1.lua",
        "0230ed1481768e7b8ddfee87e9022f6d27462674"},
    scanner={"presentation/pdiddler3_scanner_MODULE_v6_10_CURRENT_PRESENTATION.lua",
        "001d228a407076d3cc411a5a7132b0076ec4c027"},
}
local S={jobId=JOB,status="LOADING_SCANNER_ONLY",dirty=true,
    authorizesTrade=false,authorizesAccept=false,
    noOutgoing=true,noHopping=true,marketFresh=false}
E[KEY]=S
local function fetchAndRun(name,...)
    local row=assert(PINS[name],"unknown permitted module")
    local url=ROOT..row[2].."/pdiddler/"..row[1]
    local source=game:HttpGet(url,true)
    assert(type(source)=="string" and #source>40,
        "scanner-only source missing: "..name)
    local fn,why=loadstring(source,"="..name)
    assert(fn,why)
    return assert(fn(...),"scanner-only module invalid: "..name)
end
local ok,why=pcall(function()
    local profile=fetchAndRun("profile")
    assert(type(profile)=="table" and type(profile.isFresh)=="function"
        and type(profile.coverage)=="function"
        and profile.coverage().total==190,
        "existing dated profile invalid")
    -- The dated profile's OWN SOURCE clock is authoritative: never
    -- override isFresh or change its original expiresAtEpoch.
    local current=profile.isFresh()
    S.profile=profile
    S.marketFresh=(current==true)
    local reprice=fetchAndRun("strict")
    local view=fetchAndRun("scannerView")
    assert(type(reprice)=="table" and type(reprice.reprice)=="function")
    assert(type(view)=="table" and type(view.inventory)=="function")
    S.rawScanner=fetchAndRun("scanner",profile,reprice,view)
    assert(type(S.rawScanner)=="table"
        and type(S.rawScanner.getRecord)=="function"
        and type(S.rawScanner.getVerificationState)=="function",
        "existing scanner cache API unavailable")
    S.status="SCANNER_ONLY_NO_TRADE_AUTHORITY"
    S.dirty=false
end)
if not ok then
    S.status="PARTIAL_INITIALIZATION_REJOIN_REQUIRED"
    S.failure="scanner-only module did not initialize"
    warn("[GINGERSCOPE STAGE25] initialization blocked; rejoin before retry")
    return S
end
-- STAGE59-ONLY silent scanner fork. Stage25 test boot scheduled an independent
-- scanner diagnostic which changed the OS clipboard asynchronously. A shared
-- iPhone/iPad clipboard can overwrite the other device's Stage59 witness.
-- Keep verified scanner cache, eliminate that unrelated output entirely.
S.probeStatus="STAGE59_DIAGNOSTIC_AUTO_COPY_DISABLED"
print("[GINGERSCOPE STAGE59 SCANNER] Existing read-only scanner available; no unsolicited report export; marketFresh="..
 tostring(S.marketFresh).." | NO TRADING")
return S
