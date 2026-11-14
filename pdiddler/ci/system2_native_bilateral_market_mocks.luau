-- Actually executes real source-price native Lua decision code in Lune.
-- Client own/partner stock are synthetic; source rows are fetched by GitHub CI.
local fs=require("@lune/fs")
local serde=require("@lune/serde")
local luau=require("@lune/luau")
local base="pdiddler/system2/"
local source=serde.decode("json",fs.readFile(base.."research_market_crosswalk_current.json"))
local subject=luau.load(fs.readFile(base.."native_bilateral_attractiveness_shadow.lua"))()
local bridge=luau.load(fs.readFile(base.."native_bilateral_attractiveness_bridge.lua"))()
local rows={}
for _,r in ipairs(source.items) do rows[r.rawGameKeyCandidate]=r end
local count=0
local function eq(x,y,reason)
 count+=1
 assert(x==y,reason..": expected "..tostring(y).." got "..tostring(x))
end
local function yes(x,reason) count+=1;assert(x,reason) end
local function copy(x)
 return serde.decode("json",serde.encode("json",x))
end
local function slot(id,n)
 return {id=id,quantity=n or 1}
end
local function option(g,r)
 return {kind="HYPOTHETICAL_CURRENT_OFFER_VARIANT",give=g,receive=r}
end
local baseOwn={Frostsaber=1,Iceblaster=1,Harvester=1,Gingerscope=1}
local our={items={{slot=1,id="Iceblaster",quantity=1}}}
local their={items={{slot=1,id="SnowDagger",quantity=1},
  {slot=2,id="Icepiercer",quantity=1}}}
local function context()
 return {
  schema="gingerscope-system2-local-bilateral-context-v1",
  status="LOCAL_READONLY_MARKET_OFFER_CONTEXT",
  ownCounts=copy(baseOwn),
  crosswalkRowsSha256=source.crosswalkRowsSha256,
  sourceRetrievedUtc=source.sourceRetrievedUtc,
  clientOnly=true,readOnly=true,clientOfferRevision=7,
  marketSourceVerifiedForLiveTrade=false,
  counterpartyWillingnessVerified=false,
  authorizesOffer=false,authorizesAccept=false,
  offer={
   status="CLIENT_OFFER_OBSERVATION_READONLY",clientRevision=7,
   clientOnly=true,readOnly=true,
   sourceAgeSeconds=70,ownedCensusAgeSeconds=1,
   our=copy(our),their=copy(their),
   theirAccepted=false,ourAccepted=false,
   nameOnlyCatalogCandidateCount=0,
   exactRawAttributesBothSidesObserved=true,
   authorizesOffer=false,authorizesAccept=false,
  },
 }
end
local options={
 option({slot("Frostsaber")},{slot("SnowDagger")}),
 option({slot("Iceblaster")},{slot("Icepiercer")}),
}
local report=subject.compare(context(),source,options)
eq(report.status,"ABSTAIN_PARTNER_INTENT_UNVERIFIED","unknown interest abstains")
eq(report.selectedIndex,nil,"no invented counterparty agreement")
eq(report.researchAttentionIndices[1],2,"lower gain good demand beats higher gain junk")
eq(report.alternatives[1].mm2ListedDelta,150,"actual SnowDagger 160 versus Frostsaber 10")
eq(report.alternatives[2].mm2ListedDelta,145,"actual Icepiercer 180 versus Iceblaster 35")
eq(report.alternatives[1].partnerMm2ListedDelta,-150,"their perspective is the opposite")
eq(report.alternatives[2].partnerMm2ListedDelta,-145,"their sacrifice explicit")
eq(report.alternatives[1].incomingLowOrdinalDemand,true,"source demand 2 only")
eq(report.alternatives[2].incomingLowOrdinalDemand,false,"source demand 3")
eq(report.alternatives[2].partnerSurplusProven,nil,"no fake partner subjective utility")
eq(report.empiricalPartnerAcceptanceProbability,nil,"demand is not fill probability")
eq(report.authorizesOffer,false,"never trade from research comparison")
eq(report.authorizesAccept,false,"never accept from local shadow")
eq(report.alternatives[2].mayUseForTrade,false,"candidate not executable")

local accepted=context()
accepted.offer.their.items={their.items[2]}
accepted.offer.theirAccepted=true
local agreed=subject.compare(accepted,source,{
 option({slot("Frostsaber")},{slot("Icepiercer")}),
 option({slot("Iceblaster")},{slot("Icepiercer")}),
})
eq(agreed.status,"CLIENT_SHADOW_PREFERS_OBSERVED_ACCEPTED_OFFER","one accepted client offer only")
eq(agreed.selectedIndex,2,"accepted observed bundle beats more profitable speculative ask")
eq(agreed.selectedIndexIsActionable,false,"client accepted indicator not server binding")
eq(agreed.alternatives[1].partnerSignal,false,"other candidate not proven")
eq(agreed.alternatives[2].partnerSignal,true,"exact visible accepted bundle")
eq(agreed.alternatives[2].verifiedCounterpartyPreference,false,"not independent will")

local nameOnly=copy(accepted)
nameOnly.offer.nameOnlyCatalogCandidateCount=1
nameOnly.offer.exactRawAttributesBothSidesObserved=false
eq(subject.compare(nameOnly,source,{
 option({slot("Frostsaber")},{slot("Icepiercer")}),
 option({slot("Iceblaster")},{slot("Icepiercer")}),
}).selectedIndex,nil,"name-only cannot prove a selected accepted option")

local short=context()
short.offer.their.items={{slot=1,id="SnowDagger",quantity=1}}
local blockedStock=subject.compare(short,source,options)
eq(blockedStock.alternatives[2].reason,"PARTNER_STOCK_NOT_IN_CURRENT_VISIBLE_OFFER",
 "no invented partner stocks")

local loss=subject.compare(context(),source,{
 option({slot("Harvester")},{slot("SnowDagger")}),
 options[2],
})
eq(loss.alternatives[1].status,"RISK_FILTERED","negative both-publisher loss no approval")
eq(loss.alternatives[1].warnings[1],"UNAPPROVED_LISTED_VALUE_LOSS",
 "unapproved loss always blocked")
eq(loss.researchAttentionIndices[1],2,"eligible no-loss alternative survives")

local target=subject.compare(context(),source,{
 option({slot("Gingerscope")},{slot("Icepiercer")}),
 options[2],
})
eq(target.alternatives[1].reason,"OUTGOING_GINGERSCOPE_FORBIDDEN","target never outward")
eq(target.researchAttentionIndices[1],2,"non-target other alternative remains")

local unknown=subject.compare(context(),source,{
 option({slot("InventedMM2Key")},{slot("Icepiercer")}), options[2],
})
eq(unknown.alternatives[1].reason,"GIVE_EXCEEDS_FRESH_OWNED_COPIES",
 "unknown source key not priced or sent")
local tooMany=subject.compare(context(),source,{
 option({slot("Frostsaber"),slot("Iceblaster"),slot("Harvester"),
  slot("Gingerscope"),slot("Extra")},{slot("SnowDagger")}), options[2],
})
eq(tooMany.alternatives[1].reason,"ONE_TO_FOUR_PHYSICAL_SLOTS_REQUIRED",
 "5 physical slots rejected independent of stack copies")

local altered=copy(source)
altered.crosswalkRowsSha256=string.rep("f",64)
eq(subject.compare(context(),altered,options).reason,
  "CROSSWALK_SOURCE_REVISION_CONFLICT","stale source digest blocks")
local stale=context()
stale.offer.sourceAgeSeconds=21601
eq(subject.compare(stale,source,options).reason,
  "FRESH_UNAUTHORIZED_OR_WRONG_CLIENT_CONTEXT","source TTL enforced")
local fakeAuthority=context()
fakeAuthority.offer.authorizesOffer=true
eq(subject.compare(fakeAuthority,source,options).status,
  "BLOCKED","forged authorization never promotes market")

local emptySup=copy(source)
for _,r in ipairs(emptySup.items) do
 if r.rawGameKeyCandidate=="SnowDagger" then r.supremeListed=nil end
end
local noSup=subject.compare(context(),emptySup,options)
eq(noSup.alternatives[1].reason,"DUAL_PUBLISHER_PRICE_NOT_AVAILABLE",
 "missing list quote never becomes zero or false gain")
eq(noSup.alternatives[2].status,"RESEARCH_FEASIBLE_UNAUTHORIZED",
 "unaffected choice may remain research viable")

local highStack=context()
highStack.ownCounts.Frostsaber=7
highStack.offer.their.items={{slot=1,id="Icepiercer",quantity=6}}
local nonlinear=subject.compare(highStack,source,{
 option({slot("Frostsaber",6)},{slot("Icepiercer",6)}),options[2],
})
eq(nonlinear.alternatives[1].nonlinearStackPricingUnverified,true,
 "6 copies in one slot is supported but nonlinear pricing unknown")
eq(nonlinear.alternatives[1].status,"RISK_FILTERED",
 "large stacks not fake executable value")

local alteredSame=context()
alteredSame.offer.ownedCensusAgeSeconds=31
eq(subject.compare(alteredSame,source,options).status,"BLOCKED",
 "own scanner census 30 second max")

local inconsistent=context()
inconsistent.offer.clientRevision=8
eq(subject.compare(inconsistent,source,options).status,"BLOCKED",
 "bound snapshot revision mismatch")
local duplicate=subject.compare(context(),source,{options[1],options[1]})
eq(duplicate.status,"BLOCKED","duplicate options no false independent choice")

local badAge=context()
badAge.offer.sourceAgeSeconds=0/0
eq(subject.compare(badAge,source,options).reason,
 "FRESH_UNAUTHORIZED_OR_WRONG_CLIENT_CONTEXT","NaN source time never fresh")
local badOwnAge=context()
badOwnAge.offer.ownedCensusAgeSeconds=math.huge
eq(subject.compare(badOwnAge,source,options).status,"BLOCKED",
 "infinite owned census age blocked")
local fractionalRevision=context()
fractionalRevision.clientOfferRevision=7.5
fractionalRevision.offer.clientRevision=7.5
eq(subject.compare(fractionalRevision,source,options).status,
 "BLOCKED","noninteger revision cannot validate offer")
local forgedAccept=context()
forgedAccept.offer.theirAccepted="true"
eq(subject.compare(forgedAccept,source,options).status,
 "BLOCKED","string accepted flag not partner willingness")
local invisibleFifth=context()
invisibleFifth.offer.their.items={
 {slot=1,id="SnowDagger",quantity=1},
 {slot=2,id="Icepiercer",quantity=1},
 {slot=3,id="Iceblaster",quantity=1},
 {slot=4,id="Frostsaber",quantity=1},
 {slot=5,id="Harvester",quantity=1},
}
eq(subject.compare(invisibleFifth,source,options).status,
 "BLOCKED","forged fifth physical partner offer rejected")
local missingStable=context()
missingStable.offer.their.items={{slot=1,id="TheSeer",quantity=1},
 {slot=2,id="Icepiercer",quantity=1}}
local noStable=subject.compare(missingStable,source,{
 option({slot("Frostsaber")},{slot("TheSeer")}),
 option({slot("Iceblaster")},{slot("Icepiercer")}),
})
eq(noStable.alternatives[1].reason,"PUBLISHER_STABILITY_MISSING",
 "real Seer has no publisher stability, never silently treat stable")
eq(noStable.alternatives[2].status,"RESEARCH_FEASIBLE_UNAUTHORIZED",
 "unknown item stability does not taint unrelated observed option")
local callN=0
local current=context()
local dynamic={researchContext=function()
 callN+=1
 if callN==2 then current.offer.clientRevision=8;current.clientOfferRevision=8 end
 return copy(current)
end}
local adapter,adapterWhy=bridge.new({marketBridge=dynamic,bilateralCore=subject,crosswalk=source})
yes(adapter~=nil,"native crosswalk strategy bridge created")
eq(adapter:compare(options).reason,"OFFER_OR_SOURCE_CHANGED_DURING_STRATEGY_COMPARISON",
 "mid-evaluation live GUI change invalidates ranked preview")
local stable={researchContext=function()return context()end}
local adapter2,why2=bridge.new({marketBridge=stable,bilateralCore=subject,crosswalk=source})
yes(adapter2~=nil,"replay correctly bound")
eq(adapter2:compare(options).status,"ABSTAIN_PARTNER_INTENT_UNVERIFIED",
 "stable evidence but unwillingness unknown, sensible abstain")
print("SYSTEM2_BILATERAL_LIVE_SOURCE_NATIVE_ASSERTIONS_PASSED "..tostring(count))
