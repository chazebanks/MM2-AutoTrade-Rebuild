-- STAGE61: passively record only argument TYPES of incoming AcceptTrade callbacks.
-- Historical v1456 client code suggests a boolean result flag, but THIS CURRENT
-- runtime has NOT authenticated those old semantics or a server transaction.
-- Never reads callback items/IDs/names, invokes remotes or touches trade GUI actions.
local MARK="[GINGERSCOPE STAGE61 ACCEPT CALLBACK]"
local GAME=142823291
local MAX_EVENTS=12
local AFTER_CLOSE=2.5
local LP_KEY="PDIDDLER_STAGE61_ACCEPT_CALLBACK_TYPES"
local E=(type(getgenv)=="function" and getgenv()) or _G
if E[LP_KEY] then
 warn("[STAGE61] Existing collector in this session. Rejoin before running again.")
 return nil
end
local M={
 schema="gingerscope-stage61-accept-client-args-v1",
 status="INITIALIZING",reason="NOT_STARTED",readOnly=true,
 tradeOutcome="UNKNOWN",serverAttestation=false,serverCompletionProven=false,
 serverTransactionIdAuthenticated=false,eventSessionAssociationProven=false,
 causalTradeAttributionProven=false,exactWeaponIdentityConfirmed=false,
 authorizesAccept=false,authorizesTrade=false,
 mayRecordCompletedTrade=false,mayRecordRejectedTrade=false,
 mayReportProfit=false,mayUseForStrategyLearning=false,
 observedSingleGui=false,guiStableBound=false,guiClosedObserved=false,
 scopedEventCount=0,unboundEventCount=0,totalReceipts=0,discardedReceipts=0,
 listenersDisconnected=0,hadTypeTrue=false,hadTypeFalse=false,
 historicalClientFlagHypothesisCompatible=false,
 events={}
}
E[LP_KEY]=M
local panelLabel,button=nil,nil
local printed=nil
local conn=nil
local pg,selectedGui,selectedRoot=nil,nil,nil
local guiIsOpen=false
local guiBound=false
local openedAt=nil
local closedAt=nil
local armStart=os.clock()
local job=tostring(game and game.JobId or "")

local function say(message)
 print("[STAGE61 GUIDE] "..message)
 if panelLabel then
  pcall(function()panelLabel.Text=message end)
 end
end

local function tryPanel()
 pcall(function()
  local players=game:GetService("Players")
  local localPlayer=players and players.LocalPlayer
  pg=localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")
  if not pg or not Instance then return end
  local screen=Instance.new("ScreenGui")
  screen.Name="GINGERSCOPE_STAGE61_READONLY"
  screen.ResetOnSpawn=false
  local old=pg:FindFirstChild(screen.Name)
  if old then screen:Destroy();return end
  local frame=Instance.new("Frame")
  frame.Size=UDim2.fromOffset(304,138)
  frame.Position=UDim2.new(0,12,1,-176)
  frame.BackgroundColor3=Color3.fromRGB(55,26,91)
  frame.Parent=screen
  local caption=Instance.new("TextLabel")
  caption.Name="Stage61Status"
  caption.Size=UDim2.new(1,-16,0,91)
  caption.Position=UDim2.fromOffset(8,6)
  caption.BackgroundTransparency=1
  caption.Font=Enum.Font.Gotham
  caption.TextSize=13
  caption.TextColor3=Color3.fromRGB(255,255,255)
  caption.TextWrapped=true
  caption.Text="STAGE61 read-only. No trade actions."
  caption.Parent=frame
  local copy=Instance.new("TextButton")
  copy.Name="COPY_CURRENT_STAGE61_REPORT"
  copy.Size=UDim2.new(1,-16,0,29)
  copy.Position=UDim2.fromOffset(8,103)
  copy.BackgroundColor3=Color3.fromRGB(112,69,168)
  copy.TextColor3=Color3.fromRGB(255,255,255)
  copy.TextSize=15
  copy.Text="COPY REPORT"
  copy.Visible=false
  copy.Parent=frame
  copy.Activated:Connect(function()
   if M.status=="INITIALIZING" or not printed then
    say("No finalized report yet. Copy is locked.")
    return
   end
   local fn=(type(setclipboard)=="function" and setclipboard)
      or (type(toclipboard)=="function" and toclipboard)
   if not fn then
    say("Clipboard unavailable. Copy marker from Delta console.")
    return
   end
   local ok=pcall(fn,printed)
   if ok then
    say("COPIED current Stage61 report. Paste it into ChatGPT.")
   else
    say("Copy failed. Use Delta console marker.")
   end
  end)
  panelLabel,button=caption,copy
  screen.Parent=pg
 end)
end

local function result(status,reason)
 if M.status~="INITIALIZING" then return M end
 M.status=status;M.reason=reason
 if conn then
  pcall(function()conn:Disconnect()end)
  M.listenersDisconnected=M.listenersDisconnected+1
  conn=nil
 end
 M.historicalClientFlagHypothesisCompatible=
  M.guiStableBound and M.guiClosedObserved and
  M.hadTypeTrue and M.hadTypeFalse and
  M.discardedReceipts==0
 -- A historical client compatibility hint has ZERO settlement authority.
 local ok,encoded=pcall(function()
  return game:GetService("HttpService"):JSONEncode(M)
 end)
 if ok and type(encoded)=="string" then
  printed=MARK.." "..encoded
 else
  printed=MARK..' {"schema":"gingerscope-stage61-accept-client-args-v1","status":"ENCODE_FAILED","readOnly":true,"serverCompletionProven":false,"authorizesAccept":false,"tradeOutcome":"UNKNOWN"}'
 end
 print(printed)
 if button then pcall(function()button.Visible=true end)end
 say("FINISHED "..status..". Tap COPY REPORT, or use Delta console. No automatic trading.")
 return M
end

local function shallowType(v)
 local kind=type(v)
 if kind=="table" then return "TABLE" end
 if kind=="nil" then return "NIL" end
 return "OTHER"
end
local function summarizeSecond(v)
 if type(v)~="table" then return shallowType(v),"NOT_TABLE" end
 -- Only a bounded LENGTH, no indexing/serialization of table contents.
 local ok,n=pcall(function()return #v end)
 if not ok or type(n)~="number" or n<0 or n>16 then
  return "TABLE","UNKNOWN_OR_OVERSIZE"
 end
 if n==0 then return "TABLE","EMPTY_OR_DICTIONARY" end
 return "TABLE","BOUNDED_SEQUENCE_"..tostring(n)
end

local function countGuis()
 if not pg then return nil,nil,0 end
 local count,chosen,root=0,nil,nil
 for _,name in ipairs({"TradeGUI","TradeGUI_Phone"}) do
  local g=pg:FindFirstChild(name)
  if g then
   local ok,visible,nested=pcall(function()
    return g.Enabled,g:FindFirstChild("Container")
   end)
   if ok and visible==true and nested then
    local r=nested:FindFirstChild("Trade")
    if r then
     count=count+1;chosen=g;root=r
    end
   end
  end
 end
 return chosen,root,count
end
local function collect(...)
 if M.status~="INITIALIZING" then return end
 M.totalReceipts=M.totalReceipts+1
 if M.totalReceipts>MAX_EVENTS then
  M.discardedReceipts=M.discardedReceipts+1
  return
 end
 local argc=select("#",...)
 local a,b=...
 local first
 if argc==0 then first="NO_ARGS"
 elseif type(a)=="boolean" then
  first=a and "BOOLEAN_TRUE" or "BOOLEAN_FALSE"
 elseif a==nil then first="NIL"
 else first="OTHER" end
 local second,shape=summarizeSecond(b)
 local phase
 if not guiBound then phase="PRE_BOUND_UNATTRIBUTED"
 elseif closedAt then phase="AFTER_CLOSE_UNATTRIBUTED"
 elseif guiIsOpen then phase="DURING_GUI_CLIENT_ONLY"
 else phase="OUT_OF_WINDOW" end
 local dt=math.floor(math.max(0,math.min(130,os.clock()-armStart))*10+0.5)/10
 table.insert(M.events,{
  phase=phase,firstArg=first,secondArg=second,
  secondTableShape=shape,argCount=math.min(argc,16),elapsedSeconds=dt
 })
 if phase=="DURING_GUI_CLIENT_ONLY" or phase=="AFTER_CLOSE_UNATTRIBUTED" then
  M.scopedEventCount=M.scopedEventCount+1
  if first=="BOOLEAN_TRUE" then M.hadTypeTrue=true end
  if first=="BOOLEAN_FALSE" then M.hadTypeFalse=true end
 else
  M.unboundEventCount=M.unboundEventCount+1
 end
end

tryPanel()
if not game or game.PlaceId~=GAME then return result("INCOMPLETE","WRONG_GAME") end
if E.PDIDDLER_STAGE59_PAIRED_MANUAL_OBSERVER or
   E.PDIDDLER_STAGE32_RESULT_CORRELATION_PROBE then
 return result("INCOMPLETE","OLDER_COLLECTOR_PRESENT_REJOIN")
end
local ok,rs=pcall(function()return game:GetService("ReplicatedStorage")end)
if not ok or not rs then return result("INCOMPLETE","REPLICATED_STORAGE_MISSING") end
local trade=rs:FindFirstChild("Trade")
local remote=trade and trade:FindFirstChild("AcceptTrade")
if not remote or not remote:IsA("RemoteEvent") then
 return result("INCOMPLETE","ACCEPT_TRADE_EVENT_MISSING")
end
local okC,c=pcall(function()return remote.OnClientEvent:Connect(collect)end)
if not okC or not c then return result("INCOMPLETE","LISTENER_FAILED") end
conn=c
say("READY. This only watches AcceptTrade callback TYPES. Join a normal trade when ready; no automatic Accept.")
task.spawn(function()
 local lastState=""
 local stableAt=nil
 while M.status=="INITIALIZING" and os.clock()-armStart<=180 do
  if game.PlaceId~=GAME or tostring(game.JobId or "")~=job then
   result("INCOMPLETE","SERVER_CHANGED")
   return
  end
  local g,r,visibleCount=countGuis()
  if visibleCount>1 then
   result("INCOMPLETE","MULTIPLE_TRADE_GUIS")
   return
  end
  if visibleCount==1 then
   if closedAt then
    result("INCOMPLETE","SECOND_TRADE_GUI_AFTER_CLOSE")
    return
   end
   if selectedRoot and (selectedRoot~=r or selectedGui~=g) then
    result("INCOMPLETE","TRADE_ROOT_REPLACED")
    return
   end
   if not selectedRoot then selectedRoot=r; selectedGui=g;openedAt=os.clock() end
   guiIsOpen=true
   if not stableAt then stableAt=os.clock() end
   if os.clock()-stableAt>=0.2 and not guiBound then
    guiBound=true;M.guiStableBound=true;M.observedSingleGui=true
    say("TRADE GUI BOUND. The script observes only; you control every offer and Accept. Finish normally or Decline.")
   end
  elseif selectedRoot and not closedAt then
   guiIsOpen=false;closedAt=os.clock();M.guiClosedObserved=true
   say("GUI CLOSED. Watching 2.5s of delayed callbacks. Do not open another trade yet.")
  end
  if closedAt and os.clock()-closedAt>=AFTER_CLOSE then
   local status=(guiBound and M.scopedEventCount>0 and
     M.discardedReceipts==0) and "CLIENT_CALLBACK_SHAPES_CAPTURED_UNATTRIBUTED"
      or (guiBound and M.scopedEventCount==0 and M.discardedReceipts==0)
      and "NO_BOUND_ACCEPT_CALLBACK_RECEIPTS"
      or "INCOMPLETE"
   result(status,(M.discardedReceipts>0 and "EVENT_OVERFLOW")
      or not guiBound and "GUI_NOT_STABLY_BOUND"
      or "CLIENT_EVENT_NAMES_AND_ARGUMENT_TYPES_ONLY")
   return
  end
  if not selectedRoot and os.clock()-armStart>90 then
   result("INCOMPLETE","NO_TRADE_GUI_WITHIN_90S")
   return
  end
  if selectedRoot and not closedAt and os.clock()-openedAt>120 then
   result("INCOMPLETE","TRADE_GUI_NOT_CLOSED_WITHIN_120S")
   return
  end
  task.wait(0.1)
 end
 if M.status=="INITIALIZING" then
  result("INCOMPLETE","GLOBAL_DEADLINE_OR_CALLBACK_TIMEOUT")
 end
end)
return M
