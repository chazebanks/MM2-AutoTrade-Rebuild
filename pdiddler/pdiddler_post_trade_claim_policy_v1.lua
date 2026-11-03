-- Pure post-trade reward-claim state machine.
-- No Roblox services, GUI objects, remotes, or scheduler calls.
local M={}

M.RetryDelay=0.65
M.MaxAttemptsPerStep=3
M.AbsentCompleteDelay=0.35

local function trimLower(s)
    return tostring(s or ""):lower():gsub("^%s+",""):gsub("%s+$","")
end

function M.parse(text)
    local s=trimLower(text)
    local a,b=s:match("^claim%s*%(%s*(%d+)%s*/%s*(%d+)%s*%)$")
    local current=tonumber(a)
    local total=tonumber(b)

    if not current or not total then return nil,nil end
    if current<1 or total<1 or current>total then return nil,nil end
    if total>12 then return nil,nil end

    return current,total
end

function M.newSession(now)
    now=tonumber(now) or 0
    return {
        startedAt=now,
        seenAny=false,
        lastSeenAt=nil,
        lastText=nil,
        attempts=0,
        lastTapAt=nil,
    }
end

local function normalizeClaimText(text)
    local current,total=M.parse(text)
    if not current then return nil,nil,nil end
    return string.format("claim (%d/%d)",current,total),current,total
end

function M.observe(state,text,now)
    assert(type(state)=="table","claim state required")
    now=tonumber(now) or 0

    local normalized,current,total=normalizeClaimText(text)

    if normalized then
        state.seenAny=true
        state.lastSeenAt=now

        if state.lastText~=normalized then
            state.lastText=normalized
            state.attempts=0
            state.lastTapAt=nil
        end

        if state.attempts>=M.MaxAttemptsPerStep then
            local elapsed=state.lastTapAt and (now-state.lastTapAt) or math.huge
            if elapsed+1e-9>=M.RetryDelay then
                return "stuck",{
                    current=current,
                    total=total,
                    attempts=state.attempts,
                }
            end
            return "wait",{current=current,total=total}
        end

        if state.attempts==0 then
            return "tap",{
                current=current,
                total=total,
                attempt=1,
            }
        end

        local elapsed=state.lastTapAt and (now-state.lastTapAt) or math.huge
        if elapsed>=M.RetryDelay then
            return "tap",{
                current=current,
                total=total,
                attempt=state.attempts+1,
            }
        end

        return "wait",{current=current,total=total}
    end

    if state.seenAny
        and state.lastSeenAt
        and now-state.lastSeenAt>=M.AbsentCompleteDelay
    then
        return "complete",{}
    end

    return "wait",{}
end

function M.noteTap(state,text,now,success)
    assert(type(state)=="table","claim state required")
    if success~=true then return false end

    local normalized=normalizeClaimText(text)
    if not normalized then return false end

    if state.lastText~=normalized then
        state.lastText=normalized
        state.attempts=0
    end

    state.attempts=(tonumber(state.attempts) or 0)+1
    state.lastTapAt=tonumber(now) or 0
    return true
end

return M
