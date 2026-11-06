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
 local s=trim(x):lower()
 if s=="" then return nil,"EMPTY_OR_INVALID" end
 local id=s:match("^rbxassetid://(%d+)$") or
  s:match("^https?://www%.roblox%.com/asset/%?id=(%d+)$")
 if id then
  if not validId(id) then return nil,"INVALID_ASSET_ID" end
  return "asset:"..canonId(id),"ROBLOX_ASSET_ID"
 end
 local thumb,w,h=s:match("^rbxthumb://type=asset&id=(%d+)&w=(%d+)&h=(%d+)$")
 if thumb then
  local wi,hi=tonumber(w),tonumber(h)
  if not validId(thumb) or not wi or not hi or
     wi<1 or hi<1 or wi>2048 or hi>2048 then
   return nil,"ROBLOX_THUMB_INVALID"
  end
  return "thumb:"..canonId(thumb),"ROBLOX_THUMB_ASSET"
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
   local ck,ckFormat=iconKey(candidate)
   recordFormat(r.catalogueReferenceFormatCounts,ckFormat)
   if ck and not keyset[ck] then
    keyset[ck]=true;hasArt=true
    refCount=refCount+1
    if ck==raw then match=true end
   end
  end
  if hasArt then withArt=withArt+1 else missing=missing+1 end
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
