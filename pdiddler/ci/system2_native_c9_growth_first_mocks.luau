-- C9 actual ORIGINAL C4 bilateral Luau on intentionally synthetic
-- counterfactual publisher quotes; tests growth-first ranking logic only.
-- The manipulated market rows below are NEVER asserted live/current truth.
local fs=require("@lune/fs")
local serde=require("@lune/serde")
local luau=require("@lune/luau")
local base="pdiddler/system2/"
local real=serde.decode("json",fs.readFile(base.."research_market_crosswalk_current.json"))
local market=serde.decode("json",serde.encode("json",real))
local originalC4=luau.load(fs.readFile(base.."native_bilateral_attractiveness_shadow.lua"))()
local c9=luau.load(fs.readFile(base.."native_c9_growth_first_preview.lua"))()
local count=0
local function eq(x,y,why)
 count+=1
 assert(x==y,why..": expected "..tostring(y)..", got "..tostring(x))
end
local function yes(x,why)count+=1;assert(x,why)end
local function copy(x)return serde.decode("json",serde.encode("json",x))end
local rows={}
for _,r in ipairs(market.items) do rows[r.rawGameKeyCandidate]=r end
eq(#market.items,189,"C9 real complete 189-key source roster loaded")
-- Deliberately hypothetical, not authenticated publisher prices: fix
-- stable ordinal/delta signs to exercise a loss with TWO descriptive
-- improvements versus a higher paper-gain item with LOW demand.
local function row(id,mm2,sup,demand,stability)
 yes(rows[id]~=nil,"C9 original catalog key exists "..id)
 local r=rows[id]
 r.mm2Listed=mm2;r.supremeListed=sup
 r.demandOrdinal=tostring(demand);r.stabilityLabel=stability
end
row("Harvester",400,400,1,"Stable")
row("Icepiercer",300,300,8,"Stable")
row("Frostsaber",20,20,4,"Stable")
row("SnowDagger",180,180,1,"Stable")
row("Iceblaster",35,35,3,"Stable")
market.crosswalkRowsSha256=string.rep("e",64)
local job="C9_SYNTHETIC_TEST_JOB_001"
local lease="C9_SYNTHETIC_TEST_LEASE_001"
local ctx={
 schema="gingerscope-system2-local-bilateral-context-v1",
 status="LOCAL_READONLY_MARKET_OFFER_CONTEXT",
 ownCounts={Harvester=1,Frostsaber=1,Iceblaster=1},
 sessionScope={jobId=job,leaseId=lease,partnerUserId=92345},
 crosswalkRowsSha256=market.crosswalkRowsSha256,
 sourceRetrievedUtc=market.sourceRetrievedUtc,
 clientOnly=true,readOnly=true,clientOfferRevision=7,
 marketSourceVerifiedForLiveTrade=false,
 counterpartyWillingnessVerified=false,
 authorizesOffer=false,authorizesAccept=false,
 offer={
  status="CLIENT_OFFER_OBSERVATION_READONLY",
  clientRevision=7,clientOnly=true,readOnly=true,
  sourceAgeSeconds=10,ownedCensusAgeSeconds=2,
  our={items={}},their={items={
   {slot=1,id="Icepiercer",quantity=1},
   {slot=2,id="SnowDagger",quantity=1},
  }},
  ourAccepted=false,theirAccepted=false,
  nameOnlyCatalogCandidateCount=0,
  exactRawAttributesBothSidesObserved=true,
  authorizesOffer=false,authorizesAccept=false,
 }
}
local function slot(id,n)return {id=id,quantity=n or 1}end
local options={
 {kind="HYPOTHETICAL_CURRENT_OFFER_VARIANT",
  give={slot("Harvester")},receive={slot("Icepiercer")}},
 {kind="HYPOTHETICAL_CURRENT_OFFER_VARIANT",
  give={slot("Frostsaber")},receive={slot("SnowDagger")}}
}
local originalReport=originalC4.compare(ctx,market,options)
eq(originalReport.status,"ABSTAIN_PARTNER_INTENT_UNVERIFIED",
 "C9 original C4 remains research only with no granted trade consent")
eq(originalReport.alternatives[1].status,"RISK_FILTERED",
 "C9 original C4 still blocks execution for listed value loss")
eq(originalReport.alternatives[1].mm2ListedDelta,-100,
 "C9 synthetic downside test loses exactly 100 paper value")
eq(originalReport.alternatives[2].mm2ListedDelta,160,
 "C9 synthetic positive test gains 160 paper value")
local source={researchContext=function()return copy(ctx)end}
local originalBridge={compare=function(self,alts)
 return originalC4.compare(source.researchContext(),market,alts)
end}
local engine,err=c9.new({marketBridge=source,bilateralBridge=originalBridge,market=market})
yes(engine~=nil,"C9 standalone original C4 research engine composed")
local r=engine:preview(options)
eq(r.status,"GROWTH_FIRST_LISTED_LOSS_RESEARCH_ONLY",
 "C9 growth-first research permits discussing losses, not execution")
eq(r.lossAlternativesExamined,1,"C9 lost trade no longer invisible to research")
eq(r.qualityImprovingLossHypotheses,1,
 "C9 only independently separated descriptive demand and concentration signals")
eq(r.researchAttentionOrder[1],1,
 "C9 hypothetical high quality minus100 may outrank plus160 low-demand trap")
eq(r.alternatives[1].class,"LOSS_QUALITY_UPGRADE_WORTH_RESEARCH",
 "C9 loss is flagged research-worthy, NOT prediction of long-run profit")
eq(r.alternatives[2].class,"PAPER_VALUE_OR_DEMAND_TRAP_NEEDS_EXIT_EVIDENCE",
 "C9 plus160 on low demand is not blindly the best trade")
eq(r.authorizesAccept,false,"C9 never enables final Accept")
eq(r.liveLossAuthorized,false,"C9 no approved live loss budget")
eq(r.verifiedLongTermGain,false,"C9 ordinal demand is not actual exit fill")
eq(r.empiricalExitLiquidity,nil,"C9 no invented liquidity data")
eq(r.mayUseForStrategyLearning,false,"C9 hypothetical cannot train on phantom buyers")
eq(r.approvedRiskBudget,false,"C9 must not infer a numeric approved budget")
-- When a no-loss route genuinely improves both proxies, prefer that over
-- a comparable loss; not a blanket +15 threshold or forced smallest loss.
row("SnowDagger",180,180,9,"Stable")
local preferred=engine:preview(options)
eq(preferred.status,"GROWTH_FIRST_LISTED_LOSS_RESEARCH_ONLY",
 "C9 re-evaluates contextual market scenario")
eq(preferred.alternatives[1].index,2,
 "C9 equally strong no-loss quality improvement wins research tie")
-- A 100-loss for minor/negative quality is NOT worth prioritizing.
row("SnowDagger",180,180,1,"Stable")
row("Icepiercer",300,300,1,"Stable")
local weak=engine:preview(options)
eq(weak.qualityImprovingLossHypotheses,0,
 "C9 no positive demand-quality signal cannot justify an alleged upgrade")
eq(weak.alternatives[2].class,"LOSS_WITHOUT_SUFFICIENT_INDEPENDENT_QUALITY_SIGNALS",
 "C9 guess about future buyer does not win ranking")
row("Icepiercer",300,300,8,"Unsafe")
local unsafe=engine:preview(options)
eq(unsafe.alternatives[2].class,"RESEARCH_REJECTED_UNCERTAIN_OR_UNSAFE",
 "C9 unsafe incoming stability overrides tempting demand+concentration")
row("Icepiercer",300,300,8,"Stable")
-- The outgoing protected target can never become a research-winning loss.
local prohibited=copy(options)
prohibited[1].give={slot("Gingerscope")}
local protected=engine:preview(prohibited)
eq(protected.status,"GROWTH_FIRST_LISTED_LOSS_RESEARCH_ONLY",
 "C9 original C4 still returns explicitly FILTERED option")
eq(protected.alternatives[2].class,"RESEARCH_REJECTED_C4_FILTERED",
 "C9 never promotes outgoing Gingerscope")
-- A missing context/session, forged trade authority, or C3 drift is fatal.
local missing=copy(ctx);missing.sessionScope=nil
local never=c9.new({
 marketBridge={researchContext=function()return missing end},
 bilateralBridge=originalBridge,market=market})
eq(never:preview(options).reason,"C9_ACTUAL_C3_SESSION_CONTEXT_REQUIRED",
 "C9 refuse unbound P3/P4 scoped client data")
local forged={compare=function()
 local x=originalC4.compare(ctx,market,options)
 x.authorizesAccept=true
 return x
end}
local liar=c9.new({marketBridge=source,bilateralBridge=forged,market=market})
eq(liar:preview(options).reason,"C9_GENUINE_C4_BILATERAL_EVIDENCE_REQUIRED",
 "C9 forged final Accept never passes")
local n=0
local drift=c9.new({
 marketBridge={researchContext=function()
  n+=1
  local x=copy(ctx)
  if n>2 then x.sessionScope.leaseId="C9_DIFFERENT_LEASE_001" end
  return x
 end},bilateralBridge=originalBridge,market=market})
eq(drift:preview(options).reason,
 "C9_ORIGINAL_C3_SESSION_OR_OFFER_CHANGED_DURING_RESEARCH",
 "C9 source/lease ABA stops scored long-term research")
local encoded=serde.encode("json",r)
for _,private in ipairs({job,lease,"Harvester","Icepiercer",
 "SnowDagger","92345"}) do
 eq(encoded:find(private,1,true),nil,
  "C9 research summary never exports private identity or item keys")
end
print("SYSTEM2_C9_GROWTH_FIRST_NATIVE_ASSERTIONS_PASSED "..tostring(count))
