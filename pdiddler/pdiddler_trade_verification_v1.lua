-- Pure verification contracts, NOT a native MM2 protocol adapter.
-- Callers must supply canonical price/identity proofs and correlated native evidence.
-- The Delta loader deliberately does not enable native acceptance/completion.
local V={}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function integer(n) return finite(n) and n>=0 and n==math.floor(n) end
local function cents(n)
    if not finite(n) or n<0 then return nil end
    local c=math.floor(n*100+.5)
    if math.abs(c-n*100)>0.000001 then return nil end
    return c
end
local function clone(t)
    if type(t)~="table" then return t end
    local out={}; for k,v in pairs(t) do out[k]=clone(v) end; return out
end
function V.finalReady(state,p,now)
    if type(p)~="table" then state.key=nil; state.since=nil; state.ready=false; return false end
    local good=type(p)=="table" and finite(now) and p.id and p.job and p.epoch and p.partner and p.gui and p.version
        and type(p.ourSig)=="string" and p.ourSig~="" and type(p.theirSig)=="string" and p.theirSig~=""
        and p.plannedOurSig==p.ourSig and p.valuedTheirSig==p.theirSig
        and p.pricesCurrent==true and p.identitiesVerified==true and p.quantitiesVerified==true
        and p.ourAccepted==true and p.theirAccepted==true and p.cooldownKnown==true and p.cooldown==0 and p.changing==false
    local oc,tc=p and cents(p.ourTotal),p and cents(p.theirTotal)
    if not good or not oc or not tc or oc<=0 or tc-oc<1500 then state.key=nil; state.since=nil; state.ready=false; return false end
    -- Length-prefix every component; item names/IDs cannot collide with separators.
    local parts={}; for _,k in ipairs({"id","job","epoch","partner","gui","version","ourSig","theirSig"}) do
        local value=tostring(p[k]); parts[#parts+1]=#value..":"..value
    end
    parts[#parts+1]=tostring(oc)..":"..tostring(tc)
    local key=table.concat(parts,"|")
    if state.key~=key then state.key=key; state.since=now; state.ready=false end
    if state.consumed or now-state.since<1 then return false end
    state.ready=true; return true,key
end
function V.consume(state,token)
    if not state.ready or state.consumed or not token or state.key~=token then return false end
    state.consumed=true; return true
end
function V.reconcile(t,event,after,profile,policy)
    if type(t)~="table" or type(event)~="table" or event.kind~="completed" or type(after)~="table" then return nil,"unconfirmed-outcome" end
    for _,key in ipairs({"id","job","epoch","partner","ourSig","theirSig"}) do
        if t[key]==nil or t[key]~=event[key] then return nil,"uncorrelated-completion" end
    end
    if after.complete~=true or after.wholeInventoryVerified~=true or after.version~=t.version
        or not cents(after.total) or type(after.counts)~="table" or type(t.before)~="table" then return nil,"inventory-unverified" end
    if not profile or not profile.isFresh() or profile.version~=t.version or not policy
        or not integer(after.stableReads) or after.stableReads<2 then return nil,"valuation-or-stability-unproved" end
    local function priced(items)
        if type(items)~="table" then return nil end
        local inv,why=policy.reprice({items=items},profile)
        if not inv or why or inv.unmapped~=0 or inv.unpriced~=0 or inv.badQty~=0 then return nil end
        return inv
    end
    local all=priced(after.items)
    local given=priced(t.give); local received=priced(t.receive)
    if not all or not given or not received then return nil,"canonical-valuation-incomplete" end
    local valuedCounts={}; for _,it in ipairs(all.items) do valuedCounts[it.id]=it.qty end
    for id,q in pairs(after.counts) do if q~=(valuedCounts[id] or 0) then return nil,"whole-inventory-unpriced" end end
    for id,q in pairs(valuedCounts) do if q~=(after.counts[id] or 0) then return nil,"whole-inventory-quantity-mismatch" end end
    for _,list in ipairs({t.give,t.receive}) do for _,it in ipairs(list) do
        if type(it)~="table" or not profile.get(it.page,it.checkerId) or it.value~=profile.get(it.page,it.checkerId).supremeValue then return nil,"trade-price-contradiction" end
    end end
    local expected={}; for id,q in pairs(t.before) do if not integer(q) then return nil,"invalid-before-quantity" end; expected[id]=q end
    local function side(items,direction)
        if type(items)~="table" or #items==0 then return nil end
        local total,seen=0,{}
        for _,it in ipairs(items) do
            local value=cents(it.value)
            if type(it.id)~="string" or it.id=="" or seen[it.id] or not integer(it.qty) or it.qty<1
                or not value or value<=0 or not finite(it.demand) or it.demand<0 then return nil end
            seen[it.id]=true; total=total+value*it.qty
            expected[it.id]=(expected[it.id] or 0)+direction*it.qty
            if expected[it.id]<0 then return nil end
        end
        return total
    end
    local give=side(t.give,-1); local receive=side(t.receive,1)
    if not give or not receive or receive-give<1500 then return nil,"unverified-or-unprofitable-items" end
    for id,q in pairs(expected) do if (after.counts[id] or 0)~=q then return nil,"inventory-delta-mismatch" end end
    for id,q in pairs(after.counts) do if not integer(q) or q~=(expected[id] or 0) then return nil,"unrelated-inventory-change" end end
    local report={id=t.id,job=t.job,partner=t.partner,version=t.version,verified=true,
        give=clone(given.items),receive=clone(received.items),givenTotal=give/100,receivedTotal=receive/100,
        profit=(receive-give)/100,inventoryTotal=all.total,time=event.time}
    for _,list in ipairs({report.give,report.receive}) do for _,it in ipairs(list) do local r=profile.get(it.page,it.checkerId); it.liquidity=r.liquidity or "unavailable" end end
    return report
end
return V
