-- Execute ACTUAL new MAIN auto native (32k), original protected P4 IO +
-- original P3/P4 bridge + exact PR240 ABA plan and PR238 client shadow.
-- P3 request transport/bootstrap are injected mocks (per-epoch API),
-- so this is NOT proof of real repeated MM2 networking/Delta compatibility.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local native=fs.readFile("pdiddler/system1/SYSTEM1_MAIN_AUTO_FOUR_TRADES_NATIVE.lua")
local sources={
 geometry=fs.readFile("pdiddler/new_part4/stage100_screen_prompt_overlay.lua"),
 tradeio=fs.readFile("pdiddler/supervised/pdiddler4_tradeio_supervised_v2.lua"),
 bridge=fs.readFile("pdiddler/supervised/supervised_p3_p4_handoff.lua"),
 choice=fs.readFile("pdiddler/supervised/p3_one_item_owned_selection.lua"),
 controller=fs.readFile("pdiddler/system1/system1_main_auto_failstop_controller.lua"),
 plan=fs.readFile("pdiddler/ci/fixtures/SYSTEM1_FROZEN_PR240_ABA_PLAN.lua"),
 shadow=fs.readFile("pdiddler/ci/fixtures/SYSTEM1_FROZEN_PR238_SHADOW_LEASE.lua"),
}
local BOOT=[[
-- Fake only the P3 factory transport and epoch readiness. Original bridge
-- will still bind the REAL protected P4 trade root and inspect actual GUI.
local M={}
function M.new(scanner,outgoing,coordinator,bridge,io,players,lp,ctx)
 local E=getgenv()
 E.PDIDDLER_OUTGOING_SESSION=(E.PDIDDLER_OUTGOING_SESSION or 0)+1
 local epoch=E.PDIDDLER_OUTGOING_SESSION
 local armed=false
 local stopped=false
 local once=false
 local fakeOutgoing={
  session=epoch,
  isPaused=function()return armed and not stopped and io.trade()~=nil end,
  resume=function()return true,"mock-resume"end,
 }
 local supervisor={}
 function supervisor.status()
  return {status=armed and "P3_SUPERVISOR_ARMED_CLIENT_ONLY"
     or "P3_SUPERVISOR_PREPARED_NOT_ARMED"}
 end
 function supervisor.arm(approval)
  if stopped or once or approval.explicitUserAuthorization~=true
    or approval.allowRealP3RequestRotation~=true
    or approval.finalAcceptMustRemainManual~=true then
    return false,"mock-unapproved" end
  once=true;armed=true
  E.PDIDDLER_TEST_P3_EPOCH_REQUESTS=
   (E.PDIDDLER_TEST_P3_EPOCH_REQUESTS or 0)+1
  return true,"fresh-request-one"
 end
 function supervisor.isP3Paused()
  return fakeOutgoing.isPaused()
 end
 function supervisor.currentBoundReadOnly()
  if stopped or not supervisor.isP3Paused() then return nil end
  if E.PDIDDLER_TEST_PENDING_HANDOFF and
     E.PDIDDLER_TEST_PENDING_HANDOFF>0 then
   E.PDIDDLER_TEST_PENDING_HANDOFF-=1
   return nil -- original P3 processed event not published yet
  end
  local bound=bridge.bind(scanner,fakeOutgoing,io,players,lp,{
    targetName="venossgaming90190",
    getJobId=ctx.getJobId,
    getP3Session=ctx.getP3Session,
  })
  if not bound then return nil end
  return bound,{
    status="P3_BOUND_CANDIDATE_READ_ONLY",
    authorizesOffer=false,authorizesAccept=false,
  }
 end
 function supervisor.stop()
  if not stopped then
    stopped=true
    if E.PDIDDLER_OUTGOING_SESSION==epoch then
      E.PDIDDLER_OUTGOING_SESSION=epoch+1
    end
  end
  return true
 end
 return supervisor,nil
end
return M
]]
local WATCHDOG=[[
local M={}
function M.new(supervisor,p3,io,ctx,scheduler)
 local running=false
 return {
  start=function()running=true;return true,"MOCK_HEARTBEAT"end,
  isReady=function()return running end,
  stop=function()running=false;return true end,
 }
end
return M
]]
local SCANNER=[[
local M={}
local function alt()
 return game:GetService("Players"):FindFirstChild("venossgaming90190")
end
function M.isWhitelisted(uid)
 local x=alt()
 return x~=nil and uid==x.UserId
end
function M.getRecord(uid)
 local x=alt()
 if x and uid==x.UserId then return {player=x,state="whitelist"} end
end
function M.getWhitelist()
 local x=alt()
 return x and {x} or {}
end
function M.hasPendingWork()return false end
function M.setRequestState()end
function M.setStatus()end
function M.getOwnInventory()
 return {rawOwned=4,unmapped=0,badQty=0,items={
  {id="Iceblaster",name="Iceblaster",cat="Weapons",qty=1,
    page="godly",type="Gun"},
  {id="Batwing",name="Batwing",cat="Weapons",qty=1,
    page="ancient",type="Knife"},
  {id="Frostsaber",name="Frostsaber",cat="Weapons",qty=1,
    page="godly",type="Knife"},
  {id="Bioblade",name="Bioblade",cat="Weapons",qty=1,
    page="godly",type="Knife"},
 }}
end
return M
]]
local P3_PLACEHOLDER=[[
-- Actual ORIGINAL one-attempt P3 is separately frozen exact-diff audited.
-- Here its network send is represented by the bootstrap.arm mock only.
return {run=function(scanner,opts)return {}end}
]]
local COORD_PLACEHOLDER=[[
-- Actual ORIGINAL coordinator source is independently tested on main.
-- This native test checks its protected bridge, not request transport.
return {new=function()return {}end}
]]
local tests=0
local function eq(a,b,label)
 tests+=1
 assert(a==b,tostring(label)..": "..tostring(a).." != "..tostring(b))
end
local function event()
 local hooks={}
 local self={}
 function self:Connect(fn)
  local h={fn=fn,active=true}
  hooks[#hooks+1]=h
  return {Disconnect=function()h.active=false end}
 end
 function self:Fire()
  for _,h in ipairs(hooks) do if h.active then h.fn()end end
 end
 return self
end
local function vec(x,y)return {X=x,Y=y}end
local function node(class,name)
 local n={ClassName=class,Name=name or class,
  Visible=true,Enabled=true,Active=true,Text="",children={},
  attributes={},AbsolutePosition=vec(10,10),AbsoluteSize=vec(20,15),
  Activated=event(),MouseButton1Click=event()}
 function n:IsA(k)
  return self.ClassName==k or
   (k=="GuiObject" and
    (self.ClassName=="Frame" or self.ClassName=="TextButton"
    or self.ClassName=="TextLabel" or
    self.ClassName=="ScrollingFrame"))
 end
 function n:FindFirstChild(k,recursive)
  local v=self.children[k]
  if v then return v end
  if recursive then
   for _,child in pairs(self.children) do
    local got=child:FindFirstChild(k,true)
    if got then return got end
   end
  end
 end
 function n:put(child)
  child.Parent=self
  self.children[child.Name]=child
  return child
 end
 function n:GetDescendants()
  local result={}
  local function walk(c)
   for _,x in pairs(c.children)do
    result[#result+1]=x;walk(x)
   end
  end
  walk(self)
  return result
 end
 function n:GetAttribute(key)return self.attributes[key]end
 function n:GetFullName()return self.Name end
 function n:Destroy()
  if self.Parent then self.Parent.children[self.Name]=nil end
  self.Parent=nil;self.Visible=false
 end
 function n:Activate()
  self.Activated:Fire()
  if self.Name=="ActionButton" and self.Parent and
    self.Parent.Parent then
   local slot=self.Parent.Parent
   slot.Visible=false
   if slot.Parent and type(slot.Parent.onTestItemRemoval)=="function" then
    slot.Parent:onTestItemRemoval(slot)
   end
  end
  return true
 end
 return n
end
local function fixture(opts)
 opts=opts or {}
 local now=0
 local tasks={}
 local copied={}
 local gameRead={}
 local sent={};local declineCount=0
 local body=node("PlayerGui","PlayerGui")
 local screen=body:put(node("ScreenGui","TradeGUI"))
 screen.Enabled=false
 local container=screen:put(node("Frame","Container"))
 local root=container:put(node("Frame","Trade"))
 root.AbsolutePosition=vec(470,150)
 root.AbsoluteSize=vec(370,415)
 local mainPanel=root:put(node("Frame","YourOffer"))
 local own=mainPanel:put(node("Frame","Container"))
 mainPanel:put(node("Frame","Accepted")).Visible=false
 local altPanel=root:put(node("Frame","TheirOffer"))
 local their=altPanel:put(node("Frame","Container"))
 altPanel:put(node("Frame","Accepted")).Visible=false
 -- Native-only witness: emulate MM2 compacting MAIN NewItem2 to NewItem1
 -- after a valid own withdraw. Original protected P4 IO remains unchanged.
 if opts.ownRemovalMutation then
  function own:onTestItemRemoval(removed)
   self.children[removed.Name]=nil
   local survivors={}
   for _,v in pairs(self.children) do
    if v.Visible and v.Name:match("^NewItem%d$") then
     survivors[#survivors+1]=v
    end
   end
   table.sort(survivors,function(a,b)return a.Name<b.Name end)
   for _,v in ipairs(survivors) do self.children[v.Name]=nil end
   for i,v in ipairs(survivors) do
    -- Protected original removeOne removes highest index first. Model a
    -- subsequent MM2 GUI layout renumber of the *retained* item in this test.
    local position=opts.ownRemovalMutation=="reindex" and
      #survivors==1 and 2 or i
    v.Name="NewItem"..position;self.children[v.Name]=v
   end
   if #survivors==1 and opts.ownRemovalMutation~="reindex" then
    local slot=survivors[1]
    if opts.ownRemovalMutation=="replacement" then
     slot:FindFirstChild("ItemName"):FindFirstChild("Label").Text="UNAUTHORIZED_SWAP"
    elseif opts.ownRemovalMutation=="quantity" then
     slot:FindFirstChild("Container"):FindFirstChild("Amount").Text="x2"
    elseif opts.ownRemovalMutation=="chroma" then
     slot:put(node("Frame","Tags")):put(node("Frame","Chroma"))
    end
   end
  end
 end
 local partner=altPanel:put(node("TextLabel","Username"))
 partner.Text="venossgaming90190"
 local players={}
 local main={Name="MAIN_TEST",UserId=1,Parent=players}
 local alt={Name="venossgaming90190",DisplayName="ALT",UserId=2,Parent=players}
 players.LocalPlayer=main
 function players:FindFirstChild(name)
  if name==alt.Name and alt.Parent==players then return alt end
 end
 function players:GetPlayerByUserId(uid)
  if uid==alt.UserId and alt.Parent==players then return alt end
  if uid==main.UserId then return main end
 end
 function players:GetPlayers()return {main,alt}end
 function main:FindFirstChildOfClass(k)
  if k=="PlayerGui" then return body end
 end
 local RS=node("ReplicatedStorage","ReplicatedStorage")
 local tradeFolder=RS:put(node("Folder","Trade"))
 local offerRemote=tradeFolder:put(node("RemoteEvent","OfferItem"))
 local declineRemote=tradeFolder:put(node("RemoteEvent","DeclineTrade"))
 local remotes=RS:put(node("Folder","Remotes"))
 local inv=remotes:put(node("Folder","Inventory"))
 local rf=inv:put(node("RemoteFunction","GetProfileData"))
 function rf:InvokeServer()
  return {Weapons={Owned={Iceblaster=1,Batwing=1,Frostsaber=1,Bioblade=1}}}
 end
 local database=RS:put(node("Folder","Database"))
 local syncNode=database:put(node("ModuleScript","Sync"))
 local catalog={
  Weapons={
   Iceblaster={ItemName="Iceblaster",Rarity="Godly",ItemType="Gun"},
   Batwing={ItemName="Batwing",Rarity="Ancient",ItemType="Knife"},
   Frostsaber={ItemName="Frostsaber",Rarity="Godly",ItemType="Knife"},
   Bioblade={ItemName="Bioblade",Rarity="Godly",ItemType="Knife"},
  },
 }
 local services={
  Players=players,Workspace={
   CurrentCamera={ViewportSize=vec(1024,768)}},
  HttpService={
   GenerateGUID=function()return "00000000-1111-2222-3333-444444444444"end,
   JSONEncode=function(_,obj)return serde.encode("json",obj)end,
  },
  ReplicatedStorage=RS,
  GuiService={GetGuiInset=function()return vec(0,0)end},
  VirtualInputManager={SendMouseButtonEvent=function()end},
 }
 local requested=0
 local function add(side,index,name,qty,chroma)
  local s=side:put(node("Frame","NewItem"..index))
  local nameBox=s:put(node("Frame","ItemName"))
  nameBox:put(node("TextLabel","Label")).Text=name
  local box=s:put(node("Frame","Container"))
  box:put(node("TextLabel","Amount")).Text="x"..tostring(qty or 1)
  box:put(node("TextButton","ActionButton"))
  if chroma then s:put(node("Frame","Tags")):put(node("Frame","Chroma")) end
  return s
 end
 function offerRemote:FireServer(raw,category)
  assert(category=="Weapons","weapons-only original IO request")
  sent[#sent+1]={raw=raw,category=category}
  local index=1
  while index<=4 do
   local existing=own:FindFirstChild("NewItem"..index)
   if not existing or not existing.Visible then break end
   index+=1
  end
  assert(index<=4,"physical slot cap")
  add(own,index,raw)
 end
 function declineRemote:FireServer()
  declineCount+=1
  screen.Enabled=false
 end
 local game={
  PlaceId=142823291,JobId="SYSTEM1_AUTO_MOCK_JOB",
  GetService=function(_,name)return services[name]end,
  HttpGet=function(_,url)
   gameRead[#gameRead+1]=url
   if url:find("pdiddler4_tradeio_supervised_v2.lua",1,true)
    then return sources.tradeio end
   if url:find("supervised_p3_p4_handoff.lua",1,true)
    then return sources.bridge end
   if url:find("stage100_screen_prompt_overlay.lua",1,true)
    then return sources.geometry end
   if url:find("supervised_real_p3_rotation_handoff.lua",1,true)
    then return COORD_PLACEHOLDER end
   if url:find("supervised_p3_startup_supervisor.lua",1,true)
    then return BOOT end
   if url:find("supervised_p3_continuous_watchdog.lua",1,true)
    then return WATCHDOG end
   if url:find("pdiddler3_scanner_MODULE_v6_5_PART4_STATUS_BRIDGE.lua",1,true)
    then return SCANNER end
   if url:find("p3_one_item_owned_selection.lua",1,true)
    then return sources.choice end
   if url:find("pdiddler3_outgoing_single_send_epoch.lua",1,true)
    then return P3_PLACEHOLDER end
   if url:find("supervised_four_slot_operator_plan_aba_draft.lua",1,true)
    then return sources.plan end
   if url:find("p3_shadow_aba_offer_lease.lua",1,true)
    then return sources.shadow end
   if url:find("system1_main_auto_failstop_controller.lua",1,true)
    then return sources.controller end
   error("UNRECOGNIZED_PINNED_URL "..url)
  end,
 }
 local created={}
 local instance={}
 function instance.new(class)
  local n=node(class)
  created[#created+1]=n
  return n
 end
 local e={}
 e.E={PDIDDLER_TEST_PENDING_HANDOFF=opts.handoffDelays or 0}
 e.game=game
 e.getgenv=function()return e.E end
 e.loadstring=function(src)
  return luau.load(src,{environment=e,injectGlobals=true})
 end
 e.Instance=instance
 e.Enum={
  ZIndexBehavior={Sibling="Sibling"},
  TextXAlignment={Left="Left"},
  TextYAlignment={Top="Top"},
  Font={GothamSemibold="GothamSemibold",GothamBold="GothamBold"},
 }
 e.Color3={fromRGB=function(...)return {...}end}
 e.UDim={new=function(...)return {...}end}
 e.UDim2={fromOffset=function(...)return {...}end}
 e.os={clock=function()return now end}
 e.require=function(x)
  if x==syncNode then return catalog end
  error("unknown dependency")
 end
 if not opts.clipboardUnavailable then
  e.setclipboard=function(txt)copied[#copied+1]=txt end
 end
 local taskApi={}
 taskApi.spawn=function(fn)
  local co=coroutine.create(fn)
  tasks[#tasks+1]=co
  return co
 end
 taskApi.wait=function(seconds)
  return coroutine.yield(seconds or 0)
 end
 e.task=taskApi
 local abaPhase=0
 local function tickTasks()
  now+=0.12
  -- Adversarial R4 ONLY: ALT A->B->A between first and second approved
  -- MAIN item. Resume the registered original shadow observer BEFORE
  -- the main controller may dispatch item 2, to prove observed ABA abort.
  local injectionTick=false
  if opts.injectRound4ABA and abaPhase<2 then
   local runner=e.E.PDIDDLER_SYSTEM1_MAIN_AUTO_RUNNER
   local progress=runner and runner.status()
   if progress and progress.round==4 and
      progress.phase=="MAIN_OFFERING" and #sent==2 and #tasks>=2 then
    if abaPhase==0 then
     add(their,1,"ALT_UNEXPECTED_TRANSIENT")
     abaPhase=1
     injectionTick=true
    else
     their.children["NewItem1"]=nil
     abaPhase=2
    end
   end
  end
  local snapshot={}
  for _,t in ipairs(tasks)do snapshot[#snapshot+1]=t end
  if injectionTick then
   for i=1,math.floor(#snapshot/2) do
    local j=#snapshot-i+1
    snapshot[i],snapshot[j]=snapshot[j],snapshot[i]
   end
  end
  for _,taskCo in ipairs(snapshot)do
   if coroutine.status(taskCo)~="dead" then
    local ok,err=coroutine.resume(taskCo)
    assert(ok,"native coroutine fault "..tostring(err))
   end
  end
  local newer={}
  for _,co in ipairs(tasks) do
   if coroutine.status(co)~="dead" then newer[#newer+1]=co end
  end
  tasks=newer
 end
 local script=luau.load(native,{environment=e,injectGlobals=true})
 local runner=script()
 local function named(name)
  for _,x in ipairs(created) do
   if x.Name==name then return x end
  end
 end
 local function state()
  return runner and runner.status() or {status="NO_RUNNER"}
 end
 local function setAlt(n,qty,chroma)
  for i=1,4 do their.children["NewItem"..i]=nil end
  for i=1,n do
   add(their,i,"ALT_ITEM_"..tostring(i),qty,chroma)
  end
 end
 local function open()
  for i=1,4 do
   own.children["NewItem"..i]=nil
   their.children["NewItem"..i]=nil
  end
  screen.Enabled=true
 end
 return {
  runner=runner,e=e,screen=screen,root=root,own=own,their=their,
  alt=alt,partner=partner,sent=sent,requests=function()
   return e.E.PDIDDLER_TEST_P3_EPOCH_REQUESTS or 0 end,
  declines=function()return declineCount end,
  copies=copied,tick=tickTasks,named=named,state=state,
  setAlt=setAlt,open=open,gameRead=gameRead,
  prematurelyClose=function()screen.Enabled=false end,
 }
end
local function untilState(x,phase,limit)
 for _=1,(limit or 300) do
  if x.state().phase==phase then return true end
  x.tick()
 end
 return false
end
-- AUTO MAIN happy path: operator physically chooses 2 items and ARMs ONCE.
-- Four distinct *mock P3* request epochs -> original protected P4 offers,
-- original own GUI removals -> original remote Declines, automatically.
do
 local x=fixture()
 eq(type(x.runner),"table","native auto runner starts with no trading")
 eq(#x.gameRead,12,"12 frozen dependency modules loaded")
 eq(x.state().phase,"SELECT_TWO_OWN_ITEMS","default closed until selection")
 eq(x.requests(),0,"no P3 before physical ARM")
 eq(#x.sent,0,"no offers before physical ARM")
 eq(x.declines(),0,"no declines before physical ARM")
 for _=1,20 do x.tick() end
 local one=x.named("OwnedChoice_1")
 local two=x.named("OwnedChoice_2")
 eq(type(one),"table","first real owned option button built")
 eq(type(two),"table","second real owned option button built")
 one.Activated:Fire()
 two.Activated:Fire()
 x.tick()
 local arm=x.named("ArmAllFour")
 eq(arm.Visible,true,"ARM four button only with two distinct selected items")
 eq(x.named("AutoInstructions").Text:find("4 automatic requests",1,true)~=nil,true,
  "MAIN GUI discloses budget of automatic requests before ARM")
 eq(x.named("AutoInstructions").Text:find("NEVER final Accept",1,true)~=nil,true,
  "GUI discloses automatic operation cannot final Accept")
 arm.Activated:Fire()
 local function waitRound(n)
  local seen=false
  for _=1,120 do
   x.tick()
   local st=x.state()
   if st.phase=="WAIT_OPEN" and st.round==n then
    seen=true;break
   end
   assert(st.phase~="STOPPED","unexpected STOP before round "..n.." "..tostring(st.reason))
  end
  eq(seen,true,"new request epoch "..n.." armed")
  eq(x.requests(),n,"new P3 mocked request sequence "..n)
  x.open() -- ALT accepts the incoming REQUEST; no final Accept
 end
 for n=1,4 do
  waitRound(n)
  local completed=false
  local changed={}
  for i=1,280 do
   local st=x.state()
   if st.phase=="STOPPED" then
    error("NEW NATIVE FAILED "..tostring(n).." "..tostring(st.reason))
   end
   if st.completedRounds>=n then completed=true;break end
   if st.phase=="ALT_ADD" then
    x.setAlt(n==4 and 2 or 1)
   elseif st.phase=="ALT_REMOVE_ONE" then
    x.setAlt(1)
   elseif st.phase=="ALT_REMOVE_ALL" then
    x.setAlt(0)
   end
   x.tick()
  end
  eq(completed,true,"MAIN auto completed round "..n)
  eq(x.declines(),n,"MAIN original DeclineTrade remote once per round")
 end
 eq(x.state().phase,"DONE","all four trade windows completed")
 eq(x.requests(),4,"four fresh P3 mock epochs")
 eq(#x.sent,3,"three original guarded OfferItem FireServer calls")
 eq(x.sent[1].category,"Weapons","raw item offer category verified")
 eq(x.state().actions.removalsAttempted,3,
  "three MAIN original removeOne GUI clicks")
 eq(x.state().actions.clientClosedWindows,4,"all original GUI windows closed")
 eq(x.state().authorizesAccept,false,"never grants final Accept")
 eq(x.state().serverCompletionProven,false,"client close not server settlement")
 eq(x.state().tradeOutcome,"UNKNOWN","no fabricated completed trade")
 eq(#x.copies>=1,true,"MAIN automatically copied final report")
 local r=serde.decode("json",x.copies[#x.copies])
 eq(r.status,"CLIENT_TEST_SEQUENCE_COMPLETE","copied final completion")
 eq(r.completedRounds,4,"four outcomes saved in clipboard")
 eq(r.runNonce,"00000000-1111-2222-3333-444444444444",
  "run nonce in final report")
 eq(r.finalAcceptEverAttempted,false,"no Accept even in copied report")
 eq(r.verifiedCompletedTrades,0,"no authenticated settlement")
 eq(x.e.E.PDIDDLER_SYSTEM1_MAIN_AUTO_USED_JOB,
   "SYSTEM1_AUTO_MOCK_JOB","terminal job spent, no restart")
end
-- Fatal wrong partner: stop immediately, copy exact phase/reason,
-- zero false completed trades and no resending/rejoining.
do
 local x=fixture()
 for _=1,20 do x.tick() end
 x.named("OwnedChoice_1").Activated:Fire()
 x.named("OwnedChoice_2").Activated:Fire()
 x.tick()
 x.named("ArmAllFour").Activated:Fire()
 eq(untilState(x,"WAIT_OPEN"),true,"armed before wrong-partner scenario")
 x.partner.Text="IMPOSTER"
 x.open()
 eq(untilState(x,"STOPPED",50),true,"unexpected partner terminal")
 eq(#x.copies>=1,true,"immediate ERROR clipboard")
 local receipt=serde.decode("json",x.copies[#x.copies])
 eq(receipt.status,"STOPPED","stop receipt")
 eq(receipt.serverCompletionProven,false,"still no fabricated settlement")
 eq(receipt.round,1,"error identifies first trade")
 eq(receipt.reason,"TRADE_PARTNER_NOT_CONSENTING_ALT",
  "clipboard identifies exact wrong-partner root-cause")
 eq(x.requests(),1,"no next outgoing request after fault")
 eq(#x.sent,0,"no item offered to wrong partner")
 eq(x.declines(),0,"no blind decline action after wrong partner")
end
-- Normal GUI-vs-original-P3 processed callback ordering: visible root
-- before a safely bound original P4 lease must NEVER dispatch an offer and
-- must get a small read-only grace, not a false wrong-partner STOP.
do
 local x=fixture({handoffDelays=2})
 for _=1,20 do x.tick()end
 x.named("OwnedChoice_1").Activated:Fire()
 x.named("OwnedChoice_2").Activated:Fire()
 x.tick()
 x.named("ArmAllFour").Activated:Fire()
 eq(untilState(x,"WAIT_OPEN",50),true,"P3 armed for delayed read-only handoff")
 x.open()
 local eventually=false
 for _=1,50 do
  x.tick()
  if x.state().phase=="CHECK_EMPTY" or
    x.state().phase=="MAIN_DECLINING" then
   eventually=true
   break
  end
 end
 eq(eventually,true,"bounded two-frame P3 callback lag reconciled")
 eq(x.state().status~="STOPPED",true,"normal handoff delay does not false stop")
 eq(#x.sent,0,"no item offer during handoff reconciliation")
end
-- If the protected original bridge NEVER binds, stop and put precise root
-- cause in clipboard; no request #2 and no blind Decline/Offer.
do
 local x=fixture({handoffDelays=999})
 for _=1,20 do x.tick()end
 x.named("OwnedChoice_1").Activated:Fire()
 x.named("OwnedChoice_2").Activated:Fire()
 x.tick()
 x.named("ArmAllFour").Activated:Fire()
 eq(untilState(x,"WAIT_OPEN",50),true,"P3 first request armed")
 x.open()
 eq(untilState(x,"STOPPED",60),true,"missing protected binding is terminal")
 eq(#x.copies>=1,true,"handoff failure auto copied")
 local r=serde.decode("json",x.copies[#x.copies])
 eq(r.reason,"ORIGINAL_P3_P4_CLIENT_SNAPSHOT_REJECTED",
  "precise original P3-to-P4 unbound client error")
 eq(r.round,1,"failure round exact")
 eq(#x.sent,0,"zero physical offers on unbound original handoff")
 eq(x.requests(),1,"no second automatic request after unbound error")
end

-- Real fork of PR240 pre-send safety integration under active native
-- script: after one approved MAIN weapon in trade4, ALT changes its
-- physical GUI offer then restores it. No second MAIN OfferItem may fire,
-- and clipboard MUST name that precise client-observed shadow failure.
do
 local x=fixture({injectRound4ABA=true})
 for _=1,20 do x.tick()end
 x.named("OwnedChoice_1").Activated:Fire()
 x.named("OwnedChoice_2").Activated:Fire()
 x.tick()
 x.named("ArmAllFour").Activated:Fire()
 for round=1,4 do
  eq(untilState(x,"WAIT_OPEN",100),true,
    "native ABA: new outgoing request epoch "..round)
  x.open()
  local reached=false
  for _=1,350 do
   local st=x.state()
   if st.phase=="STOPPED" then
    eq(round,4,"native ABA must only interrupt fourth round")
    reached=true
    break
   end
   if st.completedRounds>=round then
    reached=true
    break
   end
   if st.phase=="ALT_ADD" then
    x.setAlt(round==4 and 2 or 1)
   elseif st.phase=="ALT_REMOVE_ONE" then
    x.setAlt(1)
   elseif st.phase=="ALT_REMOVE_ALL" then
    x.setAlt(0)
   end
   x.tick()
  end
  eq(reached,true,"native ABA round reached terminal or close "..round)
 end
 local result=x.state()
 eq(result.phase,"STOPPED","observed inter-item ABA stops all MAIN actions")
 eq(result.round,4,"ABA precisely attributed to fourth trade")
 eq(result.completedRounds,3,"only 3 previously closed test windows")
 eq(result.reason,"SHADOW_OBSERVER_STALE_DURING_PLACEMENT",
  "shadow reason retained, not generic plan failure")
 eq(#x.sent,2,"R3 item + first R4 item, NO second R4 item sent")
 eq(x.requests(),4,"no fifth P3 request after observed ABA")
 eq(x.declines(),3,"no blind R4 decline after observed ABA")
 eq(#x.copies>=1,true,"ABA STOP sends JSON immediately to clipboard")
 local receipt=serde.decode("json",x.copies[#x.copies])
 eq(receipt.reason,"SHADOW_OBSERVER_STALE_DURING_PLACEMENT",
    "exact first ABA fault is in clipboard report")
 eq(receipt.possibleSideEffect,true,"prior physical item may be present")
 eq(receipt.finalAcceptEverAttempted,false,"no final accept")
end

-- Consolidated System 1 adversarial acceptance: STOP outcomes are isolated
-- fake-Roblox runs. Do not combine these terminal faults on real ALT/iPad:
-- first unexpected error ends that session by design.
local function armedTest(opts)
 local x=fixture(opts)
 for _=1,20 do x.tick()end
 local a=x.named("OwnedChoice_1")
 local b=x.named("OwnedChoice_2")
 assert(a and b,"two exact owned selection choices required")
 a.Activated:Fire()
 b.Activated:Fire()
 x.tick()
 if opts and opts.adaptive then
  eq(x.named("ArmFiveAdaptive").Visible,true,
    "fifth-round ARM shown only after two preapproved own items")
  x.named("ArmFiveAdaptive").Activated:Fire()
 else
  x.named("ArmAllFour").Activated:Fire()
 end
 eq(untilState(x,"WAIT_OPEN",60),true,"fresh MAIN auto request is armed")
 return x
end
local function untilRound(x,number,phase,limit)
 for _=1,(limit or 180) do
  local status=x.state()
  if status.round==number and status.phase==phase then return true end
  if status.phase=="STOPPED" or status.phase=="DONE" then return false end
  x.tick()
 end
 return false
end
local function copiedStop(x,expectedReason,round)
 eq(x.state().status,"STOPPED","terminal fault outcome")
 eq(x.state().reason,expectedReason,"controller first error preserved")
 eq(x.state().round,round,"exact offending trade round")
 eq(#x.copies>=1,true,"JSON copied on first unsafe transition")
 local r=serde.decode("json",x.copies[#x.copies])
 eq(r.reason,expectedReason,"clipboard first root cause")
 eq(r.round,round,"clipboard round number")
 eq(r.authorizesAccept,false,"clipboard never authorizes Accept")
 eq(r.tradeOutcome,"UNKNOWN","no fabricated trade settlement")
 eq(r.finalAcceptEverAttempted,false,"zero auto final Accept")
 return r
end
local function finishRoundOne(x)
 x.open()
 eq(untilRound(x,2,"WAIT_OPEN",150),true,
  "round1 auto-declined then issued round2 fresh request")
 eq(x.requests(),2,"two distinct P3 mock request epochs")
 eq(x.declines(),1,"one guarded auto decline")
end

-- B01: In round2 after expected normal window OPEN, ALT unexpectedly
-- closes the trade. No silent skip to round3, no blind follow-up request.
do
 local x=armedTest()
 finishRoundOne(x)
 x.open()
 eq(untilRound(x,2,"ALT_ADD",80),true,"ALT add phase reached")
 x.prematurelyClose()
 eq(untilState(x,"STOPPED",30),true,"unexpected ALT close immediately stops MAIN")
 copiedStop(x,"TRADE_CLOSED_UNEXPECTEDLY",2)
 eq(x.requests(),2,"cannot send round3 request after early close")
 eq(#x.sent,0,"zero MAIN protected item offers after early close")
 eq(x.declines(),1,"cannot blind-decline the already missing trade root")
end

-- B03: ALT adds THREE physical items in one-item round, not a stacked x3
-- in one slot. Client scope violation: stop, log, never start another round.
do
 local x=armedTest()
 finishRoundOne(x)
 x.open()
 eq(untilRound(x,2,"ALT_ADD",80),true,"ALT add phase for extra-slot test")
 x.setAlt(3)
 eq(untilState(x,"STOPPED",25),true,"extra ALT slots cause immediate stop")
 copiedStop(x,"ALT_ADDED_UNEXPECTED_EXTRA_SLOTS",2)
 eq(x.requests(),2,"no round3 request after unapproved extra slots")
 eq(x.declines(),1,"no unapproved auto decline during unsafe offer")
end

-- B04: Test unexpected accepted-state indicator in native original P4
-- bridge entirely OFFLINE. The human test MUST NEVER press final Accept.
do
 local x=armedTest()
 x.open()
 eq(untilRound(x,1,"CHECK_EMPTY",20),true,"fresh P4 GUI read is armed")
 x.root:FindFirstChild("TheirOffer"):FindFirstChild("Accepted").Visible=true
 eq(untilState(x,"STOPPED",30),true,"unsafe accepted state stops MAIN")
 copiedStop(x,"UNEXPECTED_ACCEPTED_STATE",1)
 eq(x.requests(),1,"no second P3 request after accepted ambiguity")
 eq(x.declines(),0,"no script decline with unsafe accepted GUI")
end

-- B05: ALT player removed from actual Players membership during WAIT_OPEN.
-- No cached display-name-only substitution and no more requests.
do
 local x=armedTest()
 x.alt.Parent=nil
 eq(untilState(x,"STOPPED",20),true,"ALT departure stops")
 copiedStop(x,"ALT_LEFT_OR_REPLACED",1)
 eq(x.requests(),1,"no continued P3 rotation after ALT departed")
 eq(#x.sent,0,"no item sent after ALT departed")
end

-- B02: ALT does not accept first incoming request. Bounded 30 second
-- request expiry and no repeated outgoing send in this test epoch.
do
 local x=armedTest()
 eq(untilState(x,"STOPPED",350),true,"30s pending request expires")
 copiedStop(x,"TIMEOUT_WAIT_OPEN",1)
 eq(x.requests(),1,"one only P3 request epoch before timeout")
 eq(x.declines(),0,"never decline absent trade window")
 eq(#x.sent,0,"never send item without a protected trade window")
end

-- B14: iPad clipboard support can be missing/throw. It must NOT hide
-- the failure: preserve identical sanitized JSON in environment fallback.
do
 local x=armedTest({clipboardUnavailable=true})
 x.alt.Parent=nil
 eq(untilState(x,"STOPPED",20),true,"clipboard-unsupported stop is terminal")
 eq(#x.copies,0,"clipboard API truly unavailable in native harness")
 local json=x.e.E.PDIDDLER_SYSTEM1_MAIN_AUTO_LAST_JSON
 eq(type(json),"string","same error preserved in native env fallback")
 local r=serde.decode("json",json)
 eq(r.reason,"ALT_LEFT_OR_REPLACED","precise reason survives clipboard failure")
 eq(r.round,1,"fallback keeps exact failing round")
 eq(r.authorizesAccept,false,"fallback never claims Accept authority")
 eq(x.requests(),1,"clipboard failure cannot restart P3 sender")
end

-- A02/A03: A STACK of quantity 2 is ONE physical ALT slot, and Chroma
-- metadata must be observed without promoting an unverified raw ID.
-- These legitimate display variations continue, rather than triggering
-- a mistaken extra-slot error.
do
 local x=armedTest()
 finishRoundOne(x)
 x.open()
 eq(untilRound(x,2,"ALT_ADD",80),true,"round2 waiting for stacked chroma ALT")
 x.setAlt(1,2,true)
 eq(untilRound(x,2,"ALT_REMOVE_ALL",40),true,
   "ALT x2 chroma one physical slot accepted as normal")
 x.setAlt(0)
 eq(untilRound(x,3,"WAIT_OPEN",120),true,
   "MAIN auto declines ALT stacked-chroma round then starts third request")
 eq(x.declines(),2,"two expected auto declines before round3")
 eq(x.requests(),3,"continued fresh P3 request after valid stacked Chroma")
 eq(#x.sent,0,"MAIN did not send any item in stacked ALT-only round")
 eq(x.state().authorizesAccept,false,"still no final Accept")
end

-- A05: the new optional fifth trade does an actual revision response,
-- not just detects a change. Original protected TradeIO physically offers
-- one MAIN item, ALT replaces its offer with a different cheap item, MAIN
-- withdraws the first item while the ALT item is present, waits until ALT
-- clears, then uses a fresh protected plan for second preapproved MAIN key.
-- ALT responds again, removes, MAIN withdraws second and declines.
do
 local x=armedTest({adaptive=true})
 for round=1,5 do
  if round>1 then
   eq(untilRound(x,round,"WAIT_OPEN",180),true,
      "adaptive new epoch "..round)
  end
  x.open()
  local endRound=false
  for i=1,400 do
   local st=x.state()
   assert(st.phase~="STOPPED",
      "adaptive native unexpectedly stopped "..tostring(st.reason))
   if st.completedRounds>=round then endRound=true;break end
   if st.phase=="ALT_ADD" then
    x.setAlt(round==4 and 2 or 1)
   elseif st.phase=="ALT_REVISE" then
    x.setAlt(1)
    local box=x.their:FindFirstChild("NewItem1")
    box:FindFirstChild("ItemName"):FindFirstChild("Label").Text=
      "ALT_DIFFERENT_WEAPON"
   elseif st.phase=="ALT_CLEAR_FOR_REOFFER" then
    x.setAlt(0)
   elseif st.phase=="ALT_READD" then
    x.setAlt(1)
   elseif st.phase=="ALT_REMOVE_ONE" then
    x.setAlt(1)
   elseif st.phase=="ALT_REMOVE_ALL" then
    x.setAlt(0)
   end
   x.tick()
  end
  eq(endRound,true,"adaptive round completed "..round)
 end
 local r=x.state()
 eq(r.phase,"DONE","native full fifth-round adaptive MAIN finished")
 eq(r.completedRounds,5,"5 separate client windows")
 eq(r.actions.requestsStarted,5,"5 P3 mock session epochs")
 eq(r.actions.offersAttempted,5,"3 original + 2 adaptive physical offers")
 eq(r.actions.offersClientVisible,5,"5 reconciled original P4 offer slots")
 eq(r.actions.removalsAttempted,5,"3 original + 2 adaptive removals")
 eq(r.actions.declinesAttempted,5,"5 original guarded decline remotes")
 eq(r.actions.clientClosedWindows,5,"5 client roots closed")
 eq(r.actions.altRevisionsObserved,1,"one stable replaced ALT offer")
 eq(r.actions.adaptiveReoffersAttempted,1,"one different MAIN reoffer")
 eq(x.declines(),5,"five original protected DeclineTrade remotes")
 eq(#x.sent,5,"five original protected OfferItem remote calls")
 eq(x.sent[4].raw~=x.sent[5].raw,true,
    "adaptive first and second MAIN weapon must be distinct")
 eq(x.requests(),5,"no sixth P3 request")
 eq(#x.copies>=1,true,"single terminal auto copy after five")
 local receipt=serde.decode("json",x.copies[#x.copies])
 eq(receipt.reason,"ALL_FIVE_CLIENT_ROUNDS_VERIFIED",
    "five-round receipt distinguished from old four-round")
 eq(receipt.actions.altRevisionsObserved,1,"clipboard revision evidence")
 eq(receipt.actions.adaptiveReoffersAttempted,1,"clipboard new offer count")
 eq(receipt.finalAcceptEverAttempted,false,"no auto final Accept")
 eq(receipt.serverCompletionProven,false,"client-only no settlement proof")
end

-- B18 adaptive-specific: ALT's first revision was confirmed,
-- but it CHANGES AGAIN immediately before the protected MAIN withdrawal.
-- No withdrawal may be attempted from the old proposal; stop and copy the
-- exact first error without requesting a sixth trade or final Accept.
do
 local x=armedTest({adaptive=true})
 for round=1,4 do
  if round>1 then
   eq(untilRound(x,round,"WAIT_OPEN",180),true,
    "adversarial adaptive setup request "..round)
  end
  x.open()
  local completed=false
  for _=1,300 do
   local st=x.state()
   if st.completedRounds>=round then completed=true;break end
   assert(st.phase~="STOPPED",
    "unexpected setup failure "..tostring(st.reason))
   if st.phase=="ALT_ADD" then
    x.setAlt(round==4 and 2 or 1)
   elseif st.phase=="ALT_REMOVE_ONE" then
    x.setAlt(1)
   elseif st.phase=="ALT_REMOVE_ALL" then
    x.setAlt(0)
   end
   x.tick()
  end
  eq(completed,true,"adversarial setup completes earlier round "..round)
 end
 eq(untilRound(x,5,"WAIT_OPEN",180),true,
  "fifth P3 request starts after 4 verified closes")
 x.open()
 eq(untilRound(x,5,"ALT_ADD",90),true,"MAIN first adaptive item offered")
 x.setAlt(1)
 eq(untilRound(x,5,"ALT_REVISE",30),true,"ALT first offer established")
 x.setAlt(1)
 x.their:FindFirstChild("NewItem1"):FindFirstChild("ItemName")
   :FindFirstChild("Label").Text="ALT_CONFIRMED_REPLACEMENT"
 eq(untilRound(x,5,"MAIN_WITHDRAWING",35),true,
  "stable replacement authorized MAIN withdrawal stage")
 -- Invalidated before the click: same single slot, different candidate.
 x.setAlt(1)
 x.their:FindFirstChild("NewItem1"):FindFirstChild("ItemName")
   :FindFirstChild("Label").Text="ALT_REPLACED_AGAIN"
 eq(untilState(x,"STOPPED",25),true,
  "second ALT replacement stops stale MAIN removal")
 local r=copiedStop(x,"MAIN_WITHDRAW_PRECONDITION_FAILED",5)
 eq(r.completedRounds,4,"four previous windows remain verified")
 eq(r.actions.altRevisionsObserved,1,"one stable first ALT replacement")
 eq(r.actions.offersAttempted,4,"3 original + 1 first adaptive offer")
 eq(r.actions.adaptiveReoffersAttempted,0,
  "NO second MAIN offer after ALT mutated before withdrawal")
 eq(r.actions.removalsAttempted,3,
  "no fifth-round item withdrawal occurred from invalidated snapshot")
 eq(x.requests(),5,"no sixth request after adaptive failure")
 eq(x.declines(),4,"no premature fifth decline after ALT changed again")
 eq(#x.sent,4,"only earlier approved protected outbound offers")
 eq(r.finalAcceptEverAttempted,false,"no final accept on unsafe ALT revision")
end

-- Real-world round-4 STOP receipt: MM2 may reindex the surviving
-- NewItem2 -> NewItem1 after deleting the first ALT item. The survivor
-- must match a UNIQUE earlier client-visible item, including quantity
-- and Chroma marker, not necessarily the same GUI *position*.
-- No ALT raw item identity or server transfer is claimed.
local function testAltRemovalSurvivor(kind)
 local x=armedTest({adaptive=true})
 local reachedRound4=false
 local failSeen=false
 for round=1,5 do
  if round>1 then
   eq(untilRound(x,round,"WAIT_OPEN",180),true,
    "fresh test round "..round.." for "..kind)
  end
  x.open()
  local completed=false
  for _=1,460 do
   local st=x.state()
   if st.status=="STOPPED" then
    failSeen=true
    break
   end
   if st.completedRounds>=round then
    completed=true
    break
   end
   if round==4 and st.phase=="ALT_REMOVE_ONE" then
    reachedRound4=true
    x.setAlt(1,kind=="quantity" and 2 or 1,kind=="chroma")
    local slot=x.their:FindFirstChild("NewItem1")
    if kind=="reindexed" or kind=="unmoved_second" then
     slot:FindFirstChild("ItemName"):FindFirstChild("Label").Text=
       "ALT_ITEM_2"
    elseif kind=="replacement" then
     slot:FindFirstChild("ItemName"):FindFirstChild("Label").Text=
       "ALT_ITEM_3"
    end
    if kind=="unmoved_second" then
     x.their.children.NewItem1=nil
     slot.Name="NewItem2"
     x.their.children.NewItem2=slot
    end
   elseif st.phase=="ALT_ADD" then
    x.setAlt(round==4 and 2 or 1)
    if round==4 and kind=="duplicate" then
     x.their:FindFirstChild("NewItem2"):FindFirstChild("ItemName")
      :FindFirstChild("Label").Text="ALT_ITEM_1"
    end
   elseif st.phase=="ALT_REVISE" then
    x.setAlt(1)
    x.their:FindFirstChild("NewItem1"):FindFirstChild("ItemName")
     :FindFirstChild("Label").Text="ALT_ITEM_CHANGED_AFTER_ADD"
   elseif st.phase=="ALT_CLEAR_FOR_REOFFER" then
    x.setAlt(0)
   elseif st.phase=="ALT_READD" then
    x.setAlt(1)
   elseif st.phase=="ALT_REMOVE_ONE" then
    x.setAlt(1)
   elseif st.phase=="ALT_REMOVE_ALL" then
    x.setAlt(0)
   end
   x.tick()
  end
  if failSeen then break end
  eq(completed,true,"round completed under "..kind.." at "..round)
 end
 eq(reachedRound4,true,"actually exercised round4 ALT 2->1 "..kind)
 if kind=="reindexed" or kind=="unmoved_second" then
  local r=x.state()
  eq(r.status,"CLIENT_TEST_SEQUENCE_COMPLETE",
    "valid survivor must pass complete five-round path "..kind)
  eq(r.completedRounds,5,"five confirmed client windows "..kind)
  eq(r.actions.requestsStarted,5,"fifth epoch continued "..kind)
  eq(r.actions.altRemovalSlotReindexesObserved,
    kind=="reindexed" and 1 or 0,
    "reindex counted ONLY for actual changed GUI slot "..kind)
  eq(r.actions.adaptiveReoffersAttempted,1,
    "fifth round adaptation unaffected by previous ALT removal "..kind)
  eq(#x.copies>=1,true,"completion copied automatically "..kind)
  local json=serde.decode("json",x.copies[#x.copies])
  eq(json.actions.altRemovalSlotReindexesObserved,
    kind=="reindexed" and 1 or 0,
    "sanitized clipboard includes renumber diagnostic "..kind)
 else
  eq(failSeen,true,"unsafe ALT item change must STOP "..kind)
  local why=kind=="duplicate" and "ALT_REMOVAL_SURVIVOR_AMBIGUOUS"
    or "ALT_REPLACED_ITEM_INSTEAD_OF_REMOVING"
  local r=copiedStop(x,why,4)
  eq(r.completedRounds,3,"only three closed windows on fault "..kind)
  eq(r.actions.requestsStarted,4,"no fifth request after fault "..kind)
  eq(r.actions.removalsAttempted,1,
    "no MAIN own removal after ALT uncertain survivor "..kind)
  eq(r.actions.declinesAttempted,3,
    "no blind fourth decline after ALT uncertain survivor "..kind)
  eq(r.actions.adaptiveReoffersAttempted,0,
    "no adaptive item reoffer after round4 fault "..kind)
  eq(r.actions.altRemovalSlotReindexesObserved,0,
    "unverified survivor is NOT counted as compaction "..kind)
  eq(x.declines(),3,"original guarded decline not fired on unsafe offer "..kind)
  eq(x.requests(),4,"no continuation to fifth epoch "..kind)
 end
end
for _,kind in ipairs({
 "reindexed","unmoved_second","replacement",
 "quantity","chroma","duplicate"
}) do
 testAltRemovalSurvivor(kind)
end

-- MAIN withdrawal GUI slot-index compaction: independent of ALT correction.
local function testOwnRemovalIndex(kind)
 local x=fixture({ownRemovalMutation=kind})
 for _=1,20 do x.tick()end
 x.named("OwnedChoice_1").Activated:Fire()
 x.named("OwnedChoice_2").Activated:Fire()
 x.tick()
 x.named("ArmAllFour").Activated:Fire()
 for n=1,4 do
  eq(untilRound(x,n,"WAIT_OPEN",180),true,"own compaction request "..n.." "..kind)
  x.open()
  local endRound=false
  for _=1,330 do
   local st=x.state()
   if st.phase=="STOPPED" then break end
   if st.completedRounds>=n then endRound=true;break end
   if st.phase=="ALT_ADD" then
    x.setAlt(n==4 and 2 or 1)
   elseif st.phase=="ALT_REMOVE_ONE" then
    x.setAlt(1)
   elseif st.phase=="ALT_REMOVE_ALL" then
    x.setAlt(0)
   end
   x.tick()
  end
  if kind~="reindex" and n==4 then
   local st=x.state()
   eq(st.status,"STOPPED","unsafe own survivor must terminal STOP "..kind)
   eq(st.reason,"OWN_SLOT_REPLACED_DURING_REMOVAL",
     "specific own removal error "..kind)
   eq(st.completedRounds,3,"preserve earlier 3 clean windows "..kind)
   eq(st.actions.requestsStarted,4,"no fifth request "..kind)
   eq(st.authorizesAccept,false,"zero accept authority "..kind)
   return
  end
  eq(endRound,true,"valid MAIN withdrawal completes trade "..n.." "..kind)
 end
 local result=x.state()
 eq(result.status,"CLIENT_TEST_SEQUENCE_COMPLETE",
   "valid compacted GUI survive full ARM4")
 eq(result.actions.ownRemovalSlotReindexesObserved>=1,true,
   "own valid GUI renumber independently counted")
end
for _,kind in ipairs({"reindex","replacement","quantity","chroma"}) do
 testOwnRemovalIndex(kind)
end

-- First fully automated eight-TRADE batch: one distinct scenario per
-- FRESH original-P3 mock epoch and separate original protected P4 GUI root.
-- Every trade cleans up and terminates before the next; no final Accept.
do
 local x=fixture({ownRemovalMutation="reindex"})
 for _=1,20 do x.tick() end
 for i=1,4 do
  local button=x.named("OwnedChoice_"..i)
  eq(type(button),"table","four eligible owned-choice buttons "..i)
  button.Activated:Fire()
 end
 x.tick()
 local arm=x.named("ArmEightScenarios")
 eq(type(arm),"table","eight-trade explicitly approved ARM GUI exists")
 eq(arm.Visible,true,"ARM8 enabled only after four distinct approved choices")
 eq(x.named("ArmAllFour").Visible,false,"ARM4 not on four-choice approval")
 arm.Activated:Fire()
 eq(x.requests(),0,"no P3 request until ARM8 worker advances")
 local delayTicks=0
 for n=1,8 do
  eq(untilRound(x,n,"WAIT_OPEN",190),true,
    "eight-trade new bound P3 epoch "..n)
  eq(x.requests(),n,"exactly one fresh request per scenario "..n)
  x.open() -- consenting ALT accepts *trade request*, NEVER final Accept
  local finishedRound=false
  for _=1,650 do
   local st=x.state()
   if st.status=="STOPPED" then
    error("SYSTEM1 ARM8 STOP in trade "..n.." phase "..
      st.phase.." reason "..st.reason)
   end
   if st.completedRounds>=n then finishedRound=true;break end
   if st.phase=="ALT_ADD" then
    if n==1 then x.setAlt(1,2,false)
    elseif n==2 then x.setAlt(1,1,true)
    elseif n==3 then
     delayTicks+=1
     if delayTicks>=54 then x.setAlt(1,1,false) end
    elseif n==4 then x.setAlt(2,1,false)
    else x.setAlt(1,1,false) end
   elseif st.phase=="ALT_REMOVE_ONE" then
    x.setAlt(1)
   elseif st.phase=="ALT_REMOVE_ALL" then
    x.setAlt(0)
   elseif st.phase=="WAIT_ALT_CANCEL" then
    x.prematurelyClose() -- ALT intentionally presses Decline, no fake accept
   elseif st.phase=="ALT_REVISE" then
    x.setAlt(1)
    x.their:FindFirstChild("NewItem1"):FindFirstChild("ItemName")
      :FindFirstChild("Label").Text="ALT_B"
   elseif st.phase=="ALT_REVISE_SECOND" then
    x.setAlt(1)
    x.their:FindFirstChild("NewItem1"):FindFirstChild("ItemName")
      :FindFirstChild("Label").Text="ALT_C"
   elseif st.phase=="ALT_CLEAR_FOR_REOFFER" then
    x.setAlt(0)
   elseif st.phase=="ALT_READD" then
    x.setAlt(1)
   end
   x.tick()
  end
  eq(finishedRound,true,"one trade closes and ledger saves scenario "..n)
  eq(x.state().completedRounds,n,"no skipped or double-counted scenario "..n)
  eq(x.declines(),n==8 and 7 or (n==7 and 6 or n),
    "exact MAIN declines excluding intended ALT cancellation "..n)
 end
 local st=x.state()
 eq(st.status,"CLIENT_TEST_SEQUENCE_COMPLETE","all eight client trades passed")
 eq(st.reason,"ALL_EIGHT_CLIENT_SCENARIOS_VERIFIED",
   "distinct eight-trade outcome text")
 eq(st.maxRounds,8,"eight bounded independent client trade windows")
 eq(st.eightTradeBatchAuthorized,true,"separate ARM8 authorization recorded")
 eq(st.actions.requestsStarted,8,"eight fresh P3 mock request epochs")
 eq(st.actions.offersAttempted,10,"2+2+4+1+1 protected outgoing items")
 eq(st.actions.offersClientVisible,10,"ten original protected GUI items")
 eq(st.actions.removalsAttempted,10,"all ten own slots removed separately")
 eq(st.actions.declinesAttempted,7,"seven MAIN declines")
 eq(st.actions.clientClosedWindows,8,"eight verified client closures")
 eq(st.actions.partnerCancelWindows,1,"one ALT cancellation scenario")
 eq(st.actions.stackedAltSlotsVerified,1,"stack x2 verified as one slot")
 eq(st.actions.chromaAltSlotsVerified,1,"one Chroma variant verified")
 eq(st.actions.delayedAltOffersVerified,1,"delayed ALT verified after 5s")
 eq(st.actions.altRevisionsObserved,2,"two distinct ALT revisions")
 eq(st.actions.adaptiveReoffersAttempted,1,"one distinct MAIN reoffer")
 eq(st.actions.ownRemovalSlotReindexesObserved>=1,true,
   "own GUI reindex observed during protected withdrawals")
 eq(#st.rounds,8,"eight distinct per-trade ledger records")
 for i,record in ipairs(st.rounds) do
  eq(record.round,i,"ledger order matches trade index "..i)
  eq(type(record.scenarioId),"string","distinct scenario ID "..i)
  eq(record.clientWindowClosed,true,"independent closed window "..i)
  eq(record.status,"CLIENT_SEQUENCE_PASS","per-trade outcome "..i)
 end
 eq(st.rounds[7].reason,"EXPECTED_PARTNER_CLIENT_CLOSURE_UNATTRIBUTED",
   "ALT cancellation does not claim server outcome")
 eq(st.rounds[8].closedBy,"MAIN_GUARDED_DECLINE",
   "new P3 request resumes only after ALT cancellation")
 eq(x.requests(),8,"no ninth P3 epoch")
 eq(x.declines(),7,"no blind MAIN decline on ALT cancellation")
 eq(#x.sent,10,"ten guarded original OfferItem remote attempts")
 eq(#x.copies>=1,true,"terminal batch report automatically copied")
 local json=serde.decode("json",x.copies[#x.copies])
 eq(json.completedRounds,8,"native clipboard eight closed windows")
 eq(json.finalAcceptEverAttempted,false,"never final Accept")
 eq(json.serverCompletionProven,false,"not actual settlement proof")
 eq(json.verifiedCompletedTrades,0,"no fabricated trade completions")
end

-- Negative ARM8 first-fault proof: wrong stack quantity is terminal,
-- preserves exact scenario/phase, does not request trade 2 or click Decline.
do
 local x=fixture()
 for _=1,20 do x.tick() end
 for i=1,4 do x.named("OwnedChoice_"..i).Activated:Fire()end
 x.tick()
 x.named("ArmEightScenarios").Activated:Fire()
 eq(untilRound(x,1,"WAIT_OPEN",180),true,
   "negative scenario starts exactly one request")
 x.open()
 eq(untilRound(x,1,"ALT_ADD",80),true,
   "wrong-stack test reached exact requested phase")
 x.setAlt(1,1,false) -- expected quantity x2, physically one slot x1
 eq(untilState(x,"STOPPED",18),true,"wrong stack terminal stop")
 local r=x.state()
 eq(r.reason,"ALT_EXPECTED_ONE_STACKED_QTY2_SLOT",
   "specific first scenario fault")
 eq(r.firstFailureScenario,"STACK_QTY2",
   "failure scenario precisely exported")
 eq(r.round,1,"failed trade index precisely exported")
 eq(r.completedRounds,0,"no fictitious successful trades")
 eq(r.actions.requestsStarted,1,"no request 2 after first fault")
 eq(r.actions.offersAttempted,0,"no physical own offer attempted")
 eq(r.actions.declinesAttempted,0,"never blind decline wrong ALT offer")
 eq(r.actions.clientClosedWindows,0,"open client window not falsely closed")
 eq(r.authorizesAccept,false,"zero final accept on fatal stack mismatch")
 eq(#x.copies>=1,true,"STOP automatically saves sanitized JSON")
 eq(x.state().status,"STOPPED","cannot resume same run after STOP")
end

print("SYSTEM1_MAIN_AUTO_NATIVE_ORIGINAL_PASS",tests)
