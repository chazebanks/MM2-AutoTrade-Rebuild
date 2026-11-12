-- Test ACTUAL System1 native GUI + original protected MM2 P4 TradeIO and
-- P3/P4 bound bridge. ALL trades are manual test GUI changes in fake Roblox.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local runnerSource=fs.readFile("pdiddler/system1/SYSTEM1_MULTITRADE_GUIDED_NATIVE.lua")
local ioSource=fs.readFile("pdiddler/supervised/pdiddler4_tradeio_supervised_v2.lua")
local bridgeSource=fs.readFile("pdiddler/supervised/supervised_p3_p4_handoff.lua")
local geometrySource=fs.readFile("pdiddler/new_part4/stage100_screen_prompt_overlay.lua")
local pureSource=fs.readFile("pdiddler/system1/system1_multitrade_client_walkthrough.lua")
local tests=0
local function eq(a,b,label)
 tests+=1;assert(a==b,tostring(label)..": "..tostring(a).." ~= "..tostring(b))
end
local function event()
 local handlers={}
 local e={}
 function e:Connect(f)
  local x={f=f,active=true}
  handlers[#handlers+1]=x
  return {Disconnect=function()x.active=false end}
 end
 function e:Fire()
  for _,h in ipairs(handlers) do
   if h.active then h.f() end
  end
 end
 return e
end
local function vec(x,y)return {X=x,Y=y}end
local function node(class,name)
 local n={ClassName=class,Name=name or class,Visible=true,
  Enabled=true,Active=true,Text="",children={},attributes={},
  AbsolutePosition=vec(0,0),AbsoluteSize=vec(0,0),
  Activated=event()}
 function n:IsA(q)
  return q==self.ClassName or
   (q=="GuiObject" and
    (self.ClassName=="Frame" or self.ClassName=="TextLabel"
      or self.ClassName=="TextButton" or self.ClassName=="TextBox"))
 end
 function n:FindFirstChild(key,recursive)
  local child=self.children[key]
  if child then return child end
  if recursive then
   for _,c in pairs(self.children) do
    local deep=c:FindFirstChild(key,true)
    if deep then return deep end
   end
  end
 end
 function n:GetDescendants()
  local out={}
  local function gather(z)
   for _,c in pairs(z.children) do
    out[#out+1]=c;gather(c)
   end
  end
  gather(self)
  return out
 end
 function n:GetAttribute(k)return self.attributes[k]end
 function n:GetFullName()return self.Name end
 function n:put(child)
  child.Parent=self;self.children[child.Name]=child
  return child
 end
 function n:Destroy()
  if self.Parent then self.Parent.children[self.Name]=nil end
  self.Parent=nil;self.Visible=false
 end
 return n
end
local function fixture(settings)
 settings=settings or {}
 local players={}
 local pg=node("PlayerGui","PlayerGui")
 local screen=pg:put(node("ScreenGui","TradeGUI"))
 screen.Enabled=false
 local layout=screen:put(node("Frame","Container"))
 local root=layout:put(node("Frame","Trade"))
 root.AbsolutePosition=vec(settings.x or 370,settings.y or 140)
 root.AbsoluteSize=vec(settings.w or 420,settings.h or 410)
 local ownPanel=root:put(node("Frame","YourOffer"))
 local own=ownPanel:put(node("Frame","Container"))
 ownPanel:put(node("Frame","Accepted")).Visible=false
 local altPanel=root:put(node("Frame","TheirOffer"))
 local their=altPanel:put(node("Frame","Container"))
 altPanel:put(node("Frame","Accepted")).Visible=false
 local name=altPanel:put(node("TextLabel","Username"))
 name.Text=settings.displayPartner or "venossgaming90190"
 local me={Name="MAIN_TEST",UserId=1,Parent=players}
 local alt={Name="venossgaming90190",UserId=2,Parent=players,
   DisplayName="TestAlt"}
 if settings.altMissing then alt.Parent=nil end
 players.LocalPlayer=me
 function players:FindFirstChild(k)
  if k=="venossgaming90190" and alt.Parent==players then return alt end
 end
 function players:GetPlayers()return {me,alt} end
 function me:FindFirstChildOfClass(k)
  if k=="PlayerGui" then return pg end
 end
 local remote=node("RemoteEvent","OfferItem")
 local offered={}
 function remote:FireServer(...)
  offered[#offered+1]={...}
 end
 local folder=node("Folder","Trade")
 folder:put(remote)
 local RS=node("ReplicatedStorage","ReplicatedStorage")
 RS:put(folder)
 local run={RenderStepped=event()}
 local workspace={CurrentCamera={
   ViewportSize=vec(settings.viewportW or 1024,
    settings.viewportH or 768)}}
 local copied={}
 local http={
  GenerateGUID=function()return "12345678-abcd-0123-aaaa-bbccddeeff00" end,
  JSONEncode=function(_,obj)return serde.encode("json",obj)end,
 }
 local services={Players=players,RunService=run,Workspace=workspace,
    HttpService=http,ReplicatedStorage=RS,
    VirtualInputManager={},GuiService={}}
 local fetched={}
 local game={
  PlaceId=142823291,JobId="MULTITRADE_TEST_JOB",
  GetService=function(_,k)return services[k]end,
  HttpGet=function(_,url)
   fetched[#fetched+1]=url
   if url:find("pdiddler4_tradeio_supervised_v2.lua",1,true)
      and url:find("a3c209659942e8b45eec5da3555f7cfb83059c59",1,true)
      then return ioSource end
   if url:find("supervised_p3_p4_handoff.lua",1,true)
      and url:find("a3c209659942e8b45eec5da3555f7cfb83059c59",1,true)
      then return bridgeSource end
   if url:find("stage100_screen_prompt_overlay.lua",1,true)
      and url:find("a3c209659942e8b45eec5da3555f7cfb83059c59",1,true)
      then return geometrySource end
   if url:find("system1_multitrade_client_walkthrough.lua",1,true)
      and url:find("61536126eec12707174d16319e757ab7829b4534",1,true)
      then return pureSource end
   error("unexpected source url")
  end,
 }
 local made={}
 local instance={}
 function instance.new(c)
  local v=node(c);made[#made+1]=v;return v
 end
 local env={}
 env.game=game
 env.getgenv=function()return env.E end
 env.loadstring=function(code)
  return luau.load(code,{environment=env,injectGlobals=true})
 end
 env.Instance=instance
 env.Color3={fromRGB=function(...)return {...}end}
 env.UDim={new=function(...)return {...}end}
 env.UDim2={fromOffset=function(...)return {...}end}
 env.Enum={ZIndexBehavior={Sibling="Sibling"},
  TextXAlignment={Left="Left"},TextYAlignment={Top="Top"},
  Font={GothamBold="GothamBold",GothamSemibold="GothamSemibold"}}
 env.setclipboard=function(x)copied[#copied+1]=x end
 local spawned={}
 env.task={spawn=function(f)spawned[#spawned+1]=f end,
   wait=function()end}
 env.E={}
 local load=luau.load(runnerSource,{environment=env,injectGlobals=true})
 local runner=load()
 local function named(name)
  for _,v in ipairs(made)do if v.Name==name then return v end end
 end
 local function add(side,index,label,qty,chroma)
  local s=side:put(node("Frame","NewItem"..index))
  s:put(node("Frame","ItemName")):put(node("TextLabel","Label")).Text=label
  s:put(node("Frame","Container"))
    :put(node("TextLabel","Amount")).Text="x"..tostring(qty or 1)
  if chroma then
   s:put(node("Frame","Tags")):put(node("Frame","Chroma"))
  end
  return s
 end
 local function clear(side,index)
  local s=side:FindFirstChild("NewItem"..index)
  if s then s.Visible=false end
 end
 local function close()
  screen.Enabled=false
  if runner then return runner.tick()end
 end
 local function open()
  screen.Enabled=true
  return runner.tick()
 end
 return {runner=runner,env=env,screen=screen,root=root,me=me,
    alt=alt,name=name,own=own,their=their,offered=offered,
    copied=copied,fetched=fetched,made=made,spawned=spawned,
    named=named,add=add,clear=clear,close=close,open=open,
    next=function()named("Next").Activated:Fire()end,
    copy=function()named("Copy").Activated:Fire()end,
    stop=function()named("Stop").Activated:Fire()end}
end
-- The distinct new runner genuinely executes ORIGINAL protected client IO
-- and original bridge through FOUR real GUI root openings/closures. No offer
-- remote, request, Decline remote, Accept or teleport in this test.
do
 local x=fixture()
 eq(type(x.runner),"table","native one-session multi-trade runner loaded")
 eq(#x.fetched,4,"four immutable real original sources fetched")
 eq(#x.spawned,1,"one bounded watchdog scheduled")
 eq(x.runner.status().phase,"WAIT_OPEN","ALT requested manually first")
 eq(x.named("DoThis").Text:find("ALT:",1,true)~=nil,true,
  "GUI explicitly instructs ALT")
 eq(x.named("Safety").Text:find("NEVER FINAL ACCEPT",1,true)~=nil,true,
  "final Accept warning visible")
 local first=x.open()
 eq(first.phase,"WAIT_EMPTY","trade root found")
 eq(x.runner.tick().phase,"R1_CLOSE","real bridge verifies empty round1")
 eq(x.close().phase,"REVIEW","manual close observed")
 eq(x.runner.status().passedRounds,1,"round1 complete")
 eq(x.named("Next").Visible,true,"NEXT only after close")
 x.next()
 eq(x.runner.status().round,2,"same script starts round2")
 x.open()
 eq(x.runner.tick().phase,"R2_ALT_ADD","round2 guided ALT add")
 x.add(x.their,1,"ALT_ONE")
 x.runner.tick()
 eq(x.runner.tick().phase,"R2_ALT_REMOVE","ALT add actually seen 2 ticks")
 x.clear(x.their,1)
 x.runner.tick()
 eq(x.runner.tick().phase,"R2_CLOSE","ALT remove actually seen 2 ticks")
 x.close()
 eq(x.runner.status().passedRounds,2,"round2 complete without restart")
 x.next()
 x.open()
 eq(x.runner.tick().phase,"R3_MAIN_ADD","round3 two-sided starts")
 x.add(x.own,1,"MAIN_TEST_ONE")
 x.runner.tick()
 eq(x.runner.tick().phase,"R3_ALT_ADD","MAIN offer client visible")
 x.add(x.their,1,"ALT_TEST_ONE")
 x.runner.tick()
 eq(x.runner.tick().phase,"R3_ALT_REMOVE","two-sided offer visible")
 x.clear(x.their,1)
 x.runner.tick()
 eq(x.runner.tick().phase,"R3_MAIN_REMOVE","ALT ABA remove seen")
 x.clear(x.own,1)
 x.runner.tick()
 eq(x.runner.tick().phase,"R3_CLOSE","MAIN removed and verified empty")
 x.close()
 eq(x.runner.status().passedRounds,3,"round3 passed")
 x.next()
 x.open()
 eq(x.runner.tick().phase,"R4_MAIN_TWO","round4 2/2 slots")
 x.add(x.own,1,"MAIN_A")
 x.add(x.own,2,"MAIN_B")
 x.runner.tick()
 eq(x.runner.tick().phase,"R4_ALT_TWO","MAIN two slots")
 x.add(x.their,1,"ALT_A")
 x.add(x.their,2,"ALT_B")
 x.runner.tick()
 eq(x.runner.tick().phase,"R4_ALT_ONE","ALT two slots")
 x.clear(x.their,1)
 x.runner.tick()
 eq(x.runner.tick().phase,"R4_ALT_EMPTY","ALT one removed")
 x.clear(x.their,2)
 x.runner.tick()
 eq(x.runner.tick().phase,"R4_MAIN_EMPTY","ALT both removed")
 x.clear(x.own,1)
 x.clear(x.own,2)
 x.runner.tick()
 eq(x.runner.tick().phase,"R4_CLOSE","MAIN both removed")
 x.close()
 eq(x.runner.status().passedRounds,4,"all four windows verified")
 eq(x.runner.status().completedRounds,4,"all 4 recorded")
 x.next()
 eq(x.runner.status().phase,"DONE","one native session finishes four rounds")
 eq(x.runner.status().actualAcceptsByScript,0,"no Accept calls")
 eq(x.runner.status().physicalOffersSentByScript,0,"no scripted offers")
 eq(x.runner.status().p3AutomaticRequestsSent,0,"no fake automated P3 requests")
 eq(x.runner.status().tradeOutcome,"UNKNOWN","no false settlement")
 eq(#x.offered,0,"original guarded OfferItem remote never called")
 x.copy()
 local parsed=serde.decode("json",x.copied[#x.copied])
 eq(parsed.completedRounds,4,"clipboard captures all rounds")
 eq(#parsed.rounds,4,"all round diagnoses copied")
 eq(parsed.runNonce,"12345678-abcd-0123-aaaa-bbccddeeff00",
   "unique nonce emitted")
 eq(parsed.p3RequestOriginAuthenticated,false,"no fake P3 authority")
 x.stop()
 eq(x.env.E.PDIDDLER_SYSTEM1_MULTITRADE_OWNER,nil,
  "STOP cleans up owner")
end
-- Wrong ALT display text, dual visible roots and accepted-state anomalies
-- never leave old GUI procedures apparently PASS.
do
 local x=fixture({displayPartner="SomeOtherPlayer"})
 eq(type(x.runner),"table","runner starts safely without open trade")
 x.open()
 eq(x.env.E.PDIDDLER_SYSTEM1_MULTITRADE_OWNER,nil,
    "incorrect partner halts exact ALT gate")
 eq(x.runner.status().completedRounds,0,"no falsely completed rounds")
end
do
 local x=fixture()
 local second=x.screen.Parent:put(node("ScreenGui","TradeGUI_Phone"))
 second:put(node("Frame","Container")):put(node("Frame","Trade"))
 x.screen.Enabled=true
 x.runner.tick()
 eq(x.env.E.PDIDDLER_SYSTEM1_MULTITRADE_OWNER,nil,
  "multiple visible roots fail closed")
end
do
 local x=fixture()
 x.open()
 local other=x.root:FindFirstChild("TheirOffer")
 other:FindFirstChild("Accepted").Visible=true
 x.runner.tick()
 eq(x.env.E.PDIDDLER_SYSTEM1_MULTITRADE_OWNER,nil,
  "accept visible in protected bound snapshot stops")
end
do
 local x=fixture({viewportW=360,viewportH=440,x=0,y=70,w=360,h=360})
 eq(x.runner==nil,true,"no safe overlay means no native script")
end
do
 local x=fixture({altMissing=true})
 eq(x.runner==nil,true,"exact ALT absent never starts")
end
print("SYSTEM1_MULTITRADE_NATIVE_ORIGINAL_PASS",tests)
