-- Pdiddler P1 -> P5 boundary v1.
-- DRY RUN by default. Never starts trades, scans inventory, or selects servers.
-- Only the existing Part5 controller is allowed to perform a teleport.
local M={}
function M.evaluate(policy)
    assert(type(policy)=="table" and type(policy.assess)=="function","policy required")
    local E=(getgenv and getgenv()) or _G
    local Players=game:GetService("Players")
    local LP=Players.LocalPlayer
    local evidence=E.PDIDDLER_P1_EVIDENCE_V1
    local ids={}
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP then ids[#ids+1]=tostring(p.UserId) end
    end
    table.sort(ids)
    local old=E.PDIDDLER_PART5_CONTROLLER
    local hopping=E.PDIDDLER_HOPPING_SESSION~=nil
    local current=evidence~=nil and type(evidence.session)=="number"
        and evidence.session==E.PDIDDLER_BOT_OBSERVER_GEN
    -- Critically: no assumptions about Part 3/4 readiness.
    -- A caller must provide an explicit fresh safety snapshot to evaluate
    -- any possibility of a future hop.
    return function(safety)
        if type(safety)~="table"
            or type(safety.criticalBusy)~="boolean"
            or type(safety.tradeVisible)~="boolean"
            or type(safety.outgoingOwned)~="boolean"
            or type(safety.scannerPending)~="boolean"
            or safety.readyConfirmed~=true
        then
            return "HOLD","missing-authoritative-safety-proof"
        end
        local state,reason=policy.assess(evidence,{
            jobId=game.JobId,now=os.clock(),currentIds=ids,
            observerCurrent=current,
            criticalBusy=safety.criticalBusy,
            tradeVisible=safety.tradeVisible,
            outgoingOwned=safety.outgoingOwned,
            scannerPending=safety.scannerPending,
            hopping=hopping
        })
        if not old or type(old.isAlive)~="function" or not old:isAlive() then
            return "HOLD","part5-controller-unavailable"
        end
        return state,reason
    end
end

-- Opt-in handoff, NOT called by v4.2. Designed for later integration once
-- Part 3/4 can furnish an authoritative readyCheck callback.
function M.requestHop(policy,controller,readyCheck,opts)
    opts=opts or {}
    if opts.enabled~=true then return false,"disabled-by-default" end
    if type(readyCheck)~="function" then return false,"missing-ready-check" end
    if type(controller)~="table" or type(controller.hopNow)~="function" then
        return false,"missing-p5-controller"
    end
    local E=(getgenv and getgenv()) or _G
    if E.PDIDDLER_P1_P5_HOP_LOCK then return false,"hop-already-owned" end
    E.PDIDDLER_P1_P5_HOP_LOCK=true
    local function unlock() E.PDIDDLER_P1_P5_HOP_LOCK=false end
    -- Two fresh synchronous safety checks; stale callbacks cannot reuse a
    -- prior safety result. No task.wait between checks and hopper invocation.
    local ok,a=pcall(readyCheck)
    if not ok then unlock() return false,"ready-check-error" end
    local evaluate=M.evaluate(policy)
    local state,reason=evaluate(a)
    if state~="REVIEW" then unlock() return false,reason end
    local ok2,b=pcall(readyCheck)
    if not ok2 then unlock() return false,"second-ready-check-error" end
    local state2,reason2=M.evaluate(policy)(b)
    if state2~="REVIEW" then unlock() return false,reason2 end
    -- Exclusivity still belongs to Part 5; it refuses duplicate hops.
    local good,started,why=pcall(function()
        return controller:hopNow("p1-v4.2-reviewed-farm")
    end)
    unlock()
    if not good then return false,"p5-hop-error" end
    return started==true,why or (started and "handoff-requested" or "not-started")
end
return M
