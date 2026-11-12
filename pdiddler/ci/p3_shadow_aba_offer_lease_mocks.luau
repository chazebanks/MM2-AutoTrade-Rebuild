-- Native Luau/Lune unit regressions for a shadow-only offer mutation lease.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local mod=luau.load(fs.readFile(
  "pdiddler/intelligence_lab/p3_shadow_aba_offer_lease.lua"),
  {injectGlobals=true})()
local tests=0
local function eq(a,b,tag)
 tests+=1; assert(a==b,tostring(tag)..": "..tostring(a).." ~= "..tostring(b))
end
local function slot(i,name,qty,chroma)
 return {physicalSlot=i,displayCandidate=name,
  quantity=qty or 1,chromaCandidate=chroma or false,
  internalIdCandidate=nil,rawItemIdAuthenticated=false}
end
local function sample(our,their)
 local a,b=our or {},their or {}
 return {
  status="CLIENT_UNPRICED_TWO_SIDED_SNAPSHOT",
  ours=a,theirs=b,physicalOwnSlots=#a,physicalTheirSlots=#b,
  partnerExactClientBound=true,part3Paused=true,part4TradeVisible=true,
  requestOriginBound=false,rawItemIdsAuthenticated=false,
  pricesAuthenticated=false,offerRevisionAuthenticated=false,
  authorizesOffer=false,authorizesAccept=false,
  serverCompletionProven=false,mayReportProfit=false,
  maySendDiscordWebhook=false,tradeOutcome="UNKNOWN",
 }
end
local function fixture(initial)
 local root={}
 local ctx={active=true,root=root,snapshot=initial or sample()}
 local bound={capture=function()return ctx.snapshot end}
 local observer,r=mod.new(bound,{root=function()return ctx.root end,
  live=function()return ctx.active end})
 eq(r.status,"OBSERVING","fresh witness only observing")
 return observer,ctx
end
local function prepare(w)
 eq(w.poll().status,"OBSERVING","first safe client poll")
 eq(w.prepareShadow().status,"PREPARED","two stable protected snapshots prepare shadow")
 eq(w.state().authorizesOffer,false,"shadow never authorizes Offer")
 eq(w.state().authorizesAccept,false,"shadow never authorizes Accept")
 eq(w.state().serverRevisionAuthenticated,false,"no authenticated revision")
end
do
 local w,ctx=fixture(sample({slot(1,"Iceblaster")},{}))
 prepare(w)
 eq(w.recheckShadow().status,"PREPARED","same client snapshot still only shadow")
 eq(w.recheckShadow().reason,"CLIENT_SNAPSHOT_SAME_SHADOW_ONLY_NEVER_SEND","never permits remote")
 ctx.snapshot=sample({slot(1,"Iceblaster")},{slot(1,"Laser")})
 eq(w.recheckShadow().status,"STALE","ALT add invalidates")
 eq(w.state().observedGuiMutationCount,1,"first visible mutation counted")
 ctx.snapshot=sample({slot(1,"Iceblaster")},{})
 eq(w.poll().status,"STALE","ABA return cannot revive old intent")
 eq(w.recheckShadow().reason,"NO_CURRENT_HYPOTHETICAL_RESPONSE","never accept a restored matching fingerprint")
 eq(w.prepareShadow().status,"STALE","fresh plan cannot silently be prepared in revoked lease")
end
do
 local w,ctx=fixture(sample({slot(1,"Iceblaster")},{slot(1,"Laser")}))
 prepare(w)
 ctx.snapshot=sample({slot(1,"Iceblaster")},{slot(1,"Laser",3)})
 eq(w.poll().status,"STALE","stack quantity shift invalidates")
 eq(w.state().observedGuiMutationCount,1,"quantity mutation counted")
end
do
 local w,ctx=fixture(sample({slot(1,"Iceblaster")},{slot(1,"Laser")}))
 prepare(w)
 ctx.snapshot=sample({slot(1,"Iceblaster")},{slot(1,"Laser",1,true)})
 eq(w.poll().status,"STALE","chroma transition invalidates")
end
do
 local w,ctx=fixture(sample({slot(1,"Iceblaster")},{slot(1,"Laser")}))
 prepare(w)
 ctx.snapshot=sample({slot(1,"Iceblaster")},{slot(1,"Luger")})
 eq(w.poll().status,"STALE","different weapon same slot count invalidates")
end
do
 local w,ctx=fixture(sample({slot(1,"Iceblaster")},{slot(1,"Laser")}))
 prepare(w)
 ctx.snapshot=sample({slot(1,"Iceblaster")},{slot(2,"Laser")})
 eq(w.poll().status,"STALE","same named item moved slot invalidates")
end
do
 local w,ctx=fixture(sample({slot(1,"Iceblaster")},{slot(1,"Laser")}))
 prepare(w)
 ctx.snapshot=sample({slot(1,"Batwing")},{slot(1,"Laser")})
 eq(w.poll().status,"STALE","own side mutation invalidates")
end
do
 local w,ctx=fixture(sample({slot(1,"Iceblaster")},{slot(1,"Laser")}))
 prepare(w)
 eq(w.observeClientUpdateCallback().status,"STALE","callback explicitly invalidates even without visible changes")
 eq(w.state().observedCallbackInvalidations,1,"separate callback counter")
 ctx.snapshot=sample({slot(1,"Iceblaster")},{slot(1,"Laser")})
 eq(w.recheckShadow().status,"STALE","identical restored UI still revoked")
 eq(w.state().callbackSessionAssociationProven,false,"callback not tied to authenticated session")
end
do
 local w,ctx=fixture()
 eq(w.observeClientUpdateCallback().status,"OBSERVING","callback before prepare does not create permission")
 eq(w.state().observedCallbackInvalidations,0,"unbound callback not counted as real mutation")
 eq(w.prepareShadow().status,"OBSERVING","after first poll still not stable enough")
end
do
 local w,ctx=fixture()
 prepare(w)
 ctx.active=false
 eq(w.recheckShadow().status,"STALE","P3/P4 lease no longer live")
end
do
 local w,ctx=fixture()
 prepare(w)
 ctx.root={}
 eq(w.recheckShadow().status,"STALE","trade root replaced")
end
do
 local w,ctx=fixture()
 prepare(w)
 ctx.snapshot={status="REJECTED",reason="OFFER_CHANGED_DURING_CAPTURE"}
 eq(w.recheckShadow().status,"STALE","unreadable accepted state is never green")
end
do
 local w,ctx=fixture()
 prepare(w)
 ctx.snapshot=sample()
 ctx.snapshot.authorizesAccept=true
 eq(w.recheckShadow().status,"STALE","forged authority rejected")
end
do
 local w,ctx=fixture()
 prepare(w)
 ctx.snapshot=sample({}, {slot(1,"Laser")})
 ctx.snapshot.theirs[1].quantity=0
 eq(w.recheckShadow().status,"STALE","invalid client quantity rejected")
end
do
 local w,ctx=fixture()
 prepare(w)
 ctx.snapshot=sample({}, {slot(1,"Laser"),slot(1,"Other")})
 eq(w.recheckShadow().status,"STALE","duplicate physical slot rejected")
end
do
 local w,ctx=fixture()
 prepare(w)
 ctx.snapshot=sample({}, {slot(1,"Laser")})
 ctx.snapshot.physicalTheirSlots=0
 eq(w.recheckShadow().status,"STALE","physical slot inconsistency rejected")
end
do
 local w,ctx=fixture()
 prepare(w)
 ctx.snapshot=sample({}, {slot(1,"Laser")})
 ctx.snapshot.theirs[1].displayCandidate="\nSECRET"
 eq(w.recheckShadow().status,"STALE","malformed label quarantined and never leaked")
 eq(w.state().reason,"CLIENT_ONLY_NEVER_SEND","output has only static anonymous reason")
end
do
 local w,ctx=fixture()
 prepare(w)
 local r=w.stop()
 eq(r.status,"STALE","STOP irreversible")
 eq(w.recheckShadow().status,"STALE","post stop never returns to prepared")
end
do
 local w,ctx=fixture()
 prepare(w)
 local r=w.state()
 for _,flag in ipairs({"authorizesOffer","authorizesTrade","authorizesAccept",
   "serverRevisionAuthenticated","serverCompletionProven",
   "mayReportProfit","maySendDiscordWebhook","mayUseForStrategyLearning",
   "rawItemIdsAuthenticated","uniqueWeaponInstanceProven"}) do
  eq(r[flag],false,"no authority: "..flag)
 end
 eq(r.tradeOutcome,"UNKNOWN","no fake settlement")
end
print("P3_SHADOW_ABA_LEASE_LUA_PASS",tests)
