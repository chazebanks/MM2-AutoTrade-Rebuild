-- Stage118: strictly local two-event LastOffer/Stage9 GUI correlation.
-- Offline dependency-injected research; neither a game listener nor a sender.
-- Does not authenticate an MM2 transaction, raw key, revision or settlement.
local M={}
local function output(status,reason,s)
 return {schema="gingerscope-stage118-twoevent-lastoffer-gui-v1",
  status=status,reason=reason,clientOnly=true,readOnly=true,
  firstEventObserved=s and s.events>=1 or false,
  secondEventObserved=s and s.events==2 or false,
  callbackCount=s and s.events or 0,
  localGuiTransitions=s and s.transitions or 0,
  lastOfferEqualityClass=s and s.equality or "NONE",
  clientGuiCrossChecked=false, -- full GUI weapon identity NOT verified here
  clientGuiQuantityCrossChecked=s and s.complete or false,
  rawItemIdConfirmed=false,uniqueWeaponInstanceProven=false,
  eventSessionAssociationProven=false,callbackCausalityProven=false,
  serverTradeRevisionProven=false,serverCompletionProven=false,
  authorizesTrade=false,authorizesOffer=false,authorizesAccept=false,
  mayReportProfit=false,maySendDiscordWebhook=false,
  mayUseForStrategyLearning=false,tradeOutcome="UNKNOWN"}
end
local function finite(x)
 return type(x)=="number" and x==x and x<math.huge and x>-math.huge
end
local function scopeValid(x)
 return type(x)=="table" and type(x.session)=="string" and #x.session>0
  and type(x.jobId)=="string" and #x.jobId>0
  and x.root~=nil and x.localPlayer~=nil and x.partnerPlayer~=nil
  and x.localPlayer~=x.partnerPlayer
end
local function sameScope(a,b)
 return scopeValid(a) and a.session==b.session and a.jobId==b.jobId
  and rawequal(a.root,b.root) and rawequal(a.localPlayer,b.localPlayer)
  and rawequal(a.partnerPlayer,b.partnerPlayer)
end
local function dense(t,max)
 if type(t)~="table" or getmetatable(t)~=nil or #t>max then return false end
 local count=0
 for k in pairs(t) do
  if type(k)~="number" or k~=math.floor(k) or k<1 or k>#t then return false end
  count=count+1
 end
 return count==#t
end
local function side(x,parse)
 if type(x)~="table" or x.complete~=true or x.accepted~=false
    or not dense(x.slots,4) then return nil end
 local bySlot,seen={},{}
 for _,v in ipairs(x.slots) do
  if type(v)~="table" or type(v.slot)~="number"
     or v.slot~=math.floor(v.slot) or v.slot<1 or v.slot>4
     or seen[v.slot] or type(v.label)~="string" or #v.label<1
     or type(v.chroma)~="boolean" then return nil end
  local ok,q=pcall(parse,v.amountText)
  if not ok or type(q)~="number" or q~=math.floor(q) or q<1 or q>1000000
     then return nil end
  seen[v.slot]=true
  bySlot[#bySlot+1]={slot=v.slot,q=q,name=v.label,chroma=v.chroma}
 end
 table.sort(bySlot,function(a,b)return a.slot<b.slot end)
 return bySlot
end
local function guiEqual(a,b)
 for _,k in ipairs({"our","their"}) do
  if #a[k]~=#b[k] then return false end
  for i,v in ipairs(a[k]) do
   local x=b[k][i]
   if v.slot~=x.slot or v.q~=x.q or v.name~=x.name or v.chroma~=x.chroma then
    return false
   end
  end
 end
 return true
end
local function qtysFromGui(g)
 local q={}
 for _,v in ipairs(g) do q[#q+1]=v.q end
 table.sort(q)
 return q
end
local function qtysFromPacket(t)
 if not dense(t,4) then return nil end
 local q={}
 for _,v in ipairs(t) do
  if type(v)~="table" or type(v[2])~="number" or v[2]<1
     or v[2]>1000000 or v[2]~=math.floor(v[2]) then return nil end
  q[#q+1]=v[2]
 end
 table.sort(q)
 return q
end
local function sameQ(a,b)
 if not a or not b or #a~=#b then return false end
 for i=1,#a do if a[i]~=b[i] then return false end end
 return true
end
-- Snapshot only aggregate quantities at callback-time; never hold a caller's
-- mutable payload table across asynchronous GUI reads.
local function freezePacketQuantities(packet,scope)
 if type(packet)~="table" or packet.Locked~=false then return nil end
 local a,b=packet.Player1,packet.Player2
 if type(a)~="table" or type(b)~="table" then return nil end
 local own,their
 if rawequal(a.Player,scope.localPlayer) and rawequal(b.Player,scope.partnerPlayer) then
  own=a.Offer;their=b.Offer
 elseif rawequal(b.Player,scope.localPlayer) and rawequal(a.Player,scope.partnerPlayer) then
  own=b.Offer;their=a.Offer
 else return nil end
 local oq,tq=qtysFromPacket(own),qtysFromPacket(their)
 if not oq or not tq then return nil end
 return {our=oq,their=tq}
end
local function packetFits(frozen,gui)
 return frozen and sameQ(qtysFromGui(gui.our),frozen.our)
     and sameQ(qtysFromGui(gui.their),frozen.their)
end
function M.new(scope,deps)
 if not scopeValid(scope) or type(deps)~="table" or
  type(deps.audit)~="table" or type(deps.audit.new)~="function" or
  type(deps.stage9)~="table" or type(deps.stage9.parseQuantity)~="function" or
  type(deps.capture)~="function" or type(deps.now)~="function" or
  type(deps.isLive)~="function" then return nil end
 local frozen={session=scope.session,jobId=scope.jobId,root=scope.root,
  localPlayer=scope.localPlayer,partnerPlayer=scope.partnerPlayer}
 local audit=deps.audit.new(frozen)
 if not audit then return nil end
 local s={phase="NEW",events=0,transitions=0,complete=false,equality="NONE",
  first=nil,last=nil,packet=nil,after=nil,changedAt=nil,started=nil,lastTime=nil}
 local function fail(why)
  s.phase="BLOCKED";s.packet=nil;s.first=nil;s.last=nil;s.after=nil
  pcall(audit.stop)
  return output("INCONCLUSIVE",why,s)
 end
 local function capture()
  local okLive,live=pcall(deps.isLive)
  local okTime,at=pcall(deps.now)
  local okCap,v=pcall(deps.capture)
  if not okLive or live~=true or not okTime or not finite(at) or at<0
   or (s.lastTime~=nil and at<s.lastTime)
   or not okCap or type(v)~="table" or not sameScope(v,frozen)
   or type(v.raw)~="table" or v.raw.tradeOpen~=true
   or v.raw.contextOK~=true or v.raw.session~=frozen.session then
    return nil,"LOCAL_SESSION_OR_STAGE9_CAPTURE_UNAVAILABLE"
  end
  local ours=side(v.raw.our,deps.stage9.parseQuantity)
  local theirs=side(v.raw.their,deps.stage9.parseQuantity)
  if not ours or not theirs then return nil,"STAGE9_SLOTS_OR_ACCEPT_UNVERIFIED" end
  s.lastTime=at
  return {at=at,our=ours,their=theirs},nil
 end
 local function elapsed(t)
  return s.started~=nil and (t-s.started>90 or t<s.started)
 end
 local obj={}
 function obj.begin()
  if s.phase~="NEW" then return fail("BEGIN_REPEATED") end
  local g,why=capture()
  if not g then return fail(why) end
  if #g.our~=0 or #g.their~=0 then return fail("EMPTY_TWO_SIDED_BASELINE_REQUIRED") end
  s.started=g.at;s.first=g;s.phase="WAIT_EMPTY_STABLE"
  return output("WAITING","EMPTY_GUI_FIRST_READ",s)
 end
 function obj.onClientEvent(packet)
  if s.phase~="WAIT_FIRST_EVENT" and s.phase~="WAIT_SECOND_EVENT" then
   return fail("UNEXPECTED_OR_DUPLICATE_CLIENT_EVENT")
  end
  local g,why=capture()
  if not g then return fail(why) end
  if elapsed(g.at) then return fail("CLIENT_WINDOW_EXPIRED") end
  if not guiEqual(g,s.last) then return fail("GUI_CHANGED_BEFORE_CURRENT_CALLBACK") end
  local prior=s.last
  if s.phase=="WAIT_FIRST_EVENT" then
   if #prior.our~=0 or #prior.their~=0 then return fail("FIRST_BASELINE_NOT_EMPTY") end
  elseif #prior.our~=0 or #prior.their~=1 then
   return fail("SECOND_BASELINE_NOT_ALT_ONE")
  end
  s.events=s.events+1
  local checked=audit.observe(frozen,packet,g.at)
  if type(checked)~="table" or checked.status=="INCONCLUSIVE" then
   return fail("LASTOFFER_CLIENT_AUDIT_REJECTED")
  end
  if s.events==1 and checked.status~="CLIENT_LASTOFFER_FIRST_EVENT_UNATTRIBUTED" then
   return fail("FIRST_LASTOFFER_CLIENT_EVENT_INVALID")
  end
  if s.events==2 then
   s.equality=checked.status
   if s.equality~="CLIENT_LASTOFFER_CHANGED_WITH_DIFFERENT_OFFER"
     and s.equality~="CLIENT_LASTOFFER_UNCHANGED_WITH_DIFFERENT_OFFER" then
    return fail("SECOND_OFFER_CHANGED_TOKEN_CLASS_UNEXPECTED")
   end
  end
  s.packet=freezePacketQuantities(packet,frozen)
  if not s.packet then return fail("CLIENT_EVENT_QUANTITY_SHAPE_INVALID") end
  s.changedAt=g.at
  s.phase=s.events==1 and "WAIT_FIRST_GUI" or "WAIT_SECOND_GUI"
  return output("WAITING","CLIENT_EVENT_WAIT_PHYSICAL_GUI_CHANGE",s)
 end
 function obj.tick()
  if s.phase=="BLOCKED" then return output("INCONCLUSIVE","OBSERVER_BLOCKED",s) end
  if s.phase=="DONE" then return output("CLIENT_TWO_EVENT_LASTOFFER_GUI_UNATTRIBUTED","LOCAL_ONLY_NO_SERVER_CAUSALITY",s) end
  if s.phase=="NEW" then return fail("BEGIN_REQUIRED") end
  local g,why=capture()
  if not g then return fail(why) end
  if elapsed(g.at) then return fail("CLIENT_WINDOW_EXPIRED") end
  if s.phase=="WAIT_EMPTY_STABLE" then
   if not guiEqual(g,s.first) then return fail("EMPTY_GUI_BASELINE_CHANGED") end
   if g.at-s.started<.15 then return output("WAITING","EMPTY_GUI_SETTLING",s) end
   s.last=g;s.phase="WAIT_FIRST_EVENT"
   return output("WAITING","ALT_MANUAL_ADD_ONE",s)
  end
  if s.phase=="WAIT_FIRST_EVENT" or s.phase=="WAIT_SECOND_EVENT" then
   if not guiEqual(g,s.last) then return fail("GUI_CHANGED_WITHOUT_BOUND_CALLBACK") end
   return output("WAITING",s.phase=="WAIT_FIRST_EVENT" and "ALT_ADD_ONE" or "ALT_REMOVE_ONE",s)
  end
  if g.at-s.changedAt>3 then return fail("POST_CALLBACK_GUI_TIMEOUT") end
  local expected=s.events==1 and 1 or 0
  if #g.our~=0 or #g.their~=expected then
   if guiEqual(g,s.last) then return output("WAITING","AWAITING_GUI_CHANGE",s) end
   return fail("UNEXPECTED_CLIENT_GUI_TRANSITION")
  end
  if not packetFits(s.packet,g) then return fail("CLIENT_PACKET_GUI_QUANTITIES_DISAGREE") end
  if s.after==nil then
   s.after=g
   return output("WAITING","SECOND_STABLE_STAGE9_SAMPLE_PENDING",s)
  end
  if not guiEqual(s.after,g) then return fail("AFTER_GUI_NOT_STABLE") end
  if g.at-s.after.at<.15 then return output("WAITING","AFTER_GUI_SETTLING",s) end
  s.transitions=s.transitions+1
  s.last=g;s.after=nil;s.packet=nil
  if s.events==1 then
   s.phase="WAIT_SECOND_EVENT"
   return output("WAITING","ALT_MANUAL_REMOVE_ONE",s)
  end
  s.phase="DONE";s.complete=true
  pcall(audit.stop)
  return output("CLIENT_TWO_EVENT_LASTOFFER_GUI_UNATTRIBUTED","LOCAL_ONLY_NO_SERVER_CAUSALITY",s)
 end
 function obj.stop()
  s.phase="BLOCKED";s.packet=nil;s.first=nil;s.after=nil;s.last=nil
  pcall(audit.stop)
  return output("STOPPED","OPERATOR_STOPPED",s)
 end
 return obj
end
return M
