-- Stage 17: counterparty-aware candidate research. Pure, read-only and offline.
-- Inputs must already have independently verified market/source and ownership.
-- A seller-side 'case' is NOT evidence of intent, liquidity, or acceptance.
-- Native loadstring can inject the existing Stage16 reviewer; Lua CI
-- and offline research still use the original require path.
local injectedRisk = ...
local Risk = type(injectedRisk)=='table' and injectedRisk or require('p4_risk_review')
local M = {}

local function blocked(reason, ours, seller)
    return {case='BLOCKED', reason=reason, ourReview=ours, sellerReview=seller,
        preferencesVerified=false, acceptanceProbability=nil, reviewOnly=true,
        quoteSafe=false, nativeReady=false, authorizesTrade=false,
        authorizesAccept=false}
end

local function countCopies(rows)
    local n=0
    for _,row in ipairs(rows) do n=n+row.qty end
    return n
end

local function hasFlag(flags, target)
    for _,flag in ipairs(flags) do if flag==target then return true end end
    return false
end

function M.assess(ctx, proposal)
    -- The existing Stage 16 contract is the single authority for market
    -- validation, exact checker IDs, per-side stock, and copy/slot bounds.
    local ours=Risk.assess(ctx, proposal)
    if ours.lane=='BLOCKED' then
        return blocked('our-contract-'..ours.reason, ours)
    end

    -- Invert BOTH ownership and goods. Seller's gain must be evaluated from
    -- their perspective, not inferred from our demand or from a profit score.
    local reversed={now=ctx.now, market=ctx.market,
        ownInventory=ctx.opponentInventory,
        opponentInventory=ctx.ownInventory}
    local seller=Risk.assess(reversed,
        {give=proposal.receive, receive=proposal.give})
    if seller.lane=='BLOCKED' then
        return blocked('seller-contract-'..seller.reason, ours, seller)
    end

    local sellerReceives=ours.giveBaseCents
    local sellerGives=ours.receiveBaseCents
    local surplus=sellerReceives-sellerGives
    -- Exact integer-cent comparison, display ratio only (not a rule or score).
    local coverageBps=math.floor(sellerReceives*10000/sellerGives+0.5)
    local sellerQualityUp=(seller.demandRelation=='better'
        or seller.flippabilityRelation=='better'
        or seller.stabilityExposureRelation=='better')
    local sellerQualityDown=(seller.demandRelation=='worse'
        or seller.demandRelation=='mixed'
        or seller.flippabilityRelation=='worse'
        or seller.flippabilityRelation=='mixed'
        or seller.stabilityExposureRelation=='worse'
        or hasFlag(seller.riskWarnings,'received-stability-exposure-is-risky'))

    -- 'VALUE_CASE' only means the seller gains LISTED value. 'QUALITY_TRADEOFF'
    -- only identifies an evidence-backed quality upside despite their value
    -- shortfall. Neither implies the player wants this particular trade.
    local case
    if surplus>=0 then
        case='VALUE_CASE'
    elseif sellerQualityUp and not sellerQualityDown then
        case='QUALITY_TRADEOFF'
    else
        case='UNPROVEN_SELLER_CASE'
    end

    local warnings={'counterparty-preferences-unverified',
        'no-acceptance-probability-or-native-authority'}
    if surplus<0 then
        warnings[#warnings+1]='seller-gives-more-listed-value-than-receives'
    end
    if sellerQualityDown then
        warnings[#warnings+1]='seller-quality-mixed-or-worse'
    end
    if seller.flippabilityRelation=='unknown' then
        warnings[#warnings+1]='seller-resale-proxy-unknown'
    end
    if seller.conservativeGainCents==nil then
        warnings[#warnings+1]='seller-conservative-price-range-unverified'
    elseif seller.conservativeGainCents<0 then
        warnings[#warnings+1]='seller-worst-case-value-shortfall'
    end
    local getCopies=countCopies(proposal.give)
    local giveCopies=countCopies(proposal.receive)
    if getCopies>giveCopies then
        warnings[#warnings+1]='seller-receives-more-individual-copies'
    end
    if #proposal.give>#proposal.receive then
        warnings[#warnings+1]='seller-receives-more-visible-item-types'
    end
    if ours.lane=='REVIEW_LOSS' then
        warnings[#warnings+1]='our-listed-value-loss-requires-independent-justification'
    end

    return {case=case, reason='counterparty-research-only',
        ourReview=ours,sellerReview=seller,
        ourGainCents=ours.baseGainCents,
        sellerSurplusCents=surplus,
        sellerCoverageBasisPoints=coverageBps,
        sellerDemandRelation=seller.demandRelation,
        sellerFlippabilityRelation=seller.flippabilityRelation,
        sellerStabilityExposureRelation=seller.stabilityExposureRelation,
        sellerConservativeGainCents=seller.conservativeGainCents,
        sellerReceivedCopies=getCopies,sellerGivenCopies=giveCopies,
        sellerReceivedSlots=#proposal.give,sellerGivenSlots=#proposal.receive,
        sellerQualityUpside=sellerQualityUp,
        sellerQualityDownside=sellerQualityDown,
        warnings=warnings,preferencesVerified=false,
        acceptanceProbability=nil,reviewOnly=true,quoteSafe=false,
        nativeReady=false,authorizesTrade=false,authorizesAccept=false}
end

local function denseArray(rows,maxCount)
    if type(rows)~='table' then return false end
    local n=#rows
    if n>maxCount then return false end
    local seen=0
    for k in pairs(rows) do
        if type(k)~='number' or k~=math.floor(k) or k<1 or k>n then
            return false
        end
        seen=seen+1
    end
    return seen==n
end

function M.reviewCandidates(ctx, candidates, maxCandidates)
    local cap=maxCandidates or 128
    if type(cap)~='number' or cap~=math.floor(cap) or cap<1 or cap>128
        or not denseArray(candidates, cap) then
        return nil,'candidate-input-or-budget-invalid'
    end
    -- Separate evidence lanes; do NOT select a winner based on invented
    -- willingness, composite utilities, or arbitrary concessions.
    local out={valueCases={},qualityTradeoffs={},unproven={},blocked={},
        count=#candidates,reviewOnly=true,quoteSafe=false,nativeReady=false,
        authorizesTrade=false,authorizesAccept=false}
    for index,proposal in ipairs(candidates) do
        local result=M.assess(ctx,proposal)
        local row={index=index,result=result}
        if result.case=='VALUE_CASE' then
            out.valueCases[#out.valueCases+1]=row
        elseif result.case=='QUALITY_TRADEOFF' then
            out.qualityTradeoffs[#out.qualityTradeoffs+1]=row
        elseif result.case=='BLOCKED' then
            out.blocked[#out.blocked+1]=row
        else
            out.unproven[#out.unproven+1]=row
        end
    end
    return out,nil
end

return M
