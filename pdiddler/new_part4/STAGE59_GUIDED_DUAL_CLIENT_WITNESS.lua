-- Stage59: GUIDED, PASSIVE, read-only dual-client receipt collection.
-- This does NOT trade, press Accept, offer weapons, or infer server completion.
-- It loads the previously native-tested Stage32 passive observer at an immutable
-- GitHub commit. Sender and receiver each run ONE copy in the same MM2 server.
-- Only anonymized aggregate client readback counts are printed/copied.
-- Read full trade instructions on-screen DURING execution.
local specifiedRole,deviceProfile=...
-- Explicit role/profile passed by the two dedicated entrypoints.
-- PHONE is used only by ALT; TABLET keeps the previous main GUI unchanged.
local phoneMode=(specifiedRole=="SENDER" and (deviceProfile=="PHONE" or deviceProfile=="PHONE_RECOVER"))
local recoveryOnly=(deviceProfile=="PHONE_RECOVER" or deviceProfile=="TABLET_RECOVER")
local MARKER="[GINGERSCOPE STAGE59 PAIRED WITNESS]"
local PAIR_ID="STAGE59-NOV08-MANUAL-A"
local SOURCE="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"..
 "fe27ae43b5b52e142041d6ec930e3a1e89f33363/"..
 "pdiddler/new_part4/STAGE59_RESULT_DELTA_ROLE_NEUTRAL_BASELINE.lua"
local E=(type(getgenv)=="function" and getgenv()) or _G
local KEY="PDIDDLER_STAGE59_PAIRED_MANUAL_OBSERVER"
local OLD="PDIDDLER_STAGE32_RESULT_CORRELATION_PROBE"
local M={state="NOT_STARTED",role="UNASSIGNED",readOnly=true,
 authorizesTrade=false,authorizesAccept=false,mayReportProfit=false,
 mayRecordCompletedTrade=false,serverCompletionProven=false,
 tradeOutcome="UNKNOWN"}
local label,gui,roleButtons,reportButton=nil,nil,{},nil
local function fixedRole()
 return specifiedRole=="SENDER" or specifiedRole=="RECEIVER"
end
local function compactPhoneGuide(s)
 if s:find("^ROLE AUTO%-SELECTED") then
  return "ALT / SENDER readying. You GIVE one expendable weapon. Your main RECEIVES. Watch the status here."
 elseif s:find("^READ%-ONLY") then
  return "ALT / SENDER starting. Both accounts must join the SAME MM2 server. No automatic trades or Accept."
 elseif s:find("^READY") then
  return "READY. Wait for MAIN to say READY too. Then manually open ONE test trade. Do not Accept yet."
 elseif s:find("^BASELINE BOUND") then
  if s:find("left") then
   local secs=s:match("approx%s+(%d+)s")
   return "BASELINE BOUND. Approx "..tostring(secs or "?").."s left. Offer ONE expendable eligible duplicate; both MANUALLY Accept only if willing."
  end
  return "BASELINE BOUND. Wait for MAIN too. ALT offers ONE expendable duplicate; MAIN offers nothing. Accept manually if willing."
 elseif s:find("^TRADE WINDOW CLOSED") then
  return "CLOSED. Do NOT rejoin or trade again. Reading this client's inventory twice. Wait for FINISHED."
 elseif s:find("^FINISHED") then
  return s:sub(1,170)
 elseif s:find("^CHOOSE") then
  return "ALT / SENDER is automatically selected. You do not need purple SENDER/RECEIVER buttons."
 elseif s:find("^STAGE32") then
  return "ALT observer: "..s:sub(1,110)..". Check console if status remains unchanged."
 end
 return s
end
local function say(s)
 if label and gui and gui.Parent then
  pcall(function() label.Text=phoneMode and compactPhoneGuide(s) or s end)
 end
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
-- File storage is OPTIONAL; executor files live in that device's own
-- sandbox. We never assume iOS Delta has these functions or that a write
-- survived app termination until a readback verified it.
local function fileFn(kind)
 if kind=="write" and type(writefile)=="function" then return writefile end
 if kind=="read" and type(readfile)=="function" then return readfile end
 if type(getgenv)=="function" then
  local ok,env=pcall(getgenv)
  if ok and type(env)=="table" then
   local f=env[kind=="write" and "writefile" or "readfile"]
   if type(f)=="function" then return f end
  end
 end
 return nil
end
local function archivePrefix(role)
 if role=="SENDER" then return "GINGERSCOPE_STAGE59_ALT" end
 if role=="RECEIVER" then return "GINGERSCOPE_STAGE59_MAIN" end
 return nil
end
local function nonceIsSafe(v)
 return type(v)=="string" and #v>=16 and #v<=64
  and v:match("^[%x%-]+$")~=nil
end
local function validateLocalLine(line,expectedRole)
 if type(line)~="string" or #line<120 or #line>6000 or
  line:sub(1,#MARKER+1)~=MARKER.." " then return nil end
 local body=line:sub(#MARKER+2)
 local ok,receipt=pcall(function()
  return game:GetService("HttpService"):JSONDecode(body)
 end)
 if not ok or type(receipt)~="table" or
  receipt.schema~="gingerscope-stage59-two-client-aggregate-witness-v1" or
  receipt.operatorDeclaredRole~=expectedRole or receipt.pairId~=PAIR_ID or
  not nonceIsSafe(receipt.receiptNonce) or
  receipt.readOnly~=true or receipt.serverCompletionProven~=false or
  receipt.serverAttestation~=false or
  receipt.mayReportProfit~=false or
  receipt.mayRecordCompletedTrade~=false or
  receipt.authorizesTrade~=false or receipt.authorizesAccept~=false or
  receipt.tradeOutcome~="UNKNOWN" or
  type(receipt.observedAtUnix)~="number" or
  receipt.observedAtUnix<1700000000 or
  receipt.observedAtUnix>2100000000 or
  (receipt.collectorStatus~="CLIENT_STAGE32_TERMINAL_OBSERVATION" and
   receipt.collectorStatus~="INCOMPLETE_STAGE32_NO_POST_CLOSE_EVIDENCE" and
   receipt.collectorStatus~="INCOMPLETE_NO_NONCE") then return nil end
 if receipt.stage32~=nil then
  local d=receipt.stage32
  if type(d)~="table" or
   d.schema~="gingerscope-stage32-readonly-result-correlation-v1" or
   d.readOnly~=true or d.tradeOutcome~="UNKNOWN" or
   d.serverCompletionProven~=false or
   d.serverAttestation~=false or
   d.authorizesAccept~=false or
   d.mayRecordCompletedTrade~=false or
   d.mayReportProfit~=false then return nil end
 end
 return receipt
end
local function readSaved(role)
 local prefix=archivePrefix(role)
 local read=fileFn("read")
 if not prefix or not read then return nil end
 local ok,line=pcall(read,prefix.."_LAST.txt")
 if not ok or not validateLocalLine(line,role) then return nil end
 return line
end
local function saveLocal(line,role,nonce)
 local prefix=archivePrefix(role)
 local write,read=fileFn("write"),fileFn("read")
 if not prefix or not nonceIsSafe(nonce) or not write or not read then
  return "UNAVAILABLE"
 end
 local history=prefix.."_R_"..nonce:gsub("-","")..".txt"
 local latest=prefix.."_LAST.txt"
 local function verified(path,neverOverwrite)
  if neverOverwrite then
   local existing,old=pcall(read,path)
   if existing then return old==line end
  end
  local wrote=pcall(write,path,line)
  if not wrote then return false end
  local ok,value=pcall(read,path)
  return ok and value==line
 end
 -- Never overwrite a previous immutable receipt even on GUID collision.
 local archived=verified(history,true)
 local indexed=archived and verified(latest,false)
 if archived and indexed then
  M.localArchiveName=history
  return "VERIFIED_LOCAL_ARCHIVE"
 end
 return archived and "HISTORY_ONLY" or "UNAVAILABLE"
end
local function showAndCopyLocal()
 -- No fallback to an earlier _LAST report during a NEW observation.
 -- Copying an old result from an active READY screen caused ambiguous
 -- report provenance. Only explicit RECOVER_LAST may load prior receipts.
 local mode=M.state
 if mode~="FINISHED" and mode~="RECOVERY_ONLY" then
  say("COPY LOCKED. Current session is not FINISHED. To copy a previous report, use the separate RECOVER LAST script.")
  return false
 end
 local line=(mode=="RECOVERY_ONLY") and readSaved(M.role) or M.reportLine
 local receipt=line and validateLocalLine(line,M.role)
 if not receipt then
  say("NO RECOVERABLE "..tostring(M.role).." REPORT. Save file support may be unavailable; check Delta console.")
  return false
 end
 local ok=copyOutput(line)
 print("[STAGE59 "..M.role.." LOCAL RECEIPT RETRIEVAL] id="..
  receipt.receiptNonce:sub(1,8).." copied="..tostring(ok))
 -- Do not change a report's nonce or timestamp: a re-copy is NOT a new witness.
 if ok then
  say("COPY "..M.role.." OK (ID "..receipt.receiptNonce:sub(1,8)..
   "). Paste THIS device's report immediately; other device must have DIFFERENT ID.")
 else
  -- The ORIGINAL full receipt was already printed at completion.
  -- Never print a second full marker line: that looks like another witness.
  say("COPY BLOCKED (ID "..receipt.receiptNonce:sub(1,8)..
   "). Copy the ORIGINAL STAGE59 PAIRED WITNESS line from Delta console.")
 end
 return ok
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
  -- Lower-left start avoids Roblox's upper-right leaderboard.
  -- Drag the title bar to move the panel without hitting SENDER/RECEIVER.
  frame.Size=UDim2.fromOffset(320,182)
  frame.Position=UDim2.new(0,12,1,-200)
  if phoneMode then
   -- Compact landscape iPhone layout, away from leaderboard and joystick.
   -- Camera viewport is in Roblox UI units (not physical iPhone pixels).
   local width,height=270,146
   local screenWidth,screenHeight=0,0
   pcall(function()
    local camera=workspace and workspace.CurrentCamera
    local v=camera and camera.ViewportSize
    screenWidth=tonumber(v and v.X) or 0
    screenHeight=tonumber(v and v.Y) or 0
   end)
   if screenWidth>0 then
    width=math.max(180,math.min(270,screenWidth-24))
   end
   local y=72
   if screenHeight>0 then
    y=math.min(math.max(52,math.floor(screenHeight*0.23)),
      math.max(0,screenHeight-height))
   end
   frame.Size=UDim2.fromOffset(width,height)
   frame.Position=UDim2.fromOffset(12,y)
  end
  frame.BackgroundColor3=Color3.fromRGB(36,25,58)
  frame.BorderSizePixel=0
  frame.Parent=screen
  local corner=Instance.new("UICorner")
  corner.CornerRadius=UDim.new(0,10);corner.Parent=frame
  local heading=Instance.new("TextLabel")
  heading.Size=phoneMode
   and UDim2.new(1,-81,0,26) or UDim2.new(1,-44,0,26)
  heading.Position=UDim2.fromOffset(10,8)
  heading.BackgroundTransparency=1
  heading.Font=Enum.Font.GothamBold;heading.TextSize=phoneMode and 12 or 16
  heading.TextColor3=Color3.fromRGB(245,232,255)
  heading.TextXAlignment=Enum.TextXAlignment.Left
  heading.Text=phoneMode
   and "ALT SENDER  |  DRAG HERE" or "STAGE 59  |  DRAG HERE  |  READ-ONLY"
  heading.Active=true
  heading.Parent=frame
  label=Instance.new("TextLabel")
  label.Size=phoneMode
   and UDim2.new(1,-18,1,-80) or UDim2.new(1,-20,0,86)
  label.Position=UDim2.fromOffset(10,41)
  label.BackgroundTransparency=1;label.Font=Enum.Font.Gotham
  label.TextSize=phoneMode and 12 or 14;label.TextWrapped=true
  label.TextXAlignment=Enum.TextXAlignment.Left
  label.TextYAlignment=Enum.TextYAlignment.Top
  label.TextColor3=Color3.fromRGB(247,243,253)
  if fixedRole() then
   label.Text=specifiedRole=="RECEIVER"
     and "MAIN ACCOUNT / RECEIVER. Your alt sends the expendable weapon. Drag the title to move this guide."
     or "ALT ACCOUNT / SENDER. Your main receives the expendable weapon. Drag the title to move this guide."
  else
   label.Text="CHOOSE ROLE: SENDER gives an item; RECEIVER gets it. Hold and drag title to move this panel."
  end
  label.Parent=frame
  local close=Instance.new("TextButton")
  close.Size=UDim2.fromOffset(29,25)
  close.Position=UDim2.new(1,-33,0,7)
  close.BackgroundTransparency=1
  close.Font=Enum.Font.GothamBold;close.TextSize=18
  close.TextColor3=Color3.fromRGB(245,232,255)
  close.Text="X";close.Parent=frame
  close.Activated:Connect(function()screen:Destroy()end)
  reportButton=Instance.new("TextButton")
  reportButton.Name="COPY_OWN_STAGE59_REPORT"
  reportButton.Size=UDim2.new(1,-20,0,29)
  reportButton.Position=UDim2.new(0,10,1,-33)
  reportButton.Font=Enum.Font.GothamBold
  reportButton.TextSize=phoneMode and 12 or 13
  reportButton.BackgroundColor3=Color3.fromRGB(112,69,168)
  reportButton.TextColor3=Color3.fromRGB(255,255,255)
  reportButton.Text="COPY "..(specifiedRole=="SENDER" and "ALT" or "MAIN").." REPORT"
  -- Active sessions never expose a prior saved report's COPY control.
  reportButton.Visible=false
  reportButton.Parent=frame
  reportButton.Activated:Connect(function()showAndCopyLocal()end)
  if phoneMode then
   -- Explicit minimise/restore button: no hidden dependence on hover,
   -- scrolling, touch gestures, or the ALT role picker.
   local minimise=Instance.new("TextButton")
   minimise.Name="MINIMISE_PHONE_GUIDE"
   minimise.Size=UDim2.fromOffset(27,26)
   minimise.Position=UDim2.new(1,-64,0,7)
   minimise.BackgroundTransparency=1
   minimise.Font=Enum.Font.GothamBold;minimise.TextSize=18
   minimise.TextColor3=Color3.fromRGB(245,232,255)
   minimise.Text="-";minimise.Parent=frame
   local folded=false
   minimise.Activated:Connect(function()
    folded=not folded
    label.Visible=not folded
    if reportButton then
     reportButton.Visible=not folded and
      ((M.state=="FINISHED" and M.reportLine~=nil) or
       (M.state=="RECOVERY_ONLY" and readSaved(M.role)~=nil))
    end
    frame.Size=UDim2.fromOffset(frame.Size.X.Offset,folded and 36 or 146)
    minimise.Text=folded and "+" or "-"
   end)
  end
  if not fixedRole() then
   for index,role in ipairs({"SENDER","RECEIVER"}) do
    local b=Instance.new("TextButton")
   b.Name=role;b.Size=UDim2.fromOffset(143,36)
   b.Position=UDim2.fromOffset(10+(index-1)*160,137)
   b.BackgroundColor3=Color3.fromRGB(112,69,168)
   b.TextColor3=Color3.fromRGB(255,255,255)
   b.TextSize=14;b.Font=Enum.Font.GothamBold
   b.Text=role;b.Parent=frame
    roleButtons[role]=b
   end
  end
  gui=screen
  screen.Parent=pg

  -- Optional drag controller. A broken/missing InputService must NOT stop
  -- the role selection buttons or the passive read-only observation.
  pcall(function()
   local UIS=game:GetService("UserInputService")
   if not UIS or not UIS.InputChanged or not UIS.InputEnded
      or not heading.InputBegan then return end
   local dragging=false
   local pointer=nil
   local originX,originY,fromX,fromY=0,0,0,0
   local mouse=Enum.UserInputType.MouseButton1
   local movement=Enum.UserInputType.MouseMovement
   local touch=Enum.UserInputType.Touch
   heading.InputBegan:Connect(function(input)
    if input.UserInputType~=mouse and input.UserInputType~=touch then return end
    if dragging then return end
    dragging=true;pointer=input
    originX=frame.AbsolutePosition.X
    originY=frame.AbsolutePosition.Y
    fromX=input.Position.X;fromY=input.Position.Y
   end)
   UIS.InputChanged:Connect(function(input)
    if not dragging or not pointer or not gui or not gui.Parent then return end
    if not ((pointer.UserInputType==touch and input==pointer)
       or (pointer.UserInputType==mouse and input.UserInputType==movement)) then
     return
    end
    local camera=workspace and workspace.CurrentCamera
    if not camera then return end
    local size=camera.ViewportSize
    local width,height=frame.AbsoluteSize.X,frame.AbsoluteSize.Y
    if type(size.X)~="number" or type(size.Y)~="number" then return end
    local x=originX+(input.Position.X-fromX)
    local y=originY+(input.Position.Y-fromY)
    -- Keep the panel reachable after dragging, even on small iPad screens.
    x=math.max(0,math.min(x,math.max(0,size.X-width)))
    y=math.max(0,math.min(y,math.max(0,size.Y-height)))
    frame.Position=UDim2.fromOffset(x,y)
   end)
   UIS.InputEnded:Connect(function(input)
    if pointer and (input==pointer or
      (pointer.UserInputType==mouse and input.UserInputType==mouse)) then
     dragging=false;pointer=nil
    end
   end)
  end)
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
 "rawWeaponInventoryChanged","closureStatus","partnerCacheAtBaseline",
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
 M.report=report
 M.reportLine=line
 local localStorage=saveLocal(line,M.role,nonce)
 M.localArchiveStatus=localStorage
 if reportButton then pcall(function()
  reportButton.Text="COPY "..(M.role=="SENDER" and "ALT" or "MAIN")..
    " REPORT ("..tostring(nonce and nonce:sub(1,8) or "NO-ID")..")"
  reportButton.Visible=true
 end) end
 -- NEVER push the receipt into the OS clipboard automatically here.
 -- iPad+iPhone may share the Universal Clipboard: the later client's
 -- auto-copy can overwrite the earlier client's result, making ONE receiver
 -- receipt appear to have come from both clients. Only a deliberate tap on
 -- COPY MAIN/ALT REPORT may invoke copyOutput.
 print(line)
 local shortId=nonce and nonce:sub(1,8) or "NO-ID"
 local mode=(M.role=="SENDER" and "ALT" or "MAIN")
 local message="FINISHED "..mode.." ID "..shortId..
  " | local backup: "..localStorage..". TAP COPY "..mode..
  " REPORT on THIS DEVICE, then paste it. No automatic clipboard copy."
 if not reportButton then
  message=message.." UI unavailable: copy own console line manually."
 end
 say(message)
end
local lastState=nil
local lastAwaitReason=nil
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
   local gate=(state=="AWAIT_MANUAL_TRADE") and
    tostring(core.awaitReason or "NO_VISIBLE_TRADE") or ""
   if state~=lastState or gate~=lastAwaitReason then
    lastState=state
    lastAwaitReason=gate
    if state=="AWAIT_MANUAL_TRADE" then
     if gate=="PARTNER_LABEL_UNRESOLVED" then
      say("TRADE WINDOW FOUND; PARTNER LABEL UNRESOLVED. Check you are trading the correct account. Do NOT press Accept.")
     else
      say("READY. On BOTH devices wait for READY. Open a manual low-value trade. Don't Accept until BOTH say BASELINE BOUND.")
     end
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
if recoveryOnly then
 -- Recovery is READ-ONLY and never loads the Stage32 observation module.
 M.role=specifiedRole;M.state="RECOVERY_ONLY"
 local old=readSaved(M.role)
 if old then
  M.reportLine=old
  if reportButton then pcall(function()
   local savedReceipt=validateLocalLine(old,M.role)
   reportButton.Text="COPY "..(M.role=="SENDER" and "ALT" or "MAIN")..
     " REPORT ("..tostring(savedReceipt and savedReceipt.receiptNonce:sub(1,8) or "NO-ID")..")"
   reportButton.Visible=true
  end)end
  local receipt=validateLocalLine(old,M.role)
  say("SAVED "..M.role.." REPORT FOUND (ID "..
   tostring(receipt and receipt.receiptNonce:sub(1,8) or "UNKNOWN")..
   "). Tap COPY "..(M.role=="SENDER" and "ALT" or "MAIN")..
   " REPORT to copy it independently. Do NOT trade.")
 else
  say("NO SAVED "..M.role.." REPORT. This executor may not support file storage, or no prior archive was created. Do NOT trade.")
 end
 return M
end
if fixedRole() then
 say("ROLE AUTO-SELECTED: "..specifiedRole..". "..(specifiedRole=="SENDER"
  and "This ALT account DONATES the test weapon."
  or "This MAIN account RECEIVES the test weapon.")..
  " Your panel is draggable. No purple role button needed.")
else
 say("CHOOSE SENDER or RECEIVER for THIS device. The test only watches manual trading and reads client inventory.")
end
for role,b in pairs(roleButtons) do
 b.Activated:Connect(function()startRole(role)end)
end
if specifiedRole~=nil then startRole(specifiedRole) end
return M
