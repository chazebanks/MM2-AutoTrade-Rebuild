-- Stage59 role-neutral baseline: Stage32 read-only signal and inventory observation.
-- Client-only PRE/POST own inventory reads may start without the opponent's
-- independently verified inventory cache. That cache is for resolving OFFER
-- identities, never a prerequisite for counting our OWN before/after copies.
-- This DOES NOT relax exact trade GUI/partner matching, native session checks,
-- or permit trade, Accept, profit, server settlement or strategy learning.
-- Reuses Stage25/Stage9/Stage28/Stage29/Stage30 exactly; no Accept, Decline,
-- OfferItem, automatic requests, completion/profit/webhook or teleport.
-- Event names + three own-inventory reads are CLIENT evidence ONLY.
-- No observed receipt or quantity change establishes server completion.
local E=(getgenv and getgenv()) or _G
local KEY="PDIDDLER_STAGE32_RESULT_CORRELATION_PROBE"
if game.PlaceId~=142823291 then
 warn("[STAGE32] Wrong game; no action") return
end
for _,id in ipairs({KEY,"PDIDDLER_STAGE29_POSTCLOSE_PROBE",
  "PDIDDLER_STAGE30_PASSIVE_SIGNALS","PDIDDLER_STAGE28_PASSIVE_ACCEPT_PROBE",
  "PDIDDLER_STAGE27_NATIVE_LAB","PDIDDLER_GINGERSCOPE_REPLACEMENT_PREVIEW",
  "PDIDDLER_OUTGOING_SESSION","PDIDDLER_PART4_SESSION",
  "PDIDDLER_PART5_CONTROLLER","PDIDDLER_INTEGRATION_V15_8_VALUE_FIRST"}) do
 if E[id]~=nil then
  warn("[STAGE32] Another test or trading owner detected; rejoin before use")
  return
 end
end
local ROOT="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
local STAGE26="a2a2e601be864f970da0a69c436ab3b12efd8112"
local SILENT_SCANNER="8d7e9e9315c29ac4c9f4004d4c9620699639fb04"
local STAGE28="800ec9aa5f38b7d06e3af1bbf492dfd79ade3951"
local STAGE29="562fb0c453c1711a3fbd6ca294a44797ac359c42"
local STAGE30="3ccf9219580726e2b122e1b9d4bdb6039eff96b0"
local STAGE32="05adedad97d0b805e92a8e3d8d1f5efbc14f5a9c"
local players=game:GetService("Players")
local me=assert(players.LocalPlayer,"player not ready")
local job=game.JobId
local S={state="BOOTING_READ_ONLY",reportReady=false,job=job,
 connections={},authorizesTrade=false,authorizesAccept=false,
 serverCompletionProven=false,mayRecordCompletedTrade=false}
E[KEY]=S
local function source(pin,name)
 local data=game:HttpGet(ROOT..pin.."/pdiddler/new_part4/"..name..".lua",true)
 assert(type(data)=="string" and #data>70,"missing Stage29 source")
 local fn,why=loadstring(data,"="..name)
 assert(fn,why)
 local mod=fn()
 assert(type(mod)=="table","module invalid")
 return mod
end
local function finish(reason,ledger,timeline)
 if S.reportReady then return end
 S.reportReady=true;S.state="FINISHED_READ_ONLY"
 for _,conn in ipairs(S.connections) do
   pcall(function()conn:Disconnect()end)
 end
 S.connections={}
 if S.census and S.signalCore and not S.census.final then
   local why=(reason=="TWO_POST_CLOSE_READS_FINISHED"
     and "OBSERVATION_FINISHED" or "SESSION_CHANGED")
   S.signalCore.finish(S.census,why,os.clock())
 end
 local l=ledger and ledger.module.summary(ledger.instance) or {
   schema="gingerscope-stage29-post-close-own-inventory-v1",
   status="INCOMPLETE",reason=reason,readbackCalls=0,
   tradeOutcome="UNKNOWN",serverCompletionProven=false,
   authorizesAccept=false,mayRecordCompletedTrade=false,
   mayReportProfit=false}
 local t=timeline and timeline.module.summary(timeline.instance) or {
   schema="gingerscope-stage28-acceptance-timeline-v1",
   status="NOT_OBSERVED",closureStatus="not-observed",
   serverCompletionProven=false,mayRecordCompletedTrade=false}
 local census=S.census and S.signalCore and S.signalCore.summary(S.census) or {
   status="INCOMPLETE",signalReceipts=0,postCloseSignalReceipts=0,signals={}
 }
 local joined=S.census and S.joinCore and ledger and timeline and
    S.joinCore.evaluate(timeline.instance,S.census,ledger.instance) or {
    status="INCOMPLETE",reason="missing-terminal-three-stream-evidence",
    tradeOutcome="UNKNOWN",serverCompletionProven=false,
    mayRecordCompletedTrade=false,mayReportProfit=false}
 local candidate={}
 for _,receipt in ipairs(census.signals or {}) do
  if receipt.name=="CompleteTrade" or receipt.name=="EndTrade"
      or receipt.name=="DeclineTrade" then
   candidate[#candidate+1]={name=receipt.name,phase=receipt.phase,
     elapsed=receipt.elapsed}
  end
 end
 local data={schema="gingerscope-stage32-readonly-result-correlation-v1",
   status=joined.status,reason=joined.reason,stopReason=reason,
   inventoryStatus=l.status,
   beforeObserved=l.beforeObserved,windowClosureObserved=l.windowClosureObserved,
   postReadbacksObserved=l.postReadbacksObserved,
   changedEligibleTypes=l.changedEligibleTypes,
   gainedEligibleCopies=l.gainedEligibleCopies,
   lostEligibleCopies=l.lostEligibleCopies,
   rawWeaponInventoryChanged=l.rawWeaponInventoryChanged,
   observedTheirAccept=t.theirAcceptIndicatorEverVisible==true,
   observedOurAccept=t.ourAcceptIndicatorEverVisible==true,
   bothAcceptedStableObserved=t.bothAcceptedStableObserved==true,
   offerMutationAfterAccept=t.offerMutationAfterAccept==true,
   closureStatus=t.closureStatus,
   signalReceipts=census.signalReceipts,
   postCloseSignalReceipts=census.postCloseSignalReceipts,
   candidateSignals=candidate,
   completeTradeSignalSeen=joined.completeTradeSignalSeen==true,
   endTradeSignalSeen=joined.endTradeSignalSeen==true,
   declineTradeSignalSeen=joined.declineTradeSignalSeen==true,
   resultNamedSignalsTruncated=joined.resultNamedSignalsTruncated==true,
   partnerDepartureObserved=census.partnerDepartureObserved==true,
   tradeOutcome="UNKNOWN",readOnly=true,
   readbacksAreClientClaims=true,
   serverAttestation=false,serverCompletionProven=false,
   causalAttributionProven=false,
   authorizesTrade=false,authorizesAccept=false,
   mayRecordCompletedTrade=false,mayReportProfit=false}
 local ok,json=pcall(function()
   return game:GetService("HttpService"):JSONEncode(data)
 end)
 if ok then
  -- The outer Stage59 UI owns deliberate per-device receipt copying.
  -- An automatic nested clipboard write would overwrite the OTHER
  -- client's receipt (e.g. iPhone/iPad shared clipboard).
  print("[GINGERSCOPE STAGE32 ANONYMIZED] "..json)
 else
  warn("[STAGE32] JSON output unavailable; no trade actions")
 end
 data.partnerCacheAtBaseline=S.partnerCacheAtBaseline
 S.result=data
end
local loaded,mods=pcall(function()
 return {observer=source(STAGE26,"p4_native_observer"),
   contract=source(STAGE26,"p4_observer_contract"),
   timeline=source(STAGE28,"p4_stage28_accept_timeline"),
   ledger=source(STAGE29,"STAGE59_POSTCLOSE_LEDGER_120S"),
   census=source(STAGE30,"p4_stage30_client_signal_census"),
   join=source(STAGE32,"p4_stage32_result_correlation")}
end)
if not loaded then
 S.state="MODULES_UNAVAILABLE";finish("READ_ONLY_MODULE_LOAD_FAILED")
 return S
end
local scannerOwner=E.PDIDDLER_STAGE25_SCANNER_ONLY
if scannerOwner~=nil then
 -- Preexisting Stage25 diagnostics can still have an asynchronous scanner
 -- clipboard overwrite scheduled. Rejoin for a guaranteed silent sandbox.
 S.state="UNISOLATED_SCANNER"
 finish("REJOIN_REQUIRED_PREEXISTING_SCANNER")
 return S
end
if not scannerOwner then
 E.PDIDDLER_ALLOW_SCANNER_ONLY_TEST=true
 local ok,owner=pcall(function()
  local src=game:HttpGet(ROOT..SILENT_SCANNER..
    "/pdiddler/new_part4/STAGE59_SCANNER_SILENT_BOOT.lua",true)
  return assert(loadstring(src,"=stage59-silent-scanner-only"))()
 end)
 if not ok then
  S.state="SCANNER_UNAVAILABLE";finish("SCANNER_START_FAILED")
  return S
 end
 scannerOwner=owner
end
if type(scannerOwner)~="table" or
   scannerOwner.status~="SCANNER_ONLY_NO_TRADE_AUTHORITY" or
   type(scannerOwner.rawScanner)~="table" then
 S.state="SCANNER_UNAVAILABLE";finish("SCANNER_NOT_READY")
 return S
end
local scanner=scannerOwner.rawScanner
S.signalCore=mods.census
S.joinCore=mods.join
local function visible(x,stop)
 while x do
  if x:IsA("ScreenGui") and x.Enabled~=true then return false end
  if x:IsA("GuiObject") and x.Visible~=true then return false end
  if x==stop then return true end
  x=x.Parent
 end
 return false
end
local function tradeRoot()
 local pg=me:FindFirstChildOfClass("PlayerGui")
 if not pg then return nil end
 for _,name in ipairs({"TradeGUI_Phone","TradeGUI"}) do
  local screen=pg:FindFirstChild(name)
  local container=screen and screen:FindFirstChild("Container")
  local root=container and container:FindFirstChild("Trade")
  if root and visible(root,pg) then return root end
 end
end
local function partnerFor(root)
 local side=root and root:FindFirstChild("TheirOffer")
 local label=side and side:FindFirstChild("Username")
 local s=label and tostring(label.Text or "") or ""
 s=(s:match("^%s*%((.-)%)%s*$") or s):gsub("^@","")
 s=s:gsub("^%s+",""):gsub("%s+$","")
 if s=="" then return nil end
 for _,p in ipairs(players:GetPlayers()) do
  if p~=me and p.Parent==players and p.Name:lower()==s:lower() then
   return p
  end
 end
end
local function partnerInventory(p)
 if not p then return nil end
 local ok,rec=pcall(scanner.getRecord,p.UserId)
 local good,verify=pcall(scanner.getVerificationState,p.UserId)
 if not ok or not good or type(rec)~="table"
    or type(verify)~="table" or rec.player~=p
    or verify.player~=p or verify.record~=rec
    or verify.scanning==true or verify.retryScheduled==true
    or type(rec.inv)~="table" or type(rec.scanProof)~="table"
    or rec.scanProof.jobId~=job
    or rec.scanProof.playerUserId~=p.UserId
    or rec.scanProof.fingerprint~=rec.inv.fingerprint
    or type(rec.scanProof.completedAtMono)~="number"
    or os.clock()<rec.scanProof.completedAtMono
    or os.clock()-rec.scanProof.completedAtMono>30 then
  return nil
 end
 return rec.inv
end
local function scope(session,partner)
 return {session=session,jobId=job,
   accountId=me.UserId,partnerId=partner.UserId}
end
local function readOwn()
 local ok,value,why=pcall(scanner.getOwnInventory)
 if not ok or why or type(value)~="table" then return nil end
 return value
end
local function sameSession(root,partner)
 return game.JobId==job and players.LocalPlayer==me and
   partner.Parent==players and root==tradeRoot()
end
-- Subscribe to just three candidate client events, not all 16.
-- Each is a RemoteEvent observed ONLY, never sent or invoked.
local function watchCandidateSignals(root,partner,census)
 local rs=game:GetService("ReplicatedStorage")
 local folder=rs:FindFirstChild("Trade")
 if not folder then return false,"TRADE_FOLDER_ABSENT" end
 local eventNames={"CompleteTrade","EndTrade","DeclineTrade"}
 local refs={}
 local permitted={CompleteTrade=true,EndTrade=true,DeclineTrade=true}
 for _,node in ipairs(folder:GetDescendants()) do
  if node:IsA("RemoteEvent") and permitted[node.Name] then
   if refs[node.Name] then return false,"DUPLICATE_CANDIDATE_REMOTE" end
   refs[node.Name]=node
  end
 end
 for _,name in ipairs(eventNames) do
  if not refs[name] then return false,"CANDIDATE_REMOTE_UNAVAILABLE:"..name end
 end
 local ok,why=mods.census.catalog(census,eventNames,os.clock())
 if not ok then return false,why end
 for _,name in ipairs(eventNames) do
  local signal=refs[name]
  local made,conn=pcall(function()
   return signal.OnClientEvent:Connect(function()
    if S.reportReady or E[KEY]~=S or
       game.JobId~=job or players.LocalPlayer~=me or
       partner.Parent~=players then return end
    local current=tradeRoot()
    if current and current~=root then return end
    if census.closedAt and current then return end
    -- Callback deliberately has ZERO parameters: never read payload.
    mods.census.received(census,name,os.clock())
   end)
  end)
  if not made or not conn then return false,"CLIENT_LISTENER_UNAVAILABLE" end
  S.connections[#S.connections+1]=conn
 end
 local okDeparture,departure=pcall(function()
  return players.PlayerRemoving:Connect(function(p)
   if not S.reportReady and p==partner then
     mods.census.partnerDeparture(census,os.clock())
   end
  end)
 end)
 if not okDeparture or not departure then return false,"PARTNER_WATCH_UNAVAILABLE" end
 S.connections[#S.connections+1]=departure
 return true,"BOUND_READ_ONLY"
end
S.state="AWAIT_MANUAL_TRADE"
S.awaitReason="NO_VISIBLE_TRADE"
print("[GINGERSCOPE STAGE59] READ-ONLY role-neutral own-inventory baseline; opponent cache only supports offer identity, not session binding.")
task.spawn(function()
 local start=os.clock()
 while E[KEY]==S and game.JobId==job and os.clock()-start<120 do
  local root=tradeRoot()
  local partner=partnerFor(root)
  local their=(root and partner) and partnerInventory(partner) or nil
  -- Exact trade partner and GUI required. Stale/missing opponent cache is NOT
  -- a prerequisite for our OWN before/after inventory readback; native offer
  -- normalization remains unresolved, so there is no Accept/profit authority.
  if root and partner then
   local id="stage32:"..tostring(start)
   local sc=scope(id,partner)
   local ledger={module=mods.ledger,
     instance=mods.ledger.new(sc,os.clock(),{maxBeforeToClose=120,minPostGap=.75,maxPostAge=30})}
   local own=readOwn() -- exactly one existing scanner RPC at baseline
   local beforeTime=os.clock()
   if not sameSession(root,partner) then
    finish("TRADE_CHANGED_DURING_BASELINE",ledger)
    return
   end
   local kind=mods.ledger.before(ledger.instance,own,beforeTime,sc)
   if kind~="OBSERVED" then
    finish("BASELINE_UNVERIFIED",ledger);return
   end
   S.partnerCacheAtBaseline=(their~=nil)
   local handle=mods.observer.new({game=game,players=players,root=root,
      session=id,jobId=job,localUserId=me.UserId,
      partnerUserId=partner.UserId,
      contract=mods.contract,ownInventory=own,
      opponentInventory=their,marketFresh=function()return false end})
   local timeline={module=mods.timeline,instance=mods.timeline.new(id,os.clock())}
   S.census=mods.census.new({session=id},os.clock())
   local observed,why=watchCandidateSignals(root,partner,S.census)
   if not observed then
     finish("CANDIDATE_OBSERVER_UNAVAILABLE:"..tostring(why),ledger,timeline)
     return
   end
   S.awaitReason="BOUND"
   S.state="OBSERVING_CLOSE"
   print("[GINGERSCOPE STAGE59] OWN BASELINE + CLIENT SIGNALS BOUND. Opponent cache present="..tostring(S.partnerCacheAtBaseline).."; if missing, offer identity and accept stability remain unproven. Manual actions only; close within 120s.")
   while E[KEY]==S and game.JobId==job and
       os.clock()-beforeTime<120 do
     local captured,o,diag=pcall(mods.observer.capture,handle)
     if not captured then
       finish("NATIVE_OBSERVER_EXCEPTION",ledger,timeline);return
     end
     local kind=mods.timeline.ingest(timeline.instance,o,diag,os.clock())
     if kind=="INVALID" then
       finish("SESSION_SCOPE_CHANGED",ledger,timeline);return
     end
     if kind=="CLOSED_UNKNOWN" then
       local now=os.clock()
       local stage=mods.ledger.close(ledger.instance,kind,now,sc)
       if stage=="OBSERVED" then
         mods.census.closed(S.census,kind,now)
       end
       if stage~="OBSERVED" then
        finish("CLOSE_EVIDENCE_INVALID",ledger,timeline);return
       end
       -- Two independent calls after closure. There is no way to
       -- infer server completion from either call or their agreement.
       S.state="POST_CLOSE_READS"
       for i=2,3 do
        task.wait(i==2 and 1.1 or 1.25)
        if E[KEY]~=S or game.JobId~=job or
           players.LocalPlayer~=me or partner.Parent~=players
           or tradeRoot() then
          finish("SESSION_CHANGED_DURING_POST_READS",ledger,timeline)
          return
        end
        local inventory=readOwn() -- NO retry of an uncertain response
        local t=os.clock()
        local outcome=mods.ledger.after(ledger.instance,inventory,t,sc,i)
        if outcome=="INCOMPLETE" or outcome=="POST_READS_DISAGREE" then
          finish("POST_READBACK_UNVERIFIED",ledger,timeline);return
        end
       end
       finish("TWO_POST_CLOSE_READS_FINISHED",ledger,timeline)
       return
     end
     task.wait(.09)
   end
   finish("TRADE_WINDOW_NOT_CLOSED_WITHIN_120S",ledger,timeline)
   return
  end
  if not root then
   S.awaitReason="NO_VISIBLE_TRADE"
  elseif not partner then
   S.awaitReason="PARTNER_LABEL_UNRESOLVED"
  else
   S.awaitReason="PREPARING_OWN_BASELINE"
  end
  task.wait(.2)
 end
 finish("NO_SCANNED_TRADE_WINDOW_OR_JOB_CHANGED")
end)
return S
