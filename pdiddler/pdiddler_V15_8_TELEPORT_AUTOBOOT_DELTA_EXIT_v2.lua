-- PDIDDLER V15_8 TELEPORT AUTO-REENTRY + DELTA EXIT v2
-- Retains the V15.8 transport and all pinned trading modules; adds one Delta Exit tap per hop.
-- Reads one immutable bootstrap URL passed by the initial short entry snippet.
-- Requeues that SAME immutable URL for each subsequent teleport when the
-- current executor exposes an actual queue-on-teleport API.
-- No arbitrary file writes, folder guesses, global teleport queue clears,
-- or in-game rapid polling. One bootstrap per JobId.

local ENV=(getgenv and getgenv()) or _G
local KEY="PDIDDLER_V15_8_TELEPORT_AUTOBOOT_v1"
local URL_KEY="PDIDDLER_V15_8_AUTOBOOT_URL"
local ROOT="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
local V15_8_SHA="3daded63893a9165ad6b2a65fcbbf507f1afc571"
local V15_8_BASE=ROOT..V15_8_SHA.."/pdiddler/"
local BOOT_NAME="pdiddler_V15_8_TELEPORT_AUTOBOOT_DELTA_EXIT_v2.lua"

-- Never start pdiddler in a different Roblox game or an unready session.
local deadline=os.clock()+30
while (not game:IsLoaded() or tostring(game.JobId or "")=="") and os.clock()<deadline do
    task.wait(0.25)
end
if not game:IsLoaded() or tostring(game.JobId or "")=="" then
    warn("[PDIDDLER V15_8 AUTO] Game/JobId not ready; no execution")
    return
end
if game.PlaceId~=142823291 then
    return
end

local JOB=game.JobId
local old=ENV[KEY]
if type(old)=="table" and old.jobId==JOB and old.started==true then
    -- Important when Delta's built-in Auto Execute and queued teleport source
    -- both run: exactly ONE bootstrap attempts V15_8 per server.
    return old
end
for _,key in ipairs({"PDIDDLER_V15_5_TELEPORT_AUTOBOOT_v1","PDIDDLER_INTEGRATION_V15_5_SCANNER_EVIDENCE","PDIDDLER_V15_6_TELEPORT_AUTOBOOT_v1","PDIDDLER_INTEGRATION_V15_6_IMMEDIATE_SAFETY","PDIDDLER_V15_7_TELEPORT_AUTOBOOT_v1","PDIDDLER_INTEGRATION_V15_7_INVENTORY_GROWTH","PDIDDLER_V15_4_TELEPORT_AUTOBOOT_v1","PDIDDLER_INTEGRATION_V15_4_REACHABLE","PDIDDLER_V15_3_TELEPORT_AUTOBOOT_v1","PDIDDLER_INTEGRATION_V15_3_GUI_STATUS","PDIDDLER_V15_2_TELEPORT_AUTOBOOT_v1","PDIDDLER_INTEGRATION_V15_2_HEADLESS_GATE","PDIDDLER_V15_1_TELEPORT_AUTOBOOT_v1","PDIDDLER_INTEGRATION_V15_1_CURRENT_PRICES","PDIDDLER_V15_TELEPORT_AUTOBOOT_v1","PDIDDLER_INTEGRATION_V15_OPPONENT_ADDED","PDIDDLER_V14_TELEPORT_AUTOBOOT_v1","PDIDDLER_INTEGRATION_V14_VERIFIED_WORKFLOW","PDIDDLER_V13_TELEPORT_AUTOBOOT_v1","PDIDDLER_INTEGRATION_V13_VISIBLE_READINESS","PDIDDLER_V12_TELEPORT_AUTOBOOT_v1","PDIDDLER_INTEGRATION_V12_PORTFOLIO_LEDGER",
    "PDIDDLER_V11_TELEPORT_AUTOBOOT_v1","PDIDDLER_INTEGRATION_V11_VERIFIED_READINESS",
    "PDIDDLER_V10_TELEPORT_AUTOBOOT_v1"}) do
    local legacy=ENV[key]
    if type(legacy)=="table" and legacy.jobId==JOB and (legacy.started or legacy.running or legacy.dirty) then
        warn("[PDIDDLER V15_8 AUTO] Existing build; rejoin before switching; no new queue")
        return legacy
    end
end
if ENV.PDIDDLER_OUTGOING_SESSION~=nil or ENV.PDIDDLER_PART4_SESSION~=nil
    or ENV.PDIDDLER_HOPPING_SESSION~=nil or ENV.PDIDDLER_PART5_CONTROLLER~=nil then
    warn("[PDIDDLER V15_8 AUTO] Existing subsystem; rejoin before switching; no new queue")
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
    warn("[PDIDDLER V15_8 AUTO] Missing immutable bootstrap URL; re-run full entry snippet")
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
    -- Only the public immutable loader URL enters the teleport queue.
    -- Private configuration must be supplied separately by the executor user.
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
        print("[PDIDDLER V15_8 AUTO] Hop re-entry queued for the next server")
    else
        state.queueStatus="failed"
        warn("[PDIDDLER V15_8 AUTO] Queue rejected; use Delta built-in Auto Execute")
    end
else
    state.queueStatus="unsupported"
    warn("[PDIDDLER V15_8 AUTO] queue_on_teleport unavailable; enable Delta built-in Auto Execute for persistent hopping")
end


-- One verified coordinate tap per fresh JobId during P1's normal 10s GATE.
-- This lives INSIDE the same bootstrap that queues itself on teleport.
-- It fixes a one-time outer Auto Execute wrapper being lost after hopping.
-- Input is the same successful iPad Delta Exit attempt: (1477,816)/1536x1067.
-- No part 1/2/3/4/5 trading module is edited.
task.spawn(function()
    local tapDeadline=os.clock()+90
    while game.JobId==JOB and os.clock()<tapDeadline do
        local owner=ENV.PDIDDLER_INTEGRATION_V15_8_VALUE_FIRST
        if type(owner)=="table" and owner.jobId==JOB and owner.stage=="GATE" then
            if ENV.PDIDDLER_DELTA_EXIT_TAPPED_JOB==JOB then return end
            task.wait(0.5)
            if game.JobId~=JOB or owner.stage~="GATE" then return end
            local camera=workspace.CurrentCamera
            local size=camera and camera.ViewportSize
            if not size or size.X<400 or size.Y<300 then
                warn("[PDIDDLER DELTA EXIT] No valid viewport; skipped")
                return
            end
            local ratio=size.X/size.Y
            if ratio<1.35 or ratio>1.55 then
                warn("[PDIDDLER DELTA EXIT] Unexpected orientation; skipped")
                return
            end
            local x=math.floor(size.X*(1477/1536)+0.5)
            local y=math.floor(size.Y*(816/1067)+0.5)
            ENV.PDIDDLER_DELTA_EXIT_TAPPED_JOB=JOB
            local vim=game:GetService("VirtualInputManager")
            local down,why=pcall(function()
                vim:SendMouseButtonEvent(x,y,0,true,game,0)
            end)
            if not down then
                warn("[PDIDDLER DELTA EXIT] Touch rejected: "..tostring(why))
                return
            end
            task.wait(0.10)
            local up,whyUp=pcall(function()
                vim:SendMouseButtonEvent(x,y,0,false,game,0)
            end)
            if not up then
                warn("[PDIDDLER DELTA EXIT] Touch release rejected: "..tostring(whyUp))
            else
                print("[PDIDDLER DELTA EXIT] Attempted once for JobId at",x,y)
            end
            return
        end
        task.wait(0.15)
    end
end)

local function runPinned(filename)
    local url=V15_8_BASE..filename
    local source=game:HttpGet(url,true)
    assert(type(source)=="string" and #source>0,"empty source: "..filename)
    local fn,err=loadstring(source)
    assert(type(fn)=="function","compile failed: "..filename..": "..tostring(err))
    return fn()
end
local ok,err=pcall(function()
    runPinned("pdiddler_native_trade_probe_v2.lua")
    runPinned("pdiddler_INTEGRATED_v15_8_VALUE_FIRST.lua")
end)
if not ok then
    state.loaderStatus="failed"
    -- Keep the JobId claim even if launch fails; a same-job retry could
    -- otherwise stack another queued copy before the next teleport.
    warn("[PDIDDLER V15_8 AUTO] V15_8 loader failed; rejoin to retry:",tostring(err))
else
    state.loaderStatus="launched"
end
return state
