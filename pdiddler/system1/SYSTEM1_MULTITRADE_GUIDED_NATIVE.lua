-- System 1 MAIN / ALT: FOUR sequential manual-contact trade windows, one GUI.
-- Instrument REAL original protected MM2 TradeIO + original protected P3/P4
-- bridge with NEW manual-consent read-only lease for each opened trade.
-- DOES NOT START P3 ROTATION. Does not send requests, offers, Decline,
-- Accept, teleport, Discord, values or profit. Tests multiple GUI windows
-- without recycling P3's once-consumed outgoing contact event.
local E=(type(getgenv)=="function" and getgenv()) or _G
local ALT="venossgaming90190"
local PLACE=142823291
local MAIN="a3c209659942e8b45eec5da3555f7cfb83059c59"
local WALK="61536126eec12707174d16319e757ab7829b4534"
local BASE="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
local KEY="PDIDDLER_SYSTEM1_MULTITRADE_OWNER"
if game.PlaceId~=PLACE or E[KEY]~=nil or
   E.PDIDDLER_SYSTEM1_MULTITRADE_USED_JOB==game.JobId then
 warn("[SYSTEM1] Original MM2 + one active owner required")
 return nil
end
local conflictKeys={
 "PDIDDLER_OUTGOING_SESSION","PDIDDLER_PART4_SESSION",
 "PDIDDLER_PART4_CONTROLLER_ACTIVE","PDIDDLER_OUTGOING_CONTROLLER_ACTIVE",
 "PDIDDLER_AUTOTRADE_ACTIVE","PDIDDLER_SUPERVISED_P3_NATIVE_OWNER",
 "PDIDDLER_P3_AUTO_OWNED_PICKER_OWNER",
}
local function conflicts()
 for _,key in ipairs(conflictKeys) do
  if E[key]~=nil and E[key]~=false then return true end
 end
 return false
end
if conflicts() then
 warn("[SYSTEM1] A different P3/P4 owner is active; use a fresh server")
 return nil
end
local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local World=game:GetService("Workspace")
local Http=game:GetService("HttpService")
local LP=Players.LocalPlayer
local PG=LP and LP:FindFirstChildOfClass("PlayerGui")
if not PG or not Run or not World or not Http then
 warn("[SYSTEM1] Roblox player UI / runtime unavailable")
 return nil
end
local function getAlt()
 local x=Players:FindFirstChild(ALT)
 if not x or x==LP or x.Parent~=Players or
    type(x.Name)~="string" or x.Name~=ALT or
    type(x.UserId)~="number" or x.UserId<=0 then
  return nil
 end
 return x
end
local alt=getAlt()
if not alt then
 warn("[SYSTEM1] Exact consenting ALT absent from this server")
 return nil
end
local function loadAt(rev,path,maxlen)
 local url=BASE..rev.."/pdiddler/"..path
 local ok,source=pcall(function()return game:HttpGet(url)end)
 if not ok or type(source)~="string" or #source<100 or
    #source>(maxlen or 40000) then return nil end
 local compiled=loadstring(source)
 if type(compiled)~="function" then return nil end
 local good,mod=pcall(compiled)
 if not good or type(mod)~="table" then return nil end
 return mod
end
local ioModule=loadAt(MAIN,"supervised/pdiddler4_tradeio_supervised_v2.lua",25000)
local bridge=loadAt(MAIN,"supervised/supervised_p3_p4_handoff.lua",16000)
local geometry=loadAt(MAIN,"new_part4/stage100_screen_prompt_overlay.lua",12000)
local walkModule=loadAt(WALK,"system1/system1_multitrade_client_walkthrough.lua",16000)
if not ioModule or type(ioModule.new)~="function"
 or not bridge or type(bridge.bind)~="function"
 or not geometry or type(geometry.choose)~="function"
 or not walkModule or type(walkModule.new)~="function" then
 warn("[SYSTEM1] One of four SHA-pinned inspected sources unavailable")
 return nil
end
local gate={}
local made,io=pcall(ioModule.new,
    {resolveOfferEntry=function()return nil end},gate)
if not made or type(io)~="table" or
   type(io.trade)~="function" or
   type(io.partnerName)~="function" then
 warn("[SYSTEM1] Original safe P4 read-only API unavailable")
 return nil
end
local fsm,why=walkModule.new({maxRounds=4,maxWaitSeconds=90})
if not fsm then
 warn("[SYSTEM1] Four-round state machine rejected: "..tostring(why))
 return nil
end
local okNonce,nonce=pcall(function()return Http:GenerateGUID(false)end)
if not okNonce or type(nonce)~="string" or #nonce>70 then
 nonce="GUID_UNAVAILABLE"
end
local owner={running=true,job=game.JobId,alt=alt,nonce=nonce}
E[KEY]=owner
local ui={}
local madeGui=pcall(function()
 local sg=Instance.new("ScreenGui")
 sg.Name="PDIDDLER_System1_MultiTrade_Guided"
 sg.ResetOnSpawn=false;sg.IgnoreGuiInset=true
 sg.DisplayOrder=152
 sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
 sg.Parent=PG
 ui.screen=sg
 local panel=Instance.new("Frame")
 panel.Name="Panel"
 panel.BackgroundColor3=Color3.fromRGB(35,22,55)
 panel.BorderSizePixel=0;panel.Visible=false
 panel.ZIndex=10
 panel.Parent=sg;ui.panel=panel
 local stroke=Instance.new("UIStroke")
 stroke.Color=Color3.fromRGB(173,124,247)
 stroke.Thickness=1
 stroke.Parent=panel
 local corner=Instance.new("UICorner")
 corner.CornerRadius=UDim.new(0,9)
 corner.Parent=panel
 local function label(name,y,h,size,color)
  local x=Instance.new("TextLabel")
  x.Name=name;x.BackgroundTransparency=1
  x.TextColor3=color or Color3.fromRGB(255,255,255)
  x.TextSize=size;x.TextWrapped=true
  x.Font=Enum.Font.GothamSemibold
  x.TextXAlignment=Enum.TextXAlignment.Left
  x.TextYAlignment=Enum.TextYAlignment.Top
  x.ZIndex=11
  x.Position=UDim2.fromOffset(10,y)
  x.Size=UDim2.fromOffset(290,h)
  x.Parent=panel;return x
 end
 ui.title=label("RoundTitle",8,24,14,Color3.fromRGB(221,190,255))
 ui.body=label("DoThis",36,78,15)
 ui.metrics=label("Evidence",114,29,11,Color3.fromRGB(223,211,247))
 ui.warning=label("Safety",141,19,10,Color3.fromRGB(253,208,219))
 local function button(name,text,x,w)
  local b=Instance.new("TextButton")
  b.Name=name;b.Text=text;b.TextSize=12
  b.TextColor3=Color3.fromRGB(255,255,255)
  b.BackgroundColor3=Color3.fromRGB(79,48,117)
  b.Font=Enum.Font.GothamBold
  b.ZIndex=12
  b.Position=UDim2.fromOffset(x,164)
  b.Size=UDim2.fromOffset(w,27)
  b.Parent=panel
  return b
 end
 ui.stop=button("Stop","STOP",9,87)
 ui.copy=button("Copy","COPY",104,87)
 ui.next=button("Next","NEXT ROUND",199,103)
end)
if not madeGui or not ui.screen or not ui.panel or
   not ui.stop or not ui.copy or not ui.next then
 owner.running=false;E[KEY]=nil
 if ui.screen then pcall(function()ui.screen:Destroy()end) end
 warn("[SYSTEM1] Cannot install nonoverlapping guided panel")
 return nil
end

local bound=nil
local boundRoot=nil
local epoch=0
local lastRoot=nil
local killed=false
local lastSourceReason="CLIENT_WAITING_FOR_TRADE"
local tickCount=0
local layoutFailures=0
local lastSlotsOwn,lastSlotsTheir=0,0
local lastResult=fsm.status()
local function ancestryVisible(inst)
 if not inst then return false end
 local p,count=inst,0
 while p and p~=PG and count<25 do
  local valid,visible=pcall(function()
   if p:IsA("ScreenGui") then return p.Enabled==true end
   if p:IsA("GuiObject") then return p.Visible==true end
   return true
  end)
  if not valid or not visible then return false end
  p=p.Parent;count+=1
 end
 return p==PG
end
local function exactTrade()
 local roots={}
 for _,key in ipairs({"TradeGUI_Phone","TradeGUI"}) do
  local screen=PG:FindFirstChild(key)
  local container=screen and screen:FindFirstChild("Container")
  local root=container and container:FindFirstChild("Trade")
  if root and ancestryVisible(root) then
   roots[#roots+1]=root
  end
 end
 if #roots>1 then return nil,"MULTIPLE_VISIBLE_TRADE_ROOTS" end
 if #roots==0 then return nil,nil end
 local root=roots[1]
 if io.trade()~=root then
  return nil,"ORIGINAL_PROTECTED_IO_ROOT_MISMATCH"
 end
 if io.partnerName(root)~=ALT then
  return nil,"TRADE_PARTNER_NOT_EXACT_CONSENTING_ALT"
 end
 return root,nil
end
local function manualBound(root)
 epoch+=1
 local sessionEpoch=epoch
 local contact={
  getRecord=function(uid)
   if alt==getAlt() and uid==alt.UserId then
    return {player=alt,state="whitelist"}
   end
  end,
  isWhitelisted=function(uid)
   return uid==alt.UserId and alt==getAlt()
  end,
 }
 local window={
  session=sessionEpoch,
  isPaused=function()
   return owner.running and io.trade()==root and
       ancestryVisible(root)
  end,
  resume=function()
   return false,"MANUAL_TEST_NOT_A_P3_RESUME"
  end,
 }
 local getEpoch=function()return sessionEpoch end
 local ok,b,err=pcall(bridge.bind,
    contact,window,io,Players,LP,{
     targetName=ALT,
     getJobId=function()return game.JobId end,
     getP3Session=getEpoch,
    })
 if not ok or type(b)~="table" or type(b.capture)~="function" then
  return nil,"MANUAL_PROTECTED_P3_P4_BRIDGE_REFUSED"
 end
 return b,nil
end
local function sanitized()
 local result=fsm.status()
 return {
  schema="gingerscope-system1-supervised-multitrade-native-v1",
  runNonce=nonce,
  phase=result.phase,reason=result.reason,round=result.round,
  step=result.step,completedRounds=result.completedRounds,
  passedRounds=result.passedRounds,failedRounds=result.failedRounds,
  openedTradeWindows=result.openedTradeWindows,
  observedStepTransitions=result.observedStepTransitions,
  rounds=result.rounds,stopped=result.stopped,finished=result.finished,
  screenLayoutFailures=layoutFailures,
  nativeStopReason=lastSourceReason,
  p3AutomaticRequestsSent=0,
  physicalOffersSentByScript=0,actualAcceptsByScript=0,
  actualDeclinesByScript=0,actualTeleportsByScript=0,
  clientOnly=true,manualContactOnly=true,
  p3RequestOriginAuthenticated=false,
  serverTradeRevisionProven=false,
  rawItemIdsAuthenticated=false,
  serverCompletionProven=false,
  authorizesOffer=false,authorizesTrade=false,authorizesAccept=false,
  mayReportProfit=false,maySendDiscordWebhook=false,
  mayUseForStrategyLearning=false,tradeOutcome="UNKNOWN",
 }
end
local function copyStatus()
 local ok,json=pcall(function()return Http:JSONEncode(sanitized())end)
 if not ok or type(json)~="string" then
  warn("[SYSTEM1] Sanitized JSON serialization failed")
  return false
 end
 local copy=type(setclipboard)=="function" and setclipboard
 if copy then pcall(copy,json) end
 print("[SYSTEM1 SANITIZED RESULT] "..json)
 return true
end
local function kill(reason)
 if killed then return fsm.status() end
 killed=true;owner.running=false
 if not fsm.status().stopped then lastResult=fsm.stop() end
 lastSourceReason=reason or "OPERATOR_STOPPED"
 copyStatus()
 if ui.screen then pcall(function()ui.screen:Destroy()end) end
 E.PDIDDLER_SYSTEM1_MULTITRADE_USED_JOB=owner.job
 E.PDIDDLER_SYSTEM1_MULTITRADE_RUNNER=nil
 E[KEY]=nil
 warn("[SYSTEM1 STOP] "..tostring(lastSourceReason))
 return lastResult
end
local function geometryCheck(root)
 if not ui.screen or ui.screen.Parent~=PG or
    not ui.panel or ui.panel.Parent~=ui.screen then
  return false,"INSTRUCTION_PANEL_REMOVED"
 end
 local camera=World.CurrentCamera
 local ok,v=pcall(function()return camera.ViewportSize end)
 if not ok or not v then return false,"CAMERA_VIEWPORT_UNAVAILABLE" end
 local tradeRect=nil
 if root then
  local got,pos,size=pcall(function()
   return root.AbsolutePosition,root.AbsoluteSize
  end)
  if not got or not pos or not size then
    return false,"TRADE_BOUNDS_UNAVAILABLE"
  end
  tradeRect={x=pos.X,y=pos.Y,w=size.X,h=size.Y}
 end
 local pos,why=geometry.choose({x=v.X,y=v.Y},tradeRect,
     {w=312,h=196})
 if not pos then return false,tostring(why) end
 local laid=pcall(function()
  ui.panel.Position=UDim2.fromOffset(pos.x,pos.y)
  ui.panel.Size=UDim2.fromOffset(pos.w,pos.h)
  ui.panel.Visible=true
 end)
 return laid,laid and "NONOVERLAPPING_GUI" or "GUI_POSITION_UNAVAILABLE"
end
local function show(root)
 local safe,why=geometryCheck(root)
 if not safe then
  layoutFailures+=1
  ui.panel.Visible=false
  kill("ONSCREEN_LAYOUT_UNSAFE_"..tostring(why))
  return false
 end
 local r=fsm.status()
 lastResult=r
 local statusPrefix=r.phase=="REVIEW" and
      (r.rounds[r.round] and r.rounds[r.round].result or "REVIEW") or
      r.phase
 ui.title.Text="SYSTEM 1 | TRADE "..r.round.."/"..r.maxRounds
 if r.phase=="REVIEW" or r.phase=="WAIT_CLOSE_AFTER_FAIL"
    or r.phase=="BLOCKED" then
  ui.body.Text=r.instruction.." Reason: "..tostring(r.reason)
 else
  ui.body.Text=r.instruction
 end
 ui.metrics.Text="Phase: "..tostring(statusPrefix)..
   " | GUI own:"..tostring(lastSlotsOwn)..
   " ALT:"..tostring(lastSlotsTheir)..
   " | Passed:"..tostring(r.passedRounds)..
   " Failed:"..tostring(r.failedRounds)
 ui.warning.Text="MANUAL TEST ONLY - NEVER FINAL ACCEPT"
 ui.next.Visible=r.canNext==true
 ui.next.Active=r.canNext==true
 return true
end
local function onTick()
 if killed or not owner.running then return lastResult end
 tickCount+=1
 if game.JobId~=owner.job or getAlt()~=owner.alt or
    conflicts() then return kill("JOB_ALT_OR_CONTROLLER_CHANGED") end
 local root,unsafe=exactTrade()
 if unsafe then return kill(unsafe) end
 if root~=nil and boundRoot~=nil and root~=boundRoot then
  return kill("TRADE_ROOT_REPLACED_BEFORE_CLOSE")
 end
 local snap=nil
 if root and bound==nil then
  local b,why=manualBound(root)
  if not b then return kill(why) end
  bound=b
  boundRoot=root
 end
 if root and bound then
  local ok,r=pcall(bound.capture)
  if not ok or type(r)~="table" or
     r.status~="CLIENT_UNPRICED_TWO_SIDED_SNAPSHOT" then
   return kill("ORIGINAL_PROTECTED_P4_SNAPSHOT_REJECTED")
  end
  snap=r
  lastSlotsOwn=r.physicalOwnSlots or -1
  lastSlotsTheir=r.physicalTheirSlots or -1
 else
  if bound~=nil then bound=nil;boundRoot=nil end
  lastSlotsOwn=0;lastSlotsTheir=0
 end
 lastRoot=root
 local ok,out=pcall(fsm.tick,{
    now=os.clock(),root=root,snapshot=snap,
    sameJob=game.JobId==owner.job,
    exactPartner=getAlt()==owner.alt,
    competingController=conflicts(),
 })
 if not ok or type(out)~="table" then
  return kill("PURE_WALKTHROUGH_RUNTIME_FAILURE")
 end
 lastResult=out
 if out.phase=="BLOCKED" then
  show(root)
  kill("CLIENT_WALKTHROUGH_BLOCKED")
  return out
 end
 if not show(root) then return lastResult end
 return out
end
ui.stop.Activated:Connect(function()kill("OPERATOR_STOPPED")end)
ui.copy.Activated:Connect(function()copyStatus()end)
ui.next.Activated:Connect(function()
 local ok,why=fsm.next()
 if not ok then return end
 -- REVIEW is only available after original game trade root vanished.
 local root,unsafe=exactTrade()
 if unsafe or root~=nil then
  kill("NEXT_WHILE_TRADE_STILL_VISIBLE")
  return
 end
 show(nil)
end)
local runner={
 tick=onTick,
 status=sanitized,
 copy=copyStatus,
 stop=function()return kill("OPERATOR_STOPPED")end,
}
E.PDIDDLER_SYSTEM1_MULTITRADE_RUNNER=runner
local first=show(nil)
if not first then return nil end
local spawned=pcall(function()
 task.spawn(function()
  while owner.running and not killed do
   local ok=pcall(onTick)
   if not ok then kill("SCHEDULED_CLIENT_WITNESS_THROWN") break end
   task.wait(0.2)
  end
 end)
end)
if not spawned then
 kill("WATCHDOG_SCHEDULING_FAILED")
 return nil
end
print("[SYSTEM1] Four MANUAL consenting-ALT trade windows, read-only diagnostics; original P3 requests NOT tested, final Accept OFF")
return runner
