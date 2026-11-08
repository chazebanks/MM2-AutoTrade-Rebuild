-- Stage59: GUIDED, PASSIVE, read-only dual-client receipt collection.
-- This does NOT trade, press Accept, offer weapons, or infer server completion.
-- It loads the previously native-tested Stage32 passive observer at an immutable
-- GitHub commit. Sender and receiver each run ONE copy in the same MM2 server.
-- Only anonymized aggregate client readback counts are printed/copied.
-- Read full trade instructions on-screen DURING execution.
local specifiedRole=...
local MARKER="[GINGERSCOPE STAGE59 PAIRED WITNESS]"
local PAIR_ID="STAGE59-NOV08-MANUAL-A"
local SOURCE="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"..
 "f74cb081590dfcdf100bd41f818e07d34856dff4/"..
 "pdiddler/new_part4/STAGE59_RESULT_DELTA_120S_PROBE.lua"
local E=(type(getgenv)=="function" and getgenv()) or _G
local KEY="PDIDDLER_STAGE59_PAIRED_MANUAL_OBSERVER"
local OLD="PDIDDLER_STAGE32_RESULT_CORRELATION_PROBE"
local M={state="NOT_STARTED",role="UNASSIGNED",readOnly=true,
 authorizesTrade=false,authorizesAccept=false,mayReportProfit=false,
 mayRecordCompletedTrade=false,serverCompletionProven=false,
 tradeOutcome="UNKNOWN"}
local label,gui,roleButtons=nil,nil,{}
local function say(s)
 if label and gui and gui.Parent then pcall(function() label.Text=s end) end
 print("[STAGE59 GUIDE] "..s)
end
local function copyOutput(value)
 local function safe(fn)
  if type(fn)~="function" then return false end
  local ok,returned=pcall(fn,value)
  return ok and returned~=false
 end
 if safe(setclipboard) or safe(toclipboard) then return true end
 if type(getgenv)=="function" then
  local ok,env=pcall(getgenv)
  if ok and type(env)=="table" then
   return safe(env.setclipboard) or safe(env.toclipboard)
  end
 end
 return false
end
local function panel()
 pcall(function()
  if type(Instance)~="table" or type(Instance.new)~="function" then return end
  local Players=game:GetService("Players")
  local me=Players and Players.LocalPlayer
  local pg=me and me:FindFirstChildOfClass("PlayerGui")
  if not pg then return end
  local old=pg:FindFirstChild("GINGERSCOPE_STAGE59_GUIDE")
  if old then old:Destroy() end
  local screen=Instance.new("ScreenGui")
  screen.Name="GINGERSCOPE_STAGE59_GUIDE"
  screen.ResetOnSpawn=false;screen.DisplayOrder=175
  screen.IgnoreGuiInset=false
  local frame=Instance.new("Frame")
  frame.Size=UDim2.fromOffset(365,182)
  frame.Position=UDim2.new(1,-379,0,40)
  frame.BackgroundColor3=Color3.fromRGB(36,25,58)
  frame.BorderSizePixel=0
  frame.Parent=screen
  local corner=Instance.new("UICorner")
  corner.CornerRadius=UDim.new(0,10);corner.Parent=frame
  local heading=Instance.new("TextLabel")
  heading.Size=UDim2.new(1,-44,0,26)
  heading.Position=UDim2.fromOffset(10,8)
  heading.BackgroundTransparency=1
  heading.Font=Enum.Font.GothamBold;heading.TextSize=16
  heading.TextColor3=Color3.fromRGB(245,232,255)
  heading.TextXAlignment=Enum.TextXAlignment.Left
  heading.Text="STAGE 59  |  PASSIVE DUAL RECEIPT"
  heading.Parent=frame
  label=Instance.new("TextLabel")
  label.Size=UDim2.new(1,-20,0,86)
  label.Position=UDim2.fromOffset(10,41)
  label.BackgroundTransparency=1;label.Font=Enum.Font.Gotham
  label.TextSize=14;label.TextWrapped=true
  label.TextXAlignment=Enum.TextXAlignment.Left
  label.TextYAlignment=Enum.TextYAlignment.Top
  label.TextColor3=Color3.fromRGB(247,243,253)
  label.Text="CHOOSE ROLE: On this device are you SENDING or RECEIVING the low-value test weapon?"
  label.Parent=frame
  local close=Instance.new("TextButton")
  close.Size=UDim2.fromOffset(29,25)
  close.Position=UDim2.new(1,-33,0,7)
  close.BackgroundTransparency=1
  close.Font=Enum.Font.GothamBold;close.TextSize=18
  close.TextColor3=Color3.fromRGB(245,232,255)
  close.Text="X";close.Parent=frame
  close.Activated:Connect(function()screen:Destroy()end)
  for index,role in ipairs({"SENDER","RECEIVER"}) do
   local b=Instance.new("TextButton")
   b.Name=role;b.Size=UDim2.fromOffset(157,36)
   b.Position=UDim2.fromOffset(10+(index-1)*174,137)
   b.BackgroundColor3=Color3.fromRGB(112,69,168)
   b.TextColor3=Color3.fromRGB(255,255,255)
   b.TextSize=14;b.Font=Enum.Font.GothamBold
   b.Text=role;b.Parent=frame
   roleButtons[role]=b
  end
  gui=screen
  screen.Parent=pg
 end)
end
local function roleControlsHide()
 for _,b in pairs(roleButtons) do
  pcall(function()b.Visible=false end)
 end
end
local SAFE_FIELDS={
 "schema","status","reason","stopReason","inventoryStatus",
 "beforeObserved","windowClosureObserved","postReadbacksObserved",
 "changedEligibleTypes","gainedEligibleCopies","lostEligibleCopies",
 "rawWeaponInventoryChanged","closureStatus",
 "signalReceipts","completeTradeSignalSeen",
 "endTradeSignalSeen","declineTradeSignalSeen",
 "partnerDepartureObserved","observedOurAccept","observedTheirAccept",
 "bothAcceptedStableObserved","offerMutationAfterAccept",
 "tradeOutcome","readOnly","serverAttestation",
 "serverCompletionProven","causalAttributionProven","authorizesTrade",
 "authorizesAccept","mayRecordCompletedTrade","mayReportProfit"
}
local function safe32(src)
 if type(src)~="table" or
  src.schema~="gingerscope-stage32-readonly-result-correlation-v1" or
  src.readOnly~=true or src.tradeOutcome~="UNKNOWN" or
  src.serverCompletionProven~=false or src.serverAttestation~=false or
  src.causalAttributionProven~=false or src.authorizesTrade~=false or
  src.authorizesAccept~=false or
  src.mayRecordCompletedTrade~=false or src.mayReportProfit~=false then
  return nil
 end
 local dst={}
 for _,key in ipairs(SAFE_FIELDS) do
  local v=src[key]
  if v~=nil and type(v)~="string" and type(v)~="boolean"
    and type(v)~="number" then return nil end
  if type(v)=="string" and
    (#v>90 or not v:match("^[%w _%-%:%.]+$")) then return nil end
  if type(v)=="number" and (v~=v or v<0 or v>100000) then return nil end
  if v~=nil then dst[key]=v end
 end
 return dst
end
local function finish(reason,core)
 if M.state=="FINISHED" then return end
 M.state="FINISHED"
 local HttpService=game:GetService("HttpService")
 local nonce
 local okNonce,generated=pcall(function()
  return HttpService:GenerateGUID(false)
 end)
 if okNonce and type(generated)=="string" and
  #generated>=16 and #generated<=64 and generated:match("^[%x%-]+$") then
  nonce=generated
 end
 local source=core and core.result or nil
 local evidence=safe32(source)
 -- Wrapper status must reflect whether the nested client observer completed
 -- BOTH independent post-close inventory reads, not merely that it returned.
 local terminal=evidence
   and evidence.status~="INCOMPLETE"
   and evidence.windowClosureObserved==true
   and evidence.postReadbacksObserved==2
   and evidence.stopReason=="TWO_POST_CLOSE_READS_FINISHED"
   and evidence.closureStatus=="closed_unknown"
   and evidence.beforeObserved==true
 local report={
  schema="gingerscope-stage59-two-client-aggregate-witness-v1",
  operatorDeclaredRole=M.role,pairId=PAIR_ID,
  receiptNonce=nonce,observedAtUnix=os.time(),
  readOnly=true,serverCompletionProven=false,serverAttestation=false,
  authorizesTrade=false,authorizesAccept=false,
  mayRecordCompletedTrade=false,mayReportProfit=false,
  tradeOutcome="UNKNOWN",
  collectorStatus=terminal and "CLIENT_STAGE32_TERMINAL_OBSERVATION"
    or "INCOMPLETE_STAGE32_NO_POST_CLOSE_EVIDENCE",
  collectorReason=(not terminal and reason=="STAGE32_FINISHED")
    and "STAGE32_FINISHED_WITHOUT_TERMINAL_READBACKS"
    or (reason or "NO_REASON"),
  stage32=evidence
 }
 if not nonce then
  report.collectorStatus="INCOMPLETE_NO_NONCE"
 end
 local ok,encoded=pcall(function()return HttpService:JSONEncode(report)end)
 if not ok or type(encoded)~="string" then
  say("REPORT ERROR: Couldn't encode. Send console error; no trade result proven.")
  return
 end
 local line=MARKER.." "..encoded
 local copied=copyOutput(line)
 print(line)
 if copied then
  say("FINISHED. Anonymous result copied. PASTE it in ChatGPT. Then paste the OTHER DEVICE report too. Never claim profit.")
 else
  say("FINISHED. Clipboard blocked: copy full STAGE59 PAIRED WITNESS console line into ChatGPT. Then other device.")
 end
 M.report=report
end
local lastState=nil
local boundAt=nil
local lastCountdownBucket=nil
local running=false
local startRole
startRole=function(role)
 if running then return end
 if role~="SENDER" and role~="RECEIVER" then
  say("INVALID ROLE. Choose SENDER or RECEIVER. NO automatic trade actions.")
  return
 end
 if M.state~="NOT_STARTED" then return end
 if game.PlaceId~=142823291 then
  say("WRONG GAME. Join original Murder Mystery 2 and rerun.")
  return
 end
 if E[KEY] or E[OLD] then
  say("OLD TRADE TEST FOUND. Rejoin fresh MM2 before this test.")
  return
 end
 running=true;M.state="STARTING";M.role=role
 roleControlsHide()
 E[KEY]=M
 local originalJob=tostring(game.JobId or "")
 say("READ-ONLY "..role.." starting. Keep both devices in SAME server; wait for READY before manual trade. No auto Accept.")
 task.spawn(function()
  local got,src=pcall(function()return game:HttpGet(SOURCE,true)end)
  if not got or type(src)~="string" or #src<100 then
   finish("STAGE32_SOURCE_UNAVAILABLE");return
  end
  if type(loadstring)~="function" then finish("EXECUTOR_MISSING_LOADSTRING");return end
  local fn,why=loadstring(src,"=stage32-readonly-source")
  if not fn then finish("STAGE32_COMPILE_FAILED");return end
  local launched,core=pcall(fn)
  if not launched or type(core)~="table" then
   finish("STAGE32_LAUNCH_FAILED");return
  end
  local startedAt=os.clock()
  while game.PlaceId==142823291
    and game.JobId==originalJob
    and os.clock()-startedAt<180 do
   if core.reportReady and type(core.result)=="table" then
    finish("STAGE32_FINISHED",core)
    return
   end
   local state=tostring(core.state or "UNKNOWN")
   if state~=lastState then
    lastState=state
    if state=="AWAIT_MANUAL_TRADE" then
     say("READY. On BOTH devices wait for READY. Open a manual low-value trade. Don't Accept until BOTH say BASELINE BOUND.")
    elseif state=="OBSERVING_CLOSE" then
     say("BASELINE BOUND. Both devices ready? Sender offers ONE expendable eligible item, receiver none. BOTH MANUALLY Accept only if willing. ~120s timebox.")
    elseif state=="POST_CLOSE_READS" then
     say("TRADE WINDOW CLOSED. Do NOT rejoin yet; reading local inventory twice. Wait for FINISHED.")
    else
     say("STAGE32 "..state..". No trade automation. Wait for the next on-screen step.")
    end
   end
   -- Approximate operator clock. The Stage59-only Stage32 fork owns the
   -- authoritative 120-second monotonic observation deadline.
   if state=="OBSERVING_CLOSE" then
    if not boundAt then boundAt=os.clock() end
    local remaining=math.max(0,120-math.floor(os.clock()-boundAt))
    local bucket=math.floor(remaining/15)
    if bucket~=lastCountdownBucket then
     lastCountdownBucket=bucket
     say("BASELINE BOUND: approx "..remaining.."s left. Both clients bound? Complete ONLY manual actions now, or decline; no automatic Accept.")
    end
   end
   task.wait(.2)
  end
  finish("OBSERVER_TIMEOUT_OR_SERVER_CHANGE",core)
 end)
end
panel()
say("CHOOSE SENDER or RECEIVER for THIS device. The test only watches manual trading and reads client inventory.")
for role,b in pairs(roleButtons) do
 b.Activated:Connect(function()startRole(role)end)
end
if specifiedRole~=nil then startRole(specifiedRole) end
return M
