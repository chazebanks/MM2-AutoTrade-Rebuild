-- PDIDDLER Part 5 real-server candidate observer v1
-- Read-only mirror for the observation GUI.
-- Uses the same public endpoint shape and the same policy.rankCandidates
-- as the actual Part 5 transport. Never teleports or mutates visited state.

local M={}

function M.new(policy)
    assert(type(policy)=="table","[PDIDDLER OBS] Part 5 policy missing")
    assert(type(policy.rankCandidates)=="function","[PDIDDLER OBS] rankCandidates missing")

    local HttpService=game:GetService("HttpService")
    local observer={}

    local function buildUrl(cursor)
        local url=
            "https://games.roblox.com/v1/games/"
            ..tostring(game.PlaceId)
            .."/servers/Public?sortOrder=Desc&excludeFullGames=true&limit=100"

        if type(cursor)=="string" and cursor~="" then
            url=url.."&cursor="..HttpService:UrlEncode(cursor)
        end
        return url
    end

    function observer:refresh(currentJobId,visited)
        local all={}
        local cursor=nil
        local pages=math.max(1,tonumber(policy.MaxPagesPerRefresh) or 1)

        for _=1,pages do
            local ok,body=pcall(function()
                return game:HttpGet(buildUrl(cursor),true)
            end)
            if not ok or type(body)~="string" or body=="" then
                return {candidates={},error="http:"..tostring(body)}
            end

            local jsonOk,decoded=pcall(function()
                return HttpService:JSONDecode(body)
            end)
            if not jsonOk or type(decoded)~="table" then
                return {candidates={},error="json:"..tostring(decoded)}
            end

            if type(decoded.data)=="table" then
                for _,entry in ipairs(decoded.data) do
                    if type(entry)=="table" then
                        all[#all+1]=entry
                    end
                end
            end

            local nextCursor=decoded.nextPageCursor
            if type(nextCursor)~="string" or nextCursor=="" then
                break
            end
            cursor=nextCursor
        end

        local ranked=policy.rankCandidates(all,currentJobId,visited)

        local n11,n10=0,0
        for _,entry in ipairs(ranked) do
            if tonumber(entry.playing)==11 then
                n11+=1
            elseif tonumber(entry.playing)==10 then
                n10+=1
            end
        end

        return {
            candidates=ranked,
            error=nil,
            count11=n11,
            count10=n10,
        }
    end

    return observer
end

return M
