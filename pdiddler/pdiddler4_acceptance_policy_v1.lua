-- Pure adaptive opener + acceptance-aware ranking policy.
-- No Roblox services, remotes, GUI, or network calls.
local M={}

M.OpenerObserveSeconds=2.5
M.SweetenSeconds=5.0
M.MaxSweetenSteps=2

local TIER_RANK={A=1,B=2,C=3,D=4}

local function num(v)
    local n=tonumber(v)
    if not n or n~=n or n==math.huge or n==-math.huge then return nil end
    return n
end

local function qtyOf(item)
    local q=num(item and item.qty)
    if q==nil then q=1 end
    q=math.floor(q)
    if q<0 then q=0 end
    return q
end

local function canonicalItemKey(item)
    return tostring(item and item.page or "")..":"..tostring(item and item.id or "")
end

local function canonicalPlanKey(plan)
    local keys={}
    if type(plan)=="table" and type(plan.picks)=="table" then
        for _,pick in ipairs(plan.picks) do
            keys[#keys+1]=canonicalItemKey(pick)
        end
    end
    table.sort(keys)
    if #keys>0 then return table.concat(keys,"|") end
    return tostring(plan and plan.id or "")
end

local function profileGet(profile,page,id)
    if type(profile)~="table" then return nil end
    if type(profile.get)=="function" then
        local ok,res=pcall(profile.get,page,tostring(id))
        if ok then return res end
    end
    local profiles=profile.profiles
    if type(profiles)=="table" then
        return profiles[tostring(page)..":"..tostring(id)]
    end
    return nil
end

local function inventoryItems(inv)
    if type(inv)=="table" and type(inv.items)=="table" then return inv.items end
    return {}
end

local function partnerCapacity(inv)
    local values={}
    for _,item in ipairs(inventoryItems(inv)) do
        local raw=num(item and item.value) or 0
        local qty=qtyOf(item)
        if raw>0 and qty>0 then
            for _=1,math.min(qty,4) do
                values[#values+1]=raw
            end
        end
    end
    table.sort(values,function(a,b) return a>b end)
    local top4=0
    for i=1,math.min(4,#values) do top4+=values[i] end
    return top4,values[1] or 0
end

function M.selectOpener(ownInv,partnerInv,profile,marketLogic)
    local top4,maxSingle=partnerCapacity(partnerInv)
    local meta={
        partnerTop4Raw=top4,
        partnerMaxSingle=maxSingle,
        reason="no-realistic-candidate",
        considered=0,
    }
    if top4<=0
        or type(marketLogic)~="table"
        or type(marketLogic.itemAssessment)~="function"
    then
        return nil,meta
    end

    local candidates={}
    for _,item in ipairs(inventoryItems(ownInv)) do
        local raw=num(item and item.value) or 0
        if raw>0 and qtyOf(item)>0 then
            local record=profileGet(profile,item.page,item.id)
            local ok,a=pcall(marketLogic.itemAssessment,item,"ours",record)
            if ok and type(a)=="table" then
                meta.considered+=1
                local protected=num(a.protectedUnitValue) or raw
                local headroom=math.max(15,protected*0.03)
                local stableEnough=a.confidence==true
                    and a.materialDisagreement~=true
                    and tostring(a.stability or "")~="Underpaid For"
                local reachable=(raw+headroom)<=top4
                if stableEnough and reachable then
                    candidates[#candidates+1]={
                        item=item,
                        assessment=a,
                        distance=math.abs(raw-maxSingle),
                    }
                end
            end
        end
    end

    table.sort(candidates,function(a,b)
        local ae,be=num(a.assessment.exitScore) or -math.huge,num(b.assessment.exitScore) or -math.huge
        if ae~=be then return ae>be end
        local ar,br=num(a.assessment.riskPoints) or math.huge,num(b.assessment.riskPoints) or math.huge
        if ar~=br then return ar<br end
        if a.distance~=b.distance then return a.distance<b.distance end
        return canonicalItemKey(a.item)<canonicalItemKey(b.item)
    end)

    local best=candidates[1]
    if not best then return nil,meta end
    meta.reason="selected"
    meta.exitScore=num(best.assessment.exitScore) or 0
    meta.riskPoints=num(best.assessment.riskPoints) or 0
    meta.distanceToPartnerMax=best.distance
    return best.item,meta
end

local function directionFor(plan)
    local kind=tostring(plan and plan.kind or "NORMAL")
    if kind=="DOWNGRADE" or kind=="BIG DOWNGRADE" then
        return "counterparty-upgrade",1
    elseif kind=="UPGRADE" then
        return "counterparty-downgrade",-1
    end
    return "neutral",0
end

function M.appeal(plan,theirBundle)
    plan=type(plan)=="table" and plan or {}
    theirBundle=type(theirBundle)=="table" and theirBundle or {}

    local given=num(plan.givenExitScore) or 0
    local theirExit=num(theirBundle.exitScore) or 0
    local qualityDelta=given-theirExit
    local underpaidShare=num(theirBundle.underpaidValueShare) or 0

    -- Receiving Underpaid-For inventory cannot be credited as a positive
    -- quality gain simply because its listed/raw value is high.
    if underpaidShare>0 then
        qualityDelta=math.min(qualityDelta,0)
    end

    local direction,directionScore=directionFor(plan)
    local disputed=(num(plan.disputedCopies) or 0)>0
    local unprofiled=(num(plan.unprofiledCopies) or 0)>0
    local clean=not disputed and not unprofiled

    local tier
    if qualityDelta<=-2 and directionScore<0 then
        tier="D"
    elseif underpaidShare>=0.5 then
        tier="C"
    elseif directionScore<0 and qualityDelta<1.5 then
        tier="C"
    elseif clean and (
        qualityDelta>=2
        or (directionScore>0 and qualityDelta>=0.5)
    ) then
        tier="A"
    elseif qualityDelta<0 then
        tier="C"
    else
        tier="B"
    end

    if not clean and tier=="A" then tier="B" end

    return tier,{
        tier=tier,
        qualityDelta=qualityDelta,
        direction=direction,
        directionScore=directionScore,
        underpaidValueShare=underpaidShare,
        disputed=disputed,
        unprofiled=unprofiled,
    }
end

function M.sweetenStep(elapsedSeconds)
    local elapsed=math.max(0,num(elapsedSeconds) or 0)
    local step=math.floor(elapsed/M.SweetenSeconds)
    if step<0 then step=0 end
    if step>M.MaxSweetenSteps then step=M.MaxSweetenSteps end
    return step
end

local function profitBand(plan,minProfit,window)
    local p=num(plan and plan.rawProfit) or -math.huge
    local diff=math.max(0,p-minProfit)
    return math.floor((diff+1e-9)/window)
end

function M.rankSafePlans(plans,theirBundle,sweetenStep)
    theirBundle=type(theirBundle)=="table" and theirBundle or {}
    local safe={}
    if type(plans)=="table" then
        for _,plan in ipairs(plans) do
            if type(plan)=="table" and plan.ok~=false and plan.mode~="reject" then
                safe[#safe+1]=plan
            end
        end
    end

    local meta={
        window=math.min(25,math.max(5,(num(theirBundle.rawTotal) or 0)*0.02)),
        targetBand=nil,
        selectedBand=nil,
        bestTier=nil,
    }
    if #safe==0 then return {},meta end

    local profit={}
    local quality={}
    local minProfit=nil
    local maxBand=0
    for _,plan in ipairs(safe) do
        if plan.mode=="profit" then
            profit[#profit+1]=plan
            local rp=num(plan.rawProfit) or -math.huge
            if minProfit==nil or rp<minProfit then minProfit=rp end
        else
            quality[#quality+1]=plan
        end
    end

    local selectedBand=nil
    if #profit>0 then
        for _,plan in ipairs(profit) do
            local b=profitBand(plan,minProfit,meta.window)
            plan._acceptanceBand=b
            if b>maxBand then maxBand=b end
        end

        local step=math.max(0,math.min(M.MaxSweetenSteps,math.floor(num(sweetenStep) or 0)))
        local target=math.min(maxBand,M.MaxSweetenSteps-step)
        meta.targetBand=target

        local present={}
        for _,plan in ipairs(profit) do present[plan._acceptanceBand]=true end
        if present[target] then
            selectedBand=target
        else
            for b=target-1,0,-1 do
                if present[b] then selectedBand=b break end
            end
            if selectedBand==nil then
                for b=target+1,maxBand do
                    if present[b] then selectedBand=b break end
                end
            end
        end
        meta.selectedBand=selectedBand
    end

    local function compareAppeal(a,b)
        local at,am=M.appeal(a,theirBundle)
        local bt,bm=M.appeal(b,theirBundle)
        local ar,br=TIER_RANK[at] or 99,TIER_RANK[bt] or 99
        if ar~=br then return ar<br end
        if am.qualityDelta~=bm.qualityDelta then return am.qualityDelta>bm.qualityDelta end
        if am.directionScore~=bm.directionScore then return am.directionScore>bm.directionScore end
        local ad,bd=num(a.disputedCopies) or 0,num(b.disputedCopies) or 0
        if ad~=bd then return ad<bd end
        local au,bu=num(a.unprofiledCopies) or 0,num(b.unprofiledCopies) or 0
        if au~=bu then return au<bu end
        local as,bs=num(a.units) or #(a.picks or {}),num(b.units) or #(b.picks or {})
        if as~=bs then return as<bs end
        return canonicalPlanKey(a)<canonicalPlanKey(b)
    end

    local selected={}
    local otherProfit={}
    if #profit>0 then
        for _,plan in ipairs(profit) do
            if plan._acceptanceBand==selectedBand then
                selected[#selected+1]=plan
            else
                otherProfit[#otherProfit+1]=plan
            end
        end
        table.sort(selected,compareAppeal)
        table.sort(otherProfit,function(a,b)
            local ad=math.abs((a._acceptanceBand or 0)-(selectedBand or 0))
            local bd=math.abs((b._acceptanceBand or 0)-(selectedBand or 0))
            if ad~=bd then return ad<bd end
            return compareAppeal(a,b)
        end)
    end
    table.sort(quality,compareAppeal)

    local out={}
    for _,p in ipairs(selected) do out[#out+1]=p end
    for _,p in ipairs(otherProfit) do out[#out+1]=p end
    for _,p in ipairs(quality) do out[#out+1]=p end

    if out[1] then
        meta.bestTier=(M.appeal(out[1],theirBundle))
    end
    return out,meta
end

return M
