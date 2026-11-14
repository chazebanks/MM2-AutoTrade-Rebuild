-- Real Lune pure Luau adversarial tests: three successive manual ALT->MAIN trades.
-- All trade actions belong exclusively to humans, never this module.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local src=fs.readFile("pdiddler/supervised/main_alt_manual_multitrade_delta_core.lua")
local core=luau.load(src)()
local passed=0
local function eq(a,b,label)
 passed+=1
 assert(a==b,tostring(label)..": "..tostring(a).." != "..tostring(b))
end
local function ok(b,label)passed+=1;assert(b,label)end
local config={placeId=142823291,mainUserId=101,altUserId=202,
 mainName="MainFixture",altName="AltFixture",
 jobId="JOB_TEST_ALT_MAIN_11_14",operatorScope="ALL_MAIN_ALT_TRADES_IN_THIS_JOB",
 publicTradingEnabled=false,scriptMayFinalAccept=false}
local function weapon(k,q,slot)
 return {key=k,qty=q,slot=slot or 1,category="Weapons"}
end
local function profile(entries)
 return {ProfileData={Weapons={Owned=entries}}}
end
local function context(now,root,own,alt,mainAccepted,altAccepted)
 return {placeId=142823291,jobId=config.jobId,mainUserId=101,altUserId=202,
   mainName="MainFixture",altName="AltFixture",partnerUserId=202,
   partnerName="AltFixture",exactPlayerObjects=true,
   exactTradePartnerLabel=root~=nil,onlyTradeRoot=true,
   uiSafe=true,competingController=false,now=now,
   tradeOpen=root~=nil,tradeRoot=root,ownOffer=own or {},altOffer=alt or {},
   mainAccepted=mainAccepted==true,altAccepted=altAccepted==true}
end
local function clean(st,what)
 eq(st.authorizesAccept,false,what.." no Accept")
 eq(st.authorizesTrade,false,what.." no trade authority")
 eq(st.actualScriptOffers,0,what.." no script offered")
 eq(st.actualScriptAccepts,0,what.." no script accepted")
 eq(st.tradeOutcome,"UNKNOWN",what.." no server completion")
 eq(st.serverCompletionProven,false,what.." client only")
 eq(st.noPublicAccept,true,what.." public Accept forbidden")
 eq(st.protectOutgoingGingerscope,true,what.." target")
 local json=serde.encode("json",st)
 for _,s in ipairs({"AltFixture","MainFixture","JOB_TEST_ALT_MAIN_11_14","raw_alpha","raw_beta","raw_gamma"}) do
  ok(not json:find(s,1,true),what.." sanitized "..s)
 end
end
local function round(controller,time,before,altOffer,after)
 local root={}
 eq(controller.begin(profile(before),context(time,nil)).status,
   "WAIT_OPEN","fresh owned profile before every trade")
 eq(controller.observe(context(time+0.1,nil)).status,
   "WAIT_OPEN","wait unstarted trade")
 eq(controller.observe(context(time+0.2,root)).status,
   "WAIT_ALT","empty opening GUI required")
 local a=controller.observe(context(time+0.3,root,{},altOffer))
 eq(a.status,"STABILIZING","ALT item baseline")
 eq(controller.observe(context(time+0.5,root,{},altOffer)).status,
   "STABILIZING","no premature final Accept")
 eq(controller.observe(context(time+0.75,root,{},altOffer)).status,
   "WAIT_MANUAL_ACCEPT","stable candidate local")
 eq(controller.observe(context(time+0.95,root,{},altOffer,false,true)).status,
   "WAIT_CLOSE","operator ALT final Accept observed")
 eq(controller.observe(context(time+1.10,root,{},altOffer,true,true)).status,
   "WAIT_CLOSE","operator MAIN final Accept observed")
 eq(controller.observe(context(time+1.22,nil)).status,
   "VERIFY_DELTA","GUI closed, still unknown settlement")
 eq(controller.post(profile(before),context(time+1.50,nil)).status,
   "VERIFY_DELTA","profile initial stale waits for Claim")
 eq(controller.post(profile(after),context(time+1.85,nil)).status,
   "VERIFY_DELTA","first correct delta, recheck necessary")
 local result=controller.post(profile(after),context(time+2.30,nil))
 eq(result.status,"READY_FOR_NEXT_MAIN_ALT_TRADE","second identical delta allows next")
 eq(result.nextExactAltTradeAllowed,true,"session persists for next ALT trade")
 clean(result,"cycle complete")
end
do
 local c,why=core.new(config)
 eq(why,nil,"exact pair session config")
 local first={raw_alpha=0}
 round(c,1,first,{weapon("raw_alpha",1)},{raw_alpha=1})
 round(c,5,{raw_alpha=1},{weapon("raw_beta",5)},
   {raw_alpha=1,raw_beta=5}) -- 5 copies in one of MM2's 4 physical slots
 round(c,9,{raw_alpha=1,raw_beta=5},
   {weapon("raw_gamma",2,1),weapon("raw_delta",3,2)},
   {raw_alpha=1,raw_beta=5,raw_gamma=2,raw_delta=3})
 local status=c.status()
 eq(status.tradeCyclesStarted,3,"three distinct trade windows, no one-trade cap")
 eq(status.corroboratedClientDeltas,3,"three separate repeated client-only delta checks")
 eq(status.observedManualAcceptTransitions,3,"three manual acceptance observations")
 eq(status.ownProfileReadAttempts,12,"fresh pre, stale post, two independent matching post reads each")
 eq(status.nextExactAltTradeAllowed,true,"next authorized ALT trade can be observed")
 eq(status.serverCompletionProven,false,"never claim backend trade completion")
 eq(c.stop().status,"STOPPED","operator stop all session")
 eq(c.begin(profile({}),context(20,nil)).status,"STOPPED","no restart after stop")
end
do
 local c=assert(core.new(config))
 eq(c.begin(profile({}),context(1,nil)).status,"WAIT_OPEN","ready baseline")
 local root={}
 c.observe(context(1.1,root))
 c.observe(context(1.2,root,{}, {weapon("raw_alpha",1)}))
 local changed=c.observe(context(1.7,root,{}, {weapon("raw_other",1)}))
 eq(changed.status,"STOPPED","ALT swaps offered item after first binding")
 eq(c.begin(profile({}),context(2,nil)).status,"STOPPED","error permanently stops all future trades")
end
do
 local c=assert(core.new(config))
 c.begin(profile({}),context(1,nil))
 local root={}
 c.observe(context(1.1,root))
 local wrong=context(1.2,root)
 wrong.partnerUserId=303
 eq(c.observe(wrong).status,"STOPPED","public non-ALT must permanently stop")
end
do
 local c=assert(core.new(config))
 c.begin(profile({}),context(1,nil))
 local root={}
 local prefilled=context(1.1,root,{}, {weapon("raw_beta",1)})
 eq(c.observe(prefilled).status,"STOPPED","no empty initial trade baseline")
end
do
 local c=assert(core.new(config))
 c.begin(profile({}),context(1,nil))
 local root={}
 c.observe(context(1.1,root))
 local item=context(1.2,root,{weapon("Ginger_Scope",1)}, {weapon("raw_beta",1)})
 eq(c.observe(item).status,"STOPPED","no outgoing Gingerscope")
end
do
 local c=assert(core.new(config))
 c.begin(profile({}),context(1,nil))
 local root={}
 c.observe(context(1.1,root))
 local item=context(1.2,root,{}, {weapon("raw_beta",5)})
 eq(c.observe(item).status,"STABILIZING","5 stacked copies legal in one slot")
end
do
 local c=assert(core.new(config))
 c.begin(profile({}),context(1,nil))
 local root={}
 c.observe(context(1.1,root))
 local item=context(1.2,root,{},{
  weapon("k1",1,1),weapon("k2",1,2),
  weapon("k3",1,3),weapon("k4",1,4),weapon("k5",1,5)})
 eq(c.observe(item).status,"STOPPED","fifth fake DATA slot is invalid")
end
do
 local c=assert(core.new(config))
 local bad={raw_alpha=-1}
 eq(c.begin(profile(bad),context(1,nil)).status,"STOPPED","invalid own count stops")
end
do
 local c=assert(core.new(config))
 c.begin(profile({}),context(1,nil))
 local r={}
 c.observe(context(1.1,r))
 c.observe(context(1.2,r,{}, {weapon("raw_alpha",1)}))
 c.observe(context(1.7,r,{}, {weapon("raw_alpha",1)}))
 c.observe(context(1.8,r,{}, {weapon("raw_alpha",1)},false,true))
 c.observe(context(1.9,nil))
 eq(c.post(profile({raw_alpha=1,unrelated=1}),context(2,nil)).status,
    "STOPPED","unrelated concurrent ownership mutation stops")
end
do
 local c=assert(core.new(config))
 c.begin(profile({}),context(1,nil))
 local r={}
 c.observe(context(1.1,r))
 c.observe(context(1.2,r,{}, {weapon("raw_alpha",1)}))
 c.observe(context(1.7,r,{}, {weapon("raw_alpha",1)}))
 c.observe(context(1.8,r,{}, {weapon("raw_alpha",1)},false,true))
 c.observe(context(1.9,nil))
 eq(c.post(profile({}),context(2,nil)).status,
    "VERIFY_DELTA","wait possible claim")
 eq(c.post(profile({}),context(14.2,nil)).status,
    "STOPPED","no client delta after bounded wait halts entire session")
end
do
 local c=assert(core.new(config))
 c.begin(profile({}),context(1,nil))
 local r={}
 c.observe(context(1.1,r))
 c.observe(context(1.2,r,{}, {weapon("raw_alpha",1)}))
 c.observe(context(1.7,r,{}, {weapon("raw_alpha",1)}))
 local changed=context(1.8,r,{}, {weapon("raw_alpha",1)})
 changed.altAccepted=nil
 eq(c.observe(changed).status,"STOPPED","missing ALT acceptance indicator stops")
end
do
 local c=assert(core.new(config))
 c.begin(profile({}),context(1,nil))
 local r={}
 c.observe(context(1.1,r))
 c.observe(context(1.2,r,{}, {weapon("raw_alpha",1)}))
 c.observe(context(1.7,r,{}, {weapon("raw_alpha",1)}))
 eq(c.observe(context(1.8,nil)).status,"STOPPED",
   "missing observed manual accept before window closure is not success")
end
do
 local c=assert(core.new(config))
 c.begin(profile({}),context(1,nil))
 eq(c.observe(context(47,nil)).status,"STOPPED",
    "failure to open next trade on time stops")
end
do
 local c=assert(core.new(config))
 c.begin(profile({}),context(1,nil))
 local r={}
 c.observe(context(1.1,r))
 c.observe(context(1.2,r,{}, {weapon("raw_alpha",1)}))
 c.observe(context(1.7,r,{}, {weapon("raw_alpha",1)}))
 c.observe(context(1.8,r,{}, {weapon("raw_alpha",1)},false,true))
 c.observe(context(1.9,nil))
 eq(c.post(profile({raw_alpha=1}),context(2.5,nil)).status,"VERIFY_DELTA","first client")
 eq(c.post(profile({raw_alpha=1,other=1}),context(2.9,nil)).status,"STOPPED",
    "between-check unplanned new key stops")
end
print("[PASS] exact ALT multi-manual-trade settlement research core: "..passed.." Lune assertions")
