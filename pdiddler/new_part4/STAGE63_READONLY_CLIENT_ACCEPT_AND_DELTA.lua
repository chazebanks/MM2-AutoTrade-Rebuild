-- Stage63 MAIN-only read-only SAME-WINDOW AcceptTrade + OWN inventory evidence.
-- Built on immutable Stage59 role-neutral observer source: no second scanner.
-- Only client signals and own before/post inventory; never game settlement.
-- No offers, requests, final Accept, decline, server hop, webhook or profit.
local MARK="[GINGERSCOPE STAGE63 SAME WINDOW]"
local KEY="PDIDDLER_STAGE63_SAME_WINDOW_CLIENT_ONLY"
local CORE_KEY="PDIDDLER_STAGE32_RESULT_CORRELATION_PROBE"
local CORE_PIN="54b97f65290ce038910436e27600be6a2c4a005e"
local URL="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"..
 CORE_PIN.."/pdiddler/new_part4/STAGE59_RESULT_DELTA_ROLE_NEUTRAL_BASELINE.lua"
local env=(type(getgenv)=="function" and getgenv()) or _G
local meJob=game and tostring(game.JobId or "") or ""
local M={
 schema="gingerscope-stage63-one-window-client-accept-delta-v1",
 status="INITIALIZING",reason="AWAITING_TRADE",
 readOnly=true,tradeOutcome="UNKNOWN",
 serverAttestation=false,serverCompletionProven=false,
 serverTransactionIdAuthenticated=false,eventSessionAssociationProven=false,
 causalTradeAttributionProven=false,exactWeaponIdentityConfirmed=false,
 authorizesTrade=false,authorizesAccept=false,
 mayRecordCompletedTrade=false,mayRecordRejectedTrade=false,
 mayReportProfit=false,mayUseForStrategyLearning=false,
 clientCompatibleFlagPattern=false,clientReciprocalTransferProven=false,
 sameBoundWindowClientOnly=false,
 coreTerminal=false,guiBound=false,stablePartnerLabel=false,
 recordCount=0,ignoredUnboundReceipts=0,discardedReceipts=0,
 listenerDisconnected=false,samples={}
}
local label,copyButton,reportLine=nil,nil,nil
local connection=nil
local boundRoot,boundLabel=nil,nil
local boundAt,lastVisible,previousCoreState=nil,nil,nil
local finished=false
local start=os.clock()
local core=nil
local ignored=0

local function guidance(message)
 print("[STAGE63 GUIDE] "..message)
 if label then pcall(function()label.Text=message end) end
end
local function rootAndLabel()
 local ok,root,text,count=pcall(function()
  local pg=game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
  if not pg then return nil,nil,0 end
  local found,other,n=0,nil,0
  local function visible(node,stop)
   while node do
    if node:IsA("ScreenGui") and node.Enabled~=true then return false end
    if node:IsA("GuiObject") and node.Visible~=true then return false end
    if node==stop then return true end
    node=node.Parent
   end
   return false
  end
  for _,name in ipairs({"TradeGUI_Phone","TradeGUI"}) do
   local gui=pg:FindFirstChild(name)
   local container=gui and gui:FindFirstChild("Container")
   local trade=container and container:FindFirstChild("Trade")
   if trade and visible(trade,pg) then
    n=n+1
    other=trade
   end
  end
  if n~=1 then return nil,nil,n end
  local side=other:FindFirstChild("TheirOffer")
  local tag=side and side:FindFirstChild("Username")
  local name=tag and tag.Text
  if type(name)~="string" or #name==0 or #name>100 then
   return nil,nil,n
  end
  return other,name,n
 end)
 if not ok then return nil,nil,0 end
 return root,text,count
end

local function screenGuide()
 pcall(function()
  if type(Instance)~="table" or type(Instance.new)~="function" then return end
  local players=game:GetService("Players")
  local lp=players and players.LocalPlayer
  local pg=lp and lp:FindFirstChildOfClass("PlayerGui")
  if not pg then return end
  local old=pg:FindFirstChild("GINGERSCOPE_STAGE63_READONLY")
  if old then return end
  local screen=Instance.new("ScreenGui")
  screen.Name="GINGERSCOPE_STAGE63_READONLY"
  screen.ResetOnSpawn=false
  local panel=Instance.new("Frame")
  panel.Size=UDim2.fromOffset(326,147)
  panel.Position=UDim2.new(0,12,1,-188)
  panel.BackgroundColor3=Color3.fromRGB(56,25,93)
  panel.Parent=screen
  label=Instance.new("TextLabel")
  label.Size=UDim2.new(1,-16,0,103)
  label.Position=UDim2.fromOffset(8,5)
  label.BackgroundTransparency=1
  label.TextColor3=Color3.fromRGB(255,255,255)
  label.TextWrapped=true
  label.TextSize=13
  label.Text="STAGE63 | READ-ONLY | NO AUTO ACCEPT"
  label.Parent=panel
  copyButton=Instance.new("TextButton")
  copyButton.Size=UDim2.new(1,-16,0,29)
  copyButton.Position=UDim2.fromOffset(8,112)
  copyButton.BackgroundColor3=Color3.fromRGB(115,72,180)
  copyButton.TextColor3=Color3.fromRGB(255,255,255)
  copyButton.Text="COPY STAGE63 REPORT"
  copyButton.Visible=false
  copyButton.Parent=panel
  copyButton.Activated:Connect(function()
   if not finished or not reportLine then
    guidance("COPY LOCKED until THIS observation finishes.")
    return
   end
   local func=(type(setclipboard)=="function" and setclipboard)
       or (type(toclipboard)=="function" and toclipboard)
   if not func then
    guidance("Clipboard unsupported; use Delta console marker.")
    return
   end
   if pcall(func,reportLine) then
    guidance("COPIED current Stage63 report. Paste into ChatGPT.")
   else
    guidance("Clipboard failed. Copy Delta console result.")
   end
  end)
  screen.Parent=pg
 end)
end

local function finish(status,reason)
 if finished then return M end
 finished=true
 M.status=status
 M.reason=reason
 M.recordCount=#M.samples
 M.ignoredUnboundReceipts=ignored
 if connection then
  M.listenerDisconnected=pcall(function()connection:Disconnect()end)
  connection=nil
 end
 local c=core and core.result or nil
 if type(c)=="table" then
  M.coreTerminal=(c.stopReason=="TWO_POST_CLOSE_READS_FINISHED" and
    c.beforeObserved==true and c.windowClosureObserved==true and
    c.postReadbacksObserved==2 and c.closureStatus=="closed_unknown")
  -- Allowlist own aggregate client numbers only, never names, raw IDs or items.
  M.ownReadbacks={
    status=type(c.status)=="string" and c.status or "UNKNOWN",
    stopReason=type(c.stopReason)=="string" and c.stopReason or "UNKNOWN",
    beforeObserved=c.beforeObserved==true,
    postReadbacksObserved=type(c.postReadbacksObserved)=="number"
      and c.postReadbacksObserved or 0,
    windowClosureObserved=c.windowClosureObserved==true,
    gainedEligibleCopies=type(c.gainedEligibleCopies)=="number"
      and c.gainedEligibleCopies or 0,
    lostEligibleCopies=type(c.lostEligibleCopies)=="number"
      and c.lostEligibleCopies or 0,
    changedEligibleTypes=type(c.changedEligibleTypes)=="number"
      and c.changedEligibleTypes or 0,
    rawWeaponInventoryChanged=c.rawWeaponInventoryChanged==true,
    partnerCacheAtBaseline=c.partnerCacheAtBaseline==true
  }
 end
 local compatible=false
 if #M.samples==2 and M.ignoredUnboundReceipts==0
    and M.discardedReceipts==0 and M.guiBound
    and M.stablePartnerLabel and M.listenerDisconnected then
  local a,b=M.samples[1],M.samples[2]
  compatible=(a.firstArg=="BOOLEAN_FALSE" and a.argCount==1
    and a.secondArg=="NIL"
    and b.firstArg=="BOOLEAN_TRUE" and b.argCount==2
    and b.secondArg=="TABLE" and b.secondTableShape=="BOUNDED_SEQUENCE_1"
    and a.phase=="WITHIN_BOUND_GUI_CLIENT_ONLY"
    and (b.phase=="WITHIN_BOUND_GUI_CLIENT_ONLY"
         or b.phase=="IMMEDIATE_GUI_CLOSE_CLIENT_ONLY")
    and b.elapsedSeconds>=a.elapsedSeconds
    and b.elapsedSeconds-a.elapsedSeconds<=5)
 end
 M.clientCompatibleFlagPattern=compatible
 local own=M.ownReadbacks
 local positive=compatible and M.coreTerminal and own
   and own.gainedEligibleCopies==1 and own.lostEligibleCopies==0
   and own.changedEligibleTypes==1
   and own.rawWeaponInventoryChanged==true
 if positive then
  M.status="CLIENT_ACCEPT_FLAG_PLUS_OWN_GAIN_SAME_WINDOW_UNATTRIBUTED"
  M.reason="client-accept-flag-and-own-inventory-delta-do-not-authenticate-settlement"
 elseif M.status=="INITIALIZING" or M.status=="OBSERVING" then
  M.status="INCONCLUSIVE"
 end
 M.sameBoundWindowClientOnly=M.guiBound and M.coreTerminal and
   M.stablePartnerLabel and M.listenerDisconnected
 -- Source verified locally; this is NOT reciprocal proof on a second client.
 M.clientReciprocalTransferProven=false
 local ok,encoded=pcall(function()
  return game:GetService("HttpService"):JSONEncode(M)
 end)
 if ok and type(encoded)=="string" then
  reportLine=MARK.." "..encoded
 else
  reportLine=MARK..' {"schema":"gingerscope-stage63-one-window-client-accept-delta-v1","status":"JSON_UNAVAILABLE","readOnly":true,"serverCompletionProven":false,"tradeOutcome":"UNKNOWN","mayUseForStrategyLearning":false}'
 end
 print(reportLine)
 if copyButton then pcall(function()copyButton.Visible=true end)end
 guidance("FINISHED "..M.status..". Tap COPY REPORT; no trade automation.")
 return M
end

local function argShape(...)
 local count=select("#",...)
 local a,b=...
 local first="OTHER"
 if count==0 then first="NO_ARGS"
 elseif type(a)=="boolean" then first=a and "BOOLEAN_TRUE" or "BOOLEAN_FALSE"
 elseif a==nil then first="NIL" end
 local second="NIL"
 local shape="NOT_TABLE"
 if type(b)=="table" then
  second="TABLE"
  local ok,n=pcall(function()return #b end)
  if ok and type(n)=="number" and n>=1 and n<=16 then
   shape="BOUNDED_SEQUENCE_"..tostring(n)
  else
   shape="UNKNOWN_OR_EMPTY"
  end
 elseif b~=nil then second="OTHER" end
 return math.min(count,16),first,second,shape
end
local function onAccept(...)
 if finished then return end
 if not core or core.state~="OBSERVING_CLOSE" and
    core.state~="POST_CLOSE_READS" then
  ignored=ignored+1;return
 end
 if game.PlaceId~=142823291 or tostring(game.JobId or "")~=meJob then
  M.discardedReceipts=M.discardedReceipts+1;return
 end
 if not boundRoot or not boundLabel then
  ignored=ignored+1;return
 end
 local root,name,n=rootAndLabel()
 local phase
 if root==boundRoot and name==boundLabel and n==1 then
  phase="WITHIN_BOUND_GUI_CLIENT_ONLY"
  lastVisible=os.clock()
 elseif not root and lastVisible and
   os.clock()-lastVisible<=.75 and
   (core.state=="OBSERVING_CLOSE" or core.state=="POST_CLOSE_READS") then
  phase="IMMEDIATE_GUI_CLOSE_CLIENT_ONLY"
 else
  M.discardedReceipts=M.discardedReceipts+1
  return
 end
 if #M.samples>=12 then
  M.discardedReceipts=M.discardedReceipts+1
  return
 end
 local count,first,second,shape=argShape(...)
 local elapsed=math.floor(math.max(0,math.min(150,
   os.clock()-(boundAt or start)))*10+.5)/10
 M.samples[#M.samples+1]={
  firstArg=first,secondArg=second,secondTableShape=shape,argCount=count,
  phase=phase,elapsedSeconds=elapsed
 }
end

screenGuide()
if not game or game.PlaceId~=142823291 then
 return finish("INCOMPLETE","WRONG_GAME")
end
for _,name in ipairs({KEY,CORE_KEY,"PDIDDLER_STAGE59_PAIRED_MANUAL_OBSERVER",
  "PDIDDLER_STAGE61_ACCEPT_CALLBACK_TYPES",
  "PDIDDLER_PART4_SESSION","PDIDDLER_OUTGOING_SESSION",
  "PDIDDLER_PART5_CONTROLLER","PDIDDLER_STAGE25_SCANNER_ONLY"}) do
 if env[name]~=nil then
  return finish("INCOMPLETE","EXISTING_OBSERVER_OR_TRADER_REJOIN_REQUIRED")
 end
end
env[KEY]=M
local okay,event=pcall(function()
 local trade=game:GetService("ReplicatedStorage"):FindFirstChild("Trade")
 local remote=trade and trade:FindFirstChild("AcceptTrade")
 if remote and remote:IsA("RemoteEvent") then return remote end
 return nil
end)
if not okay or not event then
 return finish("INCOMPLETE","ACCEPT_REMOTE_NOT_PRESENT")
end
local ok,conn=pcall(function()
 return event.OnClientEvent:Connect(onAccept)
end)
if not ok or not conn then return finish("INCOMPLETE","ACCEPT_LISTENER_UNAVAILABLE")end
connection=conn
guidance("READY. Open one manual trade only after MM2 has loaded. Wait for BASELINE BOUND; do not Accept yet.")
local loaded,other=pcall(function()
 local source=game:HttpGet(URL,true)
 if type(source)~="string" or #source<5000 then return nil end
 local fn=loadstring(source,"=stage63-pinned-stage59-core")
 if type(fn)~="function" then return nil end
 return fn()
end)
if not loaded or type(other)~="table" then
 return finish("INCOMPLETE","PINNED_READONLY_CORE_UNAVAILABLE")
end
core=other
M.status="OBSERVING"
task.spawn(function()
 local boundReady=false
 while not finished and os.clock()-start<205 do
  if game.PlaceId~=142823291 or tostring(game.JobId or "")~=meJob then
   finish("INCOMPLETE","MM2_SESSION_CHANGED");return
  end
  local st=core.state
  if st=="OBSERVING_CLOSE" and not boundReady then
   local r,n,count=rootAndLabel()
   if r and n and count==1 then
    boundRoot=r;boundLabel=n
    boundAt=os.clock();lastVisible=boundAt
    M.guiBound=true;M.stablePartnerLabel=true
    boundReady=true
    guidance("BASELINE BOUND + ACCEPT LISTENER READY. You control all offers and manual Accept. Close within 120s.")
   end
  elseif boundReady and (st=="OBSERVING_CLOSE" or st=="POST_CLOSE_READS") then
   local r,n,count=rootAndLabel()
   if r and (r~=boundRoot or n~=boundLabel or count~=1) then
    M.stablePartnerLabel=false
    finish("INCOMPLETE","TRADE_GUI_OR_PARTNER_CHANGED");return
   end
   if r==boundRoot then lastVisible=os.clock() end
   if st=="POST_CLOSE_READS" and previousCoreState~=st then
    guidance("GUI CLOSED. Two separate own-inventory readbacks pending; do NOT open another trade.")
   end
  end
  previousCoreState=st
  -- The core sets reportReady immediately before constructing its summary.
  -- Wait for the actual immutable result table to avoid cross-task torn reads.
  if core.reportReady and type(core.result)=="table" then
   finish("CLIENT_OBSERVER_FINISHED",
      boundReady and "ONE_BOUND_WINDOW_FINISHED" or "NO_BOUND_WINDOW")
   return
  end
  task.wait(.08)
 end
 finish("INCOMPLETE","TIMEOUT_OR_CONTEXT_REPLACED")
end)
return M
