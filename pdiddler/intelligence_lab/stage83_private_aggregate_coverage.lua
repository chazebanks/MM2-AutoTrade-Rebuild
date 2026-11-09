-- Stage83 PURE offline / client-side, read-only historical public-reference coverage.
-- Inputs are caller-supplied CLIENT Owned + Sync.Weapons + versioned public registry.
-- No outgoing events, prices, inventory key output, Discord, or auto Accept.
local M={}
local SCHEMA="gingerscope-stage83-private-aggregate-slug-coverage-v1"
local function result()
 return {
  schema=SCHEMA,status="INCONCLUSIVE",reason="UNOBSERVED",
  readOnly=true,clientOnly=true,sourceKind="UNATTESTED_CLIENT_AND_HISTORICAL_PUBLIC_REFERENCES",
  originalOwnedKeyTypesObserved=false,exactClientCatalogueLookupObserved=false,
  historicalPublicReferenceCoverageObserved=false,
  sourcePublisherFresh=false,currentPricesVerified=false,
  numericSupremeCheckerIdVerified=false,authenticatedOwnedInventory=false,
  currentGameCatalogueAuthenticated=false,serverAttestation=false,
  currentOwnedRawToMarketSlugVerified=false,serverCompletionProven=false,
  authorizesTrade=false,authorizesAccept=false,mayReportProfit=false,
  mayRecordCompletedTrade=false,mayRecordRejectedTrade=false,
  maySendDiscordWebhook=false,mayUseForStrategyLearning=false,
  tradeOutcome="UNKNOWN",historicalPublicRegistryEntries=0,
  ownedKeys=0,ownedCopies=0,stringOwnedKeys=0,numericOwnedKeys=0,otherOwnedKeys=0,
  invalidQuantities=0,unmappedClientKeys=0,untrustedMetadataKeys=0,
  clientWeaponKeys=0,clientWeaponCopies=0,miscKeys=0,miscCopies=0,
  eligibleKeys=0,eligibleCopies=0,eligibleChromaCopies=0,
  historicalReferenceEligibleKeys=0,historicalReferenceEligibleCopies=0,
  historicalUnmappedEligibleKeys=0,historicalUnmappedEligibleCopies=0,
  historicalVariantDriftEligibleKeys=0,historicalVariantDriftEligibleCopies=0,
  unsupportedClientCategoryKeys=0
 }
end
local function isString(s)
 return type(s)=="string" and #s>0 and #s<=128 and not s:find("[%c]")
end
local function isQty(q)
 return type(q)=="number" and q==q and q>=1 and q<=1000000 and q==math.floor(q)
end
local function simpleTable(t)
 return type(t)=="table" and getmetatable(t)==nil
end
local function validateRegistry(r)
 if not simpleTable(r) or not simpleTable(r.entries) or
    r.schema~="gingerscope-stage83-public-slug-registry-v1" or
    r.publisherUtc~="2026-11-06T15:56:07Z" or
    r.publisherExpiryUtc~="2026-11-09T15:56:07Z" or
    r.currentPricesVerified~=false or
    r.authenticatedOwnedInventory~=false or
    r.authorizesTrade~=false or r.authorizesAccept~=false or
    r.mayUseForStrategyLearning~=false then
  return false
 end
 local count,used=0,{}
 for raw,d in pairs(r.entries) do
  count=count+1
  if count>189 or not isString(raw) or not simpleTable(d) or
     not isString(d[1]) or (d[2]~="Knife" and d[2]~="Gun") or
     (d[3]~="Ancient" and d[3]~="Godly") or
     type(d[4])~="boolean" or
     not isString(d[5]) or not isString(d[6]) or
     (d[5]~="ancient" and d[5]~="godly" and d[5]~="chroma") or
     (d[5]=="chroma")~=d[4] or
     (not d[4] and d[5]~=string.lower(d[3])) or
     not string.match(d[6],"^[%w_%-']+$") or
     d[7]~=nil then
   return false
  end
  local slugKey=d[5].."|"..d[6]
  if used[slugKey] then return false end
  used[slugKey]=true
 end
 return count==189
end
function M.audit(owned, catalogue, registry)
 local out=result()
 if not validateRegistry(registry) then
  out.reason="PUBLIC_SOURCE_REGISTRY_UNREVIEWED"
  return out
 end
 out.historicalPublicRegistryEntries=189
 if not simpleTable(owned) or not simpleTable(catalogue) then
  out.reason="CLIENT_TABLE_UNAVAILABLE_OR_METATABLE"
  return out
 end
 local invalid=false
 for raw,qty in pairs(owned) do
  out.ownedKeys=out.ownedKeys+1
  if out.ownedKeys>10000 then return result() end
  local validKey=isString(raw)
  if type(raw)=="string" then out.stringOwnedKeys=out.stringOwnedKeys+1
  elseif type(raw)=="number" then out.numericOwnedKeys=out.numericOwnedKeys+1
  else out.otherOwnedKeys=out.otherOwnedKeys+1 end
  if not validKey then invalid=true end
  local validQty=isQty(qty)
  if not validQty then
   invalid=true;out.invalidQuantities=out.invalidQuantities+1
  else
   out.ownedCopies=out.ownedCopies+qty
   if out.ownedCopies>1000000 then return result() end
  end
  if validKey then
   local meta=rawget(catalogue,raw)
   if meta==nil then
    out.unmappedClientKeys=out.unmappedClientKeys+1
    invalid=true
   elseif not simpleTable(meta) or not isString(meta.ItemName) or
       not isString(meta.ItemType) or not isString(meta.Rarity) or
       (meta.Chroma~=nil and type(meta.Chroma)~="boolean") then
    out.untrustedMetadataKeys=out.untrustedMetadataKeys+1
    invalid=true
   elseif meta.ItemType=="Misc" and meta.Chroma~=true then
    out.miscKeys=out.miscKeys+1
    if validQty then out.miscCopies=out.miscCopies+qty end
   elseif meta.ItemType=="Knife" or meta.ItemType=="Gun" then
    out.clientWeaponKeys=out.clientWeaponKeys+1
    if validQty then out.clientWeaponCopies=out.clientWeaponCopies+qty end
    local eligible=meta.Rarity=="Ancient" or meta.Rarity=="Godly"
    if meta.Chroma==true and not eligible then
     out.untrustedMetadataKeys=out.untrustedMetadataKeys+1
     invalid=true
    elseif eligible and validQty then
     out.eligibleKeys=out.eligibleKeys+1
     out.eligibleCopies=out.eligibleCopies+qty
     if meta.Chroma==true then
      out.eligibleChromaCopies=out.eligibleChromaCopies+qty
     end
     local expected=rawget(registry.entries,raw)
     if expected==nil then
      out.historicalUnmappedEligibleKeys=out.historicalUnmappedEligibleKeys+1
      out.historicalUnmappedEligibleCopies=out.historicalUnmappedEligibleCopies+qty
     elseif meta.ItemName~=expected[1] or meta.ItemType~=expected[2] or
         meta.Rarity~=expected[3] or (meta.Chroma==true)~=expected[4] then
      out.historicalVariantDriftEligibleKeys=out.historicalVariantDriftEligibleKeys+1
      out.historicalVariantDriftEligibleCopies=out.historicalVariantDriftEligibleCopies+qty
     else
      out.historicalReferenceEligibleKeys=out.historicalReferenceEligibleKeys+1
      out.historicalReferenceEligibleCopies=out.historicalReferenceEligibleCopies+qty
     end
    end
   else
    out.unsupportedClientCategoryKeys=out.unsupportedClientCategoryKeys+1
    invalid=true
   end
  end
 end
 if out.ownedKeys==0 then
  out.reason="NO_OWNED_ITEMS_OBSERVED"
  return out
 end
 out.originalOwnedKeyTypesObserved=true
 if invalid then
  out.reason="CLIENT_QUANTITY_TYPE_OR_CATALOGUE_DISCREPANCY"
  return out
 end
 if out.historicalReferenceEligibleKeys+out.historicalUnmappedEligibleKeys+
    out.historicalVariantDriftEligibleKeys~=out.eligibleKeys or
    out.historicalReferenceEligibleCopies+out.historicalUnmappedEligibleCopies+
    out.historicalVariantDriftEligibleCopies~=out.eligibleCopies or
    out.clientWeaponCopies+out.miscCopies~=out.ownedCopies then
  out.reason="AGGREGATE_PARTITION_MISMATCH"
  return out
 end
 out.status="CLIENT_HISTORICAL_PUBLIC_REFERENCE_COVERAGE_ONLY"
 out.reason="NOT_AUTHENTICATED_ITEM_ID_OR_FRESH_TRADE_PRICE"
 out.exactClientCatalogueLookupObserved=true
 out.historicalPublicReferenceCoverageObserved=true
 return out
end
return M
