-- Execute ACTUAL new MAIN auto native (32k), original protected P4 IO +
-- original P3/P4 bridge + exact PR240 ABA plan and PR238 client shadow.
-- P3 request transport/bootstrap are injected mocks (per-epoch API),
-- so this is NOT proof of real repeated MM2 networking/Delta compatibility.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local native=fs.readFile("pdiddler/system1/SYSTEM1_STEP1_ALT_DYNAMIC_RECOVERY_NATIVE.lua")
local sources={
 geometry=fs.readFile("pdiddler/new_part4/stage100_screen_prompt_overlay.lua"),
 tradeio=fs.readFile("pdiddler/supervised/pdiddler4_tradeio_supervised_v2.lua"),
 bridge=fs.readFile("pdiddler/supervised/supervised_p3_p4_handoff.lua"),
 choice=fs.readFile("pdiddler/supervised/p3_one_item_owned_selection.lua"),
 controller=fs.readFile("pdiddler/system1/system1_step1_alt_recovery_controller.lua"),
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
   if url:find("system1_step1_alt_recovery_controller.lua",1,true) then
    assert(url=="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"..
     "b7ba49cbdd73ef4ea08bbe8ef653ab095c487fbc/pdiddler/"..
     "system1/system1_step1_alt_recovery_controller.lua",
     "exact controller raw URL must use reviewed COMMIT, not blob hash")
    if opts.simulateControllerFetch404 then error("MOCK_CONTROLLER_404") end
    return sources.controller
   end
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
 local capturedWarnings={}
 e.warn=function(message)
  capturedWarnings[#capturedWarnings+1]=tostring(message)
 end
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
 local round6MutationInjected=false
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
  -- Live-flow mirror: an ALT mutation after the first of FOUR guarded
  -- MAIN offer sends in round6 must invalidate the remaining three.
  -- This is an isolated fake-GUI fault, NEVER an authorized live trade.
  if opts.injectRound6Mutation and not round6MutationInjected then
   local runner=e.E.PDIDDLER_SYSTEM1_MAIN_AUTO_RUNNER
   local progress=runner and runner.status()
   if progress and progress.round==6 and
      progress.phase=="MAIN_OFFERING" and #sent==5 and #tasks>=2 then
    -- Each variant is present in the GUI BEFORE original shadow polling.
    if opts.injectRound6Mutation=="ALT_SINGLE" then
     add(their,1,"ALT_NEW_SINGLE",1,false)
    elseif opts.injectRound6Mutation=="ALT_STACKED" then
     add(their,1,"ALT_NEW_STACKED",2,false)
    elseif opts.injectRound6Mutation=="ALT_CHROMA" then
     add(their,1,"ALT_NEW_CHROMA",1,true)
    elseif opts.injectRound6Mutation=="ALT_TWO_SLOTS" then
     add(their,1,"ALT_NEW_FIRST",1,false)
     add(their,2,"ALT_NEW_SECOND",1,false)
    else
     error("invalid round6 mutation mode")
    end
    round6MutationInjected=true
    injectionTick=true
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
 local function setAltNamed(name,quantity,chroma)
  for i=1,4 do their.children["NewItem"..i]=nil end
  return add(their,1,name,quantity or 1,chroma==true)
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
  setAlt=setAlt,setAltNamed=setAltNamed,open=open,gameRead=gameRead,warnings=capturedWarnings,
  round6MutationInjected=function()return round6MutationInjected end,
  prematurelyClose=function()screen.Enabled=false end,
 }
end

local function untilPhase(x,phase,max)
 for _=1,(max or 300) do
  if x.state().phase==phase then return true end
  if x.state().phase=="STOPPED" then return false end
  x.tick()
 end
 return false
end
local function arm(x)
 eq(type(x.runner),"table","actual Step1 original-protected runner constructed")
 eq(x.state().phase,"SELECT_TWO_OWN_ITEMS","default closed until two distinct owned")
 eq(x.requests(),0,"zero requests before ARM")
 for _=1,25 do x.tick()end
 x.named("OwnedChoice_1").Activated:Fire()
 x.named("OwnedChoice_2").Activated:Fire()
 x.tick()
 eq(x.named("ArmThreeRecoveryScenarios").Text,"ARM 3","new operator-only ARM3 visible")
 x.named("ArmThreeRecoveryScenarios").Activated:Fire()
end
local function scenario(x,n,mode)
 eq(untilPhase(x,"WAIT_OPEN",250),true,"P3 fresh epoch "..n)
 x.open()
 local done=false
 for _=1,950 do
  local st=x.state()
  if st.phase=="STOPPED" then
   error("Step1 original-module STOP round "..n.." reason "..st.reason)
  end
  if st.completedRounds>=n then done=true;break end
  if st.phase=="ALT_ADD" then x.setAltNamed("ALT_A",1,false)
  elseif st.phase=="ALT_REVISE" then
   if mode=="replace" then x.setAltNamed("ALT_B",1,false)
   elseif mode=="stack" then x.setAltNamed("ALT_A",2,false)
   else error("unexpected REVISION phase")end
  elseif st.phase=="ALT_CLEAR_FOR_NEW_ALT" then x.setAlt(0)
  elseif st.phase=="ALT_REVISE_READD" then x.setAltNamed("ALT_B",1,false)
  elseif st.phase=="ALT_CLEAR_FOR_REOFFER" then x.setAlt(0)
  elseif st.phase=="ALT_READD" then x.setAltNamed("ALT_FINAL",1,false)
  elseif st.phase=="ALT_REMOVE_ALL" then x.setAlt(0)
  end
  x.tick()
 end
 eq(done,true,"one client-only closed recovery trade "..n)
 eq(x.state().completedRounds,n,"all preceding rounds retained")
end
do
 local x=fixture({ownRemovalMutation="reindex"})
 arm(x)
 for i,mode in ipairs({"replace","stack","clear"})do
  scenario(x,i,mode)
 end
 local s=x.state()
 eq(s.status,"CLIENT_TEST_SEQUENCE_COMPLETE","all three recovery scenarios pass")
 eq(s.reason,"ALL_THREE_RECOVERY_CLIENT_SCENARIOS_VERIFIED","distinct recovery success receipt")
 eq(s.maxRounds,3,"3 distinct client windows")
 eq(s.recoveryBatchAuthorized,true,"explicit recovery ARM")
 eq(s.eightTradeBatchAuthorized,false,"old ARM8 mode off")
 eq(s.actions.requestsStarted,3,"exact 3 requests")
 eq(s.actions.offersAttempted,6,"3 initial offers plus 3 reoffers")
 eq(s.actions.offersClientVisible,6,"all six original P4 sends visible")
 eq(s.actions.removalsAttempted,6,"six one-at-a-time original removals")
 eq(s.actions.declinesAttempted,3,"three guarded declines")
 eq(s.actions.clientClosedWindows,3,"3 distinct closes")
 eq(s.actions.altRevisionsObserved,3,"all distinct ALT revisions observed")
 eq(s.actions.adaptiveReoffersAttempted,3,"all 3 adaptive reoffers")
 eq(x.requests(),3,"no fourth P3 epoch")
 eq(#x.sent,6,"exact physical original offer attempts")
 eq(x.declines(),3,"exact original declines")
 eq(#x.copies>0,true,"copy receipt on completion")
 local r=serde.decode("json",x.copies[#x.copies])
 eq(r.schema,"gingerscope-system1-step1-alt-recovery-native-v1","new receipt schema")
 eq(r.finalAcceptEverAttempted,false,"zero final Accept")
 eq(r.verifiedCompletedTrades,0,"zero fake completed trades")
 eq(r.serverCompletionProven,false,"no false server proof")
end
do
 local x=fixture()
 arm(x)
 eq(untilPhase(x,"WAIT_OPEN",250),true,"negative initial fresh request")
 x.open()
 eq(untilPhase(x,"ALT_ADD",150),true,"negative initial ALT offer phase")
 x.setAltNamed("ALT_A",1,false)
 eq(untilPhase(x,"ALT_REVISE",80),true,"R1 awaits true replacement")
 x.setAltNamed("ALT_A",2,false)
 eq(untilPhase(x,"STOPPED",100),true,"quantity change cannot pass different-item scenario")
 eq(x.state().reason,"ALT_EXPECTED_DIFFERENT_REPLACEMENT_ITEM","specific recovery failure")
 eq(x.requests(),1,"no additional request after fault")
 eq(#x.sent,1,"no reoffer after fault")
 eq(x.declines(),0,"no blind decline after fault")
end
do
 local x=fixture()
 arm(x)
 scenario(x,1,"replace")
 scenario(x,2,"stack")
 eq(untilPhase(x,"WAIT_OPEN",250),true,"R3 fresh original P3 request")
 x.open()
 eq(untilPhase(x,"ALT_ADD",150),true,"R3 initial ALT")
 x.setAltNamed("ALT_A",1,false)
 eq(untilPhase(x,"ALT_CLEAR_FOR_NEW_ALT",80),true,"R3 requires visible stable empty")
 x.setAltNamed("ALT_B",1,false)
 eq(untilPhase(x,"STOPPED",100),true,"R3 premature replacement stops")
 eq(x.state().reason,"RECOVERY_CLEAR_EXPECTED_ORIGINAL_ITEM",
  "can't pretend empty was observed when ALT swapped directly")
 eq(x.requests(),3,"R3 fault never generates fourth request")
 eq(#x.sent,5,"no R3 reoffer after fault")
 eq(x.declines(),2,"only two earlier windows declined")
 eq(x.state().completedRounds,2,"two earlier windows retained")
end
print("SYSTEM1_STEP1_ALT_RECOVERY_NATIVE_PASS",tests)
