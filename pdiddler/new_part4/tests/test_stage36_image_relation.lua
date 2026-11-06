-- Pure Stage36 relationship diagnostic: execute with a real Lua interpreter.
local dir=arg[1] or "pdiddler/new_part4"
package.path=dir.."/?.lua;"..package.path
local loaded,M=pcall(require,"p4_stage36_image_relation")
local passed,failed=0,0
local function check(name,fn)
 local ok,why=pcall(fn)
 if ok then passed=passed+1 else failed=failed+1;io.stderr:write("FAILED ",name,": ",tostring(why),"\n") end
end
local function input(sync,icon,name)
 return {sync=sync or {Weapons={a={Image="rbxassetid://7"}}},
  icon=icon or "rbxassetid://7",name=name,contentKind="URI",sprite=false,contextVerified=true}
end
local strings={
 ["gingerscope-stage36-image-relation-v1"]=true,INCOMPLETE=true,
 RELATIONSHIP_OBSERVED_INCONCLUSIVE=true,UNKNOWN=true,
 URI=true,OBJECT=true,NONE=true,UNREADABLE=true,
 INPUT_INVALID=true,CONTEXT_UNVERIFIED=true,ICON_INVALID=true,NAME_INVALID=true,
 CONTENT_KIND_INVALID=true,SPRITE_UNVERIFIED=true,SYNC_UNAVAILABLE=true,
 SOURCE_INVALID=true,ROW_INVALID=true,CATALOGUE_EMPTY=true,
 SOURCE_ROW_LIMIT=true,METADATA_FIELD_LIMIT=true,STRING_LIMIT=true,
 CLIENT_RELATION_ONLY=true,
}
local keys={schema=true,status=true,reason=true,contentKind=true,sprite=true,
 sourceLabelledRows=true,physicalRows=true,sourceTableCount=true,sourceAliases=true,
 uniqueArtReferences=true,sharedArtReferenceGroups=true,artCollisionRows=true,
 missingArtRows=true,otherStringMetadataFields=true,exactIconArtRows=true,
 exactIconOtherFieldRows=true,exactNameRows=true,nameCandidateRarityGroups=true,
 nameCandidatesChroma=true,missingNameRows=true,nonStringArtFields=true,
 candidateArtTokenRows=true,candidateWeaponKeyRows=true,ambiguousQueryReferences=true,
 iconStructure=true,catalogueStructures=true,slotIdentityLinked=true,
 semanticEquivalenceEstablished=true,imageGenerationMechanismConfirmed=true,
 rawItemIdConfirmed=true,exactWeaponIdentityConfirmed=true,readOnly=true,tradeOutcome=true,
 serverAttestation=true,serverCompletionProven=true,causalAttributionProven=true,
 authorizesTrade=true,authorizesAccept=true,mayRecordCompletedTrade=true,mayReportProfit=true,
 references=true,scheme=true,hostFamily=true,pathShape=true,queryKeys=true,
 HTTP_HTTPS=true,RBXASSETID=true,RBXTHUMB=true,RBXASSET=true,RBXGAMEASSET=true,OTHER=true,
 ROBLOX_WEB=true,ROBLOX_SUBDOMAIN=true,RBXCDN=true,NONE=true,
 ROOT=true,SINGLE_SEGMENT=true,MULTI_SEGMENT=true,FILE_LIKE=true,
 id=true,assetId=true,type=true,w=true,h=true,width=true,height=true,format=true,other=true}
local function safe(r)
 assert(r.schema=="gingerscope-stage36-image-relation-v1")
 assert(r.readOnly==true and r.tradeOutcome=="UNKNOWN")
 for _,k in ipairs({"slotIdentityLinked","semanticEquivalenceEstablished",
  "imageGenerationMechanismConfirmed","rawItemIdConfirmed","exactWeaponIdentityConfirmed",
  "serverAttestation","serverCompletionProven","causalAttributionProven",
  "authorizesTrade","authorizesAccept","mayRecordCompletedTrade","mayReportProfit"}) do
  assert(r[k]==false,k)
 end
 local function walk(t)
  for k,v in pairs(t) do
   assert(type(k)=="string" and keys[k],"unapproved outward key")
   local kind=type(v)
   assert(kind=="string" or kind=="boolean" or kind=="number" or kind=="table",kind)
   if kind=="table" then walk(v)
   elseif kind=="string" then assert(strings[v],"unapproved outward string")
   elseif kind=="number" then assert(v>=0 and v%1==0) end
  end
 end
 walk(r)
end
local function inspect(i)
 assert(loaded and type(M)=="table" and type(M.inspect)=="function","pure image relation module unavailable")
 local r=M.inspect(i);safe(r);return r
end
check("original source pointer alias has 2080 labelled rows and 1040 physical rows",function()
 local source={}
 for i=1,1040 do source["key"..i]={Image="rbxassetid://"..i} end
 local r=inspect(input({Weapons=source,Item=source},"rbxassetid://999999"))
 assert(r.status=="RELATIONSHIP_OBSERVED_INCONCLUSIVE")
 assert(r.sourceLabelledRows==2080 and r.physicalRows==1040)
 assert(r.sourceAliases==1 and r.sourceTableCount==1)
 assert(r.uniqueArtReferences==1040 and r.sharedArtReferenceGroups==0 and r.artCollisionRows==0)
 assert(r.exactIconArtRows==0 and r.catalogueStructures.references==1040)
 assert(source.key1.Image=="rbxassetid://1")
end)
check("different source tables and typed row keys remain separate",function()
 local row={Image="rbxassetid://7"}
 local r=inspect(input({Weapons={[7]=row,["7"]=row},Item={["7"]=row}}))
 assert(r.sourceLabelledRows==3 and r.physicalRows==3 and r.sourceAliases==0 and r.sourceTableCount==2)
 assert(r.uniqueArtReferences==1 and r.sharedArtReferenceGroups==1 and r.artCollisionRows==3)
 assert(r.exactIconArtRows==3)
end)
check("shared artwork collision counts distinct row union only",function()
 local r=inspect(input({Weapons={
  a={Image="shared-one",Icon="shared-one",Texture="shared-two"},
  b={Image="shared-one",Icon="shared-two"},c={Texture="shared-two"},
  d={Image="isolated"},e={Image="",Icon=false,Texture=7}}},"shared-one"))
 assert(r.physicalRows==5 and r.uniqueArtReferences==3 and r.sharedArtReferenceGroups==2)
 assert(r.artCollisionRows==3 and r.missingArtRows==1 and r.nonStringArtFields==2)
 assert(r.exactIconArtRows==2 and r.catalogueStructures.references==7)
end)
check("HTTP shapes provide opaque same named token candidates only",function()
 local r=inspect(input({Weapons={
  ["007"]={Image="https://images.roblox.com/one/two.png?id=007&w=150"},
  [7]={Image="http://cdn.rbxcdn.com/different/path?id=007&format=png"},
  cross={Image="https://example.org/asset?assetId=007"},
  bridge={Image="rbxassetid://007"},zero={Image="rbxassetid://7"}}},
  "https://www.roblox.com/anything?id=007&width=150"))
 assert(r.exactIconArtRows==0 and r.candidateArtTokenRows==3 and r.candidateWeaponKeyRows==1)
 assert(r.iconStructure.scheme.HTTP_HTTPS==1 and r.iconStructure.hostFamily.ROBLOX_WEB==1)
 assert(r.iconStructure.pathShape.SINGLE_SEGMENT==1 and r.iconStructure.queryKeys.id==1)
 assert(r.catalogueStructures.hostFamily.ROBLOX_SUBDOMAIN==1)
 assert(r.catalogueStructures.hostFamily.RBXCDN==1 and r.catalogueStructures.hostFamily.OTHER==1)
 assert(r.catalogueStructures.pathShape.FILE_LIKE==1)
 assert(r.ambiguousQueryReferences==0)
end)
check("strict anchored rbxassetid payload permits candidate bridge without normalization",function()
 local r=inspect(input({Weapons={
  a={Image="https://elsewhere.invalid/a?assetId=001"},b={Image="rbxassetid://001"},
  c={Image="rbxassetid://1"},d={Image=" rbxassetid://001"},
  e={Image="rbxassetid://001?x=1"}}},"rbxassetid://001"))
 assert(r.candidateArtTokenRows==2 and r.exactIconArtRows==1)
 assert(r.candidateWeaponKeyRows==0)
end)
check("unknown or duplicate known query keys disable only that reference",function()
 local r=inspect(input({Weapons={
  a={Image="https://x.invalid/a?id=secret&id=secret"},
  b={Image="https://x.invalid/a?id=secret&private=never-export"},
  c={Image="https://x.invalid/a?id=secret&w=1&w=1"},
  d={Image="https://x.invalid/a?id=secret"},
  e={Image="https://x.invalid/a?id="}}},"https://www.roblox.com/?id=secret"))
 assert(r.candidateArtTokenRows==1 and r.ambiguousQueryReferences==4)
 assert(r.catalogueStructures.queryKeys.id==5 and r.catalogueStructures.queryKeys.other==1)
 assert(r.catalogueStructures.queryKeys.w==1)
 local i=input({Weapons={["secret"]={Image="rbxassetid://1"}}},"https://www.roblox.com/?id=secret&nope=value")
 local q=inspect(i);assert(q.candidateArtTokenRows==0 and q.candidateWeaponKeyRows==0 and q.ambiguousQueryReferences==1)
end)
check("byte equality remains distinct from token candidates and escaping never decodes",function()
 local r=inspect(input({Weapons={
  a={Image="https://x.invalid/?id=abc%31"},b={Image="https://x.invalid/?id=abc1"},
  c={Image="https://x.invalid/?assetId=abc%31"},
  d={Image="https://x.invalid/?ID=abc%31"}}},"https://www.roblox.com/?id=abc%31"))
 assert(r.candidateArtTokenRows==1 and r.exactIconArtRows==0 and r.ambiguousQueryReferences==1)
end)
check("all direct other string metadata participates without exporting field names",function()
 local icon="https://secret.invalid/hidden?opaque=private"
 local r=inspect(input({Weapons={a={Image="x",["secret-field"]=icon,ItemName="Named",Name="Named",Rarity="Ancient"},
  b={Icon=icon,Other=icon},c={Description="no"}}},icon,"Named"))
 assert(r.otherStringMetadataFields==6 and r.exactIconOtherFieldRows==2 and r.exactIconArtRows==1)
 assert(r.exactNameRows==1 and r.nameCandidateRarityGroups==1 and r.missingNameRows==2)
end)
check("all rarities and chroma duplicate names stay ambiguous",function()
 local rare={}
 local r=inspect(input({Weapons={
  a={ItemName="Same",Name="Same",Rarity="Ancient",Chroma=true},
  b={Name="Same",Rarity="Common"},c={ItemName="Same",Rarity="Ancient",Chroma=true},
  d={Name="Same",Rarity=1},e={Name="Same",Rarity="1"},f={Name="Same",Rarity=rare},
  g={Name="Same",Rarity=rare},h={Name="same"},i={Name=""},j={Name=false},k={}}},"unmatched","Same"))
 assert(r.exactNameRows==7 and r.nameCandidateRarityGroups==5 and r.nameCandidatesChroma==2)
 assert(r.missingNameRows==3 and r.missingArtRows==11)
end)
check("content kinds and sprite observations cannot grant identity",function()
 for _,kind in ipairs({"URI","OBJECT","NONE","UNREADABLE"}) do
  for _,sprite in ipairs({true,false}) do
   local i=input();i.contentKind=kind;i.sprite=sprite
   local r=inspect(i);assert(r.contentKind==kind and r.sprite==sprite)
   assert(r.status=="RELATIONSHIP_OBSERVED_INCONCLUSIVE" and r.exactIconArtRows==1)
  end
 end
end)
check("fixed classifier buckets cover schemes hosts and generic paths",function()
 local source={
  a={Image="https://roblox.com",Icon="https://www.roblox.com/",Texture="https://create.roblox.com/one/two"},
  b={Image="https://rbxcdn.com/a.png",Icon="rbxthumb://type=Asset&id=7&w=150&h=150",Texture="rbxasset://textures/x.png"},
  c={Image="rbxgameasset://Images/X",Icon="rbxassetid://7",Texture="unknown://never-export"},
  d={Image="https://roblox.com.evil.invalid/a",Icon="https://evilroblox.com/a",Texture="https://x.invalid/a?type=Asset&h=1&height=2&format=png"},
 }
 local r=inspect(input({Weapons=source}))
 assert(r.catalogueStructures.scheme.HTTP_HTTPS==7 and r.catalogueStructures.scheme.RBXTHUMB==1)
 assert(r.catalogueStructures.scheme.RBXASSET==1 and r.catalogueStructures.scheme.RBXGAMEASSET==1)
 assert(r.catalogueStructures.scheme.RBXASSETID==1 and r.catalogueStructures.scheme.OTHER==1)
 assert(r.catalogueStructures.hostFamily.ROBLOX_WEB==2 and r.catalogueStructures.hostFamily.ROBLOX_SUBDOMAIN==1)
 assert(r.catalogueStructures.hostFamily.RBXCDN==1 and r.catalogueStructures.hostFamily.OTHER==3)
 assert(r.catalogueStructures.hostFamily.NONE==5 and r.catalogueStructures.pathShape.ROOT==2)
 assert(r.catalogueStructures.pathShape.MULTI_SEGMENT==1 and r.catalogueStructures.pathShape.FILE_LIKE==1)
 assert(r.catalogueStructures.queryKeys.type==1 and r.catalogueStructures.queryKeys.h==1)
 assert(r.catalogueStructures.queryKeys.height==1 and r.catalogueStructures.queryKeys.format==1)
end)
check("missing malformed or unverified input is incomplete",function()
 local cases={false,{},input()}
 cases[3].contextVerified=false
 for _,i in ipairs(cases) do assert(inspect(i).status=="INCOMPLETE") end
 for _,alter in ipairs({
  function(i)i.icon="" end,function(i)i.icon={} end,function(i)i.icon=string.rep("x",4097) end,
  function(i)i.name=17 end,function(i)i.name="" end,function(i)i.name=string.rep("x",4097) end,
  function(i)i.contentKind="OTHER" end,function(i)i.sprite=nil end,
  function(i)i.sync=nil end,function(i)i.sync={Weapons=false} end,
  function(i)i.sync={Weapons={}} end,function(i)i.sync={Weapons={a=false}} end,
  function(i)i.sync={Weapons={a={Image=string.rep("x",4097)}}} end,
 }) do local i=input();alter(i);assert(inspect(i).status=="INCOMPLETE") end
end)
check("row and metadata bounds reject without partial success",function()
 local source={};for i=1,2501 do source[i]={Image="x"} end
 local r=inspect(input({Weapons=source,Item=source}));assert(r.status=="INCOMPLETE" and r.reason=="SOURCE_ROW_LIMIT")
 local row={Image="x"};for i=1,64 do row["field"..i]="x" end
 r=inspect(input({Weapons={a=row}}));assert(r.status=="INCOMPLETE" and r.reason=="METADATA_FIELD_LIMIT")
 row.field64=nil;r=inspect(input({Weapons={a=row}}));assert(r.status=="RELATIONSHIP_OBSERVED_INCONCLUSIVE")
end)
check("direct table reads do not invoke catalogue metamethods",function()
 local function trap()error("metamethod invoked")end
 local meta={__pairs=trap,__index=trap,__len=trap,__tostring=trap}
 local row=setmetatable({Image="rbxassetid://7"},meta)
 local src=setmetatable({a=row},meta)
 local sync=setmetatable({Weapons=src,Item=src},meta)
 local r=inspect(input(sync));assert(r.physicalRows==1 and r.sourceLabelledRows==2)
end)
check("distinct source pointers cannot alias through an equality metamethod",function()
 local meta={__eq=function()error("source equality metamethod invoked")end}
 local first=setmetatable({same={Image="one"}},meta)
 local second=setmetatable({same={Image="two"}},meta)
 local r=inspect(input({Weapons=first,Item=second},"unmatched"))
 assert(r.sourceAliases==0 and r.sourceTableCount==2 and r.physicalRows==2)
end)
check("explicitly truncated inputs and overlong arbitrary metadata fail closed",function()
 local i=input();i.truncated=true;assert(inspect(i).status=="INCOMPLETE")
 i=input();i.catalogueTruncated=true;assert(inspect(i).status=="INCOMPLETE")
 i=input({Weapons={a={Other=string.rep("x",4097)}}})
 assert(inspect(i).status=="INCOMPLETE")
 i=input({Weapons={[string.rep("x",4097)]={Image="x"}}})
 assert(inspect(i).status=="INCOMPLETE")
end)
io.write("Stage36 image relation: ",passed," passed, ",failed," failed\n")
if failed>0 then os.exit(1) end
