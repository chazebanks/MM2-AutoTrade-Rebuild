-- PDIDDLER V13 TELEPORT AUTO-REENTRY v1
-- Transport-only wrapper. V13 pricing/trading/bot checks/hopping are untouched.
-- Reads one immutable bootstrap URL passed by the initial short entry snippet.
-- Requeues that SAME immutable URL for each subsequent teleport when the
-- current executor exposes an actual queue-on-teleport API.
-- No arbitrary file writes, folder guesses, global teleport queue clears,
-- or in-game rapid polling. One bootstrap per JobId.

local ENV=(getgenv and getgenv()) or _G
local KEY="PDIDDLER_V13_TELEPORT_AUTOBOOT_v1"
local URL_KEY="PDIDDLER_V13_AUTOBOOT_URL"
local ROOT="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
local V13_SHA="3ba20eeade3fdeca08d58bc53c836ec36d0b1eec"
local V13_BASE=ROOT..V13_SHA.."/pdiddler/"
local BOOT_NAME="pdiddler_V13_TELEPORT_AUTOBOOT_v1.lua"

-- Never start pdiddler in a different Roblox game or an unready session.
local deadline=os.clock()+30
while (not game:IsLoaded() or tostring(game.JobId or "")=="") and os.clock()<deadline do
    task.wait(0.25)
end
if not game:IsLoaded() or tostring(game.JobId or "")=="" then
    warn("[PDIDDLER V13 AUTO] Game/JobId not ready; no execution")
    return
end
if game.PlaceId~=142823291 then
    return
end

local JOB=game.JobId
local old=ENV[KEY]
if type(old)=="table" and old.jobId==JOB and old.started==true then
    -- Important when Delta's built-in Auto Execute and queued teleport source
    -- both run: exactly ONE bootstrap attempts V13 per server.
    return old
end
for _,key in ipairs({"PDIDDLER_V12_TELEPORT_AUTOBOOT_v1","PDIDDLER_INTEGRATION_V12_PORTFOLIO_LEDGER",
    "PDIDDLER_V11_TELEPORT_AUTOBOOT_v1","PDIDDLER_INTEGRATION_V11_VERIFIED_READINESS",
    "PDIDDLER_V10_TELEPORT_AUTOBOOT_v1"}) do
    local legacy=ENV[key]
    if type(legacy)=="table" and legacy.jobId==JOB and (legacy.started or legacy.running or legacy.dirty) then
        warn("[PDIDDLER V13 AUTO] Existing build; rejoin before switching; no new queue")
        return legacy
    end
end
if ENV.PDIDDLER_OUTGOING_SESSION~=nil or ENV.PDIDDLER_PART4_SESSION~=nil
    or ENV.PDIDDLER_HOPPING_SESSION~=nil or ENV.PDIDDLER_PART5_CONTROLLER~=nil then
    warn("[PDIDDLER V13 AUTO] Existing subsystem; rejoin before switching; no new queue")
    return
end
local state={jobId=JOB,started=true,queueStatus="unknown",loaderStatus="starting"}
ENV[KEY]=state

local bootUrl=ENV[URL_KEY]
local prefix=ROOT
local suffix="/pdiddler/"..BOOT_NAME
local bootstrapSha=type(bootUrl)=="string"
    and bootUrl:sub(#prefix+1,#bootUrl-#suffix) or ""
if type(bootUrl)~="string" or bootUrl:sub(1,#prefix)~=prefix
    or bootUrl:sub(-#suffix)~=suffix
    or #bootstrapSha~=40 or not bootstrapSha:match("^[0-9a-f]+$") then
    state.started=false
    warn("[PDIDDLER V13 AUTO] Missing immutable bootstrap URL; re-run full entry snippet")
    return state
end

local queuer=queue_on_teleport or queueonteleport or queue_on_tp
    or queueontp or queueteleport or queue_for_teleport
if type(queuer)~="function" then
    local sy=(type(syn)=="table" and syn) or (type(ENV.syn)=="table" and ENV.syn)
    queuer=sy and sy.queue_on_teleport
end
if type(queuer)=="function" then
    -- No moving-branch URL: the queued bootstrap refers to the same commit
    -- as the initial entry, and each new execution queues the next hop.
    local quoted=string.format("%q",bootUrl)
    local reentry='local e=(getgenv and getgenv()) or _G; '..
        'local old=e.'..KEY..'; if type(old)=="table" and old.jobId==game.JobId '..
        'and old.started==true then return end; e.'..URL_KEY..
        '='..quoted..'; local deadline=os.clock()+30; '..
        'while not game:IsLoaded() and os.clock()<deadline do task.wait(0.25) end; '..
        'if game:IsLoaded() then local code=game:HttpGet('..quoted..
        ',true); local fn=assert(loadstring(code)); fn() end'
    local ok,result,why=pcall(queuer,reentry)
    if ok and result~=false then
        state.queueStatus="queued"
        print("[PDIDDLER V13 AUTO] Hop re-entry queued for the next server")
    else
        state.queueStatus="failed"
        warn("[PDIDDLER V13 AUTO] Queue rejected; use Delta built-in Auto Execute",tostring(why or result))
    end
else
    state.queueStatus="unsupported"
    warn("[PDIDDLER V13 AUTO] queue_on_teleport unavailable; enable Delta built-in Auto Execute for persistent hopping")
end

local function runPinned(filename)
    local url=V13_BASE..filename
    local source=game:HttpGet(url,true)
    assert(type(source)=="string" and #source>0,"empty source: "..filename)
    local fn,err=loadstring(source)
    assert(type(fn)=="function","compile failed: "..filename..": "..tostring(err))
    return fn()
end
local ok,err=pcall(function()
    runPinned("pdiddler_native_trade_probe_v1.lua")
    runPinned("pdiddler_FASTGATE_V6_INTEGRATED_TEST_v13_VISIBLE_READINESS.lua")
end)
if not ok then
    state.loaderStatus="failed"
    -- Keep the JobId claim even if launch fails; a same-job retry could
    -- otherwise stack another queued copy before the next teleport.
    warn("[PDIDDLER V13 AUTO] V13 loader failed; rejoin to retry:",tostring(err))
else
    state.loaderStatus="launched"
end
return state
