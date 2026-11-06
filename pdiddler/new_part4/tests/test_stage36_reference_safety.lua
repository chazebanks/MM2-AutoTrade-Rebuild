-- Stage36 conservative reference equality and catalogue coverage regressions.
-- Every reference and key in this file is synthetic; no native URL is recorded.
local dir=arg[1] or "pdiddler/new_part4"
package.path=dir.."/?.lua;"..package.path
local M=require("p4_stage36_icon_catalog_audit")
local passed,failed=0,{}
local function check(name,fn)
 local okay,why=pcall(fn)
 if okay then
  passed=passed+1
  print("PASS "..name)
 else
  failed[#failed+1]=name..": "..tostring(why)
  print("FAIL "..failed[#failed])
 end
end
local function eq(actual,expected,label)
 assert(actual==expected,(label or "value").." expected "..
  tostring(expected)..", got "..tostring(actual))
end
local function entry(key,...)
 return {key=key,refs={...}}
end
local function guarded(r)
 eq(r.readOnly,true,"readOnly")
 eq(r.tradeOutcome,"UNKNOWN","tradeOutcome")
 eq(r.catalogueNotServerAttestation,true,"catalogueNotServerAttestation")
 for _,field in ipairs({"rawItemIdConfirmed","exactWeaponIdentityConfirmed",
  "serverAttestation","serverCompletionProven","causalAttributionProven",
  "authorizesTrade","authorizesAccept","mayRecordCompletedTrade",
  "mayReportProfit"}) do
  eq(r[field],false,field)
 end
 for _,field in ipairs({"rawIcon","rawAssetId","icon","imageURL",
  "itemId","weaponId","itemName","assetId","playerId","jobId",
  "partnerId","catalogue","entries","matchingKeys","matchingNames",
  "session","fingerprint","rawImage"}) do
  eq(r[field],nil,"no exported "..field)
 end
end
local function assess(icon,entries)
 local r=M.assess({side="TheirOffer",index=1,slotVisible=true,
  imageVisible=true,usesSpriteSheet=false,icon=icon,
  catalogueVerified=true,entries=entries or {
   entry("synthetic-first","rbxassetid://123456"),
   entry("synthetic-second","rbxassetid://999999")}})
 guarded(r)
 return r
end

local casePairs={
 {"filename","Weapon.png","weapon.png","FILENAME"},
 {"game asset path","rbxgameasset://Images/Potion",
  "rbxgameasset://Images/potion","ROBLOX_GAMEASSET"},
 {"built-in path","rbxasset://textures/Face.png",
  "rbxasset://textures/face.png","ROBLOX_BUILTIN_PATH"},
 {"rbxhttp query value","rbxhttp://Thumbs/Icon?token=AB",
  "rbxhttp://Thumbs/Icon?token=ab","ROBLOX_HTTP"},
}
for _,case in ipairs(casePairs) do
 check("case-sensitive "..case[1].." does not fold distinct references",function()
  local r=assess(case[2],{entry("synthetic-one",case[3])})
  eq(r.iconReferenceFormat,case[4],"reference format")
  eq(r.slotIconReferenceComparable,true,"slot comparable")
  eq(r.status,"NO_MATCH_IN_READABLE_CATALOGUE","status")
  eq(r.matchingCatalogueEntries,0,"matches")
  eq(r.uniqueIconCandidateFound,false,"unique candidate")
  eq(r.imageReferenceAmbiguous,true,"ambiguous")
 end)
 check("identical "..case[1].." remains a client reference match",function()
  local r=assess(case[2],{entry("synthetic-one",case[2])})
  eq(r.status,"ONE_ICON_REFERENCE_MATCH_CLIENT_ONLY","status")
  eq(r.matchingCatalogueEntries,1,"matches")
  eq(r.catalogEntriesWithUnresolvedArt,0,"unresolved entries")
  eq(r.catalogueCoverageComplete,true,"coverage complete")
 end)
end

local thumb="rbxthumb://type=Asset&id=123456&w=150&h=150"
for _,case in ipairs({
 {"width","rbxthumb://type=Asset&id=123456&w=420&h=150"},
 {"height","rbxthumb://type=Asset&id=123456&w=150&h=420"},
 {"both dimensions","rbxthumb://type=Asset&id=123456&w=420&h=420"},
}) do
 check("thumbnail "..case[1].." participates in reference equality",function()
  local r=assess(thumb,{entry("synthetic-thumb",case[2])})
  eq(r.iconReferenceFormat,"ROBLOX_THUMB_ASSET","reference format")
  eq(r.slotIconReferenceComparable,true,"slot comparable")
  eq(r.status,"NO_MATCH_IN_READABLE_CATALOGUE","status")
  eq(r.matchingCatalogueEntries,0,"matches")
  eq(r.uniqueIconCandidateFound,false,"unique candidate")
 end)
end
check("thumbnail with identical dimensions matches its exact reference",function()
 local r=assess(thumb,{entry("synthetic-thumb",thumb)})
 eq(r.status,"ONE_ICON_REFERENCE_MATCH_CLIENT_ONLY","status")
 eq(r.matchingCatalogueEntries,1,"matches")
 eq(r.catalogEntriesWithUnresolvedArt,0,"unresolved entries")
 eq(r.catalogueCoverageComplete,true,"coverage complete")
end)
check("thumbnail and raw asset ID remain separate reference families",function()
 local r=assess(thumb,{entry("synthetic-raw","rbxassetid://123456")})
 eq(r.status,"NO_MATCH_IN_READABLE_CATALOGUE","status")
 eq(r.matchingCatalogueEntries,0,"matches")
end)

check("unsupported art on matching entry leaves a coverage gap",function()
 local r=assess("rbxassetid://123456",{
  entry("synthetic-match","rbxassetid://123456",
   "https://fixture.invalid/opaque/matching-art"),
  entry("synthetic-other","rbxassetid://999999")})
 eq(r.status,"SINGLE_ICON_MATCH_WITH_COVERAGE_GAPS","status")
 eq(r.matchingCatalogueEntries,1,"matches")
 eq(r.catalogEntriesWithComparableArt,2,"comparable entries")
 eq(r.catalogEntriesWithoutComparableArt,0,"missing entries")
 eq(r.catalogEntriesWithUnresolvedArt,1,"unresolved entries")
 eq(r.catalogueCoverageComplete,false,"coverage complete")
 eq(r.imageReferenceAmbiguous,true,"ambiguous")
end)
check("unsupported art on otherwise comparable competitor leaves a coverage gap",function()
 local r=assess("rbxassetid://123456",{
  entry("synthetic-match","rbxassetid://123456"),
  entry("synthetic-other","rbxassetid://999999",
   "https://fixture.invalid/opaque/other-art")})
 eq(r.status,"SINGLE_ICON_MATCH_WITH_COVERAGE_GAPS","status")
 eq(r.matchingCatalogueEntries,1,"matches")
 eq(r.catalogEntriesWithComparableArt,2,"comparable entries")
 eq(r.catalogEntriesWithoutComparableArt,0,"missing entries")
 eq(r.catalogEntriesWithUnresolvedArt,1,"unresolved entries")
 eq(r.catalogueCoverageComplete,false,"coverage complete")
 eq(r.imageReferenceAmbiguous,true,"ambiguous")
end)
check("separate unsupported-only entry prevents complete catalogue coverage",function()
 local r=assess("rbxassetid://123456",{
  entry("synthetic-match","rbxassetid://123456"),
  entry("synthetic-unresolved","https://fixture.invalid/opaque/art")})
 eq(r.status,"SINGLE_ICON_MATCH_WITH_COVERAGE_GAPS","status")
 eq(r.catalogEntriesWithoutComparableArt,1,"missing entries")
 eq(r.catalogEntriesWithUnresolvedArt,1,"unresolved entries")
 eq(r.catalogueCoverageComplete,false,"coverage complete")
 eq(r.imageReferenceAmbiguous,true,"ambiguous")
end)
check("entry without any art prevents complete catalogue coverage",function()
 local r=assess("rbxassetid://123456",{
  entry("synthetic-match","rbxassetid://123456"),entry("synthetic-empty")})
 eq(r.status,"SINGLE_ICON_MATCH_WITH_COVERAGE_GAPS","status")
 eq(r.catalogEntriesWithoutComparableArt,1,"missing entries")
 eq(r.catalogEntriesWithUnresolvedArt,0,"unresolved entries")
 eq(r.catalogueCoverageComplete,false,"coverage complete")
 eq(r.imageReferenceAmbiguous,true,"ambiguous")
end)

check("synthetic 1040-reference HTTP distribution stays unassessed for equality",function()
 local entries={}
 for i=1,137 do
  entries[#entries+1]=entry("synthetic-asset-"..i,"rbxassetid://"..(100000+i))
 end
 for i=1,903 do
  entries[#entries+1]=entry("synthetic-opaque-"..i,
   "https://fixture.invalid/opaque/"..i)
 end
 local r=assess("https://fixture.invalid/images/123456.png",entries)
 eq(r.status,"INCOMPLETE","status")
 eq(r.reason,"slot-icon-reference-not-comparable","reason")
 eq(r.iconReferenceFormat,"OTHER_HTTP_IMAGE_REFERENCE","reference format")
 eq(r.nativeOfferSlotObserved,true,"visible native slot scope")
 eq(r.slotIconReferenceComparable,false,"slot comparable")
 eq(r.catalogEntriesFormatInspected,1040,"format-inspected entries")
 eq(r.catalogueReferenceFormatCounts.assetId,137,"asset reference occurrences")
 eq(r.catalogueReferenceFormatCounts.unsupported,903,"unsupported occurrences")
 for _,field in ipairs({"thumbAsset","gameAsset","builtin","robloxHttp","filename"}) do
  eq(r.catalogueReferenceFormatCounts[field],0,"other format "..field)
 end
 eq(r.catalogEntriesAudited,0,"entries compared")
 eq(r.catalogImageCandidateReferences,0,"candidate references compared")
 eq(r.matchingCatalogueEntries,0,"matches")
 eq(r.distinctMatchingWeaponKeys,0,"matching keys")
 eq(r.uniqueIconCandidateFound,false,"unique candidate")
 eq(r.imageReferenceAmbiguous,true,"ambiguous")
 eq(r.catalogueCoverageComplete,false,"coverage complete")
end)

local digitAliases={
 {"extra query parameter","https://www.roblox.com/asset/?id=123456&width=150",false},
 {"duplicate ID parameter","https://www.roblox.com/asset/?id=123456&id=999999",false},
 {"lookalike host","https://www.roblox.com.fixture.invalid/asset/?id=123456",false},
 {"alternate delivery host","https://assetdelivery.roblox.com/v1/asset/?id=123456",false},
 {"CDN path","https://tr.rbxcdn.com/123456/420/420/Weapon/Png",false},
 {"HTTP filename","https://fixture.invalid/123456.png",false},
 {"bare filename","123456.png",true},
}
for _,case in ipairs(digitAliases) do
 check("same digits in "..case[1].." cannot alias a catalogue asset ID",function()
  local r=assess(case[2])
  eq(r.slotIconReferenceComparable,case[3],"slot comparable")
  eq(r.matchingCatalogueEntries,0,"matches")
  eq(r.distinctMatchingWeaponKeys,0,"matching keys")
  eq(r.uniqueIconCandidateFound,false,"unique candidate")
  if case[3] then
   eq(r.status,"NO_MATCH_IN_READABLE_CATALOGUE","status")
  else
   eq(r.status,"INCOMPLETE","status")
   eq(r.catalogEntriesAudited,0,"entries compared")
   eq(r.catalogueCoverageComplete,false,"coverage complete")
  end
 end)
end

local rarities={"Common","Uncommon","Rare","Legendary","Godly",
 "Ancient","Vintage","Unique","Chroma"}
check("shared icon across every synthetic rarity counts all distinct catalogue keys",function()
 local entries={}
 for i,rarity in ipairs(rarities) do
  local row=entry("synthetic-tier-"..i,"rbxassetid://123456")
  row.rarity=rarity
  entries[#entries+1]=row
 end
 local r=assess("rbxassetid://123456",entries)
 eq(r.status,"MULTIPLE_CATALOGUE_ENTRIES_SHARE_ICON","status")
 eq(r.matchingCatalogueEntries,#rarities,"matches across tiers")
 eq(r.distinctMatchingWeaponKeys,#rarities,"matching keys across tiers")
 eq(r.uniqueIconCandidateFound,false,"unique candidate")
 eq(r.imageReferenceAmbiguous,true,"ambiguous")
end)
check("duplicate source key across synthetic rarity labels fails closed",function()
 local entries={}
 for _,rarity in ipairs(rarities) do
  local row=entry("synthetic-repeated-key","rbxassetid://123456")
  row.rarity=rarity
  entries[#entries+1]=row
 end
 local r=assess("rbxassetid://123456",entries)
 eq(r.status,"INCOMPLETE","status")
 eq(r.reason,"catalogue-entry-invalid-or-duplicate","reason")
 eq(r.uniqueIconCandidateFound,false,"unique candidate")
 eq(r.catalogueCoverageComplete,false,"coverage complete")
end)
check("duplicate references within one source key do not duplicate matching weapons",function()
 local r=assess("rbxassetid://123456",{
  entry("synthetic-one","rbxassetid://123456","rbxassetid://123456",
   "https://www.roblox.com/asset/?id=123456"),
  entry("synthetic-other","rbxassetid://999999")})
 eq(r.status,"ONE_ICON_REFERENCE_MATCH_CLIENT_ONLY","status")
 eq(r.matchingCatalogueEntries,1,"matching entries")
 eq(r.distinctMatchingWeaponKeys,1,"matching keys")
 eq(r.catalogImageCandidateReferences,2,"deduplicated candidate references")
 eq(r.catalogueReferenceFormatCounts.assetId,4,"raw format occurrences")
 eq(r.catalogueCoverageComplete,true,"coverage complete")
end)

print("Stage36 reference safety: "..passed.." passed, "..#failed.." failed")
if #failed>0 then
 error("Stage36 reference safety failures ("..#failed.."):\n"..
  table.concat(failed,"\n"),0)
end
