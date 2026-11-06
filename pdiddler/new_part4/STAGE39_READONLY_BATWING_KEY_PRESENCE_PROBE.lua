-- Stage39 bounded, read-only candidate Batwing catalogue key LITERAL PRESENCE in
-- ONE locally nearby UpdateTrade payload. No server slot/ID/settlement proof.
-- One or multiple nearby receipts are NOT raw weapon identity or causality proof.
-- Stage33 observed this incoming event; its name provides no source/identity proof.
-- No transfer or Accept action is needed. An empty opening may emit no UpdateTrade;
-- a timeout is INCOMPLETE and supplies no negative evidence about payload binding.
local E=(getgenv and getgenv()) or _G
local KEY="PDIDDLER_STAGE39_BATWING_LITERAL_PRESENCE"
local OWNERS={KEY,"PDIDDLER_DIRECT_KEY_OFFER_CORRELATION","PDIDDLER_DIRECT_KEY_UPDATE_SHAPE","PDIDDLER_STAGE36_IMAGE_RELATION",
 "PDIDDLER_STAGE36_ICON_CATALOG_AUDIT","PDIDDLER_STAGE36_EXACT_REFERENCE",
 "PDIDDLER_STAGE36_EXACT_REFERENCE_PROBE","PDIDDLER_STAGE36_EXACT_IDENTITY",
 "PDIDDLER_STAGE35_SLOT_METADATA_CENSUS","PDIDDLER_STAGE34_OFFER_INVENTORY_PROBE",
 "PDIDDLER_STAGE33_TRANSPORT_CENSUS","PDIDDLER_STAGE32_RESULT_CORRELATION_PROBE",
 "PDIDDLER_STAGE29_POSTCLOSE_PROBE","PDIDDLER_STAGE30_PASSIVE_SIGNALS",
 "PDIDDLER_STAGE28_PASSIVE_ACCEPT_PROBE","PDIDDLER_STAGE27_NATIVE_LAB",
 "PDIDDLER_STAGE25_SCANNER_ONLY","PDIDDLER_GINGERSCOPE_REPLACEMENT_PREVIEW",
 "PDIDDLER_OUTGOING_SESSION","PDIDDLER_PART4_SESSION","PDIDDLER_PART4_CONTROLLER",
 "PDIDDLER_PART5_CONTROLLER","PDIDDLER_OUTGOING_CONTROLLER","PDIDDLER_HOPPING_SESSION",
 "PDIDDLER_INTEGRATION_V15_8_VALUE_FIRST","PDIDDLER_INTEGRATION_V15_7_INVENTORY_GROWTH",
 "PDIDDLER_INTEGRATION_V15_6_IMMEDIATE_SAFETY"}
if game.PlaceId~=142823291 then warn("[UPDATE SHAPE] Wrong MM2 place");return end
for _,name in ipairs(OWNERS)do
 if E[name]~=nil then warn("[UPDATE SHAPE] Competing owner; observation not started");return end
end
local players=game:GetService("Players")
local me=players.LocalPlayer
if not me then warn("[UPDATE SHAPE] Local player unavailable");return end
local job=game.JobId
local S={phase="LOADING_READ_ONLY",finished=false,readOnly=true,
 authorizesTrade=false,authorizesAccept=false,mayRecordCompletedTrade=false,mayReportProfit=false}
E[KEY]=S
local ROOT="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
local BASE="35ec2d9a47048910a464a2ef6eb9b9f52ae306b1"
-- Immutable reviewed shape-only module; pinning does not request execution.
local CORE_PIN="b32ed071faf9d7cb390e7d87b70ca57abda151e4"
local PRESENCE_PIN="bc6eb1394b70b84e20f18f6bcbbadd076e9bf962"
local function source(pin,name)
 local txt=game:HttpGet(ROOT..pin.."/pdiddler/new_part4/"..name..".lua",true)
 assert(type(txt)=="string" and #txt>100,"source unavailable")
 local fn=assert(loadstring(txt,"="..name))
 local mod=fn();assert(type(mod)=="table","invalid module");return mod
end
local core,reader,contract,presence
local loaded=pcall(function()
 core=source(CORE_PIN,"p4_trade_update_shape");assert(type(core.inspect)=="function")
 presence=source(PRESENCE_PIN,"p4_stage39_literal_key_presence");assert(type(presence.inspect)=="function")
 contract=source(BASE,"p4_observer_contract");assert(type(contract.normalize)=="function")
 reader=source(BASE,"p4_native_observer");assert(type(reader.new)=="function" and type(reader.capture)=="function")
end)
-- Everything with native identity, raw slot values, payloads or private clock
-- readings lives in this closure, never on the globally visible S table.
local connections,pendingConnect,listenerCount,disconnectCount={},0,0,0
local cleanupComplete=true
local reason,shape,published=nil,nil,false
local boundRoot,boundPartner,boundLabel,boundRemote,observer,baseline,boundAt
local stableContext,changed,ourCount,theirCount,eventElapsed=false,false,0,0,0
-- Keep only sanitized shape summaries; never retain raw UpdateTrade payloads.
local events,eventCount={},0
local targetKey,knownKeys=nil,nil
local candidateCatalogueRows,displayedLabelVerified=0,false
local candidateCount,mutationSide,sequence=0,"NONE","NONE"
local selectedPresence=nil
local temporalCandidate=false
local pendingAt,pendingOur,pendingTheir=nil,nil,nil
local stableChange,changeAt=false,nil
local MAX_EVENTS,NEAR_SECONDS=12,1.5
local function incomplete()
 if core and type(core.inspect)=="function"then
  local ok,r=pcall(core.inspect,nil)
  if ok and type(r)=="table"then return r end
 end
 return {schema="gingerscope-trade-update-payload-shape-v1",status="INCOMPLETE",
  reason="CORE_UNAVAILABLE",shapeComplete=false}
end
local function disconnect(c)
 local ok=pcall(function()c:Disconnect()end)
 if ok then disconnectCount=disconnectCount+1 else cleanupComplete=false end
end
local function publish()
 if not S.finished or pendingConnect>0 or published then return end
 published=true
 local r=shape or incomplete()
 if not cleanupComplete then r=incomplete();reason="LISTENER_CLEANUP_INCOMPLETE" end
 r.stopReason=reason;r.eventName="UpdateTrade"
 r.clientWindowContextStable=stableContext
 r.offerChangedSinceBinding=changed;r.ourSlots=ourCount;r.theirSlots=theirCount
 r.elapsedSinceBind=eventElapsed
 r.receiptCount=eventCount
 r.nearbyReceiptCandidates=candidateCount
 r.temporalOfferEventCandidate=temporalCandidate
 r.candidateSequence=sequence
 r.mutatedOfferSide=mutationSide
 r.temporalOnly=true
 r.candidateCatalogueRows=candidateCatalogueRows
 r.displayedLabelVerified=displayedLabelVerified
 r.literalEqualityOnly=true
 r.literalPresence=temporalCandidate and shape and selectedPresence or nil
 r.cleanupComplete=cleanupComplete;r.listenersAttached=listenerCount
 r.listenersDisconnected=disconnectCount
 r.anonymizedCountsOnly=true;r.readOnly=true
 r.tradeOutcome="UNKNOWN"
 for _,flag in ipairs({"rawItemIdConfirmed","rawItemKeyConfirmed","exactWeaponIdentityConfirmed",
  "payloadSchemaKnown","rawKeyPresentConfirmed","ownerSideSlotBound",
  "eventSessionAssociationProven","eventOrderingKnown",
  "sideMappingConfirmed","serverSessionBindingConfirmed","payloadSchemaConfirmed",
  "argumentOrderConfirmed","payloadOrderConfirmed","delayedDeliveryRuledOut",
  "outOfOrderDeliveryRuledOut","serverAttestation","serverCompletionProven",
  "causalAttributionProven","authorizesTrade","authorizesAccept",
  "mayRecordCompletedTrade","mayReportProfit"})do r[flag]=false end
 S.result=r;S.phase="FINISHED_READ_ONLY"
 local ok,json=pcall(function()return game:GetService("HttpService"):JSONEncode(r)end)
 if ok then
  if type(setclipboard)=="function"then pcall(setclipboard,json)end
  print("[GINGERSCOPE STAGE39 KEY PRESENCE] "..json)
 else warn("[UPDATE SHAPE] JSON unavailable; observation stopped")end
end
local function finish(why,report)
 if S.finished then return end
 S.finished=true;reason=why;shape=report
 -- Disconnect every successfully returned listener, even if a sibling fails.
 for _,c in ipairs(connections)do disconnect(c)end
 connections={}
 publish()
end
S.stop=function()finish("MANUAL_STOP")end
local function connect(signal,fn)
 if S.finished then return false end
 pendingConnect=pendingConnect+1
 local ok,c=pcall(function()return signal:Connect(fn)end)
 pendingConnect=pendingConnect-1
 if ok and c then
  listenerCount=listenerCount+1
  if S.finished then disconnect(c)else connections[#connections+1]=c end
 else
  if S.finished then
   -- A signal implementation may callback synchronously and then fail without
   -- returning its connection. Such an attachment cannot prove full cleanup.
   shape=nil;cleanupComplete=false;reason="LISTENER_BIND_FAILED"
  else finish("LISTENER_BIND_FAILED")end
 end
 -- A synchronous callback inside Connect can finish before its connection is
 -- returned. Publish only once that returned connection has been torn down.
 publish()
 return ok and c~=nil and not S.finished
end
if not loaded then finish("MODULES_UNAVAILABLE");return S end
local lastClock,clockInvalid=nil,false
local function clock()
 local ok,t=pcall(os.clock)
 if not ok or type(t)~="number"or t~=t or t==math.huge or t==-math.huge
  or t<0 or(lastClock and t<lastClock)then
  clockInvalid=true;error("invalid client clock",0)
 end
 lastClock=t;return t
end
local function guarded(fn,...)
 local ok=pcall(fn,...)
 if not ok then finish(clockInvalid and "CLIENT_CLOCK_INVALID"or "NATIVE_CONTEXT_UNAVAILABLE")end
end
local function ownerReason()
 if E[KEY]~=S then return "COMPETING_OWNER" end
 for _,name in ipairs(OWNERS)do
  if name~=KEY and E[name]~=nil then return "COMPETING_OWNER" end
 end
 if game.PlaceId~=142823291 or game.JobId~=job or players.LocalPlayer~=me
  or me.Parent~=players then return "SESSION_CHANGED" end
end
local function visible(node,stop)
 while node do
  if node:IsA("ScreenGui")and node.Enabled~=true then return false end
  if node:IsA("GuiObject")and node.Visible~=true then return false end
  if node==stop then return true end
  node=node.Parent
 end
 return false
end
-- Reuse the proven Stage33 native paths; require exactly one visible root.
local function discover()
 local pg=me:FindFirstChildOfClass("PlayerGui")
 if not pg then return nil end
 local root,count=nil,0
 for _,name in ipairs({"TradeGUI_Phone","TradeGUI"})do
  for _,screen in ipairs(pg:GetChildren())do
   if screen.Name==name then
    for _,container in ipairs(screen:GetChildren())do
     if container.Name=="Container"then
      for _,candidate in ipairs(container:GetChildren())do
       if candidate.Name=="Trade"and visible(candidate,pg)then root=candidate;count=count+1 end
      end
     end
    end
   end
  end
 end
 if count~=1 then return nil end
 local their=root:FindFirstChild("TheirOffer")
 local label=their and their:FindFirstChild("Username")
 if not label or not(label:IsA("TextLabel")or label:IsA("TextButton"))then return nil end
 local name=tostring(label.Text or "")
 name=(name:match("^%s*%((.-)%)%s*$")or name):gsub("^@",""):gsub("^%s+",""):gsub("%s+$","")
 if name==""then return nil end
 local partner,identities=nil,0
 for _,p in ipairs(players:GetPlayers())do
  if p~=me and p.Parent==players and p.Name:lower()==name:lower()then
   partner=p;identities=identities+1
  end
 end
 if identities~=1 then return nil end
 return root,partner,label,pg
end
local captureContract={normalize=function(raw,trust)
 -- Preserve Stage9 physical signatures and accepted flags. Inventory resolver
 -- errors stay private: contextOK also depends on inventory and is unsuitable
 -- for this strictly local window check. This is NOT server-session evidence.
 local o,d=contract.normalize(raw,trust)
 o.windowContextOK=type(raw)=="table" and raw.contextOK==true
 return o,d
end}
local function validCount(n)return type(n)=="number" and n>=0 and n<=4 and n==math.floor(n)end
local function frame(h)
 local ok,o=pcall(reader.capture,h)
 if not ok or type(o)~="table"then return nil end
 if o.ourAccepted==true or o.theirAccepted==true then return nil,"ACCEPT_INDICATOR_OBSERVED" end
 if o.tradeOpen~=true or o.windowContextOK~=true or type(o.ourAccepted)~="boolean"
  or type(o.theirAccepted)~="boolean" or not validCount(o.ourSlots)or not validCount(o.theirSlots)
  or type(o.ourSig)~="string" or type(o.theirSig)~="string"
  or o.ourSig=="unverified-ours"or o.theirSig=="unverified-theirs"
  or o.ourSig=="capture-error"or o.theirSig=="capture-error"then return nil end
 return o
end
local exactRemote
local function checkedFrame()
 local why=ownerReason();if why then return nil,why end
 local root,partner,label=discover()
 if root~=boundRoot or partner~=boundPartner or label~=boundLabel then return nil,"WINDOW_CONTEXT_CHANGED" end
 if boundRemote and exactRemote()~=boundRemote then return nil,"UPDATE_TRADE_REMOTE_CHANGED" end
 local o,failed=frame(observer)
 if not o then return nil,failed or "WINDOW_CONTEXT_CHANGED" end
 return o
end
local function invalidate()
 guarded(function()
  if S.finished then return end
  local why=ownerReason()
  finish(why or "WINDOW_CONTEXT_CHANGED")
 end)
end
local function bindContextSignals(pg)
 local node=boundRoot
 while node do
  if node:IsA("GuiObject")then
   if not connect(node:GetPropertyChangedSignal("Visible"),invalidate)then return false end
  elseif node:IsA("ScreenGui")then
   if not connect(node:GetPropertyChangedSignal("Enabled"),invalidate)then return false end
  end
  if not connect(node.AncestryChanged,invalidate)then return false end
  if node==pg then break end
  node=node.Parent
 end
 if not connect(boundLabel:GetPropertyChangedSignal("Text"),invalidate)then return false end
 if not connect(boundLabel.AncestryChanged,invalidate)then return false end
 if not connect(boundPartner.AncestryChanged,invalidate)then return false end
 return connect(players.PlayerRemoving,function(p)if p==boundPartner then invalidate()end end)
end
exactRemote=function()
 local folder=game:GetService("ReplicatedStorage"):FindFirstChild("Trade")
 if not folder then return nil,"UPDATE_TRADE_REMOTE_UNAVAILABLE" end
 local remote,count=nil,0
 for _,node in ipairs(folder:GetDescendants())do
  if node.Name=="UpdateTrade" and node:IsA("RemoteEvent")then remote=node;count=count+1 end
 end
 if count>1 then return nil,"UPDATE_TRADE_REMOTE_AMBIGUOUS" end
 if count~=1 then return nil,"UPDATE_TRADE_REMOTE_UNAVAILABLE" end
 return remote
end
-- A temporal co-occurrence is only an investigative candidate. It does not
-- prove the server sent this receipt *because* of this visible item change.
local function resolveNearby(now)
 if not stableChange or S.finished then return end
 if now-changeAt<NEAR_SECONDS then return end -- permit late competing receipts
 local found,nearestDist,nearest=nil,nil,nil
 candidateCount=0
 for _,entry in ipairs(events) do
  local gap=math.abs(entry.at-changeAt)
  if gap<=NEAR_SECONDS then
   candidateCount=candidateCount+1
   if not nearestDist or gap<nearestDist then found=entry;nearestDist=gap end
  end
 end
 changed=true
 if candidateCount==0 then finish("NO_UPDATE_NEAR_SINGLE_OFFER_ADD");return end
 if candidateCount>1 then finish("MULTIPLE_UPDATES_NEAR_SINGLE_OFFER_ADD");return end
 if not found then finish("NO_UPDATE_NEAR_SINGLE_OFFER_ADD");return end
 temporalCandidate=true
 sequence=found.at<changeAt and "EVENT_BEFORE_GUI" or
  (found.at>changeAt and "GUI_BEFORE_EVENT" or "SAME_CLOCK_SAMPLE")
 eventElapsed=math.floor((found.at-boundAt)*100+.5)/100
 shape=found.report
 selectedPresence=found.presence
 stableContext=true
 finish("ONE_UPDATE_NEAR_SINGLE_OFFER_ADD",found.report)
end

local function isExactOurBatwing()
 local side=boundRoot and boundRoot:FindFirstChild("YourOffer")
 local cont=side and side:FindFirstChild("Container")
 local slot=cont and cont:FindFirstChild("NewItem1")
 local itemName=slot and slot:FindFirstChild("ItemName")
 local label=itemName and itemName:FindFirstChild("Label")
 local amount=slot and slot:FindFirstChild("Container")
 local amountLabel=amount and amount:FindFirstChild("Amount")
 local tags=slot and slot:FindFirstChild("Tags")
 local chroma=tags and tags:FindFirstChild("Chroma")
 if not slot or not visible(slot,boundRoot) or not label
  or not (label:IsA("TextLabel") or label:IsA("TextButton"))
  or not visible(label,boundRoot) or label.Text~="Batwing"
  or not amountLabel or not amountLabel:IsA("TextLabel")
  or amountLabel.Text~="" then return false end
 if chroma and visible(chroma,boundRoot) then return false end
 return true
end
local function catalogueKeyCensus()
 local rs=game:GetService("ReplicatedStorage")
 local db=rs:FindFirstChild("Database")
 local module=db and db:FindFirstChild("Sync")
 if not module or not module:IsA("ModuleScript") then return nil,nil,0,"SYNC_MISSING" end
 local ok,sync=pcall(require,module)
 if not ok or type(sync)~="table" then return nil,nil,0,"SYNC_UNAVAILABLE" end
 local weapons,item=rawget(sync,"Weapons"),rawget(sync,"Item")
 local sources={}
 if type(weapons)=="table" then sources[#sources+1]=weapons end
 if type(item)=="table" and item~=weapons then sources[#sources+1]=item end
 if #sources==0 then return nil,nil,0,"CATALOGUE_EMPTY" end
 local keys,count,target,seen={},0,nil,{}
 local candidates=0
 for _,source in ipairs(sources) do
  if getmetatable(source)~=nil then return nil,nil,0,"CATALOGUE_METADATA_UNSUPPORTED" end
  for key,row in next,source do
   count=count+1
   if count>2500 then return nil,nil,0,"CATALOGUE_LIMIT" end
   local kt=type(key)
   if not ((kt=="string" and #key>0 and #key<=256) or
    (kt=="number" and key==key and key~=math.huge and key~=-math.huge)) then
    return nil,nil,0,"CATALOGUE_KEY_UNSUPPORTED" end
   if type(row)~="table" or getmetatable(row)~=nil then
    return nil,nil,0,"CATALOGUE_ROW_UNSUPPORTED" end
   if seen[key]~=nil and seen[key]~=row then
    return nil,nil,0,"CATALOGUE_KEY_COLLISION" end
   seen[key]=row
   keys[key]=true
   if rawget(row,"ItemName")=="Batwing" or rawget(row,"Name")=="Batwing" then
    candidates=candidates+1
    if rawget(row,"Chroma")==true then return nil,nil,candidates,"CHROMA_AMBIGUOUS" end
    target=key
   end
  end
 end
 if candidates~=1 then return nil,nil,candidates,"BATWING_NAME_AMBIGUOUS" end
 return target,keys,candidates,nil
end
local function examineOfferFrame(o,now)
 local dOur=o.ourSlots-baseline.ourSlots
 local dTheir=o.theirSlots-baseline.theirSlots
 local singleOwn=dOur==1 and dTheir==0
 local singleTheir=dTheir==1 and dOur==0
 if not (singleOwn or singleTheir) then
  if stableChange then finish("OFFER_MUTATION_REVERTED_OR_CHANGED") end
  pendingAt=nil;pendingOur=nil;pendingTheir=nil
  return
 end
 local side=singleOwn and "OURS" or "THEIRS"
 if not pendingAt or pendingOur~=o.ourSig or pendingTheir~=o.theirSig then
  if stableChange then finish("OFFER_CHANGED_AFTER_STABILITY");return end
  pendingAt=now;pendingOur=o.ourSig;pendingTheir=o.theirSig
  return
 end
 if not stableChange and now-pendingAt>=.15 then
  if not singleOwn or not isExactOurBatwing() then finish("NOT_ONE_OWN_BATWING");return end
  displayedLabelVerified=true
  stableChange=true;changeAt=pendingAt;mutationSide=side
  ourCount=o.ourSlots;theirCount=o.theirSlots
 end
end

local function captureUpdate(...)
 if S.finished then return end
 local before,why=checkedFrame()
 if not before then finish(why);return end
 local receivedAt=clock()
 if receivedAt-boundAt>=30 then finish("NO_CORRELATED_UPDATE_IN_WINDOW");return end
 eventCount=eventCount+1
 if eventCount>MAX_EVENTS then finish("UPDATE_RECEIPT_LIMIT");return end
 -- This argument pack exists only in this stack frame, not global state.
 local packed=table.pack(...)
 local ok,report=pcall(core.inspect,packed)
 local matched,presenceResult=pcall(presence.inspect,packed,targetKey,knownKeys)
 packed=nil
 if S.finished then return end
 local after,failed=checkedFrame()
 if not after then finish(failed);return end
 if clock()-boundAt>=30 then finish("NO_CORRELATED_UPDATE_IN_WINDOW");return end
 if not ok or type(report)~="table" or not matched or type(presenceResult)~="table" then finish("PAYLOAD_INSPECTION_FAILED");return end
 events[#events+1]={at=receivedAt,report=report,presence=presenceResult}
 -- Never publish the first receipt merely because it arrived. Only a stable,
 -- independently visible, one-side, single-slot addition can be a candidate.
 resolveNearby(clock())
end
local function onUpdate(...)guarded(captureUpdate,...)end
S.phase="WAIT_MANUAL_WINDOW"
print("[STAGE39] READ-ONLY: Open a manual empty trade and wait until LISTENING; manually add one Batwing to YOUR offer. Never Accept.")
local function observe()
 local began=clock()
 local candidateRoot,candidatePartner,candidateLabel,candidateHandle,candidateFrame,candidateAt
 while not S.finished and clock()-began<90 do
  local why=ownerReason();if why then finish(why);return end
  local ok,root,partner,label,pg=pcall(discover)
  if ok and root and partner then
   if root~=candidateRoot or partner~=candidatePartner or label~=candidateLabel then
    candidateRoot=root;candidatePartner=partner;candidateLabel=label
    local made,h=pcall(reader.new,{game=game,players=players,root=root,
     session="direct-key-read-only-local-window",jobId=job,
     partnerUserId=partner.UserId,localUserId=me.UserId,contract=captureContract})
    candidateHandle=made and h or nil;candidateFrame=nil;candidateAt=nil
   end
   local o,failed
   if candidateHandle then o,failed=frame(candidateHandle)end
   if failed then finish(failed);return end
   if o then
    if candidateFrame and candidateFrame.ourSig==o.ourSig and candidateFrame.theirSig==o.theirSig
     and clock()-candidateAt>=.15 then
     boundRoot=root;boundPartner=partner;boundLabel=label;observer=candidateHandle
     baseline=o;boundAt=clock();ourCount=o.ourSlots;theirCount=o.theirSlots
     if baseline.ourSlots~=0 or baseline.theirSlots~=0 then finish("OFFERS_NOT_EMPTY_AT_BIND");return end
     local key,keys,count,err=catalogueKeyCensus()
     if err then finish(err);return end
     targetKey,knownKeys,candidateCatalogueRows=key,keys,count
     if not bindContextSignals(pg)then return end
     local current,invalid=checkedFrame();if not current then finish(invalid);return end
     if current.ourSlots~=0 or current.theirSlots~=0 or current.ourSig~=baseline.ourSig or current.theirSig~=baseline.theirSig then finish("OFFER_CHANGED_DURING_SYNC_READ");return end
     local remote,missing=exactRemote();if not remote then finish(missing);return end
     boundRemote=remote
     S.phase="LISTENING_UPDATE_TRADE"
     if not connect(remote.OnClientEvent,onUpdate)then return end
     print("[STAGE39] LISTENING_UPDATE_TRADE: add exactly one Batwing to YOUR offer, without Accept. Record the game and console.")
     break
    end
    candidateFrame=o;candidateAt=clock()
   else candidateFrame=nil;candidateAt=nil end
  else
   candidateRoot=nil;candidatePartner=nil;candidateLabel=nil;candidateFrame=nil;candidateAt=nil
  end
  task.wait(math.min(.16,math.max(0,90-(clock()-began))))
 end
 if S.finished then return end
 if not boundAt then finish("WINDOW_NOT_OPENED_IN_TIME");return end
 while not S.finished and clock()-boundAt<30 do
  local o,why=checkedFrame();if not o then finish(why);return end
  local now=clock()
  examineOfferFrame(o,now)
  if not S.finished then resolveNearby(now) end
  if not S.finished then task.wait(math.min(.16,math.max(0,30-(clock()-boundAt)))) end
 end
 if not S.finished then finish("NO_CORRELATED_UPDATE_IN_WINDOW")end
end
task.spawn(function()guarded(observe)end)
return S
