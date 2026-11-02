-- pdiddler Part 4.5 trade report v1
-- Pure Luau. No Roblox services, networking, or side effects.
-- Uses canonical checkerId for market-profile lookup.

local M={}

local function num(v)
    local n=tonumber(v)
    if n==nil or n~=n then return nil end
    return n
end

local function fmt(v)
    local n=num(v) or 0
    if math.floor(n)==n then return tostring(math.floor(n)) end
    return string.format("%.2f",n)
end

local function signed(v)
    local n=num(v) or 0
    return (n>=0 and "+" or "")..fmt(n)
end

local function qtyOf(item)
    local q=math.floor(num(item and item.qty) or 1)
    return math.max(1,q)
end

local function liquidityLabel(score)
    local s=num(score)
    if s==nil then return nil end
    if s>=3 then return "Very High" end
    if s>=2 then return "High" end
    if s>=1 then return "Good" end
    if s>=0 then return "Average" end
    if s>=-1 then return "Below Average" end
    if s>=-2 then return "Low" end
    return "Very Low"
end

M.liquidityLabel=liquidityLabel

local function profileFor(item,marketProfile)
    if type(item)~="table" or item.ineligible==true then return nil end
    if type(marketProfile)~="table" or type(marketProfile.get)~="function" then return nil end
    local marketId=tostring(item.checkerId or "")
    local page=tostring(item.page or "")
    if marketId=="" or page=="" then return nil end
    local ok,res=pcall(marketProfile.get,page,marketId)
    if ok and type(res)=="table" then return res end
    return nil
end

local function enrich(item,side,marketProfile,marketLogic)
    item=type(item)=="table" and item or {}
    local qty=qtyOf(item)
    local raw=num(item.rawValue)
    if raw==nil then raw=num(item.value) end
    local p=profileFor(item,marketProfile)

    if item.ineligible==true or raw==nil or raw<=0 or not p then
        return {
            tracked=false,
            name=tostring(item.name or item.id or "Unknown item"),
            rawId=tostring(item.id or ""),
            marketId=item.checkerId and tostring(item.checkerId) or nil,
            page=tostring(item.page or ""),
            qty=qty,
            mm2Unit=nil,
            mm2Total=nil,
            supremeUnit=nil,
            supremeLabel=nil,
            demand=nil,
            stability=nil,
            liquidityScore=nil,
            liquidityLabel=nil,
            confidence=false,
        }
    end

    local assessment=nil
    if type(marketLogic)=="table" and type(marketLogic.itemAssessment)=="function" then
        local input={
            page=tostring(item.page or ""),
            id=tostring(item.checkerId or item.id or ""),
            name=tostring(item.name or p.name or item.id or ""),
            value=raw,
            qty=qty,
        }
        local ok,res=pcall(marketLogic.itemAssessment,input,side,p)
        if ok and type(res)=="table" then assessment=res end
    end

    local score=assessment and num(assessment.exitScore) or nil

    return {
        tracked=true,
        name=tostring(item.name or p.name or item.id or "Unknown item"),
        rawId=tostring(item.id or ""),
        marketId=tostring(item.checkerId or p.id or ""),
        page=tostring(item.page or p.page or ""),
        qty=qty,
        mm2Unit=raw,
        mm2Total=raw*qty,
        supremeUnit=num(p.supremeValue),
        supremeLabel=p.supremeLabel,
        demand=num(p.demand),
        stability=tostring(p.stability or ""),
        liquidityScore=score,
        liquidityLabel=liquidityLabel(score),
        confidence=assessment and assessment.confidence==true or false,
        materialDisagreement=assessment and assessment.materialDisagreement==true or false,
    }
end

local function sideReport(items,side,marketProfile,marketLogic)
    local out={
        items={},
        mm2Total=0,
        supremeNumericTotal=0,
        supremeNonNumericCopies=0,
        trackedCopies=0,
        untrackedCopies=0,
    }

    for _,item in ipairs(type(items)=="table" and items or {}) do
        local e=enrich(item,side,marketProfile,marketLogic)
        out.items[#out.items+1]=e
        if e.tracked then
            out.trackedCopies+=e.qty
            out.mm2Total+=(e.mm2Total or 0)
            if e.supremeUnit~=nil then
                out.supremeNumericTotal+=e.supremeUnit*e.qty
            elseif e.supremeLabel then
                out.supremeNonNumericCopies+=e.qty
            end
        else
            out.untrackedCopies+=e.qty
        end
    end

    return out
end

local function inventorySummary(inv,marketProfile,marketLogic)
    inv=type(inv)=="table" and inv or nil
    if not inv then
        return {
            verified=false,
            mm2Total=nil,
            supremeNumericTotal=nil,
            supremeNonNumericCopies=0,
            eligibleCopies=0,
            excludedCopies=nil,
            incomplete=true,
        }
    end

    local side=sideReport(inv.items or {},"ours",marketProfile,marketLogic)
    local eligibleCopies=0
    for _,item in ipairs(inv.items or {}) do
        eligibleCopies+=qtyOf(item)
    end

    local rawOwned=num(inv.rawOwned)
    local excludedCopies=nil
    if rawOwned~=nil then
        excludedCopies=math.max(0,rawOwned-eligibleCopies-(num(inv.unmapped) or 0))
    end

    local incomplete=
        (num(inv.unmapped) or 0)>0
        or (num(inv.unpriced) or 0)>0
        or (num(inv.badQty) or 0)>0

    return {
        verified=not incomplete and num(inv.total)~=nil,
        mm2Total=num(inv.total),
        supremeNumericTotal=side.supremeNumericTotal,
        supremeNonNumericCopies=side.supremeNonNumericCopies,
        eligibleCopies=eligibleCopies,
        excludedCopies=excludedCopies,
        incomplete=incomplete,
        unmapped=num(inv.unmapped) or 0,
        unpriced=num(inv.unpriced) or 0,
        badQty=num(inv.badQty) or 0,
        fingerprint=inv.fingerprint,
    }
end

function M.build(candidate,postInventory,marketProfile,marketLogic)
    candidate=type(candidate)=="table" and candidate or {}

    local gave=sideReport(candidate.gave or {},"ours",marketProfile,marketLogic)
    local received=sideReport(candidate.received or {},"theirs",marketProfile,marketLogic)
    local pre=inventorySummary(candidate.preInventory,marketProfile,marketLogic)
    local post=inventorySummary(postInventory,marketProfile,marketLogic)

    local gain=received.mm2Total-gave.mm2Total
    local expected=nil
    if pre.mm2Total~=nil then expected=pre.mm2Total+gain end

    post.expectedMM2=expected

    if post.mm2Total~=nil and expected~=nil then
        post.deltaMismatch=math.abs(post.mm2Total-expected)>0.0001
    else
        post.deltaMismatch=nil
    end

    if postInventory==nil then
        post.verified=false
        post.mm2Total=expected
    end

    return {
        tradeId=tostring(candidate.tradeId or ""),
        partnerName=tostring(candidate.partnerName or "Unknown"),
        gave=gave,
        received=received,
        gainMM2=gain,
        inventoryBefore=pre,
        inventoryAfter=post,
        completedAt=candidate.completedAt,
    }
end

local function itemLine(item)
    if not item.tracked then
        return string.format(
            "• %s%s — Market data N/A (outside tracked market)",
            tostring(item.name),
            item.qty>1 and (" x"..tostring(item.qty)) or ""
        )
    end

    local supreme
    if item.supremeUnit~=nil then
        supreme=fmt(item.supremeUnit)
    elseif item.supremeLabel then
        supreme=tostring(item.supremeLabel)
    else
        supreme="N/A"
    end

    local liquidity=item.liquidityLabel
        and (item.liquidityLabel.." ("..signed(item.liquidityScore)..")")
        or "N/A"

    return string.format(
        "• %s%s — MM2 %s | Supreme %s | Demand %s | Liquidity %s | %s",
        tostring(item.name),
        item.qty>1 and (" x"..tostring(item.qty)) or "",
        fmt(item.mm2Unit),
        supreme,
        item.demand and (fmt(item.demand).."/10") or "N/A",
        liquidity,
        item.stability~="" and item.stability or "N/A"
    )
end

local function sideText(side)
    local lines={}
    for _,item in ipairs(side.items or {}) do
        lines[#lines+1]=itemLine(item)
    end
    if #lines==0 then lines[1]="No captured items" end

    lines[#lines+1]=""
    lines[#lines+1]="Tracked MM2 total: **"..fmt(side.mm2Total).."**"
    lines[#lines+1]="Supreme numeric total: **"..fmt(side.supremeNumericTotal).."**"
    if (side.supremeNonNumericCopies or 0)>0 then
        lines[#lines+1]="Supreme non-numeric copies: **"..tostring(side.supremeNonNumericCopies).."**"
    end

    local joined=table.concat(lines,"\n")
    if #joined>1024 then joined=joined:sub(1,1000).."\n…truncated" end
    return joined
end

function M.discordPayload(report)
    report=type(report)=="table" and report or {}
    local inv=type(report.inventoryAfter)=="table" and report.inventoryAfter or {}

    local invLines={
        "Tracked MM2 total: **"..fmt(inv.mm2Total or inv.expectedMM2 or 0).."**",
    }

    if inv.supremeNumericTotal~=nil then
        invLines[#invLines+1]="Supreme numeric total: **"..fmt(inv.supremeNumericTotal).."**"
    end
    if inv.excludedCopies~=nil then
        invLines[#invLines+1]="Excluded non-market weapon copies: **"..tostring(inv.excludedCopies).."**"
    end

    if inv.verified then
        invLines[#invLines+1]="Post-trade inventory verification: **VERIFIED**"
    else
        invLines[#invLines+1]="Post-trade inventory verification: **UNVERIFIED / expected total shown**"
    end

    if inv.deltaMismatch==true then
        invLines[#invLines+1]="Inventory delta mismatch detected"
    end

    local embed={
        title="MM2 Trade Completed",
        description="Partner: **"..tostring(report.partnerName or "Unknown").."**",
        fields={
            {name="You Traded",value=sideText(report.gave or {}),inline=false},
            {name="You Received",value=sideText(report.received or {}),inline=false},
            {name="Value Gained",value="Tracked MM2 gain: **"..signed(report.gainMM2 or 0).."**",inline=false},
            {name="Inventory After",value=table.concat(invLines,"\n"),inline=false},
            {name="Trade ID",value=tostring(report.tradeId or "unknown"),inline=false},
        },
        footer={
            text="Liquidity is the trader's existing exit score (demand + stability - disagreement), not a separate value list.",
        },
    }

    return {
        username="MM2 AutoTrade Audit",
        embeds={embed},
    }
end

return M
