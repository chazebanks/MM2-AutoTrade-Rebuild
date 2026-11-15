-- Gingerscope S2.C9: strict ORIGINAL native P3/P4 client preflight.
-- READS ONLY original scanner/P4 GUI and C3->C4->C9 research. Does not create
-- a P3 lease, send requests, offer/accept/decline, chat, hop, or transmit.
-- All injected host callbacks/modules must be reviewed separately; their
-- origins are NOT independently authenticated by this gate.
local M={}
local SCHEMA="gingerscope-c9-client-readonly-native-preflight-v1"
local PLACE=142823291
local MAX_SOURCE_AGE=21600
local function int(n)
 return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge
    and n==math.floor(n)
end
local function denial(why,phase)
 return {schema=SCHEMA,status="BLOCKED",reason=why,phase=phase,
  clientOnly=true,readOnly=true,actualDeviceExternallyVerified=false,
  originalP3P4ServerLeaseProven=false,publisherAuthenticatedForLive=false,
  rawItemInstancesProven=false,serverSettlementProven=false,
  noTradeActionsInvokedByPreflight=true,
  liveLossBudgetApproved=false,mayUseForStrategyLearning=false,
  maySendDiscordWebhook=false,mayReportProfit=false,
  authorizesTrade=false,authorizesOffer=false,authorizesAccept=false,
  authorizesChat=false}
end
local function validBound(b)
 return type(b)=="table" and type(b.jobId)=="string" and
  #b.jobId>=8 and type(b.leaseId)=="string" and #b.leaseId>=8 and
  int(b.localUserId) and b.localUserId>0 and
  int(b.partnerUserId) and b.partnerUserId>0 and
  b.localUserId~=b.partnerUserId and b.root~=nil
end
local function failRead(reason)
 return type(reason)=="string" and reason:match("^[A-Z0-9_]+$")~=nil and
  #reason<=100 and reason or "ORIGINAL_COMPONENT_BLOCKED_OR_UNAVAILABLE"
end
function M.new(config)
 if type(config)~="table" or config.game==nil or
  config.players==nil or not validBound(config.scope) or
  type(config.isBoundSession)~="function" or
  type(config.scannerApi)~="table" or
  type(config.scannerApi.getOwnInventory)~="function" or
  type(config.sync)~="table" or type(config.crosswalk)~="table" or
  type(config.utcNow)~="function" or type(config.monoNow)~="function" or
  type(config.isoToEpoch)~="function" or
  not int(config.sourceRetrievedEpoch) or
  type(config.marketCore)~="table" or
  type(config.marketCore.new)~="function" or
  type(config.captureAdapter)~="table" or
  type(config.captureAdapter.new)~="function" or
  type(config.marketBridgeModule)~="table" or
  type(config.marketBridgeModule.new)~="function" or
  type(config.bilateralCore)~="table" or
  type(config.bilateralCore.compare)~="function" or
  type(config.bilateralBridgeModule)~="table" or
  type(config.bilateralBridgeModule.new)~="function" or
  type(config.growthFirstModule)~="table" or
  type(config.growthFirstModule.new)~="function" then
  return nil,"C9_REVIEWED_NATIVE_INPUTS_INCOMPLETE" end
 local scope=config.scope
 local obj={}
 local function liveBound()
  local g=config.game
  if g.PlaceId~=PLACE or tostring(g.JobId)~=scope.jobId then
   return false,"C9_ORIGINAL_MM2_PLACE_OR_JOB_CHANGED" end
  local players=config.players
  local localPlayer=players.LocalPlayer
  if not localPlayer or localPlayer.UserId~=scope.localUserId or
     localPlayer.Parent~=players then
   return false,"C9_LOCAL_ACCOUNT_UNBOUND" end
  local ok,p=pcall(function()
   return players:GetPlayerByUserId(scope.partnerUserId)
  end)
  if not ok or not p or p.UserId~=scope.partnerUserId or
    p.Parent~=players or p==localPlayer then
   return false,"C9_PROTECTED_PARTNER_NOT_PRESENT" end
  local pg=localPlayer:FindFirstChildOfClass("PlayerGui")
  if not pg then return false,"C9_LOCAL_PLAYERGUI_UNAVAILABLE" end
  local good,active=pcall(config.isBoundSession)
  if not good or active~=true then
   return false,"C9_REVIEWED_P3_P4_LEASE_INACTIVE" end
  return true,nil
 end
 local function sourceFresh()
  local market=config.crosswalk
  if market.schema~="gingerscope-system2-exact-market-gamekey-crosswalk-v1"
   or market.status~="EXACT_HISTORICAL_GAMEKEY_MARKET_CROSSWALK"
   or market.matchedHistoricalGameKeys~=189 or
   type(market.items)~="table" or #market.items~=189 or
   type(market.crosswalkRowsSha256)~="string" or
   #market.crosswalkRowsSha256~=64 or
   type(market.sourceRetrievedUtc)~="string" or
   market.mayUseForLiveOffer~=false or
   market.authorizesTrade~=false or
   market.authorizesAccept~=false then
   return false,"C9_SOURCE_DATA_CONTRACT_INVALID" end
  local okAt,at=pcall(config.utcNow)
  local okEpoch,epoch=pcall(config.isoToEpoch,market.sourceRetrievedUtc)
  local sourceEpoch=config.sourceRetrievedEpoch
  if not okEpoch or not int(epoch) or epoch~=sourceEpoch then
   return false,"C9_SOURCE_TIMESTAMP_NOT_BOUND_TO_MARKET" end
  if not okAt or not int(at) or
    at<1700000000 or at>=4102444800 or
    sourceEpoch<1700000000 or
    sourceEpoch>=4102444800 or
    at<sourceEpoch or at-sourceEpoch>MAX_SOURCE_AGE then
   return false,"C9_SOURCE_TOO_OLD_OR_CLOCK_INVALID" end
  return true,nil
 end
 function obj:run(options)
  if options~=nil and
   (type(options)~="table" or #options<2 or #options>12) then
   return denial("C9_TWO_TO_TWELVE_RESEARCH_OPTIONS_REQUIRED","INPUT") end
  local okScope,scopeWhy=liveBound()
  if not okScope then return denial(scopeWhy,"P3_P4") end
  local okSource,sourceWhy=sourceFresh()
  if not okSource then return denial(sourceWhy,"MARKET") end
  local success,bridge,why=pcall(config.marketBridgeModule.new,{
   core=config.marketCore,captureAdapter=config.captureAdapter,
   scope=scope,game=config.game,players=config.players,
   scannerApi=config.scannerApi,sync=config.sync,
   nameResolver=config.nameResolver,crosswalk=config.crosswalk,
   isBoundSession=config.isBoundSession,
   utcNow=config.utcNow,monoNow=config.monoNow,
   sourceRetrievedEpoch=config.sourceRetrievedEpoch})
  if not success or type(bridge)~="table" or
   type(bridge.refreshOwn)~="function" or
   type(bridge.researchContext)~="function" then
   return denial("C9_ORIGINAL_C3_MODULE_BINDING_FAILED","C3") end
  local refreshed,own=pcall(bridge.refreshOwn)
  if not refreshed or type(own)~="table" or
   own.status~="READONLY_OWN_MARKET_BOUND" or
   own.readOnly~=true or own.authorizesOffer~=false or
   own.authorizesAccept~=false then
   return denial("C9_"..failRead(type(own)=="table" and
      own.reason or nil),"C3_OWN_CENSUS") end
  local observed,context=pcall(bridge.researchContext)
  if not observed or type(context)~="table" or
   context.status~="LOCAL_READONLY_MARKET_OFFER_CONTEXT" or
   context.readOnly~=true or context.authorizesOffer~=false or
   context.authorizesAccept~=false or
   type(context.sessionScope)~="table" or
   context.sessionScope.jobId~=scope.jobId or
   context.sessionScope.leaseId~=scope.leaseId or
   context.sessionScope.partnerUserId~=scope.partnerUserId then
   return denial("C9_ORIGINAL_C3_GUI_OR_SESSION_NOT_BOUND","P4_GUI") end
  local offer=context.offer
  if type(offer)~="table" or offer.readOnly~=true or
   not int(offer.clientRevision) or offer.clientRevision<1 or
   type(offer.our)~="table" or type(offer.their)~="table" or
   not int(offer.our.physicalSlots) or
   not int(offer.their.physicalSlots) or
   offer.our.physicalSlots>4 or offer.their.physicalSlots>4 or
   type(offer.nameOnlyCatalogCandidateCount)~="number" or
   offer.nameOnlyCatalogCandidateCount<0 then
   return denial("C9_P4_FOUR_SLOT_GUI_NOT_PROVEN","P4_GUI") end
  if offer.nameOnlyCatalogCandidateCount>0 or
    offer.exactRawAttributesBothSidesObserved~=true then
   return denial("C9_OFFER_RAW_INSTANCE_IDENTITY_UNPROVEN","P4_GUI") end
  if not options then
   local okLast,whyLast=liveBound()
   local freshLast,whyFresh=sourceFresh()
   if not okLast then return denial(whyLast,"FINAL_SESSION") end
   if not freshLast then return denial(whyFresh,"FINAL_SOURCE") end
   return {schema=SCHEMA,
    status="C9_LOCAL_READONLY_INVENTORY_AND_GUI_OBSERVED",
    reason="NO_TRADE_OR_RESEARCH_OPTIONS_REQUESTED",
    clientOnly=true,readOnly=true,
    matchedEligibleKeys=own.matchedEligibleKeys,
    matchedEligibleCopies=own.matchedEligibleCopies,
    ourVisiblePhysicalSlots=offer.our.physicalSlots,
    theirVisiblePhysicalSlots=offer.their.physicalSlots,
    clientOfferRevision=offer.clientRevision,
    originalP3P4ServerLeaseProven=false,
    actualDeviceExternallyVerified=false,
    publisherAuthenticatedForLive=false,
    rawItemInstancesProven=false,serverSettlementProven=false,
    noTradeActionsInvokedByPreflight=true,
    liveLossBudgetApproved=false,mayUseForStrategyLearning=false,
    maySendDiscordWebhook=false,mayReportProfit=false,
    authorizesTrade=false,authorizesOffer=false,authorizesAccept=false,
    authorizesChat=false}
  end
  local bOk,bBridge=pcall(config.bilateralBridgeModule.new,{
   marketBridge=bridge,bilateralCore=config.bilateralCore,
   crosswalk=config.crosswalk})
  if not bOk or type(bBridge)~="table" or
   type(bBridge.compare)~="function" then
   return denial("C9_ORIGINAL_C4_MODULE_BINDING_FAILED","C4") end
  local gOk,growth=pcall(config.growthFirstModule.new,{
   marketBridge=bridge,bilateralBridge=bBridge,
   market=config.crosswalk})
  if not gOk or type(growth)~="table" or
    type(growth.preview)~="function" then
   return denial("C9_GROWTH_FIRST_STRATEGY_MODULE_UNAVAILABLE","C9") end
  local pOk,preview=pcall(growth.preview,growth,options)
  if not pOk or type(preview)~="table" or
   preview.status~="GROWTH_FIRST_LISTED_LOSS_RESEARCH_ONLY" or
   preview.readOnly~=true or preview.clientOnly~=true or
   preview.authorizesOffer~=false or preview.authorizesTrade~=false or
   preview.authorizesAccept~=false or preview.liveLossAuthorized~=false or
   preview.maySendDiscordWebhook~=false or
   preview.mayUseForStrategyLearning~=false or
   preview.verifiedLongTermGain~=false or
   preview.empiricalExitLiquidity~=nil then
   return denial("C9_NATIVE_STRATEGY_PREVIEW_NOT_PROVEN","C9") end
  local okFinal,whyFinal=liveBound()
  if not okFinal then return denial(whyFinal,"FINAL_SESSION") end
  local ageFinal,whyAgeFinal=sourceFresh()
  if not ageFinal then return denial(whyAgeFinal,"FINAL_SOURCE") end
  local finalOK,last=pcall(bridge.researchContext)
  if not finalOK or type(last)~="table" or
   last.status~="LOCAL_READONLY_MARKET_OFFER_CONTEXT" or
   last.clientOfferRevision~=context.clientOfferRevision or
   last.sessionScope==nil or
   last.sessionScope.jobId~=scope.jobId or
   last.sessionScope.leaseId~=scope.leaseId or
   last.sessionScope.partnerUserId~=scope.partnerUserId then
   return denial("C9_NATIVE_FINAL_GUI_OR_SESSION_CHANGED","FINAL_GUI") end
  -- The growth-first module already double-reconciles all original C3
  -- inventory and GUI contents internally. No raw holdings leave this gate.
  local out={}
  for _,v in ipairs(preview.alternatives) do
   out[#out+1]={index=v.index,class=v.class,
    listedValueLoss=v.listedValueLoss,
    researchOnly=true,tradeExecutable=false}
  end
  return {schema=SCHEMA,status="C9_LOCAL_READONLY_STRATEGY_RESEARCH_OBSERVED",
   reason="SOURCE_AND_P3_P4_CLIENT_ONLY_NOT_RELEASE_ATTESTED",
   reviewedOptionCount=#out,alternatives=out,
   researchAttentionOrder=preview.researchAttentionOrder,
   qualityImprovingLossHypotheses=preview.qualityImprovingLossHypotheses,
   clientOfferRevision=context.clientOfferRevision,
   clientOnly=true,readOnly=true,
   actualDeviceExternallyVerified=false,
   originalP3P4ServerLeaseProven=false,publisherAuthenticatedForLive=false,
   rawItemInstancesProven=false,serverSettlementProven=false,
   noTradeActionsInvokedByPreflight=true,
   liveLossBudgetApproved=false,mayUseForStrategyLearning=false,
   maySendDiscordWebhook=false,mayReportProfit=false,
   authorizesTrade=false,authorizesOffer=false,authorizesAccept=false,
   authorizesChat=false}
 end
 return obj,nil
end
return M
