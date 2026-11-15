-- System2 C7: local-only conversion of reviewed P3/P4 client event receipts
-- into exactly the V2 envelope BODY consumed by the private Discord collector.
-- No Discord message, network sender, webhook, item names, chat or action.
-- Inject an independent, scrutinized cryptographic SHA256 implementation;
-- this research component does NOT attest that the injected function is secure.
local M={}
local SCHEMA="gingerscope-discord-bot-v2-client-event-envelope-v1"
local SOURCE="PRIVATE_BOT_CLIENT_EVENT_CLAIM_NOT_SERVER_SETTLEMENT"
local PROOF="BOUND_CLIENT_OBSERVATION_UNVERIFIED_SERVER"
local KINDS={
 MAIN_REQUEST_PENDING=true,PARTNER_REQUEST_ACCEPTED=true,
 PARTNER_OFFER_REVISION=true,MAIN_OFFER_REVISION=true,
 PARTNER_DECLINED=true,PARTNER_NO_RESPONSE_TIMEOUT=true,
 PARTNER_CANCELLED=true,MAIN_CANCELLED=true,
 PARTNER_ACCEPT_INDICATOR=true,MAIN_ACCEPT_INDICATOR=true,
 CLIENT_WINDOW_CLOSED_UNKNOWN=true,CLIENT_INVENTORY_DELTA_OBSERVED=true,
 CHAT_DIRECT_CLIENT_ATTRIBUTED=true,CHAT_AMBIGUOUS=true,
 CHAT_OTHER_CONVERSATION=true,
}
local CHATS={CHAT_DIRECT_CLIENT_ATTRIBUTED=true,CHAT_AMBIGUOUS=true,
 CHAT_OTHER_CONVERSATION=true}
local TERMINAL={PARTNER_DECLINED=true,PARTNER_NO_RESPONSE_TIMEOUT=true,
 PARTNER_CANCELLED=true,MAIN_CANCELLED=true,
 CLIENT_WINDOW_CLOSED_UNKNOWN=true}
local function blocked(why)
 return {status="BLOCKED",reason=why,clientOnly=true,readOnly=true,
  discordNetworkDeliveryVerified=false,serverCompletionProven=false,
  maySendDiscordWebhook=false,mayReportProfit=false,
  mayUseForStrategyLearning=false,authorizesOffer=false,
  authorizesTrade=false,authorizesAccept=false,authorizesChat=false}
end
local function integer(n)
 return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge
   and n==math.floor(n) and n>=0 and n<=1000
end
local function validStr(s,max)
 return type(s)=="string" and #s>=1 and #s<=max
end
local function digest(str)
 return type(str)=="string" and #str==64 and str:match("^[0-9a-f]+$")~=nil
end
function M.new(config)
 if type(config)~="table" or type(config.cryptoSha256)~="function" or
    type(config.readP3P4Lease)~="function" or
    type(config.bound)~="table" or not validStr(config.salt,128) or
    #config.salt<32 or not validStr(config.nonce,128) or #config.nonce<16
   then return nil,"V2_CRYPTO_AND_PROTECTED_LEASE_REQUIRED" end
 local b=config.bound
 if not validStr(b.jobId,100) or #b.jobId<8 or
    not validStr(b.leaseId,100) or #b.leaseId<8 or
    type(b.localUserId)~="number" or b.localUserId<1 or
    type(b.partnerUserId)~="number" or b.partnerUserId<1 or
    b.localUserId==b.partnerUserId or
    (b.scope~="MAIN_ALT_TEST" and b.scope~="PUBLIC_CLIENT_OBSERVATION")
   then return nil,"V2_BOUND_GAME_CLIENT_PARTNER_SCOPE_INVALID" end
 local stored,seq,revision,phase={},0,0,"NEW"
 local lastPartnerAcceptedAt=nil
 local function hash(label,value)
  local text=config.salt.."|"..tostring(#label)..":"..label..
      "|" ..tostring(#value)..":"..value
  local ok,h=pcall(config.cryptoSha256,text)
  if not ok or not digest(h) then return nil end
  return h
 end
 local job=hash("JOB",b.jobId)
 local session=hash("SESSION",b.jobId.."|"..b.leaseId.."|"..config.nonce)
 local partner=hash("PARTNER",tostring(b.partnerUserId))
 local lease=hash("LEASE",b.leaseId)
 if not job or not session or not partner or not lease or
    job==partner or job==session or partner==lease or
    session==lease then
  return nil,"V2_UNAUDITED_OR_COLLIDING_DIGEST_FUNCTION"
 end
 local obj={}
 local function current()
  local ok,w=pcall(config.readP3P4Lease)
  if not ok or type(w)~="table" or
    w.jobId~=b.jobId or w.leaseId~=b.leaseId or
    w.localUserId~=b.localUserId or
    w.partnerUserId~=b.partnerUserId or
    w.active~=true or w.clientOnly~=true then return false end
  return true
 end
 function obj.stage(kind,receipt)
  if phase=="TERMINAL" then return blocked("V2_CLIENT_EPISODE_TERMINAL") end
  if not current() then return blocked("V2_REVIEWED_LEASE_CHANGED") end
  if not KINDS[kind] or type(receipt)~="table" or
     receipt.kind~=kind or receipt.clientOnly~=true or
     receipt.observedByReviewedP3P4~=true or
     not integer(receipt.revision) or
     seq>=1000 then
    return blocked("V2_OBSERVATION_RECEIPT_NOT_PROVEN_SHAPE")
  end
  local nextRev=receipt.revision
  if seq==0 then
   if kind~="MAIN_REQUEST_PENDING" or nextRev~=0 or
      receipt.clientWitnessKind~="P3_REQUEST_SUBMITTED" then
    return blocked("V2_REQUEST_BASELINE_REQUIRED") end
  elseif kind=="PARTNER_OFFER_REVISION" or kind=="MAIN_OFFER_REVISION" then
   if phase~="IN_TRADE" or nextRev~=revision+1 or
      receipt.clientWitnessKind~="P4_OFFER_REVISION_OBSERVED" then
    return blocked("V2_OFFER_REVISION_WITNESS_REQUIRED") end
  elseif nextRev~=revision then return blocked("V2_STALE_OR_FUTURE_OFFER_REVISION")
  elseif kind=="PARTNER_REQUEST_ACCEPTED" then
   if phase~="PENDING" or
      receipt.clientWitnessKind~="P3_PARTNER_REQUEST_ACCEPTED" then
    return blocked("V2_PARTNER_REQUEST_ACCEPT_WITNESS_MISSING") end
  elseif kind=="PARTNER_DECLINED" or kind=="PARTNER_NO_RESPONSE_TIMEOUT" then
   if phase~="PENDING" or
      receipt.clientWitnessKind~="P3_REQUEST_RESOLUTION_OBSERVED" then
    return blocked("V2_PENDING_REQUEST_OUTCOME_UNPROVEN") end
  elseif kind=="PARTNER_CANCELLED" or kind=="MAIN_CANCELLED" or
       kind=="CLIENT_WINDOW_CLOSED_UNKNOWN" then
   if phase~="IN_TRADE" or
      receipt.clientWitnessKind~="P4_TRADE_WINDOW_OUTCOME_OBSERVED" then
    return blocked("V2_WINDOW_CLOSED_OR_CANCEL_WITNESS_MISSING") end
  elseif kind=="PARTNER_ACCEPT_INDICATOR" or
       kind=="MAIN_ACCEPT_INDICATOR" or
       kind=="CLIENT_INVENTORY_DELTA_OBSERVED" then
   if phase~="IN_TRADE" or
      receipt.clientWitnessKind~="P4_CLIENT_INDICATOR_OBSERVED" then
    return blocked("V2_CLIENT_INDICATOR_OUT_OF_PHASE") end
  elseif CHATS[kind] then
   if receipt.clientWitnessKind~="C6_PARTNER_CHAT_CLASSIFIED" or
      receipt.chatEvidenceClientOnly~=true then
    return blocked("V2_CHAT_EVIDENCE_PROVENANCE_MISSING") end
   if kind=="CHAT_DIRECT_CLIENT_ATTRIBUTED" and
      receipt.provenDirectedPartnerMessage~=true then
    return blocked("V2_TENTATIVE_CHAT_NOT_DIRECT") end
  else
   return blocked("V2_UNAUTHORIZED_KIND_OR_PHASE") end
  if not current() then return blocked("V2_LEASE_CHANGED_BEFORE_STAGING") end
  local nextSeq=seq+1
  local eventId=hash("EVENT",session.."|"..tostring(nextSeq).."|"..
       tostring(nextRev).."|"..kind)
  if not eventId then return blocked("V2_EVENT_DIGEST_UNVERIFIED") end
  local payload={
   schema=SCHEMA,source=SOURCE,scope=b.scope,event_id=eventId,
   job_digest=job,session_digest=session,partner_digest=partner,
   lease_digest=lease,event_seq=nextSeq,revision=nextRev,kind=kind,
   client_provenance=PROOF,
  }
  seq=nextSeq;revision=nextRev
  if kind=="MAIN_REQUEST_PENDING" then phase="PENDING"
  elseif kind=="PARTNER_REQUEST_ACCEPTED" then phase="IN_TRADE"
  elseif TERMINAL[kind] then phase="TERMINAL" end
  stored[#stored+1]=payload
  -- Only caller-local sanitized categorical V2 payloads.
  return {status="CLIENT_V2_ENVELOPE_STAGED_NOT_SENT",
   payload=payload,clientOnly=true,readOnly=true,
   discordNetworkDeliveryVerified=false,serverCompletionProven=false,
   maySendDiscordWebhook=false,mayUseForStrategyLearning=false,
   mayReportProfit=false,authorizesChat=false,authorizesOffer=false,
   authorizesTrade=false,authorizesAccept=false}
 end
 -- C8 private LOCAL-only Boolean comparison to original C3 sessionScope.
 -- No job/lease/account values or pseudo-digests leave the envelope instance.
 -- The returned bool is NOT remote attestation or backend settlement.
 function obj.matchesOriginalBoundScope(s)
  return type(s)=="table" and s.jobId==b.jobId and
   s.leaseId==b.leaseId and s.partnerUserId==b.partnerUserId and current()
 end
 function obj.summary()
  return {status="CLIENT_ONLY_STAGED_V2_NOT_DISCORD_DELIVERED",
    stagedCount=#stored,clientSessionPhase=phase,
    currentClientRevision=revision,readOnly=true,
    discordNetworkDeliveryVerified=false,
    actualPrivateCollectorAckVerified=false,
    serverCompletionProven=false,maySendDiscordWebhook=false,
    mayReportProfit=false,
    mayUseForStrategyLearning=false,authorizesOffer=false,
    authorizesTrade=false,authorizesAccept=false}
 end
 return obj,nil
end
return M
