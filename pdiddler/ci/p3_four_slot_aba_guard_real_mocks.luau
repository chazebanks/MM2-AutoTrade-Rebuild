-- Opt-in ABA pre-send regression against ACTUAL protected TradeIO and bound P3/P4.
-- This is offline only, no live MM2, no deployment and no automatic Accept.
-- Roblox game/players/GUI and P3 outgoing/scanner implementations mocked.
-- NO real Roblox gameplay actions, remotes, account/market data or HTTP.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local handoffText=fs.readFile("pdiddler/supervised/supervised_p3_p4_handoff.lua")
local ioText=fs.readFile("pdiddler/supervised/pdiddler4_tradeio_supervised_v2.lua")
local planText=fs.readFile("pdiddler/supervised/supervised_four_slot_operator_plan_aba_draft.lua")
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

local shadowCode=fs.readFile("pdiddler/intelligence_lab/p3_shadow_aba_offer_lease.lua")
local shadow=luau.load(shadowCode,{environment={math=math},injectGlobals=true})()
local function fixtureGuard(two)
 local x=fixture()
 local b=getBound(x)
 local approval=arm(two or {"Iceblaster","Batwing"})
 local witness
 local built=0
 local opts={
  wait=function()end,experimentalABAShadowRequired=true,
  onShadowPrepared=function()return true end,
  makeShadowWitness=function(realBound)
   eq(realBound==b,true,"witness uses the exact P3/P4 bound lease")
   built+=1
   local w,first=shadow.new(realBound,{
     root=function()return x.io.trade()end,
     live=function()return x.p3.isPaused() and x.p.Parent==x.players
       and x.scanner.state=="whitelist" end,
   })
   eq(first.status,"OBSERVING","only new hypothetical shadow lease created")
   witness=w
   return w
  end,
 }
 simulateOffer(x)
 return {
  x=x,b=b,approval=approval,opts=opts,
  run=function()return x.plan.run(b,x.io,x.gate,approval,opts) end,
  witness=function()return witness end,
  built=function()return built end,
 }
end

-- This test MUST be RED against old physical-slot planner: GUI A->B->A is
-- indistinguishable at the next snapshot unless the optional new lease was
-- prepared after item one and observed B in the intermediate interval.
do
 local z=fixtureGuard()
 local x=z.x
 local seen=false
 z.opts.onShadowPrepared=function(w,afterItem)
  eq(afterItem,1,"witness prepared after first confirmed physical slot")
  eq(w.state().status,"PREPARED","two stable snapshots before ALT mutation")
  seen=true
  return true
 end
 z.opts.onBeforeItem=function(idx)
  if idx==2 then
   eq(seen,true,"must not reach second step without shadow prepared")
   x.add(x.theirs,1,"ALTTransient",1)
   eq(z.witness().poll().status,"STALE","observer sees intermediate offer B")
   x.theirs.children["NewItem1"]=nil -- back to A before dispatch
  end
  return true
 end
 local r=z.run()
 eq(r.status,"STOPPED","ABA transition stops guarded multi-item plan")
 eq(r.reason,"ABA_SHADOW_STALE_BEFORE_NEXT_OFFER","precise static no-replan reason")
 eq(r.offerAttempts,1,"only first attempt was made")
 eq(r.clientVisibleAddedSlots,1,"only first GUI item remains")
 eq(#x.sends,1,"no second real protected OfferItem attempt")
 eq(z.built(),1,"guard created once from exact P3/P4 lease")
 eq(z.approval._consumed,true,"human approval spent even on aborted second step")
 eq(x.gate.checkOutbound,nil,"no lingering outbound gate")
end

-- Callback-only invalidation is conservative and blocks without pretending
-- callback was authenticated to a server trade revision.
do
 local z=fixtureGuard()
 z.opts.onBeforeItem=function(idx)
  if idx==2 then
   local r=z.witness().observeClientUpdateCallback()
   eq(r.status,"STALE","unattributed callback revokes hypothetical response")
   eq(r.callbackSessionAssociationProven,false,"no callback session proof")
  end
  return true
 end
 local r=z.run()
 eq(r.reason,"ABA_SHADOW_STALE_BEFORE_NEXT_OFFER","callback blocks second send")
 eq(#z.x.sends,1,"no duplicate remote on callback")
end

-- Stable P3/P4 same session permits the original explicitly selected second
-- item as a guarded, human-approved offer, NOT final Accept or trade authority.
do
 local z=fixtureGuard()
 local r=z.run()
 eq(r.status,"CLIENT_MANUAL_PLAN_VISIBLE_UNATTRIBUTED","unmutated optional shadow may advance")
 eq(r.offerAttempts,2,"two explicitly approved offer attempts")
 eq(#z.x.sends,2,"two protected physical offers only under stable snapshots")
 eq(z.built(),1,"one witness for one inter-item boundary")
 eq(r.authorizesAccept,false,"final Accept stays impossible")
 eq(r.tradeOutcome,"UNKNOWN","never settlement")
end

-- Explicit opt-in requires an actual original-bound witness. Absence cannot
-- silently fall back to the original snapshot-only multi-item controller.
do
 local z=fixtureGuard()
 z.opts.makeShadowWitness=nil
 local r=z.run()
 eq(r.status,"BLOCKED","missing ABA witness denies approval")
 eq(r.reason,"ABA_SHADOW_REQUIRED_FOR_MULTI_ITEM","no silent fallback")
 eq(#z.x.sends,0,"zero items sent without required source")
end

-- Shadow opt-in also requires an attached observer contract; a factory
-- alone cannot catch event history without active pumping of client snapshots.
do
 local z=fixtureGuard()
 z.opts.onShadowPrepared=nil
 local r=z.run()
 eq(r.status,"BLOCKED","required client observer attachment unavailable")
 eq(r.reason,"ABA_SHADOW_REQUIRED_FOR_MULTI_ITEM","preflight refuses missing observer hook")
 eq(#z.x.sends,0,"nothing offered when event observation is not attached")
end

-- If ALT mutates DURING observer attachment, the prepared shadow is revoked
-- before the second item guide is ever displayed.
do
 local z=fixtureGuard()
 z.opts.onShadowPrepared=function(w,index)
  eq(index,1,"first item already confirmed before shadow")
  local x=z.x
  x.add(x.theirs,1,"ALTTransient",1)
  eq(w.poll().status,"STALE","ABA intermediate state observed in attachment callback")
  x.theirs.children["NewItem1"]=nil
  return true
 end
 local r=z.run()
 eq(r.status,"STOPPED","stale at witness-preparation boundary")
 eq(r.reason,"ABA_SHADOW_PREPARATION_FAILED","first observed B permanently revokes intent")
 eq(r.offerAttempts,1,"at most first item attempted")
 eq(#z.x.sends,1,"at most first protected remote sent")
end

-- Four human-approved physical slots require a freshly prepared witness
-- after each known placement (never reuse a stale pre-own-offer witness).
do
 local z=fixtureGuard({"Iceblaster","Batwing","Laser","Luger"})
 local r=z.run()
 eq(r.status,"CLIENT_MANUAL_PLAN_VISIBLE_UNATTRIBUTED",
  "4 slots from new guarded candidate only after 3 fresh stable witnesses")
 eq(z.built(),3,"new protected P3/P4 shadow rearmed after item 1/2/3")
 eq(#z.x.sends,4,"4 user-approved distinct physical items only")
 eq(r.authorizesAccept,false,"4-item guided code still does not auto Accept")
end

-- Rejection of false/forged authority flags, malformed schema and source
-- throw, all after exactly one offered item and before the next.
for _,mode in ipairs({"BAD_REPORT","THROW_POLL","BAD_METHODS","PREPARE_THROW"}) do
 local z=fixtureGuard()
 if mode=="BAD_METHODS" then
   z.opts.makeShadowWitness=function()return {poll=function()return {}end}end
 else
  z.opts.makeShadowWitness=function()
   local x=z.x
   if mode=="BAD_REPORT" then
    local r={status="OBSERVING",schema="evil",authorizesOffer=true}
    return {poll=function()return r end,prepareShadow=function()return r end,
       recheckShadow=function()return r end}
   elseif mode=="THROW_POLL" then
    return {poll=function()error("TEST_THROW")end,
       prepareShadow=function()return {}end,
       recheckShadow=function()return {}end}
   end
   return {poll=function()return {
       schema="gingerscope-p3-client-shadow-aba-lease-v1",status="OBSERVING",
       authorizesOffer=false,authorizesAccept=false,
       shadowOnly=true,serverRevisionAuthenticated=false,
       tradeOutcome="UNKNOWN"}end,
       prepareShadow=function()error("TEST_PREPARE_THROW")end,
       recheckShadow=function()return {}end}
  end
 end
 local r=z.run()
 eq(r.status,"STOPPED","malformed witness is non-continuable "..mode)
 eq(r.reason,"ABA_SHADOW_PREPARATION_FAILED","static denial "..mode)
 eq(#z.x.sends,1,"only first item attempted "..mode)
end

-- ABA introduced in late physical IO after earlier step check: gate must
-- recheck witness at the LAST guarded outbound boundary.
do
 local z=fixtureGuard()
 local original=z.x.io.offerItem
 z.x.io.offerItem=function(item)
  if item.id=="Batwing" then
   local x=z.x
   x.add(x.theirs,1,"ALTTransient",1)
   eq(z.witness().poll().status,"STALE","late ALT mutation client-observed")
   x.theirs.children["NewItem1"]=nil
  end
  return original(item)
 end
 local r=z.run()
 eq(r.status,"STOPPED","late ABA rejected at protected IO gate")
 eq(r.reason,"GUARDED_OFFER_REMOTE_DENIED_OR_UNCONFIRMED","remote denied after preflight")
 eq(#z.x.sends,1,"no second physical FireServer call after late ABA")
 eq(z.x.gate.checkOutbound,nil,"gate cleared after late denial")
end

-- Same displayed label, changed stacks or Chroma is still a mutation.
for _,change in ipairs({"STACK","CHROMA","LABEL","OWN"}) do
 local z=fixtureGuard()
 local x=z.x
 x.add(x.theirs,1,"ALTCheap",1)
 z.opts.onBeforeItem=function(idx)
  if idx==2 then
   if change=="OWN" then
    x.ours:FindFirstChild("NewItem1"):FindFirstChild("ItemName")
       :FindFirstChild("Label").Text="WrongMain"
   else
    local slot=x.theirs:FindFirstChild("NewItem1")
    if change=="STACK" then
     slot:FindFirstChild("Container"):FindFirstChild("Amount").Text="x2"
    elseif change=="CHROMA" then
     slot:put(node("Frame","Tags")):put(node("Frame","Chroma"))
    else
     slot:FindFirstChild("ItemName"):FindFirstChild("Label").Text="DifferentAlt"
    end
   end
   eq(z.witness().poll().status,"STALE","mutation observed in protected GUI "..change)
  end
  return true
 end
 local r=z.run()
 eq(r.status,"STOPPED","mutated party stops next item "..change)
 eq(#x.sends,1,"mutated party never sends second "..change)
end

-- A callback cannot create authority; protect Gingerscope even if chosen.
do
 local z=fixtureGuard({"Gingerscope","Batwing"})
 local r=z.run()
 eq(r.status,"BLOCKED","outbound protected item stays denied")
 eq(#z.x.sends,0,"no protected item sent")
end

print("P3_FOUR_SLOT_ABA_GUARD_REAL_BOUND_PASS",tests)
