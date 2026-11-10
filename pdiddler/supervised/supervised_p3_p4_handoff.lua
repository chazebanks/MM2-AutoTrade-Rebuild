-- LIVE P3 -> P4 SUPERVISED HANDOFF: client-only, NO trade actions.
-- Uses the existing P3 scanner/outgoing interface and protected P4 TradeIO.
-- Display names and internal GUI ids are NOT authenticated raw game item IDs.
local M={}
local function deny(reason)
 return {schema="pdiddler-supervised-handoff-v1",
  status="REJECTED",reason=reason,authorizesOffer=false,
  authorizesAccept=false,mayReportProfit=false,
  maySendDiscordWebhook=false,serverCompletionProven=false,
  tradeOutcome="UNKNOWN"}
end
local function safeName(s)
 return type(s)=="string" and #s>=3 and #s<=32
  and s:match("^[%w_]+$")~=nil
end
local function same(a,b)
 return type(a)=="string" and type(b)=="string" and a:lower()==b:lower()
end
local function int(x,max)
 return type(x)=="number" and x==math.floor(x) and x>=1 and x<=max
end
local function protected(s)
 return type(s)=="string" and
  s:lower():gsub("[^%w]",""):find("gingerscope",1,true)~=nil
end
local function visible(root,pg)
 local c,limit=root,0
 while c and c~=pg and limit<20 do
  local ok,v=pcall(function()
   if c:IsA("ScreenGui") then return c.Enabled==true end
   if c:IsA("GuiObject") then return c.Visible==true end
   return true
  end)
  if not ok or v~=true then return false end
  c=c.Parent;limit+=1
 end
 return c==pg
end
local function accepted(t,io)
 local ours=t:FindFirstChild("YourOffer")
 local theirs=t:FindFirstChild("TheirOffer")
 local a=ours and ours:FindFirstChild("Accepted")
 local b=theirs and theirs:FindFirstChild("Accepted")
 if not a or not b or type(a.Visible)~="boolean" or
  type(b.Visible)~="boolean" then return false,"ACCEPT_UNKNOWN" end
 if a.Visible~=false or b.Visible~=false or
  io.acceptedTheir(t)~=false then return false,"ACCEPT_ALREADY_SET" end
 return true,nil
end
local function side(io,t,name)
 local panel=t:FindFirstChild(name)
 local container=panel and panel:FindFirstChild("Container")
 if not container or container.Visible~=true then
  return nil,"SIDE_CONTAINER_MISSING"
 end
 local src=io.readSide(t,name)
 if type(src)~="table" or type(src.slots)~="number"
  or src.slots<0 or src.slots>4 or type(src.entries)~="table" then
  return nil,"UNREADABLE_SIDE"
 end
 local physical=0
 for i=1,4 do
  local n=container:FindFirstChild("NewItem"..i)
  if n and n.Visible==true then physical+=1 end
 end
 for i=5,8 do
  local n=container:FindFirstChild("NewItem"..i)
  if n and n.Visible==true then
   return nil,"MORE_THAN_FOUR_PHYSICAL_SLOTS"
  end
 end
 if physical~=src.slots or physical~=#src.entries then
  return nil,"PHYSICAL_GUI_SLOTS_NOT_RECONCILED"
 end
 local out,seen={},{}
 for _,e in ipairs(src.entries) do
  if not int(e.index,4) or seen[e.index] or
   type(e.shown)~="string" or e.shown=="" or
   type(e.isChroma)~="boolean" or not int(e.qty,1000000) then
   return nil,"INVALID_GUI_SLOT_OR_STACK"
  end
  seen[e.index]=true
  if name=="YourOffer" and
    (protected(e.shown) or protected(e.internalId)) then
   return nil,"PROTECTED_GINGERSCOPE_IN_OWN_OFFER"
  end
  out[#out+1]={physicalSlot=e.index,quantity=e.qty,
   displayCandidate=e.shown,chromaCandidate=e.isChroma,
   internalIdCandidate=e.internalId,rawItemIdAuthenticated=false}
 end
 return out,nil
end

-- This binds one existing paused P3 request/session to one visible P4 trade.
-- The getters must return LIVE game JobId and P3 epoch, not cached values.
-- This proves neither the origin of the P3 request nor any game settlement.
function M.bind(scanner,outgoing,io,players,me,ctx)
 if type(scanner)~="table" or type(scanner.getRecord)~="function"
  or type(scanner.isWhitelisted)~="function" or
  type(outgoing)~="table" or type(outgoing.session)~="number"
  or type(outgoing.isPaused)~="function" or
  type(outgoing.resume)~="function" or type(io)~="table"
  or type(io.trade)~="function" or type(io.readSide)~="function"
  or type(io.sideSignature)~="function"
  or type(io.partnerName)~="function"
  or type(io.acceptedTheir)~="function"
  or (type(players)~="table" and type(players)~="userdata")
  or type(ctx)~="table" or not safeName(ctx.targetName)
  or type(ctx.getJobId)~="function"
  or type(ctx.getP3Session)~="function" then
  return nil,deny("HANDOFF_DEPENDENCIES_INVALID")
 end
 local pg=me and me:FindFirstChildOfClass("PlayerGui")
 local target=players:FindFirstChild(ctx.targetName)
 local job,epoch=ctx.getJobId(),ctx.getP3Session()
 if not pg or not target or target==me or target.Parent~=players
  or type(job)~="string" or job==""
  or type(epoch)~="number" or epoch~=outgoing.session then
  return nil,deny("PARTNER_JOB_OR_EPOCH_UNAVAILABLE")
 end
 local session={root=nil,closed=false}
 local function current()
  if session.closed then return nil,"HANDOFF_RELEASED" end
  if ctx.getJobId()~=job or ctx.getP3Session()~=epoch
   or outgoing.session~=epoch then return nil,"JOB_OR_EPOCH_CHANGED" end
  if me:FindFirstChildOfClass("PlayerGui")~=pg then
   return nil,"PLAYER_GUI_CHANGED"
  end
  if target.Parent~=players or
   players:FindFirstChild(ctx.targetName)~=target then
   return nil,"PARTNER_LEFT_OR_REPLACED"
  end
  if scanner.isWhitelisted(target.UserId)~=true then
   return nil,"PART3_CONTACT_NOT_ELIGIBLE"
  end
  local rec=scanner.getRecord(target.UserId)
  if type(rec)~="table" or rec.player~=target
   or rec.state~="whitelist" then
   return nil,"PART3_SCANNER_RECORD_CHANGED"
  end
  if outgoing.isPaused()~=true then return nil,"PART3_NOT_PAUSED" end
  local t=io.trade()
  if not t or not visible(t,pg) then return nil,"NO_VISIBLE_TRADE" end
  if session.root and session.root~=t then
   return nil,"TRADE_ROOT_CHANGED"
  end
  if not same(io.partnerName(t),target.Name) then
   return nil,"TRADE_PARTNER_WRONG_OR_AMBIGUOUS"
  end
  return t,nil
 end
 local trade,reason=current()
 if not trade then return nil,deny(reason) end
 session.root=trade
 local bound={}
 function bound.capture()
  local t,why=current()
  if not t then return deny(why) end
  local ok,whyAccept=accepted(t,io)
  if not ok then return deny(whyAccept) end
  local leftBefore=io.sideSignature(io.readSide(t,"YourOffer"))
  local rightBefore=io.sideSignature(io.readSide(t,"TheirOffer"))
  if type(leftBefore)~="string" or type(rightBefore)~="string" then
   return deny("OFFER_SIGNATURE_MISSING")
  end
  local ours,ourWhy=side(io,t,"YourOffer")
  if not ours then return deny(ourWhy) end
  local theirs,theirWhy=side(io,t,"TheirOffer")
  if not theirs then return deny(theirWhy) end
  local leftAfter=io.sideSignature(io.readSide(t,"YourOffer"))
  local rightAfter=io.sideSignature(io.readSide(t,"TheirOffer"))
  local t2,why2=current()
  if t2~=t then return deny(why2 or "TRADE_CHANGED") end
  local ok2,why3=accepted(t,io)
  if not ok2 then return deny(why3) end
  if leftBefore~=leftAfter or rightBefore~=rightAfter then
   return deny("OFFER_CHANGED_DURING_CAPTURE")
  end
  return {schema="pdiddler-supervised-handoff-v1",
   status="CLIENT_UNPRICED_TWO_SIDED_SNAPSHOT",
   ours=ours,theirs=theirs, -- PRIVATE; never print unredacted
   physicalOwnSlots=#ours,physicalTheirSlots=#theirs,
   partnerExactClientBound=true,part3Paused=true,
   part4TradeVisible=true,requestOriginBound=false,
   rawItemIdsAuthenticated=false,pricesAuthenticated=false,
   offerRevisionAuthenticated=false,
   authorizesOffer=false,authorizesAccept=false,
   mayReportProfit=false,maySendDiscordWebhook=false,
   serverCompletionProven=false,tradeOutcome="UNKNOWN"}
 end
 function bound.resumeAfterClose()
  if session.closed then return false,"HANDOFF_ALREADY_RELEASED" end
  if ctx.getJobId()~=job or ctx.getP3Session()~=epoch
   or outgoing.session~=epoch then
   return false,"JOB_OR_EPOCH_CHANGED"
  end
  if io.trade()~=nil then return false,"TRADE_STILL_OPEN" end
  local ok,why=outgoing.resume("supervised-trade-closed")
  if ok~=true then return false,tostring(why or "P3_RESUME_DENIED") end
  session.closed=true
  return true,"P3_RESUMED_CLIENT_ONLY"
 end
 function bound.status()
  return {status=session.closed and "HANDOFF_RELEASED" or
   "CLIENT_P3_P4_HANDOFF_BOUND_UNPRICED",
   authorizesOffer=false,authorizesAccept=false,tradeOutcome="UNKNOWN"}
 end
 return bound,nil
end
return M
