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
return M
