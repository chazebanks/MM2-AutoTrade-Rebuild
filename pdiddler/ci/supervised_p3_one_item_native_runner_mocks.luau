-- Native P3 runner integration tests with actual protected IO, coordinator,
-- exact GUI bridge, updated supervisor, and pure geometry. Scanner, real
-- 1800-line outgoing request fork and watchdog timer are test doubles;
-- the REAL source for those is separately exercised in Lune CI suites.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local runner=fs.readFile("pdiddler/supervised/SUPERVISED_P3_ONE_ITEM_OFFER_NATIVE.lua")
local ioCode=fs.readFile("pdiddler/supervised/pdiddler4_tradeio_supervised_v2.lua")
local bridgeCode=fs.readFile("pdiddler/supervised/supervised_p3_p4_handoff.lua")
local coordinatorCode=fs.readFile("pdiddler/supervised/supervised_real_p3_rotation_handoff.lua")
local bootCode=fs.readFile("pdiddler/supervised/supervised_p3_startup_supervisor.lua")
local geometryCode=fs.readFile("pdiddler/new_part4/stage100_screen_prompt_overlay.lua")
local operatorCode=fs.readFile("pdiddler/supervised/supervised_p3_one_item_operator.lua")
local planCode=fs.readFile("pdiddler/supervised/supervised_four_slot_operator_plan.lua")
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
  HttpService={JSONEncode=function(_,r)return serde.encode("json",r)end}
 }
 local E={PDIDDLER_SUPERVISED_P3_ONE_ITEM_NATIVE={
   allowOneItemPilot=true,manualOfferOnly=true,
   noAutomaticAcceptAcknowledged=true,
   approvedRawKey="Iceblaster",
   approvedDisplayName="Iceblaster",approvedChromaFlag=false,
   enableNativeSupervisor=true,finalAcceptMustRemainManual=true,
   altOnlyTest=true,targetName="TrustedAlt",
 }}
 if options.invalidConfig then
  E.PDIDDLER_SUPERVISED_P3_ONE_ITEM_NATIVE.enableNativeSupervisor=false
 end
 if options.noAltTest then
  E.PDIDDLER_SUPERVISED_P3_ONE_ITEM_NATIVE.altOnlyTest=false
 end
 if options.badTarget then
  E.PDIDDLER_SUPERVISED_P3_ONE_ITEM_NATIVE.targetName="MissingAlt"
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
  stopButton=stopButton,offerButton=offerButton,statusPanel=statusPanel,
  copied=copied,world=world,partner=partner,theirs=theirs,
  otherAccepted=otherAccepted,ownAccepted=ownAccepted,uname=uname}
end
do
 local x=fakeEnv()
 local runtime=x.run()
 eq(type(runtime),"table","new one-item native runner returns controller")
 eq(#x.readSources,10,"ten exact pinned source modules fetched")
 eq(x.E.__P3.armCalls,0,"no P3 request before ARM")
 eq(#x.offers,0,"no OfferItem on startup")
 eq(x.E.__OWN_READS,nil,"no own inventory RPC on startup")
 eq(x.offerButton().Visible,false,"offer approval hidden before P3 arm")
 eq(x.E.__SCANNER_P3_SEES.getWhitelist()[1].Name,"TrustedAlt","only correct ALT candidate")
 eq(x.E.__SCANNER_P3_SEES.isWhitelisted(99),false,"stranger excluded")
 x.armButton().Activated:Fire()
 eq(x.E.__P3.armCalls,1,"first explicit ARM starts only P3 contact")
 eq(#x.offers,0,"ARM alone cannot send an item")
 eq(x.offerButton().Visible,false,"one-item tap hidden before actual P4 GUI")
 x.screen.Enabled=true
 x.E.__P3.state.processed[2]="trade-open"
 x.E.__P3.setPaused(true)
 eq(x.E.__WATCH.tick().status,"P4_TWO_SIDED_CLIENT_SNAPSHOT",
   "original exact client-bound trade attached")
 eq(x.offerButton().Visible,true,"separate one-item approval button appears")
 eq(x.offerButton().Active,true,"real physical approval can be tapped")
 eq(#x.offers,0,"no offer until separate button tap")
 eq(x.E.__OWN_READS,nil,"no own inventory RPC until separate button tap")
 x.offerButton().Activated:Fire()
 eq(#x.offers,1,"exactly one guarded OfferItem remote")
 eq(x.offers[1][1],"Iceblaster","real own raw key sent")
 eq(x.offers[1][2],"Weapons","weapon category")
 eq(x.offerButton().Visible,false,"one-item approval button spent")
 eq(x.E.__OWN_READS,1,"one current own inventory call after tap")
 x.offerButton().Activated:Fire()
 eq(#x.offers,1,"double tap cannot resend")
 x.stopButton().Activated:Fire()
 eq(#x.copied>=1,true,"receipt copied")
 local stop=serde.decode("json",x.copied[#x.copied])
 eq(stop.oneItemTapObservedClient,true,"separate human tap observed")
 eq(stop.oneItemOfferStatus,"CLIENT_MANUAL_PLAN_VISIBLE_UNATTRIBUTED",
  "actual guarded client GUI physical placement seen")
 eq(stop.offerAttempts,1,"one outbound offer remote attempt")
 eq(stop.clientVisibleAddedSlots,1,"one visible physical slot reconciled")
 eq(stop.authorizesAccept,false,"final Accept prohibited")
 eq(stop.serverCompletionProven,false,"server settlement not claimed")
 eq(stop.mayReportProfit,false,"profit not claimed")
 eq(stop.maySendDiscordWebhook,false,"no completion webhook")
 eq(x.copied[#x.copied]:find("TrustedAlt",1,true),nil,
  "clipboard never exports ALT name")
 eq(x.copied[#x.copied]:find("Iceblaster",1,true),nil,
  "clipboard never exports raw inventory key")
 eq(x.E.__P3.stopped,true,"STOP revokes original P3")
 eq(x.run(),nil,"same JobId cannot repeat after completed pilot")
end
do
 local x=fakeEnv()
 x.run()
 x.armButton().Activated:Fire()
 x.screen.Enabled=true
 x.E.__P3.state.processed[2]="trade-open"
 x.E.__P3.setPaused(true)
 x.E.__WATCH.tick()
 x.stopButton().Activated:Fire()
 local receipt=serde.decode("json",x.copied[#x.copied])
 eq(receipt.oneItemTapObservedClient,false,"P3-only STOP cannot invent offer consent")
 eq(receipt.oneItemOfferStatus,"NOT_ATTEMPTED","no phantom offer result")
 eq(#x.offers,0,"P3 and trade GUI do not automatically place item")
end
do
 local x=fakeEnv({own={rawOwned=1,unmapped=0,badQty=0,
  items={{id="WrongItem",cat="Weapons",name="WrongItem",
   qty=1,page="godly",type="Gun"}}}})
 x.run()
 x.armButton().Activated:Fire()
 x.screen.Enabled=true
 x.E.__P3.state.processed[2]="trade-open"
 x.E.__P3.setPaused(true)
 x.E.__WATCH.tick()
 x.offerButton().Activated:Fire()
 eq(#x.offers,0,"not-owned specified weapon never sent")
 x.stopButton().Activated:Fire()
 local r=serde.decode("json",x.copied[#x.copied])
 eq(r.oneItemTapObservedClient,true,"tap still observed after denied own key")
 eq(r.oneItemOfferStatus,"BLOCKED","profile mismatch refuses outbound")
 eq(r.offerAttempts,0,"zero attempts under own-key mismatch")
end
do
 local x=fakeEnv()
 x.run()
 x.armButton().Activated:Fire()
 x.screen.Enabled=true
 x.E.__P3.state.processed[2]="trade-open"
 x.E.__P3.setPaused(true)
 x.E.__WATCH.tick()
 x.otherAccepted.Visible=true
 x.offerButton().Activated:Fire()
 eq(#x.offers,0,"already accepted GUI no item send")
end
for _,opts in ipairs({
 {invalidPlace=true},{invalidConfig=true},
 {ownerConflict=true},{pilotConflict=true},
 {noAltTest=true},{badTarget=true},{noCamera=true},{failUI=true},
}) do
 local x=fakeEnv(opts)
 x.run()
 eq(x.E.__P3==nil,true,"invalid original MM2 startup never starts P3")
 eq(#x.offers,0,"bad startup never offers")
end
for _,opts in ipairs({
 {vw=260,vh=260},
 {tradeInitiallyOpen=true,x=0,y=0,w=1024,h=768},
}) do
 local x=fakeEnv(opts)
 x.run()
 eq(x.E.__P3==nil or x.E.__P3.isArmed()==false,true,
   "unsafe panel fails closed")
 eq(#x.offers,0,"no offer when panel overlaps trade")
end
do
 local x=fakeEnv({renderedName="WrongRenderedItem"})
 x.run()
 x.armButton().Activated:Fire()
 x.screen.Enabled=true
 x.E.__P3.state.processed[2]="trade-open"
 x.E.__P3.setPaused(true)
 x.E.__WATCH.tick()
 x.offerButton().Activated:Fire()
 eq(#x.offers,1,"one remote allowed before mismatched client GUI read")
 x.stopButton().Activated:Fire()
 local r=serde.decode("json",x.copied[#x.copied])
 eq(r.oneItemOfferStatus,"STOPPED","wrong physical GUI label cannot count as success")
 eq(r.offerAttempts,1,"one send acknowledged even with failed GUI")
 eq(r.clientVisibleAddedSlots,0,"wrong physical GUI never counted")
 eq(r.serverCompletionProven,false,"no settlement even when item was sent")
end
do
 local x=fakeEnv()
 x.run()
 x.armButton().Activated:Fire()
 x.screen.Enabled=true
 x.E.__P3.state.processed[2]="trade-open"
 x.E.__P3.setPaused(true)
 x.E.__WATCH.tick()
 x.partner.Parent=nil
 x.offerButton().Activated:Fire()
 eq(#x.offers,0,"ALT leaves after initial client bind; no item offered")
end
-- The actual mutable viewport/trade layout must remain collision-free for
-- both left and right trade layouts and a repositioned original MM2 trade.
local function overlap(ax,ay,aw,ah,bx,by,bw,bh)
 return ax<bx+bw and bx<ax+aw and ay<by+bh and by<ay+ah
end
for _,opt in ipairs({
 {vw=1180,vh=820,x=100,y=150,w=530,h=410},
 {vw=1180,vh=820,x=600,y=150,w=530,h=410},
 {vw=1024,vh=768,x=270,y=100,w=484,h=560},
}) do
 local x=fakeEnv(opt)
 x.run()
 x.armButton().Activated:Fire()
 x.screen.Enabled=true
 x.E.__P3.state.processed[2]="trade-open"
 x.E.__P3.setPaused(true)
 local ok=pcall(x.E.__WATCH.tick)
 local panel=x.statusPanel()
 if ok and panel and panel.Visible and x.offerButton().Visible then
  local pp=panel.Position
  local ps=panel.Size
  local tp=x.trade.AbsolutePosition
  local ts=x.trade.AbsoluteSize
  eq(overlap(pp[1],pp[2],ps[1],ps[2],
    tp.X,tp.Y,ts.X,ts.Y),false,"real native offer prompt outside trade bounds")
 else
  eq(#x.offers,0,"any failed layout must not send items")
 end
end
do
 local x=fakeEnv()
 x.run()
 x.armButton().Activated:Fire()
 x.screen.Enabled=true
 x.E.__P3.state.processed[2]="trade-open"
 x.E.__P3.setPaused(true)
 x.E.__WATCH.tick()
 x.trade.AbsolutePosition=vec(0,0)
 x.trade.AbsoluteSize=vec(1024,768)
 local ok=pcall(x.E.__WATCH.tick)
 eq(#x.offers,0,"fullscreen trade intersection never triggers automatic offer")
 x.offerButton().Activated:Fire()
 eq(#x.offers,0,"outdated approval button cannot offer after fullscreen change")
end
print("[PASS] original MM2 P3 + explicit one-item OFFER GUI + protected IO:",tests)
print("[PASS] no offer before separate tap; wrong inventory, old session, final Accept denied")
