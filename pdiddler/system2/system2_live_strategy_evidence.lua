-- System2 live strategy interpretation for exact-ALT client-only observations.
-- Pure Lua5.4/Luau; no Roblox, networking, Discord sending or action calls.
-- Client names/IDs are used ONLY locally for comparisons and never returned.
local M={}
local KINDS={
 EVENT_PROVENANCE=true, BEHAVIOR_REVISION=true,
 BILATERAL_ALTERNATIVES=true, GROWTH_STRUCTURE=true,
 INVALIDATE_STALE_RESEARCH=true,
}
local function isInt(x,lo,hi)
 return type(x)=="number" and x==math.floor(x) and x>=lo and x<=hi
end
local function protect(x)
 return type(x)=="string" and x:lower():gsub("[^%w]",""):find("gingerscope",1,true)~=nil
end
local function verifiedShape(items)
 if type(items)~="table" or getmetatable(items)~=nil or #items>4 then return false end
 local seen,n={},0
 for k,v in pairs(items) do
  n=n+1
  if not isInt(k,1,4) or k>#items or
     type(v)~="table" or getmetatable(v)~=nil or
     not isInt(v.slot,1,4) or seen[v.slot] or
     not isInt(v.qty,1,1000000) or
     type(v.name)~="string" or #v.name<1 or #v.name>100 or
     v.name:find("[%c]") or
     type(v.id)~="string" or #v.id>100 or v.id:find("[%c]") or
     type(v.chroma)~="boolean" then return false end
  seen[v.slot]=true
 end
 return n==#items
end
local function equalCandidate(a,b)
 return a and b and a.name==b.name and a.id==b.id and
     a.chroma==b.chroma and a.qty==b.qty
end
local function summary(status,reason,fields)
 local out={
  schema="gingerscope-system2-native-client-strategy-evidence-v1",
  status=status,reason=reason,
  clientObservedButUnauthenticated=true,
  decisionResearchOnly=true,
  marketPriceAuthenticated=false,
  acceptanceProbabilityMeasured=false,
  verifiedSellerWillingness=false,
  serverSettlementProven=false,
  realDiscordV2Delivered=false,
  realLearnerUpdated=false,
  liveRankedTradeAuthorized=false,
  mayUseForStrategyLearning=false,
  authorizesOffer=false,authorizesTrade=false,authorizesAccept=false,
  mayReportProfit=false,maySendDiscordWebhook=false,
  tradeOutcome="UNKNOWN",
 }
 for k,v in pairs(fields or {}) do out[k]=v end
 return out
end
local function blocked(reason)
 return summary("BLOCKED",reason)
end
function M.review(kind,ours,first,revised)
 if not KINDS[kind] or not verifiedShape(ours) or
    not verifiedShape(first) or
    (revised~=nil and not verifiedShape(revised)) then
  return blocked("MALFORMED_SOURCE_BOUND_CLIENT_CANDIDATES") end
 for _,v in ipairs(ours) do
  if protect(v.name) or protect(v.id) then
   return blocked("PROTECTED_GINGERSCOPE_NEVER_OUTBOUND")
  end
 end
 if #first~=1 or #ours>4 then return blocked("UNSUPPORTED_CLIENT_SLOT_LAYOUT")end
 if kind=="EVENT_PROVENANCE" then
  if #ours~=0 or revised~=nil then return blocked("EVENT_BASELINE_INVALID")end
  return summary("CLIENT_RESEARCH_EVIDENCE", "LIVE_EVENT_ENVELOPE_LOCAL_ONLY",{
   localEventKind="CLIENT_ALT_OFFER_OBSERVED",
   clientEventCandidateCount=1,
   containsVerifiedTradeOutcome=false,
   readyForDiscordV2Transport=false,
   v2BotAcknowledgementProven=false,
   proposedTrainingLabel="UNKNOWN",
  })
 end
 if kind=="GROWTH_STRUCTURE" then
  if #ours~=2 or revised~=nil or equalCandidate(ours[1],ours[2]) then
   return blocked("STRUCTURAL_PATH_INPUTS_NOT_DISTINCT")end
  return summary("CLIENT_RESEARCH_EVIDENCE","MULTIPLE_STRUCTURAL_ROUTES_NO_MARKET_AUTHORITY",{
   distinctStructuralPathOptions=2,
   pathA={hypotheticalOwnPhysicalSlots=2,hypotheticalReceivedSlots=1,
          usesExistingOwnCopiesOnly=true},
   pathB={hypotheticalOwnPhysicalSlots=1,hypotheticalReceivedSlots=1,
          usesExistingOwnCopiesOnly=true},
   actualCounterpartyConsentObserved=false,
   futureSellerCounterpartiesInvented=false,
   independentResaleLiquidityMeasured=false,
   currentTargetGapCalculable=false,
   protectedTargetNeverOutgoing=true,
  })
 end
 if revised==nil or #revised~=1 or equalCandidate(first[1],revised[1]) then
  return blocked("UNCONFIRMED_DISTINCT_LIVE_REVISION")end
 local a,b=first[1],revised[1]
 local kindChange=(a.name~=b.name or a.id~=b.id) and
  "DIFFERENT_CLIENT_ITEM_CANDIDATE" or
  ((a.chroma~=b.chroma) and "CHROMA_VARIANT_CHANGED" or
    "STACK_QUANTITY_CHANGED")
 local common={
  observedDistinctClientOffers=2,
  clientRevisionKind=kindChange,
  firstResearchCandidateInvalidated=true,
  counterpartyPreferenceProven=false,
  previousProposalReevaluationRequired=true,
 }
 if kind=="BEHAVIOR_REVISION" then
  if #ours~=0 then return blocked("BEHAVIOR_NOT_PASSIVE")end
  common.clientResponseCategory="OFFER_REVISED"
  common.potentialNegotiationSignal="CHANGED_VISIBLE_PROPOSAL"
  common.greedyOrValueWatcherLabelInferred=false
  return summary("CLIENT_RESEARCH_EVIDENCE","COUNTERPARTY_RESEARCH_ATTENTION_RECONSIDERED",common)
 end
 if kind=="BILATERAL_ALTERNATIVES" then
  if #ours~=1 then return blocked("BILATERAL_MAIN_SIDE_NOT_BOUND")end
  common.bilateralClientAlternativeCount=2
  common.outgoingPhysicalSlots=1
  common.firstIncomingPhysicalSlots=1
  common.secondIncomingPhysicalSlots=1
  common.firstIncomingCopies=a.qty
  common.secondIncomingCopies=b.qty
  common.currentMarketSourceVerified=false
  common.profitBasedWinnerProven=false
  common.sellerAttractivenessProven=false
  common.recommendedOfferIndex=nil
  return summary("CLIENT_RESEARCH_EVIDENCE","BILATERAL_ALTERNATIVES_COMPARE_NO_PRICE_RANKING",common)
 end
 if kind=="INVALIDATE_STALE_RESEARCH" then
  if #ours~=0 then return blocked("INVALIDATION_TEST_MAIN_NOT_EMPTY")end
  common.mustStopCurrentResearchDecision=true
  common.noFurtherPhysicalActionAuthorized=true
  return summary("CLIENT_RESEARCH_EVIDENCE","REVISION_INVALIDATES_RESEARCH_DECISION",common)
 end
 return blocked("UNSUPPORTED_RESEARCH_SCENARIO")
end
return M
