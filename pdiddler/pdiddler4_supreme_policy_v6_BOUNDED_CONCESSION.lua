-- V10 pure Supreme policy: bounded concessions from CURRENT offer; no network, UI, remotes or Accept actions.
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
        exitScore=ok and demand or 0,riskPoints=ok and (r.stability=="Stable" and 0 or 1) or 0,
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
    local b={rawTotal=0,protectedTotal=0,eligibleCopies=0,confidence=fresh(profile),exitScore=0,riskPoints=0,unprofiledCopies=0,disputedCopies=0}
    for _,it in ipairs(items or {}) do
        local a=P.itemAssessment(it,side,b.confidence and record(profile,it) or nil)
        if not a.confidence or not integer(it.qty) then b.confidence=false; b.unprofiledCopies=b.unprofiledCopies+1
        else
            local value=a.rawUnitValue*it.qty
            b.rawTotal=b.rawTotal+value; b.eligibleCopies=b.eligibleCopies+it.qty
            b.exitScore=b.exitScore+a.exitScore*value; b.riskPoints=b.riskPoints+a.riskPoints*value
        end
    end
    b.protectedTotal=b.rawTotal
    if b.rawTotal>0 then b.exitScore=b.exitScore/b.rawTotal; b.riskPoints=b.riskPoints/b.rawTotal end
    return b
end
function P.tradeDecision(ours,theirs)
    ours=ours or {}; theirs=theirs or {}
    local ov,tv=ours.rawTotal,theirs.rawTotal
    local oc,tc=cents(ov),cents(tv)
    local valid=ours.confidence==true and theirs.confidence==true and oc~=nil and tc~=nil and oc>0 and tc>0
    local profit=valid and (tc-oc)/100 or -math.huge
    return {ok=valid and profit>=P.minimumProfit,kind="SUPREME",mode="profit",
        reason=valid and (profit>=P.minimumProfit and "supreme-profit" or "below-plus-15") or "unverified-bundle",
        rawProfit=profit,protectedProfit=profit,requiredProfit=P.minimumProfit,baseRequired=P.minimumProfit,marketPremium=0,
        qualityGain=(theirs.exitScore or 0)-(ours.exitScore or 0)}
end
-- Bands reserve room for two negotiations; they are policy heuristics, not
-- price adjustments or calibrated acceptance probabilities. Within a band,
-- counterparty demand/stability/consolidation outrank raw value donated.
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
    local units={}
    for _,it in ipairs(priced.items) do
        for copy=1,math.min(4,it.qty) do units[#units+1]={item=it,copy=copy} end
    end
    table.sort(units,function(a,b)
        if a.item.value~=b.item.value then return a.item.value<b.item.value end
        if a.item.id~=b.item.id then return a.item.id<b.item.id end
        return a.copy<b.copy
    end)
    local dp={[0]={["0:0:0"]={total=0,picks={},demand=0,risk=0,key=""}},[1]={},[2]={},[3]={},[4]={}}
    local states=1
    for _,u in ipairs(units) do
        local it=u.item; local cents=math.floor(it.value*100+0.5)
        if math.abs(cents/100-it.value)>0.000001 then return {},"unsupported-price-precision" end
        for count=4,1,-1 do
            for _,pack in pairs(dp[count-1]) do
                local nextTotal=pack.total+cents
                if nextTotal<=budget then
                    local demand=pack.demand+it.demand*it.value
                    local key=pack.key.."|"..it.page..":"..it.id..":"..u.copy
                    local risk=pack.risk+(it.stability=="Stable" and 0 or 1)
                    local stateKey=tostring(nextTotal)..":"..tostring(demand)..":"..tostring(risk)
                    local old=dp[count][stateKey]
                    if not old or demand<old.demand or (demand==old.demand and key<old.key) then
                        local picks={}; for i,p in ipairs(pack.picks) do picks[i]=p end
                        picks[#picks+1]=it; dp[count][stateKey]={total=nextTotal,picks=picks,demand=demand,risk=risk,key=key}
                        if not old then states=states+1 end
                        if states>(stateBudget or P.maxStates) then return {},"planner-state-budget" end
                    end
                end
            end
        end
    end
    local plans={}
    for count=1,4 do
        for _,pack in pairs(dp[count]) do
            local total=pack.total/100
            local decision=P.tradeDecision({rawTotal=total,confidence=true,exitScore=pack.demand/total},theirs)
            if decision.ok then
                local picks,map={},{}
                for _,it in ipairs(pack.picks) do
                    local key=it.page..":"..it.id
                    if not map[key] then
                        local p={}; for k,v in pairs(it) do p[k]=v end; p.qty=0; map[key]=p; picks[#picks+1]=p
                    end
                    map[key].qty=map[key].qty+1
                end
                plans[#plans+1]={ok=true,picks=picks,units=count,rawTotal=total,protectedTotal=total,
                    rawProfit=decision.rawProfit,protectedProfit=decision.rawProfit,requiredProfit=15,baseRequired=15,
                    marketPremium=0,kind="SUPREME",mode="profit",qualityGain=decision.qualityGain,
                    givenExitScore=pack.demand/total,givenRisk=pack.risk/count,key=pack.key}
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
function P.selectInitialOffer(plans,received)
    if not finite(received) or received<=P.minimumProfit then return nil,"unknown-received-value" end
    local budget=math.min(received-P.minimumProfit,received*P.maxInitialCounterpartShare)
    local best,low
    for _,plan in ipairs(plans or {}) do
        if type(plan)=="table" and plan.ok==true
            and finite(plan.rawTotal) and plan.rawTotal>0
            and finite(plan.rawProfit) and plan.rawProfit>=P.minimumProfit
            and math.abs(plan.rawTotal+plan.rawProfit-received)<0.00001 then
            if not low or plan.rawTotal<low.rawTotal then low=plan end
            if plan.rawTotal<=budget+1e-7 then
                -- Demand/stability determine preferences; on indistinguishable
                -- market ratings, select a more substantial (still capped) offer.
                local demand=finite(plan.givenExitScore) and plan.givenExitScore or 0
                local risk=finite(plan.givenRisk) and plan.givenRisk or 1
                local better=not best
                    or demand>(best.demand+0.25)
                    or (math.abs(demand-best.demand)<=0.25
                        and (risk<best.risk-0.25
                            or (math.abs(risk-best.risk)<=0.25
                                and plan.rawTotal>best.plan.rawTotal)))
                if better then best={plan=plan,demand=demand,risk=risk} end
            end
        end
    end
    if best then return best.plan,"initial-market-quote" end
    -- No capped candidate: the cheapest verified plan preserves the most
    -- value without fabricating a safe combination that does not exist.
    if low then return low,"initial-fallback-smallest-safe" end
    return nil,"no-verified-initial-plan"
end

-- ONLY for post-cooldown concessions. Each step is bounded relative to the
-- actual current offer and current profit; never use minimum-safe-plan bands.
function P.selectLateConcession(plans,currentTotal,step)
    local ours=cents(currentTotal)
    if not ours or ours<=0 then return nil,"invalid-current-total" end
    local received
    for _,plan in ipairs(plans or {}) do
        if type(plan)=="table" and plan.ok==true
            and finite(plan.rawTotal) and finite(plan.rawProfit) then
            local v=cents(plan.rawTotal+plan.rawProfit)
            if v and v>ours then received=v;break end
        end
    end
    if not received then return nil,"no-priced-received-total" end
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

function P.negotiate(state,signature,total,plans,now,accepted,acceptReady)
    -- One trade-generation owns one negotiation. A change invalidates old waits.
    -- MM2's observed cooldown was approximately 6s; wait 9s after the
    -- verified offer/state change before sweetening, leaving ~3s to accept.
    -- This is a conservative time-based approximation, not a proven UI-ready event.
    if state.signature~=signature then
        state.signature=signature; state.total=total; state.since=now
        state.steps=0; state.finalSince=nil; state.wasAccepted=false
    elseif state.total~=total then
        -- Our actual offer has changed: never reuse a prior final countdown.
        state.total=total; state.since=now; state.finalSince=nil
    end
    if accepted then
        -- No voluntary mutation/decline while the other side is accepted.
        -- Restart the observation interval if that state clears.
        state.since=now; state.finalSince=nil; state.wasAccepted=true
        return "hold"
    end
    if state.wasAccepted then
        -- The first observed unaccepted state begins a new full wait.
        state.wasAccepted=false; state.since=now; state.finalSince=nil
    end
    -- When the live P4 supplies an explicit native-UI readiness verdict,
    -- no sweetening or final decline is permitted until Accept has been
    -- verifiably available for the additional 2.5-second buffer.
    -- nil retains legacy pure-test semantics only; V8 runtime passes boolean.
    if acceptReady==false then
        state.finalSince=nil
        return "accept-not-ready"
    end
    if state.finalSince then
        if now-state.finalSince>=P.finalWaitSeconds then return "decline" end
        return "final-wait"
    end
    if state.steps>=2 then
        -- The last sweeten resets MM2's cooldown too. Do not start a final
        -- decline clock until this verified offer has had its full 9s window.
        if now-(state.since or now)<P.sweetenWaitSeconds then return "wait" end
        state.finalSince=now
        return "final-wait"
    end
    if now-(state.since or now)<P.sweetenWaitSeconds then return "wait" end
    local candidate,why=P.selectLateConcession(plans,total,state.steps+1)
    if candidate then
        state.steps=state.steps+1
        state.since=now
        return "improve",candidate
    end
    -- No available improvement is not grounds to decline immediately.
    -- Let the currently profitable offer sit for a final uninterrupted 5s.
    state.finalSince=now
    return "final-wait"
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
