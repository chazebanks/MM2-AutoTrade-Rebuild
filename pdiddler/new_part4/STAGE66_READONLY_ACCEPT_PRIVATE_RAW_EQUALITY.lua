-- Stage66: one same-window privacy-only raw callback row equality probe.
-- Uses Stage65 pure offline equality and Stage66 additive raw snapshot fork.
-- It does not send/accept/decline any trade, nor print raw IDs or item names.
-- Stage66 MAIN-only read-only SAME-WINDOW AcceptTrade + OWN inventory evidence.
-- Built on immutable Stage59 role-neutral observer source: no second scanner.
-- Only client signals and own before/post inventory; never game settlement.
-- No offers, requests, final Accept, decline, server hop, webhook or profit.
local MARK="[GINGERSCOPE STAGE66 SAME WINDOW]"
local KEY="PDIDDLER_STAGE66_SAME_WINDOW_CLIENT_ONLY"
local CORE_KEY="PDIDDLER_STAGE32_RESULT_CORRELATION_PROBE"
local CORE_PIN="79919f199e616e7d03cec1e8bbcfbb99ae60c099"
local URL="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"..
 CORE_PIN.."/pdiddler/new_part4/STAGE66_ROLE_NEUTRAL_PRIVATE_RAW_SNAPSHOTS.lua"
local HELPER_PIN="27263d7e2fe44a0da842b7062eff7c91c6ea3b65"
local HELPER_URL="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"..
 HELPER_PIN.."/pdiddler/intelligence_lab/p4_stage65_private_raw_receipt_equality.lua"
local env=(type(getgenv)=="function" and getgenv()) or _G
local meJob=game and tostring(game.JobId or "") or ""
local M={
 schema="gingerscope-stage66-one-window-client-accept-delta-v1",
 status="INITIALIZING",reason="AWAITING_TRADE",
 readOnly=true,tradeOutcome="UNKNOWN",
 serverAttestation=false,serverCompletionProven=false,
 serverTransactionIdAuthenticated=false,eventSessionAssociationProven=false,
 causalTradeAttributionProven=false,exactWeaponIdentityConfirmed=false,
 authorizesTrade=false,authorizesAccept=false,
 mayRecordCompletedTrade=false,mayRecordRejectedTrade=false,
 mayReportProfit=false,mayUseForStrategyLearning=false,
 clientCompatibleFlagPattern=false,clientReciprocalTransferProven=false,
 privateRawKeyEqualityObserved=false,
 privateRawEqualityStatus="NOT_TESTED",
 privateRawEqualityReason="NOT_EVALUATED",
 callbackRowFieldTypes={"NOT_OBSERVED","NOT_OBSERVED","NOT_OBSERVED"},
 callbackRowShape="NOT_OBSERVED",
 exactCallbackWeaponKeyIdentityProven=false,
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
local privateRows=nil -- real callback values only in memory, never report.
local privateHelper=nil
local ignored=0

local function guidance(message)
 print("[STAGE66 GUIDE] "..message)
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
  local old=pg:FindFirstChild("GINGERSCOPE_STAGE66_READONLY")
  if old then return end
  local screen=Instance.new("ScreenGui")
  screen.Name="GINGERSCOPE_STAGE66_READONLY"
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
  label.Text="STAGE66 | READ-ONLY | NO AUTO ACCEPT"
  label.Parent=panel
  copyButton=Instance.new("TextButton")
  copyButton.Size=UDim2.new(1,-16,0,29)
  copyButton.Position=UDim2.fromOffset(8,112)
  copyButton.BackgroundColor3=Color3.fromRGB(115,72,180)
  copyButton.TextColor3=Color3.fromRGB(255,255,255)
  copyButton.Text="COPY STAGE66 REPORT"
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
    guidance("COPIED current Stage66 report. Paste into ChatGPT.")
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
    c.status=="ELIGIBLE_DELTA_WITHOUT_RESULT_NAMED_RECEIPT" and
    c.beforeObserved==true and c.windowClosureObserved==true and
    c.postReadbacksObserved==2 and c.closureStatus=="closed_unknown" and
    c.readOnly==true and c.tradeOutcome=="UNKNOWN" and
    c.serverCompletionProven==false and
    c.mayRecordCompletedTrade==false and c.authorizesAccept==false)
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
 -- Never promote a fatal/error/partial finished path even if an old or
 -- injected core.result happens to have plausible counts and callback shapes.
 local positive=(status=="CLIENT_OBSERVER_FINISHED" and
   reason=="ONE_BOUND_WINDOW_FINISHED") and
   compatible and M.coreTerminal and own
   and own.gainedEligibleCopies==1 and own.lostEligibleCopies==0
   and own.changedEligibleTypes==1
   and own.rawWeaponInventoryChanged==true
 if positive then
  local snapshots=core and core.privateRawSnapshots
  local source=snapshots and type(snapshots)=="table"
    and {
      beforeOwned=snapshots.before,
      post1Owned=snapshots.post1,
      post2Owned=snapshots.post2,
      receivedItems=privateRows,
      callbackFirstArg=(privateRows~=nil),
      scopedInOneGui=(M.guiBound and M.stablePartnerLabel and
        M.ignoredUnboundReceipts==0 and M.discardedReceipts==0)
    } or nil
  local checked,comparison=pcall(function()
    if type(privateHelper)~="table" or
       type(privateHelper.evaluate)~="function" then return nil end
    return privateHelper.evaluate(source)
  end)
  if checked and type(comparison)=="table" then
    local state=comparison.status
    M.privateRawEqualityStatus=(type(state)=="string" and state
      or "INVALID_HELPER_STATUS")
    M.privateRawEqualityReason=(type(comparison.reason)=="string"
      and comparison.reason or "INVALID_HELPER_REASON")
    if state=="PRIVATE_RAW_PRIMITIVE_EQUALITY_CLIENT_ONLY"
       and comparison.rawCallbackKeyEqualsOwnGainedKey==true
       and comparison.serverCompletionProven==false
       and comparison.exactWeaponIdentityConfirmed==false
       and comparison.mayUseForStrategyLearning==false then
       M.privateRawKeyEqualityObserved=true
    end
  else
    M.privateRawEqualityStatus="PRIVATE_HELPER_UNAVAILABLE"
    M.privateRawEqualityReason="PRIVATE_COMPARISON_FAILED"
  end
  M.status=M.privateRawKeyEqualityObserved
      and "CLIENT_RAW_RECEIPT_EQUALS_OWN_GAIN_UNATTRIBUTED"
      or "CLIENT_SUCCESS_LIKE_RAW_KEY_UNRESOLVED"
  M.reason="private-raw-key-string-equality-is-not-server-settlement-proof"
 elseif M.status=="CLIENT_OBSERVER_FINISHED" or
        M.status=="INITIALIZING" or M.status=="OBSERVING" then
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
  reportLine=MARK..' {"schema":"gingerscope-stage66-one-window-client-accept-delta-v1","status":"JSON_UNAVAILABLE","readOnly":true,"serverCompletionProven":false,"tradeOutcome":"UNKNOWN","mayUseForStrategyLearning":false}'
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
local function privateRowTypesAndCopy(items)
 -- Native 2026 callback elements have not been established previously.
 -- NEVER print/serialize item elements; only report type() results.
 if type(items)~="table" or getmetatable(items)~=nil then
  return nil,{"NOT_TABLE","NOT_TABLE","NOT_TABLE"},"ROW_CONTAINER_UNVERIFIED"
 end
 local count=0
 for k in pairs(items) do
  if k~=1 then
   return nil,{"UNKNOWN","UNKNOWN","UNKNOWN"},"MULTIPLE_OR_NONARRAY_ROWS"
  end
  count=count+1
 end
 if count~=1 or type(items[1])~="table"
    or getmetatable(items[1])~=nil then
  return nil,{"UNKNOWN","UNKNOWN","UNKNOWN"},"NOT_SINGLE_PLAIN_ROW"
 end
 local row=items[1]
 local types={type(row[1]),type(row[2]),type(row[3])}
 local fields=0
 for k in pairs(row) do
  if k~=1 and k~=2 and k~=3 then
   return nil,types,"ROW_HAS_ADDITIONAL_FIELDS"
  end
  fields=fields+1
 end
 if fields~=3 then return nil,types,"INCOMPLETE_TRIPLET" end
 if types[1]~="string" or types[2]~="number" or
    types[3]~="string" then
  return nil,types,"HISTORICAL_TRIPLET_TYPES_NOT_OBSERVED"
 end
 -- Source row values held PRIVATE until in-memory comparison and only.
 return {{row[1],row[2],row[3]}},types,"TRIPLET_ELEMENT_TYPES_OBSERVED"
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
 if first=="BOOLEAN_TRUE" and count==2 and second=="TABLE" then
  local _,rows=...
  local copied,types,why=privateRowTypesAndCopy(rows)
  M.callbackRowFieldTypes=types
  M.callbackRowShape=why
  privateRows=copied -- do not place raw item IDs in M or output
 end
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
local loadedHelper,helper=pcall(function()
 local src=game:HttpGet(HELPER_URL,true)
 if type(src)~="string" or #src<3000 then return nil end
 local fn=loadstring(src,"=stage66-pinned-private-raw-helper")
 if type(fn)~="function" then return nil end
 return fn()
end)
if not loadedHelper or type(helper)~="table"
    or type(helper.evaluate)~="function" then
 return finish("INCOMPLETE","PINNED_PRIVATE_HELPER_UNAVAILABLE")
end
privateHelper=helper
local loaded,other=pcall(function()
 local source=game:HttpGet(URL,true)
 if type(source)~="string" or #source<5000 then return nil end
 local fn=loadstring(source,"=stage66-pinned-role-neutral-raw-core")
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
   -- Any visible trade whose root/partner is unavailable, changed or
   -- ambiguous invalidates this locally bound window; silent loss is unsafe.
   if count>0 and (r~=boundRoot or n~=boundLabel or count~=1) then
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
