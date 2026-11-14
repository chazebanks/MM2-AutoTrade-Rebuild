-- Main/ALT multi-trade supervised witness: consecutive manual final Accepts.
-- Research ONLY. No script Accept, OfferItem, decline, client-to-server mutating
-- RPC, hop, price quote, completed server trade inference or learning.
-- A safety failure permanently latches STOP for the WHOLE same-job session.
local M={}
local GAME=142823291
local MAX_RAW=4000
local MAX_COPIES=4000000
local function yesInt(x)
 return type(x)=="number" and x==x and x>0 and x<math.huge and x==math.floor(x)
end
local function clock(n)
 return type(n)=="number" and n==n and n>=0 and n<math.huge
end
local function safeName(s)
 return type(s)=="string" and #s>=3 and #s<=32 and s:match("^[%w_]+$")~=nil
end
local function raw(k)
 return type(k)=="string" and #k>0 and #k<=90 and k:match("^[%w_]+$")~=nil
end
local function profile(p,depth)
 if type(p)~="table" or depth>5 then return nil end
 if type(p.Weapons)=="table" and type(p.Weapons.Owned)=="table" then
  return p.Weapons.Owned
 end
 for _,k in ipairs({"ProfileData","Profile","PlayerData","Data","Inventory","FullInventory"}) do
  local r=profile(p[k],depth+1)
  if r then return r end
 end
 return nil
end
local function qty(x)
 if type(x)=="string" and #x<=7 and x:match("^%d+$") then x=tonumber(x) end
 if type(x)~="number" or x~=x or x<0 or x>1000000 or
    x~=math.floor(x) then return nil end
 return x
end
local function census(p)
 local tab=profile(p,0)
 if not tab then return nil,"PROFILE_OWNED_WEAPONS_MISSING" end
 local seen,n,total,copy={},{},0,0
 for k,v in pairs(tab) do
  total+=1
  if total>MAX_RAW then return nil,"PROFILE_RAW_KEY_LIMIT" end
  if not raw(k) then return nil,"PROFILE_RAW_KEY_INVALID" end
  local q=qty(v)
  if q==nil then return nil,"PROFILE_QUANTITY_INVALID" end
  copy+=q
  if copy>MAX_COPIES then return nil,"PROFILE_COPY_LIMIT" end
  if q>0 then seen[k]=q end
 end
 return seen,nil
end
local function slots(rows,outbound)
 if type(rows)~="table" then return nil,"SIDE_SLOTS_MISSING" end
 local n=0
 for k in pairs(rows) do
  n+=1
  if type(k)~="number" or k~=math.floor(k) or
     k<1 or k>4 or n>4 then return nil,"SIDE_NOT_FOUR_PHYSICAL_SLOTS" end
 end
 if n~=#rows then return nil,"SPARSE_SIDE_SLOT_ARRAY" end
 local seen,positions,parts={},{},{}
 for _,r in ipairs(rows) do
  if type(r)~="table" or not raw(r.key) or
     not yesInt(r.qty) or r.qty>10000 or
     not yesInt(r.slot) or r.slot>4 or
     r.category~="Weapons" or positions[r.slot] or seen[r.key] then
    return nil,"SIDE_RAW_KEY_QUANTITY_OR_SLOT_AMBIGUOUS"
  end
  local c=0
  for f in pairs(r) do
   c+=1
   if f~="key" and f~="qty" and f~="slot" and f~="category" then
    return nil,"SIDE_UNKNOWN_ATTRIBUTE"
   end
  end
  if c~=4 then return nil,"SIDE_REQUIRED_ATTRIBUTE_MISSING" end
  if outbound and r.key:lower():gsub("[^%w]",""):find("gingerscope",1,true) then
   return nil,"GINGERSCOPE_MUST_NEVER_BE_OUTGOING"
  end
  seen[r.key]=r.qty;positions[r.slot]=true
  parts[#parts+1]=r.slot..":"..#r.key..":"..r.key..":"..r.qty
 end
 table.sort(parts)
 return {count=n,items=seen,signature=table.concat(parts,"|")},nil
end
local function equalInventory(a,b)
 for k,v in pairs(a) do if b[k]~=v then return false end end
 for k,v in pairs(b) do if a[k]~=v then return false end end
 return true
end
local function compare(before,after,expected)
 local changes,positive,negative=0,0,0
 for key,post in pairs(after) do
  local prior=before[key] or 0
  if post~=prior then
   changes+=1
   if post<prior then negative+=1 else positive+=1 end
   if (expected[key] or 0)~=post-prior then return false,"DIFFERENT_ITEM_OR_QUANTITY_CHANGED" end
  end
 end
 for key,prior in pairs(before) do
  if after[key]==nil then
   changes+=1;negative+=1
   if (expected[key] or 0)~=-prior then
    return false,"ITEM_REMOVED_FROM_MAIN_DURING_INCOMING_TRADE"
   end
  end
 end
 if negative>0 then return false,"MAIN_INVENTORY_DECREASED" end
 local expectedCount=0
 for k,num in pairs(expected) do
  if not yesInt(num) or
    (after[k] or 0)-(before[k] or 0)~=num then
   return false,"EXPECTED_INCOMING_ITEM_MISSING_OR_WRONG_STACK"
  end
  expectedCount+=1
 end
 if positive~=expectedCount or changes~=expectedCount then
  return false,"UNRELATED_INVENTORY_CHANGE"
 end
 return true,"EXACT_EXPECTED_CLIENT_INVENTORY_DELTA"
end
function M.new(config)
 if type(config)~="table" or config.placeId~=GAME or
    not yesInt(config.mainUserId) or not yesInt(config.altUserId) or
    config.mainUserId==config.altUserId or
    not safeName(config.mainName) or not safeName(config.altName) or
    config.mainName:lower()==config.altName:lower() or
    type(config.jobId)~="string" or
    #config.jobId<8 or #config.jobId>100 or
    not config.jobId:match("^[%w_-]+$") or
    config.operatorScope~="ALL_MAIN_ALT_TRADES_IN_THIS_JOB" or
    config.publicTradingEnabled~=false or
    config.scriptMayFinalAccept~=false then
  return nil,"EXACT_ACCOUNT_SESSION_MANUAL_SCOPE_REQUIRED"
 end
 local s={phase="READY",failed=nil,clock=0,lease=nil,
    cycles=0,clientDeltas=0,manualAcceptObservations=0,reads=0}
 local self={}
 local function report(status,reason)
  return {
   schema="gingerscope-main-alt-manual-multitrade-delta-v1",
   status=status,reason=reason,phase=s.phase,readOnly=true,
   testType="MULTIPLE_CONSECUTIVE_MANUAL_TRADES",
   nextExactAltTradeAllowed=s.failed==nil and s.phase=="READY",
   tradeCyclesStarted=s.cycles,
   corroboratedClientDeltas=s.clientDeltas,
   observedManualAcceptTransitions=s.manualAcceptObservations,
   ownProfileReadAttempts=s.reads,
   allTradeControlErrorsFatal=true,
   exactAltUserIdRequired=true,
   fourPhysicalSlotsPerSide=true,stackedQuantitiesSupported=true,
   noPublicAccept=true,protectOutgoingGingerscope=true,
   actualScriptAccepts=0,actualScriptOffers=0,
   actualScriptDeclines=0,actualTeleports=0,
   confirmedNativeAcceptBinding=false,
   serverTradeRevisionProven=false,
   serverCompletionProven=false,
   tradeOutcome="UNKNOWN",mayReportProfit=false,
   maySendDiscordWebhook=false,mayUseForStrategyLearning=false,
   authorizesOffer=false,authorizesTrade=false,
   authorizesAccept=false,
   altAccountExported=false,itemKeysExported=false,
   ownedInventoryExported=false,jobIdExported=false,
  }
 end
 local function stop(why)
  s.phase="STOPPED";s.failed=s.failed or why;s.lease=nil
  return report("STOPPED",s.failed)
 end
 local function context(c,opened)
  if type(c)~="table" or c.placeId~=config.placeId or
    c.jobId~=config.jobId or c.mainUserId~=config.mainUserId or
    c.mainName~=config.mainName or c.altUserId~=config.altUserId or
    c.altName~=config.altName or c.partnerUserId~=config.altUserId or
    c.partnerName~=config.altName or
    c.exactPlayerObjects~=true or
    (c.tradeOpen==true and c.exactTradePartnerLabel~=true) or
    c.onlyTradeRoot~=true or c.uiSafe~=true or
    c.competingController~=false or not clock(c.now) or
    c.now<s.clock or
    (opened and (c.tradeOpen~=true or c.tradeRoot==nil)) then
   return false
  end
  s.clock=c.now
  return true
 end
 function self.begin(pre,c)
  if s.failed then return report("STOPPED",s.failed) end
  if s.phase~="READY" then return stop("TRADE_REENTRY_OR_OVERLAP") end
  if not context(c,false) or c.tradeOpen~=false then
   return stop("UNVERIFIED_BASELINE_ACCOUNT_SESSION_OR_TRADE_ACTIVE")
  end
  local p,why=census(pre)
  s.reads+=1
  if not p then return stop(why) end
  s.cycles+=1
  s.lease={
   startedAt=c.now,openedAt=nil,root=nil,lastAt=c.now,
   sawEmpty=false,signature=nil,stableAt=nil,
   expected=nil,old=p,acceptedSeen=false,
   postFirst=nil,postAt=nil,postStarted=nil,
  }
  s.phase="WAIT_OPEN"
  return report("WAIT_OPEN","NEW_TRADE_REQUIRES_FRESH_EMPTY_GUI_BASELINE")
 end
 function self.observe(c)
  if s.failed then return report("STOPPED",s.failed) end
  if s.phase=="READY" or s.phase=="VERIFY_DELTA" then
   return stop("WRONG_PHASE_OBSERVATION")
  end
  if not context(c,false) then return stop("PAIR_JOB_CONTROLLER_OR_CLOCK_CHANGED") end
  local l=s.lease
  if c.now-l.lastAt>15 then return stop("OBSERVATION_GAP_UNSAFE") end
  l.lastAt=c.now
  if s.phase=="WAIT_OPEN" then
   if c.tradeOpen~=true or c.tradeRoot==nil then
    if c.now-l.startedAt>45 then return stop("OPEN_TIMEOUT") end
    return report("WAIT_OPEN","NO_TRADE_YET")
   end
   l.root=c.tradeRoot;l.openedAt=c.now
   s.phase="WAIT_EMPTY"
  end
  if c.tradeOpen~=true or c.tradeRoot~=l.root then
   if s.phase=="WAIT_CLOSE" and c.tradeOpen==false then
    s.phase="VERIFY_DELTA";l.postStarted=c.now
    return report("VERIFY_DELTA","WINDOW_CLOSED_VERIFY_CLIENT_PROFILE_NO_SETTLEMENT_INFERENCE")
   end
   return stop("TRADE_ROOT_LOST_OR_UNEXPECTED_CLOSURE")
  end
  if c.now-l.openedAt>120 then return stop("TRADE_TIME_BUDGET_EXCEEDED") end
  local ours,oe=slots(c.ownOffer,true)
  local theirs,te=slots(c.altOffer,false)
  if not ours or not theirs then return stop(oe or te) end
  if ours.count~=0 then return stop("MAIN_OUTGOING_NOT_ALLOWED_IN_INCOMING_TEST") end
  if type(c.mainAccepted)~="boolean" or type(c.altAccepted)~="boolean" then
   return stop("ACCEPT_INDICATORS_UNKNOWN")
  end
  if s.phase=="WAIT_EMPTY" then
   if ours.count~=0 or theirs.count~=0 or c.mainAccepted or c.altAccepted then
    return stop("TRADE_OPENED_WITHOUT_EMPTY_CLIENT_BASELINE")
   end
   l.sawEmpty=true;s.phase="WAIT_ALT"
   return report("WAIT_ALT","ALT_MAY_NOW_ADD_INCOMING_ITEMS")
  end
  if s.phase=="WAIT_ALT" then
   if c.mainAccepted or c.altAccepted then return stop("PREMATURE_ACCEPT_STATE") end
   if theirs.count==0 then return report("WAIT_ALT","ALT_OFFER_STILL_EMPTY") end
   l.signature=theirs.signature;l.expected=theirs.items
   l.stableAt=c.now;s.phase="STABILIZING"
   return report("STABILIZING","NEW_INCOMING_OFFER_NEEDS_SECOND_CAPTURE")
  end
  if theirs.signature~=l.signature then return stop("OFFER_CHANGED_AFTER_FIRST_BINDING") end
  if s.phase=="STABILIZING" then
   if c.mainAccepted or c.altAccepted then return stop("ACCEPT_BEFORE_STABLE_OFFER") end
   if c.now-l.stableAt<0.4 then return report("STABILIZING","WAIT_STABLE_INTERVAL") end
   if c.now-l.stableAt>5 then return stop("OFFER_STABILITY_RECHECK_STALE") end
   s.phase="WAIT_MANUAL_ACCEPT"
   return report("WAIT_MANUAL_ACCEPT","OPERATOR_MAY_MANUALLY_ACCEPT_FINAL_WITH_BOTH_ACCOUNTS")
  end
  if s.phase=="WAIT_MANUAL_ACCEPT" or s.phase=="WAIT_CLOSE" then
   if s.phase=="WAIT_MANUAL_ACCEPT" and c.mainAccepted then
    return stop("ALT_ACCEPT_MUST_BE_OBSERVED_FIRST")
   end
   if s.phase=="WAIT_CLOSE" and c.mainAccepted and not c.altAccepted then
    return stop("ALT_ACCEPT_INDICATOR_REVERTED")
   end
   if c.mainAccepted or c.altAccepted then
    if not l.acceptedSeen then
     l.acceptedSeen=true;s.manualAcceptObservations+=1
    end
    s.phase="WAIT_CLOSE"
    return report("WAIT_CLOSE","HUMAN_ACCEPT_CLIENT_INDICATOR_OBSERVED")
   end
   if l.acceptedSeen then return stop("ACCEPTED_STATE_REVERTED_BEFORE_CLOSURE") end
   return report("WAIT_MANUAL_ACCEPT","WAITING_HUMAN_FINAL_ACCEPT")
  end
  return stop("UNKNOWN_TRADE_PHASE")
 end
 function self.post(readProfile,c)
  if s.failed then return report("STOPPED",s.failed) end
  if s.phase~="VERIFY_DELTA" then return stop("INVENTORY_READ_WITHOUT_TRADE_CLOSURE") end
  if not context(c,false) or c.tradeOpen~=false or
     c.now-s.lease.postStarted>18 then
   return stop("POST_TRADE_CONTEXT_INVALID_OR_TIMEOUT")
  end
  local p,why=census(readProfile)
  s.reads+=1
  if not p then return stop(why) end
  local l=s.lease
  local same,whyDiff=compare(l.old,p,l.expected)
  if not same then
   if equalInventory(l.old,p) then
    if c.now-l.postStarted<=12 then
     return report("VERIFY_DELTA","WAITING_CLIENT_INVENTORY_UPDATE_OR_MANUAL_CLAIM")
    end
    return stop("NO_CLIENT_INVENTORY_CHANGE_AFTER_WAIT")
   end
   return stop(whyDiff)
  end
  if not l.postFirst then
   l.postFirst=p;l.postAt=c.now
   return report("VERIFY_DELTA","FIRST_EXPECTED_CLIENT_DELTA_NEEDS_INDEPENDENT_RECHECK")
  end
  if c.now-l.postAt<0.3 then return report("VERIFY_DELTA","WAIT_SECOND_CLIENT_PROFILE_READ_INTERVAL") end
  if not equalInventory(l.postFirst,p) then
   return stop("POST_TRADE_PROFILE_CHANGED_DURING_CONFIRMATION")
  end
  s.clientDeltas+=1;s.lease=nil;s.phase="READY"
  return report("READY_FOR_NEXT_MAIN_ALT_TRADE",
   "TWO_MATCHED_CLIENT_PROFILE_DELTAS_ONLY_NOT_SERVER_SETTLEMENT")
 end
 function self.stop()
  return stop("OPERATOR_STOPPED")
 end
 function self.status()
  if s.failed then return report("STOPPED",s.failed) end
  return report(s.phase,"READ_ONLY_MULTI_TRADE_WITNESS_NO_AUTOMATIC_ACCEPT")
 end
 return self,nil
end
return M
