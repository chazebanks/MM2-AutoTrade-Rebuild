-- pdiddler Part 5 server hopper v1
-- Transport/lifecycle only:
--   * visited-server persistence across same-game teleports
--   * public 11/12 -> 10/12 server discovery
--   * serialized specific-instance teleport attempts
--   * immediate + late failure recovery
--   * bot-reject re-hop entry point
--
-- No scanner, trading, market, webhook, claim, or final-Accept logic.

local M={}

local STATE_KEY="PDIDDLER_P5_STATE_V1"
local NO_EVIDENCE_TIMEOUT=12.0

function M.bootstrap(policy)
    assert(type(policy)=="table","[PDIDDLER P5] policy missing")
    assert(type(policy.rankCandidates)=="function","[PDIDDLER P5] policy.rankCandidates missing")
    assert(tonumber(policy.RefreshSeconds),"[PDIDDLER P5] policy.RefreshSeconds missing")
    assert(tonumber(policy.MaxPagesPerRefresh),"[PDIDDLER P5] policy.MaxPagesPerRefresh missing")

    local Players=game:GetService("Players")
    local TeleportService=game:GetService("TeleportService")
    local HttpService=game:GetService("HttpService")
    local LP=Players.LocalPlayer

    local ENV=(getgenv and getgenv()) or _G

    local existing=ENV.PDIDDLER_PART5_CONTROLLER
    if type(existing)=="table"
        and existing.jobId==game.JobId
        and type(existing.isAlive)=="function"
        and existing:isAlive()
    then
        print("[PDIDDLER P5] REUSE EXISTING CONTROLLER | duplicate execution suppressed")
        return existing
    end

    ENV.PDIDDLER_PART5_SESSION=(tonumber(ENV.PDIDDLER_PART5_SESSION) or 0)+1
    local SESSION=ENV.PDIDDLER_PART5_SESSION

    local S={
        visited={},
        visitedOrder={},
        hopping=false,
        attemptSerial=0,
        lastReason=nil,
        lastFailure=nil,
        currentAttempt=nil,
    }

    local controller={
        session=SESSION,
        jobId=game.JobId,
        state=S,
    }

    ENV.PDIDDLER_PART5_CONTROLLER=controller

    local function alive()
        return ENV.PDIDDLER_PART5_SESSION==SESSION
            and ENV.PDIDDLER_PART5_CONTROLLER==controller
    end

    function controller:isAlive()
        return alive()
    end

    local function addVisitedRaw(id)
        id=tostring(id or "")
        if id=="" or S.visited[id] then
            return false
        end
        S.visited[id]=true
        S.visitedOrder[#S.visitedOrder+1]=id
        return true
    end

    local function loadPersisted()
        local ok,value=pcall(function()
            return TeleportService:GetTeleportSetting(STATE_KEY)
        end)
        if not ok or value==nil then
            return
        end

        local decoded=nil
        if type(value)=="string" and value~="" then
            local jsonOk,jsonValue=pcall(function()
                return HttpService:JSONDecode(value)
            end)
            if jsonOk and type(jsonValue)=="table" then
                decoded=jsonValue
            end
        elseif type(value)=="table" then
            decoded=value
        end

        if type(decoded)~="table" or tonumber(decoded.version)~=1 then
            return
        end

        if type(decoded.visited)=="table" then
            for _,id in ipairs(decoded.visited) do
                if type(id)=="string" and id~="" then
                    addVisitedRaw(id)
                end
            end
        end
    end

    local function persistState()
        local payload={
            version=1,
            visited=S.visitedOrder,
        }

        local ok,encoded=pcall(function()
            return HttpService:JSONEncode(payload)
        end)
        if not ok or type(encoded)~="string" then
            warn("[PDIDDLER P5] STATE ENCODE FAILED | "..tostring(encoded))
            return false
        end

        local saved,saveErr=pcall(function()
            TeleportService:SetTeleportSetting(STATE_KEY,encoded)
        end)
        if not saved then
            warn("[PDIDDLER P5] STATE SAVE FAILED | "..tostring(saveErr))
            return false
        end

        return true
    end

    local function markVisited(id)
        return addVisitedRaw(id)
    end

    loadPersisted()

    local function shortJob(id)
        id=tostring(id or "")
        if #id<=10 then return id end
        return string.sub(id,1,8)..".."
    end

    local function serverUrl(cursor)
        local url=
            "https://games.roblox.com/v1/games/"
            ..tostring(game.PlaceId)
            .."/servers/Public?sortOrder=Desc&excludeFullGames=true&limit=100"

        if type(cursor)=="string" and cursor~="" then
            url=url.."&cursor="..HttpService:UrlEncode(cursor)
        end

        return url
    end

    local function fetchCandidates()
        local all={}
        local cursor=nil

        for _=1,math.max(1,tonumber(policy.MaxPagesPerRefresh) or 1) do
            if not alive() then
                return nil,"stale-session"
            end

            local ok,body=pcall(function()
                return game:HttpGet(serverUrl(cursor),true)
            end)
            if not ok or type(body)~="string" or body=="" then
                return nil,"server-list-http:"..tostring(body)
            end

            local jsonOk,decoded=pcall(function()
                return HttpService:JSONDecode(body)
            end)
            if not jsonOk or type(decoded)~="table" then
                return nil,"server-list-json:"..tostring(decoded)
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

        local ranked=policy.rankCandidates(all,game.JobId,S.visited)

        local n11,n10=0,0
        for _,entry in ipairs(ranked) do
            if tonumber(entry.playing)==11 then
                n11+=1
            elseif tonumber(entry.playing)==10 then
                n10+=1
            end
        end

        print(
            "[PDIDDLER P5] SERVERS",
            "| 11/12="..tostring(n11),
            "| 10/12="..tostring(n10),
            "| visited="..tostring(#S.visitedOrder)
        )

        return ranked,nil
    end

    local function attemptCandidate(entry)
        local jobId=tostring(entry and entry.id or "")
        if jobId=="" then
            return false,"empty-job-id"
        end

        local sourceJob=game.JobId

        -- Candidate is excluded before the call so a full/failed target is
        -- never immediately selected again in this teleport chain.
        markVisited(jobId)
        persistState()

        S.attemptSerial+=1
        local serial=S.attemptSerial
        local failure=nil
        local sawProgress=false

        S.currentAttempt={
            serial=serial,
            jobId=jobId,
            sourceJob=sourceJob,
            startedAt=os.clock(),
        }

        local onTeleportConn
        local initFailedConn

        local function cleanup()
            if onTeleportConn then
                onTeleportConn:Disconnect()
                onTeleportConn=nil
            end
            if initFailedConn then
                initFailedConn:Disconnect()
                initFailedConn=nil
            end
            if S.currentAttempt and S.currentAttempt.serial==serial then
                S.currentAttempt=nil
            end
        end

        onTeleportConn=LP.OnTeleport:Connect(function(teleportState,_placeId,_spawnName)
            if not alive()
                or not S.currentAttempt
                or S.currentAttempt.serial~=serial
            then
                return
            end

            if teleportState==Enum.TeleportState.Failed then
                failure="onteleport-failed"
            elseif teleportState==Enum.TeleportState.Started
                or teleportState==Enum.TeleportState.WaitingForServer
                or teleportState==Enum.TeleportState.InProgress
            then
                sawProgress=true
            end
        end)

        initFailedConn=TeleportService.TeleportInitFailed:Connect(
            function(player,teleportResult,errorMessage,placeId,teleportOptions)
                if player~=LP
                    or not alive()
                    or not S.currentAttempt
                    or S.currentAttempt.serial~=serial
                then
                    return
                end

                if tonumber(placeId)~=tonumber(game.PlaceId) then
                    return
                end

                local optionJob=nil
                pcall(function()
                    optionJob=teleportOptions and teleportOptions.ServerInstanceId
                end)

                if type(optionJob)=="string"
                    and optionJob~=""
                    and optionJob~=jobId
                then
                    return
                end

                failure=
                    "init-failed:"
                    ..tostring(teleportResult)
                    ..":"
                    ..tostring(errorMessage)
            end
        )

        local callOk,callErr=pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId,jobId,LP)
        end)

        if not callOk then
            cleanup()
            return false,"call-error:"..tostring(callErr)
        end

        local started=os.clock()

        while alive() do
            if game.JobId~=sourceJob then
                cleanup()
                return true,"job-changed"
            end

            if failure then
                local why=failure
                cleanup()
                return false,why
            end

            local age=os.clock()-started
            if not sawProgress and age>=NO_EVIDENCE_TIMEOUT then
                cleanup()
                return false,"no-teleport-evidence"
            end

            -- Once Roblox reports Started/Waiting/InProgress, do not launch a
            -- competing teleport. Explicit failure or the actual teleport owns
            -- the lifecycle from here.
            task.wait(0.10)
        end

        cleanup()
        return false,"stale-session"
    end

    local function hopLoop(reason)
        S.lastReason=tostring(reason or "unspecified")

        markVisited(game.JobId)
        persistState()

        while alive() and ENV.PDIDDLER_HOPPING_SESSION==SESSION do
            local candidates,why=fetchCandidates()

            if not candidates then
                S.lastFailure=why
                warn("[PDIDDLER P5] SERVER LIST FAILED | "..tostring(why))
                task.wait(tonumber(policy.RefreshSeconds) or 5)
                continue
            end

            if #candidates==0 then
                print(
                    "[PDIDDLER P5] NO TARGET SERVERS | refresh in "
                    ..tostring(policy.RefreshSeconds)
                    .."s"
                )
                task.wait(tonumber(policy.RefreshSeconds) or 5)
                continue
            end

            for _,entry in ipairs(candidates) do
                if not alive() or ENV.PDIDDLER_HOPPING_SESSION~=SESSION then
                    break
                end

                local jobId=tostring(entry.id or "")
                local playing=tonumber(entry.playing) or -1

                print(
                    "[PDIDDLER P5] HOP ATTEMPT",
                    "| "..tostring(playing).."/12",
                    "| "..shortJob(jobId)
                )

                local ok,attemptWhy=attemptCandidate(entry)
                if ok then
                    return
                end

                S.lastFailure=attemptWhy
                print(
                    "[PDIDDLER P5] HOP FAILED",
                    "| "..shortJob(jobId),
                    "| "..tostring(attemptWhy),
                    "| trying next"
                )
            end

            if alive() and ENV.PDIDDLER_HOPPING_SESSION==SESSION then
                task.wait(tonumber(policy.RefreshSeconds) or 5)
            end
        end

        S.hopping=false
        if ENV.PDIDDLER_HOPPING_SESSION==SESSION then
            ENV.PDIDDLER_HOPPING_SESSION=nil
        end
    end

    function controller:hopNow(reason)
        if not alive() then
            return false,"stale-session"
        end

        if S.hopping or ENV.PDIDDLER_HOPPING_SESSION==SESSION then
            return false,"already-hopping"
        end

        if ENV.PDIDDLER_HOPPING_SESSION~=nil
            and ENV.PDIDDLER_HOPPING_SESSION~=SESSION
        then
            return false,"another-hopper-active"
        end

        S.hopping=true
        ENV.PDIDDLER_HOPPING_SESSION=SESSION

        task.spawn(function()
            hopLoop(reason)
        end)

        return true,nil
    end

    function controller:handleBotRejected(reason)
        print(
            "[PDIDDLER P5] BOT SERVER REJECTED | re-hopping",
            "| "..tostring(reason or "part1")
        )
        return self:hopNow(reason or "part1-bot-rejected")
    end

    function controller:stop()
        if not alive() then return end
        ENV.PDIDDLER_PART5_SESSION=SESSION+1
        if ENV.PDIDDLER_HOPPING_SESSION==SESSION then
            ENV.PDIDDLER_HOPPING_SESSION=nil
        end
        S.hopping=false
    end

    return controller
end

return M
