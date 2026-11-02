-- pdiddler completed-trade telemetry snapshot v1
-- Pure Luau. Reuses Part 4 resolved identities + canonical market logic.

local M={}

local function num(v)
    local n=tonumber(v)
    if not n or n~=n or n==math.huge or n==-math.huge then return nil end
    return n
end

local function getProfile(profile,page,id)
    if type(profile)~="table" or type(profile.get)~="function" then return nil end
    local ok,res=pcall(profile.get,tostring(page or ""),tostring(id or ""))
    if ok and type(res)=="table" then return res end
    return nil
end

local function enrichResolved(resolved,side,profile,marketLogic)
    local out={}

    for _,row in ipairs(type(resolved)=="table" and resolved or {}) do
        local qty=math.max(1,math.floor(num(row.qty) or 1))
        local raw=num(row.rawValue) or 0
        local item={
            page=tostring(row.page or ""),
            id=tostring(row.id or ""),
            checkerId=tostring(row.checkerId or ""),
            name=tostring(row.name or row.id or "Unknown item"),
            qty=qty,
            mm2Value=raw,
            rawTotal=(num(row.rawSubtotal) or (raw*qty)),
            ineligible=row.ineligible==true,
            confidence=false,
        }

        if item.ineligible then
            item.page=item.page~="" and item.page or "ineligible"
            item.protectedTotal=item.rawTotal
        else
            local marketId=
                item.checkerId~=""
                and item.checkerId
                or item.id
            local p=getProfile(profile,item.page,marketId)
            local assessment=nil

            if type(marketLogic)=="table"
                and type(marketLogic.itemAssessment)=="function"
            then
                local ok,a=pcall(
                    marketLogic.itemAssessment,
                    {
                        page=item.page,
                        id=marketId,
                        name=item.name,
                        value=raw,
                        qty=qty,
                    },
                    side,
                    p
                )
                if ok and type(a)=="table" then
                    assessment=a
                end
            end

            if p then
                item.supremeValue=num(p.supremeValue)
                item.supremeLabel=
                    type(p.supremeLabel)=="string" and p.supremeLabel or nil
                item.demand=num(p.demand)
                item.stability=
                    type(p.stability)=="string" and p.stability or nil
            end

            if assessment then
                item.confidence=assessment.confidence==true
                item.liquidity=num(assessment.exitScore)
                item.riskPoints=num(assessment.riskPoints)
                item.materialDisagreement=
                    assessment.materialDisagreement==true
                item.protectedTotal=
                    num(assessment.protectedValue) or item.rawTotal
            else
                item.protectedTotal=item.rawTotal
            end
        end

        out[#out+1]=item
    end

    return out
end

function M.build(args)
    assert(type(args)=="table","telemetry args required")
    assert(type(args.ourEval)=="table","ourEval required")
    assert(type(args.theirEval)=="table","theirEval required")
    assert(type(args.decision)=="table","decision required")

    local ourEval=args.ourEval
    local theirEval=args.theirEval
    local decision=args.decision

    local giveRaw=num(ourEval.rawTotal) or 0
    local receiveRaw=num(theirEval.rawTotal) or 0
    local giveProtected=num(ourEval.protectedTotal) or giveRaw
    local receiveProtected=num(theirEval.protectedTotal) or receiveRaw

    local rawGain=num(decision.rawProfit)
    local protectedGain=num(decision.protectedProfit)
    if rawGain==nil then rawGain=receiveRaw-giveRaw end
    if protectedGain==nil then
        protectedGain=receiveProtected-giveProtected
    end

    return {
        id=tostring(args.tradeId or ""),
        traderName=tostring(args.traderName or "Unknown"),
        traderUserId=tonumber(args.traderUserId),
        ourSignature=tostring(ourEval.signature or ""),
        theirSignature=tostring(theirEval.signature or ""),
        gave=enrichResolved(
            ourEval.resolved,
            "ours",
            args.marketProfile,
            args.marketLogic
        ),
        received=enrichResolved(
            theirEval.resolved,
            "theirs",
            args.marketProfile,
            args.marketLogic
        ),
        giveRaw=giveRaw,
        receiveRaw=receiveRaw,
        giveProtected=giveProtected,
        receiveProtected=receiveProtected,
        rawGain=rawGain,
        protectedGain=protectedGain,
        requiredProfit=num(decision.requiredProfit) or 0,
        kind=tostring(decision.kind or "UNKNOWN"),
        mode=tostring(decision.mode or "unknown"),
        capturedAt=num(args.capturedAt),
    }
end

return M
