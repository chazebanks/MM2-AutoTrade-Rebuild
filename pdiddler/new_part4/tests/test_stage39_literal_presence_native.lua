-- Actual new launcher, real bounded core and unchanged Stage9 modules, fake game boundary.
local dir=arg[1] or "pdiddler/new_part4"
local function read(path)
 local f=io.open(path,"rb");if not f then return nil end
 local s=f:read("*a");f:close();return s
end
local native=read(dir.."/STAGE39_READONLY_BATWING_KEY_PRESENCE_PROBE.lua")
local core=read(dir.."/p4_trade_update_shape.lua")
local presence=read(dir.."/p4_stage39_literal_key_presence.lua")
local schemaSource=read(dir.."/p4_stage40_trade_schema_hypothesis.lua")
local reader=assert(read(dir.."/p4_native_observer.lua"))
local contract=assert(read(dir.."/p4_observer_contract.lua"))
local BASE="35ec2d9a47048910a464a2ef6eb9b9f52ae306b1"
local KEY="PDIDDLER_STAGE39_BATWING_LITERAL_PRESENCE"
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
   eq(pin,"6507cb29276a1405276f7b950b6883adfa3742be","schema candidate pin")
   return schemaSource
  end
  error("unexpected remote code module "..tostring(name))
 end
 env.loadstring=function(src,name)
  assert(src==core or src==reader or src==contract or src==presence or src==schemaSource,"unreviewed execution")
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


local function addBatwing(f)
 local slot=f.sides.YourOffer:FindFirstChild("Container"):FindFirstChild("NewItem1")
 assert(slot and slot.Visible==false,"must start empty")
 local name=slot:FindFirstChild("ItemName"):FindFirstChild("Label")
 name.Text="Batwing"
 slot.Visible=true
 f:step()
 f:step()
end
test("pre-offer unrelated receipt ignored; subsequent candidate contains exact Batwing catalogue key",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 f:emit({misc=SECRET})
 eq(f.state.finished,false,"first unbound receipt ignored")
 f.now=f.now+3;f:step()
 addBatwing(f)
 f:emit({owner=io.stdout,enabled=true,
   ours={state=true,buffer={{PRIVATE_KEY,OTHER_KEY,1}}},
   theirs={state=false,player=io.stdout,buffer={}}})
 f:finishLoop();safe(f,"ONE_UPDATE_NEAR_SINGLE_OFFER_ADD")
 local r=f.state.result
 eq(r.candidateCatalogueRows,1,"unique Batwing source row")
 eq(r.displayedLabelVerified,true,"real GUI label Batwing and single copy")
 eq(r.mutatedOfferSide,"OURS","correct side")
 eq(r.receiptCount,2,"early + candidate receipts")
 eq(r.nearbyReceiptCandidates,1,"one temporal candidate")
 eq(r.temporalOnly,true,"not causal")
 eq(r.status,"INCOMPLETE","old structure inspector remains incomplete due userdata")
 eq(r.reason,"OPAQUE_VALUE","opaque Roblox-like values not decoded")
 local p=assert(r.literalPresence,"sanitized literal result")
 eq(p.candidateValueMatches,1,"exact same-type raw weapon key present")
 eq(p.otherCatalogueValueMatches,1,"another catalogue key also present")
 eq(p.candidateMapKeyMatches,0,"not a map key")
 eq(p.opaqueLeafCount,2,"opaque left unexamined")
 eq(p.status,"PRIMITIVE_LITERAL_COUNTS_UNBOUND","no identity inference")
 eq(p.ownerSideSlotBound,false,"never authenticate slot")
 eq(r.rawItemKeyConfirmed,false,"never promote evidence")
end)
test("event before local GUI display also compared",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 f:emit({PRIVATE_KEY,2})
 f.now=f.now+.32 -- real simulated event-to-render delay, not same clock tick
 addBatwing(f)
 f:finishLoop();safe(f,"ONE_UPDATE_NEAR_SINGLE_OFFER_ADD")
 eq(f.state.result.candidateSequence,"EVENT_BEFORE_GUI","event early")
 eq(f.state.result.literalPresence.candidateValueMatches,1,"candidate present")
end)
test("no raw key present is an actual negative primitive comparison, not identity denial",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 addBatwing(f)
 f:emit({label="Batwing",thing=OTHER_KEY})
 f:finishLoop();safe(f,"ONE_UPDATE_NEAR_SINGLE_OFFER_ADD")
 local p=f.state.result.literalPresence
 eq(p.candidateValueMatches,0,"actual candidate not found among primitive leaves")
 eq(p.otherCatalogueValueMatches,1,"known different key found")
 eq(p.rawKeyPresentConfirmed,false,"absence still no server claim")
end)
test("Batwing key in map index is counted separately from string values",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 addBatwing(f)
 f:emit({[PRIVATE_KEY]=true})
 f:finishLoop();safe(f,"ONE_UPDATE_NEAR_SINGLE_OFFER_ADD")
 eq(f.state.result.literalPresence.candidateMapKeyMatches,1,"same literal map key")
 eq(f.state.result.literalPresence.candidateValueMatches,0,"not mistaken for value")
end)
test("wrong visible weapon fails closed even if matching raw key appears in payload",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 local slot=f.sides.YourOffer:FindFirstChild("Container"):FindFirstChild("NewItem1")
 slot.Visible=true;slot:FindFirstChild("ItemName"):FindFirstChild("Label").Text="OtherThing"
 f:emit({PRIVATE_KEY})
 f:step();f:step()
 safe(f,"NOT_ONE_OWN_BATWING")
 eq(f.state.result.displayedLabelVerified,false,"no false GUI Batwing proof")
 eq(f.state.result.literalPresence,nil,"no event promoted")
end)
test("opponent-side mutation fails closed for own-side manual probe",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 local slot=f.sides.TheirOffer:FindFirstChild("Container"):FindFirstChild("NewItem1")
 slot.Visible=true;slot:FindFirstChild("ItemName"):FindFirstChild("Label").Text="Batwing"
 f:emit({PRIVATE_KEY})
 f:step();f:step()
 safe(f,"NOT_ONE_OWN_BATWING")
end)
test("duplicate Batwing rows require a unique source key",function()
 local sync={Weapons={
  [PRIVATE_KEY]={ItemName="Batwing"},
  [OTHER_KEY]={Name="Batwing"}}}
 local f=fixture({sync=sync});f:finishLoop()
 safe(f,"BATWING_NAME_AMBIGUOUS")
 eq(f.calls.remoteConnects,0,"no listener without identity uniqueness")
end)
test("Chroma Batwing is not the non-Chroma target",function()
 local sync={Weapons={[PRIVATE_KEY]={ItemName="Batwing",Chroma=true}}}
 local f=fixture({sync=sync});f:finishLoop()
 safe(f,"CHROMA_AMBIGUOUS")
 eq(f.calls.remoteConnects,0,"no stale continuation")
end)
test("module failure stops without incoming listener",function()
 local f=fixture({requireFails=true});f:finishLoop()
 safe(f,"SYNC_UNAVAILABLE")
 eq(f.calls.remoteConnects,0,"no event listener")
end)
test("Sync yielding while offer changes cancels",function()
 local f=fixture({duringSync=function(f)
  f.sides.YourOffer:FindFirstChild("Container"):FindFirstChild("NewItem1").Visible=true
 end});f:finishLoop()
 safe(f,"OFFER_CHANGED_DURING_SYNC_READ")
 eq(f.calls.remoteConnects,0,"no subscribe after changed baseline")
end)
test("no event but actual displayed Batwing has no binding claim",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 addBatwing(f);f:finishLoop()
 safe(f,"NO_UPDATE_NEAR_SINGLE_OFFER_ADD")
 eq(f.state.result.literalPresence,nil,"no fabricated key comparison")
end)
test("two events near add remain ambiguous despite matching one payload",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 addBatwing(f)
 f:emit({PRIVATE_KEY});f:emit({OTHER_KEY})
 f:finishLoop();safe(f,"MULTIPLE_UPDATES_NEAR_SINGLE_OFFER_ADD")
 eq(f.state.result.literalPresence,nil,"no cherry-pick matching event")
 eq(f.state.result.rawItemIdConfirmed,false,"no identity")
end)
test("manual stop/cancellation after queued event preserve cleanup",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 f:emit({PRIVATE_KEY});f.screen:Change("Enabled",false)
 safe(f,"WINDOW_CONTEXT_CHANGED")
 eq(f.state.result.literalPresence,nil,"no unverified comparison")
end)
test("single Script instance and no unauthorized remote actions",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 eq(f.calls.remoteConnects,1,"one passive transport listener")
 f:finishLoop();safe(f,"NO_CORRELATED_UPDATE_IN_WINDOW")
 eq(#f.calls.forbidden,0,"no outbounds")
end)

local function anonTrade(me,partner,id)
 return {Locked=false,LastOffer=1760000123,
  Player1={Player=me,Accepted=false,Offer={{id,1,"Weapons"}}},
  Player2={Player=partner,Accepted=false,Offer={}}}
end
test("anonymous layout agrees with local and partner objects, but remains unauthenticated",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 addBatwing(f);f:emit(anonTrade(f.me,f.partner,PRIVATE_KEY))
 f:finishLoop();safe(f,"ONE_UPDATE_NEAR_SINGLE_OFFER_ADD")
 local h=assert(f.state.result.tradeTableHypothesis)
 eq(h.status,"ANONYMOUS_LAYOUT_HYPOTHESIS_FITS_UNAUTHENTICATED","hypothesis enum")
 eq(h.hypothesisMatched,true,"matched candidate shape")
 eq(h.player1ObjectEqualsLocal,true,"local exact object")
 eq(h.player2ObjectEqualsPartner,true,"partner exact object")
 eq(h.tripletKeyEqualsCatalogue,true,"same raw key")
 eq(h.tripletQuantityIsOne,true,"one copy")
 eq(h.tripletCategoryIsWeapons,true,"expected type")
 eq(h.candidateKeyEqualsVisibleLabel,false,"private fixture key differs")
 eq(h.ownerSideSlotBound,false,"never authenticate actual side/slot")
 eq(f.state.result.rawItemIdConfirmed,false,"no trading authority")
end)
test("reversed owners fail the schema candidate check",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 addBatwing(f);f:emit(anonTrade(f.partner,f.me,PRIVATE_KEY))
 f:finishLoop();safe(f,"ONE_UPDATE_NEAR_SINGLE_OFFER_ADD")
 eq(f.state.result.tradeTableHypothesis.hypothesisMatched,false,"reversed objects")
end)
test("same printed name and raw key adds only name-equivalence warning",function()
 local f=fixture({sync={Weapons={Batwing={ItemName="Batwing"}}}})
 f:untilPhase("LISTENING_UPDATE_TRADE")
 addBatwing(f);f:emit(anonTrade(f.me,f.partner,"Batwing"))
 f:finishLoop();safe(f,"ONE_UPDATE_NEAR_SINGLE_OFFER_ADD")
 local h=f.state.result.tradeTableHypothesis
 eq(h.hypothesisMatched,true,"same shape")
 eq(h.candidateKeyEqualsVisibleLabel,true,"name-only ambiguous")
 eq(h.rawItemIdConfirmed,false,"no key authority")
end)
test("unbound early valid candidate cannot override later unrelated receipt",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 f:emit(anonTrade(f.me,f.partner,PRIVATE_KEY))
 f.now=f.now+3.5;f:step()
 addBatwing(f);f:emit({other=PRIVATE_KEY})
 f:finishLoop();safe(f,"ONE_UPDATE_NEAR_SINGLE_OFFER_ADD")
 eq(f.state.result.tradeTableHypothesis.hypothesisMatched,false,"only near receipt eligible")
end)
test("two near schema candidates remain ambiguous rather than picked by key match",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 addBatwing(f);f:emit(anonTrade(f.me,f.partner,PRIVATE_KEY));f:emit(anonTrade(f.partner,f.me,PRIVATE_KEY))
 f:finishLoop();safe(f,"MULTIPLE_UPDATES_NEAR_SINGLE_OFFER_ADD")
 eq(f.state.result.tradeTableHypothesis,nil,"ambiguous data not exported")
end)
test("invalid count or wrong item type cannot establish candidate layout",function()
 local f=fixture();f:untilPhase("LISTENING_UPDATE_TRADE")
 addBatwing(f)
 local t=anonTrade(f.me,f.partner,PRIVATE_KEY)
 t.Player1.Offer[1][2]=2
 f:emit(t);f:finishLoop();safe(f,"ONE_UPDATE_NEAR_SINGLE_OFFER_ADD")
 eq(f.state.result.tradeTableHypothesis.hypothesisMatched,false,"invalid quantity")
end)
print("Stage39 literal presence native: "..passed.." passed, "..#failures.." failed")
if #failures>0 then error(table.concat(failures,"\\n"),0)end
