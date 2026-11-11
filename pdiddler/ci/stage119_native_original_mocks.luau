-- Stage119 ORIGINAL native adapter, original frozen Stage9, PR222, PR224 and
-- original Stage100 geometry in actual Luau/Lune. No real game account calls.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local source={
 runner=fs.readFile("pdiddler/supervised/STAGE119_LASTOFFER_NATIVE.lua"),
 controller=fs.readFile("pdiddler/supervised/stage119_lastoffer_native_controller.lua"),
 stage9=fs.readFile("/tmp/gingerscope-stage119/stage9.lua"),
 native=fs.readFile("/tmp/gingerscope-stage119/native_stage9.lua"),
 geometry=fs.readFile("/tmp/gingerscope-stage119/geometry.lua"),
 lastoffer=fs.readFile("pdiddler/intelligence_lab/trade_lastoffer_client_audit.lua"),
 stage118=fs.readFile("pdiddler/intelligence_lab/stage118_lastoffer_gui_correlation.lua"),
}
local checks=0
local function eq(a,b,why)
 checks+=1
 assert(a==b,tostring(why)..": "..tostring(a).." != "..tostring(b))
end
local function event()
 local handlers={}
 local e={}
 function e:Connect(cb)
  local handle={cb=cb,active=true}
  handlers[#handlers+1]=handle
  return {Disconnect=function()handle.active=false end}
 end
 function e:Fire(...)
  for _,h in ipairs(handlers) do
   if h.active then h.cb(...) end
  end
 end
 function e:Count()
  local n=0
  for _,h in ipairs(handlers) do if h.active then n+=1 end end
  return n
 end
 return e
end
local function vec(x,y)return{X=x,Y=y}end
local function node(class,name)
 local o={ClassName=class,Name=name or class,Visible=true,Enabled=true,
  Active=false,Text="",children={},attrs={},AbsolutePosition=vec(0,0),
  AbsoluteSize=vec(10,10),Activated=event()}
 local mt={}
 function mt.__newindex(self,k,v)
  if k=="Parent" then
   local old=rawget(self,"Parent")
   if old and old.children and old.children[self.Name]==self then
    old.children[self.Name]=nil
   end
   rawset(self,k,v)
   if v and v.children then v.children[self.Name]=self end
  else rawset(self,k,v) end
 end
 setmetatable(o,mt)
 function o:IsA(k)
  return k==self.ClassName or
    (k=="GuiObject" and (self.ClassName=="Frame" or
      self.ClassName=="TextLabel" or self.ClassName=="TextButton"))
 end
 function o:FindFirstChild(k)
  return self.children[k]
 end
 function o:FindFirstChildOfClass(k)
  for _,v in pairs(self.children) do if v:IsA(k) then return v end end
 end
 function o:GetDescendants()
  local out={}
  local function visit(n)
   for _,v in pairs(n.children) do
    out[#out+1]=v
    visit(v)
   end
  end
  visit(self)
  return out
 end
 function o:GetAttribute(k) return self.attrs[k] end
 function o:Destroy()
  self.Parent=nil
  self.Visible=false
 end
 function o:put(n)
  n.Parent=self
  return n
 end
 return o
end
local modules={}
for _,key in ipairs({"controller","stage9","native","geometry","lastoffer","stage118"}) do
 local f=assert(luau.load(source[key]))
 modules[key]=f()
end
local function world(opt)
 opt=opt or {}
 local clock=1
 local gui=node("PlayerGui","PlayerGui")
 local screen=gui:put(node("ScreenGui","TradeGUI"))
 screen.Enabled=opt.immediate==true
 local trade=screen:put(node("Frame","Container")):put(node("Frame","Trade"))
 trade.AbsolutePosition=vec(opt.x or 370,opt.y or 150)
 trade.AbsoluteSize=vec(opt.w or 450,opt.h or 410)
 local ours=trade:put(node("Frame","YourOffer"))
 ours:put(node("Frame","Container"))
 ours:put(node("Frame","Accepted")).Visible=false
 local theirs=trade:put(node("Frame","TheirOffer"))
 local container=theirs:put(node("Frame","Container"))
 theirs:put(node("Frame","Accepted")).Visible=false
 theirs:put(node("TextLabel","Username")).Text="(venossgaming90190)"
 local playerService={}
 local main={Name="MAIN",UserId=21,Parent=playerService}
 local alt={Name="venossgaming90190",UserId=22,Parent=playerService}
 gui.Parent=main
 function main:FindFirstChildOfClass(k)
  if k=="PlayerGui" then return gui end
 end
 function playerService:GetPlayers()
  if opt.missingAlt then return {main} end
  return {main,alt}
 end
 function playerService:GetPlayerByUserId(id)
  if id==22 and not opt.missingAlt then return alt end
 end
 playerService.LocalPlayer=main
 local rs=node("Folder","ReplicatedStorage")
 local folder=rs:put(node("Folder","Trade"))
 local remote=folder:put(node("RemoteEvent","UpdateTrade"))
 remote.OnClientEvent=event()
 local worldService={CurrentCamera={ViewportSize=vec(opt.vw or 1024,opt.vh or 768)}}
 if opt.missingCamera then worldService.CurrentCamera=nil end
 local services={Players=playerService,ReplicatedStorage=rs,Workspace=worldService,
  HttpService={JSONEncode=function(_,x)return serde.encode("json",x)end}}
 local game={PlaceId=opt.badPlace and 1 or 142823291,
   JobId=opt.jobId or "TEST_JOB_119"}
 function game:GetService(name)return services[name]end
 function game:HttpGet(_)error("native mock forbids network")end
 local E={}
 local instance={new=function(class)
  if opt.failUI and class=="ScreenGui" then error("UI creation denied") end
  return node(class)
 end}
 local enum={ZIndexBehavior={Sibling="Sibling"},
  Font={GothamBold="GothamBold"},TextXAlignment={Left="Left"}}
 local copied,printed={},{}
 local env={game=game,Instance=instance,
  task={spawn=function(fn)end,wait=function(t)end},
  getgenv=function()return E end,
  Enum=enum,
  UDim={new=function(...)return{...}end},
  UDim2={fromOffset=function(x,y)return {X=x,Y=y}end},
  Color3={fromRGB=function(...)return{...}end},
  setclipboard=function(text)copied[#copied+1]=text end,
  print=function(...) printed[#printed+1]=table.concat({...}," ") end,
  os={clock=function()return clock end},
 }
 local m=assert(luau.load(source.runner,{environment=env}))()
 local ctl=m.start({__stage119_test_only=true,game=game,
  env=E,task=env.task,Instance=instance,clock=function()return clock end,
  clipboard=env.setclipboard,print=env.print,
  sources=modules})
 local x={ctl=ctl,clock=function(t) clock=t end,screen=screen,
  trade=trade,container=container,remote=remote,E=E,
  services=services,gui=gui,alt=alt,main=main,copied=copied,
  node=node,printed=printed,modules=modules}
 function x:packet(token,offered)
  return {LastOffer=token,Locked=false,
   Player1={Player=main,Accepted=false,Offer={}},
   Player2={Player=alt,Accepted=false,
    Offer=offered and {{"Scythe",1,"Weapons"}} or {}}}
 end
 function x:add()
  local slot=container:put(node("Frame","NewItem1"))
  slot:put(node("Frame","ItemName")):put(node("TextLabel","Label")).Text="Batwing"
  slot:put(node("Frame","Container")):put(node("TextLabel","Amount")).Text=""
  slot:put(node("Frame","Tags"))
  return slot
 end
 function x:remove()
  local slot=container:FindFirstChild("NewItem1")
  if slot then slot:Destroy() end
 end
 function x:step(t)
  clock=t
  return ctl and ctl.tick()
 end
 function x:open()
  screen.Enabled=true
 end
 function x:panel()
  local overlay=gui:FindFirstChild("PDIDDLER_Stage119_LastOffer_ReadOnly")
  return overlay and overlay:FindFirstChild("Instruction")
 end
 return x
end
local function healthy(x)
 eq(x:step(1.1).status,"WAITING","start empty trade")
 eq(x:step(1.3).status,"WAITING","stabilize empty")
 eq(x.remote.OnClientEvent:Count(),1,"single listener installed")
 eq(x:panel().title,nil,"noninterference marker")
 local p=x:panel()
 eq(p.Visible,true,"on-screen current prompt")
 eq(p.children.Step.Text,"2/3 ALT MANUALLY ADDS ONE","correct current ALT prompt")
 local place=p.Position
 assert(place and place.X>=0 and place.Y>=72,"safe area missing")
 x.remote.OnClientEvent:Fire(x:packet(8,true))
 x:add()
 eq(x:step(1.5).status,"WAITING","alt added one")
 eq(x:step(1.71).status,"WAITING","alt stable one")
 eq(x:panel().children.Step.Text,"3/3 ALT MANUALLY REMOVES ONE","next manual step")
 x.remote.OnClientEvent:Fire(x:packet(9,false))
 x:remove()
 eq(x:step(1.91).status,"WAITING","ALT removed one")
 local r=x:step(2.13)
 eq(r.status,"CLIENT_TWO_EVENT_LASTOFFER_GUI_UNATTRIBUTED","two-event client result")
 eq(r.callbackCount,2)
 eq(r.guiQuantityTransitions,2)
 eq(r.clientGuiQuantityCrossChecked,true)
 eq(r.clientGuiCrossChecked,false)
 eq(r.serverTradeRevisionProven,false)
 eq(r.authorizesAccept,false)
 eq(r.tradeOutcome,"UNKNOWN")
 eq(x.remote.OnClientEvent:Count(),0,"disconnect on success")
 local panel=x:panel()
 eq(panel.children.StopCopy.Visible,true,"STOP/COPY after complete")
 panel.children.StopCopy.Activated:Fire()
 eq(#x.copied,1,"sanitized STOP/COPY")
 eq(x.copied[1]:find("Scythe",1,true),nil,"no raw weapon key")
 eq(x.copied[1]:find("venossgaming",1,true),nil,"no account identity")
 eq(x.E.PDIDDLER_STAGE119_LASTOFFER_USED_JOB,"TEST_JOB_119","one-shot");
 return r
end
local cases=0
local function test(name,fn)
 local ok,err=pcall(fn)
 assert(ok,"FAIL native Stage119 "..name..": "..tostring(err))
 cases+=1;print("PASS STAGE119 "..name)
end
test("real Stage9 physical capture empty to alt one to empty and token changed",function()
 local x=world()
 x:open()
 local r=healthy(x)
 eq(r.lastOfferEqualityClass,"CLIENT_LASTOFFER_CHANGED_WITH_DIFFERENT_OFFER")
end)
test("same LastOffer across distinct GUI changes is client-only",function()
 local x=world();x:open()
 x:step(1.1);x:step(1.3)
 x.remote.OnClientEvent:Fire(x:packet(8,true));x:add()
 x:step(1.5);x:step(1.71)
 x.remote.OnClientEvent:Fire(x:packet(8,false));x:remove()
 x:step(1.91)
 local r=x:step(2.13)
 eq(r.lastOfferEqualityClass,"CLIENT_LASTOFFER_UNCHANGED_WITH_DIFFERENT_OFFER")
 eq(r.authorizesAccept,false)
end)
test("no ALT and bad place refuse before listener",function()
 local x=world({missingAlt=true})
 eq(x.ctl.status,"INCONCLUSIVE");eq(x.remote.OnClientEvent:Count(),0)
 x=world({badPlace=true})
 eq(x.ctl,nil);eq(x.remote.OnClientEvent:Count(),0)
end)
test("one-shot rejects same job without new owner",function()
 local x=world()
 local again=assert(luau.load(source.runner,{environment={
  game={PlaceId=142823291,JobId="TEST_JOB_119"},
  getgenv=function()return x.E end,print=function()end,
 }}))()
 -- The native entrypoint defaults to getgenv and rejects reused JobId
 local r=again.start({__stage119_test_only=true,
  game={PlaceId=142823291,JobId="TEST_JOB_119"},
  env=x.E,print=function()end})
 eq(r,nil)
end)
test("GUI changes before listener or before callback fail",function()
 local x=world();x:open()
 x:step(1.1);x:add()
 local r=x:step(1.3)
 eq(r.status,"INCONCLUSIVE")
 x=world();x:open()
 x:step(1.1);x:step(1.3);x:add()
 r=x:step(1.5)
 eq(r.status,"INCONCLUSIVE")
 eq(x.remote.OnClientEvent:Count(),0)
end)
test("multiple callbacks fail closed and disconnect",function()
 local x=world();x:open();x:step(1.1);x:step(1.3)
 x.remote.OnClientEvent:Fire(x:packet(8,true))
 x.remote.OnClientEvent:Fire(x:packet(9,true))
 eq(x.ctl.getStatus().status,"INCONCLUSIVE")
 eq(x.remote.OnClientEvent:Count(),0)
 eq(#x.copied,1,"callback failure automatically emits sanitized receipt")
 assert(x.copied[1]:find("INCONCLUSIVE",1,true),"callback report must be visible")
 assert(x.copied[1]:find("Scythe",1,true)==nil,"no raw weapon leak")
end)
test("invalid missing LastOffer fails closed",function()
 local x=world();x:open();x:step(1.1);x:step(1.3)
 local p=x:packet(8,true);p.LastOffer=nil
 x.remote.OnClientEvent:Fire(p)
 eq(x.ctl.getStatus().status,"INCONCLUSIVE")
end)
test("trade GUI move changes prompt position without overlap",function()
 local x=world();x:open();x:step(1.1);x:step(1.3)
 x.trade.AbsolutePosition=vec(15,72)
 x.trade.AbsoluteSize=vec(430,500)
 local r=x:step(1.45)
 eq(r.status,"WAITING")
 local p=x:panel()
 local a=p.Position
 assert(a.X>400,"overlay must move from left corner")
end)
test("no safe place, zero trade bounds, missing camera abort",function()
 for _,o in ipairs({
   {w=1024,h=768,x=0,y=0,vw=1024,vh=768},
   {w=0,h=500},{missingCamera=true}
 }) do
  local x=world(o);x:open()
  local r=type(x.ctl)=="table" and type(x.ctl.tick)=="function"
    and x:step(1.1) or x.ctl
  eq(r.status,"INCONCLUSIVE","unsafe viewport/bounds")
  eq(x.remote.OnClientEvent:Count(),0)
 end
end)
test("altered partner header and closed window fail",function()
 local x=world();x:open();x:step(1.1);x:step(1.3)
 x.trade.children.TheirOffer.children.Username.Text="(attacker)"
 eq(x:step(1.5).status,"INCONCLUSIVE")
 x=world();x:open();x:step(1.1);x:step(1.3)
 x.screen.Enabled=false
 eq(x:step(1.5).status,"INCONCLUSIVE")
end)
test("five iPad geometries retain readable nonoverlapping prompt",function()
 for _,v in ipairs({
  {1024,768,370,150,450,410},
  {1366,1024,100,160,620,630},
  {1024,768,10,160,500,410},
  {1200,900,700,150,480,500},
  {834,1194,205,220,550,700}
 }) do
  local x=world({vw=v[1],vh=v[2],x=v[3],y=v[4],w=v[5],h=v[6]})
  x:open();local r=x:step(1.1)
  eq(r.status,"WAITING","iPad geometry should fit")
  local p=x:panel()
  eq(p.Visible,true)
  local a=p.Position
  local b=x.trade.AbsolutePosition
  local z=x.trade.AbsoluteSize
  local overlap=a.X<b.X+z.X+12 and a.X+304>b.X-12 and
    a.Y<b.Y+z.Y+12 and a.Y+148>b.Y-12
  eq(overlap,false,"panel/trade must not overlap")
 end
end)
print("STAGE119_REAL_LUNE_NATIVE_STAGE9_PASS "..cases.." scenarios, "..checks.." assertions")
