-- Actual new launcher, real bounded core and unchanged Stage9 modules, fake game boundary.
local dir=arg[1] or "pdiddler/new_part4"
local function read(path)
 local f=io.open(path,"rb");if not f then return nil end
 local s=f:read("*a");f:close();return s
end
local native=read(dir.."/DIRECT_KEY_READONLY_OFFER_EVENT_CORRELATION_PROBE.lua")
local core=read(dir.."/p4_trade_update_shape.lua")
local reader=assert(read(dir.."/p4_native_observer.lua"))
local contract=assert(read(dir.."/p4_observer_contract.lua"))
local BASE="35ec2d9a47048910a464a2ef6eb9b9f52ae306b1"
local KEY="PDIDDLER_DIRECT_KEY_OFFER_CORRELATION"
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

local function addOne(f,side)
 local slot=f.sides[side]:FindFirstChild("Container"):FindFirstChild("NewItem1")
 assert(slot and slot.Visible==false,"fixture must start with empty slots")
 slot.Visible=true
 f:step() -- first changed GUI frame
 f:step() -- the same changed offer frame stabilizes, no remote must fire
end

test("ignored first unbound event; later manual add has one nearby UpdateTrade",function()
 local f=fixture()
 f:untilPhase("LISTENING_UPDATE_TRADE")
 eq(f.state.finished,false,"script must be listening")
 f:emit({[SECRET]=SECRET}) -- empty/no displayed offer change
 eq(f.state.finished,false,"first unbound event cannot close")
 f.now=f.now+3.0
 f:step()
 addOne(f,"TheirOffer")
 f:emit({17,nil,true})
 f:finishLoop()
 safe(f,"ONE_UPDATE_NEAR_SINGLE_OFFER_ADD")
 local r=f.state.result
 eq(r.receiptCount,2,"both events counted")
 eq(r.nearbyReceiptCandidates,1,"only event near actual addition retained")
 eq(r.temporalOfferEventCandidate,true,"explicit proximity-only finding")
 eq(r.temporalOnly,true,"no causal claim")
 eq(r.mutatedOfferSide,"THEIRS","correct local GUI side")
 eq(r.theirSlots,1,"manual offer slot observed")
 eq(r.ourSlots,0,"other side unchanged")
 eq(r.argumentCount,1,"selected later event has one argument table")
 assert(r.candidateSequence=="GUI_BEFORE_EVENT" or r.candidateSequence=="EVENT_BEFORE_GUI","fixed bounded order category")
end)
test("event-before-GUI is preserved through a rendering delay",function()
 local f=fixture({phone=true})
 f:untilPhase("LISTENING_UPDATE_TRADE")
 f:emit({[1]=SECRET,[2]=2})
 eq(f.state.finished,false,"do not finish from an unbound event")
 f.now=f.now+.06 -- distinct client-clock sample, still within association window
 addOne(f,"YourOffer")
 f:finishLoop();safe(f,"ONE_UPDATE_NEAR_SINGLE_OFFER_ADD")
 local r=f.state.result
 eq(r.candidateSequence,"EVENT_BEFORE_GUI","arrival preceded first changed frame")
 eq(r.ourSlots,1,"own-side addition")
 eq(r.theirSlots,0,"opponent unchanged")
 eq(r.receiptCount,1,"one candidate")
end)
test("GUI-before-event is counted but remains unbound",function()
 local f=fixture()
 f:untilPhase("LISTENING_UPDATE_TRADE")
 addOne(f,"TheirOffer")
 f:emit({SECRET,44})
 f:finishLoop();safe(f,"ONE_UPDATE_NEAR_SINGLE_OFFER_ADD")
 eq(f.state.result.candidateSequence,"GUI_BEFORE_EVENT","GUI first")
 eq(f.state.result.argumentCount,1,"one table argument")
 eq(f.state.result.rawItemIdConfirmed,false,"never promote")
end)
test("two nearby events are ambiguous, never arbitrarily choose the last",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 addOne(f,"TheirOffer")
 f:emit({[1]=SECRET})
 f:emit({[1]="unrelated"})
 f:finishLoop();safe(f,"MULTIPLE_UPDATES_NEAR_SINGLE_OFFER_ADD")
 local r=f.state.result
 eq(r.status,"INCOMPLETE","do not choose one candidate")
 eq(r.nearbyReceiptCandidates,2,"ambiguity count")
 eq(r.temporalOfferEventCandidate,false,"no unique temporal receipt")
 eq(r.rawItemIdConfirmed,false,"no ID authentication")
end)
test("first event without GUI change never establishes a weapon",function()
 local f=fixture()
 f:untilPhase("LISTENING_UPDATE_TRADE")
 f:emit({[1]=SECRET})
 eq(f.state.finished,false,"listener remains active")
 f:finishLoop();safe(f,"NO_CORRELATED_UPDATE_IN_WINDOW")
 eq(f.state.result.status,"INCOMPLETE","no physical addition")
 eq(f.state.result.temporalOfferEventCandidate,false,"no candidate")
 eq(f.state.result.receiptCount,1,"receipt acknowledged")
 eq(f.state.result.ourSlots,0,"nothing offered")
 eq(f.state.result.theirSlots,0,"nothing offered")
end)
test("manual add with no event never asserts key/slot binding",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 addOne(f,"YourOffer")
 f:finishLoop();safe(f,"NO_UPDATE_NEAR_SINGLE_OFFER_ADD")
 eq(f.state.result.temporalOfferEventCandidate,false,"no event")
 eq(f.state.result.status,"INCOMPLETE","no shape")
end)
test("event much earlier than added slot is not considered associated",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 f:emit({[1]=SECRET})
 f.now=f.now+3
 f:step()
 addOne(f,"TheirOffer")
 f:finishLoop();safe(f,"NO_UPDATE_NEAR_SINGLE_OFFER_ADD")
 eq(f.state.result.nearbyReceiptCandidates,0,"far receipt excluded")
end)
test("script rejects already populated offers at bind",function()
 local f=fixture({initialPopulated=true})
 f:finishLoop();safe(f,"OFFERS_NOT_EMPTY_AT_BIND")
 eq(f.state.result.temporalOfferEventCandidate,false,"cannot attribute prior items")
end)
test("new owner during pending correlation cancels and disconnects",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 f:emit({[1]=SECRET})
 f.globals.PDIDDLER_STAGE36_IMAGE_RELATION={}
 f:step();safe(f,"COMPETING_OWNER")
 eq(f.state.result.temporalOfferEventCandidate,false,"invalidated")
end)
test("Accept indicator rejects correlation",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 f:emit({[1]=SECRET})
 f.sides.TheirOffer:FindFirstChild("Accepted").Visible=true
 f:step();safe(f,"ACCEPT_INDICATOR_OBSERVED")
end)
test("closed trade cancels observation and cleans every listener",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 f:emit({[1]=SECRET})
 f.screen:Change("Enabled",false)
 safe(f,"WINDOW_CONTEXT_CHANGED")
end)
test("manual stop is always no authority",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 f.state.stop();safe(f,"MANUAL_STOP")
 eq(f.state.result.temporalOfferEventCandidate,false,"no candidate")
end)
test("no window means no listener",function()
 local f=fixture({closed=true});f:finishLoop()
 safe(f,"WINDOW_NOT_OPENED_IN_TIME")
 eq(f.calls.remoteConnects,0,"no early subscription")
end)
test("unexpected module failure stops without any listener",function()
 local f=fixture({moduleFailure="p4_trade_update_shape"})
 safe(f,"MODULES_UNAVAILABLE")
 eq(f.calls.remoteConnects,0,"no listener")
end)
test("no arbitrary callbacks or outgoing RPCs",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 eq(f.calls.remoteConnects,1,"one allowlisted update subscription")
 f:finishLoop()
 safe(f,"NO_CORRELATED_UPDATE_IN_WINDOW")
 eq(#f.calls.forbidden,0,"no actions or forbidden APIs")
end)
print("Offer event correlation native: "..passed.." passed, "..#failures.." failed")
if #failures>0 then error(table.concat(failures,"\\n"),0)end
