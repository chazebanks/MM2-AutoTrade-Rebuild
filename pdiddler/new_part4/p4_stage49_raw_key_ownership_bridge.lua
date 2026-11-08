-- Stage49 PURE read-only, equality-only raw-key ownership correspondence.
-- Candidate raw key is UNTRUSTED. We do not attest its offer provenance,
-- Supreme checker-ID, item copy/instance, session, acceptance or settlement.
local M={}
local typ,rawget,next,getmetatable,rawequal=type,rawget,next,getmetatable,rawequal
local function validKey(k)
 if typ(k)=="string" then return #k>0 and #k<=256 end
 if typ(k)=="number" then return k==k and k~=math.huge and k~=-math.huge end
 return false
end
local function qty(x)
 return typ(x)=="number" and x==x and x~=math.huge and
  x==math.floor(x) and x>=1 and x<=1000000
end
local function sealed(t)
 return typ(t)=="table" and getmetatable(t)==nil
end
local function report()
 return {schema="gingerscope-stage49-raw-key-owned-correspondence-v1",
  status="INCOMPLETE",reason="UNTESTED",readOnly=true,clientOnly=true,
  rawKeyType="UNSUPPORTED",syncAliasMode="UNTESTED",
  exactRawKeyInSync=false,exactRawKeyInOwned=false,
  scannerRowRawKeyMatched=false,scannerRowCountMatched=false,
  rawKeyOwnedClientMatch=false,offerKeyOriginVerified=false,
  checkerIdentityVerified=false,checkerMappingMode="UNATTESTED_SCANNER_RESOLVER",
  uniqueWeaponInstanceProven=false,rawItemIdConfirmed=false,
  rawKeyPresentConfirmed=false,ownerSideSlotBound=false,
  hasAuthenticatedSessionIdentifier=false,eventSessionAssociationProven=false,
  causalAttributionProven=false,serverAttestation=false,
  serverCompletionProven=false,authorizesTrade=false,authorizesAccept=false,
  mayRecordCompletedTrade=false,mayReportProfit=false,tradeOutcome="UNKNOWN"}
end
local function fail(r,reason)r.reason=reason;return r end
function M.inspect(sync,profileOwned,scanner,key,offeredCount)
 local r=report()
 r.rawKeyType=typ(key)=="string" and "STRING" or
  (typ(key)=="number" and "NUMBER" or "UNSUPPORTED")
 if not validKey(key) or not qty(offeredCount) then
  return fail(r,"INVALID_KEY_OR_REQUESTED_QUANTITY")
 end
 if not sealed(sync) or not sealed(profileOwned) or not sealed(scanner)
  or not sealed(rawget(scanner,"items")) then
  return fail(r,"UNTRUSTED_INPUT_SHAPE")
 end
 local sources={}
 local w,i=rawget(sync,"Weapons"),rawget(sync,"Item")
 if sealed(w) then sources[#sources+1]=w else
  return fail(r,"SYNC_WEAPONS_UNAVAILABLE") end
 if i~=nil then
  if not sealed(i) then return fail(r,"SYNC_ITEM_UNTRUSTED") end
  if rawequal(i,w) then r.syncAliasMode="SHARED_TABLE"
  else r.syncAliasMode="DISTINCT_TABLES";sources[#sources+1]=i end
 else r.syncAliasMode="WEAPONS_ONLY" end
 local count,seen,spellings=0,{},{}
 for _,source in ipairs(sources) do
  for k,row in next,source do
   count=count+1
   if count>2500 then return fail(r,"SYNC_CATALOGUE_OVERSIZE") end
   if not validKey(k) or not sealed(row) then
    return fail(r,"SYNC_CATALOGUE_UNTRUSTED") end
   local spelling=tostring(k)
   local old=spellings[spelling]
   if old~=nil and not rawequal(old,k) then
    return fail(r,"STRING_NUMERIC_KEY_COLLISION") end
   spellings[spelling]=k
   if seen[k]~=nil and not rawequal(seen[k],row) then
    return fail(r,"SYNC_RAW_KEY_COLLISION") end
   seen[k]=row
  end
 end
 local meta=seen[key]
 if meta==nil then return fail(r,"CANDIDATE_KEY_MISSING_IN_SYNC") end
 r.exactRawKeyInSync=true
 local t=rawget(meta,"ItemType")
 local name=rawget(meta,"ItemName")
 if name==nil then name=rawget(meta,"Name") end
 local rarity=rawget(meta,"Rarity")
 local chroma=rawget(meta,"Chroma")==true
 local page=chroma and "chroma" or
  ((rarity=="Ancient" or rarity=="Godly") and string.lower(rarity) or nil)
 if (t~="Knife" and t~="Gun") or typ(name)~="string" or name==""
  or not page or rawget(meta,"Tradable")==false
  or rawget(meta,"CanTrade")==false or rawget(meta,"Untradable")==true
  or rawget(meta,"NonTradable")==true
  or rawget(meta,"EvoBaseID")~=nil or rawget(meta,"EvoIndex")~=nil then
  return fail(r,"SYNC_ITEM_NOT_VERIFIED_ELIGIBLE")
 end
 local owned=rawget(profileOwned,key)
 if owned==nil then return fail(r,"RAW_KEY_NOT_OWNED") end
 if not qty(owned) or owned<offeredCount then
  return fail(r,"INSUFFICIENT_RAW_OWNED_COPIES") end
 r.exactRawKeyInOwned=true
 if typ(key)~="string" then
  -- Current scanner emits id=tostring(rawId). Do not accept a coerced
  -- string ID as proof of an original numeric-key identity.
  return fail(r,"NUMERIC_KEY_SCANNER_COERCION_UNVERIFIED")
 end
 local scannedItems=rawget(scanner,"items")
 local n=#scannedItems
 if n>2500 or n==0 or typ(rawget(scanner,"unmapped"))~="number"
  or rawget(scanner,"unmapped")~=0
  or typ(rawget(scanner,"badQty"))~="number"
  or rawget(scanner,"badQty")~=0 then
  return fail(r,"SCANNER_INCOMPLETE_OR_UNMAPPED")
 end
 local matches=0
 local seenIds={}
 for j=1,n do
  local row=rawget(scannedItems,j)
  if not sealed(row) or typ(rawget(row,"id"))~="string"
    or not qty(rawget(row,"qty")) then
   return fail(r,"SCANNER_ROW_UNTRUSTED") end
  local id=rawget(row,"id")
  if seenIds[id] then return fail(r,"DUPLICATE_SCANNER_RAW_KEY") end
  seenIds[id]=true
  if id==key then
   matches=matches+1
   if rawget(row,"cat")~="Weapons" or rawget(row,"page")~=page
    or rawget(row,"type")~=t or rawget(row,"name")~=name then
    return fail(r,"SCANNER_ROW_METADATA_MISMATCH")end
   r.scannerRowRawKeyMatched=true
   if rawget(row,"qty")~=owned then
    return fail(r,"SCANNER_OWNED_QUANTITY_MISMATCH")end
   r.scannerRowCountMatched=true
  end
 end
 for k in next,scannedItems do
  if typ(k)~="number" or k<1 or k>n or k~=math.floor(k) then
   return fail(r,"SCANNER_ARRAY_SPARSE_OR_EXTRA")end
 end
 if matches~=1 then return fail(r,"SCANNER_RAW_KEY_NOT_UNIQUE") end
 r.rawKeyOwnedClientMatch=true
 r.status="CLIENT_RAW_KEY_OWNERSHIP_CORRESPONDENCE_ONLY"
 r.reason="NONE"
 return r
end
return M
