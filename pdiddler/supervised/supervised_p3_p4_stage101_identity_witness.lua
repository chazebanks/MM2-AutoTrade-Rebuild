-- Research-only bridge: ORIGINAL supervised read-only P3/P4 bound.capture
-- and raw ORIGINAL Stage9 physical GUI -> frozen Stage101 client matcher.
-- No game remotes, no Accept, no item offers, no price/strategy authority.
-- The Stage101 unique raw weapon keys remain *PRIVATE*, never emitted.
-- Client-only evidence: no server trade nonce or backend settlement proof.
local M={}
local function result(status,reason)
 return {
  schema="gingerscope-supervised-p3p4-stage101-identity-witness-v1",
  status=status,reason=reason,readOnly=true,clientOnly=true,
  p3P4LeaseChecked=false,physicalGuiCrossChecked=false,
  exactOneClientEventObserved=false,
  clientBothSidesCandidateConsistent=false,
  matchedOwnSlots=0,matchedTheirSlots=0,
  uniqueRawWeaponTypeCandidate=false,
  currentPricesVerified=false,marketValueAuthority=false,
  eventSessionAssociationProven=false,callbackCausalityProven=false,
  serverTradeRevisionProven=false,rawItemIdConfirmed=false,
  uniqueWeaponInstanceProven=false,authenticatedOwnedInventory=false,
  serverCompletionProven=false,authorizesTrade=false,
  authorizesOffer=false,authorizesAccept=false,
  mayRecordCompletedTrade=false,mayReportProfit=false,
  maySendDiscordWebhook=false,mayUseForStrategyLearning=false,
  tradeOutcome="UNKNOWN"
 }
end
local function norm(s)
 if type(s)~="string" or #s<1 or #s>128 or
   s:find("[%c]") then return nil end
 return s:lower():gsub("^%s+",""):gsub("%s+$",""):gsub("%s+"," ")
end
local function natural(x,lo,hi)
 return type(x)=="number" and x==math.floor(x)
   and x>=lo and x<=hi
end
local function same(a,b)
 return a.root==b.root and a.jobId==b.jobId
   and a.session==b.session and a.localPlayer==b.localPlayer
   and a.partnerPlayer==b.partnerPlayer
end
local function scopeOK(s)
 return type(s)=="table" and
   type(s.jobId)=="string" and #s.jobId>0 and
   type(s.session)=="string" and #s.session>0 and
   s.root~=nil and s.localPlayer~=nil and
   s.partnerPlayer~=nil and s.localPlayer~=s.partnerPlayer
end
-- Stage9 and original P4 TradeIO MUST independently observe each slot.
-- Do not turn the GUI's internal text into raw identity authority.
local function verifyPhysical(side,entries,parser)
 if type(side)~="table" or side.complete~=true or
    side.accepted~=false or type(side.slots)~="table" or
    type(entries)~="table" or
    #side.slots~=#entries or #entries>4 then return false end
 local observed={}
 for _,row in ipairs(entries) do
  if type(row)~="table" or not natural(row.physicalSlot,1,4)
    or observed[row.physicalSlot] or
    not natural(row.quantity,1,4) or
    not norm(row.displayCandidate) or
    type(row.chromaCandidate)~="boolean" or
    row.rawItemIdAuthenticated~=false then return false end
  observed[row.physicalSlot]=row
 end
 local seen={}
 for _,slot in ipairs(side.slots) do
  if type(slot)~="table" or not natural(slot.slot,1,4) or
    seen[slot.slot] or type(slot.chroma)~="boolean" or
    not norm(slot.label) then return false end
  seen[slot.slot]=true
  local row=observed[slot.slot]
  local okQty,qty=pcall(parser,slot.amountText)
  if not row or not okQty or qty~=row.quantity or
    slot.chroma~=row.chromaCandidate or
    norm(slot.label)~=norm(row.displayCandidate) then
   return false
  end
 end
 return true
end
function M.new(context,deps)
 if not scopeOK(context) or type(deps)~="table" or
   type(deps.getScope)~="function" or
   type(deps.getBound)~="function" or
   type(deps.captureStage9Raw)~="function" or
   type(deps.now)~="function" or
   type(deps.isLive)~="function" or
   type(deps.stage101)~="table" or
   type(deps.stage101.inspect)~="function" or
   type(deps.stage9)~="table" or
   type(deps.stage9.parseQuantity)~="function" or
   type(deps.catalogue)~="table" or
   type(deps.registry)~="table" then
  return nil,result("BLOCKED","IDENTITY_WITNESS_DEPENDENCIES_INVALID")
 end
 -- Freeze exact reference identities; no user-visible state can retarget ALT.
 local scope={
  jobId=context.jobId,session=context.session,root=context.root,
  localPlayer=context.localPlayer,partnerPlayer=context.partnerPlayer
 }
 local phase="NOT_STARTED"
 local before,receipt,after1=nil,nil,nil
 local callbackCount=0
 local last=result("WAITING","NOT_STARTED")
 local stopped=false
 local monitor={}
 local function fail(reason)
  phase="BLOCKED"
  before=nil;receipt=nil;after1=nil
  last=result("BLOCKED",reason)
  return last
 end
 local function current()
  if stopped or phase=="BLOCKED" or phase=="DONE" then
   return nil,"IDENTITY_WITNESS_NO_LONGER_LIVE"
  end
  local okLive,live=pcall(deps.isLive)
  local okScope,nowScope=pcall(deps.getScope)
  local okT,t=pcall(deps.now)
  if not okLive or live~=true or not okScope or
     not scopeOK(nowScope) or not same(scope,nowScope) or
     not okT or type(t)~="number" or t~=t or
     t==math.huge or t<0 then
   return nil,"P3_P4_CLIENT_LEASE_OR_CLOCK_CHANGED"
  end
  local okB,bound,meta=pcall(deps.getBound)
  if not okB or type(bound)~="table" or
     type(bound.capture)~="function" or
     type(meta)~="table" or
     meta.status~="P3_BOUND_CANDIDATE_READ_ONLY" or
     meta.authorizesOffer~=false or
     meta.authorizesAccept~=false then
   return nil,"PROTECTED_P3_P4_BOUND_LEASE_UNAVAILABLE"
  end
  local okC,snap=pcall(bound.capture)
  if not okC or type(snap)~="table" or
     snap.status~="CLIENT_UNPRICED_TWO_SIDED_SNAPSHOT" or
     snap.partnerExactClientBound~=true or
     snap.part3Paused~=true or
     snap.part4TradeVisible~=true or
     snap.authorizesOffer~=false or
     snap.authorizesAccept~=false or
     snap.rawItemIdsAuthenticated~=false or
     snap.serverCompletionProven~=false or
     snap.tradeOutcome~="UNKNOWN" or
     type(snap.ours)~="table" or
     type(snap.theirs)~="table" then
   return nil,"PROTECTED_P3_P4_SNAPSHOT_REJECTED"
  end
  local okG,raw=pcall(deps.captureStage9Raw)
  if not okG or type(raw)~="table" or
     raw.tradeOpen~=true or raw.contextOK~=true or
     raw.session~=scope.session or
     not verifyPhysical(raw.our,snap.ours,deps.stage9.parseQuantity) or
     not verifyPhysical(raw.their,snap.theirs,deps.stage9.parseQuantity) then
   return nil,"ORIGINAL_STAGE9_AND_PROTECTED_P4_GUI_DISAGREE"
  end
  return {
   at=t,jobId=scope.jobId,session=scope.session,
   root=scope.root,localPlayer=scope.localPlayer,
   partnerPlayer=scope.partnerPlayer,raw=raw
  },nil
 end
 local function guiSame(a,b)
  local r1,r2=a.raw,b.raw
  for _,side in ipairs({"our","their"}) do
   local x,y=r1[side].slots,r2[side].slots
   if #x~=#y then return false end
   for i=1,#x do
    for _,k in ipairs({"slot","label","amountText","chroma","rawId"}) do
     if x[i][k]~=y[i][k] then return false end
    end
   end
  end
  return true
 end
 function monitor.begin()
  if phase~="NOT_STARTED" then return fail("REPEAT_IDENTITY_BEGIN_REJECTED") end
  local v,why=current()
  if not v then return fail(why) end
  if #v.raw.our.slots~=0 or #v.raw.their.slots~=1 then
   return fail("REQUIRES_ONE_STABLE_ALT_SLOT_AND_EMPTY_MAIN_AT_START")
  end
  before=v
  phase="WAIT_EVENT"
  last=result("WAITING","ALT_BASELINE_OBSERVED_WAIT_MAIN_MANUAL_ADD")
  last.p3P4LeaseChecked=true
  last.physicalGuiCrossChecked=true
  return last
 end
 -- Call only from ONE exact UpdateTrade.OnClientEvent callback. Packed data
 -- is private and never copied to clipboard or exposed in status fields.
 function monitor.onClientEvent(packed)
  if phase~="WAIT_EVENT" or callbackCount~=0 then
   return fail("UNEXPECTED_OR_MULTIPLE_CLIENT_EVENT")
  end
  local v,why=current()
  if not v then return fail(why) end
  -- If physical GUI already changed before callback, packet causality is
  -- too weak to support even a temporal candidate claim.
  if not guiSame(before,v) then
   return fail("GUI_CHANGED_BEFORE_CURRENT_EVENT_WITNESS")
  end
  local at=v.at
  if at<=before.at or at-before.at>3 or
     type(packed)~="table" then
   return fail("EVENT_NOT_WITHIN_CURRENT_CLIENT_WINDOW")
  end
  callbackCount=1
  receipt={
   packed=packed,at=at,jobId=scope.jobId,
   session=scope.session,root=scope.root,
   localPlayer=scope.localPlayer,partnerPlayer=scope.partnerPlayer
  }
  phase="WAIT_AFTER_ONE"
  last=result("WAITING","ONE_CLIENT_EVENT_WAIT_STABLE_BOTH_SIDES_GUI")
  last.p3P4LeaseChecked=true
  last.physicalGuiCrossChecked=true
  last.exactOneClientEventObserved=true
  return last
 end
 function monitor.tick()
  if phase=="DONE" or phase=="BLOCKED" or stopped then
   return last
  end
  local v,why=current()
  if not v then return fail(why) end
  if phase=="NOT_STARTED" then return fail("BEGIN_REQUIRED_BEFORE_EVENTS") end
  if phase=="WAIT_EVENT" then
   if not guiSame(before,v) then
    return fail("GUI_CHANGED_BEFORE_CURRENT_EVENT_WITNESS")
   end
   if v.at-before.at>3 then return fail("EVENT_WINDOW_EXPIRED") end
   return last
  end
  if not receipt or v.at<receipt.at or v.at-receipt.at>3 then
   return fail("POST_EVENT_CLIENT_WINDOW_EXPIRED")
  end
  if phase=="WAIT_AFTER_ONE" then
   if guiSame(v,before) then return last end
   if #v.raw.our.slots<1 or #v.raw.their.slots<1 then
    return fail("BOTH_SIDES_NOT_VISIBLE_AFTER_CLIENT_EVENT")
   end
   after1=v;phase="WAIT_AFTER_TWO"
   return last
  end
  if phase~="WAIT_AFTER_TWO" then return fail("IDENTITY_WITNESS_PHASE_INVALID") end
  if v.at-after1.at<0.15 then return last end
  if v.at-after1.at>1 or not guiSame(after1,v) then
   return fail("TWO_GUI_AFTER_SAMPLES_NOT_STABLE")
  end
  if callbackCount~=1 then return fail("MULTIPLE_CLIENT_CALLBACKS") end
  local ok,r,private=pcall(deps.stage101.inspect,{
   scope=scope,eventCount=callbackCount,
   before=before,receipt=receipt,after1=after1,after2=v
  },deps.catalogue,deps.registry,deps.stage9)
  -- NEVER return/store/log the private raw-key map on this research bridge.
  before=nil;receipt=nil;after1=nil;private=nil
  phase="DONE"
  if not ok or type(r)~="table" or
     r.status~="CLIENT_MULTISLOT_RAW_KEY_CANDIDATES_MATCH_GUI_UNATTRIBUTED" or
     r.authorizesTrade~=false or r.authorizesAccept~=false or
     r.serverCompletionProven~=false or
     r.eventSessionAssociationProven~=false or
     r.rawItemIdConfirmed~=false or
     r.bothSidesReconciled~=true or
     not natural(r.ourMatchedSlotCount,1,4) or
     not natural(r.theirMatchedSlotCount,1,4) then
   last=result("INCONCLUSIVE","STAGE101_TWO_SIDED_CLIENT_MATCH_REJECTED")
   return last
  end
  last=result("CLIENT_BOTH_SIDES_RAW_KEY_CANDIDATES_UNATTRIBUTED",
   "ORIGINAL_PROTECTED_P3_P4_STAGE9_GUI_MATCHED_ONE_CLIENT_EVENT")
  last.p3P4LeaseChecked=true
  last.physicalGuiCrossChecked=true
  last.exactOneClientEventObserved=true
  last.clientBothSidesCandidateConsistent=true
  last.uniqueRawWeaponTypeCandidate=true
  last.matchedOwnSlots=r.ourMatchedSlotCount
  last.matchedTheirSlots=r.theirMatchedSlotCount
  return last
 end
 function monitor.status()
  return last
 end
 function monitor.stop()
  stopped=true
  before=nil;receipt=nil;after1=nil
  if phase~="DONE" then last=result("STOPPED","OPERATOR_OR_SESSION_STOPPED") end
  return last
 end
 return monitor,result("WAITING","READ_ONLY_MONITOR_CONSTRUCTED")
end
return M
