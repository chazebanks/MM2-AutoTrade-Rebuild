-- System2 C8: OFFLINE, read-only supervised replay of REAL source modules.
-- Dependencies must be instantiated original C3/P4, C4, C5, C6, C7 modules.
-- This module cannot open a trade, offer, chat, Accept, hop, learn or send.
-- It NEVER exposes private job/lease/partner, raw inventory or raw chat.
local M={}
local SCHEMA="gingerscope-system2-c8-original-replay-v1"
local function denied(why)
 return {schema=SCHEMA,status="BLOCKED",reason=why,
  readOnly=true,clientOnly=true,originalMM2LivePass=false,
  hasAuthenticatedGameSettlement=false,
  actualTradeOutcome="UNKNOWN",verifiedProfit=false,
  authorizedForUnattendedTrading=false,selectedRouteActionable=false,
  mayUseForStrategyLearning=false,maySendDiscordWebhook=false,
  mayReportProfit=false,authorizesChat=false,authorizesTrade=false,
  authorizesOffer=false,authorizesAccept=false}
end
local function scope(s)
 return type(s)=="table" and type(s.jobId)=="string" and #s.jobId>=8 and
  type(s.leaseId)=="string" and #s.leaseId>=8 and
  type(s.partnerUserId)=="number" and s.partnerUserId>0 and
  s.partnerUserId==math.floor(s.partnerUserId)
end
local function own(a,b)
 if type(a)~="table" or type(b)~="table" then return false end
 for k,n in pairs(a) do
  if type(k)~="string" or type(n)~="number" or b[k]~=n then return false end
 end
 for k,n in pairs(b) do
  if type(k)~="string" or type(n)~="number" or a[k]~=n then return false end
 end
 return true
end
local function side(a,b)
 if type(a)~="table" or type(b)~="table" or
  type(a.items)~="table" or type(b.items)~="table" or
  #a.items~=#b.items or a.physicalSlots~=b.physicalSlots or
  a.mm2Listed~=b.mm2Listed or a.supremeListed~=b.supremeListed or
  a.clientNameOnlyCandidates~=b.clientNameOnlyCandidates or
  a.allRawAttributesObserved~=b.allRawAttributesObserved then return false end
 for i,x in ipairs(a.items) do
  local y=b.items[i]
  if type(x)~="table" or type(y)~="table" or
   x.slot~=y.slot or x.id~=y.id or x.quantity~=y.quantity or
   x.clientIdentityEvidence~=y.clientIdentityEvidence then return false end
 end
 return true
end
local function same(a,b)
 if type(a)~="table" or type(b)~="table" or
  a.status~="LOCAL_READONLY_MARKET_OFFER_CONTEXT" or
  b.status~="LOCAL_READONLY_MARKET_OFFER_CONTEXT" or
  a.readOnly~=true or b.readOnly~=true or
  a.authorizesOffer~=false or b.authorizesOffer~=false or
  a.authorizesAccept~=false or b.authorizesAccept~=false or
  not scope(a.sessionScope) or not scope(b.sessionScope) or
  a.sessionScope.jobId~=b.sessionScope.jobId or
  a.sessionScope.leaseId~=b.sessionScope.leaseId or
  a.sessionScope.partnerUserId~=b.sessionScope.partnerUserId or
  a.crosswalkRowsSha256~=b.crosswalkRowsSha256 or
  a.sourceRetrievedUtc~=b.sourceRetrievedUtc or
  a.clientOfferRevision~=b.clientOfferRevision or
  not own(a.ownCounts,b.ownCounts) then return false end
 local x,y=a.offer,b.offer
 return type(x)=="table" and type(y)=="table" and
  x.status==y.status and x.clientRevision==y.clientRevision and
  x.ourAccepted==y.ourAccepted and
  x.theirAccepted==y.theirAccepted and
  x.mm2ListedDelta==y.mm2ListedDelta and
  x.supremeListedDelta==y.supremeListedDelta and
  x.nameOnlyCatalogCandidateCount==y.nameOnlyCatalogCandidateCount and
  x.exactRawAttributesBothSidesObserved==y.exactRawAttributesBothSidesObserved and
  side(x.our,y.our) and side(x.their,y.their)
end
local function safe(t,schema)
 return type(t)=="table" and t.schema==schema and
  t.readOnly==true and
  t.authorizesTrade==false and
  t.authorizesOffer==false and t.authorizesAccept==false and
  t.mayUseForStrategyLearning==false and
  t.mayReportProfit==false
end
function M.new(config)
 if type(config)~="table" or
  type(config.c3)~="table" or type(config.c3.researchContext)~="function" or
  type(config.c4)~="table" or type(config.c4.compare)~="function" or
  type(config.c5)~="table" or type(config.c5.discover)~="function" or
  type(config.c6)~="table" or type(config.c6.snapshot)~="function" or
  type(config.c7)~="table" or type(config.c7.summary)~="function" then
  return nil,"C8_ACTUAL_COMPONENT_DEPENDENCY_MISSING" end
 local gate={}
 function gate:replay(alternatives,futureSellerStages)
  if type(alternatives)~="table" or #alternatives<2 or
    #alternatives>12 or type(futureSellerStages)~="table" or
    #futureSellerStages<1 or #futureSellerStages>3 then
   return denied("C8_DISTINCT_ALTERNATIVES_AND_FUTURE_STAGES_REQUIRED") end
  local a,first=pcall(config.c3.researchContext)
  if not a or type(first)~="table" or
     not same(first,first) then
   return denied("C8_ORIGINAL_C3_STARTING_SCOPE_NOT_PROVEN") end
  local b,bi=pcall(config.c4.compare,config.c4,alternatives)
  if not b or not safe(bi,"gingerscope-system2-bilateral-market-shadow-v1")
     or bi.status~="ABSTAIN_PARTNER_INTENT_UNVERIFIED" then
   return denied("C8_ORIGINAL_C4_SCORER_FAILED_OR_FORGED") end
  local c,gr=pcall(config.c5.discover,config.c5,futureSellerStages)
  if not c or not safe(gr,"gingerscope-system2-multistep-source-growth-shadow-v1")
     or gr.status~="RESEARCH_GROWTH_ROUTE_DISCOVERY_ONLY" or
     gr.selectedRouteActionable~=false or
     gr.originalMM2LivePass~=false then
   return denied("C8_ORIGINAL_C5_GROWTH_NOT_RESEARCH_ONLY") end
  local d,ch=pcall(config.c6.snapshot)
  if not d or not safe(ch,"gingerscope-system2-partner-intent-readonly-v1")
    or ch.status~="CLIENT_ONLY_PASSIVE_PARTNER_PREFERENCE_RESEARCH" or
    ch.completedTradeProven~=false or
    ch.noRawChatExported~=true or
    ch.maySendDiscordWebhook~=false or ch.authorizesChat~=false then
   return denied("C8_ORIGINAL_C6_PASSIVE_SPEAKER_NOT_PROVEN") end
  local e,feedback=pcall(config.c7.summary)
  if not e or type(feedback)~="table" or
    feedback.status~="CLIENT_ONLY_STAGED_V2_NOT_DISCORD_DELIVERED" or
    feedback.readOnly~=true or
    feedback.discordNetworkDeliveryVerified~=false or
    feedback.serverCompletionProven~=false or
    feedback.mayUseForStrategyLearning~=false or
    feedback.authorizesTrade~=false or feedback.authorizesOffer~=false or
    feedback.authorizesAccept~=false then
   return denied("C8_ORIGINAL_C7_UNVERIFIED_TRANSPORT_OR_AUTHORITY") end
  local f,last=pcall(config.c3.researchContext)
  if not f or not same(first,last) then
   return denied("C8_ORIGINAL_SOURCE_SCOPE_OR_OFFER_CHANGED_DURING_REPLAY") end
  return {schema=SCHEMA,status="OFFLINE_C8_ORIGINAL_CHAIN_RESEARCH_ONLY",
   c3Origin="ORIGINAL_CLIENT_SCANNER_AND_P4_GUI_RESEARCH_ONLY",
   c4Status=bi.status,c5Status=gr.status,
   c6Status=ch.status,c7Status=feedback.status,
   c5HypotheticalRouteCount=type(gr.alternativeRoutes)=="table" and
    #gr.alternativeRoutes or 0,
   c6DirectedSignalCount=ch.explicitDirectedSignals,
   v2EventsStagedLocally=feedback.stagedCount,
   clientSessionBoundForEntireReplay=true,
   noRawIdentityItemsChatOrMarketAmountsExported=true,
   readOnly=true,clientOnly=true,originalMM2LivePass=false,
   hasAuthenticatedGameSettlement=false,actualTradeOutcome="UNKNOWN",
   verifiedProfit=false,authorizedForUnattendedTrading=false,
   selectedRouteActionable=false,mayUseForStrategyLearning=false,
   maySendDiscordWebhook=false,mayReportProfit=false,
   authorizesChat=false,authorizesTrade=false,authorizesOffer=false,
   authorizesAccept=false}
 end
 return gate,nil
end
return M
