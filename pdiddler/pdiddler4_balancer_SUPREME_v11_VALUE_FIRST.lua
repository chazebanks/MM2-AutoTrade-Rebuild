-- V15.8 value-first execution of the unchanged selected plan; immediate physical-quote safety retained.
-- Scope:
--   * observe an active MM2 trade handed off by known-good Part 3
--   * observe 2.5s, then skip or choose one realistic partner-reachable opener
--   * accepted-empty => decline immediately
--   * empty/no-action => decline after 12 seconds, including after removal
--   * non-empty => stabilize, value, and rebalance our side
--   * strict +15 Supreme floor; opponent-net-addition-only upward negotiation
--   * FINAL TRADE ACCEPT IS ABSOLUTELY DISABLED
--
-- Market decisions use one immutable dated Supreme profile and strict pure policy.
-- No live market HTTP occurs inside a trade; missing metadata is unresolved.
-- FINAL ACCEPT remains disabled regardless of score.

local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local GuiService=game:GetService("GuiService")
local VIM=game:GetService("VirtualInputManager")

local LP=Players.LocalPlayer
local PG=LP and LP:FindFirstChildOfClass("PlayerGui")
local ENV=(getgenv and getgenv()) or _G

local M={}

local MARKET_PROFILE=nil
local MARKET_LOGIC=nil
local MARKET_PLANNER=nil
local ACCEPT_READY_GATE=nil -- read-only native UI readiness
local EARLY_COUNTER_POLICY=nil -- pure early market-aware policy; no Roblox actions
local AUTOMATION_READY=nil -- optional read-only readiness shared by the integration
local TRADE_SERIAL=0 -- monotonically unique within this controller
local BOUND=nil -- exactly one verified root/partner/session owns all mutations

local C={
    TradeAppearStability=0.30,
    OfferVerifyTimeout=3.0,
    EmptyTimeout=12.0,
    ActiveOfferWindow=60.0,
    OfferStability=0.65,
    EmergencyClearVerifyTimeout=0.24,
    NoPlanNegotiationGrace=5.0,
    RemoveVerifyTimeout=0.90,
    RemoveRetryVerifyTimeout=1.20,
    RemoveRetryGuard=0.25,
    RecoveryRetryDelay=0.75,
    RecoveryMaxAttemptsPerOffer=2,
    ApplyVerifyTimeout=2.5,
    LoopDelay=0.12,


}

local function norm(x)
    return tostring(x or "")
        :gsub("’","'")
        :lower()
        :gsub("^%s+",""):gsub("%s+$",""):gsub("%s+"," ")
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
            if stopAt and p==stopAt then
                return true
            end
            p=p.Parent
        end
        return stopAt==nil
    end)
    return ok and res
end

local function tradeRoot()
    PG=LP and LP:FindFirstChildOfClass("PlayerGui")
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

            if enabled and visible(t,PG) then
                return t
            end
        end
    end

    return nil
end

local function partnerName(t)
    local side=t and t:FindFirstChild("TheirOffer")
    local u=side and side:FindFirstChild("Username")
    local s=u and tostring(u.Text or "") or ""

    s=s:match("^%s*%((.-)%)%s*$") or s
    s=s:gsub("^@",""):gsub("^%s+",""):gsub("%s+$","")
    return s
end

local function findPartner(t)
    local wanted=partnerName(t):lower()
    if wanted=="" then return nil end

    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP and tostring(p.Name):lower()==wanted then
            return p
        end
    end

    return nil
end

local function slotName(slot)
    if not slot or not visible(slot) then return nil end

    local itemName=slot:FindFirstChild("ItemName")
    local label=itemName and itemName:FindFirstChild("Label")

    if label and (label:IsA("TextLabel") or label:IsA("TextButton")) then
        local s=tostring(label.Text or ""):gsub("^%s+",""):gsub("%s+$","")
        if s~="" then return s end
    end

    for _,d in ipairs(slot:GetDescendants()) do
        if (d:IsA("TextLabel") or d:IsA("TextButton")) and visible(d,slot) then
            local s=tostring(d.Text or ""):gsub("^%s+",""):gsub("%s+$","")
            if s~="" and not s:match("^[xX]%s*%d+$") then
                return s
            end
        end
    end

    return nil
end

local function slotInternalId(slot)
    if not slot then return nil end

    for _,attr in ipairs({"ItemId","ItemID","ID","WeaponId","WeaponID"}) do
        local ok,v=pcall(function() return slot:GetAttribute(attr) end)
        if ok and v~=nil and tostring(v)~="" then
            return tostring(v)
        end
    end

    for _,name in ipairs({"ItemId","ItemID","ID","WeaponId","WeaponID"}) do
        local v=slot:FindFirstChild(name,true)
        if v and (
            v:IsA("StringValue")
            or v:IsA("IntValue")
            or v:IsA("NumberValue")
        ) then
            return tostring(v.Value)
        end
    end

    return nil
end

local function slotIsChroma(slot)
    local tags=slot and slot:FindFirstChild("Tags")
    local c=tags and tags:FindFirstChild("Chroma")
    return c and visible(c,slot) or false
end

local function slotQty(slot)
    local box=slot and slot:FindFirstChild("Container")
    local amount=box and box:FindFirstChild("Amount")

    if amount and (amount:IsA("TextLabel") or amount:IsA("TextButton")) then
        return MARKET_LOGIC.quantity(amount.Text)
    end

    return 1
end

local function readSide(t,sideName)
    local side=t and t:FindFirstChild(sideName)
    local container=side and side:FindFirstChild("Container")
    local out={slots=0,entries={}}

    if not container then return out end

    for i=1,4 do
        local slot=container:FindFirstChild("NewItem"..i)
        if slot and slot.Visible then
            local shown=slotName(slot)
            do
                out.slots+=1
                out.entries[#out.entries+1]={
                    index=i,
                    node=slot,
                    shown=shown or "",
                    isChroma=slotIsChroma(slot),
                    internalId=slotInternalId(slot),
                    qty=slotQty(slot),
                }
            end
        end
    end

    return out
end

local function fullShownName(entry)
    local s=tostring(entry and entry.shown or "")
    if entry and entry.isChroma
        and not s:lower():match("^%s*chroma%s+")
    then
        return "Chroma "..s
    end
    return s
end

-- Physical evidence fence includes layout, raw ID/chroma and uncoerced amount text.
-- It does not price unknown slots or grant any economic addition.
local function rawSideSignature(t,sideName)
    local side=t and t:FindFirstChild(sideName)
    local container=side and side:FindFirstChild("Container")
    if not side or not container then return nil,"offer-layout-unavailable" end
    local parts={sideName}
    local function add(v) v=tostring(v);parts[#parts+1]=tostring(#v)..":"..v end
    for i=1,4 do
        local slot=container:FindFirstChild("NewItem"..i)
        if slot and slot.Visible then
            local box=slot:FindFirstChild("Container")
            local amount=box and box:FindFirstChild("Amount")
            add(i);add(slotInternalId(slot));add(slotName(slot) or "")
            if not amount or not (amount:IsA("TextLabel") or amount:IsA("TextButton")) then
                return nil,"offer-quantity-unavailable"
            end
            local parsed=slotQty(slot)
            add(slotIsChroma(slot))
            -- Verified quantity spelling (x1 vs 1) is not a new offered item.
            -- Preserve the literal text only when parsing cannot establish quantity.
            add(parsed and ("quantity:"..tostring(parsed)) or ("invalid:"..tostring(amount and amount.Text or "<missing>")))
        end
    end
    return table.concat(parts,"|"),nil
end

local AcceptedFallback={
    at=0,
    value=false,
    via="none",
}

local function theirAcceptedShown(t)
    if not t then return false,"no-trade" end

    -- MM2's own TradeModule writes this exact node:
    -- TradeGUI.Container.Trade.TheirOffer.Accepted.Visible.
    -- Use it first so normal polling is O(1), not a descendant-tree sweep.
    local side=t:FindFirstChild("TheirOffer")
    local direct=side and side:FindFirstChild("Accepted")

    if direct then
        local shown=visible(direct,t)
        return shown,shown and direct:GetFullName() or "direct-not-visible"
    end

    -- Compatibility fallback only if the expected MM2 node is missing.
    -- Throttle the expensive descendant scan so a changed layout cannot turn
    -- the 0.12s trade loop into repeated full-tree walks.
    local now=os.clock()
    if now-AcceptedFallback.at<0.25 then
        return AcceptedFallback.value,AcceptedFallback.via
    end

    AcceptedFallback.at=now
    AcceptedFallback.value=false
    AcceptedFallback.via="none"

    for _,d in ipairs(t:GetDescendants()) do
        if (d:IsA("TextLabel") or d:IsA("TextButton"))
            and visible(d,t)
        then
            local raw=tostring(d.Text or "")
            local q=raw:upper():gsub("%s+"," ")
                :gsub("^%s+",""):gsub("%s+$","")

            if q:find("OTHER PLAYER HAS ACCEPTED",1,true) then
                AcceptedFallback.value=true
                AcceptedFallback.via=d:GetFullName()
                break
            end
        end
    end

    return AcceptedFallback.value,AcceptedFallback.via
end

local function ourAcceptedShown(t)
    local side=t and t:FindFirstChild("YourOffer")
    local indicator=side and side:FindFirstChild("Accepted")
    if not indicator then return nil end
    return visible(indicator,t)
end

local function marketBundleAssessment(items,side)
    if not MARKET_LOGIC
        or type(MARKET_LOGIC.bundleAssessment)~="function"
        or not MARKET_PROFILE
    then
        return nil,"market-bundle-unavailable"
    end

    local ok,res=pcall(
        MARKET_LOGIC.bundleAssessment,
        items,
        side,
        MARKET_PROFILE
    )

    if not ok or type(res)~="table" then
        return nil,"market-bundle-assessment-failed"
    end

    return res,nil
end

local function resolveEntry(entry,inv)
    if not entry or not inv or type(inv.items)~="table" then return nil,"inventory-unavailable" end
    local qty=tonumber(entry.qty)
    if not qty or qty<1 or qty~=math.floor(qty) or qty==math.huge then return nil,"invalid-live-quantity" end
    local liveId=tostring(entry.internalId or "")
    local liveName=norm(fullShownName(entry))
    if liveName=="" then return nil,"missing-visible-identity" end
    local hits={}
    for _,it in ipairs(inv.items) do
        local idOK=liveId=="" or liveId==tostring(it.id or "")
        if idOK and liveName==norm(it.name) then hits[#hits+1]=it end
    end
    if #hits~=1 then return nil,#hits==0 and "unresolved" or "ambiguous" end
    local it=hits[1]
    local value=tonumber(it.value)
    if not value or value~=value or value<=0 or value==math.huge then return nil,"unpriced" end
    if not tonumber(it.qty) or qty>it.qty then return nil,"quantity-exceeds-inventory" end
    return {id=it.id,checkerId=it.checkerId,name=it.name,value=value,page=it.page,cat=it.cat,type=it.type,qty=qty,ineligible=false},"resolved"
end

local function evaluateSide(t,sideName,inv)
    local side=readSide(t,sideName)

    local out={
        slots=side.slots,
        rawTotal=0,
        protectedTotal=0,
        eligibleCopies=0,
        resolved={},
        unresolved={},
        counts={},
        market=nil,
        marketError=nil,
    }

    local marketItems={}

    for _,entry in ipairs(side.entries) do
        local item,why=resolveEntry(entry,inv)

        if item then
            local qty=math.max(1,tonumber(item.qty) or 1)
            local raw=(tonumber(item.value) or 0)*qty

            out.rawTotal+=raw

            if not item.ineligible then
                out.eligibleCopies+=qty
                marketItems[#marketItems+1]={
                    page=tostring(item.page or ""),
                    id=tostring(item.id or ""),
                    checkerId=tostring(item.checkerId or item.id or ""),
                    cat=item.cat,type=item.type,
                    name=tostring(item.name or item.id or ""),
                    value=tonumber(item.value) or 0,
                    qty=qty,
                }
            end

            local id=tostring(item.id or fullShownName(entry))
            local countKey=tostring(item.page or "")..":"..id
            out.counts[countKey]=(out.counts[countKey] or 0)+qty
            for _,owned in ipairs((inv and inv.items) or {}) do
                if tostring(owned.page)..":"..tostring(owned.id)==countKey
                    and out.counts[countKey]>(tonumber(owned.qty) or 0) then
                    out.unresolved[#out.unresolved+1]={name=item.name,qty=qty,reason="aggregate-quantity-exceeds-inventory"}
                end
            end

            out.resolved[#out.resolved+1]={
                id=id,
                checkerId=item.checkerId,
                page=item.page,
                name=item.name,
                rawValue=tonumber(item.value) or 0,
                qty=qty,
                rawSubtotal=raw,
                ineligible=item.ineligible,
                proof=why,
            }
        else
            out.unresolved[#out.unresolved+1]={
                name=fullShownName(entry),
                qty=math.max(1,tonumber(entry.qty) or 1),
                reason=why,
            }
        end
    end

    local marketSide=sideName=="YourOffer" and "ours" or "theirs"
    local market,marketWhy=marketBundleAssessment(
        marketItems,
        marketSide
    )

    if market then
        out.market=market
        out.protectedTotal=tonumber(market.protectedTotal) or out.rawTotal
    else
        out.marketError=marketWhy
        out.protectedTotal=out.rawTotal
    end

    local sig={}
    for _,r in ipairs(out.resolved) do
        sig[#sig+1]=table.concat({
            tostring(r.page or ""),
            tostring(r.id),
            tostring(r.qty),
            tostring(r.rawValue),
            r.ineligible and "0" or "1",
        },":")
    end
    for _,u in ipairs(out.unresolved) do
        sig[#sig+1]="?"..norm(u.name)..":"..tostring(u.qty)
    end
    table.sort(sig)
    out.signature=table.concat(sig,"|").."#slots="..tostring(out.slots)

    return out
end

local function yourOfferContains(t,wanted)
    local side=readSide(t,"YourOffer")
    if side.slots~=1 or #side.entries~=1 then return false,"opening-slot-count" end
    local item,why=resolveEntry(side.entries[1],{items={wanted}})
    return item~=nil and item.qty==1,why
end

local function actionContext(requirePrices)
    local bound=BOUND
    if not bound or bound.invalid or not bound.alive() then return false,"stale-session" end
    if requirePrices~=false and (not MARKET_PROFILE or not MARKET_PROFILE.isFresh()) then return false,"supreme-profile-stale" end
    if requirePrices~=false and AUTOMATION_READY then
        local ok,ready=pcall(AUTOMATION_READY)
        if not ok or ready~=true then return false,"automation-not-ready" end
    end
    if requirePrices~=false and bound.deadline and os.clock()>=bound.deadline then return false,"overall-timeout" end
    local t=tradeRoot()
    if not t then return false,"trade-closed" end
    if MARKET_PROFILE.version~=bound.profileVersion then return false,"price-version-changed" end
    if not bound.target.Parent or t~=bound.root or PG~=bound.gui or findPartner(t)~=bound.target
        or Players:GetPlayerByUserId(bound.target.UserId)~=bound.target then return false,"trade-context-changed" end
    return true,nil,t
end

local function physicalClick(button,label)
    if not button or not visible(button) or not actionContext(label~="Decline trade") then return false end

    local ok=pcall(function()
        local p=button.AbsolutePosition
        local s=button.AbsoluteSize
        local inset=GuiService:GetGuiInset()
        local x=p.X+s.X/2+inset.X
        local y=p.Y+s.Y/2+inset.Y

        VIM:SendMouseButtonEvent(x,y,0,true,game,0)
        task.wait(0.05)
        VIM:SendMouseButtonEvent(x,y,0,false,game,0)
    end)

    if not ok then
        warn("[PDIDDLER P4] CLICK FAILED",tostring(label or "button"))
    end

    return ok
end

local function removeOne(t)
    local side=t and t:FindFirstChild("YourOffer")
    local container=side and side:FindFirstChild("Container")
    if not container then return false end

    for i=4,1,-1 do
        local slot=container:FindFirstChild("NewItem"..i)
        local box=slot and slot.Visible and slot:FindFirstChild("Container")
        local button=box and box:FindFirstChild("ActionButton")
        if button then
            return physicalClick(button,"remove offered item")
        end
    end

    return false
end

local function declineTrade(reason)
    local valid,why,before=actionContext(false)
    if not valid then return why=="trade-closed",why end
    print("[PDIDDLER P4] DECLINE",tostring(reason or ""))
    local folder=RS:FindFirstChild("Trade")
    local remote=folder and folder:FindFirstChild("DeclineTrade")
    -- Choose one action path. A delayed acknowledgement is not permission to send twice.
    local sent=false
    if remote and remote:IsA("RemoteEvent") then
        sent=pcall(function() remote:FireServer() end)
    else
        local actions=before:FindFirstChild("Actions")
        local decline=actions and actions:FindFirstChild("Decline")
        sent=physicalClick(decline and decline:FindFirstChild("ActionButton"),"Decline trade")
    end
    if not sent then return false,"decline-action-failed" end
    local deadline=os.clock()+2.5
    while os.clock()<deadline do
        local current=tradeRoot()
        if not current then return true,"closed-after-decline" end
        if current~=before or not actionContext(false) then return false,"decline-context-changed" end
        task.wait(0.08)
    end
    return false,"decline-acknowledgement-uncertain"
end

local function tradeDecision(ourEval,theirEval)
    local ourRaw=tonumber(ourEval and ourEval.rawTotal) or 0
    local theirRaw=tonumber(theirEval and theirEval.rawTotal) or 0

    if not ourEval or #(ourEval.unresolved or {})>0
        or not theirEval or #(theirEval.unresolved or {})>0
        or type(ourEval.market)~="table"
        or type(theirEval.market)~="table"
        or not MARKET_LOGIC
        or type(MARKET_LOGIC.tradeDecision)~="function"
    then
        return {
            ok=false,
            kind="UNKNOWN",
            mode="reject",
            reason="market-assessment-unavailable",
            rawProfit=theirRaw-ourRaw,
            protectedProfit=0,
            requiredProfit=math.huge,
            qualityGain=0,
        }
    end

    local ok,res=pcall(
        MARKET_LOGIC.tradeDecision,
        ourEval.market,
        theirEval.market
    )

    if not ok or type(res)~="table" then
        return {
            ok=false,
            kind="UNKNOWN",
            mode="reject",
            reason="market-decision-failed",
            rawProfit=theirRaw-ourRaw,
            protectedProfit=0,
            requiredProfit=math.huge,
            qualityGain=0,
        }
    end

    return res
end

local function marketPlans(inv,theirEval)
    if not theirEval or type(theirEval.market)~="table" then
        return {},"their-market-unavailable"
    end

    if not MARKET_PLANNER
        or type(MARKET_PLANNER.buildPlans)~="function"
    then
        return {},"market-planner-unavailable"
    end

    local ok,plans,why=pcall(
        MARKET_PLANNER.buildPlans,
        inv,
        theirEval.market,
        MARKET_PROFILE,
        MARKET_LOGIC
    )

    if not ok or type(plans)~="table" then
        return {},"market-planner-failed"
    end

    return plans,why
end

local function planMatches(plan,live)
    if not MARKET_PLANNER
        or type(MARKET_PLANNER.planMatches)~="function"
    then
        return false
    end

    local ok,result=pcall(
        MARKET_PLANNER.planMatches,
        plan,
        live
    )

    return ok and result==true
end

local function txValidate(scanner,target,tx,sessionAlive)
    if not sessionAlive() then
        return false,"stale-session"
    end

    if not tx or tx.cancelled then
        return false,"stale-transaction"
    end

    local valid,contextWhy,t=actionContext()
    if not valid then return false,contextWhy end
    if BOUND.target~=target then return false,"trade-context-changed" end
    if BOUND.safetyInspect then
        local safety=BOUND.safetyInspect("mutation",tx,false)
        if safety=="stopped" then return false,"emergency-safety-stop",t end
        if safety=="unknown" then tx.cancelled=true;return false,"their-offer-unresolved",t end
    end
    if tx.expectedTheirRawSig and rawSideSignature(t,"TheirOffer")~=tx.expectedTheirRawSig then
        tx.cancelled=true;return false,"their-offer-changed",t
    end
    if theirAcceptedShown(t) then return false,"partner-accepted" end
    if ourAcceptedShown(t)~=false then return false,"local-accepted-or-unknown" end

    local rec=scanner.getRecord(target.UserId)
    local theirEval=evaluateSide(
        t,
        "TheirOffer",
        rec and rec.inv
    )

    if theirEval.signature~=tx.expectedTheirSig then
        tx.cancelled=true
        return false,"their-offer-changed",t,theirEval
    end

    return true,nil,t,theirEval
end

local function waitForOurOfferMutation(
    scanner,
    target,
    ownInv,
    tx,
    sessionAlive,
    beforeSig,
    beforeRaw,
    timeout
)
    local deadline=os.clock()+(tonumber(timeout) or C.RemoveVerifyTimeout)
    if tx.urgent and tx.deadline then deadline=math.min(deadline,tx.deadline) end

    while os.clock()<deadline do
        local valid,why,t=txValidate(
            scanner,
            target,
            tx,
            sessionAlive
        )

        if not valid then
            return false,why,nil
        end

        local ours=evaluateSide(t,"YourOffer",ownInv)

        if #ours.unresolved==0
            and ours.signature~=beforeSig
            and ours.rawTotal<(tonumber(beforeRaw) or 0)-0.0001
        then
            return true,"mutated",ours
        end

        task.wait(tx.urgent and math.min(0.06,math.max(0,deadline-os.clock())) or 0.06)
    end

    return false,"mutation-timeout",nil
end

local function clearOurOffer(scanner,target,ownInv,tx,sessionAlive)
    local modified=false

    for _=1,8 do
        local valid,why,t=txValidate(
            scanner,
            target,
            tx,
            sessionAlive
        )

        if not valid then
            return false,why,modified
        end

        local ours=evaluateSide(t,"YourOffer",ownInv)

        if #ours.unresolved>0 then
            return false,"our-offer-unresolved",modified
        end

        if ours.slots==0 then
            return true,"cleared",modified
        end

        local beforeSig=ours.signature
        local beforeRaw=ours.rawTotal

        if not removeOne(t) then
            return false,"remove-click-failed",modified
        end

        -- A successful physical click may mutate the server/UI slightly later.
        -- From this point onward treat our offer as potentially modified.
        modified=true

        local removed,removeWhy=waitForOurOfferMutation(
            scanner,
            target,
            ownInv,
            tx,
            sessionAlive,
            beforeSig,
            beforeRaw,
            tx.urgent and C.EmergencyClearVerifyTimeout or C.RemoveVerifyTimeout
        )

        if not removed and tx.urgent then return false,removeWhy,modified end
        if not removed then
            if removeWhy=="their-offer-changed"
                or removeWhy=="trade-closed"
                or removeWhy=="stale-session"
                or removeWhy=="stale-transaction"
            then
                return false,removeWhy,modified
            end

            -- Before retrying, inspect a FRESH trade/offer state. If the first
            -- click finally landed, accept that observable mutation instead of
            -- clicking Remove a second time.
            local valid2,why2,freshTrade=txValidate(
                scanner,
                target,
                tx,
                sessionAlive
            )

            if not valid2 then
                return false,why2,modified
            end

            local freshOurs=evaluateSide(
                freshTrade,
                "YourOffer",
                ownInv
            )

            if #freshOurs.unresolved>0 then
                return false,"our-offer-unresolved-after-remove",modified
            end

            if freshOurs.signature~=beforeSig
                and freshOurs.rawTotal<beforeRaw-0.0001
            then
                removed=true
            else
                -- Late-replication guard: the first physical tap may arrive
                -- just after its normal verify window. Observe before issuing a
                -- second Remove so one intended removal cannot become two.
                local guardDeadline=os.clock()+C.RemoveRetryGuard
                local guardOurs=freshOurs

                while os.clock()<guardDeadline do
                    local guardValid,guardWhy,guardTrade=txValidate(
                        scanner,
                        target,
                        tx,
                        sessionAlive
                    )

                    if not guardValid then
                        return false,guardWhy,modified
                    end

                    guardOurs=evaluateSide(
                        guardTrade,
                        "YourOffer",
                        ownInv
                    )

                    if #guardOurs.unresolved==0
                        and guardOurs.signature~=beforeSig
                        and guardOurs.rawTotal<beforeRaw-0.0001
                    then
                        removed=true
                        break
                    end

                    task.wait(0.05)
                end

                if not removed then
                    local retryValid,retryWhy0,retryTrade=txValidate(
                        scanner,
                        target,
                        tx,
                        sessionAlive
                    )

                    if not retryValid then
                        return false,retryWhy0,modified
                    end

                    local retryBefore=evaluateSide(
                        retryTrade,
                        "YourOffer",
                        ownInv
                    )

                    if #retryBefore.unresolved>0 then
                        return false,"our-offer-unresolved-before-retry",modified
                    end

                    if retryBefore.signature~=beforeSig
                        and retryBefore.rawTotal<beforeRaw-0.0001
                    then
                        removed=true
                    else
                        -- One bounded retry, using a newly reacquired ActionButton.
                        if not removeOne(retryTrade) then
                            return false,"remove-retry-click-failed",modified
                        end

                        local retried,retryWhy=waitForOurOfferMutation(
                            scanner,
                            target,
                            ownInv,
                            tx,
                            sessionAlive,
                            retryBefore.signature,
                            retryBefore.rawTotal,
                            C.RemoveRetryVerifyTimeout
                        )

                        if not retried then
                            return false,
                                retryWhy=="mutation-timeout"
                                    and "remove-verify-timeout"
                                    or retryWhy,
                                modified
                        end

                        removed=true
                    end
                end
            end
        end

        if not removed then
            return false,"remove-verify-timeout",modified
        end

        if not tx.urgent then task.wait(0.08) end
    end

    return false,"clear-limit",modified
end

-- Planner picks stay immutable: reservations and final verification still own
-- the original plan. Only this local execution list changes physical call order.
local function orderedExecutionPicks(plan)
    local picks=type(plan)=="table" and plan.picks
    if type(picks)~="table" or #picks==0 then return nil,"execution-picks-unverified" end
    local ordered={}
    for index,pick in ipairs(picks) do
        local value=type(pick)=="table" and pick.value
        local qty=type(pick)=="table" and pick.qty
        if type(value)~="number" or not (value>0 and value<math.huge)
            or type(qty)~="number" or not (qty>=1 and qty<math.huge and qty==math.floor(qty)) then
            return nil,"execution-contribution-unverified"
        end
        local contribution=value*qty
        if contribution>=math.huge then return nil,"execution-contribution-unverified" end
        ordered[#ordered+1]={pick=pick,index=index,contribution=contribution}
    end
    table.sort(ordered,function(a,b)
        if a.contribution~=b.contribution then return a.contribution>b.contribution end
        return a.index<b.index
    end)
    return ordered
end

local function applyPlan(scanner,target,ownInv,plan,tx,sessionAlive)
    local ordered,orderWhy=orderedExecutionPicks(plan)
    if not ordered then return false,orderWhy,false end
    local modified=false

    local ok,why,clearModified=clearOurOffer(
        scanner,
        target,
        ownInv,
        tx,
        sessionAlive
    )

    modified=clearModified==true

    if not ok then
        return false,why,modified
    end

    local tradeFolder=RS:FindFirstChild("Trade")
    local offer=tradeFolder and tradeFolder:FindFirstChild("OfferItem")
    if not offer or not offer:IsA("RemoteEvent") then
        return false,"offer-remote-missing",modified
    end

    for _,entry in ipairs(ordered) do
        local p=entry.pick
        for _=1,(tonumber(p.qty) or 1) do
            local valid,validWhy,t=txValidate(
                scanner,
                target,
                tx,
                sessionAlive
            )

            if not valid then
                return false,validWhy,modified
            end

            local ours=evaluateSide(t,"YourOffer",ownInv)
            if #ours.unresolved>0 then
                return false,"our-offer-unresolved",modified
            end

            if ours.slots>=4 then
                -- A duplicate may stack into an existing slot, so only block
                -- when this item does not already exist in our live offer.
                local offerKey=tostring(p.page or "")..":"..tostring(p.id or "")
                local alreadyThere=(ours.counts[offerKey] or 0)>0
                if not alreadyThere then
                    return false,"slot-limit",modified
                end
            end

            local fired=pcall(function()
                offer:FireServer(p.id,"Weapons")
            end)

            if not fired then
                return false,"offer-fire-error",modified
            end

            modified=true
            task.wait(0.15)
        end
    end

    local deadline=os.clock()+C.ApplyVerifyTimeout

    while os.clock()<deadline do
        local valid,validWhy,t=txValidate(
            scanner,
            target,
            tx,
            sessionAlive
        )

        if not valid then
            return false,validWhy,modified
        end

        local ours=evaluateSide(t,"YourOffer",ownInv)

        if planMatches(plan,ours) then
            return true,ours,modified
        end

        task.wait(0.08)
    end

    return false,"plan-verify-timeout",modified
end

local function fmt(v)
    v=tonumber(v) or 0
    if math.floor(v)==v then return tostring(math.floor(v)) end
    return string.format("%.2f",v)
end

local function runTrade(scanner,session,sessionAlive,tradeTelemetry,publishWebhookCandidate,clearWebhookCandidate,holdOutcome)
    local function p4Status(text)
        return scanner.setStatus(tostring(text or ""),"P4")
    end

    local t=tradeRoot()
    local openedAt=os.clock()
    if not t then return "trade-missing" end

    local target=findPartner(t)
    if not target then
        p4Status(
            "P4 SAFETY — trade partner could not be verified | no item offered"
        )
        return "partner-unverified"
    end

    TRADE_SERIAL=TRADE_SERIAL+1
    local tradeId=table.concat({
        "p4w",tostring(game.JobId),tostring(LP.UserId),tostring(TRADE_SERIAL),
        tostring(session),
        tostring(target.UserId),
        tostring(math.floor(os.clock()*1000)),
    },":")

    local lifecycle=tradeTelemetry.lifecycle
    local lastWebhookCandidate=nil

    local function invalidateWebhook(reason)
        lastWebhookCandidate=nil
        if type(clearWebhookCandidate)=="function" then
            clearWebhookCandidate(tostring(reason or "invalidated"))
        end
    end

    local function verifyWebhookCandidate(ourEval,theirEval,decision,source)
        if decision and decision.ok then
            BOUND.quoteInvalidated=false
            BOUND.safeQuoteSeen=true
        end
        local ok,snap=pcall(tradeTelemetry.build,{
            tradeId=tradeId,
            traderName=target.Name,
            traderUserId=target.UserId,
            ourEval=ourEval,
            theirEval=theirEval,
            decision=decision,
            marketProfile=MARKET_PROFILE,
            marketLogic=MARKET_LOGIC,
            capturedAt=os.clock(),
        })

        if not ok or type(snap)~="table" then
            invalidateWebhook("telemetry-build-failed")
            return false
        end

        snap.verified=true
        snap.source=tostring(source or "verified")
        snap.tradeOpen=true
        snap.part4Session=session

        lastWebhookCandidate=snap

        if type(publishWebhookCandidate)=="function" then
            publishWebhookCandidate(snap)
        end

        return true
    end

    local function refreshWebhookCandidate(ourEval,theirEval)
        local snap=lastWebhookCandidate
        if not snap then return end

        if not ourEval
            or not theirEval
            or tostring(ourEval.signature or "")~=tostring(snap.ourSignature or "")
            or tostring(theirEval.signature or "")~=tostring(snap.theirSignature or "")
        then
            invalidateWebhook("offer-signature-changed")
            return
        end

        local refreshed={}
        for k,v in pairs(snap) do refreshed[k]=v end
        refreshed.capturedAt=os.clock()
        refreshed.tradeOpen=true
        lastWebhookCandidate=refreshed

        if type(publishWebhookCandidate)=="function" then
            publishWebhookCandidate(refreshed)
        end
    end

    invalidateWebhook("trade-start")

    local function finishTradeClosed(reason)
        if lifecycle then lifecycle:close(tradeId,reason) end
        if BOUND and BOUND.acceptanceObserved then
            if lifecycle and lifecycle.state.phase=="reconciling" then return "completion-pending" end
            if lifecycle and lifecycle.state.phase=="completed" and lifecycle.state.lastReport
                and lifecycle.state.lastReport.id==tradeId then return "completed-verified" end
            invalidateWebhook("accepted-close-unconfirmed")
            holdOutcome("accepted trade closed before raw inventory reconciliation; "..tostring(reason))
            return "completion-unconfirmed"
        end
        invalidateWebhook("trade-closed")
        scanner.setRequestState(
            target,
            "processed",
            "P4 — trade closed/cancelled | returning to Part 3 rotation"
        )
        p4Status(
            "P4 — trade closed/cancelled | returning to Part 3 rotation"
        )
        return tostring(reason or "trade-closed")
    end
    local function finishExpired()
        invalidateWebhook("supreme-profile-stale")
        local declined,why=declineTrade("Supreme snapshot expired")
        if declined then return finishTradeClosed("supreme-snapshot-expired-declined") end
        return "supreme-snapshot-expired:"..tostring(why)
    end

    local function finishInitialContextFailure(why)
        if why=="supreme-profile-stale" then return finishExpired() end
        if why=="automation-not-ready" then
            invalidateWebhook(why)
            local declined=declineTrade("loading readiness lost before initial offer")
            if declined then return finishTradeClosed("readiness-lost-declined") end
            holdOutcome("readiness lost; bound initial trade could not be safely closed")
            return "readiness-unconfirmed"
        end
        return why
    end

    local rec=scanner.getRecord(target.UserId)
    if not rec or rec.state~="whitelist" or not rec.inv then
        p4Status(
            "P4 SAFETY — partner inventory is not a verified whitelist snapshot | no item offered"
        )
        -- Continue bounded observation without guessing partner capacity.
    end

    BOUND={root=t,gui=PG,target=target,alive=sessionAlive,connections={},profileVersion=MARKET_PROFILE.version}
    local bound=BOUND
    bound.tradeId=tradeId
    -- A GUI instance can be reused. Fence its entire visible lifetime, including
    -- a close/reopen with the same player while inventory retrieval is yielding.
    local function watch(signal,fn)
        if signal then bound.connections[#bound.connections+1]=signal:Connect(fn) end
    end
    local ancestor=t
    while ancestor and ancestor~=PG do
        local current=ancestor
        if current:IsA("GuiObject") or current:IsA("ScreenGui") then
            local property=current:IsA("ScreenGui") and "Enabled" or "Visible"
            watch(current:GetPropertyChangedSignal(property),function()
                if not visible(t,bound.gui) then bound.invalid=true;bound.closed=true end
            end)
        end
        watch(current.AncestryChanged,function() bound.invalid=true end)
        ancestor=current.Parent
    end
    local theirSide=t:FindFirstChild("TheirOffer")
    local username=theirSide and theirSide:FindFirstChild("Username")
    if username then watch(username:GetPropertyChangedSignal("Text"),function() bound.invalid=true end) end
    local localSide=t:FindFirstChild("YourOffer")
    local localIndicator=localSide and localSide:FindFirstChild("Accepted")
    if localIndicator then
        watch(localIndicator:GetPropertyChangedSignal("Visible"),function()
            if ourAcceptedShown(t)==true then
                bound.acceptanceObserved=true
                if lifecycle then lifecycle:accepted(tradeId) end
            end
        end)
    end
    if lifecycle then
        local owned,why=lifecycle:begin({id=tradeId,job=game.JobId,epoch=session,partner=target.UserId,
            root=t,gui=PG,version=MARKET_PROFILE.version,isCurrent=function() return actionContext(false) end})
        if not owned then
            if why=="transaction-context-changed-during-inventory" and not bound.acceptanceObserved then return "stale-session" end
            holdOutcome("transaction ownership unavailable: "..tostring(why));return "transaction-owned"
        end
        local valid=actionContext(false)
        if not valid then lifecycle:close(tradeId,"lifetime-changed-during-before-read");return "stale-session" end
    end
    local oursBefore=readSide(t,"YourOffer")
    if oursBefore.slots>0 then
        p4Status(
            "P4 SAFETY — YOUR OFFER was unexpectedly non-empty at handoff | declining"
        )
        scanner.setRequestState(
            target,
            "sendfailed",
            "P4 safety decline | unexpected pre-existing item in YOUR OFFER"
        )
        declineTrade("unexpected pre-existing our offer")
        return "our-offer-not-empty"
    end

    local timing={}
    MARKET_LOGIC.observe(timing,openedAt,readSide(t,"TheirOffer").slots,theirAcceptedShown(t))
    if timing.started then BOUND.deadline=timing.started+C.ActiveOfferWindow end
    local ownInv,ownWhy=scanner.getOwnInventory()
    local contextOK,contextWhy,current=actionContext()
    if not contextOK then return finishInitialContextFailure(contextWhy) end
    if readSide(current,"YourOffer").slots~=0 then return "our-offer-changed-during-inventory" end
    if not ownInv then
        p4Status(
            "P4 SAFETY — could not refresh own inventory: "..tostring(ownWhy)
        )
        ownInv={items={},unmapped=1,unpriced=0,badQty=0}
    end

    if (tonumber(ownInv.unmapped) or 0)>0
        or (tonumber(ownInv.unpriced) or 0)>0
        or (tonumber(ownInv.badQty) or 0)>0
    then
        p4Status(
            string.format(
                "P4 SAFETY — own inventory incomplete | unmapped=%d unpriced=%d badQty=%d | no offer",
                tonumber(ownInv.unmapped) or 0,
                tonumber(ownInv.unpriced) or 0,
                tonumber(ownInv.badQty) or 0
            )
        )
        -- Keep observing bounded deadlines; an unavailable opener is not an
        -- excuse to leave an empty trade open indefinitely.
    end

    local function observationStep()
        local valid,why,now=actionContext(false)
        if not valid then return nil,why end
        if not MARKET_PROFILE.isFresh() then return nil,finishExpired() end
        local side=readSide(now,"TheirOffer")
        local outcome=MARKET_LOGIC.observe(timing,os.clock(),side.slots,theirAcceptedShown(now))
        if timing.started then BOUND.deadline=timing.started+C.ActiveOfferWindow end
        if outcome=="accepted-empty" or outcome=="empty-timeout" or outcome=="overall-timeout" then
            local declined,reason=declineTrade(outcome)
            return nil,declined and finishTradeClosed(outcome.."-declined") or outcome..":"..tostring(reason)
        end
        return now,nil,side
    end
    p4Status("P4 OBSERVE — 2.5s opponent-first | Supreme +15 | MANUAL ACCEPT")
    while os.clock()-openedAt<2.5 do
        local now,why,side=observationStep()
        if not now then return why end
        if side.slots>0 then break end
        -- The record may change during observation; capacity is never cached.
        scanner.getRecord(target.UserId)
        task.wait(0.08)
    end
    local openingTrade,openingWhy,openingSide=observationStep()
    if not openingTrade then return openingWhy end
    if openingSide.slots==0 and ourAcceptedShown(openingTrade)==false then
        local partnerRec=scanner.getRecord(target.UserId)
        local opener,why=MARKET_LOGIC.selectOpener(ownInv,
            partnerRec and partnerRec.state=="whitelist" and partnerRec.inv or nil,MARKET_PROFILE)
        if opener then
            scanner.setRequestState(target,"accepted","P4 OPENING — reachable "..tostring(opener.name).." | MANUAL ACCEPT")
            local valid,contextWhy,current=actionContext()
            if not valid then return finishInitialContextFailure(contextWhy) end
            -- No yield between this final read and OfferItem. A changed side
            -- skips the speculative opener and enters the normal planner.
            if readSide(current,"TheirOffer").slots==0 and readSide(current,"YourOffer").slots==0
                and not theirAcceptedShown(current) and ourAcceptedShown(current)==false then
                local folder=RS:FindFirstChild("Trade")
                local offer=folder and folder:FindFirstChild("OfferItem")
                if not offer or not offer:IsA("RemoteEvent") then return "offer-remote-missing" end
                local fired=pcall(function() offer:FireServer(opener.id,"Weapons") end)
                if not fired then return "opening-offer-fire-failed" end
                local deadline=os.clock()+C.OfferVerifyTimeout
                local verified=false
                while os.clock()<deadline do
                    local now,reason=observationStep()
                    if not now then return reason end
                    if yourOfferContains(now,opener) then
                        verified=true;BOUND.verifiedOurSig=evaluateSide(now,"YourOffer",ownInv).signature;break
                    end
                    task.wait(0.08)
                end
                if not verified then
                    local declined,reason=declineTrade("opening-offer-unverified")
                    return declined and finishTradeClosed("opening-offer-unverified-declined") or tostring(reason)
                end
                p4Status("P4 OPENING VERIFIED — "..tostring(opener.name).." | Supreme | MANUAL ACCEPT")
            end
        else
            p4Status("P4 OPENER HOLD — "..tostring(why).." | bounded empty timeout")
        end
    else
        p4Status("P4 OPPONENT FIRST — speculative opener skipped | verifying offer")
    end

    local negotiation={}
    local manualPendingSince=nil
    local earlyCounterState={} -- root-scoped: one decision per stable their-offer generation
    -- Last opponent value that was verified alongside our committed quote.
    -- Never reward swaps, removals, or the same value twice.
    local additionAnchor=nil
    local nativeReady={}; -- fresh trade root owns readiness timers
    local cachedPlanSig,cachedPlans,cachedPlanWhy
    local offerEverStarted=false
    local lastTheirSig=nil
    local stableSince=nil

    -- Rebalance transaction / recovery state.
    local offerGeneration=0
    local rebalanceSerial=0
    local recoveryNeeded=false
    local recoveryFailures=0
    local recoveryRetryAt=0
    local recoveryHoldSig=nil
    local failedMutationSig=nil
    local safetyRestoreReference=nil -- withdrawn economic ceiling, never a fresh zero anchor

    local function invalidateQuoteEvidence(reason)
        bound.quoteInvalidated=true
        if not bound.acceptanceObserved then bound.approvedSig=nil end
        nativeReady={}
        if lifecycle and lifecycle.state.active and lifecycle.state.active.id==tradeId then
            lifecycle.state.active.readyKey=nil
            lifecycle.state.active.readySince=nil
        end
        invalidateWebhook(reason)
    end
    local function requestSafetyDecline(reason)
        if bound.safetyStop then return "stopped" end
        MARKET_LOGIC.cancelConcession(negotiation)
        invalidateQuoteEvidence(reason)
        -- Keep bound root/session intact: Decline must remain authorized.
        bound.safetyStop={reason=reason,at=os.clock()}
        print("[PDIDDLER P4] SAFETY STOP",tradeId,target.Name,tostring(reason))
        local closed,why=declineTrade(reason)
        bound.safetyStop.closed=closed;bound.safetyStop.result=why
        return "stopped"
    end
    local function finishSafetyStop()
        if not bound.safetyStop then return nil end
        if bound.safetyStop.closed then return finishTradeClosed("emergency-safety-declined") end
        holdOutcome("emergency decline could not be confirmed: "..tostring(bound.safetyStop.result))
        return "emergency-safety-unconfirmed"
    end
    bound.safetyInspect=function(stage,tx,allowClear)
        if bound.safetyStop then return "stopped" end
        local valid,_,current=actionContext(false)
        if not valid then return "unknown" end
        -- This inspection precedes the normal poll. Preserve native acceptance
        -- history even when an invalid layout, identity, or expiry exits early.
        if ourAcceptedShown(current)==true and not bound.acceptanceObserved then
            bound.acceptanceObserved=true
            if lifecycle then lifecycle:accepted(tradeId) end
        end
        local theirRaw=rawSideSignature(current,"TheirOffer")
        local ourRaw=rawSideSignature(current,"YourOffer")
        local raw=ourRaw and theirRaw and (ourRaw.."/"..theirRaw) or nil
        if not raw or raw~=bound.safetyRawSig then
            invalidateQuoteEvidence("physical-quote-changed")
            if bound.safetyRawSig and bound.acceptanceObserved then
                return requestSafetyDecline("physical quote changed after local acceptance")
            end
            bound.safetyRawSig=raw
        end
        if not ourRaw or not theirRaw then return requestSafetyDecline("offer-layout-unavailable") end
        if not MARKET_PROFILE.isFresh() then return "expired" end
        local record=scanner.getRecord(target.UserId)
        local partner=record and record.state=="whitelist" and record.inv
        local ours=evaluateSide(current,"YourOffer",ownInv)
        local theirs=evaluateSide(current,"TheirOffer",partner)
        if #ours.unresolved>0 then return requestSafetyDecline("current own quote unresolved") end
        if not partner or #theirs.unresolved>0 then
            local localAccepted=ourAcceptedShown(current)
            if ours.slots>0 and localAccepted~=false then
                if localAccepted==true then
                    bound.acceptanceObserved=true
                    if lifecycle then lifecycle:accepted(tradeId) end
                end
                return requestSafetyDecline("unverified opponent quote with local acceptance active or unknown")
            end
            return "unknown"
        end
        if ours.slots==0 then return "empty" end
        if theirs.slots==0 and not bound.safeQuoteSeen then return "initial-empty" end
        local decision=tradeDecision(ours,theirs)
        if decision.ok then bound.safeQuoteSeen=true;return "safe" end
        invalidateQuoteEvidence("unsafe-current-physical-quote")
        local localAccepted=ourAcceptedShown(current)
        if localAccepted==true then
            bound.acceptanceObserved=true
            if lifecycle then lifecycle:accepted(tradeId) end
        end
        -- Only this exact one-copy withdrawal may pass while its old quote is unsafe.
        if tx and tx.urgent and bound.safetyClearing and localAccepted==false
            and not theirAcceptedShown(current) and theirRaw==tx.expectedTheirRawSig
            and os.clock()<bound.safetyClearing.deadline then return "clearing" end
        if not allowClear or localAccepted~=false or theirAcceptedShown(current)
            or ours.slots~=1 or ours.eligibleCopies~=1 then
            return requestSafetyDecline("unsafe physical quote; immediate protected decline")
        end
        MARKET_LOGIC.cancelConcession(negotiation)
        rebalanceSerial+=1
        local emergency={id=rebalanceSerial,generation=offerGeneration,expectedTheirSig=theirs.signature,
            expectedTheirRawSig=theirRaw,cancelled=false,purpose="safety-clear",urgent=true,
            deadline=os.clock()+C.EmergencyClearVerifyTimeout}
        bound.safetyClearing={deadline=emergency.deadline}
        print("[PDIDDLER P4] SAFETY WITHDRAW",tradeId,target.Name,"our",ours.rawTotal,"their",theirs.rawTotal,
            "protected profit",decision.protectedProfit,"reason",decision.reason)
        p4Status("P4 SAFETY — unsafe physical quote | withdrawing one verified copy immediately")
        local cleared,why=clearOurOffer(scanner,target,ownInv,emergency,sessionAlive)
        bound.safetyClearing=nil
        if bound.safetyStop then return "stopped" end
        if not cleared then return requestSafetyDecline("emergency withdrawal unverified: "..tostring(why)) end
        -- Withdrawal removes exposure, never the economic baseline. A speculative
        -- opener also retains its ceiling until a real quote commits. Only an exact
        -- previously committed evaluation may authorize an above-baseline reward.
        local committedTotal=negotiation.ledger and negotiation.ledger.lastVerifiedTotal
        safetyRestoreReference={ours=ours,theirSignature=theirs.signature,theirRaw=theirRaw,
            base=committedTotal or ours.rawTotal,
            committed=committedTotal~=nil and committedTotal==ours.rawTotal}
        recoveryNeeded=false;failedMutationSig=nil;cachedPlanSig=nil
        lastTheirSig=nil;stableSince=nil
        return "cleared"
    end

    -- Human negotiation state is deliberately separate from technical
    -- OfferStability. A resolved offer can be parse-stable while the other
    -- player is still editing their bundle.


    while sessionAlive() do
        local now=tradeRoot()
        if not now then
            scanner.setRequestState(
                target,
                "processed",
                "P4 — trade closed/cancelled before our timeout | returning to Part 3 rotation"
            )
            return finishTradeClosed("trade-closed")
        end

        local valid,contextWhy=actionContext(false)
        if not valid then invalidateWebhook(contextWhy); return contextWhy end
        local safety=bound.safetyInspect("observe",nil,true)
        if safety=="stopped" then return finishSafetyStop() end
        if safety=="expired" then return finishExpired() end
        if safety=="cleared" then task.wait(C.LoopDelay);continue end
        -- Both native indicators are a reason to stop mutating, not proof
        -- of completion. Do not race the 60s timer against manual finalization.
        if ourAcceptedShown(now)==true then
            BOUND.acceptanceObserved=true
            if lifecycle then lifecycle:accepted(tradeId) end
        end
        if lifecycle and lifecycle.capabilities.autoAccept then
            local function proof()
                local valid,_,current=actionContext(true)
                if not valid or BOUND.quoteInvalidated then return nil end
                local record=scanner.getRecord(target.UserId)
                if not record or record.state~="whitelist" or not record.inv then return nil end
                local ours=evaluateSide(current,"YourOffer",ownInv)
                local theirs=evaluateSide(current,"TheirOffer",record.inv)
                if not tradeDecision(ours,theirs).ok then return nil end
                return {id=tradeId,job=game.JobId,epoch=session,partner=target.UserId,
                    root=current,gui=PG,version=MARKET_PROFILE.version,
                    ourSig=ours.signature,theirSig=theirs.signature,
                    plannedOurSig=BOUND.verifiedOurSig,valuedTheirSig=theirs.signature,
                    ourTotal=ours.rawTotal,theirTotal=theirs.rawTotal,
                    identitiesVerified=#ours.unresolved==0 and #theirs.unresolved==0,
                    quantitiesVerified=true,changing=false,
                    ourAccepted=ourAcceptedShown(current),theirAccepted=theirAcceptedShown(current),
                    give=ours.market and ours.market.items,receive=theirs.market and theirs.market.items}
            end
            local currentProof=proof()
            if currentProof then
                local ok,why=lifecycle:consider(currentProof,function(button)
                    BOUND.acceptanceObserved=true
                    return physicalClick(button,"native trade acceptance")
                end,proof)
                if lifecycle.state.phase=="unconfirmed" then holdOutcome(why);return "acceptance-unconfirmed" end
                if ok then task.wait(C.LoopDelay);continue end
            end
        end
        local pair=theirAcceptedShown(now) and ourAcceptedShown(now)==true
            and readSide(now,"TheirOffer").slots>0 and readSide(now,"YourOffer").slots>0
        if pair then
            local rec=scanner.getRecord(target.UserId)
            local partner=rec and rec.state=="whitelist" and rec.inv or nil
            local ours=evaluateSide(now,"YourOffer",ownInv)
            local theirs=evaluateSide(now,"TheirOffer",partner)
            local signature=ours.signature.."/"..theirs.signature
            -- Accepted indicators never override identity, price or the last
            -- observed approval. Recheck on every poll while finalization waits.
            if not partner or not MARKET_PROFILE.isFresh()
                or (BOUND.approvedSig or BOUND.lastObservedSig)~=signature
                or not tradeDecision(ours,theirs).ok then
                invalidateWebhook("manual-approval-invalidated")
                local declined,why=declineTrade("manual acceptance changed or could not be reverified")
                return declined and finishTradeClosed("manual-approval-invalidated") or tostring(why)
            end
            BOUND.approvedSig=signature
            manualPendingSince=manualPendingSince or os.clock()
            invalidateWebhook("manual-completion-unconfirmed")
            if os.clock()-manualPendingSince>=15 then
                holdOutcome("manual acceptance remained unresolved for 15s; inspect inventory and rejoin")
                return "completion-unconfirmed"
            end
            p4Status("P4 MANUAL PENDING — observing close; no completion claim or timeout decline")
            task.wait(C.LoopDelay)
            continue
        end
        manualPendingSince=nil
        if not MARKET_PROFILE.isFresh() then
            return finishExpired()
        end
        if not target.Parent or Players:GetPlayerByUserId(target.UserId)~=target then
            invalidateWebhook("partner-left")
            return "partner-left"
        end

        -- Timers depend on visible slots, even when a scanner record disappears.
        local accepted=theirAcceptedShown(now)
        local timeAction=MARKET_LOGIC.observe(timing,os.clock(),readSide(now,"TheirOffer").slots,accepted)
        if timing.started then BOUND.deadline=timing.started+C.ActiveOfferWindow end
        if timeAction=="accepted-empty" or timeAction=="empty-timeout" or timeAction=="overall-timeout" then
            invalidateWebhook(timeAction)
            local declined,why=declineTrade(timeAction)
            if declined then return finishTradeClosed(timeAction.."-declined") end
            return timeAction..":"..tostring(why)
        end
        local latestRec=scanner.getRecord(target.UserId)
        local partnerInv=latestRec and latestRec.state=="whitelist" and latestRec.inv or nil

        if not partnerInv then
            p4Status(
                "P4 SAFETY — partner inventory snapshot disappeared | holding, no Accept"
            )
            task.wait(C.LoopDelay)
            continue
        end

        local theirEval=evaluateSide(now,"TheirOffer",partnerInv)
        local ourEval=evaluateSide(now,"YourOffer",ownInv)

        local observedSig=ourEval.signature.."/"..theirEval.signature
        if BOUND.approvedSig and BOUND.approvedSig~=observedSig then
            invalidateWebhook("manual-approval-offer-changed")
            local declined,why=declineTrade("offer changed after manual acceptance")
            return declined and finishTradeClosed("manual-approval-invalidated") or tostring(why)
        end
        if ourAcceptedShown(now)==true then BOUND.approvedSig=observedSig end
        BOUND.lastObservedSig=observedSig
        refreshWebhookCandidate(ourEval,theirEval)

        if theirEval.slots==0 then
            invalidateWebhook("their-offer-empty")
            lastTheirSig=nil; stableSince=nil
            p4Status("P4 — THEIR OFFER empty | 12s timeout | FINAL ACCEPT DISABLED")
            task.wait(C.LoopDelay)
            continue
        end
        if not offerEverStarted then offerEverStarted=true end
        if #ourEval.unresolved>0 then
            invalidateWebhook("our-offer-unresolved")
            p4Status("P4 SAFETY — YOUR OFFER unresolved | declining")
            local declined,why=declineTrade("our-offer-unresolved")
            if declined then return finishTradeClosed("our-offer-unresolved-declined") end
            return "our-offer-unresolved:"..tostring(why)
        end

        if #theirEval.unresolved>0 then
            invalidateWebhook("their-offer-unresolved")

            scanner.setRequestState(
                target,
                "sending",
                string.format(
                    "P4 BALANCER — unresolved THEIR OFFER (%d slot%s) | waiting for offer change | no Accept",
                    #theirEval.unresolved,
                    #theirEval.unresolved==1 and "" or "s"
                )
            )

            task.wait(C.LoopDelay)
            continue
        end


        if theirEval.signature~=lastTheirSig then
            invalidateWebhook("their-offer-changed")
            lastTheirSig=theirEval.signature
            stableSince=os.clock()
            offerGeneration+=1

            -- A new opponent offer is a new planning generation. Any prior
            -- protected hold/failure budget belongs to the old offer only.
            recoveryFailures=0
            recoveryRetryAt=0
            recoveryHoldSig=nil

            p4Status(
                "P4 BALANCER — THEIR OFFER changed | waiting 0.65s for stability"
            )

            task.wait(C.LoopDelay)
            continue
        end

        if not stableSince
            or os.clock()-stableSince<C.OfferStability
        then
            task.wait(C.LoopDelay)
            continue
        end

        refreshWebhookCandidate(ourEval,theirEval)

        local localAccepted=ourAcceptedShown(now)
        if localAccepted~=false then
            invalidateWebhook("local-accepted-or-unknown")
            if localAccepted==true and not tradeDecision(ourEval,theirEval).ok then
                local declined,why=declineTrade("manual acceptance invalidated by unsafe changed offer")
                return declined and finishTradeClosed("manual-approval-invalidated") or tostring(why)
            end
            p4Status("P4 MANUAL ACCEPT HOLD — no voluntary offer changes")
            task.wait(C.LoopDelay)
            continue
        end

        if not recoveryNeeded and ourEval.slots==0 and failedMutationSig==theirEval.signature then
            -- A technical clear is not a fresh price negotiation. Do not turn
            -- a failed bounded concession into a larger initial quote.
            invalidateWebhook("offer-replacement-unverified")
            local declined,why=declineTrade("offer replacement failed; recovered empty offer")
            return declined and finishTradeClosed("offer-replacement-unverified-declined") or tostring(why)
        end
        if recoveryNeeded then
            invalidateWebhook("recovery-active")
            if recoveryHoldSig==theirEval.signature then
                p4Status(
                    "P4 PROTECTED HOLD — previous rebalance became uncertain | waiting for THEIR OFFER to change | ACCEPT DISABLED"
                )
                task.wait(C.LoopDelay)
                continue
            end

            if os.clock()<recoveryRetryAt then
                task.wait(C.LoopDelay)
                continue
            end

            rebalanceSerial+=1
            local recoveryTx={
                id=rebalanceSerial,
                generation=offerGeneration,
                expectedTheirSig=theirEval.signature,
                expectedTheirRawSig=rawSideSignature(now,"TheirOffer"),
                cancelled=false,
                purpose="recovery-clear",
            }

            p4Status(
                string.format(
                    "P4 RECOVERY — clearing partial/unverified OUR OFFER | tx=%d gen=%d | ACCEPT DISABLED",
                    recoveryTx.id,
                    recoveryTx.generation
                )
            )

            local recovered,recoverWhy,recoverModified=
                clearOurOffer(
                    scanner,
                    target,
                    ownInv,
                    recoveryTx,
                    sessionAlive
                )

            if bound.safetyStop then return finishSafetyStop() end
            if recovered then
                recoveryNeeded=false
                recoveryFailures=0
                recoveryRetryAt=0
                recoveryHoldSig=nil

                local currentTrade=tradeRoot()
                if not currentTrade then
                    return finishTradeClosed("trade-closed-during-recovery")
                end

                ourEval=evaluateSide(
                    currentTrade,
                    "YourOffer",
                    ownInv
                )

                print(
                    "[PDIDDLER P4] RECOVERY VERIFIED",
                    target.Name,
                    "| tx",recoveryTx.id,
                    "| our offer cleared"
                )

                -- Recovery changed OUR side. Do not immediately stack a new
                -- plan in the same tick; require THEIR current offer to remain
                -- stable again before rebuilding from the clean state.
                stableSince=os.clock()

                p4Status(
                    "P4 RECOVERY VERIFIED — OUR OFFER clean | revalidating THEIR OFFER before fresh plan | ACCEPT DISABLED"
                )

                task.wait(C.LoopDelay)
                continue
            else
                if recoverWhy=="their-offer-changed" then
                    lastTheirSig=nil
                    stableSince=nil
                    task.wait(C.LoopDelay)
                    continue
                end

                if recoverWhy=="trade-closed" then
                    return finishTradeClosed("trade-closed-during-recovery")
                end

                if recoverWhy=="stale-session"
                    or recoverWhy=="stale-transaction"
                then
                    return recoverWhy
                end

                recoveryFailures+=1
                recoveryRetryAt=os.clock()+C.RecoveryRetryDelay

                warn(
                    "[PDIDDLER P4] RECOVERY FAILED",
                    target.Name,
                    "| tx",recoveryTx.id,
                    "| reason",tostring(recoverWhy),
                    "| modified",tostring(recoverModified),
                    "| attempt",recoveryFailures
                )

                if recoveryFailures>=C.RecoveryMaxAttemptsPerOffer then
                    recoveryHoldSig=theirEval.signature
                    p4Status(
                        "P4 PROTECTED HOLD — recovery could not verify OUR OFFER after bounded retries | waiting for THEIR OFFER change | ACCEPT DISABLED"
                    )
                end

                task.wait(C.LoopDelay)
                continue
            end
        end

        if ourEval.slots>0 then
        local observed,observeWhy=MARKET_LOGIC.observeQuote(
            negotiation,ourEval.rawTotal,theirEval.rawTotal,os.clock()
        )
        if not observed and observeWhy=="uncommitted-own-quote" then
            -- A changed safe-looking total is not proof that our reserved
            -- increase committed. Never silently rebase away its cost.
            invalidateWebhook("uncommitted-own-quote")
            local declined=declineTrade("verified quote ownership lost: "..tostring(observeWhy))
            if declined then return finishTradeClosed("uncommitted-own-quote-declined") end
            holdOutcome("uncommitted offer could not be safely closed; inspect inventory and rejoin")
            return "uncommitted-own-quote"
        end
        end
        local currentDecision=tradeDecision(ourEval,theirEval)
        -- One planner per exact offer generation; never run the DP every frame.
        if cachedPlanSig~=theirEval.signature then
            cachedPlans,cachedPlanWhy=marketPlans(ownInv,theirEval)
            cachedPlanSig=theirEval.signature
        end
        local plans,planWhy=cachedPlans or {},cachedPlanWhy
        -- Opponent-first path: old rank[1] may jump almost to +15 floor.
        -- Choose a guarded initial quote rather than donating headroom.
        local plan=plans[1]
        local planStage=ourEval.slots==0 and "initial" or "rebalance"
        if ourEval.slots==0 or not currentDecision.ok then
            local initialWhy
            plan,initialWhy=MARKET_LOGIC.selectInitialOffer(plans,theirEval.rawTotal,theirEval.market)
            if plan then
                print("[PDIDDLER P4] INITIAL QUOTE",tostring(initialWhy),"| give",plan.rawTotal,"| profit",plan.rawProfit)
            end
        end
        if ourEval.slots>0 and currentDecision.ok then
            if additionAnchor==nil then
                -- Initial verified safe quote (including a speculative opener).
                additionAnchor=theirEval.rawTotal
            end
            verifyWebhookCandidate(ourEval,theirEval,currentDecision,"verified-profitable-test-offer")

            local earlyPlan=nil
            -- V15: an upward change is considered ONLY when their verified NET
            -- value exceeds our last reward anchor by >= max(10, 5% anchor).
            -- An unchanged offer, same-value swap, or elapsed time grants none.
            if not accepted and localAccepted==false then
                if earlyCounterState.faulted then
                    p4Status("P4 EARLY HOLD — policy fault; no unchecked mutation")
                    task.wait(C.LoopDelay)
                    continue
                end
                local ok,earlyAction,candidate,meta=pcall(
                    EARLY_COUNTER_POLICY.choose,
                    earlyCounterState,theirEval.signature,
                    ourEval,theirEval,plans,
                    {accepted=accepted,localAccepted=localAccepted,
                        earlyRemaining=MARKET_LOGIC.earlyAllowance(negotiation,ourEval.rawTotal,theirEval.rawTotal),
                        anchorTotal=additionAnchor}
                )
                if not ok then
                    earlyCounterState.faulted=true
                    invalidateWebhook("early-policy-exception")
                    warn("[PDIDDLER P4] EARLY POLICY FAILURE | holding current safe offer")
                    task.wait(C.LoopDelay)
                    continue
                end
                if earlyAction=="counter" then
                    if type(candidate)~="table" or candidate.ok~=true then
                        earlyCounterState.faulted=true
                        invalidateWebhook("early-invalid-result")
                        task.wait(C.LoopDelay)
                        continue
                    end
                    earlyPlan=candidate
                    plan=candidate
                    planStage="early"
                    p4Status(string.format(
                        "P4 EARLY COUNTER PROPOSED — profit %+s | demand +%.2f | mode %s | one-shot",
                        fmt(candidate.rawProfit),
                        tonumber(meta and meta.demandGain) or 0,
                        tostring(meta and meta.reason or "unknown")
                    ))
                elseif earlyAction=="hold" then
                    p4Status("P4 EARLY HOLD — market or acceptance context incomplete")
                    task.wait(C.LoopDelay)
                    continue
                end
            end

            if not earlyPlan then
                -- Preserve the bounded unaccepted-offer timeout but DISABLE
                -- all time-triggered value increases. Empty candidate plans
                -- make MARKET_LOGIC.negotiate a wait/decline-only path.
                -- Native acceptance readiness remains a necessary safety gate.
                local nativeUI=ACCEPT_READY_GATE.read(
                    now,function(node) return visible(node,now) end
                )
                local nativeAllowed=ACCEPT_READY_GATE.step(
                    nativeReady,observedSig,os.clock(),nativeUI,accepted or localAccepted==true
                )
                local action,nextPlan=MARKET_LOGIC.negotiate(
                    negotiation,theirEval.signature,ourEval.rawTotal,{},os.clock(),
                    accepted or localAccepted==true,nativeAllowed,
                    theirEval.rawTotal
                )
                if action=="decline" then
                    invalidateWebhook("best-safe-offer-unaccepted")
                    local declined,why=declineTrade("best safe offer unaccepted after final window")
                    if declined then return finishTradeClosed("negotiation-finished-declined") end
                    return "negotiation-decline:"..tostring(why)
                elseif action=="improve" then
                    -- Fail closed if a future policy accidentally proposes a
                    -- time-based increase despite receiving empty candidates.
                    holdOutcome("unexpected time-triggered concession")
                    return "time-concession-disallowed"
                else
                    p4Status(string.format(
                        "P4 — verified Supreme profit +%s | %s | FINAL ACCEPT DISABLED",
                        fmt(currentDecision.rawProfit),action
                    ))
                    task.wait(C.LoopDelay)
                    continue
                end
            end
        end
        if #plans==0 then
            invalidateWebhook("no-safe-plan")
            local declined,why=declineTrade("no verified +15 Supreme plan: "..tostring(planWhy or "impossible"))
            if declined then return finishTradeClosed("no-safe-plan-declined") end
            return "no-safe-plan-decline:"..tostring(why)
        end

        -- A safe candidate exists for the current exact offer, so any prior
        -- no-plan grace belongs to an obsolete planning state.

        if not plan then
            task.wait(C.LoopDelay)
            continue
        end

        -- Every economic increase uses the same opponent-addition policy,
        -- including safety replacements of a mirrored quote. An exact technical
        -- restoration is measured against the last committed quote, not zero.
        local lastVerified=negotiation.ledger and negotiation.ledger.lastVerifiedTotal or 0
        local restorationReward=false
        local economicBase=math.max(ourEval.rawTotal,lastVerified)
        if not negotiation.ledger and safetyRestoreReference then
            economicBase=math.max(economicBase,safetyRestoreReference.base)
            if plan.rawTotal>economicBase then
                local nonincreasing={}
                for _,alternative in ipairs(plans) do
                    if alternative.rawTotal<=economicBase then nonincreasing[#nonincreasing+1]=alternative end
                end
                plan=MARKET_LOGIC.selectInitialOffer(nonincreasing,theirEval.rawTotal,theirEval.market)
                if not plan then
                    local declined,why=declineTrade("no safe restoration within withdrawn speculative opener ceiling")
                    return declined and finishTradeClosed("unanchored-restoration-declined") or tostring(why)
                end
            end
        end
        if additionAnchor and planStage~="early" and plan.rawTotal>economicBase then
            local action,candidate
            if ourEval.slots==0 and safetyRestoreReference and safetyRestoreReference.committed
                and safetyRestoreReference.base==lastVerified
                and safetyRestoreReference.theirSignature==theirEval.signature
                and safetyRestoreReference.theirRaw==rawSideSignature(now,"TheirOffer") then
                -- Emergency withdrawal removed exposure, not the last verified economic baseline.
                -- Any restoration ABOVE that baseline still requires the SAME addition-only policy.
                action,candidate=EARLY_COUNTER_POLICY.choose(earlyCounterState,theirEval.signature,
                    safetyRestoreReference.ours,theirEval,plans,{accepted=accepted,localAccepted=localAccepted,
                        earlyRemaining=MARKET_LOGIC.earlyAllowance(negotiation,lastVerified,theirEval.rawTotal),
                        anchorTotal=additionAnchor})
                if action=="counter" and candidate then restorationReward=true end
            elseif ourEval.slots>0 then
                action,candidate=EARLY_COUNTER_POLICY.choose(earlyCounterState,theirEval.signature,
                    ourEval,theirEval,plans,{accepted=accepted,localAccepted=localAccepted,
                        earlyRemaining=MARKET_LOGIC.earlyAllowance(negotiation,ourEval.rawTotal,theirEval.rawTotal),
                        anchorTotal=additionAnchor})
            end
            if action=="counter" and candidate then
                plan=candidate;planStage=restorationReward and "rebalance" or "early"
            else
                local downward={}
                for _,alternative in ipairs(plans) do
                    if alternative.rawTotal<=economicBase then
                        downward[#downward+1]=alternative
                    end
                end
                plan=MARKET_LOGIC.selectInitialOffer(downward,theirEval.rawTotal,theirEval.market)
                if not plan then
                    local declined,why=declineTrade("no nonincreasing safe replacement; opponent addition did not authorize increase")
                    return declined and finishTradeClosed("net-addition-replacement-declined") or tostring(why)
                end
            end
        end

        local reserved,reserveWhy=MARKET_LOGIC.reserveOffer(
            negotiation,planStage,theirEval.signature,plan,ourEval.rawTotal,theirEval.rawTotal,os.clock()
        )
        if not reserved then
            invalidateWebhook("concession-budget-held")
            p4Status("P4 BUDGET HOLD — "..tostring(reserveWhy).." | no unverified offer change")
            task.wait(C.LoopDelay)
            continue
        end
        invalidateWebhook("rebalance-active")

        p4Status(
            string.format(
                "P4 REBALANCE — safe %s/%s | replacing RAW OUR %s with %s | target raw profit %+s | protected %+s",
                plan.kind,
                plan.mode,
                fmt(ourEval.rawTotal),
                fmt(plan.rawTotal),
                fmt(plan.rawProfit),
                fmt(plan.protectedProfit)
            )
        )

        rebalanceSerial+=1
        local tx={
            id=rebalanceSerial,
            generation=offerGeneration,
            expectedTheirSig=theirEval.signature,
            expectedTheirRawSig=rawSideSignature(now,"TheirOffer"),
            cancelled=false,
            purpose="rebalance",
        }

        local applied,why,modified=applyPlan(
            scanner,
            target,
            ownInv,
            plan,
            tx,
            sessionAlive
        )

        if bound.safetyStop then return finishSafetyStop() end
        if not applied then
            MARKET_LOGIC.cancelConcession(negotiation)
            -- Any failure after a mutation means our current offer is no longer
            -- authoritative. Never stack a fresh plan on top of it.
            if modified then
                failedMutationSig=theirEval.signature
                recoveryNeeded=true
                recoveryRetryAt=os.clock()+C.RecoveryRetryDelay
            end

            if why=="their-offer-changed" then
                lastTheirSig=nil
                stableSince=nil

                print(
                    "[PDIDDLER P4] TX ABORT",
                    target.Name,
                    "| tx",tx.id,
                    "| opponent offer changed",
                    "| modified",tostring(modified)
                )

                task.wait(C.LoopDelay)
                continue
            end

            if why=="trade-closed" then
                return finishTradeClosed("trade-closed")
            end

            if why=="stale-session"
                or why=="stale-transaction"
            then
                return why
            end

            scanner.setRequestState(
                target,
                "sendfailed",
                "P4 REBALANCE UNVERIFIED — "..tostring(why).." | entering protected recovery | ACCEPT DISABLED"
            )

            warn(
                "[PDIDDLER P4] REBALANCE FAILED",
                target.Name,
                "| tx",tx.id,
                "| reason",tostring(why),
                "| modified",tostring(modified)
            )

            if not modified then
            end

            task.wait(C.LoopDelay)
            continue
        end

        recoveryNeeded=false
        recoveryFailures=0
        recoveryRetryAt=0
        recoveryHoldSig=nil

        local verifyTrade=tradeRoot()
        if not verifyTrade then return finishTradeClosed("trade-closed-after-rebalance") end

        local latest=scanner.getRecord(target.UserId)
        local theirFinal=evaluateSide(
            verifyTrade,
            "TheirOffer",
            latest and latest.inv
        )
        local ourFinal=evaluateSide(
            verifyTrade,
            "YourOffer",
            ownInv
        )

        if theirFinal.signature~=theirEval.signature
            or not planMatches(plan,ourFinal)
        then
            MARKET_LOGIC.cancelConcession(negotiation)
            lastTheirSig=nil
            stableSince=nil
            task.wait(C.LoopDelay)
            continue
        end

        local finalDecision=tradeDecision(ourFinal,theirFinal)

        if finalDecision.ok then
            -- Approval can become visible before the next outer poll. Keep the
            -- observation fence aligned with these fully verified actual slots.
            BOUND.lastObservedSig=ourFinal.signature.."/"..theirFinal.signature
            BOUND.verifiedOurSig=ourFinal.signature
            assert(MARKET_LOGIC.confirmConcession(negotiation,theirFinal.signature,plan,ourFinal,os.clock()),
                "verified offer reservation ownership lost")
            local ledger=negotiation.ledger
            print("[PDIDDLER P4] LEDGER VERIFIED",planStage,"| early spent",ledger and ledger.earlySpent,
                "| late steps",negotiation.steps or 0,"/2 | late spent",ledger and ledger.lateSpent)
            if additionAnchor==nil or planStage=="early" or restorationReward then
                -- Move the net-addition watermark ONLY after exact P4
                -- slot verification and committed concession ownership.
                additionAnchor=theirFinal.rawTotal
            end
            safetyRestoreReference=nil
            if planStage=="initial" then
                -- This verified reply already answers their revealed offer.
                earlyCounterState.signature=theirFinal.signature
                earlyCounterState.spent=true
            end
            verifyWebhookCandidate(
                ourFinal,
                theirFinal,
                finalDecision,
                "rebalance-verified"
            )

            scanner.setRequestState(
                target,
                "accepted",
                string.format(
                    "P4 REBALANCED — %s/%s | RAW OUR %s THEIR %s PROFIT %+s | PROTECTED PROFIT %+s | ACCEPT DISABLED",
                    finalDecision.kind,
                    finalDecision.mode,
                    fmt(ourFinal.rawTotal),
                    fmt(theirFinal.rawTotal),
                    fmt(finalDecision.rawProfit),
                    fmt(finalDecision.protectedProfit)
                )
            )

            print(
                "[PDIDDLER P4] REBALANCE VERIFIED",
                target.Name,
                "| tx",tx.id,
                "kind",finalDecision.kind,
                "mode",finalDecision.mode,
                "rawProfit",finalDecision.rawProfit,
                "protectedProfit",finalDecision.protectedProfit,
                "| ACCEPT DISABLED"
            )
        else
            MARKET_LOGIC.cancelConcession(negotiation)
            invalidateWebhook("decision-unsafe")
        end

        task.wait(C.LoopDelay)
    end

    invalidateWebhook("stale-session")
    return "stale-session"
end

function M.run(scanner,marketProfile,marketLogic,marketPlanner,tradeTelemetry,acceptReadyGate,earlyCounterPolicy)
    assert(type(scanner)=="table","scanner API required")
    assert(type(scanner.getRecord)=="function","scanner.getRecord missing")
    assert(type(scanner.getOwnInventory)=="function","scanner.getOwnInventory missing")
    assert(type(scanner.setStatus)=="function","scanner.setStatus missing")
    assert(type(scanner.claimStatusOwner)=="function","scanner.claimStatusOwner missing")
    assert(type(scanner.releaseStatusOwner)=="function","scanner.releaseStatusOwner missing")
    assert(type(scanner.setRequestState)=="function","scanner.setRequestState missing")

    assert(type(marketProfile)=="table","marketProfile required")
    assert(marketProfile.liveReady==true,"marketProfile.liveReady must be true")
    assert(type(marketProfile.get)=="function","marketProfile.get missing")
    assert(type(marketProfile.coverage)=="function","marketProfile.coverage missing")

    assert(type(marketProfile.isFresh)=="function" and marketProfile.isFresh(),"Supreme snapshot expired")
    assert(type(marketLogic.quantity)=="function","strict quantity policy required")
    local coverage=marketProfile.coverage()
    assert(type(coverage)=="table" and tonumber(coverage.total)==190,
        "marketProfile coverage must be 190")

    assert(type(marketLogic)=="table","marketLogic required")
    assert(type(marketLogic.itemAssessment)=="function","marketLogic.itemAssessment missing")
    assert(type(marketLogic.bundleAssessment)=="function","marketLogic.bundleAssessment missing")
    assert(type(marketLogic.tradeDecision)=="function","marketLogic.tradeDecision missing")
    assert(type(marketLogic.rankPlans)=="function","marketLogic.rankPlans missing")
    assert(type(marketLogic.selectInitialOffer)=="function","guarded opponent-first selection required")
    assert(type(marketLogic.confirmConcession)=="function" and type(marketLogic.cancelConcession)=="function",
        "verified concession lifecycle required")
    assert(type(marketLogic.observeQuote)=="function" and type(marketLogic.earlyAllowance)=="function"
        and type(marketLogic.reserveOffer)=="function","one trade-wide concession ledger required")

    assert(type(marketPlanner)=="table","marketPlanner required")
    assert(type(marketPlanner.buildPlans)=="function","marketPlanner.buildPlans missing")
    assert(type(marketPlanner.planMatches)=="function","marketPlanner.planMatches missing")

    assert(type(tradeTelemetry)=="table","tradeTelemetry required")
    assert(type(acceptReadyGate)=="table" and type(acceptReadyGate.read)=="function"
        and type(acceptReadyGate.step)=="function","native accept readiness gate required")
    assert(type(earlyCounterPolicy)=="table" and type(earlyCounterPolicy.choose)=="function",
        "early counteroffer policy required")
    assert(type(tradeTelemetry.build)=="function","tradeTelemetry.build missing")

    local prior=ENV.PDIDDLER_PART4_CONTROLLER
    if type(prior)=="table" and type(prior.isAlive)=="function" and prior.isAlive() then
        assert(prior.kind=="supreme-v11-value-first" and prior.jobId==game.JobId,"incompatible active Part 4 controller")
        return prior
    end
    assert(ENV.PDIDDLER_PART4_SESSION==nil,"Part 4 already initialized; rejoin before switching builds")
    AUTOMATION_READY=scanner.isAutomationReady
    MARKET_PROFILE=marketProfile
    MARKET_LOGIC=marketLogic
    MARKET_PLANNER=marketPlanner
    ACCEPT_READY_GATE=acceptReadyGate
    EARLY_COUNTER_POLICY=earlyCounterPolicy
    local SESSION=1
    ENV.PDIDDLER_PART4_SESSION=SESSION

    local function alive()
        return ENV.PDIDDLER_PART4_SESSION==SESSION
    end

    local S={
        session=SESSION,
        active=false,
        result=nil,
        tradesSeen=0,
        webhookCandidate=nil,
        webhookReason="idle",
        webhookSeq=0,
    }

    local function publishWebhookCandidate(snapshot)
        S.webhookSeq+=1

        local out={}
        for k,v in pairs(type(snapshot)=="table" and snapshot or {}) do
            out[k]=v
        end

        out.seq=S.webhookSeq
        S.webhookCandidate=out
        S.webhookReason="verified"
    end

    local function clearWebhookCandidate(reason)
        S.webhookCandidate=nil
        S.webhookReason=tostring(reason or "cleared")
    end

    task.spawn(function()
        print(
            "[PDIDDLER P4] ARMED",
            "session",SESSION,
            "| strict +15 Supreme floor active",
            "| validated market planner active "..tostring(MARKET_PROFILE.snapshotDate or "snapshot-unknown"),
            "| FINAL ACCEPT DISABLED"
        )

        local seenTrade=nil
        local seenAt=nil

        while alive() do
            local t=tradeRoot()

            if t then
                if t~=seenTrade then
                    seenTrade=t
                    seenAt=os.clock()
                    S.active=false
                    S.result=nil
                end

                if not S.active
                    and seenAt
                    and os.clock()-seenAt>=C.TradeAppearStability
                then
                    S.active=true
                    S.tradesSeen+=1
                    scanner.claimStatusOwner("P4")

                    local token=SESSION
                    local function tradeSessionAlive()
                        -- Session validity and GUI existence are separate.
                        -- A normal trade close must be classified as trade-closed,
                        -- not stale-session.
                        return alive()
                            and token==SESSION
                    end

                    S.result=runTrade(
                        scanner,
                        SESSION,
                        tradeSessionAlive,
                        tradeTelemetry,
                        publishWebhookCandidate,
                        clearWebhookCandidate,
                        function(reason)
                            S.blocked=true;S.blockReason=reason
                            if type(tradeTelemetry.holdOutcome)=="function" then tradeTelemetry.holdOutcome(reason) end
                        end
                    )
                    local retired=BOUND
                    if tradeTelemetry.lifecycle and retired then tradeTelemetry.lifecycle:close(retired.tradeId,S.result) end
                    local pending=tradeTelemetry.lifecycle and tradeTelemetry.lifecycle.state.phase=="reconciling"
                    local completed=tradeTelemetry.lifecycle and tradeTelemetry.lifecycle.state.lastReport
                        and tradeTelemetry.lifecycle.state.lastReport.id==(retired and retired.tradeId)
                    if retired and retired.acceptanceObserved and not S.blocked and not pending and not completed then
                        S.blocked=true;S.blockReason="accepted transaction outcome unconfirmed"
                        S.result="completion-unconfirmed"
                        if type(tradeTelemetry.holdOutcome)=="function" then
                            tradeTelemetry.holdOutcome(S.blockReason)
                        end
                    end
                    if S.blocked then
                        if retired then for _,c in ipairs(retired.connections or {}) do c:Disconnect() end end
                        BOUND=nil;S.active=false
                        scanner.releaseStatusOwner("P4")
                        return -- terminal unknown outcome; no polling worker or new trade
                    end
                    -- Keep lifetime listeners until THIS window ends. A new
                    -- root or a witnessed close/reopen must not inherit a wait.
                    if retired then retired.invalid=true end
                    while alive() and retired and tradeRoot()==retired.root and not retired.closed do
                        task.wait(0.08)
                    end
                    if retired then
                        for _,connection in ipairs(retired.connections or {}) do connection:Disconnect() end
                    end
                    if BOUND==retired then BOUND=nil end
                    print("[PDIDDLER P4] TRADE RESULT",tostring(S.result))

                    scanner.releaseStatusOwner("P4")

                    seenTrade=nil
                    seenAt=nil
                    S.active=false
                end
            else
                seenTrade=nil
                seenAt=nil
                S.active=false
            end

            task.wait(C.LoopDelay)
        end

        clearWebhookCandidate("part4-stopped")
        scanner.releaseStatusOwner("P4")
    end)

    local controller={
        kind="supreme-v11-value-first",jobId=game.JobId,isAlive=alive,
        session=SESSION,
        state=S,
        stop=function()
            if ENV.PDIDDLER_PART4_SESSION==SESSION then
                ENV.PDIDDLER_PART4_SESSION=SESSION+1
            end
        end,
    }
    ENV.PDIDDLER_PART4_CONTROLLER=controller
    return controller
end

return M
