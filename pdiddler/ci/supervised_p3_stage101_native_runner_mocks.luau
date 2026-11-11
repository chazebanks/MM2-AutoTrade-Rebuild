-- Native P3 runner integration tests with actual protected IO, coordinator,
-- exact GUI bridge, updated supervisor, and pure geometry. Scanner, real
-- 1800-line outgoing request fork and watchdog timer are test doubles;
-- the REAL source for those is separately exercised in Lune CI suites.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local runner=fs.readFile("pdiddler/supervised/SUPERVISED_P3_STAGE101_IDENTITY_NATIVE.lua")
local ioCode=fs.readFile("pdiddler/supervised/pdiddler4_tradeio_supervised_v2.lua")
local bridgeCode=fs.readFile("pdiddler/supervised/supervised_p3_p4_handoff.lua")
local coordinatorCode=fs.readFile("pdiddler/supervised/supervised_real_p3_rotation_handoff.lua")
local bootCode=fs.readFile("pdiddler/supervised/supervised_p3_startup_supervisor.lua")
local geometryCode=fs.readFile("pdiddler/new_part4/stage100_screen_prompt_overlay.lua")
local identityCode=fs.readFile("pdiddler/supervised/supervised_p3_p4_stage101_identity_witness.lua")
local contractCode=fs.readFile("/tmp/gingerscope-stage220/stage9.lua")
local nativeStage9Code=fs.readFile("/tmp/gingerscope-stage220/native_stage9.lua")
local registryCode=fs.readFile("/tmp/gingerscope-stage220/stage83.lua")
local stage101Code=fs.readFile("/tmp/gingerscope-stage220/stage101.lua")
local tests=0
local function eq(a,b,tag)
 tests+=1
 assert(a==b,tostring(tag)..": "..tostring(a).." != "..tostring(b))
end
local function event()
 local handlers={}
 local x={}
 function x:Connect(cb)
  local h={cb=cb,live=true}
  handlers[#handlers+1]=h
  return {Disconnect=function()h.live=false end}
 end
 function x:Fire(...)
  for _,h in ipairs(handlers) do
   if h.live then h.cb(...)end
  end
 end
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
function api.getWhitelist()
 local result={}
 for _,p in ipairs(P:GetPlayers()) do
  if p~=P.LocalPlayer then result[#result+1]=p end
 end
 return result
end
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
 E.__SCANNER_P3_SEES=scanner
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
 local outsider={Name="OtherPerson",DisplayName="Stranger",UserId=99,Parent=players}
 players.LocalPlayer=lp
 pg.Parent=lp
 function lp:FindFirstChildOfClass(k)
  if k=="PlayerGui" then return pg end
 end
 function players:GetPlayerByUserId(id)
  if id==2 then return partner end
  if id==99 then return outsider end
 end
 function players:FindFirstChild(name)
  if name=="TrustedAlt" then return partner end
 end
 function players:GetPlayers()return{lp,partner,outsider}end
 local RS=node("ReplicatedStorage","ReplicatedStorage")
 local folder=RS:put(node("Folder","Trade"))
 local remote=folder:put(node("RemoteEvent","OfferItem"))
 local update=folder:put(node("RemoteEvent","UpdateTrade"))
 update.OnClientEvent=event()
 function folder:GetDescendants()return{remote,update}end
 local db=RS:put(node("Folder","Database"))
 local sync=db:put(node("ModuleScript","Sync"))
 local catalog=luau.load(registryCode)().entries
 local syncWeapons={}
 for _,id in ipairs({"Scythe","ImmortalChroma","Gingerscope"})do
  local row=catalog[id]
  syncWeapons[id]={ItemName=row[1],ItemType=row[2],
   Rarity=row[3],Chroma=row[4]}
 end
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
 local clock=100
 local E={PDIDDLER_P3_STAGE101_IDENTITY_NATIVE={
   enableNativeSupervisor=true,finalAcceptMustRemainManual=true,
   altOnlyTest=true,targetName="TrustedAlt",
   stage101IdentityReadOnly=true,
 }}
 if options.invalidConfig then
  E.PDIDDLER_P3_STAGE101_IDENTITY_NATIVE.enableNativeSupervisor=false
 end
 if options.noAltTest then
  E.PDIDDLER_P3_STAGE101_IDENTITY_NATIVE.altOnlyTest=false
 end
 if options.badTarget then
  E.PDIDDLER_P3_STAGE101_IDENTITY_NATIVE.targetName="MissingAlt"
 end
 if options.ownerConflict then E.PDIDDLER_PART4_SESSION=99 end
 if options.pilotConflict then
   E.PDIDDLER_SUPERVISED_FOUR_SLOT_GUIDE_JOB="FAKE_JOB_P3"
 end
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
   elseif url:find("p4_observer_contract.lua",1,true) then
     return contractCode
   elseif url:find("p4_native_observer.lua",1,true) then
     return nativeStage9Code
   elseif url:find("stage83_public_slug_registry.lua",1,true) then
     return registryCode
   elseif url:find("stage101_multiweapon_raw_key_match.lua",1,true) then
     return stage101Code
   elseif url:find("supervised_p3_p4_stage101_identity_witness.lua",1,true) then
     return identityCode
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
  os={clock=function()return clock end},
  require=function(mod)
   if mod==sync then return {Weapons=syncWeapons}end
   error("unexpected require of non-Sync module")
  end,
  math=math,
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
 local function named(n)
  for _,o in ipairs(instances) do
   if o.Name==n then return o end
  end
 end
 local function addWeapon(side,itemName,amountText,chroma)
  local targetSide=side=="MAIN" and ours or theirs
  local container=targetSide:FindFirstChild("Container")
  local nextSlot=#(container.__slots or {})+1
  container.__slots=container.__slots or {}
  local slot=container:put(node("Frame","NewItem"..tostring(nextSlot)))
  container.__slots[nextSlot]=slot
  local labelBox=slot:put(node("Frame","ItemName"))
  local label=labelBox:put(node("TextLabel","Label"))
  label.Text=itemName
  local inside=slot:put(node("Frame","Container"))
  local amt=inside:put(node("TextLabel","Amount"))
  amt.Text=amountText or ""
  if chroma then
   local tags=slot:put(node("Frame","Tags"))
   tags:put(node("Frame","Chroma"))
  end
  return slot
 end
 local function currentEvent()
  return {
   LastOffer=12,Locked=false,
   Player1={Player=lp,Accepted=false,Offer={{"Scythe",1,"Weapons"}}},
   Player2={Player=partner,Accepted=false,
     Offer={{"ImmortalChroma",2,"Weapons"}}}
  }
 end
 return {run=run,E=E,PG=pg,screen=screen,trade=trade,
  readSources=sourceReads,offers=offers,armButton=armButton,
  stopButton=stopButton,copied=copied,world=world,
  setTime=function(t)clock=t end,now=function()return clock end,
  update=update,addWeapon=addWeapon,currentEvent=currentEvent,
  partner=partner,our=ours,their=theirs,remote=remote,
  named=named}
end
local function start(x)
 local runtime=x.run()
 eq(type(runtime),"table","native Stage101 adapter prepared")
 eq(#x.readSources,13,"frozen original P3, Stage9, 83, 101, 219 modules loaded")
 eq(#x.offers,0,"no offers sent on load")
 eq(x.E.__P3.armCalls,0,"original P3 request queue closed")
 eq(x.E.__SCANNER_P3_SEES.getWhitelist()[1].Name,"TrustedAlt",
  "only one exact consenting ALT in original request queue")
 eq(x.E.__SCANNER_P3_SEES.isWhitelisted(99),false,
  "unknown other user never contacted")
 x.armButton().Activated:Fire()
 eq(x.E.__P3.armCalls,1,"only human ARM requests ALT")
 eq(#x.offers,0,"P3 ARM does not offer weapon")
 x.E.__P3.state.processed[2]="trade-open"
 x.E.__P3.setPaused(true)
 x.screen.Enabled=true
 eq(x.E.__WATCH.tick().status,"P4_TWO_SIDED_CLIENT_SNAPSHOT",
  "actual coordinator original P4 GUI")
 return runtime
end
do
 local x=fakeEnv()
 start(x)
 x.addWeapon("ALT","Immortal","x2",true)
 eq(x.E.__WATCH.tick().status,"P4_TWO_SIDED_CLIENT_SNAPSHOT",
  "actual ALT 1 slot seen by original protected P4")
 x.setTime(100.2)
 x.E.__WATCH.tick()
 eq(x.E.PDIDDLER_STAGE101_IDENTITY_RUNNER.status().identityReason,
  "MAIN_MANUALLY_ADD_ONE_NOW","Stage101 witness ready after exact ALT baseline")
 x.setTime(100.25)
 x.update.OnClientEvent:Fire(x.currentEvent())
 eq(x.E.PDIDDLER_STAGE101_IDENTITY_RUNNER.status().callbackCount,1,
  "single raw UpdateTrade packet observed by read-only adapter")
 eq(#x.offers,0,"callback listener only observes not offers")
 x.addWeapon("MAIN","Batwing","",false)
 x.setTime(100.3)
 x.E.__WATCH.tick()
 x.setTime(100.5)
 x.E.__WATCH.tick()
 local receipt=x.E.PDIDDLER_STAGE101_IDENTITY_RUNNER.status()
 eq(receipt.identityStatus,"CLIENT_BOTH_SIDES_RAW_KEY_CANDIDATES_UNATTRIBUTED",
  "frozen original Stage101 actual both-side raw keys corroborated by original Stage9/IO")
 eq(receipt.clientBothSidesCandidateConsistent,true,"both sides corroborated client-only")
 eq(receipt.clientGuiCrossChecked,true,"actual original Stage9 and protected P4 readers agree")
 eq(receipt.matchedOwnSlots,1,"MAIN raw candidate matched one slot")
 eq(receipt.matchedTheirSlots,1,"ALT raw candidate matched one Chroma x2 slot")
 eq(receipt.callbackCount,1,"exactly one callback")
 eq(receipt.authorizesAccept,false,"no final automatic Accept")
 eq(receipt.rawItemIdConfirmed,false,"client correlation not raw server identity")
 eq(receipt.serverCompletionProven,false,"no completed trade")
 eq(receipt.tradeOutcome,"UNKNOWN","no completed trade outcome")
 eq(#x.offers,0,"never physical OfferItem")
 eq(x.E.__P3.stopped,true,"stop original P3 after one identity result")
 x.stopButton().Activated:Fire()
 local actual=serde.decode("json",x.copied[#x.copied])
 eq(actual.identityStatus,"CLIENT_BOTH_SIDES_RAW_KEY_CANDIDATES_UNATTRIBUTED",
  "STOP COPY preserves Stage101 observed PASS")
 eq(actual.actualOffers,0,"zero item offers")
 eq(actual.actualAccepts,0,"zero Accept")
 eq(actual.actualDeclines,0,"zero scripted Decline")
 eq(x.copied[#x.copied]:find("Scythe",1,true),nil,
  "report doesn't leak raw weapon ID")
 eq(x.copied[#x.copied]:find("Immortal",1,true),nil,
  "report doesn't leak Chroma item name")
 eq(x.copied[#x.copied]:find("TrustedAlt",1,true),nil,
  "report doesn't leak username")
 eq(x.run(),nil,"one-shot exact server job consumed")
end
do
 local x=fakeEnv()
 start(x)
 x.addWeapon("ALT","Immortal","x2",true)
 x.E.__WATCH.tick()
 x.setTime(100.2)
 x.E.__WATCH.tick()
 x.update.OnClientEvent:Fire(x.currentEvent())
 x.update.OnClientEvent:Fire(x.currentEvent())
 local r=x.E.PDIDDLER_STAGE101_IDENTITY_RUNNER.status()
 eq(r.identityStatus,"INCONCLUSIVE","duplicate callback closes identity witness")
 eq(#x.offers,0,"no item offers from duplicate callbacks")
end
do
 local x=fakeEnv()
 start(x)
 x.addWeapon("MAIN","Batwing","",false)
 x.addWeapon("ALT","Immortal","x2",true)
 x.E.__WATCH.tick()
 eq(x.E.PDIDDLER_STAGE101_IDENTITY_RUNNER.status().identityStatus,
  "INCONCLUSIVE","MAIN offering before ALT baseline fails closed")
end
do
 local x=fakeEnv()
 start(x)
 x.addWeapon("ALT","Immortal","x2",true)
 x.E.__WATCH.tick()
 x.setTime(100.2)
 x.E.__WATCH.tick()
 x.partner.Parent=nil
 x.setTime(100.25)
 x.E.__WATCH.tick()
 eq(x.E.PDIDDLER_STAGE101_IDENTITY_RUNNER.status().identityStatus,
  "INCONCLUSIVE","lost ALT cannot be considered authentic identity")
end
do
 local x=fakeEnv()
 start(x)
 x.addWeapon("ALT","Immortal","x2",true)
 x.E.__WATCH.tick()
 x.setTime(100.2)
 x.E.__WATCH.tick()
 x.screen.Enabled=false
 x.setTime(100.3)
 x.E.__WATCH.tick()
 eq(x.E.PDIDDLER_STAGE101_IDENTITY_RUNNER.status().identityStatus,
  "INCONCLUSIVE","trade closure before raw callback voids this window")
end
do
 local x=fakeEnv()
 start(x)
 x.addWeapon("ALT","Immortal","x2",true)
 x.E.__WATCH.tick()
 x.setTime(100.2);x.E.__WATCH.tick()
 x.update.OnClientEvent:Fire(x.currentEvent())
 x.addWeapon("MAIN","Batwing","x2",false)
 x.setTime(100.3);x.E.__WATCH.tick()
 x.setTime(100.5);x.E.__WATCH.tick()
 eq(x.E.PDIDDLER_STAGE101_IDENTITY_RUNNER.status().identityStatus,
  "INCONCLUSIVE","client offered x2 mismatch denies raw-key candidate")
end
-- The prompt must stay on the actual game screen without covering
-- offered slots, Accept, Decline, or the current physical TradeGUI.
local function overlaps(panel,trade)
 local pp,ps=panel.Position,panel.Size
 local tp,ts=trade.AbsolutePosition,trade.AbsoluteSize
 local x,y,w,h=pp[1],pp[2],ps[1],ps[2]
 return x<tp.X+ts.X+12 and x+w>tp.X-12 and
        y<tp.Y+ts.Y+12 and y+h>tp.Y-12
end
for _,geometry in ipairs({
 {vw=1024,vh=768,x=520,y=155,w=380,h=460},
 {vw=1024,vh=768,x=15,y=155,w=420,h=460},
 {vw=1024,vh=768,x=320,y=220,w=380,h=370},
 {vw=900,vh=600,x=500,y=155,w=320,h=370},
 {vw=768,vh=1024,x=210,y=305,w=370,h=580},
})do
 local x=fakeEnv(geometry)
 start(x)
 local p=x.named("LiveStatus")
 eq(p.Visible,true,"nonoverlap instructions are visible in each layout")
 eq(overlaps(p,x.trade),false,
    "instructions avoid actual right, left, center, landscape or portrait trade")
 eq(x.named("WhatToDo").Text:find("ALT:",1,true)~=nil,true,
    "physical on-game current step names ALT, not console only")
 x.stopButton().Activated:Fire()
end
do
 local x=fakeEnv()
 start(x)
 x.trade.AbsolutePosition=vec(0,130)
 x.trade.AbsoluteSize=vec(460,460)
 x.E.__WATCH.tick()
 local p=x.named("LiveStatus")
 eq(p.Visible,true,"moving actual trade root repositions the single step panel")
 eq(overlaps(p,x.trade),false,
    "moving trade cannot cause prompt tap interception")
 x.world.CurrentCamera.ViewportSize=vec(768,1024)
 x.trade.AbsolutePosition=vec(120,360)
 x.E.__WATCH.tick()
 eq(overlaps(p,x.trade),false,
    "portrait/orientation change rechecks physical trade collision")
end
do
 local x=fakeEnv()
 start(x)
 x.trade.AbsoluteSize=vec(0,0)
 -- No safe current trade bounds: original P3 watchdog should revoke.
 pcall(x.E.__WATCH.tick)
 eq(x.E.__P3.stopped,true,"zero-size trade bounds cannot keep P3 running")
 eq(#x.offers,0,"unsafe geometry never creates a new offer")
end
for _,opts in ipairs({
 {invalidPlace=true},{invalidConfig=true},{ownerConflict=true},
 {pilotConflict=true},{noAltTest=true},{badTarget=true},
 {noCamera=true},{failUI=true},{vw=260,vh=260},
 {tradeInitiallyOpen=true,x=0,y=0,w=1024,h=768},
})do
 local x=fakeEnv(opts)
 x.run()
 eq(x.E.__P3==nil or x.E.__P3.isArmed()==false,true,
  "invalid startup or unsafe GUI can never send even P3 request")
 eq(#x.offers,0,"invalid startup zero weapon offers")
end
print("[PASS] original protected P3→Stage9/TradeIO→frozen Stage101 live native iPad GUI mocks:",tests)
print("[PASS] same ALT first, MAIN manual add, no offer/Accept/Decline/teleport, identity client-only")
