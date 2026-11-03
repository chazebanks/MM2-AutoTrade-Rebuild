-- pdiddler Part 3 rotating outgoing queue PERF test v15
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
    ENV.PDIDDLER_OUTGOING_BUSY_SESSION=nil

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
        MaxUnavailableChecks=2,
        LatePendingAdoptWindow=60,
        TradePartnerResolveGrace=2.5,
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
        recentTradeTap={},
        outgoingSerial=0,
        uncertainOutgoing=nil,
        uncertainTimeouts=0,
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
        -- Verified MM2 phone path from Leaderboard_Phone.lua:
        -- MainGUI.Lobby.Leaderboard
        local exact=PG:FindFirstChild("MainGUI")
        exact=exact and exact:FindFirstChild("Lobby")
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

        -- Verified MM2 phone structure:
        -- Leaderboard.Container.PlayerList.<username>.UsernameFrame.PlayerLabel
        local playerList=container and container:FindFirstChild("PlayerList")
        local exactRow=playerList and playerList:FindFirstChild(plr.Name)

        if exactRow and visible(exactRow) then
            local usernameFrame=exactRow:FindFirstChild("UsernameFrame")
            local exactLabel=usernameFrame and usernameFrame:FindFirstChild("PlayerLabel")

            if exactLabel and visible(exactLabel) then
                return exactLabel,nil
            end

            local action=exactRow:FindFirstChild("ActionButton")
            if action and action:IsA("GuiButton") and visible(action) then
                return action,nil
            end
        end

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

    local function exactLeaderboardPopup()
        local root=leaderboardRoot()
        local popup=root and root:FindFirstChild("Popup")
        if popup and visible(popup) then
            return popup
        end
        return nil
    end

    local function findAnyOpenCard()
        local popup=exactLeaderboardPopup()

        if popup then
            local container=popup:FindFirstChild("Container")
            local action=container and container:FindFirstChild("Action")
            local trade=action and action:FindFirstChild("Trade")

            if trade and trade:IsA("GuiButton") and visible(trade,popup) then
                return popup,trade
            end
        end

        -- Compatibility fallback only if the verified MM2 popup path is absent.
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
        local popup=exactLeaderboardPopup()
        if popup and card==popup then
            local container=popup:FindFirstChild("Container")
            local close1=container and container:FindFirstChild("Close")
            local close2=popup:FindFirstChild("Close2")

            if close1 and close1:IsA("GuiButton") and visible(close1,popup) then
                return close1
            end
            if close2 and close2:IsA("GuiButton") and visible(close2,popup) then
                return close2
            end
        end

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
        local popup=exactLeaderboardPopup()

        if popup then
            local container=popup:FindFirstChild("Container")
            local username=container and container:FindFirstChild("Username")
            local action=container and container:FindFirstChild("Action")
            local trade=action and action:FindFirstChild("Trade")

            if trade and trade:IsA("GuiButton") and visible(trade,popup) then
                local shown=username and textOf(username) or ""
                local matched=
                    key(shown)==key(plr.Name)
                    or (
                        key(plr.DisplayName)~=""
                        and key(shown)==key(plr.DisplayName)
                    )

                return popup,trade,matched
            end
        end

        -- Compatibility fallback only.
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


    local RequestFrameCache=nil

    local function exactRequestFrame()
        if RequestFrameCache
            and RequestFrameCache.Parent
        then
            return RequestFrameCache
        end

        local main=PG:FindFirstChild("MainGUI")
        local lobby=main and main:FindFirstChild("Lobby")
        local leaderboard=lobby and lobby:FindFirstChild("Leaderboard")
        local container=leaderboard and leaderboard:FindFirstChild("Container")
        local overlay=container and container:FindFirstChild("OverlayMenu")
        local frame=overlay and overlay:FindFirstChild("TradeRequest")

        if frame then
            RequestFrameCache=frame
        end

        return frame
    end

    local function playerByExactName(name)
        name=tostring(name or "")
        if name=="" then return nil end

        local direct=Players:FindFirstChild(name)
        if direct and direct:IsA("Player") then
            return direct
        end

        local wanted=key(name)

        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LP and (
                key(p.Name)==wanted
                or key(p.DisplayName)==wanted
            ) then
                return p
            end
        end

        return nil
    end

    local function findIncomingRequestFallback()
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

    local function findIncomingRequest()
        local frame=exactRequestFrame()

        if frame then
            if not visible(frame) then
                return nil,nil,nil,nil
            end

            local receiving=frame:FindFirstChild("ReceivingRequest")

            if receiving and visible(receiving,frame) then
                local decline=receiving:FindFirstChild("Decline")
                local accept=receiving:FindFirstChild("Accept")
                local username=receiving:FindFirstChild("Username")
                local sender=nil

                if username
                    and (username:IsA("TextLabel")
                        or username:IsA("TextButton")
                        or username:IsA("TextBox"))
                then
                    sender=playerByExactName(textOf(username))
                end

                -- Decompiled MM2 client has direct ReceivingRequest.Accept /
                -- Decline controls. Require both to avoid mistaking a redraw.
                if decline
                    and accept
                    and decline:IsA("GuiButton")
                    and accept:IsA("GuiButton")
                    and visible(decline,receiving)
                    and visible(accept,receiving)
                then
                    return receiving,decline,sender,frame
                end

                return receiving,nil,sender,frame
            end

            return nil,nil,nil,nil
        end

        -- Layout-change fallback only. Normal MM2 path above avoids sweeping
        -- PlayerGui/gethui every polling tick.
        return findIncomingRequestFallback()
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

    local function findPendingCancelFallback()
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

    local function findPendingCancel()
        local frame=exactRequestFrame()

        if frame then
            if not visible(frame) then
                return nil,nil
            end

            local sending=frame:FindFirstChild("SendingRequest")

            if sending and visible(sending,frame) then
                local cancel=sending:FindFirstChild("Cancel")

                if cancel
                    and cancel:IsA("GuiButton")
                    and visible(cancel,sending)
                then
                    return sending,cancel
                end

                return sending,nil
            end

            return nil,nil
        end

        -- Layout-change fallback only.
        return findPendingCancelFallback()
    end

    local function pendingOwner()
        local frame=exactRequestFrame()

        if not frame or not visible(frame) then
            return nil,nil
        end

        local sending=frame:FindFirstChild("SendingRequest")
        if not sending or not visible(sending,frame) then
            return nil,nil
        end

        local username=sending:FindFirstChild("Username")
        local raw=username and textOf(username) or ""
        raw=tostring(raw or ""):gsub("^%s+",""):gsub("%s+$","")

        if raw=="" then
            return nil,nil
        end

        return playerByExactName(raw),raw
    end

    local function pendingBelongsTo(target)
        if select(1,findPendingCancel())==nil then
            return false,"no-pending"
        end

        local owner,raw=pendingOwner()

        if owner then
            return owner==target,owner==target and "exact-owner" or "different-owner"
        end

        if raw and raw~="" and target then
            local wanted=key(target.Name)
            local display=key(target.DisplayName)
            local got=key(raw)

            if got==wanted or (display~="" and got==display) then
                return true,"exact-name"
            end

            return false,"different-name"
        end

        -- Fallback layouts may not expose the username. Preserve old behavior
        -- during an already-owned request, but never use anonymous pending UI
        -- for late adoption.
        return nil,"owner-unknown"
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

    local function tradePartner(t)
        local side=t and t:FindFirstChild("TheirOffer")
        local username=side and side:FindFirstChild("Username")
        local raw=username and textOf(username) or ""

        raw=tostring(raw or "")
        raw=raw:match("^%s*%((.-)%)%s*$") or raw
        raw=raw:gsub("^@",""):gsub("^%s+",""):gsub("%s+$","")

        if raw=="" then
            return nil,nil
        end

        return playerByExactName(raw),raw
    end

    local function tradeBelongsTo(target)
        local t=tradeOpen()
        if not t then
            return false,"no-trade",nil
        end

        local partner,raw=tradePartner(t)

        if partner then
            return partner==target,
                partner==target and "exact-partner" or "different-partner",
                partner
        end

        if raw and raw~="" and target then
            local got=key(raw)
            local wanted=key(target.Name)
            local display=key(target.DisplayName)

            if got==wanted or (display~="" and got==display) then
                return true,"exact-name",nil
            end

            return false,"different-name",nil
        end

        return nil,"partner-unknown",nil
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

    local function targetCurrent(p)
        if not p
            or p==LP
            or p.UserId==LP.UserId
            or p.Parent~=Players
            or Players:GetPlayerByUserId(p.UserId)~=p
        then
            return false,"player-left"
        end

        local rec=scanner.getRecord(p.UserId)

        if not rec then
            return false,"scanner-record-missing"
        end

        if rec.player and rec.player~=p then
            return false,"scanner-player-mismatch"
        end

        if rec.state~="whitelist" then
            return false,"no-longer-whitelisted"
        end

        return true,nil
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
        S.recentTradeTap[p.UserId]=nil
        S.unavailableUntil[p.UserId]=nil
        S.unavailableCount[p.UserId]=nil
    end

    local function processedCount()
        local n=0
        for _ in pairs(S.processed) do
            n+=1
        end
        return n
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

    local function watchOutgoingResponse(target,source,startedAt,serial)
        if not alive() then return "stale-session" end

        local started=tonumber(startedAt) or os.clock()
        local pendingConfirmed=(source=="late-adopted")
        local sentCounted=(source=="late-adopted")
        local proofMissLogged=false
        local tradeSeenAt=nil

        S.active=target
        S.declineSignalAt=0
        S.declineSignalUid=nil

        local session={
            serial=serial,
            userId=target.UserId,
            target=target,
            started=started,
            pendingConfirmed=pendingConfirmed,
        }

        S.uncertainOutgoing=session

        if sentCounted then
            S.sent+=1
        end

        scanner.setRequestState(
            target,
            "requesting",
            source=="late-adopted"
                and "LATE PENDING ADOPTED | owned response watch 15.0s"
                or "TRADE TAPPED | owning target for full 15s response window"
        )

        local function sessionCurrent()
            return alive()
                and S.uncertainOutgoing==session
                and session.userId==target.UserId
        end

        local function finish(result)
            if S.uncertainOutgoing==session then
                S.uncertainOutgoing=nil
            end
            return result
        end

        local function resolveOpenTrade(forceResolve)
            local openTrade=tradeOpen()

            if not openTrade then
                tradeSeenAt=nil
                return nil
            end

            tradeSeenAt=tradeSeenAt or os.clock()

            local belongs,why,partner=tradeBelongsTo(target)

            if belongs==true then
                if not sentCounted then
                    S.sent+=1
                    sentCounted=true
                end

                S.accepted+=1
                scanner.setRequestState(
                    target,
                    "accepted",
                    "Trade opened with exact target | request owned | PART 3 PAUSED"
                )

                print(
                    "[PDIDDLER P3 OUT] UNCERTAIN RESOLVED TRADE",
                    target.Name,
                    "serial",tostring(serial),
                    "pendingConfirmed",tostring(pendingConfirmed)
                )

                return "trade-open"
            end

            if belongs==false then
                scanner.setRequestState(
                    target,
                    "processed",
                    "Different trade opened while this Trade tap was unresolved"
                    ..(partner and (" | active partner "..partner.Name) or "")
                    .." | target protected from resend this server"
                )

                print(
                    "[PDIDDLER P3 OUT] FOREIGN TRADE DURING OUTGOING",
                    "target",target.Name,
                    "serial",tostring(serial),
                    "reason",tostring(why),
                    "partner",partner and partner.Name or "unknown"
                )

                return "trade-open-foreign"
            end

            if forceResolve
                or os.clock()-tradeSeenAt>=C.TradePartnerResolveGrace
            then
                scanner.setRequestState(
                    target,
                    "processed",
                    "Trade opened but partner header did not resolve | target protected from resend this server"
                )

                print(
                    "[PDIDDLER P3 OUT] TRADE PARTNER UNRESOLVED",
                    target.Name,
                    "serial",tostring(serial)
                )

                return "trade-open-unverified"
            end

            return "wait-partner"
        end

        while sessionCurrent()
            and os.clock()-started<C.ResponseTimeout
        do
            if incomingVisible() then
                local cleared=declineIncoming(
                    "while owning outgoing response for "..target.Name
                )

                if not cleared then
                    scanner.setRequestState(
                        target,
                        "requesting",
                        "Incoming request is obstructing UI | outgoing ownership preserved"
                    )
                    task.wait(0.15)
                    continue
                end
            end

            if target.Parent~=Players
                or Players:GetPlayerByUserId(target.UserId)~=target
            then
                S.left+=1
                scanner.setRequestState(
                    target,
                    "left",
                    "Player left while outgoing request ownership was active"
                )
                return finish("left")
            end

            local tradeResult=resolveOpenTrade(false)

            if tradeResult then
                if tradeResult=="wait-partner" then
                    task.wait(0.08)
                    continue
                end

                return finish(tradeResult)
            end

            local belongs,belongsWhy=pendingBelongsTo(target)

            if belongs==true
                or (
                    belongs==nil
                    and belongsWhy=="owner-unknown"
                    and pendingVisible()
                )
            then
                if not pendingConfirmed then
                    pendingConfirmed=true
                    session.pendingConfirmed=true

                    if not sentCounted then
                        S.sent+=1
                        sentCounted=true
                    end

                    scanner.setRequestState(
                        target,
                        "requesting",
                        "Pending UI confirmed for owned Trade tap | continuing same 15s timer"
                    )

                    print(
                        "[PDIDDLER P3 OUT] PENDING CONFIRMED",
                        target.Name,
                        "serial",tostring(serial),
                        "age",string.format("%.2f",os.clock()-started)
                    )
                end
            elseif belongs==false and pendingVisible() then
                -- With one authoritative outgoing owner, a different visible
                -- pending request is stale/manual and must not steal ownership.
                local other,raw=pendingOwner()

                scanner.setStatus(
                    "P3 OUT — foreign pending "
                    ..tostring(raw or (other and other.Name) or "unknown")
                    .." while owning "..target.Name
                    .." | cancelling foreign pending"
                )

                cancelPending(
                    "foreign pending while owning outgoing "..target.Name
                )

                task.wait(0.12)
                continue
            elseif pendingConfirmed and belongs==false then
                -- We had direct proof and it vanished. Give MM2 a short chance
                -- to render the accepted trade before classifying closure.
                scanner.setRequestState(
                    target,
                    "requesting",
                    "Confirmed pending disappeared | verifying trade-open/decline"
                )

                if waitTradeOpen(target,C.TradeOpenGrace) then
                    -- Loop again so exact partner ownership is verified.
                    task.wait(0.05)
                    continue
                end

                task.wait(0.30)

                if not tradeOpen() then
                    local finalBelongs=pendingBelongsTo(target)

                    if finalBelongs==false then
                        if S.declineSignalUid==target.UserId
                            and S.declineSignalAt>0
                        then
                            S.declined+=1
                            scanner.setRequestState(
                                target,
                                "declined",
                                "Confirmed request declined | no trade window"
                            )
                            return finish("declined")
                        end

                        S.failed+=1
                        scanner.setRequestState(
                            target,
                            "sendfailed",
                            "Confirmed request channel closed without verifiable decline or trade-open"
                        )
                        return finish("failed")
                    end
                end
            end

            if S.declineSignalUid==target.UserId
                and S.declineSignalAt>0
            then
                scanner.setRequestState(
                    target,
                    "requesting",
                    "MM2 response signal received | verifying exact trade ownership"
                )

                if waitTradeOpen(target,C.TradeOpenGrace) then
                    task.wait(0.05)
                    continue
                end

                local stillBelongs=pendingBelongsTo(target)

                if stillBelongs==false then
                    S.declined+=1
                    scanner.setRequestState(
                        target,
                        "declined",
                        "MM2 decline signal + no target pending + no trade window"
                    )
                    return finish("declined")
                end

                S.declineSignalAt=0
                S.declineSignalUid=nil
            end

            local age=os.clock()-started
            local remaining=math.max(0,C.ResponseTimeout-age)

            if not pendingConfirmed and age>=C.PendingProofTimeout then
                if not proofMissLogged then
                    proofMissLogged=true

                    warn(
                        "[PDIDDLER P3 OUT] PENDING UI NOT PROVEN",
                        target.Name,
                        "serial",tostring(serial),
                        "| ownership retained for full response window"
                    )
                end

                scanner.setRequestState(
                    target,
                    "requesting",
                    string.format(
                        "UNCERTAIN OUTGOING — Trade was tapped; pending UI not proven | target locked | %.1fs",
                        remaining
                    )
                )
            else
                scanner.setRequestState(
                    target,
                    "requesting",
                    string.format(
                        "%s | %.1fs",
                        pendingConfirmed
                            and "Pending confirmed; waiting for response"
                            or "Trade tapped; waiting for pending/trade/decline proof",
                        remaining
                    )
                )
            end

            scanner.setStatus(
                string.format(
                    "P3 OUT — owning %s request | %s | %.1fs",
                    target.Name,
                    pendingConfirmed and "pending confirmed" or "proof uncertain",
                    remaining
                )
            )

            task.wait(0.12)
        end

        if not alive() then
            return finish("stale-session")
        end

        local finalTradeResult=resolveOpenTrade(true)

        if finalTradeResult
            and finalTradeResult~="wait-partner"
        then
            return finish(finalTradeResult)
        end

        local belongs=pendingBelongsTo(target)

        if belongs==true
            or (
                belongs==nil
                and pendingConfirmed
                and pendingVisible()
            )
        then
            S.ignored+=1

            scanner.setRequestState(
                target,
                "ignored",
                "No response for 15s | cancelling owned pending request"
            )

            local cancelled=cancelPending(
                "15s no response for "..target.Name
            )

            scanner.setRequestState(
                target,
                "ignored",
                cancelled
                    and "Ignored 15s | owned pending request cancelled"
                    or "Ignored 15s | cancel attempted; target protected from resend"
            )

            return finish("ignored")
        end

        -- A physical tap proves only that our input happened. It does not prove
        -- MM2 created a request. Preserve ownership for the full response
        -- window first; only a completely unproven tap gets one bounded retry.
        S.uncertainTimeouts+=1

        local count=(tonumber(S.unavailableCount[target.UserId]) or 0)+1
        S.unavailableCount[target.UserId]=count

        if count<C.MaxUnavailableChecks then
            S.unavailableUntil[target.UserId]=os.clock()+C.UnavailableRetryDelay

            scanner.setRequestState(
                target,
                "unavailable",
                string.format(
                    "UNPROVEN SEND %d/%d — no pending/trade/decline proof for 15s | retry in %.0fs",
                    count,
                    C.MaxUnavailableChecks,
                    C.UnavailableRetryDelay
                )
            )

            print(
                "[PDIDDLER P3 OUT] UNCERTAIN DEFER",
                target.Name,
                "serial",tostring(serial),
                "check",count.."/"..C.MaxUnavailableChecks,
                "retryIn",C.UnavailableRetryDelay,
                "| no resend before cooldown"
            )

            -- Keep recentTradeTap intact so late pending replication can be
            -- adopted during the cooldown instead of triggering another tap.
            return finish("deferred-unproven")
        end

        scanner.setRequestState(
            target,
            "unavailable",
            string.format(
                "UNPROVEN SEND %d/%d — still no pending/trade/decline proof | no further resend this server",
                count,
                C.MaxUnavailableChecks
            )
        )

        print(
            "[PDIDDLER P3 OUT] UNCERTAIN FINAL",
            target.Name,
            "serial",tostring(serial),
            "check",count.."/"..C.MaxUnavailableChecks,
            "| NO FURTHER RESEND THIS SERVER"
        )

        return finish("uncertain-timeout-final")
    end

    local function sendAndWatch(target)
        if not alive() then return "stale-session" end

        if not target
            or target==LP
            or target.UserId==LP.UserId
        then
            return "self-blocked"
        end

        local current,currentWhy=targetCurrent(target)

        if not current then
            if currentWhy=="no-longer-whitelisted" then
                return "not-whitelisted"
            end
            return "left"
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

        for attempt=1,C.SendAttempts do
            if not alive() then return "stale-session" end

            if incomingVisible() then
                local cleared=declineIncoming("before card open for "..target.Name)
                if not cleared then
                    return "blocked-by-incoming"
                end
                task.wait(0.20)
            end

            local targetOk,targetWhy=targetCurrent(target)

            if not targetOk then
                if targetWhy=="no-longer-whitelisted" then
                    return "not-whitelisted"
                end

                S.left=S.left+1
                scanner.setRequestState(
                    target,
                    "left",
                    "Target became stale before physical click | skipped without send failure"
                )
                return "left"
            end

            if tradeOpen() then
                scanner.setRequestState(
                    target,
                    "processed",
                    "Trade opened before this target was tapped | no request attributed to target"
                )
                return "preexisting-trade-open"
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
                local stillCurrent,staleWhy=targetCurrent(target)

                if not stillCurrent then
                    if staleWhy=="no-longer-whitelisted" then
                        return "not-whitelisted"
                    end

                    S.left=S.left+1
                    scanner.setRequestState(
                        target,
                        "left",
                        "Player disappeared while opening card | skipped without retry/failure"
                    )

                    print(
                        "[PDIDDLER P3 OUT] STALE TARGET SKIP",
                        target.Name,
                        tostring(staleWhy)
                    )

                    return "left"
                end

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

            local finalCurrent,finalWhy=targetCurrent(target)

            if not finalCurrent then
                if finalWhy=="no-longer-whitelisted" then
                    return "not-whitelisted"
                end

                S.left=S.left+1
                scanner.setRequestState(
                    target,
                    "left",
                    "Target became stale after card verification | Trade not tapped"
                )
                return "left"
            end

            -- Re-read the card immediately before the physical Trade tap.
            -- Never trust a cached button after UI redraws / player departure.
            local freshCard,freshTradeButton,freshMatched=
                findOpenCardFor(target)

            if not freshCard
                or freshMatched~=true
                or not freshTradeButton
                or not visible(freshTradeButton)
            then
                if attempt<C.SendAttempts then
                    task.wait(0.25)
                    continue
                end

                S.failed=S.failed+1
                scanner.setRequestState(
                    target,
                    "sendfailed",
                    "Fresh target card was lost before Trade tap"
                )
                return "failed"
            end

            tradeButton=freshTradeButton

            if tradeOpen() then
                scanner.setRequestState(
                    target,
                    "processed",
                    "Trade opened before Trade tap | no request attributed to target"
                )
                return "preexisting-trade-open"
            end

            scanner.setRequestState(
                target,
                "sending",
                "Fresh target + card reverified | physically tapping Trade"
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

            S.outgoingSerial+=1
            local serial=S.outgoingSerial
            local tappedAt=os.clock()

            S.recentTradeTap[target.UserId]={
                at=tappedAt,
                player=target,
                serial=serial,
            }

            print(
                "[PDIDDLER P3 OUT] OUTGOING OWNED",
                target.Name,
                "serial",serial,
                "| physical Trade tap succeeded"
            )

            -- Do NOT release this target merely because the local pending UI
            -- fails to render. Own the request for the full response window.
            return watchOutgoingResponse(
                target,
                "physical-tap",
                tappedAt,
                serial
            )
        end

        return "failed"
    end

    task.spawn(function()
        print(
            "[PDIDDLER P3 OUT] START",
            "session",
            SESSION
        )

        task.wait(0.75)

        local idleLogged=false

        while alive() do
            if S.paused then
                if tradeOpen() then
                    -- Part 4 exclusively owns the main status while an active
                    -- item trade exists. Do not overwrite its timer/balancer UI.
                    task.wait(0.15)
                    continue
                end

                -- Part 4 closed the trade, the partner cancelled, or the trade
                -- otherwise disappeared. Resume the same queue/session. The
                -- accepted target was already marked processed, so rotation
                -- naturally advances to the next eligible player.
                S.paused=false
                S.active=nil
                idleLogged=false

                scanner.setStatus(
                    "P3 OUT — trade closed | resuming rotation to next eligible player"
                )

                print(
                    "[PDIDDLER P3 OUT] RESUME",
                    "| trade closed",
                    "| continuing queue"
                )

                task.wait(0.20)
                continue
            end

            if tradeOpen() then
                S.paused=true
                scanner.setStatus(
                    "P3 OUT — active trade detected | PAUSED for Part 4"
                )
                task.wait(0.15)
                continue
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
                local owner,rawOwner=pendingOwner()
                local recent=owner and S.recentTradeTap[owner.UserId]
                local recentAge=recent and (os.clock()-(tonumber(recent.at) or 0)) or math.huge
                local canAdopt=
                    owner
                    and owner.Parent==Players
                    and not S.processed[owner.UserId]
                    and scanner.isWhitelisted(owner.UserId)
                    and recent
                    and recentAge<=C.LatePendingAdoptWindow

                if canAdopt then
                    idleLogged=false
                    S.active=owner
                    S.unavailableUntil[owner.UserId]=nil
                    S.unavailableCount[owner.UserId]=nil

                    scanner.setRequestState(
                        owner,
                        "requesting",
                        string.format(
                            "Late pending adopted after %.1fs | starting normal 15s response timer",
                            recentAge
                        )
                    )

                    print(
                        "[PDIDDLER P3 OUT] LATE PENDING ADOPT",
                        owner.Name,
                        "age",string.format("%.2f",recentAge)
                    )

                    S.outgoingSerial+=1
                    local adoptedSerial=S.outgoingSerial

                    ENV.PDIDDLER_OUTGOING_BUSY_SESSION=SESSION
                    local adoptedResult=watchOutgoingResponse(
                        owner,
                        "late-adopted",
                        os.clock(),
                        adoptedSerial
                    )
                    if ENV.PDIDDLER_OUTGOING_BUSY_SESSION==SESSION then
                        ENV.PDIDDLER_OUTGOING_BUSY_SESSION=nil
                    end

                    if not alive() then break end

                    if adoptedResult~="blocked-by-pending"
                        and adoptedResult~="blocked-by-incoming"
                        and adoptedResult~="interrupted-by-incoming"
                        and adoptedResult~="not-whitelisted"
                        and adoptedResult~="preexisting-trade-open"
                    then
                        markProcessed(owner,adoptedResult)
                    end

                    S.active=nil

                    if adoptedResult=="trade-open"
                        or adoptedResult=="trade-open-foreign"
                        or adoptedResult=="trade-open-unverified"
                        or adoptedResult=="preexisting-trade-open"
                    then
                        S.paused=true

                        scanner.setStatus(
                            "P3 OUT — ADOPTED pending accepted | trade window open | PART 3 PAUSED"
                        )

                        print(
                            "[PDIDDLER P3 OUT] HANDOFF",
                            owner.Name,
                            "| adopted late pending",
                            "| Part 4 owns active trade"
                        )
                    end

                    task.wait(0.20)
                    continue
                end

                -- A pending request we cannot prove belongs to a recent script
                -- tap must never freeze the queue forever. Cancel it instead.
                scanner.setStatus(
                    "P3 OUT — orphan pending"
                    ..((rawOwner and rawOwner~="") and (" for "..rawOwner) or "")
                    .." | cancelling to recover queue"
                )

                local cleared=cancelPending("orphan/unowned pending recovery")

                print(
                    "[PDIDDLER P3 OUT] ORPHAN PENDING RECOVERY",
                    tostring(rawOwner or "unknown"),
                    "cleared",cleared
                )

                task.wait(cleared and 0.15 or 0.35)
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
                        processedCount(),
                        "whitelist",
                        #scanner.getWhitelist(),
                        "sent",
                        S.sent,
                        "ignored",
                        S.ignored,
                        "declined",
                        S.declined,
                        "failed",
                        S.failed,
                        "uncertainTimeouts",
                        S.uncertainTimeouts,
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

            ENV.PDIDDLER_OUTGOING_BUSY_SESSION=SESSION
            local result=sendAndWatch(target)
            if ENV.PDIDDLER_OUTGOING_BUSY_SESSION==SESSION then
                ENV.PDIDDLER_OUTGOING_BUSY_SESSION=nil
            end

            if not alive() then break end

            if result~="blocked-by-pending"
                and result~="blocked-by-incoming"
                and result~="interrupted-by-incoming"
                and result~="not-whitelisted"
                and result~="preexisting-trade-open"
                and result~="deferred-unproven"
            then
                markProcessed(target,result)
            end

            S.active=nil

            if result=="blocked-by-incoming"
                or result=="interrupted-by-incoming"
            then
                task.wait(0.20)
                continue
            end

            if result=="trade-open"
                or result=="trade-open-foreign"
                or result=="trade-open-unverified"
                or result=="preexisting-trade-open"
            then
                S.paused=true

                scanner.setStatus(
                    "P3 OUT — ACCEPTED request | trade window open | PART 3 PAUSED"
                )

                print(
                    "[PDIDDLER P3 OUT] HANDOFF",
                    target.Name,
                    "| Part 4 owns active trade",
                    "| queue will resume when trade closes",
                    "| FINAL TRADE ACCEPT remains disabled"
                )

                task.wait(0.15)
                continue
            end

            task.wait(0.25)
        end
    end)

    return {
        session=SESSION,
        state=S,
        stop=function()
            if ENV.PDIDDLER_OUTGOING_BUSY_SESSION==SESSION then
                ENV.PDIDDLER_OUTGOING_BUSY_SESSION=nil
            end
            if ENV.PDIDDLER_OUTGOING_SESSION==SESSION then
                ENV.PDIDDLER_OUTGOING_SESSION=SESSION+1
            end
        end,
    }
end

return M
