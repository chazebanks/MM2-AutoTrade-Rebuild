-- ALT-guided native P3 test, derived from real PR218 integration fixtures.
-- Native P3 runner integration tests with actual protected IO, coordinator,
-- exact GUI bridge, updated supervisor, and pure geometry. Scanner, real
-- 1800-line outgoing request fork and watchdog timer are test doubles;
-- the REAL source for those is separately exercised in Lune CI suites.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local runner=fs.readFile("pdiddler/supervised/SUPERVISED_P3_ONE_ITEM_AUTO_ALT_GUIDED_NATIVE.lua")
local ioCode=fs.readFile("pdiddler/supervised/pdiddler4_tradeio_supervised_v2.lua")
local bridgeCode=fs.readFile("pdiddler/supervised/supervised_p3_p4_handoff.lua")
local coordinatorCode=fs.readFile("pdiddler/supervised/supervised_real_p3_rotation_handoff.lua")
local bootCode=fs.readFile("pdiddler/supervised/supervised_p3_startup_supervisor.lua")
local geometryCode=fs.readFile("pdiddler/new_part4/stage100_screen_prompt_overlay.lua")
local operatorCode=fs.readFile("pdiddler/supervised/supervised_p3_one_item_operator.lua")
local planCode=fs.readFile("pdiddler/supervised/supervised_four_slot_operator_plan.lua")
local autoCode=fs.readFile("pdiddler/supervised/supervised_p3_one_item_auto_gate.lua")
local altCode=fs.readFile("pdiddler/supervised/supervised_p3_postoffer_alt_guide.lua")
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
function api.getWhitelist()
 local result={}
 for _,p in ipairs(P:GetPlayers()) do
  if p~=P.LocalPlayer then result[#result+1]=p end
 end
 return result
end
function api.hasPendingWork()return false end
function api.getOwnInventory()
 local E=getgenv()
 E.__OWN_READS=(E.__OWN_READS or 0)+1
 if E.__OWN_MUTATE then E.__OWN_MUTATE() end
 return E.__OWN
end
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
 local offers={}
 function remote:FireServer(raw,category)
  offers[#offers+1]={raw,category}
  if options.renderOffer~=false then
   local original=ours:FindFirstChild("Container")
   local slot=original:put(node("Frame","NewItem"..#offers))
   local name=slot:put(node("Frame","ItemName"))
   local label=name:put(node("TextLabel","Label"))
   label.Text=options.renderedName or "Iceblaster"
   local box=slot:put(node("Frame","Container"))
   local amount=box:put(node("TextLabel","Amount"))
   amount.Text=""
  end
 end
 local world={CurrentCamera={ViewportSize=vec(options.vw or 1024,options.vh or 768)}}
 if options.noCamera then world.CurrentCamera=nil end
 local core=node("CoreGui","CoreGui")
 local service={
  Players=players,ReplicatedStorage=RS,Workspace=world,CoreGui=core,
  GuiService={},VirtualInputManager={},
  HttpService={JSONEncode=function(_,r)return serde.encode("json",r)end,
     GenerateGUID=function()return "11223344-5566-7788-99aa-bbccddeeff00" end}
 }
 local clock=0
 local E={PDIDDLER_SUPERVISED_P3_ONE_ITEM_AUTO_NATIVE={
   autoConsent={origin="PICKER_HUMAN_APPROVED_AUTO_ONE",explicitOneAutomaticPlacement=true,singleConsentingAltOnly=true,finalAcceptMustRemainManual=true,job="FAKE_JOB_P3",altUserId=2,rawKey="Iceblaster",display="Iceblaster",chroma=false,issuedAt=0},
   allowOneItemPilot=true,manualOfferOnly=true,
   noAutomaticAcceptAcknowledged=true,
   approvedRawKey="Iceblaster",
   approvedDisplayName="Iceblaster",approvedChromaFlag=false,
   enableNativeSupervisor=true,finalAcceptMustRemainManual=true,
   altOnlyTest=true,targetName="TrustedAlt",
   altMutationGuidedReadOnlyTest=true,
 }}
 if options.invalidConfig then
  E.PDIDDLER_SUPERVISED_P3_ONE_ITEM_AUTO_NATIVE.enableNativeSupervisor=false
 end
 if options.noAltTest then
  E.PDIDDLER_SUPERVISED_P3_ONE_ITEM_AUTO_NATIVE.altOnlyTest=false
 end
 if options.badTarget then
  E.PDIDDLER_SUPERVISED_P3_ONE_ITEM_AUTO_NATIVE.targetName="MissingAlt"
 end
 if options.ownerConflict then E.PDIDDLER_PART4_SESSION=99 end
 if options.pilotConflict then
   E.PDIDDLER_SUPERVISED_FOUR_SLOT_GUIDE_JOB="FAKE_JOB_P3"
 end
 E.__OWN=options.own or {
  items={{id="Iceblaster",cat="Weapons",name="Iceblaster",
   qty=1,page="godly",type="Gun"}},
  rawOwned=1,unmapped=0,badQty=0,
 }
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
   elseif url:find("supervised_four_slot_operator_plan.lua",1,true) then
     return planCode
   elseif url:find("supervised_p3_one_item_operator.lua",1,true) then
     return operatorCode
   elseif url:find("supervised_p3_one_item_auto_gate.lua",1,true) then
     return autoCode
   elseif url:find("supervised_p3_postoffer_alt_guide.lua",1,true) then
     return altCode
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
  task={spawn=function(fn)fn()end,wait=function()end},
  os={clock=function()return clock end},
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
 local function offerButton()
  for _,o in ipairs(instances) do
   if o.Name=="ApproveOneItem" then return o end
  end
 end
 local function named(wanted)
  for _,o in ipairs(instances) do
   if o.Name==wanted then return o end
  end
 end
 local function statusPanel()
  for _,o in ipairs(instances) do
   if o.Name=="LiveStatus" then return o end
  end
 end
 local function stopButton()
  for _,o in ipairs(instances) do
   if o.Name=="StopP3" then return o end
  end
 end
 return {run=run,E=E,PG=pg,screen=screen,trade=trade,
  readSources=sourceReads,offers=offers,armButton=armButton,
  stopButton=stopButton,offerButton=offerButton,statusPanel=statusPanel,named=named,
  advance=function(dt)clock+=dt end,
  copied=copied,world=world,partner=partner,theirs=theirs,
  otherAccepted=otherAccepted,ownAccepted=ownAccepted,uname=uname}
end
local function attach(x)
 x.screen.Enabled=true
 x.E.__P3.state.processed[2]="trade-open"
 x.E.__P3.setPaused(true)
 return x.E.__WATCH.tick()
end
do
 local x=fakeEnv()
 local runtime=x.run()
 eq(type(runtime),"table","auto native runner instantiated with exact prior picker consent")
 eq(#x.readSources,12,"all original ten frozen modules plus auto and ALT guide loaded")
 eq(x.named("WhatToDo").Text:find("AUTO OFFER ONCE",1,true)~=nil,true,
  "exact one-item automation is visibly disclosed before human ARM")
 eq(x.E.__P3.armCalls,0,"no outgoing P3 before ARM")
 eq(#x.offers,0,"no automatic offer on loading")
 eq(x.offerButton(),nil,"no old post-trade manual OFFER button")
 eq(x.E.__OWN_READS,nil,"no speculative own inventory RPC")
 x.armButton().Activated:Fire()
 eq(x.E.__P3.armCalls,1,"human ARM starts only ALT request queue")
 eq(#x.offers,0,"no item sent on P3 ARM alone")
 eq(attach(x).status,"P4_TWO_SIDED_CLIENT_SNAPSHOT","exact bound original P4 client observed")
 eq(#x.offers,0,"first GUI observation never auto-sends")
 x.advance(0.2)
 eq(x.E.__WATCH.tick().status,"P4_TWO_SIDED_CLIENT_SNAPSHOT","second safe P4 status")
 eq(#x.offers,1,"exactly one automatic guarded offer")
 eq(x.offers[1][1],"Iceblaster","exact human-approved raw key")
 eq(x.offers[1][2],"Weapons","original protected item category")
 eq(x.E.__OWN_READS,1,"current own inventory verified immediately before offer")
 x.advance(0.2);x.E.__WATCH.tick()
eq(x.named("CurrentStep").Text,"3/5 ALT — ADD ONE WEAPON",
  "ALT ADD instruction must replace early decline after one own offer")
eq(x.named("WhatToDo").Text:find("ALT: manually ADD",1,true)~=nil,true,
  "ALT add instructions clearly visible on MAIN")
for i=1,4 do x.advance(0.2);x.E.__WATCH.tick()end
eq(x.named("CurrentStep").Text,"3/5 ALT — ADD ONE WEAPON",
  "no ALT action: must not skip ALT ADD")
local altContainer=x.theirs:FindFirstChild("Container")
local altSlot=altContainer:put(node("Frame","NewItem1"))
local altLabel=altSlot:put(node("Frame","ItemName"))
altLabel:put(node("TextLabel","Label")).Text="TestAltWeapon"
altSlot:put(node("Frame","Container")):put(node("TextLabel","Amount")).Text=""
x.advance(0.2);x.E.__WATCH.tick()
eq(x.named("CurrentStep").Text,"3/5 ALT — ADD ONE WEAPON",
  "first visible ALT slot frame not sufficient for ADD")
x.advance(0.2);x.E.__WATCH.tick()
eq(x.named("CurrentStep").Text,"4/5 ALT — REMOVE SAME WEAPON",
  "stable ALT add must activate remove guide")
altSlot.Visible=false
x.advance(0.2);x.E.__WATCH.tick()
eq(x.named("CurrentStep").Text,"4/5 ALT — REMOVE SAME WEAPON",
  "first remove frame not sufficient")
x.advance(0.2);x.E.__WATCH.tick()
eq(x.named("CurrentStep").Text,"5/5 MAIN — MANUALLY DECLINE",
  "remove must be observed BEFORE decline instruction")
eq(#x.offers,1,"ALT changes cannot cause a duplicate MAIN offer")
 x.screen.Enabled=false
 eq(x.E.__WATCH.tick().status,"P3_RESUMED_AFTER_CLIENT_TRADE_CLOSED",
  "original P3 resumes after manual decline")
 x.stopButton().Activated:Fire()
 local report=serde.decode("json",x.copied[#x.copied])
 eq(report.autoOfferPreauthorizedClient,true,"records prior user approval only")
 eq(report.autoOfferTriggeredClient,true,"records automatic placement trigger")
 eq(report.oneItemTapObservedClient,false,"does not fabricate a second physical tap")
 eq(report.oneItemOfferStatus,"CLIENT_MANUAL_PLAN_VISIBLE_UNATTRIBUTED",
  "real protected GUI confirmed a single client-visible slot")
 eq(report.offerAttempts,1,"one physical attempt")
 eq(report.clientVisibleAddedSlots,1,"one physical added slot")
 eq(report.schema,"gingerscope-p3-one-item-alt-guided-native-v1","new versioned report")
eq(report.runNonce,"11223344-5566-7788-99aa-bbccddeeff00",
 "new randomized run ID field for replay detection")
eq(report.altAddClientObserved,true,"ALT ADD counted only after two observed slots")
eq(report.altRemoveClientObserved,true,"ALT REMOVE counted only after two observed zeros")
eq(report.altSequenceClientComplete,true,"both actual offer transitions")
eq(report.serverCompletionProven,false,"no settlement proof")
 eq(report.authorizesAccept,false,"automatic final Accept prohibited")
 eq(report.tradeOutcome,"UNKNOWN","no claimed completed trade")
 eq(report.mayReportProfit,false,"no profits from mere GUI")
 eq(report.maySendDiscordWebhook,false,"no completed-trade Discord")
 eq(x.run(),nil,"same job never reboots after test")
end
do
 local x=fakeEnv()
 x.run();x.armButton().Activated:Fire();attach(x)
 x.stopButton().Activated:Fire()
 x.advance(1)
 eq(#x.offers,0,"STOP after first frame permanently revokes auto offer")
 local report=serde.decode("json",x.copied[#x.copied])
 eq(report.altAddClientObserved,false,"early STOP cannot invent ALT add")
 eq(report.altRemoveClientObserved,false,"early STOP cannot invent ALT remove")
end
do
 local x=fakeEnv()
 x.run();x.armButton().Activated:Fire();attach(x)
 x.otherAccepted.Visible=true;x.advance(0.2);x.E.__WATCH.tick()
 eq(#x.offers,0,"accepted GUI cannot be auto-offered")
end
do
 local x=fakeEnv()
 x.run();x.armButton().Activated:Fire();attach(x)
 x.partner.Parent=nil;x.advance(0.2);x.E.__WATCH.tick()
 eq(#x.offers,0,"ALT left original session; no offer")
end
do
 local x=fakeEnv()
 x.run();x.armButton().Activated:Fire();attach(x)
 x.screen.Enabled=false;x.advance(0.2);x.E.__WATCH.tick()
 eq(#x.offers,0,"closed trade before stable second frame never offers")
end
do
 local x=fakeEnv()
 x.run();x.armButton().Activated:Fire();attach(x)
 x.trade.AbsolutePosition=vec(0,0);x.trade.AbsoluteSize=vec(1024,768)
 x.advance(0.2);pcall(x.E.__WATCH.tick)
 eq(#x.offers,0,"unsafe trade GUI collision blocks auto send")
end
do
 local x=fakeEnv({own={rawOwned=1,unmapped=0,badQty=0,
  items={{id="WrongKey",cat="Weapons",name="WrongKey",qty=1,page="godly",type="Gun"}}}})
 x.run();x.armButton().Activated:Fire();attach(x)
 x.advance(0.2);x.E.__WATCH.tick()
 eq(#x.offers,0,"stale picker weapon no item sent")
 x.stopButton().Activated:Fire()
 local r=serde.decode("json",x.copied[#x.copied])
 eq(r.oneItemOfferStatus,"BLOCKED","own-key mismatch explicitly blocked")
 eq(r.offerAttempts,0,"blocked before any remote")
end
do
 local x=fakeEnv({renderedName="WrongItem"})
 x.run();x.armButton().Activated:Fire();attach(x)
 x.advance(0.2);x.E.__WATCH.tick()
 eq(#x.offers,1,"one remote even when GUI renders wrong item")
 x.stopButton().Activated:Fire()
 local r=serde.decode("json",x.copied[#x.copied])
 eq(r.oneItemOfferStatus,"STOPPED","wrong client GUI never counted")
 eq(r.clientVisibleAddedSlots,0,"bad item no confirmed slot")
end
do
 local x=fakeEnv()
 x.run();x.armButton().Activated:Fire();attach(x)
 x.E.PDIDDLER_SUPERVISED_P3_ONE_ITEM_AUTO_NATIVE.approvedRawKey="DifferentWeapon"
 x.advance(0.2);x.E.__WATCH.tick()
 eq(#x.offers,0,"mutated selected getgenv raw item cannot redirect original preapproval")
end
do
 local x=fakeEnv()
 x.run();x.armButton().Activated:Fire();attach(x)
 x.E.PDIDDLER_SUPERVISED_P3_ONE_ITEM_AUTO_NATIVE.autoConsent.altUserId=99
 x.advance(0.2);x.E.__WATCH.tick()
 -- The pure gate has already frozen the first exact ALT ID; changes to
 -- the public autoConsent field cannot grant a different account.
 eq(#x.offers,1,"mutating a discarded consent table cannot change frozen ALT authority")
 eq(x.offers[1][1],"Iceblaster","frozen originally approved raw key")
end
for _,opts in ipairs({
 {invalidPlace=true},{invalidConfig=true},{ownerConflict=true},
 {pilotConflict=true},{noAltTest=true},{badTarget=true},{noCamera=true},
 {failUI=true},
}) do
 local x=fakeEnv(opts)
 x.run()
 eq(x.E.__P3,nil,"invalid original MM2 environment never starts P3")
 eq(#x.offers,0,"invalid startup never sends item")
end
do
 local x=fakeEnv()
 x.E.PDIDDLER_SUPERVISED_P3_ONE_ITEM_AUTO_NATIVE.autoConsent.rawKey="Gingerscope"
 x.run()
 eq(x.E.__P3,nil,"mismatched protected raw consent denies P3 startup")
end
do
 local x=fakeEnv()
 x.E.PDIDDLER_SUPERVISED_P3_ONE_ITEM_AUTO_NATIVE.autoConsent.altUserId=99
 x.run();x.armButton().Activated:Fire();attach(x)
 x.advance(0.2);x.E.__WATCH.tick()
 eq(#x.offers,0,"preapproval bound to another UserId cannot auto-place")
end
print("P3_ALT_GUIDED_NATIVE_INTEGRATION_PASS",tests)
