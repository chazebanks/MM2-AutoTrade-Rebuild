-- Execute the ACTUAL supervised P3/P4 handoff and ACTUAL guarded P4 TradeIO.
-- Roblox game/players/GUI and P3 outgoing/scanner implementations mocked.
-- NO real Roblox gameplay actions, remotes, account/market data or HTTP.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local handoffText=fs.readFile("pdiddler/supervised/supervised_p3_p4_handoff.lua")
local ioText=fs.readFile("pdiddler/supervised/pdiddler4_tradeio_supervised_v2.lua")
local coordinatorText=fs.readFile("pdiddler/supervised/supervised_real_p3_rotation_handoff.lua")
local bootstrapText=fs.readFile("pdiddler/supervised/supervised_p3_startup_supervisor.lua")
local watchdogText=fs.readFile("pdiddler/supervised/supervised_p3_continuous_watchdog.lua")
local tests=0
local function eq(x,w,tag)
 tests+=1
 assert(x==w,tostring(tag)..": "..tostring(x).." != "..tostring(w))
end
local function node(class,name)
 local x={ClassName=class,Name=name,Visible=true,Enabled=true,
   Text="",children={},attributes={}}
 function x:IsA(k)
  return k==self.ClassName or
   (k=="GuiObject" and (class=="Frame" or
    class=="TextLabel" or class=="TextButton"))
 end
 function x:FindFirstChild(k)return self.children[k]end
 function x:GetDescendants()return {}end
 function x:GetAttribute(k)return self.attributes[k] end
 function x:GetFullName()return self.Name end
 function x:put(item)
  item.Parent=self
  self.children[item.Name]=item
  return item
 end
 return x
end
local function fixture()
 local players={}
 local pg=node("PlayerGui","PlayerGui")
 local screen=pg:put(node("ScreenGui","TradeGUI"))
 local container=screen:put(node("Frame","Container"))
 local trade=container:put(node("Frame","Trade"))
 local a=trade:put(node("Frame","YourOffer"))
 local own=a:put(node("Frame","Container"))
 local ownAccepted=a:put(node("Frame","Accepted"))
 ownAccepted.Visible=false
 local b=trade:put(node("Frame","TheirOffer"))
 local their=b:put(node("Frame","Container"))
 local theirAccepted=b:put(node("Frame","Accepted"))
 theirAccepted.Visible=false
 local name=b:put(node("TextLabel","Username"))
 name.Text="TrustedAlt"
 local lp={Name="MainAccount",UserId=1,Parent=players}
 players.LocalPlayer=lp
 local p={Name="TrustedAlt",DisplayName="Alt",UserId=2,Parent=players}
 function players:FindFirstChild(k)
  if k==p.Name and p.Parent==players then return p end
  if self.other and k==self.other.Name and self.other.Parent==players then return self.other end
 end
 function players:GetPlayerByUserId(uid)
  if p.UserId==uid and p.Parent==players then return p end
  if self.other and self.other.UserId==uid and self.other.Parent==players then return self.other end
 end
 function lp:FindFirstChildOfClass(kind)
  if kind=="PlayerGui" then return pg end
 end
 local sends={}
 local remote=node("RemoteEvent","OfferItem")
 function remote:FireServer(raw,cat)
  sends[#sends+1]={raw,cat}
 end
 local folder=node("Folder","Trade")
 folder:put(remote)
 local replicated=node("ReplicatedStorage","ReplicatedStorage")
 replicated:put(folder)
 local service={Players=players,ReplicatedStorage=replicated,
    VirtualInputManager={},GuiService={}}
 local game={
  GetService=function(_,k)return service[k] end,
 }
 local env={game=game,task={wait=function()end}}
 local module=luau.load(handoffText,{environment=env,injectGlobals=true})()
 local coordinator=luau.load(coordinatorText,{environment=env,injectGlobals=true})()
 local bootstrap=luau.load(bootstrapText,{environment=env,injectGlobals=true})()
 local watchdog=luau.load(watchdogText,{environment=env,injectGlobals=true})()
 local iomod=luau.load(ioText,{environment=env,injectGlobals=true})()
 local gate={}
 local io=iomod.new({resolveOfferEntry=function()return nil end},gate)
 local scanner={state="whitelist",object=p}
 function scanner.isWhitelisted(uid)
  return (uid==2 or (players.other and uid==players.other.UserId))
      and scanner.state=="whitelist"
 end
 function scanner.getRecord(uid)
  if uid==2 then return {state=scanner.state,player=scanner.object}end
  if players.other and uid==players.other.UserId then
   return {state=scanner.state,player=players.other}
  end
 end
 local outgoing={session=18,paused=false,resumed=0,state={processed={},active=nil}}
 function outgoing.isPaused() return outgoing.paused end
 function outgoing.resume(reason)
  outgoing.resumed+=1
  if screen.Enabled then return false,"still-open" end
  outgoing.paused=false
  return true,"resumed"
 end
 local ctx={targetName="TrustedAlt",job="Job-A",epoch=18}
 ctx.getJobId=function()return ctx.job end
 ctx.getP3Session=function()return ctx.epoch end
 local function add(root,i,key,qty,chroma,emptyLabel)
  local slot=root:put(node("Frame","NewItem"..i))
  local itemName=slot:put(node("Frame","ItemName"))
  if not emptyLabel then
   local label=itemName:put(node("TextLabel","Label"))
   label.Text=key
  end
  local c=slot:put(node("Frame","Container"))
  local q=c:put(node("TextLabel","Amount"))
  q.Text="x"..tostring(qty or 1)
  if chroma then
   local tags=slot:put(node("Frame","Tags"))
   tags:put(node("Frame","Chroma"))
  end
  return slot
 end
 return {module=module,coordinator=coordinator,bootstrap=bootstrap,watchdog=watchdog,io=io,p3=outgoing,scanner=scanner,
    ctx=ctx,players=players,lp=lp,p=p,pg=pg,screen=screen,
    trade=trade,ours=own,theirs=their,ownAccepted=ownAccepted,
    theirAccepted=theirAccepted,name=name,add=add,sends=sends}
end

local function newSupervisor(x,options)
 options=options or {}
 x.scanner.getWhitelist=function()return {x.p} end
 x.scanner.hasPendingWork=function()return false end
 x.screen.Enabled=false -- queue starts before any original MM2 trade opens
 local events={}
 local outgoingModule={}
 function outgoingModule.run(scanner,opt)
  events[#events+1]="P3_RUN_GATED"
  eq(scanner,x.scanner,"real scanner API handed to P3")
  eq(opt.requiresExplicitStart,true,"original P3 hard start gate required")
  eq(type(opt.readyCheck),"function","original live ready predicate required")
  eq(opt.readyCheck(),false,"not ready before observer attached")
  x.p3.isArmed=function()return x.p3.armed==true end
  x.p3.arm=function()
   events[#events+1]="P3_ARM_CHECK"
   if not opt.readyCheck() then
    return false,"supervisor-not-ready"
   end
   if x.p3.armed then return false,"already-armed" end
   x.p3.armed=true
   return true,"P3_QUEUE_ARMED_NO_FINAL_ACCEPT"
  end
  x.p3.stop=function()
   x.p3.stopped=true
   x.p3.armed=false
   events[#events+1]="P3_STOP"
  end
  return x.p3
 end
 local coordinatorModule={new=function(...)
   events[#events+1]="P4_OBSERVER_ATTACH"
   return x.coordinator.new(...)
 end}
 local flags={screen=true,monitor=true,external=true,ready=true}
 local ctx={
  getJobId=x.ctx.getJobId,
  getP3Session=x.ctx.getP3Session,
  onScreenSafe=function()return flags.screen end,
  watchdogReady=function()
   if type(flags.monitor)=="function" then return flags.monitor() end
   return flags.monitor
  end,
  noOtherTransactionOwner=function()return flags.external end,
  readyCheck=function()return flags.ready end,
 }
 local supervisor,err=x.bootstrap.new(x.scanner,outgoingModule,
      coordinatorModule,x.module,x.io,x.players,x.lp,ctx)
 return supervisor,err,events,flags
end

local optIn={explicitUserAuthorization=true,
 allowRealP3RequestRotation=true,finalAcceptMustRemainManual=true}
local function setup()
 local x=fixture()
 local boss,err,events,flags=newSupervisor(x)
 eq(type(boss),"table","actual PR209 boot attached")
 local now=100
 local scheduled=nil
 local ticks=0
 local reports={}
 local scheduler={
  spawn=function(fn)
   scheduled=fn
  end,
  wait=function(seconds)
   now+=seconds
  end,
  now=function()return now end,
 }
 local ctx={
  getJobId=function()return x.ctx.job end,
  isLive=function()return flags.screen end,
  onStatus=function(r)
   reports[#reports+1]=r.status
  end,
 }
 local watcher,why=x.watchdog.new(boss,x.p3,x.io,ctx,scheduler)
 eq(type(watcher),"table","watchdog constructed")
 eq(why,nil,"no watchdog constructor error")
 flags.monitor=function()return watcher.isReady()end
 local function advance(s)now+=s end
 return x,boss,watcher,flags,reports,function()return scheduled end,advance
end
do
 local x,boss,watch,flags,reports,getScheduled,advance=setup()
 eq(watch.isReady(),false,"watchdog defaults unready")
 eq(boss.arm(optIn),false,"cannot arm before live scheduled watchdog")
 eq(x.p3.armed,nil,"no P3 request rotation unmonitored")
 local ok,why=watch.start()
 eq(ok,true,"watchdog starts scheduling")
 eq(type(getScheduled()),"function","continuous background poll installed")
 eq(watch.isReady(),false,"not armed on scheduler existence alone")
 local first=watch.tick()
 eq(first.status,"P3_SUPERVISOR_PREPARED_NOT_ARMED","first live monitored cycle")
 eq(watch.isReady(),true,"heartbeat current")
 eq(boss.arm(optIn),true,"real P3 arm after actual monitor heartbeat")
 eq(x.p3.armed,true,"P3 request queue now user-authorized")
 local idle=watch.tick()
 eq(idle.status,"P3_ROTATING","continues real P3 read-only coordinator")
 eq(#x.sends,0,"no offer item remotes")
 x.screen.Enabled=true
 x.p3.state.processed[x.p.UserId]="trade-open"
 x.p3.state.active=nil
 x.p3.paused=true
 local inTrade=watch.tick()
 eq(inTrade.status,"P4_TWO_SIDED_CLIENT_SNAPSHOT","active actual original trade observed")
 eq(inTrade.authorizesAccept,false,"no auto final Accept")
 x.screen.Enabled=false
 local closed=watch.tick()
 eq(closed.status,"P3_RESUMED_AFTER_CLIENT_TRADE_CLOSED","watchdog resumes only after trade is closed")
 eq(x.p3.resumed,1,"one original P3 resume call")
 local following=watch.tick()
 eq(following.status,"P3_ROTATING","safe rotation after completed client window")
 eq(x.p3.resumed,1,"never double resume")
 eq(#x.sends,0,"no unexpected offer item")
 advance(1.0)
 eq(watch.isReady(),false,"heartbeat eventually stale")
 local blocked=boss.arm(optIn)
 eq(blocked,false,"cannot rearm already-armed P3")
 eq(watch.stop(),true,"watchdog stop")
 eq(x.p3.stopped,true,"closing watcher also stops actual P3")
 eq(watch.isReady(),false,"stopped monitor not ready")
end
do
 local x,boss,watch,flags,reports,schedule=setup()
 watch.start();watch.tick()
 eq(boss.arm(optIn),true,"armed for outage")
 flags.screen=false
 local fail=watch.tick()
 eq(fail.status,"BLOCKED","lost instruction stops supervision")
 eq(fail.reason,"P3_WATCHDOG_SESSION_LOST","specific safe live status")
 eq(x.p3.stopped,true,"original P3 stopped")
 eq(watch.isReady(),false,"dead watch no heartbeats")
end
do
 local x,boss,watch,flags,reports=setup()
 watch.start();watch.tick();boss.arm(optIn)
 flags.external=false
 local stop=watch.tick()
 eq(stop.status,"BLOCKED","external transaction owner stops watchdog")
 eq(x.p3.stopped,true,"real P3 original gate revoked")
 eq(stop.reason,"P3_EXTERNAL_CONTROLLER_DETECTED","reason from bootstrap preserved")
end
do
 local x,boss,watch,flags,reports,getScheduled=setup()
 watch.start();watch.tick();boss.arm(optIn)
 x.screen.Enabled=false
 x.p3.paused=true
 local r=watch.tick()
 eq(r.status,"P3_PAUSED_UNATTRIBUTED","no bound trade means no unsafe resume")
 eq(x.p3.resumed,0,"cannot resume unverified closed trade")
end
do
 local x,boss,watch,flags,reports,getScheduled=setup()
 eq(watch.start(),true,"first start successful")
 local second,reason=watch.start()
 eq(second,false,"double watch disallowed")
 eq(reason,"WATCHDOG_ALREADY_STARTED","stable double-start reason")
 watch.tick()
 eq(boss.arm(optIn),true,"fully armed before loss of independent monitor readiness")
 flags.monitor=false
 local r=watch.tick()
 eq(r.status,"BLOCKED","external callback cannot forge watchdog readiness")
 eq(x.p3.stopped,true,"P3 queue stopped")
end
-- The continuous scheduler must actually drive polling; fake scheduler's
-- wait terminates via live cancellation before uncontrolled infinite loops.
do
 local x=fixture()
 local boss,err,events,flags=newSupervisor(x)
 local now=200
 local rounds=0
 local scheduled=nil
 local watcher
 local sched={
  spawn=function(fn)scheduled=fn end,
  wait=function(seconds)
   now+=seconds;rounds+=1
   if rounds==5 then watcher.stop() end
  end,
  now=function()return now end,
 }
 watcher=x.watchdog.new(boss,x.p3,x.io,
  {getJobId=function()return x.ctx.job end,
   isLive=function()return true end,
   onStatus=function()end},sched)
 flags.monitor=function()return watcher.isReady()end
 eq(watcher.start(),true,"scheduler attached")
 local ok=pcall(scheduled)
 eq(ok,true,"continuous task catches its own end")
 eq(rounds,5,"continuous scheduler performs bounded poll iterations")
 eq(x.p3.stopped,true,"watchdog task cancels P3 on stop")
end
print("[PASS] continuous real P3→P4 watchdog with automatic closed-window resume:",tests)
print("[PASS] no P3 arm before heartbeat, no double-resume, no Accept/trade/profit")
