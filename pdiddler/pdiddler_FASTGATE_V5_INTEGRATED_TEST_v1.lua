-- PDIDDLER INTEGRATED FAST GATE + P2/P3/P4 + P5 TEST v1
-- One execution entrypoint. All known-good modules remain immutable.
-- Real teleports ONLY through the existing Part 5 transport controller.
-- Critical: Part 1 finishes BEFORE Part 3/4 start, so no active trade
-- can be interrupted by an initial bot classification.
-- Part 4's existing final Accept behavior remains unchanged (disabled).
local Players=game:GetService("Players")
local LP=Players.LocalPlayer
local ENV=(getgenv and getgenv()) or _G
local old=ENV.PDIDDLER_INTEGRATION_V1
if type(old)=="table" and old.jobId==game.JobId and old.running then
    warn("[PDIDDLER INTEGRATION] already running; duplicate suppressed")
    return old
end
local integration={running=true,jobId=game.JobId,startedAt=os.clock(),
    stage="BOOT",lastDecision="none"}
ENV.PDIDDLER_INTEGRATION_V1=integration
local function live()
    return integration.running and ENV.PDIDDLER_INTEGRATION_V1==integration
        and integration.jobId==game.JobId
end
local function log(message)
    integration.stage=message
    print("[PDIDDLER INTEGRATION] "..message)
end
local function pull(path,revision,label)
    local url="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"..revision.."/pdiddler/"..path
    -- HTTP fetch may hang in some executors. Do not execute a late callback.
    local finished=false
    local ok,result
    task.spawn(function()
        ok,result=pcall(function() return game:HttpGet(url,true) end)
        finished=true
    end)
    local deadline=os.clock()+14
    while live() and not finished and os.clock()<deadline do task.wait(.05) end
    if not live() then return nil,"stale-integration" end
    if not finished then return nil,label.."-fetch-timeout" end
    if not ok or type(result)~="string" or result=="" then
        return nil,label.."-fetch-failed:"..tostring(result)
    end
    local fn,err=loadstring(result)
    if not fn then return nil,label.."-compile:"..tostring(err) end
    local ran,value=pcall(fn)
    if not ran then return nil,label.."-init:"..tostring(value) end
    return value
end
local BRANCH="feature/p1-bot-gate-safety-v1"
local P5BRANCH="feature/mm2-server-hopper-design"
local function fail(reason)
    integration.stage="ERROR"
    integration.error=tostring(reason)
    warn("[PDIDDLER INTEGRATION] ERROR | "..integration.error)
end
function integration:stop()
    if not live() then return end
    self.running=false
    self.stage="STOPPED"
    if self.outgoing and type(self.outgoing.stop)=="function" then
        pcall(self.outgoing.stop)
    end
    if self.part4 and type(self.part4.stop)=="function" then
        pcall(self.part4.stop)
    end
    -- Never force-stop an ongoing teleport. Part 5 owns its lifecycle.
end
local function roster()
    local t={}
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP then t[#t+1]=tostring(p.UserId) end
    end
    table.sort(t)
    return table.concat(t,",")
end
local function tradeUiVisible()
    local pg=LP:FindFirstChildOfClass("PlayerGui")
    if not pg then return true end -- fail closed on unavailable GUI
    for _,name in ipairs({"TradeGUI_Phone","TradeGUI"}) do
        local gui=pg:FindFirstChild(name)
        if gui and gui:IsA("ScreenGui") and gui.Enabled then
            local container=gui:FindFirstChild("Container")
            local trade=container and container:FindFirstChild("Trade")
            if trade and trade:IsA("GuiObject") and trade.Visible then
                return true
            end
        end
    end
    return false
end
local function pendingUiVisible()
    local pg=LP:FindFirstChildOfClass("PlayerGui")
    local main=pg and pg:FindFirstChild("MainGUI")
    local lobby=main and main:FindFirstChild("Lobby")
    local board=lobby and lobby:FindFirstChild("Leaderboard")
    local overlay=board and board:FindFirstChild("OverlayMenu")
    local req=overlay and overlay:FindFirstChild("TradeRequest")
    if not req then return true end -- unknown UI: do not hop
    for _,name in ipairs({"SendingRequest","ReceivingRequest"}) do
        local node=req:FindFirstChild(name)
        if node and node:IsA("GuiObject") and node.Visible then return true end
    end
    return false
end
local function safety(scanner,outgoing,part4)
    if not live() or not scanner or not outgoing or not part4 then
        return false,"integration-stale"
    end
    if outgoing.session~=ENV.PDIDDLER_OUTGOING_SESSION
        or part4.session~=ENV.PDIDDLER_PART4_SESSION then
        return false,"subsystem-session-stale"
    end
    local s=outgoing.state
    if type(s)~="table" or type(part4.state)~="table" then
        return false,"missing-state"
    end
    if ENV.PDIDDLER_OUTGOING_BUSY_SESSION~=nil
        or s.active~=nil or s.paused or s.uncertainOutgoing~=nil
        or part4.state.active or ENV.PDIDDLER_STATUS_OWNER=="P4" then
        return false,"request-or-trade-owned"
    end
    if tradeUiVisible() or pendingUiVisible() then
        return false,"trade-ui-visible-or-unavailable"
    end
    local ok,pending=pcall(scanner.hasPendingWork)
    if not ok or pending then return false,"scanner-pending" end
    return true,nil
end
local function available(scanner,outgoing)
    local ok,players=pcall(scanner.getWhitelist)
    if not ok or type(players)~="table" then return nil end
    local n=0
    for _,p in ipairs(players) do
        if p and p.Parent==Players and not outgoing.state.processed[p.UserId] then
            n+=1
        end
    end
    return n
end
local function runIdleLoop(scanner,outgoing,part4,hopper)
    local since=nil
    local lastRoster=roster()
    while live() do
        if not hopper:isAlive() then
            log("P5 STOPPED: no active hopper")
            return
        end
        if hopper.state.hopping then return end
        local currentRoster=roster()
        local safe,reason=safety(scanner,outgoing,part4)
        local n=available(scanner,outgoing)
        if currentRoster~=lastRoster then
            -- Roster changes alone are not proof of a new tradable player.
            -- The scanner will classify the newcomer. Only an actual
            -- unprocessed whitelisted trader resets the countdown.
            lastRoster=currentRoster
        end
        if safe and n==0 then
            since=since or os.clock()
            local elapsed=os.clock()-since
            if elapsed>=45 then
                log("45S EXHAUSTED: final scanner-state verification")
                local proofRoster=roster()
                local proofSession=outgoing.session
                local proofProcessed={}
                for k,v in pairs(outgoing.state.processed) do
                    proofProcessed[k]=v
                end
                task.wait(2)
                if not live() then return end
                local ok,why=safety(scanner,outgoing,part4)
                local stillAvailable=available(scanner,outgoing)
                -- This verifies currently exposed scanner state, not a fresh
                -- forced inventory-RPC (no supported public API exists).
                if ok and stillAvailable==0 and proofRoster==roster()
                    and proofSession==outgoing.session then
                    local latest=outgoing.state.processed
                    local same=true
                    for k,v in pairs(proofProcessed) do
                        if latest[k]~=v then same=false break end
                    end
                    for k,v in pairs(latest) do
                        if proofProcessed[k]~=v then same=false break end
                    end
                    if same then
                        local started,hopWhy=hopper:hopNow("45s-exhausted-final-state-verified")
                        if started then
                            log("P5 HOP REQUESTED: exhausted server")
                            return
                        else
                            warn("[PDIDDLER INTEGRATION] HOP REFUSED | "..tostring(hopWhy))
                        end
                    end
                else
                    log("EXHAUSTION ABORTED: "..tostring(why or "roster-or-queue-changed"))
                end
                since=nil
            end
        else
            if reason=="scanner-pending" and n==0 then
                -- Pause hop eligibility during scanning, preserving the
                -- established exhaustion start. Final verification still
                -- requires a fully settled scanner.
            else
                -- Actual tradable player, busy request/trade, unknown UI,
                -- or invalid scanner state cancels the exhaustion window.
                since=nil
            end
        end
        task.wait(.5)
    end
end
task.spawn(function()
    log("INITIALIZING P5")
    local p5Policy,err=pull("pdiddler5_server_hopper_policy_v1.lua",P5BRANCH,"P5 policy")
    if not p5Policy then fail(err) return end
    local p5Module,err2=pull("pdiddler5_server_hopper_v1.lua",P5BRANCH,"P5 transport")
    if not p5Module then fail(err2) return end
    local success,hopper=pcall(p5Module.bootstrap,p5Policy)
    if not success or type(hopper)~="table"
        or type(hopper.hopNow)~="function" then
        fail("P5 bootstrap failed: "..tostring(hopper))
        return
    end
    integration.hopper=hopper
    log("STARTUP / TABLET SELECTION")
    local p2,why=pull("pdiddler2_KNOWN_GOOD.lua",
        "b097c1862db4cff7394d6a5e6764d34191df3283","P2")
    if not p2 or type(p2.run)~="function" then fail(why or "P2 unavailable") return end
    local success2,ready=pcall(p2.run)
    if not success2 or ready~=true then fail("P2 tablet selection failed") return end
    -- Start the bot gate only after the character can enter the lobby.
    log("BOT SCREENING (10s)")
    -- Use exactly the already-tested v5 gate. It publishes one result;
    -- do not run the frozen Part1 gate again.
    local startedGate=os.clock()
    -- Clear any result from earlier standalone testing in this client.
    ENV.PDIDDLER_FAST_GATE_RESULT=nil
    local previousGeneration=tonumber(ENV.PDIDDLER_FAST_GATE_GEN) or 0
    local gate,gateErr=pull("pdiddler1_fast_gate_TEST_v5.lua",BRANCH,"Fast Gate v5")
    -- The v5 file runs asynchronously and returns nil by design.
    if gateErr and not gate then
        -- pull() returns nil for successful nil-returning scripts as well.
        -- Only a non-nil error means the module failed to launch.
        warn("[PDIDDLER INTEGRATION] Gate launch error: "..tostring(gateErr))
    end
    local finalGate=nil
    local deadline=startedGate+14
    while live() and os.clock()<deadline do
        local result=ENV.PDIDDLER_FAST_GATE_RESULT
        if type(result)=="table" and result.evidenceVersion==5
            and result.jobId==game.JobId and result.automaticHopAllowed==false
            -- V5's result does not contain a generation field, so require
            -- a newly started gate generation and a result slot cleared before launch.
            and (tonumber(ENV.PDIDDLER_FAST_GATE_GEN) or 0)>previousGeneration
            and tonumber(result.elapsed) and result.elapsed>=0
            and tonumber(result.elapsed)<=12 then
            finalGate=result
            break
        end
        task.wait(.1)
    end
    if not live() then return end
    local state=finalGate and finalGate.state or "PROCEED_UNVERIFIED"
    integration.lastDecision=state
    log("GATE DECISION: "..state)
    local strong=finalGate
        and state=="BOT_PATTERN_FOR_REVIEW"
        and finalGate.appearanceScans==2
        and tonumber(finalGate.appearanceScore)
        and finalGate.appearanceScore>=60
        and tonumber(finalGate.total)>=6
    if strong then
        -- No scanner, outgoing, or trade controller has been started yet.
        if tradeUiVisible() or pendingUiVisible() then
            log("BOT VERDICT HELD: existing UI active; no hop")
            return
        end
        local ok,why=hopper:handleBotRejected("fast-gate-v5-strong-appearance")
        if ok then
            log("BOT SERVER: P5 OWNS HOP")
            return
        end
        fail("bot-server hop refused: "..tostring(why))
        return
    end
    -- For all uncertain/animation-only findings, go to trading.
    -- Do not treat uncertainty as evidence of a safe server.
    log("STARTING KNOWN-GOOD TRADING MODULES")
    local scanner,sErr=pull("pdiddler3_scanner_MODULE_v6_8_CRITICAL_PAUSE.lua",
        "3c48b49c1e750d91bfbf088fbc737185bddf39be","P3 scanner")
    if not scanner then fail(sErr or "scanner missing") return end
    local p4,p4Err=pull("pdiddler4_balancer_ROTATING_v2_3_EXTREME_GUARD.lua",
        "41372d75f053cb125c12847188966a10d51d1f10","P4")
    if not p4 then fail(p4Err or "P4 missing") return end
    local out,oErr=pull("pdiddler3_outgoing_ROTATING_v15_UNCERTAIN_OWNER.lua",
        "9f0637b063c2f65cb1cf6fc1f6ce4ab08b5dda87","P3 outgoing")
    if not out then fail(oErr or "outgoing missing") return end
    local ok4,part4=pcall(p4.run,scanner)
    if not ok4 or type(part4)~="table" then fail("P4 run: "..tostring(part4)) return end
    integration.part4=part4
    local ok3,outgoing=pcall(out.run,scanner)
    if not ok3 or type(outgoing)~="table" then
        pcall(part4.stop)
        fail("outgoing run: "..tostring(outgoing))
        return
    end
    integration.outgoing=outgoing
    integration.scanner=scanner
    log("TRADING ACTIVE | 45S EXHAUSTION WATCH")
    runIdleLoop(scanner,outgoing,part4,hopper)
end)
return integration
