-- Offline behavioral integration of the actual Stage36 native launcher.
-- All GUI labels, catalogue keys, names and HTTP references are synthetic.
local dir=arg[1] or "pdiddler/new_part4"
local function readFile(path)
 local file=assert(io.open(path,"rb"))
 local source=file:read("*a");file:close()
 return source
end
local nativeSource=readFile(dir.."/STAGE36_READONLY_ICON_CATALOG_DELTA_PROBE.lua")
local coreSource=readFile(dir.."/p4_stage36_icon_catalog_audit.lua")
local KEY="PDIDDLER_STAGE36_ICON_CATALOG_AUDIT"
local SHARED="https://fixture.invalid/Opaque/Shared.png?Token=NativeCase"
local OTHER="https://fixture.invalid/Opaque/Shared.png?Token=nativecase"
local REPEATED_KEY="stage36-private-repeated-weapon-key"
local COMMON_KEY="stage36-private-common-weapon-key"
local PRIVATE_NAME="Stage36PrivateSyntheticWeaponName"
local passed,failures=0,{}
local function eq(actual,expected,label)
 assert(actual==expected,(label or "value").." expected "..
  tostring(expected)..", got "..tostring(actual))
end
local function test(name,fn)
 local okay,why=pcall(fn)
 if okay then
  passed=passed+1
  print("PASS "..name)
 else
  failures[#failures+1]=name..": "..tostring(why)
  print("FAIL "..failures[#failures])
 end
end

local N={};N.__index=N
function N.new(kind,name,props)
 local node=setmetatable({ClassName=kind,Name=name,Children={},
  Parent=nil,Visible=true,Enabled=true},N)
 for key,value in pairs(props or {}) do node[key]=value end
 return node
end
function N:Add(child)
 child.Parent=self;self.Children[#self.Children+1]=child;return child
end
function N:FindFirstChild(name)
 for _,child in ipairs(self.Children) do
  if child.Name==name then return child end
 end
end
function N:FindFirstChildOfClass(kind)
 for _,child in ipairs(self.Children) do
  if child:IsA(kind) then return child end
 end
end
function N:IsA(kind)
 if self.ClassName==kind then return true end
 return kind=="GuiObject" and
  (self.ClassName=="Frame" or self.ClassName=="TextLabel" or
   self.ClassName=="TextButton" or self.ClassName=="ImageLabel" or
   self.ClassName=="ImageButton")
end
local function node(kind,name,props)return N.new(kind,name,props)end
local function art(reference,rarity)
 return {Image=reference,Icon=reference,Texture=reference,
  Rarity=rarity,Name=PRIVATE_NAME}
end

local forbiddenFields={}
for _,field in ipairs({"rawIcon","rawAssetId","icon","imageURL",
 "itemId","weaponId","itemName","assetId","playerId","jobId",
 "partnerId","catalogue","entries","matchingKeys","matchingNames",
 "session","fingerprint","rawImage","refs","provenance"}) do
 forbiddenFields[field]=true
end
local function assertAnonymized(value,seen)
 local kind=type(value)
 if kind=="string" then
  for _,secret in ipairs({SHARED,OTHER,REPEATED_KEY,COMMON_KEY,
   PRIVATE_NAME,"fixture.invalid","NativeCase","nativecase"}) do
   assert(not value:find(secret,1,true),"raw synthetic metadata escaped")
  end
  assert(not value:find("://",1,true),"raw URI escaped")
 elseif kind=="table" then
  seen=seen or {}
  assert(not seen[value],"report must not contain cycles")
  seen[value]=true
  for key,child in pairs(value) do
   assert(not forbiddenFields[key],"report exported a raw-metadata field")
   assertAnonymized(key,seen);assertAnonymized(child,seen)
  end
  seen[value]=nil
 else
  assert(kind=="number" or kind=="boolean" or kind=="nil",
   "report contains a non-JSON value")
 end
end

local function fixture(side,index)
 local calls={http={},services={},forbidden={},requireSync=0,waits=0,
  spawned=0,collectExact=0,assessExact=0,legacyAssess=0,
  json=0,clipboard={},printed={},warnings={}}
 local function forbidden(name)
  return function()
   calls.forbidden[#calls.forbidden+1]=name
   error("unexpected action or network access",0)
  end
 end
 local players=node("Players","Players")
 local me=players:Add(node("Player","Local",{UserId=880011}))
 players.LocalPlayer=me
 local pg=me:Add(node("PlayerGui","PlayerGui"))
 local screen=pg:Add(node("ScreenGui","TradeGUI"))
 local root=screen:Add(node("Frame","Container")):Add(node("Frame","Trade"))
 local offers={}
 for _,name in ipairs({"TheirOffer","YourOffer"}) do
  offers[name]=root:Add(node("Frame",name)):Add(node("Frame","Container"))
 end
 local slot=offers[side]:Add(node("Frame","NewItem"..index))
 slot:Add(node("Frame","ItemName")):Add(node("TextLabel","Label",{
  Text=PRIVATE_NAME}))
 -- Only Container.Icon.Image is the native icon; other art is a distractor.
 slot:Add(node("ImageLabel","Icon",{Image=OTHER,ImageRectSize={X=0,Y=0}}))
 local icon=slot:Add(node("Frame","Container")):Add(node("ImageLabel","Icon",{
  Image=SHARED,ImageRectSize={X=0,Y=0}}))
 local rs=node("ReplicatedStorage","ReplicatedStorage")
 local syncModule=rs:Add(node("Folder","Database")):Add(node("ModuleScript","Sync"))
 local remote=rs:Add(node("RemoteEvent","Trade"))
 remote.FireServer=forbidden("FireServer")
 remote.InvokeServer=forbidden("InvokeServer")
 local sync={Weapons={
  [REPEATED_KEY]=art(SHARED,"Ancient"),
  [COMMON_KEY]=art(SHARED,"Common")},
  Item={[REPEATED_KEY]=art(OTHER,"Godly")}}
 local globals={}
 local env=setmetatable({}, {__index=_G})
 env._G=env
 env.getgenv=function()return globals end
 local game={PlaceId=142823291,JobId="stage36-synthetic-private-job"}
 function game:HttpGet(url,useCache)
  calls.http[#calls.http+1]=url
  assert(type(url)=="string" and url:match(
   "^https://raw%.githubusercontent%.com/chazebanks/MM2%-AutoTrade%-Rebuild/[^/]+/pdiddler/new_part4/p4_stage36_icon_catalog_audit%.lua$"),
   "only the pinned local core module may be fetched")
  eq(useCache,true,"module HttpGet cache argument")
  return coreSource
 end
 game.HttpPost=forbidden("HttpPost")
 local httpService={}
 function httpService:JSONEncode(value)
  calls.json=calls.json+1
  assertAnonymized(value)
  calls.encoded=value
  -- The mock checks the complete object before emitting a harmless token.
  return "{\"offlineAnonymizedReport\":true}"
 end
 httpService.GetAsync=forbidden("GetAsync")
 httpService.PostAsync=forbidden("PostAsync")
 httpService.RequestAsync=forbidden("RequestAsync")
 function game:GetService(name)
  calls.services[name]=(calls.services[name] or 0)+1
  if name=="Players" then return players end
  if name=="ReplicatedStorage" then return rs end
  if name=="HttpService" then return httpService end
  return forbidden("service "..tostring(name))()
 end
 env.game=game
 env.require=function(module)
  assert(module==syncModule,"only native Database.Sync may be required")
  calls.requireSync=calls.requireSync+1
  eq(calls.waits,2,"three stable polls before Sync is read")
  return sync
 end
 env.loadstring=function(source,name)
  assert(source==coreSource,"loader must execute the local real core")
  local chunk,message=load(source,name,"t",env)
  if not chunk then return nil,message end
  return function(...)
   local core=chunk(...)
   if type(core.collectExact)=="function" then
    local collect=core.collectExact
    core.collectExact=function(input)
     calls.collectExact=calls.collectExact+1
     calls.collectInput=input
     local catalogue,reason=collect(input)
     calls.catalogue=catalogue
     return catalogue,reason
    end
   end
   if type(core.assessExact)=="function" then
    local assess=core.assessExact
    core.assessExact=function(input)
     calls.assessExact=calls.assessExact+1
     calls.assessInput=input
     return assess(input)
    end
   end
   if type(core.assess)=="function" then
    local assess=core.assess
    core.assess=function(...)
     calls.legacyAssess=calls.legacyAssess+1
     return assess(...)
    end
   end
   return core
  end
 end
 local tick=0
 env.os=setmetatable({clock=function()
  tick=tick+1
  assert(tick<=100,"native poll loop did not terminate")
  return tick*.1
 end},{__index=os})
 env.task={spawn=function(fn)
  calls.spawned=calls.spawned+1;fn()
 end,wait=function()
  calls.waits=calls.waits+1
  assert(calls.waits<=95,"native polling exceeded the fixture bound")
 end}
 env.print=function(...)calls.printed[#calls.printed+1]=table.concat({...}," ")end
 env.warn=function(...)calls.warnings[#calls.warnings+1]=table.concat({...}," ")end
 env.setclipboard=function(value)calls.clipboard[#calls.clipboard+1]=value end
 env.request=forbidden("request")
 env.http_request=forbidden("http_request")
 env.syn={request=forbidden("syn.request")}
 env.fireclickdetector=forbidden("fireclickdetector")
 env.fireproximityprompt=forbidden("fireproximityprompt")
 env.firesignal=forbidden("firesignal")
 env.mouse1click=forbidden("mouse1click")
 local native=assert(load(nativeSource,"=stage36-native-offline","t",env))
 local state=native()
 return {state=state,globals=globals,calls=calls,sync=sync,icon=icon}
end

for _,case in ipairs({{"TheirOffer",1},{"YourOffer",4}}) do
 test("actual native exact catalogue flow for "..case[1],function()
  local f=fixture(case[1],case[2])
  local state,calls=f.state,f.calls
  assert(type(state)=="table","native launcher must return its observer state")
  eq(state.state,"FINISHED_READ_ONLY","native observer state")
  eq(state.finished,true,"native observer finished")
  eq(state,f.globals[KEY],"published native state")
  eq(calls.collectExact,1,"native collectExact calls")
  eq(calls.assessExact,1,"native assessExact calls")
  eq(calls.legacyAssess,0,"native legacy assess calls")
  eq(calls.collectInput,f.sync,"collector receives original Sync table")
  eq(calls.assessInput.catalogue,calls.catalogue,"assessor receives collected catalogue")
  eq(calls.assessInput.entries,nil,"native must not merge catalogue rows into entries")
  eq(calls.assessInput.icon,SHARED,"original Container.Icon.Image reference")
  eq(calls.assessInput.side,case[1],"observed offer side")
  eq(calls.assessInput.index,case[2],"observed slot index")
  eq(calls.assessInput.slotVisible,true,"observed slot visibility")
  eq(calls.assessInput.imageVisible,true,"observed icon visibility")
  eq(calls.assessInput.usesSpriteSheet,false,"native sprite metadata")
  eq(f.icon.Image,SHARED,"native image remains unchanged")
  local r=state.result
  eq(r.schema,"gingerscope-stage36-client-slot-icon-catalog-audit-exact-reference-v2","schema")
  eq(r.comparisonMode,"BYTE_FOR_BYTE","comparison mode")
  eq(r.status,"MULTIPLE_IDENTICAL_REFERENCE_ROWS","status")
  eq(r.stopReason,"ICON_REFERENCE_CATALOGUE_AUDIT_FINISHED","stop reason")
  eq(r.nativeOfferSlotObserved,true,"native slot observed")
  eq(r.slotSide,nil,"counts-only report omits offer side")
  eq(r.slotIndex,nil,"counts-only report omits slot index")
  eq(r.catalogEntriesAudited,3,"source rows remain distinct")
  eq(r.catalogueReferencesCompared,9,"all nonempty art fields compared")
  assert(r.catalogueReferencesCompared>0,"opaque HTTP references must be compared")
  eq(r.matchingCatalogueEntries,2,"shared icon matches across rarities")
  eq(r.matchingReferenceOccurrences,6,"matching art field occurrences")
  eq(r.matchingSourceCount,1,"matches occur in one source table")
  eq(r.duplicateReferenceGroups,1,"shared reference group")
  eq(r.rowsSharingReferences,2,"rows sharing an exact reference")
  eq(r.stringifiedKeyOverlapGroups,1,"overlapping stringified key group")
  eq(r.conflictingStringifiedKeyGroups,1,"same key retains distinct source art")
  eq(r.sourcesAliasSameTable,false,"independent Sync sources")
  eq(r.missingArtEntries,0,"all rows have art")
  eq(r.missingArtFields,0,"all art fields present")
  eq(r.emptyArtFields,0,"no empty art fields")
  eq(r.nonStringArtFields,0,"all art fields are strings")
  eq(r.catalogueCoverageComplete,true,"fixture art coverage")
  eq(r.imageReferenceAmbiguous,true,"shared reference remains ambiguous")
  eq(r.uniqueIconCandidateFound,false,"shared reference is not unique")
  eq(r.anonymizedCountsOnly,true,"counts-only report")
  eq(r.readOnly,true,"read only")
  eq(r.tradeOutcome,"UNKNOWN","trade outcome")
  eq(r.catalogueNotServerAttestation,true,"catalogue is client evidence")
  eq(r.referenceEqualityIsNotImageIdentity,true,"reference equality is not image identity")
  for _,field in ipairs({"rawItemIdConfirmed","exactWeaponIdentityConfirmed",
   "serverAttestation","serverCompletionProven","causalAttributionProven",
   "authorizesTrade","authorizesAccept","mayRecordCompletedTrade",
   "mayReportProfit"}) do
   eq(r[field],false,field)
  end
  for _,field in ipairs({"authorizesTrade","authorizesAccept",
   "mayRecordCompletedTrade","mayReportProfit"}) do
   eq(state[field],false,"state "..field)
  end
  eq(calls.spawned,1,"one observer task")
  eq(calls.waits,2,"three stable polls")
  eq(calls.requireSync,1,"one read of Database.Sync")
  eq(#calls.http,1,"only the code module is fetched")
  eq(#calls.forbidden,0,"no network, remote or input action")
  eq(calls.json,1,"one sanitized JSON report")
  eq(calls.encoded,r,"JSONEncode receives final report")
  eq(#calls.clipboard,1,"one sanitized clipboard report")
  eq(#calls.warnings,0,"no native errors")
  assertAnonymized(r)
  for _,message in ipairs(calls.printed) do assertAnonymized(message) end
  for _,message in ipairs(calls.clipboard) do assertAnonymized(message) end
 end)
end

print("Stage36 exact native: "..passed.." passed, "..#failures.." failed")
if #failures>0 then
 error("Stage36 exact native failures ("..#failures.."):\n"..
  table.concat(failures,"\n"),0)
end
