-- Stage100 instructions overlay. UI ONLY; no remotes, inputs or trade actions.
-- Collision-tested against the ORIGINAL MM2 trade root before every display.
-- If the real game offers no non-overlapping space, fail closed: DO NOT
-- draw over accept/decline/item slots merely to keep a prompt visible.
local M={}
local function number(x)
 return type(x)=="number" and x==x and x~=-math.huge and x~=math.huge
end
local function rect(x,y,w,h)
 if not number(x) or not number(y) or not number(w) or not number(h)
   or w<=0 or h<=0 then return nil end
 return {x=x,y=y,w=w,h=h}
end
local function intersects(a,b,gap)
 gap=gap or 0
 return a.x<b.x+b.w+gap and a.x+a.w>b.x-gap and
   a.y<b.y+b.h+gap and a.y+a.h>b.y-gap
end
-- All candidate locations are in the same absolute viewport coordinates.
-- UI has IgnoreGuiInset=true, while 72 top / 34 bottom preserve iPad
-- system/Roblox bars. Refuse, rather than guess, a zero-sized trade root.
function M.choose(viewport,trade,requestedSize)
 if type(viewport)~="table" or not number(viewport.x) or
    not number(viewport.y) then return nil,"VIEWPORT_UNAVAILABLE" end
 local W,H=viewport.x,viewport.y
 if W<300 or H<260 then return nil,"SCREEN_TOO_SMALL" end
 local margin=14
 local top=72
 local bottom=34
 requestedSize=requestedSize or {}
 local requestedW=requestedSize.w or 304
 local requestedH=requestedSize.h or 96
 if not number(requestedW) or not number(requestedH) or
    requestedW<240 or requestedW>512 or requestedH<80 or
    requestedH>220 then return nil,"INVALID_PANEL_SIZE" end
 local width=math.min(requestedW,W-2*margin)
 local height=requestedH
 if width<240 or top+height+bottom>H then
  return nil,"NO_SAFE_PANEL_SIZE"
 end
 local positions={
  {margin,top},
  {W-margin-width,top},
  {margin,H-bottom-height},
  {W-margin-width,H-bottom-height},
  {margin,(H-height)/2},
  {W-margin-width,(H-height)/2},
  {(W-width)/2,top},
  {(W-width)/2,H-bottom-height}
 }
 local t=nil
 if trade~=nil then
  if type(trade)~="table" or
     not number(trade.x) or not number(trade.y) or
     not number(trade.w) or not number(trade.h) or
     trade.w<=0 or trade.h<=0 then
   return nil,"TRADE_BOUNDS_UNAVAILABLE"
  end
  t=rect(trade.x,trade.y,trade.w,trade.h)
 end
 for _,p in ipairs(positions) do
  local candidate=rect(p[1],p[2],width,height)
  if candidate and candidate.x>=margin and candidate.y>=top and
      candidate.x+width<=W-margin and candidate.y+height<=H-bottom
      and (not t or not intersects(candidate,t,12)) then
   return candidate,"NONOVERLAPPING_PANEL_PLACEMENT"
  end
 end
 return nil,"NO_SAFE_SPACE_OUTSIDE_TRADE"
end
local function bounds(inst)
 local ok,pos,size=pcall(function()
  return inst.AbsolutePosition,inst.AbsoluteSize
 end)
 if not ok or not pos or not size then return nil end
 return rect(pos.X,pos.Y,size.X,size.Y)
end
local function viewportFrom(camera)
 local ok,v=pcall(function()return camera.ViewportSize end)
 if not ok or not v then return nil end
 if not number(v.X) or not number(v.Y) then return nil end
 return {x=v.X,y=v.Y}
end
local function readable(phase)
 local map={
  WAIT_FOR_MANUAL_TRADE_WINDOW={
   title="1 / 4  •  OPEN TRADE",
   body="Manually open an EMPTY trade with your ALT.",
   hint="Do not press final Accept."
  },
  ALT_ADD_ONE={
   title="2 / 4  •  ALT ACCOUNT",
   body="On the ALT, add ONE eligible test weapon.",
   hint="Leave MAIN's offer empty."
  },
  MAIN_ADD_ONE={
   title="3 / 4  •  MAIN ACCOUNT",
   body="On MAIN, add ONE eligible test weapon.",
   hint="Do not change the ALT's item."
  },
  ALT_REMOVE_ONE={
   title="4 / 4  •  ALT ACCOUNT",
   body="On the ALT, REMOVE its test weapon.",
   hint="Leave MAIN's item unchanged. No Accept."
  }
 }
 return map[phase]
end
-- Creates a passive, noninteractive panel. Roblox GUI Instances are the ONLY
-- side effects. The test diagnostic performs no buttons/requests/Accept.
function M.new(playerGui,workspaceService)
 if not playerGui or not workspaceService then
  return nil,"GUI_PARENT_OR_CAMERA_MISSING"
 end
 local camera=workspaceService.CurrentCamera
 if not camera or not viewportFrom(camera) then
  return nil,"VIEWPORT_UNAVAILABLE"
 end
 local good,ui=pcall(function()
  local sg=Instance.new("ScreenGui")
  sg.Name="PDIDDLER_Stage100_ReadOnly_InstructionPanel"
  sg.ResetOnSpawn=false
  sg.IgnoreGuiInset=true
  sg.DisplayOrder=150
  sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
  sg.Parent=playerGui

  local frame=Instance.new("Frame")
  frame.Name="Instructions"
  frame.BackgroundColor3=Color3.fromRGB(28,23,40)
  frame.BackgroundTransparency=0.05
  frame.BorderSizePixel=0
  frame.Active=false
  frame.Visible=false
  frame.ZIndex=10
  frame.Parent=sg

  local stroke=Instance.new("UIStroke")
  stroke.Color=Color3.fromRGB(177,128,239)
  stroke.Thickness=1
  stroke.Parent=frame
  local corner=Instance.new("UICorner")
  corner.CornerRadius=UDim.new(0,11)
  corner.Parent=frame

  local title=Instance.new("TextLabel")
  title.Name="Step"
  title.BackgroundTransparency=1
  title.TextColor3=Color3.fromRGB(218,187,255)
  title.TextSize=13
  title.Font=Enum.Font.GothamBold
  title.TextXAlignment=Enum.TextXAlignment.Left
  title.TextYAlignment=Enum.TextYAlignment.Center
  title.ZIndex=11
  title.Position=UDim2.fromOffset(12,8)
  title.Parent=frame

  local body=Instance.new("TextLabel")
  body.Name="DoThis"
  body.BackgroundTransparency=1
  body.TextColor3=Color3.fromRGB(255,255,255)
  body.TextWrapped=true
  body.TextSize=17
  body.Font=Enum.Font.GothamSemibold
  body.TextXAlignment=Enum.TextXAlignment.Left
  body.TextYAlignment=Enum.TextYAlignment.Top
  body.ZIndex=11
  body.Position=UDim2.fromOffset(12,28)
  body.Parent=frame

  local hint=Instance.new("TextLabel")
  hint.Name="Warning"
  hint.BackgroundTransparency=1
  hint.TextColor3=Color3.fromRGB(235,214,255)
  hint.TextSize=12
  hint.TextWrapped=true
  hint.Font=Enum.Font.Gotham
  hint.TextXAlignment=Enum.TextXAlignment.Left
  hint.TextYAlignment=Enum.TextYAlignment.Center
  hint.ZIndex=11
  hint.Position=UDim2.fromOffset(12,75)
  hint.Parent=frame
  return {root=sg,frame=frame,title=title,body=body,hint=hint}
 end)
 if not good or type(ui)~="table" then return nil,"PANEL_CREATION_FAILED" end

 local self={ui=ui,camera=camera,phase=nil,visible=false,rect=nil}
 function self:show(phase,tradeRoot)
  local prompt=readable(phase)
  if not prompt then
   self.ui.frame.Visible=false
   self.visible=false
   return false,"UNKNOWN_MANUAL_PHASE"
  end
  local cameraCurrent=workspaceService.CurrentCamera
  if not cameraCurrent then
   self.ui.frame.Visible=false;self.visible=false
   return false,"VIEWPORT_UNAVAILABLE"
  end
  local vp=viewportFrom(cameraCurrent)
  local tr=nil
  if tradeRoot then
   tr=bounds(tradeRoot)
   if not tr then
    self.ui.frame.Visible=false;self.visible=false
    return false,"TRADE_BOUNDS_UNAVAILABLE"
   end
  end
  local pos,reason=M.choose(vp,tr)
  if not pos then
   self.ui.frame.Visible=false
   self.visible=false
   self.rect=nil
   return false,reason
  end
  local ok=pcall(function()
   self.ui.frame.Position=UDim2.fromOffset(pos.x,pos.y)
   self.ui.frame.Size=UDim2.fromOffset(pos.w,pos.h)
   self.ui.title.Size=UDim2.fromOffset(pos.w-24,19)
   self.ui.body.Size=UDim2.fromOffset(pos.w-24,44)
   self.ui.hint.Size=UDim2.fromOffset(pos.w-24,16)
   self.ui.title.Text=prompt.title
   self.ui.body.Text=prompt.body
   self.ui.hint.Text=prompt.hint
   self.ui.frame.Visible=true
  end)
  if not ok then
   self.ui.frame.Visible=false;self.visible=false
   return false,"PANEL_LAYOUT_FAILED"
  end
  self.phase=phase
  self.visible=true
  self.rect=pos
  return true,reason
 end
 function self:close()
  local r=self.ui.root
  self.visible=false
  if r then pcall(function()r:Destroy()end) end
 end
 return self
end
return M
