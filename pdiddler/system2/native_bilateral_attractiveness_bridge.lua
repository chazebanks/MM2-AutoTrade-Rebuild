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
  -- A C3 refreshOwn() resets the local offer revision. A changed inventory
  -- may therefore return the same revision number, silently reusing an old
  -- ranking unless both original scanner snapshots are compared.
  if not sameCounts(first.ownCounts,nextSnapshot.ownCounts) then
   return blocked("OWN_INVENTORY_CHANGED_DURING_STRATEGY_COMPARISON") end
  -- The same scanner census age bound is rechecked through the original bridge.
  -- Return the research output only; no command handler or offer-accept path.
  return result
 end
 return o,nil
end
return M
