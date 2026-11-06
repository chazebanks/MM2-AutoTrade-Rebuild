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
local function iconKey(x)
 if not legal(x) then return nil,"EMPTY_OR_INVALID" end
 local s=trim(x)
 if s=="" then return nil,"EMPTY_OR_INVALID" end
 s=s:lower()
 local id=s:match("^rbxassetid://(%d+)$")
 if not id then
  id=s:match("^https?://www%.roblox%.com/asset/%?id=(%d+)$")
 end
 if id then
  if #id>22 or id:match("^0+$") then return nil,"INVALID_ASSET_ID" end
  id=id:gsub("^0+","")
  return "id:"..id,"ROBLOX_ASSET_ID"
 end
 if s:match("^rbxasset://[%w_/%-%.]+$") then
  return "builtin:"..s,"ROBLOX_BUILTIN_PATH"
 end
 if s:match("^[%w_%-%.]+%.png$") or
    s:match("^[%w_%-%.]+%.jpg$") or
    s:match("^[%w_%-%.]+%.jpeg$") then
  return "filename:"..s,"FILENAME"
 end
 return nil,"INCOMPARABLE_REFERENCE_FORMAT"
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
  catalogImageCandidateReferences=0,
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
 if not raw then r.reason="slot-icon-reference-not-comparable";return r end
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
 local seen={},0
 local matches=0
 local withArt,missing,refCount=0,0,0
 for i,entry in ipairs(input.entries) do
  if type(entry)~="table" or type(entry.key)~="string" or
     entry.key=="" or #entry.key>150 or seen[entry.key] or
     type(entry.refs)~="table" or #entry.refs>6 or
     not allowCount(#entry.refs,6) then
   r.reason="catalogue-entry-invalid-or-duplicate";return r
  end
  seen[entry.key]=true
  local keyset,match,hasArt={},false,false
  for _,candidate in ipairs(entry.refs) do
   if type(candidate)~="string" or #candidate>512 then
    r.reason="catalogue-art-value-malformed";return r
   end
   local ck=iconKey(candidate)
   if ck and not keyset[ck] then
    keyset[ck]=true;hasArt=true
    refCount=refCount+1
    if ck==raw then match=true end
   end
  end
  if hasArt then withArt=withArt+1 else missing=missing+1 end
  if match then matches=matches+1 end
 end
 r.catalogEntriesAudited=#input.entries
 r.catalogEntriesWithComparableArt=withArt
 r.catalogEntriesWithoutComparableArt=missing
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
 elseif missing>0 then
  r.status="SINGLE_ICON_MATCH_WITH_COVERAGE_GAPS"
  r.reason="some-catalogue-entries-lack-comparable-image"
 else
  r.status="ONE_ICON_REFERENCE_MATCH_CLIENT_ONLY"
  r.reason="single-match-within-present-client-catalogue-only"
 end
 r.uniqueIconCandidateFound=matches==1 and not r.usesSpriteSheet
 r.imageReferenceAmbiguous=not (matches==1 and missing==0
   and not r.usesSpriteSheet)
 return r
end
return M
