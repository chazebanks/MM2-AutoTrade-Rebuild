-- pdiddler Part 5 server hopper pure policy v1
-- Pure state/ranking logic only. No Roblox services, HTTP, teleport, or executor APIs.

local M={}

M.ExhaustionSeconds=45
M.RefreshSeconds=5
M.MaxPagesPerRefresh=5

local function copyState(state)
    return {
        since=state and state.since or nil,
    }
end

function M.stepExhaustion(state,now,signals)
    local out=copyState(state)
    now=tonumber(now) or 0
    signals=signals or {}

    local criticalBusy=signals.criticalBusy==true
    local tradableAvailable=signals.tradableAvailable==true
    local queueExhausted=signals.queueExhausted==true
    local scannerPending=signals.scannerPending==true

    if criticalBusy or tradableAvailable or not queueExhausted then
        out.since=nil
        return out,"active"
    end

    if out.since==nil then
        out.since=now
    end

    local elapsed=math.max(0,now-(tonumber(out.since) or now))

    if elapsed+1e-9>=M.ExhaustionSeconds then
        if scannerPending then
            return out,"blocked"
        end
        return out,"final-scan"
    end

    return out,"countdown"
end

function M.rankCandidates(servers,currentJobId,visited)
    servers=type(servers)=="table" and servers or {}
    visited=type(visited)=="table" and visited or {}
    currentJobId=tostring(currentJobId or "")

    local out={}
    local seen={}

    for _,server in ipairs(servers) do
        if type(server)=="table" then
            local id=tostring(server.id or "")
            local playing=tonumber(server.playing)
            local maxPlayers=tonumber(server.maxPlayers)

            if id~=""
                and id~=currentJobId
                and not visited[id]
                and not seen[id]
                and maxPlayers==12
                and (playing==11 or playing==10)
            then
                seen[id]=true
                out[#out+1]=server
            end
        end
    end

    table.sort(out,function(a,b)
        local ap=tonumber(a.playing) or -1
        local bp=tonumber(b.playing) or -1
        if ap~=bp then
            return ap>bp
        end
        return tostring(a.id or "")<tostring(b.id or "")
    end)

    return out
end

return M
