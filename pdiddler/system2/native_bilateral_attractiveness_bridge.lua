-- Component 4: tie strategic *research only* to component3's exact current
-- scanner/GUI source and refuse a decision after a changed offer revision.
local M={}
local SCHEMA="gingerscope-system2-bilateral-market-shadow-v1"
local function blocked(why)
 return {schema=SCHEMA,status="BLOCKED",reason=why,
  clientOnly=true,readOnly=true,selectedIndex=nil,
  empiricalPartnerAcceptanceProbability=nil,
  verifiedCounterpartyPreference=false,
  authorizesTrade=false,authorizesOffer=false,authorizesAccept=false,
  mayReportProfit=false,mayUseForStrategyLearning=false}
end
-- A local offer revision is not globally unique. When the original P3/P4
-- lease or partner changes, a newly mounted C3 scanner may start at the same
-- revision with identical inventory and GUI contents. Compare the *private*
-- constructor-bound session identity; never promote it to settlement proof.
local function validSessionScope(s)
 return type(s)=="table" and type(s.jobId)=="string" and
  #s.jobId>=8 and type(s.leaseId)=="string" and #s.leaseId>=8 and
  type(s.partnerUserId)=="number" and
  s.partnerUserId==math.floor(s.partnerUserId) and
  s.partnerUserId>0 and s.partnerUserId<10^16
end
local function sameSessionScope(a,b)
 return validSessionScope(a) and validSessionScope(b) and
  a.jobId==b.jobId and a.leaseId==b.leaseId and
  a.partnerUserId==b.partnerUserId
end
local function sameCounts(a,b)
 if type(a)~="table" or type(b)~="table" then return false end
 for k,n in pairs(a) do
  if type(k)~="string" or type(n)~="number" or b[k]~=n then
   return false
  end
 end
 for k,n in pairs(b) do
  if type(k)~="string" or type(n)~="number" or a[k]~=n then
   return false
  end
 end
 return true
end
-- A census refresh resets C3's local revision counter. Therefore even an
-- unchanged revision and unchanged ownership are insufficient if the OTHER
-- player's offered contents or either side's Accept state changed.
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
 if type(config)~="table" or type(config.marketBridge)~="table"
  or type(config.marketBridge.researchContext)~="function"
  or type(config.bilateralCore)~="table"
  or type(config.bilateralCore.compare)~="function"
  or type(config.crosswalk)~="table"
  or config.crosswalk.mayUseForLiveOffer~=false or
  config.crosswalk.authorizesTrade~=false or
  config.crosswalk.authorizesAccept~=false then
  return nil,"BILATERAL_NATIVE_CONNECTION_INVALID" end
 local o={}
 function o:compare(alternatives)
  local ok,first=pcall(config.marketBridge.researchContext)
  if not ok or type(first)~="table" or
      first.status~="LOCAL_READONLY_MARKET_OFFER_CONTEXT" then
   return blocked("FIRST_FRESH_MARKET_OFFER_CONTEXT_UNAVAILABLE") end
  local good,result=pcall(config.bilateralCore.compare,first,config.crosswalk,alternatives)
  if not good or type(result)~="table" or result.schema~=SCHEMA or
      result.authorizesTrade~=false or result.authorizesOffer~=false or
      result.authorizesAccept~=false then
   return blocked("CORE_RETURNED_NONRESEARCH_DECISION") end
  local ok2,nextSnapshot=pcall(config.marketBridge.researchContext)
  if not ok2 or type(nextSnapshot)~="table" or
      nextSnapshot.status~="LOCAL_READONLY_MARKET_OFFER_CONTEXT" or
      nextSnapshot.crosswalkRowsSha256~=first.crosswalkRowsSha256 or
      nextSnapshot.sourceRetrievedUtc~=first.sourceRetrievedUtc or
      nextSnapshot.clientOfferRevision~=first.clientOfferRevision then
   return blocked("OFFER_OR_SOURCE_CHANGED_DURING_STRATEGY_COMPARISON") end
  if not sameSessionScope(first.sessionScope,nextSnapshot.sessionScope) then
   return blocked("P3_P4_SESSION_BINDING_CHANGED_DURING_STRATEGY_COMPARISON") end
  -- A C3 refreshOwn() resets the local offer revision. A changed inventory
  -- may therefore return the same revision number, silently reusing an old
  -- ranking unless both original scanner snapshots are compared.
  if not sameCounts(first.ownCounts,nextSnapshot.ownCounts) then
   return blocked("OWN_INVENTORY_CHANGED_DURING_STRATEGY_COMPARISON") end
  if not sameOffer(first.offer,nextSnapshot.offer) then
   return blocked("OFFER_CONTENT_CHANGED_DURING_STRATEGY_COMPARISON") end
  -- The same scanner census age bound is rechecked through the original bridge.
  -- Return the research output only; no command handler or offer-accept path.
  return result
 end
 return o,nil
end
return M
