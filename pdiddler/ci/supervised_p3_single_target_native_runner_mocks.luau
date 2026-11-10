-- ACTUAL native one-target P3 -> P4 runner under fake original MM2.
-- Real P4 TradeIO, real P3/P4 bridge, real processed rotation coordinator.
-- Scanner and P3 outgoing are minimal controlled module stubs here; their
-- entire production originals are tested separately by the P3 Lune suite.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local runnerSource=fs.readFile("pdiddler/supervised/SUPERVISED_P3_SINGLE_TARGET_NATIVE_RUNNER.lua")
local overlaySource=fs.readFile("pdiddler/new_part4/stage100_screen_prompt_overlay.lua")
local bridgeSource=fs.readFile("pdiddler/supervised/supervised_p3_p4_handoff.lua")
local ioSource=fs.readFile("pdiddler/supervised/pdiddler4_tradeio_supervised_v2.lua")
local coordinatorSource=fs.readFile("pdiddler/supervised/supervised_real_p3_rotation_handoff.lua")
local tests=0
local function check(actual,expected,label)
 tests+=1
 assert(actual==expected,tostring(label)..": "..tostring(actual).." != "..tostring(expected))
end
local function vec(x,y)return {X=x,Y=y}end
local function event()
 local e={}
 function e:Connect(fn) self.callback=fn;return {Disconnect=function()end}end
 return e
end
local function node(kind,name)
 local o={ClassName=kind,Name=name or kind,children={},Visible=true,
  Enabled=true,Active=false,Text="",AbsolutePosition=vec(0,0),
  AbsoluteSize=vec(0,0)}
 function o:IsA(class)
  return self.ClassName==class or (class=="GuiObject" and (
   self.ClassName=="Frame" or self.ClassName=="TextLabel" or
   self.ClassName=="TextButton"))
 end
 function o:put(child)
  child.Parent=self
  self.children[child.Name]=child
  return child
 end
 function o:FindFirstChild(name)return self.children[name]end
 function o:GetDescendants()return {}end
 function o:GetAttribute()return nil end
 function o:GetFullName()return self.Name end
 function o:Destroy()self.Parent=nil;self.Visible=false end
 return o
end
local SCANNER_SOURCE=String.raw[[local Players=game:GetService("Players")
local me=Players.LocalPlayer
local pg=me:FindFirstChildOfClass("PlayerGui")
local ui=Instance.new("ScreenGui")
ui.Name="MM2EligibilityScannerT41"
pg:put(ui)
local target=Players:FindFirstChild("TrustedAlt")
local M={}
function M.getRecord(id)
 if target and id==target.UserId then
  return {player=target,state="whitelist",inv={items={{id="Iceblaster",qty=1}}}}
 end
end
function M.isWhitelisted(id)
 return target~=nil and id==target.UserId
end
function M.getWhitelist()
 if target then return {target}end
 return {}
end
function M.hasPendingWork()return false end
function M.setStatus(text)return true end
function M.setRequestState(target,state,extra)end
return M]]
local OUTGOING_SOURCE=String.raw[[local M={}
function M.run(scanner,opts)
 local E=getgenv()
 E.PDIDDLER_OUTGOING_SESSION=18
 local state={processed={},active=nil}
 local out={state=state,session=18,paused=false,resumes=0}
 E.TEST_P3_OUTGOING=out
 function out.isPaused()return out.paused end
 function out.resume()
  local screen=game:GetService("Players").LocalPlayer:
    FindFirstChildOfClass("PlayerGui"):FindFirstChild("TradeGUI")
  if screen.Enabled then return false,"still-open" end
  out.paused=false
  out.resumes+=1
  return true,"resumed"
 end
 function out.stop()out.stopped=true;out.paused=false end
 function out.arm()
  if out.armed then return false,"already-armed"end
  local ready=opts.readyCheck()
  if ready~=true then return false,"supervisor-not-ready"end
  out.armed=true;return true,"armed"
 end
 return out
end
return M]]
local function fake(options)
 options=options or {}
 local pg=node("PlayerGui","PlayerGui")
 local tradeScreen=pg:put(node("ScreenGui","TradeGUI"))
 tradeScreen.Enabled=options.tradeAlreadyOpen==true
 local container=tradeScreen:put(node("Frame","Container"))
 local trade=container:put(node("Frame","Trade"))
 trade.AbsolutePosition=vec(options.x or 370,options.y or 150)
 trade.AbsoluteSize=vec(options.w or 440,options.h or 410)
 local ourSide=trade:put(node("Frame","YourOffer"))
 ourSide:put(node("Frame","Container"))
 local ourAccepted=ourSide:put(node("Frame","Accepted"))
 ourAccepted.Visible=false
 local theirSide=trade:put(node("Frame","TheirOffer"))
 theirSide:put(node("Frame","Container"))
 local theirAccepted=theirSide:put(node("Frame","Accepted"))
 theirAccepted.Visible=false
 local header=theirSide:put(node("TextLabel","Username"))
 header.Text=options.wrongTradeHeader and "WrongAccount" or "TrustedAlt"
 local players={}
 local me={Name="Main",UserId=1,Parent=players}
 local other={Name="TrustedAlt",DisplayName="Alt",UserId=2,Parent=players}
 players.LocalPlayer=me
 function me:FindFirstChildOfClass(kind)
  if kind=="PlayerGui" then return pg end
 end
 function players:FindFirstChild(k)
  if k=="TrustedAlt" and other.Parent==players then return other end
 end
 function players:GetPlayerByUserId(uid)
  if uid==2 and other.Parent==players then return other end
  if uid==1 then return me end
 end
 function players:GetPlayers()return{me,other}end
 local remote=node("RemoteEvent","OfferItem")
 local sends=0
 function remote:FireServer()sends+=1 end
 local folder=node("Folder","Trade");folder:put(remote)
 local RS=node("ReplicatedStorage","ReplicatedStorage")
 RS:put(folder)
 local run={RenderStepped=event()}
 local world={CurrentCamera={ViewportSize=vec(options.vw or 1024,options.vh or 768)}}
 if options.noCamera then world.CurrentCamera=nil end
 local services={Players=players,ReplicatedStorage=RS,
   Workspace=world,RunService=run,VirtualInputManager={},
   GuiService={},HttpService={JSONEncode=function(_,v)
    return serde.encode("json",v)
   end}}
 local reads={}
 local game={
  PlaceId=options.wrongPlace and 0 or 142823291,
  JobId="MOCK_JOB",
  GetService=function(_,key)return services[key]end,
  HttpGet=function(_,url)
   reads[#reads+1]=url
   if url:find("stage100_screen_prompt_overlay.lua",1,true)
     and url:find("5b8ee35d7f281c23d9c2181abd97a063e59a0660",1,true)
     then return overlaySource end
   if url:find("pdiddler3_scanner_MODULE_v6_5_PART4_STATUS_BRIDGE.lua",1,true)
     and url:find("dfcfc7d52ce5f9cc64390bb5e28ce79512f1c001",1,true)
     then return options.noScannerPanel and
       SCANNER_SOURCE:gsub('pg:put%(ui%)','') or SCANNER_SOURCE end
   if url:find("pdiddler3_outgoing_START_GATED_v1.lua",1,true)
     and url:find("2036ae5bd937620f21d46600f99550a1b233a654",1,true)
     then return OUTGOING_SOURCE end
   if url:find("supervised_p3_p4_handoff.lua",1,true)
     and url:find("2f556afac5e5fd9cfdbf9e081eeea01a542d293",1,true)
     then return bridgeSource end
   if url:find("supervised_real_p3_rotation_handoff.lua",1,true)
     and url:find("dfcfc7d52ce5f9cc64390bb5e28ce79512f1c001",1,true)
     then return coordinatorSource end
   if url:find("pdiddler4_tradeio_supervised_v2.lua",1,true)
     and url:find("a599c31c53d25e6799b9d631f45f282b445dcda0",1,true)
     then return ioSource end
   error("unapproved or incorrect SHA pinned source "..url)
  end,
 }
 local E={PDIDDLER_P3_SUPERVISED_TARGET_PILOT={
  armed=true,allowSingleTargetRequest=true,
  acknowledgeIncomingDeclines=true,
  noAutomaticAcceptAcknowledged=true,
  targetName=options.wrongTarget and "OtherAccount" or "TrustedAlt",
 }}
 local UI={}
 function UI.new(kind)
  if options.uiCreationFails and kind=="ScreenGui" then error("no UI")end
  return node(kind)
 end
 local Enum={ZIndexBehavior={Sibling="Sibling"},
  TextXAlignment={Left="Left"},Font={GothamBold="GothamBold"}}
 local tasks={}
 local ticks=0
 local clipboard={}
 local env={
  game=game,getgenv=function()return E end,
  Instance=UI,Enum=Enum,Color3={fromRGB=function(...)return {...}end},
  UDim2={fromOffset=function(...)return {...}end},
  UDim={new=function(...)return {...}end},
  print=function()end,warn=function()end,
  setclipboard=function(txt)clipboard[#clipboard+1]=txt end,
 }
 env.task={}
 function env.task.spawn(fn)tasks[#tasks+1]=fn end
 function env.task.wait()
  ticks+=1
  if ticks==2 and not options.noAcceptance then
   local out=E.TEST_P3_OUTGOING
   if out then
    out.paused=true
    out.state.processed[2]="trade-open"
    tradeScreen.Enabled=true
   end
  end
  if ticks==5 and not options.neverClose then
   tradeScreen.Enabled=false
  end
  if options.shrinkOnAccept and ticks==2 then
   world.CurrentCamera.ViewportSize=vec(220,190)
  end
  if ticks==8 then
   local ctl=E.PDIDDLER_P3_SUPERVISED_CONTROLLER
   if ctl then ctl.stop() end
  end
 end
 env.loadstring=function(src)
  return luau.load(src,{environment=env,injectGlobals=true})
 end
 local function start()
  return luau.load(runnerSource,{environment=env,injectGlobals=true})()
 end
 local function drain()
  for _,fn in ipairs(tasks) do fn()end
 end
 return {start=start,drain=drain,E=E,reads=reads,
  copied=clipboard,sends=function()return sends end,
  pg=pg,screen=tradeScreen,world=world,tasks=tasks}
end
do
 local x=fake()
 local ctl=x.start()
 check(type(ctl),"table","actual native controller returned")
 check(x.E.TEST_P3_OUTGOING.armed,true,"P3 start gate armed only after observer constructed")
 check(x.E.PDIDDLER_P3_SUPERVISED_TARGET_PILOT.armed,false,"operator config consumed")
 check(#x.reads,6,"six immutable source dependencies loaded before arm")
 check(x.pg.children.MM2EligibilityScannerT41.Enabled,false,"scanner UI hidden from trade controls")
 x.drain()
 check(x.E.TEST_P3_OUTGOING.resumes,1,"original P3 resume after client trade closes")
 check(x.sends(),0,"no OfferItem remotes")
 check(x.E.PDIDDLER_P3_SUPERVISED_REPORT.authorizesAccept,false,"no final Accept")
 check(x.E.PDIDDLER_P3_SUPERVISED_REPORT.mayReportProfit,false,"no profit authority")
 check(x.E.PDIDDLER_P3_SUPERVISED_REPORT.tradeOutcome,"UNKNOWN","client-only result")
 check(#x.copied,1,"sanitized result copied")
 check(x.E.TEST_P3_OUTGOING.stopped,true,"P3 stopped by operator at end")
end
for _,invalid in ipairs({
 {wrongTarget=true},{wrongPlace=true},{noCamera=true},
 {uiCreationFails=true},{vw=200,vh=160},
}) do
 local x=fake(invalid)
 local ctl=x.start()
 check(ctl,nil,"invalid device/config rejects startup")
 check(x.E.TEST_P3_OUTGOING,nil,"P3 never starts in unsafe environment")
 check(x.sends(),0,"no offered items in unsafe environment")
end
do
 local x=fake({noScannerPanel=true})
 local ctl=x.start()
 check(ctl,nil,"cannot arm if scanner UI cannot be hidden")
 check(x.E.TEST_P3_OUTGOING,nil,"scanner visibility blocker precludes P3 startup")
end
do
 local x=fake({tradeAlreadyOpen=true})
 local ctl=x.start()
 check(ctl,nil,"no arm with preexisting active trade window")
 check(x.E.TEST_P3_OUTGOING.stopped,true,"gate stopped when ready predicate refuses")
 check(x.sends(),0,"preexisting trade has zero outgoing offers")
end
do
 local x=fake({wrongTradeHeader=true})
 local ctl=x.start()
 check(type(ctl),"table","valid initial config before mismatch")
 x.drain()
 check(x.E.PDIDDLER_P3_SUPERVISED_REPORT.status,"STOPPED",
  "wrong later partner causes fail-closed shutdown")
 check(x.sends(),0,"never sends items to wrong partner")
end
print("[PASS] actual one-target native P3/P4 supervisor wrapper",tests)
print("[PASS] six immutable sources, no auto offer or final Accept, exact ALT, safe GUI")
