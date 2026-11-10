-- Stage116: run ACTUAL checked-in native wrapper with Lune sandbox Roblox mocks.
-- It uses neither real Roblox networking, game account, executor nor trade UI.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local wrapper=fs.readFile("pdiddler/new_part4/STAGE116_READONLY_EVIDENCE_PANEL.lua")
local rawView=fs.readFile("pdiddler/new_part4/stage116_client_evidence_view.lua")
local rawGeometry=fs.readFile("pdiddler/new_part4/stage116_safe_panel_geometry.lua")
local function signal()
 local s={listeners={}}
 function s:Connect(fn)
  local connection={on=true,fn=fn}
  function connection:Disconnect() self.on=false end
  table.insert(self.listeners,connection)
  return connection
 end
 function s:Fire(...)
  for _,c in ipairs(self.listeners) do
   if c.on then c.fn(...) end
  end
 end
 return s
end
local function node(class)
 local n={ClassName=class,Visible=true,Enabled=true,
          AbsolutePosition={X=0,Y=0},AbsoluteSize={X=0,Y=0},
          _children={},Destroyed=false}
 if class=="TextButton" then n.Activated=signal() end
 function n:IsA(k)
  if k==self.ClassName then return true end
  if k=="GuiObject" then
   return class=="Frame" or class=="TextButton" or class=="TextLabel"
  end
  return false
 end
 function n:FindFirstChild(k) return self._children[k] end
 function n:Destroy() self.Destroyed=true;self.Visible=false end
 return setmetatable(n,{__newindex=function(t,k,v)
  rawset(t,k,v)
  if k=="Parent" and v and type(v._children)=="table" then
   v._children[t.Name or t.ClassName]=t
  end
 end})
end
local function scene()
 local pg=node("PlayerGui")
 local player={PlayerGui=pg}
 function player:FindFirstChildOfClass(k) if k=="PlayerGui" then return pg end end
 local world={CurrentCamera={ViewportSize={X=1024,Y=768}}}
 local render=signal()
 local service={
  Players={LocalPlayer=player},Workspace=world,
  RunService={RenderStepped=render},
 }
 local E={}
 local calls={}
 local game={
  PlaceId=142823291,
  GetService=function(_,k) return service[k] end,
  HttpGet=function(_,url)
   table.insert(calls,url)
   if not url:find(
     "31cdd660f2d82ab50b548e5c8bc4e179c28312e6",1,true) then
    error("unpinned URL")
   end
   if url:find("stage116_client_evidence_view.lua",1,true) then
    return rawView
   elseif url:find("stage116_safe_panel_geometry.lua",1,true) then
    return rawGeometry
   end
   error("unauthorized module path")
  end,
 }
 local color={fromRGB=function(r,g,b)return {r=r,g=g,b=b}end}
 local dim={fromOffset=function(x,y)return {X=x,Y=y}end}
 local enum={
  ZIndexBehavior={Sibling="Sibling"},
  Font={GothamBold="GothamBold",Gotham="Gotham"},
  TextXAlignment={Left="Left"},
  TextYAlignment={Center="Center"},
 }
 local current=0
 local env={
  game=game,getgenv=function()return E end,
  Instance={new=node},Color3=color,UDim2=dim,
  UDim={new=function(a,b)return {a=a,b=b}end},
  Enum=enum,os={clock=function()return current end},
  print=function(...)end,warn=function(...)end,
 }
 env.loadstring=function(source)
  return luau.load(source,{environment=env,injectGlobals=true})
 end
 local function execute()
  return luau.load(wrapper,{environment=env,injectGlobals=true})()
 end
 local function tick()
  current+=0.3
  render:Fire()
 end
 return {E=E,pg=pg,world=world,game=game,tick=tick,execute=execute,
         calls=calls,node=node}
end
local tests=0
local function check(cond,why)
 tests+=1
 assert(cond,why or "Stage116 native wrapper assertion")
end
local sim=scene()
local state=sim.execute()
check(type(state)=="table","native script returns display-only state")
check(state.readOnly==true,"readOnly")
check(state.status=="CLIENT_EVIDENCE_DISPLAY_ONLY","status")
check(state.report.tradeOutcome=="UNKNOWN","outcome")
check(state.report.authorizesAccept==false and
      state.report.authorizesTrade==false,"no trade")
check(state.report.relationProven==false,"unlinked")
check(state.report.offerText=="No Stage106 candidate report available",
      "no old client state fabricated")
check(state.report.readbackText=="No Stage115 sanitized replay report available",
      "no prior inventory fabricated")
check(#sim.calls==2,"exactly two pinned public sources")
local screen=sim.pg:FindFirstChild("PDIDDLER_Stage116_ClientEvidence_ReadOnly")
check(screen~=nil,"actual on-screen ScreenGui created")
local frame=screen:FindFirstChild("ClientEvidence")
check(frame~=nil and frame.Visible==true,"panel visible")
check(frame:FindFirstChild("Outcome").Text=="OUTCOME UNKNOWN - CLIENT ONLY",
      "unknown outcome always in visible panel")
check(frame:FindFirstChild("NotLinked").Text:find("Not proof",1,true)~=nil,
      "explicit no settlement")
local first=frame.Position
check(first.X>=14 and first.Y>=72,"inside safe insets")
local gui=sim.node("ScreenGui");gui.Name="TradeGUI";gui.Enabled=true;gui.Parent=sim.pg
local container=sim.node("Frame");container.Name="Container";container.Parent=gui
local trade=sim.node("Frame");trade.Name="Main";trade.Parent=container
trade.AbsolutePosition={X=0,Y=80};trade.AbsoluteSize={X=480,Y=460}
sim.tick()
check(frame.Visible==true,"display repositioned when trade became visible")
local pos=frame.Position
local w,h=frame.Size.X,frame.Size.Y
local x,y=trade.AbsolutePosition.X,trade.AbsolutePosition.Y
local tw,th=trade.AbsoluteSize.X,trade.AbsoluteSize.Y
check(not (pos.X<x+tw+12 and pos.X+w>x-12
           and pos.Y<y+th+12 and pos.Y+h>y-12),
      "never overlap actual visible trade root")
sim.world.CurrentCamera.ViewportSize={X=400,Y=300}
trade.AbsolutePosition={X=0,Y=0};trade.AbsoluteSize={X=400,Y=300}
sim.tick()
check(frame.Visible==false,"hide if no safe region exists")
check(state.status=="INCONCLUSIVE_NO_SAFE_PANEL_AREA",
      "cannot claim live overlay in unsafe viewport")
sim.world.CurrentCamera.ViewportSize={X=1024,Y=768}
sim.tick()
check(frame.Visible==true,"reappear after viewport restored safely")
local button=frame:FindFirstChild("DismissReadOnly")
check(button~=nil and button.Activated~=nil,"dismiss after display")
button.Activated:Fire()
check(state.running==false,"dismiss shuts down observer")
check(screen.Destroyed==true,"dismiss destroys own GUI only")
check(sim.E.GINGERSCOPE_STAGE116_READONLY_EVIDENCE_PANEL==nil,
      "cleans state on dismissal")
sim.tick()
check(state.running==false,"no resumed UI after dismiss")
print("[PASS] Stage116 ACTUAL wrapper mocked Roblox GUI lifecycle:",tests)
print("[PASS] no actual game, remotes, trade UI manipulation or current price authority")
