-- System2 current-offer Supreme preview. Pure, read-only, no Roblox remotes.
-- The original Stage119 protected host owns all session and GUI references.
-- Does not propose imaginary offers, execute trades or assume server settlement.
local M={}
local SCHEMA="gingerscope-supreme-only-intrade-button-research-v1"
local SOURCE="SUPREME_ONLY"
local function denied(why,display)
 local safeHints={
  GUI_RAW_WEAPON_ID_OR_SLOT_NOT_PROVEN="SUPREME: Weapon IDs unavailable; cannot value safely.",
  ORIGINAL_P4_GUI_CHANGED_DURING_PREVIEW="SUPREME: Offer changed; please preview again.",
  ACCEPT_INDICATOR_ALREADY_ACTIVE="SUPREME: Accept state active. Preview blocked.",
  SUPREME_ONLY_SOURCE_EXPIRED_OR_UNVERIFIED="SUPREME: Source expired; preview blocked.",
  GINGERSCOPE_NEVER_OUTGOING="SUPREME: Gingerscope outgoing blocked.",
 }
 return {schema=SCHEMA,status="BLOCKED",reason=why,
  display=display or safeHints[why] or "SUPREME: Preview blocked. No trade action.",
  valueSource=SOURCE,readOnly=true,researchOnly=true,clientOnly=true,
  authorizesTrade=false,authorizesOffer=false,authorizesAccept=false,
  mayReportProfit=false,mayUseForStrategyLearning=false,
  maySendDiscordWebhook=false}
end
local function key(s)
 return type(s)=="string" and #s>=1 and #s<=90 and
  s:match("^[A-Za-z0-9_]+$")~=nil
end
local function amount(s)
 if type(s)~="string" or #s>20 then return nil end
 if s=="" then return 1 end
 local n=s:gsub("^%s+",""):gsub("%s+$",""):gsub("^[xX]","")
 if #n<1 or #n>7 or not n:match("^%d+$") then return nil end
 local q=tonumber(n)
 return q and q==math.floor(q) and q>=1 and q<=100000 and q or nil
end
local function slots(frame)
 if type(frame)~="table" or frame.status=="BLOCKED" or
   frame.clientOnly~=true or frame.contextOK~=true or
   frame.tradeOpen~=true or frame.rootBound~=true or
   frame.doubleReadStable~=true or
   type(frame.clientRawCaptureSignature)~="string" or
   frame.clientRawCaptureSignature=="" or
   type(frame.ourAccepted)~="boolean" or
   type(frame.theirAccepted)~="boolean" or
   type(frame.ourSlots)~="table" or type(frame.theirSlots)~="table" then
  return nil,"ORIGINAL_P4_FRAME_NOT_BOUND" end
 if frame.ourAccepted or frame.theirAccepted then
  return nil,"ACCEPT_INDICATOR_ALREADY_ACTIVE" end
 local result={}
 for _,side in ipairs({"ourSlots","theirSlots"}) do
  local src=frame[side]
  if #src<1 or #src>4 then
   return nil,"BOTH_PHYSICAL_OFFERS_MUST_BE_NONEMPTY" end
  local gathered={}
  local usedSlots,usedKeys={},{}
  for _,row in ipairs(src) do
   if type(row)~="table" or type(row.slot)~="number" or
      row.slot~=math.floor(row.slot) or row.slot<1 or row.slot>4 or
      usedSlots[row.slot] or
      not key(row.rawId) or row.rawIdObserved~=true or
      usedKeys[row.rawId] or
      type(row.label)~="string" or row.label=="" or
      type(row.chromaTag)~="boolean" then
    return nil,"GUI_RAW_WEAPON_ID_OR_SLOT_NOT_PROVEN" end
   local qty=amount(row.amountText)
   if not qty then return nil,"GUI_STACK_QUANTITY_UNVERIFIED" end
   usedSlots[row.slot]=true
   usedKeys[row.rawId]=true
   gathered[#gathered+1]={id=row.rawId,quantity=qty}
  end
  result[side]=gathered
 end
 for _,own in ipairs(result.ourSlots) do
  if own.id=="Gingerscope" then
   return nil,"GINGERSCOPE_NEVER_OUTGOING" end
 end
 return {kind="HYPOTHETICAL_RESEARCH_ONLY",valueSource=SOURCE,
  give=result.ourSlots,receive=result.theirSlots},nil
end
local function sameFrame(a,b)
 return type(a)=="table" and type(b)=="table" and
  a.clientOnly==b.clientOnly and a.contextOK==b.contextOK and
  a.tradeOpen==b.tradeOpen and a.rootBound==b.rootBound and
  a.doubleReadStable==b.doubleReadStable and
  a.jobId==b.jobId and a.tradeLeaseId==b.tradeLeaseId and
  a.partnerUserId==b.partnerUserId and
  a.clientRawCaptureSignature==b.clientRawCaptureSignature and
  a.ourAccepted==b.ourAccepted and
  a.theirAccepted==b.theirAccepted
end
local function number(x)
 return type(x)=="number" and x==x and x~=math.huge and x~=-math.huge
end
function M.new(cfg)
 if type(cfg)~="table" or type(cfg.isBound)~="function" or
    type(cfg.readFrame)~="function" or type(cfg.evaluate)~="function" then
  return nil,"SUPREME_BUTTON_ORIGINAL_HOST_DEPENDENCIES_INVALID" end
 local obj={}
 function obj.preview()
  local bound,b=pcall(cfg.isBound)
  if not bound or b~=true then
   return denied("ORIGINAL_P3_P4_LEASE_UNAVAILABLE",
    "SUPREME: Waiting for protected trade.") end
  local firstOk,first=pcall(cfg.readFrame)
  if not firstOk or type(first)~="table" then
   return denied("ORIGINAL_P4_GUI_READ_FAILED") end
  local option,reason=slots(first)
  if not option then
   if reason=="BOTH_PHYSICAL_OFFERS_MUST_BE_NONEMPTY" then
    return denied(reason,"SUPREME: Both offers must contain items.") end
   return denied(reason)
  end
  local ok,quote=pcall(cfg.evaluate,{option})
  if not ok or type(quote)~="table" or
    quote.schema~="gingerscope-system2-original-p3p4-supreme-only-adapter-v1" or
    quote.status~="SUPREME_ONLY_PROTECTED_C3_P4_SHADOW_OBSERVED" or
    quote.valueSource~=SOURCE or quote.authorizesTrade~=false or
    quote.authorizesOffer~=false or quote.authorizesAccept~=false or
    quote.mayReportProfit~=false or
    quote.mayUseForStrategyLearning~=false or
    type(quote.hypotheticalAlternatives)~="table" or
    #quote.hypotheticalAlternatives~=1 then
   local why=type(quote)=="table" and quote.reason or nil
   return denied(type(why)=="string" and why or
     "SUPREME_CURRENT_OFFER_SOURCE_OR_EVALUATION_BLOCKED") end
  local finalBound,still=pcall(cfg.isBound)
  if not finalBound or still~=true then
   return denied("ORIGINAL_P3_P4_LEASE_CHANGED_AFTER_EVALUATION") end
  local againOk,again=pcall(cfg.readFrame)
  if not againOk or not sameFrame(first,again) then
   return denied("ORIGINAL_P4_GUI_CHANGED_DURING_PREVIEW") end
  local r=quote.hypotheticalAlternatives[1]
  if type(r)~="table" or
    not number(r.outgoingSupremeListedValue) or
    not number(r.incomingSupremeListedValue) or
    not number(r.supremeListedGain) or
    r.incomingSupremeListedValue-r.outgoingSupremeListedValue~=r.supremeListedGain or
    r.tradeActionable~=false then
   return denied("SUPREME_QUOTE_ECONOMICS_OR_AUTHORITY_INVALID") end
  local text="SUPREME LISTED: "..tostring(r.outgoingSupremeListedValue)..
      " -> "..tostring(r.incomingSupremeListedValue)..
      " ("..(r.supremeListedGain>=0 and "+" or "")..
      tostring(r.supremeListedGain).."). READ ONLY."
  if r.status~="SUPREME_ONLY_PAPER_RESEARCH_NOT_EXECUTABLE" then
   text="SUPREME: "..(r.status=="BLOCKED_UNAPPROVED_SUPREME_LOSS"
     and "Listed loss NOT APPROVED." or "Risk guard BLOCKED preview.")
   -- A rejected route is a BLOCKED status, never a successful quote.
   return denied(r.status,text)
  end
  -- Never expose account, job, partner, lease, raw inventory or item names.
  return {schema=SCHEMA,status="SUPREME_ONLY_CURRENT_OFFER_CLIENT_PREVIEW",
   sourceStatus=r.status,display=text,valueSource=SOURCE,readOnly=true,
   clientOnly=true,researchOnly=true,listedDelta=r.supremeListedGain,
   authorizesTrade=false,authorizesOffer=false,authorizesAccept=false,
   mayReportProfit=false,mayUseForStrategyLearning=false,
   maySendDiscordWebhook=false}
 end
 return obj,nil
end
return M
