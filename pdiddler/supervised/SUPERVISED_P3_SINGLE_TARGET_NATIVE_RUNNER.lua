-- PDIDDLER: single-target LIVE P3 request to P4 READ-ONLY session pilot.
-- ORIGINAL MM2 only. This is NOT live portfolio trading or auto final Accept.
-- Exact single consenting username. No offers, removes, trade Accept, prices,
-- settlement/profit, webhook, full-server rotation or stale legacy balancer.
local E=(getgenv and getgenv()) or _G
local CFG=E.PDIDDLER_P3_SUPERVISED_TARGET_PILOT
if type(CFG)~="table"
  or CFG.armed~=true
  or CFG.allowSingleTargetRequest~=true
  or CFG.acknowledgeIncomingDeclines~=true
  or CFG.noAutomaticAcceptAcknowledged~=true
  or type(CFG.targetName)~="string"
  or #CFG.targetName<3 or #CFG.targetName>32
  or not CFG.targetName:match("^[A-Za-z0-9_]+$") then
  warn("[P3 SUPERVISED] Explicit single target and acknowledgments required")
  return nil
end
if game.PlaceId~=142823291 or type(game.JobId)~="string"
  or game.JobId=="" then
  warn("[P3 SUPERVISED] Original MM2 job only")
  return nil
end
if E.PDIDDLER_P3_SUPERVISED_JOB==game.JobId then
  warn("[P3 SUPERVISED] This job already ran; fresh server needed")
  return nil
end
if E.PDIDDLER_P3_OUTGOING_CONTROLLER
   or E.PDIDDLER_OUTGOING_BUSY_SESSION
   or E.PDIDDLER_PART4_SESSION
   or E.PDIDDLER_P3_SUPERVISED_CONTROLLER then
  warn("[P3 SUPERVISED] Another transaction owner is present")
  return nil
end
local Players=game:GetService("Players")
local LP=Players.LocalPlayer
local PG=LP and LP:FindFirstChildOfClass("PlayerGui")
local Run=game:GetService("RunService")
local World=game:GetService("Workspace")
if not PG or not Run or not Run.RenderStepped
  or not World or not World.CurrentCamera then
  warn("[P3 SUPERVISED] Guide cannot be rendered")
  return nil
end
local target=Players:FindFirstChild(CFG.targetName)
if not target or target==LP or target.Parent~=Players
  or Players:GetPlayerByUserId(target.UserId)~=target then
  warn("[P3 SUPERVISED] Exact target not present in current server")
  return nil
end
-- Client-origin GUI evidence never proves source ownership or settlement.
local function report(status,reason,own,their)
  return {schema="pdiddler-p3-single-target-supervised-status-v1",
   status=status,reason=reason,
   ownPhysicalSlots=own,theirPhysicalSlots=their,
   contactOrigin="P3_CLIENT_PROCESSED_TRADE_OPEN_UNATTESTED",
   requestOriginBound=false,rawItemIdsAuthenticated=false,
   pricesAuthenticated=false,serverCompletionProven=false,
   authorizesOffer=false,authorizesTrade=false,authorizesAccept=false,
   mayReportProfit=false,maySendDiscordWebhook=false,
   tradeOutcome="UNKNOWN"}
end
local function source(moduleCommit,path)
  local url="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
      ..moduleCommit.."/pdiddler/"..path
  local ok,src=pcall(function()return game:HttpGet(url,true)end)
  if not ok or type(src)~="string" or #src<30 then
    return nil,"FROZEN_SOURCE_FETCH_FAILED"
  end
  local fn=loadstring(src)
  if type(fn)~="function" then return nil,"FROZEN_SOURCE_COMPILE_FAILED" end
  local ran,mod=pcall(fn)
  if not ran or type(mod)~="table" then
    return nil,"FROZEN_SOURCE_INIT_FAILED"
  end
  return mod,nil
end
local geom,why=source(
  "5b8ee35d7f281c23d9c2181abd97a063e59a0660",
  "new_part4/stage100_screen_prompt_overlay.lua")
if not geom or type(geom.choose)~="function" then
  warn("[P3 SUPERVISED]",why or "no geometry")
  return nil
end
local statusUI={}
local made=pcall(function()
 statusUI.screen=Instance.new("ScreenGui")
 statusUI.screen.Name="PDIDDLER_P3_SUPERVISED_PILOT_STATUS"
 statusUI.screen.IgnoreGuiInset=true
 statusUI.screen.ResetOnSpawn=false
 statusUI.screen.DisplayOrder=150
 statusUI.screen.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
 statusUI.screen.Parent=PG
 statusUI.frame=Instance.new("Frame")
 statusUI.frame.BackgroundColor3=Color3.fromRGB(28,23,40)
 statusUI.frame.BorderSizePixel=0
 statusUI.frame.Active=false
 statusUI.frame.Visible=false
 statusUI.frame.Parent=statusUI.screen
 local stroke=Instance.new("UIStroke")
 stroke.Color=Color3.fromRGB(177,128,239)
 stroke.Thickness=1
 stroke.Parent=statusUI.frame
 local corner=Instance.new("UICorner")
 corner.CornerRadius=UDim.new(0,9)
 corner.Parent=statusUI.frame
 local function makeLabel(name,y,h,size,color)
  local v=Instance.new("TextLabel")
  v.Name=name;v.BackgroundTransparency=1;v.Active=false
  v.TextColor3=color;v.TextSize=size
  v.TextXAlignment=Enum.TextXAlignment.Left
  v.TextWrapped=true;v.Font=Enum.Font.GothamBold
  v.Position=UDim2.fromOffset(10,y)
  v.Size=UDim2.fromOffset(280,h)
  v.Parent=statusUI.frame
  return v
 end
 statusUI.title=makeLabel("CurrentStep",6,23,13,Color3.fromRGB(218,187,255))
 statusUI.body=makeLabel("OperatorInstruction",30,60,12,Color3.fromRGB(255,255,255))
 statusUI.warning=makeLabel("NoAccept",94,18,11,Color3.fromRGB(255,215,185))
 statusUI.warning.Text="NEVER PRESS FINAL ACCEPT | READ ONLY"
end)
if not made or not statusUI.frame then
  if statusUI.screen then pcall(function()statusUI.screen:Destroy()end)end
  warn("[P3 SUPERVISED] In-game guide unavailable")
  return nil
end
local rootCount=0
local function currentTrade()
 local result=nil
 rootCount=0
 for _,name in ipairs({"TradeGUI_Phone","TradeGUI"}) do
  local screen=PG:FindFirstChild(name)
  local container=screen and screen:FindFirstChild("Container")
  local root=container and container:FindFirstChild("Trade")
  if root and screen.Enabled==true
    and container.Visible==true and root.Visible==true then
    result=root
    rootCount+=1
  end
 end
 if rootCount>1 then return nil,"MULTIPLE_VISIBLE_TRADE_ROOTS" end
 return result,nil
end
local function placeGuide(title,body)
 if not statusUI.screen or statusUI.screen.Parent~=PG then
  return false,"GUIDE_REMOVED"
 end
 local v=World.CurrentCamera and World.CurrentCamera.ViewportSize
 if not v or not v.X or not v.Y then
  return false,"VIEWPORT_INVALID"
 end
 local trade,reason=currentTrade()
 if reason then return false,reason end
 local rect=nil
 if trade then
  local ok,pos,size=pcall(function()
     return trade.AbsolutePosition,trade.AbsoluteSize
  end)
  if not ok or not pos or not size then
    return false,"TRADE_BOUNDS_UNKNOWN"
  end
  rect={x=pos.X,y=pos.Y,w=size.X,h=size.Y}
 end
 local area,why=geom.choose(
  {x=v.X,y=v.Y},rect,{w=304,h=120})
 if not area then return false,why or "GUIDE_NO_SAFE_SPACE" end
 local ok=pcall(function()
  statusUI.frame.Position=UDim2.fromOffset(area.x,area.y)
  statusUI.frame.Size=UDim2.fromOffset(area.w,area.h)
  statusUI.title.Text=title
  statusUI.body.Text=body
  statusUI.frame.Visible=true
 end)
 if not ok then return false,"GUIDE_LAYOUT_ERROR" end
 return true,nil
end
local function terminate(reason)
 pcall(function()statusUI.frame.Visible=false end)
 if statusUI.screen then pcall(function()statusUI.screen:Destroy()end)end
 warn("[P3 SUPERVISED]",reason)
end
local shown,shownReason=placeGuide("1/3 MAIN - PREPARE",
 "MAIN: preparing exact ALT request-only test. ALT: keep trade offers empty.")
if not shown then terminate(shownReason);return nil end

local scanner,scanWhy=source(
 "dfcfc7d52ce5f9cc64390bb5e28ce79512f1c001",
 "pdiddler3_scanner_MODULE_v6_5_PART4_STATUS_BRIDGE.lua")
local outgoingModule,outWhy=source(
 "2036ae5bd937620f21d46600f99550a1b233a654",
 "supervised/pdiddler3_outgoing_START_GATED_v1.lua")
local bridge,bridgeWhy=source(
 "2f556afac5e5fd9cfdbf9e081eeea01a542d293",
 "supervised/supervised_p3_p4_handoff.lua")
local coordinator,coordWhy=source(
 "dfcfc7d52ce5f9cc64390bb5e28ce79512f1c001",
 "supervised/supervised_real_p3_rotation_handoff.lua")
local ioModule,ioWhy=source(
 "a599c31c53d25e6799b9d631f45f282b445dcda0",
 "supervised/pdiddler4_tradeio_supervised_v2.lua")
if not scanner or not outgoingModule or not bridge
  or not coordinator or not ioModule then
 terminate(scanWhy or outWhy or bridgeWhy or coordWhy or ioWhy
    or "PINNED_DEPENDENCY_UNAVAILABLE")
 return nil
end
-- Hide legacy scanner GUI. It is only metadata/whitelist evidence, not
-- an authorized trade/economic-value dashboard or a trade overlay.
local function hideScannerGui()
 local roots={PG}
 local core=game:GetService("CoreGui")
 if core then roots[#roots+1]=core end
 if type(gethui)=="function" then
  local ok,h=pcall(gethui)
  if ok and h then roots[#roots+1]=h end
 end
 local hidden=false
 for _,root in ipairs(roots) do
  local g=root:FindFirstChild("MM2EligibilityScannerT41")
  if g then
   local ok=pcall(function()g.Enabled=false end)
   if ok and g.Enabled==false then hidden=true end
  end
 end
 return hidden
end
if not hideScannerGui() then
 terminate("SCANNER_GUI_CANNOT_BE_HIDDEN")
 return nil
end
if type(scanner.getRecord)~="function" or
  type(scanner.isWhitelisted)~="function" or
  type(scanner.getWhitelist)~="function" then
 terminate("SCANNER_API_UNAVAILABLE")
 return nil
end
-- A narrowly scoped facade: the original outgoing V5 queue may only
-- contact this EXACT present user, never the rest of the server.
local facade={}
function facade.getWhitelist()
 if target.Parent==Players
  and Players:GetPlayerByUserId(target.UserId)==target
  and scanner.isWhitelisted(target.UserId) then
  return {target}
 end
 return {}
end
function facade.getRecord(uid)
 if uid==target.UserId then return scanner.getRecord(uid) end
end
function facade.isWhitelisted(uid)
 return uid==target.UserId and target.Parent==Players
  and Players:GetPlayerByUserId(uid)==target
  and scanner.isWhitelisted(uid)
end
function facade.hasPendingWork()
 return scanner.hasPendingWork()
end
function facade.setStatus(text)
 return scanner.setStatus(text)
end
function facade.setRequestState(p,state,extra)
 return scanner.setRequestState(p,state,extra)
end
local gate={}
local io
local ioOk,ioResult=pcall(ioModule.new,{
 resolveOfferEntry=function()return nil end
},gate)
if ioOk then io=ioResult end
if not io then terminate("PROTECTED_TRADE_IO_UNAVAILABLE");return nil end
-- PROTECTED TradeIO remains default-DENY: gate.checkOutbound is NEVER set.
local observer=nil
local outgoing=nil
local running=true
local startedJob=game.JobId
local function isReady()
 if not running or startedJob~=game.JobId or
  target.Parent~=Players or
  Players:GetPlayerByUserId(target.UserId)~=target or
  not observer or not outgoing or
  E.PDIDDLER_P3_SUPERVISED_JOB~=startedJob then
  return false
 end
 local ok=placeGuide("1/3 MAIN - REQUESTS ARMED",
  "MAIN: requests restricted to one ALT. ALT: accept the request. NO item-trade Accept.")
 return ok==true and hideScannerGui() and currentTrade()==nil
end
local runOk,out=pcall(outgoingModule.run,facade,{
 requiresExplicitStart=true,readyCheck=isReady
})
if not runOk or type(out)~="table" then
 terminate("P3_START_BARRIER_INITIALIZATION_FAILED")
 return nil
end
outgoing=out
local bound,err=coordinator.new(
 facade,outgoing,bridge,io,Players,LP,
 {getJobId=function()return game.JobId end,
  getP3Session=function()return E.PDIDDLER_OUTGOING_SESSION end}
)
if type(bound)~="table" then
 outgoing.stop()
 terminate("P3_P4_SUPERVISOR_UNAVAILABLE")
 return nil
end
observer=bound
E.PDIDDLER_P3_SUPERVISED_JOB=startedJob
CFG.armed=false
local armed,armReason=outgoing.arm()
if armed~=true then
 outgoing.stop()
 observer.stop()
 terminate("P3_START_BARRIER_NOT_ARMED")
 return nil
end
local state=report("P3_ROTATING","ONE_NAMED_PARTNER_ONLY")
E.PDIDDLER_P3_SUPERVISED_REPORT=state
local lastStatus=nil
local turnBound=false
local lost=0
local function publish(r)
 if type(r)~="table" then return end
 state=report(r.status or "UNKNOWN",r.reason or "UNKNOWN",
  r.ownPhysicalSlots,r.theirPhysicalSlots)
 E.PDIDDLER_P3_SUPERVISED_REPORT=state
 if state.status~=lastStatus then
  lastStatus=state.status
  print("[P3 SUPERVISED]",state.status,state.reason,
   "NO AUTO OFFER OR FINAL ACCEPT")
 end
end
local function shutdown(reason)
 if not running then return end
 running=false
 if outgoing and outgoing.stop then outgoing.stop() end
 if observer and observer.stop then observer.stop() end
 publish(report("STOPPED",reason))
 placeGuide("STOP - READ ONLY",
   "MAIN: no further requests. Outcome UNKNOWN. Do not press final Accept.")
 local ok,json=pcall(function()
  return game:GetService("HttpService"):JSONEncode(state)
 end)
 if ok and type(json)=="string" then
  E.PDIDDLER_P3_SUPERVISED_LAST_JSON=json
  local clip=type(setclipboard)=="function" and setclipboard
    or type(toclipboard)=="function" and toclipboard
    or type(E.setclipboard)=="function" and E.setclipboard
  if clip then pcall(clip,json) end
  print("[P3 SUPERVISED RESULT]",json)
 end
end
E.PDIDDLER_P3_SUPERVISED_CONTROLLER={
 stop=function() shutdown("OPERATOR_STOP") end,
 report=function()return state end,
}
task.spawn(function()
 for iteration=1,600 do
  if not running then break end
  task.wait(0.25)
  -- Operator shutdown may occur DURING task.wait. Never overwrite the
  -- final STOPPED receipt with a stale observer poll after that.
  if not running then break end
  if startedJob~=game.JobId then
   shutdown("JOB_CHANGED");break
  end
  if not hideScannerGui() then
   shutdown("SCANNER_GUI_NOT_HIDDEN");break
  end
  local a,why=placeGuide("1/3 MAIN - P3 ROTATING",
   "MAIN: only exact ALT will receive a request. ALT: accept. No final item Accept.")
  if not a then shutdown(why or "GUIDE_UNAVAILABLE");break end
  if outgoing.isPaused() and io.trade()==nil then
   local resumed,resumeReason=observer.resumeAfterClose()
   if resumed then
    turnBound=false
    publish(report("P3_RESUMED","CLIENT_TRADE_CLOSED"))
   elseif turnBound then
    shutdown(resumeReason or "P3_RESUME_REFUSED");break
   end
  end
  local observed=observer.poll()
  if observed.status=="P4_TWO_SIDED_CLIENT_SNAPSHOT" then
   turnBound=true
   lost=0
   publish(observed)
   local safe,why2=placeGuide("2/3 MAIN - PART 4 OBSERVE",
    "MAIN: review read-only trade. ALT: keep offers unchanged. Manually Decline to resume.")
   if not safe then shutdown(why2 or "GUIDE_COLLISION");break end
  elseif observed.status=="P3_PAUSED_UNATTRIBUTED" then
   lost+=1
   publish(observed)
   if lost>8 then shutdown("UNATTRIBUTED_P3_TRADE");break end
  elseif observed.status=="BLOCKED" then
   publish(observed)
   shutdown("P3_P4_SESSION_UNSAFE");break
  else
   lost=0
   publish(observed)
  end
 end
 if running then shutdown("PILOT_WATCH_WINDOW_ENDED") end
end)
return E.PDIDDLER_P3_SUPERVISED_CONTROLLER
