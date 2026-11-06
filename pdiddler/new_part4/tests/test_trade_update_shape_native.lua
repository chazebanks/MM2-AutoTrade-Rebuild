-- Actual new launcher, real bounded core and unchanged Stage9 modules, fake game boundary.
local dir=arg[1] or "pdiddler/new_part4"
local function read(path)
 local f=io.open(path,"rb");if not f then return nil end
 local s=f:read("*a");f:close();return s
end
local native=read(dir.."/DIRECT_KEY_READONLY_UPDATE_SHAPE_PROBE.lua")
local core=read(dir.."/p4_trade_update_shape.lua")
local reader=assert(read(dir.."/p4_native_observer.lua"))
local contract=assert(read(dir.."/p4_observer_contract.lua"))
local BASE="35ec2d9a47048910a464a2ef6eb9b9f52ae306b1"
local KEY="PDIDDLER_DIRECT_KEY_UPDATE_SHAPE"
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
 local calls={http={},forbidden={},allConnections={},json=0,inspect=0,prints={},warns={},waits=0,remoteConnects=0}
 local f={calls=calls,now=0,globals={}}
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
   local slot=slots:Add(node("Frame","NewItem1"));slot.attrs.ItemId=SECRET
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
  eq(name,"p4_trade_update_shape","only new shape core")
  assert(pin=="CORE_PIN_REVIEW_COMMIT" or (#pin==40 and pin:match("^%x+$")),"immutable new core pin")
  return core
 end
 env.loadstring=function(src,name)
  assert(src==core or src==reader or src==contract,"unreviewed execution")
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
 env.task={spawn=function(fn)f.thread=coroutine.create(fn)end,wait=function(dt)
  f.now=f.now+(dt or .16);calls.waits=calls.waits+1
  if opts.onWait then opts.onWait(f,calls.waits)end
  coroutine.yield()
 end}
 env.print=function(s)calls.prints[#calls.prints+1]=s end
 env.warn=function(s)calls.warns[#calls.warns+1]=s end
 env.setclipboard=function(s)clean(s);calls.clipboard=s end
 env.require=forbidden("require")
 for _,name in ipairs({"request","http_request","getconnections","hookfunction","hookmetamethod","getrawmetatable","getsenv","getscriptclosure","decompile","fireclickdetector","firesignal","mouse1click"})do env[name]=forbidden(name)end
 f.players=players;f.me=me;f.partner=partner;f.pg=pg;f.screen=screen;f.root=root
 f.sides=sides;f.label=label;f.remote=remote;f.folder=folder;f.node=node;f.game=game;f.env=env
 function f:step()
  if self.thread and coroutine.status(self.thread)~="dead"then
   local ok,why=coroutine.resume(self.thread);assert(ok,why)
  end
 end
 function f:untilPhase(phase)
  for _=1,1000 do
   if self.state and self.state.phase==phase then return end
   if self.state and self.state.finished then error("finished before "..phase..": "..tostring(self.state.result and self.state.result.stopReason))end
   self:step()
  end
  error("poll did not reach "..phase)
 end
 function f:finishLoop()for _=1,1000 do if not self.state or self.state.finished then return end;self:step()end;error("loop did not terminate")end
 function f:emit(...)self.remote.OnClientEvent:Fire(...)end
 f.state=assert(load(native,"=actual-trade-update-shape-native","t",env))()
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
for _,phone in ipairs({false,true})do
 for _,side in ipairs({"YourOffer","TheirOffer"})do
  test("first event shapes with real old reader: "..tostring(phone)..side,function()
   local f=fixture({phone=phone});f:untilPhase("LISTENING_UPDATE_TRADE")
   eq(f.calls.remoteConnects,1,"one incoming listener")
   assert(f.now>=.15,"two frames require minimum interval")
   f.sides[side]:FindFirstChild("Container"):FindFirstChild("NewItem1").attrs.ItemId=SECRET.."changed"
   f:emit({[SECRET]=SECRET,[1]=44},nil,false,7)
   safe(f,"FIRST_UPDATE_OBSERVED")
   eq(f.state.result.status,"PAYLOAD_SHAPE_OBSERVED_UNBOUND","shape remains unbound")
   eq(f.state.result.clientWindowContextStable,true,"client scope")
   eq(f.state.result.offerChangedSinceBinding,true,"private physical signature comparison")
   eq(f.state.result.ourSlots,1,"our physical count")
   eq(f.state.result.theirSlots,1,"their physical count")
   eq(f.state.result.argumentCount,4,"nil argument positions retained")
   eq(f.state.result.argumentTypes[2],"NIL","packed nil type")
   local result=f.state.result;local calls=f.calls.inspect
   f:emit(SECRET);eq(f.state.result,result,"late event ignored");eq(f.calls.inspect,calls,"first event only")
  end)
 end
end
test("no event times out and disconnects",function()
 local f=fixture();f:finishLoop();safe(f,"NO_EVENT_WITHIN_LISTEN_WINDOW")
 eq(f.state.result.status,"INCOMPLETE","no payload")
end)
test("manual stop has one fixed reason and no second report",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 f.state.stop(SECRET);f.state.stop();safe(f,"MANUAL_STOP")
 eq(f.calls.inspect,1,"one incomplete report")
end)
test("no open window times out without event subscription",function()
 local f=fixture({closed=true});f:finishLoop();safe(f,"WINDOW_NOT_OPENED_IN_TIME")
 eq(f.calls.remoteConnects,0,"no early listener")
end)
for _,case in ipairs({
 {"job",function(f)f.game.JobId=SECRET end,"SESSION_CHANGED"},
 {"player",function(f)f.players.LocalPlayer={}end,"SESSION_CHANGED"},
 {"partner label",function(f)f.label:Change("Text","Other")end,"WINDOW_CONTEXT_CHANGED"},
 {"partner leaves",function(f)f.partner:Move(nil)end,"WINDOW_CONTEXT_CHANGED"},
 {"close reopen",function(f)f.screen:Change("Enabled",false);f.screen:Change("Enabled",true)end,"WINDOW_CONTEXT_CHANGED"},
 {"ancestor visibility",function(f)f.root.Parent:Change("Visible",false);f.root.Parent:Change("Visible",true)end,"WINDOW_CONTEXT_CHANGED"},
 {"reused root",function(f)local p=f.root.Parent;f.root:Move(nil);f.root:Move(p)end,"WINDOW_CONTEXT_CHANGED"},
 {"their accept",function(f)f.sides.TheirOffer:FindFirstChild("Accepted").Visible=true end,"ACCEPT_INDICATOR_OBSERVED"},
 {"our accept",function(f)f.sides.YourOffer:FindFirstChild("Accepted").Visible=true end,"ACCEPT_INDICATOR_OBSERVED"},
 {"new owner",function(f)f.globals.PDIDDLER_STAGE36_IMAGE_RELATION={}end,"COMPETING_OWNER"}
})do
 test("invalidation before first callback: "..case[1],function()
  local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE");case[2](f);f:emit(SECRET)
  if not f.state.finished then f:step()end
  safe(f,case[3]);eq(f.state.result.status,"INCOMPLETE","invalid context has no payload")
 end)
end
test("context mutation during bounded core inspection discards shape",function()
 local mutated=false
 local f=fixture({duringInspect=function(f)
  if not mutated then mutated=true;f.screen:Change("Enabled",false)end
 end});f:untilPhase("LISTENING_UPDATE_TRADE");f:emit(SECRET)
 safe(f,"WINDOW_CONTEXT_CHANGED");eq(f.state.result.status,"INCOMPLETE","post-inspect context validation")
end)
for _,opts in ipairs({{missingRemote=true},{duplicateRemote=true},{wrongRemoteType=true}})do
 test("exactly one RemoteEvent required: "..tostring(next(opts)),function()
  local f=fixture(opts);f:finishLoop();safe(f,opts.duplicateRemote and "UPDATE_TRADE_REMOTE_AMBIGUOUS" or "UPDATE_TRADE_REMOTE_UNAVAILABLE")
  eq(f.calls.remoteConnects,0,"no wrong event fallback")
 end)
end
for _,opts in ipairs({{twoRoots=true},{ambiguousPartner=true},{captureError=true}})do
 test("invalid native layout never binds: "..tostring(next(opts)),function()
  local f=fixture(opts);f:finishLoop();safe(f,"WINDOW_NOT_OPENED_IN_TIME")
  eq(f.calls.remoteConnects,0,"no ambiguous binding")
 end)
end
for _,side in ipairs({"YourOffer","TheirOffer"})do
 test("accept indicator prevents initial binding: "..side,function()
  local f=fixture({accepted=side});f:finishLoop();safe(f,"ACCEPT_INDICATOR_OBSERVED")
  eq(f.calls.remoteConnects,0,"no listener after acceptance")
 end)
end
for _,kind in ipairs({"UpdateTrade","property:Text","ancestry","departure"})do
 test("partial connection failure cleanup: "..kind,function()
  local f=fixture({attachFailure=kind});f:finishLoop();safe(f,"LISTENER_BIND_FAILED")
 end)
end
test("synchronous event inside Connect cleans returned connection before JSON",function()
 local f=fixture({duringConnect=function(f,fn)fn(SECRET,nil,{[1]=true})end})
 f:finishLoop();safe(f,"FIRST_UPDATE_OBSERVED")
 eq(f.calls.remoteConnects,1,"exactly one event subscription")
 eq(f.calls.inspect,1,"synchronous first event once")
end)
test("JSON error preserves sanitized result and disconnected listeners",function()
 local f=fixture({jsonFailure=true});f:untilPhase("LISTENING_UPDATE_TRADE");f:emit(SECRET)
 safe(f,"FIRST_UPDATE_OBSERVED");eq(f.calls.clipboard,nil,"no failed JSON clipboard")
end)
test("Disconnect exception attempts all siblings and prevents late callbacks",function()
 local f=fixture({disconnectFailure="UpdateTrade"});f:untilPhase("LISTENING_UPDATE_TRADE");f:emit(SECRET)
 local r=assert(f.state.result);eq(r.cleanupComplete,false,"cleanup failure exported")
 eq(r.status,"INCOMPLETE","failed cleanup cannot report full observation")
 eq(r.stopReason,"LISTENER_CLEANUP_INCOMPLETE","fixed cleanup failure")
 eq(r.listenersAttached,#f.calls.allConnections,"all connections counted")
 eq(r.listenersDisconnected,#f.calls.allConnections-1,"only successful disconnects counted")
 for _,c in ipairs(f.calls.allConnections)do eq(c.disconnects,1,"every disconnect attempted")end
 local inspected=f.calls.inspect;f:emit(SECRET);eq(f.calls.inspect,inspected,"late live callback inert")
 clean(r);for _,s in ipairs(f.calls.warns)do clean(s)end
end)
test("native context exception in callback tears down every listener",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE");f.raiseReadError=true;f:emit(SECRET)
 safe(f,"NATIVE_CONTEXT_UNAVAILABLE")
 eq(f.state.result.status,"INCOMPLETE","context exception has no payload")
end)
test("native context exception in poll tears down every listener",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE");f.raiseReadError=true;f:step()
 safe(f,"NATIVE_CONTEXT_UNAVAILABLE")
end)
test("native context exception immediately after Connect still cleans listeners",function()
 local f=fixture({readErrorAfterBind=true});f:finishLoop();safe(f,"NATIVE_CONTEXT_UNAVAILABLE")
end)
test("Connect throwing after synchronous payload cannot publish success",function()
 local f=fixture({connectThrowsAfterCallback=true,duringConnect=function(_,fn)fn(SECRET)end})
 f:finishLoop()
 eq(f.state.result.status,"INCOMPLETE","attachment failure overrides deferred shape")
 eq(f.state.result.cleanupComplete,false,"unreturned connection cannot be claimed disconnected")
 local count=f.calls.inspect;f:emit(SECRET);eq(f.calls.inspect,count,"unreturned listener is inert")
 for _,c in ipairs(f.calls.allConnections)do if c.kind~="UpdateTrade"then eq(c.Connected,false,"returned siblings disconnected")end end
 clean(f.state.result)
end)
for _,case in ipairs({
 {"renamed",function(f)f.remote.Name="UpdateOffers"end},
 {"removed",function(f)f.folder.Children={}end},
 {"duplicated",function(f)f.folder:Add(f.node("RemoteEvent","UpdateTrade"))end}
})do
 test("bound event remains exact allowlist: "..case[1],function()
  local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE");case[2](f);f:emit(SECRET)
  safe(f,"UPDATE_TRADE_REMOTE_CHANGED");eq(f.state.result.status,"INCOMPLETE","invalid remote has no payload")
 end)
end
test("inspection crossing local deadline is incomplete",function()
 local once=false
 local f=fixture({duringInspect=function(f)if not once then once=true;f.now=f.now+31 end end})
 f:untilPhase("LISTENING_UPDATE_TRADE");f:emit(SECRET)
 safe(f,"NO_EVENT_WITHIN_LISTEN_WINDOW");eq(f.state.result.status,"INCOMPLETE","deadline rechecked")
end)
for _,owner in ipairs({KEY,"PDIDDLER_STAGE36_IMAGE_RELATION","PDIDDLER_STAGE36_ICON_CATALOG_AUDIT",
 "PDIDDLER_STAGE36_EXACT_REFERENCE","PDIDDLER_STAGE35_SLOT_METADATA_CENSUS","PDIDDLER_STAGE34_OFFER_INVENTORY_PROBE",
 "PDIDDLER_STAGE33_TRANSPORT_CENSUS","PDIDDLER_STAGE32_RESULT_CORRELATION_PROBE","PDIDDLER_STAGE29_POSTCLOSE_PROBE",
 "PDIDDLER_STAGE30_PASSIVE_SIGNALS","PDIDDLER_STAGE28_PASSIVE_ACCEPT_PROBE","PDIDDLER_STAGE27_NATIVE_LAB",
 "PDIDDLER_STAGE25_SCANNER_ONLY","PDIDDLER_GINGERSCOPE_REPLACEMENT_PREVIEW","PDIDDLER_OUTGOING_SESSION",
 "PDIDDLER_PART4_SESSION","PDIDDLER_PART4_CONTROLLER","PDIDDLER_PART5_CONTROLLER","PDIDDLER_OUTGOING_CONTROLLER",
 "PDIDDLER_HOPPING_SESSION","PDIDDLER_INTEGRATION_V15_8_VALUE_FIRST","PDIDDLER_INTEGRATION_V15_7_INVENTORY_GROWTH",
 "PDIDDLER_INTEGRATION_V15_6_IMMEDIATE_SAFETY"})do
 test("competing owner blocks boot: "..owner,function()
  local f=fixture({owner=owner});eq(f.state,nil,"no overlapping owner");eq(#f.calls.http,0,"no module fetch");eq(f.calls.remoteConnects,0,"no remote listener")
 end)
end
test("elapsed time is rounded bounded client-clock seconds",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE");f.now=f.now+1.234;f:emit()
 safe(f,"FIRST_UPDATE_OBSERVED")
 local elapsed=f.state.result.elapsedSinceBind
 assert(elapsed>=0 and elapsed<=30 and elapsed*100==math.floor(elapsed*100+.000001),"bounded rounded elapsed")
end)
for _,bad in ipairs({-1,math.huge,0/0})do
 test("invalid client clock aborts without a receipt: "..tostring(bad),function()
  local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE");f.now=bad;f:emit(SECRET)
  safe(f,"CLIENT_CLOCK_INVALID");eq(f.state.result.status,"INCOMPLETE","bad clock cannot bind receipt")
 end)
end
test("clock moving backwards within nonnegative range aborts",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE");f.now=.01;f:emit(SECRET)
 safe(f,"CLIENT_CLOCK_INVALID")
end)
for _,name in ipairs({"p4_trade_update_shape","p4_observer_contract","p4_native_observer"})do
 test("unavailable reviewed module has fixed safe fallback: "..name,function()
  local f=fixture({moduleFailure=name});safe(f,"MODULES_UNAVAILABLE")
  eq(f.state.result.status,"INCOMPLETE","module failure cannot observe payload")
  eq(f.calls.remoteConnects,0,"no unavailable module subscription")
 end)
end
test("exactly one root includes duplicate Trade children",function()
 local f=fixture();f.root.Parent:Add(f.node("Frame","Trade"));f:finishLoop()
 safe(f,"WINDOW_NOT_OPENED_IN_TIME");eq(f.calls.remoteConnects,0,"no duplicated root listener")
end)
test("changed physical frame must stabilize again before attachment",function()
 local f=fixture({onWait=function(f,n)
  if n==1 then f.sides.TheirOffer:FindFirstChild("Container"):FindFirstChild("NewItem1").attrs.ItemId=SECRET.."new"end
 end})
 f:untilPhase("LISTENING_UPDATE_TRADE");assert(f.now>=.3,"changed signature restarted stabilization")
 f:emit(true);safe(f,"FIRST_UPDATE_OBSERVED")
 eq(f.state.result.offerChangedSinceBinding,false,"binding begins at stabilized physical frame")
end)
test("event during opening stability wait is never captured",function()
 local f=fixture({onWait=function(f,n)if n==1 then f:emit(SECRET)end end})
 f:untilPhase("LISTENING_UPDATE_TRADE");eq(f.calls.inspect,0,"no prebinding payload retained")
 f:emit(nil);safe(f,"FIRST_UPDATE_OBSERVED");eq(f.state.result.argumentTypes[1],"NIL","first bound payload only")
end)
test("context callback property exception still tears down listeners",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 f.game.PlaceId=nil
 setmetatable(f.game,{__index=function(_,key)if key=="PlaceId"then error(SECRET,0)end end})
 f.screen:Change("Enabled",false)
 safe(f,"NATIVE_CONTEXT_UNAVAILABLE")
end)
test("elapsed metadata uses the checked client clock sample",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 local samples=0
 f.clockFn=function()samples=samples+1;return f.now+(samples>=3 and 31 or 0)end
 f:emit(SECRET);safe(f,"FIRST_UPDATE_OBSERVED")
 assert(f.state.result.elapsedSinceBind<=30,"extra unchecked clock sample escaped listen bound")
end)
print("Trade update shape native: "..passed.." passed, "..#failures.." failed")
if #failures>0 then error(table.concat(failures,"\n"),0)end
