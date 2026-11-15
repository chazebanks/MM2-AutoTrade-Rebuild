-- Component 5 live-source-adjacent read-only integration.
-- Invokes C3 original own scanner/offer revision then C4 bilateral price oracle,
-- invokes bounded C5 planning, then re-reads C3 to discard stale research.
-- No trade, Accept, chat, Discord, session activation, hop or web requests.
local M={}
local SCHEMA="gingerscope-system2-multistep-source-growth-shadow-v1"
local function stop(reason)
 return {schema=SCHEMA,status="BLOCKED",reason=reason,
   selectedResearchRouteIndex=nil,selectedRouteActionable=false,
   readOnly=true,clientOnly=true,originalMM2LivePass=false,
   authorizesTrade=false,authorizesOffer=false,authorizesAccept=false,
   mayReportProfit=false,maySendDiscordWebhook=false,
   mayUseForStrategyLearning=false}
end
local function sameCounts(a,b)
 if type(a)~="table" or type(b)~="table" then return false end
 for k,q in pairs(a) do if b[k]~=q then return false end end
 for k,q in pairs(b) do if a[k]~=q then return false end end
 return true
end
-- The original C3 refreshOwn() resets clientOfferRevision to zero.
-- Compare the actual bilateral offer as well as source, revision, and holdings:
-- a partner's x1 -> x2 offer can otherwise retain the same revision after
-- the refresh and leave the whole bounded route based on obsolete items.
local function sameOfferSide(a,b)
 if type(a)~="table" or type(b)~="table" or
    type(a.items)~="table" or type(b.items)~="table" or
    #a.items~=#b.items or
    a.physicalSlots~=b.physicalSlots or
    a.mm2Listed~=b.mm2Listed or
    a.supremeListed~=b.supremeListed or
    a.clientNameOnlyCandidates~=b.clientNameOnlyCandidates or
    a.allRawAttributesObserved~=b.allRawAttributesObserved then
  return false
 end
 for i,x in ipairs(a.items) do
  local y=b.items[i]
  if type(x)~="table" or type(y)~="table" or
     x.slot~=y.slot or x.id~=y.id or
     x.quantity~=y.quantity or
     x.clientIdentityEvidence~=y.clientIdentityEvidence then
   return false
  end
 end
 return true
end
local function sameOffer(a,b)
 return type(a)=="table" and type(b)=="table" and
    a.status==b.status and a.clientRevision==b.clientRevision and
    a.ourAccepted==b.ourAccepted and
    a.theirAccepted==b.theirAccepted and
    a.mm2ListedDelta==b.mm2ListedDelta and
    a.supremeListedDelta==b.supremeListedDelta and
    a.nameOnlyCatalogCandidateCount==b.nameOnlyCatalogCandidateCount and
    a.exactRawAttributesBothSidesObserved==b.exactRawAttributesBothSidesObserved and
    sameOfferSide(a.our,b.our) and sameOfferSide(a.their,b.their)
end
function M.new(config)
 if type(config)~="table" or type(config.marketBridge)~="table" or
    type(config.marketBridge.researchContext)~="function" or
    type(config.growthCore)~="table" or
    type(config.growthCore.search)~="function" or
    type(config.bilateralCore)~="table" or
    type(config.bilateralCore.compare)~="function" or
    type(config.crosswalk)~="table" or
    config.crosswalk.mayUseForLiveOffer~=false or
    config.crosswalk.authorizesTrade~=false then
  return nil,"GROWTH_RESEARCH_BRIDGE_DEPENDENCY_INVALID" end
 local bridge={}
 function bridge:discover(futureSellerStages)
  -- No supplied private account information outside this local process.
  local ok,first=pcall(config.marketBridge.researchContext)
  if not ok or type(first)~="table" or
    first.status~="LOCAL_READONLY_MARKET_OFFER_CONTEXT" then
   return stop("FRESH_STARTING_ACCOUNT_AND_PARTNER_OFFER_NOT_OBSERVED") end
  local reportOK,report=pcall(config.growthCore.search,first,config.crosswalk,{
    kind="BOUNDED_RESEARCH_FUTURE_SELLER_ROUTE_SEARCH",
    futureSellerStages=futureSellerStages,
  },config.bilateralCore)
  if not reportOK or type(report)~="table" or
     report.schema~=SCHEMA or report.authorizesOffer~=false or
     report.authorizesTrade~=false or report.authorizesAccept~=false or
     report.originalMM2LivePass~=false then
   return stop("UNRECOGNIZED_OR_UNAUTHORIZED_GROWTH_RESULT") end
  local ok2,last=pcall(config.marketBridge.researchContext)
  if not ok2 or type(last)~="table" or
    last.status~="LOCAL_READONLY_MARKET_OFFER_CONTEXT" or
    last.sourceRetrievedUtc~=first.sourceRetrievedUtc or
    last.crosswalkRowsSha256~=first.crosswalkRowsSha256 or
    last.clientOfferRevision~=first.clientOfferRevision or
    not sameCounts(last.ownCounts,first.ownCounts) or
    not sameOffer(last.offer,first.offer) then
   return stop("OWN_INVENTORY_OFFER_OR_SOURCE_CHANGED_DURING_GROWTH_SEARCH") end
  if (type(report.clientOfferRevision)=="number" and
      report.clientOfferRevision~=first.clientOfferRevision) or
     (type(report.marketRowsSha256)=="string" and
      report.marketRowsSha256~=first.crosswalkRowsSha256) then
   return stop("GROWTH_RESULT_SOURCE_OR_REVISION_MISMATCH") end
  return report
 end
 return bridge,nil
end
return M
