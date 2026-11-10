-- Supervised operator-selected 1..4 physical-slot offer executor.
-- Requires the existing PR199 P3->P4 bound session and PR195 protected TradeIO.
-- This is NOT an economic planner. Human must approve the exact keys in advance.
-- No price feed, inventory ownership proof, automatic Accept, negotiation, hop,
-- settlement, profit reporting, Discord or automatic contact requests.
local M={}
local spentBindings=setmetatable({},{__mode="k"})
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
local function candidateAdded(before,after,key)
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
 -- Raw game key = GUI display is a conservative *candidate* in this
 -- deliberately narrow manual pilot, not authenticated item identity.
 return norm(added.displayCandidate)==norm(key) and
    added.chromaCandidate==false and added.quantity==1 and
    not protected(added.internalIdCandidate) and
    not protected(added.displayCandidate)
end
local function current(bound,own,their)
 local ok,snapshot=pcall(bound.capture)
 if not ok or type(snapshot)~="table" or
    snapshot.status~="CLIENT_UNPRICED_TWO_SIDED_SNAPSHOT" then
  return nil,"P3_P4_LIVE_SNAPSHOT_REJECTED"
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
 local keyCount=0
 local selected,seen={},{}
 for k,key in pairs(keys) do
  keyCount+=1
  if type(k)~="number" or k~=math.floor(k) or
   k<1 or k>#keys or not rawKeyValid(key) or
   protected(key) or seen[norm(key)] then
   return report("BLOCKED","PLAN_ITEM_IDENTITY_INVALID_OR_PROTECTED")
  end
  selected[k]=key
  seen[norm(key)]=true
 end
 if keyCount~=#keys then
  return report("BLOCKED","PLAN_SPARSE_OR_EXTRA_SLOTS")
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
 for _,key in ipairs(selected) do
  -- Pause/partner/GUI/offer checks are redone before EVERY item.
  local before,reason=current(bound,expectedOwn,their)
  if not before or io.trade()~=root then
   return report("STOPPED",reason or "TRADE_ROOT_CHANGED",attempts,confirmed)
  end
  if #before.ours>=4 then
   return report("STOPPED","FOUR_PHYSICAL_SLOTS_ALREADY_USED",attempts,confirmed)
  end
  local item={id=key,rawKey=key,name=key}
  local pending=true
  local callbackSeen=false
  gate.checkOutbound=function(candidate,observed)
   if not pending or candidate~=item or observed~=root
    or candidate.id~=key or candidate.rawKey~=key
    or candidate.name~=key or protected(candidate.id) then
    return false
   end
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
  local observed=false
  for _=1,5 do
   local waited=pcall(opts.wait,0.2)
   if not waited then
    return report("STOPPED","GUI_REPLICATION_WAIT_FAILED",attempts,confirmed)
   end
   local fresh,reason=current(bound,nil,their)
   if not fresh or io.trade()~=root then
    return report("STOPPED",reason or "TRADE_ROOT_CHANGED",attempts,confirmed)
   end
   if matches(fresh.ours,expectedOwn) then
    -- Waiting on GUI replication; do not attempt a second send.
   elseif candidateAdded(expectedOwn,fresh.ours,key) then
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
   return report("STOPPED","ITEM_GUI_CONFIRMATION_TIMEOUT",attempts,confirmed)
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
