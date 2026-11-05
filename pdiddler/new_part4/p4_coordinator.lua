-- Stage 11: defensive-only integration coordinator for the new Part 4.
-- No Roblox APIs, trade remotes, direct clicks, offer insertion, or Accept.
-- Dependency-injected Stage 9 observer, Stage 8 safety state machine, and
-- Stage 10 one-shot removal ledger/native adapter. DO NOT auto-execute.
local M = {}

local function clockRead(s)
    local ok,now=pcall(s.clock)
    if not ok or type(now)~="number" or now~=now or now<0 or now==math.huge then
        return nil
    end
    if s.lastTime and now<s.lastTime then return nil end
    s.lastTime=now
    return now
end
local function result(s,action,reason,detail)
    s.lastAction=action
    s.lastReason=reason
    return action,reason,detail
end
local function stop(s,reason)
    s.terminal="STOP"
    s.pending=false
    s.queuedRemove=false
    if s.stability then s.stability.reset(s.gate) end
    if s.executor and type(s.executor.stop)=="function" then
        pcall(s.executor.stop,s.execState,reason)
    end
    if s.native and type(s.native.close)=="function" then
        pcall(s.native.close,s.nativeHandle)
    end
    return result(s,"STOP",reason)
end
local function decline(s,reason)
    -- Output is a single DECLINE INTENT for a *separate* verified arbiter.
    -- This module never sends a decline remote or clicks native Decline.
    s.terminal="DECLINE_REQUIRED"
    s.pending=false
    s.queuedRemove=false
    if s.stability then s.stability.reset(s.gate) end
    if s.executor and type(s.executor.stop)=="function" then
        pcall(s.executor.stop,s.execState,reason)
    end
    if s.native and type(s.native.close)=="function" then
        pcall(s.native.close,s.nativeHandle)
    end
    return result(s,"DECLINE",reason)
end
local function read(s)
    local ok,observation,diagnostics=pcall(s.observer.capture,s.obsHandle)
    if not ok or type(observation)~="table" then return nil,nil,"observer-capture-failed" end
    if observation.tradeOpen==false then return observation,diagnostics,"trade-closed" end
    if observation.session~=s.session then return observation,diagnostics,"trade-session-mismatch" end
    return observation,diagnostics,nil
end
local function failure(s,reason)
    -- One fresh read prevents a stale decline INTENT crossing a known root close.
    local o,_,why=read(s)
    if why=="trade-closed" or why=="trade-session-mismatch" then
        return stop(s,why)
    end
    return decline(s,reason)
end

function M.new(config)
    assert(type(config)=="table","coordinator config required")
    assert(type(config.session)=="string" and config.session~="","session required")
    assert(type(config.clock)=="function","monotonic clock callback required")
    assert(type(config.observer)=="table" and type(config.observer.capture)=="function","Stage 9 observer required")
    assert(type(config.obsHandle)=="table" and config.obsHandle.config
        and config.obsHandle.config.session==config.session,"bound Stage 9 handle required")
    assert(type(config.safety)=="table" and type(config.safety.new)=="function"
        and type(config.safety.step)=="function","Stage 8 safety engine required")
    assert(type(config.executor)=="table" and type(config.executor.new)=="function"
        and type(config.executor.prepare)=="function"
        and type(config.executor.dispatched)=="function"
        and type(config.executor.observe)=="function","Stage 10 executor required")
    assert(type(config.native)=="table" and type(config.native.execute)=="function"
        and type(config.native.new)=="function","Stage 10 native removal adapter required")
    assert(type(config.stability)=="table" and type(config.stability.new)=="function"
        and type(config.stability.observe)=="function"
        and type(config.stability.reset)=="function","Stage 14 preflight gate required")
    assert(type(config.nativeHandle)=="table" and type(config.nativeHandle.config)=="table"
        and config.nativeHandle.config.session==config.session
        and config.nativeHandle.config.handle==config.obsHandle,
        "native actuator must use same observer handle and session")
    local safety=config.safety.new(config.session,config.safetyOptions)
    local exec=config.executor.new(config.session,config.executorOptions)
    local gate=config.stability.new(config.session,config.stabilityOptions)
    return {session=config.session,clock=config.clock,observer=config.observer,
        obsHandle=config.obsHandle,safety=config.safety,safetyState=safety,
        executor=config.executor,execState=exec,native=config.native,
        stability=config.stability,gate=gate,
        nativeHandle=config.nativeHandle,terminal=nil,pending=false,
        lastTime=nil,lastAction="HOLD",lastReason="created",pollCount=0,queuedRemove=false,
        busy=false}
end

function M.tick(s)
    assert(type(s)=="table" and s.session and s.safetyState,"coordinator state required")
    if s.terminal then return result(s,s.terminal=="STOP" and "STOP" or "HOLD",
        s.terminal=="STOP" and "already-stopped" or "awaiting-independent-decline") end
    -- Refuse reentrant observations/clicks; no two command owners may overlap.
    if s.busy then return result(s,"HOLD","poll-already-running") end
    s.busy=true
    local function go()
        local now=clockRead(s)
        if not now then return failure(s,"clock-invalid-or-reversed") end
        local observation,diag,readWhy=read(s)
        if readWhy=="trade-closed" or readWhy=="trade-session-mismatch" then
            return stop(s,readWhy)
        end
        if readWhy then return failure(s,readWhy) end
        s.pollCount=s.pollCount+1
        if observation.marketFresh~=true then return failure(s,"market-not-fresh") end

        -- An outstanding dispatched physical removal must be observed first.
        -- Never request or dispatch the next removal on the same observation
        -- that proves the previous one finished.
        if s.pending then
            local action,reason=s.executor.observe(s.execState,observation,now)
            if action=="STOP" then return stop(s,"executor-"..tostring(reason)) end
            if action=="ESCALATE" then return failure(s,"removal-"..tostring(reason)) end
            if action~="VERIFIED" then return result(s,"HOLD","removal-"..tostring(reason),diag) end
            s.pending=false
            s.stability.reset(s.gate) -- the next local stack state requires new proof
            -- Feed independent physical proof back to Stage 8; the next
            -- REMOVE_ONE command, if any, is dispatched on a future poll.
            local nextAction,nextWhy=s.safety.step(s.safetyState,observation,now)
            s.queuedRemove=nextAction=="REMOVE_ONE"
            if nextAction=="DECLINE" then return failure(s,"safety-"..tostring(nextWhy)) end
            if nextAction=="STOP" then return stop(s,"safety-"..tostring(nextWhy)) end
            return result(s,"HOLD","verified-removal;next="..tostring(nextAction),diag)
        end

        local action,why=s.safety.step(s.safetyState,observation,now)
        -- Stage 8 emits a new REMOVE_ONE on the snapshot that proved the
        -- preceding removal. Stage 11 defers it to the next poll, but must
        -- not forget it: a second safety.step alone returns HOLD while the
        -- next removal is pending. Revalidate the current quote and acceptance
        -- before actually using that queued command.
        if s.queuedRemove then
            s.queuedRemove=false
            if action=="REMOVE_ONE" then
                s.queuedRemove=true
                s.stability.reset(s.gate)
                return result(s,"HOLD","new-removal-request-deferred",diag)
            end
            if action=="HOLD" and why=="awaiting-removal-proof"
                and s.safetyState.mode=="AWAIT_REMOVAL" then
                action="REMOVE_ONE"
            else
                s.stability.reset(s.gate)
            end
        end
        if action=="STOP" then return stop(s,"safety-"..tostring(why)) end
        if action=="DECLINE" then return failure(s,"safety-"..tostring(why)) end
        if action=="REQUEST_PLAN" then
            -- Stage 7 is offline research: DO NOT invent a market-authorized
            -- strategy plan or change the safety core to BUILDING here.
            return result(s,"HOLD","awaiting-separate-verified-strategy",diag)
        end
        if action~="REMOVE_ONE" then
            s.stability.reset(s.gate)
            return result(s,"HOLD",tostring(why),diag)
        end
        -- Stage 14: do not trust one GUI sample, even when the Stage 8 safety
        -- controller correctly requests protective withdrawal. The deferred
        -- REMOVE_ONE survives awaiting-removal-proof until enough stable,
        -- separately timed, identity-matched samples have been observed.
        local stable,stableWhy=s.stability.observe(s.gate,observation,now)
        if stable~=true then
            s.queuedRemove=true
            return result(s,"HOLD","preflight-"..tostring(stableWhy),diag)
        end
        s.queuedRemove=false
        s.stability.reset(s.gate)
        -- Only protection (removal) is permitted, never new item addition.
        local choice,intent=s.executor.prepare(s.execState,"REMOVE_ONE",observation,now)
        if choice=="STOP" then return stop(s,"executor-"..tostring(intent)) end
        if choice=="ESCALATE" then return failure(s,"removal-"..tostring(intent)) end
        if choice~="DISPATCH" then return result(s,"HOLD","executor-"..tostring(intent),diag) end
        -- Native.execute() itself re-observes the exact bound trade session,
        -- consumes the token before attempting input, and checks acceptance.
        local ok,receipt=pcall(s.native.execute,s.nativeHandle,intent)
        if not ok or type(receipt)~="table" then
            return failure(s,"native-removal-exception")
        end
        local later=clockRead(s)
        if not later then return failure(s,"clock-invalid-after-dispatch") end
        local dispatched,dispatchWhy=s.executor.dispatched(s.execState,intent,receipt,later)
        if dispatched~="WAIT" then
            return failure(s,"removal-dispatch-"..tostring(dispatchWhy))
        end
        s.pending=true
        return result(s,"HOLD","removal-sent-awaiting-proof",{receipt=receipt,diagnostics=diag})
    end
    local ok,a,b,c=pcall(go)
    s.busy=false
    if not ok then return failure(s,"integration-exception:"..tostring(a)) end
    return a,b,c
end

function M.status(s)
    return {session=s.session,terminal=s.terminal,mode=s.safetyState.mode,
        executorMode=s.execState.mode,waitingProof=s.pending==true,
        polls=s.pollCount,lastAction=s.lastAction,lastReason=s.lastReason,
        preflightSamples=s.gate and s.gate.samples or 0}
end
return M
