-- Gingerscope Stage75 PURE local client catalogue ↔ PUBLIC historical name audit.
-- NO own/other inventory, trades, prices, live value, remotes, player identities,
-- raw game keys, source-local checker IDs, ItemID, profit, Discord or learning.
local M={}
local SCHEMA="gingerscope-stage75-client-catalogue-public-name-only-v1"
local SOURCE_SCHEMA="gingerscope-stage75-public-source-names-only-v1"
local SOURCE_BLOB="955e3fb7cd25999fc4f0aad4a77378b9a7bb9ba3"
local function integer(n)
 return type(n)=="number" and n==n and n>0 and n<1e15 and n==math.floor(n)
end
local function safe(s)
 return type(s)=="string" and #s>0 and #s<=128
  and not s:find("[%c]")
end
local function result(status,reason)
 return {
  schema=SCHEMA, status=status, reason=reason, readOnly=true,clientOnly=true,
  sourcePublicationHistorical=true, sourceFresh=false,
  gameCatalogueServerAuthenticated=false,rawToCheckerIdAuthenticated=false,
  numericSupremePriceVerified=false, priceSourceUsed=false,
  currentGameWeaponIdentityProven=false,currentPlayerInventoryRead=false,
  serverAttestation=false,sourceValueAuthority=false,
  catalogRows=0,catalogEligibleRows=0,sourceRows=0,strictMatches=0,
  ambiguousMatches=0,sourceNamesMissing=0,invalidCatalogEntries=0,
  matchedByCategory={ancient=0,godly=0,chroma=0},
  missingSourceNames={},
  authorizesTrade=false,authorizesAccept=false,mayReportProfit=false,
  mayRecordCompletedTrade=false,mayRecordRejectedTrade=false,
  mayUseForStrategyLearning=false,maySendDiscordWebhook=false,
  tradeOutcome="UNKNOWN",
 }
end
function M.evaluate(sync,source)
 local out=result("INCONCLUSIVE","NO_VALIDATED_INPUT")
 if type(source)~="table" or source.schema~=SOURCE_SCHEMA
  or source.historyOnly~=true or source.sourcePublisherCurrent~=false
  or source.rawToCheckerIdAuthenticated~=false
  or source.sourceGitBlob~=SOURCE_BLOB
  or type(source.rows)~="table" then
  out.reason="PINNED_NAME_INDEX_INVALID"
  return out
 end
 local wanted={},sourceCounts={ancient=0,godly=0,chroma=0}
 for k,v in pairs(source.rows) do
  if type(k)~="number" or k~=math.floor(k) or k<1 or k>190
   or type(v)~="table" or not safe(v.name)
   or not sourceCounts[v.page] then
   out.reason="INVALID_PUBLIC_SOURCE_ROWS" return out
  end
  local key=v.page.."|"..v.name
  if wanted[key] then out.reason="DUPLICATE_PUBLIC_NAME" return out end
  wanted[key]={page=v.page,name=v.name}
  sourceCounts[v.page]=sourceCounts[v.page]+1
  out.sourceRows=out.sourceRows+1
 end
 if out.sourceRows~=190 or sourceCounts.ancient~=16 or
    sourceCounts.godly~=128 or sourceCounts.chroma~=46 then
  out.reason="SOURCE_ROW_COVERAGE_MISMATCH" return out
 end
 for i=1,190 do
  if type(source.rows[i])~="table" then
   out.reason="SPARSE_PUBLIC_SOURCE_INDEX" return out
  end
 end
 if type(sync)~="table" or type(sync.Weapons)~="table" then
  out.reason="SYNC_WEAPONS_NOT_AVAILABLE" return out
 end
 local matches={},rows=0,invalid=0,eligible=0
 for raw,d in pairs(sync.Weapons) do
  rows=rows+1
  if rows>2500 then
   out.reason="CATALOG_OVERSIZE" return out
  end
  if not safe(raw) or type(d)~="table" then
   invalid=invalid+1
  else
   local rarity,kind,chroma=d.Rarity,d.ItemType,d.Chroma
   if (rarity=="Godly" or rarity=="Ancient")
     and (kind=="Knife" or kind=="Gun") then
    eligible=eligible+1
    if safe(d.ItemName) and (chroma==nil or type(chroma)=="boolean")
      and integer(d.ItemID) then
     local page=chroma==true and "chroma"
           or rarity=="Ancient" and "ancient" or "godly"
     local name=d.ItemName
     if chroma==true then
      if name:sub(1,7)=="Chroma " then invalid=invalid+1
      else name="Chroma "..name end
     end
     local key=page.."|"..name
     if wanted[key] then matches[key]=(matches[key] or 0)+1 end
    else invalid=invalid+1 end
   end
  end
 end
 out.catalogRows=rows
 out.catalogEligibleRows=eligible
 out.invalidCatalogEntries=invalid
 -- Bounded, public-source labels ONLY. Never export raw game keys or asset ID.
 for _,page in ipairs({"ancient","godly","chroma"}) do
  for _,row in ipairs(source.rows) do
   if row.page==page then
    local n=matches[page.."|"..row.name] or 0
    if n==1 then
     out.strictMatches=out.strictMatches+1
     out.matchedByCategory[page]=out.matchedByCategory[page]+1
    elseif n>1 then
     out.ambiguousMatches=out.ambiguousMatches+1
    else
     out.sourceNamesMissing=out.sourceNamesMissing+1
     if #out.missingSourceNames<12 then
      out.missingSourceNames[#out.missingSourceNames+1]={
       page=page,name=row.name
      }
     end
    end
   end
  end
 end
 if out.strictMatches+out.ambiguousMatches+out.sourceNamesMissing~=190 then
  out.reason="ACCOUNTING_ERROR" return out
 end
 if rows~=1040 then
  out.status="CLIENT_CATALOG_COUNT_DRIFT_REVIEW_ONLY"
  out.reason="NEW_GAME_CATALOGUE_SIZE_NOT_PREVIOUSLY_OBSERVED"
 elseif invalid>0 or out.ambiguousMatches>0 then
  out.status="CLIENT_CATALOG_SHAPE_OR_AMBIGUITY_REVIEW_ONLY"
  out.reason="CANNOT_ASSERT_FULL_DIRECT_NAME_CORRESPONDENCE"
 else
  out.status="CLIENT_CATALOG_PUBLIC_NAME_ONLY"
  out.reason="EXACT_TEXT_CATEGORY_VARIANT_ONLY_NOT_SERVER_AUTHORITY"
 end
 return out
end
return M
