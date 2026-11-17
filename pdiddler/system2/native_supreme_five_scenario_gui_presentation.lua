-- Gingerscope Supreme-only Stage119 GUI text/state presenter.
-- render() is pure Luau: NO Roblox Instances, remotes, weapon IDs,
-- clocks or mutable state. buildUI() only creates the original local
-- read-only panel from passed-in Roblox GUI constructors. The host retains
-- all P3/P4 identity, lease, GUI collision geometry and trade controls.
local M={}
local SCHEMA="gingerscope-supreme-five-scenario-presentation-v1"
function M.render(args)
 if type(args)~="table" or type(args.status)~="string" or
    type(args.armed)~="boolean" or
    type(args.watcherReady)~="boolean" or
    type(args.previewBusy)~="boolean" or
    type(args.ownerRunning)~="boolean" or
    type(args.panelVisible)~="boolean" or
    type(args.hasBoundScope)~="boolean" or
    type(args.completedCount)~="number" or
    args.completedCount~=math.floor(args.completedCount) or
    args.completedCount<0 or args.completedCount>5 or
    type(args.identityPhase)~="string" or
    type(args.researchOnly)~="boolean" or
    type(args.previewUntil)~="number" or
    type(args.now)~="number" then
  return nil,"PRESENTER_INPUT_INVALID"
 end
 local status=args.status
 local completed=args.completedCount
 local title,body
 if args.researchOnly then
  if status=="P3_SUPERVISOR_PREPARED_NOT_ARMED" then
   title="SUPREME MULTI | 1/5 ARM P3"
   body="MAIN: manually ARM one P3 request to consenting ALT. ALT accepts REQUEST, not final trade. Both offers EMPTY."
  elseif status=="P4_TWO_SIDED_CLIENT_SNAPSHOT" then
   local step=math.min(5,completed+1)
   title="SUPREME MULTI | "..tostring(step).."/5"
   if completed>=5 then
    body="5/5 done: manually CLOSE trade, then STOP / COPY. NEVER final Accept."
   elseif step<=2 then
    body="Start/EMPTY: keep both offers empty and tap PREVIEW."
   elseif step==3 then
    body="ONE-SIDED: manually add ONE cheap weapon on EITHER side; tap PREVIEW."
   elseif step==4 then
    body="TWO-SIDED: manually add a cheap weapon on OTHER side; tap PREVIEW."
   else
    body="CHANGE: manually swap weapon or stack, keeping both sides nonempty; tap PREVIEW."
   end
  else
   title="SUPREME MULTI | WAIT PROTECTED"
   body="Wait for bound trade. Manual offer changes only at each displayed stage. NEVER final Accept."
  end
 elseif args.identityPhase=="RESULT" or args.identityPhase=="FAILED" then
  title=args.identityPhase=="RESULT"
     and "5/5 CLIENT LASTOFFER OBSERVED" or "5/5 CLIENT LASTOFFER INCONCLUSIVE"
  body="MAIN: manually DECLINE the trade, then tap STOP / COPY. NEVER final Accept."
 elseif args.identityPhase=="WAIT_ALT_REMOVE" or
        args.identityPhase=="WAIT_REMOVE_GUI" then
  title="4/5 ALT — REMOVE THAT WEAPON"
  body="ALT: manually REMOVE the same weapon. MAIN stays EMPTY. Wait for result."
 elseif args.identityPhase=="WAIT_ALT_ADD" or
        args.identityPhase=="WAIT_ADD_GUI" then
  title="3/5 ALT — ADD ONE WEAPON"
  body="ALT: manually ADD ONE inexpensive eligible weapon NOW. MAIN stays EMPTY."
 elseif status=="P3_SUPERVISOR_PREPARED_NOT_ARMED" then
  title="1/5 MAIN — ARM P3"
  body="MAIN: tap ARM P3 to request only your ALT. No item will be automatically offered."
 elseif args.identityPhase=="WAIT_EMPTY" or
        args.identityPhase=="WAIT_EMPTY_STABLE" then
  title="2/5 ALT — ACCEPT REQUEST"
  body="ALT: manually ACCEPT the P3 trade REQUEST. Keep BOTH offers EMPTY."
 else
  title="PROTECTED P3/P4 LASTOFFER"
  body="Waiting for original protected trade. Never press final Accept."
 end

 local armVisible=not args.armed and args.watcherReady
 local previewVisible=args.armed and not args.previewBusy and
      args.hasBoundScope and status=="P4_TWO_SIDED_CLIENT_SNAPSHOT" and
      args.ownerRunning and args.panelVisible
 local previewText=completed>=5 and "5/5 COMPLETE" or
      "TEST "..tostring(math.min(5,completed+1)).."/5"
 -- Preserve original 8-second ephemeral text precedence exactly.
 if type(args.previewText)=="string" and
    args.previewUntil>args.now and
    status=="P4_TWO_SIDED_CLIENT_SNAPSHOT" and args.hasBoundScope then
  body=args.previewText
 end
 return {
  schema=SCHEMA,title=title,body=body,
  armVisible=armVisible,previewVisible=previewVisible,
  previewButtonText=previewText,
  stopVisible=true,
 },nil
end

-- Build exactly the original supervisor's three static text labels and
-- ARM/Preview/STOP buttons. Does not place the panel or change game state.
-- All Roblox dependencies are passed explicitly and mocked under Lune.
function M.buildUI(env)
 if type(env)~="table" or type(env.Instance)~="table" or
    type(env.Instance.new)~="function" or
    type(env.Color3)~="table" or type(env.Color3.fromRGB)~="function" or
    type(env.UDim)~="table" or type(env.UDim.new)~="function" or
    type(env.UDim2)~="table" or type(env.UDim2.fromOffset)~="function" or
    type(env.Enum)~="table" or env.Parent==nil then
   return nil,"PRESENTER_GUI_DEPENDENCIES_INVALID"
 end
 local Instance,Color3,UDim,UDim2,Enum=env.Instance,env.Color3,
    env.UDim,env.UDim2,env.Enum
 local ui={}
 local ok=pcall(function()
    ui.screen=Instance.new("ScreenGui")
    ui.screen.Name="PDIDDLER_P3_STAGE101_ReadonlyIdentity"
    ui.screen.ResetOnSpawn=false
    ui.screen.IgnoreGuiInset=true
    ui.screen.DisplayOrder=150
    ui.screen.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    ui.screen.Parent=env.Parent
    ui.panel=Instance.new("Frame")
    ui.panel.Name="LiveStatus"
    ui.panel.BackgroundColor3=Color3.fromRGB(28,23,40)
    ui.panel.BorderSizePixel=0
    ui.panel.Active=false
    ui.panel.Visible=false
    ui.panel.Parent=ui.screen
    local stroke=Instance.new("UIStroke")
    stroke.Color=Color3.fromRGB(177,128,239)
    stroke.Thickness=1
    stroke.Parent=ui.panel
    local corner=Instance.new("UICorner")
    corner.CornerRadius=UDim.new(0,10)
    corner.Parent=ui.panel
    local function label(n,y,h,size)
        local q=Instance.new("TextLabel")
        q.Name=n
        q.BackgroundTransparency=1
        q.TextColor3=Color3.fromRGB(255,255,255)
        q.TextSize=size
        q.TextWrapped=true
        q.TextXAlignment=Enum.TextXAlignment.Left
        q.Font=Enum.Font.GothamBold
        q.Position=UDim2.fromOffset(12,y)
        q.Size=UDim2.fromOffset(280,h)
        q.Parent=ui.panel
        return q
    end
    ui.title=label("CurrentStep",7,24,14)
    ui.body=label("WhatToDo",32,52,12)
    ui.warning=label("Safety",90,18,11)
    ui.warning.Text="MANUAL ITEM TEST | NEVER FINAL ACCEPT"
    local function action(n,text,x)
        local q=Instance.new("TextButton")
        q.Name=n
        q.Text=text
        q.TextSize=13
        q.TextColor3=Color3.fromRGB(255,255,255)
        q.BackgroundColor3=Color3.fromRGB(88,55,129)
        q.Position=UDim2.fromOffset(x,111)
        q.Size=UDim2.fromOffset(128,28)
        q.Parent=ui.panel
        q.Active=false
        q.Visible=false
        return q
    end
    ui.arm=action("ArmP3","ARM P3",12)
    -- Preview replaces ARM only after the original guarded lease opens.
    ui.preview=action("SupremePreview","SUPREME PREVIEW",12)
    ui.stop=action("StopP3","STOP / COPY",164)
 end)
 if not ok then
    if ui.screen then pcall(function()ui.screen:Destroy()end) end
    return nil,"PRESENTER_GUI_CONSTRUCTION_FAILED"
 end
 return ui,nil
end
return M
