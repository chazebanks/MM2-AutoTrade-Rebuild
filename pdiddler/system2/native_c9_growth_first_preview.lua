-- System2 C9 GROWTH-FIRST research evaluator.
-- This is a local-only research lens over the ORIGINAL C3 scanner/P4 GUI and
-- ORIGINAL C4 bilateral price/demand/portfolio evaluator; C5 continues
-- to refuse live/unapproved negative-value steps. It does not place offers.
-- "Better exit" and "future gain" are hypotheses until verified retrades.
local M={}
local SCHEMA="gingerscope-system2-c9-growth-first-research-v1"
local function denied(reason)
 return {schema=SCHEMA,status="BLOCKED",reason=reason,
  readOnly=true,clientOnly=true,
  objective="LONG_TERM_QUALITY_AND_GINGERSCOPE_ACQUISITION_RESEARCH",
  empiricalFillRate=nil,empiricalExitLiquidity=nil,
  verifiedLongTermGain=false,verifiedTradeSettlement=false,
  selectedTradeActionable=false,liveLossAuthorized=false,
  approvedRiskBudget=false,authorizesTrade=false,authorizesOffer=false,
  authorizesAccept=false,authorizesChat=false,mayReportProfit=false,
  maySendDiscordWebhook=false,mayUseForStrategyLearning=false}
end
local function finite(v)
 return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge
end
local function validScope(s)
 return type(s)=="table" and type(s.jobId)=="string" and
  #s.jobId>=8 and type(s.leaseId)=="string" and #s.leaseId>=8 and
  finite(s.partnerUserId) and s.partnerUserId==math.floor(s.partnerUserId) and
  s.partnerUserId>0
end
local function sameCounts(a,b)
 if type(a)~="table" or type(b)~="table" then return false end
 for k,q in pairs(a) do if type(k)~="string" or not finite(q) or b[k]~=q then
  return false end end
 for k,q in pairs(b) do if type(k)~="string" or not finite(q) or a[k]~=q then
  return false end end
 return true
end
local function sameSide(a,b)
 if type(a)~="table" or type(b)~="table" or
  type(a.items)~="table" or type(b.items)~="table" or
  #a.items~=#b.items or a.physicalSlots~=b.physicalSlots or
  a.mm2Listed~=b.mm2Listed or a.supremeListed~=b.supremeListed or
  a.clientNameOnlyCandidates~=b.clientNameOnlyCandidates or
  a.allRawAttributesObserved~=b.allRawAttributesObserved then return false end
 for i,v in ipairs(a.items) do
  local w=b.items[i]
  if type(v)~="table" or type(w)~="table" or
   v.slot~=w.slot or v.id~=w.id or v.quantity~=w.quantity or
   v.clientIdentityEvidence~=w.clientIdentityEvidence then return false end
 end
 return true
end
local function sameCtx(a,b)
 if type(a)~="table" or type(b)~="table" or
  a.status~="LOCAL_READONLY_MARKET_OFFER_CONTEXT" or
  b.status~="LOCAL_READONLY_MARKET_OFFER_CONTEXT" or
  a.readOnly~=true or b.readOnly~=true or a.clientOnly~=true or
  b.clientOnly~=true or a.authorizesOffer~=false or
  b.authorizesOffer~=false or a.authorizesAccept~=false or
  b.authorizesAccept~=false or not validScope(a.sessionScope) or
  not validScope(b.sessionScope) or
  a.sessionScope.jobId~=b.sessionScope.jobId or
  a.sessionScope.leaseId~=b.sessionScope.leaseId or
  a.sessionScope.partnerUserId~=b.sessionScope.partnerUserId or
  a.crosswalkRowsSha256~=b.crosswalkRowsSha256 or
  a.sourceRetrievedUtc~=b.sourceRetrievedUtc or
  a.clientOfferRevision~=b.clientOfferRevision or
  not sameCounts(a.ownCounts,b.ownCounts) then return false end
 local x,y=a.offer,b.offer
 return type(x)=="table" and type(y)=="table" and
  x.status==y.status and x.clientRevision==y.clientRevision and
  x.ourAccepted==y.ourAccepted and x.theirAccepted==y.theirAccepted and
  x.mm2ListedDelta==y.mm2ListedDelta and
  x.supremeListedDelta==y.supremeListedDelta and
  x.nameOnlyCatalogCandidateCount==y.nameOnlyCatalogCandidateCount and
  x.exactRawAttributesBothSidesObserved==y.exactRawAttributesBothSidesObserved and
  sameSide(x.our,y.our) and sameSide(x.their,y.their)
end
local function valueStats(owned,market)
 if type(market)~="table" or type(market.items)~="table" or
  #market.items~=189 then return nil end
 local index={}
 for _,r in ipairs(market.items) do
  if type(r)~="table" or type(r.rawGameKeyCandidate)~="string" or
   index[r.rawGameKeyCandidate] or not finite(r.mm2Listed) or
   r.mm2Listed<=0 or not finite(tonumber(r.demandOrdinal)) or
   type(r.stabilityLabel)~="string" then return nil end
  index[r.rawGameKeyCandidate]=r
 end
 local total,largest,atRisk=0,0,0
 for k,q in pairs(owned) do
  local row=index[k]
  if not row or not finite(q) or q<1 or q~=math.floor(q) then
   return nil end
  local v=row.mm2Listed*q
  total+=v
  if v>largest then largest=v end
  local stability=row.stabilityLabel:lower():gsub("[^%a]","")
  if stability=="unsafe" or stability=="decreasing" or
     stability=="underpaidfor" or stability=="unknown" then
   atRisk+=v end
 end
 if total<=0 then return nil end
 return {concentration=math.floor(10000*largest/total),
  riskShare=math.floor(10000*atRisk/total)}
end
local function warningSet(w)
 if type(w)~="table" then return nil end
 local seen={}
 for _,s in ipairs(w) do
  if type(s)~="string" or seen[s] then return nil end
  seen[s]=true
 end
 return seen
end
local function scorer(row,before)
 if type(row)~="table" or not finite(row.mm2ListedDelta) or
   not finite(row.supremeListedDelta) or
   not finite(row.incomingDemandOrdinal) or
   not finite(row.outgoingDemandOrdinal) or
   not finite(row.qualityChangeDemandOrdinal) or
   not finite(row.beforeConcentrationBasisPoints) or
   not finite(row.afterConcentrationBasisPoints) or
   not finite(row.afterAtRiskShareBasisPoints) or
   not finite(row.partnerMm2ListedDelta) or
   not finite(row.partnerSupremeListedDelta) or
   type(row.incomingLowOrdinalDemand)~="boolean" or
   type(row.incomingAtRisk)~="boolean" or
   type(row.nonlinearStackPricingUnverified)~="boolean" then
  return nil
 end
 local warnings=warningSet(row.warnings)
 if not warnings then return nil end
 local loss=row.mm2ListedDelta<0 or row.supremeListedDelta<0
 local copyRisk=row.nonlinearStackPricingUnverified or
  warnings.FIVE_PLUS_COPY_PRICE_NONLINEAR
 local unsafe=row.incomingAtRisk or warnings.UNSAFE_INCOMING_STABILITY
 local sourceQualityImprove=row.qualityChangeDemandOrdinal>0 and
  row.incomingDemandOrdinal>row.outgoingDemandOrdinal
 local concentrationImprove=row.afterConcentrationBasisPoints<
  before.concentration
 local riskWorsens=row.afterAtRiskShareBasisPoints>before.riskShare
 local liquidTrap=row.incomingLowOrdinalDemand or
  row.incomingDemandOrdinal<=2
 local validResearchShape=(row.status=="RESEARCH_FEASIBLE_UNAUTHORIZED") or
  (row.status=="RISK_FILTERED" and loss and
   warnings.UNAPPROVED_LISTED_VALUE_LOSS)
 local rejected=not validResearchShape or copyRisk or unsafe or
   (loss and not warnings.UNAPPROVED_LISTED_VALUE_LOSS)
 local class,priority
 if rejected then class="RESEARCH_REJECTED_UNCERTAIN_OR_UNSAFE";priority=0
 elseif loss and sourceQualityImprove and concentrationImprove and
    not riskWorsens and not liquidTrap then
   class="LOSS_QUALITY_UPGRADE_WORTH_RESEARCH";priority=4
 elseif not loss and sourceQualityImprove and concentrationImprove and
    not riskWorsens and not liquidTrap then
   class="NO_LOSS_QUALITY_UPGRADE_WORTH_RESEARCH";priority=4
 elseif not loss and not liquidTrap and not riskWorsens then
   class="NO_LOSS_POSSIBLE_COMPOUNDING_ROUTE";priority=3
 elseif loss then
   class="LOSS_WITHOUT_SUFFICIENT_INDEPENDENT_QUALITY_SIGNALS";priority=1
 else
   class="PAPER_VALUE_OR_DEMAND_TRAP_NEEDS_EXIT_EVIDENCE";priority=2
 end
 return {index=row.index,class=class,priority=priority,
  mm2ListedDelta=row.mm2ListedDelta,
  supremeListedDelta=row.supremeListedDelta,
  listedValueLoss=loss,
  demandQualityImprovedDescriptive=sourceQualityImprove,
  concentrationImprovedDescriptive=concentrationImprove,
  riskShareWorsened=riskWorsens,
  incomingLowDemandCaution=liquidTrap,
  partnerListedDeltaMm2=row.partnerMm2ListedDelta,
  partnerListedDeltaSupreme=row.partnerSupremeListedDelta,
  counterpartyWillingnessVerified=false,
  empiricallyVerifiedRetradability=false,
  futureBuyerExistsVerified=false,
  listedValueLossTradeAuthorized=false,
  mayUseForLiveOffer=false}
end
local function better(a,b)
 if a.priority~=b.priority then return a.priority>b.priority end
 -- Same growth-quality tier: prefer nonloss, then less paper downside.
 if a.listedValueLoss~=b.listedValueLoss then
  return not a.listedValueLoss end
 if a.riskShareWorsened~=b.riskShareWorsened then
  return not a.riskShareWorsened end
 local x=math.min(a.mm2ListedDelta,a.supremeListedDelta)
 local y=math.min(b.mm2ListedDelta,b.supremeListedDelta)
 if x~=y then return x>y end
 return a.index<b.index
end
function M.new(config)
 if type(config)~="table" or type(config.marketBridge)~="table" or
    type(config.marketBridge.researchContext)~="function" or
    type(config.bilateralBridge)~="table" or
    type(config.bilateralBridge.compare)~="function" or
    type(config.market)~="table" then
  return nil,"C9_ORIGINAL_C3_C4_SOURCE_DEPENDENCIES_MISSING" end
 local obj={}
 function obj:preview(options)
  if type(options)~="table" or #options<2 or #options>12 then
   return denied("C9_TWO_TO_TWELVE_DISTINCT_ALTERNATIVES_REQUIRED") end
  local a,start=pcall(config.marketBridge.researchContext)
  if not a or not sameCtx(start,start) then
   return denied("C9_ACTUAL_C3_SESSION_CONTEXT_REQUIRED") end
  if start.crosswalkRowsSha256~=config.market.crosswalkRowsSha256 or
     start.sourceRetrievedUtc~=config.market.sourceRetrievedUtc or
     config.market.authorizesTrade~=false or
     config.market.mayUseForLiveOffer~=false then
   return denied("C9_ACTUAL_SOURCE_REVISION_MISMATCH") end
  local baseline=valueStats(start.ownCounts,config.market)
  if not baseline then return denied("C9_BASELINE_RISK_QUALITY_UNAVAILABLE") end
  local b,report=pcall(config.bilateralBridge.compare,
    config.bilateralBridge,options)
  if not b or type(report)~="table" or
    report.schema~="gingerscope-system2-bilateral-market-shadow-v1" or
    (report.status~="ABSTAIN_PARTNER_INTENT_UNVERIFIED" and
     report.status~="CLIENT_SHADOW_PREFERS_OBSERVED_ACCEPTED_OFFER") or
    report.authorizesTrade~=false or report.authorizesOffer~=false or
    report.authorizesAccept~=false or report.mayUseForStrategyLearning~=false or
    report.completedTradeProven~=false or
    report.sourceRowsSha256~=start.crosswalkRowsSha256 or
    report.clientOfferRevision~=start.clientOfferRevision or
    type(report.alternatives)~="table" or
    #report.alternatives~=#options then
   return denied("C9_GENUINE_C4_BILATERAL_EVIDENCE_REQUIRED") end
  local ranked={}
  for i,row in ipairs(report.alternatives) do
   if type(row)~="table" or row.index~=i then
    return denied("C9_CORRUPT_OR_REORDERED_C4_REPORT") end
   if row.status=="FILTERED" then
    ranked[#ranked+1]={index=i,class="RESEARCH_REJECTED_C4_FILTERED",
     priority=0,listedValueLoss=false,mayUseForLiveOffer=false}
   else
    local entry=scorer(row,baseline)
    if not entry then return denied("C9_UNVERIFIED_C4_OPTION_METRICS") end
    ranked[#ranked+1]=entry
   end
  end
  local c,last=pcall(config.marketBridge.researchContext)
  if not c or not sameCtx(start,last) then
   return denied("C9_ORIGINAL_C3_SESSION_OR_OFFER_CHANGED_DURING_RESEARCH") end
  table.sort(ranked,better)
  local countLoss,qualityLoss,needsEvidence=0,0,0
  local attention={}
  for _,v in ipairs(ranked) do
   attention[#attention+1]=v.index
   if v.listedValueLoss then
    countLoss+=1
    if v.class=="LOSS_QUALITY_UPGRADE_WORTH_RESEARCH" then
     qualityLoss+=1
    else needsEvidence+=1 end
   end
  end
  return {schema=SCHEMA,status="GROWTH_FIRST_LISTED_LOSS_RESEARCH_ONLY",
   objective="LONG_TERM_QUALITY_AND_GINGERSCOPE_ACQUISITION_RESEARCH",
   sourceRowsSha256=start.crosswalkRowsSha256,
   clientOfferRevision=start.clientOfferRevision,
   baselineConcentrationBasisPoints=baseline.concentration,
   baselineAtRiskShareBasisPoints=baseline.riskShare,
   researchAttentionOrder=attention,alternatives=ranked,
   lossAlternativesExamined=countLoss,
   qualityImprovingLossHypotheses=qualityLoss,
   unconvincingLossHypotheses=needsEvidence,
   noLossRouteRequiredBeforeLiveLoss=false,
   bothSidesListedValueCompared=true,
   futureBuyerExistsVerified=false,
   empiricalFillRate=nil,empiricalExitLiquidity=nil,
   verifiedLongTermGain=false,verifiedTradeSettlement=false,
   selectedTradeActionable=false,liveLossAuthorized=false,
   approvedRiskBudget=false,readOnly=true,clientOnly=true,
   authorizesTrade=false,authorizesOffer=false,authorizesAccept=false,
   authorizesChat=false,mayReportProfit=false,maySendDiscordWebhook=false,
   mayUseForStrategyLearning=false}
 end
 return obj,nil
end
return M
