-- Original MM2 MAIN iPad current-own human AUTO OFFER preauthorization.
-- Selecting and confirming ONE safe item explicitly allows the NEXT exact
-- consenting ALT P3/P4 trade window to attempt ONE protected OfferItem.
-- Wrapper itself sends NO requests, OfferItem, Accept or Decline.
-- Final Accept remains exclusively manual; old picker/runner unchanged.
local E=(type(getgenv)=="function" and getgenv()) or _G
local OWNER="PDIDDLER_P3_AUTO_OWNED_PICKER_OWNER"
local JOB="PDIDDLER_P3_AUTO_OWNED_PICKER_USED_JOB"
local TARGET="venossgaming90190"
local GAME=142823291
local AUTORUNNER="182255295eafcd28102e429cc377d06c8f510c1b"
local CHOICES_REV="2b030fe448d9fd039418aeb603e9b63d0e6b553f"
local GEOMETRY_REV="5b8ee35d7f281c23d9c2181abd97a063e59a0660"
if game.PlaceId~=GAME or E[OWNER]~=nil or E[JOB]==game.JobId
    or E.PDIDDLER_P3_OWNED_PICKER_OWNER~=nil
    or E.PDIDDLER_P3_OWNED_PICKER_USED_JOB==game.JobId
    or E.PDIDDLER_SUPERVISED_P3_NATIVE_OWNER~=nil
    or E.PDIDDLER_SUPERVISED_P3_USED_JOB==game.JobId
    or E.PDIDDLER_SUPERVISED_P3_ONE_ITEM_USED_JOB==game.JobId
    or E.PDIDDLER_SUPERVISED_P3_AUTO_USED_JOB==game.JobId
    or E.PDIDDLER_OUTGOING_SESSION~=nil
    or E.PDIDDLER_PART4_SESSION~=nil
    or E.PDIDDLER_SUPERVISED_FOUR_SLOT_GUIDE_JOB==game.JobId
    or E.PDIDDLER_SUPERVISED_ONE_ITEM_GUIDE_JOB==game.JobId
    or E.PDIDDLER_AUTOTRADE_ACTIVE==true
    or E.PDIDDLER_PART4_CONTROLLER_ACTIVE==true
    or E.PDIDDLER_OUTGOING_CONTROLLER_ACTIVE==true then
 warn("[P3 PICKER] Fresh original MM2 job with no other pdiddler scripts required")
 return nil
end
local players=game:GetService("Players")
local me=players.LocalPlayer
local pg=me and me:FindFirstChildOfClass("PlayerGui")
local target=players:FindFirstChild(TARGET)
local world=game:GetService("Workspace")
local camera=world and world.CurrentCamera
if not me or not pg or not target or target==me or
 target.Parent~=players or target.Name~=TARGET or
 players:GetPlayerByUserId(target.UserId)~=target or
 not camera then
 warn("[P3 PICKER] Exact consenting ALT, MAIN PlayerGui and camera required")
 return nil
end
local uid=target.UserId
local function exactAlt()
 return target.Parent==players and target.Name==TARGET
   and players:FindFirstChild(TARGET)==target
   and players:GetPlayerByUserId(uid)==target
end
local function noTrade()
 for _,name in ipairs({"TradeGUI","TradeGUI_Phone"}) do
  local screen=pg:FindFirstChild(name)
  if screen and screen.Enabled==true then
   local container=screen:FindFirstChild("Container")
   local t=container and
    (container:FindFirstChild("Trade") or
     container:FindFirstChild("Main"))
   if t and container.Visible==true and t.Visible==true then
    return false
   end
  end
 end
 return true
end
if not noTrade() then
 warn("[P3 PICKER] Do not open trade before starting the P3 runner")
 return nil
end
local function loadFrozen(rev,path)
 local url="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
  ..rev.."/pdiddler/"..path
 local ok,src=pcall(function()return game:HttpGet(url)end)
 if not ok or type(src)~="string" or #src<100 or #src>32000 then
  return nil
 end
 local compiler=loadstring or load
 if type(compiler)~="function" then return nil end
 local success,mod=pcall(function()return assert(compiler(src))()end)
 return success and type(mod)=="table" and mod or nil
end
local model=loadFrozen(CHOICES_REV,"supervised/p3_one_item_owned_selection.lua")
local geometry=loadFrozen(GEOMETRY_REV,"new_part4/stage100_screen_prompt_overlay.lua")
if not model or type(model.build)~="function" or
 not geometry or type(geometry.choose)~="function" then
 warn("[P3 PICKER] Immutable read-only choice source unavailable")
 return nil
end
local owner={job=game.JobId,live=true,state="LOADING",startedAt=os.clock()}
-- Keep the user's exact selected raw weapon in private closure memory.
-- Global owner/status object must not be able to retarget a physical tap.
local selected=nil
local profileReadAt=nil
E[OWNER]=owner
local ui={}
local made=pcall(function()
 ui.screen=Instance.new("ScreenGui")
 ui.screen.Name="PDIDDLER_OneItem_AutoConsent"
 ui.screen.ResetOnSpawn=false
 ui.screen.IgnoreGuiInset=true
 ui.screen.DisplayOrder=160
 ui.screen.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
 ui.screen.Parent=pg
 ui.frame=Instance.new("Frame")
 ui.frame.Name="PickerPanel"
 ui.frame.BackgroundColor3=Color3.fromRGB(28,23,40)
 ui.frame.BorderSizePixel=0
 ui.frame.Active=true
 ui.frame.Parent=ui.screen
 local corner=Instance.new("UICorner")
 corner.CornerRadius=UDim.new(0,10)
 corner.Parent=ui.frame
 local stroke=Instance.new("UIStroke")
 stroke.Color=Color3.fromRGB(177,128,239)
 stroke.Thickness=1
 stroke.Parent=ui.frame
 local function label(n,y,h,sz)
  local o=Instance.new("TextLabel")
  o.Name=n
  o.BackgroundTransparency=1
  o.TextColor3=Color3.fromRGB(255,255,255)
  o.TextSize=sz
  o.TextWrapped=true
  o.Font=Enum.Font.GothamBold
  o.TextXAlignment=Enum.TextXAlignment.Left
  o.Position=UDim2.fromOffset(12,y)
  o.Size=UDim2.fromOffset(328,h)
  o.Parent=ui.frame
  return o
 end
 ui.title=label("PickTitle",5,23,14)
 ui.title.Text="MAIN - AUTHORIZE ONE AUTO OFFER"
 ui.status=label("PickStatus",30,24,11)
 ui.status.Text="Choose ONE owned item to auto-place for exact ALT."
 ui.scroll=Instance.new("ScrollingFrame")
 ui.scroll.Name="OwnedChoices"
 ui.scroll.Position=UDim2.fromOffset(12,57)
 ui.scroll.Size=UDim2.fromOffset(332,91)
 ui.scroll.CanvasSize=UDim2.fromOffset(0,0)
 ui.scroll.ScrollBarThickness=6
 ui.scroll.BackgroundColor3=Color3.fromRGB(15,13,24)
 ui.scroll.BorderSizePixel=0
 ui.scroll.Parent=ui.frame
 ui.detail=label("SelectedOne",153,23,11)
 ui.detail.Text="Confirming will authorize one future AUTO item offer."
 local function btn(n,text,x,w)
  local o=Instance.new("TextButton")
  o.Name=n
  o.Text=text
  o.TextSize=12
  o.Font=Enum.Font.GothamBold
  o.TextColor3=Color3.fromRGB(255,255,255)
  o.BackgroundColor3=Color3.fromRGB(77,54,113)
  o.Size=UDim2.fromOffset(w,28)
  o.Position=UDim2.fromOffset(x,183)
  o.Parent=ui.frame
  return o
 end
 ui.confirm=btn("ConfirmOwnedOne","AUTHORIZE 1 AUTO OFFER",12,213)
 ui.cancel=btn("CancelOwnedOne","STOP",235,109)
 ui.confirm.Visible=false
 ui.confirm.Active=false
end)
if not made then
 if ui.screen then pcall(function()ui.screen:Destroy()end)end
 E[OWNER]=nil
 warn("[P3 PICKER] On-screen owned picker unavailable")
 return nil
end
local function stop(reason)
 if not owner.live then return false end
 owner.live=false
 owner.state=tostring(reason or "STOPPED")
 E[JOB]=game.JobId
 E[OWNER]=nil
 pcall(function()ui.screen:Destroy()end)
 print("[P3 PICKER] "..owner.state.." | no trading initiated by picker")
 return true
end
ui.cancel.Activated:Connect(function()stop("OPERATOR_CANCELLED")end)
local function fail(reason)
 if not owner.live then return end
 owner.state="BLOCKED"
 ui.status.Text="BLOCKED: "..tostring(reason)
 ui.detail.Text="STOP and join a fresh server. No item was offered."
 ui.confirm.Visible=false
 ui.confirm.Active=false
end
local function place()
 if not owner.live or not camera or not noTrade() then
  return false
 end
 local v=camera.ViewportSize
 if not v then return false end
 local rect=geometry.choose({x=v.X,y=v.Y},nil,{w=356,h=216})
 if not rect then return false end
 local ok=pcall(function()
  ui.frame.Position=UDim2.fromOffset(rect.x,rect.y)
  ui.frame.Size=UDim2.fromOffset(rect.w,rect.h)
 end)
 return ok
end
if not place() then
 stop("VIEWPORT_NO_SAFE_PICKER_SPACE")
 return nil
end
local function active()
 return owner.live and E[OWNER]==owner and game.JobId==owner.job
   and me.Parent==players and
   me:FindFirstChildOfClass("PlayerGui")==pg and
   ui.screen.Parent==pg and exactAlt() and noTrade()
end
local function parseCurrent()
 local RS=game:GetService("ReplicatedStorage")
 local remoteRoot=RS:FindFirstChild("Remotes")
 local inv=remoteRoot and remoteRoot:FindFirstChild("Inventory")
 local remote=inv and inv:FindFirstChild("GetProfileData")
 local db=RS:FindFirstChild("Database")
 local syncModule=db and db:FindFirstChild("Sync")
 if not remote or not remote:IsA("RemoteFunction") or
    not syncModule then return nil,"OWN_INVENTORY_OR_SYNC_MISSING" end
 local sync
 local got,s=pcall(require,syncModule)
 if got then sync=s end
 if not sync and type(setthreadidentity)=="function" then
  local oldIdentity=8
  if type(getthreadidentity)=="function" then
   local ok,n=pcall(getthreadidentity)
   if ok and type(n)=="number" then oldIdentity=n end
  end
  pcall(setthreadidentity,2)
  local ok,n=pcall(require,syncModule)
  pcall(setthreadidentity,oldIdentity)
  if ok then sync=n end
 end
 if type(sync)~="table" then return nil,"GAME_SYNC_NOT_READABLE" end
 -- One in-flight client RemoteFunction read only; after 8 seconds fail
 -- closed, never retry a late or ambiguous profile response.
 local done=false
 local success=false
 local raw=nil
 local started=os.clock()
 task.spawn(function()
  success,raw=pcall(function()return remote:InvokeServer()end)
  done=true
 end)
 while not done and active() and os.clock()-started<8 do
  task.wait(0.05)
 end
 if not active() then return nil,"PICKER_SESSION_OR_ALT_CHANGED" end
 if not done then return nil,"OWN_PROFILE_READ_TIMEOUT_NO_RETRY" end
 if not success then return nil,"OWN_PROFILE_READ_FAILED" end
 local ok,r=pcall(model.build,raw,sync)
 if not ok or type(r)~="table" or
    r.status~="CLIENT_ELIGIBLE_OWN_CHOICES" or
    type(r.choices)~="table" or #r.choices==0 or
    r.authorizesOffer~=false or
    r.authorizesAccept~=false or
    r.serverCompletionProven~=false then
  return nil,type(r)=="table" and r.reason
     or "CURRENT_ITEM_SELECTION_UNVERIFIED"
 end
 return r,nil
end
local function showChoices(r)
 if not active() then return fail("PICKER_SESSION_OR_ALT_CHANGED") end
 owner.state="READY"
 profileReadAt=os.clock()
 ui.status.Text=tostring(#r.choices)..
  " eligible types. Select, then authorize ONE automatic ALT offer."
 for i,item in ipairs(r.choices) do
  local b=Instance.new("TextButton")
  b.Name="OwnedOption_"..tostring(i)
  b.BackgroundColor3=Color3.fromRGB(39,30,58)
  b.TextColor3=Color3.fromRGB(255,255,255)
  b.Font=Enum.Font.GothamBold
  b.TextSize=11
  b.TextXAlignment=Enum.TextXAlignment.Left
  b.Text=tostring(item.display)..
   (item.chroma and " [CHROMA]" or "")..
   "  x"..tostring(item.qty).."  | "..tostring(item.raw)
  b.Position=UDim2.fromOffset(4,(i-1)*31+4)
  b.Size=UDim2.fromOffset(315,27)
  b.Parent=ui.scroll
  b.Activated:Connect(function()
   if not active() or owner.state~="READY" then return end
   selected={raw=item.raw,display=item.display,chroma=item.chroma}
   ui.detail.Text="AUTO OFFER ONCE: "..item.display..
      (item.chroma and " [CHROMA]" or "").." | raw "..item.raw
   ui.confirm.Visible=true
   ui.confirm.Active=true
  end)
 end
 ui.scroll.CanvasSize=UDim2.fromOffset(0,#r.choices*31+8)
end
ui.confirm.Activated:Connect(function()
 if not active() or owner.state~="READY" or
    type(selected)~="table" or
    os.clock()-(profileReadAt or 0)>180 or
    not place() then
  fail("SELECTION_EXPIRED_OR_LIVE_CONTEXT_CHANGED")
  return
 end
 local item=selected
 if not item or type(item.raw)~="string" or
    type(item.display)~="string" or
    type(item.chroma)~="boolean" then
  fail("SELECTION_UNREADABLE")
  return
 end
 -- The human's physical AUTHORIZE 1 AUTO OFFER tap preauthorizes ONLY
 -- this exact raw key + ALT, no request/OfferItem dispatched by picker.
 -- A further ARM P3 tap is required after visible auto-offer warning.
 owner.state="CONSUMED"
 E[JOB]=game.JobId
 owner.live=false
 E[OWNER]=nil
 pcall(function()ui.screen:Destroy()end)
 E.PDIDDLER_SUPERVISED_P3_ONE_ITEM_AUTO_NATIVE={
  enableNativeSupervisor=true,
  finalAcceptMustRemainManual=true,
  altOnlyTest=true,
  allowOneItemPilot=true,
  manualOfferOnly=true,
  noAutomaticAcceptAcknowledged=true,
  targetName=TARGET,
  approvedRawKey=item.raw,
  approvedDisplayName=item.display,
  approvedChromaFlag=item.chroma,
  autoConsent={
   origin="PICKER_HUMAN_APPROVED_AUTO_ONE",
   explicitOneAutomaticPlacement=true,
   singleConsentingAltOnly=true,
   finalAcceptMustRemainManual=true,
   job=game.JobId,altUserId=uid,
   rawKey=item.raw,display=item.display,chroma=item.chroma,
   issuedAt=os.clock(),
  },
 }
 local url="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
   ..AUTORUNNER.."/pdiddler/supervised/SUPERVISED_P3_ONE_ITEM_AUTO_OFFER_NATIVE.lua"
 local ok,source=pcall(function()return game:HttpGet(url)end)
 if not ok or type(source)~="string" or #source<12000 or
     #source>30000 then
  warn("[P3 PICKER] Pinned AUTO runner unavailable; no requests sent")
  return
 end
 local compiler=loadstring or load
 if type(compiler)~="function" then return end
 local ran,res=pcall(function()return assert(compiler(source))()end)
 if not ran or type(res)~="table" then
  warn("[P3 PICKER] P3 runner did not start; use a fresh server")
  return
 end
 print("[P3 AUTO PICKER] One item explicitly PREAUTHORIZED. Read auto-offer warning, then tap ARM P3. Final Accept manual.")
end)
task.spawn(function()
 local r,why=parseCurrent()
 if not owner.live then return end
 if not r then
  fail(why or "CURRENT_ITEMS_UNAVAILABLE")
  return
 end
 showChoices(r)
end)
return {
 stop=function()return stop("OPERATOR_CANCELLED")end,
 status=function()return owner.state end,
}
