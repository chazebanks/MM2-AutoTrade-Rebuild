-- Project Gingerscope: MAIN P3 sends the outgoing trade REQUEST FIRST.
-- Repeated exact ALT trades in ONE supervised session; P3 physical REQUEST
-- initiation is a real client ACTION, not a read-only operation.
-- Humans on ALT accept incoming REQUEST, choose ALT offer, then both humans
-- perform FINAL ACCEPT and optional Claim; MAIN script offers ZERO items.
-- MAIN own-inventory/Stage9 settlement watcher is READ-ONLY. No automated
-- final Accept, OfferItem, Decline, Teleport, webhook or public trading.
-- All failures STOP the whole controller, never merely skip a bad trade.
local E=(type(getgenv)=="function" and getgenv()) or _G
local OWNER="PDIDDLER_MAIN_ALT_MULTITRADE_MANUAL_OWNER"
local USED="PDIDDLER_MAIN_ALT_MULTITRADE_MANUAL_USED_JOB"
local ALT_KEY="PDIDDLER_ACCEPT_DISCOVERY_ALT_NAME"
local PLACE=142823291
-- Private exact-epoch ownership lease. A preexisting P3 session is a
-- collision; OUR newly created guarded P3 session must not self-collide.
local ownedP3Epoch=nil
local function validName(x)
 return type(x)=="string" and #x>=3 and #x<=32 and x:match("^[%w_]+$")~=nil
end
local function conflict()
 for _,k in ipairs({
  "PDIDDLER_SUPERVISED_P3_NATIVE_OWNER",
  "PDIDDLER_PART4_SESSION","PDIDDLER_STAGE119_LASTOFFER_OWNER",
  "PDIDDLER_STAGE119_P3_OWNER","PDIDDLER_STAGE101_IDENTITY_OWNER",
  "PDIDDLER_S2_SHADOW_OWNER","PDIDDLER_S2_KEY_RECON_OWNER",
  "PDIDDLER_S2_MULTIFEATURE_OWNER","PDIDDLER_ACCEPT_CONTROL_DISCOVERY_OWNER",
  "PDIDDLER_SUPERVISED_ONE_ITEM_PILOT",
 }) do if E[k]~=nil then return true end end
 local liveP3Epoch=E.PDIDDLER_OUTGOING_SESSION
 if ownedP3Epoch==nil then
  -- Before we construct P3, ANY preexisting epoch is foreign.
  if liveP3Epoch~=nil then return true end
 elseif type(liveP3Epoch)~="number" or
    liveP3Epoch~=ownedP3Epoch then
  -- Once constructed, only our exact P3 epoch is allowed.
  -- Missing/advanced/replaced owner permanently fails closed.
  return true
 end
 return E.PDIDDLER_AUTOTRADE_ACTIVE==true or
   E.PDIDDLER_PART4_CONTROLLER_ACTIVE==true or
   E.PDIDDLER_OUTGOING_CONTROLLER_ACTIVE==true
end
if game.PlaceId~=PLACE or type(game.JobId)~="string" or
 #game.JobId<8 or #game.JobId>100 or
 not validName(E[ALT_KEY]) or E[OWNER]~=nil or E[USED]==game.JobId or conflict() then
 warn("[MAIN ALT MULTI] original MM2 fresh job, ALT account, no other scripts required")
 return nil
end
local Players=game:GetService("Players")
local LP=Players and Players.LocalPlayer
local PG=LP and LP:FindFirstChildOfClass("PlayerGui")
local World=game:GetService("Workspace")
local Run=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local HTTP=game:GetService("HttpService")
local ALTNAME=E[ALT_KEY]
local ALT=Players and Players:FindFirstChild(ALTNAME)
if not LP or not PG or not ALT or ALT==LP or
 ALT.Name~=ALTNAME or ALT.Parent~=Players or
 Players:GetPlayerByUserId(ALT.UserId)~=ALT or
 not World or not World.CurrentCamera or not Run or
 not Run.Heartbeat or not RS or not HTTP then
 warn("[MAIN ALT MULTI] exact ALT account and MAIN client services required")
 return nil
end
local MAINID=LP.UserId
local ALTID=ALT.UserId
local job=game.JobId
local function immutable(rev,path)
 local u="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"..
    rev.."/pdiddler/"..path
 local ok,s=pcall(function()return game:HttpGet(u)end)
 if not ok or type(s)~="string" or #s<150 or #s>85000 then return nil end
 local compile=loadstring or load
 if type(compile)~="function" then return nil end
 local success,obj=pcall(function()return assert(compile(s))()end)
 if success and type(obj)=="table" then return obj end
 return nil
end
local core=immutable("553b7e44245c5ed36aa3f65aea335953ec1fed5f",
  "supervised/main_alt_manual_multitrade_delta_core.lua")
local stage9=immutable("1971b93d324f0275e6a9affb472ac3e804439ed8",
  "new_part4/p4_native_observer.lua")
local contract=immutable("1971b93d324f0275e6a9affb472ac3e804439ed8",
  "new_part4/p4_observer_contract.lua")
local geometry=immutable("5b8ee35d7f281c23d9c2181abd97a063e59a0660",
  "new_part4/stage100_screen_prompt_overlay.lua")
local outgoingModule=immutable("1c874cdbc5e85418360148fbdf33fa17534cd1ad",
 "supervised/pdiddler3_exact_alt_outbound_requeue.lua")
local scannerModule=immutable("2036ae5bd937620f21d46600f99550a1b233a654",
 "pdiddler3_scanner_MODULE_v6_5_PART4_STATUS_BRIDGE.lua")
if not core or type(core.new)~="function" or
 not stage9 or type(stage9.new)~="function" or
 type(stage9.capture)~="function" or
 not contract or type(contract.normalize)~="function" or
 type(contract.parseQuantity)~="function" or
 not geometry or type(geometry.choose)~="function" or
 not outgoingModule or type(outgoingModule.run)~="function" or
 not scannerModule or type(scannerModule.getWhitelist)~="function" or
 type(scannerModule.isWhitelisted)~="function" or
 type(scannerModule.getRecord)~="function" then
 warn("[MAIN ALT MULTI] pinned module checks",
  type(core),type(stage9),type(contract),type(geometry),
  type(outgoingModule),type(scannerModule),
  type(scannerModule and scannerModule.getRecord),
  type(scannerModule and scannerModule.getWhitelist),
  type(scannerModule and scannerModule.isWhitelisted))
 warn("[MAIN ALT MULTI] pinned original modules unavailable; nothing started")
 return nil
end
local remotes=RS:FindFirstChild("Remotes")
local inventory=remotes and remotes:FindFirstChild("Inventory")
local rf=inventory and inventory:FindFirstChild("GetProfileData")
local database=RS:FindFirstChild("Database")
local mod=database and database:FindFirstChild("Sync")
if not rf or not rf:IsA("RemoteFunction") or
 not mod or not mod:IsA("ModuleScript") then
 warn("[MAIN ALT MULTI] read-only inventory remote or current game catalog missing")
 return nil
end
local syncOK,sync=pcall(require,mod)
if not syncOK or type(sync)~="table" or type(sync.Weapons)~="table" then
 warn("[MAIN ALT MULTI] current original-MM2 item metadata unavailable")
 return nil
end
local function norm(s)
 if type(s)~="string" then return nil end
 return s:lower():gsub("^%s+",""):gsub("%s+$",""):gsub("%s+"," ")
end
local known={}
local candidateByName={}
local inspected=0
local catalogOK=true
for _,section in ipairs({"Weapons","Item"}) do
 local source=sync[section]
 if type(source)=="table" then
  for id,m in pairs(source) do
   inspected+=1
   if inspected>12000 then catalogOK=false;break end
   if type(id)=="string" and id:match("^[%w_]+$") and
       type(m)=="table" and type(m.ItemName or m.Name)=="string" then
    local label=norm(m.ItemName or m.Name)
    local chroma=m.Chroma==true
    if chroma and label:sub(1,7)=="chroma " then label=label:sub(8) end
    local kind=norm(m.ItemType)
    local rarity=norm(m.Rarity)
    local eligible=(kind=="gun" or kind=="knife") and
      (rarity=="godly" or rarity=="ancient") and
      m.Tradable~=false and m.CanTrade~=false and
      m.Untradable~=true and m.NonTradable~=true and
      m.EvoBaseID==nil and m.EvoIndex==nil
    local rec={name=label,chroma=chroma,eligible=eligible}
    if known[id] and (known[id].name~=label or
       known[id].chroma~=chroma or known[id].eligible~=eligible) then
      catalogOK=false;break
    end
    if not known[id] then
     known[id]=rec
     local group=label.."@"..tostring(chroma)
     candidateByName[group]=candidateByName[group] or {}
     table.insert(candidateByName[group],id)
    end
   end
  end
 end
 if not catalogOK then break end
end
if not catalogOK then
 warn("[MAIN ALT MULTI] conflicting or oversized game catalog; no test")
 return nil
end
-- Original P3 scanner, restricted at ALL request-queue entry points
-- to the one client-verified exact ALT Player object / UserId.
local scanner=setmetatable({},{__index=scannerModule})
function scanner.isWhitelisted(uid)
 if uid~=ALTID then return false end
 local ok,v=pcall(scannerModule.isWhitelisted,uid)
 return ok and v==true
end
function scanner.getRecord(uid)
 if uid~=ALTID or not scanner.isWhitelisted(uid) then return nil end
 local ok,v=pcall(scannerModule.getRecord,uid)
 return ok and type(v)=="table" and v.player==ALT and
   v.state=="whitelist" and v or nil
end
function scanner.getWhitelist()
 if ALT.Parent~=Players or Players:GetPlayerByUserId(ALTID)~=ALT then return {} end
 return scanner.getRecord(ALTID) and {ALT} or {}
end
local function suppressScannerUI()
 for _,parent in ipairs({PG,game:GetService("CoreGui")}) do
  local gui=parent and parent:FindFirstChild("MM2EligibilityScannerT41")
  if gui and gui:IsA("ScreenGui") then gui.Enabled=false end
 end
end
suppressScannerUI()
local function exactPair()
 return game.PlaceId==PLACE and game.JobId==job and
  Players.LocalPlayer==LP and LP.UserId==MAINID and
  LP:FindFirstChildOfClass("PlayerGui")==PG and
  ALT.Parent==Players and ALT.Name==ALTNAME and ALT.UserId==ALTID and
  Players:FindFirstChild(ALTNAME)==ALT and
  Players:GetPlayerByUserId(ALTID)==ALT and not conflict()
end
local function visible(n,root)
 local hops=0
 while n do
  hops+=1
  if hops>22 then return false end
  if n:IsA("GuiObject") and n.Visible~=true then return false end
  if n:IsA("ScreenGui") and n.Enabled~=true then return false end
  if n==root then return true end
  n=n.Parent
 end
 return false
end
local function trade()
 local matches={}
 for _,name in ipairs({"TradeGUI_Phone","TradeGUI"}) do
  local screen=PG:FindFirstChild(name)
  local frame=screen and screen:FindFirstChild("Container")
  local root=frame and frame:FindFirstChild("Trade")
  if screen and frame and root and visible(root,PG) then
   matches[#matches+1]=root
  end
 end
 if #matches>1 then return nil,"MULTIPLE_LIVE_TRADE_ROOTS" end
 return matches[1],nil
end
local function partnerLabel(root)
 if not root then return false end
 local their=root:FindFirstChild("TheirOffer")
 local label=their and their:FindFirstChild("Username")
 if not label or not (label:IsA("TextLabel") or label:IsA("TextButton")) then
  return false
 end
 local s=label.Text
 if type(s)~="string" then return false end
 s=s:match("^%s*%((.-)%)%s*$") or s
 s=s:gsub("^@",""):gsub("^%s+",""):gsub("%s+$","")
 return s:lower()==ALTNAME:lower()
end
local function fromSlot(slot)
 local labelNode=slot:FindFirstChild("ItemName")
 local textNode=labelNode and labelNode:FindFirstChild("Label")
 local amountParent=slot:FindFirstChild("Container")
 local amountNode=amountParent and amountParent:FindFirstChild("Amount")
 local chromaParent=slot:FindFirstChild("Tags")
 local chromaNode=chromaParent and chromaParent:FindFirstChild("Chroma")
 if not textNode or not textNode:IsA("TextLabel") or
   not amountNode or not amountNode:IsA("TextLabel") then return nil end
 local label=norm(textNode.Text)
 local q=contract.parseQuantity(amountNode.Text)
 if not label or not q or q>10000 then return nil end
 local chroma=chromaNode~=nil and visible(chromaNode,slot) or false
 if chroma and label:sub(1,7)=="chroma " then label=label:sub(8) end
 local group=label.."@"..tostring(chroma)
 local choices=candidateByName[group]
 if type(choices)~="table" or #choices~=1 then return nil end
 local id=choices[1];local meta=known[id]
 if not meta or not meta.eligible then return nil end
 local boundId=nil
 for _,k in ipairs({"ItemId","ItemID","ID","WeaponId","WeaponID"}) do
  local v=slot:GetAttribute(k)
  if v~=nil and tostring(v)~="" then
   if boundId and boundId~=tostring(v) then return nil end
   boundId=tostring(v)
  end
 end
 if boundId and boundId~=id then return nil end
 return id,q
end
local function theirOffer(root)
 local side=root:FindFirstChild("TheirOffer")
 local container=side and side:FindFirstChild("Container")
 if not side or not container then return nil,"THEIR_OFFER_GUI_MISSING" end
 -- MM2 has EXACTLY four physical slots, never a fifth.
 -- A fifth node would be hostile/corrupted client data, not a game slot.
 for i=5,8 do
  if container:FindFirstChild("NewItem"..i) then
   return nil,"FABRICATED_EXTRA_ALT_SLOT_NODE"
  end
 end
 local rows={}
 for i=1,4 do
  local slot=container:FindFirstChild("NewItem"..i)
  if slot and visible(slot,root) then
   local id,qty=fromSlot(slot)
   if not id then return nil,"ALT_ITEM_ID_QUANTITY_OR_ELIGIBILITY_AMBIGUOUS" end
   rows[#rows+1]={key=id,qty=qty,slot=i,category="Weapons"}
  end
 end
 return rows,nil
end
local main,err=core.new({
 placeId=PLACE,mainUserId=MAINID,altUserId=ALTID,
 mainName=LP.Name,altName=ALTNAME,jobId=job,
 operatorScope="ALL_MAIN_ALT_TRADES_IN_THIS_JOB",
 publicTradingEnabled=false,scriptMayFinalAccept=false,
})
if not main then warn("[MAIN ALT MULTI] session policy rejected");return nil end
local state={active=true,armed=false,core=main,job=job,
  root=nil,observer=nil,pending=nil,nextReadAt=0,
  requests=0,lastRead=0,readErr=nil,view=nil,phase="PREPARED",
  final=nil,heartbeat=nil,outgoing=nil,awaitingRequeue=false,unattributedAt=nil}
E[OWNER]=state
E[USED]=job
-- Reviewed original P3 request mechanism: default CLOSED until ARM.
-- Client-only delta proof is rechecked before each exact-ALT requeue.
local okOutgoing,outgoing=pcall(outgoingModule.run,scanner,{
 requiresExplicitStart=true,exactAltMultiTrade=true,
 exactAltUserId=ALTID,noIncomingAutoDecline=true,
 readyCheck=function()
  return state.active and state.armed and state.pending==nil and
    main.status().phase=="WAIT_OPEN" and exactPair()
 end,
 verifiedClientDeltaCount=function()
  local report=main.status()
  if not state.awaitingRequeue or report.phase~="WAIT_OPEN" then return nil end
  return report.corroboratedClientDeltas
 end,
})
if not okOutgoing or type(outgoing)~="table" or
 type(outgoing.arm)~="function" or type(outgoing.isArmed)~="function" or
 type(outgoing.isPaused)~="function" or type(outgoing.fatalStatus)~="function" or
 type(outgoing.requeueVerifiedExactAlt)~="function" or
 type(outgoing.stop)~="function" or
 type(outgoing.session)~="number" or
 outgoing.session~=math.floor(outgoing.session) or outgoing.session<1 or
 E.PDIDDLER_OUTGOING_SESSION~=outgoing.session then
 if type(outgoing)=="table" and type(outgoing.stop)=="function" then
  pcall(outgoing.stop)
 end
 E[OWNER]=nil
 warn("[MAIN ALT MULTI] exact owned P3 epoch could not be bound")
 return nil
end
-- This is not a wildcard bypass: record the ONE epoch created by this
-- exact guarded P3 instance, and reject any replacement at every tick/ARM.
ownedP3Epoch=outgoing.session
state.outgoing=outgoing
local UI={}
local built=pcall(function()
 UI.screen=Instance.new("ScreenGui")
 UI.screen.Name="PDIDDLER_MAIN_ALT_MULTITRADE_MANUAL"
 UI.screen.IgnoreGuiInset=true;UI.screen.ResetOnSpawn=false
 UI.screen.DisplayOrder=160;UI.screen.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
 UI.screen.Parent=PG
 UI.panel=Instance.new("Frame")
 UI.panel.Name="MultiTradeInstructions";UI.panel.Active=false
 UI.panel.BackgroundColor3=Color3.fromRGB(31,22,44)
 UI.panel.BorderSizePixel=0;UI.panel.Visible=false
 UI.panel.Parent=UI.screen
 local corner=Instance.new("UICorner")
 corner.CornerRadius=UDim.new(0,9);corner.Parent=UI.panel
 local stroke=Instance.new("UIStroke")
 stroke.Color=Color3.fromRGB(177,128,239);stroke.Thickness=1;stroke.Parent=UI.panel
 local function txt(name,y,height,size)
  local o=Instance.new("TextLabel")
  o.Name=name;o.BackgroundTransparency=1
  o.TextColor3=Color3.fromRGB(255,245,255)
  o.Font=Enum.Font.GothamBold
  o.TextXAlignment=Enum.TextXAlignment.Left
  o.TextWrapped=true;o.TextSize=size
  o.Position=UDim2.fromOffset(9,y)
  o.Size=UDim2.fromOffset(304,height);o.Parent=UI.panel
  return o
 end
 UI.title=txt("TradeNumber",5,26,14)
 UI.body=txt("HumanSteps",33,80,12)
 UI.warning=txt("ProofDisclaimer",114,17,10)
 UI.warning.Text="HUMAN FINAL ACCEPT ONLY • CLIENT DELTA ≠ SERVER PROOF"
 local function button(name,value,x)
  local b=Instance.new("TextButton")
  b.Name=name;b.Text=value;b.TextSize=12;b.Active=true
  b.TextColor3=Color3.fromRGB(255,255,255)
  b.BackgroundColor3=Color3.fromRGB(95,51,136)
  b.Position=UDim2.fromOffset(x,136)
  b.Size=UDim2.fromOffset(137,28)
  b.Parent=UI.panel
  return b
 end
 UI.arm=button("ArmMultipleManualTrades","ARM MULTI TRADES",10)
 UI.stop=button("StopCopy", "STOP / COPY",168)
end)
if not built then
 E[OWNER]=nil;state.active=false
 if UI.screen then pcall(function()UI.screen:Destroy()end)end
 warn("[MAIN ALT MULTI] GUI failed closed")
 return nil
end
local function display(message)
 if state.active then
  UI.title.Text="MAIN + ALT • TRADE "..tostring((main.status().tradeCyclesStarted or 0)+
    (main.status().phase=="READY" and 1 or 0))
  UI.body.Text=message
 end
end
local function UIarea(root)
 local camera=World.CurrentCamera
 if not camera or not camera.ViewportSize then return false end
 local v=camera.ViewportSize
 local unsafe=nil
 if root then
  local p=root.AbsolutePosition
  local d=root.AbsoluteSize
  if not p or not d then return false end
  unsafe={x=p.X,y=p.Y,w=d.X,h=d.Y}
 end
 local rect=geometry.choose({x=v.X,y=v.Y},unsafe,{w=322,h=174})
 if not rect then UI.panel.Visible=false;return false end
 UI.panel.Position=UDim2.fromOffset(rect.x,rect.y)
 UI.panel.Size=UDim2.fromOffset(rect.w,rect.h)
 UI.panel.Visible=true
 return true
end
local function report()
 local o=state.final or main.status()
 -- The pure settlement core is read-only, BUT this wrapper actually sends
 -- outbound P3 trade REQUEST clicks. Never mislabel whole test read-only.
 -- S.sent counts pending-UI-confirmed requests; do not call it server proof.
 o.readOnly=false
 o.clientInventoryObserverReadOnly=true
 o.mainAutomaticallyInitiatesTradeRequests=true
 o.automaticFinalAcceptEnabled=false
 o.publicRequestSendingEnabled=false
 o.confirmedPendingOutboundRequestCount=
   (state.outgoing and type(state.outgoing.state.sent)=="number" and
    state.outgoing.state.sent>=0 and state.outgoing.state.sent) or 0
 -- The user sees only safe aggregate counters; no account or weapon IDs.
 return o
end
local function copy()
 local ok,s=pcall(function()return HTTP:JSONEncode(report())end)
 if not ok or type(s)~="string" then return end
 E.PDIDDLER_MAIN_ALT_MULTITRADE_LAST_SAFE_JSON=s
 print("[MAIN ALT MULTITRADE SAFE RESULT] "..s)
 local clipboard=type(setclipboard)=="function" and setclipboard
  or type(toclipboard)=="function" and toclipboard
 if clipboard then pcall(clipboard,s) end
end
local function terminate(why)
 if not state.active then return end
 state.final=main.stop()
 if why then
  -- preserve exact stop reason without copying any private state.
  state.final.reason=why
 end
 state.active=false
 if state.heartbeat then pcall(function()state.heartbeat:Disconnect()end)end
 if state.outgoing then pcall(state.outgoing.stop) end
 state.pending=nil
 E[OWNER]=nil
 UI.arm.Active=false;UI.arm.Visible=false
 UI.title.Text="MULTI TRADE WITNESS STOPPED"
 UI.body.Text="No script final Accept was attempted. Tap STOP / COPY; submit sanitized counts. No automatic retry."
 UI.stop.Active=true;UI.stop.Visible=true
end
local function stop(reason)
 if state.active then terminate(reason) end
end
local function ctx(now,root,snap,offers)
 return {placeId=game.PlaceId,jobId=game.JobId,
  mainUserId=LP.UserId,mainName=LP.Name,
  altUserId=ALT.UserId,altName=ALT.Name,
  partnerUserId=ALTID,partnerName=ALTNAME,
  exactPlayerObjects=exactPair(),
  exactTradePartnerLabel=root and partnerLabel(root) or false,
  onlyTradeRoot=true,uiSafe=UIarea(root),
  competingController=conflict(),now=now,
  tradeOpen=root~=nil,tradeRoot=root,
  ownOffer={},altOffer=offers or {},
  mainAccepted=snap and snap.ourAccepted,
  altAccepted=snap and snap.theirAccepted}
end
local function issueRead(kind,now)
 if state.pending then return end
 if state.requests>=1000 then stop("TOTAL_READ_ATTEMPT_SAFETY_CAP");return end
 state.requests+=1
 local pending={kind=kind,started=now,done=false,success=false,data=nil}
 state.pending=pending;state.lastRead=now
 task.spawn(function()
  pending.success,pending.data=pcall(function()return rf:InvokeServer()end)
  pending.done=true
 end)
end
local function withRead(now,root)
 local p=state.pending
 if not p then return end
 if root~=nil or not exactPair() then stop("TRADE_OPEN_OR_ACCOUNT_CHANGED_DURING_CLIENT_PROFILE_READ");return end
 if now-p.started>6 then stop("CLIENT_PROFILE_RPC_TIMEOUT");return end
 if not p.done then return end
 state.pending=nil
 if not p.success or type(p.data)~="table" then
  stop("READ_ONLY_CLIENT_PROFILE_RPC_FAILED");return
 end
 local c=ctx(now,nil,nil,nil)
 local ok,res
 if p.kind=="BASELINE" then
  ok,res=pcall(main.begin,p.data,c)
 elseif p.kind=="POST" then
  ok,res=pcall(main.post,p.data,c)
 else stop("PROFILE_READ_PHASE_INVALID");return end
 p.data=nil
 if not ok or type(res)~="table" then stop("PURE_MULTITRADE_CORE_EXCEPTION");return end
 if res.status=="STOPPED" then stop(res.reason);return end
 if res.status=="READY_FOR_NEXT_MAIN_ALT_TRADE" then
  state.root=nil;state.observer=nil;state.phase="NEXT_TRADE"
  state.awaitingRequeue=true
  display("Delta matched; MAIN captures fresh baseline, THEN requeues ALT to send again.")
 elseif p.kind=="BASELINE" then
  state.phase="TRADE"
  if state.awaitingRequeue then
   local okRequeue,allowed=pcall(state.outgoing.requeueVerifiedExactAlt)
   if not okRequeue or allowed~=true then
    stop("EXACT_ALT_OUTBOUND_REQUEUE_NOT_PROVEN");return
   end
   state.awaitingRequeue=false
  elseif not state.outgoing.isArmed() then
   local okArm,allowed=pcall(state.outgoing.arm)
   if not okArm or allowed~=true then
    stop("MAIN_OUTBOUND_REQUEST_ARM_REFUSED");return
   end
  end
  display("MAIN P3 sends the trade REQUEST first. ALT accepts REQUEST. No MAIN outgoing items.")
 else
  state.phase="VERIFY"
  display("Awaiting Claim/client inventory update. Do not start another trade yet.")
 end
end
local function captureTrade(root)
 if state.root and state.root~=root then return nil,"TRADE_ROOT_CHANGED" end
 if not state.observer then
  local ok,h=pcall(stage9.new,{game=game,players=Players,
    root=root,session="MAIN_ALT_MULTITRADE_LOCAL_UI",
    jobId=job,partnerUserId=ALTID,localUserId=MAINID,
    contract=contract,marketFresh=function()return false end})
  if not ok or type(h)~="table" then
   return nil,"PINNED_STAGE9_OBSERVER_FAILED"
  end
  state.root=root;state.observer=h
 end
 local ok,ob,diag=pcall(stage9.capture,state.observer)
 if not ok or type(ob)~="table" or type(diag)~="table" or
    ob.tradeOpen~=true or diag.authorizesAccept~=false or
    diag.authorizesTrade~=false then return nil,"ORIGINAL_STAGE9_CAPTURE_INVALID" end
 if type(ob.ourSlots)~="number" or type(ob.theirSlots)~="number" or
    ob.ourSlots~=0 or ob.theirSlots>4 or
    type(ob.ourAccepted)~="boolean" or
    type(ob.theirAccepted)~="boolean" then return nil,"STAGE9_SLOTS_OR_ACCEPT_INDICATORS_UNKNOWN" end
 local rows,why=theirOffer(root)
 if not rows then return nil,why end
 if #rows~=ob.theirSlots then return nil,"INDEPENDENT_ALT_SLOT_COUNT_MISMATCH" end
 return {ourAccepted=ob.ourAccepted,theirAccepted=ob.theirAccepted},rows
end
local function tick()
 if not state.active or not state.armed then return end
 if conflict() then stop("OWNED_P3_EPOCH_OR_CONTROLLER_CHANGED");return end
 if not exactPair() or UI.screen.Parent~=PG or
    not World.CurrentCamera then stop("PAIR_OWNER_UI_OR_JOB_CHANGED");return end
 suppressScannerUI()
 if state.outgoing.fatalStatus() then
  stop("MAIN_P3_OUTBOUND_FATAL_CONTEXT");return
 end
 local outcome=state.outgoing.state.processed[ALTID]
 if outcome~=nil and outcome~="trade-open" then
  stop("MAIN_P3_OUTBOUND_FAILED_OR_NOT_ACCEPTED");return
 end
 local now=os.clock()
 local root,reason=trade()
 if reason then stop(reason);return end
 if not UIarea(root) then stop("NO_SAFE_OVERLAY_SPACE");return end
 if state.pending then withRead(now,root);return end
 local before=main.status()
 if before.phase=="READY" then
  if root then stop("NEW_TRADE_BEFORE_OWN_INVENTORY_BASELINE");return end
  if now-state.lastRead>=0.35 then
   issueRead("BASELINE",now)
  end
  return
 end
 if before.phase=="VERIFY_DELTA" then
  if root then stop("NEW_TRADE_BEFORE_PREVIOUS_DELTA_VERIFIED");return end
  if now-state.lastRead>=0.65 then issueRead("POST",now) end
  return
 end
 local snap=nil;local rows={}
 if root then
  if state.outgoing.state.processed[ALTID]~="trade-open"
     or state.outgoing.isPaused()~=true then
   state.unattributedAt=state.unattributedAt or now
   if now-state.unattributedAt>2.5 then
    stop("TRADE_OPEN_WITHOUT_MAIN_P3_PENDING_PROOF")
   end
   return
  end
  state.unattributedAt=nil
  if not partnerLabel(root) then stop("TRADE_PARTNER_LABEL_CHANGED_OR_INCORRECT");return end
  local value,items=captureTrade(root)
  if not value then stop(items);return end
  snap=value;rows=items
 end
 local c=ctx(now,root,snap,rows)
 local worked,res=pcall(main.observe,c)
 if not worked or type(res)~="table" then stop("PURE_MULTITRADE_OBSERVER_EXCEPTION");return end
 if res.status=="STOPPED" then stop(res.reason);return end
 if res.status=="WAIT_ALT" then
  display("ALT offer EMPTY witnessed. ALT may add 1–4 distinct weapons (copies stack). MAIN offers NOTHING.")
 elseif res.status=="STABILIZING" then
  display("Do NOT Accept yet. Watching unchanged ALT items and exact quantities.")
 elseif res.status=="WAIT_MANUAL_ACCEPT" then
  display("ALT: press final ACCEPT manually FIRST. MAIN: wait for confirmation in this purple panel.")
 elseif res.status=="WAIT_CLOSE" then
  display("ALT Accept observed. MAIN: manually press FINAL ACCEPT. If Claim appears, manually Claim.")
 elseif res.status=="VERIFY_DELTA" then
  state.phase="VERIFY"
  display("Window closed. Wait for two matching MAIN client inventory reads. Claim manually if prompted.")
 elseif res.status=="WAIT_OPEN" then
  display("MAIN P3 sends request to exact ALT. ALT accepts request; neither final Accept yet.")
 end
end
UI.arm.Activated:Connect(function()
 if not state.active or state.armed then return end
 -- Report ownership, exact pair and geometry failures independently.
 -- Neither a valid UI nor matching ALT can override a stolen P3 epoch.
 if E.PDIDDLER_OUTGOING_SESSION~=ownedP3Epoch then
  stop("PREARM_OWNED_P3_EPOCH_CHANGED");return
 end
 if conflict() then stop("PREARM_COMPETING_CONTROLLER");return end
 if not exactPair() then stop("PREARM_EXACT_ALT_PAIR_CHANGED");return end
 if not UIarea(nil) then stop("PREARM_VIEWPORT_UNSAFE");return end
 state.armed=true
 UI.arm.Visible=false;UI.arm.Active=false
 state.lastRead=0
 display("Capturing fresh MAIN baseline. MAIN P3 will initiate request; ALT waits.")
end)
UI.stop.Activated:Connect(function()
 if state.active then terminate("OPERATOR_ENDED_MULTI_TRADE_SESSION") end
 copy()
 pcall(function()UI.screen:Destroy()end)
end)
if not UIarea(nil) then
 terminate("UNSAFE_INITIAL_VIEWPORT")
 warn("[MAIN ALT MULTI] no UI space; no test")
 return nil
end
UI.title.Text="MAIN–ALT • MULTIPLE MANUAL TRADES"
UI.body.Text="Press ARM once. MAIN automatically SENDS each exact ALT request. ALT accepts request; both final Accept manually. Errors stop ALL."
UI.arm.Visible=true;UI.arm.Active=true;UI.stop.Visible=true
state.heartbeat=Run.Heartbeat:Connect(function()
 local ok=pcall(tick)
 if not ok then stop("UNEXPECTED_NATIVE_MULTITRADE_WITNESS_EXCEPTION") end
end)
print("[MAIN ALT MULTI] MAIN auto-sends ALT requests; final Accept remains manual")
return {status=function()return report()end,stop=function()
 terminate("OPERATOR_ENDED_MULTI_TRADE_SESSION")
 return report()
end}
