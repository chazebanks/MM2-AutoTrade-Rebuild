-- Stage36 byte-for-byte client-reference audit. All fixture data is synthetic.
-- Run with Lua 5.4; no Roblox APIs, source-text assertions, or network calls.
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
local counters={"catalogEntriesAudited","catalogueReferencesCompared",
 "matchingCatalogueEntries","matchingReferenceOccurrences","matchingSourceCount",
 "duplicateReferenceGroups","rowsSharingReferences","stringifiedKeyOverlapGroups",
 "conflictingStringifiedKeyGroups","missingArtEntries","missingArtFields",
 "emptyArtFields","nonStringArtFields"}
local forbidden={}
for _,field in ipairs({"rawIcon","rawAssetId","icon","imageURL","imageUrl",
 "rawImage","itemId","weaponId","itemName","assetId","playerId","jobId",
 "partnerId","catalogue","entries","refs","matchingKeys","matchingNames",
 "matchingSources","source","key","keyType","Image","Icon","Texture",
 "rarity","chroma","name","session","fingerprint","provenance","sync"}) do
 forbidden[field]=true
end
local reportsChecked=0
local function guarded(r)
 eq(type(r),"table","report type")
 eq(r.schema,"gingerscope-stage36-client-slot-icon-catalog-audit-exact-reference-v2","schema")
 eq(r.comparisonMode,"BYTE_FOR_BYTE","comparison mode")
 eq(r.readOnly,true,"readOnly")
 eq(r.tradeOutcome,"UNKNOWN","tradeOutcome")
 eq(r.catalogueNotServerAttestation,true,"catalogueNotServerAttestation")
 for _,field in ipairs({"rawItemIdConfirmed","exactWeaponIdentityConfirmed",
  "serverAttestation","serverCompletionProven","causalAttributionProven",
  "authorizesTrade","authorizesAccept","mayRecordCompletedTrade","mayReportProfit"}) do
  eq(r[field],false,field)
 end
 for _,field in ipairs(counters) do
  local value=r[field]
  assert(type(value)=="number" and value>=0 and value==math.floor(value),
   field.." must be a nonnegative integer")
 end
 eq(type(r.imageReferenceAmbiguous),"boolean","ambiguity type")
 eq(type(r.catalogueCoverageComplete),"boolean","coverage type")
 eq(type(r.sourcesAliasSameTable),"boolean","alias type")
 local seen={}
 local function noPrivate(value)
  if type(value)=="table" then
   assert(not seen[value],"report must not contain cyclic/private tables")
   seen[value]=true
   for key,child in pairs(value) do
    assert(not forbidden[key],"private field exported: "..tostring(key))
    noPrivate(child)
   end
  elseif type(value)=="string" then
   assert(not value:find("://",1,true),"raw reference exported")
   assert(not value:find("PrivateExactSentinel",1,true),"private fixture metadata exported")
   assert(value~="Weapons" and value~="Item","source provenance exported")
  end
 end
 noPrivate(r)
 reportsChecked=reportsChecked+1
 return r
end
local function collect(sync)
 eq(type(M.collectExact),"function","collectExact export")
 local catalogue,reason=M.collectExact(sync)
 assert(type(catalogue)=="table","fixture collection failed: "..tostring(reason))
 eq(type(catalogue.entries),"table","catalogue entries")
 return catalogue
end
local function input(sync,icon)
 return {side="TheirOffer",index=1,slotVisible=true,imageVisible=true,
  usesSpriteSheet=false,icon=icon or "https://fixture.invalid/art/exact?token=AB",
  catalogueVerified=true,catalogue=collect(sync or {
   Weapons={one={Image="https://fixture.invalid/art/exact?token=AB"}}})}
end
local function assessInput(value)
 eq(type(M.assessExact),"function","assessExact export")
 return guarded(M.assessExact(value))
end
local function assess(sync,icon)
 return assessInput(input(sync,icon))
end
local function rowBy(catalogue,source,key)
 for _,row in ipairs(catalogue.entries) do
  if row.source==source and type(row.key)==type(key) and row.key==key then
   return row
  end
 end
 error("missing original typed source row")
end
local function refBy(row,field)
 for _,ref in ipairs(row.refs) do
  if ref.field==field then return ref end
 end
 error("missing original art field "..field)
end

check("exact collector and assessor are independently exported",function()
 eq(type(M.collectExact),"function","collectExact export")
 eq(type(M.assessExact),"function","assessExact export")
end)
check("collector preserves source typed keys and original nonempty reference bytes",function()
 local marker={PrivateExactSentinel="non-string-art"}
 local sync={Weapons={
  [7]={Image=" HTTP://fixture.invalid/PrivateExactSentinel?B=2&A=1 ",
   Icon="",Texture=marker,Rarity="PrivateExactSentinelAncient",Chroma=true},
  ["7"]={Image="Other.png",Icon=false,Texture=81}},
  Item={same={Image="Exact.png"}}}
 local c=collect(sync)
 eq(#c.entries,3,"preserved row count")
 eq(c.sourcesAliasSameTable,false,"distinct source tables")
 local numeric=rowBy(c,"Weapons",7)
 eq(numeric.keyType,"number","numeric key type")
 eq(refBy(numeric,"Image").value,sync.Weapons[7].Image,"unmodified image")
 eq(#numeric.refs,1,"empty and non-string values are counted outside reference list")
 eq(numeric.missingArtFields,0,"present art fields")
 eq(numeric.emptyArtFields,1,"empty art fields")
 eq(numeric.nonStringArtFields,1,"non-string art fields")
 eq(numeric.rarity,"PrivateExactSentinelAncient","internal rarity")
 eq(numeric.chroma,true,"internal chroma")
 local textual=rowBy(c,"Weapons","7")
 eq(textual.keyType,"string","string key type")
 eq(#textual.refs,1,"false and numeric art are not comparable references")
 eq(textual.nonStringArtFields,2,"two non-string fields")
 local item=rowBy(c,"Item","same")
 eq(item.missingArtFields,2,"missing art counted internally")
 eq(sync.Weapons[7].Texture,marker,"source untouched")
 eq(sync.Weapons[7].Image," HTTP://fixture.invalid/PrivateExactSentinel?B=2&A=1 ","source bytes untouched")
 assessInput(input(sync,sync.Weapons[7].Image))
end)

check("opaque HTTP identical bytes count as one client-only reference match",function()
 local r=assess()
 eq(r.status,"SINGLE_IDENTICAL_REFERENCE_CLIENT_ONLY","status")
 eq(r.catalogEntriesAudited,1,"audited rows")
 eq(r.catalogueReferencesCompared,1,"compared occurrences")
 eq(r.matchingCatalogueEntries,1,"matching source rows")
 eq(r.matchingReferenceOccurrences,1,"matching field occurrences")
 eq(r.matchingSourceCount,1,"matching source count")
 eq(r.missingArtFields,2,"absent optional art fields")
 eq(r.missingArtEntries,0,"rows without any nonempty string art")
 eq(r.catalogueCoverageComplete,true,"coverage")
 eq(r.imageReferenceAmbiguous,false,"reference ambiguity")
end)
check("opaque HTTP different bytes produce a complete no-match audit",function()
 local r=assess(nil,"https://fixture.invalid/art/absent?token=AB")
 eq(r.status,"NO_IDENTICAL_REFERENCE","status")
 eq(r.catalogEntriesAudited,1,"audited rows")
 eq(r.catalogueReferencesCompared,1,"all references compared")
 eq(r.matchingCatalogueEntries,0,"matching rows")
 eq(r.matchingReferenceOccurrences,0,"matching occurrences")
 eq(r.matchingSourceCount,0,"matching sources")
 eq(r.imageReferenceAmbiguous,true,"ambiguity")
end)

local unequal={
 {"leading whitespace","https://fixture.invalid/Art?A=1&B=2"," https://fixture.invalid/Art?A=1&B=2"},
 {"trailing whitespace","https://fixture.invalid/Art?A=1&B=2","https://fixture.invalid/Art?A=1&B=2 "},
 {"filename case","Weapon.png","weapon.png"},
 {"HTTP host case","https://FIXTURE.invalid/Art","https://fixture.invalid/Art"},
 {"HTTP path case","https://fixture.invalid/Art","https://fixture.invalid/art"},
 {"HTTP query value case","https://fixture.invalid/art?token=AB","https://fixture.invalid/art?token=ab"},
 {"query parameter order","https://fixture.invalid/art?A=1&B=2","https://fixture.invalid/art?B=2&A=1"},
 {"scheme case","HTTPS://fixture.invalid/art","https://fixture.invalid/art"},
 {"HTTP and HTTPS","http://fixture.invalid/art","https://fixture.invalid/art"},
 {"asset leading zeroes","rbxassetid://000123456","rbxassetid://123456"},
 {"asset URL leading zeroes","https://www.roblox.com/asset/?id=000123456","https://www.roblox.com/asset/?id=123456"},
 {"asset URL and raw asset scheme","https://www.roblox.com/asset/?id=123456","rbxassetid://123456"},
 {"thumbnail and raw asset scheme","rbxthumb://type=Asset&id=123456&w=150&h=150","rbxassetid://123456"},
 {"thumbnail width","rbxthumb://type=Asset&id=123456&w=150&h=150","rbxthumb://type=Asset&id=123456&w=420&h=150"},
 {"thumbnail height","rbxthumb://type=Asset&id=123456&w=150&h=150","rbxthumb://type=Asset&id=123456&w=150&h=420"},
 {"thumbnail query order","rbxthumb://type=Asset&id=123456&w=150&h=150","rbxthumb://type=Asset&w=150&h=150&id=123456"},
 {"thumbnail numeric spelling","rbxthumb://type=Asset&id=123456&w=0150&h=150","rbxthumb://type=Asset&id=123456&w=150&h=150"},
 {"plain digits and asset ID","123456","rbxassetid://123456"},
 {"numeric substring","https://fixture.invalid/123456.png","rbxassetid://123456"},
 {"game asset path case","rbxgameasset://Images/Potion","rbxgameasset://Images/potion"},
}
for _,case in ipairs(unequal) do
 check("byte comparison never normalizes "..case[1],function()
  local r=assess({Weapons={one={Image=case[3]}}},case[2])
  eq(r.status,"NO_IDENTICAL_REFERENCE","status")
  eq(r.catalogueReferencesCompared,1,"comparison count")
  eq(r.matchingCatalogueEntries,0,"matching rows")
  eq(r.catalogueCoverageComplete,true,"opaque strings remain covered")
 end)
end
for _,reference in ipairs({"  Exact.png  ","123456",
 "customscheme://PrivateExactSentinel/art?token=AB",
 "https://fixture.invalid/PrivateExactSentinel?unrecognized=1",
 "rbxthumb://type=Avatar&id=123456&w=0&h=150&extra=1"}) do
 check("identical nonempty bytes remain comparable without format allowlisting: "..
  tostring(_),function()
  local r=assess({Weapons={one={Image=reference}}},reference)
  eq(r.status,"SINGLE_IDENTICAL_REFERENCE_CLIENT_ONLY","status")
  eq(r.matchingCatalogueEntries,1,"matches")
  eq(r.catalogueCoverageComplete,true,"complete byte coverage")
 end)
end

check("all rarity tiers and chroma participate in shared-reference collisions",function()
 local weapons={}
 for i,rarity in ipairs({"Common","Uncommon","Rare","Legendary","Godly",
  "Ancient","Vintage","Unique","Chroma"}) do
  weapons["PrivateExactSentinelTier"..i]={Image="shared.png",Rarity=rarity,
   Chroma=rarity=="Chroma"}
 end
 local r=assess({Weapons=weapons},"shared.png")
 eq(r.status,"MULTIPLE_IDENTICAL_REFERENCE_ROWS","status")
 eq(r.catalogEntriesAudited,9,"all tiers audited")
 eq(r.catalogueReferencesCompared,9,"all tiers compared")
 eq(r.matchingCatalogueEntries,9,"all tiers match")
 eq(r.matchingReferenceOccurrences,9,"matching occurrences")
 eq(r.matchingSourceCount,1,"one catalogue source")
 eq(r.duplicateReferenceGroups,1,"one shared reference")
 eq(r.rowsSharingReferences,9,"all shared rows")
 eq(r.imageReferenceAmbiguous,true,"ambiguity")
end)
check("duplicate art fields count occurrences while matching their row only once",function()
 local r=assess({Weapons={one={Image="same.png",Icon="same.png",Texture="same.png"}}},"same.png")
 eq(r.status,"SINGLE_IDENTICAL_REFERENCE_CLIENT_ONLY","status")
 eq(r.catalogEntriesAudited,1,"one source row")
 eq(r.catalogueReferencesCompared,3,"three field comparisons")
 eq(r.matchingCatalogueEntries,1,"one row match")
 eq(r.matchingReferenceOccurrences,3,"three field matches")
 eq(r.duplicateReferenceGroups,0,"same-row duplication is not shared-row duplication")
 eq(r.rowsSharingReferences,0,"no rows share art with another row")
 eq(r.imageReferenceAmbiguous,false,"reference unambiguous")
end)
check("global shared-reference counts include unmatched references and count each row once",function()
 local r=assess({Weapons={
  match={Image="slot.png"},a={Image="shared-a.png",Icon="shared-b.png"},
  b={Image="shared-a.png",Icon="shared-b.png"},c={Image="shared-b.png"}}},"slot.png")
 eq(r.status,"SINGLE_IDENTICAL_REFERENCE_CLIENT_ONLY","status")
 eq(r.catalogueReferencesCompared,6,"all occurrences inspected")
 eq(r.duplicateReferenceGroups,2,"two global shared references")
 eq(r.rowsSharingReferences,3,"union of rows sharing references")
 eq(r.matchingCatalogueEntries,1,"one matching row")
 eq(r.imageReferenceAmbiguous,false,"unmatched duplication cannot duplicate slot reference")
end)
check("same key in distinct sources preserves both conflicting source rows",function()
 local sync={Weapons={same={Image="weapon.png"}},Item={same={Image="item.png"}}}
 local c=collect(sync)
 eq(#c.entries,2,"source rows are never merged")
 eq(rowBy(c,"Weapons","same").keyType,"string","weapon key type")
 eq(rowBy(c,"Item","same").keyType,"string","item key type")
 local r=assess(sync,"weapon.png")
 eq(r.status,"SINGLE_IDENTICAL_REFERENCE_WITH_GAPS","status")
 eq(r.catalogEntriesAudited,2,"both rows audited")
 eq(r.catalogueReferencesCompared,2,"both rows compared")
 eq(r.matchingCatalogueEntries,1,"one row matches")
 eq(r.stringifiedKeyOverlapGroups,1,"same string key overlap")
 eq(r.conflictingStringifiedKeyGroups,1,"different reference sets conflict")
 eq(r.catalogueCoverageComplete,true,"all source art present")
 eq(r.imageReferenceAmbiguous,true,"key conflict prevents uniqueness")
end)
check("identical same key rows across sources are two matches without key conflict",function()
 local r=assess({Weapons={same={Image="same.png"}},Item={same={Image="same.png"}}},"same.png")
 eq(r.status,"MULTIPLE_IDENTICAL_REFERENCE_ROWS","status")
 eq(r.matchingCatalogueEntries,2,"two source row matches")
 eq(r.matchingReferenceOccurrences,2,"two field matches")
 eq(r.matchingSourceCount,2,"two matching sources")
 eq(r.stringifiedKeyOverlapGroups,1,"one overlapping key")
 eq(r.conflictingStringifiedKeyGroups,0,"identical rows do not conflict")
 eq(r.duplicateReferenceGroups,1,"one cross-source duplicate reference")
 eq(r.rowsSharingReferences,2,"two shared source rows")
end)
check("numeric and string keys in one source survive tostring overlap",function()
 local sync={Weapons={[7]={Image="seven-number.png"},["7"]={Image="seven-string.png"}}}
 local c=collect(sync)
 eq(#c.entries,2,"typed keys preserved")
 eq(rowBy(c,"Weapons",7).keyType,"number","number key")
 eq(rowBy(c,"Weapons","7").keyType,"string","string key")
 local r=assess(sync,"seven-number.png")
 eq(r.status,"SINGLE_IDENTICAL_REFERENCE_WITH_GAPS","status")
 eq(r.catalogEntriesAudited,2,"both typed rows audited")
 eq(r.stringifiedKeyOverlapGroups,1,"typed tostring overlap")
 eq(r.conflictingStringifiedKeyGroups,1,"typed key art conflict")
 eq(r.matchingCatalogueEntries,1,"typed rows never merge")
 eq(r.imageReferenceAmbiguous,true,"conflict prevents uniqueness")
end)
check("tostring key overlap groups are counted once across multiple typed source rows",function()
 local r=assess({Weapons={[7]={Image="same.png"},["7"]={Image="same.png"}},
  Item={[7]={Image="same.png"},["7"]={Image="same.png"}}},"same.png")
 eq(r.catalogEntriesAudited,4,"four source typed rows")
 eq(r.matchingCatalogueEntries,4,"four matches")
 eq(r.stringifiedKeyOverlapGroups,1,"one tostring group")
 eq(r.conflictingStringifiedKeyGroups,0,"same art mappings")
 eq(r.duplicateReferenceGroups,1,"one shared reference group")
 eq(r.rowsSharingReferences,4,"all source typed rows share")
end)
check("aliased source tables preserve Weapons and Item provenance independently",function()
 local shared={one={Image="alias.png"},two={Image="other.png"}}
 local sync={Weapons=shared,Item=shared}
 local c=collect(sync)
 eq(c.sourcesAliasSameTable,true,"source alias detected internally")
 eq(#c.entries,4,"aliased rows are preserved twice")
 eq(refBy(rowBy(c,"Weapons","one"),"Image").value,"alias.png","Weapons reference")
 eq(refBy(rowBy(c,"Item","one"),"Image").value,"alias.png","Item reference")
 local r=assess(sync,"alias.png")
 eq(r.sourcesAliasSameTable,true,"source alias flag")
 eq(r.catalogEntriesAudited,4,"all aliased source rows audited")
 eq(r.matchingCatalogueEntries,2,"two source provenance matches")
 eq(r.matchingSourceCount,2,"two matching source labels")
 eq(r.stringifiedKeyOverlapGroups,2,"each source key overlaps")
 eq(r.conflictingStringifiedKeyGroups,0,"alias art does not conflict")
 eq(r.duplicateReferenceGroups,2,"two shared references")
 eq(r.rowsSharingReferences,4,"all source rows share art")
 eq(r.status,"MULTIPLE_IDENTICAL_REFERENCE_ROWS","status")
end)
check("missing empty and non-string art have distinct counts without discarded rows",function()
 local bad={PrivateExactSentinel="table-art"}
 local sync={Weapons={
  match={Image="match.png"},missing={},empty={Image="",Icon=""},
  invalid={Image=false,Icon=42,Texture=bad},mixed={Image="other.png",Icon=false}}}
 local c=collect(sync)
 eq(#c.entries,5,"every source row preserved")
 eq(rowBy(c,"Weapons","missing").missingArtFields,3,"fully missing fields")
 eq(rowBy(c,"Weapons","empty").emptyArtFields,2,"empty string fields")
 eq(rowBy(c,"Weapons","invalid").nonStringArtFields,3,"invalid field types")
 local r=assess(sync,"match.png")
 eq(r.status,"SINGLE_IDENTICAL_REFERENCE_WITH_GAPS","status")
 eq(r.catalogEntriesAudited,5,"all rows audited")
 eq(r.catalogueReferencesCompared,2,"only nonempty strings compared")
 eq(r.missingArtEntries,3,"rows without a nonempty string")
 eq(r.missingArtFields,7,"absent art fields")
 eq(r.emptyArtFields,2,"empty art fields")
 eq(r.nonStringArtFields,4,"non-string art fields")
 eq(r.catalogueCoverageComplete,false,"incomplete reference coverage")
 eq(r.imageReferenceAmbiguous,true,"coverage gap prevents uniqueness")
end)
check("non-string competitor art leaves a gap even when every row has string art",function()
 local r=assess({Weapons={match={Image="match.png"},
  other={Image="other.png",Texture=false}}},"match.png")
 eq(r.status,"SINGLE_IDENTICAL_REFERENCE_WITH_GAPS","status")
 eq(r.missingArtEntries,0,"all rows contain a reference")
 eq(r.nonStringArtFields,1,"one unresolved art value")
 eq(r.catalogueCoverageComplete,false,"non-string art prevents complete coverage")
 eq(r.imageReferenceAmbiguous,true,"ambiguity")
end)
check("empty optional art fields preserve complete coverage when every row has a reference",function()
 local r=assess({Weapons={one={Image="match.png",Icon="",Texture=""}}},"match.png")
 eq(r.status,"SINGLE_IDENTICAL_REFERENCE_CLIENT_ONLY","status")
 eq(r.emptyArtFields,2,"empty optional fields")
 eq(r.missingArtEntries,0,"row has a nonempty reference")
 eq(r.nonStringArtFields,0,"no non-string values")
 eq(r.catalogueCoverageComplete,true,"complete coverage")
 eq(r.imageReferenceAmbiguous,false,"one complete row")
end)
check("sprite metadata prevents identity with a single exact matching reference",function()
 local i=input(nil,"https://fixture.invalid/art/exact?token=AB")
 i.usesSpriteSheet=true
 local r=assessInput(i)
 eq(r.status,"SPRITESHEET_REFERENCE_NOT_IDENTITY","status")
 eq(r.matchingCatalogueEntries,1,"matching row still counted")
 eq(r.imageReferenceAmbiguous,true,"sprite ambiguity")
end)
check("sprite metadata prevents identity with multiple exact matching rows",function()
 local i=input({Weapons={one={Image="sprite.png"},two={Image="sprite.png"}}},"sprite.png")
 i.usesSpriteSheet=true
 local r=assessInput(i)
 eq(r.status,"SPRITESHEET_REFERENCE_NOT_IDENTITY","status")
 eq(r.matchingCatalogueEntries,2,"all sprite reference matches counted")
 eq(r.imageReferenceAmbiguous,true,"sprite ambiguity")
end)
check("sprite metadata without any exact reference retains no-match status",function()
 local i=input(nil,"https://fixture.invalid/art/absent")
 i.usesSpriteSheet=true
 local r=assessInput(i)
 eq(r.status,"NO_IDENTICAL_REFERENCE","status")
 eq(r.matchingCatalogueEntries,0,"no matches")
end)

local invalidCases={
 {"nil input",function() return nil end},
 {"scalar input",function() return "PrivateExactSentinel" end},
 {"invalid side",function() local i=input();i.side="Unknown";return i end},
 {"index zero",function() local i=input();i.index=0;return i end},
 {"index five",function() local i=input();i.index=5;return i end},
 {"fractional index",function() local i=input();i.index=1.5;return i end},
 {"infinite index",function() local i=input();i.index=math.huge;return i end},
 {"hidden slot",function() local i=input();i.slotVisible=false;return i end},
 {"hidden image",function() local i=input();i.imageVisible=false;return i end},
 {"unknown sprite metadata",function() local i=input();i.usesSpriteSheet=nil;return i end},
 {"unverified catalogue",function() local i=input();i.catalogueVerified=false;return i end},
 {"missing catalogue",function() local i=input();i.catalogue=nil;return i end},
 {"empty catalogue",function() local i=input();i.catalogue={entries={},sourcesAliasSameTable=false};return i end},
 {"empty icon",function() local i=input();i.icon="";return i end},
 {"non-string icon",function() local i=input();i.icon=123456;return i end},
 {"oversize icon",function() local i=input();i.icon=string.rep("x",4097);return i end},
}
for _,case in ipairs(invalidCases) do
 check("invalid context fails closed: "..case[1],function()
  local r=assessInput(case[2]())
  eq(r.status,"INCOMPLETE","status")
  eq(r.imageReferenceAmbiguous,true,"invalid context ambiguity")
 end)
end
local invalidCatalogues={
 {"unknown source",function(c) c.entries[1].source="PrivateExactSentinelSource" end},
 {"typed key mismatch",function(c) c.entries[1].keyType="number" end},
 {"non-string non-number key",function(c) c.entries[1].key={};c.entries[1].keyType="table" end},
 {"duplicate source row",function(c) c.entries[2]=c.entries[1] end},
 {"sparse source rows",function(c) c.entries[3]=c.entries[1] end},
 {"unknown art field",function(c) c.entries[1].refs[1].field="PrivateExactSentinelField" end},
 {"empty comparable art",function(c) c.entries[1].refs[1].value="" end},
 {"non-string comparable art",function(c) c.entries[1].refs[1].value=false end},
 {"repeated art field",function(c)
   local row=c.entries[1];row.refs[2]={field="Image",value="other.png"};row.missingArtFields=1
  end},
 {"inconsistent field accounting",function(c) c.entries[1].missingArtFields=0 end},
 {"missing alias metadata",function(c) c.sourcesAliasSameTable=nil end},
}
for _,case in ipairs(invalidCatalogues) do
 check("malformed supplied catalogue fails closed: "..case[1],function()
  local i=input();case[2](i.catalogue)
  local r=assessInput(i)
  eq(r.status,"INCOMPLETE","status")
  eq(r.catalogEntriesAudited,0,"invalid catalogue not reported as audited")
  eq(r.catalogueReferencesCompared,0,"invalid catalogue not reported as compared")
  eq(r.imageReferenceAmbiguous,true,"invalid catalogue ambiguity")
 end)
end
check("collector rejects unavailable malformed and oversized source data",function()
 eq(type(M.collectExact),"function","collectExact export")
 local invalid={false,{},
  {Weapons="PrivateExactSentinelSource"},
  {Weapons={row="PrivateExactSentinelRow"}},
  {Weapons={[true]={Image="art.png"}}},
  {Weapons={row={Image=string.rep("x",4097)}}}}
 for _,sync in ipairs(invalid) do
  local catalogue,reason=M.collectExact(sync)
  eq(catalogue,nil,"invalid source catalogue")
  assert(type(reason)=="string" and #reason>0,"invalid collection needs a reason")
  assert(not reason:find("PrivateExactSentinel",1,true),"collection reason leaked source data")
 end
 local catalogue,reason=M.collectExact(nil)
 eq(catalogue,nil,"missing source catalogue")
 assert(type(reason)=="string" and #reason>0,"missing collection needs a reason")
end)
check("collector accepts all 5000 bounded rows and rejects the 5001st row",function()
 local sync={Weapons={}}
 for i=1,5000 do sync.Weapons[i]={Image="bounded.png"} end
 local c=collect(sync)
 eq(#c.entries,5000,"maximum bounded source rows")
 local r=assessInput({side="TheirOffer",index=1,slotVisible=true,imageVisible=true,
  usesSpriteSheet=false,icon="bounded.png",catalogueVerified=true,catalogue=c})
 eq(r.status,"MULTIPLE_IDENTICAL_REFERENCE_ROWS","status")
 eq(r.catalogEntriesAudited,5000,"all bounded rows audited")
 eq(r.catalogueReferencesCompared,5000,"all bounded occurrences compared")
 eq(r.matchingCatalogueEntries,5000,"all bounded source rows match")
 sync.Weapons[5001]={Image="bounded.png"}
 local oversized,reason=M.collectExact(sync)
 eq(oversized,nil,"oversized source is not silently truncated")
 assert(type(reason)=="string" and #reason>0,"oversized source needs a reason")
end)
check("both legal offer sides and all four visible slot indices can be audited",function()
 for _,side in ipairs({"YourOffer","TheirOffer"}) do
  for index=1,4 do
   local i=input();i.side=side;i.index=index
   local r=assessInput(i)
   eq(r.status,"SINGLE_IDENTICAL_REFERENCE_CLIENT_ONLY","status")
  end
 end
end)
check("bounded reference accepts 4096 exact bytes without interpreting them",function()
 local reference=string.rep("x",4096)
 local r=assess({Weapons={one={Image=reference}}},reference)
 eq(r.status,"SINGLE_IDENTICAL_REFERENCE_CLIENT_ONLY","status")
 eq(r.catalogueReferencesCompared,1,"one bounded byte comparison")
end)

check("1040 source rows and all 1146 occurrences are audited for every row image",function()
 local sync={Weapons={},Item={}}
 for i=1,520 do
  -- The 1040 primary images retain the legacy 137 asset / 903 HTTP split.
  local w={Image=i<=137 and "rbxassetid://"..(100000+i) or
   "https://fixture.invalid/large/W"..i}
  local t={Image="https://fixture.invalid/large/I"..i}
  if i%10==0 then w.Icon=w.Image;t.Icon=t.Image end
  sync.Weapons["W"..i]=w
  sync.Item["I"..i]=t
 end
 sync.Weapons.W1.Texture="https://fixture.invalid/large/shared-unmatched"
 sync.Item.I1.Texture="https://fixture.invalid/large/shared-unmatched"
 local c=collect(sync)
 eq(#c.entries,1040,"all rows collected")
 for _,source in ipairs({"Weapons","Item"}) do
  for i=1,520 do
   local key=(source=="Weapons" and "W" or "I")..i
   local value={side="TheirOffer",index=4,slotVisible=true,imageVisible=true,
    usesSpriteSheet=false,icon=sync[source][key].Image,catalogueVerified=true,
    catalogue=c}
   local r=assessInput(value)
   eq(r.status,"SINGLE_IDENTICAL_REFERENCE_CLIENT_ONLY","large fixture status")
   eq(r.catalogEntriesAudited,1040,"all rows audited")
   eq(r.catalogueReferencesCompared,1146,"all reference occurrences compared")
   eq(r.matchingCatalogueEntries,1,"one matching source row")
   eq(r.matchingReferenceOccurrences,i%10==0 and 2 or 1,"matching field occurrences")
   eq(r.matchingSourceCount,1,"one matching source")
   eq(r.duplicateReferenceGroups,1,"unmatched cross-source duplicate group")
   eq(r.rowsSharingReferences,2,"unmatched reference shared by two rows")
   eq(r.stringifiedKeyOverlapGroups,0,"disjoint source key strings")
   eq(r.conflictingStringifiedKeyGroups,0,"no source key conflict")
   eq(r.missingArtEntries,0,"every row has reference art")
   eq(r.missingArtFields,1974,"three fields per row minus 1146 present fields")
   eq(r.emptyArtFields,0,"no empty fields")
   eq(r.nonStringArtFields,0,"no non-string fields")
   eq(r.sourcesAliasSameTable,false,"distinct source tables")
   eq(r.catalogueCoverageComplete,true,"complete catalogue coverage")
   eq(r.imageReferenceAmbiguous,false,"only selected row matches")
  end
 end
end)

check("sparse catalogue with a hidden matching competitor cannot claim uniqueness",function()
 local i=input({Weapons={a={Image="same.png"},b={Image="other.png"},
  c={Image="same.png"},d={Image="last.png"}}},"same.png")
 local cat=i.catalogue
 local sparse={}
 sparse[1]=rowBy(cat,"Weapons","a")
 sparse[2]=rowBy(cat,"Weapons","b")
 sparse[4]=rowBy(cat,"Weapons","c")
 sparse[6]=rowBy(cat,"Weapons","d")
 cat.entries=sparse
 local r=assessInput(i)
 eq(r.status,"INCOMPLETE","sparse catalogue rejected")
 eq(r.catalogEntriesAudited,0,"no misleading partial audit")
 eq(r.imageReferenceAmbiguous,true,"hidden competitor cannot be excluded")
end)

print("Stage36 exact reference: "..passed.." passed, "..#failed..
 " failed; "..reportsChecked.." sanitized reports checked")
if #failed>0 then
 error("Stage36 exact reference failures ("..#failed.."):\n"..
  table.concat(failed,"\n"),0)
end
