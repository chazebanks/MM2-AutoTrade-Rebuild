-- Actual MAIN+ALT multi-trade read-only native GUI runner under Lune.
-- Original Stage9, Stage100, real Luau core and Roblox GUI mock.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local native=fs.readFile("pdiddler/supervised/MAIN_ALT_OUTBOUND_FIRST_MULTITRADE_NATIVE.lua")
local core=fs.readFile("pdiddler/supervised/main_alt_manual_multitrade_delta_core.lua")
local stage9=fs.readFile("pdiddler/new_part4/p4_native_observer.lua")
local contract=fs.readFile("pdiddler/new_part4/p4_observer_contract.lua")
local geometry=fs.readFile("pdiddler/new_part4/stage100_screen_prompt_overlay.lua")
-- Outbound original P3 has a separate whole-source Lune regression. Here
-- the native GUI test double simulates validated request/pending/handoff,
-- and proves the ACTUAL native wrapper cannot open an ALT trade first.
local scannerCode=[[
local Players=game:GetService("Players")
local api={}
function api.getWhitelist()return {Players:FindFirstChild("FixtureAlt")}end
function api.getRecord(uid)
 local p=Players:GetPlayerByUserId(uid)
 return p and {player=p,state="whitelist"} or nil
end
function api.isWhitelisted(uid)return uid==202 end
function api.hasPendingWork()return false end
function api.setStatus()end
function api.setRequestState()end
return api
]]
local outgoingCode=[[
local M={}
function M.run(scanner,options)
 local E=getgenv()
 local armed,paused,stopped=false,false,false
 local verified=0
 local requests=0
 local S={processed={},verifiedClientDeltaCycles=0}
 local obj={state=S}
 function obj.arm()
  if armed or stopped or options.exactAltMultiTrade~=true or
      options.exactAltUserId~=202 or
      options.noIncomingAutoDecline~=true or
      not options.readyCheck() or
      not scanner.isWhitelisted(202) or
      scanner.isWhitelisted(999) then return false,"SENDER_GUARD_DENIED" end
  armed=true
  requests+=1
  return true,"MAIN_REQUEST_PENDING"
 end
 function obj.isArmed()return armed and not stopped end
 function obj.isPaused()return paused end
 function obj.fatalStatus()return nil end
 function obj.acceptPending()
  if not armed or stopped or paused then return false end
  S.processed[202]="trade-open";paused=true
  return true
 end
 function obj.requeueVerifiedExactAlt()
  if stopped or not paused or S.processed[202]~="trade-open" then return false end
  local count=options.verifiedClientDeltaCount()
  if count~=verified+1 then return false end
  verified=count;S.verifiedClientDeltaCycles=count
  S.processed[202]=nil;paused=false;requests+=1
  return true,"NEXT_MAIN_OUTBOUND_SENT"
 end
 function obj.stop()stopped=true end
 function obj.requestCount()return requests end
 E.__P3_OUTBOUND_MOCK=obj
 return obj
end
return M
]]
local assertions=0
local function eq(a,b,why)
 assertions+=1
 assert(a==b,why..": "..tostring(a).." != "..tostring(b))
end
local function ok(a,why)assertions+=1;assert(a,why)end
local function event()
 local e={listeners={}}
 function e:Connect(fn)
  local h={fn=fn,live=true}
  table.insert(self.listeners,h)
  return {Disconnect=function()h.live=false end}
 end
 function e:Fire()
  for _,h in ipairs(self.listeners)do if h.live then h.fn() end end
 end
 return e
end
local function vec(x,y)return {X=x,Y=y}end
local function gameFixture(opts)
 opts=opts or {}
 local all={}
 local function node(class,name)
  local t={ClassName=class,Name=name or class,Text="",Visible=true,
   Enabled=true,Active=true,Parent=nil,Activated=event(),
   AbsolutePosition=vec(30,120),AbsoluteSize=vec(50,28)}
  table.insert(all,t)
  function t:IsA(other)
   return self.ClassName==other or (other=="GuiObject" and
     (class=="Frame" or class=="TextButton" or class=="TextLabel" or
      class=="ImageButton"))
  end
  function t:FindFirstChild(label,recurse)
   for _,c in ipairs(all)do
    if c.Parent==self and c.Name==label then return c end
   end
   if recurse then
    for _,c in ipairs(all)do
     local x=c.Parent
     while x do
      if x==self and c.Name==label then return c end
      x=x.Parent
     end
    end
   end
   return nil
  end
  function t:FindFirstChildOfClass(class)
   for _,c in ipairs(all)do
    if c.Parent==self and c.ClassName==class then return c end
   end
  end
  function t:GetDescendants()
   local a={}
   for _,c in ipairs(all)do
    local x=c.Parent
    while x do if x==self then table.insert(a,c);break end;x=x.Parent end
   end
   return a
  end
  function t:GetAttribute(key) return nil end
  function t:Destroy()self.Parent=nil;self.Visible=false end
  return t
 end
 local function put(p,c)c.Parent=p;return c end
 local PG=node("PlayerGui","PlayerGui")
 local screen=put(PG,node("ScreenGui","TradeGUI_Phone"))
 screen.Enabled=false
 local container=put(screen,node("Frame","Container"))
 local root=put(container,node("Frame","Trade"))
 root.AbsolutePosition=opts.mobile and vec(120,130) or vec(400,130)
 root.AbsoluteSize=opts.mobile and vec(560,420) or vec(440,420)
 local ours=put(root,node("Frame","YourOffer"))
 local oursContainer=put(ours,node("Frame","Container"))
 local ourAccepted=put(ours,node("Frame","Accepted"));ourAccepted.Visible=false
 local theirs=put(root,node("Frame","TheirOffer"))
 local theirContainer=put(theirs,node("Frame","Container"))
 local theirAccepted=put(theirs,node("Frame","Accepted"));theirAccepted.Visible=false
 local username=put(theirs,node("TextLabel","Username"));username.Text="FixtureAlt"
 local Players={}
 local lp={Name="FixtureMain",UserId=101,Parent=Players}
 local alt={Name="FixtureAlt",UserId=202,Parent=Players}
 Players.LocalPlayer=lp
 function Players:FindFirstChild(name)return name=="FixtureAlt" and alt or nil end
 function Players:GetPlayerByUserId(id)
  if id==202 then return alt elseif id==101 then return lp end
 end
 function lp:FindFirstChildOfClass(k)return k=="PlayerGui" and PG or nil end
 local RS=node("ReplicatedStorage","ReplicatedStorage")
 local remotes=put(RS,node("Folder","Remotes"))
 local inventories=put(remotes,node("Folder","Inventory"))
 local rfn=put(inventories,node("RemoteFunction","GetProfileData"))
 local DB=put(RS,node("Folder","Database"))
 local sync=put(DB,node("ModuleScript","Sync"))
 local meta={Weapons={
  raw_alpha={Name="AlphaFixture",ItemType="Knife",Rarity="Godly",Chroma=false},
  raw_beta={Name="BetaFixture",ItemType="Gun",Rarity="Godly",Chroma=false},
  raw_gamma={Name="GammaFixture",ItemType="Knife",Rarity="Ancient",Chroma=false},
  raw_delta={Name="DeltaFixture",ItemType="Gun",Rarity="Godly",Chroma=false},
 }}
 local weapons={}
 local reads=0
 function rfn:InvokeServer()
  reads+=1
  local x={}
  for k,v in pairs(weapons)do x[k]=v end
  return {ProfileData={Weapons={Owned=x}}}
 end
 local time=2
 local tickEvt=event()
 local services={
  Players=Players,ReplicatedStorage=RS,
  Workspace={CurrentCamera={ViewportSize=opts.mobile and vec(820,1180) or vec(1024,768)}},
  RunService={Heartbeat=tickEvt},
  HttpService={JSONEncode=function(_,o)return serde.encode("json",o)end},
 }
 local sources={}
 local game={
  PlaceId=opts.wrongPlace and 11111 or 142823291,
  JobId="JOB_MULTI_MANUAL_11_14_A",
  GetService=function(_,name)return services[name]end,
  HttpGet=function(_,u)
   table.insert(sources,u)
   if u:find("553b7e44245c5ed36aa3f65aea335953ec1fed5f",1,true)
      and u:find("main_alt_manual_multitrade_delta_core.lua",1,true) then return core end
   if u:find("1c874cdbc5e85418360148fbdf33fa17534cd1ad",1,true)
      and u:find("pdiddler3_exact_alt_outbound_requeue.lua",1,true)then
    return outgoingCode
   end
   if u:find("2036ae5bd937620f21d46600f99550a1b233a654",1,true)
      and u:find("pdiddler3_scanner_MODULE_v6_5_PART4_STATUS_BRIDGE.lua",1,true)then
    return scannerCode
   end
   if u:find("1971b93d324f0275e6a9affb472ac3e804439ed8",1,true)then
    if u:find("p4_native_observer.lua",1,true)then return stage9 end
    if u:find("p4_observer_contract.lua",1,true)then return contract end
   end
   if u:find("5b8ee35d7f281c23d9c2181abd97a063e59a0660",1,true)
       and u:find("stage100_screen_prompt_overlay.lua",1,true) then return geometry end
   error("unverified source")
  end
 }
 local E={PDIDDLER_ACCEPT_DISCOVERY_ALT_NAME="FixtureAlt"}
 if opts.otherController then E.PDIDDLER_PART4_SESSION={} end
 local copied={}
 local env={
  game=game,getgenv=function()return E end,
  Instance={new=function(kind)
   if opts.failUI and kind=="ScreenGui" then error("UI_FAILURE") end
   return node(kind)
  end},
  Color3={fromRGB=function(...)return {...}end},
  Enum={ZIndexBehavior={Sibling="Sibling"},Font={GothamBold="GothamBold"},
   TextXAlignment={Left="Left"}},
  UDim={new=function(...)return {...}end},
  UDim2={fromOffset=function(...)return {...}end},
  task={spawn=function(fn)fn()end},
  os={clock=function()return time end},
  require=function(obj)
   if obj==sync then return meta end
   error("unexpected require")
  end,
  loadstring=function(s) return luau.load(s,{environment=env,injectGlobals=true}) end,
  print=function()end,warn=function()end,
  setclipboard=function(x)table.insert(copied,x)end,
 }
 local function run()
  return luau.load(native,{environment=env,injectGlobals=true})()
 end
 local function button(name)
  for _,x in ipairs(all)do
   if x.Name==name and x.Parent~=nil then return x end
  end
 end
 local function tick(dt)
  time+=dt or 0.1
  tickEvt:Fire()
 end
 local function offer(items)
  for _,x in ipairs(all)do
   if x.Parent==theirContainer then x.Parent=nil end
  end
  for i,info in ipairs(items)do
   local item=put(theirContainer,node("Frame","NewItem"..i))
   local name=put(item,node("Frame","ItemName"))
   local label=put(name,node("TextLabel","Label"))
   label.Text=info.label
   local box=put(item,node("Frame","Container"))
   local amount=put(box,node("TextLabel","Amount"))
   amount.Text=info.qty==1 and "" or "x"..tostring(info.qty)
   local tags=put(item,node("Frame","Tags"))
   if info.chroma then put(tags,node("Frame","Chroma")) end
  end
 end
 local function open()
  local outgoing=E.__P3_OUTBOUND_MOCK
  if not outgoing or not outgoing.acceptPending() then
   error("ALT cannot accept uninitiated trade: MAIN P3 must send first")
  end
  ourAccepted.Visible=false
  theirAccepted.Visible=false
  offer({})
  screen.Enabled=true
 end
 local function close()
  screen.Enabled=false
 end
 local function arm()
  local r=run()
  if not r then return nil end
  local b=button("ArmMultipleManualTrades")
  ok(b,"native has reusable session ARM")
  b.Activated:Fire()
  tick(0.5);tick(0.1)
  return r
 end
 return {run=run,arm=arm,tick=tick,open=open,close=close,offer=offer,
   button=button,ourAccepted=ourAccepted,theirAccepted=theirAccepted,
   getReads=function()return reads end,
   getSources=function()return sources end,
   setInventory=function(o)weapons=o end,
   E=E,game=game,alt=alt,username=username,copied=copied,screen=screen,
   getRequests=function()local o=E.__P3_OUTBOUND_MOCK
    return o and o.requestCount() or 0 end}
end
local function finishRound(f,r,offerRows,post)
 f.open();f.tick(0.1)
 eq(r.status().phase,"WAIT_ALT","requires empty-before item observation")
 f.offer(offerRows);f.tick(0.1)
 eq(r.status().phase,"STABILIZING","independent offer fingerprint")
 f.tick(0.5)
 eq(r.status().phase,"WAIT_MANUAL_ACCEPT","stable after second snapshot")
 f.theirAccepted.Visible=true;f.tick(0.1)
 eq(r.status().phase,"WAIT_CLOSE","ALT manual Accept observed first")
 f.ourAccepted.Visible=true;f.tick(0.1)
 eq(r.status().phase,"WAIT_CLOSE","MAIN manual Accept follows ALT")
 f.close();f.tick(0.1)
 eq(r.status().phase,"VERIFY_DELTA","no server settlement inferred")
 f.tick(0.7);f.tick(0.1)
 eq(r.status().phase,"VERIFY_DELTA","old own profile waits for valid delta")
 f.setInventory(post)
 f.tick(0.7);f.tick(0.1)
 eq(r.status().phase,"VERIFY_DELTA","first client delta not sufficient")
 f.tick(0.7);f.tick(0.1)
 eq(r.status().phase,"READY","second stable client delta permits next trade")
 f.tick(0.5);f.tick(0.1)
 eq(r.status().phase,"WAIT_OPEN","new distinct pre-trade baseline read")
end
do
 local f=gameFixture()
 local r=f.arm()
 ok(type(r)=="table","actual native source loaded")
 eq(#f.getSources(),6,"six immutable source modules fetched including original P3 sender+scanner")
 finishRound(f,r,{{label="AlphaFixture",qty=1}},{raw_alpha=1})
 finishRound(f,r,{{label="BetaFixture",qty=5}},{raw_alpha=1,raw_beta=5})
 finishRound(f,r,{{label="GammaFixture",qty=2},{label="DeltaFixture",qty=3}},
   {raw_alpha=1,raw_beta=5,raw_gamma=2,raw_delta=3})
 local v=r.status()
 eq(f.getRequests(),4,"fourth MAIN outbound REQUEST automatically sent after 3 completed cycles")
 eq(v.corroboratedClientDeltas,3,"three successive separate trades")
 eq(v.tradeCyclesStarted,4,"fourth new baseline opened automatically")
 eq(v.actualScriptAccepts,0,"zero automated final Accept")
 eq(v.authorizesAccept,false,"native test no auto Accept")
 eq(v.serverCompletionProven,false,"corroborated client deltas not server proof")
 eq(v.nextExactAltTradeAllowed,false,"fourth cycle already awaiting manual request")
 local final=r.stop()
 eq(final.status,"STOPPED","operator ends entire session")
 local stop=f.button("StopCopy")
 stop.Activated:Fire()
 ok(#f.copied>=1,"sanitized report copied")
 local raw=f.copied[#f.copied]
 for _,secret in ipairs({"FixtureAlt","FixtureMain","AlphaFixture","BetaFixture",
        "GammaFixture","DeltaFixture","raw_alpha","raw_beta",
        "JOB_MULTI_MANUAL_11_14_A"}) do
  ok(not raw:find(secret,1,true),"no account or item disclosure")
 end
 local j=serde.decode("json",raw)
 eq(j.corroboratedClientDeltas,3,"3 matched deltas preserved in final receipt")
 eq(j.tradeOutcome,"UNKNOWN","server status never inferred")
end
do
 local f=gameFixture({mobile=true})
 local r=f.arm()
 ok(type(r)=="table","iPad-like portrait viewport still permits non-overlapping GUI")
 finishRound(f,r,{{label="AlphaFixture",qty=1}},{raw_alpha=1})
 eq(r.status().corroboratedClientDeltas,1,"portrait iPad repeated-run supports first event")
end
do
 local f=gameFixture()
 local r=f.arm()
 f.open();f.tick()
 f.offer({
  {label="AlphaFixture",qty=1},{label="BetaFixture",qty=1},
  {label="GammaFixture",qty=1},{label="DeltaFixture",qty=1},
  {label="AlphaFixture",qty=1},
 })
 f.tick()
 eq(r.status().status,"STOPPED","fabricated fifth UI slot fails closed")
 eq(r.status().reason,"FABRICATED_EXTRA_ALT_SLOT_NODE","fifth data node not actual MM2 slot")
end
do
 local f=gameFixture()
 local r=f.arm()
 eq(f.getRequests(),1,"first MAIN outgoing request before ALT can open")
 f.open();f.tick()
 f.offer({{label="AlphaFixture",qty=1}});f.tick()
 eq(r.status().phase,"STABILIZING","inbound item in MAIN-initiated trade")
 eq(f.getRequests(),1,"no extra outgoing request mid-trade")
end
do
 local f=gameFixture({otherController=true})
 eq(f.run(),nil,"competing owner forbids test")
 eq(#f.getSources(),0,"no module fetch if controller competing")
end
do
 local f=gameFixture({wrongPlace=true})
 eq(f.run(),nil,"wrong place rejected")
end
do
 local f=gameFixture({failUI=true})
 eq(f.run(),nil,"UI construction failure stops")
end
do
 local f=gameFixture()
 local r=f.arm()
 f.open();f.tick()
 f.offer({{label="AlphaFixture",qty=1}});f.tick()
 f.username.Text="ImposterAlt"
 f.tick(0.5)
 eq(r.status().status,"STOPPED","changing partner label stops global session")
end
do
 local f=gameFixture()
 local r=f.arm()
 f.open();f.tick()
 f.offer({{label="UnlistedName",qty=1}});f.tick()
 eq(r.status().status,"STOPPED","unknown item identity fails closed")
end
do
 local f=gameFixture()
 local r=f.arm()
 f.open();f.tick()
 f.offer({{label="AlphaFixture",qty=1}});f.tick()
 f.ourAccepted.Visible=true
 f.tick(0.5)
 eq(r.status().status,"STOPPED","MAIN final Accept before ALT first is fatal")
end
print("[PASS] MAIN ALT one-session multiple MANUAL trades native integration: "..assertions.." Lune assertions")
