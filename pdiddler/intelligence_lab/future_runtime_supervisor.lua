-- Pure OFFLINE MM2 runtime supervisor. NO Roblox calls and NO actual actions.
-- Intended as a future orchestration contract, not enabled in Part 3 or 4.
-- Every transition is a total-function safety decision: Unknown -> HOLD.
local M={}
local function uint(v,hi)
 return type(v)=="number" and v==math.floor(v) and v>=0 and v<=hi
end
local function nonempty(v)
 return type(v)=="string" and #v>=1 and #v<=160
end
local function copy(s)
 local t={}
 for k,v in pairs(s) do t[k]=v end
 return t
end
local function result(s,reason)
 s.reason=reason
 s.authorizesTrade=false
 s.authorizesAccept=false
 s.mayRecordCompletedTrade=false
 s.mayReportProfit=false
 s.serverCompletionProven=false
 s.tradeOutcome="UNKNOWN"
 s.canHopAsSuggestion=(s.phase=="HOP_ELIGIBLE" and s.inCombat==false)
 return s
end
local function reset(s,reason)
 local n={
  schema="gingerscope-offline-runtime-supervisor-v1",
  phase="WAIT_WORLD",epoch=s.epoch+1,jobId=nil,
  candidate=nil,tradeId=nil,offerRevision=0,
  uiFingerprint=nil,uiFirstAt=nil,scanCompleted=false,
  requestSince=nil,hopSince=nil,inCombat=nil,worldStable=false,
  lastAt=s.lastAt
 }
 return result(n,reason)
end
function M.new(now)
 if not uint(now,9007199254740991) then return nil,"INVALID_CLOCK" end
 return result({schema="gingerscope-offline-runtime-supervisor-v1",
  phase="WAIT_WORLD",epoch=0,jobId=nil,tradeId=nil,
  candidate=nil,offerRevision=0,
  uiFingerprint=nil,uiFirstAt=nil,scanCompleted=false,
  requestSince=nil,hopSince=nil,inCombat=nil,worldStable=false,
  lastAt=now},"STARTUP")
end
function M.step(previous,event,now)
 if type(previous)~="table" or previous.schema~="gingerscope-offline-runtime-supervisor-v1"
    or not uint(previous.epoch,2147483647) or type(event)~="table"
    or not uint(now,9007199254740991) or now<(previous.lastAt or math.huge) then
  return nil,"INVALID_STATE_EVENT_OR_NONMONOTONIC_CLOCK"
 end
 local s=copy(previous)
 s.lastAt=now
 local kind=event.kind
 if s.phase=="STOPPED" then
  return result(s,"STOPPED_REQUIRES_FRESH_BOOT")
 end
 -- All asynchronous event callbacks must be stamped with the current epoch.
 -- A late callback from a previous Roblox server/character cannot open trade.
 if not uint(event.epoch,2147483647) or event.epoch~=s.epoch then
  return result(s,"STALE_OR_MISSING_EVENT_EPOCH")
 end
 if kind=="WORLD_LOADING" or kind=="SERVER_CHANGED" then
  return reset(s,kind.."_INVALIDATES_PRIOR_SESSIONS")
 end
 if kind=="STOP" then
  s.phase="STOPPED"
  s.tradeId=nil
  s.hopSince=nil
  return result(s,"USER_STOPPED")
 end
 if kind=="COMBAT_STATE" then
  if type(event.inCombat)~="boolean" then
   return result(s,"COMBAT_STATUS_UNVERIFIED")
  end
  s.inCombat=event.inCombat
  if s.inCombat and (s.phase=="HOP_ELIGIBLE" or s.phase=="HOP_WAIT") then
   s.phase="HOP_WAIT"
   s.hopSince=now -- full cooldown after combat interrupts hopping
  end
  return result(s,"COMBAT_FLAG_UPDATED")
 end
 if kind=="WORLD_READY" then
  if s.phase~="WAIT_WORLD" or not nonempty(event.jobId) then
   return result(s,"WORLD_READY_IGNORED_WRONG_PHASE_OR_JOB")
  end
  s.phase="WAIT_UI_STABLE"
  s.jobId=event.jobId
  return result(s,"WORLD_READY_WAIT_FOR_UI")
 end
 if kind=="UI_SNAPSHOT" then
  if s.phase~="WAIT_UI_STABLE" then
   return result(s,"UI_SNAPSHOT_WRONG_PHASE")
  end
  if event.tradeUiReady~=true or not nonempty(event.fingerprint)
     or event.jobId~=s.jobId then
   s.uiFirstAt=nil
   s.uiFingerprint=nil
   return result(s,"UI_NOT_STABLE")
  end
  if event.fingerprint~=s.uiFingerprint or s.uiFirstAt==nil then
   s.uiFirstAt=now
   s.uiFingerprint=event.fingerprint
   return result(s,"UI_STABILITY_TIMER_STARTED")
  end
  if now-s.uiFirstAt<1500 then return result(s,"UI_STABILITY_WAIT")end
  s.phase="SCANNING"
  s.worldStable=true
  return result(s,"UI_STABLE_ENABLE_READONLY_SCAN")
 end
 if kind=="UI_LOST" then
  if not nonempty(s.jobId) then
   return result(s,"UI_LOSS_IGNORED_BEFORE_WORLD_READY")
  end
  s.phase="WAIT_UI_STABLE"
  s.uiFirstAt=nil
  s.uiFingerprint=nil
  s.worldStable=false
  s.scanCompleted=false
  s.candidate=nil
  s.tradeId=nil
  s.hopSince=nil
  return result(s,"UI_LOST_INVALIDATES_CURRENT_REQUEST_AND_TRADE")
 end
 if kind=="SCAN_FINISHED" then
  if s.phase~="SCANNING" or event.verified~=true then
   return result(s,"SCAN_NOT_VERIFIED")
  end
  s.phase="READY"
  s.scanCompleted=true
  return result(s,"READONLY_SCAN_READY")
 end
 if kind=="TARGET_REVIEW" then
  if s.phase~="READY" or not nonempty(event.partnerKey)
     or event.jobId~=s.jobId then
   return result(s,"TARGET_REVIEW_NOT_READY_OR_UNBOUND")
  end
  s.candidate=event.partnerKey
  s.phase="TARGET_REVIEW"
  return result(s,"TARGET_RESEARCH_ONLY_NO_REQUEST_ACTION")
 end
 if kind=="REQUEST_OBSERVED" then
  if s.phase~="TARGET_REVIEW" or s.candidate~=event.partnerKey
     or event.jobId~=s.jobId then
   return result(s,"REQUEST_UNMATCHED_OR_UNOBSERVED")
  end
  s.phase="REQUEST_PENDING"
  s.requestSince=now
  return result(s,"EXTERNAL_REQUEST_OBSERVED_NO_ACTION")
 end
 if kind=="REQUEST_EXPIRED" then
  if s.phase~="REQUEST_PENDING" or not uint(event.timeoutMs,120000)
     or not s.requestSince or now-s.requestSince<event.timeoutMs then
   return result(s,"REQUEST_TIMEOUT_UNVERIFIED")
  end
  s.phase="READY"
  s.candidate=nil
  s.requestSince=nil
  return result(s,"REQUEST_EXPIRED_READY_TO_RESUME")
 end
 if kind=="TRADE_OPEN" then
  if s.phase~="REQUEST_PENDING" or not nonempty(event.tradeId)
    or event.jobId~=s.jobId or event.partnerKey~=s.candidate
    or event.exactPartnerVerified~=true then
   return result(s,"TRADE_OPEN_UNBOUND_OR_UNKNOWN_PARTNER")
  end
  s.phase="IN_TRADE"
  s.tradeId=event.tradeId
  s.offerRevision=0
  return result(s,"TRADE_OBSERVATION_ONLY")
 end
 if kind=="OFFER_CHANGED" then
  if s.phase~="IN_TRADE" or event.tradeId~=s.tradeId
     or not uint(event.newRevision,2147483647)
     or event.newRevision<=s.offerRevision then
   return result(s,"OFFER_REVISION_INVALID_OR_WRONG_SESSION")
  end
  s.offerRevision=event.newRevision
  return result(s,"ALL_PREVIOUS_TRADE_PLANS_INVALIDATED")
 end
 if kind=="TRADE_CLOSED" then
  if s.phase~="IN_TRADE" or event.tradeId~=s.tradeId then
   return result(s,"TRADE_CLOSE_NOT_BOUND_TO_ACTIVE_SESSION")
  end
  s.phase="OUTCOME_UNKNOWN"
  s.tradeId=nil
  s.candidate=nil
  return result(s,"CLIENT_WINDOW_CLOSED_NO_SERVER_RESULT_PROOF")
 end
 if kind=="CONTINUE_ROTATION" then
  if s.phase~="OUTCOME_UNKNOWN" then
   return result(s,"ROTATION_WAIT_FOR_UNVERIFIED_CLOSE")
  end
  s.phase="READY"
  return result(s,"RESUME_READONLY_TARGET_ROTATION")
 end
 if kind=="HOP_REVIEW" then
  if s.phase~="READY" or s.inCombat~=false
   or event.jobId~=s.jobId then
   return result(s,"HOP_BLOCKED_TRADE_COMBAT_OR_UNVERIFIED")
  end
  s.phase="HOP_WAIT"
  s.hopSince=now
  return result(s,"HOP_COUNTDOWN_RESEARCH_ONLY")
 end
 if kind=="HOP_TIMER_FINISHED" then
  if s.phase~="HOP_WAIT" or s.inCombat~=false
     or not s.hopSince or now-s.hopSince<30000 then
   return result(s,"HOP_TIMER_OR_COMBAT_BLOCKED")
  end
  s.phase="HOP_ELIGIBLE"
  return result(s,"HOP_CANDIDATE_ONLY_EXTERNAL_VERIFY_REQUIRED")
 end
 -- Including RESULT_VERIFIED: user/client assertions cannot authenticate settlement.
 return result(s,"UNSUPPORTED_EVENT_NO_AUTHORITY")
end
return M
