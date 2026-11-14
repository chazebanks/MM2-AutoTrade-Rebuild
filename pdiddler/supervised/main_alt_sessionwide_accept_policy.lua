-- Project Gingerscope: consent scope for MULTIPLE consecutive MAIN <-> exact ALT
-- trades in ONE explicitly supervised original-MM2 job. No price-based trades.
-- SECURITY: this module ONLY gates research preconditions; it DOES NOT press
-- any Accept button, fire AcceptTrade, or authorize live action deployment.
-- Every new trade requires a fresh lease and two stable independent GUI captures.
-- A failed guard latches STOP and revokes all further trade/Accept activity.
local M={}
local SCHEMA="gingerscope-main-alt-sessionwide-accept-policy-v1"
local PLACE=142823291
local function finite(n)
 return type(n)=="number" and n==n and n~=-math.huge and n~=math.huge and n>=0
end
local function positiveInt(n)
 return finite(n) and n>0 and n==math.floor(n)
end
local function username(s)
 return type(s)=="string" and #s>=3 and #s<=32 and
     s:match("^[A-Za-z0-9_]+$")~=nil
end
local function key(k)
 return type(k)=="string" and #k>=1 and #k<=90 and
     k:match("^[A-Za-z0-9_]+$")~=nil
end
local function protected(k)
 return k:lower():find("gingerscope",1,true)~=nil
end
local function digestSide(entries,outbound)
 if type(entries)~="table" then return nil,"SLOT_COUNT_INVALID" end
 local count=0
 for index in pairs(entries) do
  count+=1
  if type(index)~="number" or index~=math.floor(index) or
     index<1 or index>4 or count>4 then
   return nil,"SLOT_INDEX_ARRAY_INVALID"
  end
 end
 if count~=#entries then return nil,"SPARSE_OR_EXTRA_SLOT_ENTRIES" end
 local seen,positions,parts={}, {}, {}
 for _,r in ipairs(entries) do
  if type(r)~="table" or not key(r.rawKey) or
     type(r.quantity)~="number" or r.quantity~=math.floor(r.quantity) or
     r.quantity<1 or r.quantity>10000 or
     type(r.slotIndex)~="number" or r.slotIndex~=math.floor(r.slotIndex) or
     r.slotIndex<1 or r.slotIndex>4 or
     r.category~="Weapons" or seen[r.rawKey] or
     positions[r.slotIndex] then return nil,"SLOT_IDENTITY_OR_QUANTITY_INVALID" end
  local propertyCount=0
  for field in pairs(r) do
   propertyCount+=1
   if field~="rawKey" and field~="quantity" and
       field~="slotIndex" and field~="category" then
    return nil,"SLOT_UNEXPECTED_METADATA"
   end
  end
  if propertyCount~=4 then return nil,"SLOT_FIELDS_INCOMPLETE" end
  if outbound and protected(r.rawKey) then return nil,"PROTECTED_GINGERSCOPE_OUTGOING" end
  seen[r.rawKey]=true;positions[r.slotIndex]=true
  parts[#parts+1]=tostring(r.slotIndex)..":"..r.rawKey..":"..tostring(r.quantity)
 end
 table.sort(parts)
 return table.concat(parts,"|"),nil
end
local function offerSignature(c)
 if type(c.ownOffer)~="table" or type(c.altOffer)~="table" then
  return nil,"BOTH_OFFER_SIDES_REQUIRED"
 end
 local own,oe=digestSide(c.ownOffer,true)
 if not own then return nil,oe end
 local alt,ae=digestSide(c.altOffer,false)
 if not alt then return nil,ae end
 if #c.ownOffer==0 and #c.altOffer==0 then return nil,"EMPTY_BILATERAL_TRADE" end
 if type(c.ownAccepted)~="boolean" or type(c.altAccepted)~="boolean" then
  return nil,"ACCEPT_STATE_AMBIGUOUS"
 end
 if c.ownAccepted then return nil,"MAIN_ALREADY_ACCEPTED_OR_STATE_STALE" end
 return own.."#"..alt.."#main0#alt"..(c.altAccepted and "1" or "0"),nil
end
function M.new(config)
 if type(config)~="table" or
   not positiveInt(config.mainUserId) or
   not positiveInt(config.altUserId) or
   config.mainUserId==config.altUserId or
   not username(config.mainName) or
   not username(config.altName) or
   config.mainName:lower()==config.altName:lower() or
   type(config.jobId)~="string" or #config.jobId<8 or #config.jobId>100 or
   not config.jobId:match("^[A-Za-z0-9_-]+$") or
   config.placeId~=PLACE or
   config.operatorScope~="ALL_MAIN_ALT_TRADES_IN_THIS_JOB" or
   config.enablePublicAccept~=false then
   return nil,"EXPLICIT_MAIN_ALT_SESSION_CONFIG_INVALID"
 end
 local s={phase="IDLE",fatalReason=nil,lease=nil,
          observedTransfers=0,checkedTradeEpochs=0,acceptAttempts=0}
 local self={}
 local function receipt(status,reason)
  return {
   schema=SCHEMA,status=status,reason=reason,phase=s.phase,
   operatorScope="ALL_MAIN_ALT_TRADES_IN_THIS_JOB",
   exactPairOnly=true,mayObserveFurtherMainAltTrades=(s.fatalReason==nil),
   checkedTradeEpochs=s.checkedTradeEpochs,
   clientWindowClosures=s.observedTransfers,
   actualAccepts=0,actualOffers=0,actualDeclines=0,
   tradeOutcome="UNKNOWN",serverCompletionProven=false,
   noClientTradeCanProveSettlement=true,
   noPublicPartnerAccepted=true,protectedOutgoingGingerscope=true,
   automaticAcceptDispatched=false,liveAcceptActionEnabled=false,
   actionAuthorized=false,mayUseForStrategyLearning=false,
   maySendDiscordWebhook=false,mayReportProfit=false,
   rawOwnedItemsExported=false,playerIdsExported=false,jobIdExported=false,
  }
 end
 local function stop(why)
  s.phase="STOPPED";s.fatalReason=s.fatalReason or why
  s.lease=nil
  return receipt("STOPPED",s.fatalReason)
 end
 local function context(c,requireVisible)
  if type(c)~="table" or c.placeId~=PLACE or
     c.jobId~=config.jobId or
     c.mainUserId~=config.mainUserId or
     c.mainName~=config.mainName or
     c.altUserId~=config.altUserId or
     c.altName~=config.altName or
     c.partnerUserId~=config.altUserId or
     c.partnerName~=config.altName or
     c.mainIsLocalPlayer~=true or c.altPlayerObjectExact~=true or
     c.mainPlayerObjectExact~=true or c.altPresent~=true or
     c.otherTradeControllerActive~=false or c.uiSafe~=true or
     c.tradingPaused~=false or c.tradeRootUnique~=true or
     not finite(c.now) or
     (requireVisible and (c.tradeVisible~=true or c.tradeRoot==nil)) then
   return false,"EXACT_PAIR_GAME_GUI_OR_OWNER_CONTEXT_INVALID"
  end
  return true,nil
 end
 function self.begin(c)
  if s.fatalReason then return receipt("STOPPED",s.fatalReason) end
  if s.phase~="IDLE" then return stop("OVERLAPPING_OR_REUSED_TRADE_LEASE") end
  local ok,why=context(c,true)
  if not ok then return stop(why) end
  s.checkedTradeEpochs+=1
  s.lease={root=c.tradeRoot,openedAt=c.now,lastAt=c.now,
           signature=nil,firstStableAt=nil,readySignature=nil}
  s.phase="OBSERVING"
  return receipt("OBSERVING","NEW_EXACT_ALT_TRADE_LOCAL_LEASE")
 end
 function self.observe(c)
  if s.fatalReason then return receipt("STOPPED",s.fatalReason) end
  if s.phase~="OBSERVING" and s.phase~="STABLE" then
   return stop("OBSERVATION_WITHOUT_ACTIVE_LEASE")
  end
  local ok,why=context(c,true)
  if not ok then return stop(why) end
  local l=s.lease
  if l.root~=c.tradeRoot or c.now<l.lastAt or
      c.now-l.openedAt>25 then return stop("TRADE_ROOT_CLOCK_OR_LEASE_CHANGED") end
  l.lastAt=c.now
  local signature,sigReason=offerSignature(c)
  if not signature then
   if sigReason=="EMPTY_BILATERAL_TRADE" and s.phase=="OBSERVING" then
    return receipt("OBSERVING","WAIT_FOR_NONEMPTY_OFFER")
   end
   return stop(sigReason)
  end
  if s.phase=="STABLE" then
   if signature~=l.readySignature then return stop("OFFER_CHANGED_AFTER_STABLE_BINDING") end
   return receipt("STABLE_RESEARCH_ONLY","RECHECKED_EXACT_ALT_OFFER_UNCHANGED")
  end
  if l.signature~=signature then
   l.signature=signature;l.firstStableAt=c.now
   return receipt("OBSERVING","NEW_OFFER_BASELINE_NEEDS_INDEPENDENT_RECHECK")
  end
  if c.now-l.firstStableAt<0.3 then
   return receipt("OBSERVING","WAIT_MINIMUM_STABILITY_INTERVAL")
  end
  if c.now-l.firstStableAt>5 then return stop("OFFER_RECHECK_STALE") end
  l.readySignature=signature
  s.phase="STABLE"
  return receipt("STABLE_RESEARCH_ONLY","PAIR_OFFER_AND_LOCAL_CLOCK_CROSSCHECKED")
 end
 -- Deliberately never authorizes or performs actual Accept in this research
 -- module. A separate later live action needs proven GUI/button/remote identity.
 function self.requestAccept(c)
  if s.fatalReason then return receipt("STOPPED",s.fatalReason) end
  if s.phase~="STABLE" then return stop("ACCEPT_REQUEST_BEFORE_STABLE_BINDING") end
  local r=self.observe(c)
  if r.status=="STOPPED" then return r end
  s.acceptAttempts+=1
  return receipt("HOLD_NATIVE_ACCEPT_MAPPING_REQUIRED",
                 "NO_VERIFIED_FINAL_ACCEPT_CONTROL_OR_SERVER_REVISION")
 end
 function self.tradeClosed(c)
  if s.fatalReason then return receipt("STOPPED",s.fatalReason) end
  if s.phase~="STABLE" or type(c)~="table" or
     c.tradeVisible~=false or c.tradeRoot~=s.lease.root or
     c.jobId~=config.jobId or c.mainUserId~=config.mainUserId or
     c.altUserId~=config.altUserId or not finite(c.now) or
     c.now<s.lease.lastAt or c.now-s.lease.openedAt>120 then
    return stop("UNVERIFIED_OR_UNEXPECTED_TRADE_CLOSURE")
  end
  s.observedTransfers+=1 -- CLIENT WINDOW closures ONLY, not game transfers!
  s.lease=nil;s.phase="IDLE"
  return receipt("READY_FOR_ANOTHER_MAIN_ALT_TRADE",
                 "PRIOR_TRADE_CLOSED_CLIENT_ONLY_NO_SETTLEMENT_PROOF")
 end
 function self.operatorStop()
  return stop("EXPLICIT_OPERATOR_STOP")
 end
 function self.status()
  if s.fatalReason then return receipt("STOPPED",s.fatalReason) end
  return receipt(s.phase,"NO_LIVE_ACCEPT_ACTION_ENABLED")
 end
 return self,nil
end
return M
