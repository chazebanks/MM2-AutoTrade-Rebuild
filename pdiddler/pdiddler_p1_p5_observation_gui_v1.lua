-- PDIDDLER P1 + P5 observation GUI v1
-- Recording-only observer. No teleport/trade authority.

local M={}

local GUI_NAME="PDIDDLER_P1_P5_OBSERVATION_GUI"
local CANDIDATE_REFRESH_SECONDS=5
local ACTION_REFRESH_SECONDS=0.5
local MAX_CANDIDATES=5

function M.new(config)
    assert(type(config)=="table","[PDIDDLER OBS] config missing")
    local policy=config.policy
    local candidateObserver=config.candidateObserver
    assert(type(policy)=="table","[PDIDDLER OBS] policy missing")
    assert(type(candidateObserver)=="table","[PDIDDLER OBS] candidate observer missing")
    assert(type(config.sessionAlive)=="function","[PDIDDLER OBS] sessionAlive missing")

    local Players=game:GetService("Players")
    local TextChatService=game:GetService("TextChatService")
    local UserInputService=game:GetService("UserInputService")
    local LP=Players.LocalPlayer
    local PG=LP:WaitForChild("PlayerGui")

    local state={
        alive=true,
        started=false,
        manualBotted=false,
        manualRemaining=nil,
        manualSnapshot=nil,
        connections={},
        playerRows={},
        minimized=false,
        root=nil,
        main=nil,
        content=nil,
        statusLabel=nil,
        countdownLabel=nil,
        currentLabel=nil,
        manualLabel=nil,
        candidateHeader=nil,
        candidateLabels={},
        playerList=nil,
    }

    local controller={}

    local function sessionAlive()
        return state.alive and config.sessionAlive()==true
    end

    local function track(conn)
        if conn then
            state.connections[#state.connections+1]=conn
        end
        return conn
    end

    local function shortJob(id)
        id=tostring(id or "")
        if #id<=10 then return id end
        return string.sub(id,1,8)..".."
    end

    local function destroyExisting()
        local old=PG:FindFirstChild(GUI_NAME)
        if old then
            old:Destroy()
        end
    end

    local function makeText(parent,text,size,pos,fontSize)
        local l=Instance.new("TextLabel")
        l.BackgroundTransparency=1
        l.Text=tostring(text or "")
        l.TextColor3=Color3.new(1,1,1)
        l.TextXAlignment=Enum.TextXAlignment.Left
        l.TextYAlignment=Enum.TextYAlignment.Center
        l.Font=Enum.Font.Gotham
        l.TextSize=fontSize or 14
        l.Size=size
        l.Position=pos or UDim2.new()
        l.Parent=parent
        return l
    end

    local function createGui()
        destroyExisting()

        local screen=Instance.new("ScreenGui")
        screen.Name=GUI_NAME
        screen.ResetOnSpawn=false
        screen.IgnoreGuiInset=true
        screen.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
        screen.Parent=PG
        state.root=screen

        local main=Instance.new("Frame")
        main.Name="Main"
        main.Size=UDim2.fromOffset(500,590)
        main.Position=UDim2.fromOffset(14,72)
        main.BackgroundColor3=Color3.fromRGB(24,24,28)
        main.BorderSizePixel=0
        main.Parent=screen
        state.main=main

        local corner=Instance.new("UICorner")
        corner.CornerRadius=UDim.new(0,10)
        corner.Parent=main

        local header=Instance.new("Frame")
        header.Name="Header"
        header.Size=UDim2.new(1,0,0,42)
        header.BackgroundColor3=Color3.fromRGB(35,35,42)
        header.BorderSizePixel=0
        header.Parent=main

        local headerCorner=Instance.new("UICorner")
        headerCorner.CornerRadius=UDim.new(0,10)
        headerCorner.Parent=header

        local title=makeText(
            header,
            "PDIDDLER P1 + P5 OBSERVATION LAB",
            UDim2.new(1,-62,1,0),
            UDim2.fromOffset(12,0),
            15
        )
        title.Font=Enum.Font.GothamBold

        local minimize=Instance.new("TextButton")
        minimize.Name="Minimize"
        minimize.Size=UDim2.fromOffset(42,30)
        minimize.Position=UDim2.new(1,-49,0,6)
        minimize.Text="—"
        minimize.TextSize=20
        minimize.Font=Enum.Font.GothamBold
        minimize.TextColor3=Color3.new(1,1,1)
        minimize.BackgroundColor3=Color3.fromRGB(55,55,65)
        minimize.BorderSizePixel=0
        minimize.Parent=header
        local mc=Instance.new("UICorner")
        mc.CornerRadius=UDim.new(0,7)
        mc.Parent=minimize

        local body=Instance.new("Frame")
        body.Name="Body"
        body.Position=UDim2.fromOffset(0,42)
        body.Size=UDim2.new(1,0,1,-42)
        body.BackgroundTransparency=1
        body.Parent=main
        state.content=body

        state.statusLabel=makeText(
            body,
            "PART 1: "..tostring(config.part1Status or "PENDING"),
            UDim2.new(1,-24,0,24),
            UDim2.fromOffset(12,8),
            15
        )
        state.statusLabel.Font=Enum.Font.GothamBold

        state.currentLabel=makeText(
            body,
            "CURRENT: loading",
            UDim2.new(0.5,-12,0,22),
            UDim2.fromOffset(12,34),
            14
        )

        state.countdownLabel=makeText(
            body,
            "HOP IN: --",
            UDim2.new(0.5,-12,0,22),
            UDim2.new(0.5,0,0,34),
            14
        )
        state.countdownLabel.TextXAlignment=Enum.TextXAlignment.Right

        state.manualLabel=makeText(
            body,
            'MANUAL: type "botted" if Part 1 missed this lobby',
            UDim2.new(1,-24,0,30),
            UDim2.fromOffset(12,58),
            13
        )
        state.manualLabel.TextWrapped=true

        state.candidateHeader=makeText(
            body,
            "NEXT REAL SERVERS",
            UDim2.new(1,-24,0,22),
            UDim2.fromOffset(12,94),
            13
        )
        state.candidateHeader.Font=Enum.Font.GothamBold

        local candidateFrame=Instance.new("Frame")
        candidateFrame.Name="Candidates"
        candidateFrame.Position=UDim2.fromOffset(12,118)
        candidateFrame.Size=UDim2.new(1,-24,0,118)
        candidateFrame.BackgroundColor3=Color3.fromRGB(31,31,36)
        candidateFrame.BorderSizePixel=0
        candidateFrame.Parent=body
        local cc=Instance.new("UICorner")
        cc.CornerRadius=UDim.new(0,8)
        cc.Parent=candidateFrame

        for i=1,MAX_CANDIDATES do
            local label=makeText(
                candidateFrame,
                i==1 and "Loading real server candidates..." or "",
                UDim2.new(1,-16,0,21),
                UDim2.fromOffset(8,4+(i-1)*22),
                13
            )
            state.candidateLabels[i]=label
        end

        local playerHeader=makeText(
            body,
            "CURRENT SERVER PLAYERS",
            UDim2.new(1,-24,0,22),
            UDim2.fromOffset(12,246),
            13
        )
        playerHeader.Font=Enum.Font.GothamBold

        local scroll=Instance.new("ScrollingFrame")
        scroll.Name="Players"
        scroll.Position=UDim2.fromOffset(12,270)
        scroll.Size=UDim2.new(1,-24,1,-282)
        scroll.BackgroundColor3=Color3.fromRGB(31,31,36)
        scroll.BorderSizePixel=0
        scroll.ScrollBarThickness=6
        scroll.CanvasSize=UDim2.fromOffset(0,0)
        scroll.Parent=body
        state.playerList=scroll
        local sc=Instance.new("UICorner")
        sc.CornerRadius=UDim.new(0,8)
        sc.Parent=scroll

        local list=Instance.new("UIListLayout")
        list.Padding=UDim.new(0,4)
        list.SortOrder=Enum.SortOrder.LayoutOrder
        list.Parent=scroll

        local padding=Instance.new("UIPadding")
        padding.PaddingTop=UDim.new(0,6)
        padding.PaddingBottom=UDim.new(0,6)
        padding.PaddingLeft=UDim.new(0,6)
        padding.PaddingRight=UDim.new(0,6)
        padding.Parent=scroll

        track(list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            if sessionAlive() and state.playerList then
                state.playerList.CanvasSize=UDim2.fromOffset(0,list.AbsoluteContentSize.Y+12)
            end
        end))

        track(minimize.MouseButton1Click:Connect(function()
            if not sessionAlive() then return end
            state.minimized=not state.minimized
            body.Visible=not state.minimized
            main.Size=state.minimized and UDim2.fromOffset(500,42) or UDim2.fromOffset(500,590)
            minimize.Text=state.minimized and "+" or "—"
        end))

        -- Touch/mouse drag for iPad and desktop.
        local dragging=false
        local dragStart=nil
        local startPos=nil
        local dragInput=nil

        track(header.InputBegan:Connect(function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton1
                or input.UserInputType==Enum.UserInputType.Touch
            then
                dragging=true
                dragStart=input.Position
                startPos=main.Position
                track(input.Changed:Connect(function()
                    if input.UserInputState==Enum.UserInputState.End then
                        dragging=false
                    end
                end))
            end
        end))

        track(header.InputChanged:Connect(function(input)
            if input.UserInputType==Enum.UserInputType.MouseMovement
                or input.UserInputType==Enum.UserInputType.Touch
            then
                dragInput=input
            end
        end))

        track(UserInputService.InputChanged:Connect(function(input)
            if not sessionAlive() or not dragging or input~=dragInput then return end
            local delta=input.Position-dragStart
            main.Position=UDim2.new(
                startPos.X.Scale,startPos.X.Offset+delta.X,
                startPos.Y.Scale,startPos.Y.Offset+delta.Y
            )
        end))
    end

    local function actionSnapshot(plr)
        local char=plr and plr.Character
        if not char then
            return {character=false}
        end

        local hum=char:FindFirstChildOfClass("Humanoid")
        if not hum then
            return {character=true,health=nil,sit=false,humanoidState=nil,moving=false}
        end

        local stateName=nil
        pcall(function()
            stateName=hum:GetState().Name
        end)

        return {
            character=true,
            health=hum.Health,
            sit=hum.Sit==true,
            humanoidState=stateName,
            moving=hum.MoveDirection.Magnitude>0.05,
        }
    end

    local function createPlayerRow(plr)
        if not state.playerList or state.playerRows[plr.UserId] then return end

        local row=Instance.new("Frame")
        row.Name="Player_"..tostring(plr.UserId)
        row.Size=UDim2.new(1,-12,0,44)
        row.BackgroundColor3=Color3.fromRGB(42,42,48)
        row.BorderSizePixel=0
        row.LayoutOrder=plr.UserId
        row.Parent=state.playerList
        local rc=Instance.new("UICorner")
        rc.CornerRadius=UDim.new(0,7)
        rc.Parent=row

        local avatar=Instance.new("ImageLabel")
        avatar.Name="Avatar"
        avatar.Size=UDim2.fromOffset(36,36)
        avatar.Position=UDim2.fromOffset(4,4)
        avatar.BackgroundColor3=Color3.fromRGB(58,58,64)
        avatar.BorderSizePixel=0
        avatar.Image=""
        avatar.Parent=row
        local ac=Instance.new("UICorner")
        ac.CornerRadius=UDim.new(1,0)
        ac.Parent=avatar

        local name=makeText(
            row,
            plr.DisplayName.."  @"..plr.Name,
            UDim2.new(1,-190,1,0),
            UDim2.fromOffset(48,0),
            13
        )

        local action=makeText(
            row,
            "Character Loading",
            UDim2.fromOffset(130,44),
            UDim2.new(1,-136,0,0),
            13
        )
        action.TextXAlignment=Enum.TextXAlignment.Right

        state.playerRows[plr.UserId]={
            player=plr,
            row=row,
            avatar=avatar,
            name=name,
            action=action,
        }

        task.spawn(function()
            local ok,contentUrl,isReady=pcall(function()
                return Players:GetUserThumbnailAsync(
                    plr.UserId,
                    Enum.ThumbnailType.HeadShot,
                    Enum.ThumbnailSize.Size100x100
                )
            end)
            local liveRow=state.playerRows[plr.UserId]
            if ok
                and sessionAlive()
                and liveRow
                and liveRow.row
                and liveRow.row.Parent
                and type(contentUrl)=="string"
                and contentUrl~=""
            then
                liveRow.avatar.Image=contentUrl
                liveRow.avatar.ImageTransparency=isReady and 0 or 0.15
            end
        end)
    end

    local function removeMissingRows(present)
        for userId,rowData in pairs(state.playerRows) do
            if not present[userId] then
                if rowData.row then
                    rowData.row:Destroy()
                end
                state.playerRows[userId]=nil
            end
        end
    end

    local function refreshPlayers()
        local present={}
        local total=0

        for _,plr in ipairs(Players:GetPlayers()) do
            if plr~=LP then
                present[plr.UserId]=true
                total+=1
                createPlayerRow(plr)

                local rowData=state.playerRows[plr.UserId]
                if rowData and rowData.row and rowData.row.Parent then
                    rowData.name.Text=plr.DisplayName.."  @"..plr.Name
                    rowData.action.Text=policy.actionLabel(actionSnapshot(plr))
                end
            end
        end

        removeMissingRows(present)

        if state.currentLabel then
            state.currentLabel.Text=
                "CURRENT: "
                ..tostring(#Players:GetPlayers())
                .."/"
                ..tostring(Players.MaxPlayers)
                .." | Job "
                ..shortJob(game.JobId)
        end
    end

    local function currentSnapshot(remaining)
        local players={}
        for _,plr in ipairs(Players:GetPlayers()) do
            if plr~=LP then
                players[#players+1]={
                    userId=plr.UserId,
                    name=plr.Name,
                    displayName=plr.DisplayName,
                    action=policy.actionLabel(actionSnapshot(plr)),
                }
            end
        end
        table.sort(players,function(a,b)
            return string.lower(a.name)<string.lower(b.name)
        end)

        return {
            jobId=game.JobId,
            shortJobId=shortJob(game.JobId),
            playerCount=#Players:GetPlayers(),
            maxPlayers=Players.MaxPlayers,
            remaining=tonumber(remaining) or 0,
            part1Result=tostring(config.part1Status or "APPROVED"),
            manualResult="BOTTED",
            players=players,
        }
    end

    function controller:markManualBotted(remaining)
        local nextState,changed=policy.markManual(state,"botted",remaining)
        state.manualBotted=nextState.manualBotted==true
        state.manualRemaining=nextState.manualRemaining

        if not changed then
            return false
        end

        state.manualSnapshot=currentSnapshot(state.manualRemaining)

        if state.statusLabel then
            state.statusLabel.Text="PART 1: APPROVED | MANUALLY CONFIRMED BOTTED"
        end
        if state.manualLabel then
            state.manualLabel.Text=
                "Snapshot captured at "
                ..string.format("%.1f",state.manualRemaining or 0)
                .."s remaining"
        end

        if type(config.onManualBotted)=="function" then
            pcall(config.onManualBotted,state.manualSnapshot)
        end

        print(
            "[PDIDDLER OBS] MANUAL BOTTED",
            "| Job "..shortJob(game.JobId),
            "| players "..tostring(#Players:GetPlayers()),
            "| remaining "..string.format("%.1f",state.manualRemaining or 0).."s"
        )

        return true
    end

    function controller:setBotRehop()
        if state.statusLabel then
            state.statusLabel.Text="PART 1: BOT DETECTED — REHOPPING"
        end
        if state.countdownLabel then
            state.countdownLabel.Text="HOP IN: IMMEDIATE"
        end
        if state.manualLabel then
            state.manualLabel.Text="Part 1 blocked this lobby automatically"
        end
    end

    local function handleManualMessage(text)
        if not sessionAlive() then return end
        if policy.normalizeManualMessage(text)~="botted" then return end

        local remaining=0
        if tonumber(config.deadline) then
            remaining=math.max(0,config.deadline-os.clock())
        end
        controller:markManualBotted(remaining)
    end

    local function connectChat()
        local okSending=pcall(function()
            track(TextChatService.SendingMessage:Connect(function(message)
                if not sessionAlive() then return end

                local text=nil
                local sourceUserId=nil
                pcall(function()
                    text=message.Text
                    sourceUserId=message.TextSource and message.TextSource.UserId
                end)

                if sourceUserId==nil or sourceUserId==LP.UserId then
                    handleManualMessage(text)
                end
            end))
        end)

        if not okSending then
            warn("[PDIDDLER OBS] TextChatService local-send listener unavailable")
        end

        track(LP.Chatted:Connect(function(message)
            handleManualMessage(message)
        end))
    end

    local function updateCandidates(result)
        if not state.candidateHeader then return end

        if type(result)~="table" then
            state.candidateHeader.Text="NEXT REAL SERVERS | unavailable"
            for i=1,MAX_CANDIDATES do
                state.candidateLabels[i].Text=""
            end
            return
        end

        if result.error then
            state.candidateHeader.Text="NEXT REAL SERVERS | refresh failed"
            state.candidateLabels[1].Text=tostring(result.error)
            for i=2,MAX_CANDIDATES do
                state.candidateLabels[i].Text=""
            end
            return
        end

        state.candidateHeader.Text=
            "NEXT REAL SERVERS | 11/12="
            ..tostring(result.count11 or 0)
            .." | 10/12="
            ..tostring(result.count10 or 0)

        local candidates=result.candidates or {}
        for i=1,MAX_CANDIDATES do
            local entry=candidates[i]
            if entry then
                state.candidateLabels[i].Text=
                    tostring(entry.playing)
                    .."/"
                    ..tostring(entry.maxPlayers)
                    .."   Job "
                    ..shortJob(entry.id)
            else
                state.candidateLabels[i].Text=i==1 and "No unvisited 11/12 or 10/12 currently found" or ""
            end
        end
    end

    function controller:start()
        if state.started or not sessionAlive() then
            return false
        end
        state.started=true

        createGui()
        connectChat()
        refreshPlayers()

        task.spawn(function()
            while sessionAlive() do
                refreshPlayers()

                if state.countdownLabel and tonumber(config.deadline) then
                    local remaining=math.max(0,config.deadline-os.clock())
                    state.countdownLabel.Text="HOP IN: "..tostring(math.ceil(remaining)).."s"
                end

                task.wait(ACTION_REFRESH_SECONDS)
            end
        end)

        task.spawn(function()
            while sessionAlive() do
                local visited={}
                if type(config.getVisited)=="function" then
                    local ok,value=pcall(config.getVisited)
                    if ok and type(value)=="table" then
                        visited=value
                    end
                end

                local ok,result=pcall(function()
                    return candidateObserver:refresh(game.JobId,visited)
                end)
                if ok then
                    updateCandidates(result)
                else
                    updateCandidates({candidates={},error=tostring(result)})
                end

                task.wait(CANDIDATE_REFRESH_SECONDS)
            end
        end)

        return true
    end

    function controller:destroy()
        if not state.alive then return end
        state.alive=false

        for _,conn in ipairs(state.connections) do
            pcall(function()
                conn:Disconnect()
            end)
        end
        table.clear(state.connections)

        if state.root then
            state.root:Destroy()
            state.root=nil
        end
        table.clear(state.playerRows)
    end

    return controller
end

return M
