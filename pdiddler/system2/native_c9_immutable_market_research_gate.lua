-- C9 read-only MM2 public market SOURCE snapshot, immutable Git commit.
-- This is a research-candidate snapshot (not publisher-signed, not a real
-- server settlement), and EXPIRES six hours after its actual collection.
-- No P3/P4 remote, offer, Accept, chat, teleport or HTTP POST.
local M={}
local SNAPSHOT_COMMIT="734a316ee8d1afa14da50216a3d38de1ddd8694c"
local BASE="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"..
 SNAPSHOT_COMMIT.."/pdiddler/system2/"
local SOURCE_URL=BASE.."c9_research_public_189_crosswalk.json"
local RECEIPT_URL=BASE.."c9_research_public_source_admission.json"
M.SNAPSHOT_COMMIT=SNAPSHOT_COMMIT
M.SOURCE_URL=SOURCE_URL
M.RECEIPT_URL=RECEIPT_URL
local function int(n)
 return type(n)=="number" and n==n and n==math.floor(n) and
  n~=-math.huge and n~=math.huge
end
local function denied(reason)
 return {schema="gingerscope-c9-immutable-source-open-v1",status="BLOCKED",
  reason=reason,readOnly=true,clientOnly=true,researchOnly=true,
  livePublisherAuthenticated=false,authorizesOffer=false,
  authorizesAccept=false,authorizesTrade=false,
  maySendDiscordWebhook=false,mayUseForStrategyLearning=false}
end
function M.new(deps)
 if type(deps)~="table" or type(deps.fetch)~="function" or
  type(deps.decode)~="function" or type(deps.isoToEpoch)~="function" or
  type(deps.utcNow)~="function" or
  type(deps.isBoundSession)~="function" then
  return nil,"C9_REVIEWED_SOURCE_DEPENDENCIES_MISSING" end
 local obj={}
 function obj:open()
  local bound,b=pcall(deps.isBoundSession)
  if not bound or b~=true then
   return nil,denied("C9_ORIGINAL_PROTECTED_LEASE_NOT_ACTIVE") end
  local okNow,now=pcall(deps.utcNow)
  if not okNow or not int(now) or now<1700000000 or
     now>=4102444800 then
   return nil,denied("C9_HOST_UTC_CLOCK_INVALID") end
  local ok1,s1=pcall(deps.fetch,SOURCE_URL)
  local ok2,s2=pcall(deps.fetch,RECEIPT_URL)
  if not ok1 or not ok2 or type(s1)~="string" or
    type(s2)~="string" or #s1<30000 or #s1>300000 or
    #s2<1000 or #s2>10000 then
   return nil,denied("C9_IMMUTABLE_RESEARCH_JSON_FETCH_FAILED") end
  local parse1,market=pcall(deps.decode,s1)
  local parse2,proof=pcall(deps.decode,s2)
  if not parse1 or not parse2 or type(market)~="table" or
   type(proof)~="table" then
   return nil,denied("C9_RESEARCH_JSON_UNPARSEABLE") end
  if market.schema~="gingerscope-system2-exact-market-gamekey-crosswalk-v1"
   or market.status~="EXACT_HISTORICAL_GAMEKEY_MARKET_CROSSWALK"
   or market.matchedHistoricalGameKeys~=189 or
   type(market.items)~="table" or #market.items~=189 or
   market.actualCurrentOwnedInventoryVerified~=false or
   market.actualGameIdentityRevalidatedNow~=false or
   market.marketDatasetNotSignedByPublisher~=true or
   market.mayUseForLiveOffer~=false or
   market.authorizesTrade~=false or
   market.authorizesAccept~=false or
   market.mayReportProfit~=false or
   market.mayUseForLearning~=false or
   type(market.historicalRegistryBlob)~="string" or
   market.historicalRegistryBlob~="40e2a0ff01b70b2d0181c62cae347a08da82bcb8" or
   type(market.crosswalkRowsSha256)~="string" or
   #market.crosswalkRowsSha256~=64 or
   type(market.categoryGameKeys)~="table" or
   market.categoryGameKeys.ancient~=15 or
   market.categoryGameKeys.godly~=128 or
   market.categoryGameKeys.chroma~=46 then
   return nil,denied("C9_ORIGINAL_189_SOURCE_CONTRACT_MISMATCH") end
  if proof.schema~="gingerscope-c9-current-189-research-source-admission-v1"
   or proof.status~="PUBLIC_C9_RESEARCH_SOURCE_ADMITTED_NOT_LIVE_AUTHORITY"
   or proof.matchedHistoricalGameKeys~=189 or
   proof.fourPageReadObserved~=true or proof.researchOnly~=true or
   proof.outgoingGingerscopeProtected~=true or
   proof.sourcePublisherSignatureVerified~=false or
   proof.providerMarketDataNotIndependent~=true or
   proof.rawGameItemInstanceIdentityVerified~=false or
   proof.completedTradeOrRetradabilityProven~=false or
   proof.authorizesTrade~=false or
   proof.authorizesOffer~=false or
   proof.authorizesAccept~=false or
   proof.mayUseForLiveOffer~=false or
   proof.mayReportProfit~=false or
   proof.mayUseForStrategyLearning~=false or
   proof.sourceCanBeReusedAfterSixHours~=false or
   proof.sourceRetrievedUtc~=market.sourceRetrievedUtc or
   proof.siteEditionDate~=market.marketEdition or
   proof.crosswalkRowsSha256~=market.crosswalkRowsSha256 or
   proof.historicalRegistryBlob~=market.historicalRegistryBlob or
   type(proof.tierSourcePageSha256)~="table" or
   type(market.sourcePageSha256)~="table" then
   return nil,denied("C9_RESEARCH_CROSSWALK_ADMISSION_MISMATCH") end
  for _,k in ipairs({"ancient","godly","chroma"}) do
   if type(proof.tierSourcePageSha256[k])~="string" or
      proof.tierSourcePageSha256[k]~=market.sourcePageSha256[k] or
      #proof.tierSourcePageSha256[k]~=64 then
    return nil,denied("C9_RESEARCH_PAGE_FINGERPRINT_MISMATCH") end
  end
  local seen,byKey={},{}
  local total=0
  for _,r in ipairs(market.items) do
   if type(r)~="table" or type(r.rawGameKeyCandidate)~="string" or
      not r.rawGameKeyCandidate:match("^[A-Za-z0-9_]+$") or
      seen[r.rawGameKeyCandidate] or
      type(r.expectedGameName)~="string" or
      type(r.marketSlug)~="string" or
      type(r.gameChroma)~="boolean" or
      type(r.gameRarity)~="string" or
      type(r.outgoingGingerscopeProtected)~="boolean" then
    return nil,denied("C9_MARKET_GAME_KEY_SET_INVALID") end
   seen[r.rawGameKeyCandidate]=true
   byKey[r.rawGameKeyCandidate]=r
   total+=1
   if r.rawGameKeyCandidate=="Gingerscope" then
    if r.outgoingGingerscopeProtected~=true or
       not int(r.mm2Listed) or r.mm2Listed<=0 then
     return nil,denied("C9_GINGERSCOPE_SOURCE_OR_PROTECTION_INVALID") end
   elseif r.outgoingGingerscopeProtected then
    return nil,denied("C9_FORGED_EXTRA_PROTECTED_GAME_KEY") end
  end
  if total~=189 or not seen.Gingerscope then
   return nil,denied("C9_ORIGINAL_189_KEY_COVERAGE_CHANGED") end
  local parsed,epoch=pcall(deps.isoToEpoch,market.sourceRetrievedUtc)
  if not parsed or not int(epoch) or epoch<1700000000 or
    epoch>now or now-epoch>21600 then
   return nil,denied("C9_REAL_PUBLIC_SOURCE_EXPIRED_OR_CLOCK_CHANGED") end
  local again,still=pcall(deps.isBoundSession)
  local lastOK,last=pcall(deps.utcNow)
  if not again or still~=true or not lastOK or
    not int(last) or last<now or last<epoch or
    last-epoch>21600 then
   return nil,denied("C9_PROTECTED_LEASE_OR_SOURCE_CHANGED_DURING_FETCH") end
  return {
   schema="gingerscope-c9-immutable-source-open-v1",
   status="PUBLIC_SOURCE_RESEARCH_ONLY_READY",
   market=market,sourceRetrievedEpoch=epoch,
   researchOnly=true,readOnly=true,clientOnly=true,
   livePublisherAuthenticated=false,
   mayUseForLiveOffer=false,authorizesTrade=false,
   authorizesOffer=false,authorizesAccept=false,
   mayUseForStrategyLearning=false,maySendDiscordWebhook=false
  },nil
 end
 return obj,nil
end
return M
