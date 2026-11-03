-- Post-trade received-item auto-claimer v1.
-- Arms only from verified AcceptTrade completion; physically taps visible
-- "Claim (n/total)" buttons and pauses scanner/outgoing until the sequence ends.
local M={}

function M.run(scanner,policy)
    assert(type(scanner)=="table","scanner required")
    assert(type(scanner.claimStatusOwner)=="function","scanner.claimStatusOwner missing")
    assert(type(scanner.releaseStatusOwner)=="function","scanner.releaseStatusOwner missing")
    assert(type(scanner.setStatus)=="function","scanner.setStatus missing")
    assert(type(policy)=="table","claim policy required")
    assert(type(policy.parse)=="function","claim policy parse missing")
    assert(type(policy.newSession)=="function","claim policy newSession missing")
    assert(type(policy.observe)=="function","claim policy observe missing")
    assert(type(policy.noteTap)=="function","claim policy noteTap missing")

    local Players=game:GetService("Players")
    local RS=game:GetService("ReplicatedStorage")
    local VIM=game:GetService("VirtualInputManager")
    local GuiService=game:GetService("GuiService")

    local LP=Players.LocalPlayer
    local PG=LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui")
    local ENV=(getgenv and getgenv()) or _G

    local SESSION=(tonumber(ENV.PDIDDLER_POST_TRADE_CLAIM_SESSION) or 0)+1
    ENV.PDIDDLER_POST_TRADE_CLAIM_SESSION=SESSION
    ENV.PDIDDLER_POST_TRADE_CLAIM_BUSY_SESSION=nil

    local C={
        AppearTimeout=4.0,
        OverallTimeout=12.0,
        Poll=0.10,
    }

    local S={
        session=SESSION,
        busy=false,
        cycles=0,
        taps=0,
        completed=0,
        timeouts=0,
        noPopup=0,
        lastReason="idle",
    }

    local function alive()
        return ENV.PDIDDLER_POST_TRADE_CLAIM_SESSION==SESSION
    end

    local function visible(o)
        if not o then return false end
        local ok,res=pcall(function()
            local c=o
            while c do
                if c:IsA("ScreenGui") and not c.Enabled then return false end
                if c:IsA("GuiObject") and not c.Visible then return false end
                c=c.Parent
            end
            return true
        end)
        return ok and res==true
    end

    local function clickableAncestor(o,limit)
        local c=o
        for _=1,(limit or 6) do
            if not c then break end
            if c:IsA("GuiButton") then return c end
            c=c.Parent
        end
        return nil
    end

    local function center(o)
        local ok,pos,size=pcall(function()
            return o.AbsolutePosition,o.AbsoluteSize
        end)
        if not ok or not pos or not size then return nil,nil end

        local insetX,insetY=0,0
        pcall(function()
            local inset=GuiService:GetGuiInset()
            insetX=inset.X
            insetY=inset.Y
        end)

        return pos.X+(size.X/2)+insetX,pos.Y+(size.Y/2)+insetY
    end

    local function physicalTap(button)
        if not alive() or not button or not visible(button) then return false end
        local x,y=center(button)
        if not x then return false end

        local ok=pcall(function()
            VIM:SendMouseButtonEvent(x,y,0,true,game,0)
            task.wait(0.07)
            VIM:SendMouseButtonEvent(x,y,0,false,game,0)
        end)
        return ok
    end

    local function findClaimButton()
        -- Short-lived post-completion scan only. Prefer MainGUI, but fall back
        -- to PlayerGui because the reward popup's exact object path is not
        -- assumed from the recording.
        local scope=PG:FindFirstChild("MainGUI") or PG
        local ok,desc=pcall(function() return scope:GetDescendants() end)
        if not ok then return nil,nil,nil,nil end

        for _,d in ipairs(desc) do
            if (d:IsA("TextButton") or d:IsA("TextLabel"))
                and visible(d)
            then
                local text=tostring(d.Text or "")
                local current,total=policy.parse(text)
                if current then
                    local button=d:IsA("GuiButton") and d or clickableAncestor(d,6)
                    if button and visible(button) then
                        return button,text,current,total
                    end
                end
            end
        end

        -- If MainGUI existed but the reward popup lives under another ScreenGui,
        -- use one bounded fallback scan for the same strict Claim(n/total) text.
        if scope~=PG then
            local ok2,all=pcall(function() return PG:GetDescendants() end)
            if ok2 then
                for _,d in ipairs(all) do
                    if (d:IsA("TextButton") or d:IsA("TextLabel"))
                        and visible(d)
                    then
                        local text=tostring(d.Text or "")
                        local current,total=policy.parse(text)
                        if current then
                            local button=d:IsA("GuiButton") and d or clickableAncestor(d,6)
                            if button and visible(button) then
                                return button,text,current,total
                            end
                        end
                    end
                end
            end
        end

        return nil,nil,nil,nil
    end

    local cycleSerial=0

    local function releaseBusy(reason)
        S.busy=false
        S.lastReason=tostring(reason or "released")

        if ENV.PDIDDLER_POST_TRADE_CLAIM_BUSY_SESSION==SESSION then
            ENV.PDIDDLER_POST_TRADE_CLAIM_BUSY_SESSION=nil
        end

        scanner.releaseStatusOwner("CLAIM")
    end

    local function startClaimCycle(source)
        if not alive() then return false,"stale-session" end
        if S.busy then return false,"already-busy" end

        cycleSerial+=1
        local cycle=cycleSerial
        S.busy=true
        S.cycles+=1
        S.lastReason="starting"

        ENV.PDIDDLER_POST_TRADE_CLAIM_BUSY_SESSION=SESSION
        scanner.claimStatusOwner("CLAIM")
        scanner.setStatus(
            "POST-TRADE CLAIM — waiting for received weapon popup",
            "CLAIM"
        )

        print(
            "[PDIDDLER CLAIM] AUTO CLAIM START",
            "| cycle",cycle,
            "| source",tostring(source or "server-complete")
        )

        task.spawn(function()
            local started=os.clock()
            local state=policy.newSession(started)
            local finishReason="timeout"

            while alive()
                and S.busy
                and cycle==cycleSerial
                and os.clock()-started<C.OverallTimeout
            do
                local button,text,current,total=findClaimButton()
                local now=os.clock()
                local action,meta=policy.observe(state,text,now)

                if action=="tap" and button then
                    local ok=physicalTap(button)
                    policy.noteTap(state,text,now,ok)

                    if ok then
                        S.taps+=1
                        scanner.setStatus(
                            string.format(
                                "POST-TRADE CLAIM — claiming %d/%d",
                                tonumber(current) or 0,
                                tonumber(total) or 0
                            ),
                            "CLAIM"
                        )
                        print(
                            "[PDIDDLER CLAIM] AUTO CLAIM TAP",
                            tostring(current).."/"..tostring(total),
                            "| attempt",tostring(meta and meta.attempt or "?")
                        )
                    end
                elseif action=="complete" then
                    finishReason="complete"
                    break
                elseif action=="stuck" then
                    finishReason="stuck"
                    break
                elseif not state.seenAny
                    and now-started>=C.AppearTimeout
                then
                    finishReason="no-popup"
                    break
                end

                task.wait(C.Poll)
            end

            if not alive() or cycle~=cycleSerial then
                return
            end

            if finishReason=="complete" then
                S.completed+=1
                print(
                    "[PDIDDLER CLAIM] AUTO CLAIM COMPLETE",
                    "| cycle",cycle,
                    "| taps",S.taps
                )
            elseif finishReason=="no-popup" then
                S.noPopup+=1
                print(
                    "[PDIDDLER CLAIM] AUTO CLAIM COMPLETE",
                    "| cycle",cycle,
                    "| no claim popup appeared"
                )
            else
                S.timeouts+=1
                warn(
                    "[PDIDDLER CLAIM] AUTO CLAIM TIMEOUT",
                    "| cycle",cycle,
                    "| reason",finishReason,
                    "| releasing queue to avoid deadlock"
                )
            end

            releaseBusy(finishReason)
        end)

        return true,"started"
    end

    local tradeFolder=RS:FindFirstChild("Trade")
    local AcceptTrade=tradeFolder and tradeFolder:FindFirstChild("AcceptTrade")
    local conn=nil

    if AcceptTrade and AcceptTrade:IsA("RemoteEvent") then
        conn=AcceptTrade.OnClientEvent:Connect(function(complete)
            if not alive() or complete~=true then return end
            startClaimCycle("server-complete")
        end)
    else
        warn("[PDIDDLER CLAIM] AcceptTrade completion event unavailable; auto-claim not armed")
    end

    print("[PDIDDLER CLAIM] ARMED | verified completion -> physical Claim(n/total) taps")

    return {
        session=SESSION,
        state=S,
        startClaimCycle=startClaimCycle,
        stop=function()
            cycleSerial+=1
            if conn then pcall(function() conn:Disconnect() end) end
            releaseBusy("stopped")
            if ENV.PDIDDLER_POST_TRADE_CLAIM_SESSION==SESSION then
                ENV.PDIDDLER_POST_TRADE_CLAIM_SESSION=SESSION+1
            end
        end,
    }
end

return M
