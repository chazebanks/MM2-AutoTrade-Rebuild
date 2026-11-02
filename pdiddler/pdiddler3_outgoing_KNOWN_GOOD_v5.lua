-- pdiddler Part 3 outgoing-request subtest v5
-- Scope:
--   * consumes successful scanner whitelist through ScannerAPI
--   * physically taps target name -> Trade on tablet
--   * verifies sender-side pending UI
--   * waits 15 seconds
--   * accepted -> pause at trade-open handoff
--   * declined -> mark and continue
--   * ignored -> cancel and continue
--   * failed/left -> mark and continue
--   * one outgoing request per player per execution session
--
-- SAFETY:
--   * NEVER presses the final Accept button inside an active item trade
--   * does not offer/rebalance/confirm items

local M={}

function M.run(scanner)
    if type(scanner)~="table" then
        error("[PDIDDLER P3 OUT] scanner API missing")
    end

    for _,name in ipairs({
        "getWhitelist",
        "getRecord",
        "isWhitelisted",
        "hasPendingWork",
        "setStatus",
        "setRequestState",
    }) do
        if type(scanner[name])~="function" then
            error("[PDIDDLER P3 OUT] scanner API missing "..name)
        end
    end

    local Players=game:GetService("Players")
    local RS=game:GetService("ReplicatedStorage")
    local VIM=game:GetService("VirtualInputManager")
    local GuiService=game:GetService("GuiService")

    local LP=Players.LocalPlayer
    local PG=LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui")

    local ENV=(getgenv and getgenv()) or _G
    ENV.PDIDDLER_OUTGOING_SESSION=(tonumber(ENV.PDIDDLER_OUTGOING_SESSION) or 0)+1
    local SESSION=ENV.PDIDDLER_OUTGOING_SESSION

    local function alive()
        return ENV.PDIDDLER_OUTGOING_SESSION==SESSION
    end

    local TradeFolder=RS:FindFirstChild("Trade")
    local DeclineRequest=TradeFolder and TradeFolder:FindFirstChild("DeclineRequest")

    local C={
        ResponseTimeout=15,
        SendAttempts=3,
        PendingProofTimeout=4.5,
        TradeOpenGrace=2.5,
        JoinTradeGrace=15,
        UnavailableRetryDelay=15,
        MaxUnavailableChecks=3,
    }

    local S={
        processed={},
        active=nil,
        paused=false,
        sent=0,
        ignored=0,
        declined=0,
        failed=0,
        left=0,
        accepted=0,
        incomingDeclined=0,
        joinedAt={},
        unavailableUntil={},
        unavailableCount={},
        declineSignalAt=0,
        declineSignalUid=nil,
    }

    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP then
            S.joinedAt[p.UserId]=0
        end
    end

    Players.PlayerAdded:Connect(function(p)
        if not alive() or p==LP then return end
        S.joinedAt[p.UserId]=os.clock()
    end)

    Players.PlayerRemoving:Connect(function(p)
        if not alive() then return end
        S.joinedAt[p.UserId]=nil
    end)

    local function key(x)
        return tostring(x or ""):lower():gsub("[^%w]","")
    end

    local function textOf(o)
        if not o then return "" end

        if o:IsA("TextLabel")
            or o:IsA("TextButton")
            or o:IsA("TextBox")
        then
            local ok,v=pcall(function() return tostring(o.Text or "") end)
            if ok then return v end
        end

        return ""
    end

    local function visible(o)
        if not o then return false end

        local ok,result=pcall(function()
            local c=o
            while c do
                if c:IsA("ScreenGui") and not c.Enabled then return false end
                if c:IsA("GuiObject") and not c.Visible then return false end
                c=c.Parent
            end
            return true
        end)

        return ok and result
    end

    local function clickableAncestor(o,limit)
        local c=o

        for _=1,(limit or 8) do
            if not c then break end
            if c:IsA("GuiButton") then return c end
            c=c.Parent
        end

        return nil
    end

    local function correctedCenter(o)
        local ok,pos,size=pcall(function()
            return o.AbsolutePosition,o.AbsoluteSize
        end)

        if not ok or not pos or not size then
            return nil,nil
        end

        local insetX,insetY=0,0

        pcall(function()
            local inset=GuiService:GetGuiInset()
            insetX=inset.X
            insetY=inset.Y
        end)

        return
            pos.X+(size.X/2)+insetX,
            pos.Y+(size.Y/2)+insetY
    end

    local function rawCenter(o)
        local ok,pos,size=pcall(function()
            return o.AbsolutePosition,o.AbsoluteSize
        end)

        if not ok or not pos or not size then
            return nil,nil,nil,nil
        end

        return
            pos.X+(size.X/2),
            pos.Y+(size.Y/2),
            size.X,
            size.Y
    end

    local function physicalTap(o,label)
        if not alive() or not o or not visible(o) then
            return false
        end

        local x,y=correctedCenter(o)
        if not x then
            return false
        end

        local ok=pcall(function()
            VIM:SendMouseButtonEvent(x,y,0,true,game,0)
            task.wait(0.07)
            VIM:SendMouseButtonEvent(x,y,0,false,game,0)
        end)

        if ok then
            print(
                "[PDIDDLER P3 OUT] TAP",
                tostring(label or o.Name),
                math.floor(x),
                math.floor(y)
            )
        end

        return ok
    end

    local function leaderboardRoot()
        local exact=PG:FindFirstChild("MainGUI")
        exact=exact and exact:FindFirstChild("Game")
        exact=exact and exact:FindFirstChild("Leaderboard")

        if exact then return exact end

        local ok,desc=pcall(function() return PG:GetDescendants() end)
        if not ok then return nil end

        for _,d in ipairs(desc) do
            if (d:IsA("TextLabel") or d:IsA("TextButton"))
                and visible(d)
            then
                local tx=textOf(d):upper()

                if tx:find("TRADE REQUESTS",1,true)
                    or tx:find("CLICK ON A PLAYER TO TRADE",1,true)
                then
                    local p=d

                    for _=1,12 do
                        if not p then break end

                        if key(p.Name)=="leaderboard" then
                            return p
                        end

                        p=p.Parent
                    end
                end
            end
        end

        return nil
    end

    local function findPlayerLabel(plr)
        if not plr
            or plr==LP
            or plr.UserId==LP.UserId
        then
            return nil,"self/missing target"
        end

        local root=leaderboardRoot()
        if not root then
            return nil,"MM2 Leaderboard root not found"
        end

        local container=root:FindFirstChild("Container")
        local want=key(plr.Name)

        if container then
            for _,row in ipairs(container:GetChildren()) do
                if key(row.Name)==want
                    and key(row.Name)~=key(LP.Name)
                then
                    local label=
                        row:FindFirstChild("PlayerLabel")
                        or row:FindFirstChildWhichIsA("TextButton")
                        or row:FindFirstChildWhichIsA("TextLabel")

                    if label and visible(label) then
                        return label,nil
                    end
                end
            end
        end

        local display=key(plr.DisplayName)
        local candidates={}

        local ok,desc=pcall(function() return root:GetDescendants() end)
        if not ok then
            return nil,"cannot inspect MM2 Leaderboard"
        end

        for _,d in ipairs(desc) do
            if (d:IsA("TextLabel") or d:IsA("TextButton"))
                and visible(d)
            then
                local tx=key(textOf(d))
                local parentName=d.Parent and key(d.Parent.Name) or ""

                if parentName~=key(LP.Name) then
                    local userMatch=
                        want~=""
                        and tx:find(want,1,true)

                    local displayMatch=
                        display~=""
                        and #display>=4
                        and display~=key(LP.Name)
                        and display~=key(LP.DisplayName)
                        and tx:find(display,1,true)

                    if userMatch or displayMatch then
                        local score=0

                        if parentName==want then score=score+200 end
                        if key(d.Name)=="playerlabel" then score=score+100 end
                        if userMatch then score=score+40 end
                        if tx==want then score=score+20 end

                        candidates[#candidates+1]={
                            node=d,
                            score=score,
                        }
                    end
                end
            end
        end

        table.sort(candidates,function(a,b)
            return a.score>b.score
        end)

        if candidates[1] then
            return candidates[1].node,nil
        end

        return nil,"target PlayerLabel not found"
    end

    local function cardTextList(card)
        local out={}
        if not card then return out end

        local ok,desc=pcall(function() return card:GetDescendants() end)
        if not ok then return out end

        for _,d in ipairs(desc) do
            if (d:IsA("TextLabel") or d:IsA("TextButton"))
                and visible(d)
            then
                local tx=textOf(d)
                if tx~="" then out[#out+1]=tx end
            end
        end

        return out
    end

    local function cardContainerForTradeButton(tradeButton)
        local p=tradeButton

        for _=1,10 do
            if not p then break end

            local hasProfile=false
            local hasTrade=false

            local ok,desc=pcall(function() return p:GetDescendants() end)
            if ok then
                for _,d in ipairs(desc) do
                    if (d:IsA("TextLabel") or d:IsA("TextButton"))
                        and visible(d)
                    then
                        local q=key(textOf(d))
                        if q=="profile" then hasProfile=true end
                        if q=="trade" then hasTrade=true end
                    end
                end
            end

            if hasProfile and hasTrade then
                return p
            end

            p=p.Parent
        end

        return nil
    end

    local function cardMatchesPlayer(card,plr)
        if not card or not plr then return false end

        local user=key(plr.Name)
        local display=key(plr.DisplayName)
        local lpUser=key(LP.Name)
        local lpDisplay=key(LP.DisplayName)

        for _,tx in ipairs(cardTextList(card)) do
            local q=key(tx)

            if user~="" and q:find(user,1,true) then
                return true
            end

            if display~=""
                and #display>=4
                and display~=lpUser
                and display~=lpDisplay
                and q:find(display,1,true)
            then
                return true
            end
        end

        return false
    end

    local function findIdentityNearTradeButton(tradeButton,plr)
        if not tradeButton or not plr then
            return nil,nil
        end

        local tx,ty,tw,th=rawCenter(tradeButton)
        if not tx then return nil,nil end

        local root=leaderboardRoot() or PG
        local ok,desc=pcall(function() return root:GetDescendants() end)
        if not ok then return nil,nil end

        local wantUser=key(plr.Name)
        local wantDisplay=key(plr.DisplayName)
        local lpUser=key(LP.Name)
        local lpDisplay=key(LP.DisplayName)

        local best=nil
        local bestScore=-math.huge

        for _,d in ipairs(desc) do
            if (d:IsA("TextLabel") or d:IsA("TextButton"))
                and visible(d)
            then
                local q=key(textOf(d))
                local userMatch=
                    wantUser~=""
                    and q:find(wantUser,1,true)

                local displayMatch=
                    wantDisplay~=""
                    and #wantDisplay>=4
                    and wantDisplay~=lpUser
                    and wantDisplay~=lpDisplay
                    and q:find(wantDisplay,1,true)

                if userMatch or displayMatch then
                    local cx,cy,cw,ch=rawCenter(d)

                    if cx then
                        local dx=math.abs(cx-tx)
                        local dy=ty-cy

                        -- The selected-player username/header sits directly
                        -- above the Profile/Trade controls. The ordinary
                        -- leaderboard row is farther to the right and must not
                        -- be mistaken for card proof.
                        local maxDx=math.max(170,(tw or 0)*2.2)
                        local spatial=
                            dx<=maxDx
                            and dy>=-25
                            and dy<=185

                        if spatial then
                            local score=0

                            if userMatch then score+=300 end
                            if q==wantUser then score+=100 end
                            if displayMatch then score+=80 end
                            score-=dx
                            score-=math.abs(dy-65)*0.5

                            if score>bestScore then
                                best=d
                                bestScore=score
                            end
                        end
                    end
                end
            end
        end

        return best,bestScore
    end

    local function findAnyOpenCard()
        local ok,desc=pcall(function() return PG:GetDescendants() end)
        if not ok then return nil,nil end

        for _,d in ipairs(desc) do
            if (d:IsA("TextLabel") or d:IsA("TextButton"))
                and visible(d)
                and key(textOf(d))=="trade"
            then
                local button=
                    d:IsA("GuiButton")
                    and d
                    or clickableAncestor(d,6)

                if button then
                    local card=cardContainerForTradeButton(button)
                    if card then return card,button end
                end
            end
        end

        return nil,nil
    end

    local function findCloseNearTradeButton(card,tradeButton)
        if card then
            local ok,desc=pcall(function() return card:GetDescendants() end)

            if ok then
                for _,d in ipairs(desc) do
                    if (d:IsA("TextButton") or d:IsA("ImageButton"))
                        and visible(d)
                    then
                        local q=key(textOf(d).." "..tostring(d.Name or ""))

                        if q=="x"
                            or q=="close"
                            or q:find("close",1,true)
                        then
                            return d
                        end
                    end
                end
            end
        end

        local tx,ty=rawCenter(tradeButton)
        if not tx then return nil end

        local best=nil
        local bestDist=math.huge

        local ok,desc=pcall(function() return PG:GetDescendants() end)
        if not ok then return nil end

        for _,d in ipairs(desc) do
            if (d:IsA("TextLabel")
                or d:IsA("TextButton")
                or d:IsA("ImageButton"))
                and visible(d)
            then
                local q=key(textOf(d).." "..tostring(d.Name or ""))
                local looksClose=
                    q=="x"
                    or q=="close"
                    or q:find("close",1,true)

                if looksClose then
                    local cx,cy=rawCenter(d)

                    if cx then
                        local dx=cx-tx
                        local dy=cy-ty
                        local dist=math.sqrt(dx*dx+dy*dy)

                        if dist<bestDist and dist<450 then
                            best=d
                            bestDist=dist
                        end
                    end
                end
            end
        end

        return best
    end

    local function closeOpenCard()
        for _=1,3 do
            local card,tradeButton=findAnyOpenCard()

            if not card then
                return true
            end

            local close=findCloseNearTradeButton(card,tradeButton)

            if not close then
                warn(
                    "[PDIDDLER P3 OUT] CARD CLOSE FAILED",
                    "Profile/Trade card visible but nearby X/Close not found"
                )
                return false
            end

            if not physicalTap(close,"close player card") then
                return false
            end

            task.wait(0.25)

            if not findAnyOpenCard() then
                return true
            end
        end

        return findAnyOpenCard()==nil
    end

    local function findOpenCardFor(plr)
        local ok,desc=pcall(function() return PG:GetDescendants() end)
        if not ok then return nil,nil,nil end

        for _,d in ipairs(desc) do
            if (d:IsA("TextLabel") or d:IsA("TextButton"))
                and visible(d)
                and key(textOf(d))=="trade"
            then
                local button=
                    d:IsA("GuiButton")
                    and d
                    or clickableAncestor(d,6)

                if button then
                    local card=cardContainerForTradeButton(button)

                    if card then
                        -- First use the old descendant proof when available.
                        if cardMatchesPlayer(card,plr) then
                            return card,button,true
                        end

                        -- MM2's username header is a sibling of the small
                        -- Profile/Trade controls container on tablet. Verify
                        -- that visible header geometrically instead.
                        local identity=findIdentityNearTradeButton(button,plr)

                        if identity then
                            print(
                                "[PDIDDLER P3 OUT] VERIFIED CARD HEADER",
                                plr.Name,
                                identity:GetFullName()
                            )
                            return card,button,true
                        end

                        return card,button,false
                    end
                end
            end
        end

        return nil,nil,nil
    end

    local function openTargetCard(plr)
        -- A fresh-card proof starts by requiring no stale Profile/Trade card.
        if not closeOpenCard() then
            return false,"could not clear stale Profile/Trade card"
        end

        task.wait(0.20)

        if findAnyOpenCard() then
            return false,"stale card remained after cleanup"
        end

        local label,why=findPlayerLabel(plr)
        if not label then
            return false,why
        end

        if not physicalTap(label,"player "..plr.Name) then
            return false,"physical player-label click failed"
        end

        local deadline=os.clock()+3.0
        local sawCard=false

        while alive() and os.clock()<deadline do
            local card,tradeButton,matched=findOpenCardFor(plr)

            if card then
                sawCard=true
            end

            if card and matched==true then
                print(
                    "[PDIDDLER P3 OUT] FRESH CARD VERIFIED",
                    plr.Name
                )
                return true,tradeButton
            end

            -- Do not immediately reject an unmatched card. The username
            -- header can render a frame after Profile/Trade controls.
            task.wait(0.08)
        end

        if sawCard then
            local card,tradeButton=findAnyOpenCard()
            local close=findCloseNearTradeButton(card,tradeButton)

            if close then
                physicalTap(close,"unverified-card close")
            end

            return false,"fresh Profile/Trade card appeared but target header was not verified"
        end

        return false,"player click produced no fresh Profile/Trade card"
    end

    local tradeOpen

    local function roots()
        local out={PG}

        if gethui then
            local ok,h=pcall(gethui)
            if ok and h then out[#out+1]=h end
        end

        return out
    end


    local function findIncomingRequest()
        for _,root in ipairs(roots()) do
            local ok,list=pcall(function()
                return root:GetDescendants()
            end)

            if ok then
                for _,marker in ipairs(list) do
                    if visible(marker)
                        and (marker:IsA("TextLabel")
                            or marker:IsA("TextButton")
                            or marker:IsA("TextBox"))
                    then
                        local markerText=textOf(marker):upper()

                        if markerText:find(
                            "NEW TRADE REQUEST FROM",
                            1,
                            true
                        ) then
                            local p=marker

                            for _=1,10 do
                                if not p then break end

                                local ok2,desc=pcall(function()
                                    return p:GetDescendants()
                                end)

                                if ok2 then
                                    local acceptButton=nil
                                    local declineButton=nil
                                    local sender=nil

                                    for _,d in ipairs(desc) do
                                        if visible(d) then
                                            if d:IsA("GuiButton") then
                                                local q=key(
                                                    textOf(d)
                                                    .." "
                                                    ..tostring(d.Name or "")
                                                )

                                                if q=="accept"
                                                    or q:find("accept",1,true)
                                                then
                                                    acceptButton=d
                                                elseif q=="decline"
                                                    or q:find("decline",1,true)
                                                then
                                                    declineButton=d
                                                end
                                            end

                                            if (d:IsA("TextLabel")
                                                or d:IsA("TextButton"))
                                            then
                                                local tx=tostring(textOf(d) or "")
                                                local q=key(tx)

                                                if tx~=""
                                                    and not tx:upper():find(
                                                        "NEW TRADE REQUEST FROM",
                                                        1,
                                                        true
                                                    )
                                                    and q~="accept"
                                                    and q~="decline"
                                                then
                                                    for _,plr in ipairs(Players:GetPlayers()) do
                                                        if plr~=LP
                                                            and (
                                                                q==key(plr.Name)
                                                                or (
                                                                    key(plr.DisplayName)~=""
                                                                    and q==key(plr.DisplayName)
                                                                )
                                                            )
                                                        then
                                                            sender=plr
                                                            break
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end

                                    -- Require BOTH buttons in the same small
                                    -- popup region. If we climb all the way to
                                    -- a broad GUI root, unrelated active-trade
                                    -- controls must not qualify as this popup.
                                    if acceptButton and declineButton then
                                        local mx,my=rawCenter(marker)
                                        local ax,ay=rawCenter(acceptButton)
                                        local dx,dy=rawCenter(declineButton)

                                        local localPopup=
                                            mx and ax and dx
                                            and math.abs(ax-mx)<=550
                                            and math.abs(dx-mx)<=550
                                            and math.abs(ay-my)<=300
                                            and math.abs(dy-my)<=300

                                        if localPopup then
                                            return marker,declineButton,sender,p
                                        end
                                    end
                                end

                                p=p.Parent
                            end

                            return marker,nil,nil,nil
                        end
                    end
                end
            end
        end

        return nil,nil,nil,nil
    end

    local function incomingVisible()
        return select(1,findIncomingRequest())~=nil
    end

    local function declineIncoming(reason)
        if tradeOpen and tradeOpen() then
            return false,"trade-open"
        end

        local marker,declineButton,sender=findIncomingRequest()

        if not marker then
            return true,"none"
        end

        local senderName=sender and sender.Name or "unknown"

        if not declineButton then
            warn(
                "[PDIDDLER P3 OUT] INCOMING FOUND BUT DECLINE BUTTON MISSING",
                senderName,
                tostring(reason or "")
            )
            return false,"decline-button-missing"
        end

        scanner.setStatus(
            "P3 OUT — declining incoming request from "
            ..senderName
            .." | outgoing queue protected"
        )

        print(
            "[PDIDDLER P3 OUT] DECLINE INCOMING",
            senderName,
            "|",tostring(reason or "")
        )

        local clicked=physicalTap(
            declineButton,
            "Decline incoming from "..senderName
        )

        if not clicked then
            return false,"tap-failed"
        end

        local deadline=os.clock()+1.5

        while alive()
            and os.clock()<deadline
            and incomingVisible()
        do
            task.wait(0.08)
        end

        if incomingVisible() then
            -- Retry the exact popup control, never a generic decline remote.
            local _,retryButton,retrySender=findIncomingRequest()
            if retryButton then
                physicalTap(
                    retryButton,
                    "Decline incoming retry from "
                    ..(retrySender and retrySender.Name or senderName)
                )
                task.wait(0.25)
            end
        end

        local cleared=not incomingVisible()

        if cleared then
            S.incomingDeclined+=1
            return true,"declined"
        end

        return false,"popup-still-visible"
    end

    local function findPendingCancel()
        for _,root in ipairs(roots()) do
            local ok,list=pcall(function() return root:GetDescendants() end)

            if ok then
                for _,marker in ipairs(list) do
                    if visible(marker)
                        and (marker:IsA("TextLabel")
                            or marker:IsA("TextButton")
                            or marker:IsA("TextBox"))
                        and textOf(marker):upper():find(
                            "TRADE REQUEST PENDING",
                            1,
                            true
                        )
                    then
                        local p=marker

                        for _=1,10 do
                            if not p then break end

                            local ok2,desc=pcall(function()
                                return p:GetDescendants()
                            end)

                            if ok2 then
                                for _,d in ipairs(desc) do
                                    if d:IsA("GuiButton") and visible(d) then
                                        local q=key(textOf(d).." "..tostring(d.Name or ""))

                                        if q=="cancel"
                                            or q:find("cancel",1,true)
                                        then
                                            return marker,d
                                        end
                                    end
                                end
                            end

                            p=p.Parent
                        end

                        return marker,nil
                    end
                end
            end
        end

        return nil,nil
    end

    local function pendingVisible()
        return select(1,findPendingCancel())~=nil
    end

    tradeOpen=function()
        for _,name in ipairs({"TradeGUI_Phone","TradeGUI"}) do
            local g=PG:FindFirstChild(name)
            local c=g and g:FindFirstChild("Container")
            local t=c and c:FindFirstChild("Trade")

            if t then
                local enabled=true

                if g:IsA("ScreenGui") then
                    local ok,v=pcall(function() return g.Enabled end)
                    if ok then enabled=v end
                end

                if enabled then
                    return t
                end
            end
        end

        return nil
    end

    local function waitTradeOpen(target,seconds)
        local deadline=os.clock()+(tonumber(seconds) or C.TradeOpenGrace)

        while alive() and os.clock()<deadline do
            if tradeOpen() then
                return true
            end

            if not target
                or not target.Parent
                or Players:GetPlayerByUserId(target.UserId)~=target
            then
                return false
            end

            task.wait(0.08)
        end

        return tradeOpen()~=nil
    end

    local function cancelPending(reason)
        local _,button=findPendingCancel()
        local clicked=false
        local remote=false

        if button then
            clicked=physicalTap(button,"Cancel pending request")
        end

        task.wait(0.15)

        if pendingVisible()
            and DeclineRequest
            and DeclineRequest:IsA("RemoteEvent")
        then
            remote=pcall(function()
                DeclineRequest:FireServer()
            end)
        end

        local deadline=os.clock()+1.0

        while alive()
            and os.clock()<deadline
            and pendingVisible()
        do
            local _,b=findPendingCancel()
            if b then
                physicalTap(b,"Cancel pending retry")
            end
            task.wait(0.10)
        end

        local cleared=not pendingVisible()

        print(
            "[PDIDDLER P3 OUT] CANCEL",
            tostring(reason or ""),
            "ui",clicked,
            "remote",remote,
            "cleared",cleared
        )

        return cleared
    end

    local function joinGraceRemaining(p)
        if not p or p==LP then return math.huge end

        local at=S.joinedAt[p.UserId]

        if not at or at<=0 then
            return 0
        end

        return math.max(
            0,
            C.JoinTradeGrace-(os.clock()-at)
        )
    end

    local function unavailableRemaining(p)
        if not p then return math.huge end
        local untilAt=tonumber(S.unavailableUntil[p.UserId]) or 0
        return math.max(0,untilAt-os.clock())
    end

    local function readinessRemaining(p)
        return math.max(
            joinGraceRemaining(p),
            unavailableRemaining(p)
        )
    end

    local function nextTarget()
        for _,p in ipairs(scanner.getWhitelist()) do
            if p
                and p.Parent==Players
                and not S.processed[p.UserId]
                and readinessRemaining(p)<=0
            then
                return p
            end
        end

        return nil
    end

    local function soonestMaturing()
        local best=nil
        local bestRemain=math.huge

        for _,p in ipairs(scanner.getWhitelist()) do
            if p
                and p.Parent==Players
                and not S.processed[p.UserId]
            then
                local remain=readinessRemaining(p)

                if remain>0 and remain<bestRemain then
                    best=p
                    bestRemain=remain
                end
            end
        end

        return best,bestRemain
    end

    local function markProcessed(p,result)
        if not p then return end
        S.processed[p.UserId]=tostring(result or "processed")
    end

    if DeclineRequest
        and DeclineRequest:IsA("RemoteEvent")
    then
        DeclineRequest.OnClientEvent:Connect(function()
            if not alive() then return end

            local active=S.active

            if not active then return end

            S.declineSignalAt=os.clock()
            S.declineSignalUid=active.UserId
        end)
    end

    local function sendAndWatch(target)
        if not alive() then return "stale-session" end

        if not target
            or target==LP
            or target.UserId==LP.UserId
        then
            return "self-blocked"
        end

        if target.Parent~=Players then
            return "left"
        end

        if not scanner.isWhitelisted(target.UserId) then
            return "not-whitelisted"
        end

        S.active=target
        S.declineSignalAt=0
        S.declineSignalUid=nil

        if incomingVisible() then
            local cleared=declineIncoming("before outgoing target "..target.Name)
            if not cleared then
                scanner.setRequestState(
                    target,
                    "sending",
                    "Incoming trade request is blocking MM2 trade UI | will retry target"
                )
                return "blocked-by-incoming"
            end
            task.wait(0.20)
        end

        local delivered=false

        for attempt=1,C.SendAttempts do
            if not alive() then return "stale-session" end

            if incomingVisible() then
                local cleared=declineIncoming("before card open for "..target.Name)
                if not cleared then
                    return "blocked-by-incoming"
                end
                task.wait(0.20)
            end

            if target.Parent~=Players
                or Players:GetPlayerByUserId(target.UserId)~=target
            then
                S.left=S.left+1
                scanner.setRequestState(
                    target,
                    "left",
                    "Player left before outgoing request completed"
                )
                return "left"
            end

            if tradeOpen() then
                S.accepted=S.accepted+1
                scanner.setRequestState(
                    target,
                    "accepted",
                    "Trade window already open | outgoing queue paused"
                )
                return "trade-open"
            end

            if pendingVisible() then
                scanner.setRequestState(
                    target,
                    "sending",
                    "Another pending request is visible | waiting"
                )
                return "blocked-by-pending"
            end

            scanner.setRequestState(
                target,
                "sending",
                string.format(
                    "Attempt %d/%d | physically tapping player name",
                    attempt,
                    C.SendAttempts
                )
            )

            scanner.setStatus(
                string.format(
                    "P3 OUT — %s | opening player card %d/%d",
                    target.Name,
                    attempt,
                    C.SendAttempts
                )
            )

            local opened,tradeButtonOrWhy=openTargetCard(target)

            if not opened then
                warn(
                    "[PDIDDLER P3 OUT] CARD OPEN FAILED",
                    target.Name,
                    tostring(tradeButtonOrWhy)
                )

                if attempt<C.SendAttempts then
                    task.wait(0.8)
                    continue
                end

                S.failed=S.failed+1
                scanner.setRequestState(
                    target,
                    "sendfailed",
                    "Could not verify correct fresh Profile/Trade card after 3 attempts"
                )
                return "failed"
            end

            local tradeButton=tradeButtonOrWhy

            if incomingVisible() then
                local cleared=declineIncoming(
                    "incoming appeared after card verification for "..target.Name
                )

                if not cleared then
                    return "blocked-by-incoming"
                end

                -- The popup may have closed/rebuilt the player card. Do not
                -- trust the old Trade button reference after an overlay change.
                return "interrupted-by-incoming"
            end

            scanner.setRequestState(
                target,
                "sending",
                "Correct player card verified | physically tapping Trade"
            )

            if not physicalTap(
                tradeButton,
                "Trade for "..target.Name
            ) then
                if attempt<C.SendAttempts then
                    task.wait(0.8)
                    continue
                end

                S.failed=S.failed+1
                scanner.setRequestState(
                    target,
                    "sendfailed",
                    "Trade button physical tap failed after 3 attempts"
                )
                return "failed"
            end

            local proofDeadline=os.clock()+C.PendingProofTimeout

            while alive() and os.clock()<proofDeadline do
                if incomingVisible() then
                    local cleared=declineIncoming(
                        "while verifying outgoing request to "..target.Name
                    )

                    if cleared then
                        -- Incoming popup can temporarily replace/cover pending
                        -- UI. Give the outgoing channel a fresh proof window
                        -- after the obstruction is removed.
                        proofDeadline=os.clock()+C.PendingProofTimeout
                    else
                        return "blocked-by-incoming"
                    end
                end

                if target.Parent~=Players
                    or Players:GetPlayerByUserId(target.UserId)~=target
                then
                    S.left=S.left+1
                    scanner.setRequestState(
                        target,
                        "left",
                        "Player left while verifying outgoing request"
                    )
                    return "left"
                end

                if tradeOpen() then
                    S.accepted=S.accepted+1
                    scanner.setRequestState(
                        target,
                        "accepted",
                        "Request accepted immediately | trade window opened | queue paused"
                    )
                    return "trade-open"
                end

                if pendingVisible() then
                    delivered=true
                    break
                end

                task.wait(0.08)
            end

            if delivered then
                S.sent=S.sent+1
                S.unavailableUntil[target.UserId]=nil
                S.unavailableCount[target.UserId]=nil
                break
            end

            warn(
                "[PDIDDLER P3 OUT] PENDING NOT FOUND",
                target.Name,
                "after physical Trade tap"
            )

            -- IMPORTANT: once Trade was physically tapped successfully, do
            -- NOT tap it again immediately. A loading target or delayed UI
            -- can make pending proof late, and rapid retries risk duplicate
            -- requests. Defer this target instead.
            local count=(tonumber(S.unavailableCount[target.UserId]) or 0)+1
            S.unavailableCount[target.UserId]=count

            if count>=C.MaxUnavailableChecks then
                scanner.setRequestState(
                    target,
                    "unavailable",
                    string.format(
                        "Outgoing unavailable after %d checks | trades may be OFF, target busy, or target still loading | no request was counted as sent",
                        count
                    )
                )
                return "unavailable-final"
            end

            S.unavailableUntil[target.UserId]=os.clock()+C.UnavailableRetryDelay

            scanner.setRequestState(
                target,
                "unavailable",
                string.format(
                    "Trade tapped but no pending request appeared | target may have trades OFF, be busy, or still be loading | retry later (%d/%d)",
                    count,
                    C.MaxUnavailableChecks
                )
            )

            print(
                "[PDIDDLER P3 OUT] TARGET UNAVAILABLE",
                target.Name,
                "reason=no pending proof after Trade tap",
                "possible=trades-off/busy/loading",
                "retryIn",C.UnavailableRetryDelay,
                "check",count.."/"..C.MaxUnavailableChecks
            )

            return "deferred-unavailable"
        end

        if not delivered then
            return "deferred-unavailable"
        end

        local started=os.clock()

        scanner.setRequestState(
            target,
            "requesting",
            "TRADE REQUEST PENDING confirmed | waiting 15.0s"
        )

        while alive() and os.clock()-started<C.ResponseTimeout do
            if incomingVisible() then
                local cleared=declineIncoming(
                    "while waiting on outgoing response from "..target.Name
                )

                if not cleared then
                    scanner.setRequestState(
                        target,
                        "requesting",
                        "Incoming request is obstructing UI | preserving current outgoing watch"
                    )
                    task.wait(0.15)
                    continue
                end
            end

            if target.Parent~=Players
                or Players:GetPlayerByUserId(target.UserId)~=target
            then
                S.left=S.left+1
                scanner.setRequestState(
                    target,
                    "left",
                    "Player left after confirmed outgoing request"
                )
                return "left"
            end

            if tradeOpen() then
                S.accepted=S.accepted+1
                scanner.setRequestState(
                    target,
                    "accepted",
                    "Request accepted | trade window opened | PART 3 PAUSED"
                )
                return "trade-open"
            end

            if S.declineSignalUid==target.UserId
                and S.declineSignalAt>0
            then
                scanner.setRequestState(
                    target,
                    "requesting",
                    "Request response signal received | checking for trade window"
                )

                if waitTradeOpen(target,C.TradeOpenGrace) then
                    S.accepted=S.accepted+1
                    scanner.setRequestState(
                        target,
                        "accepted",
                        "Request accepted | trade window opened | PART 3 PAUSED"
                    )
                    return "trade-open"
                end

                if not pendingVisible() then
                    task.wait(0.30)

                    if not tradeOpen() and not pendingVisible() then
                        S.declined=S.declined+1
                        scanner.setRequestState(
                            target,
                            "declined",
                            "MM2 decline signal + pending closed + no trade window"
                        )
                        return "declined"
                    end
                end

                S.declineSignalAt=0
                S.declineSignalUid=nil
            end

            if not pendingVisible() then
                scanner.setRequestState(
                    target,
                    "requesting",
                    "Pending UI disappeared | verifying accept/decline before rotating"
                )

                if waitTradeOpen(target,C.TradeOpenGrace) then
                    S.accepted=S.accepted+1
                    scanner.setRequestState(
                        target,
                        "accepted",
                        "Request accepted | trade window opened | PART 3 PAUSED"
                    )
                    return "trade-open"
                end

                task.wait(0.30)

                if not tradeOpen() and not pendingVisible() then
                    S.failed=S.failed+1
                    scanner.setRequestState(
                        target,
                        "sendfailed",
                        "Request channel closed without verifiable decline or trade-open"
                    )
                    return "failed"
                end
            end

            local remaining=math.max(
                0,
                C.ResponseTimeout-(os.clock()-started)
            )

            scanner.setRequestState(
                target,
                "requesting",
                string.format(
                    "Pending confirmed | waiting for response | %.1fs",
                    remaining
                )
            )

            scanner.setStatus(
                string.format(
                    "P3 OUT — waiting on %s | %.1fs",
                    target.Name,
                    remaining
                )
            )

            task.wait(0.12)
        end

        if not alive() then return "stale-session" end

        S.ignored=S.ignored+1

        scanner.setRequestState(
            target,
            "ignored",
            "No response for 15s | cancelling confirmed pending request"
        )

        local cancelled=cancelPending(
            "15s no response for "..target.Name
        )

        scanner.setRequestState(
            target,
            "ignored",
            cancelled
                and "Ignored 15s | pending request cancelled"
                or "Ignored 15s | cancel attempted but pending UI may remain"
        )

        return "ignored"
    end

    task.spawn(function()
        print(
            "[PDIDDLER P3 OUT] START",
            "session",
            SESSION
        )

        task.wait(0.75)

        local idleLogged=false

        while alive() and not S.paused do
            if tradeOpen() then
                S.paused=true
                scanner.setStatus(
                    "P3 OUT — active trade detected | PAUSED for Part 4"
                )
                break
            end

            if incomingVisible() then
                local cleared=declineIncoming("queue guard before next target")

                if not cleared then
                    scanner.setStatus(
                        "P3 OUT — incoming request still blocking trade UI"
                    )
                    task.wait(0.20)
                else
                    task.wait(0.15)
                end

                continue
            end

            if pendingVisible() and not S.active then
                scanner.setStatus(
                    "P3 OUT — existing pending request visible | queue paused"
                )
                task.wait(0.25)
                continue
            end

            local target=nextTarget()

            if not target then
                local maturing,remain=soonestMaturing()

                if maturing then
                    idleLogged=false

                    scanner.setStatus(
                        string.format(
                            "P3 OUT — %s trade-ready in %.1fs",
                            maturing.Name,
                            remain
                        )
                    )

                    task.wait(0.25)
                    continue
                end

                if scanner.hasPendingWork() then
                    idleLogged=false
                    scanner.setStatus(
                        "P3 OUT — waiting for scanner to resolve players"
                    )
                    task.wait(0.35)
                    continue
                end

                if not idleLogged then
                    print(
                        "[PDIDDLER P3 OUT] QUEUE IDLE",
                        "processed",
                        tostring(#scanner.getWhitelist()),
                        "sent",
                        S.sent,
                        "ignored",
                        S.ignored,
                        "declined",
                        S.declined,
                        "failed",
                        S.failed,
                        "incomingDeclined",
                        S.incomingDeclined
                    )
                    idleLogged=true
                end

                scanner.setStatus(
                    "P3 OUT — no unprocessed whitelist targets | watching joins"
                )

                task.wait(0.35)
                continue
            end

            idleLogged=false

            local result=sendAndWatch(target)

            if not alive() then break end

            if result~="blocked-by-pending"
                and result~="blocked-by-incoming"
                and result~="interrupted-by-incoming"
                and result~="not-whitelisted"
                and result~="deferred-unavailable"
            then
                markProcessed(target,result)
            end

            S.active=nil

            if result=="deferred-unavailable"
                or result=="blocked-by-incoming"
                or result=="interrupted-by-incoming"
            then
                task.wait(0.20)
                continue
            end

            if result=="trade-open" then
                S.paused=true

                scanner.setStatus(
                    "P3 OUT — ACCEPTED request | trade window open | PART 3 PAUSED"
                )

                print(
                    "[PDIDDLER P3 OUT] HANDOFF",
                    target.Name,
                    "| Part 4 not active yet",
                    "| FINAL TRADE ACCEPT remains disabled"
                )

                break
            end

            task.wait(0.25)
        end
    end)

    return {
        session=SESSION,
        state=S,
        stop=function()
            if ENV.PDIDDLER_OUTGOING_SESSION==SESSION then
                ENV.PDIDDLER_OUTGOING_SESSION=SESSION+1
            end
        end,
    }
end

return M
