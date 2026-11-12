-- Shadow-only local offer-mutation lease: a previously prepared *hypothetical*
-- response becomes permanently stale on ANY observed change, including ABA.
-- No physical offer, RemoteEvent, Accept, Decline, price, profit or webhook.
-- This cannot detect unobserved changes between polls; optional UpdateTrade
-- callbacks are ONLY an extra fail-closed invalidation signal, never authority.
local M={}
local function report(state,reason,transitions,callbacks)
 return {
  schema="gingerscope-p3-client-shadow-aba-lease-v1",
  status=state,reason=reason,
  observedGuiMutationCount=transitions,
  observedCallbackInvalidations=callbacks,
  clientOnly=true,shadowOnly=true,
  serverRevisionAuthenticated=false,
  callbackSessionAssociationProven=false,
  rawItemIdsAuthenticated=false,
  uniqueWeaponInstanceProven=false,
  serverCompletionProven=false,
  verifiedMarketQuote=false,
  authorizesOffer=false,authorizesTrade=false,authorizesAccept=false,
  mayReportProfit=false,maySendDiscordWebhook=false,
  mayUseForStrategyLearning=false,tradeOutcome="UNKNOWN",
 }
end
local function int(v,low,high)
 return type(v)=="number" and v==math.floor(v) and v>=low and v<=high
end
local function str(s)
 return type(s)=="string" and #s<=100 and #s>0
    and not s:find("[%c]")
end
local function side(slots)
 if type(slots)~="table" or getmetatable(slots)~=nil or #slots>4 then
  return nil
 end
 local seen,count={},0
 local values={}
 for k,v in pairs(slots) do
  count+=1
  if type(k)~="number" or not int(k,1,4)
    or type(v)~="table" or getmetatable(v)~=nil
    or not int(v.physicalSlot,1,4) or seen[v.physicalSlot]
    or not int(v.quantity,1,1000000)
    or not str(v.displayCandidate)
    or type(v.chromaCandidate)~="boolean"
    or v.rawItemIdAuthenticated~=false
    or (v.internalIdCandidate~=nil and
       (type(v.internalIdCandidate)~="string"
         or #v.internalIdCandidate>100
         or v.internalIdCandidate:find("[%c]"))) then
    return nil
  end
  seen[v.physicalSlot]=true
  -- Never serialize item labels/IDs or log raw inventory. These candidate
  -- values stay inside this shadow-only in-memory fingerprint.
  values[#values+1]={
    slot=v.physicalSlot,q=v.quantity,name=v.displayCandidate,
    chroma=v.chromaCandidate,id=v.internalIdCandidate or "",
  }
 end
 if count~=#slots then return nil end
 table.sort(values,function(a,b)return a.slot<b.slot end)
 return values
end
local function sameSide(a,b)
 if #a~=#b then return false end
 for i=1,#a do
  local x,y=a[i],b[i]
  if x.slot~=y.slot or x.q~=y.q or x.name~=y.name
    or x.chroma~=y.chroma or x.id~=y.id then return false end
 end
 return true
end
local function canonical(snapshot)
 if type(snapshot)~="table" or
    snapshot.status~="CLIENT_UNPRICED_TWO_SIDED_SNAPSHOT"
    or snapshot.partnerExactClientBound~=true
    or snapshot.part3Paused~=true
    or snapshot.part4TradeVisible~=true
    or snapshot.requestOriginBound~=false
    or snapshot.rawItemIdsAuthenticated~=false
    or snapshot.pricesAuthenticated~=false
    or snapshot.offerRevisionAuthenticated~=false
    or snapshot.authorizesOffer~=false
    or snapshot.authorizesAccept~=false
    or snapshot.serverCompletionProven~=false
    or snapshot.mayReportProfit~=false
    or snapshot.maySendDiscordWebhook~=false
    or snapshot.tradeOutcome~="UNKNOWN" then return nil end
 local ours,theirs=side(snapshot.ours),side(snapshot.theirs)
 if not ours or not theirs
    or snapshot.physicalOwnSlots~=#ours
    or snapshot.physicalTheirSlots~=#theirs then return nil end
 return {ours=ours,theirs=theirs}
end
function M.new(bound,source)
 if type(bound)~="table" or type(bound.capture)~="function"
   or type(source)~="table" or type(source.root)~="function"
   or type(source.live)~="function" then
  return nil,report("BLOCKED","INVALID_DEPENDENCIES",0,0)
 end
 local scopeRoot=nil
 local phase="OBSERVING"
 local last=nil
 local stable=0
 local prepared=nil
 local transitions=0
 local callbacks=0
 local witness={}
 local function result(reason)
  return report(phase,reason,transitions,callbacks)
 end
 local function revoke(reason)
  if phase~="STALE" then phase="STALE" end
  return result(reason)
 end
 local function checkScope()
  local ok,live=pcall(source.live)
  local got,root=pcall(source.root)
  if not ok or live~=true or not got
      or (type(root)~="table" and type(root)~="userdata")
      or root==nil then
    return nil,"BOUND_CLIENT_SCOPE_LOST"
  end
  if scopeRoot~=nil and scopeRoot~=root then
    return nil,"BOUND_CLIENT_TRADE_ROOT_CHANGED"
  end
  scopeRoot=root
  return root,nil
 end
 function witness.poll()
  if phase=="STALE" then return result("PREPARED_SHADOW_RESPONSE_REVOKED") end
  local root,reason=checkScope()
  if not root then return revoke(reason) end
  local ok,snap=pcall(bound.capture)
  local fresh=ok and canonical(snap) or nil
  if not fresh then return revoke("BOUND_CLIENT_SNAPSHOT_UNREADABLE") end
  local changed=last~=nil and
      (not sameSide(last.ours,fresh.ours)
       or not sameSide(last.theirs,fresh.theirs))
  if changed then
   transitions=math.min(transitions+1,1000000)
   last=fresh
   stable=1
   if phase=="PREPARED" then
    return revoke("OBSERVED_GUI_MUTATION_REQUIRES_FRESH_PLAN")
   end
   return result("OBSERVING_NEW_CLIENT_OFFER")
  end
  if last==nil then
   last=fresh
   stable=1
  else
   stable=math.min(stable+1,1000000)
  end
  return result("CLIENT_SNAPSHOT_OBSERVED_NO_AUTHORITY")
 end
 function witness.prepareShadow()
  if phase=="STALE" then return result("PREPARED_SHADOW_RESPONSE_REVOKED") end
  if phase=="PREPARED" then return result("SHADOW_ALREADY_PREPARED") end
  local seen=witness.poll()
  if seen.status=="STALE" then return seen end
  if stable<2 or last==nil then
   return result("WAIT_FOR_TWO_STABLE_CLIENT_SNAPSHOTS")
  end
  prepared=last
  phase="PREPARED"
  return result("SHADOW_RESPONSE_PREPARED_UNPRICED")
 end
 function witness.observeClientUpdateCallback()
  -- A callback has no server-session authentication. Refuse ONLY; never
  -- positively prove an offer or authorize activity based on this signal.
  if phase=="PREPARED" then
   callbacks=math.min(callbacks+1,1000000)
   return revoke("CLIENT_CALLBACK_REQUIRES_FRESH_PLAN")
  end
  if phase=="STALE" then return result("ALREADY_REVOKED") end
  return result("CALLBACK_BEFORE_SHADOW_PREPARE_UNATTRIBUTED")
 end
 function witness.recheckShadow()
  if phase~="PREPARED" then
   return result("NO_CURRENT_HYPOTHETICAL_RESPONSE")
  end
  local checked=witness.poll()
  if checked.status~="PREPARED" or prepared~=last then
   return result("REPLAN_REQUIRED")
  end
  return result("CLIENT_SNAPSHOT_SAME_SHADOW_ONLY_NEVER_SEND")
 end
 function witness.stop()
  return revoke("OPERATOR_STOPPED_OR_GUI_CLOSED")
 end
 function witness.state()
  return result("CLIENT_ONLY_NEVER_SEND")
 end
 return witness,report("OBSERVING","NO_PLAN_PREPARED",0,0)
end
return M
