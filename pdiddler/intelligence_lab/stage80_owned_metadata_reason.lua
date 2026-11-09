-- Stage80 pure read-only root-cause classifier for one Stage79 metadata discrepancy.
-- Never invent raw key, apply fuzzy alias, quote price, or trade. Aggregate only.
-- CLIENT tables supplied by caller are not server-authenticated.
local M={}
local schema="gingerscope-stage80-owned-catalogue-field-reasons-v1"
local fields={
 "ownedKeys","ownedCopies","stringKeyCount","numericKeyCount","otherKeyCount",
 "invalidQuantityKeys","missingCatalogueKeys","untrustedMetadataKeys",
 "missingNameKeys","missingTypeKeys","missingRarityKeys",
 "miscKeys","miscCopies","unknownItemTypeKeys","invalidChromaTypeKeys",
 "chromaRarityConflictKeys","weaponKeys","weaponCopies",
 "eligibleWeaponKeys","eligibleWeaponCopies","chromaEligibleCopies"
}
local function report()
 local r={
  schema=schema,status="INCONCLUSIVE",reason="SOURCE_UNAVAILABLE",
  readOnly=true,clientOnly=true,originalOwnedTypesObserved=false,
  metadataReasonsObserved=false,sourceScope="UNATTESTED_SAME_CLIENT_TABLES",
  tradeOutcome="UNKNOWN",serverAttestation=false,authenticatedOwnedInventory=false,
  currentGameCatalogueAuthenticated=false,sourcePublisherFresh=false,
  currentPricesVerified=false,numericSupremeCheckerIdVerified=false,
  serverCompletionProven=false,authorizesTrade=false,authorizesAccept=false,
  mayRecordCompletedTrade=false,mayRecordRejectedTrade=false,
  mayReportProfit=false,maySendDiscordWebhook=false,
  mayUseForStrategyLearning=false,
 }
 for _,f in ipairs(fields) do r[f]=0 end
 return r
end
local function str(v)
 return type(v)=="string" and #v>=1 and #v<=128 and not v:find("[%c]")
end
local function qty(v)
 return type(v)=="number" and v==v and v==math.floor(v) and v>=1 and v<=1000000
end
function M.audit(owned,catalogue)
 local out=report()
 if type(owned)~="table" or getmetatable(owned)~=nil or
    type(catalogue)~="table" or getmetatable(catalogue)~=nil then
  return out
 end
 for key,number in pairs(owned) do
  out.ownedKeys=out.ownedKeys+1
  if out.ownedKeys>10000 then
   return report() -- limit invalidates all partial proof, not count
  end
  if type(key)=="string" then
   out.stringKeyCount=out.stringKeyCount+1
  elseif type(key)=="number" then
   out.numericKeyCount=out.numericKeyCount+1
  else
   out.otherKeyCount=out.otherKeyCount+1
  end
  if not qty(number) then
   out.invalidQuantityKeys=out.invalidQuantityKeys+1
  else
   out.ownedCopies=out.ownedCopies+number
   if out.ownedCopies>1000000 then return report() end
  end
  -- Never coerce original key type or index catalogue using a display label.
  if not str(key) then
   out.untrustedMetadataKeys=out.untrustedMetadataKeys+1
  else
   local meta=rawget(catalogue,key)
   if meta==nil then
    out.missingCatalogueKeys=out.missingCatalogueKeys+1
   elseif type(meta)~="table" or getmetatable(meta)~=nil then
    out.untrustedMetadataKeys=out.untrustedMetadataKeys+1
   elseif not str(meta.ItemName) then
    out.missingNameKeys=out.missingNameKeys+1
   elseif type(meta.ItemType)~="string" or meta.ItemType=="" then
    out.missingTypeKeys=out.missingTypeKeys+1
   elseif not str(meta.Rarity) then
    out.missingRarityKeys=out.missingRarityKeys+1
   elseif meta.Chroma~=nil and type(meta.Chroma)~="boolean" then
    out.invalidChromaTypeKeys=out.invalidChromaTypeKeys+1
   elseif meta.Chroma==true and meta.Rarity~="Ancient"
       and meta.Rarity~="Godly" then
    out.chromaRarityConflictKeys=out.chromaRarityConflictKeys+1
   elseif meta.ItemType=="Misc" and meta.Chroma~=true then
    -- Do not call this a weapon, assign price or silently skip unknown types.
    out.miscKeys=out.miscKeys+1
    if qty(number) then out.miscCopies=out.miscCopies+number end
   elseif meta.ItemType=="Knife" or meta.ItemType=="Gun" then
    out.weaponKeys=out.weaponKeys+1
    if qty(number) then
     out.weaponCopies=out.weaponCopies+number
     if meta.Rarity=="Ancient" or meta.Rarity=="Godly" then
      out.eligibleWeaponKeys=out.eligibleWeaponKeys+1
      out.eligibleWeaponCopies=out.eligibleWeaponCopies+number
      if meta.Chroma==true then
       out.chromaEligibleCopies=out.chromaEligibleCopies+number
      end
     end
    end
   else
    out.unknownItemTypeKeys=out.unknownItemTypeKeys+1
   end
  end
 end
 out.originalOwnedTypesObserved=true
 out.metadataReasonsObserved=true
 if out.ownedKeys==0 then
  out.reason="EMPTY_OWNED"
  return out
 end
 local uncertain=out.numericKeyCount+out.otherKeyCount+out.invalidQuantityKeys
   +out.missingCatalogueKeys+out.untrustedMetadataKeys+out.missingNameKeys
   +out.missingTypeKeys+out.missingRarityKeys+out.unknownItemTypeKeys
   +out.invalidChromaTypeKeys+out.chromaRarityConflictKeys
 if uncertain>0 then
  out.reason="ONE_OR_MORE_UNVERIFIED_FIELDS_PRESENT"
 elseif out.miscKeys>0 then
  out.status="CLIENT_MISC_EXCLUDED_FROM_WEAPON_CATEGORY_ONLY"
  out.reason="EXACT_MATCHED_MISC_IS_NOT_A_WEAPON_CLIENT_ONLY"
 else
  out.status="CLIENT_WEAPON_CATEGORY_METADATA_CONSISTENT_ONLY"
  out.reason="CLIENT_METADATA_CONSISTENT_NOT_AUTHENTICATED"
 end
 return out
end
return M
