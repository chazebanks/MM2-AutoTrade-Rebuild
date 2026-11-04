-- V14 verified-market early proposals use the strict trade ledger allowance; this policy never spends it.
-- One early *decision* per stable opponent offer generation. NO Roblox actions.
--
-- This planner is NOT a probability model. Higher Supreme demand/stability are
-- evidence-based proxies for market appeal, not the opponent's personal wish.
-- Safeguard: at most 40% of profit headroom above +15, capped at 40 raw value,
-- may be spent on an early counter. This is an explicit conservative POLICY
-- budget, not a market-observed acceptance rate.
--
-- A current +94 offer may become a +65 offer if the alternate has materially
-- better verified appeal. It must NOT become +30 just for a marginal upgrade.
-- Late negotiations and actual MM2 offer mutations belong elsewhere.
local P={
    MinProfit=15,
    MaxEarlyHeadroomShare=0.40,
    MaxEarlyConcession=40,
    MinDemandImprovement=1.0,
    StrongDemandImprovement=2.0,
    MinStabilityImprovement=0.50,
    MaxRiskIncrease=0.15,
    ValueLiftDemandTieTolerance=0.05,
    MinValueLift=3,
    MinValueLiftShareOfCurrent=0.15,
    MaxValueLiftMinimum=10,
}
local function finite(x)
    return type(x)=="number" and x==x and x~=math.huge and x~=-math.huge
end
local function validQty(n)
    return finite(n) and n>=1 and n==math.floor(n)
end
local function cents(v)
    if not finite(v) or v<0 then return nil end
    local k=math.floor(v*100+0.5)
    return math.abs(k/100-v)<1e-7 and k or nil
end
local function validMarket(m)
    return type(m)=="table" and m.confidence==true
        and cents(m.rawTotal)~=nil and m.rawTotal>0
        and finite(m.exitScore) and m.exitScore>=0 and m.exitScore<=11
        and finite(m.riskPoints) and m.riskPoints>=0 and m.riskPoints<=1
end
local function picksValid(plan)
    if type(plan.picks)~="table" or #plan.picks<1 or #plan.picks>4 then return false end
    local copies,distinct,seen=0,0,{}
    for _,it in ipairs(plan.picks) do
        if type(it)~="table" or not validQty(it.qty) or it.qty>4 then return false end
        local page=tostring(it.page or "")
        local id=tostring(it.id or "")
        if (page~="godly" and page~="ancient" and page~="chroma") or id=="" then return false end
        local key=page..":"..id
        if seen[key] then return false end
        seen[key]=true
        distinct=distinct+1
        copies=copies+it.qty
    end
    return copies<=4 and distinct<=4 and copies==plan.units
end
local function verifiedRisk(plan,theirValue)
    -- The legacy plan.givenRisk is an *unweighted copy average*, while the
    -- current live offer's market.riskPoints is value-weighted. Comparing
    -- them would rank mixed bundles incorrectly. Recompute and VERIFY the
    -- actual candidate value-weighted risk from already-priced plan picks.
    if type(plan)~="table" or plan.ok~=true or not picksValid(plan)
        or not finite(plan.givenExitScore) or plan.givenExitScore<0 or plan.givenExitScore>11
        or not finite(plan.givenRisk) or plan.givenRisk<0 or plan.givenRisk>1 then
        return nil
    end
    local tv=cents(theirValue)
    local pv=cents(plan.rawTotal)
    local profit=cents(plan.rawProfit)
    if tv==nil or pv==nil or profit==nil or pv<=0
        or tv-pv~=profit or profit<P.MinProfit*100 then return nil end
    local subtotal,weightedDemand,weightedRisk=0,0,0
    for _,it in ipairs(plan.picks) do
        local itemValue=cents(it.value)
        if not itemValue or itemValue<=0
            or not finite(it.demand) or it.demand<0 or it.demand>11
            or type(it.stability)~="string" or it.stability==""
            or it.cat~="Weapons"
            or (it.type~="Knife" and it.type~="Gun") then
            return nil
        end
        local extension=itemValue*it.qty
        subtotal=subtotal+extension
        weightedDemand=weightedDemand+extension*it.demand
        weightedRisk=weightedRisk+extension*((it.stability=="Fluctuating" or it.stability=="Underpaid For") and 1 or 0)
    end
    if subtotal~=pv or subtotal<=0
        or math.abs(weightedDemand/subtotal-plan.givenExitScore)>1e-6 then
        return nil
    end
    return weightedRisk/subtotal
end
local function equivalent(plan,current)
    local counts=current and current.counts
    if type(counts)~="table" then return true end -- cannot prove distinctness
    local seen={}
    for _,item in ipairs(plan.picks) do
        local key=tostring(item.page)..":"..tostring(item.id)
        seen[key]=(seen[key] or 0)+item.qty
    end
    for key,n in pairs(seen) do if counts[key]~=n then return false end end
    for key,n in pairs(counts) do if seen[key]~=n then return false end end
    return true
end
local function tier(deltaDemand,deltaRisk)
    -- Counterparty utility PROXY: market demand and stability, not predicted
    -- acceptance. Reject any risk degradation above 0.15.
    if deltaRisk < -P.MaxRiskIncrease then return 0 end
    if deltaDemand>=P.StrongDemandImprovement then return 4 end
    if deltaDemand>=P.MinDemandImprovement then return 3 end
    if deltaRisk>=P.MinStabilityImprovement and deltaDemand>=0 then return 2 end
    return 0
end
local function better(a,b)
    if not b then return true end
    if a.tier~=b.tier then return a.tier>b.tier end
    if a.demandBand~=b.demandBand then return a.demandBand>b.demandBand end
    if a.stabilityBand~=b.stabilityBand then return a.stabilityBand>b.stabilityBand end
    -- Same market demand/stability does NOT imply equally persuasive dollar
    -- offers. Within a STRICT early budget, prefer meaningful value lift.
    -- Measurable-demand improvements do NOT justify arbitrary generosity.
    if a.plan.rawProfit~=b.plan.rawProfit then return a.plan.rawProfit>b.plan.rawProfit end
    if a.plan.units~=b.plan.units then return a.plan.units<b.plan.units end
    return tostring(a.plan.key or "")<tostring(b.plan.key or "")
end
function P.choose(state,opponentSignature,current,theirs,plans,options)
    assert(type(state)=="table","early state required")
    options=type(options)=="table" and options or {}
    if not finite(options.earlyRemaining) or options.earlyRemaining<0 then
        return "hold",nil,{reason="strict-early-allowance-required"}
    end
    if type(opponentSignature)~="string" or opponentSignature=="" then
        return "hold",nil,{reason="missing-opponent-signature"}
    end
    if state.signature~=opponentSignature then
        state.signature=opponentSignature
        state.spent=false
        state.generation=(state.generation or 0)+1
    end
    if options.accepted==true or options.localAccepted~=false then
        return "hold",nil,{reason="accepted-or-unknown-local-state"}
    end
    if state.spent then return "keep",nil,{reason="early-decision-already-used"} end
    if type(current)~="table" or type(theirs)~="table"
        or not validMarket(current.market) or not validMarket(theirs.market)
        or type(current.unresolved)~="table" or #current.unresolved>0
        or type(theirs.unresolved)~="table" or #theirs.unresolved>0
        or type(current.counts)~="table"
        or not finite(current.rawTotal) or not finite(theirs.rawTotal)
        or math.abs(current.rawTotal-current.market.rawTotal)>1e-7
        or math.abs(theirs.rawTotal-theirs.market.rawTotal)>1e-7 then
        -- Unknown is not "no improvement"; evaluate once proof is restored.
        return "hold",nil,{reason="incomplete-live-offer"}
    end
    local cv,tv=cents(current.rawTotal),cents(theirs.rawTotal)
    if not cv or not tv or cv<=0 or tv-cv<P.MinProfit*100 then
        return "hold",nil,{reason="current-trade-not-verified-safe"}
    end
    if type(plans)~="table" then
        return "hold",nil,{reason="missing-plans"}
    end
    local profit=(tv-cv)/100
    local budget=math.min(options.earlyRemaining,P.MaxEarlyConcession,
        math.max(0,(profit-P.MinProfit)*P.MaxEarlyHeadroomShare))
    local budgetCents=math.floor(budget*100+1e-8)
    local best
    local stats={safe=0,appealing=0,underBudget=0}
    for _,plan in ipairs(plans) do
        local candidateRisk=verifiedRisk(plan,theirs.rawTotal)
        if candidateRisk~=nil and not equivalent(plan,current) then
            stats.safe=stats.safe+1
            local pc=cents(plan.rawTotal)
            local concessionCents=pc-cv
            if concessionCents>=0 and concessionCents<=budgetCents then
                stats.underBudget=stats.underBudget+1
                local deltaDemand=plan.givenExitScore-current.market.exitScore
                local deltaRisk=current.market.riskPoints-candidateRisk
                local rank=tier(deltaDemand,deltaRisk)
                local lift=concessionCents/100
                local minLift=math.min(P.MaxValueLiftMinimum,
                    math.max(P.MinValueLift,current.rawTotal*P.MinValueLiftShareOfCurrent))
                -- Value-only increases belong to the deliberate late negotiation
                -- window. Early changes need a verified market-appeal improvement.
                if rank>0 then
                    stats.appealing=stats.appealing+1
                    local candidate={
                        plan=plan,tier=rank,
                        -- Whole demand-point bands prevent tiny differences
                        -- in weighted item averages from forcing concessions.
                        demandBand=math.floor(math.max(0,deltaDemand)+1e-9),
                        stabilityBand=math.floor(math.max(0,deltaRisk)*2+1e-9),
                        demandGain=deltaDemand,stabilityGain=deltaRisk,
                        concession=concessionCents/100,
                        kind=rank==1 and "bounded-value-lift" or "verified-market-appeal",
                    }
                    if better(candidate,best) then best=candidate end
                end
            end
        end
    end
    -- One *decision* per stable opponent offer. A failed execution does not
    -- endlessly retry with increasingly modified own offers.
    state.spent=true
    state.lastReason=best and best.kind or "no-defensible-early-counter"
    if best then
        return "counter",best.plan,{
            reason=state.lastReason,
            concession=best.concession,
            demandGain=best.demandGain,
            stabilityGain=best.stabilityGain,
            remainingProfit=best.plan.rawProfit,
            budget=budget,stats=stats,generation=state.generation,
        }
    end
    return "keep",nil,{reason=state.lastReason,budget=budget,stats=stats,generation=state.generation}
end
return P
