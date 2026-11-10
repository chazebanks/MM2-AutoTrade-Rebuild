-- Native P3 runner integration tests with actual protected IO, coordinator,
-- exact GUI bridge, updated supervisor, and pure geometry. Scanner, real
-- 1800-line outgoing request fork and watchdog timer are test doubles;
-- the REAL source for those is separately exercised in Lune CI suites.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local runner=fs.readFile("pdiddler/supervised/SUPERVISED_P3_NATIVE_STARTUP.lua")
local ioCode=fs.readFile("pdiddler/supervised/pdiddler4_tradeio_supervised_v2.lua")
local bridgeCode=fs.readFile("pdiddler/supervised/supervised_p3_p4_handoff.lua")
local coordinatorCode=fs.readFile("pdiddler/supervised/supervised_real_p3_rotation_handoff.lua")
local bootCode=fs.readFile("pdiddler/supervised/supervised_p3_startup_supervisor.lua")
local geometryCode=fs.readFile("pdiddler/new_part4/stage100_screen_prompt_overlay.lua")
local tests=0
local function eq(a,b,tag)
 tests+=1
 assert(a==b,tostring(tag)..": "..tostring(a).." != "..tostring(b))
end
local function event()
 local handlers={}
 local x={}
 function x:Connect(cb)handlers[#handlers+1]=cb;return {Disconnect=function()end}end
 function x:Fire()for _,cb in ipairs(handlers) do cb()end end
 return x
end
local function vec(x,y)return{X=x,Y=y}end
local function node(class,name)
 local o={ClassName=class,Name=name or class,Visible=true,Enabled=true,
   Active=false,Text="",children={},attributes={},
   AbsolutePosition=vec(0,0),AbsoluteSize=vec(0,0),Activated=event()}
 function o:IsA(kind)
  return kind==self.ClassName or
    (kind=="GuiObject" and (class=="Frame" or class=="TextLabel"
     or class=="TextButton"))
 end
 function o:FindFirstChild(k)return self.children[k]end
 function o:FindFirstChildOfClass(k)
  for _,v in pairs(self.children) do if v:IsA(k) then return v end end
 end
 function o:WaitForChild(k)return self:FindFirstChild(k)end
 function o:GetAttribute(k)return self.attributes[k]end
 function o:GetDescendants()return{}end
 function o:GetFullName()return self.Name end
 function o:put(n)n.Parent=self;self.children[n.Name]=n;return n end
 function o:Destroy()self.Parent=nil;self.Visible=false end
 return o
end
local scannerCode=[[
local P=game:GetService("Players")
local api={}
function api.getWhitelist()return{}end
function api.hasPendingWork()return false end
function api.getRecord(uid)
 local player=P:GetPlayerByUserId(uid)
 if player then return {player=player,state="whitelist"}end
end
function api.isWhitelisted(uid)return P:GetPlayerByUserId(uid)~=nil end
function api.setStatus()end
function api.setRequestState()end
return api
]]
local outgoingCode=[[
local M={}
function M.run(scanner,opt)
 local E=getgenv()
 E.PDIDDLER_OUTGOING_SESSION=18
 local state={processed={},active=nil}
 local armed=false
 local paused=false
 local stopped=false
 local obj={session=18,state=state,armCalls=0}
 function obj.isArmed()return armed and not stopped end
 function obj.isPaused()return paused end
 function obj.setPaused(v)paused=v end
 function obj.arm()
   obj.armCalls+=1
   if not opt.requiresExplicitStart or not opt.readyCheck() then
    return false,"supervisor-not-ready"
   end
   if armed or stopped then return false,"already-armed" end
   armed=true
   return true,"P3_QUEUE_ARMED_NO_FINAL_ACCEPT"
 end
 function obj.resume()
   if stopped or E.__TRADE_OPEN then return false,"trade-still-open" end
   obj.resumed=(obj.resumed or 0)+1;paused=false
   return true,"resumed"
 end
 function obj.stop()stopped=true;armed=false;obj.stopped=true end
 E.__P3=obj
 return obj
end
return M
]]
local watchdogCode=[[
local M={}
function M.new(supervisor,p3,io,ctx,scheduler)
 local E=getgenv()
 local ready=false
 local active=true
 local obj={}
 function obj.isReady()return ready and active end
 function obj.start()
   ready=true
   local ok=pcall(ctx.onStatus,supervisor.status())
   if not ok then
     active=false;ready=false;supervisor.stop()
     return false,"P3_UI_UNAVAILABLE"
   end
   return true,"TEST_WATCHDOG_READY"
 end
 function obj.stop()active=false;ready=false;supervisor.stop()end
 function obj.tick()
   if not active then return false end
   local status
   if p3.isPaused()==true and io.trade()==nil then
     local ok=supervisor.resumeAfterClose()
     if ok then
       status={status="P3_RESUMED_AFTER_CLIENT_TRADE_CLOSED",
        reason="CLIENT_ONLY"}
     end
   end
   status=status or supervisor.poll()
   ctx.onStatus(status)
   return status
 end
 E.__WATCH=obj
 return obj
end
return M
]]
local function fakeEnv(options)
 options=options or {}
 local pg=node("PlayerGui","PlayerGui")
 local screen=pg:put(node("ScreenGui","TradeGUI"))
 screen.Enabled=options.tradeInitiallyOpen==true
 local layout=screen:put(node("Frame","Container"))
 local trade=layout:put(node("Frame","Trade"))
 trade.AbsolutePosition=vec(options.x or 370,options.y or 150)
 trade.AbsoluteSize=vec(options.w or 440,options.h or 410)
 local ours=trade:put(node("Frame","YourOffer"))
 ours:put(node("Frame","Container"))
 local ownAccepted=ours:put(node("Frame","Accepted"))
 ownAccepted.Visible=false
 local theirs=trade:put(node("Frame","TheirOffer"))
 theirs:put(node("Frame","Container"))
 local otherAccepted=theirs:put(node("Frame","Accepted"))
 otherAccepted.Visible=false
 local uname=theirs:put(node("TextLabel","Username"))
 uname.Text="TrustedAlt"
 local players={}
 local lp={Name="MainAccount",UserId=1,Parent=players}
 local partner={Name="TrustedAlt",DisplayName="Alias",UserId=2,Parent=players}
 players.LocalPlayer=lp
 pg.Parent=lp
 function lp:FindFirstChildOfClass(k)
  if k=="PlayerGui" then return pg end
 end
 function players:GetPlayerByUserId(id)
  if id==2 then return partner end
 end
 function players:FindFirstChild(name)
  if name=="TrustedAlt" then return partner end
 end
 function players:GetPlayers()return{lp,partner}end
 local RS=node("ReplicatedStorage","ReplicatedStorage")
 local folder=RS:put(node("Folder","Trade"))
 local remote=folder:put(node("RemoteEvent","OfferItem"))
 local offers={}
 function remote:FireServer(raw,category)
  offers[#offers+1]={raw,category}
 end
 local world={CurrentCamera={ViewportSize=vec(options.vw or 1024,options.vh or 768)}}
 if options.noCamera then world.CurrentCamera=nil end
 local core=node("CoreGui","CoreGui")
 local service={
  Players=players,ReplicatedStorage=RS,Workspace=world,CoreGui=core,
  GuiService={},VirtualInputManager={},
  HttpService={JSONEncode=function(_,r)return serde.encode("json",r)end}
 }
 local E={PDIDDLER_SUPERVISED_P3_NATIVE={
   enableNativeSupervisor=true,finalAcceptMustRemainManual=true,
 }}
 if options.invalidConfig then
  E.PDIDDLER_SUPERVISED_P3_NATIVE.enableNativeSupervisor=false
 end
 if options.ownerConflict then E.PDIDDLER_PART4_SESSION=99 end
 local sourceReads={}
 local game={
  PlaceId=options.invalidPlace and 123 or 142823291,
  JobId="FAKE_JOB_P3",
  GetService=function(_,k)return service[k]end,
  HttpGet=function(_,url)
   sourceReads[#sourceReads+1]=url
   if url:find("stage100_screen_prompt_overlay.lua",1,true) then
     return geometryCode
   elseif url:find("pdiddler4_tradeio_supervised_v2.lua",1,true) then
     return ioCode
   elseif url:find("supervised_p3_p4_handoff.lua",1,true) then
     return bridgeCode
   elseif url:find("supervised_real_p3_rotation_handoff.lua",1,true) then
     return coordinatorCode
   elseif url:find("pdiddler3_outgoing_START_GATED_v1.lua",1,true) then
     return outgoingCode
   elseif url:find("supervised_p3_startup_supervisor.lua",1,true) then
     return bootCode
   elseif url:find("supervised_p3_continuous_watchdog.lua",1,true) then
     return watchdogCode
   elseif url:find("pdiddler3_scanner_MODULE_v6_5_PART4_STATUS_BRIDGE.lua",1,true) then
     return scannerCode
   end
   error("unexpected network source")
  end
 }
 local instances={}
 local instance={new=function(kind)
   if options.failUI and kind=="ScreenGui" then error("no UI") end
   local n=node(kind)
   instances[#instances+1]=n
   return n
 end}
 local enums={ZIndexBehavior={Sibling="Sibling"},
  TextXAlignment={Left="Left"},Font={GothamBold="GothamBold"}}
 local copied={}
 local env={game=game,getgenv=function()return E end,
  Instance=instance,Enum=enums,
  UDim={new=function(...)return{...}end},
  UDim2={fromOffset=function(...)return{...}end},
  Color3={fromRGB=function(...)return{...}end},
  setclipboard=function(s)copied[#copied+1]=s end,
  print=function()end,warn=function()end,
  task={spawn=function()end,wait=function()end},
 }
 env.loadstring=function(source)
  return luau.load(source,{environment=env,injectGlobals=true})
 end
 local function run()
  return luau.load(runner,{environment=env,injectGlobals=true})()
 end
 local function armButton()
  for _,o in ipairs(instances) do
   if o.Name=="ArmP3" then return o end
  end
 end
 local function stopButton()
  for _,o in ipairs(instances) do
   if o.Name=="StopP3" then return o end
  end
 end
 return {run=run,E=E,PG=pg,screen=screen,trade=trade,
  readSources=sourceReads,offers=offers,armButton=armButton,
  stopButton=stopButton,copied=copied,world=world}
end
do
 local x=fakeEnv()
 local runtime=x.run()
 eq(type(runtime),"table","native runner returned controls")
 eq(#x.readSources,8,"all eight exact pinned module sources fetched")
 eq(x.E.__P3.armCalls,0,"real P3 request queue closed at startup")
 eq(x.E.__P3.isArmed(),false,"default deny no requests")
 local arm=x.armButton()
 eq(type(arm),"table","arm appears inside game")
 eq(arm.Visible,true,"arm appears after watchdog readiness")
 eq(arm.Active,true,"user can tap explicit arm")
 arm.Activated:Fire()
 eq(x.E.__P3.armCalls,1,"exactly one original guarded arm call")
 eq(x.E.__P3.isArmed(),true,"real P3 armed after in-game tap")
 eq(runtime.isArmed(),true,"public status reflects operator arm")
 eq(x.E.PDIDDLER_SUPERVISED_P3_USED_JOB,"FAKE_JOB_P3","no repeat in same job")
 arm.Activated:Fire()
 eq(x.E.__P3.armCalls,1,"second tap does not double-arm")
 x.screen.Enabled=true
 x.E.__P3.state.processed[2]="trade-open"
 x.E.__P3.setPaused(true)
 local observed=x.E.__WATCH.tick()
 eq(observed.status,"P4_TWO_SIDED_CLIENT_SNAPSHOT","actual coordinator bind on original GUI")
 eq(observed.authorizesAccept,false,"no final Accept")
 eq(#x.offers,0,"no item remotes at all")
 x.screen.Enabled=false
 local closed=x.E.__WATCH.tick()
 eq(closed.status,"P3_RESUMED_AFTER_CLIENT_TRADE_CLOSED","closed GUI resumes original outgoing")
 eq(x.E.__P3.resumed,1,"one original P3 resume")
 x.stopButton().Activated:Fire()
 eq(x.E.__P3.stopped,true,"STOP button revokes outgoing queue")
 eq(#x.copied,1,"STOP exports anonymous result")
 eq(x.E.PDIDDLER_SUPERVISED_P3_NATIVE_OWNER,nil,"owner released")
 eq(#x.offers,0,"never issued OfferItem")
 eq(x.run(),nil,"cannot run again in same JobId")
end
for _,opts in ipairs({
 {invalidPlace=true},{invalidConfig=true},{ownerConflict=true},
 {noCamera=true},{failUI=true},
}) do
 local x=fakeEnv(opts)
 x.run()
 eq(x.E.__P3==nil,true,"invalid startup never instantiates request fork")
 eq(#x.offers,0,"zero item offers in invalid startup")
end
for _,opts in ipairs({
 {vw=260,vh=260},{tradeInitiallyOpen=true,
  x=0,y=0,w=1024,h=768},
}) do
 local x=fakeEnv(opts)
 x.run()
 eq(x.E.__P3==nil or x.E.__P3.isArmed()==false,true,
   "unsafe viewport/trade cannot arm original P3")
 eq(#x.offers,0,"zero item offers in unsafe viewport")
end
print("[PASS] original MM2 native P3 explicit ARM GUI + real P4 coordinator:",tests)
print("[PASS] eight pinned loads, no request before tap, close/resume, STOP clipboard, never final Accept")
