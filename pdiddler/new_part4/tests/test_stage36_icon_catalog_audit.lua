-- Stage36 pure catalogue icon collision audit. Actual Lua, no Roblox APIs.
local dir=arg[1] or "pdiddler/new_part4"
package.path=dir.."/?.lua;"..package.path
local M=require("p4_stage36_icon_catalog_audit")
local n=0
local function check(name,fn)
 local ok,why=pcall(fn)
 if not ok then error("FAILED "..name..": "..tostring(why)) end
 n=n+1
end
local function entry(key,...)
 return {key=key,refs={...}}
end
local function one(opts)
 opts=opts or {}
 return {side=opts.side or "TheirOffer",index=opts.index or 1,
  slotVisible=opts.slotVisible~=false,imageVisible=opts.imageVisible~=false,
  usesSpriteSheet=opts.usesSpriteSheet==true,
  icon=opts.icon or "rbxassetid://123456",
  catalogueVerified=opts.catalogueVerified~=false,
  entries=opts.entries or {entry("ancient-gun","rbxassetid://123456"),
      entry("ordinary-knife","rbxassetid://999999")}}
end
local function safe(r)
 assert(r.tradeOutcome=="UNKNOWN" and r.readOnly==true)
 assert(r.serverAttestation==false and r.serverCompletionProven==false)
 assert(r.causalAttributionProven==false and r.rawItemIdConfirmed==false)
 assert(r.exactWeaponIdentityConfirmed==false)
 assert(r.authorizesTrade==false and r.authorizesAccept==false)
 assert(r.mayRecordCompletedTrade==false and r.mayReportProfit==false)
 assert(r.catalogueNotServerAttestation==true)
 for _,field in ipairs({"rawIcon","rawAssetId","icon","imageURL",
  "itemId","weaponId","itemName","assetId","playerId","jobId",
  "partnerId","catalogue","entries","matchingKeys","matchingNames",
  "session","fingerprint","rawImage"}) do
  assert(r[field]==nil)
 end
end
check("one exact native image asset reference matches one complete client catalogue key",function()
 local r=M.assess(one())
 assert(r.status=="ONE_ICON_REFERENCE_MATCH_CLIENT_ONLY")
 assert(r.matchingCatalogueEntries==1 and r.catalogEntriesAudited==2)
 assert(r.catalogEntriesWithComparableArt==2 and r.catalogEntriesWithoutComparableArt==0)
 assert(r.uniqueIconCandidateFound and not r.imageReferenceAmbiguous)
 assert(r.iconReferenceFormat=="ROBLOX_ASSET_ID")
 safe(r)
end)
check("same image reused by Ancient and Common blocks uniqueness across ALL tiers",function()
 local inp=one({entries={entry("ancient-weapon","rbxassetid://123456"),
    entry("common-weapon","rbxassetid://123456"),
    entry("godly-weapon","rbxassetid://999999")}})
 local r=M.assess(inp)
 assert(r.status=="MULTIPLE_CATALOGUE_ENTRIES_SHARE_ICON")
 assert(r.matchingCatalogueEntries==2 and r.imageReferenceAmbiguous)
 assert(not r.uniqueIconCandidateFound)
 safe(r)
end)
check("two art fields on one item still count ONE matching weapon",function()
 local r=M.assess(one({entries={
  entry("one","rbxassetid://123456","rbxassetid://123456",
    "https://www.roblox.com/asset/?id=123456"),
  entry("two","rbxassetid://222222")}}))
 assert(r.status=="ONE_ICON_REFERENCE_MATCH_CLIENT_ONLY")
 assert(r.matchingCatalogueEntries==1 and r.catalogImageCandidateReferences==2)
 safe(r)
end)
check("Roblox asset links normalized only using exact recognized format",function()
 local r=M.assess(one({icon="https://www.roblox.com/asset/?id=00123456"}))
 assert(r.status=="ONE_ICON_REFERENCE_MATCH_CLIENT_ONLY")
 assert(r.matchingCatalogueEntries==1)
 safe(r)
end)
check("unrecognized asset-query suffix cannot masquerade as exact link",function()
 local r=M.assess(one({icon="https://www.roblox.com/asset/?id=123456&foo=1"}))
 assert(r.status=="INCOMPLETE")
 assert(r.iconReferenceFormat=="ROBLOX_ASSET_URL_UNSUPPORTED_VARIANT")
 assert(r.catalogEntriesAudited==0 and r.catalogEntriesFormatInspected==2)
 assert(r.catalogueReferenceFormatCounts.assetId==2)
 assert(r.slotIconReferenceComparable==false)
 safe(r)
end)
check("filename matching only when both use same exact filename",function()
 local inp=one({icon="Iceblaster.png",entries={
  entry("one","Iceblaster.png"),entry("two","Other.png")}})
 local r=M.assess(inp)
 assert(r.status=="ONE_ICON_REFERENCE_MATCH_CLIENT_ONLY")
 assert(r.iconReferenceFormat=="FILENAME")
 safe(r)
end)
check("filename is not equated to unrelated Roblox asset ID",function()
 local r=M.assess(one({icon="iceblaster.png"}))
 assert(r.status=="NO_MATCH_IN_READABLE_CATALOGUE")
 assert(r.matchingCatalogueEntries==0)
 safe(r)
end)
check("missing icon art fields prohibit assertion of full-catalogue uniqueness",function()
 local r=M.assess(one({entries={
   entry("one","rbxassetid://123456"),
   entry("two",""),
   entry("three","noComparable?")}}))
 assert(r.status=="SINGLE_ICON_MATCH_WITH_COVERAGE_GAPS")
 assert(r.catalogEntriesWithoutComparableArt==2)
 assert(r.uniqueIconCandidateFound and r.imageReferenceAmbiguous)
 safe(r)
end)
check("none of the catalogue references match is diagnostic not exact absence",function()
 local r=M.assess(one({icon="rbxassetid://111111"}))
 assert(r.status=="NO_MATCH_IN_READABLE_CATALOGUE")
 assert(r.catalogEntriesAudited==2)
 assert(r.imageReferenceAmbiguous)
 safe(r)
end)
check("duplicate source weapon key is invalid even if image matches",function()
 local r=M.assess(one({entries={
  entry("same","rbxassetid://123456"),entry("same","rbxassetid://123456")}}))
 assert(r.status=="INCOMPLETE" and r.reason=="catalogue-entry-invalid-or-duplicate")
 safe(r)
end)
check("missing catalogue is incomplete, not assumed absent icon",function()
 local inp=one();inp.catalogueVerified=false
 local r=M.assess(inp)
 assert(r.status=="INCOMPLETE")
 safe(r)
end)
check("empty catalogue is incomplete",function()
 local inp=one();inp.entries={}
 local r=M.assess(inp)
 assert(r.status=="INCOMPLETE")
 safe(r)
end)
check("unreadable icon is incomplete",function()
 local inp=one();inp.icon=""
 local r=M.assess(inp)
 assert(r.status=="INCOMPLETE" and
   r.iconReferenceFormat=="EMPTY_OR_INVALID")
 safe(r)
end)
check("nonvisible occupied icon must not be trusted",function()
 local inp=one({imageVisible=false})
 local r=M.assess(inp)
 assert(r.status=="INCOMPLETE" and
   r.reason=="slot-icon-image-not-visible")
 safe(r)
end)
check("unknown sprite metadata is incomplete",function()
 local inp=one();inp.usesSpriteSheet=nil
 local r=M.assess(inp)
 assert(r.status=="INCOMPLETE" and r.reason=="sprite-metadata-unverified")
 safe(r)
end)
check("sprite sheet reference is NOT entire weapon identity",function()
 local inp=one();inp.usesSpriteSheet=true
 local r=M.assess(inp)
 assert(r.status=="SPRITESHEET_REFERENCE_NOT_IDENTITY")
 assert(r.uniqueIconCandidateFound==false and r.imageReferenceAmbiguous)
 safe(r)
end)
check("empty non-string catalogue art not silently counted as comparable",function()
 local inp=one();inp.entries={entry("one","rbxassetid://123456")}
 inp.entries[1].refs[2]={oops=true}
 local r=M.assess(inp)
 assert(r.status=="INCOMPLETE" and r.reason=="catalogue-art-value-malformed")
 safe(r)
end)
check("invalid context fails closed",function()
 local inp=one();inp.side="Other"
 local r=M.assess(inp)
 assert(r.status=="INCOMPLETE")
 safe(r)
 local i2=one();i2.index=5
 assert(M.assess(i2).status=="INCOMPLETE")
end)
check("missing entries not identifiable by copy counts alone",function()
 local inp=one({entries={
  entry("one","rbxassetid://123456"),entry("two",""),
  entry("three","rbxassetid://987654")}})
 local r=M.assess(inp)
 assert(r.matchingCatalogueEntries==1)
 assert(r.status=="SINGLE_ICON_MATCH_WITH_COVERAGE_GAPS")
 assert(not r.rawItemIdConfirmed)
 safe(r)
end)
check("read-only module does not output raw client catalogue metadata",function()
 local inp=one()
 inp.entries[1].rarity="ANCiENT secret";inp.entries[1].name="private_name"
 local r=M.assess(inp)
 assert(r.name==nil and r.rarity==nil and r.icon==nil)
 assert(r.rawItemIdConfirmed==false)
 safe(r)
end)
check("official rbxthumb Asset URI now comparable to another thumb reference",function()
 local r=M.assess(one({icon="rbxthumb://type=Asset&id=000123456&w=150&h=150",
  entries={
   entry("ancient","rbxthumb://type=Asset&id=123456&w=150&h=150"),
   entry("common","rbxassetid://999999")}}))
 assert(r.status=="ONE_ICON_REFERENCE_MATCH_CLIENT_ONLY")
 assert(r.iconReferenceFormat=="ROBLOX_THUMB_ASSET")
 assert(r.catalogueReferenceFormatCounts.thumbAsset==1)
 assert(r.catalogueReferenceFormatCounts.assetId==1)
 assert(r.catalogEntriesFormatInspected==2 and r.catalogEntriesAudited==2)
 assert(r.slotIconReferenceComparable==true)
 safe(r)
end)
check("thumb asset and raw rbxassetid remain distinct icon families",function()
 local r=M.assess(one({icon="rbxthumb://type=Asset&id=123456&w=150&h=150"}))
 assert(r.status=="NO_MATCH_IN_READABLE_CATALOGUE")
 assert(r.iconReferenceFormat=="ROBLOX_THUMB_ASSET")
 assert(r.matchingCatalogueEntries==0)
 safe(r)
end)
check("thumbnail Asset ID shared with excluded tier detected as collision",function()
 local r=M.assess(one({icon="rbxthumb://type=Asset&id=123456&w=150&h=150",
  entries={
   entry("ancient","rbxthumb://type=Asset&id=123456&w=150&h=150"),
   entry("common","rbxthumb://type=Asset&id=123456&w=150&h=150")}}))
 assert(r.status=="MULTIPLE_CATALOGUE_ENTRIES_SHARE_ICON")
 assert(r.matchingCatalogueEntries==2)
 safe(r)
end)
check("thumbnail Avatar type cannot be mistaken for an Asset weapon icon",function()
 local r=M.assess(one({icon="rbxthumb://type=Avatar&id=123456&w=150&h=150"}))
 assert(r.status=="INCOMPLETE")
 assert(r.iconReferenceFormat=="ROBLOX_THUMB_UNSUPPORTED_VARIANT")
 assert(r.catalogEntriesAudited==0 and r.catalogEntriesFormatInspected==2)
 assert(r.catalogueReferenceFormatCounts.assetId==2)
 assert(not r.slotIconReferenceComparable)
 safe(r)
end)
check("thumbnail untrusted query injection rejected without surfacing token or ID",function()
 local r=M.assess(one({icon=
  "rbxthumb://type=Asset&id=123456&w=150&h=150&extra=SensitiveToken"}))
 assert(r.status=="INCOMPLETE")
 assert(r.iconReferenceFormat=="ROBLOX_THUMB_UNSUPPORTED_VARIANT")
 assert(r.catalogEntriesFormatInspected==2)
 assert(r.icon==nil and r.rawAssetId==nil)
 safe(r)
end)
check("Roblox game-local asset path is matched only to identical project path",function()
 local r=M.assess(one({icon="rbxgameasset://Images/Potion",
  entries={
   entry("godly","rbxgameasset://Images/Potion"),
   entry("vintage","rbxassetid://123456")}}))
 assert(r.status=="ONE_ICON_REFERENCE_MATCH_CLIENT_ONLY")
 assert(r.iconReferenceFormat=="ROBLOX_GAMEASSET")
 assert(r.catalogueReferenceFormatCounts.gameAsset==1)
 safe(r)
end)
check("Roblox built-in resource URI is distinct from game asset",function()
 local r=M.assess(one({icon="rbxasset://textures/face.png",
  entries={
   entry("one","rbxasset://textures/face.png"),
   entry("other","rbxgameasset://Images/face.png")}}))
 assert(r.status=="ONE_ICON_REFERENCE_MATCH_CLIENT_ONLY")
 assert(r.catalogueReferenceFormatCounts.builtin==1)
 safe(r)
end)
check("documented Roblox rbxhttp reference compared as URI string not numeric substring",function()
 local r=M.assess(one({icon="rbxhttp://Thumbs/Avatar.ashx?x=100&y=100&format=png",
  entries={
   entry("item1","rbxhttp://Thumbs/Avatar.ashx?x=100&y=100&format=png"),
   entry("item2","rbxassetid://123456")}}))
 assert(r.status=="ONE_ICON_REFERENCE_MATCH_CLIENT_ONLY")
 assert(r.iconReferenceFormat=="ROBLOX_HTTP")
 safe(r)
end)
check("unknown scheme is labeled only by safe family and audits catalogue formats",function()
 local r=M.assess(one({icon="customscheme://a/12345?secret=456"}))
 assert(r.status=="INCOMPLETE")
 assert(r.iconReferenceFormat=="OTHER_URI_SCHEME")
 assert(r.catalogEntriesAudited==0)
 assert(r.catalogEntriesFormatInspected==2)
 assert(r.catalogueReferenceFormatCounts.assetId==2)
 assert(r.rawAssetId==nil and r.icon==nil)
 safe(r)
end)
check("undocumented numeric-only icon is not guessed to equal catalog asset",function()
 local r=M.assess(one({icon="123456"}))
 assert(r.status=="INCOMPLETE")
 assert(r.iconReferenceFormat=="PLAIN_NUMERIC_REFERENCE")
 assert(r.matchingCatalogueEntries==0)
 assert(r.catalogEntriesFormatInspected==2)
 safe(r)
end)
check("invalid thumbnail dimensions cannot become an accepted thumbnail ID",function()
 local r=M.assess(one({icon="rbxthumb://type=Asset&id=123456&w=0&h=150"}))
 assert(r.status=="INCOMPLETE" and
   r.iconReferenceFormat=="ROBLOX_THUMB_INVALID")
 safe(r)
end)
check("synthetic unsupported thumbnail is incomplete not empty Sync catalogue",function()
 local r=M.assess(one({side="YourOffer",index=1,icon="rbxthumb://type=User&id=123456&w=150&h=150"}))
 assert(r.status=="INCOMPLETE")
 assert(r.nativeOfferSlotObserved==true and r.slotSide=="YourOffer")
 assert(r.catalogEntriesAudited==0 and r.catalogEntriesFormatInspected==2)
 assert(r.catalogueReferenceFormatCounts.assetId==2)
 assert(r.reason=="slot-icon-reference-not-comparable")
 safe(r)
end)
print("PASS",n,"Stage36 client icon vs all-tier Sync catalogue collision audit")
