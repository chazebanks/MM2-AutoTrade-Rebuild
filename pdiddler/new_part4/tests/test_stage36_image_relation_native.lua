-- Offline behavioral integration of the actual new Stage36 launcher.
-- The game boundary is synthetic; the launcher and pure inspector are real.
local dir=arg[1] or "pdiddler/new_part4"
local function readFile(path)
 local file=io.open(path,"rb")
 if not file then return nil end
 local source=file:read("*a");file:close();return source
end
local nativeSource=readFile(dir.."/STAGE36_READONLY_IMAGE_RELATION_PROBE.lua")
local coreSource=readFile(dir.."/p4_stage36_image_relation.lua")
local KEY="PDIDDLER_STAGE36_IMAGE_RELATION"
local ICON="https://fixture.invalid/Private/Artwork.png?Token=CaseSensitive"
local OTHER="https://fixture.invalid/Private/Artwork.png?Token=casesensitive"
local PRIVATE_NAME="PrivateSyntheticStage36WeaponName"
local PRIVATE_KEY="private-stage36-relation-key"
local passed,failures=0,{}
local function eq(actual,expected,label)
 assert(actual==expected,(label or "value").." expected "..
  tostring(expected)..", got "..tostring(actual))
end
local function test(name,fn)
 local okay,why=pcall(fn)
 if okay then passed=passed+1;print("PASS "..name)
 else failures[#failures+1]=name..": "..tostring(why)
  print("FAIL "..failures[#failures]) end
end
local N={}
N.__index=function(self,key)
 if key=="ImageContent" and rawget(self,"unreadableImageContent") then
  error("private synthetic property exception",0)
 end
 return N[key]
end
function N.new(kind,name,props)
 local node=setmetatable({ClassName=kind,Name=name,Children={},
  Visible=true,Enabled=true},N)
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
local function node(...)return N.new(...)end
local forbiddenFields={}
for _,key in ipairs({"sync","icon","name","itemName","itemId","weaponId",
 "assetId","playerId","jobId","partnerId","catalogue","entries",
 "matchingKeys","matchingNames","rawImage","rawIcon","imageURL"}) do
 forbiddenFields[key]=true
end
local function anonymized(value,seen,parent)
 local kind=type(value)
 if kind=="string" then
  for _,secret in ipairs({ICON,OTHER,PRIVATE_NAME,PRIVATE_KEY,
   "fixture.invalid","private-synthetic-job","private synthetic property exception"}) do
   assert(not value:find(secret,1,true),"private synthetic metadata escaped")
  end
  assert(not value:find("://",1,true),"raw URI escaped")
 elseif kind=="table" then
  seen=seen or {};assert(not seen[value],"report contains a cycle");seen[value]=true
  for key,child in pairs(value) do
   -- assetId under queryKeys is a structural occurrence count, not an ID.
   assert(not forbiddenFields[key] or
    (parent=="queryKeys" and key=="assetId" and type(child)=="number"),
    "report exported private metadata")
   anonymized(key,seen);anonymized(child,seen,key)
  end
  seen[value]=nil
 else
  assert(kind=="number" or kind=="boolean" or kind=="nil","non-JSON report value")
 end
end
local function fixture(options)
 options=options or {}
 assert(nativeSource,"new Stage36 image relation launcher is missing")
 assert(coreSource,"real Stage36 image relation pure module is missing")
 local calls={http={},forbidden={},requireSync=0,waits=0,spawned=0,
  inspect=0,json=0,printed={},warnings={},clipboard={}}
 local function forbidden(name)
  return function()
   calls.forbidden[#calls.forbidden+1]=name
   error("unexpected network, execution or input action",0)
  end
 end
 local players=node("Players","Players")
 local me=players:Add(node("Player","Local",{UserId=880011}))
 players.LocalPlayer=me
 local pg=me:Add(node("PlayerGui","PlayerGui"))
 local screen=pg:Add(node("ScreenGui",options.phone and "TradeGUI_Phone" or "TradeGUI"))
 local root=screen:Add(node("Frame","Container")):Add(node("Frame","Trade"))
 local offers={}
 for _,side in ipairs({"TheirOffer","YourOffer"}) do
  offers[side]=root:Add(node("Frame",side)):Add(node("Frame","Container"))
 end
 local side,index=options.side or "TheirOffer",options.index or 1
 local slot=offers[side]:Add(node("Frame","NewItem"..index))
 local label=slot:Add(node("Frame","ItemName")):Add(node("TextLabel","Label",{
  Text=PRIVATE_NAME}))
 -- A direct child Icon is a distractor; only Container.Icon is native art.
 slot:Add(node("ImageLabel","Icon",{Image=OTHER,ImageRectSize={X=0,Y=0}}))
 local content=setmetatable({SourceType={Name=options.sourceType or "Uri"}},
  {__index=function(_,key)return forbidden("ImageContent."..tostring(key))()end})
 local icon=slot:Add(node("Frame","Container")):Add(node("ImageLabel","Icon",{
  Image=ICON,ImageRectSize=options.rect or {X=0,Y=0},
  ImageContent=content}))
 if options.unreadableContent then
  icon.ImageContent=nil;icon.unreadableImageContent=true
 end
 local rs=node("ReplicatedStorage","ReplicatedStorage")
 local syncModule=rs:Add(node("Folder","Database")):Add(node("ModuleScript","Sync"))
 local remote=rs:Add(node("RemoteEvent","Trade"))
 remote.FireServer=forbidden("FireServer");remote.InvokeServer=forbidden("InvokeServer")
 remote.OnClientEvent=setmetatable({}, {__index=forbidden("remote listener")})
 local sync={Weapons={
  [PRIVATE_KEY]={Image=ICON,Icon=OTHER,Texture="rbxassetid://123456",
   Name=PRIVATE_NAME,Rarity="Ancient"}},
  Item={other={Image=OTHER,Name="AnotherPrivateSyntheticName",Rarity="Common"}}}
 if options.alias then sync.Item=sync.Weapons end
 local globals={}
 if options.owner then globals[options.owner]={} end
 local env=setmetatable({}, {__index=_G});env._G=env
 env.getgenv=function()return globals end
 local game={PlaceId=142823291,JobId="private-synthetic-job"}
 local f={calls=calls,sync=sync,globals=globals,players=players,me=me,
  pg=pg,screen=screen,root=root,slot=slot,label=label,icon=icon,game=game}
 function game:HttpGet(url,useCache)
  calls.http[#calls.http+1]=url
  local pin=url:match("^https://raw%.githubusercontent%.com/chazebanks/"..
   "MM2%-AutoTrade%-Rebuild/(%x+)/pdiddler/new_part4/p4_stage36_image_relation%.lua$")
  assert(pin and #pin==40,"only the pinned reviewed pure source may be fetched")
  eq(useCache,true,"source cache argument")
  return coreSource
 end
 game.HttpPost=forbidden("HttpPost")
 local http={}
 function http:JSONEncode(value)
  calls.json=calls.json+1;anonymized(value);calls.encoded=value
  return '{"offlineAnonymizedReport":true}'
 end
 for _,method in ipairs({"GetAsync","PostAsync","RequestAsync"}) do
  http[method]=forbidden(method)
 end
 function game:GetService(name)
  if name=="Players" then return players end
  if name=="ReplicatedStorage" then return rs end
  if name=="HttpService" then return http end
  return forbidden("service "..tostring(name))()
 end
 env.game=game
 env.require=function(module)
  assert(module==syncModule,"only existing Database.Sync may be required")
  calls.requireSync=calls.requireSync+1
  assert(calls.waits>=2,"Sync was read before three stable polls")
  if options.onRequire then options.onRequire(f) end
  if options.requireError then error("private synthetic property exception",0) end
  return sync
 end
 env.loadstring=function(source,name)
  assert(source==coreSource,"only the real local reviewed pure source may execute")
  local chunk,message=load(source,name,"t",env)
  if not chunk then return nil,message end
  return function(...)
   local core=chunk(...)
   local inspect=assert(core.inspect,"real core must expose inspect")
   core.inspect=function(input)
    calls.inspect=calls.inspect+1;calls.inspectInput=input
    return inspect(input)
   end
   return core
  end
 end
 local tick=0
 env.os=setmetatable({clock=function()
  tick=tick+1;assert(tick<=100,"native poll loop did not terminate");return tick
 end},{__index=os})
 env.task={spawn=function(fn)calls.spawned=calls.spawned+1;fn()end,
  wait=function()
   calls.waits=calls.waits+1
   if options.onWait then options.onWait(f,calls.waits) end
  end}
 env.print=function(...)calls.printed[#calls.printed+1]=table.concat({...}," ")end
 env.warn=function(...)calls.warnings[#calls.warnings+1]=table.concat({...}," ")end
 env.setclipboard=function(value)calls.clipboard[#calls.clipboard+1]=value end
 for _,name in ipairs({"request","http_request","fireclickdetector",
  "fireproximityprompt","firesignal","mouse1click","getconnections",
  "hookfunction","hookmetamethod","getsenv","getscriptclosure"}) do
  env[name]=forbidden(name)
 end
 env.syn={request=forbidden("syn.request")}
 f.state=assert(load(nativeSource,"=stage36-image-relation-native-offline","t",env))()
 return f
end
local function safety(f)
 eq(#f.calls.forbidden,0,"no image requests, remotes, listeners, hooks or input")
 for _,message in ipairs(f.calls.printed) do anonymized(message) end
 for _,message in ipairs(f.calls.warnings) do anonymized(message) end
 for _,message in ipairs(f.calls.clipboard) do anonymized(message) end
 if not f.state then return end
 eq(f.state.state,"FINISHED_READ_ONLY","finished observer state")
 eq(f.state.finished,true,"observer stopped after one snapshot")
 eq(f.calls.inspect,1,"one pure inspection")
 eq(f.calls.json,1,"one report")
 eq(f.calls.encoded,f.state.result,"only final core report encoded")
 eq(f.state.result.schema,"gingerscope-stage36-image-relation-v1","report schema")
 eq(f.state.result.status,f.calls.inspectInput and
  "RELATIONSHIP_OBSERVED_INCONCLUSIVE" or "INCOMPLETE","unproven report status")
 for _,field in ipairs({"rawItemIdConfirmed","exactWeaponIdentityConfirmed",
  "serverAttestation","serverCompletionProven","causalAttributionProven",
  "authorizesTrade","authorizesAccept","mayRecordCompletedTrade","mayReportProfit"}) do
  eq(f.state.result[field],false,field)
 end
 anonymized(f.state.result)
end
for _,case in ipairs({{"TheirOffer",1,false},{"YourOffer",4,true}}) do
 test("actual native single snapshot for "..case[1],function()
  local f=fixture({side=case[1],index=case[2],phone=case[3]})
  safety(f)
  eq(f.state,f.globals[KEY],"new independent owner")
  eq(#f.calls.http,1,"only source fetched")
  eq(f.calls.requireSync,1,"only existing Sync executed once")
  eq(f.calls.waits,2,"three stable polls")
  local input=assert(f.calls.inspectInput,"native context must reach the real inspector")
  eq(input.sync,f.sync,"original Sync table")
  eq(input.icon,ICON,"original exact Container.Icon.Image")
  eq(input.name,PRIVATE_NAME,"original exact stable native label")
  eq(input.contentKind,"URI","SourceType.Name metadata")
  eq(input.sprite,false,"whole image")
  eq(input.contextVerified,true,"rechecked native context")
  eq(f.icon.Image,ICON,"image unchanged")
  eq(f.label.Text,PRIVATE_NAME,"label unchanged")
  assert(f.calls.printed[1]:find("No testing transfer is needed",1,true),
   "observer must say no testing transfer is needed")
 end)
end
test("native passes alias Sync sources unchanged",function()
 local f=fixture({alias=true});safety(f)
 eq(f.calls.inspectInput.sync,f.sync,"original aliased Sync")
 eq(f.calls.inspectInput.sync.Weapons,f.calls.inspectInput.sync.Item,"alias retained")
end)
for _,case in ipairs({{{X=16,Y=16},true},{{X=16,Y=0},false},{{X=0,Y=16},false}}) do
 test("sprite metadata requires both dimensions: "..case[1].X..","..case[1].Y,function()
  local f=fixture({rect=case[1]});safety(f)
  eq(f.calls.inspectInput.sprite,case[2],"documented whole-image zero dimension")
 end)
end
for _,case in ipairs({{"Object","OBJECT"},{"None","NONE"},{"Unknown","UNREADABLE"}}) do
 test("SourceType.Name is read safely: "..case[1],function()
  local f=fixture({sourceType=case[1]});safety(f)
  eq(f.calls.inspectInput.contentKind,case[2],"content metadata family")
 end)
end
test("unavailable ImageContent is a safe unreadable observation",function()
 local f=fixture({unreadableContent=true});safety(f)
 eq(f.calls.inspectInput.contentKind,"UNREADABLE","property failure is not object inspection")
end)
test("same icon with a changed label restarts the stable polls",function()
 local f=fixture({onWait=function(f,n)
  if n==1 then f.label.Text="ChangedPrivateSyntheticName" end
 end});safety(f)
 eq(f.calls.waits,3,"new label requires three new stable polls")
 eq(f.calls.inspectInput.name,"ChangedPrivateSyntheticName","stable changed exact label")
end)
for _,case in ipairs({
 {"icon",function(f)f.icon.Image=OTHER end},
 {"label text",function(f)f.label.Text="ChangedPrivateSyntheticName" end},
 {"owner",function(f)f.globals[KEY]={}end},
 {"competing owner",function(f)f.globals.PDIDDLER_STAGE36_ICON_CATALOG_AUDIT={}end},
 {"job",function(f)f.game.JobId="changed-job"end},
 {"player",function(f)f.players.LocalPlayer={}end},
 {"root",function(f)f.root.Name="ReplacedTrade"end},
 {"slot",function(f)f.slot.Name="ReplacedSlot"end},
 {"icon object",function(f)f.icon.Name="ReplacedIcon"end},
 {"label object",function(f)f.label.Name="ReplacedLabel"end},
 {"visibility",function(f)f.label.Visible=false end}}) do
 test("abort when "..case[1].." changes during Sync require",function()
  local f=fixture({onRequire=case[2]});safety(f)
  eq(f.calls.inspectInput,nil,"changed context never reaches pure inspector")
  eq(f.state.result.stopReason,"SLOT_CHANGED_DURING_SYNC_READ","fixed safe abort reason")
  eq(f.calls.requireSync,1,"one attempted Sync read")
 end)
end
test("Sync require failure stays read-only and omits exception text",function()
 local f=fixture({requireError=true});safety(f)
 eq(f.calls.inspectInput,nil,"unavailable Sync has no context")
 eq(f.state.result.stopReason,"SYNC_CATALOGUE_UNAVAILABLE","fixed safe failure")
end)
for _,owner in ipairs({KEY,"PDIDDLER_STAGE36_ICON_CATALOG_AUDIT",
 "PDIDDLER_STAGE35_SLOT_METADATA_CENSUS","PDIDDLER_STAGE34_OFFER_INVENTORY_PROBE",
 "PDIDDLER_STAGE33_TRANSPORT_CENSUS","PDIDDLER_STAGE32_RESULT_CORRELATION_PROBE",
 "PDIDDLER_STAGE29_POSTCLOSE_PROBE","PDIDDLER_STAGE25_SCANNER_ONLY",
 "PDIDDLER_GINGERSCOPE_REPLACEMENT_PREVIEW","PDIDDLER_OUTGOING_SESSION",
 "PDIDDLER_PART4_SESSION","PDIDDLER_PART4_CONTROLLER","PDIDDLER_PART5_CONTROLLER",
 "PDIDDLER_INTEGRATION_V15_8_VALUE_FIRST","PDIDDLER_STAGE30_PASSIVE_SIGNALS",
 "PDIDDLER_STAGE28_PASSIVE_ACCEPT_PROBE","PDIDDLER_STAGE27_NATIVE_LAB",
 "PDIDDLER_OUTGOING_CONTROLLER","PDIDDLER_HOPPING_SESSION",
 "PDIDDLER_INTEGRATION_V15_7_INVENTORY_GROWTH",
 "PDIDDLER_INTEGRATION_V15_6_IMMEDIATE_SAFETY"}) do
 test("competing owner blocks all execution: "..owner,function()
  local f=fixture({owner=owner});safety(f)
  eq(f.state,nil,"no competing observer")
  eq(#f.calls.http,0,"no code fetch")
  eq(f.calls.spawned,0,"no polling task")
  eq(f.calls.requireSync,0,"no Sync require")
  eq(f.calls.inspect,0,"no pure inspection")
  eq(f.calls.json,0,"no report")
 end)
end
print("Stage36 image relation native: "..passed.." passed, "..#failures.." failed")
if #failures>0 then
 error("Stage36 image relation native failures ("..#failures.."):\n"..
  table.concat(failures,"\n"),0)
end
