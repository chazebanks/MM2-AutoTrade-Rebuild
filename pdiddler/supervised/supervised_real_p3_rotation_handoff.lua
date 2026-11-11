-- Actual P3 request-rotation -> supervised P4 paused-trade handoff.
-- The existing legacy scanner/outgoing are supplied as LIVE instantiated APIs.
-- This file sends NO requests, offers, final Accept, Decline, hops, price,
-- profit or Discord; it is only their session/identity/closure coordinator.
local M={}
local function result(status,reason,extra)
 local r={
  schema="pdiddler-supervised-real-p3-handoff-v1",
  status=status,reason=reason,
  contactOrigin="P3_CLIENT_PROCESSED_TRADE_OPEN_UNATTESTED",
  part3RotationAuthorized=false,
  requestOriginBound=false,
  rawItemIdsAuthenticated=false,pricesAuthenticated=false,
  serverCompletionProven=false,authorizesOffer=false,
  authorizesTrade=false,authorizesAccept=false,
  mayReportProfit=false,maySendDiscordWebhook=false,
  mayUseForStrategyLearning=false,tradeOutcome="UNKNOWN",
 }
 if extra then
  r.ownPhysicalSlots=extra.ownPhysicalSlots
  r.theirPhysicalSlots=extra.theirPhysicalSlots
 end
 return r
end
local function integer(x)
 return type(x)=="number" and x>=1 and
  x==math.floor(x) and x<100000000000000000000
end
local function exactString(a,b)
 return type(a)=="string" and type(b)=="string"
   and a:lower()==b:lower()
end
function M.new(scanner,outgoing,bridge,io,players,me,ctx)
 if type(scanner)~="table" or
   type(scanner.getRecord)~="function" or
   type(scanner.isWhitelisted)~="function" or
   type(outgoing)~="table" or
   type(outgoing.state)~="table" or
   type(outgoing.state.processed)~="table" or
   type(outgoing.session)~="number" or
   type(outgoing.isPaused)~="function" or
   type(outgoing.resume)~="function" or
   type(bridge)~="table" or type(bridge.bind)~="function" or
   type(io)~="table" or type(io.trade)~="function" or
   type(io.partnerName)~="function" or
   (type(players)~="table" and type(players)~="userdata") or
   type(players.GetPlayerByUserId)~="function" or
   type(me)~="table" and type(me)~="userdata" or
   type(ctx)~="table" or type(ctx.getJobId)~="function" or
   type(ctx.getP3Session)~="function" then
   return nil,result("BLOCKED","P3_P4_DEPENDENCY_INVALID")
 end
 local okJ,job=pcall(ctx.getJobId)
 local okS,epoch=pcall(ctx.getP3Session)
 if not okJ or not okS or type(job)~="string" or job==""
    or not integer(epoch) or epoch~=outgoing.session then
  return nil,result("BLOCKED","P3_JOB_OR_EPOCH_INVALID")
 end
 local state=outgoing.state
 -- Historical trade-open outcomes already present when attached CANNOT
 -- be shown to originate in a NEW pause. The coordinator is attached
 -- before new outgoing requests, or it refuses a stale handoff.
 local preexisting={}
 for uid in pairs(state.processed) do
  preexisting[tostring(uid)]=true
 end
 local consumed={}
 local active=nil
 local running=true
 local controller={}
 local function live()
  if not running then return false,"CONTROLLER_STOPPED" end
  local goodJ,currentJ=pcall(ctx.getJobId)
  local goodS,currentS=pcall(ctx.getP3Session)
  if not goodJ or not goodS or currentJ~=job
     or currentS~=epoch or outgoing.session~=epoch then
   return false,"P3_JOB_OR_EPOCH_CHANGED"
  end
  return true,nil
 end
 local function paused()
  local ok,v=pcall(outgoing.isPaused)
  return ok and v==true
 end
 local function findFreshOutcome()
  local found=nil
  for key,code in pairs(state.processed) do
   if code=="trade-open" then
    local uid=tostring(key)
    if not preexisting[uid] and not consumed[uid] then
     local numeric=tonumber(uid)
     if not integer(numeric) or tostring(numeric)~=uid then
      return nil,"P3_PROCESSED_ID_INVALID"
     end
     if found then return nil,"P3_MULTIPLE_NEW_TRADE_OUTCOMES" end
     found=numeric
    end
   end
  end
  if not found then
    return nil,"P3_NO_FRESH_ACCEPTED_TARGET"
  end
  return found,nil
 end
 local function resolveTarget(uid)
  local ok,p=pcall(players.GetPlayerByUserId,players,uid)
  if not ok or not p or p==me or p.Parent~=players
     or p.UserId~=uid then
   return nil,"P3_PROCESSED_TARGET_GONE"
  end
  local okW,white=pcall(scanner.isWhitelisted,uid)
  local okR,rec=pcall(scanner.getRecord,uid)
  if not okW or white~=true or not okR
     or type(rec)~="table" or rec.player~=p
     or rec.state~="whitelist" then
   return nil,"P3_SCANNER_TARGET_NOT_CURRENT"
  end
  if type(p.Name)~="string" or
     not p.Name:match("^[A-Za-z0-9_]+$") then
   return nil,"P3_TARGET_USERNAME_INVALID"
  end
  return p,nil
 end
 function controller.poll()
  local ok,why=live()
  if not ok then return result("BLOCKED",why) end
  if active then
   if not paused() then return result("BLOCKED","P3_RESUMED_EXTERNALLY") end
   local good,snap=pcall(active.bound.capture)
   if not good or type(snap)~="table" then
    return result("BLOCKED","P4_SNAPSHOT_UNAVAILABLE")
   end
   if snap.status~="CLIENT_UNPRICED_TWO_SIDED_SNAPSHOT"
      or snap.authorizesOffer~=false or
      snap.authorizesAccept~=false or
      snap.pricesAuthenticated~=false or
      snap.tradeOutcome~="UNKNOWN" then
    return result("BLOCKED","P4_SNAPSHOT_NO_LONGER_SAFE")
   end
   return result("P4_TWO_SIDED_CLIENT_SNAPSHOT",
    "READ_ONLY_P3_PAUSED_P4_OBSERVED",{
       ownPhysicalSlots=snap.physicalOwnSlots,
       theirPhysicalSlots=snap.physicalTheirSlots,
    })
  end
  if not paused() then return result("P3_ROTATING","NO_TRADE_HANDOFF_YET") end
  local uid,missing=findFreshOutcome()
  if not uid then return result("P3_PAUSED_UNATTRIBUTED",missing) end
  if state.active~=nil then
    return result("P3_PAUSED_UNATTRIBUTED","P3_ACTIVE_PLAYER_NOT_RELEASED")
  end
  local partner,reason=resolveTarget(uid)
  if not partner then return result("P3_PAUSED_UNATTRIBUTED",reason) end
  local trade=io.trade()
  if not trade or not exactString(io.partnerName(trade),partner.Name) then
    return result("P3_PAUSED_UNATTRIBUTED",
       "P3_TRADE_WINDOW_PARTNER_NOT_EXACT")
  end
  -- Bridge also verifies the exact instance, GUI lineage, two-sided
  -- acceptance flags, price independence and four PHYSICAL slots.
  local good,bound,err=pcall(bridge.bind,scanner,outgoing,io,
      players,me,{targetName=partner.Name,
       getJobId=ctx.getJobId,getP3Session=ctx.getP3Session})
  if not good or type(bound)~="table" then
    return result("P3_PAUSED_UNATTRIBUTED",
      "P3_TO_P4_BOUND_HANDOFF_REFUSED")
  end
  -- The original P3/P4 bridge binds a GUI root BEFORE its first accepted
  -- indicator/offer read. Validate its actual snapshot NOW rather than
  -- publishing a bound turn which was already unsafe at attachment.
  local goodInitial,initial=pcall(bound.capture)
  if not goodInitial or type(initial)~="table" or
     initial.status~="CLIENT_UNPRICED_TWO_SIDED_SNAPSHOT"
     or initial.authorizesAccept~=false or
     initial.authorizesOffer~=false or
     initial.pricesAuthenticated~=false or
     initial.tradeOutcome~="UNKNOWN" then
    -- Quarantine this event, even if the UI later appears safe.
    -- A consumed flagged outcome must not be recycled as a new request.
    consumed[tostring(uid)]=true
    return result("P3_PAUSED_UNATTRIBUTED",
      "P3_TO_P4_BOUND_HANDOFF_REFUSED")
  end
  -- Mark this processed event ONCE; original P3 does not clear the
  -- processed map on resume. Never allow a historical stale rebind.
  consumed[tostring(uid)]=true
  active={bound=bound,userId=uid}
  return controller.poll()
 end
 -- Read-only future manual-plan bridge: never dispatches or approves offers.
 -- One facade is tied to exactly ONE active original client P3/P4 session.
 -- It is revoked after closure, stop, replacement or any unsafe capture.
 local function denyCapture(reason)
  return {
   schema="pdiddler-supervised-handoff-v1",
   status="REJECTED",reason=reason,
   authorizesOffer=false,authorizesAccept=false,
   rawItemIdsAuthenticated=false,pricesAuthenticated=false,
   serverCompletionProven=false,mayReportProfit=false,
   maySendDiscordWebhook=false,tradeOutcome="UNKNOWN",
  }
 end
 function controller.currentBoundReadOnly()
  local observed=controller.poll()
  if type(observed)~="table" or
     observed.status~="P4_TWO_SIDED_CLIENT_SNAPSHOT" or
     active==nil or not running then
   return nil,result("BLOCKED","P3_NO_CURRENT_EXACT_BOUND_TRADE")
  end
  local session=active
  local facade={}
  local revoked=false
  function facade.capture()
   if revoked or not running or active~=session then
    revoked=true
    return denyCapture("HANDOFF_RELEASED")
   end
   -- The ORIGINAL coordinator and protected GUI observer must re-pass
   -- on every capture. A prior snapshot or matching username is not enough.
   local current=controller.poll()
   if type(current)~="table" or
      current.status~="P4_TWO_SIDED_CLIENT_SNAPSHOT" or
      active~=session then
    revoked=true
    return denyCapture("P3_CURRENT_BOUND_TRADE_UNSAFE")
   end
   local ok,snapshot=pcall(session.bound.capture)
   if not ok or type(snapshot)~="table" or
      snapshot.status~="CLIENT_UNPRICED_TWO_SIDED_SNAPSHOT" or
      snapshot.authorizesOffer~=false or
      snapshot.authorizesAccept~=false or
      snapshot.pricesAuthenticated~=false or
      snapshot.rawItemIdsAuthenticated~=false or
      snapshot.offerRevisionAuthenticated~=false or
      snapshot.serverCompletionProven~=false or
      snapshot.mayReportProfit~=false or
      snapshot.maySendDiscordWebhook~=false or
      snapshot.requestOriginBound~=false or
      snapshot.partnerExactClientBound~=true or
      snapshot.part3Paused~=true or
      snapshot.part4TradeVisible~=true or
      snapshot.tradeOutcome~="UNKNOWN" then
    revoked=true
    return denyCapture("P4_BOUND_SNAPSHOT_UNSAFE")
   end
   return snapshot
  end
  return facade,result("P3_BOUND_CANDIDATE_READ_ONLY",
    "NOT_AN_OFFER_OR_TRADE_AUTHORIZATION")
 end
 function controller.resumeAfterClose()
  local ok,reason=live()
  if not ok then return false,reason end
  if not active then return false,"NO_CLIENT_BOUND_TRADE" end
  if not paused() then return false,"P3_NOT_PAUSED" end
  local good,yes,why=pcall(active.bound.resumeAfterClose)
  if not good or yes~=true then
    return false,good and tostring(why or "P3_RESUME_REFUSED") or
      "P3_RESUME_CALLBACK_FAILED"
  end
  active=nil
  return true,"P3_RESUMED_AFTER_CLIENT_TRADE_CLOSED"
 end
 function controller.stop()
  running=false
  active=nil
  return true
 end
 return controller,nil
end
return M
