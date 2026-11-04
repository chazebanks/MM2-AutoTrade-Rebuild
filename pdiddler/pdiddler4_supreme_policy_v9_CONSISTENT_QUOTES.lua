-- V14 deterministic quotes and explicit source-condition descriptors: bounded concessions from CURRENT offer; no network, UI, remotes or Accept actions.
local P={
    minimumProfit=15,maxStates=50000,
    sweetenWaitSeconds=9,finalWaitSeconds=5,
    -- Relative to CURRENT verified profit, not min safe plan.
    maxLateHeadroomShare=0.25,
    maxLateConcession=20,
    minLateConcession=3,
    minLateCurrentValueShare=0.08,
    maxLateMinValue=8,
    -- Initial opponent-first quote must not blindly select near +15 floor.
    maxInitialCounterpartShare=0.60,
}
local function finite(n) return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge end
local function integer(n) return finite(n) and n>=1 and n==math.floor(n) end
local function cents(n)
    if not finite(n) or n<0 then return nil end
    local rounded=math.floor(n*100+0.5)
    if math.abs(n*100-rounded)>0.000001 then return nil end
    return rounded
end
local function name(s) return tostring(s or ""):gsub("’","'"):gsub("^%s+",""):gsub("%s+$",""):gsub("%s+"," "):lower() end
function P.usernameEqual(a,b) return tostring(a or ""):lower()==tostring(b or ""):lower() and tostring(a or "")~="" end
function P.quantity(text)
    local s=tostring(text or ""):match("^%s*(.-)%s*$")
    if s=="" then return 1 end
    s=s:match("^[xX]%s*(.+)$") or s
    if not s:match("^%d+$") then
        if not s:match("^%d%d?%d?,%d%d%d") then return nil end
        local first,rest=s:match("^(%d+)(,.*)$")
        if not first or #first>3 or rest:gsub(",%d%d%d","")~="" then return nil end
    end
    local n=tonumber((s:gsub(",","")))
    return integer(n) and n or nil
end
local function fresh(profile)
    if type(profile)~="table" or type(profile.get)~="function" or type(profile.isFresh)~="function" then return false end
    local ok,result=pcall(profile.isFresh); return ok and result==true
end
local function record(profile,it)
    if not it then return nil end
    local id=tostring(it.checkerId or ""); if id=="" then id=tostring(it.id or "") end
    return profile.get(tostring(it.page or ""),id)
end
function P.itemAssessment(it,side,r)
    local v=r and r.supremeValue
    local demand=r and r.demand
    local ok=type(it)=="table" and type(r)=="table" and r.verified==true
        and (it.page=="godly" or it.page=="ancient" or it.page=="chroma")
        and finite(v) and v>0 and finite(demand) and demand>=0 and demand<=11
        and type(r.stability)=="string" and r.stability~=""
        and name(it.name)==name(r.name)
        and tostring(it.checkerId or it.id)==tostring(r.id) and tostring(it.page)==tostring(r.page)
    return {confidence=ok==true,rawUnitValue=ok and v or 0,protectedUnitValue=ok and v or 0,
        exitScore=ok and demand or 0,riskPoints=ok and ((r.stability=="Fluctuating" or r.stability=="Underpaid For") and 1 or 0) or 0,
        marketCondition=r and r.stability or "unknown",
        volatility=r and (r.stability=="Stable" and "stable" or r.stability=="Fluctuating" and "fluctuating" or "unknown") or "unknown",
        riskMeaning="fluctuating-or-underpaid-source-status",
        materialDisagreement=false,reason=ok and "verified-supreme" or "unknown-or-contradictory-price"}
end
function P.reprice(inv,profile)
    if type(inv)~="table" then return nil,"inventory-unavailable" end
    local out={}; for k,v in pairs(inv) do out[k]=v end
    out.items={}; out.unpriced=tonumber(inv.unpriced) or 0; out.badQty=tonumber(inv.badQty) or 0; out.unmapped=tonumber(inv.unmapped) or 0
    local seen={}; local current=fresh(profile)
    for _,it in ipairs(inv.items or {}) do
        local r=current and record(profile,it) or nil
        local assessment=P.itemAssessment(it,"ours",r)
        local key=tostring(it.page)..":"..tostring(it.id)
        if (name(it.type)~="knife" and name(it.type)~="gun") or it.cat~="Weapons" then out.unmapped=out.unmapped+1
        elseif not integer(it.qty) or seen[key] then out.badQty=out.badQty+1
        elseif not assessment.confidence or tostring(it.id or "")=="" then out.unpriced=out.unpriced+1
        else
            local copy={}; for k,v in pairs(it) do copy[k]=v end
            copy.value=r.supremeValue; copy.supremeValue=r.supremeValue
            copy.demand=r.demand; copy.stability=r.stability
            out.items[#out.items+1]=copy
        end
        seen[key]=true
    end
    out.value=0; for _,it in ipairs(out.items) do out.value=out.value+it.value*it.qty end
    out.total=out.value
    out.supremeVersion=profile and profile.version
    if not current then return out,"supreme-profile-stale" end
    return out,nil
end
function P.bundleAssessment(items,side,profile)
    local b={items={},rawTotal=0,protectedTotal=0,eligibleCopies=0,confidence=fresh(profile),exitScore=0,riskPoints=0,unprofiledCopies=0,disputedCopies=0}
    for _,it in ipairs(items or {}) do
        local a=P.itemAssessment(it,side,b.confidence and record(profile,it) or nil)
        if not a.confidence or not integer(it.qty) then b.confidence=false; b.unprofiledCopies=b.unprofiledCopies+1
        else
            local value=a.rawUnitValue*it.qty
            b.rawTotal=b.rawTotal+value; b.eligibleCopies=b.eligibleCopies+it.qty
            local copy={};for k,v in pairs(it) do copy[k]=v end
            local r=record(profile,it);copy.value=r.supremeValue;copy.demand=r.demand;copy.stability=r.stability
            b.items[#b.items+1]=copy
            b.exitScore=b.exitScore+a.exitScore*value; b.riskPoints=b.riskPoints+a.riskPoints*value
        end
    end
    if not b.confidence then b.items=nil end
    b.protectedTotal=b.rawTotal
    if b.rawTotal>0 then b.exitScore=b.exitScore/b.rawTotal; b.riskPoints=b.riskPoints/b.rawTotal end
    return b
end
local function assetKey(it) return tostring(it.page)..":"..tostring(it.checkerId or it.id) end
function P.sharedItem(ours,theirs)
    local offered={}
    for _,it in ipairs((ours or {}).items or {}) do offered[assetKey(it)]=true end
    for _,it in ipairs((theirs or {}).items or {}) do if offered[assetKey(it)] then return assetKey(it) end end
    return nil
end
function P.tradeDecision(ours,theirs)
    ours=ours or {}; theirs=theirs or {}
    local ov,tv=ours.rawTotal,theirs.rawTotal
    local oc,tc=cents(ov),cents(tv)
    local valid=ours.confidence==true and theirs.confidence==true and oc~=nil and tc~=nil and oc>0 and tc>0
    local profit=valid and (tc-oc)/100 or -math.huge
    local overlap=P.sharedItem(ours,theirs)
    if overlap then return {ok=false,kind="SUPREME",mode="reject",reason="matching-item-on-both-sides",
        rawProfit=profit,protectedProfit=profit,requiredProfit=P.minimumProfit,sharedItem=overlap} end
    return {ok=valid and profit>=P.minimumProfit,kind="SUPREME",mode="profit",
        reason=valid and (profit>=P.minimumProfit and "supreme-profit" or "below-plus-15") or "unverified-bundle",
        rawProfit=profit,protectedProfit=profit,requiredProfit=P.minimumProfit,baseRequired=P.minimumProfit,marketPremium=0,
        qualityGain=(theirs.exitScore or 0)-(ours.exitScore or 0)}
end
-- Bands reserve room for two negotiations; they are policy heuristics, not
-- price adjustments or calibrated acceptance probabilities. Within a band,
-- counterparty demand/stability/consolidation outrank raw value donated.
-- Descriptors are exact list-value facts, not estimated liquidity or returns.
local function portfolioContext(priced,theirs,profile)
    local incomingKnown=false
    local incoming
    if type(theirs.items)=="table" then
        incoming=P.bundleAssessment(theirs.items,"theirs",profile)
        incomingKnown=incoming.confidence and math.abs(incoming.rawTotal-theirs.rawTotal)<1e-6
            and finite(theirs.exitScore) and math.abs(incoming.exitScore-theirs.exitScore)<1e-6
    end
    if incomingKnown then for _,it in ipairs(incoming.items) do if not cents(it.value) then incomingKnown=false;break end end end
    local context={known=incomingKnown,assets={},total=0,squares=0,unstable=0,thresholds={},top={}}
    for i=1,11 do context.thresholds[i]=0 end
    local function add(it)
        local key=assetKey(it);local unit=cents(it.value);local old=context.assets[key]
        if not old then old={qty=0,value=unit,demand=it.demand,unstable=it.stability=="Fluctuating" or it.stability=="Underpaid For"};context.assets[key]=old end
        old.qty=old.qty+it.qty
    end
    for _,it in ipairs(priced.items) do add(it) end
    if incomingKnown then for _,it in ipairs(incoming.items) do add(it) end end
    context.distinct=0
    for key,it in pairs(context.assets) do
        local value=it.value*it.qty;context.total=context.total+value;context.squares=context.squares+value*value
        context.distinct=context.distinct+1
        if it.unstable then context.unstable=context.unstable+value end
        for threshold=1,11 do if it.demand>=threshold then context.thresholds[threshold]=context.thresholds[threshold]+value end end
        for _=1,math.min(8,it.qty) do context.top[#context.top+1]={key=key,value=it.value} end
    end
    table.sort(context.top,function(a,b) if a.value~=b.value then return a.value>b.value end;return a.key<b.key end)
    while #context.top>8 do table.remove(context.top) end
    return context
end
local function portfolioFacts(context,picks)
    local removed={};for _,it in ipairs(picks) do local key=assetKey(it);removed[key]=(removed[key] or 0)+1 end
    local facts={known=context.known,scope="priced-eligible-inventory",valueUnit="integer-cents",total=context.total,squares=context.squares,unstableValue=context.unstable,
        compact4=0,distinct=context.distinct,demandThresholds={},topValues={}}
    for i=1,11 do facts.demandThresholds[i]=context.thresholds[i] end
    for key,qty in pairs(removed) do
        local it=context.assets[key];local before=it.value*it.qty;local after=it.value*(it.qty-qty);local cost=it.value*qty
        facts.total=facts.total-cost;facts.squares=facts.squares-before*before+after*after
        if it.unstable then facts.unstableValue=facts.unstableValue-cost end
        if after==0 then facts.distinct=facts.distinct-1 end
        for i=1,11 do if it.demand>=i then facts.demandThresholds[i]=facts.demandThresholds[i]-cost end end
    end
    local skip={};for k,v in pairs(removed) do skip[k]=v end
    -- With at most four total removals, 8-used remaining values contain every
    -- possible final top four. The sequence (not only its sum) is necessary:
    -- future row removals may reveal a different retained denomination.
    local horizon=8-#picks
    for _,entry in ipairs(context.top) do
        if (skip[entry.key] or 0)>0 then skip[entry.key]=skip[entry.key]-1
        else
            facts.topValues[#facts.topValues+1]=entry.value
            if #facts.topValues<=4 then facts.compact4=facts.compact4+entry.value end
            if #facts.topValues==horizon then break end
        end
    end
    facts.concentration=facts.total>0 and facts.squares/(facts.total*facts.total) or 0
    local key={tostring(facts.squares),tostring(facts.compact4),tostring(facts.unstableValue),tostring(facts.distinct)}
    for i=1,11 do key[#key+1]=tostring(facts.demandThresholds[i]) end
    for _,value in ipairs(facts.topValues) do key[#key+1]=tostring(value) end
    facts.key=table.concat(key,":")
    return facts
end
local function portfolioBetter(a,b)
    a=a and a.portfolio;b=b and b.portfolio
    local ak=a and a.known==true;local bk=b and b.known==true
    if ak~=bk then return ak end
    if not ak then return nil end
    -- A deterministic tuple avoids cycles from mixing partial dominance with ID
    -- ordering. Preserve all descriptor tradeoffs in the returned candidate set.
    -- At equal given economics: compact capacity, ordinal holdings, exposure,
    -- then concentration. These are tie-break priorities, not calibrated returns.
    if a.total~=b.total then return a.total>b.total end
    if a.compact4~=b.compact4 then return a.compact4>b.compact4 end
    for i=11,1,-1 do
        if a.demandThresholds[i]~=b.demandThresholds[i] then return a.demandThresholds[i]>b.demandThresholds[i] end
    end
    if a.unstableValue~=b.unstableValue then return a.unstableValue<b.unstableValue end
    if a.squares~=b.squares then return a.squares<b.squares end
    return nil
end
P.portfolioBetter=portfolioBetter
function P.rankPlans(plans,theirs,step)
    theirs=theirs or {}; step=math.min(2,math.max(0,step or 0))
    local safe,minProfit={},nil
    for _,plan in ipairs(plans or {}) do
        if plan.ok and finite(plan.rawProfit) and plan.rawProfit>=15 and finite(plan.rawTotal) and plan.rawTotal>0 then
            safe[#safe+1]=plan; minProfit=math.min(minProfit or plan.rawProfit,plan.rawProfit)
        end
    end
    if #safe==0 then return safe end
    local window=math.max(5,math.min(25,(theirs.rawTotal or 0)*0.02))
    local target=2-step
    local function band(plan) return math.floor((plan.rawProfit-minProfit)/window+0.000001) end
    local function appeal(plan)
        local delta=(plan.givenExitScore or 0)-(theirs.exitScore or 0)
        local unstable=plan.givenRisk or 0
        local tier=delta>=2 and 1 or (delta>=0 and 2 or 3)
        return tier,unstable
    end
    table.sort(safe,function(a,b)
        local ad,bd=math.abs(band(a)-target),math.abs(band(b)-target)
        if ad~=bd then return ad<bd end
        local at,ar=appeal(a); local bt,br=appeal(b)
        if at~=bt then return at<bt end
        if ar~=br then return ar<br end
        if a.units~=b.units then return a.units<b.units end
        -- Preserve value and stronger demand when appeal is otherwise comparable.
        if a.rawTotal~=b.rawTotal then return a.rawTotal<b.rawTotal end
        if a.givenExitScore~=b.givenExitScore then return a.givenExitScore<b.givenExitScore end
        local preserved=portfolioBetter(a,b);if preserved~=nil then return preserved end
        return a.key<b.key
    end)
    return safe
end
function P.selectOpener(ownInv,partnerInv,profile)
    local ours,why=P.reprice(ownInv,profile)
    local theirs,theirWhy=P.reprice(partnerInv,profile)
    local function complete(inv) return inv and inv.unmapped==0 and inv.unpriced==0 and inv.badQty==0 end
    if why or theirWhy or not complete(ours) or not complete(theirs) then return nil,"inventory-incomplete" end
    local values={}
    for _,it in ipairs(theirs.items) do for _=1,math.min(4,it.qty) do values[#values+1]=it.value end end
    table.sort(values,function(a,b) return a>b end)
    local capacity=0; for i=1,math.min(4,#values) do capacity=capacity+values[i] end
    local candidates={}
    for _,it in ipairs(ours.items) do
        if cents(it.value) and cents(capacity) and cents(capacity)-cents(it.value)>=1500
            and it.demand>=1 and it.stability~="Underpaid For" then candidates[#candidates+1]=it end
    end
    table.sort(candidates,function(a,b)
        if a.demand~=b.demand then return a.demand>b.demand end
        local ar=a.stability=="Fluctuating" and 1 or 0; local br=b.stability=="Fluctuating" and 1 or 0
        if ar~=br then return ar<br end
        local ad=math.abs(a.value-(values[1] or 0)); local bd=math.abs(b.value-(values[1] or 0))
        if ad~=bd then return ad<bd end
        if a.value~=b.value then return a.value<b.value end
        return a.id<b.id
    end)
    return candidates[1],candidates[1] and "reachable-market-opener" or "no-realistic-candidate"
end
function P.buildPlans(inv,theirs,profile,logic,stateBudget)
    local priced,why=P.reprice(inv,profile)
    if not priced or why or (priced.unmapped or 0)>0 or priced.unpriced>0 or priced.badQty>0 then return {},why or "inventory-incomplete" end
    if not theirs or not theirs.confidence or not finite(theirs.rawTotal) then return {},"their-market-unavailable" end
    local budget=math.floor((theirs.rawTotal-P.minimumProfit)*100+0.000001)
    if budget<=0 then return {},"no-safe-plan" end
    for _,it in ipairs(priced.items) do if not cents(it.value) then return {},"unsupported-price-precision" end end
    local context=portfolioContext(priced,theirs,profile)
    local rows={};local canonical={};local overlapping=false
    local receivedAssets={}
    for _,it in ipairs(theirs.items or {}) do receivedAssets[assetKey(it)]=true end
    for _,it in ipairs(priced.items) do
        if not receivedAssets[assetKey(it)] then rows[#rows+1]=it end
        local key=assetKey(it);if canonical[key] then overlapping=true end;canonical[key]=true
    end
    if overlapping then context.known=false end
    table.sort(rows,function(a,b)
        if a.value~=b.value then return a.value<b.value end
        return a.id<b.id
    end)
    local dp={[0]={["empty"]={total=0,picks={},demand=0,risk=0,key=""}},[1]={},[2]={},[3]={},[4]={}}
    local states=1
    -- Each raw owned row is processed once. Future rows therefore have the
    -- same availability for every merged prefix; individual copies are not
    -- merged while more copies of that same raw row remain to be processed.
    for _,it in ipairs(rows) do
        local nextDP={[0]={},[1]={},[2]={},[3]={},[4]={}}
        for count=0,4 do for key,pack in pairs(dp[count]) do nextDP[count][key]=pack end end
        local unit=cents(it.value)
        for count=0,3 do
            for _,pack in pairs(dp[count]) do
                for qty=1,math.min(it.qty,4-count) do
                    local nextTotal=pack.total+unit*qty
                    if nextTotal<=budget then
                        local demand=pack.demand+it.demand*unit*qty
                        local key=pack.key.."|"..it.page..":"..it.id..":"..qty
                        local risk=pack.risk+((it.stability=="Fluctuating" or it.stability=="Underpaid For") and unit*qty or 0)
                        local picks={};for i,p in ipairs(pack.picks) do picks[i]=p end
                        for _=1,qty do picks[#picks+1]=it end
                        local facts=portfolioFacts(context,picks)
                        local stateKey=table.concat({nextTotal,string.format("%.8f",demand),risk,facts.key},":")
                        -- Valid distinct raw rows may share a price identity.
                        -- Their future ownership overlap is not proved by price
                        -- metadata: retain exact raw choices within the same cap.
                        if overlapping then stateKey=stateKey.."/raw="..key end
                        local old=nextDP[count+qty][stateKey]
                        if not old or key<old.key then
                            nextDP[count+qty][stateKey]={total=nextTotal,picks=picks,demand=demand,risk=risk,key=key,portfolio=facts}
                            if not old then states=states+1 end
                            if states>(stateBudget or P.maxStates) then return {},"planner-state-budget" end
                        end
                    end
                end
            end
        end
        dp=nextDP
    end
    local plans={}
    for count=1,4 do
        for _,pack in pairs(dp[count]) do
            local total=pack.total/100
            local decision=P.tradeDecision({rawTotal=total,confidence=true,exitScore=pack.demand/pack.total},theirs)
            if decision.ok then
                local picks,map={},{}
                for _,it in ipairs(pack.picks) do
                    local key=it.page..":"..it.id
                    if not map[key] then local p={};for k,v in pairs(it) do p[k]=v end;p.qty=0;map[key]=p;picks[#picks+1]=p end
                    map[key].qty=map[key].qty+1
                end
                plans[#plans+1]={ok=true,picks=picks,units=count,rawTotal=total,protectedTotal=total,
                    rawProfit=decision.rawProfit,protectedProfit=decision.rawProfit,requiredProfit=15,baseRequired=15,
                    marketPremium=0,kind="SUPREME",mode="profit",qualityGain=decision.qualityGain,
                    givenExitScore=pack.demand/pack.total,givenRisk=pack.risk/pack.total,key=pack.key,portfolio=pack.portfolio}
            end
        end
    end
    return P.rankPlans(plans,theirs,0),nil
end
function P.planMatches(plan,live)
    if not plan or not live or #(live.unresolved or {})>0 or not finite(live.rawTotal) or math.abs(live.rawTotal-plan.rawTotal)>0.000001 then return false end
    local expected={}
    for _,it in ipairs(plan.picks or {}) do
        if not integer(it.qty) then return false end
        local key=tostring(it.page)..":"..tostring(it.id); expected[key]=(expected[key] or 0)+it.qty
    end
    for key,qty in pairs(expected) do if (live.counts or {})[key]~=qty then return false end end
    for key,qty in pairs(live.counts or {}) do if expected[key]~=qty then return false end end
    return true
end
-- First reply when THEIR offer arrives before OUR opener. Choose a priced,
-- market-aware quote that protects meaningful margin; original rankPlans near
-- +15 is NOT a suitable default for a brand-new offer.
-- The 60% is an explicit initial price ceiling, not an acceptance prediction.
function P.selectInitialOffer(plans,received,theirMarket)
    if not finite(received) or received<=P.minimumProfit then return nil,"unknown-received-value" end
    local budget=math.min(received-P.minimumProfit,received*P.maxInitialCounterpartShare)
    local best,low
    for _,plan in ipairs(plans or {}) do
        if type(plan)=="table" and plan.ok==true
            and finite(plan.rawTotal) and plan.rawTotal>0
            and finite(plan.rawProfit) and plan.rawProfit>=P.minimumProfit
            and math.abs(plan.rawTotal+plan.rawProfit-received)<0.00001 then
            if not low or plan.rawTotal<low.rawTotal or (plan.rawTotal==low.rawTotal and tostring(plan.key or "")<tostring(low.key or "")) then low=plan end
            if plan.rawTotal<=budget+1e-7 then
                -- Demand/stability determine preferences; on indistinguishable
                -- market ratings, select a more substantial (still capped) offer.
                local demand=finite(plan.givenExitScore) and plan.givenExitScore or 0
                local risk=finite(plan.givenRisk) and plan.givenRisk or 1
                -- Absolute quarter-point bands form a total ordering. Comparing
                -- against a moving best with +/-0.25 allowed unused alternatives
                -- to move the chosen quote through a chain of near-ties.
                local demandBand=math.floor(demand*4+1e-7)
                local riskBand=math.floor(risk*4+1e-7)
                local prior=best and best.plan
                local better=not best
                    or demandBand>best.demandBand
                    or (demandBand==best.demandBand and (riskBand<best.riskBand
                        or (riskBand==best.riskBand and (plan.rawTotal>prior.rawTotal
                            or (plan.rawTotal==prior.rawTotal and ((plan.units or math.huge)<(prior.units or math.huge)
                                or (plan.units==prior.units and (portfolioBetter(plan,prior)==true
                                    or (portfolioBetter(plan,prior)==nil and tostring(plan.key or "")<tostring(prior.key or ""))))))))))
                if better then best={plan=plan,demand=demand,risk=risk,demandBand=demandBand,riskBand=riskBand} end
            end
        end
    end
    -- A small explicit extension is permitted only against verified comparison facts.
    if best and type(theirMarket)=="table" and theirMarket.confidence==true
        and theirMarket.rawTotal==received and finite(theirMarket.exitScore) and finite(theirMarket.riskPoints)
        and theirMarket.exitScore-best.demand>1 then
        local ceiling=budget+math.min(P.maxLateConcession,math.max(0,received-budget-P.minimumProfit)*P.maxLateHeadroomShare)
        local extended
        for _,plan in ipairs(plans or {}) do
            if plan.ok and finite(plan.rawTotal) and plan.rawTotal>0 and plan.rawTotal<=ceiling+1e-7
                and finite(plan.rawProfit) and plan.rawProfit>=P.minimumProfit
                and math.abs(plan.rawTotal+plan.rawProfit-received)<1e-6
                and finite(plan.givenExitScore) and plan.givenExitScore>=theirMarket.exitScore
                and finite(plan.givenRisk) and plan.givenRisk<=theirMarket.riskPoints then
                if not extended or plan.rawTotal<extended.rawTotal
                    or (plan.rawTotal==extended.rawTotal and plan.units==extended.units and portfolioBetter(plan,extended)==true) then extended=plan end
            end
        end
        if extended then return extended,"bounded-comparable-initial-extension" end
    end
    if best then return best.plan,"initial-market-quote" end
    -- No capped candidate: the cheapest verified plan preserves the most
    -- value without fabricating a safe combination that does not exist.
    if low then return low,"initial-fallback-smallest-safe" end
    return nil,"no-verified-initial-plan"
end

-- ONLY for post-cooldown concessions. Each step is bounded relative to the
-- actual current offer and current profit; never use minimum-safe-plan bands.
function P.selectLateConcession(plans,currentTotal,step,verifiedReceived)
    -- Never infer opponent value from candidate data: the live, resolved
    -- their-offer total is supplied separately by the trade controller.
    local ours=cents(currentTotal)
    if not ours or ours<=0 then return nil,"invalid-current-total" end
    local received=cents(verifiedReceived)
    if not received or received<=ours then
        return nil,"missing-or-unsafe-verified-received"
    end
    local headroom=received-ours-P.minimumProfit*100
    if headroom<=0 then return nil,"no-profit-headroom" end
    local maxIncrement=math.min(P.maxLateConcession*100,
        math.floor(headroom*P.maxLateHeadroomShare+1e-7))
    local minIncrement=math.ceil(math.min(P.maxLateMinValue,
        math.max(P.minLateConcession,currentTotal*P.minLateCurrentValueShare))*100-1e-7)
    if maxIncrement<minIncrement then return nil,"no-meaningful-safe-increment" end
    local eligible={}
    for _,plan in ipairs(plans or {}) do
        local pv=cents(plan.rawTotal)
        local profit=cents(plan.rawProfit)
        if plan.ok==true and pv and profit and
            pv+profit==received and profit>=P.minimumProfit*100 and
            pv-ours>=minIncrement and pv-ours<=maxIncrement and
            finite(plan.givenExitScore) and
            finite(plan.givenRisk) then
            eligible[#eligible+1]=plan
        end
    end
    table.sort(eligible,function(a,b)
        -- High demand and stable items first, but tiny demand differences
        -- do not outweigh a materially better value-lift within our cap.
        local ad=math.floor(a.givenExitScore*2+1e-8)
        local bd=math.floor(b.givenExitScore*2+1e-8)
        if ad~=bd then return ad>bd end
        local ar=math.floor(a.givenRisk*2+1e-8)
        local br=math.floor(b.givenRisk*2+1e-8)
        if ar~=br then return ar<br end
        if a.rawTotal~=b.rawTotal then return a.rawTotal>b.rawTotal end
        if a.units~=b.units then return a.units<b.units end
        if a.givenExitScore==b.givenExitScore and a.givenRisk==b.givenRisk then local preserved=portfolioBetter(a,b);if preserved~=nil then return preserved end end
        return tostring(a.key or "")<tostring(b.key or "")
    end)
    if eligible[1] then
        return eligible[1],"current-margin-capped",{
            headroom=headroom/100,cap=maxIncrement/100,
            increment=eligible[1].rawTotal-currentTotal,
            step=step,
        }
    end
    return nil,"no-meaningful-capped-plan"
end

local function safeQuote(total,received)
    local a,b=cents(total),cents(received)
    return a and b and a>0 and b-a>=P.minimumProfit*100
end
function P.observeQuote(state,currentTotal,received,now)
    -- Ownership is independent of whether their latest value is still safe.
    if state.ledger and cents(currentTotal)~=cents(state.ledger.lastVerifiedTotal) then
        return false,"uncommitted-own-quote"
    end
    if not safeQuote(currentTotal,received) then return false,"unsafe-observed-quote" end
    if not state.ledger then
        state.ledger={anchorTotal=currentTotal,maxReceived=received,lastVerifiedTotal=currentTotal,earlySpent=0,lateSpent=0}
    else
        if cents(currentTotal)~=cents(state.ledger.lastVerifiedTotal) then return false,"uncommitted-own-quote" end
        state.ledger.maxReceived=math.max(state.ledger.maxReceived,received)
    end
    state.steps=state.steps or state.lateSteps or 0;state.lateSteps=state.steps
    return true
end
function P.earlyAllowance(state,currentTotal,received)
    local l=state.ledger
    if not l or not safeQuote(currentTotal,received) then return 0 end
    local envelope=math.min(4000,math.floor(math.max(0,math.min(cents(l.maxReceived),cents(received))-cents(l.anchorTotal)-1500)*.4+1e-7))
    local remaining=math.max(0,envelope-cents(l.earlySpent))
    local current=math.min(4000,math.floor(math.max(0,cents(received)-cents(currentTotal)-1500)*.4+1e-7))
    return math.min(remaining,current)/100
end
local function generation(state,signature,total,now)
    if state.signature~=signature then
        state.signature=signature;state.total=total;state.since=now;state.finalSince=nil;state.wasAccepted=false
        state.pending=nil;state.blocked=false
    elseif state.total~=total then state.total=total;state.since=now;state.finalSince=nil end
end
function P.reserveOffer(state,stage,signature,plan,currentTotal,received,now)
    if type(plan)~="table" or plan.ok~=true or not safeQuote(plan.rawTotal,received)
        or not cents(plan.rawProfit) or cents(plan.rawTotal)+cents(plan.rawProfit)~=cents(received)
        or type(signature)~="string" or signature=="" or not finite(now)
        or not cents(currentTotal) then return false,"unsafe-reservation" end
    if stage~="initial" and stage~="rebalance" and stage~="early" and stage~="late" then return false,"unknown-stage" end
    if state.ledger and currentTotal~=state.ledger.lastVerifiedTotal then
        local restoring=(stage=="initial" or stage=="rebalance")
            and (currentTotal==0 or plan.rawTotal<=state.ledger.lastVerifiedTotal)
        if not restoring then return false,"uncommitted-own-quote" end
    end
    generation(state,signature,currentTotal,now)
    if state.blocked then return false,"unverified-generation-held" end
    if state.pending then
        local p=state.pending
        if p.stage==stage and p.signature==signature and p.plan==plan and p.currentTotal==currentTotal and p.received==received then return true,"already-reserved" end
        return false,"reservation-owned"
    end
    if not state.ledger and safeQuote(currentTotal,received) then P.observeQuote(state,currentTotal,received,now) end
    local baseline=state.ledger==nil
    if baseline and not (stage=="initial" and currentTotal==0
        or stage=="rebalance" and currentTotal>0 and plan.rawTotal<currentTotal) then return false,"verified-anchor-required" end
    local reference=currentTotal
    if not baseline and (stage=="initial" or stage=="rebalance") then reference=state.ledger.lastVerifiedTotal end
    local increment=math.max(0,cents(plan.rawTotal)-cents(reference))/100
    if stage=="early" or stage=="late" then
        if cents(plan.rawTotal)<=cents(currentTotal) then return false,"positive-increment-required" end
    end
    if stage=="late" then
        if (state.steps or state.lateSteps or 0)>=2 then return false,"late-step-limit" end
        local candidate=P.selectLateConcession({plan},currentTotal,(state.steps or 0)+1,received)
        if candidate~=plan then return false,"late-budget-exceeded" end
    elseif not baseline and increment>P.earlyAllowance(state,reference,received)+1e-7 then return false,"early-budget-exceeded" end
    state.pending={stage=stage,signature=signature,plan=plan,currentTotal=currentTotal,received=received,
        increment=increment,baseline=baseline,reservedAt=now}
    return true,"reserved"
end
function P.confirmConcession(state,signature,plan,live,now)
    local pending=state.pending
    if not pending or state.signature~=signature or pending.signature~=signature or pending.plan~=plan or not finite(now)
        or not P.planMatches(plan,live) or not safeQuote(live.rawTotal,pending.received)
        or cents(plan.rawProfit)+cents(live.rawTotal)~=cents(pending.received) then return false end
    if live.market and (live.market.confidence~=true or live.market.rawTotal~=live.rawTotal) then return false end
    if not state.ledger then
        if not pending.baseline then return false end
        P.observeQuote(state,live.rawTotal,pending.received,now)
    else
        local l=state.ledger
        if pending.stage=="late" then
            state.steps=(state.steps or state.lateSteps or 0)+1;state.lateSteps=state.steps
            l.lateSpent=(cents(l.lateSpent)+cents(pending.increment))/100
        else l.earlySpent=(cents(l.earlySpent)+cents(pending.increment))/100 end
        l.lastVerifiedTotal=live.rawTotal;l.maxReceived=math.max(l.maxReceived,pending.received)
    end
    state.pending=nil;state.total=live.rawTotal;state.since=now;state.finalSince=nil
    return true
end
function P.cancelConcession(state)
    if state.pending then state.pending=nil;state.blocked=true;state.finalSince=nil end
end
function P.negotiate(state,signature,total,plans,now,accepted,acceptReady,verifiedReceived)
    if not safeQuote(total,verifiedReceived) then return "hold" end
    local observed,why=P.observeQuote(state,total,verifiedReceived,now)
    if not observed then return "unverified-hold",nil,why end
    generation(state,signature,total,now)
    if state.blocked then return "unverified-hold" end
    if state.pending then return "pending-verification" end
    if accepted then state.since=now;state.finalSince=nil;state.wasAccepted=true;return "hold" end
    if state.wasAccepted then state.wasAccepted=false;state.since=now;state.finalSince=nil end
    if acceptReady==false then state.finalSince=nil;return "accept-not-ready" end
    if state.finalSince then
        if now-state.finalSince>=P.finalWaitSeconds then return "decline" end
        return "final-wait"
    end
    if (state.steps or 0)>=2 then
        if now-(state.since or now)<P.sweetenWaitSeconds then return "wait" end
        state.finalSince=now;return "final-wait"
    end
    if now-(state.since or now)<P.sweetenWaitSeconds then return "wait" end
    local candidate=P.selectLateConcession(plans,total,(state.steps or 0)+1,verifiedReceived)
    if candidate then
        local ok=P.reserveOffer(state,"late",signature,candidate,total,verifiedReceived,now)
        if ok then return "improve",candidate end
        return "unverified-hold"
    end
    state.finalSince=now;return "final-wait"
end
function P.observe(state,now,slots,accepted)
    if slots==0 and accepted then return "accepted-empty" end
    if slots>0 and not state.started then state.started=now end
    if state.started and now-state.started>=60 then return "overall-timeout" end
    if slots==0 then
        if not state.emptySince then state.emptySince=now end
        if now-state.emptySince>=12 then return "empty-timeout" end
        return "wait"
    end
    state.emptySince=nil; return "active"
end
return P
