-- Stage 16: bounded, read-only, risk-aware trade candidate reviewer.
-- NOT an offer builder, strategy authorizer, clicker, remote, Accept policy, or
-- native Part 4 adapter. Only compare evidence supplied by a separate caller.
-- Every result is human-review-only and quoteSafe remains false.
local M={}
local MAX_VALUE_CENTS=1000000000 -- per copy, for bounded exact integer math
local MAX_TOTAL_CENTS=4000000000
local stability={
    rising=true,overpaid=true,doing_well=true,improving=true,
    fluctuating=true,receding=true,stable=true,
    underpaid=true,decreasing=true,unsafe=true,
}
local seriousRisk={underpaid=true,decreasing=true,unsafe=true}
local cautionRisk={fluctuating=true,receding=true,underpaid=true,decreasing=true,unsafe=true}
local flippability={rarely_flippable=1,flippable=2,highly_flippable=3}
local lanes={REVIEW_FAVORABLE=1,REVIEW_CAUTION=2,REVIEW_LOSS=3,BLOCKED=4}

local function int(n,lo,hi)
    return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge
        and n==math.floor(n) and n>=lo and n<=hi
end
local function denseArray(rows,low,high)
    if type(rows)~="table" then return false end
    local n=#rows
    if not int(n,low,high) then return false end
    local count=0
    for k in pairs(rows) do
        if not int(k,1,n) then return false end
        count=count+1
    end
    return count==n
end
local function validKey(key)
    if type(key)~="string" then return false end
    local page,num=key:match("^(%a+):(%d+):checker%-id$")
    return (page=="godly" or page=="chroma" or page=="ancient")
        and num~=nil and #num<=8
end
local function pack(code)
    return {lane="BLOCKED",reason=code,quoteSafe=false,authorizesTrade=false,
        authorizesAccept=false,nativeReady=false,reviewOnly=true}
end
local function source(ctx)
    if type(ctx)~="table" or type(ctx.market)~="table" then
        return nil,"market-missing" end
    local m=ctx.market
    if type(m.sourceId)~="string" or m.sourceId==""
        or m.verified~=true or type(m.items)~="table"
        or not int(ctx.now,1,9999999999)
        or not int(m.observedAt,1,9999999999)
        or not int(m.validUntil,1,9999999999)
        or m.validUntil<=m.observedAt
        or ctx.now<m.observedAt or ctx.now>=m.validUntil then
        return nil,"source-missing-unverified-or-expired"
    end
    return m,nil
end
local function marketRow(c,id)
    local it=c.items[id]
    if type(it)~="table" or it.verified~=true or it.tradable~=true
        or not int(it.valueCents,1,MAX_VALUE_CENTS)
        or not int(it.demand,0,11)
        or not stability[it.stability] then
        return nil,"item-price-demand-or-stability-unverified"
    end
    if it.lowCents~=nil or it.highCents~=nil then
        if not int(it.lowCents,1,MAX_VALUE_CENTS)
            or not int(it.highCents,1,MAX_VALUE_CENTS)
            or it.lowCents>it.valueCents or it.valueCents>it.highCents then
            return nil,"price-range-invalid"
        end
    end
    if it.flippability~=nil and not flippability[it.flippability] then
        return nil,"flippability-invalid"
    end
    return it,nil
end
local function bundle(rows,stock,market,label)
    if not denseArray(rows,1,4)
        or type(stock)~="table" then return nil,label.."-bundle-or-inventory-missing" end
    local out={base=0,lo=0,hi=0,rangeComplete=true,demand={},flip={},
        flipComplete=true,atRisk=0,serious=false,items={},copyCount=0,
        slotCount=#rows}
    local seen={}
    for _,row in ipairs(rows) do
        if type(row)~="table" or not validKey(row.id)
            or not int(row.qty,1,4) or seen[row.id] then
            return nil,label.."-identity-quantity-or-duplicate-invalid" end
        seen[row.id]=true
        if not int(stock[row.id],1,1000000) or row.qty>stock[row.id] then
            return nil,label.."-ownership-unproven" end
        local item,why=marketRow(market,row.id)
        if not item then return nil,label.."-"..why end
        out.copyCount=out.copyCount+row.qty
        if out.copyCount>4 then return nil,label.."-conservative-four-copy-limit" end
        local v=item.valueCents*row.qty
        out.base=out.base+v
        if out.base>MAX_TOTAL_CENTS then return nil,label.."-value-limit-exceeded" end
        if item.lowCents==nil then out.rangeComplete=false
        else
            out.lo=out.lo+item.lowCents*row.qty
            out.hi=out.hi+item.highCents*row.qty
        end
        if cautionRisk[item.stability] then out.atRisk=out.atRisk+v end
        if seriousRisk[item.stability] then out.serious=true end
        for t=1,item.demand do
            out.demand[t]=(out.demand[t] or 0)+v
        end
        if item.flippability==nil then out.flipComplete=false
        else
            for t=1,flippability[item.flippability] do
                out.flip[t]=(out.flip[t] or 0)+v
            end
        end
        out.items[#out.items+1]={id=row.id,qty=row.qty}
    end
    return out,nil
end
local function dominance(a,b,field,maxT)
    -- Compare value-weighted ordinal distributions, NOT probabilities.
    if field=="flip" and (not a.flipComplete or not b.flipComplete) then
        return "unknown"
    end
    local more,less=false,false
    for t=1,maxT do
        local av=(a[field][t] or 0)/a.base
        local bv=(b[field][t] or 0)/b.base
        if bv>av+1e-12 then more=true end
        if bv<av-1e-12 then less=true end
    end
    if more and less then return "mixed" end
    if more then return "better" end
    if less then return "worse" end
    return "unchanged"
end
local function riskRelation(give,receive)
    -- Proportion of base value tied to fluctuation / negative statuses.
    local a=give.atRisk/give.base
    local b=receive.atRisk/receive.base
    if b>a+1e-12 then return "worse" end
    if b<a-1e-12 then return "better" end
    return "unchanged"
end
function M.assess(ctx,proposal)
    local m,why=source(ctx)
    if not m then return pack(why) end
    if type(ctx.ownInventory)~="table" or type(ctx.opponentInventory)~="table"
        or type(proposal)~="table" then return pack("inventory-or-proposal-missing") end
    local give,eg=bundle(proposal.give,ctx.ownInventory,m,"give")
    if not give then return pack(eg) end
    local recv,er=bundle(proposal.receive,ctx.opponentInventory,m,"receive")
    if not recv then return pack(er) end
    local givenIds={}
    for _,r in ipairs(give.items) do givenIds[r.id]=true end
    for _,r in ipairs(recv.items) do
        if givenIds[r.id] then return pack("same-weapon-on-both-sides") end
    end
    local base=recv.base-give.base
    local conservative=nil
    if give.rangeComplete and recv.rangeComplete then
        conservative=recv.lo-give.hi
    end
    local demand=dominance(give,recv,"demand",11)
    local flip=dominance(give,recv,"flip",3)
    local volatility=riskRelation(give,recv)
    local warnings={"counterparty-preferences-unverified","no-native-execution-authority"}
    if not give.rangeComplete or not recv.rangeComplete then
        warnings[#warnings+1]="price-range-not-fully-verified"
    elseif conservative<0 then
        warnings[#warnings+1]="worst-case-listed-range-is-negative"
    end
    if flip=="unknown" then warnings[#warnings+1]="flippability-unknown-not-liquidity-proof" end
    if flip=="mixed" or flip=="worse" then warnings[#warnings+1]="received-flippability-not-unambiguously-better" end
    if demand=="mixed" or demand=="worse" then warnings[#warnings+1]="received-demand-not-unambiguously-better" end
    if volatility=="worse" or recv.serious then
        warnings[#warnings+1]="received-stability-exposure-is-risky"
    end
    if give.copyCount>1 or recv.copyCount>1 then
        warnings[#warnings+1]="stack-trading-may-deviate-from-listed-value"
    end
    local lane
    if base<0 then lane="REVIEW_LOSS"
    elseif base>0 and conservative~=nil and conservative>=0
        and (demand=="better" or demand=="unchanged")
        and (flip=="better" or flip=="unchanged")
        and volatility~="worse" and not recv.serious then
        lane="REVIEW_FAVORABLE"
    else
        lane="REVIEW_CAUTION"
    end
    return {lane=lane,reason="review-only",baseGainCents=base,
        conservativeGainCents=conservative,giveBaseCents=give.base,
        receiveBaseCents=recv.base,demandRelation=demand,
        flippabilityRelation=flip,stabilityExposureRelation=volatility,
        riskWarnings=warnings,marketSource=m.sourceId,
        marketValidUntil=m.validUntil,
        quoteSafe=false,authorizesTrade=false,authorizesAccept=false,
        nativeReady=false,reviewOnly=true}
end
function M.reviewCandidates(ctx,candidates,maxCandidates)
    local cap=maxCandidates or 128
    if not int(cap,1,128) or not denseArray(candidates,0,cap) then
        return nil,"candidate-budget-or-input-invalid" end
    local rows={}
    for i,candidate in ipairs(candidates) do
        local result=M.assess(ctx,candidate)
        rows[#rows+1]={index=i,result=result}
    end
    table.sort(rows,function(a,b)
        local ar,br=a.result,b.result
        if lanes[ar.lane]~=lanes[br.lane] then
            return lanes[ar.lane]<lanes[br.lane] end
        local ag,bg=ar.conservativeGainCents,br.conservativeGainCents
        if ag~=nil and bg~=nil and ag~=bg then return ag>bg end
        if (ag~=nil)~=(bg~=nil) then return ag~=nil end
        if ar.baseGainCents~=nil and br.baseGainCents~=nil
            and ar.baseGainCents~=br.baseGainCents then
            return ar.baseGainCents>br.baseGainCents end
        return a.index<b.index
    end)
    return {candidates=rows,reviewOnly=true,authorizesTrade=false,
        authorizesAccept=false,quoteSafe=false},nil
end
return M
