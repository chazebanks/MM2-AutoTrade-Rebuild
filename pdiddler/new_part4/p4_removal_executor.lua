-- New Part 4 / Stage 10: pure one-shot physical-removal command ledger.
-- No Roblox services, clicks, trade remotes, networking or auto-accept.
-- A separate, bound native adapter performs at most one attempt; only a later
-- independent observation may acknowledge a removal.
local M = {}

local function integer(x, lo, hi)
    return type(x)=="number" and x==x and x~=math.huge and x~=-math.huge
        and x==math.floor(x) and x>=lo and x<=hi
end
local function validTime(t) return type(t)=="number" and t==t and t>=0 and t<math.huge end
local function countRows(obs)
    if type(obs)~="table" or type(obs.ownItems)~="table"
        or #obs.ownItems>4 or not integer(obs.ourSlots,0,4)
        or #obs.ownItems~=obs.ourSlots then return nil,"slot-count-unverified" end
    local seen,byId={},{}
    local selected
    for _,r in ipairs(obs.ownItems) do
        if type(r)~="table" or not integer(r.slot,1,4) or seen[r.slot]
            or type(r.id)~="string" or r.id==""
            or not integer(r.qty,1,1000000) then return nil,"own-row-unverified" end
        seen[r.slot]=true
        byId[r.id]=(byId[r.id] or 0)+r.qty
        if not selected or r.slot>selected.slot then selected=r end
    end
    return {counts=byId,selection=selected},nil
end
local function equivalent(a,b)
    for id,n in pairs(a) do if b[id]~=n then return false end end
    for id,n in pairs(b) do if a[id]~=n then return false end end
    return true
end
local function stop(s,reason)
    s.mode="STOPPED";s.reason=reason;s.pending=nil
    return "STOP",reason
end
local function escalate(s,reason)
    s.mode="ESCALATE";s.reason=reason
    -- Caller must send fresh state to the safety controller. Never repeat a click.
    return "ESCALATE",reason
end
local function validateObs(s,o)
    if type(o)~="table" then return nil,"observation-missing" end
    if o.tradeOpen==false then return nil,"trade-closed" end
    if o.session~=s.session then return nil,"session-mismatch" end
    if o.tradeOpen~=true or o.contextOK~=true
        or type(o.ourSig)~="string" or o.ourSig==""
        or type(o.theirSig)~="string" or o.theirSig==""
        or o.ourAccepted~=false or o.theirAccepted~=false then
        return nil,"context-or-acceptance-unverified" end
    -- Removal is protective exposure reduction. No price/quoteSafe conclusion is
    -- drawn; stale prices cannot authorize a new item insertion or acceptance.
    local rows,why=countRows(o)
    if not rows then return nil,why end
    return rows,nil
end

function M.new(session,opts)
    assert(type(session)=="string" and session~="","session required")
    opts=opts or {}
    local proofSeconds=opts.proofSeconds or 1.0
    local dispatchSeconds=opts.dispatchSeconds or 0.25
    assert(validTime(proofSeconds) and proofSeconds>0 and proofSeconds<=5,"bad proofSeconds")
    assert(validTime(dispatchSeconds) and dispatchSeconds>0 and dispatchSeconds<=5,"bad dispatchSeconds")
    return {session=session,mode="IDLE",serial=0,pending=nil,
        proofSeconds=proofSeconds,dispatchSeconds=dispatchSeconds,reason="ready"}
end

function M.prepare(s,command,o,now)
    assert(type(s)=="table" and s.session and s.mode,"executor required")
    if s.mode=="STOPPED" then return "STOP","already-stopped" end
    if s.mode=="ESCALATE" then return "ESCALATE",s.reason end
    if s.mode~="IDLE" then return "HOLD","one-removal-already-pending" end
    if command~="REMOVE_ONE" then return "HOLD","no-physical-removal-request" end
    if not validTime(now) then return escalate(s,"invalid-clock") end
    local rows,why=validateObs(s,o)
    if not rows then
        if why=="trade-closed" or why=="session-mismatch" then return stop(s,why) end
        return escalate(s,why)
    end
    if not rows.selection then return escalate(s,"no-local-items-to-remove") end
    s.serial=s.serial+1
    local selected=rows.selection
    local intent={kind="REMOVE_ONE",session=s.session,token=s.serial,
        ourSig=o.ourSig,theirSig=o.theirSig,slot=selected.slot,id=selected.id,qty=selected.qty}
    s.pending={token=intent.token,slot=intent.slot,id=intent.id,qty=intent.qty,
        ourSig=intent.ourSig,theirSig=intent.theirSig,before=rows.counts,reservedAt=now}
    s.mode="RESERVED"
    return "DISPATCH",intent
end

function M.dispatched(s,intent,receipt,now)
    assert(type(s)=="table","executor required")
    if s.mode=="STOPPED" then return "STOP","already-stopped" end
    if s.mode=="ESCALATE" then return "ESCALATE",s.reason end
    if s.mode~="RESERVED" then return "ESCALATE","no-reserved-action" end
    local p=s.pending
    if type(intent)~="table" or intent.token~=p.token or intent.session~=s.session
        or intent.id~=p.id or intent.slot~=p.slot or intent.qty~=p.qty
        or intent.ourSig~=p.ourSig or intent.theirSig~=p.theirSig then
        return escalate(s,"dispatch-intent-mismatch") end
    if not validTime(now) or now<p.reservedAt or now-p.reservedAt>s.dispatchSeconds then
        return escalate(s,"dispatch-window-expired") end
    if type(receipt)~="table" or receipt.attempted~=true
        or receipt.status~="SENT_ONCE" then return escalate(s,"physical-removal-not-dispatched") end
    s.mode="SENT"
    p.sentAt=now
    return "WAIT","await-independent-removal-proof"
end

function M.observe(s,o,now)
    assert(type(s)=="table","executor required")
    if s.mode=="STOPPED" then return "STOP","already-stopped" end
    if s.mode=="ESCALATE" then return "ESCALATE",s.reason end
    if s.mode=="IDLE" then return "HOLD","no-pending-removal" end
    if not validTime(now) then return escalate(s,"invalid-clock") end
    local p=s.pending
    local rows,why=validateObs(s,o)
    if not rows then
        if why=="trade-closed" or why=="session-mismatch" then return stop(s,why) end
        return escalate(s,why)
    end
    if s.mode=="RESERVED" then
        if now-p.reservedAt>=s.dispatchSeconds then return escalate(s,"unconsumed-removal-reservation") end
        return "HOLD","awaiting-single-dispatch"
    end
    if s.mode~="SENT" then return escalate(s,"unexpected-executor-phase") end
    if now<p.sentAt then return escalate(s,"clock-reversed") end
    local after=rows.counts
    for id,qty in pairs(after) do
        if not p.before[id] or qty>p.before[id] then
            return escalate(s,"new-or-increased-local-offer-item")
        end
    end
    local changed=false
    for id,qty in pairs(p.before) do
        local n=after[id] or 0
        if n<qty then
            changed=true
            if id~=p.id then return escalate(s,"non-target-item-removed") end
        end
    end
    if not changed then
        if o.ourSig~=p.ourSig then return escalate(s,"signature-changed-without-item-reduction") end
        if now-p.sentAt>=s.proofSeconds then return escalate(s,"removal-unverified-timeout") end
        return "HOLD","waiting-for-physical-proof"
    end
    if o.ourSig==p.ourSig then return escalate(s,"quantity-change-without-physical-signature") end
    if equivalent(p.before,after) then return escalate(s,"no-reduction") end
    s.mode="IDLE";s.pending=nil;s.reason="verified-target-reduced"
    return "VERIFIED","verified-target-reduced"
end

function M.stop(s,reason)
    assert(type(s)=="table","executor required")
    return stop(s,tostring(reason or "operator-stop"))
end
return M
