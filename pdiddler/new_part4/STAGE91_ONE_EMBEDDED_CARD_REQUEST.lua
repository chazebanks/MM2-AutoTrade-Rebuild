-- Stage91: ONE personally armed outgoing MM2 request, NO offer or Accept.
-- This is a diagnostic of the actual iPad GUI send boundary, not an autotrader.
-- Requires the operator to name the EXACT username and MANUALLY open that
-- player's leaderboard Profile/Trade card before the ONE physical Trade tap.
local E=(type(getgenv)=="function" and getgenv()) or _G
local KEY="GINGERSCOPE_STAGE91_SINGLE_REQUEST_DIAGNOSTIC"
local SCHEMA="gingerscope-stage91-single-contact-request-v1"
local targetName=E.PDIDDLER_STAGE91_TARGET_USERNAME
if E.PDIDDLER_STAGE91_ONE_REQUEST_ARMED~=true or
   type(targetName)~="string" or not targetName:match("^[A-Za-z0-9_]+$") or
   #targetName<3 or #targetName>20 then
 warn("[STAGE91] requires explicit one-request arming and exact Roblox username")
 return nil
end
if game.PlaceId~=142823291 then
 warn("[STAGE91] wrong game")
 return nil
end
if E[KEY]~=nil then
 warn("[STAGE91] one-shot already attempted: rejoin before another test")
 return E[KEY]
end
for _,k in ipairs({
 "GINGERSCOPE_STAGE88_CONTACT_READONLY_PREVIEW",
 "PDIDDLER_GINGERSCOPE_REPLACEMENT_PREVIEW",
 "PDIDDLER_OUTGOING_CONTROLLER","PDIDDLER_OUTGOING_SESSION",
 "PDIDDLER_OUTGOING_BUSY_SESSION","PDIDDLER_PART4_SESSION",
 "PDIDDLER_PART4_CONTROLLER","PDIDDLER_HOPPING_SESSION",
 "PDIDDLER_PART5_CONTROLLER","PDIDDLER_STATUS_OWNER",
 "GINGERSCOPE_STAGE83_READONLY_AGGREGATE_COVERAGE"
}) do
 if E[k]~=nil then
  warn("[STAGE91] existing script or transaction owner; fresh rejoin required")
  return nil
 end
end
local R={
 schema=SCHEMA,readOnly=false,contactRequestOnly=true,
 status="STARTING",reason="INITIALIZING",
 exactTargetClientBound=false,ownContactEvidenceReady=false,
 visibleCardExactNameMatched=false,requestTapCount=0,
 clientPendingExactTargetObserved=false,tradeWindowObserved=false,cardLayout="UNVERIFIED",
 actualOffers=0,actualAccepts=0,actualDeclines=0,actualTeleports=0,
 currentPricesVerified=false,authenticatedOwnedInventory=false,
 numericSupremeCheckerIdVerified=false,serverAttestation=false,
 serverCompletionProven=false,authorizesTrade=false,authorizesAccept=false,
 mayRecordCompletedTrade=false,mayReportProfit=false,
 maySendDiscordWebhook=false,mayUseForStrategyLearning=false,
 tradeOutcome="UNKNOWN",elapsedSeconds=0
}
local I={running=true,report=R,jobId=tostring(game.JobId)}
E[KEY]=I
local started=os.clock()
local Players=game:GetService("Players")
local LP=Players.LocalPlayer
local PG=LP and LP:FindFirstChildOfClass("PlayerGui")
local target=nil
local function printResult()
 R.elapsedSeconds=math.floor(math.max(0,os.clock()-started))
 local ok,json=pcall(function()return game:GetService("HttpService"):JSONEncode(R)end)
 if ok and type(json)=="string" and #json<2400 then
  local line="[GINGERSCOPE STAGE91 SINGLE REQUEST] "..json
  print(line)
  if type(setclipboard)=="function" then pcall(setclipboard,line) end
 else
  warn("[STAGE91] report unavailable")
 end
end
local function finish(status,reason)
 I.running=false
 R.status=status;R.reason=reason
 printResult()
 return I
end
local function live()
 return I.running and E[KEY]==I and tostring(game.JobId)==I.jobId
    and LP~=nil and LP.Parent==Players
    and LP:FindFirstChildOfClass("PlayerGui")==PG and PG~=nil
    and PG.Parent==LP
end
local function visible(node)
 if not node then return false end
 local c=node
 while c do
  if c:IsA("ScreenGui") and c.Enabled==false then return false end
  if c:IsA("GuiObject") and c.Visible==false then return false end
  c=c.Parent
 end
 return true
end
local function trimName(raw)
 if type(raw)~="string" then return "" end
 return raw:gsub("^%s+",""):gsub("%s+$",""):gsub("^@","")
end
local function blockedUI()
 if not live() then return true,"SESSION_OR_GUI_CHANGED" end
 if E.PDIDDLER_OUTGOING_BUSY_SESSION or E.PDIDDLER_PART4_SESSION
   or E.PDIDDLER_STATUS_OWNER or E.PDIDDLER_OUTGOING_CONTROLLER then
  return true,"OTHER_TRANSACTION_OWNER"
 end
 for _,name in ipairs({"TradeGUI","TradeGUI_Phone"}) do
  local gui=PG:FindFirstChild(name)
  local container=gui and gui:FindFirstChild("Container")
  local trade=container and container:FindFirstChild("Trade")
  if trade and visible(gui) and visible(trade) then
   return true,"TRADE_WINDOW_ALREADY_OPEN"
  end
 end
 -- Only the original verified leaderboard's request frame is accepted;
 -- if other popup layouts exist or we cannot identify them, fail closed.
 local board=nil
 local frame=nil
 for _,gui in ipairs(PG:GetChildren()) do
  if gui:IsA("ScreenGui") and visible(gui) then
   for _,branchName in ipairs({"Game","Lobby"}) do
    local branch=gui:FindFirstChild(branchName)
    local candidate=branch and branch:FindFirstChild("Leaderboard")
    local cont=candidate and candidate:FindFirstChild("Container")
    if cont and visible(candidate) then
     if board and board~=candidate then
      return true,"MULTIPLE_LEADERBOARD_LAYOUTS"
     end
     board=candidate
     local holder=branchName=="Lobby" and cont:FindFirstChild("OverlayMenu") or cont
     frame=holder and holder:FindFirstChild("TradeRequest")
    end
   end
  end
 end
 if not board then return true,"LEADERBOARD_NOT_VISIBLE" end
 if frame and visible(frame) then
  for _,name in ipairs({"SendingRequest","ReceivingRequest"}) do
   local child=frame:FindFirstChild(name)
   if child and visible(child) then
    return true,"REQUEST_ALREADY_PENDING_OR_INCOMING"
   end
  end
 end
 return false,"CLEAR",board,frame
end
-- A Stage90 native client report (not an offline guess) showed one visible
-- Profile/Trade card with the exact username embedded, and NO direct Popup.
-- This resolver is deliberately stricter than the older v18 fallback:
-- one GUI Trade control, a paired Profile control, an exact visible username
-- in the SAME bounded card ancestor and geometrically near the Trade button.
-- Never use a broad leaderboard/root ancestor to bind a player name.
local function exactCard()
 local busy,why,board=blockedUI()
 if busy then return nil,nil,why end
 local popup=board:FindFirstChild("Popup")
 if popup and visible(popup) then
  local container=popup:FindFirstChild("Container")
  local username=container and container:FindFirstChild("Username")
  local action=container and container:FindFirstChild("Action")
  local trade=action and action:FindFirstChild("Trade")
  if not container or not username or not trade
     or not trade:IsA("GuiButton") or not visible(username)
     or not visible(trade) then
   return nil,nil,"DIRECT_POPUP_INCOMPLETE"
  end
  if trimName(username.Text):lower()~=target.Name:lower() then
   return nil,nil,"DIRECT_POPUP_WRONG_TARGET"
  end
  if Players:GetPlayerByUserId(target.UserId)~=target
     or target.Parent~=Players or target==LP then
   return nil,nil,"TARGET_NOT_SAME_LIVE_PLAYER"
  end
  local p,s=trade.AbsolutePosition,trade.AbsoluteSize
  if not p or not s or s.X<=0 or s.Y<=0
     or s.X>1500 or s.Y>900 then
   return nil,nil,"TRADE_BUTTON_GEOMETRY_INVALID"
  end
  return trade,board,"VERIFIED","DIRECT_POPUP"
 end

 local function textOf(n)
  if not n or not (n:IsA("TextLabel") or n:IsA("TextButton")) then
   return ""
  end
  return type(n.Text)=="string" and n.Text or ""
 end
 local function kids(n)
  local ok,d=pcall(function()return n:GetDescendants()end)
  if not ok or type(d)~="table" or #d>12000 then return nil end
  return d
 end
 local function clickable(n)
  local p=n
  for _=1,5 do
   if not p then break end
   if p:IsA("GuiButton") and visible(p) then return p end
   p=p.Parent
  end
  return nil
 end
 local function midpoint(n)
  local ok,x,y,w,h=pcall(function()
   local p,s=n.AbsolutePosition,n.AbsoluteSize
   return p.X+s.X/2,p.Y+s.Y/2,s.X,s.Y
  end)
  if not ok or type(x)~="number" or type(y)~="number"
     or type(w)~="number" or type(h)~="number"
     or x~=x or y~=y or w<=0 or h<=0
     or w>1500 or h>900 then return nil end
  return x,y,w,h
 end
 local all=kids(board)
 if not all then return nil,nil,"ALTERNATIVE_BOARD_SCAN_UNAVAILABLE" end
 local tradeButtons,seen={},{}
 for _,node in ipairs(all) do
  if visible(node) and trimName(textOf(node)):lower()=="trade" then
   local candidate=clickable(node)
   if candidate and not seen[candidate] then
    seen[candidate]=true
    tradeButtons[#tradeButtons+1]=candidate
   end
  end
 end
 if #tradeButtons~=1 then
  return nil,nil,"ALTERNATIVE_TRADE_BUTTON_COUNT_NOT_ONE"
 end
 local trade=tradeButtons[1]
 local tx,ty,tw=midpoint(trade)
 if not tx then return nil,nil,"ALTERNATIVE_TRADE_GEOMETRY_INVALID" end
 local p=trade.Parent
 local matched=false
 -- Require bounded ancestor smaller than the whole leaderboard, with both
 -- Profile and Trade controls and an exact username physically by the button.
 for depth=1,7 do
  if not p or p==board then break end
  local desc=kids(p)
  if not desc then return nil,nil,"ALTERNATIVE_CARD_SCAN_UNAVAILABLE" end
  local hasProfile,hasExactNearby=false,false
  for _,d in ipairs(desc) do
   if visible(d) then
    local value=trimName(textOf(d)):lower()
    if value=="profile" and clickable(d) then hasProfile=true end
    if value==target.Name:lower() and
       (d:IsA("TextLabel") or d:IsA("TextButton")) then
     local cx,cy=midpoint(d)
     if cx and math.abs(cx-tx)<=math.max(170,tw*2.2)
        and ty-cy>=-25 and ty-cy<=185 then
      hasExactNearby=true
     end
    end
   end
  end
  if hasProfile and hasExactNearby then
   matched=true
   break
  end
  p=p.Parent
 end
 if not matched then return nil,nil,"ALTERNATIVE_CARD_IDENTITY_NOT_BOUND" end
 if Players:GetPlayerByUserId(target.UserId)~=target or
    target.Parent~=Players or target==LP then
  return nil,nil,"TARGET_NOT_SAME_LIVE_PLAYER"
 end
 return trade,board,"VERIFIED","ALTERNATIVE_EMBEDDED_CARD"
end

local function noQuote()
 return {version="STAGE91_NO_QUOTE",isFresh=function()return false end,
         liveReady=false}
end
local ROOT="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
local SOURCES={
 scanner={"7a289d62ef3f0be0a299506eb451c57435493be3",
 "pdiddler/presentation/pdiddler3_scanner_MODULE_v6_10_CURRENT_PRESENTATION.lua"},
 view={"a00be9c54825b9b91fcfa394dc11d300fcce3575",
 "pdiddler/presentation/pdiddler3_scanner_view_contact_v1.lua"},
 eligibility={"f1a0492ab5959f31be3544bf04ee8a514e09255f",
 "pdiddler/pdiddler3_outgoing_eligibility_v2_SCANNER_EVIDENCE.lua"},
 feasibility={"f1a0492ab5959f31be3544bf04ee8a514e09255f",
 "pdiddler/new_part4/P3_ELIGIBILITY_NO_LEGACY_PROFIT.lua"}
}
local function getSource(name,...)
 local spec=assert(SOURCES[name],"unreviewed-name")
 assert(live(),"stale-before-source")
 local contents=game:HttpGet(ROOT..spec[1].."/"..spec[2],true)
 assert(live(),"stale-after-source")
 assert(type(contents)=="string" and #contents>500,"source-unavailable")
 local fn,reason=loadstring(contents,"=stage91-"..name)
 assert(fn,reason)
 assert(live(),"stale-before-module-run")
 local module=fn(...)
 assert(type(module)=="table","module-unavailable")
 return module
end
local function run()
 if not live() or not game:IsLoaded() or targetName:lower()==LP.Name:lower() then
  return finish("HELD","GAME_OR_TARGET_UNAVAILABLE")
 end
 -- Roblox username matching is case-insensitive, but only a unique
 -- CURRENT Player object is eligible. Never use DisplayName or fuzzy aliases.
 for _,candidate in ipairs(Players:GetPlayers()) do
  if candidate~=LP and candidate.Parent==Players
     and candidate:IsA("Player") and type(candidate.Name)=="string"
     and candidate.Name:lower()==targetName:lower() then
   if target~=nil then
    return finish("HELD","AMBIGUOUS_CURRENT_USERNAME")
   end
   target=candidate
  end
 end
 if not target or target==LP or
    not target:IsA("Player") or target.UserId==LP.UserId or
    target.Parent~=Players or
    Players:GetPlayerByUserId(target.UserId)~=target then
  return finish("HELD","EXACT_TARGET_NOT_IN_CURRENT_SERVER")
 end
 R.exactTargetClientBound=true
 local safe,why=blockedUI()
 if safe and why~="LEADERBOARD_NOT_VISIBLE" then
  return finish("HELD",why)
 end
 local view=getSource("view")
 local profile=noQuote()
 local strict={reprice=function()return nil,"PRICES_UNVERIFIED" end}
 local scanner=getSource("scanner",profile,strict,view)
 local p3=getSource("feasibility")
 local eligibility=getSource("eligibility")
 assert(type(scanner.getVerificationState)=="function" and
        type(scanner.getOwnInventory)=="function" and
        type(scanner.setOutgoingState)=="function" and
        type(eligibility.new)=="function" and
        type(p3.evaluateContact)=="function","scanner-contract-unavailable")
 local controller=eligibility.new({
  scanner=scanner,feasibility=p3,profile=profile,strict=strict,
  now=os.clock,readOwn=scanner.getOwnInventory,
  context=function()
   local ok3=not select(1,blockedUI())
   return {job=game.JobId,gui=PG,outgoing=nil,session=nil,
    part4Session=nil,transaction=false,phase="STAGE91_CONTACT_ONLY",
    activeTarget=nil,allowed=ok3,reason="ui-or-session-hold"}
  end,
  render=function(player,state,reason)
   if not live() then return false end
   return scanner.setOutgoingState(player,state,reason)
  end
 })
 -- Operator must open exact target card MANUALLY. Never auto-select players.
 local readyAt=os.clock()+25
 local candidate=false
 while live() and os.clock()<readyAt do
  if target.Parent~=Players then return finish("HELD","TARGET_LEFT") end
  local ownOK=controller:refresh(false)
  if ownOK then R.ownContactEvidenceReady=true end
  local assessment=controller:assess(target)
  if ownOK and assessment.state=="reachable" then
   candidate=true
   break
  end
  task.wait(0.25)
 end
 if not live() then return finish("HELD","SESSION_CHANGED") end
 if not candidate then return finish("INCONCLUSIVE","CONTACT_PROOF_NOT_READY") end
 local cardWait=os.clock()+20
 local tradeButton,cardLayout=nil,nil
 while live() and os.clock()<cardWait do
  local btn,_,_,layout=exactCard()
  if btn then tradeButton=btn;cardLayout=layout;break end
  task.wait(0.10)
 end
 if not tradeButton then return finish("INCONCLUSIVE","EXACT_TARGET_CARD_NOT_OPENED") end
 R.visibleCardExactNameMatched=true
 R.cardLayout=cardLayout
 local token,why4=controller:authorize(target)
 if not token then return finish("HELD","CONTACT_AUTHORIZATION_CHANGED") end
 local permitted,why5=controller:prepare(target,token)
 if type(permitted)~="function" then return finish("HELD","CONTACT_PREPARE_FAILED") end
 -- Match the existing reviewed tablet tap convention: account for the
 -- visible Roblox GuiService inset before input dispatch. No speculative
 -- origin/zero-offset fallback when a native layout is unavailable.
 local okInset,inset=pcall(function()
  return game:GetService("GuiService"):GetGuiInset()
 end)
 local insetX,insetY
 local validInset=okInset and inset~=nil and pcall(function()
  insetX,insetY=inset.X,inset.Y
 end)
 if not validInset or type(insetX)~="number" or type(insetY)~="number"
    or insetX~=insetX or insetY~=insetY
    or math.abs(insetX)>1000 or math.abs(insetY)>1000 then
  return finish("HELD","GUI_INSET_UNAVAILABLE")
 end
 local pos,sz=tradeButton.AbsolutePosition,tradeButton.AbsoluteSize
 local x,y=pos.X+sz.X/2+insetX,pos.Y+sz.Y/2+insetY
 -- Input boundary: final player/card/permit validation occurs AFTER we
 -- calculate geometry and immediately BEFORE the ONE physical mouse-down.
 local button,_,_,stillLayout=exactCard()
 if button~=tradeButton or stillLayout~=cardLayout or not permitted() or not live() then
  return finish("HELD","CARD_OR_CONTACT_CHANGED_BEFORE_TAP")
 end
 -- Ownership of this one physical attempt is reserved BEFORE dispatch.
 -- Even if the input API throws, do not retry; the server might have received it.
 R.requestTapCount=1
 R.status="TAP_ATTEMPTED_UNVERIFIED"
 local VIM=game:GetService("VirtualInputManager")
 local pressed=pcall(function()
  VIM:SendMouseButtonEvent(x,y,0,true,game,0)
 end)
 if not pressed then
  return finish("UNCERTAIN","MOUSE_DOWN_UNCERTAIN_NO_RETRY")
 end
 task.wait(0.07)
 local released=pcall(function()
  VIM:SendMouseButtonEvent(x,y,0,false,game,0)
 end)
 if not released then return finish("UNCERTAIN","MOUSE_UP_UNCERTAIN_NO_RETRY") end
 -- One request may be sent. No cancel/decline/accept/offer. Only observe.
 local endAt=os.clock()+8
 while live() and os.clock()<endAt do
  -- Do not use blockedUI here: it correctly blocks *before* the tap when
  -- sending is visible, but after the tap we must observe that very UI.
  for _,gui in ipairs(PG:GetChildren()) do
   if gui:IsA("ScreenGui") and visible(gui) then
    for _,branchName in ipairs({"Game","Lobby"}) do
     local branch=gui:FindFirstChild(branchName)
     local board=branch and branch:FindFirstChild("Leaderboard")
     local cont=board and board:FindFirstChild("Container")
     local holder=branchName=="Lobby" and cont and cont:FindFirstChild("OverlayMenu") or cont
     local frame=holder and holder:FindFirstChild("TradeRequest")
     local sending=frame and frame:FindFirstChild("SendingRequest")
     local name=sending and sending:FindFirstChild("Username")
     if sending and name and visible(sending) and
        trimName(name.Text):lower()==target.Name:lower() then
      R.clientPendingExactTargetObserved=true
     end
    end
   end
  end
  for _,n in ipairs({"TradeGUI","TradeGUI_Phone"}) do
   local g=PG:FindFirstChild(n)
   local c=g and g:FindFirstChild("Container")
   local trade=c and c:FindFirstChild("Trade")
   if trade and visible(g) and visible(trade) then
    R.tradeWindowObserved=true
   end
  end
  task.wait(0.1)
 end
 if not live() then return finish("UNCERTAIN","SESSION_CHANGED_AFTER_TAP") end
 if R.clientPendingExactTargetObserved then
  return finish("CLIENT_PENDING_OBSERVED","NOT_SERVER_AUTHENTICATED")
 end
 if R.tradeWindowObserved then
  return finish("CLIENT_TRADE_WINDOW_OBSERVED","PARTNER_AND_SETTLEMENT_UNVERIFIED")
 end
 return finish("UNCERTAIN","NO_CONFIRMED_REQUEST_UI_NO_RETRY")
end
task.spawn(function()
 local ok,err=xpcall(run,function(e)return tostring(e)end)
 if not ok then
  finish("INCONCLUSIVE","SCRIPT_OR_GUI_FAILURE_NO_AUTO_RETRY")
  warn("[STAGE91] diagnostic stopped; no trade authority")
 end
end)
return I
