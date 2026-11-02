-- pdiddler Part 4 balanced-aggressive planner v1
-- Pure decision logic. No Roblox remotes/UI.
-- Final Accept is outside this module and intentionally unsupported.

local M={}

local C={
    NormalAbs=15,
    NormalPct=0.03,

    DowngradeAbs=20,
    DowngradePct=0.06,

    BigDowngradeAbs=30,
    BigDowngradePct=0.08,

    UpgradeMaxRawOverpayPct=0.03,
    UpgradeMinDemand=4,
    UpgradeDemandAdvantage=0.75,

    FluctuatingExtraPct=0.02,
    WeakExtraPct=0.05,
    SevereExtraPct=0.10,

    MaxOfferUnits=4,
}

local function norm(x)
    return tostring(x or ""):lower():gsub("[^%w]","")
end

local function copyItem(it,qty)
    return {
        id=tostring(it.id),
        name=tostring(it.name),
        value=tonumber(it.value),
        page=tostring(it.page or ""),
        type=tostring(it.type or ""),
        qty=math.max(1,tonumber(qty) or tonumber(it.qty) or 1),
        checkerId=tostring(it.checkerId or ""),
        identity=tostring(it.identity or ""),
        valueSource=tostring(it.valueSource or ""),
    }
end

local function aggregateUnits(units)
    local byId={}
    local order={}

    for _,u in ipairs(units or {}) do
        local id=tostring(u.id)

        if not byId[id] then
            byId[id]=copyItem(u,0)
            byId[id].qty=0
            order[#order+1]=id
        end

        byId[id].qty+=1
    end

    table.sort(order,function(a,b)
        local x=byId[a]
        local y=byId[b]

        if (x.value or 0)~=(y.value or 0) then
            return (x.value or 0)>(y.value or 0)
        end

        return a<b
    end)

    local out={}

    for _,id in ipairs(order) do
        out[#out+1]=byId[id]
    end

    return out
end

local function classify(ourUnits,theirUnits)
    ourUnits=tonumber(ourUnits) or 0
    theirUnits=tonumber(theirUnits) or 0

    if ourUnits<theirUnits then
        if ourUnits==1 and theirUnits>=3 then
            return "big-downgrade"
        end

        return "downgrade"
    end

    if ourUnits>theirUnits then
        return "upgrade"
    end

    return "normal"
end

local function riskExtraPct(theirStats)
    local extra=0

    for _,d in ipairs((theirStats and theirStats.details) or {}) do
        local s=norm(d.stability)

        if s=="decreasing" then
            extra=math.max(extra,C.SevereExtraPct)
        elseif s=="underpaidfor"
            or s=="losinghype"
        then
            extra=math.max(extra,C.WeakExtraPct)
        elseif s=="fluctuating" then
            extra=math.max(extra,C.FluctuatingExtraPct)
        end
    end

    return extra
end

local function baseRequirement(kind,ourRaw)
    ourRaw=tonumber(ourRaw) or 0

    if kind=="big-downgrade" then
        return C.BigDowngradeAbs,C.BigDowngradePct
    end

    if kind=="downgrade" then
        return C.DowngradeAbs,C.DowngradePct
    end

    return C.NormalAbs,C.NormalPct
end

function M.evaluate(market,ourItems,theirItems)
    if type(market)~="table"
        or type(market.offerStats)~="function"
    then
        error("[PDIDDLER P4 PLAN] market module missing")
    end

    local ours=market.offerStats(ourItems or {})
    local theirs=market.offerStats(theirItems or {})
    local kind=classify(ours.units,theirs.units)
    local absMin,pctMin=baseRequirement(kind,ours.raw)
    local riskPct=riskExtraPct(theirs)

    local rawRequired=math.max(
        absMin,
        ours.raw*(pctMin+riskPct)
    )

    local effectiveRequired=math.max(
        absMin,
        ours.effective*pctMin
    )

    local rawProfit=theirs.raw-ours.raw
    local effectiveProfit=theirs.effective-ours.effective

    local standard=
        ours.units>0
        and theirs.units>0
        and rawProfit+0.0001>=rawRequired
        and effectiveProfit+0.0001>=effectiveRequired

    local upgradeException=false
    local upgradeReason=nil

    if not standard
        and kind=="upgrade"
        and ours.raw>0
        and theirs.raw>0
    then
        local rawLoss=math.max(0,ours.raw-theirs.raw)
        local rawLossPct=rawLoss/ours.raw
        local demandOkay=false

        if theirs.avgDemand
            and theirs.avgDemand>=C.UpgradeMinDemand
        then
            if not ours.avgDemand then
                demandOkay=theirs.avgDemand>=5
            else
                demandOkay=
                    theirs.avgDemand
                    >=ours.avgDemand+C.UpgradeDemandAdvantage
            end
        end

        local qualityOkay=
            theirs.allKnown
            and not theirs.weak
            and not theirs.severe
            and demandOkay
            and theirs.effective+0.0001>=ours.effective

        if rawLossPct<=C.UpgradeMaxRawOverpayPct+0.000001
            and qualityOkay
        then
            upgradeException=true
            upgradeReason=string.format(
                "controlled upgrade | raw loss %.2f%% | demand %.2f -> %.2f",
                rawLossPct*100,
                tonumber(ours.avgDemand) or 0,
                tonumber(theirs.avgDemand) or 0
            )
        end
    end

    return {
        valid=standard or upgradeException,
        standard=standard,
        upgradeException=upgradeException,
        upgradeReason=upgradeReason,

        kind=kind,
        ours=ours,
        theirs=theirs,

        rawProfit=rawProfit,
        effectiveProfit=effectiveProfit,
        rawRequired=rawRequired,
        effectiveRequired=effectiveRequired,
        riskExtraPct=riskPct,
    }
end

local function expandUnits(inv)
    local units={}

    for _,it in ipairs((inv and inv.items) or {}) do
        local value=tonumber(it.value)
        local qty=math.min(
            C.MaxOfferUnits,
            math.max(0,tonumber(it.qty) or 0)
        )

        if value and value>0
            and it.id
            and tostring(it.id)~=""
        then
            for _=1,qty do
                units[#units+1]=copyItem(it,1)
            end
        end
    end

    table.sort(units,function(a,b)
        if a.value~=b.value then
            return a.value>b.value
        end

        return tostring(a.id)<tostring(b.id)
    end)

    return units
end

local function planSignature(units)
    local ids={}

    for _,u in ipairs(units or {}) do
        ids[#ids+1]=tostring(u.id)
    end

    table.sort(ids)

    return table.concat(ids,",")
end

local function buildPlans(market,inv,theirItems)
    local theirStats=market.offerStats(theirItems or {})

    if theirStats.raw<=0 then
        return {}
    end

    local units=expandUnits(inv)
    local maxRaw=
        theirStats.raw*(1+C.UpgradeMaxRawOverpayPct)
        +0.0001

    local dp={
        [0]={[0]={units={},effective=0,signature=""}},
        [1]={},
        [2]={},
        [3]={},
        [4]={},
    }

    for _,u in ipairs(units) do
        local cents=math.floor((tonumber(u.value) or 0)*100+0.5)

        if cents>0 then
            for slots=C.MaxOfferUnits,1,-1 do
                local additions={}

                for sum,prev in pairs(dp[slots-1]) do
                    local ns=sum+cents
                    local raw=ns/100

                    if raw<=maxRaw then
                        local list={}

                        for i=1,#prev.units do
                            list[i]=prev.units[i]
                        end

                        list[#list+1]=u

                        local items=aggregateUnits(list)
                        local stats=market.offerStats(items)
                        local sig=planSignature(list)

                        local candidate={
                            units=list,
                            effective=stats.effective,
                            signature=sig,
                        }

                        local existing=dp[slots][ns]
                            or additions[ns]

                        if not existing
                            or candidate.effective<existing.effective-0.0001
                            or (
                                math.abs(candidate.effective-existing.effective)<=0.0001
                                and sig<existing.signature
                            )
                        then
                            additions[ns]=candidate
                        end
                    end
                end

                for ns,candidate in pairs(additions) do
                    local existing=dp[slots][ns]

                    if not existing
                        or candidate.effective<existing.effective-0.0001
                        or (
                            math.abs(candidate.effective-existing.effective)<=0.0001
                            and candidate.signature<existing.signature
                        )
                    then
                        dp[slots][ns]=candidate
                    end
                end
            end
        end
    end

    local plans={}

    for slots=1,C.MaxOfferUnits do
        for cents,node in pairs(dp[slots]) do
            if cents>0 then
                local items=aggregateUnits(node.units)
                local ev=M.evaluate(market,items,theirItems)

                if ev.valid then
                    plans[#plans+1]={
                        items=items,
                        units=slots,
                        raw=cents/100,
                        effective=node.effective,
                        evaluation=ev,
                        signature=node.signature,
                    }
                end
            end
        end
    end

    return plans
end

local function betterPlan(a,b)
    if not b then return true end

    -- Real raw-profit plans beat controlled-loss upgrade exceptions.
    if a.evaluation.standard~=b.evaluation.standard then
        return a.evaluation.standard
    end

    -- Offer the most value we safely can while preserving the required
    -- profit. This avoids absurd lowballs and improves trade conversion.
    if math.abs(a.raw-b.raw)>0.0001 then
        return a.raw>b.raw
    end

    -- At equal raw cost, prefer giving away the weaker/easier-to-replace
    -- market basket.
    if math.abs(a.effective-b.effective)>0.0001 then
        return a.effective<b.effective
    end

    -- Receiving more pieces than we give is useful for future flips.
    local ag=a.evaluation.theirs.units-a.evaluation.ours.units
    local bg=b.evaluation.theirs.units-b.evaluation.ours.units

    if ag~=bg then
        return ag>bg
    end

    if a.units~=b.units then
        return a.units<b.units
    end

    return a.signature<b.signature
end

function M.choose(market,ownInv,theirItems,currentItems)
    local current=M.evaluate(
        market,
        currentItems or {},
        theirItems or {}
    )

    if current.valid then
        return {
            action="hold",
            evaluation=current,
            plan={
                items=currentItems,
                evaluation=current,
                raw=current.ours.raw,
                effective=current.ours.effective,
                units=current.ours.units,
            },
            reason=current.upgradeException
                and current.upgradeReason
                or "current offer already meets profit threshold",
        }
    end

    local plans=buildPlans(market,ownInv,theirItems)
    local best=nil

    for _,p in ipairs(plans) do
        if betterPlan(p,best) then
            best=p
        end
    end

    if not best then
        return {
            action="wait",
            evaluation=current,
            reason="no profitable 1-4 item plan for their current offer",
        }
    end

    return {
        action="replace",
        evaluation=best.evaluation,
        plan=best,
        reason=best.evaluation.upgradeException
            and best.evaluation.upgradeReason
            or "profitable replacement plan found",
    }
end

function M.planText(plan)
    if not plan or not plan.items then
        return "none"
    end

    local parts={}

    for _,it in ipairs(plan.items) do
        local qty=math.max(1,tonumber(it.qty) or 1)

        parts[#parts+1]=string.format(
            "%s%s (%s)",
            tostring(it.name),
            qty>1 and (" x"..qty) or "",
            tostring(it.value)
        )
    end

    return table.concat(parts,", ")
end

M.Config=C

return M
