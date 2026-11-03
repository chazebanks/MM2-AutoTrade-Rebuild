-- pdiddler manual-accept + projected-gain observer v1
-- TEST-ONLY, read-only UI observer.
-- Never clicks Accept/Confirm, never fires trade remotes, never mutates offers.
--
-- Responsibilities:
--   * show current verified raw-value projected gain from Part 4 webhookCandidate
--   * detect the local native YourOffer.Accepted indicator
--   * report accept/clear transitions for test evidence
--   * hide cleanly when the trade closes
--
-- The verified completion logger remains the ONLY authority for deciding that
-- a trade actually completed.

local M={}

function M.run(part4Controller)
    assert(type(part4Controller)=="table","Part 4 controller required")
    assert(type(part4Controller.state)=="table","Part 4 state required")

    local Players=game:GetService("Players")
    local LP=Players.LocalPlayer
    local ENV=(getgenv and getgenv()) or _G

    local SESSION=(tonumber(ENV.PDIDDLER_MANUAL_GAIN_SESSION) or 0)+1
    ENV.PDIDDLER_MANUAL_GAIN_SESSION=SESSION

    local S={
        session=SESSION,
        manualAccepted=false,
        acceptTransitions=0,
        clearTransitions=0,
        lastGain=nil,
        lastOur=nil,
        lastTheir=nil,
        lastCandidateSeq=nil,
        status="starting",
    }

    local function alive()
        return ENV.PDIDDLER_MANUAL_GAIN_SESSION==SESSION
    end

    local function playerGui()
        return LP and (
            LP:FindFirstChildOfClass("PlayerGui")
            or LP:FindFirstChild("PlayerGui")
        )
    end

    local function visible(o,stopAt)
        if not o then return false end
        local ok,res=pcall(function()
            local p=o
            while p do
                if p:IsA("GuiObject") and not p.Visible then
                    return false
                end
                if p:IsA("ScreenGui") and not p.Enabled then
                    return false
                end
                if stopAt and p==stopAt then return true end
                p=p.Parent
            end
            return stopAt==nil
        end)
        return ok and res
    end

    local function tradeRoot()
        local PG=playerGui()
        if not PG then return nil end

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
                if enabled then return t end
            end
        end

        return nil
    end

    local function localAcceptedShown(t)
        if not t then return false end
        local ours=t:FindFirstChild("YourOffer")
        local accepted=ours and ours:FindFirstChild("Accepted")
        return accepted~=nil and visible(accepted,t)
    end

    local gui=nil
    local label=nil

    local function destroyGui()
        if gui then
            pcall(function() gui:Destroy() end)
        end
        gui=nil
        label=nil
    end

    local function ensureGui()
        local PG=playerGui()
        if not PG then return nil end

        if gui and gui.Parent==PG and label and label.Parent then
            return label
        end

        destroyGui()

        local old=PG:FindFirstChild("PDIDDLER_TradeGain_Test_v1")
        if old then
            pcall(function() old:Destroy() end)
        end

        gui=Instance.new("ScreenGui")
        gui.Name="PDIDDLER_TradeGain_Test_v1"
        gui.ResetOnSpawn=false
        gui.IgnoreGuiInset=true
        gui.DisplayOrder=1000
        gui.ZIndexBehavior=Enum.ZIndexBehavior.Global
        gui.Parent=PG

        label=Instance.new("TextLabel")
        label.Name="ProjectedGain"
        label.AnchorPoint=Vector2.new(0,0)
        label.Size=UDim2.fromOffset(330,38)
        label.BackgroundTransparency=0.18
        label.BackgroundColor3=Color3.fromRGB(20,20,24)
        label.BorderSizePixel=0
        label.Font=Enum.Font.GothamBold
        label.TextSize=17
        label.TextWrapped=true
        label.TextColor3=Color3.fromRGB(235,235,240)
        label.Text="Projected Gain: calculating..."
        label.Visible=false
        label.ZIndex=50
        label.Parent=gui

        local corner=Instance.new("UICorner")
        corner.CornerRadius=UDim.new(0,9)
        corner.Parent=label

        local stroke=Instance.new("UIStroke")
        stroke.Thickness=1
        stroke.Transparency=0.45
        stroke.Parent=label

        return label
    end

    local function fmt(v)
        local n=tonumber(v)
        if not n then return "?" end
        if math.abs(n-math.floor(n+0.5))<0.0001 then
            return tostring(math.floor(n+0.5))
        end
        return string.format("%.2f",n)
    end

    local function gainText(candidate,accepted)
        if type(candidate)~="table" or candidate.verified~=true then
            return accepted
                and "Projected Gain: calculating...  |  MANUAL ACCEPTED"
                or "Projected Gain: calculating..."
        end

        local ours=tonumber(candidate.giveRaw)
        local theirs=tonumber(candidate.receiveRaw)
        local gain=tonumber(candidate.rawGain)

        if not ours or not theirs or not gain then
            return accepted
                and "Projected Gain: unknown  |  MANUAL ACCEPTED"
                or "Projected Gain: unknown"
        end

        local prefix=gain>=0 and "+" or ""
        local base=string.format(
            "Projected Gain: %s%s  |  You: %s  Them: %s",
            prefix,
            fmt(gain),
            fmt(ours),
            fmt(theirs)
        )

        if accepted then
            base=base.."  |  MANUAL ACCEPTED"
        end

        return base
    end

    task.spawn(function()
        print("[PDIDDLER MANUAL TEST] ARMED | projected gain + local Accept observer | NO CLICK")

        local previousAccepted=false
        local hadTrade=false

        while alive() do
            local t=tradeRoot()
            local l=ensureGui()

            if t and l then
                hadTrade=true
                l.Visible=true

                local pos=t.AbsolutePosition
                local size=t.AbsoluteSize
                local x=math.floor(pos.X+(size.X/2)-165)
                local y=math.floor(pos.Y-42)
                if y<6 then y=math.floor(pos.Y+6) end
                if x<6 then x=6 end
                l.Position=UDim2.fromOffset(x,y)

                local accepted=localAcceptedShown(t)
                local candidate=part4Controller.state.webhookCandidate

                l.Text=gainText(candidate,accepted)

                if type(candidate)=="table" and candidate.verified==true then
                    S.lastGain=tonumber(candidate.rawGain)
                    S.lastOur=tonumber(candidate.giveRaw)
                    S.lastTheir=tonumber(candidate.receiveRaw)
                    S.lastCandidateSeq=candidate.seq
                    S.status="verified-gain"
                else
                    S.status="awaiting-verified-gain"
                end

                if accepted and not previousAccepted then
                    S.manualAccepted=true
                    S.acceptTransitions+=1
                    S.status="manual-accept-detected"

                    local gain=S.lastGain
                    print(
                        "[PDIDDLER MANUAL TEST] LOCAL ACCEPT DETECTED",
                        "| projected gain",gain and ((gain>=0 and "+") or "")..fmt(gain) or "unknown",
                        "| NO AUTOMATED ACCEPT/CONFIRM ACTION"
                    )
                elseif not accepted and previousAccepted then
                    S.manualAccepted=false
                    S.clearTransitions+=1
                    S.status="manual-accept-cleared"
                    print(
                        "[PDIDDLER MANUAL TEST] LOCAL ACCEPT CLEARED",
                        "| trade still open",
                        "| planner may continue from current native state"
                    )
                else
                    S.manualAccepted=accepted
                end

                previousAccepted=accepted
            else
                if l then l.Visible=false end

                if hadTrade and previousAccepted then
                    print(
                        "[PDIDDLER MANUAL TEST] TRADE CLOSED AFTER LOCAL ACCEPT",
                        "| completion authority remains webhook completion logger"
                    )
                end

                hadTrade=false
                previousAccepted=false
                S.manualAccepted=false
                S.status="no-trade"
            end

            task.wait(0.12)
        end

        destroyGui()
        S.manualAccepted=false
        S.status="stopped"
    end)

    return {
        session=SESSION,
        state=S,
        stop=function()
            if ENV.PDIDDLER_MANUAL_GAIN_SESSION==SESSION then
                ENV.PDIDDLER_MANUAL_GAIN_SESSION=SESSION+1
            end
            destroyGui()
        end,
    }
end

return M
