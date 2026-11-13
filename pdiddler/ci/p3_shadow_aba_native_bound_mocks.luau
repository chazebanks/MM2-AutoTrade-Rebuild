-- SHADOW non-sending client ABA lease runs against ACTUAL protected P3/P4 bound capture.
-- Roblox game/players/GUI and P3 outgoing/scanner implementations mocked.
-- NO real Roblox gameplay actions, remotes, account/market data or HTTP.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local handoffText=fs.readFile("pdiddler/supervised/supervised_p3_p4_handoff.lua")
local ioText=fs.readFile("pdiddler/supervised/pdiddler4_tradeio_supervised_v2.lua")
local planText=fs.readFile("pdiddler/supervised/supervised_four_slot_operator_plan.lua")
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
 local gate={}
 local io=iomod.new({resolveOfferEntry=function()return nil end},gate)
 local scanner={state="whitelist",object=p}
 function scanner.isWhitelisted(uid)
  return uid==2 and scanner.state=="whitelist"
 end
 function scanner.getRecord(uid)
  if uid==2 then return {state=scanner.state,player=scanner.object}end
 end
 local outgoing={session=18,paused=true,resumed=0}
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
 return {module=module,plan=plan,io=io,gate=gate,remote=remote,p3=outgoing,scanner=scanner,
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

local leaseText=fs.readFile("pdiddler/intelligence_lab/p3_shadow_aba_offer_lease.lua")
local lease=luau.load(leaseText,{injectGlobals=true})()
local function tracker(x)
 local b=getBound(x)
 local w,initial=lease.new(b,{
  root=function()return x.io.trade()end,
  live=function()return x.p3.isPaused() and x.p.Parent==x.players
       and x.scanner.state=="whitelist" end,
 })
 eq(initial.status,"OBSERVING","source-bound new lease starts observing")
 return w,b
end
local function prepare(w)
 eq(w.poll().status,"OBSERVING","first protected native P4 read")
 eq(w.prepareShadow().status,"PREPARED",
    "two consecutive real protected P3/P4 reads produce hypothetical preview")
 eq(w.recheckShadow().reason,"CLIENT_SNAPSHOT_SAME_SHADOW_ONLY_NEVER_SEND",
    "even healthy preview can NEVER send")
end
do
 local x=fixture()
 x.add(x.ours,1,"Iceblaster",1)
 local w=tracker(x)
 prepare(w)
 x.add(x.theirs,1,"TestLaser",1)
 eq(w.poll().status,"STALE",
    "real bound capture ALT added one physical slot invalidates shadow")
 eq(w.state().observedGuiMutationCount,1,"ALT addition counted from original protected P4 GUI")
 x.theirs.children["NewItem1"]=nil
 eq(w.recheckShadow().status,"STALE",
    "ABA returned to identical offer but prepared shadow remains revoked")
 eq(#x.sends,0,"no OfferItem calls whatsoever")
 eq(w.state().authorizesOffer,false,"never authorize offer")
 eq(w.state().authorizesAccept,false,"never authorize final Accept")
end
do
 local x=fixture()
 x.add(x.theirs,1,"TestLaser",2)
 local w=tracker(x)
 prepare(w)
 local q=x.theirs:FindFirstChild("NewItem1")
    :FindFirstChild("Container"):FindFirstChild("Amount")
 q.Text="x3"
 eq(w.recheckShadow().status,"STALE","protected stacked quantity mutation invalidates")
 eq(w.state().observedGuiMutationCount,1,"stack changes counted")
 eq(#x.sends,0,"no trade remote")
end
do
 local x=fixture()
 x.add(x.theirs,1,"TestLaser",1)
 local w=tracker(x)
 prepare(w)
 x.theirs:FindFirstChild("NewItem1"):FindFirstChild("ItemName")
   :FindFirstChild("Label").Text="TestMortal"
 eq(w.recheckShadow().status,"STALE",
    "same slot count and quantity but weapon display mutation revokes")
 eq(#x.sends,0,"no OfferItem")
end
do
 local x=fixture()
 local w=tracker(x)
 prepare(w)
 eq(w.observeClientUpdateCallback().status,"STALE",
    "even an unauthenticated UpdateTrade signal can conservatively revoke")
 eq(w.state().callbackSessionAssociationProven,false,
    "never claim proven callback session binding")
 eq(#x.sends,0,"no trade remote")
end
do
 local x=fixture()
 x.add(x.theirs,1,"TestLaser",1)
 local w=tracker(x)
 prepare(w)
 x.theirs:FindFirstChild("NewItem1"):FindFirstChild("Container")
   :FindFirstChild("Amount").Text="x?"
 eq(w.recheckShadow().status,"STALE",
    "original protected P4 rejects malformed stack and shadow revokes")
 eq(#x.sends,0,"no trade remote")
end
do
 local x=fixture()
 local w=tracker(x)
 prepare(w)
 x.screen.Enabled=false
 eq(w.recheckShadow().status,"STALE","trade root loss revokes hypothetical plan")
 eq(#x.sends,0,"not a real outgoing trading controller")
end
do
 local x=fixture()
 local w=tracker(x)
 prepare(w)
 x.p.Parent=nil
 eq(w.recheckShadow().status,"STALE","protected exact partner loss revokes")
 eq(#x.sends,0,"no trade remote")
end
do
 local x=fixture()
 local w=tracker(x)
 prepare(w)
 x.p3.paused=false
 eq(w.recheckShadow().status,"STALE","protected P3 pause loss revokes")
 eq(#x.sends,0,"no trade remote")
end
do
 local x=fixture()
 local w=tracker(x)
 prepare(w)
 x.ctx.epoch=19
 eq(w.recheckShadow().status,"STALE","P3 epoch change invalidates original session")
 eq(#x.sends,0,"no trade remote")
end
do
 local x=fixture()
 local w=tracker(x)
 prepare(w)
 x.theirAccepted.Visible=true
 eq(w.recheckShadow().status,"STALE","ALT accept indicator revokes shadow")
 eq(#x.sends,0,"no trade remote")
end
do
 local x=fixture()
 local w=tracker(x)
 prepare(w)
 x.add(x.theirs,1,"TestLaser",1)
 local r=w.poll()
 eq(r.status,"STALE","actual bound mismatch")
 eq(r.serverRevisionAuthenticated,false,"not server revision proof")
 eq(r.serverCompletionProven,false,"not completed trade proof")
 eq(r.mayUseForStrategyLearning,false,"not learner input")
 eq(r.tradeOutcome,"UNKNOWN","not settlement")
 eq(r.observedGuiMutationCount,1,"bounded sanitized count")
 for k,v in pairs(r) do
  if type(v)=="string" then
   eq(v:find("TestLaser",1,true),nil,"no raw item leaked in shadow receipt "..k)
  end
 end
end
print("P3_SHADOW_ABA_REAL_BOUND_INTEGRATION_PASS",tests)
