-- C9 protected ORIGINAL P3/P4 host composition, RESEARCH ONLY.
-- Binds actual original C9 private host lease -> actual 4-page admitted
-- public market candidate -> original C3 scanner/P4 GUI -> original C4
-- bilateral evaluator -> C9 growth-first research preview.
-- C3 ScannerAPI.getOwnInventory may make a READ RPC GetProfileData;
-- only invoke after explicit operator consent to that specific read.
-- Never initiate a trade request, offer, Accept, Decline, chat, hop, or send.
local M={}
local SCHEMA="gingerscope-c9-original-host-market-composition-v1"
local function denial(why)
 return {schema=SCHEMA,status="BLOCKED",reason=why,
  readOnly=true,clientOnly=true,researchOnly=true,
  actualIpadRunVerified=false,rawWeaponInstanceProven=false,
  livePublisherAuthenticated=false,serverSettlementProven=false,
  realFutureBuyerValidated=false,liveLossBudgetApproved=false,
  authorizesTrade=false,authorizesOffer=false,
  authorizesAccept=false,authorizesChat=false,
  mayReportProfit=false,maySendDiscordWebhook=false,
  mayUseForStrategyLearning=false}
end
local function validBound(h)
 if type(h)~="table" or type(h.status)~="function" or
   type(h.isBoundSession)~="function" or
   type(h.scope)~="table" or
   type(h.scope.jobId)~="string" or
   type(h.scope.leaseId)~="string" or
   type(h.scope.partnerUserId)~="number" or
   type(h.scope.localUserId)~="number" or
   h.readOnly~=true or h.clientOnly~=true or
   h.authorizesOffer~=false or h.authorizesAccept~=false or
   h.authorizesTrade~=false then return false end
 return true
end
function M.new(c)
 if type(c)~="table" or not validBound(c.hostHandle) or
  c.consentedToReadOnlyInventoryRpc~=true or
  type(c.marketGate)~="table" or type(c.marketGate.new)~="function" or
  type(c.devicePreflight)~="table" or type(c.devicePreflight.new)~="function" or
  type(c.marketCore)~="table" or type(c.marketCore.new)~="function" or
  type(c.captureAdapter)~="table" or type(c.captureAdapter.new)~="function" or
  type(c.marketBridgeModule)~="table" or
  type(c.marketBridgeModule.new)~="function" or
  type(c.bilateralCore)~="table" or
  type(c.bilateralCore.compare)~="function" or
  type(c.bilateralBridgeModule)~="table" or
  type(c.bilateralBridgeModule.new)~="function" or
  type(c.growthFirstModule)~="table" or
  type(c.growthFirstModule.new)~="function" or
  type(c.scannerApi)~="table" or
  type(c.scannerApi.getOwnInventory)~="function" or
  type(c.sync)~="table" or
  type(c.sourceHttpGet)~="function" or
  type(c.jsonDecode)~="function" or
  type(c.utcNow)~="function" or
  type(c.monoNow)~="function" or
  type(c.isoToEpoch)~="function" or
  c.game==nil or c.players==nil then
  return nil,"C9_REVIEWED_ORIGINAL_HOST_COMPONENTS_OR_OPERATOR_CONSENT_MISSING"
 end
 local h=c.hostHandle
 local function lease()
  local ok,b=pcall(h.isBoundSession)
  if not ok or b~=true then return false end
  local good,receipt=pcall(h.status)
  return good and type(receipt)=="table" and
   receipt.schema=="gingerscope-c9-original-p3-host-lease-v1" and
   receipt.status=="ORIGINAL_P3_CLIENT_LEASE_READONLY_BOUND" and
   receipt.clientOnly==true and receipt.readOnly==true and
   receipt.authorizesTrade==false and receipt.authorizesOffer==false and
   receipt.authorizesAccept==false and
   receipt.serverCompletionProven==false
 end
 local obj={}
 function obj:run(options)
  if not lease() then return denial("C9_ORIGINAL_PROTECTED_HOST_LEASE_LOST") end
  local okGate,sourceGate=pcall(c.marketGate.new,{
    fetch=c.sourceHttpGet,decode=c.jsonDecode,
    utcNow=c.utcNow,isoToEpoch=c.isoToEpoch,isBoundSession=lease})
  if not okGate or type(sourceGate)~="table" or
    type(sourceGate.open)~="function" then
   return denial("C9_IMMUTABLE_MARKET_SOURCE_GATE_UNAVAILABLE") end
  local good,admitted,why=pcall(sourceGate.open,sourceGate)
  if not good or type(admitted)~="table" or
    admitted.status~="PUBLIC_SOURCE_RESEARCH_ONLY_READY" or
    admitted.readOnly~=true or admitted.clientOnly~=true or
    admitted.livePublisherAuthenticated~=false or
    admitted.authorizesOffer~=false or
    admitted.authorizesAccept~=false or
    admitted.authorizesTrade~=false or
    type(admitted.market)~="table" or
    type(admitted.sourceRetrievedEpoch)~="number" then
   return denial(type(why)=="table" and
    tostring(why.reason) or "C9_FRESH_PUBLIC_SOURCE_NOT_ADMITTED") end
  if not lease() then return denial("C9_ORIGINAL_LEASE_LOST_AFTER_SOURCE") end
  local okBuilder,preflight=pcall(c.devicePreflight.new,{
   game=c.game,players=c.players,
   scope=h.scope,isBoundSession=lease,
   scannerApi=c.scannerApi,sync=c.sync,
   crosswalk=admitted.market,
   utcNow=c.utcNow,monoNow=c.monoNow,
   isoToEpoch=c.isoToEpoch,
   sourceRetrievedEpoch=admitted.sourceRetrievedEpoch,
   nameResolver=c.nameResolver,
   marketCore=c.marketCore,
   captureAdapter=c.captureAdapter,
   marketBridgeModule=c.marketBridgeModule,
   bilateralCore=c.bilateralCore,
   bilateralBridgeModule=c.bilateralBridgeModule,
   growthFirstModule=c.growthFirstModule,
  })
  if not okBuilder or type(preflight)~="table" or
    type(preflight.run)~="function" then
   return denial("C9_ORIGINAL_C3_C4_GROWTH_PREFLIGHT_NOT_BOUND") end
  local performed,p=pcall(preflight.run,preflight,options)
  if not performed or type(p)~="table" or
   p.readOnly~=true or p.clientOnly~=true or
   p.authorizesOffer~=false or
   p.authorizesAccept~=false or
   p.authorizesTrade~=false or
   p.maySendDiscordWebhook~=false or
   p.mayUseForStrategyLearning~=false or
   p.serverSettlementProven~=false then
   return denial("C9_UNSAFE_ORIGINAL_NATIVE_PREFLIGHT_RESULT") end
  if not lease() then return denial("C9_ORIGINAL_LEASE_CHANGED_AFTER_PREFLIGHT") end
  if p.status~="C9_LOCAL_READONLY_INVENTORY_AND_GUI_OBSERVED" and
     p.status~="C9_LOCAL_READONLY_STRATEGY_RESEARCH_OBSERVED" then
   return denial(type(p.reason)=="string" and
    p.reason or "C9_NATIVE_PREFLIGHT_ABSTAINED") end
  return {schema=SCHEMA,status="C9_PROTECTED_READONLY_PREFLIGHT_OBSERVED",
   innerStatus=p.status,marketEdition=admitted.market.marketEdition,
   sourceAgeSeconds=math.max(0,c.utcNow()-admitted.sourceRetrievedEpoch),
   clientOfferRevision=p.clientOfferRevision,
   reviewedOptionCount=p.reviewedOptionCount,
   qualityImprovingLossHypotheses=p.qualityImprovingLossHypotheses,
   researchAttentionOrder=p.researchAttentionOrder,
   -- Sanitized: never export original lease, own inventory, partner,
   -- precise item instances, raw held weapons, chat or trade data.
   readOnly=true,clientOnly=true,researchOnly=true,
   actualIpadRunVerified=false,rawWeaponInstanceProven=false,
   livePublisherAuthenticated=false,serverSettlementProven=false,
   realFutureBuyerValidated=false,liveLossBudgetApproved=false,
   authorizesTrade=false,authorizesOffer=false,
   authorizesAccept=false,authorizesChat=false,
   mayReportProfit=false,maySendDiscordWebhook=false,
   mayUseForStrategyLearning=false}
 end
 return obj,nil
end
return M
