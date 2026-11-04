-- Pure outcome/outbox contracts. --baseline reproduces old-contract failures.
local baseline=arg and arg[1]=="--baseline"
local V=dofile("pdiddler/pdiddler_trade_verification_"..(baseline and "v1" or "v2")..".lua")
local O=dofile("pdiddler/pdiddler_webhook_outbox_"..(baseline and "v2" or "v3")..".lua")
local P=dofile("pdiddler/pdiddler4_supreme_policy_v8_PORTFOLIO_LEDGER.lua")
local passed,failed=0,0
local function test(name,fn)
    local ok,why=pcall(fn)
    if ok then passed=passed+1;print("PASS "..name)
    else failed=failed+1;print("FAIL "..name..": "..tostring(why)) end
end
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function clone(t) if type(t)~="table" then return t end;local out={};for k,v in pairs(t) do out[k]=clone(v) end;return out end
local function fixture()
    local rows={A=100,B=115}
    local profile={version="prices",observedAtEpoch=100,expiresAtEpoch=200,fresh=true}
    profile.isFresh=function(now) if now then return now>=100 and now<200 end;return profile.fresh end
    profile.get=function(page,id)
        if page~="godly" or not rows[id] then return nil end
        return {page=page,id=id,name=id,supremeValue=rows[id],demand=3,stability="Stable",verified=true}
    end
    local function item(id,qty) return {id=id,checkerId=id,page="godly",cat="Weapons",type="Knife",name=id,qty=qty,value=rows[id],demand=3} end
    local t={id="tx1",job="job",epoch=1,partner=2,version="prices",ourSig="a",theirSig="b",
        beforeComplete=true,before={A=2,B=0},give={item("A",1)},receive={item("B",1)}}
    local e={kind="completed",id=t.id,job=t.job,epoch=t.epoch,partner=t.partner,ourSig=t.ourSig,theirSig=t.theirSig,time=210}
    local a={counts={A=1,B=1},items={item("A",1),item("B",1)},stableReads=2,version="prices",complete=true,wholeInventoryVerified=true,total=215}
    local function submission(at)
        local proof={verified=true,atEpoch=at}
        for _,key in ipairs({"id","job","epoch","partner","ourSig","theirSig","version"}) do proof[key]=t[key] end
        t.submission=proof;return proof
    end
    return t,e,a,profile,item,submission
end
local function report()
    local t,e,a,p=fixture();return assert(V.reconcile(t,e,a,p,P))
end
local function finalProof()
    return {id="tx1",job="job",epoch=1,partner=2,gui="gui",version="prices",ourSig="a",theirSig="b",
        plannedOurSig="a",valuedTheirSig="b",ourTotal=100,theirTotal=115,pricesCurrent=true,
        identitiesVerified=true,quantitiesVerified=true,ourAccepted=true,theirAccepted=true,cooldownKnown=true,cooldown=0,changing=false}
end
local function durable(ledger,hook)
    local disk={}
    local function persist(snapshot) if hook then local ok=hook(snapshot);if ok~=nil then return ok end end;disk=clone(snapshot);return true end
    return O.new(ledger or {},true,{persist=persist}),function() return disk end
end
local function acknowledged() return {status=204,receipt={acknowledged=true}} end

test("final proof needs uninterrupted extra second and one-use consumption",function()
    local state,p={},finalProof();assert(not V.finalReady(state,p,0));assert(not V.finalReady(state,p,.99))
    local ok,token=V.finalReady(state,p,1);assert(ok);assert(V.consume(state,token));assert(not V.consume(state,token));assert(not V.finalReady(state,p,2))
end)
test("changed offer and unknown cooldown restart final proof",function()
    local state,p={},finalProof();V.finalReady(state,p,0);p.theirSig="c";assert(not V.finalReady(state,p,2))
    p.valuedTheirSig="c";assert(not V.finalReady(state,p,2));p.cooldownKnown=false;assert(not V.finalReady(state,p,3))
end)
test("invalidated ready proof cannot be consumed",function()
    local state,p={},finalProof();V.finalReady(state,p,0);local _,token=V.finalReady(state,p,1)
    p.changing=true;assert(not V.finalReady(state,p,1.1));assert(not V.consume(state,token))
end)
test("below-floor and nonfinite final proof never becomes ready",function()
    local p=finalProof();p.theirTotal=114.99;assert(not V.finalReady({},p,1));p.theirTotal=115;assert(not V.finalReady({},p,math.huge))
end)
test("completed proof has distinct provenance and exact totals",function()
    local r=report();eq(r.kind,"completed-trade");eq(r.provenance,"exact-raw-delta-v2");assert(r.rawInventoryVerified)
    eq(r.profit,15);eq(r.pricedInventoryTotal,215);eq(r.inventoryTotal,215);eq(r.unpricedTypes,0);eq(r.unpricedCopies,0)
end)
test("unchanged unpriced raw holdings permit completed subtotal report",function()
    local t,e,a,p=fixture();t.before.Common=5;a.counts.Common=5;a.wholeInventoryVerified=false;a.total=nil
    local r,why=V.reconcile(t,e,a,p,P);assert(r,why);eq(r.pricedInventoryTotal,215);eq(r.inventoryTotal,nil);eq(r.unpricedTypes,1);eq(r.unpricedCopies,5)
end)
test("unpriceable metadata counts as unknown without invented zero value",function()
    local t,e,a,p,item=fixture();t.before.Common=5;a.counts.Common=5;a.items[#a.items+1]=item("Common",5)
    local r,why=V.reconcile(t,e,a,p,P);assert(r,why);eq(r.unpricedCopies,5);eq(r.pricedInventoryTotal,215);eq(r.inventoryTotal,nil)
end)
test("partial priced row coverage counts remaining copies accurately",function()
    local t,e,a,p=fixture();t.before.A=4;a.counts.A=3
    local r,why=V.reconcile(t,e,a,p,P);assert(r,why);eq(r.pricedInventoryTotal,215);eq(r.unpricedTypes,1);eq(r.unpricedCopies,2);eq(r.inventoryTotal,nil)
end)
test("caller monetary totals never override canonical subtotal",function()
    local t,e,a,p=fixture();a.total=9999;local r=assert(V.reconcile(t,e,a,p,P));eq(r.pricedInventoryTotal,215)
end)
test("missing complete before evidence rejects even exact delta",function()
    local t,e,a,p=fixture();t.beforeComplete=nil;assert(not V.reconcile(t,e,a,p,P))
end)
test("incomplete after and one stable read reject outcome",function()
    local t,e,a,p=fixture();a.complete=false;assert(not V.reconcile(t,e,a,p,P));a.complete=true;a.stableReads=1;assert(not V.reconcile(t,e,a,p,P))
end)
test("bare boolean closure and wrong correlation never prove completion",function()
    local t,e,a,p=fixture();assert(not V.reconcile(t,true,a,p,P));e.kind="closed";assert(not V.reconcile(t,e,a,p,P));e.kind="completed";e.epoch=0;assert(not V.reconcile(t,e,a,p,P))
end)
test("unrelated positive and negative raw deltas reject completion",function()
    local t,e,a,p=fixture();a.counts.Unrelated=1;assert(not V.reconcile(t,e,a,p,P));a.counts.Unrelated=nil;t.before.Unrelated=1;assert(not V.reconcile(t,e,a,p,P))
end)
test("invalid raw identifiers quantities and negative ownership reject",function()
    local t,e,a,p=fixture();t.before[7]=1;assert(not V.reconcile(t,e,a,p,P));t.before[7]=nil;a.counts.A=.5;assert(not V.reconcile(t,e,a,p,P))
    a.counts.A=math.huge;assert(not V.reconcile(t,e,a,p,P));a.counts.A=1;t.before.A=0;assert(not V.reconcile(t,e,a,p,P))
end)
test("traded items require exact canonical prices and fifteen profit",function()
    local t,e,a,p=fixture();t.receive[1].value=114.99;assert(not V.reconcile(t,e,a,p,P));t.receive[1].value=nil;assert(not V.reconcile(t,e,a,p,P))
end)
test("duplicate traded raw IDs and duplicate inventory metadata reject",function()
    local t,e,a,p=fixture();t.give[2]=clone(t.give[1]);assert(not V.reconcile(t,e,a,p,P));t.give[2]=nil;a.items[3]=clone(a.items[1]);assert(not V.reconcile(t,e,a,p,P))
end)
test("priced subset cannot exceed or invent raw holdings",function()
    local t,e,a,p=fixture();a.items[1].qty=2;assert(not V.reconcile(t,e,a,p,P));a.items[1].qty=1;a.items[2].id="Different";assert(not V.reconcile(t,e,a,p,P))
end)
test("pinned pre-expiry submission may reconcile after expiry",function()
    local t,e,a,p,_,submission=fixture();submission(150);p.fresh=false
    local r,why=V.reconcile(t,e,a,p,P);assert(r,why);eq(r.profit,15);assert(r.valuationAtSubmission==true)
end)
test("expiry exception requires matching verified submission identity",function()
    local t,e,a,p,_,submission=fixture();p.fresh=false;assert(not V.reconcile(t,e,a,p,P))
    local proof=submission(150);proof.partner=99;assert(not V.reconcile(t,e,a,p,P));proof.partner=2;proof.verified=false;assert(not V.reconcile(t,e,a,p,P))
end)
test("expiry exception rejects boundary future and unsupported profile bounds",function()
    local t,e,a,p,_,submission=fixture();p.fresh=false;submission(200);assert(not V.reconcile(t,e,a,p,P));submission(99);assert(not V.reconcile(t,e,a,p,P))
    submission(150);p.expiresAtEpoch=nil;assert(not V.reconcile(t,e,a,p,P))
end)
test("outbox refuses open-trade quote even if verified flag is true",function()
    local o=durable();assert(not o.enqueue({id="quote",verified=true,tradeOpen=true}));assert(not o.enqueue({id="quote",verified=true,kind="completed-trade"}))
end)
test("outbox refuses tampered completed totals and unknown coverage",function()
    local o=durable();local r=report();r.profit=99;assert(not o.enqueue(r));r=report();r.unpricedCopies=1;assert(not o.enqueue(r))
end)
test("enabled outbox requires explicit durable persistence",function()
    local o=O.new({},true);assert(not o.enqueue(report()));eq(o.state,"persistence-unavailable")
end)
test("disabled outbox invokes no persistence or transport",function()
    local called=0;local o=O.new({},false,{persist=function() called=called+1;return true end});assert(not o.enqueue(report()));assert(not o.deliver("tx1",0,function() called=called+1 end));eq(called,0)
end)
test("enqueue persists copied report before accepting ownership",function()
    local o,disk=durable();local r=report();assert(o.enqueue(r));r.give[1].value=1;eq(o.ledger.tx1.report.give[1].value,100);eq(disk().tx1.state,"queued")
end)
test("failed enqueue persistence rolls back without ownership",function()
    local o=durable({},function() return false end);assert(not o.enqueue(report()));eq(o.ledger.tx1,nil)
end)
test("durable sending precedes transport and acknowledged result is persisted",function()
    local o,disk=durable();assert(o.enqueue(report()));local calls=0
    assert(o.deliver("tx1",0,function() calls=calls+1;eq(disk().tx1.state,"sending");eq(disk().tx1.attempts,1);return acknowledged() end))
    eq(calls,1);eq(disk().tx1.state,"sent");assert(not o.deliver("tx1",1,acknowledged));assert(not o.enqueue(report()))
end)
test("failed sending persistence prevents transport and preserves queued row",function()
    local o=durable({},function(snapshot) if snapshot.tx1 and snapshot.tx1.state=="sending" then return false end end)
    assert(o.enqueue(report()));local calls=0;assert(not o.deliver("tx1",0,function() calls=calls+1;return acknowledged() end));eq(calls,0);eq(o.ledger.tx1.state,"queued");eq(o.ledger.tx1.attempts,0)
end)
test("status-only success remains ambiguous and cannot retry",function()
    local o=durable();o.enqueue(report());local calls=0
    local function send() calls=calls+1;return {status=204} end
    assert(not o.deliver("tx1",0,send));assert(not o.deliver("tx1",10,send));eq(calls,1);eq(o.ledger.tx1.state,"delivery-uncertain")
end)
test("lost acknowledgement server error and malformed response never retry",function()
    for _,send in ipairs({function() error("lost") end,function() return {status=500} end,function() return true end}) do
        local o=durable();o.enqueue(report());o.deliver("tx1",0,send);eq(o.ledger.tx1.state,"delivery-uncertain");assert(not o.deliver("tx1",10,send))
    end
end)
test("full 120 second retry delay is honored with three total attempts",function()
    local o=durable();o.enqueue(report());local calls=0
    local function send() calls=calls+1;return {status=429,retryAfter=120} end
    o.deliver("tx1",0,send);eq(o.ledger.tx1.nextAttempt,120);o.deliver("tx1",119,send);eq(calls,1)
    o.deliver("tx1",120,send);o.deliver("tx1",240,send);o.deliver("tx1",500,send);eq(calls,3);eq(o.ledger.tx1.state,"rejected")
end)
test("invalid rate-limit delay does not create blind immediate retry",function()
    for _,delay in ipairs({-1,math.huge,0/0}) do
        local o=durable();o.enqueue(report());o.deliver("tx1",0,function() return {status=429,retryAfter=delay} end);eq(o.ledger.tx1.state,"delivery-uncertain")
    end
end)
test("rejected client responses and invalid delivery time never send again",function()
    local o=durable();o.enqueue(report());assert(not o.deliver("tx1",math.huge,acknowledged));eq(o.ledger.tx1.attempts,0)
    o.deliver("tx1",0,function() return {status=400} end);eq(o.ledger.tx1.state,"rejected");assert(not o.deliver("tx1",1,acknowledged))
end)
test("persistence loss after send retains nonretry ownership",function()
    local o,disk=durable({},function(snapshot) if snapshot.tx1 and snapshot.tx1.state=="sent" then return false end end)
    o.enqueue(report());assert(not o.deliver("tx1",0,acknowledged));eq(o.ledger.tx1.state,"delivery-uncertain");eq(disk().tx1.state,"sending");assert(not o.deliver("tx1",1,acknowledged))
end)
test("reloaded in-flight delivery becomes uncertain and stays deduplicated",function()
    local ledger={tx1={state="sending",attempts=1,report=report(),nextAttempt=0}}
    local o,disk=durable(ledger);eq(o.ledger.tx1.state,"delivery-uncertain");eq(disk().tx1.state,"delivery-uncertain");assert(not o.enqueue(report()));assert(not o.deliver("tx1",1,acknowledged))
end)
test("yielding or reentrant persistence cannot duplicate a delivery",function()
    local o,calls,reentered=nil,0,false
    local function send() calls=calls+1;return acknowledged() end
    o=durable({},function(snapshot)
        if snapshot.tx1 and snapshot.tx1.state=="sending" and not reentered then
            reentered=true;assert(not o.deliver("tx1",0,send))
        end
    end)
    assert(o.enqueue(report()));assert(o.deliver("tx1",0,send));eq(calls,1)
end)
test("failed persistence releases operation ownership for a later retry",function()
    local fail=true
    local o=durable({},function() if fail then return false end end)
    assert(not o.enqueue(report()));fail=false;assert(o.enqueue(report()));assert(o.deliver("tx1",0,acknowledged))
end)
test("payload clearly distinguishes partial subtotal from whole value",function()
    local t,e,a,p=fixture();t.before.Common=5;a.counts.Common=5;local r=assert(V.reconcile(t,e,a,p,P));local payload=O.payload(r)
    eq(#payload.allowed_mentions.parse,0);local fields=payload.embeds[1].fields;local text="";for _,f in ipairs(fields) do text=text..f.name.." "..f.value.."\n" end
    assert(text:find("Priced inventory subtotal",1,true));assert(text:find("Whole inventory value unavailable",1,true));assert(text:find("5",1,true));assert(text:find("liquidity unavailable",1,true))
end)
print("RESULT "..passed.." passed; "..failed.." failed"..(baseline and " (baseline)" or ""))
if failed>0 then os.exit(1) end
