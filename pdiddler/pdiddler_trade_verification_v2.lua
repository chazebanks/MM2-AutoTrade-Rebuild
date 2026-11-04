-- Pure contracts only. Native correlation, complete raw reads and submission
-- timestamps must be supplied by the single transaction owner.
local V={}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function integer(n) return finite(n) and n>=0 and n==math.floor(n) end
local function text(s) return type(s)=="string" and s~="" end
local function cents(n)
    if not finite(n) or n<0 then return nil end
    local value=math.floor(n*100+.5)
    return math.abs(value-n*100)<.000001 and value or nil
end
local function clone(t)
    if type(t)~="table" then return t end
    local out={};for k,v in pairs(t) do out[k]=clone(v) end;return out
end
local identity={"id","job","epoch","partner","ourSig","theirSig"}
local function correlated(a,b,version)
    for _,key in ipairs(identity) do if a[key]==nil or a[key]~=b[key] then return false end end
    return not version or a.version==b.version
end
function V.finalReady(state,p,now)
    if type(state)~="table" then return false end
    local function invalidate() state.key=nil;state.since=nil;state.ready=false;return false end
    if type(p)~="table" or not finite(now) then return invalidate() end
    local good=p.id and p.job and p.epoch and p.partner and p.gui and p.version
        and text(p.ourSig) and text(p.theirSig) and p.plannedOurSig==p.ourSig and p.valuedTheirSig==p.theirSig
        and p.pricesCurrent==true and p.identitiesVerified==true and p.quantitiesVerified==true
        and p.ourAccepted==true and p.theirAccepted==true and p.cooldownKnown==true
        and p.cooldown==0 and p.changing==false
    local ours,theirs=cents(p.ourTotal),cents(p.theirTotal)
    if not good or not ours or not theirs or ours<=0 or theirs-ours<1500 then return invalidate() end
    local parts={}
    for _,key in ipairs({"id","job","epoch","partner","gui","version","ourSig","theirSig"}) do
        local value=tostring(p[key]);parts[#parts+1]=#value..":"..value
    end
    parts[#parts+1]=tostring(ours)..":"..tostring(theirs)
    local key=table.concat(parts,"|")
    if state.key~=key or not finite(state.since) or now<state.since then state.key=key;state.since=now;state.ready=false end
    if state.consumed or now-state.since<1 then return false end
    state.ready=true;return true,key
end
function V.consume(state,token)
    if type(state)~="table" or not state.ready or state.consumed or not token or state.key~=token then return false end
    state.consumed=true;return true
end
local function rawCounts(counts)
    if type(counts)~="table" then return nil end
    local out={}
    for id,qty in pairs(counts) do if not text(id) or not integer(qty) then return nil end;out[id]=qty end
    return out
end
local function valuationProfile(t,profile)
    if type(profile)~="table" or profile.version~=t.version or type(profile.isFresh)~="function" or type(profile.get)~="function" then return nil end
    local ok,current=pcall(profile.isFresh)
    if ok and current==true then return profile,false end
    local proof=t.submission
    if type(proof)~="table" or proof.verified~=true or not correlated(t,proof,true)
        or not integer(proof.atEpoch) or not integer(profile.observedAtEpoch) or not integer(profile.expiresAtEpoch)
        or profile.expiresAtEpoch<=profile.observedAtEpoch or proof.atEpoch<profile.observedAtEpoch
        or proof.atEpoch>=profile.expiresAtEpoch then return nil end
    -- A local facade permits historical canonical repricing only after checking
    -- this exact submission against the immutable profile's own time bounds.
    local pinned={};for key,value in pairs(profile) do pinned[key]=value end
    pinned.isFresh=function() return true end
    return pinned,true
end
function V.reconcile(t,event,after,profile,policy)
    if type(t)~="table" or type(event)~="table" or event.kind~="completed" or type(after)~="table" then return nil,"unconfirmed-outcome" end
    if not text(t.id) or not text(t.job) or not text(t.version) or not text(t.ourSig) or not text(t.theirSig)
        or not correlated(t,event) then return nil,"uncorrelated-completion" end
    if t.beforeComplete~=true or after.complete~=true or after.version~=t.version then return nil,"inventory-unverified" end
    local before,counts=rawCounts(t.before),rawCounts(after.counts)
    if not before or not counts then return nil,"invalid-raw-inventory" end
    if not integer(after.stableReads) or after.stableReads<2 then return nil,"inventory-not-stable" end
    local pinned,historical=valuationProfile(t,profile)
    if not pinned or type(policy)~="table" or type(policy.reprice)~="function" then return nil,"valuation-or-stability-unproved" end
    local function price(items)
        local ok,inv,why=pcall(policy.reprice,{items=items},pinned)
        if not ok or type(inv)~="table" or why or inv.unmapped~=0 or inv.unpriced~=0 or inv.badQty~=0 then return nil end
        return inv
    end
    local expected=clone(before)
    local function side(items,direction)
        if type(items)~="table" or #items==0 then return nil end
        local total,seen=0,{}
        for _,it in ipairs(items) do
            if type(it)~="table" or not text(it.id) or seen[it.id] or not integer(it.qty) or it.qty<1 then return nil end
            local value=cents(it.value)
            local ok,row=pcall(pinned.get,it.page,it.checkerId)
            if not value or value<=0 or not ok or type(row)~="table" or row.supremeValue~=it.value then return nil end
            seen[it.id]=true;total=total+value*it.qty
            expected[it.id]=(expected[it.id] or 0)+direction*it.qty
            if expected[it.id]<0 then return nil end
        end
        local priced=price(items)
        if not priced then return nil end
        return total,priced.items
    end
    local given,give=side(t.give,-1)
    local received,receive=side(t.receive,1)
    if not given or not received or received-given<1500 then return nil,"unverified-or-unprofitable-items" end
    for id,qty in pairs(expected) do if (counts[id] or 0)~=qty then return nil,"inventory-delta-mismatch" end end
    for id,qty in pairs(counts) do if qty~=(expected[id] or 0) then return nil,"unrelated-inventory-change" end end
    if type(after.items)~="table" then return nil,"inventory-metadata-unavailable" end
    local seen,pricedCounts,pricedTotal={},{},0
    for _,it in ipairs(after.items) do
        if type(it)~="table" or not text(it.id) or seen[it.id] or not integer(it.qty) or it.qty<1
            or it.qty>(counts[it.id] or 0) then return nil,"inventory-metadata-contradiction" end
        seen[it.id]=true
        local inv=price({it})
        if inv then
            local canonical=inv.items[1]
            local value=canonical and cents(canonical.value)
            if not value then return nil,"unsupported-price-precision" end
            pricedCounts[it.id]=canonical.qty;pricedTotal=pricedTotal+value*canonical.qty
        end
    end
    local unpricedTypes,unpricedCopies=0,0
    for id,qty in pairs(counts) do
        local missing=qty-(pricedCounts[id] or 0)
        if missing>0 then unpricedTypes=unpricedTypes+1;unpricedCopies=unpricedCopies+missing end
    end
    local report={kind="completed-trade",provenance="exact-raw-delta-v2",verified=true,rawInventoryVerified=true,
        id=t.id,job=t.job,epoch=t.epoch,partner=t.partner,version=t.version,ourSig=t.ourSig,theirSig=t.theirSig,
        give=clone(give),receive=clone(receive),givenTotal=given/100,receivedTotal=received/100,profit=(received-given)/100,
        pricedInventoryTotal=pricedTotal/100,unpricedTypes=unpricedTypes,unpricedCopies=unpricedCopies,
        inventoryTotal=unpricedCopies==0 and pricedTotal/100 or nil,time=event.time,valuationAtSubmission=historical==true}
    for _,list in ipairs({report.give,report.receive}) do for _,it in ipairs(list) do
        local row=pinned.get(it.page,it.checkerId);it.liquidity=row.liquidity or "unavailable"
    end end
    return report
end
return V
