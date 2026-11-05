-- Stage 14: pure preflight stability guard for a ONE-SHOT defensive withdrawal.
-- This module does not click, query inventories, authorize prices or accept.
-- Each sample must come from a fresh, session-bound Stage 9 capture.
local M = {}

local function finite(n)
    return type(n)=="number" and n==n and n>=0 and n<math.huge
end
local function integer(n,low,high)
    return finite(n) and n==math.floor(n) and n>=low and n<=high
end
local function part(v)
    v=tostring(v)
    return tostring(#v)..":"..v
end
local function identity(o)
    if type(o)~="table" or o.tradeOpen~=true or o.contextOK~=true
        or o.marketFresh~=true or o.ourAccepted~=false or o.theirAccepted~=false
        or type(o.ourSig)~="string" or o.ourSig==""
        or type(o.theirSig)~="string" or o.theirSig==""
        or not integer(o.ourSlots,1,4) or not integer(o.theirSlots,0,4)
        or type(o.ownItems)~="table" or #o.ownItems~=o.ourSlots
        or type(o.theirResolved)~="boolean" then return nil end
    local rows,seen={},{}
    for _,it in ipairs(o.ownItems) do
        if type(it)~="table" or not integer(it.slot,1,4) or seen[it.slot]
            or type(it.id)~="string" or it.id==""
            or not integer(it.qty,1,1000000) then return nil end
        seen[it.slot]=true
        rows[#rows+1]=it
    end
    table.sort(rows,function(a,b) return a.slot<b.slot end)
    local keys={}
    for _,it in ipairs(rows) do
        keys[#keys+1]=part(it.slot)..part(it.id)..part(it.qty)
    end
    return table.concat(keys,"|")
end
function M.new(session,opts)
    assert(type(session)=="string" and session~="","session required")
    opts=opts or {}
    local seconds=opts.minSeconds or 0.20
    local samples=opts.minSamples or 3
    local gap=opts.maxGapSeconds or 0.30
    assert(finite(seconds) and seconds>=0.16 and seconds<=1.0,"invalid minSeconds")
    assert(integer(samples,3,12),"invalid minSamples")
    assert(finite(gap) and gap>=0.16 and gap<=1.0,"invalid maxGapSeconds")
    return {session=session,minSeconds=seconds,minSamples=samples,
        maxGapSeconds=gap,ourSig=nil,theirSig=nil,rowKey=nil,
        samples=0,firstAt=nil,lastAt=nil}
end
function M.reset(s)
    s.ourSig=nil;s.theirSig=nil;s.rowKey=nil
    s.samples=0;s.firstAt=nil;s.lastAt=nil
end
function M.observe(s,o,now)
    assert(type(s)=="table" and s.session,"stability gate required")
    if not finite(now) or type(o)~="table" or o.session~=s.session then
        M.reset(s);return false,"invalid-time-or-session"
    end
    local rowKey=identity(o)
    if not rowKey then M.reset(s);return false,"unverified-or-accepted-snapshot" end
    if s.lastAt and now<=s.lastAt then
        -- Same-time UI changes still invalidate previous evidence; repeated
        -- timestamps can never count as separate independent samples.
        if now<s.lastAt or s.ourSig~=o.ourSig
            or s.theirSig~=o.theirSig or s.rowKey~=rowKey then M.reset(s) end
        return false,"non-advancing-time"
    end
    if s.lastAt and now-s.lastAt>s.maxGapSeconds then
        M.reset(s)
    end
    if s.ourSig~=o.ourSig or s.theirSig~=o.theirSig or s.rowKey~=rowKey then
        M.reset(s)
        s.ourSig=o.ourSig;s.theirSig=o.theirSig;s.rowKey=rowKey
        s.firstAt=now;s.lastAt=now;s.samples=1
        return false,"new-or-changed-snapshot"
    end
    s.samples=s.samples+1;s.lastAt=now
    if s.samples<s.minSamples or now-s.firstAt<s.minSeconds then
        return false,"awaiting-stability"
    end
    return true,"stable-matched-snapshots"
end
return M
