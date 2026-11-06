-- Stage36: PURE, bounded, read-only relations in the supplied live Sync tables.
-- No game APIs, requests, requires, hooks, URL rewriting or identity resolution.
-- Exact reference equality and opaque token coincidences are client observations;
-- neither explains the GUI assignment/rendering mechanism nor proves item IDs.
local M={}
local MAX_STRING,MAX_ROWS,MAX_FIELDS=4096,5000,64
local artFields={Image=true,Icon=true,Texture=true}
local knownQuery={id=true,assetId=true,type=true,w=true,h=true,
 width=true,height=true,format=true}
local function buckets()
 return {references=0,
  scheme={HTTP_HTTPS=0,RBXASSETID=0,RBXTHUMB=0,RBXASSET=0,RBXGAMEASSET=0,OTHER=0},
  hostFamily={ROBLOX_WEB=0,ROBLOX_SUBDOMAIN=0,RBXCDN=0,OTHER=0,NONE=0},
  pathShape={ROOT=0,SINGLE_SEGMENT=0,MULTI_SEGMENT=0,FILE_LIKE=0,NONE=0},
  queryKeys={id=0,assetId=0,type=0,w=0,h=0,width=0,height=0,format=0,other=0}}
end
local function report(reason)
 return {schema="gingerscope-stage36-image-relation-v1",status="INCOMPLETE",
  reason=reason or "INPUT_INVALID",contentKind="UNREADABLE",sprite=false,
  sourceLabelledRows=0,physicalRows=0,sourceTableCount=0,sourceAliases=0,
  uniqueArtReferences=0,sharedArtReferenceGroups=0,artCollisionRows=0,
  missingArtRows=0,otherStringMetadataFields=0,exactIconArtRows=0,
  exactIconOtherFieldRows=0,exactNameRows=0,nameCandidateRarityGroups=0,
  nameCandidatesChroma=0,missingNameRows=0,nonStringArtFields=0,
  candidateArtTokenRows=0,candidateWeaponKeyRows=0,ambiguousQueryReferences=0,
  iconStructure=buckets(),catalogueStructures=buckets(),
  slotIdentityLinked=false,semanticEquivalenceEstablished=false,
  imageGenerationMechanismConfirmed=false,rawItemIdConfirmed=false,
  exactWeaponIdentityConfirmed=false,readOnly=true,tradeOutcome="UNKNOWN",
  serverAttestation=false,serverCompletionProven=false,causalAttributionProven=false,
  authorizesTrade=false,authorizesAccept=false,mayRecordCompletedTrade=false,
  mayReportProfit=false}
end
local function boundedString(value,nonempty)
 return type(value)=="string" and #value<=MAX_STRING and (not nonempty or #value>0)
end
local function rowKey(key)
 if type(key)=="string" then return boundedString(key,true) end
 return type(key)=="number" and key==key and key~=math.huge and key~=-math.huge
end
local function hostFamily(authority)
 -- These buckets describe literal host families only. They do not grant any
 -- host/path special image identity meaning. Unusual authorities stay OTHER.
 local host=authority:match("^([%w%.%-]+):%d+$") or authority
 if not host:match("^[%w%.%-]+$") then return "OTHER" end
 if host=="roblox.com" or host=="www.roblox.com" then return "ROBLOX_WEB" end
 if host:match("^[%w%.%-]+%.roblox%.com$") then return "ROBLOX_SUBDOMAIN" end
 if host=="rbxcdn.com" or host:match("^[%w%.%-]+%.rbxcdn%.com$") then return "RBXCDN" end
 return "OTHER"
end
local function pathShape(path)
 if path=="" or path=="/" then return "ROOT" end
 local last=path:match("([^/]+)$")
 if last and last:match("^.+%..+$") then return "FILE_LIKE" end
 local segments=0
 for _ in path:gmatch("[^/]+") do segments=segments+1 end
 if segments==0 then return "ROOT" end
 return segments==1 and "SINGLE_SEGMENT" or "MULTI_SEGMENT"
end
local function parseQuery(query)
 local presence={}
 local tokens,ambiguous,unknown={},false,0
 if query==nil then return presence,tokens,ambiguous,unknown end
 if query=="" then return presence,tokens,true,unknown end
 local start=1
 while true do
  local stop=query:find("&",start,true)
  local pair=query:sub(start,stop and stop-1 or #query)
  local equals=pair:find("=",1,true)
  local key=equals and pair:sub(1,equals-1) or pair
  local value=equals and pair:sub(equals+1) or nil
  if knownQuery[key] then
   if presence[key] then ambiguous=true end
   presence[key]=true
   if not value or value=="" then ambiguous=true end
   if key=="id" or key=="assetId" then tokens[key]=value end
  else
   unknown=unknown+1;ambiguous=true
  end
  if not stop then break end
  start=stop+1
 end
 if ambiguous then tokens={} end
 return presence,tokens,ambiguous,unknown
end
local function classify(reference,counts)
 counts.references=counts.references+1
 local scheme,host,path="OTHER","NONE","NONE"
 local tokens,httpTokens,ambiguous={},{},false
 local prefix,rest=reference:match("^([%a][%w+%.%-]*)://(.*)$")
 if prefix=="http" or prefix=="https" then
  scheme="HTTP_HTTPS"
  -- Generic structural splitting only: no decoding, trimming, case folding,
  -- canonicalization, path assumptions or URL equivalence assertions.
  local fragment=rest:find("#",1,true)
  local body=fragment and rest:sub(1,fragment-1) or rest
  local queryAt=body:find("?",1,true)
  local address=queryAt and body:sub(1,queryAt-1) or body
  local query=queryAt and body:sub(queryAt+1) or nil
  local slash=address:find("/",1,true)
  local authority=slash and address:sub(1,slash-1) or address
  local rawPath=slash and address:sub(slash) or ""
  host=hostFamily(authority);path=pathShape(rawPath)
  local presence,other
  presence,httpTokens,ambiguous,other=parseQuery(query)
  for key in next,presence do counts.queryKeys[key]=counts.queryKeys[key]+1 end
  counts.queryKeys.other=counts.queryKeys.other+other
  -- Empty/whitespace authorities and controls are not usable query references.
  if authority=="" or reference:find("[%s%c]") then ambiguous=true;httpTokens={} end
  tokens=httpTokens
 elseif prefix=="rbxassetid" then
  scheme="RBXASSETID"
  local payload=reference:match("^rbxassetid://(%d+)$")
  if payload then tokens={id=payload,assetId=payload} end
 elseif prefix=="rbxthumb" then scheme="RBXTHUMB"
 elseif prefix=="rbxasset" then scheme="RBXASSET"
 elseif prefix=="rbxgameasset" then scheme="RBXGAMEASSET" end
 counts.scheme[scheme]=counts.scheme[scheme]+1
 counts.hostFamily[host]=counts.hostFamily[host]+1
 counts.pathShape[path]=counts.pathShape[path]+1
 return tokens,httpTokens,ambiguous
end
local function tokenRelation(a,b)
 return (a.id~=nil and b.id~=nil and a.id==b.id) or
  (a.assetId~=nil and b.assetId~=nil and a.assetId==b.assetId)
end
function M.inspect(input)
 if type(input)~="table" then return report("INPUT_INVALID") end
 if rawget(input,"contextVerified")~=true then return report("CONTEXT_UNVERIFIED") end
 if rawget(input,"truncated")==true or rawget(input,"catalogueTruncated")==true then
  return report("INPUT_INVALID")
 end
 local icon,name=rawget(input,"icon"),rawget(input,"name")
 if not boundedString(icon,true) then return report("ICON_INVALID") end
 if name~=nil and not boundedString(name,true) then return report("NAME_INVALID") end
 local contentKind,sprite=rawget(input,"contentKind"),rawget(input,"sprite")
 if contentKind~="URI" and contentKind~="OBJECT" and contentKind~="NONE" and contentKind~="UNREADABLE" then
  return report("CONTENT_KIND_INVALID")
 end
 if type(sprite)~="boolean" then return report("SPRITE_UNVERIFIED") end
 local sync=rawget(input,"sync")
 if type(sync)~="table" then return report("SYNC_UNAVAILABLE") end
 local weapons,item=rawget(sync,"Weapons"),rawget(sync,"Item")
 if (weapons~=nil and type(weapons)~="table") or (item~=nil and type(item)~="table") then
  return report("SOURCE_INVALID")
 end
 local r=report()
 r.contentKind=contentKind;r.sprite=sprite
 local sources,sourceCounts={},{}
 if weapons then sources[#sources+1]=weapons end
 if item then
  if weapons and rawequal(weapons,item) then r.sourceAliases=1
  else sources[#sources+1]=item end
 end
 r.sourceTableCount=#sources
 for _,source in ipairs(sources) do
  local count=0
  for key,row in next,source do
   count=count+1
   if count>MAX_ROWS then return report("SOURCE_ROW_LIMIT") end
   if not rowKey(key) or type(row)~="table" then return report("ROW_INVALID") end
  end
  sourceCounts[source]=count
 end
 -- Keep per-source counts internal; aliases remain two labelled traversals.
 r.sourceLabelledRows=(weapons and sourceCounts[weapons] or 0)+(item and sourceCounts[item] or 0)
 if r.sourceLabelledRows>MAX_ROWS then return report("SOURCE_ROW_LIMIT") end
 if r.sourceLabelledRows==0 then return report("CATALOGUE_EMPTY") end
 local guiTokens,guiHttpTokens,ambiguous=classify(icon,r.iconStructure)
 if ambiguous then r.ambiguousQueryReferences=r.ambiguousQueryReferences+1 end
 local artGroups,rarities,collisionRows={},{},{}
 for _,source in ipairs(sources) do
  for key,row in next,source do
   r.physicalRows=r.physicalRows+1
   local rowIndex=r.physicalRows
   local fields,hasArt,exactArt,exactOther,candidateArt=0,false,false,false,false
   local perRowArt={}
   for field,value in next,row do
    fields=fields+1
    if fields>MAX_FIELDS then return report("METADATA_FIELD_LIMIT") end
    if (type(field)=="string" and #field>MAX_STRING) or
     (type(value)=="string" and #value>MAX_STRING) then return report("STRING_LIMIT") end
    if artFields[field] then
     if type(value)~="string" then r.nonStringArtFields=r.nonStringArtFields+1
     elseif value~="" then
      hasArt=true
      if value==icon then exactArt=true end
      local tokens,_,artAmbiguous=classify(value,r.catalogueStructures)
      if artAmbiguous then r.ambiguousQueryReferences=r.ambiguousQueryReferences+1 end
      if tokenRelation(guiTokens,tokens) then candidateArt=true end
      if not perRowArt[value] then
       perRowArt[value]=true
       local group=artGroups[value]
       if not group then
        group={count=0,rows={}};artGroups[value]=group
        r.uniqueArtReferences=r.uniqueArtReferences+1
       end
       group.count=group.count+1;group.rows[rowIndex]=true
      end
     end
    elseif type(value)=="string" then
     r.otherStringMetadataFields=r.otherStringMetadataFields+1
     if value==icon then exactOther=true end
    end
   end
   if not hasArt then r.missingArtRows=r.missingArtRows+1 end
   if exactArt then r.exactIconArtRows=r.exactIconArtRows+1 end
   if exactOther then r.exactIconOtherFieldRows=r.exactIconOtherFieldRows+1 end
   if candidateArt then r.candidateArtTokenRows=r.candidateArtTokenRows+1 end
   if type(key)=="string" and (key==guiHttpTokens.id or key==guiHttpTokens.assetId) then
    r.candidateWeaponKeyRows=r.candidateWeaponKeyRows+1
   end
   local itemName,plainName=rawget(row,"ItemName"),rawget(row,"Name")
   if not boundedString(itemName,true) and not boundedString(plainName,true) then
    r.missingNameRows=r.missingNameRows+1
   end
   if name~=nil and (name==itemName or name==plainName) then
    r.exactNameRows=r.exactNameRows+1
    if rawget(row,"Chroma")==true then r.nameCandidatesChroma=r.nameCandidatesChroma+1 end
    local rarity=rawget(row,"Rarity")
    if rarity~=nil then
     -- Actual raw values retain their Lua types/pointer identity internally.
     -- NaN has no equal raw value and cannot be a Lua table key.
     if rarity~=rarity then r.nameCandidateRarityGroups=r.nameCandidateRarityGroups+1
     elseif not rarities[rarity] then
      rarities[rarity]=true;r.nameCandidateRarityGroups=r.nameCandidateRarityGroups+1
     end
    end
   end
  end
 end
 for _,group in next,artGroups do
  if group.count>1 then
   r.sharedArtReferenceGroups=r.sharedArtReferenceGroups+1
   for rowIndex in next,group.rows do collisionRows[rowIndex]=true end
  end
 end
 for _ in next,collisionRows do r.artCollisionRows=r.artCollisionRows+1 end
 r.status="RELATIONSHIP_OBSERVED_INCONCLUSIVE";r.reason="CLIENT_RELATION_ONLY"
 return r
end
return M
