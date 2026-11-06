-- Gingerscope Stage29: CLIENT-ONLY inventory evidence after manual close.
-- It NEVER sends a trade request, places or removes an item, presses Accept,
-- presses Decline, server hops, computes profit or sends Discord messages.
-- All three own-inventory reads reuse Stage25's existing GetProfileData reader.
-- A client inventory difference is never attributed to this trade.
local E=(getgenv and getgenv()) or _G
local KEY="PDIDDLER_STAGE29_POSTCLOSE_PROBE"
if game.PlaceId~=142823291 then
 warn("[STAGE29] Wrong game; no action") return
end
for _,id in ipairs({KEY,"PDIDDLER_STAGE28_PASSIVE_ACCEPT_PROBE",
  "PDIDDLER_STAGE27_NATIVE_LAB","PDIDDLER_GINGERSCOPE_REPLACEMENT_PREVIEW",
  "PDIDDLER_OUTGOING_SESSION","PDIDDLER_PART4_SESSION",
  "PDIDDLER_PART5_CONTROLLER","PDIDDLER_INTEGRATION_V15_8_VALUE_FIRST"}) do
 if E[id]~=nil then
  warn("[STAGE29] Another test or trading owner detected; rejoin before use")
  return
 end
end
local ROOT="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
local STAGE26="a2a2e601be864f970da0a69c436ab3b12efd8112"
local STAGE28="800ec9aa5f38b7d06e3af1bbf492dfd79ade3951"
local STAGE29="06374ead14ce0b18fb05e55c80c2df6a143bf0ce"
local players=game:GetService("Players")
local me=assert(players.LocalPlayer,"player not ready")
local job=game.JobId
local S={state="BOOTING_READ_ONLY",reportReady=false,job=job,
 authorizesTrade=false,authorizesAccept=false,
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
 local data={schema="gingerscope-stage29-client-outcome-probe-v1",
   status=l.status,reason=l.reason,stopReason=reason,
   readbackCalls=l.readbackCalls,
   beforeObserved=l.beforeObserved,
   postReadbacksObserved=l.postReadbacksObserved,
   changedEligibleTypes=l.changedEligibleTypes,
   gainedEligibleCopies=l.gainedEligibleCopies,
   lostEligibleCopies=l.lostEligibleCopies,
   rawWeaponInventoryChanged=l.rawWeaponInventoryChanged,
   windowClosureObserved=l.windowClosureObserved,
   observedTheirAccept=t.theirAcceptIndicatorEverVisible==true,
   observedOurAccept=t.ourAcceptIndicatorEverVisible==true,
   offerMutationAfterAccept=t.offerMutationAfterAccept==true,
   closureStatus=t.closureStatus,
   tradeOutcome="UNKNOWN",readOnly=true,
   sourceType="client-GetProfileData-and-Stage9-GUI",
   serverAttestation=false,serverCompletionProven=false,
   authorizesTrade=false,authorizesAccept=false,
   mayRecordCompletedTrade=false,mayReportProfit=false}
 local ok,json=pcall(function()
   return game:GetService("HttpService"):JSONEncode(data)
 end)
 if ok then
  if type(setclipboard)=="function" then pcall(setclipboard,json) end
  print("[GINGERSCOPE STAGE29 ANONYMIZED] "..json)
 else
  warn("[STAGE29] JSON output unavailable; no trade actions")
 end
 S.result=data
end
local loaded,mods=pcall(function()
 return {observer=source(STAGE26,"p4_native_observer"),
   contract=source(STAGE26,"p4_observer_contract"),
   timeline=source(STAGE28,"p4_stage28_accept_timeline"),
   ledger=source(STAGE29,"p4_stage29_postclose_ledger")}
end)
if not loaded then
 S.state="MODULES_UNAVAILABLE";finish("READ_ONLY_MODULE_LOAD_FAILED")
 return S
end
local scannerOwner=E.PDIDDLER_STAGE25_SCANNER_ONLY
if not scannerOwner then
 E.PDIDDLER_ALLOW_SCANNER_ONLY_TEST=true
 local ok,owner=pcall(function()
  local src=game:HttpGet(ROOT..STAGE26..
    "/pdiddler/new_part4/STAGE25_SCANNER_ONLY_BOOT.lua",true)
  return assert(loadstring(src,"=stage25-scanner-only"))()
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
S.state="AWAIT_MANUAL_TRADE"
print("[GINGERSCOPE STAGE29] Read-only. Open a trade, let the baseline scan complete, then close manually; NEVER Accept.")
task.spawn(function()
 local start=os.clock()
 while E[KEY]==S and game.JobId==job and os.clock()-start<120 do
  local root=tradeRoot()
  local partner=partnerFor(root)
  local their=partner and partnerInventory(partner)
  if root and partner and their then
   local id="stage29:"..tostring(start)
   local sc=scope(id,partner)
   local ledger={module=mods.ledger,
     instance=mods.ledger.new(sc,os.clock(),{maxBeforeToClose=30,minPostGap=.75,maxPostAge=30})}
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
   local handle=mods.observer.new({game=game,players=players,root=root,
      session=id,jobId=job,localUserId=me.UserId,
      partnerUserId=partner.UserId,
      contract=mods.contract,ownInventory=own,
      opponentInventory=their,marketFresh=function()return false end})
   local timeline={module=mods.timeline,instance=mods.timeline.new(id,os.clock())}
   S.state="OBSERVING_CLOSE"
   print("[GINGERSCOPE STAGE29] BASELINE VERIFIED. Close the trade manually within 30s; do NOT Accept.")
   while E[KEY]==S and game.JobId==job and
       os.clock()-beforeTime<30 do
     local captured,o,diag=pcall(mods.observer.capture,handle)
     if not captured then
       finish("NATIVE_OBSERVER_EXCEPTION",ledger,timeline);return
     end
     local kind=mods.timeline.ingest(timeline.instance,o,diag,os.clock())
     if kind=="INVALID" then
       finish("SESSION_SCOPE_CHANGED",ledger,timeline);return
     end
     if kind=="CLOSED_UNKNOWN" then
       local stage=mods.ledger.close(ledger.instance,kind,os.clock(),sc)
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
   finish("TRADE_WINDOW_NOT_CLOSED_WITHIN_30S",ledger,timeline)
   return
  end
  task.wait(.2)
 end
 finish("NO_SCANNED_TRADE_WINDOW_OR_JOB_CHANGED")
end)
return S
