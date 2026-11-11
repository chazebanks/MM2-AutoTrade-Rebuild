-- Native P3 runner integration tests with actual protected IO, coordinator,
-- exact GUI bridge, updated supervisor, and pure geometry. Scanner, real
-- 1800-line outgoing request fork and watchdog timer are test doubles;
-- the REAL source for those is separately exercised in Lune CI suites.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local runner=fs.readFile("pdiddler/supervised/STAGE119_P3_BOUND_READONLY_NATIVE.lua")
local ioCode=fs.readFile("pdiddler/supervised/pdiddler4_tradeio_supervised_v2.lua")
local bridgeCode=fs.readFile("pdiddler/supervised/supervised_p3_p4_handoff.lua")
local coordinatorCode=fs.readFile("/tmp/gingerscope-stage220/frozen_coordinator.lua")
local bootCode=fs.readFile("/tmp/gingerscope-stage220/frozen_boot.lua")
local geometryCode=fs.readFile("pdiddler/new_part4/stage100_screen_prompt_overlay.lua")
local identityCode=fs.readFile("pdiddler/supervised/supervised_p3_p4_stage101_identity_witness.lua")
local stage118Code=fs.readFile("pdiddler/intelligence_lab/stage118_lastoffer_gui_correlation.lua")
local lastOfferCode=fs.readFile("pdiddler/intelligence_lab/trade_lastoffer_client_audit.lua")
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
 local E={PDIDDLER_P3_STAGE119_LASTOFFER_NATIVE={
   enableNativeSupervisor=true,finalAcceptMustRemainManual=true,
   altOnlyTest=true,targetName="TrustedAlt",
   stage119LastOfferReadOnly=true,
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
     if options.oldBootWithoutLease then
       return bootCode:gsub("return supervisor,nil\nend\nreturn M",
         "supervisor.currentBoundReadOnly=nil\n return supervisor,nil\nend\nreturn M")
     end
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
   elseif url:find("stage118_lastoffer_gui_correlation.lua",1,true) then
     return stage118Code
   elseif url:find("trade_lastoffer_client_audit.lua",1,true) then
     return lastOfferCode
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
 local function currentEvent(state,token)
  local offered=state=="ADD"
  return {
   LastOffer=token or 12,Locked=false,
   Player1={Player=lp,Accepted=false,Offer={}},
   Player2={Player=partner,Accepted=false,
     Offer=offered and {{"ImmortalChroma",2,"Weapons"}} or {}}
  }
 end
 local function removeAltWeapon()
  local container=theirs:FindFirstChild("Container")
  container.__slots={}
  for i=1,4 do container.children["NewItem"..tostring(i)]=nil end
 end
 return {run=run,E=E,PG=pg,screen=screen,trade=trade,
  readSources=sourceReads,offers=offers,armButton=armButton,
  stopButton=stopButton,copied=copied,world=world,
  setTime=function(t)clock=t end,now=function()return clock end,
  update=update,addWeapon=addWeapon,removeAltWeapon=removeAltWeapon,currentEvent=currentEvent,
  partner=partner,our=ours,their=theirs,remote=remote,
  named=named}
end

-- This suite uses the EXACT ORIGINAL PR221 P3/TradeIO/coordinator/boot and
-- frozen original Stage9 GUI reader, swapping ONLY the new LastOffer observer.
local function runnerStatus(x)
 local api=x.E.PDIDDLER_STAGE119_P3_RUNNER
 assert(type(api)=="table")
 return api.status()
end
local function start(x)
 local runtime=x.run()
 eq(type(runtime),"table","prepared original protected Stage119 native P3 runner")
 eq(#x.readSources,12,"exact 12 frozen modules including protected P3 and Stage118")
 eq(#x.offers,0,"no offers sent on load")
 eq(x.E.__P3.armCalls,0,"P3 request remains shut until ARM tap")
 eq(x.E.__SCANNER_P3_SEES.isWhitelisted(99),false,"cannot trade outsider")
 eq(x.E.__SCANNER_P3_SEES.getWhitelist()[1].Name,"TrustedAlt",
   "only the consenting ALT is eligible for P3 request")
 eq(x.armButton().Visible,true,"ARM P3 on purple screen")
 eq(x.stopButton().Visible,true,"STOP/COPY available before ARM")
 x.armButton().Activated:Fire()
 eq(x.E.__P3.armCalls,1,"one operator authorized original P3 request")
 eq(runnerStatus(x).p3ArmObservedClient,true,"ARM P3 observed client")
 eq(#x.offers,0,"ARM P3 does not create any offer")
 x.E.__P3.state.processed[2]="trade-open"
 x.E.__P3.setPaused(true)
 x.screen.Enabled=true
 eq(x.E.__WATCH.tick().status,"P4_TWO_SIDED_CLIENT_SNAPSHOT",
  "current original protected P3-to-P4 trade")
 x.setTime(100.22)
 x.E.__WATCH.tick()
 eq(x.named("CurrentStep").Text:find("3/5 ALT",1,true)~=nil,true,
  "only after protected EMPTY GUI and original Stage118 listener step 3 shows")
 eq(x.stopButton().Visible,true,"STOP/COPY remains visible in stage 3")
 return runtime
end
local function conclude(x,lastToken)
 x.update.OnClientEvent:Fire(x.currentEvent("ADD",12))
 x.addWeapon("ALT","Immortal","x2",true)
 x.setTime(100.3);x.E.__WATCH.tick()
 x.setTime(100.51);x.E.__WATCH.tick()
 eq(x.named("CurrentStep").Text:find("4/5 ALT",1,true)~=nil,true,
    "only stable protected original P4 and Stage9 ADD makes REMOVE appear")
 eq(x.stopButton().Visible,true,"STOP/COPY remains visible after ALT add")
 x.update.OnClientEvent:Fire(x.currentEvent("REMOVE",lastToken))
 x.removeAltWeapon()
 x.setTime(100.62);x.E.__WATCH.tick()
 x.setTime(100.84);x.E.__WATCH.tick()
 local r=runnerStatus(x)
 eq(r.clientLastOfferStatus,"CLIENT_TWO_EVENT_LASTOFFER_GUI_UNATTRIBUTED",
    "two LastOffer/GUI transitions in original protected P3/P4")
 eq(r.p3ArmObservedClient,true,"P3 was ARM authorized")
 eq(r.clientTradeWindowObserved,true,"P4 was active")
 eq(r.protectedP3P4LeaseCrossChecked,true,"P3 bound lease checked with original P4")
 eq(r.clientGuiQuantityCrossChecked,true,"original Stage9 and P4 quantities verified")
 eq(r.callbackCount,2,"exactly two client UpdateTrade callbacks")
 eq(r.guiQuantityTransitions,2,"two physical GUI quantity transitions")
 eq(r.clientGuiCrossChecked,false,"not a full weapon identity proof")
 eq(r.serverTradeRevisionProven,false,"LastOffer not authenticated")
 eq(r.eventSessionAssociationProven,false,"session not server authenticated")
 eq(r.authorizesAccept,false,"final accept denied")
 eq(r.tradeOutcome,"UNKNOWN","never claim settlement")
 eq(#x.offers,0,"no OfferItem FireServer calls")
 eq(x.E.__P3.stopped,true,"P3 stopped on one bounded client-only result")
 eq(x.stopButton().Visible,true,"STOP/COPY still shown at positive result")
 x.stopButton().Activated:Fire()
 local decoded=serde.decode("json",x.copied[#x.copied])
 eq(decoded.clientLastOfferStatus,"CLIENT_TWO_EVENT_LASTOFFER_GUI_UNATTRIBUTED",
    "STOP/COPY retains client result")
 eq(decoded.actualAccepts,0,"no scripted Accept")
 eq(decoded.actualOffers,0,"no scripted OfferItem")
 eq(decoded.actualDeclines,0,"no scripted Decline")
 eq(x.copied[#x.copied]:find("Immortal",1,true),nil,"no weapon name leak")
 eq(x.copied[#x.copied]:find("TrustedAlt",1,true),nil,"no ALT identity leak")
 return r
end
do
 local x=fakeEnv()
 start(x)
 local r=conclude(x,13)
 eq(r.lastOfferEqualityClass,"CLIENT_LASTOFFER_CHANGED_WITH_DIFFERENT_OFFER",
  "two original protected client events differ in LastOffer opaque equality")
 eq(x.run(),nil,"same JobId cannot run again")
end
do
 local x=fakeEnv()
 start(x)
 local r=conclude(x,12)
 eq(r.lastOfferEqualityClass,"CLIENT_LASTOFFER_UNCHANGED_WITH_DIFFERENT_OFFER",
   "same opaque LastOffer across GUI changes cannot authorize server acceptance")
end
do
 local x=fakeEnv()
 local r=x.run()
 eq(type(r),"table","startup prepared")
 eq(x.E.__P3.armCalls,0,"NO request without operator tap")
 eq(#x.offers,0,"no offers without ARM")
 eq(x.stopButton().Visible,true,"STOP/COPY before ARM")
 x.stopButton().Activated:Fire()
 eq(x.E.__P3.stopped,true,"STOP cancels unarmed P3 safely")
end
do
 local x=fakeEnv({oldBootWithoutLease=true})
 eq(x.run(),nil,"old original P3 supervisor without lease rejected before ARM")
 eq(x.E.__P3.armCalls,0,"missing frozen lease means zero requests")
 eq(#x.offers,0,"missing lease cannot offer")
end
do
 local x=fakeEnv()
 start(x)
 x.update.OnClientEvent:Fire(x.currentEvent("ADD",12))
 x.update.OnClientEvent:Fire(x.currentEvent("ADD",12))
 eq(runnerStatus(x).clientLastOfferStatus,"INCONCLUSIVE",
   "duplicate client UpdateTrade callback must invalidate")
 eq(x.stopButton().Visible,true,"STOP/COPY remains present on error")
 eq(#x.offers,0,"duplicate callback cannot create offer")
 x.stopButton().Activated:Fire()
end
do
 local x=fakeEnv()
 start(x)
 local bad=x.currentEvent("ADD",12)
 bad.LastOffer=nil
 x.update.OnClientEvent:Fire(bad)
 eq(runnerStatus(x).clientLastOfferStatus,"INCONCLUSIVE",
  "malformed opaque token rejected")
 eq(x.stopButton().Visible,true,"STOP after malformed client event")
end
do
 local x=fakeEnv()
 start(x)
 x.partner.Parent=nil
 x.setTime(100.3)
 x.E.__WATCH.tick()
 eq(runnerStatus(x).clientLastOfferStatus,"INCONCLUSIVE",
   "lost original consenting ALT cannot bind")
end
do
 local x=fakeEnv()
 start(x)
 x.screen.Enabled=false
 x.setTime(100.3)
 x.E.__WATCH.tick()
 eq(runnerStatus(x).clientLastOfferStatus,"INCONCLUSIVE",
   "closed original P4 root revokes current client lease")
end
do
 local x=fakeEnv()
 start(x)
 x.addWeapon("MAIN","Batwing","",false)
 x.setTime(100.3)
 x.E.__WATCH.tick()
 eq(runnerStatus(x).clientLastOfferStatus,"INCONCLUSIVE",
   "MAIN must remain empty throughout ALT-only read-only test")
 eq(#x.offers,0)
end
local function overlaps(panel,trade)
 local p,z=panel.Position,panel.Size
 local t,w=trade.AbsolutePosition,trade.AbsoluteSize
 return p[1]<t.X+w.X+12 and p[1]+z[1]>t.X-12 and
  p[2]<t.Y+w.Y+12 and p[2]+z[2]>t.Y-12
end
for _,geo in ipairs({
 {vw=1024,vh=768,x=520,y=155,w=380,h=460},
 {vw=1024,vh=768,x=15,y=155,w=420,h=460},
 {vw=1024,vh=768,x=320,y=280,w=380,h=300},
 {vw=900,vh=600,x=500,y=155,w=320,h=370},
 {vw=768,vh=1024,x=210,y=305,w=370,h=580},
})do
 local x=fakeEnv(geo)
 start(x)
 local p=x.named("LiveStatus")
 eq(p.Visible,true,"current on-screen instructions visible")
 eq(overlaps(p,x.trade),false,
   "real Stage100 geometry separates purple panel from actual TradeGUI")
 eq(x.stopButton().Visible,true,"STOP is always present")
 x.stopButton().Activated:Fire()
end
do
 local x=fakeEnv({x=320,y=220,w=380,h=370})
 x.run();x.armButton().Activated:Fire()
 x.E.__P3.state.processed[2]="trade-open"
 x.E.__P3.setPaused(true)
 x.screen.Enabled=true
 eq(pcall(x.E.__WATCH.tick),false,
   "no safe UI space must STOP instead of covering trade Accept/Decline")
 eq(x.E.__P3.stopped,true,"unsafe screen stops P3")
 eq(#x.offers,0)
end
for _,opts in ipairs({
 {invalidPlace=true},{invalidConfig=true},{ownerConflict=true},
 {pilotConflict=true},{noAltTest=true},{badTarget=true},
 {noCamera=true},{failUI=true},{vw=260,vh=260}
})do
 local x=fakeEnv(opts)
 x.run()
 eq(x.E.__P3==nil or x.E.__P3.isArmed()==false,true,
   "unsafe startup must not arm original P3")
 eq(#x.offers,0,"unsafe startup cannot offer")
end
print("STAGE119_P3_BOUND_LEASE_NATIVE_PASS real original P3 P4 Stage9 LastOffer integration",tests)
