-- Stage73: isolated SCANNER-ONLY historical-reference view smoke test.
-- Identical existing safe scanner, strict stale profile, and NO trading loader.
-- Adds only a separate read-only historical source-name reference annotation.
-- Never converts historical prices to current/verified or enables outgoing.
-- A fresh original MM2 server is required; do not run atop any other bot.
local E=(getgenv and getgenv()) or _G
local KEY="PDIDDLER_STAGE25_SCANNER_ONLY"
local JOB=game.JobId
-- Explicit execution of this isolated read-only loader is the operator
-- authorization to display local references. No trading action is possible.
if game.PlaceId~=142823291 then
    warn("[GINGERSCOPE STAGE73] wrong game; no actions")
    return nil
end
local old=E[KEY]
if type(old)=="table" and old.jobId==JOB then
    warn("[GINGERSCOPE STAGE73] scanner already loaded or partially initialized; rejoin to reset")
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
    "PDIDDLER_STAGE63_SAME_WINDOW_CLIENT_ONLY",
    "PDIDDLER_STAGE66_SAME_WINDOW_CLIENT_ONLY",
    "PDIDDLER_STAGE68_CLIENT_RUN_ONLY",
}) do
    if E[name]~=nil then
        warn("[GINGERSCOPE STAGE73] another stack/session exists; rejoin to test in isolation")
        return nil
    end
end
local ROOT="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
local PINS={
    profile={"snapshots/pdiddler_supreme_snapshot_2026_11_06.lua",
        "d9d7970f281f725ff21d1a409495fcc197e3d2dc"},
    strict={"new_part4/P4_REPRICE_ONLY.lua",
        "daf42166b9a713b69b0a8c93708ff13e86b36283"},
    historical={"intelligence_lab/stage72_historical_reference_preview.lua",
        "a10d80a086b644085a9cffd87c1f5ce0489597bc"},
    scannerView={"presentation/pdiddler3_scanner_view_stage73_history_v1.lua",
        "8a5604bd2b44eb27293b134ed1a78382fe5b4048"},
    scanner={"presentation/pdiddler3_scanner_MODULE_v6_10_CURRENT_PRESENTATION.lua",
        "001d228a407076d3cc411a5a7132b0076ec4c027"},
    probe={"new_part4/STAGE25_READONLY_DIAGNOSTIC.lua",
        "cd8ed9ca5cdc73d98af93059df6b189dcd0a93bc"},
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
    assert(current~=true,
        "Stage73 historical preview must not replace a fresh-price renderer")
    S.profile=profile
    S.marketFresh=(current==true)
    local reprice=fetchAndRun("strict")
    local historical=fetchAndRun("historical")
    assert(type(historical)=="table" and type(historical.preview)=="function")
    local preview=historical.preview({items={}},profile)
    assert(type(preview)=="table" and preview.outgoingPaused==true
       and preview.totalText=="UNVERIFIED"
       and preview.authorizesTrade==false
       and preview.authorizesAccept==false,
       "historical preview would weaken trading gate")
    local view=fetchAndRun("scannerView",historical)
    assert(type(reprice)=="table" and type(reprice.reprice)=="function")
    assert(type(view)=="table" and type(view.inventory)=="function")
    S.historicalPreviewOnly=true
    S.rawScanner=fetchAndRun("scanner",profile,reprice,view)
    assert(type(S.rawScanner)=="table"
        and type(S.rawScanner.getRecord)=="function"
        and type(S.rawScanner.getVerificationState)=="function",
        "existing scanner cache API unavailable")
    S.status="STAGE73_SCANNER_HISTORY_ONLY_NO_TRADE_AUTHORITY"
    S.dirty=false
end)
if not ok then
    S.status="PARTIAL_INITIALIZATION_REJOIN_REQUIRED"
    S.failure="scanner-only module did not initialize"
    warn("[GINGERSCOPE STAGE73] initialization blocked; rejoin before retry")
    return S
end
-- One diagnostic output only, after the existing scanner's initial
-- records settle or the bounded evidence window closes. No second scanner,
-- additional MM2 inventory read, outgoing request, or server hop is started.
S.probeStatus="AWAITING_STABLE_SCANNER_CACHE"
task.spawn(function()
    local start=os.clock()
    local duration=45
    while E[KEY]==S and game.JobId==JOB and os.clock()-start<duration do
        local ready=true
        local players=game:GetService("Players")
        for _,p in ipairs(players:GetPlayers()) do
            if p~=players.LocalPlayer then
                local yes,state=pcall(S.rawScanner.getVerificationState,p.UserId)
                if not yes or type(state)~="table" or state.scanning==true
                    or state.retryScheduled==true or
                    type(state.record)~="table" then
                    ready=false
                    break
                end
            end
        end
        if ready and os.clock()-start>=1.5 then break end
        task.wait(0.3)
    end
    if E[KEY]~=S or game.JobId~=JOB
       or E.PDIDDLER_OUTGOING_SESSION~=nil
       or E.PDIDDLER_PART4_SESSION~=nil then
        S.probeStatus="ABORTED_SESSION_CHANGED"
        return
    end
    local reportOK=pcall(fetchAndRun,"probe")
    S.probeStatus=reportOK and "ONE_REPORT_CAPTURED" or "REPORT_UNAVAILABLE"
    if not reportOK then
        warn("[GINGERSCOPE STAGE73] read-only report unavailable; no trade actions")
    end
end)
print("[GINGERSCOPE STAGE73] Existing scanner running READ-ONLY with historical UNVERIFIED annotations; marketFresh="
    ..tostring(S.marketFresh)
    .." | One anonymized report will be copied after scan | NO TRADING")
return S
