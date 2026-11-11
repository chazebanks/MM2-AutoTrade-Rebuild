-- Stage78: one narrow offline-only client-source raw-key -> Sync.Weapons exact join.
-- This is a STRICT DESIGN GUARD, NOT another user inventory read or a live script.
-- It must NEVER execute trade APIs, look up Supreme prices, or report profit.
-- Source inputs are caller-supplied client tables; positive != Roblox attestation.
local M={}
local SCHEMA="gingerscope-stage78-strict-owned-raw-catalogue-join-v1"

local function result(status,reason)
 return {
  schema=SCHEMA,status=status,reason=reason,readOnly=true,
  positiveOwnedKeys=0,positiveOwnedCopies=0,eligibleCopies=0,
  eligibleKeys=0,chromaEligibleCopies=0,
  sourceScope="CALLER_SUPPLIED_CLIENT_TABLES_UNAUTHENTICATED",
  rawToCatalogueDirectJoinObserved=false,
  playerInventoryAuthenticated=false,currentGameCatalogueAuthenticated=false,
  sourcePublisherFresh=false,currentPricesVerified=false,
  numericSupremeCheckerIdVerified=false,
  sourceLevelNameCorrespondenceOnly=false,
  serverAttestation=false,serverCompletionProven=false,
  authorizesTrade=false,authorizesAccept=false,mayReportProfit=false,
  mayRecordCompletedTrade=false,mayRecordRejectedTrade=false,
  maySendDiscordWebhook=false,mayUseForStrategyLearning=false,
  tradeOutcome="UNKNOWN"
 }
end

local function safeText(s)
 return type(s)=="string" and #s>0 and #s<=128 and
   not s:find("[%c]")
end
local function integerCopies(v)
 return type(v)=="number" and v==v and v>0 and
   v<=1000000 and v==math.floor(v)
end
local function noMeta(t)
 return type(t)=="table" and getmetatable(t)==nil
end

function M.evaluate(owned, catalogue)
 local out=result("INCONCLUSIVE","INPUTS_UNAVAILABLE")
 if not noMeta(owned) or not noMeta(catalogue) then
  out.reason="SOURCE_TABLE_OR_METATABLE_UNTRUSTED"
  return out
 end
 local keys,copies,eligible,eligibleKeys,chroma=0,0,0,0,0
 for rawKey,qty in pairs(owned) do
  -- Crucial: DO NOT tostring(rawKey). The legacy scanner did, which could
  -- collapse distinct [123] and ["123"] raw-key types into one metadata ID.
  if not safeText(rawKey) then
   out.reason="RAW_KEY_NOT_EXACT_STRING"
   return out
  end
  if not integerCopies(qty) then
   out.reason="UNTRUSTED_RAW_QUANTITY"
   return out
  end
  keys=keys+1
  copies=copies+qty
  if keys>10000 or copies>1000000 then
   out.reason="OWNED_KEY_OR_COPY_LIMIT_EXCEEDED"
   return out
  end
  -- Direct exact string lookup ONLY. Never use client display labels,
  -- image ItemID, fuzzy aliases, copied checkerId or coercion.
  local d=rawget(catalogue,rawKey)
  if not noMeta(d) then
   out.reason="CATALOGUE_RAW_KEY_ABSENT_OR_UNTRUSTED"
   return out
  end
  if not safeText(d.ItemName) or not safeText(d.ItemType) or
     not safeText(d.Rarity) then
   out.reason="CATALOGUE_REQUIRED_FIELDS_MALFORMED"
   return out
  end
  if d.ItemType~="Knife" and d.ItemType~="Gun" then
   out.reason="CATALOGUE_NOT_WEAPON_TYPE"
   return out
  end
  if d.Chroma~=nil and type(d.Chroma)~="boolean" then
   out.reason="CATALOGUE_CHROMA_TYPE_MALFORMED"
   return out
  end
  local isEligible=d.Rarity=="Ancient" or d.Rarity=="Godly"
  if d.Chroma==true and not isEligible then
   out.reason="CATALOGUE_CHROMA_RARITY_CONFLICT"
   return out
  end
  if isEligible then
   eligibleKeys=eligibleKeys+1
   eligible=eligible+qty
   if d.Chroma==true then chroma=chroma+qty end
  end
 end
 if keys==0 then
  out.reason="EMPTY_OWNED_MAP_NOT_PROOF"
  return out
 end
 out.status="CALLER_CLIENT_RAW_TO_CATALOGUE_EXACT_LOOKUP_ONLY"
 out.reason="NO_OWNED_INVENTORY_OR_MARKET_SERVER_ATTESTATION"
 out.positiveOwnedKeys=keys
 out.positiveOwnedCopies=copies
 out.eligibleKeys=eligibleKeys
 out.eligibleCopies=eligible
 out.chromaEligibleCopies=chroma
 out.rawToCatalogueDirectJoinObserved=true
 return out
end

return M
