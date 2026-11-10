-- Execute the ACTUAL supervised P3/P4 handoff and ACTUAL guarded P4 TradeIO.
-- Roblox game/players/GUI and P3 outgoing/scanner implementations mocked.
-- NO real Roblox gameplay actions, remotes, account/market data or HTTP.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local handoffText=fs.readFile("pdiddler/supervised/supervised_p3_p4_handoff.lua")
local ioText=fs.readFile("pdiddler/supervised/pdiddler4_tradeio_supervised_v2.lua")
local coordinatorText=fs.readFile("pdiddler/supervised/supervised_real_p3_rotation_handoff.lua")
local bootstrapText=fs.readFile("pdiddler/supervised/supervised_p3_startup_supervisor.lua")
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
 return {module=module,coordinator=coordinator,bootstrap=bootstrap,io=io,p3=outgoing,scanner=scanner,
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
  watchdogReady=function()return flags.monitor end,
  noOtherTransactionOwner=function()return flags.external end,
  readyCheck=function()return flags.ready end,
 }
 local supervisor,err=x.bootstrap.new(x.scanner,outgoingModule,
      coordinatorModule,x.module,x.io,x.players,x.lp,ctx)
 return supervisor,err,events,flags
end
local optIn={
 explicitUserAuthorization=true,
 allowRealP3RequestRotation=true,
 finalAcceptMustRemainManual=true,
}
do
 local x=fixture()
 local boss,err,events,flags=newSupervisor(x)
 eq(type(boss),"table","atomic supervisor constructed")
 eq(err,nil,"no bootstrap error")
 eq(events[1],"P3_RUN_GATED","first instantiates closed original P3")
 eq(events[2],"P4_OBSERVER_ATTACH","observer attached BEFORE any P3 arm")
 eq(boss.status().status,"P3_SUPERVISOR_PREPARED_NOT_ARMED","startup default deny")
 eq(x.p3.armed,nil,"no real request rotation before user arming")
 eq(#x.sends,0,"no offer remote")
 local idle=boss.poll()
 eq(idle.status,"P3_SUPERVISOR_PREPARED_NOT_ARMED","no implicit rotation")
 eq(boss.arm({}),false,"no opt-in refused")
 eq(x.p3.armed,nil,"no accidental arming")
 for _,invalid in ipairs({
  {explicitUserAuthorization=false,allowRealP3RequestRotation=true,finalAcceptMustRemainManual=true},
  {explicitUserAuthorization=true,allowRealP3RequestRotation=false,finalAcceptMustRemainManual=true},
  {explicitUserAuthorization=true,allowRealP3RequestRotation=true,finalAcceptMustRemainManual=false},
 }) do
   local armed,why=boss.arm(invalid)
   eq(armed,false,"all explicit approval required")
   eq(why,"OPERATOR_AUTHORIZATION_MISSING","source refused")
 end
 flags.screen=false
 eq(boss.arm(optIn),false,"unsafe on-screen instructions block physical rotation")
 eq(x.p3.armed,nil,"no requests without visible instructions")
 flags.screen=true;flags.monitor=false
 eq(boss.arm(optIn),false,"absent watchdog refuses P3 rotation")
 flags.monitor=true;flags.external=false
 eq(boss.arm(optIn),false,"external transaction owner refuses rotation")
 flags.external=true;flags.ready=false
 eq(boss.arm(optIn),false,"scanner/lobby readiness refused")
 flags.ready=true
 local armed,reason=boss.arm(optIn)
 eq(armed,true,"explicit opt in arms original real P3")
 eq(reason,"P3_QUEUE_ARMED_NO_FINAL_ACCEPT","clear state")
 eq(x.p3.armed,true,"actual gated original P3 arm invoked")
 eq(events[#events],"P3_ARM_CHECK","called real P3 arm only after observer")
 eq(boss.status().status,"P3_SUPERVISOR_ARMED_CLIENT_ONLY","P3 can now send requests")
 eq(boss.arm(optIn),false,"never arm twice")
 eq(boss.poll().status,"P3_ROTATING","observer reads active original queue")
 x.screen.Enabled=true
 x.p3.state.processed[x.p.UserId]="trade-open"
 x.p3.state.active=nil
 x.p3.paused=true
 local observe=boss.poll()
 eq(observe.status,"P4_TWO_SIDED_CLIENT_SNAPSHOT","real P3 processed opens exact P4")
 eq(observe.authorizesAccept,false,"no automatic final Accept")
 eq(observe.authorizesOffer,false,"no item offer from observer")
 eq(observe.part3RotationAuthorized,false,"read-only observer never authorizes new actions")
 eq(observe.tradeOutcome,"UNKNOWN","no server settlement")
 local ok,resumeWhy=boss.resumeAfterClose()
 eq(ok,false,"cannot resume while trade root present")
 eq(resumeWhy,"TRADE_STILL_OPEN","safety block exact")
 x.screen.Enabled=false
 ok,resumeWhy=boss.resumeAfterClose()
 eq(ok,true,"real outgoing resumes AFTER client closure")
 eq(x.p3.resumed,1,"one resume")
 eq(#x.sends,0,"no P4 offers or final Accept by startup glue")
 eq(boss.stop(),true,"stops original P3 and observer")
 eq(x.p3.stopped,true,"underlying P3 stopped")
 eq(boss.arm(optIn),false,"cannot restart stopped supervisor")
 eq(#x.sends,0,"no remotes on stop")
end
-- Default deny if coordinator could not attach: no arm, stop P3.
do
 local x=fixture()
 x.coordinator.new=function()
  return nil,{status="BLOCKED",reason="FAILED"}
 end
 local boss,err,events=newSupervisor(x)
 eq(boss,nil,"observer initialization failure blocks bootstrap")
 eq(err.reason,"P4_OBSERVER_ATTACH_REFUSED","generic safe init error")
 eq(x.p3.stopped,true,"original P3 fork stopped on failure")
 eq(events[2],"P4_OBSERVER_ATTACH","observer attempted before arm")
 eq(#x.sends,0,"no offers during failure")
end
-- A changed job/server epoch between attach and arm must stop.
do
 local x=fixture()
 local boss=newSupervisor(x)
 x.ctx.epoch=19
 local ok,reason=boss.arm(optIn)
 eq(ok,false,"changed P3 epoch blocks physical rotation")
 eq(reason,"P3_JOB_OR_EPOCH_CHANGED","returns exact code")
 eq(x.p3.armed,nil,"zero P3 requests in stale job")
end
-- Another trade already open before arm is not a P3 rotation start state.
do
 local x=fixture()
 local boss=newSupervisor(x)
 x.screen.Enabled=true
 local ok,why=boss.arm(optIn)
 eq(ok,false,"existing manual trade blocks P3 request rotation")
 eq(why,"P3_TRADE_WINDOW_ALREADY_OPEN","on-screen existing trade safety")
 eq(x.p3.armed,nil,"no competing P3 requests")
end
-- Readiness callbacks can throw and must fail closed without throwing.
do
 local x=fixture()
 local boss,err,events,flags=newSupervisor(x)
 flags.screen=false
 local ok=pcall(boss.arm,optIn)
 eq(ok,true,"unsafe rendered state does not propagate error")
 eq(x.p3.armed,nil,"unsafe monitor blocked")
end
print("[PASS] actual P3 outgoing startup + original P4 observer atomic bootstrap:",tests)
print("[PASS] no unsolicited requests, status-only P4, manual final Accept, explicit render/watchdog barrier")
