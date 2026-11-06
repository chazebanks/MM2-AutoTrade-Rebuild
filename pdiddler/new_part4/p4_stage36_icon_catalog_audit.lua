-- Stage36: PURE, bounded read-only comparison of one native offer-slot
-- image reference against *all available* MM2 Sync catalogue art fields.
-- No image URL, item ID, asset ID, names, account IDs or fingerprints output.
-- A single icon match is client catalogue evidence ONLY, never a raw ID.
local M={}
local function legal(s)
 return type(s)=="string" and #s>0 and #s<=512
end
local function trim(s)
 return s:match("^%s*(.-)%s*$")
end
-- Only exact bounded Roblox-documented URI shapes become keys.
-- Thumb asset ID remains a separate image-reference family from raw asset ID.
local function validId(id)
 return type(id)=="string" and #id>0 and #id<=22 and not id:match("^0+$")
end
local function canonId(id) return id:gsub("^0+","") end
local function iconKey(x)
 if not legal(x) then return nil,"EMPTY_OR_INVALID" end
 -- Paths, filenames and query values are not case-insensitive identities.
 local s=trim(x)
 if s=="" then return nil,"EMPTY_OR_INVALID" end
 local id=s:match("^rbxassetid://(%d+)$") or
  s:match("^https?://www%.roblox%.com/asset/%?id=(%d+)$")
 if id then
  if not validId(id) then return nil,"INVALID_ASSET_ID" end
  return "asset:"..canonId(id),"ROBLOX_ASSET_ID"
 end
 local thumb,w,h=s:match("^rbxthumb://type=Asset&id=(%d+)&w=(%d+)&h=(%d+)$")
 if thumb then
  local wi,hi=tonumber(w),tonumber(h)
  if not validId(thumb) or not wi or not hi or
     wi<1 or hi<1 or wi>2048 or hi>2048 then
   return nil,"ROBLOX_THUMB_INVALID"
  end
  -- Different thumbnail dimensions request different renderings. Do not
  -- assert equivalent pixels merely because the source asset ID agrees.
  return "thumb:"..canonId(thumb)..":"..w..":"..h,"ROBLOX_THUMB_ASSET"
 end
 if s:match("^rbxgameasset://[%w_/%-%.]+$") then
  return "gameasset:"..s,"ROBLOX_GAMEASSET"
 end
 if s:match("^rbxasset://[%w_/%-%.]+$") then
  return "builtin:"..s,"ROBLOX_BUILTIN_PATH"
 end
 if s:match("^rbxhttp://[%w_/%?&=%.%-%+]+$") then
  return "rbxhttp:"..s,"ROBLOX_HTTP"
 end
 if s:match("^[%w_%-%.]+%.png$") or
    s:match("^[%w_%-%.]+%.jpg$") or
    s:match("^[%w_%-%.]+%.jpeg$") then
  return "filename:"..s,"FILENAME"
 end
 if s:match("^rbxthumb://") then
  return nil,"ROBLOX_THUMB_UNSUPPORTED_VARIANT"
 end
 if s:match("^rbxgameasset://") then
  return nil,"ROBLOX_GAMEASSET_UNSUPPORTED_VARIANT"
 end
 if s:match("^rbxassetid://") then
  return nil,"ROBLOX_ASSET_ID_UNSUPPORTED_VARIANT"
 end
 if s:match("^https?://www%.roblox%.com/asset/") then
  return nil,"ROBLOX_ASSET_URL_UNSUPPORTED_VARIANT"
 end
 if s:match("^https?://") then return nil,"OTHER_HTTP_IMAGE_REFERENCE" end
 if s:match("^%d+$") then return nil,"PLAIN_NUMERIC_REFERENCE" end
 if s:match("^[%a][%w+%.%-]*://") then
  return nil,"OTHER_URI_SCHEME"
 end
 return nil,"INCOMPARABLE_REFERENCE_FORMAT"
end
local function formatCounts()
 return {assetId=0,thumbAsset=0,gameAsset=0,builtin=0,
  robloxHttp=0,filename=0,unsupported=0}
end
local function recordFormat(counts,fmt)
 local col=({
  ROBLOX_ASSET_ID="assetId",ROBLOX_THUMB_ASSET="thumbAsset",
  ROBLOX_GAMEASSET="gameAsset",ROBLOX_BUILTIN_PATH="builtin",
  ROBLOX_HTTP="robloxHttp",FILENAME="filename"
 })[fmt] or "unsupported"
 counts[col]=counts[col]+1
end
local function allowCount(x,hi)
 return type(x)=="number" and x==x and
  x==math.floor(x) and x>=0 and x<=hi
end
function M.assess(input)
 local r={schema="gingerscope-stage36-client-slot-icon-catalog-audit-v1",
  status="INCOMPLETE",reason="missing-native-slot-or-catalogue",
  nativeOfferSlotObserved=false,slotSide=nil,slotIndex=nil,
  iconReferenceFormat="UNAVAILABLE",catalogEntriesAudited=0,
  catalogEntriesWithComparableArt=0,catalogEntriesWithoutComparableArt=0,
  catalogEntriesWithUnresolvedArt=0,catalogueCoverageComplete=false,
  catalogImageCandidateReferences=0,
  catalogEntriesFormatInspected=0,catalogueReferenceFormatCounts=formatCounts(),
  slotIconReferenceComparable=false,
  matchingCatalogueEntries=0,distinctMatchingWeaponKeys=0,
  imageReferenceAmbiguous=true,uniqueIconCandidateFound=false,
  usesSpriteSheet=false,catalogueNotServerAttestation=true,
  rawItemIdConfirmed=false,exactWeaponIdentityConfirmed=false,
  readOnly=true,tradeOutcome="UNKNOWN",
  serverAttestation=false,serverCompletionProven=false,
  causalAttributionProven=false,authorizesTrade=false,
  authorizesAccept=false,mayRecordCompletedTrade=false,
  mayReportProfit=false}
 if type(input)~="table" then return r end
 if input.side~="YourOffer" and input.side~="TheirOffer" then
  r.reason="invalid-offer-side";return r
 end
 if not allowCount(input.index,4) or input.index<1 or
   input.slotVisible~=true then
  r.reason="native-slot-scope-unverified";return r
 end
 r.nativeOfferSlotObserved=true
 r.slotSide=input.side;r.slotIndex=input.index
 r.usesSpriteSheet=input.usesSpriteSheet==true
 local raw,format=iconKey(input.icon)
 r.iconReferenceFormat=format
 r.slotIconReferenceComparable=raw~=nil
 if input.imageVisible~=true then
  r.reason="slot-icon-image-not-visible";return r
 end
 if input.usesSpriteSheet~=true and input.usesSpriteSheet~=false then
  r.reason="sprite-metadata-unverified";return r
 end
 if input.catalogueVerified~=true or type(input.entries)~="table" or
    not allowCount(#input.entries,5000) or #input.entries==0 then
  r.reason="catalogue-unavailable-or-unbounded";return r
 end
 local seen={}
 local matches=0
 local withArt,missing,refCount,unresolved=0,0,0,0
 for i,entry in ipairs(input.entries) do
  if type(entry)~="table" or type(entry.key)~="string" or
     entry.key=="" or #entry.key>150 or seen[entry.key] or
     type(entry.refs)~="table" or #entry.refs>6 or
     not allowCount(#entry.refs,6) then
   r.reason="catalogue-entry-invalid-or-duplicate";return r
  end
  seen[entry.key]=true
  local keyset,match,hasArt,hasUnresolved={},false,false,false
  for _,candidate in ipairs(entry.refs) do
   if type(candidate)~="string" or #candidate>512 then
    r.reason="catalogue-art-value-malformed";return r
   end
   local ck,ckFormat=iconKey(candidate)
   recordFormat(r.catalogueReferenceFormatCounts,ckFormat)
   if not ck then hasUnresolved=true end
   if ck and not keyset[ck] then
    keyset[ck]=true;hasArt=true
    refCount=refCount+1
    if ck==raw then match=true end
   end
  end
  if hasArt then withArt=withArt+1 else missing=missing+1 end
  if hasUnresolved then unresolved=unresolved+1 end
  if match then matches=matches+1 end
 end
 r.catalogEntriesFormatInspected=#input.entries
 if not raw then
  r.reason="slot-icon-reference-not-comparable"
  return r
 end
 r.catalogEntriesAudited=#input.entries
 r.catalogEntriesWithComparableArt=withArt
 r.catalogEntriesWithoutComparableArt=missing
 r.catalogEntriesWithUnresolvedArt=unresolved
 -- Coverage of the supplied reference set only, not of the game's full
 -- catalogue, loaded artwork, or the GUI's undocumented rendering path.
 r.catalogueCoverageComplete=missing==0 and unresolved==0
 r.catalogImageCandidateReferences=refCount
 r.matchingCatalogueEntries=matches
 r.distinctMatchingWeaponKeys=matches
 if matches==0 then
  r.status="NO_MATCH_IN_READABLE_CATALOGUE"
  r.reason="asset-reference-not-equal-to-any-readable-catalogue-art"
 elseif matches>1 then
  r.status="MULTIPLE_CATALOGUE_ENTRIES_SHARE_ICON"
  r.reason="icon-reference-collision-across-multiple-weapons"
 elseif r.usesSpriteSheet then
  r.status="SPRITESHEET_REFERENCE_NOT_IDENTITY"
  r.reason="sprite-subregion-not-a-whole-weapon-icon"
 elseif not r.catalogueCoverageComplete then
  r.status="SINGLE_ICON_MATCH_WITH_COVERAGE_GAPS"
  r.reason="some-catalogue-art-missing-or-unresolved"
 else
  r.status="ONE_ICON_REFERENCE_MATCH_CLIENT_ONLY"
  r.reason="single-match-within-present-client-catalogue-only"
 end
 r.uniqueIconCandidateFound=matches==1 and not r.usesSpriteSheet
 r.imageReferenceAmbiguous=not (matches==1 and r.catalogueCoverageComplete
   and not r.usesSpriteSheet)
 return r
end
-- Native Stage36 uses ONLY the exact-reference path below. assess() above
-- remains for historical normalized-reference regression compatibility.
-- No URI parser, trim, case folding, ID extraction or URL resolution is used.
local artFields={"Image","Icon","Texture"}
local function exactString(s)
 return type(s)=="string" and #s>0 and #s<=4096
end
local function exactKey(k)
 return (type(k)=="string" and #k>0 and #k<=150) or
  (type(k)=="number" and k==k and k~=math.huge and k~=-math.huge)
end
local function dense(t,limit)
 if type(t)~="table" or #t>limit then return false end
 local count,length=0,#t
 for k in pairs(t) do
  count=count+1
  if count>limit or not allowCount(k,length) or k<1 then return false end
 end
 return count==length
end
function M.collectExact(sync)
 if type(sync)~="table" then return nil,"SYNC_CATALOGUE_UNAVAILABLE" end
 local cat={entries={},sourcesAliasSameTable=
  type(sync.Weapons)=="table" and sync.Weapons==sync.Item}
 for _,source in ipairs({"Weapons","Item"}) do
  local src=sync[source]
  if src~=nil and type(src)~="table" then return nil,"SYNC_SOURCE_NOT_TABLE" end
  for key,d in pairs(src or {}) do
   if not exactKey(key) or type(d)~="table" then
    return nil,"SYNC_ROW_INVALID"
   end
   if #cat.entries>=5000 then return nil,"SYNC_TOO_LARGE_OR_INVALID" end
   -- Never coalesce sources, typed keys, table aliases or equal art.
   local row={source=source,key=key,keyType=type(key),refs={},
    rarity=type(d.Rarity)=="string" and d.Rarity or nil,
    chroma=d.Chroma==true,
    missingArtFields=0,emptyArtFields=0,nonStringArtFields=0}
   for _,field in ipairs(artFields) do
    local value=d[field]
    if value==nil then row.missingArtFields=row.missingArtFields+1
    elseif type(value)~="string" then
     row.nonStringArtFields=row.nonStringArtFields+1
    elseif value=="" then row.emptyArtFields=row.emptyArtFields+1
    elseif not exactString(value) then return nil,"SYNC_ART_TOO_LARGE"
    else row.refs[#row.refs+1]={field=field,value=value} end
   end
   cat.entries[#cat.entries+1]=row
  end
 end
 if #cat.entries==0 then return nil,"SYNC_CATALOGUE_EMPTY" end
 return cat,"SYNC_READ_ONLY"
end
local function exactReport()
 return {schema="gingerscope-stage36-client-slot-icon-catalog-audit-exact-reference-v2",
  comparisonMode="BYTE_FOR_BYTE",status="INCOMPLETE",
  reason="missing-native-slot-or-catalogue",
  catalogEntriesAudited=0,catalogueReferencesCompared=0,
  matchingCatalogueEntries=0,matchingReferenceOccurrences=0,matchingSourceCount=0,
  duplicateReferenceGroups=0,rowsSharingReferences=0,
  stringifiedKeyOverlapGroups=0,conflictingStringifiedKeyGroups=0,
  missingArtEntries=0,missingArtFields=0,emptyArtFields=0,nonStringArtFields=0,
  sourcesAliasSameTable=false,catalogueCoverageComplete=false,
  nativeOfferSlotObserved=false,slotIconReferenceComparable=false,
  usesSpriteSheet=false,imageReferenceAmbiguous=true,uniqueIconCandidateFound=false,
  catalogueNotServerAttestation=true,referenceEqualityIsNotImageIdentity=true,
  rawItemIdConfirmed=false,exactWeaponIdentityConfirmed=false,
  readOnly=true,tradeOutcome="UNKNOWN",
  serverAttestation=false,serverCompletionProven=false,causalAttributionProven=false,
  authorizesTrade=false,authorizesAccept=false,
  mayRecordCompletedTrade=false,mayReportProfit=false}
end
function M.assessExact(input)
 local r=exactReport()
 if type(input)~="table" then return r end
 if (input.side~="YourOffer" and input.side~="TheirOffer") or
  not allowCount(input.index,4) or input.index<1 or input.slotVisible~=true then
  r.reason="native-slot-scope-unverified";return r
 end
 r.nativeOfferSlotObserved=true
 -- Deliberately no raw side/slot metadata or catalogue provenance in output.
 if input.imageVisible~=true or not exactString(input.icon) then
  r.reason="slot-icon-empty-invalid-or-not-visible";return r
 end
 if type(input.usesSpriteSheet)~="boolean" then
  r.reason="sprite-metadata-unverified";return r
 end
 local cat=input.catalogue
 if input.catalogueVerified~=true or type(cat)~="table" or
  not dense(cat.entries,5000) or #cat.entries==0 or
  type(cat.sourcesAliasSameTable)~="boolean" then
  r.reason="catalogue-unavailable-or-unbounded";return r
 end
 local seen={Weapons={},Item={}}
 local byReference,byText,matchedSources={},{},{}
 for _,row in ipairs(cat.entries) do
  if type(row)~="table" or not seen[row.source] or not exactKey(row.key) or
   row.keyType~=type(row.key) or seen[row.source][row.key] or
   not dense(row.refs,3) or not allowCount(row.missingArtFields,3) or
   not allowCount(row.emptyArtFields,3) or not allowCount(row.nonStringArtFields,3) or
   #row.refs+row.missingArtFields+row.emptyArtFields+row.nonStringArtFields~=3 then
   r.reason="catalogue-provenance-or-art-invalid";return r
  end
  seen[row.source][row.key]=true
  local fields,refset={},{}
  for _,art in ipairs(row.refs) do
   if type(art)~="table" or
    (art.field~="Image" and art.field~="Icon" and art.field~="Texture") or
    fields[art.field] or not exactString(art.value) then
    r.reason="catalogue-provenance-or-art-invalid";return r
   end
   fields[art.field]=art.value;refset[art.value]=true
  end
  -- tostring is used ONLY to detect overlapping textual keys, never to
  -- merge rows or to compare references. Field placement matters to conflict.
  local text=tostring(row.key)
  local group=byText[text]
  if not group then
   group={count=0,first=row,fields=fields,conflict=false};byText[text]=group
  else
   local first=group.first
   if first.rarity~=row.rarity or first.chroma~=row.chroma or
    first.missingArtFields~=row.missingArtFields or
    first.emptyArtFields~=row.emptyArtFields or
    first.nonStringArtFields~=row.nonStringArtFields then group.conflict=true end
   for _,field in ipairs(artFields) do
    if fields[field]~=group.fields[field] then group.conflict=true end
   end
  end
  group.count=group.count+1
  for reference in pairs(refset) do
   local owners=byReference[reference]
   if not owners then owners={};byReference[reference]=owners end
   owners[#owners+1]=row
  end
 end
 -- Validation completes before reporting any audited/equality counts.
 r.sourcesAliasSameTable=cat.sourcesAliasSameTable
 r.slotIconReferenceComparable=true;r.usesSpriteSheet=input.usesSpriteSheet
 local sharedRows={}
 for _,owners in pairs(byReference) do
  if #owners>1 then
   r.duplicateReferenceGroups=r.duplicateReferenceGroups+1
   for _,row in ipairs(owners) do sharedRows[row]=true end
  end
 end
 for _ in pairs(sharedRows) do r.rowsSharingReferences=r.rowsSharingReferences+1 end
 for _,group in pairs(byText) do
  if group.count>1 then r.stringifiedKeyOverlapGroups=r.stringifiedKeyOverlapGroups+1 end
  if group.conflict then r.conflictingStringifiedKeyGroups=r.conflictingStringifiedKeyGroups+1 end
 end
 for _,row in ipairs(cat.entries) do
  r.catalogEntriesAudited=r.catalogEntriesAudited+1
  r.missingArtFields=r.missingArtFields+row.missingArtFields
  r.emptyArtFields=r.emptyArtFields+row.emptyArtFields
  r.nonStringArtFields=r.nonStringArtFields+row.nonStringArtFields
  if #row.refs==0 then r.missingArtEntries=r.missingArtEntries+1 end
  local matched=false
  for _,art in ipairs(row.refs) do
   r.catalogueReferencesCompared=r.catalogueReferencesCompared+1
   -- This is the complete equivalence rule: original Lua string equality.
   if art.value==input.icon then
    matched=true;r.matchingReferenceOccurrences=r.matchingReferenceOccurrences+1
   end
  end
  if matched then
   r.matchingCatalogueEntries=r.matchingCatalogueEntries+1
   matchedSources[row.source]=true
  end
 end
 for _ in pairs(matchedSources) do r.matchingSourceCount=r.matchingSourceCount+1 end
 r.catalogueCoverageComplete=r.missingArtEntries==0 and r.nonStringArtFields==0
 if r.matchingCatalogueEntries==0 then
  r.status="NO_IDENTICAL_REFERENCE"
  r.reason="no-supplied-artwork-string-is-byte-identical"
 elseif r.usesSpriteSheet then
  r.status="SPRITESHEET_REFERENCE_NOT_IDENTITY"
  r.reason="identical-reference-does-not-compare-sprite-subregions"
 elseif r.matchingCatalogueEntries>1 then
  r.status="MULTIPLE_IDENTICAL_REFERENCE_ROWS"
  r.reason="identical-reference-shared-by-source-rows"
 elseif not r.catalogueCoverageComplete or r.conflictingStringifiedKeyGroups>0 then
  r.status="SINGLE_IDENTICAL_REFERENCE_WITH_GAPS"
  r.reason="one-matching-row-with-missing-art-or-key-conflicts"
 else
  r.status="SINGLE_IDENTICAL_REFERENCE_CLIENT_ONLY"
  r.reason="one-byte-identical-source-row-not-weapon-id-proof"
  r.imageReferenceAmbiguous=false
 end
 r.uniqueIconCandidateFound=r.matchingCatalogueEntries==1 and not r.usesSpriteSheet
 return r
end
return M
