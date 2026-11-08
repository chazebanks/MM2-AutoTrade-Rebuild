-- Whole Stage45 native launcher exercised against a deterministic fake Roblox game.
-- Python executes this real Lua suite in CI. No trade remotes are fired.
local dir=arg[1] or "pdiddler/new_part4"
local function read(path)
 local f=assert(io.open(path,"rb"),path);local s=f:read("*a");f:close();return s
end
local native=read(dir.."/STAGE45_READONLY_STARTTRADE_TYPES_PROBE.lua")
local core=read(dir.."/p4_stage45_start_trade_payload.lua")
local observer=read(dir.."/p4_native_observer.lua")
local contract=read(dir.."/p4_observer_contract.lua")
local PASS,FAIL=0,{}
local SECRET="SECRET_SERVER_TOKEN_123"
local function eq(a,b,m) assert(a==b,(m or "value")..":"..tostring(a).." != "..tostring(b)) end
local function test(label,fn)
 local ok,err=pcall(fn)
 if ok then PASS=PASS+1;print("PASS Stage45 "..label)
 else FAIL[#FAIL+1]=label..": "..tostring(err);print("FAIL Stage45 "..FAIL[#FAIL]) end
end
local function run(opts)
 opts=opts or {}
 local f={time=0,prints={},warnings={},allConns={},http={},forbidden={},
  fired=false,secondFired=false,guiOpened=false,globals={},encoded=nil}
 local function nope(name)return function()
  f.forbidden[#f.forbidden+1]=name;error("MUTATION_BLOCKED:"..name,0)
 end end
 local function signal(name)
  local s={connections={}}
  function s:Connect(fn)
   if opts.bindFail then error("unavailable listener",0)end
   local c={Connected=true,name=name,fn=fn}
   function c:Disconnect()
    if opts.disconnectFail then error("disconnect failure",0)end
    self.Connected=false
   end
   self.connections[#self.connections+1]=c
   f.allConns[#f.allConns+1]=c
   if opts.callbackInsideConnect and name=="StartTrade" then fn(f.partner)end
   return c
  end
  function s:Fire(...)
   local copy={}
   for _,c in ipairs(self.connections)do copy[#copy+1]=c end
   for _,c in ipairs(copy)do if c.Connected then c.fn(...)end end
  end
  return s
 end
 local N={};N.__index=N
 local function node(kind,name,props)
  local n=setmetatable({ClassName=kind,Name=name,Children={},
   Visible=true,Enabled=true,attrs={}},N)
  for k,v in pairs(props or {})do n[k]=v end
  return n
 end
 function N:Add(c)c.Parent=self;self.Children[#self.Children+1]=c;return c end
 function N:IsA(kind)
  return self.ClassName==kind or (kind=="GuiObject" and
   (self.ClassName=="Frame" or self.ClassName=="TextLabel" or
    self.ClassName=="TextButton" or self.ClassName=="ImageLabel"))
 end
 function N:GetChildren()return self.Children end
 function N:FindFirstChild(name,recursive)
  for _,c in ipairs(self.Children)do if c.Name==name then return c end end
  if recursive then
   for _,c in ipairs(self.Children)do
    local r=c:FindFirstChild(name,true);if r then return r end
   end
  end
 end
 function N:FindFirstChildOfClass(kind)
  for _,c in ipairs(self.Children)do if c:IsA(kind)then return c end end
 end
 function N:GetDescendants()
  local a={}
  local function add(n)
   for _,c in ipairs(n.Children)do a[#a+1]=c;add(c)end
  end
  add(self);return a
 end
 function N:GetAttribute(k)return self.attrs[k]end
 local players=node("Players","Players")
 local me=players:Add(node("Player","LocalUser",{UserId=101}))
 local partner=players:Add(node("Player","SecretPartner",{UserId=202}))
 f.partner=partner
 players.LocalPlayer=me
 function players:GetPlayers()return self.Children end
 function players:GetPlayerByUserId(id)
  for _,p in ipairs(self.Children)do if p.UserId==id then return p end end
 end
 local gui=me:Add(node("PlayerGui","PlayerGui"))
 local screen=gui:Add(node("ScreenGui","TradeGUI",{Enabled=false}))
 local root=screen:Add(node("Frame","Container")):Add(node("Frame","Trade"))
 local sides={}
 for _,name in ipairs({"YourOffer","TheirOffer"})do
  local side=root:Add(node("Frame",name));sides[name]=side
  side:Add(node("Frame","Accepted",{Visible=opts.accepted==name}))
  local slots=side:Add(node("Frame","Container"))
  for i=1,4 do
   local slot=slots:Add(node("Frame","NewItem"..i,{Visible=false}))
   slot:Add(node("Frame","ItemName")):Add(node("TextLabel","Label",{Text="none"}))
   slot:Add(node("Frame","Container")):Add(node("TextLabel","Amount",{Text=""}))
  end
 end
 local label=sides.TheirOffer:Add(node("TextLabel","Username",
   {Text=opts.badLabel and "(UnknownFake)" or "(SecretPartner)"}))
 local rs=node("ReplicatedStorage","ReplicatedStorage")
 local trade=rs:Add(node("Folder","Trade"))
 local remote=trade:Add(node("RemoteEvent",opts.noStartRemote and "OtherTradeRemote" or "StartTrade"))
 remote.OnClientEvent=signal("StartTrade")
 remote.FireServer=nope("StartTrade.FireServer")
 remote.InvokeServer=nope("StartTrade.InvokeServer")
 if opts.doubleRemote then trade:Add(node("RemoteEvent","StartTrade"))end
 local app={PlaceId=142823291,JobId="job-secret"}
 if opts.badPlace then app.PlaceId=1 end
 local http={}
 local allowed={
  p4_stage45_start_trade_payload=core,
  p4_native_observer=observer,
  p4_observer_contract=contract,
 }
 function app:HttpGet(url,cached)
  eq(cached,true,"HTTP expected cached")
  local pin,name=url:match(
    "^https://raw%.githubusercontent%.com/chazebanks/MM2%-AutoTrade%-Rebuild/([^/]+)/pdiddler/new_part4/([^/]+)%.lua$")
  assert(pin and allowed[name],"unreviewed module requested")
  if name=="p4_stage45_start_trade_payload"then
   eq(pin,"3635e6322cdcccc3d5bc9c1ea8a74bcf00a4333c")
  else eq(pin,"35ec2d9a47048910a464a2ef6eb9b9f52ae306b1")end
  f.http[#f.http+1]=url
  return allowed[name]
 end
 local function privateClean(v,seen)
  local ty=type(v)
  if ty=="string" then
   assert(not v:find(SECRET,1,true),"raw secret exposed")
   assert(not v:find("job%-secret"),"job exposed")
   assert(not v:find("SecretPartner"),"partner name exposed")
  elseif ty=="table"then
   seen=seen or {};assert(not seen[v],"cyclic report")
   seen[v]=true
   for k,x in pairs(v)do privateClean(k,seen);privateClean(x,seen)end
   seen[v]=nil
  else assert(ty=="number" or ty=="boolean" or ty=="nil","opaque report")end
 end
 function http:JSONEncode(report)
  privateClean(report);f.encoded=report
  for _,c in ipairs(f.allConns)do
   if not opts.disconnectFail then eq(c.Connected,false,"listener not disconnected")end
  end
  return '{"anonymized":true}'
 end
 function app:GetService(name)
  if name=="Players" then return players end
  if name=="ReplicatedStorage"then return rs end
  if name=="HttpService"then return http end
  return nope("unexpected service "..name)()
 end
 local env=setmetatable({}, {__index=_G})
 env._G=env
 env.game=app
 env.getgenv=function()return f.globals end
 env.loadstring=function(s,name)return load(s,name,"t",env)end
 env.os={clock=function()return f.time end}
 env.print=function(x)f.prints[#f.prints+1]=x end
 env.warn=function(x)f.warnings[#f.warnings+1]=x end
 env.setclipboard=function(s)eq(s,'{"anonymized":true}')end
 local function fire()
  if opts.payload=="partner"then remote.OnClientEvent:Fire(partner)
  elseif opts.payload=="both"then remote.OnClientEvent:Fire(me,partner)
  elseif opts.payload=="scalar"then remote.OnClientEvent:Fire(SECRET,1)
  elseif opts.payload=="table"then remote.OnClientEvent:Fire({private=SECRET})
  elseif opts.payload=="none"then remote.OnClientEvent:Fire()
  elseif opts.payload=="overlimit"then
   remote.OnClientEvent:Fire(1,2,3,4,5,6,7)
  else remote.OnClientEvent:Fire(partner)end
 end
 local function pump(dt)
  f.time=f.time+(dt or .1)
  if opts.changeJob and f.time>=1.45 then app.JobId="new-job" end
  if opts.dropPartner and f.time>=1.5 then partner.Parent=nil end
  if opts.guiAfterArm and not f.guiOpened and f.time>=1 then
   f.guiOpened=true;screen.Enabled=true
  end
  if opts.guiSameStep and not f.guiOpened and f.time>=1.2 then
   f.guiOpened=true;screen.Enabled=true
  end
  if opts.rootClosedDuringGrace and f.time>=2.0 then screen.Enabled=false end
  if opts.offerDuringGrace and f.time>=2.0 then
   sides.YourOffer:FindFirstChild("Container"):FindFirstChild("NewItem1").Visible=true
  end
  if opts.remoteChangedDuringGrace and f.time>=2.0 then remote.Name="FormerStartTrade" end
  if opts.localSwappedDuringGrace and f.time>=2.0 then players.LocalPlayer=partner end
  if opts.ownerConflictDuringGrace and f.time>=2.0 then
   f.globals.PDIDDLER_PART4_CONTROLLER={}
  end
  if opts.manualStopDuringGrace and f.time>=2.0 and
   f.globals.PDIDDLER_STAGE45_STARTTRADE_TYPES then
   f.globals.PDIDDLER_STAGE45_STARTTRADE_TYPES.stop()
  end
  if opts.prearm and not f.fired and f.time>=.25 then
   f.fired=true;fire()
  end
  if opts.earlyGui and not f.guiOpened and f.time>=.3 then
   f.guiOpened=true;screen.Enabled=true
  end
  if not opts.noEvent and not opts.prearm and not f.fired
   and f.time>=1.2 then
   f.fired=true;fire()
  end
  if opts.extraEvent and f.fired and not f.secondFired
   and f.time>=1.31 then
   f.secondFired=true;fire()
  end
  if not opts.noGui and not opts.earlyGui and not f.guiOpened
   and f.time>=(opts.lateGui and 30 or 1.4) then
   f.guiOpened=true;screen.Enabled=true
  end
 end
 env.task={wait=pump,spawn=function(fn)fn()end}
 local fn,err=load(native,"=stage45_native","t",env)
 assert(fn,err)
 local s=fn()
 f.session=s;f.screen=screen;f.remote=remote
 return f
end
local function okReport(f,reason)
 assert(f.session and f.session.finished,"probe must terminate")
 local r=f.encoded or f.session.result
 assert(r,"missing report")
 eq(r.stopReason,reason)
 eq(r.authorizesTrade,false);eq(r.authorizesAccept,false)
 eq(r.mayRecordCompletedTrade,false);eq(r.mayReportProfit,false)
 eq(r.sessionIdProven,false);eq(r.eventSessionAssociationProven,false)
 eq(r.serverCompletionProven,false);eq(r.tradeOutcome,"UNKNOWN")
 eq(#f.forbidden,0,"prohibited outbound game action")
 return r
end
test("one partner argument typed; no session authority",function()
 local f=run({payload="partner"})
 local r=okReport(f,"ONE_START_TRADE_TYPE_CENSUS_MATCHED")
 eq(r.argumentCount,1);eq(r.argumentTypes[1],"PARTNER_PLAYER_REF")
 eq(r.partnerPlayerReferenceCount,1);eq(r.eventBeforeVisibleGui,true)
 eq(r.receiptCount,1);eq(r.cleanupComplete,true)
 eq(r.listenerCount,r.listenersDisconnected)
end)
test("empty StartTrade still reports zero args without asserting absence of token",function()
 local r=okReport(run({payload="none"}),"ONE_START_TRADE_TYPE_CENSUS_MATCHED")
 eq(r.argumentCount,0);eq(r.directPrimitiveCandidateCount,0)
end)
test("both actor references are only client actor evidence",function()
 local r=okReport(run({payload="both"}),"ONE_START_TRADE_TYPE_CENSUS_MATCHED")
 eq(r.playerPairReferencesObserved,true)
 eq(r.hasAuthenticatedSessionIdentifier,false)
end)
test("unknown scalar types do not leak or prove session ID",function()
 local r=okReport(run({payload="scalar"}),"ONE_START_TRADE_TYPE_CENSUS_MATCHED")
 eq(r.argumentCount,2);eq(r.directPrimitiveCandidateCount,2)
 eq(r.argumentTypes[1],"STRING");eq(r.argumentTypes[2],"NUMBER")
end)
test("nested payload table is uninspected and opaque as content",function()
 local r=okReport(run({payload="table"}),"ONE_START_TRADE_TYPE_CENSUS_MATCHED")
 eq(r.argumentTypes[1],"TABLE");eq(r.directPrimitiveCandidateCount,0)
end)
test("second callback is ambiguous",function()
 local f=run({extraEvent=true})
 local r=okReport(f,"MULTIPLE_START_TRADE_RECEIPTS")
 eq(r.receiptCount,2)
end)
test("no StartTrade receipt times out",function()
 local r=okReport(run({noEvent=true,noGui=true}),"NO_START_TRADE_IN_WINDOW")
 eq(r.receiptCount,0)
end)
test("StartTrade without opening GUI fails closed",function()
 okReport(run({noGui=true}),"TRADE_GUI_NOT_STABLE_AFTER_START")
end)
test("late GUI does not count as near event",function()
 okReport(run({lateGui=true}),"TRADE_GUI_NOT_STABLE_AFTER_START")
end)
test("pre-arm callback from queued/stale event fails",function()
 okReport(run({prearm=true,noGui=true}),"UNARMED_START_TRADE_RECEIPT")
end)
test("preexisting GUI cannot be falsely bound",function()
 okReport(run({earlyGui=true,noEvent=true}),"WINDOW_OPEN_BEFORE_ARM")
end)
test("duplicate remote names reject",function()
 okReport(run({doubleRemote=true,noEvent=true}),"START_TRADE_REMOTE_AMBIGUOUS")
end)
test("missing StartTrade remote fails before attaching",function()
 local r=okReport(run({noStartRemote=true,noEvent=true}),"START_TRADE_REMOTE_UNAVAILABLE")
 eq(r.listenerCount,0)
end)
test("event more than six arguments rejects",function()
 okReport(run({payload="overlimit"}),"ARGUMENT_LIMIT_EXCEEDED")
end)
test("wrong partner label fails closed",function()
 okReport(run({badLabel=true}),"TRADE_GUI_NOT_STABLE_AFTER_START")
end)
test("observed acceptance fails closed",function()
 okReport(run({accepted="YourOffer"}),"ACCEPT_INDICATOR_OBSERVED")
end)
test("session job change fails closed",function()
 okReport(run({changeJob=true}),"SESSION_CHANGED")
end)
test("partner departure fails closed",function()
 okReport(run({dropPartner=true}),"TRADE_GUI_NOT_STABLE_AFTER_START")
end)
test("wrong Roblox place cannot execute",function()
 local f=run({badPlace=true,noEvent=true})
 eq(f.session,nil);eq(#f.forbidden,0)
end)
test("listener bind failure does not permit false success",function()
 okReport(run({bindFail=true}),"LISTENER_CLEANUP_INCOMPLETE")
end)
test("unbound visible GUI before StartTrade is rejected",function()
 okReport(run({badLabel=true,guiAfterArm=true}),"GUI_WITHOUT_START_TRADE")
end)
test("same-tick visible GUI prevents false event-before-GUI claim",function()
 local r=okReport(run({guiSameStep=true}),"GUI_VISIBLE_BEFORE_START_TRADE_RECEIPT")
 eq(r.eventBeforeVisibleGui,false)
end)
test("trade GUI disappearance during grace rejects",function()
 okReport(run({rootClosedDuringGrace=true}),"WINDOW_CONTEXT_CHANGED")
end)
test("offer mutation during observation grace rejects",function()
 okReport(run({offerDuringGrace=true}),"WINDOW_CONTEXT_CHANGED")
end)
test("remote identity change during grace rejects",function()
 okReport(run({remoteChangedDuringGrace=true}),"START_TRADE_REMOTE_CHANGED")
end)
test("local player swap during grace rejects",function()
 okReport(run({localSwappedDuringGrace=true}),"SESSION_CHANGED")
end)
test("competing owner during grace rejects",function()
 okReport(run({ownerConflictDuringGrace=true}),"COMPETING_OWNER")
end)
test("manual stop cleans listener without releasing payload",function()
 local r=okReport(run({manualStopDuringGrace=true}),"MANUAL_STOP")
 eq(r.cleanupComplete,true)
end)
test("synchronous callback inside listener attach tears down correctly",function()
 local r=okReport(run({callbackInsideConnect=true}),"UNARMED_START_TRADE_RECEIPT")
 eq(r.listenerCount,r.listenersDisconnected)
 eq(r.cleanupComplete,true)
end)
test("listener disconnection failure reports incomplete",function()
 local f=run({disconnectFail=true,payload="partner"})
 local r=okReport(f,"LISTENER_CLEANUP_INCOMPLETE")
 eq(r.cleanupComplete,false)
end)
for _,reason in ipairs(FAIL)do io.stderr:write(reason.."\n")end
assert(#FAIL==0,tostring(#FAIL).." Stage45 native failures")
print("Stage45 StartTrade whole launcher native: "..PASS.." passed, 0 failed")
