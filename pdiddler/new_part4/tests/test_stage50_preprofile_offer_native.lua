-- Actual new launcher, real bounded core and unchanged Stage9 modules, fake game boundary.
local dir=arg[1] or "pdiddler/new_part4"
local function read(path)
 local f=io.open(path,"rb");if not f then return nil end
 local s=f:read("*a");f:close();return s
end
local native=read(dir.."/STAGE50_READONLY_PREPROFILE_OFFER_KEY_PROBE.lua")
local core=read(dir.."/p4_trade_update_shape.lua")
local presence=read(dir.."/p4_stage39_literal_key_presence.lua")
local schemaSource=read(dir.."/p4_stage40_trade_schema_hypothesis.lua")
local typeSource=read(dir.."/p4_stage41_key_type_first_failure.lua")
local orientationSource=read(dir.."/p4_stage42_player_orientation.lua")
local dynamicSource=read(dir.."/p4_stage43_dynamic_own_offer.lua")
local stateSource=read(dir.."/p4_stage44_client_offer_state.lua")
local profileSource=read(dir.."/p4_stage50_preprofile_raw_key.lua")
local reader=assert(read(dir.."/p4_native_observer.lua"))
local contract=assert(read(dir.."/p4_observer_contract.lua"))
local BASE="35ec2d9a47048910a464a2ef6eb9b9f52ae306b1"
local KEY="PDIDDLER_STAGE50_PREPROFILE_OFFER_KEY"
local PRIVATE_KEY="Private_Batwing_Catalogue_Key"
local OTHER_KEY="Private_Other_Catalogue_Key"
local SECRET="PrivateSyntheticValue-DoNotExport"
local passed,failures=0,{}
local function eq(a,b,label)assert(a==b,(label or "value")..": "..tostring(a).." ~= "..tostring(b))end
local function test(name,fn)
 local ok,why=pcall(fn)
 if ok then passed=passed+1;print("PASS "..name)
 else failures[#failures+1]=name..": "..tostring(why);print("FAIL "..failures[#failures])end
end
local function clean(v,seen)
 if type(v)=="string" then
  assert(not v:find(SECRET,1,true),"private value escaped")
  assert(not v:find("Private_",1,true),"private catalog raw key escaped")
  assert(not v:find("private%-job"),"job escaped")
  assert(not v:find("https?://"),"URL escaped")
 elseif type(v)=="table" then
  seen=seen or {};assert(not seen[v],"report cycle");seen[v]=true
  for k,x in pairs(v)do clean(k,seen);clean(x,seen)end
  seen[v]=nil
 else assert(type(v)=="nil" or type(v)=="number" or type(v)=="boolean","non-JSON export")end
end
local function fixture(opts)
 opts=opts or {}
 assert(native,"new direct-key launcher is missing")
 assert(core,"new real shape core is missing")
 assert(presence,"stage39 key comparator module is missing")
 assert(schemaSource,"stage40 trade schema candidate module missing")
 assert(typeSource,"stage41 first failure module missing")
 assert(orientationSource,"stage42 orientation module missing")
 assert(dynamicSource,"stage43 dynamic own-offer module missing")
 assert(stateSource,"stage44 offer state module missing")
  assert(profileSource,"stage50 profile module missing")
 local calls={http={},forbidden={},allConnections={},json=0,inspect=0,prints={},warns={},waits=0,remoteConnects=0,profileCalls=0}
 local f={calls=calls,now=0,globals={},threads={}}
 local function forbidden(name)return function()calls.forbidden[#calls.forbidden+1]=name;error("forbidden boundary "..name,0)end end
 local function signal(kind)
  local s={connections={}}
  function s:Connect(fn)
   if opts.attachFailure==kind then error(SECRET,0)end
   local c={Connected=true,disconnects=0,fn=fn,kind=kind}
   function c:Disconnect()
    self.disconnects=self.disconnects+1
    if opts.disconnectFailure==kind then error(SECRET,0)end
    self.Connected=false
   end
   self.connections[#self.connections+1]=c;calls.allConnections[#calls.allConnections+1]=c
   if kind=="UpdateTrade" then
    calls.remoteConnects=calls.remoteConnects+1
    if opts.duringConnect then opts.duringConnect(f,fn)end
    if opts.connectThrowsAfterCallback then error(SECRET,0)end
   end
   return c
  end
  function s:Fire(...)
   local snapshot={};for _,c in ipairs(self.connections)do snapshot[#snapshot+1]=c end
   for _,c in ipairs(snapshot)do if c.Connected then c.fn(...)end end
  end
  return s
 end
 local N={};N.__index=N
 local function node(kind,name,props)
  local n=setmetatable({ClassName=kind,Name=name,Children={},attrs={},Visible=true,Enabled=true,signals={}},N)
  n.AncestryChanged=signal("ancestry")
  for k,v in pairs(props or {})do n[k]=v end;return n
 end
 function N:Add(c)c.Parent=self;self.Children[#self.Children+1]=c;return c end
 function N:IsA(k)return self.ClassName==k or (k=="GuiObject" and
  (self.ClassName=="Frame" or self.ClassName=="TextLabel" or self.ClassName=="TextButton" or self.ClassName=="ImageLabel"))end
 function N:FindFirstChild(name,recurse)
  for _,c in ipairs(self.Children)do if c.Name==name then return c end end
  if recurse then for _,c in ipairs(self.Children)do local v=c:FindFirstChild(name,true);if v then return v end end end
 end
 function N:FindFirstChildOfClass(kind)for _,c in ipairs(self.Children)do if c:IsA(kind)then return c end end end
 function N:GetChildren()
  if f.raiseReadError or (opts.readErrorAfterBind and calls.remoteConnects>0)then error(SECRET,0)end
  return self.Children
 end
 function N:GetDescendants()
  local all={};local function walk(n)for _,c in ipairs(n.Children)do all[#all+1]=c;walk(c)end end;walk(self);return all
 end
 function N:GetAttribute(k)if opts.captureError then error(SECRET,0)end;return self.attrs[k]end
 function N:GetPropertyChangedSignal(prop)
  if not self.signals[prop]then self.signals[prop]=signal("property:"..prop)end;return self.signals[prop]
 end
 function N:Change(k,v)self[k]=v;if self.signals[k]then self.signals[k]:Fire()end end
 function N:Move(p)self.Parent=p;self.AncestryChanged:Fire(self,p)end
 local players=node("Players","Players");players.PlayerRemoving=signal("departure")
 local me=players:Add(node("Player","Local",{UserId=771122}))
 local partner=players:Add(node("Player",SECRET,{UserId=993344}));players.LocalPlayer=me
 function players:GetPlayers()return self.Children end
 function players:GetPlayerByUserId(id)for _,p in ipairs(self.Children)do if p.UserId==id then return p end end end
 local pg=me:Add(node("PlayerGui","PlayerGui"))
 local function addGui(phone)
  local screen=pg:Add(node("ScreenGui",phone and "TradeGUI_Phone" or "TradeGUI",{Enabled=not opts.closed}))
  local root=screen:Add(node("Frame","Container")):Add(node("Frame","Trade"))
  local sides={}
  for _,name in ipairs({"YourOffer","TheirOffer"})do
   local side=root:Add(node("Frame",name));sides[name]=side
   side:Add(node("Frame","Accepted",{Visible=opts.accepted==name}))
   local slots=side:Add(node("Frame","Container"))
   local slot=slots:Add(node("Frame","NewItem1",{Visible=opts.initialPopulated==true}));slot.attrs.ItemId=SECRET
   slot:Add(node("Frame","ItemName")):Add(node("TextLabel","Label",{Text=SECRET}))
   slot:Add(node("Frame","Container")):Add(node("TextLabel","Amount",{Text=""}))
  end
  local label=sides.TheirOffer:Add(node("TextLabel","Username",{Text="("..SECRET..")"}))
  return screen,root,sides,label
 end
 local screen,root,sides,label=addGui(opts.phone)
 if opts.twoRoots then addGui(not opts.phone)end
 if opts.ambiguousPartner then players:Add(node("Player",SECRET:lower(),{UserId=665544}))end
 local rs=node("ReplicatedStorage","ReplicatedStorage")
 local folder=rs:Add(node("Folder","Trade"))
 local remote=folder:Add(node("RemoteEvent",opts.missingRemote and "UpdateOffers" or "UpdateTrade"))
 remote.OnClientEvent=signal("UpdateTrade")
 remote.FireServer=forbidden("FireServer");remote.InvokeServer=forbidden("InvokeServer")
 local remotes=rs:Add(node("Folder","Remotes"))
 local inv=remotes:Add(node("Folder","Inventory"))
 if not opts.profileRemoteMissing then
  local get=inv:Add(node(opts.profileRemoteType or "RemoteFunction","GetProfileData"))
  get.FireServer=forbidden("unexpected profile FireServer")
  function get:InvokeServer(...)
   calls.profileCalls=calls.profileCalls+1
   eq(select("#",...),0,"GetProfileData must have zero args")
   if opts.profileRpcHang then
    while not f.profileRpcReleased do coroutine.yield() end
   end
   if opts.profileRpcError then error(SECRET,0)end
   if opts.duringProfile then opts.duringProfile(f)end
   if opts.profileBadShape then return {NoWeapons=true}end
   local obj={Weapons={Owned=opts.profileOwned or {[PRIVATE_KEY]=2,[OTHER_KEY]=1}}}
   if opts.profileWrapped then return {ProfileData=obj}end
   return obj
  end
 end
 local db=rs:Add(node("Folder","Database"))
 local syncModule=db:Add(node("ModuleScript","Sync"))
 local catalog=opts.sync or {Weapons={
  [PRIVATE_KEY]={ItemName="Batwing",Rarity="Ancient",Chroma=false},
  [OTHER_KEY]={ItemName="OtherThing",Rarity="Godly",Chroma=false}}}
 catalog.Item=opts.itemSeparate and catalog.Item or catalog.Weapons
 local other=folder:Add(node("RemoteEvent","AcceptTrade"))
 other.OnClientEvent={Connect=forbidden("other remote listener")}
 if opts.duplicateRemote then folder:Add(node("RemoteEvent","UpdateTrade"))end
 if opts.wrongRemoteType then remote.ClassName="RemoteFunction"end
 local env=setmetatable({}, {__index=_G});env._G=env
 env.getgenv=function()return f.globals end
 if opts.owner then f.globals[opts.owner]={}end
 local game={PlaceId=142823291,JobId="private-job"};env.game=game
 if opts.wrongPlace then game.PlaceId=1 end
 local http={}
 function http:JSONEncode(report)
  calls.json=calls.json+1;clean(report)
  for _,c in ipairs(calls.allConnections)do
   if opts.disconnectFailure==c.kind or (opts.connectThrowsAfterCallback and c.kind=="UpdateTrade")then eq(report.cleanupComplete,false,"failed disconnect disclosed")
   else eq(c.Connected,false,"all disconnected before JSON")end
  end
  if opts.jsonFailure then error(SECRET,0)end
  calls.encoded=report;return '{"anonymized":true}'
 end
 function game:GetService(name)
  if name=="Players"then return players elseif name=="ReplicatedStorage"then return rs
  elseif name=="HttpService"then return http end
  return forbidden("service "..tostring(name))()
 end
 function game:HttpGet(url,cached)
  calls.http[#calls.http+1]=url;eq(cached,true,"cache argument")
  local pin,name=url:match("^https://raw%.githubusercontent%.com/chazebanks/MM2%-AutoTrade%-Rebuild/([^/]+)/pdiddler/new_part4/([^/]+)%.lua$")
  assert(pin and name,"only reviewed module sources may be fetched")
  if opts.moduleFailure==name then error(SECRET,0)end
  if name=="p4_native_observer"then eq(pin,BASE,"immutable reader base");return reader end
  if name=="p4_observer_contract"then eq(pin,BASE,"immutable contract base");return contract end
  if name=="p4_trade_update_shape"then
   eq(pin,"b32ed071faf9d7cb390e7d87b70ca57abda151e4","old pure shape module pin")
   return core
  end
  if name=="p4_stage39_literal_key_presence"then
   eq(pin,"bc6eb1394b70b84e20f18f6bcbbadd076e9bf962","new comparator pin")
   return presence
  end
  if name=="p4_stage40_trade_schema_hypothesis"then
   eq(pin,"9003ba057f23aa44460dbb2f9895e8ade3d73a3b","schema candidate pin")
   return schemaSource
  end
  if name=="p4_stage41_key_type_first_failure"then
   eq(pin,"9dbd727a0b563aff11be2434bd679be55f911a53","stage41 first failure pin")
   return typeSource
  end
  if name=="p4_stage42_player_orientation"then
   eq(pin,"9fcd2ae45d8ae3ee2c5292d794097703df24206d","stage42 orientation pin")
   return orientationSource
  end
  if name=="p4_stage43_dynamic_own_offer"then
   eq(pin,"26b51a41ffd65e1c422054358e353360871e1428","stage43 owner-relative tuple pin")
   return dynamicSource
  end
  if name=="p4_stage50_preprofile_raw_key"then
   eq(pin,"43cd3031127ea769ab608078f4b89b5f90c43fa6","stage50 pure module pin")
   return profileSource
  end
  if name=="p4_stage44_client_offer_state"then
   eq(pin,"749adf9c7a967818358cb91b2033a7f0ae706fb4","stage44 offer-state pin")
   return stateSource
  end
  error("unexpected remote code module "..tostring(name))
 end
 env.loadstring=function(src,name)
  assert(src==core or src==reader or src==contract or src==presence or src==schemaSource or src==typeSource or src==orientationSource or src==dynamicSource or src==stateSource or src==profileSource,"unreviewed execution")
  local chunk,why=load(src,name,"t",env);if not chunk then return nil,why end
  return function()
   local m=chunk()
   if src==core then local inspect=m.inspect;m.inspect=function(...)
    calls.inspect=calls.inspect+1
    if opts.duringInspect then opts.duringInspect(f)end
    return inspect(...)
   end end
   return m
  end
 end
 env.os={clock=function()if f.clockFn then return f.clockFn()end;return f.now end}
 env.task={spawn=function(fn)
  local co=coroutine.create(fn)
  f.threads[#f.threads+1]=co
  if not f.thread then f.thread=co end
  return co
 end,wait=function(dt)
  f.now=f.now+(dt or .16);calls.waits=calls.waits+1
  if opts.onWait then opts.onWait(f,calls.waits)end
  coroutine.yield()
 end}
 env.print=function(s)calls.prints[#calls.prints+1]=s end
 env.warn=function(s)calls.warns[#calls.warns+1]=s end
 env.setclipboard=function(s)clean(s);calls.clipboard=s end
 env.require=function(m)
  if m~=syncModule then return forbidden("require unknown module")()end
  if opts.requireFails then error(SECRET,0)end
  if opts.duringSync then opts.duringSync(f)end
  calls.sync=(calls.sync or 0)+1
  return catalog
 end
 for _,name in ipairs({"request","http_request","getconnections","hookfunction","hookmetamethod","getrawmetatable","getsenv","getscriptclosure","decompile","fireclickdetector","firesignal","mouse1click"})do env[name]=forbidden(name)end
 f.players=players;f.me=me;f.partner=partner;f.pg=pg;f.screen=screen;f.root=root
 f.sides=sides;f.label=label;f.remote=remote;f.folder=folder;f.node=node;f.game=game;f.env=env;f.catalog=catalog;f.syncModule=syncModule
 function f:step()
  local n=#self.threads
  for i=1,n do
   local co=self.threads[i]
   if coroutine.status(co)~="dead"then
    local ok,why=coroutine.resume(co);assert(ok,why)
   end
  end
 end
 function f:untilPhase(phase)
  for _=1,1000 do
   if self.state and self.state.phase==phase then return end
   if self.state and self.state.finished then error("finished before "..phase..": "..tostring(self.state.result and self.state.result.stopReason))end
   self:step()
  end
  error("poll did not reach "..phase.." current="..tostring(self.state and self.state.phase).." finished="..tostring(self.state and self.state.finished).." now="..tostring(self.now).." coroutine="..tostring(self.thread and coroutine.status(self.thread)).." lastMarker="..tostring(self.calls.prints[#self.calls.prints]))
 end
 function f:finishLoop()for _=1,1000 do if not self.state or self.state.finished then return end;self:step()end;error("loop did not terminate")end
 function f:emit(...)self.remote.OnClientEvent:Fire(...)end
 f.state=assert(load(native,"=stage50-actual-whole-native","t",env))()
 return f
end
local function safe(f,reason)
 eq(#f.calls.forbidden,0,"forbidden boundary calls")
 for _,s in ipairs(f.calls.prints)do clean(s)end
 for _,s in ipairs(f.calls.warns)do clean(s)end
 if not f.state then return end
 eq(f.state.finished,true,"finished")
 eq(f.state.phase,"FINISHED_READ_ONLY","finished state")
 eq(f.calls.json,1,"one JSON attempt")
 local r=assert(f.state.result,"sanitized result");clean(r)
 eq(r.schema,"gingerscope-trade-update-payload-shape-v1","schema")
 eq(r.eventName,"UpdateTrade","one allowlisted event")
 if reason then eq(r.stopReason,reason,"fixed reason")end
 for _,key in ipairs({"payloadSchemaKnown","rawKeyPresentConfirmed","ownerSideSlotBound","eventSessionAssociationProven","eventOrderingKnown","rawItemIdConfirmed","rawItemKeyConfirmed","sideMappingConfirmed","serverSessionBindingConfirmed","payloadSchemaConfirmed","argumentOrderConfirmed","serverCompletionProven","causalAttributionProven","authorizesTrade","authorizesAccept","mayRecordCompletedTrade","mayReportProfit"})do
  eq(r[key],false,key)
 end
 eq(r.cleanupComplete,true,"complete teardown")
 eq(r.listenersAttached,#f.calls.allConnections,"attached listener count")
 eq(r.listenersDisconnected,#f.calls.allConnections,"disconnected listener count")
 for _,c in ipairs(f.calls.allConnections)do eq(c.Connected,false,"listener cleanup")end
 for k,v in pairs(f.state)do
  assert(k~="root" and k~="partner" and k~="observer" and k~="payload" and k~="connections","private native object stored on S")
  if type(v)~="function"then clean(v)end
 end
end


local function addBatwing(f)
 local slot=f.sides.YourOffer:FindFirstChild("Container"):FindFirstChild("NewItem1")
 assert(slot and slot.Visible==false,"must start empty")
 local name=slot:FindFirstChild("ItemName"):FindFirstChild("Label")
 name.Text="Batwing"
 slot.Visible=true
 f:step()
 f:step()
end

local function tradeState(f,orientation,include,options)
 options=options or {}
 local firstLocal=orientation=="LOCAL_FIRST"
 local root={Locked=false,LastOffer=1760000123,
  Player1={Player=firstLocal and f.me or f.partner,Accepted=false,Offer={}},
  Player2={Player=firstLocal and f.partner or f.me,Accepted=false,Offer={}}}
 if include then
  (firstLocal and root.Player1 or root.Player2).Offer={{options.rawKey or PRIVATE_KEY,options.quantity or 1,options.category or "Weapons"}}
 end
 if options.partnerItem then
  (firstLocal and root.Player2 or root.Player1).Offer={{OTHER_KEY,1,"Weapons"}}
 end
 if options.partnerAccepted then
  (firstLocal and root.Player2 or root.Player1).Accepted=true
 end
 if options.badPlayer then
  (firstLocal and root.Player1 or root.Player2).Player={}
 end
 return root
end
local function removeBatwing(f)
 local slot=f.sides.YourOffer:FindFirstChild("Container"):FindFirstChild("NewItem1")
 assert(slot and slot.Visible==true,"must have manual Batwing in offer before removal")
 slot.Visible=false
 f:step()
 f:step()
end
local function completeAdd(f,orientation,options)
 addBatwing(f)
 f:emit(tradeState(f,orientation,true,options))
 f:untilPhase("WAIT_MANUAL_REMOVE")
 eq(f.state.finished,false,"must not end after add")
end
test("Stage50 native preprofile RPC occurs once before add",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 eq(f.calls.profileCalls,1);eq(f.state.finished,false)
 completeAdd(f,"LOCAL_SECOND")
 removeBatwing(f);f:emit(tradeState(f,"LOCAL_SECOND",false))
 f:finishLoop();safe(f,"TWO_PHASE_CLIENT_PREPROFILE_RAW_KEY_MATCHED")
 local r=f.state.result
 eq(r.stage50ProfileReadReady,true)
 eq(r.stage50ProfileReadAttempts,1)
 eq(r.stage50ClientRawOfferOwnedMatch,true)
 eq(r.stage50Preprofile.profileCandidateClientMatched,true)
 eq(r.stage50Preprofile.rawOfferKeyBoundToPreprofile,false)
 eq(r.stage50Preprofile.checkerIdentityVerified,false)
 eq(r.stage50Preprofile.serverCompletionProven,false)
 eq(f.calls.profileCalls,1)
end)
test("Stage50 native wrapped profile works",function()
 local f=fixture({profileWrapped=true});f:untilPhase("LISTENING_UPDATE_TRADE")
 completeAdd(f,"LOCAL_FIRST")
 removeBatwing(f);f:emit(tradeState(f,"LOCAL_FIRST",false))
 f:finishLoop();safe(f,"TWO_PHASE_CLIENT_PREPROFILE_RAW_KEY_MATCHED")
end)
test("Stage50 native missing preprofile RemoteFunction fails before event listener",function()
 local f=fixture({profileRemoteMissing=true});f:finishLoop()
 safe(f,"OWN_PROFILE_REMOTE_MISSING")
 eq(f.calls.profileCalls,0);eq(f.calls.remoteConnects,0)
end)
test("Stage50 native incorrect RemoteFunction type refuses",function()
 local f=fixture({profileRemoteType="RemoteEvent"});f:finishLoop()
 safe(f,"OWN_PROFILE_REMOTE_MISSING")
 eq(f.calls.profileCalls,0)
end)
test("Stage50 native missing Batwing raw key refuses before listener",function()
 local f=fixture({profileOwned={[OTHER_KEY]=3}});f:finishLoop()
 safe(f,"PREPROFILE_RAW_KEY_NOT_MATCHED")
 eq(f.calls.remoteConnects,0)
 eq(f.state.result.stage50Preprofile.reason,"KEY_NOT_PRESENT_IN_PREPROFILE")
end)
test("Stage50 native zero preprofile Batwing count refuses",function()
 local f=fixture({profileOwned={[PRIVATE_KEY]=0}});f:finishLoop()
 safe(f,"PREPROFILE_RAW_KEY_NOT_MATCHED")
 eq(f.state.result.stage50Preprofile.reason,"KEY_ZERO_PREPROFILE_COPIES")
end)
test("Stage50 native numeric Owned key cannot alias string",function()
 local f=fixture({profileOwned={[42]=2}});f:finishLoop()
 safe(f,"PREPROFILE_RAW_KEY_NOT_MATCHED")
end)
test("Stage50 native numeric string collision in Owned refuses",function()
 local f=fixture({profileOwned={[PRIVATE_KEY]=2,[42]=1,["42"]=1}});f:finishLoop()
 safe(f,"PREPROFILE_RAW_KEY_NOT_MATCHED")
 eq(f.state.result.stage50Preprofile.reason,"PROFILE_STRING_NUMERIC_KEY_COLLISION")
end)
test("Stage50 native malformed extra owned item count refuses",function()
 local f=fixture({profileOwned={[PRIVATE_KEY]=2,[OTHER_KEY]="NO"}});f:finishLoop()
 safe(f,"PREPROFILE_RAW_KEY_NOT_MATCHED")
 eq(f.state.result.stage50Preprofile.reason,"PROFILE_QUANTITY_INVALID")
end)
test("Stage50 native unrecognized profile result fails closed",function()
 local f=fixture({profileBadShape=true});f:finishLoop()
 safe(f,"OWN_PROFILE_SHAPE_UNRECOGNIZED")
 eq(f.state.result.stage50Preprofile,nil)
end)
test("Stage50 native RPC exception not leaked",function()
 local f=fixture({profileRpcError=true});f:finishLoop()
 safe(f,"OWN_PROFILE_READ_FAILED");eq(f.calls.profileCalls,1)
end)
test("Stage50 native profile RPC timeout bounded",function()
 local f=fixture({profileRpcHang=true});f:finishLoop()
 safe(f,"OWN_PROFILE_READ_TIMEOUT")
 eq(f.state.result.stage50ProfileReadTimedOut,true)
 eq(f.state.result.stage50ClientRawOfferOwnedMatch,false)
 eq(f.calls.profileCalls,1)
end)
test("Stage50 native late RPC result cannot republish",function()
 local f=fixture({profileRpcHang=true});f:finishLoop()
 safe(f,"OWN_PROFILE_READ_TIMEOUT")
 local report=f.state.result
 f.profileRpcReleased=true;f:step();f:step()
 eq(f.calls.json,1);eq(f.calls.profileCalls,1);eq(f.state.result,report)
end)
test("Stage50 native GUI close during profile read fails",function()
 local f=fixture({duringProfile=function(f)f.root.Visible=false end})
 f:finishLoop();safe(f,"WINDOW_CONTEXT_CHANGED")
end)
test("Stage50 native job change during profile read fails",function()
 local f=fixture({duringProfile=function(f)f.game.JobId="different-job"end})
 f:finishLoop();safe(f,"SESSION_CHANGED")
end)
test("Stage50 native manual offer before profile bound rejected",function()
 local f=fixture({duringProfile=function(f)
  local slot=f.sides.YourOffer:FindFirstChild("Container"):FindFirstChild("NewItem1")
  slot.Visible=true
 end})
 f:finishLoop();safe(f,"OFFER_CHANGED_DURING_PROFILE_READ")
end)
test("Stage50 native P2 local manual add then remove yields two consistent event states",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 completeAdd(f,"LOCAL_SECOND")
 removeBatwing(f)
 f:emit(tradeState(f,"LOCAL_SECOND",false))
 f:finishLoop();safe(f,"TWO_PHASE_CLIENT_PREPROFILE_RAW_KEY_MATCHED")
 local r=f.state.result
 eq(r.stage44TwoPhaseClientSnapshotsMatched,true)
 eq(r.stage44AddState.state,"OWN_ONE_BATWING")
 eq(r.stage44AddState.orientation,"LOCAL_SECOND")
 eq(r.stage44RemoveState.state,"BOTH_EMPTY")
 eq(r.stage44RemoveState.orientation,"LOCAL_SECOND")
 eq(r.stage44AddNearbyCandidates,1);eq(r.stage44RemoveNearbyCandidates,1)
 eq(r.stage44ClientCallbackOrderObserved,true)
 eq(r.stage50ClientRawOfferOwnedMatch,true)
 eq(r.stage50ProfileReadReady,true)
 eq(r.stage50ProfileReadAttempts,1)
 eq(r.stage50Preprofile.profileCandidateClientMatched,true)
 eq(f.calls.profileCalls,1)
 eq(r.eventSessionAssociationProven,false);eq(r.causalAttributionProven,false)
 eq(r.authorizesAccept,false);eq(r.tradeOutcome,"UNKNOWN")
end)
test("Stage50 native delayed manual start beyond 30 seconds still completes within 60 seconds",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 f.now=f.now+35
 f:step()
 completeAdd(f,"LOCAL_SECOND")
 removeBatwing(f);f:emit(tradeState(f,"LOCAL_SECOND",false))
 f:finishLoop();safe(f,"TWO_PHASE_CLIENT_PREPROFILE_RAW_KEY_MATCHED")
 eq(f.state.result.stage44TwoPhaseClientSnapshotsMatched,true)
 eq(f.state.result.elapsedSinceBind>35,true,"receipt after historical 30 second cutoff")
end)
test("Stage50 native P1 local manual add/remove also valid",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 completeAdd(f,"LOCAL_FIRST")
 removeBatwing(f);f:emit(tradeState(f,"LOCAL_FIRST",false))
 f:finishLoop();safe(f,"TWO_PHASE_CLIENT_PREPROFILE_RAW_KEY_MATCHED")
 eq(f.state.result.stage44AddState.localOfferTable,"PLAYER1")
 eq(f.state.result.stage44RemoveState.localOfferTable,"PLAYER1")
end)
test("Stage50 native removal must not leave Batwing in event payload",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 completeAdd(f,"LOCAL_SECOND")
 removeBatwing(f);f:emit(tradeState(f,"LOCAL_SECOND",true))
 f:finishLoop();safe(f,"REMOVE_EVENT_STATE_MISMATCH")
 eq(f.state.result.stage44TwoPhaseClientSnapshotsMatched,false)
 eq(f.state.result.stage44RemoveState,nil)
end)
test("Stage50 native missing removal event is incomplete",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 completeAdd(f,"LOCAL_SECOND")
 removeBatwing(f)
 f:finishLoop();safe(f,"NO_REMOVE_UPDATE")
 eq(f.state.result.stage44TwoPhaseClientSnapshotsMatched,false)
end)
test("Stage50 native duplicate remove receipts fail closed",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 completeAdd(f,"LOCAL_SECOND")
 removeBatwing(f)
 local e=tradeState(f,"LOCAL_SECOND",false)
 f:emit(e);f:emit(e)
 f:finishLoop();safe(f,"MULTIPLE_REMOVE_UPDATES")
 eq(f.state.result.stage44TwoPhaseClientSnapshotsMatched,false)
end)
test("Stage50 native duplicate add receipts fail closed",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 addBatwing(f)
 local e=tradeState(f,"LOCAL_SECOND",true)
 f:emit(e);f:emit(e)
 f:finishLoop();safe(f,"MULTIPLE_ADD_UPDATES")
 eq(f.state.result.stage44AddState,nil)
end)
test("Stage50 native missing add event is not a false empty state",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 addBatwing(f)
 f:finishLoop();safe(f,"NO_ADD_UPDATE")
 eq(f.state.result.stage44TwoPhaseClientSnapshotsMatched,false)
end)
test("Stage50 native invalid initial offer state does not advance to remove",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 addBatwing(f);f:emit(tradeState(f,"LOCAL_SECOND",true,{quantity=2}))
 f:finishLoop();safe(f,"ADD_EVENT_STATE_MISMATCH")
 eq(f.state.result.stage44AddState,nil)
end)
test("Stage50 native partner offer invalidates the add snapshot",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 addBatwing(f);f:emit(tradeState(f,"LOCAL_SECOND",true,{partnerItem=true}))
 f:finishLoop();safe(f,"ADD_EVENT_STATE_MISMATCH")
end)
test("Stage50 native accepted state invalidates remove event",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 completeAdd(f,"LOCAL_SECOND")
 removeBatwing(f);f:emit(tradeState(f,"LOCAL_SECOND",false,{partnerAccepted=true}))
 f:finishLoop();safe(f,"REMOVE_EVENT_STATE_MISMATCH")
end)
test("Stage50 native actor orientation change between add and remove fails closed",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 completeAdd(f,"LOCAL_SECOND")
 removeBatwing(f);f:emit(tradeState(f,"LOCAL_FIRST",false))
 f:finishLoop();safe(f,"PLAYER_ORIENTATION_CHANGED_BETWEEN_UPDATES")
end)
test("Stage50 native manual stop before second step publishes no transition",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 completeAdd(f,"LOCAL_SECOND")
 f.state.stop()
 safe(f,"MANUAL_STOP")
 eq(f.state.result.stage44TwoPhaseClientSnapshotsMatched,false)
end)
test("Stage50 native closed GUI before removal invalidates context",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 completeAdd(f,"LOCAL_SECOND")
 f.root.Visible=false
 f:finishLoop();safe(f,"WINDOW_CONTEXT_CHANGED")
 eq(f.state.result.stage44TwoPhaseClientSnapshotsMatched,false)
end)
test("Stage50 native opposite actor mapping at add fails pair validation",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 addBatwing(f);f:emit(tradeState(f,"LOCAL_SECOND",true,{badPlayer=true}))
 f:finishLoop();safe(f,"ADD_EVENT_STATE_MISMATCH")
end)
print("Stage50 preprofile add/remove native: "..passed.." passed, "..#failures.." failed")
if #failures>0 then error(table.concat(failures,"\n"),0)end
