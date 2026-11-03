-- pdiddler Part 4 balancer v2.5.1 ADAPTIVE PLAN CACHE PERF
-- Scope:
--   * observe an active MM2 trade handed off by known-good Part 3
--   * observe first, then use a realistic market-aware opener only if THEY stay empty
--   * accepted-empty => decline immediately
--   * empty/no-action => decline after 15 seconds
--   * non-empty => stabilize, value, and rebalance our side
--   * balanced-aggressive raw-value thresholds
--   * FINAL TRADE ACCEPT IS ABSOLUTELY DISABLED
--
-- Market decisions are injected from the validated 190-item profile + pure market engine.
-- No live market HTTP occurs inside a trade; missing metadata never defaults to Stable.
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
local ACCEPTANCE_POLICY=nil

local C={
    TradeAppearStability=0.30,
    OfferVerifyTimeout=3.0,
    EmptyTimeout=15.0,
    ActiveOfferWindow=60.0,
    OfferStability=0.65,
    NoPlanNegotiationGrace=5.0,
    RemoveVerifyTimeout=0.90,
    RemoveRetryVerifyTimeout=1.20,
    RemoveRetryGuard=0.25,
    RecoveryRetryDelay=0.75,
    RecoveryMaxAttemptsPerOffer=2,
    ApplyVerifyTimeout=2.5,
    LoopDelay=0.12,

    -- Profit-focused strategy:
    -- keep moderate overpay, but do not sit on an implausibly tiny OUR OFFER
    -- after THEIR OFFER grows dramatically. Extreme normalization requires
    -- BOTH a large ratio and a large profit surplus so small-value trades like
    -- 25 vs 8 (+17) are not "fixed" just because the ratio is high.
    ExtremeReplanRatio=2.0,
    ExtremeProfitFlat=50,
    ExtremeProfitMultiple=2.5,
    ExtremeMinReplanStep=5,
}

local function norm(x)
    return tostring(x or "")
        :gsub("’","'")
        :lower()
        :gsub("[^%w]","")
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

            if enabled then
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
    local wanted=norm(partnerName(t))
    if wanted=="" then return nil end

    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP and (
            norm(p.Name)==wanted
            or norm(p.DisplayName)==wanted
        ) then
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
        local n=tonumber(tostring(amount.Text or ""):match("^[xX]%s*(%d+)$"))
        if n and n>=1 then return math.floor(n) end
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
            if shown and shown~="" then
                out.slots+=1
                out.entries[#out.entries+1]={
                    index=i,
                    node=slot,
                    shown=shown,
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

local OurAcceptedFallback={
    at=0,
    value=false,
    via="none",
}

local function ourAcceptedShown(t)
    if not t then return false,"no-trade" end

    local side=t:FindFirstChild("YourOffer")
    local direct=side and side:FindFirstChild("Accepted")

    if direct then
        local shown=visible(direct,t)
        return shown,shown and direct:GetFullName() or "direct-not-visible"
    end

    local now=os.clock()
    if now-OurAcceptedFallback.at<0.25 then
        return OurAcceptedFallback.value,OurAcceptedFallback.via
    end

    OurAcceptedFallback.at=now
    OurAcceptedFallback.value=false
    OurAcceptedFallback.via="none"

    for _,d in ipairs(t:GetDescendants()) do
        if (d:IsA("TextLabel") or d:IsA("TextButton"))
            and visible(d,t)
        then
            local q=tostring(d.Text or ""):upper():gsub("%s+"," ")
                :gsub("^%s+",""):gsub("%s+$","")

            if q:find("YOU HAVE ACCEPTED",1,true) then
                OurAcceptedFallback.value=true
                OurAcceptedFallback.via=d:GetFullName()
                break
            end
        end
    end

    return OurAcceptedFallback.value,OurAcceptedFallback.via
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
    if not entry or not inv or type(inv.items)~="table" then
        return nil,"inventory-unavailable"
    end

    local liveId=norm(entry.internalId)
    local liveName=norm(fullShownName(entry))
    local hits={}

    for _,it in ipairs(inv.items) do
        local idMatch=
            liveId~=""
            and norm(it.id)~=""
            and liveId==norm(it.id)

        local nameMatch=
            liveName~=""
            and liveName==norm(it.name)

        if idMatch or nameMatch then
            hits[#hits+1]=it
        end
    end

    if #hits==0 then
        -- The scanner inventory intentionally stores only eligible
        -- Ancient/Godly/Chroma weapons. A complete partner scan with no
        -- eligible match means this visible slot is non-eligible for valuation.
        if (tonumber(inv.unmapped) or 0)==0
            and (tonumber(inv.unpriced) or 0)==0
            and (tonumber(inv.badQty) or 0)==0
        then
            return {
                id=tostring(entry.internalId or ""),
                name=fullShownName(entry),
                value=0,
                page="ineligible",
                qty=math.max(1,tonumber(entry.qty) or 1),
                ineligible=true,
            },"ineligible-zero"
        end

        return nil,"unresolved"
    end

    local first=hits[1]

    for i=2,#hits do
        local x=hits[i]
        if norm(x.id)~=norm(first.id)
            or tostring(x.page or "")~=tostring(first.page or "")
            or tonumber(x.value)~=tonumber(first.value)
        then
            return nil,"ambiguous"
        end
    end

    return {
        id=first.id,
        checkerId=first.checkerId,
        name=first.name,
        value=tonumber(first.value) or 0,
        page=first.page,
        qty=math.max(1,tonumber(entry.qty) or 1),
        ineligible=false,
    },"resolved"
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
                    id=tostring(item.checkerId or item.id or ""),
                    name=tostring(item.name or item.id or ""),
                    value=tonumber(item.value) or 0,
                    qty=qty,
                }
            end

            local id=tostring(item.id or fullShownName(entry))
            local countKey=tostring(item.page or "")..":"..id
            out.counts[countKey]=(out.counts[countKey] or 0)+qty

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
    local wantedId=norm(wanted and wanted.id)
    local wantedName=tostring(wanted and wanted.name or "")
    local wantedNorm=norm(wantedName)
    local wantedBase=norm(
        wantedName:gsub("^[Cc][Hh][Rr][Oo][Mm][Aa]%s+","")
    )
    local wantedChroma=
        wantedName:lower():match("^%s*chroma%s+")~=nil
        or wantedId:find("chroma",1,true)~=nil

    for _,entry in ipairs(side.entries) do
        local entryId=norm(entry.internalId)
        local entryName=norm(entry.shown)

        if wantedId~="" and entryId~="" and wantedId==entryId then
            return true,"internal-id"
        end

        if wantedChroma then
            if entry.isChroma and entryName==wantedBase then
                return true,"base-name+chroma-tag"
            end
        elseif not entry.isChroma and entryName==wantedNorm then
            return true,"display-name"
        end
    end

    return false,"no-match"
end

local function physicalClick(button,label)
    if not button or not visible(button) then return false end

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
    local before=tradeRoot()
    if not before then return true,"already-closed" end

    print("[PDIDDLER P4] DECLINE",tostring(reason or ""))

    local tradeFolder=RS:FindFirstChild("Trade")
    local remote=tradeFolder and tradeFolder:FindFirstChild("DeclineTrade")
    local remoteFired=false

    if remote and remote:IsA("RemoteEvent") then
        remoteFired=pcall(function()
            remote:FireServer()
        end)
    end

    local deadline=os.clock()+1.2
    while tradeRoot() and os.clock()<deadline do
        task.wait(0.08)
    end

    if tradeRoot() then
        local t=tradeRoot()
        local actions=t and t:FindFirstChild("Actions")
        local decline=actions and actions:FindFirstChild("Decline")
        local button=decline and decline:FindFirstChild("ActionButton")
        if button then
            physicalClick(button,"Decline trade")
        end
    end

    local closeDeadline=os.clock()+2.5
    while tradeRoot() and os.clock()<closeDeadline do
        task.wait(0.08)
    end

    return tradeRoot()==nil,
        remoteFired and "remote" or "ui-fallback"
end

local function tradeDecision(ourEval,theirEval)
    local ourRaw=tonumber(ourEval and ourEval.rawTotal) or 0
    local theirRaw=tonumber(theirEval and theirEval.rawTotal) or 0

    if not ourEval
        or not theirEval
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

local function extremeOneSided(decision,ourEval,theirEval)
    decision=type(decision)=="table" and decision or {}

    if decision.mode~="profit" then
        return false,{
            ratio=0,
            rawFloor=math.huge,
            protectedFloor=math.huge,
        }
    end

    local ourRaw=math.max(0,tonumber(ourEval and ourEval.rawTotal) or 0)
    local theirRaw=math.max(0,tonumber(theirEval and theirEval.rawTotal) or 0)
    local rawProfit=tonumber(decision.rawProfit) or (theirRaw-ourRaw)
    local protectedProfit=tonumber(decision.protectedProfit) or 0
    local required=math.max(0,tonumber(decision.requiredProfit) or 0)

    local ratio
    if ourRaw<=0 then
        ratio=theirRaw>0 and math.huge or 1
    else
        ratio=theirRaw/ourRaw
    end

    local rawFloor=math.max(
        C.ExtremeProfitFlat,
        required*C.ExtremeProfitMultiple
    )

    local protectedFloor=math.max(
        C.ExtremeProfitFlat,
        required*C.ExtremeProfitMultiple
    )

    local extreme=
        ratio>=C.ExtremeReplanRatio
        and rawProfit>=rawFloor-0.0001
        and protectedProfit>=protectedFloor-0.0001

    return extreme,{
        ratio=ratio,
        rawFloor=rawFloor,
        protectedFloor=protectedFloor,
    }
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

    local t=tradeRoot()
    if not t then
        return false,"trade-closed"
    end

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

        task.wait(0.06)
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
            C.RemoveVerifyTimeout
        )

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

        task.wait(0.08)
    end

    return false,"clear-limit",modified
end

local function applyPlan(scanner,target,ownInv,plan,tx,sessionAlive)
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

    for _,p in ipairs(plan.picks) do
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

local function runTrade(scanner,session,sessionAlive,tradeTelemetry,publishWebhookCandidate,clearWebhookCandidate)
    local function p4Status(text)
        return scanner.setStatus(tostring(text or ""),"P4")
    end

    local t=tradeRoot()
    if not t then return "trade-missing" end

    local target=findPartner(t)
    if not target then
        p4Status(
            "P4 SAFETY — trade partner could not be verified | no item offered"
        )
        return "partner-unverified"
    end

    local tradeId=table.concat({
        "p4w",
        tostring(session),
        tostring(target.UserId),
        tostring(math.floor(os.clock()*1000)),
    },":")

    local lastWebhookCandidate=nil

    local function invalidateWebhook(reason)
        lastWebhookCandidate=nil
        if type(clearWebhookCandidate)=="function" then
            clearWebhookCandidate(tostring(reason or "invalidated"))
        end
    end

    local function verifyWebhookCandidate(ourEval,theirEval,decision,source)
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

    local rec=scanner.getRecord(target.UserId)
    if not rec or rec.state~="whitelist" or not rec.inv then
        p4Status(
            "P4 SAFETY — partner inventory is not a verified whitelist snapshot | no item offered"
        )
        return "partner-inventory-unverified"
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

    local ownInv,ownWhy=scanner.getOwnInventory()
    if not ownInv then
        p4Status(
            "P4 SAFETY — could not refresh own inventory: "..tostring(ownWhy)
        )
        return "own-inventory-unavailable"
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
        return "own-inventory-incomplete"
    end

    local tradeFolder=RS:FindFirstChild("Trade")
    local offer=tradeFolder and tradeFolder:FindFirstChild("OfferItem")

    if not offer or not offer:IsA("RemoteEvent") then
        p4Status("P4 SAFETY — OfferItem remote unavailable")
        return "offer-remote-missing"
    end

    local emptySince=os.clock()
    local openerObserveSeconds=tonumber(ACCEPTANCE_POLICY.OpenerObserveSeconds) or 2.5
    local openerSkipped=false
    local openerPlaced=false

    scanner.setRequestState(
        target,
        "accepted",
        string.format(
            "P4 ADAPTIVE OPENER OBSERVE — waiting %.1fs for THEIR first move | FINAL ACCEPT DISABLED",
            openerObserveSeconds
        )
    )
    print(
        "[PDIDDLER P4] ADAPTIVE OPENER OBSERVE",
        target.Name,
        "| seconds",openerObserveSeconds,
        "| ACCEPT DISABLED"
    )

    local openerObserveStart=os.clock()
    while sessionAlive()
        and os.clock()-openerObserveStart<openerObserveSeconds
    do
        local openerTrade=tradeRoot()
        if not openerTrade then
            return finishTradeClosed("trade-closed-during-opener-observe")
        end

        local openerRec=scanner.getRecord(target.UserId)
        local openerPartnerInv=openerRec and openerRec.inv
        if not openerPartnerInv then
            p4Status(
                "P4 SAFETY — partner inventory disappeared during opener observation | holding"
            )
            task.wait(C.LoopDelay)
            continue
        end

        local openerTheir=evaluateSide(
            openerTrade,
            "TheirOffer",
            openerPartnerInv
        )

        if openerTheir.slots>0 then
            openerSkipped=true
            print(
                "[PDIDDLER P4] ADAPTIVE OPENER SKIP — THEIR OFFER FIRST",
                target.Name,
                "| slots",openerTheir.slots
            )
            break
        end

        task.wait(C.LoopDelay)
    end

    if not openerSkipped then
        local opener,openerMeta=ACCEPTANCE_POLICY.selectOpener(
            ownInv,
            rec.inv,
            MARKET_PROFILE,
            MARKET_LOGIC
        )

        if opener then
            -- Re-read THEIR side immediately before mutation. If they acted
            -- during selection, their revealed intent owns the negotiation.
            local openerBoundaryTrade=tradeRoot()
            if not openerBoundaryTrade then
                return finishTradeClosed("trade-closed-before-opener")
            end

            local openerBoundaryRec=scanner.getRecord(target.UserId)
            local openerBoundaryInv=openerBoundaryRec and openerBoundaryRec.inv
            local openerBoundaryTheir=openerBoundaryInv
                and evaluateSide(
                    openerBoundaryTrade,
                    "TheirOffer",
                    openerBoundaryInv
                )
                or nil

            if openerBoundaryTheir and openerBoundaryTheir.slots>0 then
                openerSkipped=true
                print(
                    "[PDIDDLER P4] ADAPTIVE OPENER SKIP — THEIR OFFER FIRST",
                    target.Name,
                    "| boundary slots",openerBoundaryTheir.slots
                )
            else
                scanner.setRequestState(
                    target,
                    "accepted",
                    string.format(
                        "P4 ADAPTIVE OPENER — %s (%s) | partnerTop4=%s | FINAL ACCEPT DISABLED",
                        tostring(opener.name),
                        fmt(opener.value),
                        fmt(openerMeta and openerMeta.partnerTop4Raw)
                    )
                )

                local fired=pcall(function()
                    offer:FireServer(opener.id,"Weapons")
                end)

                if not fired then
                    p4Status("P4 — adaptive opening OfferItem call failed")
                    return "opening-offer-fire-failed"
                end

                local deadline=os.clock()+C.OfferVerifyTimeout
                local verified=false

                while sessionAlive() and os.clock()<deadline do
                    local verifyTrade=tradeRoot()
                    if not verifyTrade then
                        return finishTradeClosed("trade-closed-opening")
                    end

                    local found=yourOfferContains(verifyTrade,opener)
                    if found then
                        verified=true
                        break
                    end

                    task.wait(0.08)
                end

                if not verified then
                    p4Status(
                        "P4 SAFETY — adaptive opener was not verified in YOUR OFFER | stopping"
                    )
                    return "opening-offer-unverified"
                end

                openerPlaced=true
                print(
                    "[PDIDDLER P4] ADAPTIVE OPENER SELECT",
                    target.Name,
                    tostring(opener.name),
                    tostring(opener.value),
                    "exit",tostring(openerMeta and openerMeta.exitScore),
                    "reachable",tostring(openerMeta and openerMeta.partnerTop4Raw),
                    "| ACCEPT DISABLED"
                )
            end
        else
            print(
                "[PDIDDLER P4] ADAPTIVE OPENER NONE — no realistic candidate",
                target.Name,
                "partnerTop4",tostring(openerMeta and openerMeta.partnerTop4Raw),
                "| staying empty"
            )
        end
    end

    if openerPlaced then
        p4Status(
            "P4 — adaptive opener verified | waiting on THEIR OFFER | market snapshot "
            ..tostring(MARKET_PROFILE.snapshotDate or "unknown")
        )
    elseif openerSkipped then
        p4Status(
            "P4 — THEIR OFFER arrived first | responding to revealed intent | ACCEPT DISABLED"
        )
    else
        p4Status(
            "P4 — no realistic opener | waiting for THEIR OFFER | ACCEPT DISABLED"
        )
    end

    local offerStartedAt=nil
    local offerEverStarted=false
    local lastOfferWindowSecond=-1
    local lastTheirSig=nil
    local stableSince=nil
    local lastBalancedSig=nil
    local lastBalancedStep=-1
    local lastCountdown=-1
    local sweetenSince=nil
    local sweetenGeneration=nil
    local lastSweetenLogged=-1

    -- Rebalance transaction / recovery state.
    local offerGeneration=0

    -- PERF: safe-plan generation is expensive (dual-variant DP). It depends
    -- only on our frozen inventory + the exact THEIR offer generation.
    -- Sweetening changes ranking only, so never rebuild the planner for the
    -- same signature/generation.
    local cachedPlanSig=nil
    local cachedPlanGeneration=nil
    local cachedSafePlans=nil
    local cachedPlanWhy=nil

    local rebalanceSerial=0
    local recoveryNeeded=false
    local recoveryFailures=0
    local recoveryRetryAt=0
    local recoveryHoldSig=nil

    -- Human negotiation state is deliberately separate from technical
    -- OfferStability. A resolved offer can be parse-stable while the other
    -- player is still editing their bundle.
    local noPlanSig=nil
    local noPlanSince=nil
    local lastNoPlanSecond=-1

    local function clearNoPlanHold()
        noPlanSig=nil
        noPlanSince=nil
        lastNoPlanSecond=-1
    end

    local function clearPlanCache()
        cachedPlanSig=nil
        cachedPlanGeneration=nil
        cachedSafePlans=nil
        cachedPlanWhy=nil
    end

    local function safePlansForGeneration(theirEval)
        if cachedPlanSig==theirEval.signature
            and cachedPlanGeneration==offerGeneration
            and type(cachedSafePlans)=="table"
        then
            return cachedSafePlans,cachedPlanWhy,true
        end

        local plans,why=marketPlans(ownInv,theirEval)

        -- Cache only an actual planner result. Infrastructure/runtime failure
        -- stays retryable instead of becoming authoritative for the generation.
        if why~="market-planner-failed"
            and why~="market-planner-unavailable"
            and why~="their-market-unavailable"
            and type(plans)=="table"
        then
            cachedPlanSig=theirEval.signature
            cachedPlanGeneration=offerGeneration
            cachedSafePlans=plans
            cachedPlanWhy=why

            print(
                "[PDIDDLER P4] PLAN CACHE MISS",
                target.Name,
                "| gen",offerGeneration,
                "| plans",#plans
            )
        end

        return plans,why,false
    end

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

        if not target.Parent or Players:GetPlayerByUserId(target.UserId)~=target then
            invalidateWebhook("partner-left")
            return "partner-left"
        end

        -- Once Case 3 has ever started, this is the authoritative rotation
        -- deadline. Any non-fatal balancer/read issue is allowed to HOLD, but
        -- it cannot keep the trade alive past 60 seconds.
        if offerEverStarted and offerStartedAt then
            local elapsed=os.clock()-offerStartedAt

            if elapsed>=C.ActiveOfferWindow then
                local boundaryTrade=tradeRoot()

                if not boundaryTrade then
                    return finishTradeClosed("trade-closed-before-rotation")
                end

                local boundarySide=readSide(boundaryTrade,"TheirOffer")
                local boundaryAccepted=theirAcceptedShown(boundaryTrade)

                if boundarySide.slots==0 and boundaryAccepted then
                    declineTrade("accepted empty at 60s rotation boundary")
                    return "accepted-empty-declined"
                end

                scanner.setRequestState(
                    target,
                    "declined",
                    "P4 — 60s Case 3 test window complete | rotating to next player"
                )

                declineTrade("60s Case 3 rotation boundary")
                return "offer-window-timeout-declined"
            end
        end

        local latestRec=scanner.getRecord(target.UserId)
        local partnerInv=latestRec and latestRec.inv

        if not partnerInv then
            p4Status(
                "P4 SAFETY — partner inventory snapshot disappeared | holding, no Accept"
            )
            task.wait(C.LoopDelay)
            continue
        end

        local theirEval=evaluateSide(now,"TheirOffer",partnerInv)
        local ourEval=evaluateSide(now,"YourOffer",ownInv)

        refreshWebhookCandidate(ourEval,theirEval)

        if #ourEval.unresolved>0 then
            invalidateWebhook("our-offer-unresolved")
            if offerEverStarted then
                local remain=math.max(
                    0,
                    C.ActiveOfferWindow-(os.clock()-(offerStartedAt or os.clock()))
                )

                p4Status(
                    string.format(
                        "P4 PROTECTED HOLD — YOUR OFFER unresolved | %.0fs rotation window remaining | no rebalance, no Accept",
                        remain
                    )
                )

                task.wait(C.LoopDelay)
                continue
            end

            p4Status(
                "P4 SAFETY — YOUR OFFER became unresolved before Case 3 | declining to protect inventory"
            )
            declineTrade("our offer unresolved before Case 3")
            return "our-offer-unresolved"
        end

        if theirEval.slots==0 then
            invalidateWebhook("their-offer-empty")
            clearNoPlanHold()
            lastTheirSig=nil
            stableSince=nil
            lastBalancedSig=nil
            lastBalancedStep=-1
            sweetenSince=nil
            sweetenGeneration=nil
            lastSweetenLogged=-1
            clearPlanCache()

            local accepted,via=theirAcceptedShown(now)

            if accepted then
                scanner.setRequestState(
                    target,
                    "declined",
                    "P4 — THEY ACCEPTED WITH ZERO ITEMS | declining immediately"
                )
                p4Status(
                    "P4 — accepted-empty detected | immediate decline"
                )

                declineTrade("accepted empty via "..tostring(via))
                return "accepted-empty-declined"
            end

            if offerEverStarted then
                -- Once Case 3 has started, do not fall back to the short
                -- 15-second empty timer if they remove their items. The user
                -- wants the whole 60-second active-offer window for testing.
                local elapsed=os.clock()-(offerStartedAt or os.clock())
                local remain=math.max(0,C.ActiveOfferWindow-elapsed)
                local sec=math.ceil(remain)

                if sec~=lastOfferWindowSecond then
                    lastOfferWindowSecond=sec
                    p4Status(
                        string.format(
                            "P4 TEST WINDOW — they previously offered, now empty | %.0fs until rotate/decline | ACCEPT DISABLED",
                            remain
                        )
                    )
                end

                if elapsed>=C.ActiveOfferWindow then
                    local finalTrade=tradeRoot()
                    if not finalTrade then
                        return finishTradeClosed("trade-closed-by-partner")
                    end

                    local finalAccepted=theirAcceptedShown(finalTrade)
                    local finalSide=readSide(finalTrade,"TheirOffer")

                    if finalSide.slots==0 and finalAccepted then
                        declineTrade("accepted empty at 60s test-window boundary")
                        return "accepted-empty-declined"
                    end

                    scanner.setRequestState(
                        target,
                        "declined",
                        "P4 — 60s Case 3 test window complete | rotating to next player"
                    )

                    declineTrade("60s active-offer test window complete")
                    return "offer-window-timeout-declined"
                end

                task.wait(C.LoopDelay)
                continue
            end

            if not emptySince then
                emptySince=os.clock()
            end

            local elapsed=os.clock()-emptySince
            local remain=math.max(0,C.EmptyTimeout-elapsed)
            local sec=math.ceil(remain)

            if sec~=lastCountdown then
                lastCountdown=sec
                p4Status(
                    string.format(
                        "P4 — THEIR OFFER empty | %.0fs until decline | FINAL ACCEPT DISABLED",
                        remain
                    )
                )
            end

            if elapsed>=C.EmptyTimeout then
                -- Exact final recheck at timeout.
                local finalTrade=tradeRoot()
                local finalSide=finalTrade and readSide(finalTrade,"TheirOffer")

                if finalTrade and finalSide and finalSide.slots==0 then
                    local finalAccepted=theirAcceptedShown(finalTrade)

                    scanner.setRequestState(
                        target,
                        "declined",
                        finalAccepted
                            and "P4 — accepted empty at timeout | declined"
                            or "P4 — no item offered for 15s | declined"
                    )

                    declineTrade(
                        finalAccepted
                            and "accepted empty at timeout"
                            or "15s empty offer timeout"
                    )
                    return finalAccepted
                        and "accepted-empty-declined"
                        or "empty-timeout-declined"
                else
                    emptySince=nil
                    lastCountdown=-1
                end
            end

            task.wait(C.LoopDelay)
            continue
        end

        -- Their side became non-empty: Case 3 / balancer.
        emptySince=nil
        lastCountdown=-1

        if not offerEverStarted then
            offerEverStarted=true
            offerStartedAt=os.clock()
            lastOfferWindowSecond=-1

            print(
                "[PDIDDLER P4] CASE 3 START",
                target.Name,
                "| 60s active-offer test window"
            )
        end

        local offerElapsed=os.clock()-(offerStartedAt or os.clock())
        local offerRemain=math.max(0,C.ActiveOfferWindow-offerElapsed)
        local offerSec=math.ceil(offerRemain)

        if offerSec~=lastOfferWindowSecond then
            lastOfferWindowSecond=offerSec
            p4Status(
                string.format(
                    "P4 CASE 3 — %.0fs test window remaining | balancing active | ACCEPT DISABLED",
                    offerRemain
                )
            )
        end

        if offerElapsed>=C.ActiveOfferWindow then
            local finalTrade=tradeRoot()

            if not finalTrade then
                return finishTradeClosed("trade-closed-by-partner")
            end

            local finalSide=readSide(finalTrade,"TheirOffer")
            local finalAccepted=theirAcceptedShown(finalTrade)

            if finalSide.slots==0 and finalAccepted then
                declineTrade("accepted empty at 60s test-window boundary")
                return "accepted-empty-declined"
            end

            scanner.setRequestState(
                target,
                "declined",
                "P4 — 60s Case 3 test window complete | rotating to next player"
            )

            declineTrade("60s active-offer test window complete")
            return "offer-window-timeout-declined"
        end

        if theirEval.signature~=lastTheirSig then
            invalidateWebhook("their-offer-changed")
            clearNoPlanHold()
            lastTheirSig=theirEval.signature
            stableSince=os.clock()
            lastBalancedSig=nil
            lastBalancedStep=-1
            offerGeneration+=1
            clearPlanCache()
            sweetenSince=os.clock()
            sweetenGeneration=offerGeneration
            lastSweetenLogged=-1

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

        if sweetenGeneration~=offerGeneration or not sweetenSince then
            sweetenSince=os.clock()
            sweetenGeneration=offerGeneration
            lastSweetenLogged=-1
        end

        local currentSweetenStep=ACCEPTANCE_POLICY.sweetenStep(
            os.clock()-sweetenSince
        )

        if currentSweetenStep~=lastSweetenLogged then
            if currentSweetenStep>0 then
                print(
                    "[PDIDDLER P4] SWEETEN STEP",
                    target.Name,
                    tostring(currentSweetenStep).."/"..tostring(ACCEPTANCE_POLICY.MaxSweetenSteps or 2),
                    "| THEIR signature unchanged"
                )
            end
            lastSweetenLogged=currentSweetenStep
        end

        if lastBalancedSig==theirEval.signature
            and lastBalancedStep==currentSweetenStep
        then
            task.wait(C.LoopDelay)
            continue
        end

        if #theirEval.unresolved>0 then
            invalidateWebhook("their-offer-unresolved")
            clearNoPlanHold()
            lastBalancedSig=theirEval.signature
            lastBalancedStep=currentSweetenStep

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

        if recoveryNeeded then
            invalidateWebhook("recovery-active")
            clearNoPlanHold()
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
                lastBalancedSig=nil
                lastBalancedStep=-1
                sweetenSince=os.clock()
                sweetenGeneration=offerGeneration
                lastSweetenLogged=-1

                p4Status(
                    "P4 RECOVERY VERIFIED — OUR OFFER clean | revalidating THEIR OFFER before fresh plan | ACCEPT DISABLED"
                )

                task.wait(C.LoopDelay)
                continue
            else
                if recoverWhy=="their-offer-changed" then
                    lastTheirSig=nil
                    stableSince=nil
                    lastBalancedSig=nil
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

        local ourAccepted,ourAcceptedVia=ourAcceptedShown(now)
        if ourAccepted then
            scanner.setRequestState(
                target,
                "accepted",
                "P4 MANUAL ACCEPT HOLD — local Accept visible | freezing voluntary offer mutation"
            )
            p4Status(
                "P4 MANUAL ACCEPT HOLD — no opener/rebalance/sweeten while YOU HAVE ACCEPTED | waiting for completion/change"
            )
            print(
                "[PDIDDLER P4] MANUAL ACCEPT HOLD",
                target.Name,
                "| via",tostring(ourAcceptedVia),
                "| no voluntary mutation"
            )
            task.wait(C.LoopDelay)
            continue
        end

        local currentDecision=tradeDecision(ourEval,theirEval)
        local extreme=false
        local extremeInfo=nil

        if ourEval.slots>0 and currentDecision.ok then
            extreme,extremeInfo=
                extremeOneSided(currentDecision,ourEval,theirEval)
        end

        -- Generate safety-approved plans once per exact THEIR generation.
        -- Sweetening only re-ranks the cached safe set; it does not rerun the
        -- expensive dual-variant planner at 5s/10s or during no-plan grace.
        local plans,planWhy=safePlansForGeneration(theirEval)
        local okAppeal,rankedPlans,appealMeta=pcall(
            ACCEPTANCE_POLICY.rankSafePlans,
            plans,
            theirEval.market,
            currentSweetenStep
        )

        if not okAppeal or type(rankedPlans)~="table" then
            invalidateWebhook("acceptance-rank-failed")
            scanner.setRequestState(
                target,
                "sending",
                "P4 SAFETY — acceptance ranking failed | holding, no mutation"
            )
            p4Status(
                "P4 SAFETY — acceptance ranking failed | waiting for THEIR OFFER change | ACCEPT DISABLED"
            )
            lastBalancedSig=theirEval.signature
            lastBalancedStep=currentSweetenStep
            task.wait(C.LoopDelay)
            continue
        end

        plans=rankedPlans
        local plan=plans[1]
        local bestTier=appealMeta and appealMeta.bestTier or nil

        if #plans>0 and bestTier=="D" then
            -- A mathematically safe trade is not automatically worth showing.
            -- Do not force low-appeal inventory onto the counterparty.
            if ourEval.slots>0 and currentDecision.ok then
                verifyWebhookCandidate(
                    ourEval,
                    theirEval,
                    currentDecision,
                    "appeal-hold"
                )
            else
                invalidateWebhook("appeal-hold-no-current-safe-offer")
            end

            scanner.setRequestState(
                target,
                "sending",
                string.format(
                    "P4 APPEAL HOLD — safe plans exist but best tier D | sweeten %d/%d | waiting for THEIR change",
                    currentSweetenStep,
                    tonumber(ACCEPTANCE_POLICY.MaxSweetenSteps) or 2
                )
            )
            print(
                "[PDIDDLER P4] APPEAL HOLD",
                target.Name,
                "| tier D",
                "| sweeten",currentSweetenStep,
                "| no forced mutation"
            )
            lastBalancedSig=theirEval.signature
            lastBalancedStep=currentSweetenStep
            task.wait(C.LoopDelay)
            continue
        end

        if ourEval.slots>0 and currentDecision.ok and not extreme then
            local selectedAlreadyShown=
                (not plan)
                or planMatches(plan,ourEval)

            if selectedAlreadyShown then
                clearNoPlanHold()
                lastBalancedSig=theirEval.signature
                lastBalancedStep=currentSweetenStep
                verifyWebhookCandidate(
                    ourEval,
                    theirEval,
                    currentDecision,
                    "profitable-hold"
                )

                scanner.setRequestState(
                    target,
                    "accepted",
                    string.format(
                        "P4 PROFITABLE HOLD — %s/%s | appeal %s | sweeten %d/%d | RAW OUR %s THEIR %s PROFIT %+s | PROTECTED %+s | ACCEPT DISABLED",
                        currentDecision.kind,
                        currentDecision.mode,
                        tostring(bestTier or "?"),
                        currentSweetenStep,
                        tonumber(ACCEPTANCE_POLICY.MaxSweetenSteps) or 2,
                        fmt(ourEval.rawTotal),
                        fmt(theirEval.rawTotal),
                        fmt(currentDecision.rawProfit),
                        fmt(currentDecision.protectedProfit)
                    )
                )

                print(
                    "[PDIDDLER P4] PROFITABLE HOLD",
                    target.Name,
                    "kind",currentDecision.kind,
                    "mode",currentDecision.mode,
                    "appeal",tostring(bestTier or "?"),
                    "sweeten",currentSweetenStep,
                    "rawProfit",currentDecision.rawProfit,
                    "protectedProfit",currentDecision.protectedProfit,
                    "| ACCEPT DISABLED"
                )

                task.wait(C.LoopDelay)
                continue
            end
        end

        if ourEval.slots>0 and currentDecision.ok and extreme then
            local canRaise=
                plan
                and plan.rawTotal
                    >=ourEval.rawTotal+C.ExtremeMinReplanStep-0.0001
                and plan.rawProfit
                    <=currentDecision.rawProfit-C.ExtremeMinReplanStep+0.0001

            if not canRaise then
                clearNoPlanHold()
                lastBalancedSig=theirEval.signature
                lastBalancedStep=currentSweetenStep
                verifyWebhookCandidate(
                    ourEval,
                    theirEval,
                    currentDecision,
                    "extreme-hold"
                )

                scanner.setRequestState(
                    target,
                    "accepted",
                    string.format(
                        "P4 EXTREME HOLD — RAW OUR %s THEIR %s PROFIT %+s ratio %.2fx | no higher safe plan | ACCEPT DISABLED",
                        fmt(ourEval.rawTotal),
                        fmt(theirEval.rawTotal),
                        fmt(currentDecision.rawProfit),
                        tonumber(extremeInfo and extremeInfo.ratio) or 0
                    )
                )

                print(
                    "[PDIDDLER P4] EXTREME HOLD",
                    target.Name,
                    "ours",ourEval.rawTotal,
                    "theirs",theirEval.rawTotal,
                    "rawProfit",currentDecision.rawProfit,
                    "ratio",tonumber(extremeInfo and extremeInfo.ratio) or 0,
                    "| no higher safe plan",
                    "| ACCEPT DISABLED"
                )

                task.wait(C.LoopDelay)
                continue
            end

            p4Status(
                string.format(
                    "P4 EXTREME REPLAN — RAW OUR %s THEIR %s PROFIT %+s ratio %.2fx | moving OUR -> %s | target profit %+s",
                    fmt(ourEval.rawTotal),
                    fmt(theirEval.rawTotal),
                    fmt(currentDecision.rawProfit),
                    tonumber(extremeInfo and extremeInfo.ratio) or 0,
                    fmt(plan.rawTotal),
                    fmt(plan.rawProfit)
                )
            )

            print(
                "[PDIDDLER P4] EXTREME REPLAN",
                target.Name,
                "ours",ourEval.rawTotal,
                "theirs",theirEval.rawTotal,
                "rawProfit",currentDecision.rawProfit,
                "ratio",tonumber(extremeInfo and extremeInfo.ratio) or 0,
                "rawFloor",tonumber(extremeInfo and extremeInfo.rawFloor) or 0,
                "protectedFloor",tonumber(extremeInfo and extremeInfo.protectedFloor) or 0,
                "newOur",plan.rawTotal,
                "targetProfit",plan.rawProfit,
                "| ACCEPT DISABLED"
            )
        end

        if #plans==0 then
            invalidateWebhook("no-safe-plan")

            -- The offer is technically stable, but that does not mean the
            -- human trader is finished editing it. Bind this grace timer to
            -- the exact THEIR OFFER signature. Any offer mutation clears the
            -- timer above before this branch can run again.
            if noPlanSig~=theirEval.signature or not noPlanSince then
                noPlanSig=theirEval.signature
                noPlanSince=os.clock()
                lastNoPlanSecond=-1

                print(
                    "[PDIDDLER P4] NO PLAN HOLD START",
                    target.Name,
                    "ours",ourEval.rawTotal,
                    "theirs",theirEval.rawTotal,
                    "planner",tostring(planWhy or "no-safe-plan"),
                    "| grace",C.NoPlanNegotiationGrace,
                    "| ACCEPT DISABLED"
                )
            end

            local held=os.clock()-(noPlanSince or os.clock())
            local remain=math.max(0,C.NoPlanNegotiationGrace-held)
            local sec=math.ceil(remain)

            if sec~=lastNoPlanSecond then
                lastNoPlanSecond=sec
                scanner.setRequestState(
                    target,
                    "sending",
                    string.format(
                        "P4 NO PLAN HOLD — RAW OUR %s THEIR %s | waiting %.0fs for THEIR OFFER change | ACCEPT DISABLED",
                        fmt(ourEval.rawTotal),
                        fmt(theirEval.rawTotal),
                        remain
                    )
                )
            end

            if held<C.NoPlanNegotiationGrace then
                task.wait(C.LoopDelay)
                continue
            end

            -- Final signature/session recheck immediately before decline.
            local finalTrade=tradeRoot()
            if not finalTrade then
                return finishTradeClosed("trade-closed-before-no-plan-decline")
            end

            local finalRec=scanner.getRecord(target.UserId)
            local finalInv=finalRec and finalRec.inv
            if not finalInv then
                clearNoPlanHold()
                task.wait(C.LoopDelay)
                continue
            end

            local finalTheir=evaluateSide(finalTrade,"TheirOffer",finalInv)

            if finalTheir.signature~=noPlanSig then
                clearNoPlanHold()
                lastTheirSig=nil
                stableSince=nil
                lastBalancedSig=nil
                task.wait(C.LoopDelay)
                continue
            end

            print(
                "[PDIDDLER P4] NO PLAN DECLINE",
                target.Name,
                "ours",ourEval.rawTotal,
                "theirs",finalTheir.rawTotal,
                "planner",tostring(planWhy or "no-safe-plan"),
                "| unchanged for",string.format("%.2f",held).."s",
                "| declining trade",
                "| ACCEPT DISABLED"
            )

            local declined,declineWhy=declineTrade("no-safe-plan-after-grace")

            if not declined then
                scanner.setRequestState(
                    target,
                    "sendfailed",
                    "P4 NO PLAN — decline failed/timeout after grace | rotation stopped for this trade"
                )
                p4Status(
                    "P4 SAFETY — no-plan decline failed after grace: "
                    ..tostring(declineWhy)
                    .." | ACCEPT DISABLED"
                )
                return "no-safe-plan-decline-failed"
            end

            clearNoPlanHold()
            return finishTradeClosed("no-safe-plan-declined-after-grace")
        end

        -- A safe candidate exists for the current exact offer, so any prior
        -- no-plan grace belongs to an obsolete planning state.
        clearNoPlanHold()

        if not plan then
            lastBalancedSig=theirEval.signature
            lastBalancedStep=currentSweetenStep
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

        if not applied then
            -- Any failure after a mutation means our current offer is no longer
            -- authoritative. Never stack a fresh plan on top of it.
            if modified then
                recoveryNeeded=true
                recoveryRetryAt=os.clock()+C.RecoveryRetryDelay
                sweetenSince=os.clock()
                sweetenGeneration=offerGeneration
                lastSweetenLogged=-1
            end

            if why=="their-offer-changed" then
                lastTheirSig=nil
                stableSince=nil
                lastBalancedSig=nil

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
                lastBalancedSig=theirEval.signature
                lastBalancedStep=currentSweetenStep
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
            lastTheirSig=nil
            stableSince=nil
            lastBalancedSig=nil
            task.wait(C.LoopDelay)
            continue
        end

        local finalDecision=tradeDecision(ourFinal,theirFinal)

        if finalDecision.ok then
            lastBalancedSig=theirFinal.signature
            lastBalancedStep=currentSweetenStep
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
            invalidateWebhook("decision-unsafe")
            lastBalancedSig=nil
            lastBalancedStep=-1
        end

        task.wait(C.LoopDelay)
    end

    invalidateWebhook("stale-session")
    return "stale-session"
end

function M.run(scanner,marketProfile,marketLogic,marketPlanner,acceptancePolicy,tradeTelemetry)
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

    local coverage=marketProfile.coverage()
    assert(type(coverage)=="table" and tonumber(coverage.total)==190,
        "marketProfile coverage must be 190")

    assert(type(marketLogic)=="table","marketLogic required")
    assert(type(marketLogic.itemAssessment)=="function","marketLogic.itemAssessment missing")
    assert(type(marketLogic.bundleAssessment)=="function","marketLogic.bundleAssessment missing")
    assert(type(marketLogic.tradeDecision)=="function","marketLogic.tradeDecision missing")
    assert(type(marketLogic.rankPlans)=="function","marketLogic.rankPlans missing")

    assert(type(marketPlanner)=="table","marketPlanner required")
    assert(type(marketPlanner.buildPlans)=="function","marketPlanner.buildPlans missing")
    assert(type(marketPlanner.planMatches)=="function","marketPlanner.planMatches missing")

    assert(type(acceptancePolicy)=="table","acceptancePolicy required")
    assert(type(acceptancePolicy.OpenerObserveSeconds)=="number","acceptancePolicy.OpenerObserveSeconds missing")
    assert(type(acceptancePolicy.selectOpener)=="function","acceptancePolicy.selectOpener missing")
    assert(type(acceptancePolicy.sweetenStep)=="function","acceptancePolicy.sweetenStep missing")
    assert(type(acceptancePolicy.rankSafePlans)=="function","acceptancePolicy.rankSafePlans missing")

    assert(type(tradeTelemetry)=="table","tradeTelemetry required")
    assert(type(tradeTelemetry.build)=="function","tradeTelemetry.build missing")

    MARKET_PROFILE=marketProfile
    MARKET_LOGIC=marketLogic
    MARKET_PLANNER=marketPlanner
    ACCEPTANCE_POLICY=acceptancePolicy

    local SESSION=(tonumber(ENV.PDIDDLER_PART4_SESSION) or 0)+1
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
            "| adaptive opener + acceptance-aware ranking active",
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
                        clearWebhookCandidate
                    )

                    print(
                        "[PDIDDLER P4] TRADE RESULT",
                        tostring(S.result)
                    )
                    clearWebhookCandidate("trade-closed")

                    -- One runTrade per visible trade instance. When the GUI
                    -- fully disappears, observer rearms for the next trade.
                    while alive() and tradeRoot() do
                        task.wait(0.08)
                    end

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

    return {
        session=SESSION,
        state=S,
        stop=function()
            if ENV.PDIDDLER_PART4_SESSION==SESSION then
                ENV.PDIDDLER_PART4_SESSION=SESSION+1
            end
        end,
    }
end

return M
