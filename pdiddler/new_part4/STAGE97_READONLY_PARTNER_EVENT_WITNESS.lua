-- Stage97: READ-ONLY one-window partner UpdateTrade / Part4 GUI correlation.
-- Original MM2, manually opened trade with a consenting ALT.
-- No request tap, offer, Accept, Decline, hop, Discord, price or ownership call.
-- Does not prove a server transaction nonce or causal attribution.
local E=(type(getgenv)=="function" and getgenv()) or _G
local KEY="GINGERSCOPE_STAGE97_PARTNER_EVENT_READONLY"
local SCHEMA="gingerscope-stage97-native-partner-event-research-v1"
local targetName=E.PDIDDLER_STAGE97_TARGET_USERNAME
if E.PDIDDLER_STAGE97_READONLY_ARMED~=true
   or type(targetName)~="string" or #targetName<3 or #targetName>20
   or not targetName:match("^[A-Za-z0-9_]+$") then
 warn("[STAGE97] explicitly arm READONLY and set exact consenting ALT username")
 return nil
end
if game.PlaceId~=142823291 then
 warn("[STAGE97] original MM2 place only")
 return nil
end
if E[KEY]~=nil then
 warn("[STAGE97] one-shot already used: fresh server required")
 return E[KEY]
end
for _,k in ipairs({
 "GINGERSCOPE_STAGE88_CONTACT_READONLY_PREVIEW",
 "GINGERSCOPE_STAGE89_SINGLE_REQUEST_DIAGNOSTIC",
 "GINGERSCOPE_STAGE90_CARD_LAYOUT_AUDIT",
 "GINGERSCOPE_STAGE91_SINGLE_REQUEST_DIAGNOSTIC",
 "GINGERSCOPE_STAGE92_SINGLE_REQUEST_DIAGNOSTIC",
 "GINGERSCOPE_STAGE93_SINGLE_REQUEST_DIAGNOSTIC",
 "PDIDDLER_GINGERSCOPE_REPLACEMENT_PREVIEW",
 "PDIDDLER_OUTGOING_CONTROLLER","PDIDDLER_OUTGOING_SESSION",
 "PDIDDLER_OUTGOING_BUSY_SESSION","PDIDDLER_PART4_SESSION",
 "PDIDDLER_PART4_CONTROLLER","PDIDDLER_HOPPING_SESSION",
 "PDIDDLER_PART5_CONTROLLER","PDIDDLER_STATUS_OWNER"
}) do
 if E[k]~=nil then
  warn("[STAGE97] existing transaction/probe owner, use fresh MM2 server")
  return nil
 end
end
local R={
 schema=SCHEMA,status="STARTING",reason="INITIALIZING",
 readOnly=true,clientOnly=true,contactRequestOnly=false,
 targetClientBound=false,exactPartnerGuiObserved=false,
 stage9ObserverBound=false,stage9Frames=0,
 eventReceiptCount=0,onePartnerGuiSlotObserved=false,
 partnerEventTupleObserved=false,clientNameQuantityConsistent=false,
 clientRawTextConsistent=false,clientNameOnlyUnbound=false,
 ourGuiOfferStayedUnchanged=true,
 actualRequestTaps=0,actualOffers=0,actualAccepts=0,
 actualDeclines=0,actualTeleports=0,
 eventSessionAssociationProven=false,callbackCausalityProven=false,
 ownerSideSlotBound=false,rawItemIdConfirmed=false,
 uniqueWeaponInstanceProven=false,authenticatedOwnedInventory=false,
 currentGameCatalogueAuthenticated=false,numericSupremeCheckerIdVerified=false,
 sourcePublisherFresh=false,currentPricesVerified=false,
 priceForTradeVerified=false,marketValueAuthority=false,
 serverAttestation=false,serverCompletionProven=false,
 authorizesTrade=false,authorizesAccept=false,
 mayRecordCompletedTrade=false,mayReportProfit=false,
 maySendDiscordWebhook=false,mayUseForStrategyLearning=false,
 tradeOutcome="UNKNOWN",elapsedSeconds=0
}
local started=os.clock()
local Players=game:GetService("Players")
local LP=Players and Players.LocalPlayer
local PG=LP and LP:FindFirstChildOfClass("PlayerGui")
local I={running=true,report=R,jobId=tostring(game.JobId)}
E[KEY]=I
local connection=nil
local target=nil
local function result()
 R.elapsedSeconds=math.floor(math.max(0,os.clock()-started))
 local ok,json=pcall(function()
  return game:GetService("HttpService"):JSONEncode(R)
 end)
 if ok and type(json)=="string" and #json<2500 then
  local line="[GINGERSCOPE STAGE97 PARTNER EVENT] "..json
  print(line)
  if type(setclipboard)=="function" then pcall(setclipboard,line) end
 else
  warn("[STAGE97] sanitized JSON report unavailable")
 end
end
local function finish(status,reason)
 if not I.running then return I end
 I.running=false
 if connection then pcall(function()connection:Disconnect()end) end
 connection=nil
 R.status=status;R.reason=reason
 result()
 return I
end
local function live()
 return I.running and E[KEY]==I
  and tostring(game.JobId)==I.jobId and LP~=nil
  and LP.Parent==Players and PG~=nil and PG.Parent==LP
  and LP:FindFirstChildOfClass("PlayerGui")==PG
  and target~=nil and target.Parent==Players
  and Players:GetPlayerByUserId(target.UserId)==target
end
local function visible(node)
 if not node then return false end
 local x=node
 while x do
  if x:IsA("ScreenGui") and x.Enabled==false then return false end
  if x:IsA("GuiObject") and x.Visible==false then return false end
  x=x.Parent
 end
 return true
end
local function trim(s)
 if type(s)~="string" then return "" end
 return s:gsub("^%s+",""):gsub("%s+$",""):gsub("^@","")
end
local function exactRoot()
 if not live() then return nil,"SESSION_OR_TARGET_CHANGED" end
 local roots={}
 for _,gn in ipairs({"TradeGUI_Phone","TradeGUI"}) do
  local gui=PG:FindFirstChild(gn)
  local c=gui and gui:FindFirstChild("Container")
  local t=c and c:FindFirstChild("Trade")
  if t and visible(gui) and visible(t) then
   roots[#roots+1]=t
  end
 end
 if #roots~=1 then
  return nil,#roots>1 and "MULTIPLE_VISIBLE_TRADE_GUI_ROOTS" or
    "EXACT_TRADE_WINDOW_NOT_OPEN"
 end
 local root=roots[1]
 local theirs=root:FindFirstChild("TheirOffer")
 local name=theirs and theirs:FindFirstChild("Username")
 if not name or not (name:IsA("TextLabel") or name:IsA("TextButton"))
    or not visible(name) or type(name.Text)~="string" then
  return nil,"TRADE_PARTNER_HEADER_UNAVAILABLE"
 end
 local shown=name.Text:match("^%s*%((.-)%)%s*$") or name.Text
 if trim(shown):lower()~=target.Name:lower() then
  return nil,"TRADE_GUI_WRONG_PARTNER"
 end
 return root,"EXACT_CURRENT_CLIENT_PARTNER"
end
local ROOT="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
local SOURCES={
 stage9contract={"1971b93d324f0275e6a9affb472ac3e804439ed8",
 "pdiddler/new_part4/p4_observer_contract.lua"},
 stage9native={"1971b93d324f0275e6a9affb472ac3e804439ed8",
 "pdiddler/new_part4/p4_native_observer.lua"},
 stage95={"cf2dbba6244a276955be9fca3d5e9789fd8449b0",
 "pdiddler/intelligence_lab/stage95_p4_public_slot_boundary.lua"},
 stage96={"f04776820ae213b91be60aab8415a9bdb26834ea",
 "pdiddler/intelligence_lab/stage96_partner_event_gui_correlation.lua"},
 stage83={"25b48b60fdb2f971bbb6b2a2020f3c7c4432f7ae",
 "pdiddler/intelligence_lab/stage83_public_slug_registry.lua"},
}
local function source(key)
 local p=SOURCES[key]
 local ok,mod=pcall(function()
  local text=game:HttpGet(ROOT..p[1].."/"..p[2])
  assert(type(text)=="string" and #text>50 and #text<100000)
  return assert(loadstring(text))()
 end)
 if not ok or type(mod)~="table" then return nil end
 return mod
end
local function loadCatalogue()
 local ok,cat=pcall(function()
  local rs=game:GetService("ReplicatedStorage")
  local db=rs:FindFirstChild("Database")
  local syncModule=db and db:FindFirstChild("Sync")
  assert(syncModule and syncModule:IsA("ModuleScript"))
  local sync=require(syncModule)
  assert(type(sync)=="table")
  local w=rawget(sync,"Weapons")
  assert(type(w)=="table" and getmetatable(w)==nil)
  return w
 end)
 if not ok then return nil end
 return cat
end
local function exactRemote()
 local rs=game:GetService("ReplicatedStorage")
 local folder=rs:FindFirstChild("Trade")
 if not folder then return nil end
 local ok,desc=pcall(function()return folder:GetDescendants()end)
 if not ok or type(desc)~="table" or #desc>12000 then return nil end
 local match,count=nil,0
 for _,node in ipairs(desc) do
  if node.Name=="UpdateTrade" and node:IsA("RemoteEvent") then
   count=count+1;match=node
  end
 end
 return count==1 and match or nil
end
local function run()
 if LP==nil or PG==nil or not PG.Parent or PG.Parent~=LP then
  return finish("INCONCLUSIVE","MAIN_CLIENT_GUI_UNAVAILABLE")
 end
 local matches={}
 for _,p in ipairs(Players:GetPlayers()) do
  if p~=LP and type(p.Name)=="string"
     and p.Name:lower()==targetName:lower() and p.Parent==Players then
   matches[#matches+1]=p
  end
 end
 if #matches~=1 then return finish("INCONCLUSIVE","TARGET_NOT_UNIQUE_IN_SERVER") end
 target=matches[1]
 R.targetClientBound=true
 local root,why=exactRoot()
 if not root then return finish("INCONCLUSIVE",why) end
 R.exactPartnerGuiObserved=true
 -- Pinned original Stage9 capture; all other modules are passive.
 local p4contract=source("stage9contract")
 local p4native=source("stage9native")
 local stage95=source("stage95")
 local stage96=source("stage96")
 local registry=source("stage83")
 local catalogue=loadCatalogue()
 if not p4contract or not p4native or not stage95 or
    not stage96 or not registry or not catalogue or
    type(p4contract.normalize)~="function" or
    type(p4native.new)~="function" or type(p4native.capture)~="function"
    or type(stage96.inspect)~="function" or type(stage95.inspect)~="function" then
  return finish("INCONCLUSIVE","READONLY_PINNED_SOURCES_UNAVAILABLE")
 end
 local session="stage97:"..tostring(started)
 local capturedRaw=nil
 local proxy={
  normalize=function(raw,_)
   capturedRaw=raw
   return p4contract.normalize(raw,{marketFresh=false})
  end
 }
 local made,handle=pcall(p4native.new,{
  game=game,players=Players,root=root,session=session,
  jobId=I.jobId,partnerUserId=target.UserId,localUserId=LP.UserId,
  contract=proxy,ownInventory=nil,opponentInventory=nil,
  marketFresh=function()return false end
 })
 if not made or type(handle)~="table" then
  return finish("INCONCLUSIVE","ORIGINAL_STAGE9_OBSERVER_NOT_AVAILABLE")
 end
 local scope={session=session,jobId=I.jobId,root=root,
  localPlayer=LP,partnerPlayer=target}
 local function record(raw,at)
  return {raw=raw,at=at,session=session,jobId=I.jobId,
   root=root,localPlayer=LP,partnerPlayer=target}
 end
 local function capture()
  local same,reason=exactRoot()
  if not same or same~=root then
   return nil,nil,nil,reason or "TRADE_GUI_ROOT_CHANGED"
  end
  capturedRaw=nil
  local ok,o,diag=pcall(p4native.capture,handle)
  local raw=capturedRaw
  if not ok or type(o)~="table" or type(diag)~="table"
     or type(raw)~="table" or o.tradeOpen~=true
     or o.session~=session or raw.contextOK~=true
     or o.quoteSafe~=false
     or type(o.ourSig)~="string" or type(o.theirSig)~="string"
     or o.ourSig:sub(1,10)=="unverified"
     or o.theirSig:sub(1,10)=="unverified"
     or o.ourSig=="capture-error" or o.theirSig=="capture-error"
     or type(o.ourSlots)~="number" or type(o.theirSlots)~="number"
     or o.ourSlots<0 or o.theirSlots<0 or
     o.ourSlots>4 or o.theirSlots>4
     or raw.our==nil or raw.their==nil
     or raw.our.accepted~=false or raw.their.accepted~=false
     or diag.authorizesTrade~=false or diag.authorizesAccept~=false then
   return nil,nil,nil,"ORIGINAL_STAGE9_CAPTURE_UNVERIFIED"
  end
  R.stage9Frames=R.stage9Frames+1
  return o,raw,os.clock(),"EXACT_CLIENT_GUI"
 end
 local o0,raw0,at0,why0=capture()
 if not o0 then return finish("INCONCLUSIVE",why0) end
 if o0.ourSlots~=0 or o0.theirSlots~=0 then
  return finish("INCONCLUSIVE","TRADE_OFFERS_NOT_BOTH_EMPTY_AT_BIND")
 end
 task.wait(.18)
 local o1,raw1,at1,why1=capture()
 if not o1 then return finish("INCONCLUSIVE",why1) end
 if o1.ourSig~=o0.ourSig or o1.theirSig~=o0.theirSig
    or o1.ourSlots~=0 or o1.theirSlots~=0 then
  return finish("INCONCLUSIVE","BASELINE_GUI_NOT_STABLE")
 end
 R.stage9ObserverBound=true
 local remote=exactRemote()
 if not remote then return finish("INCONCLUSIVE","UNIQUE_UPDATE_TRADE_REMOTE_UNAVAILABLE") end
 local before=record(raw1,at1)
 local receiptCount=0
 local receipt=nil
 local callbackBad=false
 local ok,con=pcall(function()
  return remote.OnClientEvent:Connect(function(...)
   if not I.running then return end
   receiptCount=receiptCount+1
   if receiptCount~=1 then
    callbackBad=true;receipt=nil;return
   end
   local current,reason=exactRoot()
   if not current or current~=root then callbackBad=true;return end
   receipt={packed=table.pack(...),at=os.clock(),
    session=session,jobId=I.jobId,root=root,
    localPlayer=LP,partnerPlayer=target}
  end)
 end)
 if not ok or not con or type(con.Disconnect)~="function" then
  return finish("INCONCLUSIVE","READONLY_UPDATE_TRADE_LISTENER_FAILED")
 end
 connection=con
 print("[STAGE97] READY: alt may manually ADD ONE expendable Ancient/Godly item to THEIR offer. Leave main side empty. NEVER final Accept.")
 local deadline=os.clock()+35
 while live() and os.clock()<deadline do
  task.wait(.08)
  R.eventReceiptCount=math.min(receiptCount,99)
  if callbackBad or receiptCount>1 then
   return finish("INCONCLUSIVE","MULTIPLE_OR_UNBOUND_UPDATE_TRADE_CALLBACKS")
  end
  local o,raw,at,why2=capture()
  if not o then return finish("INCONCLUSIVE",why2) end
  if o.ourSlots~=0 then
   R.ourGuiOfferStayedUnchanged=false
   return finish("INCONCLUSIVE","OUR_GUI_OFFER_CHANGED")
  end
  if receiptCount==0 then
   if o.theirSlots==0 then
    before=record(raw,at)
   else
    -- A callback arriving after the visible mutation could be delayed from
    -- another trade; preserve the uncertainty instead of accepting it.
    return finish("INCONCLUSIVE","GUI_OFFER_CHANGED_BEFORE_PARTNER_CALLBACK")
   end
  elseif receiptCount==1 and receipt then
   if o.theirSlots>1 then
    return finish("INCONCLUSIVE","MULTIPLE_PARTNER_GUI_SLOTS")
   end
   if o.theirSlots==1 then
    R.onePartnerGuiSlotObserved=true
    local after1=record(raw,at)
    task.wait(.18)
    local o2,raw2,at2,reason2=capture()
    if not o2 then return finish("INCONCLUSIVE",reason2) end
    if callbackBad or receiptCount~=1 then
     return finish("INCONCLUSIVE","MULTIPLE_OR_UNBOUND_UPDATE_TRADE_CALLBACKS")
    end
    local after2=record(raw2,at2)
    local evaluated=stage96.inspect({
      scope=scope,before=before,receipt=receipt,
      after1=after1,after2=after2,eventCount=receiptCount
    },catalogue,registry,p4contract,stage95)
    -- Never emit private raw key, weapon label, player identity, or payload.
    receipt=nil
    if type(evaluated)~="table" then
     return finish("INCONCLUSIVE","STAGE96_RESEARCH_COMPARATOR_FAILED")
    end
    R.partnerEventTupleObserved=evaluated.partnerEventTupleObserved==true
    R.clientNameQuantityConsistent=evaluated.oneVisiblePartnerGuiSlotMatched==true
    R.clientRawTextConsistent=evaluated.clientEventRawTextMatchesGuiRawText==true
    R.clientNameOnlyUnbound=evaluated.clientGuiNameOnlyUnbound==true
    if evaluated.authorizesTrade~=false or evaluated.authorizesAccept~=false
       or evaluated.serverCompletionProven~=false
       or evaluated.eventSessionAssociationProven~=false then
     return finish("INCONCLUSIVE","UNEXPECTED_AUTHORITY_ESCALATION_BLOCKED")
    end
    return finish(evaluated.status or "INCONCLUSIVE",
       evaluated.reason or "STAGE96_RESEARCH_RESULT_UNKNOWN")
   end
  end
 end
 if not live() then return finish("INCONCLUSIVE","SESSION_OR_TARGET_CHANGED") end
 return finish("INCONCLUSIVE",receiptCount==1
   and "NO_MATCHING_PARTNER_GUI_AFTER_ONE_CALLBACK"
   or "NO_UPDATE_TRADE_CALLBACK_OBSERVED")
end
task.spawn(function()
 local ok,err=xpcall(run,function(e)return tostring(e)end)
 if not ok then
  finish("INCONCLUSIVE","READONLY_RUNTIME_OR_GUI_FAILURE")
  warn("[STAGE97] stopped safely; no trade or Accept authorization")
 end
end)
return I
