-- Stage119: original-MM2 read-only native two-callback coordinator.
-- Pure dependency-injected Lua; no Roblox actions or offer/accept remotes.
-- Bind exact root/partner; independent original Stage9 physical capture is
-- supplied by the native adapter, not simulated within this controller.
local M={}
local function receipt(s,status,reason)
 local r=s.last or {}
 return {
  schema="gingerscope-stage119-native-lastoffer-v1",
  status=status,reason=reason,readOnly=true,clientOnly=true,
  nativeStage118Status=r.status or "UNOBSERVED",
  lastOfferEqualityClass=r.lastOfferEqualityClass or "NONE",
  callbackCount=r.callbackCount or 0,
  guiQuantityTransitions=r.localGuiTransitions or 0,
  clientGuiQuantityCrossChecked=r.clientGuiQuantityCrossChecked==true,
  clientGuiCrossChecked=false, -- NOT full weapon identity
  p3ArmObservedClient=false, -- this test is MANUAL ONLY, not P3
  actualRequests=0,actualOffers=0,actualAccepts=0,
  actualDeclines=0,actualTeleports=0,
  rawItemIdConfirmed=false,uniqueWeaponInstanceProven=false,
  eventSessionAssociationProven=false,callbackCausalityProven=false,
  serverTradeRevisionProven=false,serverCompletionProven=false,
  authorizesTrade=false,authorizesOffer=false,authorizesAccept=false,
  mayRecordCompletedTrade=false,mayReportProfit=false,
  maySendDiscordWebhook=false,mayUseForStrategyLearning=false,
  tradeOutcome="UNKNOWN"
 }
end
local function depsOK(d)
 return type(d)=="table" and type(d.now)=="function" and
  type(d.isLive)=="function" and type(d.findRoot)=="function" and
  type(d.newObserver)=="function" and type(d.capture)=="function" and
  type(d.connect)=="function" and type(d.show)=="function" and
  type(d.hide)=="function" and type(d.bridge)=="table" and
  type(d.bridge.new)=="function" and type(d.audit)=="table" and
  type(d.audit.new)=="function" and type(d.stage9)=="table" and
  type(d.stage9.parseQuantity)=="function" and
  type(d.scope)=="function"
end
function M.new(d)
 if not depsOK(d) then return nil end
 local s={phase="WAIT_TRADE",startAt=d.now(),last=nil,root=nil,
  core=nil,conn=nil,stopped=false,reported=false}
 local self={}
 local function disconnect()
  if s.conn then pcall(function()s.conn:Disconnect()end);s.conn=nil end
 end
 local function terminate(status,reason)
  if s.stopped then return receipt(s,"STOPPED","ALREADY_STOPPED") end
  disconnect()
  if s.core and status~="PASS" then pcall(function()s.core.stop()end) end
  if status~="PASS" then
   s.stopped=true;s.phase="FAILED"
   pcall(d.hide)
   return receipt(s,status,reason)
  end
  s.phase="PASS"
  return receipt(s,"CLIENT_TWO_EVENT_LASTOFFER_GUI_UNATTRIBUTED",
    "ONLY_LOCAL_GUI_QUANTITY_AND_OPAQUE_TOKEN_EQUALITY")
 end
 local function step()
  if s.phase=="WAIT_TRADE" then
   return "1/3 MAIN OPENS EMPTY TRADE",
     "MAIN manually opens trade with consenting ALT; both offers EMPTY."
  elseif s.phase=="WAIT_EMPTY" then
   return "1/3 VERIFYING EMPTY BASELINE",
     "MAIN/ALT leave both offers empty until armed."
  elseif s.phase=="WAIT_ADD" or s.phase=="WAIT_FIRST_GUI" then
   return "2/3 ALT MANUALLY ADDS ONE",
     "ALT: add ONE cheap eligible weapon. MAIN keeps offer EMPTY."
  elseif s.phase=="WAIT_REMOVE" or s.phase=="WAIT_SECOND_GUI" then
   return "3/3 ALT MANUALLY REMOVES ONE",
     "ALT: remove that weapon. MAIN stays EMPTY. No final Accept."
  else
   return "DONE - MAIN MANUAL DECLINE",
    "MAIN manually Decline, then STOP/COPY sanitized result."
  end
 end
 function self.tick()
  if s.stopped then return receipt(s,"STOPPED","ALREADY_STOPPED") end
  if s.phase=="PASS" then return receipt(s,"CLIENT_TWO_EVENT_LASTOFFER_GUI_UNATTRIBUTED",
     "ONLY_LOCAL_GUI_QUANTITY_AND_OPAQUE_TOKEN_EQUALITY") end
  local okLive,live=pcall(d.isLive)
  local okTime,t=pcall(d.now)
  if not okLive or live~=true or not okTime or type(t)~="number"
    or t~=t or t==math.huge or t<0 or t<s.startAt or t-s.startAt>95 then
   return terminate("INCONCLUSIVE","CLIENT_SESSION_OR_TIME_INVALID")
  end
  local okRoot,root,rootReason=pcall(d.findRoot)
  if not okRoot then return terminate("INCONCLUSIVE","CURRENT_TRADE_GUI_UNAVAILABLE") end
  if s.root then
   if root~=s.root then return terminate("INCONCLUSIVE","TRADE_ROOT_OR_PARTNER_CHANGED") end
  elseif rootReason~="NOT_OPEN" and root==nil then
   return terminate("INCONCLUSIVE",rootReason or "TRADE_ROOT_UNVERIFIED")
  end
  if s.phase=="WAIT_TRADE" and root then
   s.root=root
   local okObs,observer=pcall(d.newObserver,root)
   if not okObs or type(observer)~="table" then
    return terminate("INCONCLUSIVE","ORIGINAL_STAGE9_NATIVE_OBSERVER_UNAVAILABLE")
   end
   local scope=d.scope(root)
   if type(scope)~="table" then
    return terminate("INCONCLUSIVE","CURRENT_TRADE_SCOPE_UNVERIFIED")
   end
   local newCore=d.bridge.new(scope,{
    audit=d.audit,stage9=d.stage9,
    capture=function()return d.capture(observer,scope)end,
    now=d.now,isLive=function()
     local ok,yes=pcall(d.isLive)
     local good,current=pcall(d.findRoot)
     return ok and yes==true and good and current==root
    end
   })
   if not newCore then return terminate("INCONCLUSIVE","STAGE118_NATIVE_BRIDGE_UNAVAILABLE") end
   s.core=newCore
   local okBegin,r=pcall(s.core.begin)
   if not okBegin or type(r)~="table" or r.status~="WAITING" then
    return terminate("INCONCLUSIVE","STAGE118_EMPTY_BASELINE_FAILED")
   end
   s.last=r;s.phase="WAIT_EMPTY"
  elseif s.phase=="WAIT_EMPTY" then
   local ok,r=pcall(s.core.tick)
   if not ok or type(r)~="table" or r.status=="INCONCLUSIVE" then
    return terminate("INCONCLUSIVE",r and r.reason or "EMPTY_CLIENT_GUI_INVALID")
   end
   s.last=r
   if r.reason=="ALT_MANUAL_ADD_ONE" then
    -- Listener connects only AFTER stable empty original Stage9 GUI; ALT
    -- cannot be prompted to add before the listener is ready.
    local good,con=pcall(d.connect,function(...)
     return self.onClientEvent(...)
    end)
    if not good or type(con)~="table" or type(con.Disconnect)~="function" then
     return terminate("INCONCLUSIVE","UNIQUE_UPDATE_TRADE_LISTENER_UNAVAILABLE")
    end
    s.conn=con;s.phase="WAIT_ADD"
   end
  elseif s.phase=="WAIT_ADD" or s.phase=="WAIT_FIRST_GUI"
      or s.phase=="WAIT_REMOVE" or s.phase=="WAIT_SECOND_GUI" then
   local ok,r=pcall(s.core.tick)
   if not ok or type(r)~="table" or r.status=="INCONCLUSIVE" then
    return terminate("INCONCLUSIVE",r and r.reason or "STAGE118_CLIENT_EVIDENCE_INVALID")
   end
   s.last=r
   if r.status=="CLIENT_TWO_EVENT_LASTOFFER_GUI_UNATTRIBUTED" then
    local result=terminate("PASS","CLIENT_TWO_EVENT_LASTOFFER_GUI_UNATTRIBUTED")
    local title,body=step()
    local uiOk,shown=pcall(d.show,title,body,s.root,true)
    if not uiOk or shown~=true then return terminate("INCONCLUSIVE","ONSCREEN_GUIDE_NO_SAFE_SPACE_OUTSIDE_TRADE") end
    return result
   elseif r.reason=="ALT_MANUAL_REMOVE_ONE" then
    s.phase="WAIT_REMOVE"
   end
  end
  local title,body=step()
  local shownOK,shown,why=pcall(d.show,title,body,s.root,false)
  if not shownOK or shown~=true then
   return terminate("INCONCLUSIVE",why or "ONSCREEN_GUIDE_NO_SAFE_SPACE_OUTSIDE_TRADE")
  end
  return receipt(s,"WAITING",s.phase)
 end
 function self.onClientEvent(...)
  if s.stopped or s.phase=="PASS" then
   return terminate("INCONCLUSIVE","CALLBACK_OUTSIDE_ACTIVE_CLIENT_WINDOW")
  end
  if s.phase~="WAIT_ADD" and s.phase~="WAIT_REMOVE" then
   return terminate("INCONCLUSIVE","UNEXPECTED_OR_DUPLICATE_CLIENT_EVENT")
  end
  if select("#",...)~=1 then return terminate("INCONCLUSIVE","CLIENT_CALLBACK_ARGUMENTS_UNVERIFIED") end
  local p=(...)
  local ok,r=pcall(s.core.onClientEvent,p)
  if not ok or type(r)~="table" or r.status=="INCONCLUSIVE" then
   return terminate("INCONCLUSIVE",r and r.reason or "CLIENT_LASTOFFER_PACKET_INVALID")
  end
  s.last=r
  s.phase=s.phase=="WAIT_ADD" and "WAIT_FIRST_GUI" or "WAIT_SECOND_GUI"
  return receipt(s,"WAITING","CLIENT_EVENT_RECEIVED_WAIT_STAGE9_GUI")
 end
 function self.stop()
  -- A cleanup STOP following a terminal failure must never relabel that
  -- failure as an operator stop or silently erase the first diagnostic.
  if s.phase=="FAILED" then
   disconnect()
   return receipt(s,"INCONCLUSIVE","ALREADY_INCONCLUSIVE")
  end
  local wasPass=s.phase=="PASS"
  disconnect()
  if s.core and not wasPass then pcall(function()s.core.stop()end) end
  s.stopped=true;s.phase="STOPPED"
  return receipt(s,"STOPPED",wasPass and "OPERATOR_STOPPED_AFTER_CLIENT_PASS" or "OPERATOR_STOPPED")
 end
 function self.getStatus()
  return receipt(s,s.phase=="PASS" and "CLIENT_TWO_EVENT_LASTOFFER_GUI_UNATTRIBUTED"
    or s.phase=="FAILED" and "INCONCLUSIVE" or s.phase=="STOPPED" and "STOPPED"
    or "WAITING",s.phase)
 end
 return self
end
return M
