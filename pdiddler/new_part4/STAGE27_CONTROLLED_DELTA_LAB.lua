-- Project Gingerscope Stage27: MANUAL Delta item placement/withdrawal test.
-- EXACTLY ONE low-value local weapon, operator ADD then operator REMOVE.
-- No outgoing trade request, no automatic negotiations, no Accept, no
-- Decline, no server hopping, no completed-trade webhook.
-- Start in a fresh MM2 server BEFORE opening a trade. Wait for initial scans.
local E=(getgenv and getgenv()) or _G
local ROOT="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
local STAGE26="a2a2e601be864f970da0a69c436ab3b12efd8112"
local CORE27="cfcb0d729ff38ebd0ceedc018a689ce474137aca"
local TRANSPORT27="dd36c309bdb0d921cf008b65b5948b3ff23b2fc9"
local PLACE_ID=142823291
local MAX_ITEM_VALUE=200
local KEY="PDIDDLER_STAGE27_NATIVE_LAB"
if game.PlaceId~=PLACE_ID then
 warn("[STAGE27] Wrong Roblox place; test not started") return
end
if E[KEY]~=nil or E.PDIDDLER_PART4_SESSION~=nil
 or E.PDIDDLER_OUTGOING_SESSION~=nil
 or E.PDIDDLER_PART5_CONTROLLER~=nil
 or E.PDIDDLER_GINGERSCOPE_REPLACEMENT_PREVIEW~=nil
 or E.PDIDDLER_INTEGRATION_V15_8_VALUE_FIRST~=nil then
 warn("[STAGE27] Another trading/test owner exists; fresh rejoin required")
 return
end
local Players=game:GetService("Players")
local LP=assert(Players.LocalPlayer,"local player missing")
local GAME_JOB=game.JobId
local function import(ref,name)
 local path=ROOT..ref.."/pdiddler/new_part4/"..name..".lua"
 local src=game:HttpGet(path,true)
 assert(type(src)=="string" and #src>50,"module unavailable: "..name)
 local fn,why=loadstring(src,"="..name)
 assert(fn,why)
 local value=fn()
 assert(type(value)=="table","module invalid: "..name)
 return value
end
local function visible(node,root)
 if not node then return false end
 local curr=node
 while curr do
  if curr:IsA("GuiObject") and curr.Visible~=true then return false end
  if curr:IsA("ScreenGui") and curr.Enabled~=true then return false end
  if curr==root then return true end
  curr=curr.Parent
 end
 return false
end
local function tradeRoot()
 local pg=LP:FindFirstChildOfClass("PlayerGui")
 if not pg then return nil end
 for _,name in ipairs({"TradeGUI_Phone","TradeGUI"}) do
  local gui=pg:FindFirstChild(name)
  local root=gui and gui:FindFirstChild("Container")
  root=root and root:FindFirstChild("Trade")
  if root and visible(root,pg) then return root end
 end
 return nil
end
local function tradePartner(root)
 local side=root and root:FindFirstChild("TheirOffer")
 local label=side and side:FindFirstChild("Username")
 local name=label and tostring(label.Text or "") or ""
 name=name:match("^%s*%((.-)%)%s*$") or name
 name=name:gsub("^@",""):gsub("^%s+",""):gsub("%s+$","")
 if name=="" then return nil end
 for _,p in ipairs(Players:GetPlayers()) do
  if p~=LP and p.Parent==Players and p.Name:lower()==name:lower() then
   return p
  end
 end
 return nil
end
-- Stage25's isolated scanner is the ONLY inventory reader.
-- The standalone lab never starts a second scanner or reads player data
-- through a new RemoteFunction; it reuses its existing scanner APIs.
local owner=E.PDIDDLER_STAGE25_SCANNER_ONLY
if not owner then
 E.PDIDDLER_ALLOW_SCANNER_ONLY_TEST=true
 local url=ROOT..STAGE26.."/pdiddler/new_part4/STAGE25_SCANNER_ONLY_BOOT.lua"
 local ok,result=pcall(function()
  local src=game:HttpGet(url,true)
  local fn=assert(loadstring(src,"=stage25-scanner-only"))
  return fn()
 end)
 if not ok then
  warn("[STAGE27] Scanner-only startup failed; rejoin before retry")
  return
 end
 owner=result
end
if type(owner)~="table" or owner.status~="SCANNER_ONLY_NO_TRADE_AUTHORITY"
 or not owner.rawScanner or not owner.profile then
 warn("[STAGE27] Existing scanner not initialized; no trading actions")
 return
end
local scanner=owner.rawScanner
local profile=owner.profile
local okay,modules=pcall(function()
 return {
  contract=import(STAGE26,"p4_observer_contract"),
  observer=import(STAGE26,"p4_native_observer"),
  offerCore=import(STAGE26,"p4_offer_executor"),
  offerNative=import(STAGE26,"p4_native_offer"),
  removeCore=import(STAGE26,"p4_removal_executor"),
  removeNative=import(STAGE26,"p4_native_removal"),
  labCore=import(CORE27,"p4_stage27_lab_core"),
  transport=import(TRANSPORT27,"p4_stage27_native_transport"),
 }
end)
if not okay then
 warn("[STAGE27] Read-only module loading failed; no physical action attempted")
 return
end

-- Movable, isolated test panel. Only these on-screen buttons create intent.
local pg=LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui")
local ui=Instance.new("ScreenGui")
ui.Name="Gingerscope_Stage27_Controlled_Test"
ui.ResetOnSpawn=false
ui.IgnoreGuiInset=false
ui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
-- Original Stage27 left DisplayOrder at 0; when MM2 creates TradeGUI
-- afterward its fullscreen input layer may be on top of our buttons.
-- DisplayOrder is per ScreenGui (GuiObject.ZIndex alone cannot fix this).
ui.DisplayOrder=10
ui.Parent=pg
local lastTradeLayer=nil
local lastTradeOrder=nil
local function keepPanelAboveTrade()
 if ui.Parent~=pg then return end
 local highest=0
 local topTrade=nil
 for _,name in ipairs({"TradeGUI_Phone","TradeGUI"}) do
  local other=pg:FindFirstChild(name)
  if other and other:IsA("ScreenGui") and other.Enabled==true
    and (not topTrade or other.DisplayOrder>=highest) then
   highest=other.DisplayOrder
   topTrade=other
  end
 end
 if ui.DisplayOrder<=highest then
  -- Newer Roblox clients permit large orders; older builds may cap them.
  -- If capped and tied, re-parent our own panel once *after* the trade GUI,
  -- so it wins equal-order input priority. Never modify MM2's trade GUI.
  pcall(function() ui.DisplayOrder=math.max(10,highest+1) end)
  if ui.DisplayOrder<=highest
    and (topTrade~=lastTradeLayer or highest~=lastTradeOrder) then
   ui.Parent=nil
   ui.Parent=pg
  end
 end
 lastTradeLayer=topTrade
 lastTradeOrder=highest
end
keepPanelAboveTrade()
local frame=Instance.new("Frame")
frame.Name="Stage27Panel"
frame.Size=UDim2.new(0,335,0,238)
frame.Position=UDim2.new(0,8,0,65)
frame.BackgroundColor3=Color3.fromRGB(28,34,43)
frame.BorderSizePixel=0
frame.ZIndex=10
frame.Active=true
frame.Draggable=true
frame.Parent=ui
local function label(name,text,y,height)
 local v=Instance.new("TextLabel")
 v.Name=name;v.Position=UDim2.new(0,8,0,y)
 v.Size=UDim2.new(1,-16,0,height or 34)
 v.BackgroundTransparency=1
 v.TextColor3=Color3.fromRGB(241,241,246)
 v.Font=Enum.Font.Gotham
 v.TextSize=13;v.TextWrapped=true
 v.TextXAlignment=Enum.TextXAlignment.Left
 v.TextYAlignment=Enum.TextYAlignment.Center
 v.ZIndex=11
 v.Text=text;v.Parent=frame
 return v
end
local title=label("Title","STAGE 27 | 1 ADD + 1 REMOVE | NO ACCEPT",4,27)
title.Font=Enum.Font.GothamBold
local info=label("Selected","1. Bind in open trade. 2. Select cheap weapon.",35,42)
local status=label("Status","SCANNER READY. Wait for scans; open manual trade.",79,54)
local help=label("Help","Partner must offer 1 eligible weapon; neither player Accept.",139,28)
local function button(name,text,x,y,w)
 local b=Instance.new("TextButton")
 b.Name=name;b.Position=UDim2.new(0,x,0,y)
 b.Size=UDim2.new(0,w,0,32)
 b.Font=Enum.Font.GothamBold;b.TextSize=13
 b.TextColor3=Color3.fromRGB(255,255,255)
 b.BackgroundColor3=Color3.fromRGB(50,87,123)
 b.ZIndex=12
 b.Text=text;b.Parent=frame
 return b
end
local bindButton=button("Bind","BIND",7,174,60)
local selectButton=button("Select","NEXT",72,174,62)
local addButton=button("Add","ADD ONCE",139,174,93)
local removeButton=button("Remove","REMOVE",237,174,91)
local stopButton=button("Stop","STOP / REPORT",7,208,321)
stopButton.BackgroundColor3=Color3.fromRGB(99,54,54)

local S={jobId=GAME_JOB,running=true,phase="PREPARE",
 addAttempted=false,removeAttempted=false,
 authorizesAccept=false,serverCompletionProven=false,
 bound=nil,items={},selected=1,stamp=0}
E[KEY]=S
local function safeLive()
 return S.running and E[KEY]==S and game.JobId==GAME_JOB
  and E.PDIDDLER_PART4_SESSION==nil
  and E.PDIDDLER_OUTGOING_SESSION==nil
end
local function show(reason)
 status.Text=tostring(reason)
 S.reason=tostring(reason)
end
local function picked()
 return S.items[S.selected]
end
local function updateSelection()
 local item=picked()
 if item then
  info.Text="WEAPON: "..item.name.." | value "..tostring(item.price)..
   " | "..tostring(S.selected).."/"..tostring(#S.items)
 else
  info.Text="No verified eligible owned weapon <= "..MAX_ITEM_VALUE
 end
end
local function report()
 local base=S.bound and modules.labCore.report(S.bound.lab) or {
  schema="gingerscope-stage27-controlled-native-lab-v1",
  status=S.phase,reason=S.reason,addAttempted=S.addAttempted,
  removeAttempted=S.removeAttempted,
  addVerified=false,removeVerified=false,
  authorizesAccept=false,serverCompletionProven=false,
 }
 base.sourceFresh=profile.isFresh()==true
 base.nativePlaceValidated=base.addVerified==true
 base.nativeRemoveValidated=base.removeVerified==true
 base.operatorStopped=not S.running
 base.serverAttestation=false
 local body=game:GetService("HttpService"):JSONEncode(base)
 if type(setclipboard)=="function" then pcall(setclipboard,body) end
 print("[GINGERSCOPE STAGE27 ANONYMIZED] "..body)
 return body
end
local function invalidate(why)
 S.phase="MANUAL_RECOVERY"
 show(why..". If an item is offered, remove it MANUALLY and decline.")
end
local function bind()
 if not safeLive() or S.bound or S.addAttempted then return end
 local root=tradeRoot()
 if not root then show("Open trade window after scanner completes.");return end
 local partner=tradePartner(root)
 if not partner then show("Trade partner is not uniquely verified.");return end
 if not profile.isFresh() then show("DATED SUPREME SOURCE EXPIRED. Do not test ADD.");return end
 local ok,rec=pcall(scanner.getRecord,partner.UserId)
 local stateOK,state=pcall(scanner.getVerificationState,partner.UserId)
 if not ok or not stateOK or type(rec)~="table" or
   type(state)~="table" or state.scanning==true
   or state.retryScheduled==true or rec.state~="whitelist"
   or rec.player~=partner or type(rec.inv)~="table"
   or type(state.record)~="table"
   or state.record.inv~=rec.inv then
  show("Partner scan not ready. Close trade and allow a full scan.");return
 end
 local proof=rec.scanProof
 if type(proof)~="table"
   or proof.kind~="local-stable-scan-publication-v1"
   or proof.jobId~=GAME_JOB or proof.playerUserId~=partner.UserId
   or proof.fingerprint~=rec.inv.fingerprint
   or type(proof.completedAtMono)~="number"
   or os.clock()<proof.completedAtMono
   or os.clock()-proof.completedAtMono>30 then
  show("Partner timestamp missing/stale. Rescan before testing.");return
 end
 local ownOK,own,err=pcall(scanner.getOwnInventory)
 if not ownOK or err or type(own)~="table"
   or type(own.items)~="table" or own.unmapped~=0
   or own.badQty~=0 or own.unpriced~=0
   or type(own.fingerprint)~="string" or own.fingerprint=="" then
  show("Local inventory cannot be verified. No action.");return
 end
 if not profile.isFresh() or root~=tradeRoot() then
  show("Trade/source changed during inventory read.");return end
 -- Do not place even a low-value item unless we can at least
 -- resolve both native input interfaces. A later GUI proof remains required.
 local interfacesOK=pcall(function()
  local trade=game:GetService("ReplicatedStorage"):FindFirstChild("Trade")
  local add=trade and trade:FindFirstChild("OfferItem")
  assert(add and add:IsA("RemoteEvent"),"OfferItem missing")
  local vim=game:GetService("VirtualInputManager")
  assert(vim and type(vim.SendMouseButtonEvent)=="function",
      "physical remove-input API missing")
  local gs=game:GetService("GuiService")
  assert(gs and type(gs.GetGuiInset)=="function",
      "GUI inset API missing")
 end)
 if not interfacesOK then
  show("Native add or physical removal input unavailable; no items touched.")
  return
 end
 local choices={}
 for _,it in ipairs(own.items) do
  if type(it)=="table" and type(it.id)=="string"
   and type(it.checkerId)=="string" and it.checkerId:match("^%d+$")
   and (it.page=="ancient" or it.page=="chroma" or it.page=="godly")
   and (it.type=="Knife" or it.type=="Gun") and it.cat=="Weapons"
   and type(it.qty)=="number" and it.qty>=1 then
   local price=profile.get(it.page,it.checkerId)
   if price and price.verified==true and price.name==it.name
    and type(price.supremeValue)=="number"
    and price.supremeValue>0 and price.supremeValue<=MAX_ITEM_VALUE then
    choices[#choices+1]={
     id=it.id,page=it.page,checkerId=it.checkerId,
     name=it.name,price=price.supremeValue}
   end
  end
 end
 table.sort(choices,function(a,b)
  if a.price~=b.price then return a.price<b.price end
  return a.name<b.name
 end)
 if #choices==0 then
  show("No eligible owned weapon <= "..MAX_ITEM_VALUE.."; no test action.")
  return
 end
 local session="stage27:"..tostring(os.clock())
 local handle=modules.observer.new({
  game=game,players=Players,root=root,session=session,
  jobId=GAME_JOB,partnerUserId=partner.UserId,
  localUserId=LP.UserId,contract=modules.contract,
  ownInventory=own,opponentInventory=rec.inv,
  marketFresh=function()return profile.isFresh()==true end})
 local obs,diag=modules.observer.capture(handle)
 if obs.tradeOpen~=true or obs.contextOK~=true
  or obs.marketFresh~=true or obs.ourAccepted~=false
  or obs.theirAccepted~=false or obs.ourSlots~=0
  or obs.theirSlots<1 or obs.theirResolved~=true then
  show("Trade not verified: both sides unaccepted; partner must offer eligible item.")
  return
 end
 S.items=choices;S.selected=1
 local transport=modules.transport.new({
  game=game,
  confirm=function(kind,id,arg)
   local bound=S.bound
   if not safeLive() or not bound or not bound.lab
    or id~=bound.lab.item.id or os.clock()-S.stamp>0.6 then return false end
   if kind=="ADD" then return bound.lab.phase=="ADDING" and S.addAttempted end
   if kind=="REMOVE" then return bound.lab.phase=="REMOVING"
     and S.removeAttempted and arg.kind=="REMOVE_ONE" end
   return false
  end,
  targetObscured=function(x,y)
   local p=frame.AbsolutePosition;local z=frame.AbsoluteSize
   return x>=p.X and x<=p.X+z.X and y>=p.Y and y<=p.Y+z.Y
  end
 })
 S.bound={handle=handle,transport=transport,own=own,partner=partner,root=root}
 S.boundAt=os.clock();S.phase="READY_ADD"
 updateSelection()
 show("BOUND. Use NEXT to select. Tap ADD ONCE only when both are unaccepted.")
end
local function executeAdd()
 if not safeLive() or S.phase~="READY_ADD" or S.addAttempted then return end
 if os.clock()-S.boundAt>30 then invalidate("Bound inventory older than 30s");return end
 local sel=picked()
 if not sel then show("No eligible item selected.");return end
 local B=S.bound
 local lab
 local state=modules.offerCore.new(B.handle.config.session,{
  validatePermit=function(p,o,now)
   return lab and modules.labCore.validateManualPermit(lab,p,o,now)==true
  end})
 local addHandle=modules.offerNative.new({
  observer=modules.observer,handle=B.handle,
  session=B.handle.config.session,ownInventory=B.own,
  sendOnce=function(id,kind) return modules.transport.add(B.transport,id,kind) end})
 local removeState=modules.removeCore.new(B.handle.config.session)
 local removeHandle=modules.removeNative.new({
  observer=modules.observer,handle=B.handle,
  session=B.handle.config.session,
  clickOnce=function(button,intent)
   return modules.transport.remove(B.transport,button,intent)
  end})
 lab=modules.labCore.new({
  session=B.handle.config.session,observer=modules.observer,
  handle=B.handle,clock=os.clock,item=sel,
  offerCore=modules.offerCore,offerNative=modules.offerNative,
  offerState=state,offerHandle=addHandle,
  removeCore=modules.removeCore,removeNative=modules.removeNative,
  removeState=removeState,removeHandle=removeHandle
 })
 B.lab=lab
 S.stamp=os.clock();S.addAttempted=true
 local ok,action,why=pcall(modules.labCore.add,lab)
 if not ok then invalidate("Stage27 ADD exception; no retry");return end
 S.phase=lab.phase
 show(action..": "..tostring(why))
end
local function executeRemove()
 if not safeLive() or S.phase~="READY_REMOVE" or S.removeAttempted
  or not S.bound or not S.bound.lab then return end
 S.stamp=os.clock();S.removeAttempted=true
 local ok,action,why=pcall(modules.labCore.remove,S.bound.lab)
 if not ok then invalidate("Stage27 REMOVE exception; no retry");return end
 S.phase=S.bound.lab.phase
 show(action..": "..tostring(why))
end
bindButton.Activated:Connect(function()
 keepPanelAboveTrade()
 if safeLive() then bind() end
end)
selectButton.Activated:Connect(function()
 if S.phase=="READY_ADD" and not S.addAttempted and #S.items>0 then
  S.selected=S.selected%#S.items+1
  updateSelection()
 end
end)
addButton.Activated:Connect(executeAdd)
removeButton.Activated:Connect(executeRemove)
stopButton.Activated:Connect(function()
 if S.bound and S.bound.lab and S.bound.lab.phase~="DONE" then
  modules.labCore.stop(S.bound.lab)
 end
 S.running=false
 show("STOPPED. If an item remains, remove it MANUALLY; decline trade.")
 report()
end)

task.spawn(function()
 while safeLive() do
  keepPanelAboveTrade()
  if S.bound and S.bound.lab and
    (S.phase=="VERIFY_ADD" or S.phase=="VERIFY_REMOVE") then
   local ok,kind,why=pcall(modules.labCore.poll,S.bound.lab)
   if not ok then invalidate("Observer exception; manual recovery")
   else
    S.phase=S.bound.lab.phase
    if kind=="VERIFIED" or S.phase=="MANUAL_RECOVERY" then
     show(tostring(kind)..": "..tostring(why))
     if S.phase=="DONE" then
      report()
     end
    end
   end
  end
  task.wait(0.09)
 end
end)
print("[GINGERSCOPE STAGE27] Controlled test panel ready | no actions without manual tap")
return S
