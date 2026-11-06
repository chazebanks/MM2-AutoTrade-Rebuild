-- Gingerscope Stage33: read-only census of exactly 16 known MM2 Trade RemoteEvents.
-- Native completion TRANSPORT exploration, not completion or profit authority.
-- No item moves, clicks, remote sends, scanner, market quotes or webhook.
local E=(getgenv and getgenv()) or _G
local KEY="PDIDDLER_STAGE33_TRANSPORT_CENSUS"
if game.PlaceId~=142823291 then warn("[STAGE33] wrong game") return end
for _,id in ipairs({
 KEY,"PDIDDLER_STAGE32_RESULT_CORRELATION_PROBE",
 "PDIDDLER_STAGE29_POSTCLOSE_PROBE",
 "PDIDDLER_STAGE30_PASSIVE_SIGNALS",
 "PDIDDLER_STAGE28_PASSIVE_ACCEPT_PROBE",
 "PDIDDLER_STAGE27_NATIVE_LAB",
 "PDIDDLER_GINGERSCOPE_REPLACEMENT_PREVIEW",
 "PDIDDLER_OUTGOING_SESSION",
 "PDIDDLER_PART4_SESSION","PDIDDLER_PART5_CONTROLLER",
 "PDIDDLER_INTEGRATION_V15_8_VALUE_FIRST"
}) do
 if E[id]~=nil then
  warn("[STAGE33] previous observer/controller owner present; rejoin") return
 end
end
local ROOT="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
local PIN30="3ccf9219580726e2b122e1b9d4bdb6039eff96b0"
local PIN33="74a14e00248be9679b1a87011a6b57656eeaf90a"
local players=game:GetService("Players")
local me=players.LocalPlayer
if not me then warn("[STAGE33] local player missing") return end
local job=game.JobId
local S={reportReady=false,connections={},phase="BOOTING",readOnly=true,
 authorizesTrade=false,authorizesAccept=false,
 mayRecordCompletedTrade=false,mayReportProfit=false}
E[KEY]=S
local function source(pin,name)
 local code=game:HttpGet(ROOT..pin.."/pdiddler/new_part4/"..name..".lua",true)
 assert(type(code)=="string" and #code>60,"source unavailable")
 local fn,why=loadstring(code,"="..name)
 assert(fn,why)
 local mod=fn()
 assert(type(mod)=="table","module invalid")
 return mod
end
local loaded,mods=pcall(function()
 return {census=source(PIN30,"p4_stage30_client_signal_census"),
  window=source(PIN33,"p4_stage33_transport_window")}
end)
if not loaded then
 S.phase="MODULES_UNAVAILABLE"
 warn("[STAGE33] load failure; do not attempt manual trade")
 return S
end
S.window=mods.window.new(mods.census,os.clock())
local function finish(reason,normal)
 if S.reportReady then return end
 S.reportReady=true
 for _,c in ipairs(S.connections) do pcall(function() c:Disconnect() end) end
 S.connections={}
 mods.window.finish(S.window,os.clock(),normal)
 local report=mods.window.summary(S.window)
 report.stopReason=reason
 report.unverifiedClientSignals=true
 report.partnerDepartureObserved=S.partnerLeft==true
 report.nativeAcceptanceNotControlled=true
 report.serverCompletionProven=false
 report.authorizesAccept=false
 report.mayRecordCompletedTrade=false
 report.mayReportProfit=false
 local ok,json=pcall(function()
  return game:GetService("HttpService"):JSONEncode(report)
 end)
 S.phase="FINISHED";S.result=report
 if ok then
  if type(setclipboard)=="function" then pcall(setclipboard,json) end
  print("[GINGERSCOPE STAGE33 ANONYMIZED] "..json)
 else
  warn("[STAGE33] unable to encode JSON; no action taken")
 end
end
local function visible(node,stop)
 while node do
  if node:IsA("ScreenGui") and not node.Enabled then return false end
  if node:IsA("GuiObject") and not node.Visible then return false end
  if node==stop then return true end
  node=node.Parent
 end
 return false
end
local function tradeRoot()
 local pg=me:FindFirstChildOfClass("PlayerGui")
 if not pg then return nil end
 for _,name in ipairs({"TradeGUI_Phone","TradeGUI"}) do
  local screen=pg:FindFirstChild(name)
  local container=screen and screen:FindFirstChild("Container")
  local root=container and container:FindFirstChild("Trade")
  if root and visible(root,pg) then return root end
 end
end
local function partnerFor(root)
 local their=root and root:FindFirstChild("TheirOffer")
 local label=their and their:FindFirstChild("Username")
 local name=label and tostring(label.Text or "") or ""
 name=(name:match("^%s*%((.-)%)%s*$") or name):gsub("^@","")
 name=name:gsub("^%s+",""):gsub("%s+$","")
 if name=="" then return nil end
 for _,p in ipairs(players:GetPlayers()) do
  if p~=me and p.Parent==players and p.Name:lower()==name:lower() then
   return p
  end
 end
end
local folder=game:GetService("ReplicatedStorage"):FindFirstChild("Trade")
if not folder then finish("TRADE_FOLDER_UNAVAILABLE",false) return S end
local names=mods.window.names()
local refs,allowed={},{}
for _,name in ipairs(names) do allowed[name]=true end
for _,node in ipairs(folder:GetDescendants()) do
 if node:IsA("RemoteEvent") and allowed[node.Name] then
  if refs[node.Name] then
   finish("DUPLICATE_KNOWN_REMOTE",false) return S
  end
  refs[node.Name]=node
 end
end
for _,name in ipairs(names) do
 if not refs[name] then
  finish("KNOWN_REMOTE_UNAVAILABLE",false) return S
 end
end
-- Bind every known OnClientEvent BEFORE requesting any manual trade.
-- Callbacks deliberately have ZERO payload arguments.
for _,name in ipairs(names) do
 local node=refs[name]
 local ok,conn=pcall(function()
  return node.OnClientEvent:Connect(function()
   if S.reportReady or E[KEY]~=S or game.JobId~=job or
     players.LocalPlayer~=me then return end
   mods.window.received(S.window,name,os.clock())
  end)
 end)
 if not ok or not conn then
  finish("LISTENER_BIND_FAILED",false) return S
 end
 S.connections[#S.connections+1]=conn
end
S.phase="WAIT_MANUAL_WINDOW"
print("[GINGERSCOPE STAGE33] 16 SIGNAL LISTENERS BOUND BEFORE TRADE. READ-ONLY; manually open a trade only if you choose.")
task.spawn(function()
 local start=os.clock()
 local maybeRoot,maybePartner,stable=nil,nil,0
 while not S.reportReady and E[KEY]==S and game.JobId==job
   and os.clock()-start<120 do
  local root=tradeRoot()
  local partner=partnerFor(root)
  if root and partner then
   if root==maybeRoot and partner==maybePartner then stable=stable+1
   else maybeRoot=root;maybePartner=partner;stable=1 end
   if stable>=2 then
    local ok=mods.window.open(S.window,os.clock())
    if not ok then finish("WINDOW_BIND_FAILED",false) return end
    S.phase="OBSERVING_MANUAL_TRADE"
    S.root=root;S.partner=partner
    print("[GINGERSCOPE STAGE33] TRADE WINDOW SCOPED. Manual actions only. Close within 30s.")
    break
   end
  else
   maybeRoot=nil;maybePartner=nil;stable=0
  end
  task.wait(.08)
 end
 if S.phase~="OBSERVING_MANUAL_TRADE" then
  finish("WINDOW_NOT_OPENED_IN_TIME",false) return
 end
 local boundTime=os.clock()
 while not S.reportReady and game.JobId==job and
   E[KEY]==S and os.clock()-boundTime<30 do
  if S.partner.Parent~=players then
   S.partnerLeft=true;finish("PARTNER_LEFT",false);return
  end
  local nowRoot=tradeRoot()
  if not nowRoot then
   local ok=mods.window.close(S.window,os.clock())
   if not ok then finish("CLOSE_NOT_SCOPED",false);return end
   S.phase="POST_CLOSE_GRACE"
   local stopAt=os.clock()+2.4
   while not S.reportReady and game.JobId==job and
     os.clock()<stopAt do
    if S.partner.Parent~=players then
     S.partnerLeft=true;finish("PARTNER_LEFT_AFTER_CLOSE",false);return
    end
    if tradeRoot() then
     finish("WINDOW_REOPENED_DURING_GRACE",false);return
    end
    task.wait(.08)
   end
   if game.JobId~=job or E[KEY]~=S then
    finish("SESSION_CHANGED",false);return
   end
   finish("POST_CLOSE_GRACE_FINISHED",true)
   return
  end
  if nowRoot~=S.root then
   finish("BOUND_GUI_ROOT_CHANGED",false);return
  end
  task.wait(.08)
 end
 finish("TRADE_WINDOW_TIMEOUT_OR_SESSION_CHANGED",false)
end)
return S
