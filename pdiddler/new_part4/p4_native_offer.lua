-- Stage22: ONE-SHOT offered-item insertion through an INJECTED native send.
-- Never auto-executes; no default remote lookup, no clicks and no Accept.
-- A separate, source-backed plan permit must have been checked by the pure
-- p4_offer_executor before this module receives the reserved intent.
local M={}
local function visible(root)
 local n=root
 while n do
  if n:IsA("ScreenGui") and n.Enabled~=true then return false end
  if n:IsA("GuiObject") and n.Visible~=true then return false end
  n=n.Parent
 end
 return true
end
local function denied(reason)
 return {status="BLOCKED",attempted=false,reason=reason}
end
local function integer(x,a,b)
 return type(x)=="number" and x==x and x~=math.huge and x~=-math.huge
    and x==math.floor(x) and x>=a and x<=b
end
function M.new(config)
 assert(type(config)=="table" and type(config.observer)=="table"
     and type(config.observer.capture)=="function","bound observer required")
 assert(type(config.handle)=="table" and type(config.handle.config)=="table",
     "bound Stage9 handle required")
 assert(type(config.session)=="string" and config.session~=""
     and config.handle.config.session==config.session,
     "observer session mismatch")
 assert(type(config.ownInventory)=="table"
     and type(config.ownInventory.items)=="table","scanner ownership record required")
 assert(type(config.sendOnce)=="function","native sender must be explicitly injected")
 return {config=config,used={},closed=false}
end
local function owned(c,intent)
 local inv=c.ownInventory
 if inv.unmapped~=0 or inv.badQty~=0 or inv.unpriced~=0 then
  return false end
 local found
 for _,it in ipairs(inv.items) do
  if it.id==intent.id then
   if found then return false end
   found=it
  end
 end
 if not found or found.page~=intent.page
   or found.checkerId~=intent.checkerId
   or found.cat~="Weapons"
   or not (found.type=="Knife" or found.type=="Gun")
   or not integer(found.qty,1,1000000) then
    return false
 end
 return true
end
function M.execute(h,intent)
 assert(type(h)=="table" and type(h.config)=="table","native handle required")
 if h.closed then return denied("session-closed") end
 local c=h.config
 if type(intent)~="table" or intent.kind~="ADD_ONE"
    or intent.session~=c.session or not integer(intent.token,1,1000000)
    or type(intent.id)~="string" or intent.id==""
    or type(intent.page)~="string"
    or type(intent.checkerId)~="string" or not intent.checkerId:match("^%d+$")
    or intent.qty~=1
    or type(intent.ourSig)~="string" or intent.ourSig==""
    or type(intent.theirSig)~="string" or intent.theirSig=="" then
    return denied("invalid-insertion-intent")
 end
 -- At-most-once even if sender throws, rejects, or times out.
 if h.used[intent.token] then return denied("insertion-token-consumed") end
 h.used[intent.token]=true
 if not owned(c,intent) then return denied("item-not-proven-owned") end
 local ok,obs=pcall(c.observer.capture,c.handle)
 if not ok or type(obs)~="table" or obs.tradeOpen~=true then
  return denied("live-observation-unavailable")
 end
 if obs.session~=c.session or obs.contextOK~=true or
    obs.marketFresh~=true or obs.theirResolved~=true
    or obs.ourAccepted~=false or obs.theirAccepted~=false
    or obs.ourSig~=intent.ourSig or obs.theirSig~=intent.theirSig
    or not integer(obs.ourSlots,0,3) or not integer(obs.theirSlots,1,4)
    or type(obs.ownItems)~="table" or #obs.ownItems~=obs.ourSlots then
  return denied("live-offer-or-session-changed")
 end
 for _,row in ipairs(obs.ownItems) do
  if row.id==intent.id then return denied("stack-add-unverified") end
 end
 if not c.handle.config.root or not visible(c.handle.config.root) then
  return denied("bound-trade-root-not-visible")
 end
 -- Sender typically wraps the MM2 OfferItem transport. Callback acceptance
 -- is only that one attempt was dispatched, NEVER server-confirmed placement.
 local sent,ack=pcall(c.sendOnce,intent.id,"Weapons")
 if not sent or ack~=true then
  return {status="ATTEMPT_UNCERTAIN",attempted=true,
    reason="native-transport-unconfirmed"}
 end
 return {status="SENT_ONCE",attempted=true,
   reason="dispatched-not-yet-shown-in-trade"}
end
function M.close(h)
 if type(h)=="table" then h.closed=true end
end
return M
