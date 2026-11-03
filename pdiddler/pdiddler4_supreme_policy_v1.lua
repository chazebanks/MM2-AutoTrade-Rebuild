-- Pure Supreme policy. No network, GUI, remotes, acceptance or completion claims.
local P={minimumProfit=15,maxStates=50000}
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
function P.rankPlans(plans)
    table.sort(plans,function(a,b)
        if a.rawTotal~=b.rawTotal then return a.rawTotal>b.rawTotal end
        if a.units~=b.units then return a.units<b.units end
        -- At the same price preserve stronger-demand inventory; no invented resale multiplier.
        if a.givenExitScore~=b.givenExitScore then return a.givenExitScore<b.givenExitScore end
        return a.key<b.key
    end)
    return plans
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
    local dp={[0]={[0]={picks={},demand=0,key=""}},[1]={},[2]={},[3]={},[4]={}}
    local states=1
    for _,u in ipairs(units) do
        local it=u.item; local cents=math.floor(it.value*100+0.5)
        if math.abs(cents/100-it.value)>0.000001 then return {},"unsupported-price-precision" end
        for count=4,1,-1 do
            for total,pack in pairs(dp[count-1]) do
                local nextTotal=total+cents
                if nextTotal<=budget then
                    local demand=pack.demand+it.demand*it.value
                    local key=pack.key.."|"..it.page..":"..it.id..":"..u.copy
                    local old=dp[count][nextTotal]
                    if not old or demand<old.demand or (demand==old.demand and key<old.key) then
                        local picks={}; for i,p in ipairs(pack.picks) do picks[i]=p end
                        picks[#picks+1]=it; dp[count][nextTotal]={picks=picks,demand=demand,key=key}
                        if not old then states=states+1 end
                        if states>(stateBudget or P.maxStates) then return {},"planner-state-budget" end
                    end
                end
            end
        end
    end
    local plans={}
    for count=1,4 do
        for cents,pack in pairs(dp[count]) do
            local total=cents/100
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
                    givenExitScore=pack.demand/total,key=pack.key}
            end
        end
    end
    return P.rankPlans(plans),nil
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
function P.negotiate(state,signature,total,plans,now,accepted)
    if state.signature~=signature or state.total~=total then state.signature=signature; state.total=total; state.since=now end
    if accepted then state.since=now; return "hold" end
    if now-(state.since or now)<5 then return "wait" end
    local nextPlan
    for _,plan in ipairs(plans or {}) do
        if plan.rawTotal>total and (not nextPlan or plan.rawTotal<nextPlan.rawTotal) then nextPlan=plan end
    end
    if nextPlan then return "improve",nextPlan end
    return "decline"
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
