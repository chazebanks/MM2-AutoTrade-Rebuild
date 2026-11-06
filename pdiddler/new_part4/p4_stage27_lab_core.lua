-- Stage27 controlled Delta experiment state machine.
-- Only explicit operator ADD and REMOVE calls may dispatch one native action.
-- Uses the already-tested Stage22 ADD and Stage10 REMOVE ledgers.
-- No trade completion, Accept, Decline, outbound trade requests or hopping.
local M={}
local function fail(s,reason)
 s.phase="MANUAL_RECOVERY"
 s.reason=reason
 s.permitActive=false
 return "STOP",reason
end
local function capture(s)
 local ok,o,diag=pcall(s.observer.capture,s.handle)
 if not ok or type(o)~="table" then return nil,"observer-unavailable" end
 if o.tradeOpen~=true or o.session~=s.session or o.contextOK~=true
  or o.ourAccepted~=false or o.theirAccepted~=false then
  return nil,"trade-session-or-acceptance-unsafe" end
 return o,diag
end
function M.new(config)
 assert(type(config)=="table" and type(config.session)=="string"
   and config.session~="" and config.observer and config.handle
   and config.handle.config
   and config.handle.config.session==config.session,
   "session-bound Stage9 capture required")
 for _,name in ipairs({"offerCore","offerNative","removeCore","removeNative"}) do
  assert(type(config[name])=="table","missing "..name) end
 assert(type(config.clock)=="function" and
   type(config.item)=="table" and type(config.item.id)=="string"
   and config.item.id~="" and type(config.item.checkerId)=="string"
   and config.item.checkerId:match("^%d+$")
   and (config.item.page=="godly" or config.item.page=="chroma"
    or config.item.page=="ancient"),"exact item and clock required")
 local s={session=config.session,observer=config.observer,
    handle=config.handle,clock=config.clock,item=config.item,
    offerCore=config.offerCore,offerNative=config.offerNative,
    removeCore=config.removeCore,removeNative=config.removeNative,
    phase="READY_ADD",reason="manual-one-item-test",
    addAttempted=false,addVerified=false,
    removeAttempted=false,removeVerified=false,
    permitActive=false,permitIssuedAt=nil,
    authorizesAccept=false,serverCompletionProven=false}
 return s
end
function M.validateManualPermit(s,proposal,o,now)
 return s.phase=="ADDING" and s.permitActive==true
    and s.addAttempted==true and
    proposal.session==s.session
    and proposal.id==s.item.id
    and proposal.page==s.item.page
    and proposal.checkerId==s.item.checkerId
    and proposal.qty==1 and proposal.ourSig==o.ourSig
    and proposal.theirSig==o.theirSig
    and s.permitIssuedAt and now>=s.permitIssuedAt
    and now-s.permitIssuedAt<=0.35
    and o.contextOK==true and o.marketFresh==true
    and o.ourSlots==0 and o.theirSlots>=1
    and o.theirResolved==true
    and o.ourAccepted==false and o.theirAccepted==false
end
function M.add(s)
 if s.phase~="READY_ADD" or s.addAttempted then
  return "HOLD","add-not-operator-ready" end
 s.addAttempted=true -- reserved before observing, never retry a lost attempt
 local o,why=capture(s)
 if not o then return fail(s,"add-"+why) end
 if o.ourSlots~=0 or o.theirSlots<1 or o.theirResolved~=true
   or o.marketFresh~=true then
  return fail(s,"add-source-or-offer-not-ready") end
 local ok,now=pcall(s.clock)
 if not ok or type(now)~="number" then return fail(s,"clock-failed") end
 s.phase="ADDING";s.permitActive=true;s.permitIssuedAt=now
 local proposal={session=s.session,id=s.item.id,page=s.item.page,
  checkerId=s.item.checkerId,qty=1,
  ourSig=o.ourSig,theirSig=o.theirSig}
 local action,intent=s.offerCore.prepare(s.offerState,proposal,o,now)
 s.permitActive=false
 if action~="DISPATCH" then return fail(s,"add-hold:"..tostring(intent)) end
 local okay,receipt=pcall(s.offerNative.execute,s.offerHandle,intent)
 if not okay or type(receipt)~="table" then
  return fail(s,"add-native-exception") end
 local later=s.clock()
 local status,reason=s.offerCore.dispatched(s.offerState,intent,receipt,later)
 if status~="WAIT" then return fail(s,"add-not-dispatched:"..tostring(reason)) end
 s.phase="VERIFY_ADD"
 s.reason="one-native-add-attempt;verify-by-GUI"
 return "WAIT",s.reason
end
function M.remove(s)
 if s.phase~="READY_REMOVE" or s.removeAttempted then
  return "HOLD","removal-not-operator-ready" end
 s.removeAttempted=true -- never click twice on uncertain UI action
 local o,why=capture(s)
 if not o then return fail(s,"remove-"+why) end
 if o.ourSlots~=1 or type(o.ownItems)~="table"
  or #o.ownItems~=1 or o.ownItems[1].id~=s.item.id
  or o.ownItems[1].qty~=1 then
  return fail(s,"remove-unexpected-local-item") end
 local now=s.clock()
 s.phase="REMOVING"
 local action,intent=s.removeCore.prepare(s.removeState,"REMOVE_ONE",o,now)
 if action~="DISPATCH" then return fail(s,"remove-hold:"..tostring(intent)) end
 if intent.id~=s.item.id or intent.qty~=1 then
  return fail(s,"remove-wrong-command") end
 local okay,receipt=pcall(s.removeNative.execute,s.removeHandle,intent)
 if not okay or type(receipt)~="table" then
  return fail(s,"remove-native-exception") end
 local later=s.clock()
 local status,reason=s.removeCore.dispatched(s.removeState,intent,receipt,later)
 if status~="WAIT" then return fail(s,"remove-not-dispatched:"..tostring(reason)) end
 s.phase="VERIFY_REMOVE";s.reason="one-physical-click-attempt;verify-by-GUI"
 return "WAIT",s.reason
end
function M.poll(s)
 if s.phase~="VERIFY_ADD" and s.phase~="VERIFY_REMOVE" then
   return "HOLD",s.reason end
 local o,why=capture(s)
 if not o then return fail(s,"verify-"+why) end
 local now=s.clock()
 if s.phase=="VERIFY_ADD" then
  local action,reason=s.offerCore.observe(s.offerState,o,now)
  if action=="VERIFIED" then
    if o.ourSlots~=1 or #o.ownItems~=1
      or o.ownItems[1].id~=s.item.id or o.ownItems[1].qty~=1 then
      return fail(s,"add-extra-or-mismatched-weapon") end
    s.addVerified=true;s.phase="READY_REMOVE"
    s.reason="add-verified;operator-remove-required"
    return "VERIFIED",s.reason
  end
  if action=="STOP" or action=="ESCALATE" then
    return fail(s,"add-"+tostring(reason)) end
  return "HOLD",reason
 end
 local action,reason=s.removeCore.observe(s.removeState,o,now)
 if action=="VERIFIED" then
  if o.ourSlots~=0 or #o.ownItems~=0 then
    return fail(s,"remove-extra-weapon-in-offer") end
  s.removeVerified=true;s.phase="DONE"
  s.reason="add-and-remove-confirmed-from-distinct-GUI-polls"
  return "VERIFIED",s.reason
 end
 if action=="STOP" or action=="ESCALATE" then
  return fail(s,"remove-"+tostring(reason)) end
 return "HOLD",reason
end
function M.stop(s)
 if not s or s.phase=="DONE" then return end
 s.phase="MANUAL_RECOVERY";s.reason="operator-stopped"
 s.permitActive=false
end
function M.report(s)
 return {schema="gingerscope-stage27-controlled-native-lab-v1",
    status=s.phase,reason=s.reason,
    addAttempted=s.addAttempted,addVerified=s.addVerified,
    removeAttempted=s.removeAttempted,removeVerified=s.removeVerified,
    itemPrice=s.item.price,marketFresh=s.marketFresh==true,
    authorizesAccept=false,serverCompletionProven=false}
end
return M
