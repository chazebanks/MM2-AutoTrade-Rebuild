-- Stage79 pure evidence analyser: raw Owned keys DIRECTLY against Sync.Weapons.
-- No Roblox API, trade remote, player name, raw IDs, item labels or prices.
-- Positive output proves only consistency of two caller-provided CLIENT tables.
local M={}
local SCHEMA="gingerscope-stage79-client-owned-typed-key-census-v1"
local function report(status,reason)
 return {
  schema=SCHEMA,status=status,reason=reason,readOnly=true,clientOnly=true,
  originalOwnedKeyTypesObserved=false,directCatalogueJoinObserved=false,
  ownedKeyCount=0,positiveCopyCount=0,stringKeyCount=0,
  numericKeyCount=0,otherKeyCount=0,invalidQuantityCount=0,
  unmatchedStringKeyCount=0,malformedCatalogueEntryCount=0,
  directCatalogueKeyCount=0,eligibleKeyCount=0,eligibleCopies=0,
  chromaEligibleCopies=0,coercionCollisionPairs=0,
  sourceKind="CLIENT_GETPROFILEDATA_AND_REPLICATED_SYNC_UNATTESTED",
  authenticatedOwnedInventory=false,serverAttestation=false,
  serverCompletionProven=false,rawToSupremeCheckerVerified=false,
  sourcePublisherFresh=false,currentPricesVerified=false,
  mayReportProfit=false,mayRecordCompletedTrade=false,
  mayRecordRejectedTrade=false,maySendDiscordWebhook=false,
  mayUseForStrategyLearning=false,authorizesTrade=false,
  authorizesAccept=false,tradeOutcome="UNKNOWN"
 }
end
local function safeKey(s)
 return type(s)=="string" and #s>=1 and #s<=128 and not s:find("[%c]")
end
local function safeQty(q)
 return type(q)=="number" and q==q and
   q>=1 and q<=1000000 and q==math.floor(q)
end
function M.audit(owned,cat)
 local out=report("INCONCLUSIVE","SOURCE_TABLE_UNAVAILABLE")
 if type(owned)~="table" or type(cat)~="table"
    or getmetatable(owned)~=nil or getmetatable(cat)~=nil then
  return out
 end
 local numberAsText={}
 local strings={}
 local hasMalformed=false
 for k,q in pairs(owned) do
  out.ownedKeyCount=out.ownedKeyCount+1
  if out.ownedKeyCount>10000 then
   return report("INCONCLUSIVE","OWNED_KEY_LIMIT_EXCEEDED")
  end
  if type(k)=="string" then
   out.stringKeyCount=out.stringKeyCount+1
   if safeKey(k) then strings[k]=true else hasMalformed=true end
  elseif type(k)=="number" then
   out.numericKeyCount=out.numericKeyCount+1
   if k==k and k~=math.huge and k~=-math.huge then
    numberAsText[tostring(k)]=true
   end
  else
   out.otherKeyCount=out.otherKeyCount+1
  end
  if not safeQty(q) then
   out.invalidQuantityCount=out.invalidQuantityCount+1
   hasMalformed=true
  else
   out.positiveCopyCount=out.positiveCopyCount+q
   if out.positiveCopyCount>1000000 then
    return report("INCONCLUSIVE","OWNED_COPY_LIMIT_EXCEEDED")
   end
  end
  if type(k)=="string" and safeKey(k) then
   -- Exact primitive STRING key, no tostring/coercion, alias/fuzzy,
   -- normalized display name, art ItemID or historical checker ID.
   local meta=rawget(cat,k)
   if meta==nil then
    out.unmatchedStringKeyCount=out.unmatchedStringKeyCount+1
   elseif type(meta)~="table" or getmetatable(meta)~=nil or
       not safeKey(meta.ItemName) or
       (meta.ItemType~="Knife" and meta.ItemType~="Gun") or
       not safeKey(meta.Rarity) or
       (meta.Chroma~=nil and type(meta.Chroma)~="boolean") then
    out.malformedCatalogueEntryCount=out.malformedCatalogueEntryCount+1
   else
    out.directCatalogueKeyCount=out.directCatalogueKeyCount+1
    local eligible=meta.Rarity=="Ancient" or meta.Rarity=="Godly"
    if meta.Chroma==true and not eligible then
      out.malformedCatalogueEntryCount=out.malformedCatalogueEntryCount+1
      out.directCatalogueKeyCount=out.directCatalogueKeyCount-1
    elseif eligible and safeQty(q) then
      out.eligibleKeyCount=out.eligibleKeyCount+1
      out.eligibleCopies=out.eligibleCopies+q
      if meta.Chroma==true then
       out.chromaEligibleCopies=out.chromaEligibleCopies+q
      end
    end
   end
  end
 end
 for textKey in pairs(numberAsText) do
  if strings[textKey] then
   out.coercionCollisionPairs=out.coercionCollisionPairs+1
  end
 end
 out.originalOwnedKeyTypesObserved=true
 if out.ownedKeyCount==0 then
  out.reason="EMPTY_OWNED_TABLE_UNINFORMATIVE"
 elseif out.numericKeyCount>0 or out.otherKeyCount>0 or
   out.coercionCollisionPairs>0 or out.invalidQuantityCount>0 or
   out.unmatchedStringKeyCount>0 or
   out.malformedCatalogueEntryCount>0 or hasMalformed then
  out.reason="OWNED_TYPE_QUANTITY_OR_CATALOGUE_DISCREPANCY"
 else
  out.status="CLIENT_TYPED_OWNED_DIRECT_CATALOGUE_MATCH_ONLY"
  out.reason="UNATTESTED_SINGLE_CLIENT_READ_ONLY"
  out.directCatalogueJoinObserved=true
 end
 return out
end
return M
