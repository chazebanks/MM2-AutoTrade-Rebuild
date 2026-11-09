-- Stage71 read-only preview: distinguish CLIENT INVENTORY OBSERVATION from
-- SUPREME MARKET PRICE VERIFICATION and RAW->CHECKER ID identity proof.
-- Never equate a recognized weapon with a verified economic quote.
local M={}
local function integer(x)
 return type(x)=="number" and x==x
   and x~=math.huge and x~=-math.huge
   and x==math.floor(x) and x>=0 and x<=1000000
end
local function clean(x,limit)
 if type(x)~="string" or x=="" then return "UNAVAILABLE" end
 local s=x:gsub("[%c]"," "):gsub("%s+"," ")
 s=s:gsub("^%s+",""):gsub("%s+$","")
 if #s==0 then return "UNAVAILABLE" end
 limit=limit or 70
 if #s>limit then s=s:sub(1,limit).."...(truncated)" end
 return s
end
local function init()
 return {
  schema="gingerscope-stage71-inventory-price-confidence-v1",
  readOnly=true,tradeOutcome="UNKNOWN",
  inventoryState="UNAVAILABLE",
  itemCountKnown=false,itemCount=nil,
  itemRowsObserved=0,
  priceState="UNVERIFIED_SOURCE_OR_MAPPING",
  rawCheckerIdentityState="UNREVIEWED",
  publisherStamp="UNAVAILABLE",
  marketValuesShown=false,
  authoritativeTotal=nil,
  representativeItems={},
  authorizesTrade=false,authorizesAccept=false,
  mayUseForStrategyLearning=false,maySendDiscordWebhook=false,
  mayReportProfit=false,mayRecordCompletedTrade=false,
  mayRecordRejectedTrade=false,
  text=""
 }
end
function M.describe(inv,profile,proofGate)
 local r=init()
 local available=type(inv)=="table" and type(inv.items)=="table"
 local observedCount=0
 local shape=available
 local items=available and inv.items or {}
 local rowCount=0
 if available then
  for k,v in pairs(items) do
   if type(k)~="number" or k<1 or k>10000
      or k~=math.floor(k) or type(v)~="table" then
    shape=false
   else rowCount=rowCount+1 end
  end
  if rowCount>10000 then shape=false end
  for i=1,rowCount do
   if type(items[i])~="table" then shape=false end
  end
 end
 r.itemRowsObserved=rowCount
 local records={}
 local rawSeen={}
 if shape then
  for _,it in ipairs(items) do
   if type(it.id)~="string" or it.id==""
     or rawSeen[it.id]
     or it.cat~="Weapons"
     or not integer(it.qty) or it.qty==0
     or (it.type~="Knife" and it.type~="Gun") then
    shape=false
    break
   end
   rawSeen[it.id]=true
   observedCount=observedCount+it.qty
   if observedCount>1000000 then shape=false;break end
   if #records<40 then
    local name=clean(it.name or it.id,60)
    records[#records+1]=name.." x"..tostring(it.qty).." [price UNVERIFIED]"
   end
  end
 end
 local census=available and type(inv.unmapped)=="number"
   and type(inv.badQty)=="number" and type(inv.unpriced)=="number"
   and integer(inv.unmapped) and integer(inv.badQty) and integer(inv.unpriced)
 if not census or inv.unmapped~=0 or inv.badQty~=0 then
  shape=false
 end
 r.inventoryState=not available and "UNAVAILABLE"
   or shape and "CLIENT_ELIGIBLE_ITEMS_OBSERVED"
   or "PARTIAL_CLIENT_INVENTORY"
 if shape then
  r.itemCountKnown=true
  r.itemCount=observedCount
  r.representativeItems=records
 end
 local sourceStamp=type(profile)=="table"
   and (profile.publishedAt or profile.sourceTimestamp or profile.supremeUpdated)
   or nil
 r.publisherStamp=clean(sourceStamp,48)
 local proofStatus="MISSING_PROOF_GATE"
 local sourceFresh=false
 if type(proofGate)=="table" and type(proofGate.evaluate)=="function" then
  local ok,v=pcall(proofGate.evaluate,inv,profile)
  if ok and type(v)=="table"
    and v.schema=="gingerscope-stage70-raw-checker-proof-gate-v1"
    and v.authorizesTrade==false and v.authorizesAccept==false
    and v.numericTradingAuthority==false
    and v.rawCheckerCrosswalkProven==false then
   proofStatus=v.status
   sourceFresh=v.sourceFresh==true
  end
 end
 if proofStatus=="MISSING_PROOF_GATE" then
  r.priceState="SOURCE_AND_ITEM_ID_NOT_VALIDATED"
 elseif not sourceFresh then
  r.priceState="SUPREME_SOURCE_EXPIRED_OR_UNTRUSTED"
 else
  r.priceState="SUPREME_SOURCE_CURRENT_RAW_ID_UNREVIEWED"
 end
 -- Even if a future Stage70 review-only proof gate reports static reviewed
 -- rows, this UI NEVER elevates them into live economic/trade authority.
 r.rawCheckerIdentityState="UNREVIEWED_FOR_LIVE_TRADING"
 local invText=r.inventoryState=="CLIENT_ELIGIBLE_ITEMS_OBSERVED"
   and ("CLIENT-OBSERVED eligible weapon copies: "..tostring(r.itemCount))
   or r.inventoryState=="PARTIAL_CLIENT_INVENTORY"
   and "Client inventory: PARTIAL; item quantities not trustworthy"
   or "Client inventory: UNAVAILABLE"
 local priceText=not sourceFresh and
   "Supreme quote: UNVERIFIED (source expired/untrusted or provenance missing)"
   or "Supreme quote: UNVERIFIED (raw item-to-checker ID not independently reviewed)"
 if proofStatus=="MISSING_PROOF_GATE" then
  priceText="Supreme quote: UNVERIFIED (source+ID proof guard unavailable)"
 end
 local seenItems=#r.representativeItems>0
    and table.concat(r.representativeItems,", ")
    or "No safely readable eligible weapon rows"
 if #records==40 and rowCount>40 then
  seenItems=seenItems..", ...additional weapon rows omitted"
 end
 r.text=invText.."\n"
   ..priceText.."\n"
   .."Supreme publisher timestamp: "..r.publisherStamp.."\n"
   .."Raw item-to-Supreme checker identity: UNREVIEWED for live pricing\n"
   .."Displayed weapons: "..seenItems.."\n"
   .."Total verified value: UNVERIFIED (not 0)\n"
   .."Outgoing: PAUSED | Auto Accept: DISABLED | Discord learning: DISABLED"
 return r
end
return M
