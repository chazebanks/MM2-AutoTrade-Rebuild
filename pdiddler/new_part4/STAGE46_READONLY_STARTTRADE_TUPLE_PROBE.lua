-- Stage46: ONE passive TWO-ARGUMENT StartTrade table/name-hypothesis census.
-- NO outgoing remotes, item mutations, final Accept, inventory reads or webhook.
-- Native event timing/player references DO NOT authenticate trade session/cause.
local E=(getgenv and getgenv()) or _G
local KEY="PDIDDLER_STAGE46_STARTTRADE_TUPLE"
local OWNERS={KEY,"PDIDDLER_STAGE45_STARTTRADE_TYPES","PDIDDLER_STAGE44_BATWING_MANUAL_ADD_REMOVE",
 "PDIDDLER_STAGE39_BATWING_LITERAL_PRESENCE",
 "PDIDDLER_DIRECT_KEY_OFFER_CORRELATION","PDIDDLER_DIRECT_KEY_UPDATE_SHAPE",
 "PDIDDLER_STAGE36_IMAGE_RELATION","PDIDDLER_STAGE36_ICON_CATALOG_AUDIT",
 "PDIDDLER_STAGE36_EXACT_REFERENCE","PDIDDLER_STAGE36_EXACT_REFERENCE_PROBE",
 "PDIDDLER_STAGE36_EXACT_IDENTITY","PDIDDLER_STAGE35_SLOT_METADATA_CENSUS",
 "PDIDDLER_STAGE34_OFFER_INVENTORY_PROBE",
 "PDIDDLER_STAGE33_TRANSPORT_CENSUS","PDIDDLER_STAGE32_RESULT_CORRELATION_PROBE",
 "PDIDDLER_STAGE29_POSTCLOSE_PROBE","PDIDDLER_STAGE30_PASSIVE_SIGNALS",
 "PDIDDLER_STAGE28_PASSIVE_ACCEPT_PROBE","PDIDDLER_STAGE27_NATIVE_LAB",
 "PDIDDLER_STAGE25_SCANNER_ONLY","PDIDDLER_GINGERSCOPE_REPLACEMENT_PREVIEW",
 "PDIDDLER_OUTGOING_SESSION","PDIDDLER_PART4_SESSION",
 "PDIDDLER_PART4_CONTROLLER","PDIDDLER_PART5_CONTROLLER",
 "PDIDDLER_OUTGOING_CONTROLLER","PDIDDLER_HOPPING_SESSION",
 "PDIDDLER_INTEGRATION_V15_8_VALUE_FIRST",
 "PDIDDLER_INTEGRATION_V15_7_INVENTORY_GROWTH",
 "PDIDDLER_INTEGRATION_V15_6_IMMEDIATE_SAFETY"}
if game.PlaceId~=142823291 then warn("[STAGE46] wrong MM2 place");return end
for _,owner in ipairs(OWNERS)do
 if E[owner]~=nil then warn("[STAGE46] competing session owner; rejoin");return end
end
local players=game:GetService("Players")
local me=players.LocalPlayer
if not me then warn("[STAGE46] local player unavailable");return end
local job=game.JobId
local S={phase="LOADING_PASSIVE",finished=false,readOnly=true,
 authorizesTrade=false,authorizesAccept=false,
 mayRecordCompletedTrade=false,mayReportProfit=false}
E[KEY]=S
local ROOT="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
local CORE_PIN="6118cd280991a257d6ad89b42c4e4aea61b33f4e"
local BASE="35ec2d9a47048910a464a2ef6eb9b9f52ae306b1"
local function source(pin,name)
 local body=game:HttpGet(ROOT..pin.."/pdiddler/new_part4/"..name..".lua",true)
 assert(type(body)=="string" and #body>100,"source missing")
 local fn=assert(loadstring(body,"="..name))
 local t=fn();assert(type(t)=="table","source not a module")
 return t
end
local inspector,observerCore,contract
local loaded=pcall(function()
 inspector=source(CORE_PIN,"p4_stage46_starttrade_tuple_semantics")
 observerCore=source(BASE,"p4_native_observer")
 contract=source(BASE,"p4_observer_contract")
 assert(type(inspector.inspect)=="function" and type(observerCore.new)=="function"
  and type(observerCore.capture)=="function" and type(contract.normalize)=="function")
end)
local connection,connections,pendingConnect,attached,disconnected=nil,{},0,0,0
local cleanupComplete=true
local finishedReport=false
local seen,receiptAt,privatePack=0,nil,nil
local activeRoot,activePartner,activeLabel,activeRemote=nil,nil,nil,nil
local eventBeforeVisibleGui=nil
local callbackGuiMode="NOT_OBSERVED"
-- Private references and label text never leave this diagnostic closure.
local receiptRoot,receiptPartner,receiptLabel,receiptLabelText=nil,nil,nil,nil
local clockLast=nil
local function clock()
 local t=os.clock()
 if type(t)~="number" or t~=t or t<0 or t==math.huge or t==-math.huge
   or (clockLast and t<clockLast) then error("bad clock",0)end
 clockLast=t;return t
end
local function safeStatus()
 return {schema="gingerscope-stage46-starttrade-tuple-semantic-census-v1",
  status="INCOMPLETE",reason="NOT_AUTHENTICATED",readOnly=true,
  tradeOutcome="UNKNOWN",hasAuthenticatedSessionIdentifier=false,
  sessionIdProven=false,eventSessionAssociationProven=false,
  causalAttributionProven=false,serverAttestation=false,
  serverCompletionProven=false,ownerSideSlotBound=false,
  rawItemIdConfirmed=false,exactWeaponIdentityConfirmed=false,
  rawKeyPresentConfirmed=false,authorizesTrade=false,
  authorizesAccept=false,mayRecordCompletedTrade=false,mayReportProfit=false}
end
local reason,report="NOT_STARTED",nil
local function disconnect(c)
 local ok=pcall(function()c:Disconnect()end)
 if ok then disconnected=disconnected+1 else cleanupComplete=false end
end
local function publish()
 if not S.finished or pendingConnect~=0 or finishedReport then return end
 finishedReport=true
 local r=report or safeStatus()
 r.stopReason=cleanupComplete and reason or "LISTENER_CLEANUP_INCOMPLETE"
 r.eventName="StartTrade"
 r.receiptCount=seen
 r.listenerCount=attached;r.listenersDisconnected=disconnected
 r.cleanupComplete=cleanupComplete
 r.eventBeforeVisibleGui=eventBeforeVisibleGui
 r.callbackGuiMode=callbackGuiMode
 r.clientWindowContextStable=(reason=="ONE_START_TRADE_TUPLE_CLASSIFIED_CLIENT_ONLY")
 r.clientOnly=true
 -- Both the core and the fallback report have zero authority. Explicitly pin
 -- the published zero-authority contract regardless of inspector behavior.
 for _,flag in ipairs({"hasAuthenticatedSessionIdentifier","sessionIdProven",
  "eventSessionAssociationProven","causalAttributionProven","serverAttestation",
  "serverCompletionProven","ownerSideSlotBound","rawItemIdConfirmed",
  "exactWeaponIdentityConfirmed","rawKeyPresentConfirmed",
  "authorizesTrade","authorizesAccept","mayRecordCompletedTrade","mayReportProfit"})do
   r[flag]=false
 end
 r.tradeOutcome="UNKNOWN";r.readOnly=true
 S.result=r;S.phase="FINISHED_READ_ONLY"
 local ok,json=pcall(function()return game:GetService("HttpService"):JSONEncode(r)end)
 if ok then
  if type(setclipboard)=="function"then pcall(setclipboard,json)end
  print("[GINGERSCOPE STAGE46 STARTTRADE TUPLE] "..json)
 else warn("[STAGE46] JSON unavailable; no trade actions attempted")end
end
local function finish(why,result)
 if S.finished then return end
 S.finished=true;reason=why;report=result
 privatePack=nil
 receiptRoot=nil;receiptPartner=nil;receiptLabel=nil;receiptLabelText=nil
 if connection then disconnect(connection);connection=nil end
 for _,c in ipairs(connections)do disconnect(c)end
 connections={}
 publish()
end
S.stop=function()finish("MANUAL_STOP")end
local function connect(signal,callback,primary)
 if S.finished then return false end
 pendingConnect=pendingConnect+1
 local ok,c=pcall(function()return signal:Connect(callback)end)
 pendingConnect=pendingConnect-1
 if ok and c then
  attached=attached+1
  if S.finished then disconnect(c)
  elseif primary then connection=c
  else connections[#connections+1]=c end
 else
  cleanupComplete=false
  if not S.finished then finish("LISTENER_ATTACH_FAILED")
  else reason="LISTENER_ATTACH_FAILED" end
 end
 publish()
 return ok and c~=nil and not S.finished
end
if not loaded then finish("MODULES_UNAVAILABLE");return S end
local startAt=clock()
local function ownerProblem()
 if E[KEY]~=S then return "COMPETING_OWNER" end
 for _,owner in ipairs(OWNERS)do
  if owner~=KEY and E[owner]~=nil then return "COMPETING_OWNER" end
 end
 if game.PlaceId~=142823291 or game.JobId~=job
  or players.LocalPlayer~=me or me.Parent~=players then
  return "SESSION_CHANGED"end
end
local function visible(node,top)
 while node do
  if node:IsA("ScreenGui")and node.Enabled~=true then return false end
  if node:IsA("GuiObject")and node.Visible~=true then return false end
  if node==top then return true end
  node=node.Parent
 end
 return false
end
local function visibleTradeRoots()
 local pg=me:FindFirstChildOfClass("PlayerGui")
 if not pg then return nil,0,nil end
 local root,n=nil,0
 for _,screen in ipairs(pg:GetChildren())do
  if screen.Name=="TradeGUI" or screen.Name=="TradeGUI_Phone"then
   for _,container in ipairs(screen:GetChildren())do
    if container.Name=="Container"then
     for _,candidate in ipairs(container:GetChildren())do
      if candidate.Name=="Trade" and visible(candidate,pg)then
       root=candidate;n=n+1
      end
     end
    end
   end
  end
 end
 return root,n,pg
end
local function discover()
 local root,n,pg=visibleTradeRoots()
 if n~=1 then return nil end
 local their=root:FindFirstChild("TheirOffer")
 local label=their and their:FindFirstChild("Username")
 if not label or not(label:IsA("TextLabel")or label:IsA("TextButton"))then return nil end
 local name=tostring(label.Text or "")
 name=(name:match("^%s*%((.-)%)%s*$")or name):gsub("^@",""):gsub("^%s+",""):gsub("%s+$","")
 if name==""then return nil end
 local partner,count=nil,0
 for _,p in ipairs(players:GetPlayers())do
  if p~=me and p.Parent==players and p.Name:lower()==name:lower()then
   partner=p;count=count+1
  end
 end
 if count~=1 then return nil end
 return root,partner,label,pg
end
local captureContract={normalize=function(raw,trust)
 local o,d=contract.normalize(raw,trust)
 o.windowContextOK=type(raw)=="table" and raw.contextOK==true
 return o,d
end}
local function frame(h)
 local ok,o=pcall(observerCore.capture,h)
 if not ok or type(o)~="table"then return nil end
 if o.ourAccepted==true or o.theirAccepted==true then
  return nil,"ACCEPT_INDICATOR_OBSERVED"end
 if o.tradeOpen~=true or o.windowContextOK~=true
  or type(o.ourAccepted)~="boolean" or type(o.theirAccepted)~="boolean"
  or type(o.ourSlots)~="number" or o.ourSlots~=0
  or type(o.theirSlots)~="number" or o.theirSlots~=0
  or type(o.ourSig)~="string" or type(o.theirSig)~="string"
  or o.ourSig=="unverified-ours" or o.theirSig=="unverified-theirs"
  or o.ourSig=="capture-error" or o.theirSig=="capture-error"then return nil end
 return o
end
local function currentRemote()
 local folder=game:GetService("ReplicatedStorage"):FindFirstChild("Trade")
 if not folder then return nil end
 local remote,count=nil,0
 for _,node in ipairs(folder:GetDescendants())do
  if node.Name=="StartTrade" and node:IsA("RemoteEvent")then
   remote=node;count=count+1
  end
 end
 if count>1 then return nil,"START_TRADE_REMOTE_AMBIGUOUS"end
 if count==0 then return nil,"START_TRADE_REMOTE_UNAVAILABLE"end
 return remote,nil
end
local function onStart(...)
 if S.finished then return end
 -- Capture the variable argument pack before entering protected closure;
 -- nested Lua closures cannot directly reference an outer vararg list.
 local args=table.pack(...)
 local ok=pcall(function()
  local why=ownerProblem()
  if why then finish(why);return end
  local now=clock()
  if S.phase~="READY_FOR_MANUAL_INVITATION"and S.phase~="WAIT_TRADE_WINDOW"
   and S.phase~="OBSERVE_POST_GUI_GRACE"then
   finish("UNARMED_START_TRADE_RECEIPT");return end
  seen=seen+1
  if seen>1 then finish("MULTIPLE_START_TRADE_RECEIPTS");return end
  if args.n>6 then finish("ARGUMENT_LIMIT_EXCEEDED");return end
  receiptAt=now
  privatePack=args
  args=nil
  -- GUI visibility can precede this callback under real native timing.
  -- A callback while GUI is visible is eligible for TYPES ONLY when there is
  -- exactly one visible, uniquely bound partner GUI, preserved until reading.
  -- This does NOT authenticate event-to-session association or freshness.
  local visibleRoot,visibleCount=visibleTradeRoots()
  eventBeforeVisibleGui=visibleCount==0
  if visibleCount>1 then finish("AMBIGUOUS_GUI_AT_START_CALLBACK");return end
  if visibleCount==1 then
   local root,partner,label=discover()
   if not root or root~=visibleRoot or not partner or not label then
    finish("GUI_VISIBLE_BUT_PARTNER_UNBOUND_AT_START");return
   end
   receiptRoot=root;receiptPartner=partner;receiptLabel=label
   receiptLabelText=tostring(label.Text or "")
   callbackGuiMode="GUI_VISIBLE_AT_CALLBACK_CLIENT_ONLY"
  else
   callbackGuiMode="EVENT_BEFORE_VISIBLE_GUI_CLIENT_ONLY"
  end
  S.phase="WAIT_TRADE_WINDOW"
 end)
 if not ok then finish("START_EVENT_INSPECTION_FAILED")end
end
local knownRemote,remoteProblem=currentRemote()
if not knownRemote then finish(remoteProblem);return S end
if not connect(knownRemote.OnClientEvent,onStart,true)then return S end
local function checked(r,p,l)
 local problem=ownerProblem();if problem then return nil,problem end
 if currentRemote()~=activeRemote then return nil,"START_TRADE_REMOTE_CHANGED"end
 local root,partner,label=discover()
 if root~=r or partner~=p or label~=l then return nil,"WINDOW_CONTEXT_CHANGED"end
 return true
end
local function observe()
 -- Wait for a quiet period after listener binding; queued/stale traffic fails.
 S.phase="PRE_ARM_QUIET"
 local quietAt=clock()
 while not S.finished and clock()-quietAt<.6 do
  if ownerProblem()then finish("SESSION_CHANGED");return end
  local _,visibleCount=visibleTradeRoots()
  if visibleCount~=0 then finish("WINDOW_OPEN_BEFORE_ARM");return end
  task.wait(.1)
 end
 if S.finished then return end
 activeRemote=currentRemote()
 if not activeRemote then finish("START_TRADE_REMOTE_CHANGED");return end
 S.phase="READY_FOR_MANUAL_INVITATION"
 print("[STAGE46] READY: OTHER trusted account sends ONE invitation; Delta opens invitation only. Both offers EMPTY, no final Accept.")
 while not S.finished and not receiptAt and clock()-startAt<60 do
  if ownerProblem()then finish("SESSION_CHANGED");return end
  if currentRemote()~=activeRemote then finish("START_TRADE_REMOTE_CHANGED");return end
  local _,visibleCount=visibleTradeRoots()
  if visibleCount~=0 then finish("GUI_WITHOUT_START_TRADE");return end
  task.wait(.12)
 end
 if S.finished then return end
 if not receiptAt then finish("NO_START_TRADE_IN_WINDOW");return end
 local stableRoot,stablePartner,stableLabel,handle,lastFrame,frameAt=nil,nil,nil,nil,nil,nil
 local selectedRoot,selectedPartner,selectedLabel,selectedFrame
 while not S.finished and clock()-receiptAt<15 do
  if ownerProblem()then finish("SESSION_CHANGED");return end
  if currentRemote()~=activeRemote then finish("START_TRADE_REMOTE_CHANGED");return end
  local root,partner,label=discover()
  if receiptRoot then
   local actualRoot,actualCount=visibleTradeRoots()
   if actualCount~=1 or actualRoot~=receiptRoot then
    finish("CALLBACK_GUI_ROOT_CHANGED");return
   end
   if root~=receiptRoot or partner~=receiptPartner
    or label~=receiptLabel or tostring((label and label.Text)or "")~=receiptLabelText then
    finish("CALLBACK_GUI_PARTNER_CHANGED");return
   end
  end
  if root and partner then
   if root~=stableRoot or partner~=stablePartner or label~=stableLabel then
    stableRoot=root;stablePartner=partner;stableLabel=label
    local made,h=pcall(observerCore.new,{game=game,players=players,root=root,
     session="stage46-client-only",jobId=job,
     partnerUserId=partner.UserId,localUserId=me.UserId,contract=captureContract})
    handle=made and h or nil;lastFrame=nil;frameAt=nil
   end
   local o,fail
   if handle then o,fail=frame(handle)end
   if fail then finish(fail);return end
   if o then
    if lastFrame and o.ourSig==lastFrame.ourSig
      and o.theirSig==lastFrame.theirSig then
     -- Preserve the first matching snapshot's clock. Resetting on EVERY
     -- .12s poll makes a .15s stability gate mathematically unreachable.
     if clock()-frameAt>=.15 then
      selectedRoot=root;selectedPartner=partner;selectedLabel=label
      selectedFrame=o
      break
     end
    else lastFrame=o;frameAt=clock() end
   else lastFrame=nil;frameAt=nil end
  else
   stableRoot=nil;stablePartner=nil;stableLabel=nil
   handle=nil;lastFrame=nil;frameAt=nil
  end
  task.wait(.12)
 end
 if S.finished then return end
 if not selectedRoot then finish("TRADE_GUI_NOT_STABLE_AFTER_START");return end
 if clock()-receiptAt>10 then finish("START_TRADE_TOO_DISTANT_FROM_GUI");return end
 activeRoot=selectedRoot;activePartner=selectedPartner;activeLabel=selectedLabel
 -- The payload is held only inside this closure until a unique bound partner
 -- exists; inspect shallow types, destroy source immediately, no raw export.
 local ok,r=pcall(inspector.inspect,privatePack,me,selectedPartner)
 privatePack=nil
 if not ok or type(r)~="table" then finish("ARGUMENT_INSPECTION_FAILED");return end
 if r.status~="CLIENT_TUPLE_CLASSIFIED_UNAUTHENTICATED"then
  finish("ARGUMENT_SCHEMA_REJECTED",r);return end
 local stableAt=clock()
 S.phase="OBSERVE_POST_GUI_GRACE"
 while not S.finished and clock()-stableAt<1 do
  local valid,why=checked(selectedRoot,selectedPartner,selectedLabel)
  if not valid then finish(why);return end
  local o,fail=frame(handle)
  if not o then finish(fail or "WINDOW_CONTEXT_CHANGED");return end
  if o.ourSig~=selectedFrame.ourSig or o.theirSig~=selectedFrame.theirSig then
   finish("OFFER_CHANGED_DURING_GRACE");return end
  if selectedPartner.Parent~=players then finish("PARTNER_DEPARTED");return end
  task.wait(.1)
 end
 if S.finished then return end
 if seen~=1 then finish("MULTIPLE_START_TRADE_RECEIPTS");return end
 finish("ONE_START_TRADE_TUPLE_CLASSIFIED_CLIENT_ONLY",r)
end
task.spawn(function()
 local ok=pcall(observe)
 if not ok then finish("NATIVE_OBSERVER_FAILED")end
end)
return S
