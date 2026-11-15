-- S2.C9 RESEARCH ONLY. Bind a CLIENT-ONLY C9 market observer to the
-- ORIGINAL P3 supervisor's already-armed and revocable P4 read facade.
-- This module cannot ARM, create a trade, send a request/offer, Accept,
-- Decline, chat, hop, price, report profit, or learn.
-- Intended to be instantiated WITHIN an independently reviewed original
-- Stage119-style host, never by a fabricated external P3 state.
local M={}
local localGeneration=0
local function natural(x)
 return type(x)=="number" and x==x and x==math.floor(x) and x>0
  and x<10^16
end
local function validScope(s)
 return type(s)=="table" and type(s.jobId)=="string" and
  #s.jobId>=8 and type(s.session)=="string" and
  type(s.root)~="nil" and type(s.localPlayer)~="nil" and
  type(s.partnerPlayer)~="nil"
end
local function checkedSnapshot(s)
 return type(s)=="table" and
  s.status=="CLIENT_UNPRICED_TWO_SIDED_SNAPSHOT" and
  s.partnerExactClientBound==true and
  s.part3Paused==true and s.part4TradeVisible==true and
  s.authorizesOffer==false and s.authorizesAccept==false and
  s.rawItemIdsAuthenticated==false and
  s.offerRevisionAuthenticated==false and
  s.pricesAuthenticated==false and
  s.requestOriginBound==false and
  s.serverCompletionProven==false and
  s.mayReportProfit==false and
  s.maySendDiscordWebhook==false and
  s.tradeOutcome=="UNKNOWN" and
  type(s.ours)=="table" and type(s.theirs)=="table" and
  type(s.physicalOwnSlots)=="number" and
  s.physicalOwnSlots==math.floor(s.physicalOwnSlots) and
  s.physicalOwnSlots>=0 and s.physicalOwnSlots<=4 and
  type(s.physicalTheirSlots)=="number" and
  s.physicalTheirSlots==math.floor(s.physicalTheirSlots) and
  s.physicalTheirSlots>=0 and s.physicalTheirSlots<=4
end
local function out(reason)
 return {schema="gingerscope-c9-original-p3-host-lease-v1",
  status="BLOCKED",reason=reason,clientOnly=true,readOnly=true,
  serverCompletionProven=false,
  authorizesTrade=false,authorizesOffer=false,authorizesAccept=false,
  mayReportProfit=false,maySendDiscordWebhook=false,
  mayUseForStrategyLearning=false}
end
function M.new(d)
 if type(d)~="table" or type(d.supervisor)~="table" or
  type(d.supervisor.currentBoundReadOnly)~="function" or
  type(d.supervisor.isP3Paused)~="function" or
  type(d.readOriginalHostBoundScope)~="function" or
  type(d.getJobId)~="function" or
  type(d.getP3Session)~="function" or
  type(d.isOriginalHostRunning)~="function" or
  type(d.io)~="table" or type(d.io.trade)~="function" or
  type(d.players)~="table" or
  type(d.players.GetPlayerByUserId)~="function" or
  d.game==nil or d.game.PlaceId~=142823291 then
  return nil,out("ORIGINAL_P3_SUPERVISOR_HOST_MISSING") end
 -- This is the ORIGINAL host's lexical boundScope, not a copy or
 -- externally guessed job/partner/lease. New trade binds a NEW table.
 local goodBound,bound=pcall(d.readOriginalHostBoundScope)
 local goodJob,job=pcall(d.getJobId)
 local goodEpoch,epoch=pcall(d.getP3Session)
 local goodRunning,running=pcall(d.isOriginalHostRunning)
 if not goodBound or not validScope(bound) or not goodJob or
    type(job)~="string" or job~=bound.jobId or
    d.game.JobId~=job or not goodEpoch or not natural(epoch) or
    bound.session~="p3stage119:"..tostring(epoch) or
    not goodRunning or running~=true then
  return nil,out("ORIGINAL_P3_HOST_SESSION_NOT_PROVEN") end
 local me,partner=bound.localPlayer,bound.partnerPlayer
 if not natural(me.UserId) or not natural(partner.UserId) or
   me.UserId==partner.UserId or me.Parent~=d.players or
   partner.Parent~=d.players or d.players.LocalPlayer~=me then
  return nil,out("ORIGINAL_P3_HOST_PLAYER_IDENTITY_INVALID") end
 local goodP,livePartner=pcall(d.players.GetPlayerByUserId,
   d.players,partner.UserId)
 if not goodP or livePartner~=partner then
  return nil,out("ORIGINAL_P3_HOST_PARTNER_CHANGED") end
 local goodGui,gui=pcall(d.io.trade)
 local goodPaused,paused=pcall(d.supervisor.isP3Paused)
 if not goodGui or gui~=bound.root or
    not goodPaused or paused~=true then
  return nil,out("ORIGINAL_P3_HOST_TRADE_NOT_PAUSED") end
 local okLease,facade,info=pcall(d.supervisor.currentBoundReadOnly)
 if not okLease or type(facade)~="table" or
   type(facade.capture)~="function" or type(info)~="table" or
   info.status~="P3_BOUND_CANDIDATE_READ_ONLY" or
   info.authorizesOffer~=false or info.authorizesAccept~=false or
   info.serverCompletionProven~=false then
  return nil,out("ORIGINAL_P3_REVOCABLE_READ_LEASE_UNAVAILABLE") end
 local revoked=false
 local function isCurrent()
  if revoked then return false end
  local okB,current=pcall(d.readOriginalHostBoundScope)
  local okJ,newJob=pcall(d.getJobId)
  local okE,newEpoch=pcall(d.getP3Session)
  local okR,live=pcall(d.isOriginalHostRunning)
  local okG,root=pcall(d.io.trade)
  local okPaused,isPaused=pcall(d.supervisor.isP3Paused)
  local okPartner,newPartner=pcall(d.players.GetPlayerByUserId,
      d.players,partner.UserId)
  if not okB or current~=bound or not validScope(current) or
    not okJ or newJob~=job or d.game.JobId~=job or
    not okE or newEpoch~=epoch or
    current.jobId~=job or
    current.session~="p3stage119:"..tostring(epoch) or
    current.root~=bound.root or
    current.localPlayer~=me or current.partnerPlayer~=partner or
    not okR or live~=true or
    me.Parent~=d.players or partner.Parent~=d.players or
    d.players.LocalPlayer~=me or
    not okPartner or newPartner~=partner or
    not okG or root~=bound.root or
    not okPaused or isPaused~=true then
   revoked=true
   return false end
  -- Reuse the SAME original revocable facade: after new trade, it fails
  -- even if JobId, partner username, GUI root and P3 epoch are reused.
  local ok1,s1=pcall(facade.capture)
  local ok2,s2=pcall(facade.capture)
  if not ok1 or not ok2 or not checkedSnapshot(s1) or
   not checkedSnapshot(s2) or
   s1.physicalOwnSlots~=s2.physicalOwnSlots or
   s1.physicalTheirSlots~=s2.physicalTheirSlots then
   revoked=true
   return false end
  return true
 end
 if not isCurrent() then
  return nil,out("ORIGINAL_P3_LEASE_CAPTURE_NOT_CURRENT") end
 localGeneration+=1
 -- LOCAL uniqueness binds each C3 instance to a distinct facade even if
 -- the same original job/epoch/root returns in a later accepted request.
 -- This is NOT an authenticated server lease or cryptographic credential.
 local clientLease="p3c9_local_"..tostring(epoch).."_"..tostring(localGeneration)
 local scope={jobId=job,leaseId=clientLease,
  localUserId=me.UserId,partnerUserId=partner.UserId,root=bound.root}
 local result={
  readOnly=true,clientOnly=true,
  authorizesTrade=false,authorizesOffer=false,authorizesAccept=false,
  -- Private in-process ONLY; NEVER serialize scope, captured lease or
  -- original inventory to public logs, Discord, GitHub or webhooks.
  scope=scope,
  isBoundSession=function()return isCurrent()end,
  status=function()
   local live=isCurrent()
   return {schema="gingerscope-c9-original-p3-host-lease-v1",
    status=live and "ORIGINAL_P3_CLIENT_LEASE_READONLY_BOUND"
     or "BLOCKED",reason=live and "CLIENT_ONLY_NOT_SERVER_ATTESTED"
     or "ORIGINAL_P3_READ_LEASE_PERMANENTLY_REVOKED",
    clientOnly=true,readOnly=true,
    originalP3P4ServerLeaseProven=false,serverCompletionProven=false,
    authorizesTrade=false,authorizesOffer=false,authorizesAccept=false,
    mayUseForStrategyLearning=false,mayReportProfit=false,
    maySendDiscordWebhook=false}
  end,
 }
 return result,nil
end
return M
