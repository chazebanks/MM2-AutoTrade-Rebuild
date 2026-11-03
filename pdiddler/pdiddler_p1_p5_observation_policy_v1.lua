-- PDIDDLER P1 + P5 observation policy v1
-- Pure testable state only. No Roblox services.

local M={}

M.ObservationSeconds=30

local function trim(s)
    return (tostring(s or ""):gsub("^%s+",""):gsub("%s+$",""))
end

function M.normalizeManualMessage(text)
    return string.lower(trim(text))
end

function M.markManual(state,text,remaining)
    local out={}
    if type(state)=="table" then
        for k,v in pairs(state) do
            out[k]=v
        end
    end

    if out.manualBotted==true then
        return out,false
    end

    if M.normalizeManualMessage(text)~="botted" then
        out.manualBotted=out.manualBotted==true
        return out,false
    end

    out.manualBotted=true
    out.manualRemaining=tonumber(remaining) or 0
    return out,true
end

function M.actionLabel(snapshot)
    snapshot=type(snapshot)=="table" and snapshot or {}

    if snapshot.character~=true then
        return "Character Loading"
    end

    local health=tonumber(snapshot.health)
    if health~=nil and health<=0 then
        return "Dead"
    end

    if snapshot.sit==true then
        return "Sitting"
    end

    local state=tostring(snapshot.humanoidState or "")
    if state=="Jumping" then
        return "Jumping"
    end
    if state=="Freefall" then
        return "Freefall"
    end

    if snapshot.moving==true then
        return "Moving"
    end

    return "Idle"
end

return M
