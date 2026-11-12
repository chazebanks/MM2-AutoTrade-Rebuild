-- Candidate opt-in ABA guarded operator-selected 1..4 physical-slot executor.
-- Forked from exact original immutable plan. OFFLINE RESEARCH ONLY: never
-- replace an installed iPad/Delta loader until a separate live gate review.
-- The optional shadow lease can REVOKE a previously user-approved next item
-- after client-observed ALT A->B->A. The shadow NEVER AUTHORIZES offering.
-- Requires the existing PR199 P3->P4 bound session and PR195 protected TradeIO.
-- This is NOT an economic planner. Human must approve the exact keys in advance.
-- No price feed, inventory ownership proof, automatic Accept, negotiation, hop,
-- settlement, profit reporting, Discord or automatic contact requests.
local M={}
local spentBindings=setmetatable({},{__mode="k"})
-- All public error codes are static and anonymous; reject raw GUI strings.
local knownSnapshotReasons={
    HANDOFF_RELEASED=true,JOB_OR_EPOCH_CHANGED=true,
    PLAYER_GUI_CHANGED=true,PARTNER_LEFT_OR_REPLACED=true,
    PART3_CONTACT_NOT_ELIGIBLE=true,PART3_SCANNER_RECORD_CHANGED=true,
    PART3_NOT_PAUSED=true,MULTIPLE_VISIBLE_TRADE_ROOTS=true,
    NO_VISIBLE_TRADE=true,TRADE_ROOT_CHANGED=true,
    TRADE_PARTNER_WRONG_OR_AMBIGUOUS=true,ACCEPT_UNKNOWN=true,
    ACCEPT_ALREADY_SET=true,OFFER_SIGNATURE_MISSING=true,
    SIDE_CONTAINER_MISSING=true,UNREADABLE_SIDE=true,
    MORE_THAN_FOUR_PHYSICAL_SLOTS=true,
    PHYSICAL_GUI_SLOTS_NOT_RECONCILED=true,
    INVALID_GUI_SLOT_OR_STACK=true,
    VISIBLE_STACK_TEXT_INVALID=true,HIDDEN_STACK_TEXT_CONFLICT=true,
    PROTECTED_GINGERSCOPE_IN_OWN_OFFER=true,
    OFFER_CHANGED_DURING_CAPTURE=true,
}
local transientSnapshotReasons={
    PHYSICAL_GUI_SLOTS_NOT_RECONCILED=true,
    VISIBLE_STACK_TEXT_INVALID=true,
    OFFER_CHANGED_DURING_CAPTURE=true,
}
local function safeSnapshotReason(snapshot)
    if type(snapshot)=="table" and snapshot.status=="REJECTED"
       and knownSnapshotReasons[snapshot.reason]==true then
        return snapshot.reason
    end
    return "UNKNOWN_SNAPSHOT_REJECTION"
end
local function withSnapshotReason(output,detail)
    if type(detail)=="string" then
        output.snapshotRejectReason=knownSnapshotReasons[detail]
            and detail or "UNKNOWN_SNAPSHOT_REJECTION"
    end
    return output
end
local function report(status,reason,attempts,confirmed)
 return {
  schema="pdiddler-supervised-physical-slot-plan-v1",
  status=status,reason=reason,offerAttempts=attempts or 0,
  clientVisibleAddedSlots=confirmed or 0,
  authorizesTrade=false,authorizesAccept=false,
  pricesAuthenticated=false,rawItemIdsAuthenticated=false,
  serverCompletionProven=false,mayReportProfit=false,
  maySendDiscordWebhook=false,mayUseForStrategyLearning=false,
  tradeOutcome="UNKNOWN",
 }
end
local function rawKeyValid(s)
 return type(s)=="string" and #s>=1 and #s<=90 and
  s:match("^[A-Za-z0-9_]+$")~=nil
end
local function norm(s)
 if type(s)~="string" then return "" end
 return s:lower():gsub("[^%w]","")
end
local function protected(s)
 return norm(s):find("gingerscope",1,true)~=nil
end
local function displayValid(s)
 return type(s)=="string" and #s>=1 and #s<=90 and
    not s:find("[%c]") and not s:find("^%s") and
    not s:find("%s$") and norm(s)~=""
end
local function providedArrayValid(src,n,kind)
 if src==nil then return true end
 if type(src)~="table" or #src~=n then return false end
 local count=0
 for i,v in pairs(src) do
  if type(i)~="number" or i~=math.floor(i) or i<1 or i>n
   or (kind=="display" and not displayValid(v))
   or (kind=="chroma" and type(v)~="boolean") then return false end
  count+=1
 end
 return count==n
end
local function copySlots(items)
 local result={}
 for i,s in ipairs(items) do
  if type(s)~="table" or
   type(s.physicalSlot)~="number" or
   type(s.quantity)~="number" or
   type(s.displayCandidate)~="string" or
   type(s.chromaCandidate)~="boolean" or
   s.rawItemIdAuthenticated~=false then return nil end
  result[i]={
   physicalSlot=s.physicalSlot,
   quantity=s.quantity,
   displayCandidate=s.displayCandidate,
   chromaCandidate=s.chromaCandidate,
   internalIdCandidate=s.internalIdCandidate,
  }
 end
 return result
end
local function matches(a,b)
 if type(a)~="table" or type(b)~="table" or #a~=#b then return false end
 for i=1,#a do
  local x,y=a[i],b[i]
  for _,field in ipairs({"physicalSlot","quantity","displayCandidate",
                         "chromaCandidate","internalIdCandidate"}) do
   if x[field]~=y[field] then return false end
  end
 end
 return true
end
local function candidateAdded(before,after,expected)
 if #after~=#before+1 or #after>4 then return false end
 -- Previous slots must be unchanged, independent of their GUI order.
 local previous={}
 for _,s in ipairs(before) do previous[s.physicalSlot]=s end
 local additions={}
 for _,s in ipairs(after) do
  local old=previous[s.physicalSlot]
  if old then
   if not matches({old},{s}) then return false end
  else
   additions[#additions+1]=s
  end
 end
 if #additions~=1 then return false end
 local added=additions[1]
 -- Raw weapon key and GUI-visible label are separate client claims.
 -- The visible text/Chroma tag must match the operator's explicit approval.
 return type(added.displayCandidate)=="string" and
    added.displayCandidate:lower()==expected.display:lower() and
    added.chromaCandidate==expected.chroma and added.quantity==1 and
    not protected(added.internalIdCandidate) and
    not protected(added.displayCandidate)
end
local function current(bound,own,their)
 local ok,snapshot=pcall(bound.capture)
 if not ok or type(snapshot)~="table" or
    snapshot.status~="CLIENT_UNPRICED_TWO_SIDED_SNAPSHOT" then
  return nil,"P3_P4_LIVE_SNAPSHOT_REJECTED",
     ok and safeSnapshotReason(snapshot) or "UNKNOWN_SNAPSHOT_REJECTION"
 end
 if snapshot.authorizesOffer~=false or snapshot.authorizesAccept~=false
  or snapshot.pricesAuthenticated~=false or
  snapshot.rawItemIdsAuthenticated~=false or
  snapshot.tradeOutcome~="UNKNOWN" then
  return nil,"SNAPSHOT_AUTHORITY_MISMATCH"
 end
 if type(snapshot.ours)~="table" or type(snapshot.theirs)~="table" then
  return nil,"PHYSICAL_SLOT_SNAPSHOT_UNREADABLE"
 end
 local ours=copySlots(snapshot.ours)
 local theirs=copySlots(snapshot.theirs)
 if not ours or not theirs or
  snapshot.physicalOwnSlots~=#ours or
  snapshot.physicalTheirSlots~=#theirs or
  #ours>4 or #theirs>4 then
  return nil,"PHYSICAL_SLOT_SNAPSHOT_UNREADABLE"
 end
 if own and not matches(ours,own) then
  return nil,"OWN_OFFER_REVISION_OR_SLOT_CHANGED"
 end
 if their and not matches(theirs,their) then
  return nil,"PARTNER_OFFER_REVISION_OR_SLOT_CHANGED"
 end
 return {ours=ours,theirs=theirs},nil
end
-- An untrusted/unauthenticated CLIENT-only shadow can deny, NEVER approve.
-- This intentionally does not prove that every mutation was observed or
-- that any current game/server offer revision is authenticated.
local function shadowReceiptSafe(r,status)
 return type(r)=="table"
  and r.schema=="gingerscope-p3-client-shadow-aba-lease-v1"
  and r.status==status
  and r.clientOnly==true and r.shadowOnly==true
  and r.serverRevisionAuthenticated==false
  and r.callbackSessionAssociationProven==false
  and r.rawItemIdsAuthenticated==false
  and r.uniqueWeaponInstanceProven==false
  and r.verifiedMarketQuote==false
  and r.authorizesOffer==false and r.authorizesTrade==false
  and r.authorizesAccept==false
  and r.serverCompletionProven==false
  and r.mayReportProfit==false
  and r.maySendDiscordWebhook==false
  and r.mayUseForStrategyLearning==false
  and r.tradeOutcome=="UNKNOWN"
  and r.observedGuiMutationCount==0
  and r.observedCallbackInvalidations==0
end
local function currentShadowFresh(w)
 if type(w)~="table" or type(w.recheckShadow)~="function" then
   return false
 end
 local ok,r=pcall(w.recheckShadow)
 return ok and shadowReceiptSafe(r,"PREPARED") and
    r.reason=="CLIENT_SNAPSHOT_SAME_SHADOW_ONLY_NEVER_SEND"
end
local function prepareShadow(bound,opts,itemIndex)
 local ok,w=pcall(opts.makeShadowWitness,bound)
 if not ok or type(w)~="table" or type(w.poll)~="function"
   or type(w.prepareShadow)~="function"
   or type(w.recheckShadow)~="function" then return nil end
 local polled,initial=pcall(w.poll)
 if not polled or not shadowReceiptSafe(initial,"OBSERVING")
    then return nil end
 local prepared,receipt=pcall(w.prepareShadow)
 if not prepared or not shadowReceiptSafe(receipt,"PREPARED")
   or receipt.reason~="SHADOW_RESPONSE_PREPARED_UNPRICED"
   then return nil end
 -- Observer UI/event attachment (if supplied) MUST succeed before
 -- the next item can be considered. No implicit retry or permission.
 if type(opts.onShadowPrepared)~="function" then return nil end
 local attached,yes=pcall(opts.onShadowPrepared,w,itemIndex)
 if not attached or yes~=true then return nil end
 return currentShadowFresh(w) and w or nil
end
-- Explicit operator approval covers exactly one planned list.
-- All attempted offer remote calls remain guarded by REAL TradeIO.
-- opts.wait: injected non-yielding/mock wait in CI, task.wait in a runtime.
function M.run(bound,io,gate,approval,opts)
 if type(bound)~="table" or type(bound.capture)~="function" or
  type(io)~="table" or type(io.trade)~="function" or
  type(io.offerItem)~="function" or
  type(gate)~="table" or
  type(approval)~="table" or type(opts)~="table"
  or type(opts.wait)~="function" then
  return report("BLOCKED","DEPENDENCIES_UNAVAILABLE")
 end
 -- No two controllers may share one gate or silently retain authorization.
 if gate.checkOutbound~=nil then
  return report("BLOCKED","OTHER_OUTBOUND_GATE_ACTIVE")
 end
 if spentBindings[bound] or approval._consumed==true then
  return report("BLOCKED","PLAN_ONE_SHOT_ALREADY_SPENT")
 end
 if approval.armed~=true or approval.manualOfferOnly~=true
  or approval.noAutomaticAcceptAcknowledged~=true then
  return report("BLOCKED","OPERATOR_EXPLICIT_ARM_REQUIRED")
 end
 local keys=approval.weaponKeys
 if type(keys)~="table" or #keys<1 or #keys>4 then
  return report("BLOCKED","PLAN_PHYSICAL_SLOT_COUNT_INVALID")
 end
 local names=approval.expectedDisplayNames
 local flags=approval.expectedChromaFlags
 if not providedArrayValid(names,#keys,"display") or
    not providedArrayValid(flags,#keys,"chroma") then
  return report("BLOCKED","PLAN_DISPLAY_OR_CHROMA_SHAPE_INVALID")
 end
 local keyCount=0
 local selected,seenRaw,seenDisplay={},{},{}
 for k,key in pairs(keys) do
  keyCount+=1
  if type(k)~="number" or k~=math.floor(k) or
   k<1 or k>#keys or not rawKeyValid(key) or
   protected(key) or seenRaw[norm(key)] then
   return report("BLOCKED","PLAN_ITEM_IDENTITY_INVALID_OR_PROTECTED")
  end
  local display=(names and names[k]) or key
  local chroma=(flags and flags[k]) or false
  local variant=norm(display)..":"..tostring(chroma)
  if not displayValid(display) or protected(display) or
      seenDisplay[variant] then
   return report("BLOCKED","PLAN_DISPLAY_INVALID_AMBIGUOUS_OR_PROTECTED")
  end
  selected[k]={raw=key,display=display,chroma=chroma}
  seenRaw[norm(key)]=true
  seenDisplay[variant]=true
 end
 if keyCount~=#keys then
  return report("BLOCKED","PLAN_SPARSE_OR_EXTRA_SLOTS")
 end
 -- The old implementation is unmodified. New test candidates must
 -- EXPLICITLY opt into ABA denial. A required but absent witness blocks
 -- before any remote or consumption; do not silently use snapshot-only.
 local shadowRequired=(#selected>1)
 if shadowRequired and opts.experimentalABAShadowRequired~=true then
  return report("BLOCKED","ABA_SHADOW_EXPLICIT_MODE_REQUIRED")
 end
 if shadowRequired and (type(opts.makeShadowWitness)~="function"
       or type(opts.onShadowPrepared)~="function") then
  return report("BLOCKED","ABA_SHADOW_REQUIRED_FOR_MULTI_ITEM")
 end
 local baseline,why=current(bound,nil,nil)
 if not baseline then return report("BLOCKED",why) end
 -- For this first human-approved multi-item pass, initially empty own
 -- side is mandatory; do not silently rebalance an existing live offer.
 if #baseline.ours~=0 then
  return report("BLOCKED","OWN_OFFER_MUST_START_EMPTY")
 end
 if #baseline.theirs>4 then
  return report("BLOCKED","PARTNER_MORE_THAN_FOUR_PHYSICAL_SLOTS")
 end
 local their=baseline.theirs
 local expectedOwn=baseline.ours
 local root=io.trade()
 if not root then return report("BLOCKED","TRADE_ROOT_NOT_VISIBLE") end

 spentBindings[bound]=true
 approval._consumed=true
 approval.armed=false
 local attempts,confirmed=0,0
 local preparedWitness=nil
 for itemIndex,approved in ipairs(selected) do
  -- Pause/partner/GUI/offer checks are redone before EVERY item.
  -- This preflight rejects observed historical A->B->A even if current
  -- client offer has returned to the old identical snapshot.
  if shadowRequired and itemIndex>1 and
      not currentShadowFresh(preparedWitness) then
    return report("STOPPED","ABA_SHADOW_STALE_BEFORE_NEXT_OFFER",
      attempts,confirmed)
  end
  local before,reason=current(bound,expectedOwn,their)
  if not before or io.trade()~=root then
   return report("STOPPED",reason or "TRADE_ROOT_CHANGED",attempts,confirmed)
  end
  if #before.ours>=4 then
   return report("STOPPED","FOUR_PHYSICAL_SLOTS_ALREADY_USED",attempts,confirmed)
  end
  -- Advance to item i/N only after the preceding slot is GUI-confirmed.
  -- A missing, hidden, or failing on-screen guide blocks the next remote.
  if type(opts.onBeforeItem)=="function" then
   local okStep,shown=pcall(opts.onBeforeItem,itemIndex,#selected,#before.ours)
   if not okStep or shown~=true then
    return report("STOPPED","ONSCREEN_STEP_UNAVAILABLE",attempts,confirmed)
   end
  end
  -- On-screen step may yield while ALT mutates and restores. Always
  -- recheck the PREPARED shadow AFTER that possible yield.
  if shadowRequired and itemIndex>1 and
      not currentShadowFresh(preparedWitness) then
    return report("STOPPED","ABA_SHADOW_STALE_BEFORE_NEXT_OFFER",
      attempts,confirmed)
  end
  local key=approved.raw
  local item={id=key,rawKey=key,name=approved.display}
  local pending=true
  local callbackSeen=false
  gate.checkOutbound=function(candidate,observed)
   if not pending or candidate~=item or observed~=root
    or candidate.id~=key or candidate.rawKey~=key
    or candidate.name~=approved.display or protected(candidate.id)
    or protected(candidate.name) then
    return false
   end
   -- Last guarded pre-remote check. The GUI can be back at A while
   -- the read-only witness remembers an earlier observed B.
   if shadowRequired and itemIndex>1 and
       not currentShadowFresh(preparedWitness) then return false end
   local nextState=io.trade()==root and current(bound,expectedOwn,their)
   if not nextState then return false end
   callbackSeen=true
   return true
  end
  -- One remote attempt only. Never retry after an uncertain send.
  attempts+=1
  local called,offered=pcall(io.offerItem,item)
  pending=false
  gate.checkOutbound=nil
  if not called or offered~=true or not callbackSeen then
   return report("STOPPED","GUARDED_OFFER_REMOTE_DENIED_OR_UNCONFIRMED",
     attempts,confirmed)
  end
  -- The outgoing remote was already fired ONCE. These polls are read
  -- ONLY: neither the controller nor the on-screen guide can resend.
  -- Rendering sometimes exposes a physical slot before its label/amount
  -- has become readable. Treat only known transient observer codes as
  -- candidates for bounded rechecks; NEVER retry acceptance, partner,
  -- job, trade-root or protected item changes.
  local observed=false
  local lastTransientReason=nil
  for _=1,5 do
   local waited=pcall(opts.wait,0.2)
   if not waited then
    return report("STOPPED","GUI_REPLICATION_WAIT_FAILED",attempts,confirmed)
   end
   local fresh,reason,detail=current(bound,nil,their)
   if io.trade()~=root then
    return report("STOPPED","TRADE_ROOT_CHANGED",attempts,confirmed)
   end
   if not fresh then
    if reason=="P3_P4_LIVE_SNAPSHOT_REJECTED" and
       transientSnapshotReasons[detail]==true then
      lastTransientReason=detail
      -- One more bounded read may reconcile a partially rendered GUI.
    else
      return withSnapshotReason(report("STOPPED",
          reason or "P3_P4_LIVE_SNAPSHOT_REJECTED",
          attempts,confirmed),detail)
    end
   elseif matches(fresh.ours,expectedOwn) then
    -- Waiting for the first valid slot; do not dispatch anything else.
    lastTransientReason=nil
   elseif candidateAdded(expectedOwn,fresh.ours,approved) then
    expectedOwn=fresh.ours
    observed=true
    confirmed+=1
    break
   else
    return report("STOPPED","UNEXPECTED_OWN_OFFER_MUTATION",
       attempts,confirmed)
   end
  end
  if not observed then
    if lastTransientReason then
      return withSnapshotReason(report("STOPPED",
          "P3_P4_LIVE_SNAPSHOT_REJECTED",attempts,confirmed),
          lastTransientReason)
    end
    return report("STOPPED","ITEM_GUI_CONFIRMATION_TIMEOUT",attempts,confirmed)
  end
  -- After the prior approved own-item placement is fully client visible,
  -- establish a fresh PREPARED read-only witness around the CURRENT offer.
  -- Do not arm earlier: the expected first own-slot change would invalidate
  -- the shadow. Never resurrect an older revoked witness.
  if shadowRequired and itemIndex<#selected then
    local witness=prepareShadow(bound,opts,itemIndex)
    if not witness then
      return report("STOPPED","ABA_SHADOW_PREPARATION_FAILED",
        attempts,confirmed)
    end
    preparedWitness=witness
  end
 end
 local final,reason=current(bound,expectedOwn,their)
 if not final or io.trade()~=root then
  return report("STOPPED",reason or "TRADE_ROOT_CHANGED",attempts,confirmed)
 end
 return report("CLIENT_MANUAL_PLAN_VISIBLE_UNATTRIBUTED",
  "CLIENT_GUI_ONLY_NO_TRADE_OR_PRICE_AUTHORITY",attempts,confirmed)
end
return M
