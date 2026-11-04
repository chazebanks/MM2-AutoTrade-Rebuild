-- V13 supervised loader. Bounded visible-branch readiness; all V12 trading modules preserved.
-- Native automatic acceptance and completion/webhook reporting remain disabled.
-- One bootstrap/monitor; only P5 transports. Final trade acceptance stays disabled.
local E=(getgenv and getgenv()) or _G
local KEY="PDIDDLER_INTEGRATION_V13_VISIBLE_READINESS"
local JOB=game.JobId
local prior=E[KEY]
if type(prior)=="table" and prior.jobId==JOB and (prior.running or prior.dirty) then
    warn("[PDIDDLER V13_VISIBLE_READINESS] HOLD | existing owner or partial initialization; rejoin if stopped")
    return prior
end
-- Never steal sessions from an older stack or an independent outgoing owner.
for _,key in ipairs({"PDIDDLER_INTEGRATION_V1","PDIDDLER_INTEGRATION_V2","PDIDDLER_INTEGRATION_V3","PDIDDLER_INTEGRATION_V4_SUPREME","PDIDDLER_INTEGRATION_V5_ADAPTIVE","PDIDDLER_INTEGRATION_V6_FINAL_WAIT","PDIDDLER_INTEGRATION_V7_DELAYED_SWEETEN","PDIDDLER_INTEGRATION_V8_VISIBLE_ACCEPT","PDIDDLER_INTEGRATION_V9_EARLY_COUNTER","PDIDDLER_INTEGRATION_V10_BOUNDED_SELECTION","PDIDDLER_INTEGRATION_V11_VERIFIED_READINESS","PDIDDLER_INTEGRATION_V12_PORTFOLIO_LEDGER"}) do
    local old=E[key]
    if type(old)=="table" and old.jobId==JOB then
        warn("[PDIDDLER V13_VISIBLE_READINESS] HOLD | legacy integration present; rejoin first")
        return old
    end
end
if E.PDIDDLER_OUTGOING_SESSION~=nil or E.PDIDDLER_PART4_SESSION~=nil
    or E.PDIDDLER_HOPPING_SESSION~=nil or E.PDIDDLER_PART5_CONTROLLER~=nil then
    warn("[PDIDDLER V13_VISIBLE_READINESS] HOLD | subsystem already initialized; rejoin first")
    return
end
local I={capabilities={autoAccept=false,completion=false,discord=false,stackedSlots=false},blockers={autoAccept="native final control/cooldown sequence unproved",completion="native boolean event lacks transaction identity; full raw inventory reconciliation unproved",discord="verified completion and persistent outbox adapter unavailable",stackedSlots="native slot/quantity behavior unproved"},running=true,dirty=false,jobId=JOB,stage="BOOT",reason="starting",lastDecision="PROCEED_UNVERIFIED"}
E[KEY]=I
local Players=game:GetService("Players")
local LP
local workerGui
local tasks={}
local function live() return I.running and E[KEY]==I and game.JobId==JOB end
local function phase(stage,reason)
    if I.stage~=stage or I.reason~=reason then
        I.stage=stage; I.reason=reason
        print("[PDIDDLER V13_VISIBLE_READINESS] "..stage.." | "..tostring(reason))
    end
end
local function cancel(co)
    if co and type(task.cancel)=="function" then pcall(task.cancel,co) end
end
local function cleanup()
    for co in pairs(tasks) do cancel(co) end
    if I.gateGeneration and E.PDIDDLER_FAST_GATE_GEN==I.gateGeneration then
        if type(E.PDIDDLER_FAST_GATE_STOP)=="function" then pcall(E.PDIDDLER_FAST_GATE_STOP) end
        E.PDIDDLER_FAST_GATE_GEN=I.gateGeneration+1
    end
    for _,controller in ipairs({I.outgoing or false,I.part4 or false}) do
        if controller and type(controller.stop)=="function" then pcall(controller.stop) end
    end
    -- Frozen scanner has background listeners and no stop API. Dirty lock persists.
    -- Do not cancel/replace P5 while Roblox may still be processing its teleport.
    if I.hopper and not I.hopper.state.hopping then pcall(I.hopper.stop,I.hopper) end
end
local function fail(reason)
    I.error=tostring(reason); I.running=false
    phase("ERROR",I.error..(I.dirty and "; rejoin before rerun" or "; clean retry permitted"))
    cleanup()
end
function I:stop()
    if not live() then return end
    self.running=false; phase("STOPPED","manual stop"); cleanup()
end
-- Separate success flag: a successful module may return nil (Fast Gate V5).
-- Timeout cancels the yielding caller, never re-executes side-effecting code.
local function bounded(label,seconds,fn)
    local done,ok,value=false,false,nil
    local co=task.spawn(function()
        ok,value=pcall(fn)
        done=true
    end)
    tasks[co]=true
    local deadline=os.clock()+seconds
    while live() and not done and os.clock()<deadline do task.wait(.05) end
    tasks[co]=nil
    if not live() then cancel(co); error(label..":stale",0) end
    if not done then cancel(co); error(label..":timeout",0) end
    if not ok then error(label..":"..tostring(value),0) end
    if workerGui and LP:FindFirstChildOfClass("PlayerGui")~=workerGui then
        if type(value)=="table" and type(value.stop)=="function" then pcall(value.stop) end
        error("worker PlayerGui replaced during "..label.."; rejoin",0)
    end
    return value
end
local ROOT="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
local PINS={
    readiness={"pdiddler_readiness_v2_VISIBLE_SCAN.lua","8144fd2dc9b1a446c336adeeea8dfd6139a7aab3"},
    profile={"pdiddler_supreme_snapshot_2026_11_03_ISSUE4.lua","7ecd5b44b30f513a16061f0cb92476cb8cd2e6fa"},
    strict={"pdiddler4_supreme_policy_v8_PORTFOLIO_LEDGER.lua","a8b2e1641297678a51cb2ed04fe0932830b4a22d"},
    p2={"pdiddler2_KNOWN_GOOD.lua","b097c1862db4cff7394d6a5e6764d34191df3283"},
    gate={"pdiddler1_fast_gate_TEST_v6_VALID_EVIDENCE.lua","962dcafe2b5c535ed7c94293ebb812693404d4e7"},
    scanner={"pdiddler3_scanner_MODULE_v6_8_CRITICAL_PAUSE.lua","3c48b49c1e750d91bfbf088fbc737185bddf39be"},
    p4={"pdiddler4_balancer_SUPREME_v7_PORTFOLIO_LEDGER.lua","a8b2e1641297678a51cb2ed04fe0932830b4a22d"},
    early={"pdiddler4_early_counter_policy_v3_TRADE_BUDGET.lua","a8b2e1641297678a51cb2ed04fe0932830b4a22d"},
    acceptGate={"pdiddler4_accept_ui_gate_v1.lua","55c5b4a46c26294f3d97ba61dfd43fadd4f07d02"},
    outgoing={"pdiddler3_outgoing_ROTATING_v16_EXACT_IDENTITY.lua","c37c6db25a01f3c12cac98e46a1a9aedab64f675"},
    policy={"pdiddler5_server_hopper_policy_v1.lua","3be1c15f435389ff518cf3a4594b34efc08e84de"},
    transport={"pdiddler5_server_hopper_v2.lua","a20e96fff663e42e50bf668d5be5c7b148a70b9e"},
}
local function fetch(key)
    local pin=assert(PINS[key])
    phase("FETCH",key)
    local url=ROOT..pin[2].."/pdiddler/"..pin[1]
    local source,lastError
    for attempt=1,2 do
        local ok,result=pcall(function() return bounded(key.." fetch",14,function() return game:HttpGet(url,true) end) end)
        if ok and type(result)=="string" and result~="" then source=result; break end
        lastError=result
        if not live() then error("fetch stale",0) end
        if attempt==1 then task.wait(.5) end
    end
    if not source then error(key.." fetch failed:"..tostring(lastError),0) end
    local fn,err=loadstring(source,"="..pin[1])
    if not fn then error(key.." compile:"..tostring(err),0) end
    return fn
end
local function module(key,seconds,sideEffects)
    local fn=fetch(key)
    if sideEffects then I.dirty=true end
    phase("INITIALIZE",key)
    return bounded(key.." execute",seconds,fn)
end
local function api(value,label,methods)
    assert(type(value)=="table",label.." missing API")
    for _,name in ipairs(methods) do assert(type(value[name])=="function",label.." missing "..name) end
    return value
end
local function roster()
    local ids={}
    for _,p in ipairs(Players:GetPlayers()) do if p~=LP then ids[#ids+1]=tostring(p.UserId) end end
    table.sort(ids); return table.concat(ids,",")
end
local function visible(node)
    local c=node
    while c do
        if c:IsA("ScreenGui") and not c.Enabled then return false end
        if c:IsA("GuiObject") and not c.Visible then return false end
        c=c.Parent
    end
    return true
end
local function requestFrames(pg) return I.readiness.requestFrames(pg) end
local function automationReady(force)
    if I.blocked then return false,"integration-held" end
    if not I.readiness then return false,"readiness-unavailable" end
    if force or not I.readinessAt or os.clock()-I.readinessAt>=.1 then
        I.readinessState=I.readiness.read(game,LP);I.readinessAt=os.clock()
    end
    local snapshot=I.readinessState
    if workerGui and snapshot.playerGui~=workerGui then return false,"worker-player-gui-replaced" end
    return snapshot.ready==true,snapshot.reason
end
local function holdOutcome(reason)
    I.blocked=true
    if I.outgoing then I.outgoing.stop() end
    if I.hopper and not I.hopper.state.hopping then I.hopper:stop() end
    phase("OUTCOME_HOLD",tostring(reason).."; completion/Discord OFF; inspect inventory and rejoin")
end
local function awaitReadiness(seconds)
    local lastSampleReason
    local ok,last=I.readiness.wait(game,LP,{timeout=seconds,live=live,onSample=function(snapshot)
        I.readinessState=snapshot;I.readinessAt=os.clock()
        local reason=snapshot.reason..(snapshot.loading and " | "..snapshot.loading.path or "")
        if reason~=lastSampleReason then
            lastSampleReason=reason
            local scan=snapshot.loadingInspection
            if scan then reason=reason.." | examined="..scan.visited.." pruned="..scan.pruned
                ..(scan.limitPath and " | limit="..scan.limitPath or "") end
            phase("WAIT_READINESS",reason)
        end
    end})
    if not ok then
        I.blocked=true
        phase("READINESS_HOLD",last.reason.."; bounded observation ended; rejoin after checking native loading")
    end
    return ok
end
local function requestPath(frame,pg)
    local parts={}
    local node=frame
    while node and node~=pg do table.insert(parts,1,node.Name); node=node.Parent end
    return table.concat(parts,".")
end
-- Always reacquire PlayerGui and request nodes: respawns must not reuse stale refs.
local function uiSafety()
    local ready,loadingWhy=automationReady(true)
    if not ready then return false,"readiness:"..tostring(loadingWhy) end
    local pg=LP and LP:FindFirstChildOfClass("PlayerGui")
    if not pg then return false,"player-gui-loading" end
    if workerGui and pg~=workerGui then error("worker PlayerGui replaced; rejoin",0) end
    for _,name in ipairs({"TradeGUI_Phone","TradeGUI"}) do
        local g=pg:FindFirstChild(name)
        local c=g and g:FindFirstChild("Container")
        local t=c and c:FindFirstChild("Trade")
        if t and visible(t) then return false,"active-trade-ui" end
    end
    local frames,inspectionError=requestFrames(pg)
    if not frames then return false,inspectionError end
    local paths={}
    local complete=false
    local blocked=nil
    for _,req in ipairs(frames) do
        local path=requestPath(req,pg)
        paths[#paths+1]=path
        local sending=req:FindFirstChild("SendingRequest")
        local receiving=req:FindFirstChild("ReceivingRequest")
        if sending and receiving and sending:IsA("GuiObject") and receiving:IsA("GuiObject") then
            complete=true
            if visible(sending) or visible(receiving) then blocked="pending-request-ui:"..path end
        elseif visible(req) then blocked="request-ui-incomplete:"..path end
    end
    local found=#paths>0 and table.concat(paths,";") or "none (checked Lobby/Game and structural fallback)"
    if I.requestUiPath~=found then
        I.requestUiPath=found
        print("[PDIDDLER V13_VISIBLE_READINESS] REQUEST_UI | "..found)
    end
    if blocked then return false,blocked end
    if not complete then return false,"request-ui-loading:"..found end
    return true,"idle"
end
local seenEligible={}
local function queueState()
    if I.blocked then return false,"integration-held",false end
    local scanner,outgoing,part4=I.scanner,I.outgoing,I.part4
    if (I.quietOutgoingSession or outgoing.session)~=E.PDIDDLER_OUTGOING_SESSION
        or (I.quietPart4Session or part4.session)~=E.PDIDDLER_PART4_SESSION then
        error("subsystem-session-replaced",0)
    end
    local s=outgoing.state
    assert(type(s)=="table" and type(s.processed)=="table" and type(part4.state)=="table","subsystem-state-missing")
    local busy=E.PDIDDLER_OUTGOING_BUSY_SESSION~=nil or s.active~=nil or s.paused
        or s.uncertainOutgoing~=nil or part4.state.active or E.PDIDDLER_STATUS_OWNER=="P4"
    local ui,why=uiSafety()
    -- Whitelist AND per-player records remain authoritative. A join can precede
    -- the scanner's delayed join callback, so missing records explicitly block.
    local available=false
    local discovered=false
    local function eligible(p)
        if not seenEligible[p.UserId] then discovered=true; seenEligible[p.UserId]=true end
        if not s.processed[p.UserId] then available=true end
    end
    local white=scanner.getWhitelist()
    assert(type(white)=="table","scanner whitelist invalid")
    for _,p in ipairs(white) do
        if p~=LP and p.Parent==Players then eligible(p) end
    end
    local settled=not scanner.hasPendingWork()
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP then
            local rec=scanner.getRecord(p.UserId)
            if type(rec)~="table" or (rec.state~="whitelist" and rec.state~="blacklist") then settled=false
            elseif rec.state=="whitelist" then eligible(p) end
        end
    end
    local reset=available or discovered
    if busy then return false,"request-or-trade-owned",reset end
    if not ui then return false,why,reset end
    if available then return false,"eligible-trader",true end
    if not settled then return false,"scanner-pending",reset end
    return true,"exhausted",reset
end
local function requestHop(bot)
    local ok,why
    if bot then ok,why=I.hopper:handleBotRejected("v11-two-positive-valid-v6-appearance-scans")
    else ok,why=I.hopper:hopNow("v5-adaptive-45s-authoritative-final-state") end
    if not ok then error("P5 hop refused:"..tostring(why),0) end
    phase("HOPPING",bot and "corroborated bot" or "exhausted server")
    -- Keep ownership and supervise P5 even after the asynchronous call returns.
    while live() do
        if not I.hopper:isAlive() then error("P5 owner lost",0) end
        local s=I.hopper.state
        if s.terminal then error("P5:"..tostring(s.lastFailure),0) end
        if not s.hopping then error("P5 stopped without server change",0) end
        task.wait(.5)
    end
end
local function monitor()
    local since=os.clock()
    local loadingSince=nil
    while live() do
        if I.blocked or I.part4.state.blocked then
            if not I.blocked then holdOutcome(I.part4.state.blockReason or "unconfirmed native outcome") end
            return
        end
        local ready,loadingWhy=automationReady(true)
        if not ready then
            loadingSince=loadingSince or os.clock()
            phase("READINESS_WAIT",loadingWhy)
            if os.clock()-loadingSince>=15 then
                I.blocked=true;I.outgoing.stop()
                phase("READINESS_HOLD",loadingWhy.."; unresolved for 15s; no hopping; inspect and rejoin")
                return
            end
        else
        loadingSince=nil
        if not I.profile.isFresh() then
            -- P4 may still need to decline a bound active trade. Stop outgoing
            -- requests and hopping while its identity-only close guard runs.
            I.outgoing.stop()
            I.blocked=true
            phase("PRICE_HOLD","Supreme snapshot expired; refresh the dated build and rejoin")
            return
        end
        if not I.hopper:isAlive() then error("P5 owner lost",0) end
        local safe,why,eligible=queueState()
        if eligible then since=os.clock() end -- ONLY a newly available eligible trader resets.
        if safe and os.clock()-since>=45 then
            phase("RECHECK","45s exhausted; authoritative scanner state")
            local beforeRoster=roster()
            local before={}
            for k,v in pairs(I.outgoing.state.processed) do before[k]=v end
            local recheckUntil=os.clock()+2
            local final=true
            repeat
                task.wait(.1)
                if not live() or I.blocked then return end
                local safeNow,_,newEligible=queueState()
                if newEligible then since=os.clock(); final=false end
                if not safeNow then final=false end
            until os.clock()>=recheckUntil
            local unchanged=true
            for k,v in pairs(before) do if I.outgoing.state.processed[k]~=v then unchanged=false end end
            for k,v in pairs(I.outgoing.state.processed) do if before[k]~=v then unchanged=false end end
            if final and unchanged and roster()==beforeRoster then requestHop(false); return end
        else phase("TRADING",why) end
        end
        task.wait(.5)
    end
end
local function boot()
    assert(type(task.cancel)=="function","executor task.cancel required for bounded startup")
    phase("WAIT_GAME","LocalPlayer and loaded game")
    local deadline=os.clock()+30
    repeat
        LP=Players.LocalPlayer
        if LP and game:IsLoaded() and LP:FindFirstChildOfClass("PlayerGui") then break end
        task.wait(.1)
    until not live() or os.clock()>=deadline
    assert(live() and LP and game:IsLoaded() and LP:FindFirstChildOfClass("PlayerGui"),"game/UI loading timeout")
    local p2=api(module("p2",5,false),"P2",{"run"})
    phase("TABLET","frozen P2 startup; bounded 35s")
    assert(bounded("P2 run",35,p2.run)==true,"P2 did not return true")
    I.readiness=api(module("readiness",5,false),"readiness",{"read","wait","requestFrames"})
    if not awaitReadiness(60) then return end
    -- Download BEFORE beginning the gate's ten-second observation clock.
    local downloaded,gate=pcall(fetch,"gate")
    E.PDIDDLER_FAST_GATE_RESULT=nil
    local generation=(tonumber(E.PDIDDLER_FAST_GATE_GEN) or 0)+1
    local gateRoster=roster()
    I.gateGeneration=generation
    phase("GATE","10s observation; unknown permits trading")
    local started=os.clock()
    local launched,launchError=false,gate
    if downloaded then
        -- V6 may wait up to two seconds for PlayerGui before returning nil.
        -- This is inside, not added to, the ten-second observation budget.
        launched,launchError=pcall(bounded,"gate launch",3,gate)
    end
    if not launched then phase("GATE_UNKNOWN",tostring(launchError)) end
    local result
    while launched and live() and os.clock()-started<10.5 do
        local r=E.PDIDDLER_FAST_GATE_RESULT
        -- Accept only this exact gate generation and unchanged server roster.
        if E.PDIDDLER_FAST_GATE_GEN==generation and type(r)=="table" and r.evidenceVersion==6 and r.generation==generation and r.roster==gateRoster
            and r.jobId==JOB and r.automaticHopAllowed==false and type(r.elapsed)=="number"
            and r.elapsed>=9.5 and r.elapsed<=10.5 and roster()==gateRoster then
            result=r; break
        end
        task.wait(.05)
    end
    if not live() then return end
    if E.PDIDDLER_FAST_GATE_GEN==generation then
        if type(E.PDIDDLER_FAST_GATE_STOP)=="function" then pcall(E.PDIDDLER_FAST_GATE_STOP) end
        E.PDIDDLER_FAST_GATE_GEN=generation+1 -- fence delayed callbacks after verdict/timeout
    end
    I.lastDecision=result and result.state or "PROCEED_UNVERIFIED"
    local strong=result and result.state=="BOT_PATTERN_FOR_REVIEW" and result.appearanceScans==2
        and type(result.appearanceScore)=="number" and result.appearanceScore>=60
        and type(result.total)=="number" and result.total>=6
    local policy=module("policy",5,false)
    local transport=api(module("transport",5,false),"P5",{"bootstrap"})
    local function transportSafety()
        if not live() then return false,"integration-stale" end
        if strong then
            if roster()~=gateRoster then return false,"bot-roster-changed" end
            return uiSafety()
        end
        local safe,why=queueState()
        if not safe then return false,why end
        if not I.quiesced then
            -- Quiesce immediately before the actual teleport call, after P5's
            -- yielding discovery. No outgoing callback may send during a hop.
            I.outgoing.stop(); I.part4.stop()
            I.quietOutgoingSession=E.PDIDDLER_OUTGOING_SESSION
            I.quietPart4Session=E.PDIDDLER_PART4_SESSION
            I.quiesced=true
        end
        return true,"safe-to-transport"
    end
    I.dirty=true -- bootstrap may install listeners even if it throws/yields.
    I.hopper=api(bounded("P5 bootstrap",5,function() return transport.bootstrap(policy,transportSafety) end),"P5 controller",{"hopNow","handleBotRejected","isAlive","stop"})
    assert(type(I.hopper.state)=="table","P5 state missing")
    I.dirty=true -- P5 owns listeners/session now; do not adopt after partial failure.
    if strong then
        -- Missing/loading UI remains conservative, but is rechecked dynamically.
        local untilUI=os.clock()+15
        local heldReason
        repeat
            local safe,why=uiSafety()
            if safe then requestHop(true); return end
            heldReason=why
            phase("BOT_HOLD",why)
            task.wait(.25)
        until not live() or os.clock()>=untilUI
        error("corroborated bot held:"..tostring(heldReason),0)
    end
    I.profile=api(module("profile",5,false),"Supreme profile",{"get","coverage","isFresh"})
    assert(I.profile.liveReady==true and I.profile.coverage().total==190,"Supreme profile coverage invalid")
    assert(I.profile.isFresh(),"Supreme snapshot expired; refresh snapshot before new trading")
    I.strict=api(module("strict",5,false),"strict Supreme policy",{"reprice","buildPlans","tradeDecision","observe","negotiate","selectLateConcession","selectInitialOffer","confirmConcession","cancelConcession","observeQuote","earlyAllowance","reserveOffer"})
    I.acceptGate=api(module("acceptGate",5,false),"native UI-ready gate",{"read","step"})
    I.earlyPolicy=api(module("early",5,false),"early counteroffer policy",{"choose"})
    workerGui=LP:FindFirstChildOfClass("PlayerGui")
    assert(workerGui,"PlayerGui unavailable before scanner startup")
    I.rawScanner=api(module("scanner",240,true),"scanner",{"getWhitelist","getRecord","hasPendingWork"})
    -- Keep frozen scanning/eligibility intact; reprice copies at the trading API.
    I.scanner=setmetatable({}, {__index=I.rawScanner})
    I.scanner.getRecord=function(uid)
        local rec=I.rawScanner.getRecord(uid)
        if not rec then return nil end
        local copy={}; for k,v in pairs(rec) do copy[k]=v end
        if rec.inv then copy.inv=I.strict.reprice(rec.inv,I.profile) end
        if not automationReady(false) then copy.state="automation-hold" end
        return copy
    end
    I.scanner.isAutomationReady=function() return automationReady(true) end
    I.scanner.getWhitelist=function()
        if not automationReady(false) then return {} end
        return I.rawScanner.getWhitelist()
    end
    I.scanner.getOwnInventory=function()
        if not automationReady(true) then return nil,"automation-not-ready" end
        local inv,why=I.rawScanner.getOwnInventory()
        if not inv then return nil,why end
        return I.strict.reprice(inv,I.profile)
    end
    I.scanner.isWhitelisted=function(uid)
        return automationReady(false) and I.profile.isFresh() and I.rawScanner.isWhitelisted(uid)
    end
    if not awaitReadiness(15) then return end
    assert(I.profile.isFresh(),"Supreme snapshot expired during scanner startup")
    local p4=api(module("p4",5,false),"P4",{"run"})
    local outgoing=api(module("outgoing",5,false),"outgoing",{"run"})
    I.part4=api(bounded("P4 run",5,function() return p4.run(I.scanner,I.profile,I.strict,I.strict,{build=function() return nil end,holdOutcome=holdOutcome},I.acceptGate,I.earlyPolicy) end),"P4 controller",{"stop"})
    I.outgoing=api(bounded("outgoing run",5,function() return outgoing.run(I.scanner) end),"outgoing controller",{"stop"})
    phase("TRADING","Portfolio-aware quotes + one verified trade-wide ledger | Supreme +15 | MANUAL ACCEPT | completion/Discord OFF | gate="..tostring(I.lastDecision))
    monitor()
end
task.spawn(function()
    local ok,err=xpcall(boot,function(e) return tostring(e) end)
    if not ok then fail(I.stage..":"..tostring(err)) end
end)
return I
