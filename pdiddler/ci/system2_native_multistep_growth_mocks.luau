-- True Lune execution of native C5 bounded route discovery and C4 bilateral.
-- Actual fresh public market prices are fetched in this CI workflow; all game
-- holdings, seller scenarios, player GUI revisions are SANITIZED SIMULATIONS.
local fs=require("@lune/fs")
local serde=require("@lune/serde")
local luau=require("@lune/luau")
local root="pdiddler/system2/"
local market=serde.decode("json",fs.readFile(root.."research_market_crosswalk_current.json"))
local c4=luau.load(fs.readFile(root.."native_bilateral_attractiveness_shadow.lua"))()
local c5=luau.load(fs.readFile(root.."native_multistep_growth_shadow.lua"))()
local bridge=luau.load(fs.readFile(root.."native_multistep_growth_bridge.lua"))()
local count=0
local function eq(x,y,why)
 count+=1
 assert(x==y,why..": expected "..tostring(y)..", got "..tostring(x))
end
local function yes(x,why)count+=1;assert(x,why)end
local function copy(v)return serde.decode("json",serde.encode("json",v))end
local function id(k,q)return {id=k,quantity=q or 1} end
local function seller(...)
 local items={...}
 return {kind="EXPLICIT_HYPOTHETICAL_FUTURE_SELLER_STOCK",
   stock=items,availabilityVerified=false,willingnessVerified=false}
end
local function config(...)
 return {kind="BOUNDED_RESEARCH_FUTURE_SELLER_ROUTE_SEARCH",
  futureSellerStages={...}}
end
local rows={}
for _,r in ipairs(market.items) do rows[r.rawGameKeyCandidate]=r end
eq(#market.items,189,"actual current gamekey catalog")
eq(rows.Gingerscope.mm2Listed,16000,"source target value—not guaranteed execution price")
eq(rows.SnowDagger.mm2Listed,160,"source high paper gain trap")
eq(rows.Icepiercer.mm2Listed,180,"source higher-demand goal")
eq(rows.Icepiercer.demandOrdinal,"3","actual demand label not fill probability")
local function context()
 return {
 schema="gingerscope-system2-local-bilateral-context-v1",
 status="LOCAL_READONLY_MARKET_OFFER_CONTEXT",
 ownCounts={Frostsaber=1,Iceblaster=1,Harvester=1,OrangeSeer=1},
 crosswalkRowsSha256=market.crosswalkRowsSha256,
 sourceRetrievedUtc=market.sourceRetrievedUtc,
 clientOnly=true,readOnly=true,clientOfferRevision=4,
 marketSourceVerifiedForLiveTrade=false,
 counterpartyWillingnessVerified=false,
 authorizesOffer=false,authorizesAccept=false,
 offer={status="CLIENT_OFFER_OBSERVATION_READONLY",
  clientRevision=4,clientOnly=true,readOnly=true,
  sourceAgeSeconds=120,ownedCensusAgeSeconds=1,
  our={items={}},their={items={id("SnowDagger"),id("Icepiercer")}},
  theirAccepted=false,ourAccepted=false,
  nameOnlyCatalogCandidateCount=0,
  exactRawAttributesBothSidesObserved=true,
  authorizesOffer=false,authorizesAccept=false}
 }
end
local stages=config(
 seller(id("Waves_K"),id("FlowerwoodGun"),id("Ocean_G"),id("Blizzard")),
 seller(id("Snowcannon"),id("SunsetKnife"),id("Bauble"),id("SunsetGun")))
local result=c5.search(context(),market,stages,c4)
eq(result.status,"RESEARCH_GROWTH_ROUTE_DISCOVERY_ONLY",
  "real-source bounded 2-3 step dynamic route search")
yes(result.firstOptionsCompared>=2,"two different actually observed first trade possibilities")
yes(result.distinctFirstStepRoutesDisplayed>=2,"distinct first steps, not five copies of same trade")
yes(#result.alternativeRoutes>=2,"competing paths actually returned")
eq(result.futureSellerStageCount,2,"two different future seller hypotheses")
yes(result.searchPairEvaluations>2,"real search rather than scripted replay")
eq(result.targetListedValue,16000,"gap uses current source value")
eq(result.futureSellerAvailabilityVerified,false,"hypothetical future seller never proven")
eq(result.anyPartnerWillingnessVerified,false,"no fake acceptance")
eq(result.selectedRouteActionable,false,"research recommendation never gameplay action")
eq(result.authorizesOffer,false,"never place offer")
eq(result.authorizesAccept,false,"never press Accept")
eq(result.mayReportProfit,false,"no fake settled profit")
eq(result.originalMM2LivePass,false,"offline native mock is not client pass")
for _,route in ipairs(result.alternativeRoutes) do
 yes(route.routeLength>=2 and route.routeLength<=3,"must genuinely plan two or more steps")
 yes(route.steps[1].scope=="ACTUAL_CLIENT_OFFER_VISIBLE_UNVERIFIED_ACCEPTANCE",
  "starting point constrained to observed partner GUI stock")
 eq(route.distinctFirstStepSignature~=nil,true,"first move fingerprint attached")
 eq(route.futureSellerStocksIndependentlyObserved,false,"never promote fictional future stock")
 for n,step in ipairs(route.steps) do
  yes(#step.give>=1 and #step.give<=4,"give physical slots bound")
  yes(#step.receive>=1 and #step.receive<=4,"receive physical slots bound")
  yes(step.mm2ListedGain>=0 and step.supremeListedGain>=0,
   "both public price lists no unapproved loss")
  eq(step.partnerMm2ListedDelta,-step.mm2ListedGain,
   "seller loses MAIN's listed gain, zero-sum")
  eq(step.partnerSupremeListedDelta,-step.supremeListedGain,
   "seller loses MAIN's Supreme listed gain")
  eq(step.sellerActuallyVerified,false,"even first offer is only client seen")
  eq(step.authorizedAction,false,"never action from hypothetical step")
  if n>1 then
   eq(step.scope,"EXPLICIT_HYPOTHETICAL_FUTURE_SELLER_UNVERIFIED",
    "later seller cannot look like real GUI evidence")
  end
  for _,outItem in ipairs(step.give) do
   yes(outItem.id~="Gingerscope","target never outgoing")
  end
 end
end

local stableBridge={researchContext=function()return context()end}
local connected,reason=bridge.new({
 marketBridge=stableBridge,growthCore=c5,bilateralCore=c4,crosswalk=market})
yes(connected~=nil,"component3->component4->component5 bridge created")
local bound=connected:discover(stages.futureSellerStages)
eq(bound.status,"RESEARCH_GROWTH_ROUTE_DISCOVERY_ONLY",
 "read-only native route bridge can produce candidate paths")
eq(bound.authorizesTrade,false,"bound route no trading authority")
local changing=0
local changedBridge={researchContext=function()
 changing+=1
 local x=context()
 if changing>=2 then x.clientOfferRevision=5;x.offer.clientRevision=5 end
 return x
end}
local changed=bridge.new({marketBridge=changedBridge,growthCore=c5,
 bilateralCore=c4,crosswalk=market})
eq(changed:discover(stages.futureSellerStages).reason,
 "OWN_INVENTORY_OFFER_OR_SOURCE_CHANGED_DURING_GROWTH_SEARCH",
 "changed original GUI revisions invalidate entire expensive path search")
local ownChange=0
local changedOwn=bridge.new({
 marketBridge={researchContext=function()
  ownChange+=1
  local c=context()
  if ownChange>=2 then c.ownCounts.Frostsaber=2 end
  return c
 end},
 growthCore=c5,bilateralCore=c4,crosswalk=market})
eq(changedOwn:discover(stages.futureSellerStages).status,"BLOCKED",
 "changing owned client copy counts invalidate route")

local fakeFuture=copy(stages)
fakeFuture.futureSellerStages[1].availabilityVerified=true
eq(c5.search(context(),market,fakeFuture,c4).reason,
 "FUTURE_SELLER_STAGE_MUST_BE_HYPOTHETICAL",
 "invented confirmed future availability blocked")
local futureUnknown=config(seller(id("FAKEWEAPON123")))
eq(c5.search(context(),market,futureUnknown,c4).reason,
 "STOCK_RAW_KEY_OR_QUANTITY_INVALID",
 "unknown future market stock blocks no guessing")
local fakeSource=copy(market)
fakeSource.authorizesTrade=true
eq(c5.search(context(),fakeSource,stages,c4).reason,
 "SOURCE_MARKET_CROSSWALK_UNVERIFIED","source authority cannot be forged")
local targetFuture=config(seller(id("Gingerscope")))
eq(c5.search(context(),market,targetFuture,c4).status,"ABSTAIN",
 "unattributed future Gingerscope seller cannot create fantasy acquisition route")
local noPartner=context()
noPartner.offer.their.items={}
eq(c5.search(noPartner,market,stages,c4).reason,
 "PARTNER_CURRENT_OFFER_EMPTY","initial seller has not offered stock")
local sourceOld=context()
sourceOld.offer.sourceAgeSeconds=21601
eq(c5.search(sourceOld,market,stages,c4).reason,
 "COMPONENT4_BILATERAL_ORACLE_REJECTED_FIRST_STEPS",
 "stale prices prevent route planning")
local staleRev=context()
staleRev.offer.clientRevision=9
eq(c5.search(staleRev,market,stages,c4).status,"BLOCKED",
 "changed GUI revision cannot be a valid first step")

local small=context()
small.ownCounts={OrangeSeer=1,Harvester=1}
small.offer.their.items={id("Flames"),id("Frostbite")}
local compounding=c5.search(small,market,
 config(seller(id("Frostsaber"),id("Chill"),id("BattleAxe"))),c4)
eq(compounding.status,"RESEARCH_GROWTH_ROUTE_DISCOVERY_ONLY",
 "+5 original MM2 first step supported without old +15 min")
local foundFive=false
for _,route in ipairs(compounding.alternativeRoutes) do
 if route.steps[1].mm2ListedGain==5 then foundFive=true end
end
yes(foundFive,"literal +5 strategy can be discovered and compared")
local bigStack=copy(small)
bigStack.ownCounts.OrangeSeer=6
local stacked=c5.search(bigStack,market,
 config(seller(id("Frostsaber"),id("Chill"))),c4)
yes(stacked.rejectedUnverifiedStackPairs>0,
 "six copies fit one physical slot but price is not verified linear")

print("SYSTEM2_GROWTH_MARKET_NATIVE_ASSERTIONS_PASSED "..tostring(count))
