-- SYSTEM1 full MAIN automatic four-trade TEST: one operator ARM, four new
-- original guarded P3 request epochs, supervised P4 offers/removals/declines.
-- ALT manually ACCEPTS THE REQUEST and changes cheap offers when instructed.
-- NO FINAL ACCEPT! Any failed step stops ALL P3 actions, copies exact error.
-- This is a DRAFT candidate, NOT settlement, pricing, profit or learning.
local E=(type(getgenv)=="function" and getgenv()) or _G
local OWNER_KEY="PDIDDLER_SYSTEM1_MAIN_AUTO_OWNER"
local USED_KEY="PDIDDLER_SYSTEM1_MAIN_AUTO_USED_JOB"
local ALT_NAME="venossgaming90190"
local ORIGINAL_MM2=142823291
local MAIN="a3c209659942e8b45eec5da3555f7cfb83059c59"
local P3_EPOCH="ba76adb21ffe4124c44d6d9a256683861eceb61d"
local SHADOW_PLAN="be8d8c5b77c0c7c345639c53e6a04959728d01a8"
local CTRL="3ec1173c01b95fa97e981fdd368ee33104ebaec4"
local BASE="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
local isTrue=function(x)return x==true end
local conflictNames={
 "PDIDDLER_PART4_CONTROLLER_ACTIVE",
 "PDIDDLER_OUTGOING_CONTROLLER_ACTIVE",
 "PDIDDLER_AUTOTRADE_ACTIVE",
 "PDIDDLER_SUPERVISED_P3_NATIVE_OWNER",
 "PDIDDLER_SUPERVISED_FOUR_SLOT_PILOT",
 "PDIDDLER_SYSTEM1_MULTITRADE_OWNER",
}
local function conflicts()
 for _,key in ipairs(conflictNames) do
  local value=E[key]
  if value~=nil and value~=false then return true end
 end
 return false
end
local function approvedKey(s)
 return type(s)=="string" and #s>0 and #s<=24
     and s:match("^[A-Za-z0-9_]+$")~=nil and
     not s:lower():find("gingerscope",1,true)
end
local function protected(s)
 return type(s)=="string" and
   s:lower():gsub("[^%w]",""):find("gingerscope",1,true)~=nil
end
if game.PlaceId~=ORIGINAL_MM2 or
   E[OWNER_KEY]~=nil or E[USED_KEY]==game.JobId or
   E.PDIDDLER_OUTGOING_SESSION~=nil or
   E.PDIDDLER_PART4_SESSION~=nil or conflicts() then
 warn("[SYSTEM1 AUTO] Fresh original MM2 server with no other trader required")
 return nil
end
local Players=game:GetService("Players")
local World=game:GetService("Workspace")
local Http=game:GetService("HttpService")
local LP=Players.LocalPlayer
local PG=LP and LP:FindFirstChildOfClass("PlayerGui")
local ALT=Players:FindFirstChild(ALT_NAME)
if not PG or not LP or not World or not World.CurrentCamera or
   not ALT or ALT==LP or ALT.Parent~=Players or
   type(ALT.UserId)~="number" or ALT.UserId<=0 or
   ALT.Name~=ALT_NAME or
   Players:GetPlayerByUserId(ALT.UserId)~=ALT then
 warn("[SYSTEM1 AUTO] GUI or exact consenting ALT unavailable")
 return nil
end
local altId=ALT.UserId
local function altExact()
 return ALT.Parent==Players and ALT.Name==ALT_NAME and
   Players:FindFirstChild(ALT_NAME)==ALT and
   Players:GetPlayerByUserId(altId)==ALT
end
local function loadPinned(rev,path,limit)
 local url=BASE..rev.."/pdiddler/"..path
 local ok,src=pcall(function()return game:HttpGet(url)end)
 if not ok or type(src)~="string" or #src<100 or
    #src>(limit or 90000) then return nil end
 local compiler=loadstring or load
 if type(compiler)~="function" then return nil end
 local good,mod=pcall(function()return assert(compiler(src))()end)
 return good and type(mod)=="table" and mod or nil
end
-- The original protected source has survived previous native pilot tests.
local geometry=loadPinned(MAIN,"new_part4/stage100_screen_prompt_overlay.lua",12000)
local protectedIO=loadPinned(MAIN,"supervised/pdiddler4_tradeio_supervised_v2.lua",25000)
local bridge=loadPinned(MAIN,"supervised/supervised_p3_p4_handoff.lua",16000)
local coordinator=loadPinned(MAIN,"supervised/supervised_real_p3_rotation_handoff.lua",16000)
local boot=loadPinned(MAIN,"supervised/supervised_p3_startup_supervisor.lua",15000)
local watchdog=loadPinned(MAIN,"supervised/supervised_p3_continuous_watchdog.lua",10000)
local rawScanner=loadPinned(MAIN,"pdiddler3_scanner_MODULE_v6_5_PART4_STATUS_BRIDGE.lua",95000)
local choicesModule=loadPinned(MAIN,"supervised/p3_one_item_owned_selection.lua",16000)
local outgoingModule=loadPinned(P3_EPOCH,"system1/pdiddler3_outgoing_single_send_epoch.lua",70000)
local planModule=loadPinned(SHADOW_PLAN,"supervised/supervised_four_slot_operator_plan_aba_draft.lua",25000)
local shadowModule=loadPinned(SHADOW_PLAN,"intelligence_lab/p3_shadow_aba_offer_lease.lua",13000)
local controllerModule=loadPinned(CTRL,"system1/system1_main_auto_failstop_controller.lua",26000)
if not geometry or type(geometry.choose)~="function" or
   not protectedIO or type(protectedIO.new)~="function" or
   not bridge or type(bridge.bind)~="function" or
   not coordinator or type(coordinator.new)~="function" or
   not boot or type(boot.new)~="function" or
   not watchdog or type(watchdog.new)~="function" or
   not rawScanner or type(rawScanner.getOwnInventory)~="function" or
   not choicesModule or type(choicesModule.build)~="function" or
   not outgoingModule or type(outgoingModule.run)~="function" or
   not planModule or type(planModule.run)~="function" or
   not shadowModule or type(shadowModule.new)~="function" or
   not controllerModule or type(controllerModule.new)~="function" then
 warn("[SYSTEM1 AUTO] SOURCE_UNAVAILABLE: no request/offer was started")
 return nil
end
local gate={}
local okIO,io=pcall(protectedIO.new,{
 resolveOfferEntry=function()return nil end,
},gate)
if not okIO or type(io)~="table" or
 type(io.trade)~="function" or type(io.offerItem)~="function"
 or type(io.decline)~="function" or type(io.removeOne)~="function"
 or type(io.partnerName)~="function" then
 warn("[SYSTEM1 AUTO] ORIGINAL_PROTECTED_IO_UNAVAILABLE")
 return nil
end
local owner={
 job=game.JobId,running=true,armed=false,
 startAuthorized=false,alt=ALT,offerActive=false,
}
E[OWNER_KEY]=owner
local okId,runNonce=pcall(function()return Http:GenerateGUID(false)end)
if not okId or type(runNonce)~="string" or #runNonce>64 then
 runNonce="GUID_NOT_AVAILABLE"
end
local currentSupervisor=nil
local currentWatchdog=nil
local epochRound=nil
local latestP3="NOT_STARTED"
local currentBound=nil
local boundRoot=nil
local handoffRoot=nil
local handoffFirstSeen=nil
local actionBusy=false
local currentShadow=nil
local shadowLoopLive=false
local haltReason=nil
local controller=nil
local selected={}
local profileReadAt=nil
local latestReceipt=nil
local lastJson=nil
local screen={}
local function copyPayload(payload)
 local data={}
 for k,v in pairs(payload) do data[k]=v end
 data.schema="gingerscope-system1-main-auto-native-v1"
 data.runNonce=runNonce
 data.finalAcceptEverAttempted=false
 data.verifiedCompletedTrades=0
 data.noServerSettlementProof=true
 data.clientOnly=true
 local ok,json=pcall(function()return Http:JSONEncode(data)end)
 if not ok or type(json)~="string" then
  warn("[SYSTEM1 AUTO] ERROR_JSON_ENCODING_FAILED")
  return false
 end
 E.PDIDDLER_SYSTEM1_MAIN_AUTO_LAST_JSON=json
 lastJson=json
 local cp=type(setclipboard)=="function" and setclipboard or
   type(toclipboard)=="function" and toclipboard or
   type(E.setclipboard)=="function" and E.setclipboard
 local copied=false
 if cp then
  local success,answer=pcall(cp,json)
  copied=success and answer~=false
 end
 print("[SYSTEM1 MAIN AUTO JSON] "..json)
 if screen.copy then
  screen.copy.Text=copied and "COPIED" or "COPY ERR"
 end
 return copied
end
local function earlyStop(reason)
 if not owner.running then return false end
 owner.running=false;haltReason=reason
 E[USED_KEY]=owner.job
 pcall(function()if currentWatchdog then currentWatchdog.stop()end end)
 pcall(function()if currentSupervisor then currentSupervisor.stop()end end)
 gate.checkOutbound=nil;shadowLoopLive=false
 copyPayload({
  status="STOPPED",round=0,phase="SETUP",reason=reason,
  lastAction="BEFORE_ARM",completedRounds=0,
  offerAttemptsKnown=false,serverCompletionProven=false,
  tradeOutcome="UNKNOWN",authorizesAccept=false,
  mayUseForStrategyLearning=false,
 })
 if screen.title then
  screen.title.Text="SYSTEM1 AUTO STOPPED"
  screen.body.Text="Error: "..tostring(reason)..". Do not press final Accept."
 end
 return true
end
-- Fixed slot/partner reader used BEFORE callbacks that may send a real remote.
local function exactTrade()
 local seen={}
 for _,name in ipairs({"TradeGUI_Phone","TradeGUI"}) do
  local g=PG:FindFirstChild(name)
  local c=g and g:FindFirstChild("Container")
  local r=c and c:FindFirstChild("Trade")
  if r and g.Enabled==true and c.Visible==true and r.Visible==true then
   seen[#seen+1]=r
  end
 end
 if #seen>1 then return nil,"MULTIPLE_VISIBLE_TRADE_ROOTS" end
 local root=seen[1]
 -- An Accepted flag can coincide with loss of the active protected
 -- trade root. Surface this exact unsafe client condition instead of
 -- mislabeling it as an ordinary unexpected closed trade window.
 -- This does NOT prove that the MM2 server accepted or settled anything.
 if root then
  local our=root:FindFirstChild("YourOffer")
  local their=root:FindFirstChild("TheirOffer")
  local a=our and our:FindFirstChild("Accepted")
  local b=their and their:FindFirstChild("Accepted")
  if not a or not b or type(a.Visible)~="boolean" or
     type(b.Visible)~="boolean" or
     a.Visible~=false or b.Visible~=false then
   return nil,"UNEXPECTED_ACCEPTED_STATE"
  end
 end
 if root and io.trade()~=root then
  return nil,"ORIGINAL_P4_ROOT_CHANGED"
 end
 if root and io.partnerName(root)~=ALT_NAME then
  return nil,"TRADE_PARTNER_NOT_CONSENTING_ALT"
 end
 return root,nil
end
local function targetStillSafe()
 return owner.running and owner.armed and
    E[OWNER_KEY]==owner and game.JobId==owner.job and
    LP.Parent==Players and LP:FindFirstChildOfClass("PlayerGui")==PG
    and altExact() and not conflicts() and
    screen.gui~=nil and screen.gui.Parent==PG
end
local function layoutSafe()
 local t,why=exactTrade()
 if why then return false,why end
 if not screen.gui or screen.gui.Parent~=PG or
    not screen.panel or screen.panel.Parent~=screen.gui then
  return false,"GUI_PANEL_REMOVED"
 end
 local camera=World.CurrentCamera
 if not camera then return false,"CAMERA_LOST" end
 local got,v=pcall(function()return camera.ViewportSize end)
 if not got or not v then return false,"VIEWPORT_LOST" end
 local tb=nil
 if t then
  local ok,p,sz=pcall(function()
   return t.AbsolutePosition,t.AbsoluteSize
  end)
  if not ok or not p or not sz then
   return false,"TRADE_BOUNDS_LOST"
  end
  tb={x=p.X,y=p.Y,w=sz.X,h=sz.Y}
 end
 local r,code=geometry.choose({x=v.X,y=v.Y},tb,{w=340,h=216})
 if not r then return false,"GUI_NO_NONOVERLAPPING_SPACE" end
 local shown=pcall(function()
  screen.panel.Position=UDim2.fromOffset(r.x,r.y)
  screen.panel.Size=UDim2.fromOffset(r.w,r.h)
  screen.panel.Visible=true
 end)
 return shown,shown and "GUI_VISIBLE" or "GUI_LAYOUT_EXCEPTION"
end
local okayUI=pcall(function()
 local gui=Instance.new("ScreenGui")
 gui.Name="PDIDDLER_System1_AUTO_MAIN_4Trades"
 gui.ResetOnSpawn=false
 gui.IgnoreGuiInset=true
 gui.DisplayOrder=155
 gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
 gui.Parent=PG;screen.gui=gui
 local panel=Instance.new("Frame")
 panel.Name="AutomationPanel"
 panel.BackgroundColor3=Color3.fromRGB(33,21,52)
 panel.BorderSizePixel=0;panel.Visible=false
 panel.ZIndex=10;panel.Parent=gui
 screen.panel=panel
 local stroke=Instance.new("UIStroke")
 stroke.Color=Color3.fromRGB(180,123,244)
 stroke.Thickness=1;stroke.Parent=panel
 local corner=Instance.new("UICorner")
 corner.CornerRadius=UDim.new(0,10)
 corner.Parent=panel
 local function textLabel(name,y,h,size)
  local x=Instance.new("TextLabel")
  x.Name=name;x.BackgroundTransparency=1
  x.TextColor3=Color3.fromRGB(255,255,255)
  x.TextSize=size;x.TextWrapped=true
  x.Font=Enum.Font.GothamSemibold
  x.TextXAlignment=Enum.TextXAlignment.Left
  x.TextYAlignment=Enum.TextYAlignment.Top
  x.ZIndex=11
  x.Position=UDim2.fromOffset(10,y)
  x.Size=UDim2.fromOffset(320,h)
  x.Parent=panel;return x
 end
 screen.title=textLabel("AutoTitle",7,24,14)
 screen.body=textLabel("AutoInstructions",30,60,13)
 screen.status=textLabel("AutoEvidence",93,30,11)
 screen.warning=textLabel("NeverAccept",126,23,11)
 screen.warning.Text="FINAL ACCEPT DISABLED | TEST ONLY"
 local scroll=Instance.new("ScrollingFrame")
 scroll.Name="ApprovedOwnedChoices"
 scroll.Position=UDim2.fromOffset(10,108)
 scroll.Size=UDim2.fromOffset(318,70)
 scroll.CanvasSize=UDim2.fromOffset(0,0)
 scroll.ScrollBarThickness=4
 scroll.BackgroundColor3=Color3.fromRGB(17,12,29)
 scroll.ZIndex=11;scroll.Parent=panel
 screen.choices=scroll
 local function button(name,label,x,w)
  local b=Instance.new("TextButton")
  b.Name=name;b.Text=label
  b.Font=Enum.Font.GothamBold
  b.TextColor3=Color3.fromRGB(255,255,255)
  b.TextSize=11
  b.BackgroundColor3=Color3.fromRGB(89,53,132)
  b.ZIndex=12
  b.Position=UDim2.fromOffset(x,183)
  b.Size=UDim2.fromOffset(w,27)
  b.Parent=panel
  return b
 end
 screen.stop=button("StopAuto","STOP",10,56)
 screen.copy=button("CopyAuto","COPY",72,56)
 screen.reset=button("ResetChoices","RESET",134,59)
 screen.arm=button("ArmAllFour","ARM 4",198,61)
 screen.armAdaptive=button("ArmFiveAdaptive","ARM 5",264,66)
 screen.armAdaptive.Visible=false
 screen.armAdaptive.Active=false
 screen.arm.Visible=false
 screen.arm.Active=false
end)
if not okayUI or not screen.gui or not screen.arm or
   not screen.armAdaptive or not screen.copy then
 earlyStop("AUTO_GUI_CREATION_FAILED")
 return nil
end
local safe,layoutReason=layoutSafe()
if not safe then
 earlyStop(layoutReason or "GUI_LAYOUT_UNAVAILABLE")
 return nil
end
screen.title.Text="SYSTEM 1 AUTO | SELECT 2"
screen.warning.Visible=false
screen.status.Position=UDim2.fromOffset(10,83)
screen.body.Text="Select TWO distinct, cheap OWNED weapons to test. MAIN will auto-offer, remove and decline. ALT accepts REQUESTS + changes items."
screen.status.Text="Reading current owned MM2 inventory..."
-- The original scanner may draw its old full-screen inventory GUI; hide it
-- so this safety panel never obscures original MM2 trade controls.
local function hideOldScanner()
 pcall(function()
  local g=PG:FindFirstChild("MM2EligibilityScannerT41")
  if g and g:IsA("ScreenGui") then g.Enabled=false end
 end)
end
local function restrictedScanner()
 local scanner=setmetatable({}, {__index=rawScanner})
 function scanner.isWhitelisted(uid)
  if uid~=altId or not altExact() then return false end
  local ok,yes=pcall(rawScanner.isWhitelisted,uid)
  return ok and yes==true
 end
 function scanner.getRecord(uid)
  if not scanner.isWhitelisted(uid) then return nil end
  local ok,r=pcall(rawScanner.getRecord,uid)
  if ok and type(r)=="table" and r.player==ALT and
     r.state=="whitelist" then return r end
  return nil
 end
 function scanner.getWhitelist()
  if not scanner.getRecord(altId) then return {} end
  local ok,list=pcall(rawScanner.getWhitelist)
  if not ok or type(list)~="table" then return {} end
  for _,p in ipairs(list) do
   if p==ALT then return {ALT} end
  end
  return {}
 end
 return scanner
end
local scanner=restrictedScanner()
local function availableForArm()
 local ok,list=pcall(scanner.getWhitelist)
 return ok and type(list)=="table" and #list==1
   and list[1]==ALT and altExact()
end
local function parseOwned()
 local RS=game:GetService("ReplicatedStorage")
 local rf=RS:FindFirstChild("Remotes")
 local inventory=rf and rf:FindFirstChild("Inventory")
 local profile=inventory and inventory:FindFirstChild("GetProfileData")
 local db=RS:FindFirstChild("Database")
 local syncNode=db and db:FindFirstChild("Sync")
 if not profile or not profile:IsA("RemoteFunction") or
    not syncNode then return nil,"OWN_PROFILE_SOURCE_MISSING" end
 local okSync,sync=pcall(require,syncNode)
 if (not okSync or type(sync)~="table") and
     type(setthreadidentity)=="function" then
  -- Match the original proven owned-picker fallback; restore the previous
  -- thread identity even on error. Never assume this grants item authority.
  local oldIdentity=8
  if type(getthreadidentity)=="function" then
   local known,previous=pcall(getthreadidentity)
   if known and type(previous)=="number" then
    oldIdentity=previous
   end
  end
  pcall(setthreadidentity,2)
  local okay,ret=pcall(require,syncNode)
  pcall(setthreadidentity,oldIdentity)
  if okay then okSync=true;sync=ret end
 end
 if not okSync or type(sync)~="table" then
  return nil,"OWN_GAME_WEAPON_CATALOG_UNAVAILABLE"
 end
 local done=false
 local okRaw=false
 local raw=nil
 task.spawn(function()
  okRaw,raw=pcall(function()return profile:InvokeServer()end)
  done=true
 end)
 local began=os.clock()
 while not done and owner.running and os.clock()-began<8 do
  task.wait(0.05)
 end
 if not owner.running or not altExact() then
  return nil,"PICKER_ALT_OR_JOB_LOST"
 end
 if not done then return nil,"OWN_PROFILE_READ_TIMEOUT" end
 if not okRaw or type(raw)~="table" then
  return nil,"OWN_PROFILE_READ_FAILED"
 end
 local ok,result=pcall(choicesModule.build,raw,sync)
 if not ok or type(result)~="table" or
    result.status~="CLIENT_ELIGIBLE_OWN_CHOICES" or
    result.authorizesOffer~=false or
    result.authorizesAccept~=false or
    result.serverCompletionProven~=false or
    type(result.choices)~="table" then
  return nil,"OWN_ELIGIBLE_CHOICES_UNAVAILABLE"
 end
 return result.choices,nil
end
local function refreshSelection()
 if not owner.running or owner.armed then return end
 local count=#selected
 screen.status.Text="Chosen: "..tostring(count).."/2 | ALT eligible: "..
   (availableForArm() and "YES" or "WAITING")
 screen.arm.Visible=count==2 and availableForArm()
 screen.arm.Active=screen.arm.Visible
 screen.armAdaptive.Visible=screen.arm.Visible
 screen.armAdaptive.Active=screen.arm.Visible
 if count==2 then
  screen.body.Text="ARM 4: 4 automatic requests; 3 offers/removals; 4 declines. ARM 5: 5 requests; 5 offers/removals/declines; ALT swap. NEVER final Accept."
 end
end
local function showOwned(choices)
 if not owner.running then return end
 if type(choices)~="table" or #choices<2 then
  earlyStop("FEWER_THAN_TWO_ELIGIBLE_OWN_WEAPON_TYPES")
  return
 end
 screen.status.Text="Tap any 2 distinct cheap weapons. Never use Gingerscope."
 for index,choice in ipairs(choices) do
  if approvedKey(choice.raw) and
     type(choice.display)=="string" and #choice.display>0 and
     #choice.display<=24 and not protected(choice.display) and
     type(choice.chroma)=="boolean" and
     type(choice.qty)=="number" and choice.qty>=1 then
   local b=Instance.new("TextButton")
   b.Name="OwnedChoice_"..tostring(index)
   b.Text=choice.display..
     (choice.chroma and " [CHROMA]" or "")..
     " x"..tostring(choice.qty)
   b.TextSize=11
   b.Font=Enum.Font.GothamSemibold
   b.TextXAlignment=Enum.TextXAlignment.Left
   b.TextColor3=Color3.fromRGB(255,255,255)
   b.BackgroundColor3=Color3.fromRGB(58,39,88)
   b.ZIndex=12
   b.Position=UDim2.fromOffset(3,3+(index-1)*30)
   b.Size=UDim2.fromOffset(291,27)
   b.Parent=screen.choices
   b.Activated:Connect(function()
    if not owner.running or owner.armed or
       #selected>=2 or
       not altExact() then return end
    for _,p in ipairs(selected) do
     if p.raw==choice.raw then return end
    end
    selected[#selected+1]={
     raw=choice.raw,display=choice.display,chroma=choice.chroma,
    }
    refreshSelection()
   end)
  end
 end
 screen.choices.CanvasSize=UDim2.fromOffset(0,#choices*30+8)
 profileReadAt=os.clock()
 refreshSelection()
end
screen.reset.Activated:Connect(function()
 if owner.armed or not owner.running then return end
 selected={}
 refreshSelection()
end)
local function liveBeforeAction()
 if not targetStillSafe() or not availableForArm() then return false end
 local safe=layoutSafe()
 return safe==true and currentSupervisor~=nil and
    currentSupervisor.isP3Paused()==true
end
local function currentClientSnapshot()
 if not liveBeforeAction() then return nil,"EXACT_ALT_P3_LEASE_NOT_SAFE" end
 local ok,bound,info=pcall(currentSupervisor.currentBoundReadOnly)
 if not ok or type(bound)~="table" or
    type(bound.capture)~="function" or
    type(info)~="table" or
    info.status~="P3_BOUND_CANDIDATE_READ_ONLY" then
  return nil,"FRESH_PROTECTED_P3_P4_BOUND_MISSING"
 end
 local valid,s=pcall(bound.capture)
 if not valid or type(s)~="table" or
    s.status~="CLIENT_UNPRICED_TWO_SIDED_SNAPSHOT"
    or s.partnerExactClientBound~=true
    or s.part3Paused~=true or s.part4TradeVisible~=true
    or s.authorizesOffer~=false or s.authorizesAccept~=false
    or s.rawItemIdsAuthenticated~=false or s.pricesAuthenticated~=false
    or s.offerRevisionAuthenticated~=false
    or s.serverCompletionProven~=false
    or s.tradeOutcome~="UNKNOWN" then
  return nil,"ORIGINAL_P3_P4_CLIENT_SNAPSHOT_REJECTED"
 end
 return {bound=bound,snap=s},nil
end
local function currentlyOwned()
 local ok,inv,why=pcall(rawScanner.getOwnInventory)
 if not ok or type(inv)~="table" or
    type(inv.items)~="table" or inv.unmapped~=0
    or inv.badQty~=0 or
    type(inv.rawOwned)~="number" or inv.rawOwned<2 then
  return false
 end
 for _,wanted in ipairs(selected) do
  local count=0
  for _,item in ipairs(inv.items) do
   if item.id==wanted.raw then
    count+=1
    local display=item.name
    if wanted.chroma and type(display)=="string" then
     display=display:gsub("^[Cc][Hh][Rr][Oo][Mm][Aa]%s+","")
    end
    if count>1 or type(display)~="string" or
      display:lower()~=wanted.display:lower() or
      item.cat~="Weapons" or
      type(item.qty)~="number" or item.qty<1 or
      (item.page=="chroma")~=wanted.chroma or
      protected(display) or protected(item.id) then
     return false
    end
   end
  end
  if count~=1 then return false end
 end
 return true
end
local function newContext(supervisorGetter,watchdogGetter)
 return {
  getJobId=function()return game.JobId end,
  getP3Session=function()return E.PDIDDLER_OUTGOING_SESSION end,
  onScreenSafe=function()return owner.running and layoutSafe()==true end,
  watchdogReady=function()
   local monitor=watchdogGetter()
   return monitor~=nil and monitor.isReady()==true
  end,
  noOtherTransactionOwner=function()
   return owner.running and not conflicts() and
     E.PDIDDLER_PART4_SESSION==nil
  end,
  readyCheck=function()
   local safe=layoutSafe()
   return owner.running and altExact() and safe==true and
     availableForArm()
  end,
 }
end
local adapters={}
function adapters.startEpoch(round,nonce)
 if not targetStillSafe() or not availableForArm()
    or io.trade()~=nil or currentSupervisor~=nil or
    currentWatchdog~=nil or actionBusy or
    type(nonce)~="number" or nonce~=round then
  return false,"FRESH_EPOCH_PRECONDITION_FAILED"
 end
 local ctx=newContext(function()return currentSupervisor end,
                     function()return currentWatchdog end)
 local okay,sup,why=pcall(boot.new,
    scanner,outgoingModule,coordinator,bridge,io,Players,LP,ctx)
 if not okay or type(sup)~="table" then
  return false,"NEW_ORIGINAL_P3_SESSION_CREATION_FAILED"
 end
 currentSupervisor=sup;epochRound=round
 handoffRoot=nil;handoffFirstSeen=nil
 latestP3="P3_SUPERVISOR_PREPARED_NOT_ARMED"
 local watcherCtx={
  getJobId=function()return game.JobId end,
  isLive=function()return targetStillSafe() end,
  onStatus=function(r)
   latestP3=type(r)=="table" and r.status or "P3_STATUS_UNKNOWN"
   if latestP3=="BLOCKED" then
    haltReason="ORIGINAL_P3_WATCHDOG_BLOCKED"
   end
  end,
 }
 local watcher,whyWatch=watchdog.new(sup,{
   isPaused=function()return sup.isP3Paused()end,
 },io,watcherCtx,{
   spawn=function(fn)task.spawn(fn)end,
   wait=function(s)task.wait(s)end,
   now=function()return os.clock()end,
 })
 if not watcher then
  pcall(sup.stop)
  currentSupervisor=nil
  return false,"P3_WATCHDOG_CONSTRUCTION_FAILED"
 end
 currentWatchdog=watcher
 local started=watcher.start()
 if started~=true then
  pcall(watcher.stop);currentWatchdog=nil
  pcall(sup.stop);currentSupervisor=nil
  return false,"P3_WATCHDOG_START_FAILED"
 end
 local before=os.clock()
 while owner.running and not watcher.isReady() and
   os.clock()-before<2.5 do
  task.wait(0.05)
 end
 if not owner.running or not watcher.isReady() then
  return false,"P3_NO_FRESH_WATCHDOG_HEARTBEAT"
 end
 local good,armed=pcall(sup.arm,{
  explicitUserAuthorization=true,
  allowRealP3RequestRotation=true,
  finalAcceptMustRemainManual=true,
 })
 if not good or armed~=true then
  return false,"P3_EXACT_ALT_REQUEST_ARM_DENIED"
 end
 return true,"CLIENT_EPOCH_"..tostring(round)
end
local function blockedInspection(staticCode)
 return {
   sessionFresh=false,exactPartner=false,
   noOtherController=false,p3Status="BLOCKED",
   errorCode=staticCode,
 }
end
function adapters.inspect(round,epoch)
 if game.JobId~=owner.job then
  return blockedInspection("JOB_CHANGED")
 end
 if not altExact() then
  return blockedInspection("ALT_LEFT_OR_REPLACED")
 end
 if conflicts() then
  return blockedInspection("COMPETING_CONTROLLER_ACTIVE")
 end
 if not currentWatchdog or
     currentWatchdog.isReady()~=true then
  return blockedInspection("P3_WATCHDOG_LOST")
 end
 if epochRound~=round or not currentSupervisor then
  return blockedInspection("P3_SESSION_EPOCH_MISMATCH")
 end
 if not targetStillSafe() or haltReason then
  return blockedInspection("CLIENT_GUI_OR_OPERATOR_SESSION_LOST")
 end
 local root,why=exactTrade()
 if why then
  return blockedInspection(why)
 end
 if root then
  if handoffRoot~=root then
   handoffRoot=root
   handoffFirstSeen=os.clock()
  end
  local b,whyClient=currentClientSnapshot()
  if not b then
   -- A visible GUI may precede the ORIGINAL P3 processed("trade-open")
   -- event/paused coordinator by a frame. Never interpret the raw GUI
   -- as a valid bound trade or dispatch an item during this grace window.
   -- After a bounded 1.5s, fail closed with a precise clipboard error.
   if latestP3~="BLOCKED" and
      handoffFirstSeen~=nil and
      os.clock()-handoffFirstSeen<=1.5 then
    return {
     sessionFresh=true,exactPartner=true,noOtherController=true,
     p3Status="P3_BINDING_PENDING_CLIENT_ONLY",
     root=nil,snapshot=nil,
    }
   end
   return blockedInspection("ORIGINAL_P3_P4_CLIENT_SNAPSHOT_REJECTED")
  end
  handoffRoot=nil;handoffFirstSeen=nil
  -- Use the original protected P3/P4 read-only lease, never caller GUI claim.
  currentBound=b.bound;boundRoot=root
  return {
   sessionFresh=true,exactPartner=true,noOtherController=true,
   p3Status=latestP3,root=root,snapshot=b.snap,
  }
 end
 currentBound=nil;boundRoot=nil
 handoffRoot=nil;handoffFirstSeen=nil
 return {
  sessionFresh=true,exactPartner=true,noOtherController=true,
  p3Status=latestP3,root=nil,snapshot=nil,
 }
end
function adapters.offerApproved(round,count,epoch,choiceIndex)
 if actionBusy or epochRound~=round or
    not liveBeforeAction() or
    not ((round==3 and count==1 and choiceIndex==1) or
         (round==4 and count==2 and choiceIndex==1) or
         (round==5 and count==1 and (choiceIndex==1 or choiceIndex==2))) then
  return nil
 end
 local b=currentClientSnapshot()
 if not b or b.snap.physicalOwnSlots~=0 or
    b.snap.physicalTheirSlots~=0 then return nil end
 if not currentlyOwned() then return nil end
 actionBusy=true
 local approval={
  armed=true,manualOfferOnly=true,
  noAutomaticAcceptAcknowledged=true,
  weaponKeys={},expectedDisplayNames={},expectedChromaFlags={},
 }
 for i=1,count do
  approval.weaponKeys[i]=selected[choiceIndex+i-1].raw
  approval.expectedDisplayNames[i]=selected[choiceIndex+i-1].display
  approval.expectedChromaFlags[i]=selected[choiceIndex+i-1].chroma
 end
 local shadowLive=false
 local opts={
  wait=function(seconds)task.wait(seconds)end,
  onBeforeItem=function(index,total,priorVisible)
   if index~=priorVisible+1 or total~=count or
      not liveBeforeAction() or io.trade()~=boundRoot then
    return false end
   local ok=layoutSafe()
   if ok~=true then return false end
   task.wait(0.03)
   return owner.running and liveBeforeAction()
  end,
  experimentalABAShadowRequired=count>1,
  makeShadowWitness=function(bound)
   local shadow,reason=shadowModule.new(bound,{
    root=function()return io.trade()end,
    live=function()
      return owner.running and not haltReason and
        currentSupervisor~=nil and
        currentSupervisor.isP3Paused()==true and
        io.trade()==boundRoot
    end,
   })
   return shadow
  end,
  onShadowPrepared=function(w)
   if not liveBeforeAction() then return false end
   local yes,state=pcall(w.poll)
   if not yes or type(state)~="table" or
     state.status~="PREPARED" then return false end
   shadowLive=true
   local started=pcall(function()
    task.spawn(function()
     while shadowLive and owner.running and
       io.trade()==boundRoot do
      local safe,res=pcall(w.poll)
      if not safe or type(res)~="table" or
         res.status=="STALE" or res.status=="BLOCKED" then
       haltReason="SHADOW_OBSERVER_STALE_DURING_PLACEMENT"
       break
      end
      task.wait(0.035)
     end
    end)
   end)
   return started==true
  end,
 }
 -- The shadow guards the *prepared next outbound* interval only. Once
 -- the original protected TradeIO successfully performs that next
 -- outgoing send, the expected OWN-side item-2 GUI change invalidates
 -- the old hypothetical shadow; that is NOT an unexpected ALT revision.
 -- Detach this specific witness immediately after the guarded IO call
 -- returns. The PR240 gate still checked it at the actual remote boundary.
 local originalOfferItem=io.offerItem
 local guardedOfferCalls=0
 io.offerItem=function(item)
  guardedOfferCalls+=1
  local accepted,reason=originalOfferItem(item)
  if count>1 and guardedOfferCalls>=2 then
   shadowLive=false
  end
  return accepted,reason
 end
 local ok,receipt=pcall(planModule.run,
    b.bound,io,gate,approval,opts)
 io.offerItem=originalOfferItem
 shadowLive=false
 gate.checkOutbound=nil;actionBusy=false
 -- Surface the precise FIRST observed client ABA watcher failure directly,
 -- before a generic "guarded offer not confirmed" can overwrite its reason.
 if haltReason then
  if controller then controller.abort(haltReason) end
  return nil
 end
 if not ok or type(receipt)~="table" then return nil end
 -- This is client-visible placement only, not settled transfer authority.
 return receipt
end
function adapters.removeOwnOne(round,root,epoch,allowAltItem)
 if actionBusy or not liveBeforeAction() or
    io.trade()~=root then return false end
 local b=currentClientSnapshot()
 if not b or b.snap.physicalOwnSlots<1 or
   ((allowAltItem==true and (round~=5 or b.snap.physicalTheirSlots~=1)) or
    (allowAltItem~=true and b.snap.physicalTheirSlots~=0)) then return false end
 actionBusy=true
 local ok,clicked=pcall(io.removeOne,root)
 actionBusy=false
 return ok and clicked==true
end
function adapters.decline(round,root,epoch)
 if actionBusy or not liveBeforeAction()
    or io.trade()~=root then return false end
 local b=currentClientSnapshot()
 if not b or b.snap.physicalOwnSlots~=0 or
    b.snap.physicalTheirSlots~=0 then return false end
 actionBusy=true
 -- This is the original protected P4 DeclineTrade action, NOT final Accept.
 local ok,closed=pcall(io.decline,"SYSTEM1_MAIN_AUTO_TEST_CLIENT_CLOSE")
 actionBusy=false
 return ok and closed==true and io.trade()==nil
end
function adapters.endEpoch(round,epoch)
 if epochRound~=round or io.trade()~=nil then return false end
 shadowLoopLive=false
 if currentWatchdog then
  pcall(currentWatchdog.stop)
 end
 if currentSupervisor then
  pcall(currentSupervisor.stop)
 end
 currentWatchdog=nil;currentSupervisor=nil
 currentBound=nil;boundRoot=nil;epochRound=nil
 handoffRoot=nil;handoffFirstSeen=nil
 latestP3="EPOCH_ENDED"
 gate.checkOutbound=nil
 return true
end
function adapters.stopAll()
 owner.running=false
 shadowLoopLive=false
 gate.checkOutbound=nil
 if currentWatchdog then pcall(currentWatchdog.stop)end
 if currentSupervisor then pcall(currentSupervisor.stop)end
 currentWatchdog=nil;currentSupervisor=nil
 E[USED_KEY]=owner.job
 E[OWNER_KEY]=nil
 return true
end
function adapters.copyReport(report)
 latestReceipt=report
 return copyPayload(report)
end
local function showRuntime()
 if not owner.armed or not controller then return end
 local safe,why=layoutSafe()
 if not safe then
  controller.abort(why or "GUI_LAYOUT_LOST")
  return
 end
 local r=controller.status()
 screen.title.Text="SYSTEM 1 MAIN AUTO | TRADE "..r.round.."/"..tostring(r.maxRounds or 4)
 screen.body.Text=r.instruction
 screen.status.Text="Phase: "..r.phase..
   " | Completed: "..tostring(r.completedRounds)..
   " | Requests: "..tostring(r.actions.requestsStarted)..
   " | Own offers: "..tostring(r.actions.offersClientVisible)
 if r.phase=="STOPPED" then
  screen.warning.Text="STOPPED: "..r.reason.." | COPY REPORT"
 elseif r.phase=="DONE" then
  screen.warning.Text="DONE | REPORT COPIED | NO FINAL ACCEPT"
 else
  screen.warning.Text="MAIN AUTOMATIC | ALT FOLLOW PANEL | NO FINAL ACCEPT"
 end
 screen.arm.Visible=false
 screen.armAdaptive.Visible=false
 screen.choices.Visible=false
 screen.reset.Visible=false
end
screen.stop.Activated:Connect(function()
 if controller then
  controller.stop()
  showRuntime()
 else
  earlyStop("OPERATOR_STOPPED_BEFORE_ARM")
 end
end)
screen.copy.Activated:Connect(function()
 if controller then controller.copyNow()
 elseif lastJson then copyPayload({status="STOPPED",phase="SETUP",
    reason=haltReason or "SETUP_IN_PROGRESS",
    authorizesAccept=false,tradeOutcome="UNKNOWN"})
 else
  copyPayload({status="PREPARING",phase="SETUP",
    reason="CHOOSING_TWO_TEST_ITEMS",tradeOutcome="UNKNOWN",
    authorizesAccept=false})
 end
end)
local function armRounds(requestedRounds)
 if requestedRounds~=4 and requestedRounds~=5 then return end
 if not owner.running or owner.armed or
    #selected~=2 or not availableForArm() or
    not profileReadAt or os.clock()-profileReadAt>180 or
    io.trade()~=nil then return end
 -- The operator explicitly approves ALL FOUR guarded exact-ALT test rounds:
 -- 4 outgoing requests, 3 preselected cheap own-item placements, up to
 -- 3 own-item removals and 4 declines. NEVER final Accept.
 owner.startAuthorized=true
 owner.armed=true
 local engine,why=controllerModule.new(adapters,{
  explicitFourRoundConsent=true,finalAcceptDisabled=true,
  exactConsentingAlt=true,approvedTwoDistinctOwnedItems=true,
  includeAdaptiveRound=requestedRounds==5,
  explicitAdaptiveRevisionConsent=requestedRounds==5,
  requestTimeout=30,altStepTimeout=90,actionTimeout=12,
 })
 if not engine then
  earlyStop("AUTO_CONTROLLER_START_FAILED")
  return
 end
 controller=engine
 screen.choices.Visible=false
 screen.reset.Visible=false
 screen.warning.Visible=true
 screen.status.Position=UDim2.fromOffset(10,93)
 screen.arm.Visible=false
 screen.armAdaptive.Visible=false
 screen.title.Text="SYSTEM1 AUTO ARMED"
 screen.body.Text="MAIN automatically manages "..tostring(requestedRounds)..
   " test trades. ALT follows panel. NEVER final Accept."
 local started=pcall(function()
  task.spawn(function()
   while owner.running and controller and
      controller.status().phase~="STOPPED" and
      controller.status().phase~="DONE" do
    if haltReason then
     controller.abort(haltReason)
     break
    end
    local ok,result=pcall(controller.tick,os.clock())
    if not ok or type(result)~="table" then
     controller.abort("AUTO_TICK_UNEXPECTED_EXCEPTION")
     break
    end
    showRuntime()
    if result.phase=="STOPPED" or result.phase=="DONE" then
     break
    end
    task.wait(0.15)
   end
   if controller then showRuntime()end
  end)
 end)
 if not started then controller.abort("AUTO_LOOP_SCHEDULE_FAILED") end
end
screen.arm.Activated:Connect(function()armRounds(4)end)
screen.armAdaptive.Activated:Connect(function()armRounds(5)end)
local profileWorker=pcall(function()
 task.spawn(function()
  local choices,reason=parseOwned()
  if not owner.running or owner.armed then return end
  if not choices then
   earlyStop(reason or "TEST_ITEM_CHOICES_UNAVAILABLE")
  else
   showOwned(choices)
  end
 end)
end)
if not profileWorker then
 earlyStop("OWNED_PICKER_SCHEDULE_FAILED")
 return nil
end
task.spawn(function()
 while owner.running and not owner.armed do
  hideOldScanner()
  if not altExact() or conflicts() or game.JobId~=owner.job then
   earlyStop("ALT_OR_JOB_CHANGED_BEFORE_ARM")
   break
  end
  local safe,why=layoutSafe()
  if not safe then
   earlyStop(why or "GUI_REMOVED_BEFORE_ARM")
   break
  end
  refreshSelection()
  task.wait(0.4)
 end
end)
E.PDIDDLER_SYSTEM1_MAIN_AUTO_RUNNER={
 stop=function()
  if controller then return controller.stop()end
  return earlyStop("OPERATOR_STOPPED_BEFORE_ARM")
 end,
 status=function()
  return controller and controller.status() or {
   status="PREPARING",phase="SELECT_TWO_OWN_ITEMS",
   reason=haltReason or "NO_REQUESTS_UNTIL_ARM_BUTTON",
   authorizesAccept=false,
   serverCompletionProven=false,tradeOutcome="UNKNOWN",
  }
 end,
 copy=function()
  if controller then return controller.copyNow()end
  return copyPayload({status="PREPARING",phase="SELECT_TWO_OWN_ITEMS",
   reason=haltReason or "NOT_ARMED",authorizesAccept=false})
 end,
}
print("[SYSTEM1 MAIN AUTO] Select 2 cheap owned weapon types, then ARM all 4. After ARM MAIN automatically sends/places/removes/declines. ALT must accept each incoming REQUEST and change items per purple GUI. Any unexpected stop auto copies diagnostic. NEVER final Accept.")
return E.PDIDDLER_SYSTEM1_MAIN_AUTO_RUNNER
