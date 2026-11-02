-- pdiddler Part 5 shadow completion runtime v1
-- Read-only observer. SHADOW ONLY.
-- Reports when the first native Accept click would be permitted.
-- Performs no click, signal fire, remote fire, or completion action.

local M={}
local READY_REASON="ready-first-click"

function M.run(part4Controller,policy)
    assert(type(part4Controller)=="table","Part 4 controller required")
    assert(type(part4Controller.state)=="table","Part 4 state required")
    assert(type(policy)=="table" and type(policy.evaluate)=="function",
        "Part 5 policy required")

    local Players=game:GetService("Players")
    local LP=Players.LocalPlayer
    local PG=LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui")
    local ENV=(getgenv and getgenv()) or _G

    local SESSION=(tonumber(ENV.PDIDDLER_PART5_SESSION) or 0)+1
    ENV.PDIDDLER_PART5_SESSION=SESSION

    local S={
        session=SESSION,
        ready=false,
        reason="starting",
        transitions=0,
        lastSnapshot=nil,
    }

    local function alive()
        return ENV.PDIDDLER_PART5_SESSION==SESSION
    end

    local function visible(o,stopAt)
        if not o then return false end
        local ok,res=pcall(function()
            local p=o
            while p do
                if p:IsA("GuiObject") and not p.Visible then return false end
                if p:IsA("ScreenGui") and not p.Enabled then return false end
                if stopAt and p==stopAt then return true end
                p=p.Parent
            end
            return stopAt==nil
        end)
        return ok and res
    end

    local function tradeRoot()
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

    local function textOf(o)
        if not o then return "" end
        if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
            local ok,v=pcall(function() return tostring(o.Text or "") end)
            if ok then return v end
        end
        return ""
    end

    local function normName(x)
        return tostring(x or "")
            :gsub("^%s+","")
            :gsub("%s+$","")
            :gsub("^%(","")
            :gsub("%)$","")
            :lower()
    end

    local function uiState()
        local t=tradeRoot()
        if not t then
            return {
                tradeOpen=false,
                partnerName=nil,
                opponentAccepted=false,
                cooldownReady=false,
                acceptButtonVisible=false,
                confirmVisible=false,
                localAccepted=false,
            }
        end

        local their=t:FindFirstChild("TheirOffer")
        local ours=t:FindFirstChild("YourOffer")
        local actions=t:FindFirstChild("Actions")
        local accept=actions and actions:FindFirstChild("Accept")

        local theirAccepted=their and their:FindFirstChild("Accepted")
        local ourAccepted=ours and ours:FindFirstChild("Accepted")
        local username=their and their:FindFirstChild("Username")

        local cooldown=accept and accept:FindFirstChild("Cooldown")
        local confirm=accept and accept:FindFirstChild("Confirm")
        local actionButton=accept and accept:FindFirstChild("ActionButton")

        local partner=textOf(username)
        partner=partner~="" and normName(partner) or nil

        local nativeShapeComplete=
            cooldown~=nil
            and confirm~=nil
            and actionButton~=nil

        return {
            tradeOpen=true,
            partnerName=partner,
            opponentAccepted=theirAccepted~=nil and visible(theirAccepted,t),
            cooldownReady=cooldown~=nil and not visible(cooldown,t),
            acceptButtonVisible=nativeShapeComplete and visible(actionButton,t),
            confirmVisible=confirm~=nil and visible(confirm,t),
            localAccepted=ourAccepted~=nil and visible(ourAccepted,t),
        }
    end

    local lastKey=nil

    task.spawn(function()
        print("[PDIDDLER P5 SHADOW] ARMED | SHADOW ONLY | no completion action")

        while alive() do
            local feed=part4Controller.state.completion
            local ui=uiState()

            local feedAge=math.huge
            if type(feed)=="table" and tonumber(feed.lastObservedAt) then
                feedAge=math.max(0,os.clock()-tonumber(feed.lastObservedAt))
            end

            local targetName=type(feed)=="table" and feed.targetName or nil
            local partnerCurrent=
                ui.tradeOpen
                and type(targetName)=="string"
                and targetName~=""
                and ui.partnerName==normName(targetName)

            local snapshot={
                tradeOpen=ui.tradeOpen,
                sessionCurrent=
                    type(feed)=="table"
                    and tonumber(feed.part4Session)==tonumber(part4Controller.session)
                    and part4Controller.state.active==true,
                partnerCurrent=partnerCurrent,
                p4Verified=type(feed)=="table" and feed.verified==true,
                ourNonEmpty=type(feed)=="table" and feed.ourNonEmpty==true,
                theirNonEmpty=type(feed)=="table" and feed.theirNonEmpty==true,
                ourResolved=type(feed)=="table" and feed.ourResolved==true,
                theirResolved=type(feed)=="table" and feed.theirResolved==true,
                recoveryIdle=type(feed)=="table" and feed.recoveryIdle==true,
                txIdle=type(feed)=="table" and feed.txIdle==true,
                offerStable=type(feed)=="table" and feed.offerStable==true,
                decisionOk=type(feed)=="table" and feed.decisionOk==true,
                signaturesCurrent=
                    type(feed)=="table"
                    and feed.signaturesCurrent==true
                    and feedAge<=0.75,
                opponentAccepted=ui.opponentAccepted,
                cooldownReady=ui.cooldownReady,
                acceptButtonVisible=ui.acceptButtonVisible,
                confirmVisible=ui.confirmVisible,
                localAccepted=ui.localAccepted,
            }

            local ready,reason=policy.evaluate(snapshot)
            S.ready=ready==true
            S.reason=tostring(reason)
            S.lastSnapshot=snapshot

            local key=table.concat({
                ready and "1" or "0",
                tostring(reason),
                tostring(targetName or ""),
                tostring(type(feed)=="table" and feed.seq or ""),
            },":")

            if key~=lastKey then
                lastKey=key
                S.transitions+=1

                if ready then
                    if reason~=READY_REASON then
                        warn(
                            "[PDIDDLER P5 SHADOW] POLICY MISMATCH",
                            tostring(reason)
                        )
                    end

                    print(
                        "[PDIDDLER P5 SHADOW] READY-FIRST-CLICK",
                        "| policy",tostring(reason),
                        "| partner",tostring(targetName),
                        "| source",tostring(feed and feed.source),
                        "| rawProfit",tostring(feed and feed.rawProfit),
                        "| protectedProfit",tostring(feed and feed.protectedProfit),
                        "| native cooldown ready",
                        "| SHADOW ONLY | NO CLICK"
                    )
                elseif ui.tradeOpen then
                    print(
                        "[PDIDDLER P5 SHADOW] BLOCKED",
                        "| reason",tostring(reason),
                        "| partner",tostring(targetName or ui.partnerName or "unknown"),
                        "| feedAge",string.format("%.2f",feedAge)
                    )
                end
            end

            task.wait(0.12)
        end

        S.ready=false
        S.reason="stopped"
    end)

    return {
        session=SESSION,
        state=S,
        stop=function()
            if ENV.PDIDDLER_PART5_SESSION==SESSION then
                ENV.PDIDDLER_PART5_SESSION=SESSION+1
            end
        end,
    }
end

return M
