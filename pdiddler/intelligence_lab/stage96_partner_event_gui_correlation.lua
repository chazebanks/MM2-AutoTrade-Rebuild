-- Stage96: pure, RESEARCH-ONLY client UpdateTrade partner tuple vs Stage9 GUI.
-- Complements proven native Stage43/44 OWN Batwing and Stage93 ALT GUI addition.
-- No Roblox API, no listeners, remotes, price, offer placement, Accept, hop or webhook.
-- A same-shaped delayed client callback cannot be server-session authenticated.
local M={}
local typ,rawget,next,getmetatable,rawequal=type,rawget,next,getmetatable,rawequal
local ROOT={LastOffer=true,Locked=true,Player1=true,Player2=true}
local SIDE={Player=true,Accepted=true,Offer=true}
local PACK={n=true,[1]=true}
local ONE={[1]=true}
local EMPTY={}
local TRIPLE={[1]=true,[2]=true,[3]=true}
local function exact(t,keys,cap)
 if typ(t)~="table" or getmetatable(t)~=nil then return false end
 local n=0
 for k in next,t do
  n=n+1
  if n>cap or keys[k]~=true then return false end
 end
 for k in next,keys do if rawget(t,k)==nil then return false end end
 return true
end
local function int(n,lo,hi)
 return typ(n)=="number" and n==n and n~=math.huge and n~=-math.huge
   and n==math.floor(n) and n>=lo and n<=hi
end
local function finite(n)
 return typ(n)=="number" and n==n and n~=math.huge and n~=-math.huge
end
local function clean(s)
 if typ(s)~="string" or #s==0 or #s>128 or s:find("[%c]") then return nil end
 return s:gsub("^%s+",""):gsub("%s+$",""):gsub("%s+"," "):lower()
end
local function report()
 return {
  schema="gingerscope-stage96-partner-event-gui-correlation-research-v1",
  status="INCONCLUSIVE",reason="NOT_TESTED",readOnly=true,clientOnly=true,
  eventCountObserved=0,partnerEventTupleObserved=false,
  sameClientPlayerReferencesMatched=false,
  oneVisiblePartnerGuiSlotMatched=false,guiStableTwoSamples=false,
  clientEventRawTextMatchesGuiRawText=false,
  clientGuiNameOnlyUnbound=false,clientQuantityCompared=false,
  clientPublicNameVariantMatched=false,
  clientEventLastOfferNumericObserved=false,
  physicalGuiRootStillBound=false,proposedRawKeyIsPrivate=true,
  eventSessionAssociationProven=false,
  callbackCausalityProven=false,ownerSideSlotBound=false,
  rawItemIdConfirmed=false,uniqueWeaponInstanceProven=false,
  authenticatedOwnedInventory=false,currentGameCatalogueAuthenticated=false,
  sourcePublisherFresh=false,currentPricesVerified=false,
  priceForTradeVerified=false,numericSupremeCheckerIdVerified=false,
  serverAttestation=false,serverCompletionProven=false,
  authorizesTrade=false,authorizesAccept=false,
  mayRecordCompletedTrade=false,mayReportProfit=false,
  maySendDiscordWebhook=false,mayUseForStrategyLearning=false,
  tradeOutcome="UNKNOWN",
 }
end
local function fail(o,why)
 o.reason=why
 return o
end
local function validScope(c)
 return typ(c)=="table" and typ(c.session)=="string" and
    #c.session>0 and #c.session<=180 and
    typ(c.jobId)=="string" and #c.jobId>0 and #c.jobId<=180 and
    c.root~=nil and c.localPlayer~=nil and c.partnerPlayer~=nil
    and not rawequal(c.localPlayer,c.partnerPlayer)
end
local function view(v,scope)
 if typ(v)~="table" or not finite(v.at) or v.at<0
    or not rawequal(v.root,scope.root)
    or v.jobId~=scope.jobId or v.session~=scope.session
    or not rawequal(v.localPlayer,scope.localPlayer)
    or not rawequal(v.partnerPlayer,scope.partnerPlayer) then
  return nil,"GUI_VIEW_SCOPE_CHANGED"
 end
 local raw=v.raw
 if typ(raw)~="table" or raw.tradeOpen~=true
    or raw.contextOK~=true or raw.session~=scope.session
    or typ(raw.our)~="table" or raw.our.complete~=true
    or typ(raw.their)~="table" or raw.their.complete~=true
    or raw.our.accepted~=false or raw.their.accepted~=false
    or typ(raw.our.slots)~="table" or typ(raw.their.slots)~="table"
    or #raw.our.slots>4 or #raw.their.slots>4 then
  return nil,"GUI_VIEW_INCOMPLETE_OR_ACCEPTED"
 end
 return raw
end
local function eventPair(packed,localPlayer,partnerPlayer)
 if not exact(packed,PACK,2) or rawget(packed,"n")~=1 then
  return nil,"EVENT_PACK_INVALID"
 end
 local root=rawget(packed,1)
 if not exact(root,ROOT,4) or not finite(rawget(root,"LastOffer"))
    or typ(rawget(root,"Locked"))~="boolean"
    or rawget(root,"Locked")~=false then
  return nil,"EVENT_ROOT_UNVERIFIED"
 end
 local p1,p2=rawget(root,"Player1"),rawget(root,"Player2")
 if not exact(p1,SIDE,3) or not exact(p2,SIDE,3) then
  return nil,"EVENT_PLAYER_SIDE_SCHEMA_INVALID"
 end
 local first=rawequal(rawget(p1,"Player"),localPlayer)
    and rawequal(rawget(p2,"Player"),partnerPlayer)
 local second=rawequal(rawget(p2,"Player"),localPlayer)
    and rawequal(rawget(p1,"Player"),partnerPlayer)
 if first==second then return nil,"EVENT_PLAYER_REFERENCE_NOT_UNIQUE" end
 if rawget(p1,"Accepted")~=false or rawget(p2,"Accepted")~=false then
  return nil,"EVENT_ACCEPTED_OR_AMBIGUOUS"
 end
 local ours=first and p1 or p2
 local theirs=first and p2 or p1
 if not exact(rawget(ours,"Offer"),EMPTY,0) then
  return nil,"EVENT_OWN_OFFER_NOT_EMPTY"
 end
 local offer=rawget(theirs,"Offer")
 if not exact(offer,ONE,1) then return nil,"EVENT_PARTNER_OFFER_NOT_ONE_ROW" end
 local triple=rawget(offer,1)
 if not exact(triple,TRIPLE,3) then return nil,"EVENT_PARTNER_TUPLE_SHAPE_INVALID" end
 local rawKey,qty,cat=rawget(triple,1),rawget(triple,2),rawget(triple,3)
 if typ(rawKey)~="string" or #rawKey==0 or #rawKey>128
    or rawKey:find("[%c]") or not int(qty,1,4) or cat~="Weapons" then
  return nil,"EVENT_PARTNER_KEY_QUANTITY_CATEGORY_INVALID"
 end
 return {key=rawKey,qty=qty}
end
local function expectedGuiName(ref)
 local name=clean(ref[1])
 if not name then return nil end
 return ref[4] and ("chroma "..name) or name
end
local function guiName(slot)
 local name=clean(slot.label)
 if not name then return nil end
 return slot.chroma and name:sub(1,7)~="chroma " and
     ("chroma "..name) or name
end
local function samePhysical(a,b)
 return typ(a)=="table" and typ(b)=="table" and
    a.slot==b.slot and a.rawId==b.rawId and a.label==b.label
    and a.chroma==b.chroma and a.amountText==b.amountText
end
-- No copied key, item name, or player information in the return object.
-- This comparison is a CLIENT CONSISTENCY observation, NOT a slot binding
-- or proof that UpdateTrade belongs to the currently visible server trade.
function M.inspect(input,catalogue,registry,originalStage9,stage95)
 local o=report()
 if typ(input)~="table" or not validScope(input.scope) then
  return fail(o,"CALLER_SCOPE_INVALID")
 end
 local scope=input.scope
 if not originalStage9 or typ(originalStage9.parseQuantity)~="function"
    or not stage95 or typ(stage95.inspect)~="function" then
  return fail(o,"ORIGINAL_OBSERVER_MODULES_MISSING")
 end
 if typ(input.eventCount)~="number" or input.eventCount~=1 then
  return fail(o,"EVENT_COUNT_NOT_EXACTLY_ONE")
 end
 o.eventCountObserved=1
 local before,why=view(input.before,scope)
 if not before then return fail(o,why) end
 local after1,why1=view(input.after1,scope)
 if not after1 then return fail(o,why1) end
 local after2,why2=view(input.after2,scope)
 if not after2 then return fail(o,why2) end
 local receipt=input.receipt
 if typ(receipt)~="table" or receipt.jobId~=scope.jobId
   or receipt.session~=scope.session
   or not rawequal(receipt.root,scope.root)
   or not rawequal(receipt.localPlayer,scope.localPlayer)
   or not rawequal(receipt.partnerPlayer,scope.partnerPlayer)
   or not finite(receipt.at) or receipt.at<0 then
  return fail(o,"CALLBACK_CONTEXT_SCOPE_CHANGED")
 end
 -- Delayed/replayed callbacks can still satisfy local timing and visibility.
 -- This only filters obvious older/duplicate/out-of-order observations.
 if not (input.before.at<receipt.at and receipt.at<=input.after1.at
   and input.after1.at<input.after2.at
   and receipt.at-input.before.at<=3
   and input.after1.at-receipt.at<=3
   and input.after2.at-input.after1.at>=.15
   and input.after2.at-input.after1.at<=1) then
  return fail(o,"CALLBACK_GUI_TIMING_NOT_BOUNDED")
 end
 if #before.our.slots~=0 or #before.their.slots~=0
   or #after1.our.slots~=0 or #after2.our.slots~=0
   or #after1.their.slots~=1 or #after2.their.slots~=1 then
  return fail(o,"NOT_EMPTY_TO_SINGLE_PARTNER_GUI_TRANSITION")
 end
 local event,evReason=eventPair(receipt.packed,scope.localPlayer,scope.partnerPlayer)
 if not event then return fail(o,evReason) end
 o.clientEventLastOfferNumericObserved=true
 o.sameClientPlayerReferencesMatched=true
 o.partnerEventTupleObserved=true
 local slot1,slot2=after1.their.slots[1],after2.their.slots[1]
 if not samePhysical(slot1,slot2) or not int(slot1.slot,1,4)
   or typ(slot1.chroma)~="boolean" then
  return fail(o,"PHYSICAL_PARTNER_GUI_SLOT_UNSTABLE")
 end
 o.guiStableTwoSamples=true
 local qty=originalStage9.parseQuantity(slot1.amountText)
 if not int(qty,1,4) or qty~=event.qty then
  return fail(o,"GUI_AND_CLIENT_EVENT_QUANTITY_DISAGREE")
 end
 o.clientQuantityCompared=true
 local p4=stage95.inspect(after2,catalogue,registry,originalStage9.parseQuantity)
 if typ(p4)~="table" or p4.exactCurrentPlayerBound~=true or
    p4.rejectedSlotCount~=0 or
    not (p4.status=="CLIENT_DISPLAY_ONLY_UNBOUND" or
         p4.status=="CLIENT_GUI_PUBLIC_REFERENCE_CANDIDATES_ONLY") then
  return fail(o,"STAGE95_PHYSICAL_OFFER_NOT_CANDIDATE")
 end
 local ref=typ(registry)=="table" and
     typ(registry.entries)=="table" and rawget(registry.entries,event.key)
 local meta=typ(catalogue)=="table" and rawget(catalogue,event.key)
 if typ(ref)~="table" or typ(meta)~="table" or
    rawget(meta,"ItemName")~=ref[1] or
    rawget(meta,"ItemType")~=ref[2] or
    rawget(meta,"Rarity")~=ref[3] or
    (rawget(meta,"Chroma")==true)~=ref[4] or
    (rawget(meta,"Chroma")~=nil and typ(rawget(meta,"Chroma"))~="boolean") then
  return fail(o,"CALLBACK_RAW_KEY_NOT_SAME_CURRENT_PUBLIC_CATALOGUE")
 end
 if slot1.chroma~=ref[4] or guiName(slot1)~=expectedGuiName(ref) then
  return fail(o,"EVENT_KEY_AND_GUI_DISPLAY_VARIANT_DISAGREE")
 end
 o.clientPublicNameVariantMatched=true
 if slot1.rawId~=nil and slot1.rawId~="" then
  if typ(slot1.rawId)~="string" or slot1.rawId~=event.key then
   return fail(o,"PHYSICAL_RAW_TEXT_DISAGREES_WITH_EVENT")
  end
  o.clientEventRawTextMatchesGuiRawText=true
 elseif slot1.rawId==nil or slot1.rawId=="" then
  o.clientGuiNameOnlyUnbound=true
 else
  return fail(o,"PHYSICAL_RAW_TEXT_TYPE_INVALID")
 end
 o.oneVisiblePartnerGuiSlotMatched=true
 o.physicalGuiRootStillBound=true
 -- Critically, no 'rawItemIdConfirmed' / 'ownerSideSlotBound' privilege:
 -- event payload is client-origin, not signed with a server trade nonce.
 o.status=o.clientEventRawTextMatchesGuiRawText and
    "CLIENT_PARTNER_EVENT_GUI_RAW_TEXT_CONSISTENT_UNATTRIBUTED" or
    "CLIENT_PARTNER_EVENT_GUI_NAME_QTY_CONSISTENT_UNATTRIBUTED"
 o.reason="CLIENT_CALLBACK_AND_GUI_SHAPE_CONSISTENT_NOT_SERVER_CAUSALITY"
 return o
end
return M
