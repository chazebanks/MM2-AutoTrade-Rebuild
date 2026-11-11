-- Client-only, one-shot, preauthorized ALT/P3/P4 auto-placement gate.
-- Human authorizes ONE raw key on MAIN picker BEFORE ARM P3.
-- Never send an item from this gate: caller's original protected PR216
-- operator alone can issue the one guarded OfferItem after fresh own read.
-- An observed trade open is NOT settlement/ownership/price authorization.
local M={}
local function receipt(status,reason)
 return {
  schema="gingerscope-p3-one-preauthorized-gate-v1",
  status=status,reason=reason,
  authorizesAccept=false,authorizesTrade=false,
  serverCompletionProven=false,pricesAuthenticated=false,
  rawItemIdsAuthenticated=false,mayReportProfit=false,
  maySendDiscordWebhook=false,tradeOutcome="UNKNOWN",
 }
end
local function key(s)
 return type(s)=="string" and #s>=1 and #s<=24
   and s:match("^[A-Za-z0-9_]+$")~=nil
end
local function safeName(s)
 return type(s)=="string" and #s>=1 and #s<=24 and
   not s:find("[%c]") and not s:match("^%s") and
   not s:match("%s$")
end
local function protected(s)
 if type(s)~="string" then return true end
 return s:lower():gsub("[^%w]",""):find("gingerscope",1,true)~=nil
end
function M.new(pilot,consent,env)
 if type(pilot)~="table" or type(pilot.preview)~="function"
    or type(pilot.execute)~="function" or
    type(consent)~="table" or type(env)~="table" or
    type(env.getJobId)~="function" or
    type(env.now)~="function" or
    type(env.isLive)~="function" or
    type(env.isArmed)~="function" or
    type(env.isExactAlt)~="function" or
    type(env.getTradeRoot)~="function" or
    type(env.onTrigger)~="function" then
  return nil,receipt("BLOCKED","GATE_DEPENDENCIES_INVALID")
 end
 local okJob,job=pcall(env.getJobId)
 local okTime,now=pcall(env.now)
 if not okJob or type(job)~="string" or job=="" or
    not okTime or type(now)~="number" or now~=now or now<0 or
    consent.origin~="PICKER_HUMAN_APPROVED_AUTO_ONE" or
    consent.explicitOneAutomaticPlacement~=true or
    consent.singleConsentingAltOnly~=true or
    consent.finalAcceptMustRemainManual~=true or
    consent.job~=job or
    type(consent.altUserId)~="number" or
    consent.altUserId<=0 or consent.altUserId~=math.floor(consent.altUserId) or
    not key(consent.rawKey) or not safeName(consent.display) or
    protected(consent.rawKey) or protected(consent.display) or
    type(consent.chroma)~="boolean" or
    type(consent.issuedAt)~="number" or
    consent.issuedAt~=consent.issuedAt or
    consent.issuedAt>now or now-consent.issuedAt>180 then
  return nil,receipt("BLOCKED","GATE_EXACT_PRIOR_HUMAN_CONSENT_INVALID")
 end
 -- Capture the *specific* prior human selection. No mutable cfg or global
 -- owner table is read for the authorization source after construction.
 local approved={
  job=job,uid=consent.altUserId,raw=consent.rawKey,
  display=consent.display,chroma=consent.chroma,
  issuedAt=consent.issuedAt,
 }
 local spent=false
 local stopped=false
 local firstRoot=nil
 local firstTime=nil
 local gate={}
 local function live()
  local ok1,j=pcall(env.getJobId)
  local ok2,t=pcall(env.now)
  local ok3,r=pcall(env.isLive)
  local ok4,a=pcall(env.isArmed)
  local ok5,e=pcall(env.isExactAlt,approved.uid)
  return ok1 and j==approved.job and
    ok2 and type(t)=="number" and t==t and
      t>=approved.issuedAt and t-approved.issuedAt<=180 and
    ok3 and r==true and ok4 and a==true and
    ok5 and e==true
 end
 function gate.observe(status)
  if spent or stopped then return receipt("SPENT","AUTO_ONE_SHOT_ALREADY_SPENT") end
  if status~="P4_TWO_SIDED_CLIENT_SNAPSHOT" then
   firstRoot=nil
   firstTime=nil
   return receipt("WAITING","WAIT_FOR_EXACT_CLIENT_P4_WINDOW")
  end
  if not live() then
   spent=true
   return receipt("BLOCKED","AUTO_CONSENT_OR_CURRENT_SESSION_STALE")
  end
  local okRoot,root=pcall(env.getTradeRoot)
  if not okRoot or not root then
   firstRoot=nil
   firstTime=nil
   return receipt("WAITING","CURRENT_TRADE_ROOT_UNREADABLE")
  end
  -- Do not offer on the first possibly transient client GUI frame.
  local okTime,now=pcall(env.now)
  if not okTime or type(now)~="number" or now~=now then
   spent=true
   return receipt("BLOCKED","AUTO_MONOTONIC_TIME_UNAVAILABLE")
  end
  if firstRoot~=root or firstTime==nil then
   firstRoot=root
   firstTime=now
   return receipt("WAITING","VERIFYING_STABLE_TRADE_WINDOW")
  end
  if now-firstTime<0.15 then
   return receipt("WAITING","VERIFYING_STABLE_TRADE_WINDOW")
  end
  -- Every gate readiness is only a CLIENT-side candidate.
  -- Underlying pilot.preview() runs the revocable exact P3/P4 facade.
  local okPreview,preview=pcall(pilot.preview)
  if not okPreview or type(preview)~="table" or
     preview.status~="READY_FOR_HUMAN_TAP" or
     preview.authorizesAccept~=false or
     preview.serverCompletionProven~=false then
   spent=true
   return receipt("BLOCKED","PROTECTED_P3_P4_PREVIEW_REFUSED")
  end
  local okAgain,stillRoot=pcall(env.getTradeRoot)
  if not live() or not okAgain or stillRoot~=root then
   spent=true
   return receipt("BLOCKED","AUTO_TRADE_CHANGED_AFTER_PREVIEW")
  end
  -- Set spent before the callback can schedule a yielding own-profile RPC.
  -- All subsequent ticks, status rerenders, or other trade windows are inert.
  spent=true
  local success,launched=pcall(env.onTrigger,approved.raw,
    approved.display,approved.chroma,root)
  if not success or launched~=true then
   return receipt("INCONCLUSIVE","AUTO_TRIGGER_CALLBACK_REFUSED")
  end
  return receipt("AUTO_ONE_ITEM_TRIGGERED","CLIENT_ONLY_NOT_A_REMOTE_RECEIPT")
 end
 function gate.stop()
  stopped=true
  spent=true
  firstRoot=nil
  firstTime=nil
  return true
 end
 function gate.isSpent()
  return spent
 end
 function gate.wasPreauthorized()
  return true
 end
 return gate,receipt("PREAUTHORIZED","EXACT_ONE_ALT_ONE_WEAPON_NO_ACCEPT")
end
return M
