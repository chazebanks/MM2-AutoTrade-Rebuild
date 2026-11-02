-- pdiddler Part 4 balancer TEST v1
-- Scope:
--   * observe an active MM2 trade handed off by known-good Part 3
--   * offer exactly ONE highest-valued eligible item from our verified inventory
--   * accepted-empty => decline immediately
--   * empty/no-action => decline after 15 seconds
--   * non-empty => stabilize, value, and rebalance our side
--   * balanced-aggressive raw-value thresholds
--   * FINAL TRADE ACCEPT IS ABSOLUTELY DISABLED
--
-- Market-quality hooks exist, but are intentionally neutral until a verified
-- demand/stability snapshot is added. This module never invents demand tags.

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
    OfferStability=0.65,
    RemoveVerifyTimeout=0.90,
    ApplyVerifyTimeout=2.5,
    LoopDelay=0.08,

    NormalMinFlat=15,
    NormalMinPct=0.03,

    DowngradeMinFlat=20,
    DowngradeMinPct=0.06,

    BigDowngradeMinFlat=30,
    BigDowngradeMinPct=0.08,

    UpgradeOverpayCapPct=0.03,
}

-- Intentionally empty for v1. Later we can populate this from a separately
-- verified snapshot. Keys may be exact internal IDs or normalized names.
local MARKET_QUALITY={}

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

local function theirAcceptedShown(t)
    if not t then return false,"no-trade" end

    for _,d in ipairs(t:GetDescendants()) do
        if (d:IsA("TextLabel") or d:IsA("TextButton"))
            and visible(d,t)
        then
            local raw=tostring(d.Text or "")
            local q=raw:upper():gsub("%s+"," ")
                :gsub("^%s+",""):gsub("%s+$","")

            if q:find("OTHER PLAYER HAS ACCEPTED",1,true) then
                return true,d:GetFullName()
            end
        end
    end

    local side=t:FindFirstChild("TheirOffer")
    local direct=side and side:FindFirstChild("Accepted")
    if direct and visible(direct,t) then
        return true,direct:GetFullName()
    end

    return false,"none"
end

local function exactQuality(it)
    if not it then
        return {mult=1,tag="unknown",reject=false,verified=false}
    end

    local rec=
        MARKET_QUALITY[tostring(it.id or "")]
        or MARKET_QUALITY[norm(it.name)]

    if type(rec)~="table" then
        return {mult=1,tag="neutral-unverified",reject=false,verified=false}
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
    local dp={
        [0]={[0]={}},
        [1]={},
        [2]={},
        [3]={},
        [4]={},
    }

    for _,u in ipairs(units) do
        local cents=math.floor(u.value*100+0.5)

        for slots=4,1,-1 do
            local add={}

            for sum,list in pairs(dp[slots-1]) do
                local ns=sum+cents

                if not dp[slots][ns] and not add[ns] then
                    local nl={}
                    for i=1,#list do nl[i]=list[i] end
                    nl[#nl+1]=u
                    add[ns]=nl
                end
            end

            for ns,nl in pairs(add) do
                if not dp[slots][ns] then
                    dp[slots][ns]=nl
                end
            end
        end
    end

    local plans={}

    for slots=1,4 do
        for cents,list in pairs(dp[slots]) do
            local raw=cents/100
            local required,kind=requiredProfit(
                raw,
                slots,
                theirEval.eligibleCopies
            )
            local profit=theirEval.rawTotal-raw

            if raw>0 and profit>=required-0.0001 then
                local effective=0
                for _,u in ipairs(list) do
                    effective+=u.effective
                end

                plans[#plans+1]={
                    picks=aggregateUnits(list),
                    units=slots,
                    rawTotal=raw,
                    effectiveTotal=effective,
                    rawProfit=profit,
                    requiredProfit=required,
                    kind=kind,
                }
            end
        end
    end

    table.sort(plans,function(a,b)
        -- Balanced-aggressive policy:
        -- if we MUST rebalance because current offer is too expensive,
        -- choose the lowest-value valid combination to maximize room/profit.
        if a.rawTotal~=b.rawTotal then
            return a.rawTotal<b.rawTotal
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
    if live.slots~=plan.units then return false end
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

local function clearOurOffer(scanner,target,ownInv,expectedTheirSig,sessionAlive)
    for _=1,8 do
        if not sessionAlive() then return false,"stale-session" end

        local t=tradeRoot()
        if not t then return false,"trade-closed" end

        local rec=scanner.getRecord(target.UserId)
        local partnerInv=rec and rec.inv
        local theirEval=evaluateSide(t,"TheirOffer",partnerInv)

        if theirEval.signature~=expectedTheirSig then
            return false,"their-offer-changed"
        end

        local ours=evaluateSide(t,"YourOffer",ownInv)

        if #ours.unresolved>0 then
            return false,"our-offer-unresolved"
        end

        if ours.slots==0 then
            return true,"cleared"
        end

        local before=ours.slots

        if not removeOne(t) then
            return false,"remove-click-failed"
        end

        local deadline=os.clock()+C.RemoveVerifyTimeout
        local removed=false

        while sessionAlive() and os.clock()<deadline do
            local now=tradeRoot()
            if not now then return false,"trade-closed" end

            local rec2=scanner.getRecord(target.UserId)
            local theirNow=evaluateSide(
                now,
                "TheirOffer",
                rec2 and rec2.inv
            )

            if theirNow.signature~=expectedTheirSig then
                return false,"their-offer-changed"
            end

            local oursNow=evaluateSide(now,"YourOffer",ownInv)
            if oursNow.slots<before then
                removed=true
                break
            end

            task.wait(0.06)
        end

        if not removed then
            return false,"remove-verify-timeout"
        end

        task.wait(0.08)
    end

    return false,"clear-limit"
end

local function applyPlan(scanner,target,ownInv,plan,expectedTheirSig,sessionAlive)
    local ok,why=clearOurOffer(
        scanner,
        target,
        ownInv,
        expectedTheirSig,
        sessionAlive
    )

    if not ok then return false,why end

    local tradeFolder=RS:FindFirstChild("Trade")
    local offer=tradeFolder and tradeFolder:FindFirstChild("OfferItem")
    if not offer or not offer:IsA("RemoteEvent") then
        return false,"offer-remote-missing"
    end

    for _,p in ipairs(plan.picks) do
        for _=1,(tonumber(p.qty) or 1) do
            if not sessionAlive() then return false,"stale-session" end

            local t=tradeRoot()
            if not t then return false,"trade-closed" end

            local rec=scanner.getRecord(target.UserId)
            local theirNow=evaluateSide(
                t,
                "TheirOffer",
                rec and rec.inv
            )

            if theirNow.signature~=expectedTheirSig then
                return false,"their-offer-changed"
            end

            local ours=evaluateSide(t,"YourOffer",ownInv)
            if ours.slots>=4 then
                return false,"slot-limit"
            end

            local fired=pcall(function()
                offer:FireServer(p.id,"Weapons")
            end)

            if not fired then return false,"offer-fire-error" end
            task.wait(0.15)
        end
    end

    local deadline=os.clock()+C.ApplyVerifyTimeout

    while sessionAlive() and os.clock()<deadline do
        local t=tradeRoot()
        if not t then return false,"trade-closed" end

        local rec=scanner.getRecord(target.UserId)
        local theirNow=evaluateSide(
            t,
            "TheirOffer",
            rec and rec.inv
        )

        if theirNow.signature~=expectedTheirSig then
            return false,"their-offer-changed"
        end

        local ours=evaluateSide(t,"YourOffer",ownInv)
        if planMatches(plan,ours) then
            return true,ours
        end

        task.wait(0.08)
    end

    return false,"plan-verify-timeout"
end

local function fmt(v)
    v=tonumber(v) or 0
    if math.floor(v)==v then return tostring(math.floor(v)) end
    return string.format("%.2f",v)
end

local function runTrade(scanner,session,sessionAlive)
    local t=tradeRoot()
    if not t then return "trade-missing" end

    local target=findPartner(t)
    if not target then
        scanner.setStatus(
            "P4 SAFETY — trade partner could not be verified | no item offered"
        )
        return "partner-unverified"
    end

    local rec=scanner.getRecord(target.UserId)
    if not rec or rec.state~="whitelist" or not rec.inv then
        scanner.setStatus(
            "P4 SAFETY — partner inventory is not a verified whitelist snapshot | no item offered"
        )
        return "partner-inventory-unverified"
    end

    local oursBefore=readSide(t,"YourOffer")
    if oursBefore.slots>0 then
        scanner.setStatus(
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
        scanner.setStatus(
            "P4 SAFETY — could not refresh own inventory: "..tostring(ownWhy)
        )
        return "own-inventory-unavailable"
    end

    if (tonumber(ownInv.unmapped) or 0)>0
        or (tonumber(ownInv.unpriced) or 0)>0
        or (tonumber(ownInv.badQty) or 0)>0
    then
        scanner.setStatus(
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
        scanner.setStatus("P4 — no eligible own item available")
        return "no-own-item"
    end

    local tradeFolder=RS:FindFirstChild("Trade")
    local offer=tradeFolder and tradeFolder:FindFirstChild("OfferItem")

    if not offer or not offer:IsA("RemoteEvent") then
        scanner.setStatus("P4 SAFETY — OfferItem remote unavailable")
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
        scanner.setStatus("P4 — opening OfferItem call failed")
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
        scanner.setStatus(
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

    scanner.setStatus(
        string.format(
            "P4 — opening verified: %s (%s) | waiting on THEIR OFFER | market-quality tags neutral in v1",
            tostring(highest.name),
            fmt(highest.value)
        )
    )

    local emptySince=os.clock()
    local lastTheirSig=nil
    local stableSince=nil
    local lastBalancedSig=nil
    local lastCountdown=-1

    while sessionAlive() do
        local now=tradeRoot()
        if not now then
            return "trade-closed"
        end

        if not target.Parent or Players:GetPlayerByUserId(target.UserId)~=target then
            return "partner-left"
        end

        local latestRec=scanner.getRecord(target.UserId)
        local partnerInv=latestRec and latestRec.inv

        if not partnerInv then
            scanner.setStatus(
                "P4 SAFETY — partner inventory snapshot disappeared | holding, no Accept"
            )
            task.wait(C.LoopDelay)
            continue
        end

        local theirEval=evaluateSide(now,"TheirOffer",partnerInv)
        local ourEval=evaluateSide(now,"YourOffer",ownInv)

        if #ourEval.unresolved>0 then
            scanner.setStatus(
                "P4 SAFETY — YOUR OFFER became unresolved | declining to protect inventory"
            )
            declineTrade("our offer unresolved")
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
                scanner.setStatus(
                    "P4 — accepted-empty detected | immediate decline"
                )

                declineTrade("accepted empty via "..tostring(via))
                return "accepted-empty-declined"
            end

            if not emptySince then
                emptySince=os.clock()
            end

            local elapsed=os.clock()-emptySince
            local remain=math.max(0,C.EmptyTimeout-elapsed)
            local sec=math.ceil(remain)

            if sec~=lastCountdown then
                lastCountdown=sec
                scanner.setStatus(
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

        if theirEval.signature~=lastTheirSig then
            lastTheirSig=theirEval.signature
            stableSince=os.clock()
            lastBalancedSig=nil

            scanner.setStatus(
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
            scanner.setStatus(
                "P4 BALANCER — rejected-risk item detected | declining"
            )
            declineTrade("rejected market-risk item")
            return "market-risk-declined"
        end

        local required,kind=requiredProfit(
            ourEval.rawTotal,
            ourEval.slots,
            theirEval.eligibleCopies
        )
        local currentProfit=theirEval.rawTotal-ourEval.rawTotal

        if ourEval.slots>0
            and currentProfit>=required-0.0001
        then
            lastBalancedSig=theirEval.signature

            scanner.setRequestState(
                target,
                "accepted",
                string.format(
                    "P4 PROFITABLE — %s | OUR %s | THEIR %s | PROFIT +%s | NEED +%s | HOLDING OFFER | ACCEPT DISABLED",
                    kind,
                    fmt(ourEval.rawTotal),
                    fmt(theirEval.rawTotal),
                    fmt(currentProfit),
                    fmt(required)
                )
            )

            print(
                "[PDIDDLER P4] PROFITABLE HOLD",
                target.Name,
                "kind",kind,
                "ours",ourEval.rawTotal,
                "theirs",theirEval.rawTotal,
                "profit",currentProfit,
                "required",required,
                "| ACCEPT DISABLED"
            )

            task.wait(C.LoopDelay)
            continue
        end

        local plans=buildPlans(ownInv,theirEval)

        if #plans==0 then
            lastBalancedSig=theirEval.signature

            scanner.setRequestState(
                target,
                "sending",
                string.format(
                    "P4 UNDERPAY — OUR %s | THEIR %s | no profitable 1-4 item plan yet | waiting for them to change offer",
                    fmt(ourEval.rawTotal),
                    fmt(theirEval.rawTotal)
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

        local plan=plans[1]

        scanner.setStatus(
            string.format(
                "P4 REBALANCE — %s | replacing OUR %s with %s | expected profit +%s",
                plan.kind,
                fmt(ourEval.rawTotal),
                fmt(plan.rawTotal),
                fmt(plan.rawProfit)
            )
        )

        local applied,why=applyPlan(
            scanner,
            target,
            ownInv,
            plan,
            theirEval.signature,
            sessionAlive
        )

        if not applied then
            if why=="their-offer-changed" then
                lastTheirSig=nil
                stableSince=nil
                lastBalancedSig=nil
                task.wait(C.LoopDelay)
                continue
            end

            if why=="trade-closed" or why=="stale-session" then
                return why
            end

            scanner.setRequestState(
                target,
                "sendfailed",
                "P4 REBALANCE FAILED — "..tostring(why).." | FINAL ACCEPT DISABLED"
            )

            warn(
                "[PDIDDLER P4] REBALANCE FAILED",
                target.Name,
                tostring(why)
            )

            lastBalancedSig=theirEval.signature
            task.wait(C.LoopDelay)
            continue
        end

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

        local finalRequired,finalKind=requiredProfit(
            ourFinal.rawTotal,
            ourFinal.slots,
            theirFinal.eligibleCopies
        )
        local finalProfit=theirFinal.rawTotal-ourFinal.rawTotal

        if finalProfit>=finalRequired-0.0001 then
            lastBalancedSig=theirFinal.signature

            scanner.setRequestState(
                target,
                "accepted",
                string.format(
                    "P4 REBALANCED — %s | OUR %s | THEIR %s | PROFIT +%s | NEED +%s | ACCEPT DISABLED",
                    finalKind,
                    fmt(ourFinal.rawTotal),
                    fmt(theirFinal.rawTotal),
                    fmt(finalProfit),
                    fmt(finalRequired)
                )
            )

            print(
                "[PDIDDLER P4] REBALANCE VERIFIED",
                target.Name,
                "ours",ourFinal.rawTotal,
                "theirs",theirFinal.rawTotal,
                "profit",finalProfit,
                "required",finalRequired,
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
            "| market-quality modifiers NEUTRAL until verified snapshot",
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
