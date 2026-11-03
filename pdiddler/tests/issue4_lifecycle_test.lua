local V=dofile("pdiddler/pdiddler_trade_verification_v1.lua")
local O=dofile("pdiddler/pdiddler_webhook_outbox_v2.lua")
local P=dofile("pdiddler/pdiddler4_supreme_policy_v2_ADAPTIVE.lua")
local profile={version="prices",isFresh=function() return true end,get=function(page,id) if page~="godly" or (id~="A" and id~="B") then return nil end; return {page=page,id=id,name=id,supremeValue=id=="A" and 100 or 115,demand=id=="A" and 3 or 4,stability="Stable",verified=true} end}
local function valued(id,qty) return {id=id,checkerId=id,page="godly",cat="Weapons",type="Knife",name=id,qty=qty,value=id=="A" and 100 or 115,demand=id=="A" and 3 or 4} end
local function reconcile(t,e,a) return V.reconcile(t,e,a,profile,P) end
local n=0
local function test(name,fn) fn(); n=n+1; print("PASS "..name) end
local function proof()
 return {id="tx1",job="job",epoch=1,partner=2,gui="gui1",version="prices",ourSig="a",theirSig="b",plannedOurSig="a",valuedTheirSig="b",ourTotal=100,theirTotal=115,pricesCurrent=true,identitiesVerified=true,quantitiesVerified=true,ourAccepted=true,theirAccepted=true,cooldownKnown=true,cooldown=0,changing=false}
end
test("final eligibility requires uninterrupted extra second",function() local st={}; local p=proof(); assert(not V.finalReady(st,p,0)); assert(not V.finalReady(st,p,.99)); assert(V.finalReady(st,p,1)) end)
test("offer change invalidates prior final eligibility",function() local st={}; local p=proof(); V.finalReady(st,p,0); p.theirSig="c"; assert(not V.finalReady(st,p,2)); p.valuedTheirSig="c"; assert(not V.finalReady(st,p,2)); assert(V.finalReady(st,p,3)) end)
test("unproved cooldown and mismatched plan block final eligibility",function() local p=proof(); p.cooldownKnown=false; assert(not V.finalReady({},p,4)); p.cooldownKnown=true; p.plannedOurSig="wrong"; assert(not V.finalReady({},p,4)) end)
test("a different partner restarts verification",function() local p=proof(); local st={}; V.finalReady(st,p,0); p.partner=3; assert(not V.finalReady(st,p,2)) end)
test("final eligibility is consumed only once",function() local p=proof(); local st={}; V.finalReady(st,p,0); local ok,token=V.finalReady(st,p,1); assert(ok and V.consume(st,token)); assert(not V.consume(st,token)); assert(not V.finalReady(st,p,2)) end)
test("invalid snapshot types cannot throw",function() assert(not V.finalReady({},true,1)) end)
test("an unready token cannot be consumed",function() local st={}; V.finalReady(st,proof(),0); assert(not V.consume(st,st.key)) end)
local function trade()
 return {id="tx1",job="job",epoch=1,partner=2,version="prices",ourSig="a",theirSig="b",before={A=2,B=0},give={valued("A",1)},receive={valued("B",1)}}
end
local function event() return {kind="completed",id="tx1",job="job",epoch=1,partner=2,ourSig="a",theirSig="b"} end
local function after() return {counts={A=1,B=1},items={valued("A",1),valued("B",1)},stableReads=2,version="prices",complete=true,wholeInventoryVerified=true,total=215} end
test("close or bare boolean never proves completion",function() assert(not reconcile(trade(),true,after())); local e=event(); e.kind="closed"; assert(not reconcile(trade(),e,after())) end)
test("late or wrong-partner completion is rejected",function() local e=event(); e.epoch=0; assert(not reconcile(trade(),e,after())); e=event(); e.partner=99; assert(not reconcile(trade(),e,after())) end)
test("exact correlated event plus raw inventory delta produces report",function() local r=assert(reconcile(trade(),event(),after())); assert(r.verified and r.profit==15 and r.inventoryTotal==215 and r.give[1].liquidity=="unavailable") end)
test("unrelated inventory changes reject completion proof",function() local a=after(); a.counts.Unrelated=1; assert(not reconcile(trade(),event(),a)) end)
test("unverified whole inventory blocks report",function() local a=after(); a.wholeInventoryVerified=false; assert(not reconcile(trade(),event(),a)) end)
test("one inventory read is not stable proof",function() local a=after(); a.stableReads=1; assert(not reconcile(trade(),event(),a)) end)
test("whole inventory totals are recomputed rather than trusted",function() local a=after(); a.total=9999; local r=assert(reconcile(trade(),event(),a)); assert(r.inventoryTotal==215) end)
test("unknown whole inventory item prevents reconciliation",function() local a=after(); a.counts.Other=1; a.items[#a.items+1]=valued("Other",1); assert(not reconcile(trade(),event(),a)) end)
test("unknown item value is never zero",function() local t=trade(); t.receive[1].value=nil; assert(not reconcile(t,event(),after())) end)
test("below 15 profit blocks completion report",function() local t=trade(); t.receive[1].value=114.99; assert(not reconcile(t,event(),after())) end)
test("duplicate raw item rows and invalid quantities are rejected",function() local t=trade(); t.give[2]=t.give[1]; assert(not reconcile(t,event(),after())); t=trade(); t.give[1].qty=1.2; assert(not reconcile(t,event(),after())) end)
local report=assert(reconcile(trade(),event(),after()))
test("Discord payload includes item metadata and verified totals",function() local p=O.payload(report); assert(p.allowed_mentions.parse[1]==nil); local s=p.embeds[1].fields; assert(s[1].value:find("liquidity unavailable",1,true)); assert(s[3].value:find("+15",1,true)); assert(s[4].value=="215") end)
test("disabled outbox never reads credentials or sends",function() local o=O.new({},false); assert(not o.enqueue(report)); assert(o.state=="disabled") end)
test("verified report sends once",function() local count=0; local ledger={}; local o=O.new(ledger,true); assert(o.enqueue(report)); local function send() count=count+1; return {status=204} end; assert(o.deliver("tx1",0,send)); assert(not o.deliver("tx1",1,send)); assert(not o.enqueue(report)); assert(count==1) end)
test("unknown acknowledgement is not retried",function() local count=0; local o=O.new({},true); o.enqueue(report); local function send() count=count+1; error("lost acknowledgement") end; o.deliver("tx1",0,send); o.deliver("tx1",10,send); assert(count==1 and o.ledger.tx1.state=="delivery-uncertain") end)
test("server error is ambiguous rather than retryable",function() local o=O.new({},true); o.enqueue(report); o.deliver("tx1",0,function() return {status=500} end); assert(o.ledger.tx1.state=="delivery-uncertain") end)
test("429 retry is bounded and respects backoff",function() local o=O.new({},true); o.enqueue(report); local n=0; local function send() n=n+1; return {status=429,retryAfter=2} end; o.deliver("tx1",0,send); o.deliver("tx1",1,send); assert(n==1); o.deliver("tx1",2,send); o.deliver("tx1",4,send); o.deliver("tx1",8,send); assert(n==3 and o.ledger.tx1.state=="rejected") end)
test("restart after sending retains uncertain ownership",function() local ledger={tx1={state="sending"}}; local o=O.new(ledger,true); assert(ledger.tx1.state=="delivery-uncertain"); assert(not o.enqueue(report)) end)
print("PASS "..n.." lifecycle/outbox tests")
