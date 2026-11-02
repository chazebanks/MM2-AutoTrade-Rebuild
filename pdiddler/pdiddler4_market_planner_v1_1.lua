-- Pure market-aware Part 4 planner.
-- No Roblox services, remotes, GUI, task scheduler, or network calls.
local P={}

local function profileRecord(profile,item)
    if type(profile)~="table"
        or type(profile.get)~="function"
        or type(item)~="table"
    then
        return nil
    end

    local ok,res=pcall(
        profile.get,
        tostring(item.page or ""),
        tostring(item.id or "")
    )

    if ok then return res end
    return nil
end

local function assessUnit(profile,logic,it)
    if type(logic)~="table"
        or type(logic.itemAssessment)~="function"
    then
        return nil,"market-logic-unavailable"
    end

    local value=tonumber(it and it.value)
    if not value or value<=0 or tostring(it.id or "")=="" then
        return nil,"invalid-unit"
    end

    local input={
        page=tostring(it.page or ""),
        id=tostring(it.id),
        name=tostring(it.name or it.id),
        value=value,
        qty=1,
    }

    local ok,res=pcall(
        logic.itemAssessment,
        input,
        "ours",
        profileRecord(profile,input)
    )

    if not ok or type(res)~="table" then
        return nil,"market-item-assessment-failed"
    end

    return {
        page=input.page,
        id=input.id,
        name=input.name,
        value=value,
        protected=tonumber(res.protectedUnitValue) or value,
        exitScore=tonumber(res.exitScore) or 0,
        riskPoints=tonumber(res.riskPoints) or 0,
        disputed=res.materialDisagreement==true,
        disagreementAbs=tonumber(res.disagreementAbs) or 0,
        unprofiled=res.confidence~=true,
    },nil
end

local function makeUnits(inv,profile,logic)
    local out={}

    for _,it in ipairs((inv and inv.items) or {}) do
        local base,why=assessUnit(profile,logic,it)

        if base then
            local qty=math.min(4,math.max(0,tonumber(it.qty) or 0))
            for copy=1,qty do
                out[#out+1]={
                    page=base.page,
                    id=base.id,
                    name=base.name,
                    value=base.value,
                    protected=base.protected,
                    exitScore=base.exitScore,
                    riskPoints=base.riskPoints,
                    disputed=base.disputed,
                    disagreementAbs=base.disagreementAbs,
                    unprofiled=base.unprofiled,
                    copy=copy,
                }
            end
        elseif why~="invalid-unit" then
            return nil,why
        end
    end

    table.sort(out,function(a,b)
        if a.value~=b.value then return a.value<b.value end
        if a.page~=b.page then return a.page<b.page end
        if a.id~=b.id then return a.id<b.id end
        return a.copy<b.copy
    end)

    return out,nil
end

local function aggregateUnits(list)
    local byKey={}
    local order={}

    for _,u in ipairs(list) do
        local k=tostring(u.page)..":"..tostring(u.id)

        if not byKey[k] then
            byKey[k]={
                page=u.page,
                id=u.id,
                name=u.name,
                value=u.value,
                qty=0,
            }
            order[#order+1]=k
        end

        byKey[k].qty+=1
    end

    table.sort(order)

    local out={}
    for _,k in ipairs(order) do
        out[#out+1]=byKey[k]
    end

    return out
end

local function canonicalPackKey(list)
    local keys={}

    for _,u in ipairs(list or {}) do
        keys[#keys+1]=table.concat({
            tostring(u.page or ""),
            tostring(u.id or ""),
            tostring(u.copy or 0),
        },":")
    end

    table.sort(keys)
    return table.concat(keys,"|")
end

local function packBetter(a,b)
    if not b then return true end

    local ae=tonumber(a and a.weightedExit) or 0
    local be=tonumber(b and b.weightedExit) or 0
    if math.abs(ae-be)>0.0001 then return ae<be end

    local ad=tonumber(a and a.disputed) or 0
    local bd=tonumber(b and b.disputed) or 0
    if ad~=bd then return ad<bd end

    local au=tonumber(a and a.unprofiled) or 0
    local bu=tonumber(b and b.unprofiled) or 0
    if au~=bu then return au<bu end

    return canonicalPackKey(a and a.list)<canonicalPackKey(b and b.list)
end

function P.buildPlans(inv,theirBundle,profile,logic)
    if type(theirBundle)~="table" then
        return {},"their-market-unavailable"
    end

    if type(profile)~="table" or type(profile.get)~="function" then
        return {},"market-profile-unavailable"
    end

    if type(logic)~="table"
        or type(logic.tradeDecision)~="function"
        or type(logic.rankPlans)~="function"
    then
        return {},"market-logic-unavailable"
    end

    local units,unitsWhy=makeUnits(inv,profile,logic)
    if not units then
        return {},unitsWhy
    end

    local dp={
        [0]={
            ["0:0"]={
                list={},
                rawCents=0,
                protectedCents=0,
                weightedExit=0,
                weightedRisk=0,
                disputed=0,
                unprofiled=0,
                disagreementValue=0,
            }
        },
        [1]={},
        [2]={},
        [3]={},
        [4]={},
    }

    for _,u in ipairs(units) do
        local rawCents=math.floor(u.value*100+0.5)
        local protectedCents=math.floor(u.protected*100+0.5)

        for slots=4,1,-1 do
            local additions={}

            for _,pack in pairs(dp[slots-1]) do
                local nl={}
                for i=1,#pack.list do nl[i]=pack.list[i] end
                nl[#nl+1]=u

                local nextPack={
                    list=nl,
                    rawCents=(tonumber(pack.rawCents) or 0)+rawCents,
                    protectedCents=(tonumber(pack.protectedCents) or 0)+protectedCents,
                    weightedExit=(tonumber(pack.weightedExit) or 0)
                        +(tonumber(u.exitScore) or 0)*(tonumber(u.value) or 0),
                    weightedRisk=(tonumber(pack.weightedRisk) or 0)
                        +(tonumber(u.riskPoints) or 0)*(tonumber(u.value) or 0),
                    disputed=(tonumber(pack.disputed) or 0)+(u.disputed and 1 or 0),
                    unprofiled=(tonumber(pack.unprofiled) or 0)+(u.unprofiled and 1 or 0),
                    disagreementValue=(tonumber(pack.disagreementValue) or 0)
                        +(u.disputed and (tonumber(u.disagreementAbs) or 0) or 0),
                }

                local key=tostring(nextPack.rawCents)
                    ..":"..tostring(nextPack.protectedCents)
                local existing=dp[slots][key] or additions[key]

                if packBetter(nextPack,existing) then
                    additions[key]=nextPack
                end
            end

            for key,pack in pairs(additions) do
                if packBetter(pack,dp[slots][key]) then
                    dp[slots][key]=pack
                end
            end
        end
    end

    local plans={}

    for slots=1,4 do
        for _,pack in pairs(dp[slots]) do
            local raw=(tonumber(pack.rawCents) or 0)/100
            local protected=(tonumber(pack.protectedCents) or 0)/100

            if raw>0 then
                local pseudoOur={
                    rawTotal=raw,
                    protectedTotal=protected,
                    eligibleCopies=slots,
                    exitScore=pack.weightedExit/raw,
                    riskPoints=pack.weightedRisk/raw,
                    confidence=(tonumber(pack.unprofiled) or 0)==0,
                    materialDisagreementValue=tonumber(pack.disagreementValue) or 0,
                    disputedCopies=tonumber(pack.disputed) or 0,
                    unprofiledCopies=tonumber(pack.unprofiled) or 0,
                }

                local okDecision,decision=pcall(
                    logic.tradeDecision,
                    pseudoOur,
                    theirBundle
                )

                if okDecision
                    and type(decision)=="table"
                    and decision.ok
                then
                    plans[#plans+1]={
                        ok=true,
                        picks=aggregateUnits(pack.list),
                        units=slots,
                        rawTotal=raw,
                        protectedTotal=protected,
                        rawProfit=decision.rawProfit,
                        protectedProfit=decision.protectedProfit,
                        requiredProfit=decision.requiredProfit,
                        baseRequired=decision.baseRequired,
                        marketPremium=decision.marketPremium,
                        kind=decision.kind,
                        mode=decision.mode,
                        qualityGain=decision.qualityGain,
                        givenExitScore=pseudoOur.exitScore,
                        disputedCopies=pseudoOur.disputedCopies,
                        unprofiledCopies=pseudoOur.unprofiledCopies,
                    }
                end
            end
        end
    end

    local okRank,ranked=pcall(
        logic.rankPlans,
        plans,
        theirBundle
    )

    if not okRank or type(ranked)~="table" then
        return {},"rank-failed"
    end

    return ranked,nil
end

local function planCounts(plan)
    local counts={}
    for _,p in ipairs((plan and plan.picks) or {}) do
        local key=tostring(p.page or "")..":"..tostring(p.id or "")
        counts[key]=(counts[key] or 0)+(tonumber(p.qty) or 1)
    end
    return counts
end

function P.planMatches(plan,live)
    if not plan or not live then return false end
    if #(live.unresolved or {})>0 then return false end

    local liveRaw=tonumber(live.rawTotal) or 0
    local planRaw=tonumber(plan.rawTotal) or 0
    if math.abs(liveRaw-planRaw)>0.001 then return false end

    local expected=planCounts(plan)
    local actual=type(live.counts)=="table" and live.counts or {}

    for key,qty in pairs(expected) do
        if (tonumber(actual[key]) or 0)~=(tonumber(qty) or 0) then
            return false
        end
    end

    for key,qty in pairs(actual) do
        key=tostring(key)
        if not key:match("^ineligible:") then
            if (tonumber(expected[key]) or 0)~=(tonumber(qty) or 0) then
                return false
            end
        end
    end

    return true
end


return P
