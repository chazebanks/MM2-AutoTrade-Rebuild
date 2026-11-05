-- New Part 4 / Stage 8: pure offer-safety and transaction-state controller.
-- No Roblox APIs, remote calls, clicks, spawning, webhooks or side effects.
-- This is an offline contract; a future executor must supply verified snapshots
-- and acknowledge each command by observing the physical trade UI afterward.
local M = {}

local function integer(x, lo, hi)
    return type(x) == "number" and x == x and x ~= math.huge
        and x ~= -math.huge and x == math.floor(x) and x >= lo and x <= hi
end
local function finite(x)
    return type(x) == "number" and x == x and x ~= math.huge
        and x ~= -math.huge and x >= 0
end
local function copyCounts(rows)
    if type(rows) ~= "table" or #rows > 4 then return nil end
    local counts, slots, used = {}, 0, {}
    for _, row in ipairs(rows) do
        if type(row) ~= "table" or type(row.id) ~= "string" or row.id == ""
            or not integer(row.qty, 1, 1000000) or not integer(row.slot, 1, 4)
            or used[row.slot] then return nil end
        used[row.slot] = true
        counts[row.id] = (counts[row.id] or 0) + row.qty
        slots = slots + 1
    end
    return counts, slots
end
local function same(a,b)
    if not a or not b then return false end
    for k,v in pairs(a) do if b[k] ~= v then return false end end
    for k,v in pairs(b) do if a[k] ~= v then return false end end
    return true
end
local function subset(before,after)
    if not before or not after then return false,false end
    local progress = false
    for id,n in pairs(after) do
        if not before[id] or n > before[id] then return false,false end
    end
    for id,n in pairs(before) do
        local nextN = after[id] or 0
        if nextN > n then return false,false end
        if nextN < n then progress = true end
    end
    return true,progress
end
local function result(s,action,reason)
    s.lastAction = action
    s.lastReason = reason
    return action,reason
end
local function stopped(s,reason)
    s.mode = "STOPPED"
    return result(s,"STOP",reason)
end
local function decline(s,reason)
    s.mode = "DECLINE_REQUIRED"
    s.plan = nil
    s.pending = nil
    return result(s,"DECLINE",reason)
end
local function empty(s,now,otherSig,otherSlots)
    s.mode = "WAIT_REPLAN"
    s.pending = nil
    s.plan = nil
    s.stableOtherSig = otherSig
    s.stableSince = now
    s.emptySince = otherSlots == 0 and now or nil
    return result(s,"HOLD","our-offer-cleared")
end
local function beginRemoval(s,counts,obs,now,reason)
    if not s.clearingSince then s.clearingSince = now end
    s.mode = "AWAIT_REMOVAL"
    s.pending = counts
    s.pendingOurSig = obs.ourSig
    s.pendingSince = now
    s.plan = nil
    s.quoteApproved = false
    return result(s,"REMOVE_ONE",reason)
end

function M.new(session, opts)
    assert(type(session) == "string" and session ~= "", "nonempty session key required")
    opts = opts or {}
    local c = {
        removalSeconds = opts.removalSeconds or 1.35,
        clearSeconds = opts.clearSeconds or 6.5,
        stabilizeSeconds = opts.stabilizeSeconds or 0.65,
        emptySeconds = opts.emptySeconds or 12,
        buildSeconds = opts.buildSeconds or 5,
    }
    for _,v in pairs(c) do assert(finite(v) and v > 0 and v <= 60,"bad safety timeout") end
    return {session=session,mode="MONITOR",config=c,quoteApproved=false,
        lastPair=nil,lastOurCounts=nil,clearingSince=nil,
        lastAction="HOLD",lastReason="initial"}
end

function M.authorizePlan(s, opponentSignature, proposedRows, now)
    if s.mode ~= "PLAN_REQUESTED" or not finite(now) then return false,"not-ready" end
    if type(opponentSignature) ~= "string" or opponentSignature ~= s.stableOtherSig then
        return false,"opponent-version-changed"
    end
    local counts,slots = copyCounts(proposedRows)
    if not counts or slots < 1 then return false,"invalid-plan" end
    s.plan = {counts=counts,opponentSignature=opponentSignature,started=now}
    s.mode = "BUILDING"
    return true,"plan-armed"
end

function M.step(s,o,now)
    assert(type(s) == "table" and type(s.config) == "table", "state required")
    if s.mode == "STOPPED" then return result(s,"STOP","already-stopped") end
    -- Even after requesting a decline, never carry its command into a new
    -- trade session or repeat it after the original window has closed.
    if type(o) == "table" and o.tradeOpen == false then return stopped(s,"trade-closed") end
    if type(o) == "table" and o.session ~= s.session then return stopped(s,"trade-session-mismatch") end
    if s.mode == "DECLINE_REQUIRED" then return result(s,"DECLINE","decline-not-yet-confirmed") end
    if type(o) ~= "table" or not finite(now) then return decline(s,"invalid-observation") end
    if o.tradeOpen ~= true or o.contextOK ~= true or o.marketFresh ~= true
        or type(o.ourSig) ~= "string" or o.ourSig == ""
        or type(o.theirSig) ~= "string" or o.theirSig == ""
        or not integer(o.ourSlots,0,4) or not integer(o.theirSlots,0,4)
        or type(o.theirResolved) ~= "boolean"
        or type(o.quoteSafe) ~= "boolean"
        or (o.ourAccepted ~= true and o.ourAccepted ~= false)
        or (o.theirAccepted ~= true and o.theirAccepted ~= false) then
        return decline(s,"observation-or-market-unverified")
    end
    local counts,slots = copyCounts(o.ownItems)
    if not counts or slots ~= o.ourSlots then return decline(s,"own-slot-identity-unverified") end
    local pair = o.ourSig.."/"..o.theirSig

    -- Accepted states may never manipulate offers. A changed accepted quote is
    -- invalid even if its new nominal profit happens to be positive.
    if s.mode == "ACCEPTED_HOLD" then
        if not o.ourAccepted or not o.quoteSafe or not o.theirResolved
            or pair ~= s.acceptedPair then return decline(s,"accepted-quote-changed") end
        return result(s,"HOLD","accepted-quote-unchanged")
    end
    if o.ourAccepted then
        if s.mode ~= "MONITOR" or s.lastPair ~= pair or not o.quoteSafe
            or not o.theirResolved or slots == 0 or o.theirSlots == 0 then
            return decline(s,"manual-accept-without-current-proof")
        end
        s.mode = "ACCEPTED_HOLD"
        s.acceptedPair = pair
        return result(s,"HOLD","manual-accept-locked")
    end

    if s.mode == "AWAIT_REMOVAL" then
        if o.theirAccepted then return decline(s,"partner-accepted-during-withdrawal") end
        if now - s.clearingSince > s.config.clearSeconds then
            return decline(s,"total-withdrawal-timeout")
        end
        local valid,progress = subset(s.pending,counts)
        if not valid then return decline(s,"unexpected-own-offer-mutation") end
        if not progress then
            if now - s.pendingSince >= s.config.removalSeconds then
                return decline(s,"unverified-removal-timeout")
            end
            return result(s,"HOLD","awaiting-removal-proof")
        end
        -- The independent raw GUI signature must agree that the physical
        -- offer changed. A quantity delta with the same raw signature is not
        -- sufficient to acknowledge a native removal.
        if o.ourSig == s.pendingOurSig then
            return decline(s,"removal-signature-not-changed")
        end
        if slots == 0 then
            s.clearingSince = nil
            s.lastPair = pair
            s.lastOurCounts = counts
            return empty(s,now,o.theirSig,o.theirSlots)
        end
        s.lastPair = pair
        s.lastOurCounts = counts
        return beginRemoval(s,counts,o,now,"remove-next-verified-slot")
    end

    if s.mode == "BUILDING" then
        if o.theirAccepted then return decline(s,"partner-accepted-during-plan-build") end
        if o.theirSig ~= s.plan.opponentSignature then
            if slots > 0 then
                s.clearingSince = nil
                return beginRemoval(s,counts,o,now,"building-context-changed")
            end
            return empty(s,now,o.theirSig,o.theirSlots)
        end
        local valid = subset(s.plan.counts,counts)
        if not valid then
            if slots > 0 then
                s.clearingSince = nil
                return beginRemoval(s,counts,o,now,"unauthorized-plan-item")
            end
            return decline(s,"invalid-build-state")
        end
        if now - s.plan.started > s.config.buildSeconds then
            if slots > 0 then
                s.clearingSince = nil
                return beginRemoval(s,counts,o,now,"plan-build-timeout")
            end
            return empty(s,now,o.theirSig,o.theirSlots)
        end
        if same(counts,s.plan.counts) and o.quoteSafe and o.theirResolved then
            s.mode = "MONITOR"
            s.quoteApproved = true
            s.lastPair = pair
            s.lastOurCounts = counts
            s.plan = nil
            return result(s,"HOLD","planned-offer-verified")
        end
        return result(s,"HOLD","building-authorized-plan")
    end

    if s.mode == "WAIT_REPLAN" or s.mode == "PLAN_REQUESTED" then
        if o.theirAccepted then return decline(s,"partner-accepted-without-safe-offer") end
        if slots > 0 then
            s.clearingSince = nil
            return beginRemoval(s,counts,o,now,"unexpected-offer-during-replan")
        end
        if s.stableOtherSig ~= o.theirSig then
            s.stableOtherSig = o.theirSig
            s.stableSince = now
            s.mode = "WAIT_REPLAN"
        end
        if o.theirSlots == 0 then
            if not s.emptySince then s.emptySince = now end
            if now - s.emptySince >= s.config.emptySeconds then
                return decline(s,"opponent-empty-timeout")
            end
            return result(s,"HOLD","opponent-editing-or-empty")
        end
        s.emptySince = nil
        if not o.theirResolved then return result(s,"HOLD","opponent-items-unresolved") end
        if now - s.stableSince < s.config.stabilizeSeconds then
            return result(s,"HOLD","waiting-opponent-stability")
        end
        if s.mode == "PLAN_REQUESTED" then return result(s,"HOLD","awaiting-authorized-plan") end
        s.mode = "PLAN_REQUESTED"
        return result(s,"REQUEST_PLAN","stable-empty-local-offer")
    end

    if s.mode ~= "MONITOR" then return decline(s,"unknown-controller-mode") end
    if o.theirAccepted and (not o.quoteSafe or slots == 0
        or (s.lastPair and pair ~= s.lastPair)) then
        return decline(s,"opponent-accepted-unsafe-or-changed-quote")
    end
    if slots == 0 then
        s.lastPair = pair
        s.lastOurCounts = counts
        return empty(s,now,o.theirSig,o.theirSlots)
    end
    if (s.lastPair and pair ~= s.lastPair) or not o.quoteSafe or not o.theirResolved
        or o.theirSlots == 0 then
        s.clearingSince = nil
        return beginRemoval(s,counts,o,now,"physical-quote-changed-or-unsafe")
    end
    s.lastPair = pair
    s.lastOurCounts = counts
    return result(s,"HOLD","current-quote-unchanged")
end

return M
