-- Actual pure Luau repeated MAIN-ALT accept-policy security regression.
-- NO AcceptTrade or live game remotes. Local mock observations only.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local code=fs.readFile("pdiddler/supervised/main_alt_sessionwide_accept_policy.lua")
local policy=luau.load(code)()
local tests=0
local function eq(actual,expected,name)
 tests+=1
 assert(actual==expected,name..": "..tostring(actual).." != "..tostring(expected))
end
local function ok(v,name)
 tests+=1; assert(v,name)
end
local function clone(t)
 if type(t)~="table" then return t end
 local o={}
 for k,v in pairs(t) do o[k]=clone(v) end
 return o
end
local config={mainUserId=101,altUserId=202,mainName="MainFixture",
              altName="AltFixture",jobId="JOB_TEST_20261114_A",
              placeId=142823291,
              operatorScope="ALL_MAIN_ALT_TRADES_IN_THIS_JOB",
              enablePublicAccept=false}
local function gift()
 return {rawKey="test_godly",quantity=1,slotIndex=1,category="Weapons"}
end
local function ctx(root,now,own,alt)
 return {placeId=142823291,jobId=config.jobId,
   mainUserId=101,altUserId=202,
   mainName="MainFixture",altName="AltFixture",
   partnerUserId=202,partnerName="AltFixture",
   mainIsLocalPlayer=true,mainPlayerObjectExact=true,
   altPlayerObjectExact=true,altPresent=true,
   otherTradeControllerActive=false,uiSafe=true,tradingPaused=false,
   tradeRootUnique=true,tradeVisible=true,tradeRoot=root,now=now,
   ownOffer=own or {},altOffer=alt or {gift()},
   ownAccepted=false,altAccepted=false}
end
local function observed(own,alt)
 local c,reason=policy.new(config)
 eq(reason,nil,"correct configuration accepted")
 local root={}
 local first=ctx(root,1,own,alt)
 eq(c.begin(first).status,"OBSERVING","new lease")
 eq(c.observe(first).status,"OBSERVING","new signature baseline")
 local second=ctx(root,1.35,own,alt)
 eq(c.observe(second).status,"STABLE_RESEARCH_ONLY","stable after 350ms")
 return c,root,second
end
do
 local c,why=policy.new(config)
 eq(why,nil,"consent contract recognized")
 local root={}
 local one=ctx(root,1)
 eq(c.begin(one).status,"OBSERVING","first session")
 eq(c.observe(one).status,"OBSERVING","first baseline")
 local tooFast=ctx(root,1.15)
 eq(c.observe(tooFast).reason,"WAIT_MINIMUM_STABILITY_INTERVAL","minimum time")
 local ready=ctx(root,1.4)
 eq(c.observe(ready).status,"STABLE_RESEARCH_ONLY","first session stable")
 eq(c.requestAccept(ctx(root,1.41)).status,
    "HOLD_NATIVE_ACCEPT_MAPPING_REQUIRED","never fake Accept")
 eq(c.status().liveAcceptActionEnabled,false,"no live Accept until verified")
 local closing={tradeVisible=false,tradeRoot=root,
      jobId=config.jobId,mainUserId=101,altUserId=202,now=1.5}
 eq(c.tradeClosed(closing).status,"READY_FOR_ANOTHER_MAIN_ALT_TRADE",
    "first client window closes, controller keeps running")
 eq(c.status().checkedTradeEpochs,1,"one bound epoch")
 eq(c.status().clientWindowClosures,1,"one closure not settlement")
 local nextRoot={}
 eq(c.begin(ctx(nextRoot,2)).status,"OBSERVING","SECOND real trade allowed")
 eq(c.observe(ctx(nextRoot,2)).status,"OBSERVING","new baseline not inherited")
 eq(c.observe(ctx(nextRoot,2.31)).status,"STABLE_RESEARCH_ONLY",
    "second needs own independent 300ms check")
 eq(c.requestAccept(ctx(nextRoot,2.4)).status,
    "HOLD_NATIVE_ACCEPT_MAPPING_REQUIRED","second still not executable")
 eq(c.status().checkedTradeEpochs,2,"multiple sessions, not one-shot")
 eq(c.status().actualAccepts,0,"zero action claims forever")
 eq(c.status().noPublicPartnerAccepted,true,"public pair never accepted")
 eq(c.status().serverCompletionProven,false,"client close not settlement")
 eq(c.tradeClosed({tradeVisible=false,tradeRoot=nextRoot,
                   jobId=config.jobId,mainUserId=101,altUserId=202,now=2.5}).status,
    "READY_FOR_ANOTHER_MAIN_ALT_TRADE","second closes")
 eq(c.status().clientWindowClosures,2,"multiple closures not trade success")
 eq(c.status().mayObserveFurtherMainAltTrades,true,"sessionwide persists")
 eq(c.operatorStop().status,"STOPPED","one operator stop disables all trades")
 eq(c.begin(ctx({},3)).status,"STOPPED","cannot restart stopped controller")
end
do
 local c,r,last=observed()
 eq(c.observe(ctx(r,1.4)).status,"STABLE_RESEARCH_ONLY","unchanged stable state")
 eq(c.requestAccept(ctx(r,1.5)).actionAuthorized,false,"read-only request")
 eq(c.status().playerIdsExported,false,"identity never exported")
 eq(c.status().jobIdExported,false,"JobId never exported")
 eq(c.status().rawOwnedItemsExported,false,"no raw names exported")
end
local badConfigs={
 {mainUserId=101,altUserId=101},{altUserId=0},{mainUserId=-1},
 {mainUserId=101.5},{altName="MainFixture"},{mainName="Other Person"},
 {jobId="short"},{placeId=12345},{operatorScope="ONE_TRADE"},
 {enablePublicAccept=true},
}
for i,change in ipairs(badConfigs) do
 local c=clone(config)
 for k,v in pairs(change) do c[k]=v end
 local controller,why=policy.new(c)
 eq(controller,nil,"bad config "..i)
 eq(why,"EXPLICIT_MAIN_ALT_SESSION_CONFIG_INVALID","config fails closed "..i)
end
local mutations={
 {partnerUserId=303},{partnerName="FakeAlt"},{altUserId=303},
 {altName="NotAlt"},{mainUserId=202},{mainName="NotMain"},
 {placeId=22222},{jobId="OTHER_JOB_001"},
 {mainIsLocalPlayer=false},{mainPlayerObjectExact=false},
 {altPlayerObjectExact=false},{altPresent=false},
 {otherTradeControllerActive=true},{uiSafe=false},
 {tradingPaused=true},{tradeRootUnique=false},{tradeVisible=false},
 {now=math.huge},{now=-1},
}
for i,change in ipairs(mutations) do
 local c=assert(policy.new(config))
 local x=ctx({},1)
 for k,v in pairs(change) do x[k]=v end
 eq(c.begin(x).status,"STOPPED","forged or unsafe context "..i)
 eq(c.status().mayObserveFurtherMainAltTrades,false,"fatal latch "..i)
 eq(c.begin(ctx({},2)).status,"STOPPED","no later retries "..i)
end
local badOffers={
 {ownOffer={{rawKey="Gingerscope",quantity=1,slotIndex=1,category="Weapons"}}},
 {ownOffer={{rawKey="GINGERSCOPE",quantity=1,slotIndex=1,category="Weapons"}}},
 {ownOffer={{rawKey="Chroma_Gingerscope",quantity=1,slotIndex=1,category="Weapons"}}},
 {altOffer={{rawKey="BAD/KEY",quantity=1,slotIndex=1,category="Weapons"}}},
 {altOffer={{rawKey="x",quantity=0,slotIndex=1,category="Weapons"}}},
 {altOffer={{rawKey="x",quantity=-1,slotIndex=1,category="Weapons"}}},
 {altOffer={{rawKey="x",quantity=1.5,slotIndex=1,category="Weapons"}}},
 {altOffer={{rawKey="x",quantity=10001,slotIndex=1,category="Weapons"}}},
 {altOffer={{rawKey="x",quantity=1,slotIndex=5,category="Weapons"}}},
 {altOffer={{rawKey="x",quantity=1,slotIndex=1,category="Pets"}}},
 {altOffer={{rawKey="x",quantity=1,slotIndex=1,category="Weapons"},
            {rawKey="x",quantity=1,slotIndex=2,category="Weapons"}}},
 {altOffer={{rawKey="x",quantity=1,slotIndex=1,category="Weapons"},
            {rawKey="y",quantity=1,slotIndex=1,category="Weapons"}}},
 {altOffer={{rawKey="a",quantity=1,slotIndex=1,category="Weapons"},
            {rawKey="b",quantity=1,slotIndex=2,category="Weapons"},
            {rawKey="c",quantity=1,slotIndex=3,category="Weapons"},
            {rawKey="d",quantity=1,slotIndex=4,category="Weapons"},
            {rawKey="e",quantity=1,slotIndex=5,category="Weapons"}}},
 {ownAccepted=true},{altAccepted=nil},{ownOffer=nil},
}
for i,change in ipairs(badOffers) do
 local c=assert(policy.new(config))
 local r={}
 eq(c.begin(ctx(r,1)).status,"OBSERVING","bad offer lease starts "..i)
 local x=ctx(r,1.1)
 for k,v in pairs(change) do x[k]=v end
 -- Lua cannot represent nil in a test update literal; those test cases
 -- get their own explicit assignments below.
 if i==15 then x.altAccepted=nil end
 if i==16 then x.ownOffer=nil end
 local answer=c.observe(x)
 eq(answer.status,"STOPPED","invalid payload must stop "..i)
 eq(c.status().mayObserveFurtherMainAltTrades,false,"stop persists "..i)
end
-- A real empty opening trade is normal; it is NOT a fifth-slot error.
do
 local c=assert(policy.new(config))
 local root={}
 c.begin(ctx(root,1))
 local empty=ctx(root,1.1);empty.altOffer={};empty.ownOffer={}
 eq(c.observe(empty).status,"OBSERVING","empty opening trade waits safely")
 eq(c.status().phase,"OBSERVING","empty trade does not stop session")
 eq(c.observe(ctx(root,1.5)).status,"OBSERVING","first item needs new baseline")
 eq(c.observe(ctx(root,1.9)).status,"STABLE_RESEARCH_ONLY","later independent recheck")
end
do
 local c=assert(policy.new(config))
 local root={}
 c.begin(ctx(root,1))
 local tricky=ctx(root,1.1)
 tricky.altOffer={[1]=gift(),[3]={rawKey="hidden",quantity=1,slotIndex=3,category="Weapons"}}
 eq(c.observe(tricky).status,"STOPPED","sparse hidden offer slot stops")
end
do
 local c=assert(policy.new(config))
 local root={}
 c.begin(ctx(root,1))
 local tricky=ctx(root,1.1)
 tricky.altOffer={gift()}
 tricky.altOffer[5]={rawKey="hidden",quantity=1,slotIndex=4,category="Weapons"}
 eq(c.observe(tricky).status,"STOPPED","fabricated fifth data entry beyond four physical slots blocks")
end
do
 local c=assert(policy.new(config))
 local root={}
 c.begin(ctx(root,1))
 local tricky=ctx(root,1.1)
 tricky.altOffer={{rawKey="safe",quantity=1,slotIndex=1,category="Weapons",isGift=true}}
 eq(c.observe(tricky).status,"STOPPED","unexpected metadata refused")
end
do
 local c=assert(policy.new(config))
 local root={}
 c.begin(ctx(root,1))
 local tricky=ctx(root,1.1)
 tricky.altOffer={{rawKey="safe",quantity=1,slotIndex=1}}
 eq(c.observe(tricky).status,"STOPPED","missing weapons category refused")
end
do
 local c,r=observed()
 local mismatch=ctx(r,1.5);mismatch.altOffer={{rawKey="another",quantity=1,slotIndex=1,category="Weapons"}}
 eq(c.observe(mismatch).reason,"OFFER_CHANGED_AFTER_STABLE_BINDING","offer swap stops all")
 eq(c.requestAccept(ctx(r,1.6)).status,"STOPPED","can't accept after change")
end
do
 local c,r=observed()
 local changed=ctx(r,1.5);changed.altAccepted=true
 eq(c.observe(changed).status,"STOPPED","accept-state change stops")
end
do
 local c=assert(policy.new(config))
 local r={}
 c.begin(ctx(r,1))
 eq(c.tradeClosed({tradeVisible=false,tradeRoot=r,
        jobId=config.jobId,mainUserId=101,altUserId=202,now=1.2}).status,
    "STOPPED","unexpected close before stable is fatal")
 eq(c.begin(ctx({},2)).status,"STOPPED","any fatal stops future pair trade")
end
do
 local c,r=observed()
 eq(c.begin(ctx({},1.5)).status,"STOPPED","overlapping trade never accepted")
end
do
 local c,r=observed()
 local late=ctx(r,26.5)
 eq(c.observe(late).status,"STOPPED","stale trade lease >25 seconds stops")
end
do
 local c=assert(policy.new(config))
 local r={}
 c.begin(ctx(r,1))
 c.observe(ctx(r,1))
 local backward=ctx(r,0.9)
 eq(c.observe(backward).status,"STOPPED","clock rollback fatal")
end
do
 local c=assert(policy.new(config))
 local r={}
 c.begin(ctx(r,1))
 c.observe(ctx(r,1))
 local reset=ctx(r,1.2);reset.altOffer={{rawKey="changed",quantity=1,slotIndex=1,category="Weapons"}}
 eq(c.observe(reset).reason,"NEW_OFFER_BASELINE_NEEDS_INDEPENDENT_RECHECK",
    "changed offer BEFORE ready only resets stability")
 eq(c.observe(ctx(r,1.6)).reason,"NEW_OFFER_BASELINE_NEEDS_INDEPENDENT_RECHECK",
    "original item returned and must be rebound")
 eq(c.observe(ctx(r,1.95)).status,"STABLE_RESEARCH_ONLY",
    "independent recheck still required")
end
do
 local c=assert(policy.new(config))
 local r={}
 c.begin(ctx(r,1))
 eq(c.requestAccept(ctx(r,1.1)).status,"STOPPED",
    "premature accept request kills whole controller")
end
print("[PASS] MAIN-ALT multi-trade session-only fail-stop policy: "..tests.." Luau assertions")
