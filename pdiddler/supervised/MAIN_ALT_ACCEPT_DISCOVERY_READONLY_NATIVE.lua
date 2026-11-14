-- ORIGINAL MM2 MAIN iPad: SINGLE read-only Accept-control discovery batch.
-- MAIN and authorized ALT open trade MANUALLY; ALT shows ONE cheap item.
-- Neither account presses FINAL ACCEPT; no items are transferred.
-- Does not send trade requests, OfferItem, AcceptTrade, DeclineTrade or inputs.
local E=(type(getgenv)=="function" and getgenv()) or _G
local OWNER="PDIDDLER_ACCEPT_CONTROL_DISCOVERY_OWNER"
local USED="PDIDDLER_ACCEPT_CONTROL_DISCOVERY_USED_JOB"
local NAME_KEY="PDIDDLER_ACCEPT_DISCOVERY_ALT_NAME"
local GAME=142823291
local SCHEMA="gingerscope-main-alt-native-accept-shape-batch-v1"
local function validName(n)
 return type(n)=="string" and #n>=3 and #n<=32
    and n:match("^[A-Za-z0-9_]+$")~=nil
end
local function blockOther()
 for _,key in ipairs({
  "PDIDDLER_SUPERVISED_P3_NATIVE_OWNER","PDIDDLER_OUTGOING_SESSION",
  "PDIDDLER_PART4_SESSION","PDIDDLER_STAGE119_LASTOFFER_OWNER",
  "PDIDDLER_STAGE119_P3_OWNER","PDIDDLER_STAGE101_IDENTITY_OWNER",
  "PDIDDLER_S2_SHADOW_OWNER","PDIDDLER_S2_KEY_RECON_OWNER",
  "PDIDDLER_S2_MULTIFEATURE_OWNER","PDIDDLER_SUPERVISED_ONE_ITEM_PILOT"
 }) do if E[key]~=nil then return true end end
 for _,key in ipairs({"PDIDDLER_AUTOTRADE_ACTIVE",
  "PDIDDLER_PART4_CONTROLLER_ACTIVE","PDIDDLER_OUTGOING_CONTROLLER_ACTIVE"}) do
  if E[key]==true then return true end
 end
 return false
end
local function pack(status,reason)
 return {schema=SCHEMA,status=status,reason=reason,
  readOnly=true,clientOnly=true,
  mainAltAccountLookupExact=false,clientTradePartnerLabelMatches=false,
  originalStage9Used=false,observedLocalOfferTransition=false,
  twoStableCaptures=false,stableIntervalMilliseconds=0,
  theirVisibleSlots=0,ourVisibleSlots=0,
  bothAcceptedIndicatorsReadable=false,acceptedState="UNKNOWN",
  controlShapeStatus="NOT_OBSERVED",candidateCount=0,
  visibleButtonCount=0,acceptTextLabelOnlyCount=0,
  candidatePath="NOT_MAPPED",candidateClass="NONE",
  candidateLabel="NONE",candidateActive=false,candidateBoundsVerified=false,
  acceptNamedRemoteStatus="NOT_INSPECTED",
  uiPlacementSafe=false,
  confirmedNativeAcceptBinding=false,serverTradeRevisionProven=false,
  serverCompletionProven=false,verifiedMarketPrice=false,
  authorizedAutoAccept=false,authorizesTrade=false,
  authorizesOffer=false,authorizesAccept=false,
  actualRequests=0,actualOffers=0,actualAccepts=0,actualDeclines=0,
  actualTeleports=0,mayReportProfit=false,maySendDiscordWebhook=false,
  mayUseForStrategyLearning=false,tradeOutcome="UNKNOWN",
  rawItemNamesExported=false,playerIdsExported=false,
  jobIdExported=false,fullInventoryExported=false}
end
if game.PlaceId~=GAME or type(game.JobId)~="string" or
   #game.JobId<8 or E[OWNER]~=nil or E[USED]==game.JobId or blockOther()
   or not validName(E[NAME_KEY]) then
 warn("[ACCEPT SHAPE] original MM2 fresh job, no other script and exact ALT username config required")
 return nil
end
local Players=game:GetService("Players")
local LP=Players and Players.LocalPlayer
local PG=LP and LP:FindFirstChildOfClass("PlayerGui")
local World=game:GetService("Workspace")
local Run=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
if not LP or not PG or not World or not World.CurrentCamera or
   not Run or not Run.RenderStepped or not RS then
 warn("[ACCEPT SHAPE] MAIN client services unavailable")
 return nil
end
local ALTNAME=E[NAME_KEY]
local ALT=Players:FindFirstChild(ALTNAME)
if not ALT or ALT==LP or ALT.Parent~=Players or ALT.Name~=ALTNAME or
   type(ALT.UserId)~="number" or ALT.UserId<1 or
   Players:GetPlayerByUserId(ALT.UserId)~=ALT then
 warn("[ACCEPT SHAPE] exact named ALT account must already be in MAIN server")
 return nil
end
local ALTID=ALT.UserId
local MAINID=LP.UserId
local function exactPair()
 return LP==Players.LocalPlayer and LP.Parent==Players and
  LP.UserId==MAINID and LP:FindFirstChildOfClass("PlayerGui")==PG and
  ALT.Parent==Players and ALT.Name==ALTNAME and ALT.UserId==ALTID and
  Players:FindFirstChild(ALTNAME)==ALT and
  Players:GetPlayerByUserId(ALTID)==ALT
end
local function frozen(sha,path)
 local url="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
   ..sha.."/pdiddler/"..path
 local good,code=pcall(function()return game:HttpGet(url)end)
 if not good or type(code)~="string" or #code<100 or #code>30000 then return nil end
 local compiler=loadstring or load
 if type(compiler)~="function" then return nil end
 local ok,result=pcall(function()return assert(compiler(code))()end)
 return ok and type(result)=="table" and result or nil
end
local shape=frozen("c6830816c23624d43da2242e15a716127629a189",
 "supervised/main_alt_accept_control_shape_probe.lua")
local stage9=frozen("1971b93d324f0275e6a9affb472ac3e804439ed8",
 "new_part4/p4_native_observer.lua")
local contract=frozen("1971b93d324f0275e6a9affb472ac3e804439ed8",
 "new_part4/p4_observer_contract.lua")
local geometry=frozen("5b8ee35d7f281c23d9c2181abd97a063e59a0660",
 "new_part4/stage100_screen_prompt_overlay.lua")
if not shape or type(shape.inspect)~="function" or
   not stage9 or type(stage9.new)~="function" or
   type(stage9.capture)~="function" or
   not contract or type(contract.normalize)~="function" or
   not geometry or type(geometry.choose)~="function" then
 warn("[ACCEPT SHAPE] immutable observer sources unavailable; no test")
 return nil
end
local state={running=true,phase="PREPARED",job=game.JobId,started=0,
 root=nil,handle=nil,baseline=nil,baselineAt=0,lastSnapshot=nil,
 render=nil,status=pack("PREPARED","WAIT_OPERATOR_ARM"),everTrade=false,
 sawEmptyAltOffer=false}
E[USED]=game.JobId
E[OWNER]=state
local function currentTrade()
 local roots={}
 for _,name in ipairs({"TradeGUI_Phone","TradeGUI"}) do
  local screen=PG:FindFirstChild(name)
  local container=screen and screen:FindFirstChild("Container")
  local root=container and container:FindFirstChild("Trade")
  if screen and screen.Enabled==true and container and
     container.Visible==true and root and root.Visible==true then
   roots[#roots+1]=root
  end
 end
 if #roots>1 then return nil,"MULTIPLE_VISIBLE_TRADE_ROOTS" end
 return roots[1],nil
end
local function labelMatches(root)
 local side=root and root:FindFirstChild("TheirOffer")
 local label=side and side:FindFirstChild("Username")
 local raw=label and (label:IsA("TextLabel") or label:IsA("TextButton"))
     and label.Text or nil
 if type(raw)~="string" then return false end
 local s=raw:match("^%s*%((.-)%)%s*$") or raw
 s=s:gsub("^@",""):gsub("^%s+",""):gsub("%s+$","")
 -- DisplayName is deliberately NOT trusted as an account key.
 return s:lower()==ALTNAME:lower()
end
local function clock()return os.clock()end
local ui={}
local constructed=pcall(function()
 ui.root=Instance.new("ScreenGui")
 ui.root.Name="PDIDDLER_MainAlt_AcceptShape_ReadOnly"
 ui.root.IgnoreGuiInset=true
 ui.root.ResetOnSpawn=false
 ui.root.DisplayOrder=160
 ui.root.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
 ui.root.Parent=PG
 ui.panel=Instance.new("Frame")
 ui.panel.Name="Instructions"
 ui.panel.BackgroundColor3=Color3.fromRGB(31,21,45)
 ui.panel.BorderSizePixel=0;ui.panel.Active=false
 ui.panel.Visible=false;ui.panel.Parent=ui.root
 local corner=Instance.new("UICorner")
 corner.CornerRadius=UDim.new(0,9);corner.Parent=ui.panel
 local stroke=Instance.new("UIStroke")
 stroke.Color=Color3.fromRGB(191,153,238)
 stroke.Thickness=1;stroke.Parent=ui.panel
 local function label(name,y,h,sz)
  local n=Instance.new("TextLabel")
  n.Name=name;n.TextColor3=Color3.fromRGB(249,243,255)
  n.BackgroundTransparency=1;n.TextWrapped=true;n.TextSize=sz
  n.TextXAlignment=Enum.TextXAlignment.Left
  n.Font=Enum.Font.GothamBold
  n.Position=UDim2.fromOffset(10,y)
  n.Size=UDim2.fromOffset(284,h);n.Parent=ui.panel
  return n
 end
 ui.title=label("StepTitle",5,23,13)
 ui.body=label("StepBody",29,76,12)
 ui.warning=label("SafetyWarning",103,20,11)
 ui.warning.Text="READ ONLY • NEVER FINAL ACCEPT"
 local function button(name,text,x)
  local n=Instance.new("TextButton")
  n.Name=name;n.Text=text;n.TextSize=12
  n.BackgroundColor3=Color3.fromRGB(97,59,137)
  n.TextColor3=Color3.fromRGB(255,255,255)
  n.Position=UDim2.fromOffset(x,127)
  n.Size=UDim2.fromOffset(129,28)
  n.Active=true;n.Parent=ui.panel
  return n
 end
 ui.arm=button("ArmObserver","ARM READ-ONLY",12)
 ui.stop=button("StopAndCopy","STOP / COPY",162)
end)
if not constructed then
 E[OWNER]=nil
 if ui.root then pcall(function()ui.root:Destroy()end)end
 warn("[ACCEPT SHAPE] safe panel creation failed; no live actions")
 return nil
end
local function refresh()
 if not state.running or ui.root.Parent~=PG or not World.CurrentCamera then
  return false,"SCREEN_CONTEXT_LOST"
 end
 local camera=World.CurrentCamera
 local vp=camera.ViewportSize
 if not vp then return false,"VIEWPORT_MISSING" end
 local bounds=nil
 if state.root then
  local p=state.root.AbsolutePosition
  local d=state.root.AbsoluteSize
  if not p or not d then return false,"TRADE_BOUNDS_MISSING" end
  bounds={x=p.X,y=p.Y,w=d.X,h=d.Y}
 end
 local rect,why=geometry.choose({x=vp.X,y=vp.Y},bounds,{w=304,h=160})
 if not rect then
  ui.panel.Visible=false
  return false,why
 end
 ui.panel.Position=UDim2.fromOffset(rect.x,rect.y)
 ui.panel.Size=UDim2.fromOffset(rect.w,rect.h)
 ui.panel.Visible=true
 return true,"NONOVERLAPPING"
end
local function sanitize(p)
 local x=pack(p.status or "INCONCLUSIVE",p.reason or "UNVERIFIED")
 for _,name in ipairs({"mainAltAccountLookupExact","clientTradePartnerLabelMatches",
 "originalStage9Used","observedLocalOfferTransition","twoStableCaptures",
 "stableIntervalMilliseconds","theirVisibleSlots","ourVisibleSlots",
 "bothAcceptedIndicatorsReadable","acceptedState","controlShapeStatus",
 "candidateCount","visibleButtonCount","acceptTextLabelOnlyCount",
 "candidatePath","candidateClass","candidateLabel",
 "candidateActive","candidateBoundsVerified","acceptNamedRemoteStatus",
 "uiPlacementSafe"}) do
  if p[name]~=nil then x[name]=p[name] end
 end
 return x
end
local function printCopy()
 local safe=sanitize(state.status)
 local ok,json=pcall(function()
  return game:GetService("HttpService"):JSONEncode(safe)
 end)
 if not ok or type(json)~="string" then
  warn("[ACCEPT SHAPE] sanitized JSON unavailable; screenshot status")
  return false
 end
 E.PDIDDLER_ACCEPT_DISCOVERY_LAST_JSON=json
 print("[MAIN ALT ACCEPT SHAPE SAFE RESULT] "..json)
 local fn=type(setclipboard)=="function" and setclipboard
    or type(toclipboard)=="function" and toclipboard or nil
 if fn then local good,r=pcall(fn,json);return good and r~=false end
 return false
end
local function terminate(reason,keepUI)
 if not state.running then return end
 state.running=false
 state.status=sanitize(state.status)
 if reason then
  state.status.status="STOPPED"
  state.status.reason=reason
 end
 if state.render then pcall(function()state.render:Disconnect()end)end
 E[OWNER]=nil
 if keepUI then
  ui.arm.Visible=false;ui.arm.Active=false
  ui.title.Text="SAFE REPORT READY"
  ui.body.Text="No final Accept was touched. Tap STOP / COPY and send JSON. Then manually Decline the trade on MAIN."
  ui.stop.Visible=true;ui.stop.Active=true
 else
  pcall(function()ui.root:Destroy()end)
 end
end
local function fail(why)
 terminate(why,true)
end
local function tick()
 if state.phase=="COMPLETE" or not state.running or
    state.phase=="PREPARED" then return end
 if game.PlaceId~=GAME or game.JobId~=state.job or
    not exactPair() or blockOther() then
  fail("EXACT_PAIR_JOB_OR_CONTROLLER_CHANGED");return
 end
 if ui.root.Parent~=PG or ui.panel.Parent~=ui.root then
  fail("OBSERVATION_PANEL_REMOVED");return
 end
 local t=clock()
 if t<state.started or t-state.started>120 then
  fail("CLIENT_OBSERVATION_TIMEOUT_OR_CLOCK_ROLLBACK");return
 end
 local trade,reason=currentTrade()
 if reason then fail(reason);return end
 if not state.root then
  if not trade then
   local safe=refresh()
   if not safe then fail("NO_SAFE_UI_SPACE");return end
   ui.title.Text="1/3 • MAIN + ALT"
   ui.body.Text="ALT sends a TRADE REQUEST. MAIN manually accepts that REQUEST. Do not press FINAL ACCEPT."
   return
  end
  if not labelMatches(trade) then
   fail("UNVERIFIED_OR_WRONG_PARTNER_LABEL");return
  end
  state.root=trade
  local session="MAIN_ALT_ACCEPT_SHAPE_ONE_LOCAL_TRADE"
  local ok,h=pcall(stage9.new,{game=game,players=Players,
   root=trade,session=session,jobId=state.job,
   partnerUserId=ALTID,localUserId=MAINID,
   contract=contract,marketFresh=function()return false end})
  if not ok or type(h)~="table" then
   fail("FROZEN_STAGE9_OBSERVER_SETUP_FAILED");return
  end
  state.handle=h;state.everTrade=true
  state.phase="WAIT_ALT_ITEM"
 end
 if trade~=state.root or not trade or not labelMatches(trade) then
  fail("TRADE_ROOT_OR_PARTNER_CHANGED");return
 end
 if not refresh() then
  fail("NO_SAFE_PANEL_OUTSIDE_LIVE_TRADE");return
 end
 local ok,snap,diag=pcall(stage9.capture,state.handle)
 if not ok or type(snap)~="table" or type(diag)~="table" or
    snap.tradeOpen~=true then
  fail("STAGE9_CLIENT_CAPTURE_INVALID_OR_CLOSED");return
 end
 if diag.authorizesAccept~=false or diag.authorizesTrade~=false then
  fail("ORIGINAL_STAGE9_AUTHORITY_UNEXPECTED");return
 end
 if type(snap.ourAccepted)~="boolean" or
    type(snap.theirAccepted)~="boolean" then
  fail("ACCEPT_STATE_INDICATOR_UNAVAILABLE");return
 end
 if snap.ourAccepted or snap.theirAccepted then
  fail("UNEXPECTED_MANUAL_FINAL_ACCEPT_STATE");return
 end
 if type(snap.ourSlots)~="number" or type(snap.theirSlots)~="number"
   or snap.ourSlots~=0 or snap.theirSlots>4 then
  fail("UNEXPECTED_MAIN_OFFER_OR_CLIENT_SLOT_COUNT");return
 end
 if snap.theirSlots==0 then
  state.sawEmptyAltOffer=true
  state.phase="WAIT_ALT_ITEM"
  ui.title.Text="2/3 • ALT ADD ONE"
  ui.body.Text="ALT manually adds ONE inexpensive eligible weapon. MAIN offers NOTHING. Neither side presses FINAL ACCEPT."
  return
 end
 if snap.theirSlots~=1 then
  fail("ALT_TEST_OFFER_NOT_EXACTLY_ONE_SLOT");return
 end
 if not state.sawEmptyAltOffer then
  fail("ALT_ITEM_PREEXISTED_WITHOUT_EMPTY_BASELINE");return
 end
 local vp=World.CurrentCamera.ViewportSize
 local info=shape.inspect(trade,{x=vp.X,y=vp.Y})
 if type(info)~="table" or
    info.readOnly~=true or info.authorizesAccept~=false then
  fail("NATIVE_ACCEPT_SHAPE_MODULE_INVALID");return
 end
 local remote=shape.remotePresence(RS)
 local sign=table.concat({tostring(snap.ourSig),tostring(snap.theirSig),
  tostring(snap.ourSlots),tostring(snap.theirSlots),
  tostring(snap.ourAccepted),tostring(snap.theirAccepted),
  tostring(info.status),tostring(info.candidatePath),
  tostring(info.candidateClass),tostring(info.candidateCount),
  tostring(info.candidateActive),tostring(remote)},"#")
 if state.baseline~=sign then
  if state.phase=="RECHECKING" then
   fail("ACTIVE_TRADE_OFFER_OR_ACCEPT_CONTROL_CHANGED");return
  end
  state.baseline=sign;state.baselineAt=t
  state.phase="RECHECKING"
  ui.title.Text="3/3 • KEEP OFFERS STILL"
  ui.body.Text="MAIN: no items. ALT: keep that single test weapon. Observing read-only Accept control twice. DO NOT FINAL ACCEPT."
  return
 end
 if t-state.baselineAt<0.4 then return end
 if t-state.baselineAt>5 then fail("STABLE_CAPTURE_WINDOW_EXPIRED");return end
 local shapeMapped=info.status=="ONE_VISIBLE_CANDIDATE_SHAPE"
 state.status=pack(shapeMapped and "CLIENT_ACCEPT_CONTROL_OBSERVED"
   or "INCONCLUSIVE_ACCEPT_CONTROL_MAPPING",
   shapeMapped and "GUI_SHAPE_ONLY_NOT_NATIVE_ACCEPT_OR_SETTLEMENT_AUTHORITY"
   or "NO_UNIQUE_TRUSTED_ACCEPT_CONTROL_SHAPE")
 state.status.mainAltAccountLookupExact=true
 state.status.clientTradePartnerLabelMatches=true
 state.status.originalStage9Used=true
 state.status.observedLocalOfferTransition=true
 state.status.twoStableCaptures=true
 state.status.stableIntervalMilliseconds=math.floor((t-state.baselineAt)*1000)
 state.status.theirVisibleSlots=snap.theirSlots
 state.status.ourVisibleSlots=snap.ourSlots
 state.status.bothAcceptedIndicatorsReadable=true
 state.status.acceptedState="MAIN_FALSE_ALT_FALSE"
 state.status.controlShapeStatus=info.status
 state.status.candidateCount=math.min(100,info.candidateCount or 0)
 state.status.visibleButtonCount=math.min(100,info.visibleButtonCount or 0)
 state.status.acceptTextLabelOnlyCount=math.min(100,info.labelOnlyCount or 0)
 state.status.candidatePath=info.candidatePath or "NOT_MAPPED"
 state.status.candidateClass=info.candidateClass or "NONE"
 state.status.candidateLabel=info.candidateLabel or "NONE"
 state.status.candidateActive=info.candidateActive==true
 state.status.candidateBoundsVerified=info.candidateBoundsVerified==true
 state.status.acceptNamedRemoteStatus=remote
 state.status.uiPlacementSafe=true
 state.phase="COMPLETE"
 terminate(nil,true)
end
ui.arm.Activated:Connect(function()
 if not state.running or state.phase~="PREPARED" then return end
 if not exactPair() or blockOther() then fail("PREARM_PAIR_OR_CONTROLLER_CHANGED");return end
 state.started=clock();state.phase="WAIT_TRADE"
 ui.arm.Visible=false;ui.arm.Active=false
 ui.stop.Visible=true
end)
ui.stop.Activated:Connect(function()
 if state.running then terminate("OPERATOR_STOPPED",true) end
 printCopy()
 pcall(function()ui.root:Destroy()end)
end)
local ok,err=refresh()
if not ok then
 terminate("INITIAL_PANEL_LAYOUT_"..tostring(err),false)
 warn("[ACCEPT SHAPE] no safe screen space; nothing started")
 return nil
end
ui.title.Text="MAIN ALT • READ-ONLY DISCOVERY"
ui.body.Text="Press ARM to observe ONE manual ALT trade. We inspect Accept control but NEVER touch it. Exact ALT account required."
ui.arm.Visible=true;ui.arm.Active=true
ui.stop.Visible=true;ui.stop.Active=true
state.render=Run.RenderStepped:Connect(function()
 local ok,err=pcall(tick)
 if not ok then fail("UNEXPECTED_CLIENT_OBSERVER_EXCEPTION") end
end)
print("[ACCEPT SHAPE] MAIN+ALT safe observer ready. ARM once; do not final Accept.")
return {status=function()return sanitize(state.status)end, stop=function()
 terminate("OPERATOR_STOPPED",true);return sanitize(state.status)
end}
