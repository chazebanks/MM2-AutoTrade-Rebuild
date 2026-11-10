-- Stage95: client-only bridge for existing Stage9 physical offer snapshots.
-- Reuses Stage83 exact historical PUBLIC raw-key/canonical variant registry.
-- Does NOT infer that a GUI label alone identifies a weapon, that a
-- client-visible attribute is server-attested, or that the user owns a slot.
-- NO market pricing, offer/Accept, remotes, mutable GUI, Discord, or hops.
local M={}
local typ,rawget,next,getmetatable=type,rawget,next,getmetatable
local SCHEMA="gingerscope-stage95-physical-slot-public-reference-boundary-v1"
local function clean(s)
 if typ(s)~="string" then return nil end
 if #s<1 or #s>128 or s:find("[%c]") then return nil end
 return s:gsub("^%s+",""):gsub("%s+$",""):gsub("%s+"," "):lower()
end
local function int(n,a,b)
 return typ(n)=="number" and n==n and n~=math.huge and n~=-math.huge
  and n==math.floor(n) and n>=a and n<=b
end
local function base()
 return {
  schema=SCHEMA,status="INCONCLUSIVE",reason="UNTESTED",
  readOnly=true,clientOnly=true,tradeOutcome="UNKNOWN",
  exactCurrentPlayerBound=false,clientGuiOfferObserved=false,
  clientRawKeyCandidateCount=0,nameOnlyUnboundCount=0,
  rejectedSlotCount=0,ourGuiCopyCount=0,theirGuiCopyCount=0,
  ourSlots={},theirSlots={},
  historicalPublicReferenceOnly=true,
  currentOwnedRawKeyAuthenticated=false,
  currentGameCatalogueAuthenticated=false,
  rawOfferKeyBoundToPreprofile=false,
  offerKeyOriginVerified=false,
  uniqueWeaponInstanceProven=false,
  eventSessionAssociationProven=false,
  serverAttestation=false,serverCompletionProven=false,
  numericSupremeCheckerIdVerified=false,
  currentPricesVerified=false,priceForTradeVerified=false,
  marketValueAuthority=false,authorizesTrade=false,
  authorizesAccept=false,mayRecordCompletedTrade=false,
  mayReportProfit=false,maySendDiscordWebhook=false,
  mayUseForStrategyLearning=false,
 }
end
local function validRegistry(r)
 if typ(r)~="table" or getmetatable(r)~=nil or
    r.schema~="gingerscope-stage83-public-slug-registry-v1" or
    r.publisherUtc~="2026-11-06T15:56:07Z" or
    r.publisherExpiryUtc~="2026-11-09T15:56:07Z" or
    r.currentPricesVerified~=false or
    r.authenticatedOwnedInventory~=false or
    r.authorizesTrade~=false or r.authorizesAccept~=false or
    r.mayUseForStrategyLearning~=false or
    typ(r.entries)~="table" or getmetatable(r.entries)~=nil then
  return false end
 local count=0
 for k,v in next,r.entries do
  count=count+1
  if count>189 or typ(k)~="string" or #k<1 or #k>128 or
     typ(v)~="table" or getmetatable(v)~=nil or
     typ(v[1])~="string" or clean(v[1])==nil or
     (v[2]~="Gun" and v[2]~="Knife") or
     (v[3]~="Ancient" and v[3]~="Godly") or
     typ(v[4])~="boolean" or
     (v[5]~="ancient" and v[5]~="godly" and v[5]~="chroma") or
     (v[5]=="chroma")~=v[4] or
     (not v[4] and v[5]~=v[3]:lower()) or
     typ(v[6])~="string" or #v[6]<1 or #v[6]>128 or
     not v[6]:match("^[%w_%-']+$") or v[7]~=nil then
   return false end
 end
 return count==189
end
local function matchingCurrentCatalogue(raw, ref, catalogue)
 if typ(catalogue)~="table" or getmetatable(catalogue)~=nil then
  return false end
 local meta=rawget(catalogue,raw)
 if typ(meta)~="table" or getmetatable(meta)~=nil then return false end
 return rawget(meta,"ItemName")==ref[1]
    and rawget(meta,"ItemType")==ref[2]
    and rawget(meta,"Rarity")==ref[3]
    and (rawget(meta,"Chroma")==true)==ref[4]
    and (rawget(meta,"Chroma")==nil or typ(rawget(meta,"Chroma"))=="boolean")
end
local function slotStatus(slot,catalogue,registry,parseQuantity)
 if typ(slot)~="table" or getmetatable(slot)~=nil or
    not int(slot.slot,1,4) then return nil,"INVALID_SLOT" end
 if typ(slot.chroma)~="boolean" then return nil,"CHROMA_STATE_UNAVAILABLE" end
 local qty=parseQuantity(slot.amountText)
 if not int(qty,1,1000000) then return nil,"QUANTITY_UNVERIFIED" end
 local label=clean(slot.label)
 if not label then return nil,"DISPLAY_NAME_MISSING" end
 if slot.rawId==nil or slot.rawId=="" then
  -- Stage12/35/36 native audits have no consistently usable raw ID on the
  -- physical GUI slots. Stage50 correlation is a separate client receipt,
  -- never fabricate its key for a new opponent's current UI slot.
  return {slot=slot.slot,quantity=qty,status="NAME_ONLY_UNBOUND_NO_GUI_RAW_KEY"},"NAME_ONLY"
 end
 if typ(slot.rawId)~="string" or #slot.rawId>128 or
    slot.rawId:find("[%c]") then return nil,"RAW_GUI_ID_TYPE_OR_SHAPE_INVALID" end
 local ref=rawget(registry.entries,slot.rawId)
 if typ(ref)~="table" or not matchingCurrentCatalogue(slot.rawId,ref,catalogue) then
  return nil,"RAW_GUI_ID_NOT_EXACT_CURRENT_PUBLIC_REF"
 end
 local normalized=slot.chroma and label:sub(1,7)~="chroma "
   and ("chroma "..label) or label
 local expected=ref[4] and ("chroma "..clean(ref[1])) or clean(ref[1])
 if ref[4]~=slot.chroma or normalized~=expected then
  return nil,"RAW_GUI_ID_NAME_OR_CHROMA_MISMATCH" end
 -- Client-visible GUI attribute/child content may be spoofed or coerced by
 -- Stage9's tostring() reader: this is a corroborated client CANDIDATE,
 -- not an authenticated identity, ownership, or transaction key.
 return {slot=slot.slot,quantity=qty,
   status="GUI_RAW_TEXT_EQUALS_CURRENT_CLIENT_PUBLIC_REFERENCE_ONLY"},"CLIENT_RAW_CANDIDATE"
end
local function inspectSide(side,out,key,catalogue,registry,parseQuantity)
 if typ(side)~="table" or side.complete~=true or
    typ(side.slots)~="table" or #side.slots>4 or
    typ(side.accepted)~="boolean" or side.accepted then
   return false,"OFFER_SIDE_OR_ACCEPT_STATE_UNVERIFIED" end
 local seen={}
 for _,slot in ipairs(side.slots) do
  if typ(slot)~="table" or not int(slot.slot,1,4) or
     seen[slot.slot] then return false,"SLOT_DUPLICATED_OR_OUT_OF_RANGE" end
  seen[slot.slot]=true
  local item,kind=slotStatus(slot,catalogue,registry,parseQuantity)
  if not item then
   out.rejectedSlotCount=out.rejectedSlotCount+1
   out[key][#out[key]+1]={slot=slot.slot,status=kind}
  else
   out[key][#out[key]+1]=item
   if kind=="NAME_ONLY" then out.nameOnlyUnboundCount=out.nameOnlyUnboundCount+1
   else out.clientRawKeyCandidateCount=out.clientRawKeyCandidateCount+1 end
   if key=="ourSlots" then
    out.ourGuiCopyCount=out.ourGuiCopyCount+item.quantity
   else out.theirGuiCopyCount=out.theirGuiCopyCount+item.quantity end
  end
 end
 table.sort(out[key],function(a,b)return a.slot<b.slot end)
 return true
end
function M.inspect(raw,catalogue,registry,parseQuantity)
 local out=base()
 if not validRegistry(registry) then
  out.reason="HISTORICAL_PUBLIC_REGISTRY_NOT_REVIEWED";return out end
 if typ(parseQuantity)~="function" then
  out.reason="STAGE9_QUANTITY_PARSER_MISSING";return out end
 if typ(raw)~="table" or raw.tradeOpen~=true or
    raw.contextOK~=true or typ(raw.session)~="string" or
    #raw.session<1 or #raw.session>180 then
   out.reason="EXACT_PARTNER_OR_SESSION_NOT_BOUND";return out end
 out.exactCurrentPlayerBound=true
 local ok,why=inspectSide(raw.our,out,"ourSlots",catalogue,registry,parseQuantity)
 if not ok then out.reason=why;return out end
 ok,why=inspectSide(raw.their,out,"theirSlots",catalogue,registry,parseQuantity)
 if not ok then out.reason=why;return out end
 out.clientGuiOfferObserved=true
 out.status="CLIENT_GUI_PUBLIC_REFERENCE_CANDIDATES_ONLY"
 out.reason=out.rejectedSlotCount==0 and out.nameOnlyUnboundCount==0
    and "CLIENT_GUI_RAW_TEXT_CANDIDATES_NOT_AUTHORITATIVE"
     or "UNBOUND_OR_REJECTED_PHYSICAL_SLOT_IDENTITY"
 return out
end
-- Inject into the ORIGINAL Stage9 native adapter's existing
-- config.contract.normalize hook. No changes to its GUI reading or gameplay.
-- The original normalize() still runs first and retains all fail-closed flags.
function M.wrapOriginalContract(original,catalogue,registry)
 assert(typ(original)=="table" and typ(original.normalize)=="function"
    and typ(original.parseQuantity)=="function","original Stage9 contract required")
 return {
  normalize=function(raw,trust)
   local o,diag=original.normalize(raw,{marketFresh=false})
   if typ(diag)=="table" then
    diag.stage95=M.inspect(raw,catalogue,registry,original.parseQuantity)
   end
   return o,diag
  end
 }
end
return M
