-- pdiddler Part 4 balancer ROTATION PERF TEST v2.0
-- Scope:
--   * observe an active MM2 trade handed off by known-good Part 3
--   * offer exactly ONE highest-valued eligible item from our verified inventory
--   * accepted-empty => decline immediately
--   * empty/no-action => decline after 15 seconds
--   * non-empty => stabilize, value, and rebalance our side
--   * balanced-aggressive raw-value thresholds
--   * FINAL TRADE ACCEPT IS ABSOLUTELY DISABLED
--
-- Market-quality snapshot: MM2Values stability tags checked 2026-11-02.
-- Unlisted eligible Godly/Chroma/Ancient items default to verified Stable.
-- FINAL ACCEPT remains disabled regardless of score.

local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local GuiService=game:GetService("GuiService")
local VIM=game:GetService("VirtualInputManager")

local LP=Players.LocalPlayer
local PG=LP and LP:FindFirstChildOfClass("PlayerGui")
local ENV=(getgenv and getgenv()) or _G

local M={}

local C={
    TradeAppearStability=0.30,
    OfferVerifyTimeout=3.0,
    EmptyTimeout=15.0,
    ActiveOfferWindow=60.0,
    OfferStability=0.65,
    RemoveVerifyTimeout=0.90,
    RemoveRetryVerifyTimeout=1.20,
    RemoveRetryGuard=0.25,
    RecoveryRetryDelay=0.75,
    RecoveryMaxAttemptsPerOffer=2,
    ApplyVerifyTimeout=2.5,
    LoopDelay=0.12,

    NormalMinFlat=15,
    NormalMinPct=0.03,

    DowngradeMinFlat=20,
    DowngradeMinPct=0.06,

    BigDowngradeMinFlat=30,
    BigDowngradeMinPct=0.08,

    UpgradeOverpayCapPct=0.03,

    -- Avoid human-unrealistic offers such as their 80 vs our 8.
    -- A valid trade has a minimum profit AND a preferred upper band.
    -- If profit is far above this band and we own a closer safe offer,
    -- rebalance upward to the highest-value still-profitable combination.
    NormalProfitBandExtraFlat=15,
    NormalProfitBandExtraPct=0.03,
    DowngradeProfitBandExtraFlat=20,
    DowngradeProfitBandExtraPct=0.04,
    BigDowngradeProfitBandExtraFlat=25,
    BigDowngradeProfitBandExtraPct=0.05,
    RebalanceMinValueStep=5,
}

local MARKET_QUALITY_UPDATED="2026-11-02"

-- Stability multipliers are intentionally small/capped:
--   Overpaid For +5%, Doing Well +3%, Stable 0%,
--   Fluctuating -2%, Underpaid For -8%.
-- These are decision modifiers, NOT replacement MM2Values prices.
local MARKET_QUALITY={
    -- Godly
    ["darkshot"]={mult=0.92,tag="Underpaid For"},
    ["darksword"]={mult=0.92,tag="Underpaid For"},
    ["mortal"]={mult=0.98,tag="Fluctuating"},
    ["immortal"]={mult=0.98,tag="Fluctuating"},
    ["embersickle"]={mult=0.92,tag="Underpaid For"},

    -- Ancient
    ["niksscythe"]={mult=1.05,tag="Overpaid For"},
    ["vampiresaxe"]={mult=1.03,tag="Doing Well"},
    ["emberbow"]={mult=0.92,tag="Underpaid For"},
    ["emberscythe"]={mult=0.92,tag="Underpaid For"},

    -- Chroma
    ["chromaemberscythe"]={mult=0.98,tag="Fluctuating"},
    ["chromaemberbow"]={mult=0.98,tag="Fluctuating"},
    ["chromamortal"]={mult=0.98,tag="Fluctuating"},
    ["chromaimmortal"]={mult=0.98,tag="Fluctuating"},
    ["chromaembersickle"]={mult=0.92,tag="Underpaid For"},
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

local function exactQuality(it)
    if not it then
        return {mult=1,tag="unknown",reject=false,verified=false}
    end

    local rec=
        MARKET_QUALITY[tostring(it.id or "")]
        or MARKET_QUALITY[norm(it.name)]

    if type(rec)~="table" then
        return {mult=1,tag="Stable",reject=false,verified=true}
    end

    return {
        mult=tonumber(rec.mult) or 1,
        tag=tostring(rec.tag or "verified"),
        reject=rec.reject==true,
        verified=true,
    }
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
            or tonumber(x.value)~=tonumber(first.value)
        then
            return nil,"ambiguous"
        end
    end

    return {
        id=first.id,
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
        effectiveTotal=0,
        eligibleCopies=0,
        resolved={},
        unresolved={},
        rejected={},
        counts={},
    }

    for _,entry in ipairs(side.entries) do
        local item,why=resolveEntry(entry,inv)

        if item then
            local qty=math.max(1,tonumber(item.qty) or 1)
            local q=exactQuality(item)
            local raw=(tonumber(item.value) or 0)*qty
            local effective=raw*(tonumber(q.mult) or 1)

            out.rawTotal+=raw
            out.effectiveTotal+=effective

            if not item.ineligible then
                out.eligibleCopies+=qty
            end

            if q.reject then
                out.rejected[#out.rejected+1]=
                    tostring(item.name).." ["..q.tag.."]"
            end

            local id=tostring(item.id or fullShownName(entry))
            out.counts[id]=(out.counts[id] or 0)+qty

            out.resolved[#out.resolved+1]={
                id=id,
                name=item.name,
                rawValue=tonumber(item.value) or 0,
                qty=qty,
                rawSubtotal=raw,
                effectiveSubtotal=effective,
                quality=q,
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

    local sig={}
    for _,r in ipairs(out.resolved) do
        sig[#sig+1]=table.concat({
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

local function highestOwn(inv)
    if not inv or type(inv.items)~="table" then return nil end

    local best=nil
    for _,it in ipairs(inv.items) do
        local qty=tonumber(it.qty) or 0
        local value=tonumber(it.value)

        if qty>0 and value and value>0 and tostring(it.id or "")~="" then
            if not best
                or value>(tonumber(best.value) or 0)
                or (
                    value==(tonumber(best.value) or 0)
                    and tostring(it.id)<tostring(best.id)
                )
            then
                best=it
            end
        end
    end

    return best
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

local function requiredProfit(ourValue,ourCopies,theirCopies)
    ourValue=math.max(0,tonumber(ourValue) or 0)
    ourCopies=math.max(0,tonumber(ourCopies) or 0)
    theirCopies=math.max(0,tonumber(theirCopies) or 0)

    if ourCopies==1 and theirCopies>=3 then
        return math.max(
            C.BigDowngradeMinFlat,
            ourValue*C.BigDowngradeMinPct
        ),"BIG DOWNGRADE"
    end

    if theirCopies>ourCopies then
        return math.max(
            C.DowngradeMinFlat,
            ourValue*C.DowngradeMinPct
        ),"DOWNGRADE"
    end

    return math.max(
        C.NormalMinFlat,
        ourValue*C.NormalMinPct
    ),theirCopies<ourCopies and "UPGRADE" or "NORMAL"
end


local function qualityRatio(ev)
    local raw=tonumber(ev and ev.rawTotal) or 0
    local effective=tonumber(ev and ev.effectiveTotal) or raw
    if raw<=0 then return 1 end
    return effective/raw
end

local function tradeDecision(ourEval,theirEval)
    local ourRaw=tonumber(ourEval and ourEval.rawTotal) or 0
    local theirRaw=tonumber(theirEval and theirEval.rawTotal) or 0
    local ourEff=tonumber(ourEval and ourEval.effectiveTotal) or ourRaw
    local theirEff=tonumber(theirEval and theirEval.effectiveTotal) or theirRaw
    local ourCopies=tonumber(ourEval and (ourEval.eligibleCopies>0 and ourEval.eligibleCopies or ourEval.slots)) or 0
    local theirCopies=tonumber(theirEval and theirEval.eligibleCopies) or 0

    local rawRequired,kind=requiredProfit(
        ourRaw,
        ourCopies,
        theirCopies
    )

    local effectiveRequired=math.max(
        rawRequired,
        ourEff*(
            kind=="BIG DOWNGRADE" and C.BigDowngradeMinPct
            or kind=="DOWNGRADE" and C.DowngradeMinPct
            or C.NormalMinPct
        )
    )

    local rawProfit=theirRaw-ourRaw
    local effectiveProfit=theirEff-ourEff

    if rawProfit>=rawRequired-0.0001
        and effectiveProfit>=effectiveRequired-0.0001
    then
        return {
            ok=true,
            kind=kind,
            mode="profit",
            rawProfit=rawProfit,
            effectiveProfit=effectiveProfit,
            rawRequired=rawRequired,
            effectiveRequired=effectiveRequired,
            qualityGain=qualityRatio(theirEval)-qualityRatio(ourEval),
        }
    end

    -- Controlled upgrade exception:
    -- only when consolidating OUR multiple eligible copies into fewer received
    -- copies, their market quality is materially better, raw loss is <=3%,
    -- and effective value does not decrease.
    if kind=="UPGRADE"
        and ourCopies>theirCopies
        and theirCopies>0
    then
        local maxRawLoss=ourRaw*C.UpgradeOverpayCapPct
        local qualityGain=qualityRatio(theirEval)-qualityRatio(ourEval)

        if rawProfit<rawRequired
            and rawProfit>=-maxRawLoss-0.0001
            and qualityGain>=0.03-0.0001
            and effectiveProfit>=-0.0001
        then
            return {
                ok=true,
                kind=kind,
                mode="quality-upgrade",
                rawProfit=rawProfit,
                effectiveProfit=effectiveProfit,
                rawRequired=rawRequired,
                effectiveRequired=0,
                qualityGain=qualityGain,
            }
        end
    end

    return {
        ok=false,
        kind=kind,
        mode="underpay",
        rawProfit=rawProfit,
        effectiveProfit=effectiveProfit,
        rawRequired=rawRequired,
        effectiveRequired=effectiveRequired,
        qualityGain=qualityRatio(theirEval)-qualityRatio(ourEval),
    }
end

local function preferredProfitCeiling(decision,theirEval)
    decision=type(decision)=="table" and decision or {}
    local required=tonumber(decision.rawRequired) or 0
    local theirRaw=tonumber(theirEval and theirEval.rawTotal) or 0
    local kind=tostring(decision.kind or "NORMAL")

    local extraFlat=C.NormalProfitBandExtraFlat
    local extraPct=C.NormalProfitBandExtraPct

    if kind=="BIG DOWNGRADE" then
        extraFlat=C.BigDowngradeProfitBandExtraFlat
        extraPct=C.BigDowngradeProfitBandExtraPct
    elseif kind=="DOWNGRADE" then
        extraFlat=C.DowngradeProfitBandExtraFlat
        extraPct=C.DowngradeProfitBandExtraPct
    end

    return required+math.max(
        tonumber(extraFlat) or 0,
        theirRaw*(tonumber(extraPct) or 0)
    )
end

local function planCounts(plan)
    local counts={}
    for _,p in ipairs(plan.picks or {}) do
        counts[tostring(p.id)]=(counts[tostring(p.id)] or 0)
            +(tonumber(p.qty) or 1)
    end
    return counts
end

local function makeUnits(inv)
    local out={}

    for _,it in ipairs((inv and inv.items) or {}) do
        local value=tonumber(it.value)
        local q=exactQuality(it)

        if value and value>0 and not q.reject then
            local qty=math.min(4,math.max(0,tonumber(it.qty) or 0))
            for copy=1,qty do
                out[#out+1]={
                    id=tostring(it.id),
                    name=tostring(it.name or it.id),
                    value=value,
                    effective=value*(tonumber(q.mult) or 1),
                    quality=q,
                    copy=copy,
                }
            end
        end
    end

    table.sort(out,function(a,b)
        if a.value~=b.value then return a.value<b.value end
        if a.id~=b.id then return a.id<b.id end
        return a.copy<b.copy
    end)

    return out
end

local function aggregateUnits(list)
    local byId={}
    local order={}

    for _,u in ipairs(list) do
        local k=tostring(u.id)
        if not byId[k] then
            byId[k]={
                id=u.id,
                name=u.name,
                value=u.value,
                effective=u.effective,
                qty=0,
            }
            order[#order+1]=k
        end
        byId[k].qty+=1
    end

    local out={}
    for _,k in ipairs(order) do
        out[#out+1]=byId[k]
    end
    return out
end

local function buildPlans(inv,theirEval)
    local units=makeUnits(inv)

    -- dp[slots][raw cents] = best (lowest effective value) unit list
    -- for that exact raw total. This matters once market-quality modifiers
    -- differ between items with the same listed value.
    local dp={
        [0]={[0]={list={},effective=0}},
        [1]={},
        [2]={},
        [3]={},
        [4]={},
    }

    for _,u in ipairs(units) do
        local cents=math.floor(u.value*100+0.5)

        for slots=4,1,-1 do
            local additions={}

            for sum,pack in pairs(dp[slots-1]) do
                local ns=sum+cents
                local neff=(tonumber(pack.effective) or 0)
                    +(tonumber(u.effective) or tonumber(u.value) or 0)

                local existing=dp[slots][ns] or additions[ns]

                if not existing
                    or neff<(tonumber(existing.effective) or math.huge)-0.0001
                then
                    local nl={}
                    for i=1,#pack.list do nl[i]=pack.list[i] end
                    nl[#nl+1]=u

                    additions[ns]={
                        list=nl,
                        effective=neff,
                    }
                end
            end

            for ns,pack in pairs(additions) do
                local existing=dp[slots][ns]
                if not existing
                    or pack.effective<(tonumber(existing.effective) or math.huge)-0.0001
                then
                    dp[slots][ns]=pack
                end
            end
        end
    end

    local plans={}

    for slots=1,4 do
        for cents,pack in pairs(dp[slots]) do
            local raw=cents/100

            local pseudoOur={
                rawTotal=raw,
                effectiveTotal=pack.effective,
                eligibleCopies=slots,
                slots=slots,
            }

            local decision=tradeDecision(pseudoOur,theirEval)

            if raw>0 and decision.ok then
                plans[#plans+1]={
                    picks=aggregateUnits(pack.list),
                    units=slots,
                    rawTotal=raw,
                    effectiveTotal=pack.effective,
                    rawProfit=decision.rawProfit,
                    effectiveProfit=decision.effectiveProfit,
                    requiredProfit=decision.rawRequired,
                    requiredEffective=decision.effectiveRequired,
                    kind=decision.kind,
                    mode=decision.mode,
                    qualityGain=decision.qualityGain,
                }
            end
        end
    end

    table.sort(plans,function(a,b)
        -- PRIMARY GOAL: a real profit plan. A controlled quality-upgrade
        -- overpay is only a fallback when there is no profitable plan.
        if a.mode~=b.mode then
            if a.mode=="profit" then return true end
            if b.mode=="profit" then return false end
        end

        -- Within the same plan class, choose the HIGHEST raw value that still
        -- passes every safety threshold: closest realistic profitable offer,
        -- not the cheapest item we can get away with.
        if a.rawTotal~=b.rawTotal then
            return a.rawTotal>b.rawTotal
        end
        if a.effectiveTotal~=b.effectiveTotal then
            return a.effectiveTotal<b.effectiveTotal
        end
        if a.units~=b.units then
            return a.units<b.units
        end
        return tostring(a.picks[1] and a.picks[1].id or "")
            <tostring(b.picks[1] and b.picks[1].id or "")
    end)

    return plans
end

local function planMatches(plan,live)
    if not plan or not live or #live.unresolved>0 then return false end
    if math.abs(live.rawTotal-plan.rawTotal)>0.001 then return false end

    local expected=planCounts(plan)
    for id,qty in pairs(expected) do
        if (live.counts[id] or 0)~=qty then return false end
    end
    for id,qty in pairs(live.counts) do
        if (expected[id] or 0)~=qty then return false end
    end

    return true
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
                local alreadyThere=(ours.counts[tostring(p.id)] or 0)>0
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

local function runTrade(scanner,session,sessionAlive)
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

    local highest=highestOwn(ownInv)
    if not highest then
        p4Status("P4 — no eligible own item available")
        return "no-own-item"
    end

    local tradeFolder=RS:FindFirstChild("Trade")
    local offer=tradeFolder and tradeFolder:FindFirstChild("OfferItem")

    if not offer or not offer:IsA("RemoteEvent") then
        p4Status("P4 SAFETY — OfferItem remote unavailable")
        return "offer-remote-missing"
    end

    scanner.setRequestState(
        target,
        "accepted",
        string.format(
            "P4 OPENING — placing highest own item: %s (%s) | FINAL ACCEPT DISABLED",
            tostring(highest.name),
            fmt(highest.value)
        )
    )

    local fired=pcall(function()
        offer:FireServer(highest.id,"Weapons")
    end)

    if not fired then
        p4Status("P4 — opening OfferItem call failed")
        return "opening-offer-fire-failed"
    end

    local deadline=os.clock()+C.OfferVerifyTimeout
    local verified=false

    while sessionAlive() and os.clock()<deadline do
        local now=tradeRoot()
        if not now then return "trade-closed-opening" end

        local found=yourOfferContains(now,highest)
        if found then
            verified=true
            break
        end

        task.wait(0.08)
    end

    if not verified then
        p4Status(
            "P4 SAFETY — opening item was not verified in YOUR OFFER | stopping"
        )
        return "opening-offer-unverified"
    end

    print(
        "[PDIDDLER P4] OPENING VERIFIED",
        target.Name,
        tostring(highest.name),
        tostring(highest.value),
        "| FINAL ACCEPT DISABLED"
    )

    p4Status(
        string.format(
            "P4 — opening verified: %s (%s) | waiting on THEIR OFFER | market snapshot "..MARKET_QUALITY_UPDATED,
            tostring(highest.name),
            fmt(highest.value)
        )
    )

    local emptySince=os.clock()
    local offerStartedAt=nil
    local offerEverStarted=false
    local lastOfferWindowSecond=-1
    local lastTheirSig=nil
    local stableSince=nil
    local lastBalancedSig=nil
    local lastCountdown=-1

    -- Rebalance transaction / recovery state.
    local offerGeneration=0
    local rebalanceSerial=0
    local recoveryNeeded=false
    local recoveryFailures=0
    local recoveryRetryAt=0
    local recoveryHoldSig=nil

    while sessionAlive() do
        local now=tradeRoot()
        if not now then
            scanner.setRequestState(
                target,
                "processed",
                "P4 — trade closed/cancelled before our timeout | returning to Part 3 rotation"
            )
            return "trade-closed"
        end

        if not target.Parent or Players:GetPlayerByUserId(target.UserId)~=target then
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
                    return "trade-closed-before-rotation"
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

        if #ourEval.unresolved>0 then
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
            lastTheirSig=nil
            stableSince=nil
            lastBalancedSig=nil

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
                        return "trade-closed-by-partner"
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
                return "trade-closed-by-partner"
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
            lastTheirSig=theirEval.signature
            stableSince=os.clock()
            lastBalancedSig=nil
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

        if lastBalancedSig==theirEval.signature then
            task.wait(C.LoopDelay)
            continue
        end

        if #theirEval.unresolved>0 then
            lastBalancedSig=theirEval.signature

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

        if #theirEval.rejected>0 then
            lastBalancedSig=theirEval.signature

            scanner.setRequestState(
                target,
                "sending",
                string.format(
                    "P4 RISK HOLD — rejected-risk item detected | %.0fs test window remaining | will not Accept",
                    offerRemain
                )
            )

            task.wait(C.LoopDelay)
            continue
        end

        if recoveryNeeded then
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
                    return "trade-closed-during-recovery"
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

                if recoverWhy=="trade-closed"
                    or recoverWhy=="stale-session"
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

        local currentDecision=tradeDecision(ourEval,theirEval)
        local currentCeiling=preferredProfitCeiling(
            currentDecision,
            theirEval
        )

        local plans=buildPlans(ownInv,theirEval)
        local plan=plans[1]

        if ourEval.slots>0 and currentDecision.ok then
            local overPreferredBand=
                currentDecision.mode=="profit"
                and currentDecision.rawProfit>currentCeiling+0.0001

            local closerPlan=
                overPreferredBand
                and plan
                and plan.rawTotal
                    >=ourEval.rawTotal+C.RebalanceMinValueStep-0.0001
                and plan.rawProfit
                    <currentDecision.rawProfit-C.RebalanceMinValueStep+0.0001

            if not closerPlan then
                lastBalancedSig=theirEval.signature

                scanner.setRequestState(
                    target,
                    "accepted",
                    string.format(
                        "P4 PROFITABLE HOLD — %s/%s | RAW OUR %s THEIR %s PROFIT %+s | PREFERRED <= +%s | EFFECTIVE PROFIT %+s | ACCEPT DISABLED",
                        currentDecision.kind,
                        currentDecision.mode,
                        fmt(ourEval.rawTotal),
                        fmt(theirEval.rawTotal),
                        fmt(currentDecision.rawProfit),
                        fmt(currentCeiling),
                        fmt(currentDecision.effectiveProfit)
                    )
                )

                print(
                    "[PDIDDLER P4] PROFITABLE HOLD",
                    target.Name,
                    "kind",currentDecision.kind,
                    "mode",currentDecision.mode,
                    "rawProfit",currentDecision.rawProfit,
                    "preferredCeiling",currentCeiling,
                    "effectiveProfit",currentDecision.effectiveProfit,
                    "qualityGain",currentDecision.qualityGain,
                    "| ACCEPT DISABLED"
                )

                task.wait(C.LoopDelay)
                continue
            end

            -- Current offer is technically profitable but implausibly one-sided.
            -- Move OUR side upward to the closest verified safe plan instead of
            -- sitting on an 80-vs-8 / +167 style offer.
            p4Status(
                string.format(
                    "P4 NORMALIZE PROFIT — current +%s exceeds preferred +%s | moving OUR %s -> %s | target profit %+s",
                    fmt(currentDecision.rawProfit),
                    fmt(currentCeiling),
                    fmt(ourEval.rawTotal),
                    fmt(plan.rawTotal),
                    fmt(plan.rawProfit)
                )
            )
        elseif #plans==0 then
            lastBalancedSig=theirEval.signature

            scanner.setRequestState(
                target,
                "sending",
                string.format(
                    "P4 UNDERPAY — RAW OUR %s THEIR %s | EFFECTIVE OUR %s THEIR %s | no valid 1-4 item plan yet | waiting for offer change",
                    fmt(ourEval.rawTotal),
                    fmt(theirEval.rawTotal),
                    fmt(ourEval.effectiveTotal),
                    fmt(theirEval.effectiveTotal)
                )
            )

            print(
                "[PDIDDLER P4] NO PLAN",
                target.Name,
                "ours",ourEval.rawTotal,
                "theirs",theirEval.rawTotal
            )

            task.wait(C.LoopDelay)
            continue
        end

        if not plan then
            lastBalancedSig=theirEval.signature
            task.wait(C.LoopDelay)
            continue
        end

        p4Status(
            string.format(
                "P4 REBALANCE — closest safe %s/%s | replacing RAW OUR %s with %s | target raw profit %+s | effective %+s",
                plan.kind,
                plan.mode,
                fmt(ourEval.rawTotal),
                fmt(plan.rawTotal),
                fmt(plan.rawProfit),
                fmt(plan.effectiveProfit)
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

            if why=="trade-closed"
                or why=="stale-session"
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
            end

            task.wait(C.LoopDelay)
            continue
        end

        recoveryNeeded=false
        recoveryFailures=0
        recoveryRetryAt=0
        recoveryHoldSig=nil

        local verifyTrade=tradeRoot()
        if not verifyTrade then return "trade-closed-after-rebalance" end

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

            scanner.setRequestState(
                target,
                "accepted",
                string.format(
                    "P4 REBALANCED — %s/%s | RAW OUR %s THEIR %s PROFIT %+s | EFFECTIVE PROFIT %+s | ACCEPT DISABLED",
                    finalDecision.kind,
                    finalDecision.mode,
                    fmt(ourFinal.rawTotal),
                    fmt(theirFinal.rawTotal),
                    fmt(finalDecision.rawProfit),
                    fmt(finalDecision.effectiveProfit)
                )
            )

            print(
                "[PDIDDLER P4] REBALANCE VERIFIED",
                target.Name,
                "| tx",tx.id,
                "kind",finalDecision.kind,
                "mode",finalDecision.mode,
                "rawProfit",finalDecision.rawProfit,
                "effectiveProfit",finalDecision.effectiveProfit,
                "| ACCEPT DISABLED"
            )
        else
            lastBalancedSig=nil
        end

        task.wait(C.LoopDelay)
    end

    return "stale-session"
end

function M.run(scanner)
    assert(type(scanner)=="table","scanner API required")
    assert(type(scanner.getRecord)=="function","scanner.getRecord missing")
    assert(type(scanner.getOwnInventory)=="function","scanner.getOwnInventory missing")
    assert(type(scanner.setStatus)=="function","scanner.setStatus missing")
    assert(type(scanner.claimStatusOwner)=="function","scanner.claimStatusOwner missing")
    assert(type(scanner.releaseStatusOwner)=="function","scanner.releaseStatusOwner missing")
    assert(type(scanner.setRequestState)=="function","scanner.setRequestState missing")

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
    }

    task.spawn(function()
        print(
            "[PDIDDLER P4] ARMED",
            "session",SESSION,
            "| balanced-aggressive thresholds active",
            "| MM2Values stability modifiers active "..MARKET_QUALITY_UPDATED,
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
                        return alive()
                            and token==SESSION
                            and tradeRoot()~=nil
                    end

                    S.result=runTrade(
                        scanner,
                        SESSION,
                        tradeSessionAlive
                    )

                    print(
                        "[PDIDDLER P4] TRADE RESULT",
                        tostring(S.result)
                    )

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
