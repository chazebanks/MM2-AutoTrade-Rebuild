-- Execute actual guarded IO, real P3 coordinator, four-slot planner, and ONE-TAP operator.
-- Roblox game/players/GUI and P3 outgoing/scanner implementations mocked.
-- NO real Roblox gameplay actions, remotes, account/market data or HTTP.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local handoffText=fs.readFile("pdiddler/supervised/supervised_p3_p4_handoff.lua")
local ioText=fs.readFile("pdiddler/supervised/pdiddler4_tradeio_supervised_v2.lua")
local planText=fs.readFile("pdiddler/supervised/supervised_four_slot_operator_plan.lua")
local coordinatorText=fs.readFile("pdiddler/supervised/supervised_real_p3_rotation_handoff.lua")
local operatorText=fs.readFile("pdiddler/supervised/supervised_p3_one_item_operator.lua")
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
 local iomod=luau.load(ioText,{environment=env,injectGlobals=true})()
 local plan=luau.load(planText,{environment=env,injectGlobals=true})()
 local coordinator=luau.load(coordinatorText,{environment=env,injectGlobals=true})()
 local operator=luau.load(operatorText,{environment=env,injectGlobals=true})()
 local gate={}
 local io=iomod.new({resolveOfferEntry=function()return nil end},gate)
 local scanner={state="whitelist",object=p}
 function scanner.isWhitelisted(uid)
  return uid==2 and scanner.state=="whitelist"
 end
 function scanner.getRecord(uid)
  if uid==2 then return {state=scanner.state,player=scanner.object}end
 end
 local outgoing={session=18,paused=true,resumed=0,state={processed={},active=nil}}
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
 return {module=module,plan=plan,coordinator=coordinator,operator=operator,io=io,gate=gate,remote=remote,p3=outgoing,scanner=scanner,
    ctx=ctx,players=players,lp=lp,p=p,pg=pg,screen=screen,
    trade=trade,ours=own,theirs=their,ownAccepted=ownAccepted,
    theirAccepted=theirAccepted,name=name,add=add,sends=sends}
end
local function arm(keys)
 return {armed=true,manualOfferOnly=true,noAutomaticAcceptAcknowledged=true,weaponKeys=keys}
end
local function getBound(x)
 local b,err=x.module.bind(x.scanner,x.p3,x.io,x.players,x.lp,x.ctx)
 eq(b~=nil,true,"requires valid original P3/P4 bound session "..tostring(err and err.reason))
 return b
end
local function simulateOffer(x,handler)
 x.remote.FireServer=function(_,key,category)
  table.insert(x.sends,{key,category})
  if handler then handler(key,category,#x.sends)
  else x.add(x.ours,#x.sends,key,1) end
 end
end
local function run(x,keys,wait)
 local b=getBound(x)
 local approval=arm(keys)
 return x.plan.run(b,x.io,x.gate,approval,{wait=wait or function()end}),approval,b
end
local function owned(raw,name,page,qty)
 return {items={{id=raw,cat="Weapons",name=name,qty=qty or 1,
  page=page or "godly",type="Gun"}},
  rawOwned=qty or 1,unmapped=0,badQty=0}
end
local function fixturePilot(options)
 options=options or {}
 local x=fixture()
 x.safe=true
 x.altExact=true
 x.guideSafe=true
 x.reads=0
 x.scanner.getOwnInventory=function()
  x.reads+=1
  if options.beforeInventory then options.beforeInventory(x) end
  return options.inventory or owned("Iceblaster","Iceblaster","godly")
 end
 x.p3.state.processed={}
 x.p3.paused=true
 local manager,why=x.coordinator.new(x.scanner,x.p3,x.module,x.io,
  x.players,x.lp,{getJobId=x.ctx.getJobId,getP3Session=x.ctx.getP3Session})
 eq(type(manager),"table","real coordinator created: "..tostring(why and why.reason))
 x.p3.state.processed[2]="trade-open"
 eq(manager.poll().status,"P4_TWO_SIDED_CLIENT_SNAPSHOT",
   "real exact-P3 client session attached")
 local cfg={
  allowOneItemPilot=true,manualOfferOnly=true,
  noAutomaticAcceptAcknowledged=true,approvedRawKey="Iceblaster",
  approvedDisplayName="Iceblaster",approvedChromaFlag=false,
 }
 for k,v in pairs(options.cfg or {}) do cfg[k]=v end
 local ctx={
  isSafe=function()return x.safe end,
  altStillExact=function()return x.altExact end,
  showItemStep=function(raw,shown,chroma)
   return x.guideSafe and raw==cfg.approvedRawKey
      and shown==cfg.approvedDisplayName
      and chroma==cfg.approvedChromaFlag
  end,
  wait=function(seconds)
   if options.onWait then options.onWait(x) end
  end,
 }
 local pilot,reason=x.operator.new(
  {currentBoundReadOnly=function()return manager.currentBoundReadOnly()end},
  x.io,x.gate,x.plan,x.scanner,cfg,ctx)
 return x,pilot,reason,manager,cfg
end
do
 local x,pilot=fixturePilot()
 simulateOffer(x)
 eq(type(pilot),"table","one-item real P3 operator available")
 eq(pilot.preview().status,"READY_FOR_HUMAN_TAP","visible correct P4 session ready")
 eq(pilot.execute(false).reason,"PHYSICAL_APPROVAL_TAP_REQUIRED","no physical tap cannot offer")
 eq(#x.sends,0,"no OfferItem before human tap")
 eq(x.reads,0,"no speculative own inventory remote before tap")
 local r=pilot.execute(true)
 eq(r.status,"CLIENT_MANUAL_PLAN_VISIBLE_UNATTRIBUTED","real P3 one physical approved item")
 eq(r.offerAttempts,1,"one outbound physical attempt only")
 eq(r.clientVisibleAddedSlots,1,"confirmed original guarded GUI one slot")
 eq(x.sends[1][1],"Iceblaster","exact own client raw key, not display alias")
 eq(r.authorizesAccept,false,"final Accept still forbidden")
 eq(r.serverCompletionProven,false,"no settlement authority")
 eq(r.mayReportProfit,false,"no profit claim")
 eq(r.maySendDiscordWebhook,false,"no Discord")
 eq(x.reads,1,"one current own client GetProfileData read after physical tap")
 eq(pilot.execute(true).reason,"ONE_ITEM_APPROVAL_ALREADY_SPENT","second tap cannot duplicate")
 eq(#x.sends,1,"exactly one send total")
 eq(x.gate.checkOutbound,nil,"physical gate cleared after execution")
end
do
 local x,pilot=fixturePilot({inventory=owned("Other","Other","godly")})
 simulateOffer(x)
 local r=pilot.execute(true)
 eq(r.reason,"CURRENT_OWN_WEAPON_IDENTITY_NOT_PROVEN","wrong raw inventory blocks")
 eq(#x.sends,0,"no send with wrong own raw key")
 eq(pilot.execute(true).status,"BLOCKED","no retry after failed one-shot")
end
for _,inv in ipairs({
 owned("Iceblaster","Iceblaster","godly",0),
 owned("Iceblaster","WrongDisplay","godly"),
 owned("Iceblaster","Iceblaster","ancient"),
}) do
 local x,pilot=fixturePilot({inventory=inv})
 simulateOffer(x)
 local r=pilot.execute(true)
 if inv.items[1].page=="ancient" then
  -- Still a qualifying Ancient; the raw key is what matters here.
  eq(r.status,"CLIENT_MANUAL_PLAN_VISIBLE_UNATTRIBUTED",
    "legitimate Ancient page still accepted with matching raw key")
 else
  eq(r.reason,"CURRENT_OWN_WEAPON_IDENTITY_NOT_PROVEN","invalid owned identity denied")
  eq(#x.sends,0,"bad ownership never sends")
 end
end
for _,over in ipairs({
 {approvedRawKey="Gingerscope"},
 {approvedDisplayName="Gingerscope"},
 {approvedRawKey="Ginger Scope"},
 {approvedChromaFlag="false"},
 {allowOneItemPilot=false},
 {manualOfferOnly=false},
 {noAutomaticAcceptAcknowledged=false},
}) do
 local x,pilot,reason=fixturePilot({cfg=over})
 eq(pilot,nil,"selection denied before operator creation")
 eq(reason.status,"BLOCKED","no approved pilot on unsafe config")
 eq(#x.sends,0,"bad config zero remotes")
end
do
 local x,pilot=fixturePilot()
 x.altExact=false
 eq(pilot.preview().status,"WAITING","wrong alt identity not ready")
 eq(pilot.execute(true).status,"BLOCKED","wrong alt never offers")
 eq(#x.sends,0,"no wrong-partner outgoing")
end
do
 local x,pilot=fixturePilot()
 x.theirAccepted.Visible=true
 eq(pilot.preview().status,"WAITING","accepted GUI not ready for operator")
 eq(pilot.execute(true).status,"BLOCKED","accepted GUI never offered")
 eq(#x.sends,0,"no send while accepted")
end
do
 local x,pilot=fixturePilot({beforeInventory=function(y)
  y.screen.Enabled=false
 end})
 eq(pilot.execute(true).reason,"P3_BOUND_TRADE_CHANGED_AFTER_OWN_READ",
   "trade close during RPC refuses physical send")
 eq(#x.sends,0,"trade close mid-own-read zero offer remotes")
end
do
 local x,pilot=fixturePilot({beforeInventory=function(y)
  y.ctx.epoch=99
 end})
 eq(pilot.execute(true).reason,"P3_BOUND_TRADE_CHANGED_AFTER_OWN_READ",
   "P3 epoch changed during RPC refuses send")
 eq(#x.sends,0,"P3 epoch changed zero sends")
end
do
 local x,pilot=fixturePilot()
 x.safe=false
 eq(pilot.execute(true).status,"BLOCKED","unsafe onscreen runtime blocks")
 eq(#x.sends,0,"no send without safe panel")
end
do
 local x,pilot=fixturePilot()
 x.guideSafe=false
 simulateOffer(x)
 local r=pilot.execute(true)
 eq(r.reason,"ONSCREEN_STEP_UNAVAILABLE","cannot offer without current visible step")
 eq(#x.sends,0,"on-screen guidance failure zero remote")
end
do
 local x,pilot=fixturePilot({onWait=function(y)
  y.safe=false
 end})
 simulateOffer(x)
 local r=pilot.execute(true)
 eq(r.status,"STOPPED","unsafe GUI replication wait stops after attempt")
 eq(r.offerAttempts,1,"at most one attempt after unsafe change")
 eq(#x.sends,1,"never re-sends after uncertain wait")
 eq(pilot.execute(true).reason,"ONE_ITEM_APPROVAL_ALREADY_SPENT","no unsafe retry")
end
do
 local x,pilot=fixturePilot({cfg={
  approvedRawKey="ChromaFang",approvedDisplayName="Fang",
  approvedChromaFlag=true,
 },inventory=owned("ChromaFang","Chroma Fang","chroma")})
 simulateOffer(x,function(raw,cat,n)
  x.add(x.ours,n,"Fang",1,true)
 end)
 local r=pilot.execute(true)
 eq(r.status,"CLIENT_MANUAL_PLAN_VISIBLE_UNATTRIBUTED",
   "exact Chroma raw-key / base display / true tag reconciled")
 eq(#x.sends,1,"one Chroma remote only")
end
print("[PASS] original protected P3 lease + current own weapon + one physical human-tap:",tests)
print("[PASS] no pre-tap remote, no final Accept, unsafe conditions fail closed")
