-- Gingerscope Stage119 ORIGINAL MM2 MAIN iPad / Delta read-only LastOffer witness.
-- HUMAN opens trade; consenting ALT adds then removes one item. MAIN offers 0.
-- No FireServer, InvokeServer, Accept, Decline, trading, hop, value or webhook.
-- This file returns a start() function; launcher source-pins this revision.
local M={}
local REPO="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
local PINS={
 stage9={"1971b93d324f0275e6a9affb472ac3e804439ed8","pdiddler/new_part4/p4_observer_contract.lua"},
 native={"1971b93d324f0275e6a9affb472ac3e804439ed8","pdiddler/new_part4/p4_native_observer.lua"},
 geometry={"59d869b7d4d8fbcee3f2709e266b47ffb4a05d78","pdiddler/new_part4/stage100_screen_prompt_overlay.lua"},
 lastoffer={"7c12a2e9768ef294b411086deef9ddaf2bee8d21","pdiddler/intelligence_lab/trade_lastoffer_client_audit.lua"},
 stage118={"891d548d2ef77763e9f7e3a679984a646bb9d4b4","pdiddler/intelligence_lab/stage118_lastoffer_gui_correlation.lua"},
 controller={"88bdfa53a8d68d329ad30d6c37e25b100da97460","pdiddler/supervised/stage119_lastoffer_native_controller.lua"}
}
local function result(status,reason)
 return {schema="gingerscope-stage119-native-lastoffer-v1",
 status=status,reason=reason,clientOnly=true,readOnly=true,
 callbackCount=0,guiQuantityTransitions=0,lastOfferEqualityClass="NONE",
 clientGuiQuantityCrossChecked=false,clientGuiCrossChecked=false,
 rawItemIdConfirmed=false,uniqueWeaponInstanceProven=false,
 eventSessionAssociationProven=false,callbackCausalityProven=false,
 serverTradeRevisionProven=false,serverCompletionProven=false,
 actualRequests=0,actualOffers=0,actualAccepts=0,actualDeclines=0,
 actualTeleports=0,authorizesTrade=false,authorizesOffer=false,
 authorizesAccept=false,mayRecordCompletedTrade=false,
 mayReportProfit=false,maySendDiscordWebhook=false,
 mayUseForStrategyLearning=false,tradeOutcome="UNKNOWN"}
end
function M.start(test)
 local g=game
 local tasks=task
 local make=Instance
 local env=getgenv()
 local clock=os.clock
 local signalPrint=print
 local clipboard=type(setclipboard)=="function" and setclipboard
   or type(toclipboard)=="function" and toclipboard or nil
 if type(test)=="table" and test.__stage119_test_only==true then
  -- Injectable test harness; NEVER creates game authorization.
  g=test.game or g;tasks=test.task or tasks;make=test.Instance or make
  env=test.env or env;clock=test.clock or clock
  signalPrint=test.print or signalPrint;clipboard=test.clipboard or clipboard
 end
 local job=tostring(g.JobId)
 local key="PDIDDLER_STAGE119_LASTOFFER_OWNER"
 local used="PDIDDLER_STAGE119_LASTOFFER_USED_JOB"
 if g.PlaceId~=142823291 or job=="" or
    env[key]~=nil or env[used]==job then
  signalPrint("[STAGE119] refused: original MM2, fresh JobId and no other Stage119 run required")
  return nil
 end
 env[used]=job
 local owner={running=true}
 env[key]=owner
 local players=g:GetService("Players")
 local lp=players.LocalPlayer
 local pg=lp and lp:FindFirstChildOfClass("PlayerGui")
 local target=nil
 local src={}
 local ui=nil
 local controller=nil
 local finished=false
 local last=result("LOADING","NO_TRADE_ACTIONS")
 local stamp=tostring(clock())
 local function safeJson(r)
  local o=result(r.status or "INCONCLUSIVE",r.reason or "UNVERIFIED")
  for _,k in ipairs({"callbackCount","guiQuantityTransitions",
    "lastOfferEqualityClass","clientGuiQuantityCrossChecked"}) do
    if r[k]~=nil then o[k]=r[k] end
  end
  if r.nativeStage118Status~=nil then o.nativeStage118Status=r.nativeStage118Status end
  if r.p3ArmObservedClient~=nil then o.p3ArmObservedClient=false end
  local ok,text=pcall(function()
   return g:GetService("HttpService"):JSONEncode(o)
  end)
  if ok and type(text)=="string" and #text<3500 then
   env.PDIDDLER_STAGE119_LAST_JSON=text
   signalPrint("[GINGERSCOPE STAGE119 LASTOFFER] "..text)
   if clipboard then pcall(clipboard,text) end
  else signalPrint("[STAGE119] sanitized report unavailable") end
 end
 local function fail(why)
  if finished then return last end
  finished=true;owner.running=false
  if controller then pcall(function()controller.stop()end) end
  last=result("INCONCLUSIVE",why)
  if ui then pcall(function()ui.panel.Visible=false end) end
  safeJson(last)
  return last
 end
 local function fetch(name)
  local pin=PINS[name]
  if not pin then return nil end
  if type(test)=="table" and test.__stage119_test_only==true
    and type(test.sources)=="table" then return test.sources[name] end
  local ok,module=pcall(function()
    local body=g:HttpGet(REPO..pin[1].."/"..pin[2])
    assert(type(body)=="string" and #body>=50 and #body<300000)
    return assert(loadstring(body))()
  end)
  return ok and type(module)=="table" and module or nil
 end
 local function visible(node)
  local n=node
  while n and n~=pg do
   if n:IsA("ScreenGui") and n.Enabled~=true then return false end
   if n:IsA("GuiObject") and n.Visible~=true then return false end
   n=n.Parent
  end
  return n==pg
 end
 local function root()
  if not pg or pg.Parent~=lp then return nil,"PLAYER_GUI_MISSING" end
  local matches={}
  for _,name in ipairs({"TradeGUI_Phone","TradeGUI"}) do
   local screen=pg:FindFirstChild(name)
   local container=screen and screen:FindFirstChild("Container")
   local r=container and container:FindFirstChild("Trade")
   if r and visible(r) then matches[#matches+1]=r end
  end
  if #matches==0 then return nil,"NOT_OPEN" end
  if #matches~=1 then return nil,"MULTIPLE_VISIBLE_TRADE_ROOTS" end
  local r=matches[1]
  local their=r:FindFirstChild("TheirOffer")
  local label=their and their:FindFirstChild("Username")
  if not label or not (label:IsA("TextLabel") or label:IsA("TextButton"))
   or not visible(label) or type(label.Text)~="string" then
   return nil,"TRADE_PARTNER_LABEL_UNVERIFIED"
  end
  local text=label.Text:match("^%s*%((.-)%)%s*$") or label.Text
  text=text:gsub("^@",""):gsub("^%s+",""):gsub("%s+$","")
  if not target or text:lower()~=target.Name:lower() then
   return nil,"TRADE_PARTNER_MISMATCH"
  end
  return r,"CURRENT_EXACT_ALT_TRADE"
 end
 local function alive()
  return owner.running and env[key]==owner and tostring(g.JobId)==job
   and lp and lp.Parent==players and lp:FindFirstChildOfClass("PlayerGui")==pg
   and target and target.Parent==players
   and players:GetPlayerByUserId(target.UserId)==target
 end
 local function uiShow(title,body,r,done)
  if not ui or not ui.panel or not ui.panel.Parent then
   return false,"PANEL_MISSING"
  end
  local world=g:GetService("Workspace")
  local cam=world and world.CurrentCamera
  if not cam or not cam.ViewportSize then return false,"VIEWPORT_UNAVAILABLE" end
  local trade=nil
  if r then
   local ok,pos,sz=pcall(function()return r.AbsolutePosition,r.AbsoluteSize end)
   if not ok or not pos or not sz or type(pos.X)~="number"
     or type(pos.Y)~="number" or type(sz.X)~="number"
     or type(sz.Y)~="number" or sz.X<=0 or sz.Y<=0 then
    return false,"TRADE_BOUNDS_UNAVAILABLE"
   end
   trade={x=pos.X,y=pos.Y,w=sz.X,h=sz.Y}
  end
  local vp={x=cam.ViewportSize.X,y=cam.ViewportSize.Y}
  local place=src.geometry.choose(vp,trade,{w=304,h=148})
  if not place then
   ui.panel.Visible=false
   return false,"ONSCREEN_GUIDE_NO_SAFE_SPACE_OUTSIDE_TRADE"
  end
  local ok=pcall(function()
   ui.panel.Position=UDim2.fromOffset(place.x,place.y)
   ui.panel.Size=UDim2.fromOffset(place.w,place.h)
   ui.title.Text=title
   ui.body.Text=body
   ui.warning.Text="READ ONLY | NEVER FINAL ACCEPT"
   ui.button.Visible=done==true
   ui.panel.Visible=true
  end)
  if not ok then return false,"ONSCREEN_GUIDE_LAYOUT_FAILED" end
  return true
 end
 local function createUI()
  local ok,out=pcall(function()
   local screen=make.new("ScreenGui")
   screen.Name="PDIDDLER_Stage119_LastOffer_ReadOnly"
   screen.ResetOnSpawn=false;screen.IgnoreGuiInset=true
   screen.DisplayOrder=180
   screen.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
   screen.Parent=pg
   local panel=make.new("Frame")
   panel.Name="Instruction";panel.BackgroundColor3=Color3.fromRGB(29,23,43)
   panel.BorderSizePixel=0;panel.Active=false;panel.Visible=false
   panel.Parent=screen
   local stroke=make.new("UIStroke")
   stroke.Color=Color3.fromRGB(170,127,236);stroke.Parent=panel
   local corner=make.new("UICorner")
   corner.CornerRadius=UDim.new(0,8);corner.Parent=panel
   local function label(n,y,h,size)
    local x=make.new("TextLabel");x.Name=n;x.BackgroundTransparency=1
    x.TextColor3=Color3.fromRGB(250,245,255)
    x.Font=Enum.Font.GothamBold;x.TextSize=size;x.TextWrapped=true
    x.TextXAlignment=Enum.TextXAlignment.Left
    x.Position=UDim2.fromOffset(10,y);x.Size=UDim2.fromOffset(282,h)
    x.Active=false;x.Parent=panel
    return x
   end
   local title=label("Step",4,26,14)
   local body=label("Instructions",31,62,13)
   local warning=label("Safety",93,20,11)
   local button=make.new("TextButton")
   button.Name="StopCopy";button.Text="STOP / COPY"
   button.TextSize=13;button.Font=Enum.Font.GothamBold
   button.TextColor3=Color3.fromRGB(255,255,255)
   button.BackgroundColor3=Color3.fromRGB(93,56,137)
   button.Position=UDim2.fromOffset(10,116)
   button.Size=UDim2.fromOffset(282,27)
   button.Active=true;button.Visible=false;button.Parent=panel
   return {screen=screen,panel=panel,title=title,body=body,
    warning=warning,button=button}
  end)
  return ok and out or nil
 end
 if not lp or not pg or lp.Parent~=players then
  return fail("MAIN_PLAYER_GUI_UNAVAILABLE")
 end
 local candidates={}
 for _,p in ipairs(players:GetPlayers()) do
  if p~=lp and type(p.Name)=="string"
    and p.Name:lower()=="venossgaming90190" and p.Parent==players then
   candidates[#candidates+1]=p
  end
 end
 if #candidates~=1 then return fail("EXACT_CONSENTING_ALT_NOT_PRESENT") end
 target=candidates[1]
 for _,name in ipairs({"stage9","native","geometry","lastoffer","stage118","controller"}) do
  src[name]=fetch(name)
  if type(src[name])~="table" then return fail("PINNED_"..name.."_SOURCE_UNAVAILABLE") end
 end
 if type(src.native.new)~="function" or type(src.native.capture)~="function"
  or type(src.stage9.normalize)~="function" or
  type(src.geometry.choose)~="function" or
  type(src.stage118.new)~="function" or
  type(src.controller.new)~="function" then
  return fail("ORIGINAL_READONLY_SOURCE_CONTRACT_MISMATCH")
 end
 local tradeFolder=g:GetService("ReplicatedStorage"):FindFirstChild("Trade")
 if not tradeFolder then return fail("CURRENT_TRADE_REMOTES_UNAVAILABLE") end
 local good,desc=pcall(function()return tradeFolder:GetDescendants()end)
 if not good or type(desc)~="table" or #desc>12000 then
  return fail("REMOTE_SURFACE_UNVERIFIED")
 end
 local remote=nil
 local count=0
 for _,v in ipairs(desc) do
  if v.Name=="UpdateTrade" and v:IsA("RemoteEvent") then
   remote=v;count=count+1
  end
 end
 if count~=1 or not remote then return fail("UNIQUE_UPDATE_TRADE_UNAVAILABLE") end
 ui=createUI()
 if not ui then return fail("NONOVERLAPPING_GUIDE_CREATION_FAILED") end
 local scopeId="stage119:"..stamp
 local observerCache=nil
 controller=src.controller.new({
  now=clock,isLive=alive,findRoot=root,
  scope=function(r)return {session=scopeId,jobId=job,root=r,
   localPlayer=lp,partnerPlayer=target}end,
  newObserver=function(r)
   local proxy={normalize=function(raw,trust)
    observerCache=raw
    return src.stage9.normalize(raw,trust)
   end}
   return src.native.new({
    game=g,players=players,root=r,session=scopeId,
    jobId=job,partnerUserId=target.UserId,localUserId=lp.UserId,
    contract=proxy,ownInventory=nil,opponentInventory=nil,
    marketFresh=function()return false end})
  end,
  capture=function(observer,scope)
   if not alive() then return nil end
   observerCache=nil
   local ok,o,diag=pcall(src.native.capture,observer)
   if not ok or type(o)~="table" or type(diag)~="table"
    or o.tradeOpen~=true or o.session~=scope.session
    or o.quoteSafe~=false or diag.authorizesTrade~=false
    or diag.authorizesAccept~=false or type(observerCache)~="table"
    or observerCache.tradeOpen~=true or observerCache.contextOK~=true
    or observerCache.session~=scope.session then
    return nil
   end
   return {session=scope.session,jobId=scope.jobId,
    root=scope.root,localPlayer=lp,partnerPlayer=target,raw=observerCache}
  end,
  connect=function(callback)
   return remote.OnClientEvent:Connect(callback)
  end,
  bridge=src.stage118,audit=src.lastoffer,stage9=src.stage9,
  show=uiShow,hide=function()if ui then ui.panel.Visible=false end end
 })
 if not controller then return fail("NATIVE_CLIENT_CONTROLLER_UNAVAILABLE") end
 local initial=controller.tick()
 if initial.status=="INCONCLUSIVE" then return fail(initial.reason) end
 ui.button.Activated:Connect(function()
  if finished then return end
  last=controller.stop()
  finished=true;owner.running=false
  safeJson(last)
  pcall(function()ui.screen:Destroy()end)
 end)
 -- A single non-mutating read loop. No loops after terminal result.
 tasks.spawn(function()
  while owner.running and not finished do
   local r=controller.tick()
   last=r
   if r.status=="INCONCLUSIVE" then
    fail(r.reason);break
   end
   if r.status=="CLIENT_TWO_EVENT_LASTOFFER_GUI_UNATTRIBUTED" then
    signalPrint("[STAGE119] CLIENT-ONLY PASS; MAIN manually Decline, then STOP / COPY.")
    -- Hold the result and panel until the user presses STOP/COPY.
    break
   end
   tasks.wait(0.05)
  end
 end)
 return controller
end
return M
