-- Issue #1 test transport: the sole server-hop owner. No trading/detection logic.
-- Bounded discovery. Explicit failure permits retry; ambiguous progress holds.
local M={}
local STATE_KEY="PDIDDLER_P5_STATE_V1"
function M.bootstrap(policy,canTeleport)
    assert(type(policy)=="table" and type(policy.rankCandidates)=="function","P5 policy missing")
    assert(canTeleport==nil or type(canTeleport)=="function","P5 safety callback invalid")
    local Players=game:GetService("Players")
    local TS=game:GetService("TeleportService")
    local HS=game:GetService("HttpService")
    local LP=assert(Players.LocalPlayer,"LocalPlayer missing")
    local E=(getgenv and getgenv()) or _G
    local JOB=game.JobId
    local existing=E.PDIDDLER_PART5_CONTROLLER
    if type(existing)=="table" and existing.jobId==JOB then
        assert(existing.version==2,"legacy P5 owner present; rejoin")
        return existing
    end
    assert(E.PDIDDLER_HOPPING_SESSION==nil,"another hopper owns teleport")
    local session=(tonumber(E.PDIDDLER_PART5_SESSION) or 0)+1
    E.PDIDDLER_PART5_SESSION=session
    local S={visited={},visitedOrder={},hopping=false,terminal=false,attemptSerial=0}
    local C={version=2,session=session,jobId=JOB,state=S}
    E.PDIDDLER_PART5_CONTROLLER=C
    local function owner() return E.PDIDDLER_PART5_CONTROLLER==C and E.PDIDDLER_PART5_SESSION==session end
    local function alive() return owner() and game.JobId==JOB end
    function C:isAlive() return alive() end
    local function visited(id)
        if type(id)=="string" and id~="" and not S.visited[id] then
            S.visited[id]=true; S.visitedOrder[#S.visitedOrder+1]=id
        end
    end
    local ok,stored=pcall(function() return TS:GetTeleportSetting(STATE_KEY) end)
    if ok then
        if type(stored)=="string" then
            local decoded,value=pcall(function() return HS:JSONDecode(stored) end)
            stored=decoded and value or nil
        end
        if type(stored)=="table" and stored.version==1 and type(stored.visited)=="table" then
            for _,id in ipairs(stored.visited) do visited(id) end
        end
    end
    local function persist()
        local encoded,value=pcall(function() return HS:JSONEncode({version=1,visited=S.visitedOrder}) end)
        if not encoded or type(value)~="string" then return false end
        return pcall(function() TS:SetTeleportSetting(STATE_KEY,value) end)
    end
    local function terminal(reason,ambiguous)
        S.terminal=true; S.lastFailure=tostring(reason)
        S.hopping=ambiguous==true
        -- An uncertain teleport retains the global lock permanently in this
        -- client. A timeout is NOT proof Roblox abandoned the teleport.
        if not ambiguous and E.PDIDDLER_HOPPING_SESSION==session then E.PDIDDLER_HOPPING_SESSION=nil end
        warn("[PDIDDLER P5 V2] "..(ambiguous and "HOLD" or "STOP").." | "..S.lastFailure)
    end
    local function fetchPage(url)
        local done,success,body=false,false,nil
        local valid=true
        local co=task.spawn(function()
            local a,b=pcall(function() return game:HttpGet(url,true) end)
            if valid then success=a; body=b; done=true end
        end)
        local deadline=os.clock()+14
        while alive() and not done and os.clock()<deadline do task.wait(.05) end
        valid=false
        if not done then
            if type(task.cancel)=="function" then pcall(task.cancel,co) end
            return nil,alive() and "server-list-timeout" or "stale-owner"
        end
        if not success or type(body)~="string" or body=="" then return nil,"server-list-http:"..tostring(body) end
        local parsed,page=pcall(function() return HS:JSONDecode(body) end)
        if not parsed or type(page)~="table" or type(page.data)~="table" then return nil,"server-list-json" end
        return page
    end
    local function candidates()
        local all,seenCursors={},{}
        local cursor=nil
        for _=1,math.min(5,math.max(1,tonumber(policy.MaxPagesPerRefresh) or 5)) do
            if not alive() then return nil,"stale-owner" end
            local url="https://games.roblox.com/v1/games/"..tostring(game.PlaceId).."/servers/Public?sortOrder=Desc&excludeFullGames=true&limit=100"
            if cursor then url=url.."&cursor="..HS:UrlEncode(cursor) end
            local page,why=fetchPage(url)
            if not page then return nil,why end
            for _,entry in ipairs(page.data) do all[#all+1]=entry end
            local nextCursor=page.nextPageCursor
            if type(nextCursor)~="string" or nextCursor=="" or seenCursors[nextCursor] then break end
            seenCursors[nextCursor]=true; cursor=nextCursor
        end
        return policy.rankCandidates(all,JOB,S.visited)
    end
    local function attempt(entry)
        if not alive() then return "stop","stale-owner" end
        local id=tostring(entry.id or "")
        visited(id)
        if not persist() then return "stop","visited-state-save-failed" end
        S.attemptSerial=S.attemptSerial+1
        local serial=S.attemptSerial
        local started=os.clock()
        local a={serial=serial,jobId=id,sourceJob=JOB,startedAt=started,progress=false}
        S.currentAttempt=a
        local failure,callDone,callOk,callErr=nil,false,false,nil
        local unattributedFailure=false
        local safetyBlocked=nil
        local active=true
        local function current() return active and owner() and S.currentAttempt==a end
        local progressConn=LP.OnTeleport:Connect(function(state)
            if not current() then return end
            if state==Enum.TeleportState.Failed then unattributedFailure=true
            elseif state==Enum.TeleportState.Started or state==Enum.TeleportState.WaitingForServer or state==Enum.TeleportState.InProgress then
                a.progress=true
            end
        end)
        local failureConn=TS.TeleportInitFailed:Connect(function(player,result,message,place,options)
            if player~=LP or not current() or tonumber(place)~=tonumber(game.PlaceId) then return end
            local target=nil
            pcall(function() target=options and options.ServerInstanceId end)
            if type(target)~="string" or target=="" then unattributedFailure=true; return end
            if target~=id then return end
            failure="init-failed:"..tostring(result)..":"..tostring(message)
        end)
        local function cleanup(keepAttempt)
            active=false; progressConn:Disconnect(); failureConn:Disconnect()
            if not keepAttempt and S.currentAttempt==a then S.currentAttempt=nil end
        end
        task.spawn(function()
            if canTeleport then
                local checked,allowed,why=pcall(canTeleport)
                if not checked or not allowed then
                    safetyBlocked=tostring(checked and why or allowed)
                    callDone=true
                    return
                end
            end
            callOk,callErr=pcall(function() TS:TeleportToPlaceInstance(game.PlaceId,id,LP) end)
            callDone=true
        end)
        while owner() do
            if game.JobId~=JOB then cleanup(false); return "success","job-changed" end
            if safetyBlocked then cleanup(false); return "stop","safety-blocked:"..safetyBlocked end
            -- A call may still be suspended even after a failure event. Do not
            -- start the next call until this one has actually returned.
            if callDone and failure then cleanup(false); return "retry",failure end
            if unattributedFailure then cleanup(true); return "hold","unattributed-teleport-failure" end
            if callDone and not callOk and not a.progress then cleanup(false); return "retry","call-error:"..tostring(callErr) end
            local age=os.clock()-started
            if (not a.progress and age>=12) or age>=35 then
                cleanup(true)
                return "hold",a.progress and "teleport-progress-timeout" or "teleport-outcome-unknown"
            end
            task.wait(.1)
        end
        cleanup(true); return "hold","owner-changed-during-teleport"
    end
    local function run()
        visited(JOB)
        if not persist() then terminal("visited-state-save-failed",false); return end
        local attempts=0
        -- Two discovery passes, at most six explicit-failure retries.
        for refresh=1,2 do
            if not alive() then return end
            local list,why=candidates()
            if list then
                for _,entry in ipairs(list) do
                    if attempts>=6 then break end
                    attempts=attempts+1
                    local outcome,reason=attempt(entry)
                    S.lastFailure=reason
                    if outcome=="success" then
                        S.hopping=false
                        if E.PDIDDLER_HOPPING_SESSION==session then E.PDIDDLER_HOPPING_SESSION=nil end
                        return
                    elseif outcome=="hold" then terminal(reason,true); return
                    elseif outcome=="stop" then terminal(reason,false); return end
                end
            else S.lastFailure=why end
            if refresh==1 and attempts<6 then task.wait(5) end
        end
        terminal(S.lastFailure or "no-eligible-11-or-10-player-servers",false)
    end
    function C:hopNow(reason)
        if not alive() then return false,"stale-owner" end
        if S.hopping or S.terminal or E.PDIDDLER_HOPPING_SESSION~=nil then return false,"hop-owned-or-terminal" end
        S.hopping=true; S.lastReason=tostring(reason); E.PDIDDLER_HOPPING_SESSION=session
        task.spawn(function()
            local ran,why=xpcall(run,function(e) return tostring(e) end)
            if not ran then terminal("transport-exception:"..tostring(why),S.currentAttempt~=nil) end
        end)
        return true
    end
    function C:handleBotRejected(reason) return self:hopNow(reason or "bot-rejected") end
    function C:stop()
        if S.hopping or S.currentAttempt then return false,"teleport-owned" end
        if owner() then E.PDIDDLER_PART5_SESSION=session+1 end
        return true
    end
    return C
end
return M
