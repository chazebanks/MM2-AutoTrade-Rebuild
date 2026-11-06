-- PROJECT GINGERSCOPE: replacement-only isolated integration PREVIEW.
-- No old Part4 balancer, no +15 offer gate; Part4 only observes.
-- NOT a completed auto-trader. Final Accept and profit reporting remain disabled.
-- Native automatic acceptance and completion/webhook reporting remain disabled.
-- One bootstrap/monitor; only P5 transports. Final trade acceptance stays disabled.
local E=(getgenv and getgenv()) or _G
if E.PDIDDLER_ALLOW_REPLACEMENT_PREVIEW~=true then
    warn("[GINGERSCOPE REPLACEMENT] PREVIEW NOT ARMED; no trade automation started")
    return nil
end
local KEY="PDIDDLER_GINGERSCOPE_REPLACEMENT_PREVIEW"
local JOB=game.JobId
local prior=E[KEY]
if type(prior)=="table" and prior.jobId==JOB and (prior.running or prior.dirty) then
    warn("[PDIDDLER V15_8_VALUE_FIRST] HOLD | existing owner or partial initialization; rejoin if stopped")
    return prior
end
-- Never steal sessions from an older stack or an independent outgoing owner.
for _,key in ipairs({"PDIDDLER_INTEGRATION_V1","PDIDDLER_INTEGRATION_V2","PDIDDLER_INTEGRATION_V3","PDIDDLER_INTEGRATION_V4_SUPREME","PDIDDLER_INTEGRATION_V5_ADAPTIVE","PDIDDLER_INTEGRATION_V6_FINAL_WAIT","PDIDDLER_INTEGRATION_V7_DELAYED_SWEETEN","PDIDDLER_INTEGRATION_V8_VISIBLE_ACCEPT","PDIDDLER_INTEGRATION_V9_EARLY_COUNTER","PDIDDLER_INTEGRATION_V10_BOUNDED_SELECTION","PDIDDLER_INTEGRATION_V11_VERIFIED_READINESS","PDIDDLER_INTEGRATION_V12_PORTFOLIO_LEDGER","PDIDDLER_INTEGRATION_V13_VISIBLE_READINESS","PDIDDLER_INTEGRATION_V14_VERIFIED_WORKFLOW","PDIDDLER_INTEGRATION_V15_OPPONENT_ADDED","PDIDDLER_INTEGRATION_V15_1_CURRENT_PRICES","PDIDDLER_INTEGRATION_V15_2_HEADLESS_GATE","PDIDDLER_INTEGRATION_V15_3_GUI_STATUS","PDIDDLER_INTEGRATION_V15_4_REACHABLE","PDIDDLER_INTEGRATION_V15_5_SCANNER_EVIDENCE","PDIDDLER_INTEGRATION_V15_6_IMMEDIATE_SAFETY","PDIDDLER_INTEGRATION_V15_7_INVENTORY_GROWTH"}) do
    local old=E[key]
    if type(old)=="table" and old.jobId==JOB then
        warn("[PDIDDLER V15_8_VALUE_FIRST] HOLD | legacy integration present; rejoin first")
        return old
    end
end
if E.PDIDDLER_OUTGOING_SESSION~=nil or E.PDIDDLER_PART4_SESSION~=nil
    or E.PDIDDLER_HOPPING_SESSION~=nil or E.PDIDDLER_PART5_CONTROLLER~=nil then
    warn("[PDIDDLER V15_8_VALUE_FIRST] HOLD | subsystem already initialized; rejoin first")
    return
end
local I={capabilities={autoAccept=false,completion=false,discord=false,stackedSlots=false},blockers={autoAccept="native final control/cooldown sequence unproved",completion="native boolean event lacks transaction identity; full raw inventory reconciliation unproved",discord="verified completion and persistent outbox adapter unavailable",stackedSlots="native slot/quantity behavior unproved"},running=true,dirty=false,jobId=JOB,stage="BOOT",reason="starting",lastDecision="PROCEED_UNVERIFIED"}
E[KEY]=I
local Players=game:GetService("Players")
local LP
local workerGui
local tasks={}
local function live() return I.running and E[KEY]==I and game.JobId==JOB end
-- Startup-only display. It never clicks, scans inventory, blocks input or owns
-- trading status. The preserved scanner creates the existing interactive panel.
local startupGui,startupStatus
local terminalDisplay={ERROR=true,STOPPED=true,PRICE_HOLD=true,READINESS_HOLD=true,OUTCOME_HOLD=true,REPORT_HOLD=true}
local function display(stage,reason)
    if startupGui then
        pcall(function()
            startupGui.Enabled=not (stage=="INITIALIZE" and reason=="scanner")
            startupStatus.Text=stage.." | "..tostring(reason):sub(1,500)
        end)
    elseif I.rawScanner and terminalDisplay[stage] and type(I.rawScanner.setStatus)=="function" then
        -- The scanner enforces its existing P4 status lock; do not claim it.
        pcall(I.rawScanner.setStatus,stage.." | "..tostring(reason))
    end
end
local function destroyStartupGui()
    if startupGui then pcall(function() startupGui:Destroy() end) end
    startupGui,startupStatus=nil,nil
end
local function createStartupGui()
    local ok=pcall(function()
        local pg=assert(LP:FindFirstChildOfClass("PlayerGui"),"PlayerGui unavailable")
        startupGui=Instance.new("ScreenGui")
        startupGui.Name="PdiddlerStartupStatusV15_8"
        startupGui.ResetOnSpawn=false
        startupGui.Enabled=true
        startupGui.DisplayOrder=5
        startupGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
        local panel=Instance.new("Frame")
        panel.Name="Panel"
        panel.Size=UDim2.fromOffset(300,108)
        panel.Position=UDim2.fromOffset(12,80)
        panel.BackgroundColor3=Color3.fromRGB(32,12,52)
        panel.BorderSizePixel=0
        panel.Active=false
        panel.Parent=startupGui
        local title=Instance.new("TextLabel")
        title.Name="Title"
        title.BackgroundTransparency=1
        title.Size=UDim2.new(1,-20,0,24)
        title.Position=UDim2.fromOffset(10,6)
        title.Font=Enum.Font.GothamBold
        title.TextSize=15
        title.TextColor3=Color3.fromRGB(235,214,255)
        title.TextXAlignment=Enum.TextXAlignment.Left
        title.Text="PDIDDLER | GINGERSCOPE REPLACEMENT PREVIEW"
        title.Active=false
        title.Parent=panel
        startupStatus=Instance.new("TextLabel")
        startupStatus.Name="Status"
        startupStatus.BackgroundTransparency=1
        startupStatus.Size=UDim2.new(1,-20,1,-38)
        startupStatus.Position=UDim2.fromOffset(10,32)
        startupStatus.Font=Enum.Font.Gotham
        startupStatus.TextSize=13
        startupStatus.TextWrapped=true
        startupStatus.TextColor3=Color3.fromRGB(238,241,245)
        startupStatus.TextXAlignment=Enum.TextXAlignment.Left
        startupStatus.TextYAlignment=Enum.TextYAlignment.Top
        startupStatus.Active=false
        startupStatus.Parent=panel
        startupGui.Parent=pg
        display(I.stage,I.reason)
    end)
    if not ok then
        destroyStartupGui()
        warn("[PDIDDLER V15.8] Startup display unavailable; console status remains active")
    end
end
local function phase(stage,reason)
    if I.stage~=stage or I.reason~=reason then
        I.stage=stage; I.reason=reason
        display(stage,reason)
        print("[PDIDDLER V15_8_VALUE_FIRST] "..stage.." | "..tostring(reason))
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
    if I.lifecycle then pcall(I.lifecycle.stop,I.lifecycle) end
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
    scannerView={"presentation/pdiddler3_scanner_view_v1.lua","0230ed1481768e7b8ddfee87e9022f6d27462674"},
    feasibility={"new_part4/P3_ELIGIBILITY_NO_LEGACY_PROFIT.lua","dc308be872b3f585075e8398dabd284de805f2be"},
    eligibility={"pdiddler3_outgoing_eligibility_v2_SCANNER_EVIDENCE.lua","0230ed1481768e7b8ddfee87e9022f6d27462674"},
    readiness={"pdiddler_readiness_v2_VISIBLE_SCAN.lua","8144fd2dc9b1a446c336adeeea8dfd6139a7aab3"},
    profile={"snapshots/pdiddler_supreme_snapshot_2026_11_04.lua","11537dfd47f8df72aec7aeba9ecaffdfc5c879d4"},
    strict={"new_part4/P4_REPRICE_ONLY.lua","daf42166b9a713b69b0a8c93708ff13e86b36283"},
    p2={"pdiddler2_KNOWN_GOOD.lua","b097c1862db4cff7394d6a5e6764d34191df3283"},
    gate={"pdiddler1_fast_gate_v7_HEADLESS.lua","1bcc13d857489376ee57eae42ee34de33323bbeb"},
    scanner={"presentation/pdiddler3_scanner_MODULE_v6_10_CURRENT_PRESENTATION.lua","001d228a407076d3cc411a5a7132b0076ec4c027"},
    p4={"new_part4/PDIDDLER_PART4_REPLACEMENT.lua","a5a9bd101a38a75cdd785cd424406df7c37aadff"},
    outgoing={"pdiddler3_outgoing_ROTATING_v18_REACHABLE.lua","b411a5eca727649c86f079b22a5368039cc60fc3"},
    policy={"pdiddler5_server_hopper_policy_v1.lua","3be1c15f435389ff518cf3a4594b34efc08e84de"},
    transport={"pdiddler5_server_hopper_v2.lua","a20e96fff663e42e50bf668d5be5c7b148a70b9e"},
    discord={"pdiddler_discord_transport_v1.lua","b23138cc769a632b8791fe1d50776faf1c7ac1dd"},
    journal={"pdiddler_runtime_journal_v1.lua","b23138cc769a632b8791fe1d50776faf1c7ac1dd"},
    outbox={"pdiddler_webhook_outbox_v3.lua","b23138cc769a632b8791fe1d50776faf1c7ac1dd"},
    verifier={"pdiddler_trade_verification_v2.lua","b23138cc769a632b8791fe1d50776faf1c7ac1dd"},
    lifecycle={"pdiddler_trade_lifecycle_v1.lua","b23138cc769a632b8791fe1d50776faf1c7ac1dd"},
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
local function module(key,seconds,sideEffects,args)
    local fn=fetch(key)
    if sideEffects then I.dirty=true end
    phase("INITIALIZE",key)
    if args then return bounded(key.." execute",seconds,function() return fn(table.unpack(args)) end) end
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
    local verified=I.lifecycle and I.lifecycle.state.actualOutcome=="completed"
    phase(verified and "REPORT_HOLD" or "OUTCOME_HOLD",tostring(reason)..(verified
        and "; completion verified; report retained; resolve delivery before resuming"
        or "; completion unconfirmed; inspect inventory and rejoin"))
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
    if I.lifecycle and not I.lifecycle:canStartWork() then return false,"transaction-owned" end
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
        print("[PDIDDLER V15_8_VALUE_FIRST] REQUEST_UI | "..found)
    end
    if blocked then return false,blocked end
    if not complete then return false,"request-ui-loading:"..found end
    return true,"idle"
end
local function queueState()
    if I.blocked then return false,"integration-held",false end
    if I.lifecycle and not I.lifecycle:canStartWork() then I.eligibility:invalidate() end
    local outgoing,part4=I.outgoing,I.part4
    if (I.quietOutgoingSession or outgoing.session)~=E.PDIDDLER_OUTGOING_SESSION
        or (I.quietPart4Session or part4.session)~=E.PDIDDLER_PART4_SESSION then
        error("subsystem-session-replaced",0)
    end
    local s=outgoing.state
    assert(type(s)=="table" and type(s.processed)=="table" and type(part4.state)=="table","subsystem-state-missing")
    if s.paused or part4.state.active or not I.lifecycle:canStartWork() then I.eligibility:invalidate() end
    local rosterPlayers={}
    for _,p in ipairs(Players:GetPlayers()) do if p~=LP and p.Parent==Players then rosterPlayers[#rosterPlayers+1]=p end end
    local q=I.eligibility:queue(rosterPlayers,s.processed)
    I.queueAssessment=q
    I.rawScanner.setOutgoingSummary(q.counts)
    local busy=E.PDIDDLER_OUTGOING_BUSY_SESSION~=nil or s.active~=nil or s.paused
        or s.uncertainOutgoing~=nil or part4.state.active or E.PDIDDLER_STATUS_OWNER=="P4"
    local ui,why=uiSafety()
    if busy then return false,"request-or-trade-owned",q.discovered end
    if not ui then return false,why,q.discovered end
    if q.globalHold then return false,q.globalHold,q.discovered end
    if q.available then return false,"reachable-trader",q.discovered end
    if q.verificationPending then return false,"inventory-verification",q.discovered end
    return q.exhausted,"exhausted",q.discovered
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
    local exhaustion=I.eligibilityModule.clock(os.clock())
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
        I.eligibility:refresh(false)
        local safe,why,discovered=queueState()
        local elapsed=exhaustion:step(os.clock(),{exhausted=safe,discovered=discovered})
        if safe and elapsed then
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
                if newEligible then exhaustion:step(os.clock(),{exhausted=false,discovered=true}); final=false end
                if not safeNow then exhaustion:step(os.clock(),{exhausted=false}); final=false end
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
    createStartupGui()
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
    I.strict=api(module("strict",5,false),"Supreme scanner repricer only",{"reprice"})
    workerGui=LP:FindFirstChildOfClass("PlayerGui")
    assert(workerGui,"PlayerGui unavailable before scanner startup")
    I.scannerView=api(module("scannerView",5,false),"scanner current-price view",{"inventory","row","summary"})
    I.rawScanner=api(module("scanner",240,true,{I.profile,I.strict,I.scannerView}),"scanner",
        {"getWhitelist","getRecord","hasPendingWork","getVerificationState","setOutgoingState","setOutgoingSummary","refreshPresentation"})
    destroyStartupGui() -- one-way handoff to the preserved scanner panel
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
    -- This is the only source of native protocol authority. No completed native
    -- probe trace has been supplied; globals cannot substitute for that evidence.
    local approvedNativeContract=nil
    local lifecycle=api(module("lifecycle",5,false),"transaction lifecycle",{"new"})
    local verifier=api(module("verifier",5,false),"completion verifier",{"reconcile"})
    local outbox=api(module("outbox",5,false),"completed report outbox",{"new","payload"})
    local journal=api(module("journal",5,false),"runtime journal",{"open"})
    local discord=api(module("discord",5,false),"Discord transport",{"new"})
    local jsonOK,jsonService=pcall(function() return game:GetService("HttpService") end)
    local encode=jsonOK and jsonService and function(data) return jsonService:JSONEncode(data) end or nil
    local decode=jsonOK and jsonService and function(data) return jsonService:JSONDecode(data) end or nil
    I.journal,I.journalReason=journal.open({accountId=tostring(LP.UserId),read=readfile,write=writefile,exists=isfile,encode=encode,decode=decode})
    local http=request or http_request or (type(syn)=="table" and syn.request)
    I.discordSend,I.discordReason=discord.new({webhookUrl=E.PDIDDLER_DISCORD_WEBHOOK_URL,http=http,encode=encode,decode=decode,
        bounded=function(label,seconds,fn) return pcall(bounded,label,seconds,fn) end})
    I.lifecycle=lifecycle.new({jobId=JOB,now=os.clock,profile=I.profile,policy=I.strict,verifier=verifier,
        native=approvedNativeContract,live=live,onHold=holdOutcome})
    local deliveryEnabled=I.lifecycle.capabilities.completion and I.journal~=nil and I.discordSend~=nil
    local function deliveryNow() return os.time() end
    I.outbox=outbox.new(I.journal and I.journal.ledger or {},deliveryEnabled,{persist=I.journal and I.journal.persist,now=deliveryNow})
    I.lifecycle.capabilities.discord=deliveryEnabled and I.outbox.state=="ready"
    -- The outbox is the only completed-report consumer; open quotes cannot enter it.
    I.lifecycle:setOutbox(I.outbox)
    I.capabilities.autoAccept=I.lifecycle.capabilities.autoAccept==true
    I.capabilities.completion=I.lifecycle.capabilities.completion==true
    I.capabilities.discord=I.lifecycle.capabilities.discord==true
    I.blockers.autoAccept=I.lifecycle.blocker
    I.blockers.completion=I.capabilities.completion and nil or "observed native completion contract and complete raw read adapter missing"
    I.blockers.discord=I.capabilities.discord and nil or "verified completion, configured endpoint and durable delivery adapters required"
    I.scanner.hasActiveTradeLifecycle=function() return not I.lifecycle:canStartWork() end
    local originalWhitelist=I.scanner.getWhitelist
    I.scanner.getWhitelist=function() if not I.lifecycle:canStartWork() then return {} end;return originalWhitelist() end
    local originalEligible=I.scanner.isWhitelisted
    I.scanner.isWhitelisted=function(uid) return I.lifecycle:canStartWork() and originalEligible(uid) end
    -- Observe outcomes independently of the trading/price monitor. Expiry cannot
    -- erase evidence from a transaction already submitted under pinned prices.
    local observer=task.spawn(function()
        while live() do
            local observed,err=pcall(function() I.lifecycle:poll() end)
            if not observed then holdOutcome("outcome observer failed");return end
            if I.outbox.state=="ready" then
                for id,row in pairs(I.outbox.ledger) do
                    if row.state=="queued" then I.outbox.deliver(id,deliveryNow(),function(report) return I.discordSend(outbox.payload(report)) end) end
                    row=I.outbox.ledger[id]
                    if row.state=="delivery-uncertain" or I.outbox.state=="persistence-error" then holdOutcome("completed report delivery requires reconciliation");return end
                end
            end
            task.wait(.5)
        end
    end)
    tasks[observer]=true
    local p4=api(module("p4",5,false),"P4",{"run"})
    local outgoing=api(module("outgoing",5,false),"outgoing",{"run"})
    I.part4=api(bounded("P4 replacement run",5,function() return p4.run(I.scanner,I.profile) end),"P4 replacement controller",{"stop"})
    local feasibility=api(module("feasibility",5,false),"outgoing feasibility",{"evaluate","validateInventory"})
    I.eligibilityModule=api(module("eligibility",5,false),"outgoing evidence",{"new","clock"})
    local function outgoingContext()
        local allowed,reason=uiSafety()
        if I.part4.state.active or E.PDIDDLER_STATUS_OWNER=="P4" then allowed=false;reason="transaction-owned" end
        local owner=E.PDIDDLER_OUTGOING_CONTROLLER
        if I.outgoing and owner~=I.outgoing then allowed=false;reason="outgoing-owner-changed" end
        return {job=game.JobId,gui=LP:FindFirstChildOfClass("PlayerGui"),outgoing=owner,
            session=E.PDIDDLER_OUTGOING_SESSION,part4Session=E.PDIDDLER_PART4_SESSION,
            transaction=I.lifecycle.state.active,phase=I.lifecycle.state.phase,
            activeTarget=I.outgoing and I.outgoing.state.active,allowed=allowed and live(),reason=reason}
    end
    I.eligibility=I.eligibilityModule.new({scanner=I.rawScanner,profile=I.profile,strict=I.strict,
        feasibility=feasibility,now=os.clock,context=outgoingContext,readOwn=I.rawScanner.getOwnInventory,
        render=function(p,state,reason)
            if I.outgoing and I.outgoing.state.processed[p.UserId] then return false end
            -- Economic evidence has its own display channel; genuine request and P4 state retain ownership.
            local rendered=I.rawScanner.setOutgoingState(p,state,reason)
            if rendered~=false then print("[PDIDDLER P3 ECON]",JOB,p.Name,p.UserId,state,reason) end
            return rendered
        end})
    I.scanner.getOutgoingEligibility=function(p)
        local a=I.eligibility:assess(p);return a.state,a.reason,a.witness
    end
    I.scanner.refreshOutgoingInventory=function() return I.eligibility:refresh(false) end
    I.scanner.authorizeOutgoing=function(p) return I.eligibility:authorize(p) end
    I.scanner.prepareOutgoing=function(p,token) return I.eligibility:prepare(p,token) end
    I.outgoing=api(bounded("outgoing run",5,function() return outgoing.run(I.scanner) end),"outgoing controller",{"stop"})
    phase("REPLACEMENT_PREVIEW","New P4 OBSERVATION ONLY | NO legacy +15 or old balancer | NO automatic offers/removals/accept | gate="..tostring(I.lastDecision))
    monitor()
end
task.spawn(function()
    local ok,err=xpcall(boot,function(e) return tostring(e) end)
    if not ok then fail(I.stage..":"..tostring(err)) end
end)
return I
