-- Outgoing-request feasibility only. No UI, remotes, clocks, mutation, or negotiation policy.
-- Full verified quantities prove impossibility; a supported <=4-row witness proves reachability.
-- Unproved stacked-slot capacity and planner failures remain unknown.
local F={}
local MAX_INTEGER=9007199254740991
local function finite(n)
    return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge
end
local function integer(n)
    return finite(n) and n>=0 and n<=MAX_INTEGER and n==math.floor(n)
end
local function cents(n)
    if not finite(n) or n<=0 or n>MAX_INTEGER/100 then return nil end
    local scaled=n*100
    local rounded=math.floor(scaled+0.5)
    if rounded>MAX_INTEGER or math.abs(scaled-rounded)>0.000001 then return nil end
    return rounded
end
local function canonical(it)
    return tostring(it.page)..":"..tostring(it.checkerId or it.id)
end
local function copyOne(it)
    local copy={}
    for k,v in pairs(it) do copy[k]=v end
    copy.qty=1
    return copy
end
local function fresh(profile)
    if type(profile)~="table" or type(profile.get)~="function" or type(profile.isFresh)~="function" then return false end
    local ok,value=pcall(profile.isFresh)
    return ok and value==true
end
local function structure(inv)
    if type(inv)~="table" or type(inv.items)~="table" then return false end
    for _,key in ipairs({"unmapped","unpriced","badQty"}) do
        if not integer(inv[key]) or inv[key]~=0 then return false end
    end
    local count=0
    local seen={}
    for key,it in pairs(inv.items) do
        if not integer(key) or key<1 or key>#inv.items or type(it)~="table" then return false end
        count=count+1
        if type(it.id)~="string" or it.id=="" or seen[it.id] or not integer(it.qty) or it.qty<1 then return false end
        seen[it.id]=true
    end
    return count==#inv.items
end
local function verified(inv,profile,policy)
    if not structure(inv) then return nil,"inventory-incomplete" end
    local ok,priced,why=pcall(policy.reprice,inv,profile)
    if not ok or why or not structure(priced) or #priced.items~=#inv.items then return nil,"inventory-unverified" end
    for _,it in ipairs(priced.items) do
        if not cents(it.value) then return nil,"unsupported-price-precision" end
    end
    return priced
end
local function candidate(own,theirs)
    local key=canonical(own)
    local upper=0
    local rows={}
    for _,it in ipairs(theirs.items) do
        if canonical(it)~=key then
            local unit=cents(it.value)
            -- Exact conservative totals must stay inside the integer arithmetic range.
            if it.qty>math.floor(MAX_INTEGER/unit) then return nil,nil,"inventory-total-overflow" end
            local subtotal=unit*it.qty
            if upper>MAX_INTEGER-subtotal then return nil,nil,"inventory-total-overflow" end
            upper=upper+subtotal
            rows[#rows+1]=it
        end
    end
    table.sort(rows,function(a,b)
        if a.value~=b.value then return a.value>b.value end
        return a.id<b.id
    end)
    local received={}
    local total=0
    for i=1,math.min(4,#rows) do
        local unit=cents(rows[i].value)
        if total>MAX_INTEGER-unit then return nil,nil,"inventory-total-overflow" end
        total=total+unit
        received[#received+1]=copyOne(rows[i])
    end
    return upper,{items=received,cents=total}
end

-- Shared own-read validation: successful RPC delivery alone is not verified inventory.
function F.validateInventory(inv,profile,policy)
    if not fresh(profile) then return nil,"supreme-profile-stale" end
    if type(policy)~="table" or type(policy.reprice)~="function" then return nil,"strict-policy-unavailable" end
    return verified(inv,profile,policy)
end

function F.evaluate(ownInventory,theirInventory,profile,policy)
    if not fresh(profile) then return "unknown","supreme-profile-stale" end
    if type(policy)~="table" or type(policy.reprice)~="function" or type(policy.bundleAssessment)~="function"
        or type(policy.buildPlans)~="function" or type(policy.tradeDecision)~="function" then
        return "unknown","strict-policy-unavailable"
    end
    local ours,ownWhy=F.validateInventory(ownInventory,profile,policy)
    if not ours then return "unknown",ownWhy end
    local theirs,theirWhy=F.validateInventory(theirInventory,profile,policy)
    if not theirs then return "unknown",theirWhy end
    if #ours.items==0 then return "unknown","no-verified-owned-giveaway" end
    local possible=false
    local unknownReason="slot-capacity-unverified"
    for _,owned in ipairs(ours.items) do
        local ownCents=cents(owned.value)
        local upper,received,why=candidate(owned,theirs)
        if not upper then return "unknown",why end
        if upper-ownCents>=1500 then
            possible=true
            if received.cents-ownCents>=1500 then
                local ownItem=copyOne(owned)
                local ownSubset={items={ownItem},unmapped=0,unpriced=0,badQty=0}
                local marketOK,market=pcall(policy.bundleAssessment,received.items,"theirs",profile)
                if marketOK and market and market.confidence==true then
                    local planOK,plans,planWhy=pcall(policy.buildPlans,ownSubset,market,profile)
                    if planOK and type(plans)=="table" and not planWhy then
                        for _,plan in ipairs(plans) do
                            local pick=type(plan)=="table" and type(plan.picks)=="table" and plan.picks[1]
                            if pick and #plan.picks==1 and plan.units==1 and pick.qty==1 and pick.id==ownItem.id
                                and canonical(pick)==canonical(ownItem) and cents(plan.rawTotal)==ownCents then
                                local quoteOK,quote=pcall(policy.tradeDecision,
                                    {rawTotal=ownCents/100,confidence=true,items={ownItem}},market)
                                if quoteOK and quote and quote.ok==true and fresh(profile) then
                                    return "reachable","verified-feasible-witness",{
                                        ourValue=ownCents/100,theirValue=received.cents/100,
                                        profit=(received.cents-ownCents)/100,
                                        theirItems=received.items,ownItem=ownItem,
                                    }
                                end
                            end
                        end
                    end
                end
                unknownReason="planner-witness-unverified"
            end
        end
    end
    if not fresh(profile) then return "unknown","supreme-profile-stale" end
    -- Any valid positive-value multi-item giveaway contains a cheaper valid single.
    -- Thus failure of every full-quantity upper bound proves no 1–4-slot giveaway can work.
    if not possible then return "unprofitable","profit-unreachable" end
    return "unknown",unknownReason
end
return F
