-- Integration entrypoint for reviewed P3/P4 owner; no autonomous game actions.
-- Host supplies existing ScannerAPI return, exact P3/P4 bound session scope,
-- original current Database.Sync, and current source-mapped JSON.
-- This glue does not open a trade or create a new lease on its own.
local M={}
function M.new(config)
 if type(config)~="table" or type(config.core)~="table"
  or type(config.core.new)~="function" or type(config.captureAdapter)~="table"
  or type(config.captureAdapter.new)~="function"
  or type(config.scope)~="table" or config.game==nil
  or config.players==nil or type(config.sync)~="table"
  or type(config.scannerApi)~="table"
  or type(config.crosswalk)~="table"
  or type(config.isBoundSession)~="function"
  or type(config.utcNow)~="function"
  or type(config.monoNow)~="function"
  or type(config.sourceRetrievedEpoch)~="number" then
  return nil,"LIVE_BRIDGE_ORIGINAL_DEPENDENCY_MISSING" end
 local scope=config.scope
 local reader,why=config.captureAdapter.new({
  game=config.game,players=config.players,scope=scope,
  isBoundSession=config.isBoundSession})
 if not reader then return nil,why end
 local bound,err=config.core.new({
  scannerApi=config.scannerApi,
  sync=config.sync,
  crosswalk=config.crosswalk,
  captureOffer=reader.capture,
  utcNow=config.utcNow,
  monoNow=config.monoNow,
  sourceRetrievedEpoch=config.sourceRetrievedEpoch,
  jobId=scope.jobId,leaseId=scope.leaseId,
  partnerUserId=scope.partnerUserId,
 })
 if not bound then return nil,err end
 return {
  refreshOwn=function()return bound:refreshOwn()end,
  observeOffer=function()return bound:observe()end,
  readOnly=true,authorizesOffer=false,authorizesAccept=false,
 },nil
end
-- Immutable Git commit from a REAL successful four-page source refresh,
-- not an expired Stage83 listed-price snapshot nor a mutable latest branch.
-- An expired snapshot BLOCKS after 6h. Only a reviewed new immutable source
-- capture may replace this pin in a subsequent research revision.
M.SOURCE_COMMIT="fd823dd0f0036c02ba4632a4f0a879bd429cb4fc"
M.SOURCE_URL="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"..
 M.SOURCE_COMMIT.."/pdiddler/system2/research_market_crosswalk_current.json"
function M.newWithPinnedSource(config)
 if type(config)~="table" or config.game==nil then
  return nil,"PINNED_SOURCE_BRIDGE_CONFIG_INVALID" end
 local loader=config.sourceHttpGet
 local jsonDecode=config.jsonDecode
 local toEpoch=config.isoToEpoch
 if type(loader)~="function" then
  loader=function(url)return config.game:HttpGet(url)end
 end
 if type(jsonDecode)~="function" then
  local h=config.game:GetService("HttpService")
  if h then jsonDecode=function(s)return h:JSONDecode(s)end end
 end
 if type(toEpoch)~="function" then
  toEpoch=function(s)
   local date=DateTime.fromIsoDate(s)
   if date then return date.UnixTimestamp end
   return nil
  end
 end
 if type(loader)~="function" or type(jsonDecode)~="function" or
  type(toEpoch)~="function" then
  return nil,"PINNED_SOURCE_READER_DEPENDENCIES_INVALID" end
 local ok,bytes=pcall(loader,M.SOURCE_URL)
 if not ok or type(bytes)~="string" or #bytes<1000 or #bytes>300000 then
  return nil,"PINNED_PUBLIC_SOURCE_FETCH_FAILED" end
 local decoded,market=pcall(jsonDecode,bytes)
 if not decoded or type(market)~="table" then
  return nil,"PINNED_PUBLIC_SOURCE_JSON_INVALID" end
 local parsed,epoch=pcall(toEpoch,market.sourceRetrievedUtc)
 if not parsed or type(epoch)~="number" then
  return nil,"PINNED_PUBLIC_SOURCE_UTC_TIME_INVALID" end
 local dep={}
 for k,v in pairs(config) do dep[k]=v end
 dep.crosswalk=market
 dep.sourceRetrievedEpoch=epoch
 return M.new(dep)
end
return M
