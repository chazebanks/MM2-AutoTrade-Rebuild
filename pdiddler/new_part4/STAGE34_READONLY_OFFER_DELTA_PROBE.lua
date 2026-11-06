-- Gingerscope Stage34: one manual-trade read-only canonical offer/delta probe.
-- Reuses Stage25 scanner + Stage9 native observer + Stage29 owned ledger
-- and Stage34 PURE reconciler. NO Accept/Decline/OfferItem, no webhook or hop.
local E=(getgenv and getgenv()) or _G
local KEY="PDIDDLER_STAGE34_OFFER_INVENTORY_PROBE"
if game.PlaceId~=142823291 then
 warn("[STAGE34] wrong game") return
end
for _,id in ipairs({KEY,
 "PDIDDLER_STAGE32_RESULT_CORRELATION_PROBE",
 "PDIDDLER_STAGE33_TRANSPORT_CENSUS",
 "PDIDDLER_STAGE29_POSTCLOSE_PROBE",
 "PDIDDLER_STAGE30_PASSIVE_SIGNALS",
 "PDIDDLER_STAGE28_PASSIVE_ACCEPT_PROBE",
 "PDIDDLER_STAGE27_NATIVE_LAB",
 "PDIDDLER_GINGERSCOPE_REPLACEMENT_PREVIEW",
 "PDIDDLER_OUTGOING_SESSION","PDIDDLER_PART4_SESSION",
 "PDIDDLER_PART5_CONTROLLER","PDIDDLER_PART4_CONTROLLER",
 "PDIDDLER_INTEGRATION_V15_8_VALUE_FIRST"
}) do
 if E[id]~=nil then
  warn("[STAGE34] competing owner detected: rejoin before testing") return
 end
end
local ROOT="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
local PIN26="a2a2e601be864f970da0a69c436ab3b12efd8112"
local PIN29="06374ead14ce0b18fb05e55c80c2df6a143bf0ce"
local PIN34="ec6fa655deb9e683b12a072225b24bb6a01e7598"
local players=game:GetService("Players")
local me=players.LocalPlayer
if not me then warn("[STAGE34] player not ready") return end
local job=game.JobId
local S={state="BOOTING_READ_ONLY",reportReady=false,
 authorizesTrade=false,authorizesAccept=false,
 serverCompletionProven=false,mayRecordCompletedTrade=false,
 mayReportProfit=false}
E[KEY]=S
local function source(pin,name)
 local src=game:HttpGet(ROOT..pin.."/pdiddler/new_part4/"..name..".lua",true)
 assert(type(src)=="string" and #src>70,"module unavailable")
 local run,why=loadstring(src,"="..name)
 assert(run,why)
 local mod=run()
 assert(type(mod)=="table","loaded module invalid")
 return mod
end
local function finish(reason,match,ledger)
 if S.reportReady then return end
 S.reportReady=true;S.state="FINISHED_READ_ONLY"
 local r=match and match.module.evaluate(match.instance,
    ledger and ledger.instance or nil,match.scope) or {
    schema="gingerscope-stage34-client-offer-delta-reconciliation-v1",
    status="INCOMPLETE",reason="no-bound-offer-and-ledger-session",
    tradeOutcome="UNKNOWN",readOnly=true,
    authorizesAccept=false,authorizesTrade=false,
    mayRecordCompletedTrade=false,mayReportProfit=false,
    serverCompletionProven=false}
 r.stopReason=reason
 r.nativeAcceptanceNotControlled=true
 r.readOnly=true;r.tradeOutcome="UNKNOWN"
 r.serverAttestation=false;r.serverCompletionProven=false
 r.causalAttributionProven=false;r.authorizesTrade=false
 r.authorizesAccept=false;r.mayRecordCompletedTrade=false
 r.mayReportProfit=false
 local ok,j=pcall(function()
  return game:GetService("HttpService"):JSONEncode(r)
 end)
 S.result=r
 if ok then
  if type(setclipboard)=="function" then pcall(setclipboard,j) end
  print("[GINGERSCOPE STAGE34 ANONYMIZED] "..j)
 else
  warn("[STAGE34] JSON output unavailable; no trade action performed")
 end
end
local loaded,mods=pcall(function()
 return {observer=source(PIN26,"p4_native_observer"),
  contract=source(PIN26,"p4_observer_contract"),
  ledger=source(PIN29,"p4_stage29_postclose_ledger"),
  compare=source(PIN34,"p4_stage34_offer_delta_reconcile")}
end)
if not loaded then
 finish("READ_ONLY_MODULES_UNAVAILABLE")
 return S
end
local scannerOwner=E.PDIDDLER_STAGE25_SCANNER_ONLY
if not scannerOwner then
 E.PDIDDLER_ALLOW_SCANNER_ONLY_TEST=true
 local ok,created=pcall(function()
  local code=game:HttpGet(ROOT..PIN26..
   "/pdiddler/new_part4/STAGE25_SCANNER_ONLY_BOOT.lua",true)
  return assert(loadstring(code,"=stage25-scanner-only"))()
 end)
 if not ok then finish("STAGE25_SCANNER_START_FAILED");return S end
 scannerOwner=created
end
if type(scannerOwner)~="table" or
  scannerOwner.status~="SCANNER_ONLY_NO_TRADE_AUTHORITY" or
  type(scannerOwner.rawScanner)~="table" then
 finish("SCANNER_NOT_READY_OR_COMPETING_OWNER");return S
end
local scanner=scannerOwner.rawScanner
if type(scanner.getOwnInventory)~="function" or
 type(scanner.getRecord)~="function" or
 type(scanner.getVerificationState)~="function" then
 finish("SCANNER_APIS_MISSING");return S
end
local function visible(node,stop)
 while node do
  if node:IsA("ScreenGui") and not node.Enabled then return false end
  if node:IsA("GuiObject") and not node.Visible then return false end
  if node==stop then return true end
  node=node.Parent
 end
 return false
end
local function tradeRoot()
 local pg=me:FindFirstChildOfClass("PlayerGui")
 if not pg then return nil end
 for _,name in ipairs({"TradeGUI_Phone","TradeGUI"}) do
  local gui=pg:FindFirstChild(name)
  local container=gui and gui:FindFirstChild("Container")
  local root=container and container:FindFirstChild("Trade")
  if root and visible(root,pg) then return root end
 end
end
local function partnerFor(root)
 local their=root and root:FindFirstChild("TheirOffer")
 local label=their and their:FindFirstChild("Username")
 local name=label and tostring(label.Text or "") or ""
 name=(name:match("^%s*%((.-)%)%s*$") or name):gsub("^@","")
 name=name:gsub("^%s+",""):gsub("%s+$","")
 if name=="" then return nil end
 for _,p in ipairs(players:GetPlayers()) do
  if p~=me and p.Parent==players and p.Name:lower()==name:lower() then
   return p
  end
 end
end
local function partnerInventory(p)
 if not p then return nil end
 local ok,rec=pcall(scanner.getRecord,p.UserId)
 local verified,state=pcall(scanner.getVerificationState,p.UserId)
 if not ok or not verified or type(rec)~="table" or
    type(state)~="table" or rec.player~=p or
    state.player~=p or state.record~=rec or
    state.scanning==true or state.retryScheduled==true or
    type(rec.inv)~="table" or type(rec.scanProof)~="table" or
    rec.scanProof.jobId~=job or
    rec.scanProof.playerUserId~=p.UserId or
    rec.scanProof.fingerprint~=rec.inv.fingerprint or
    type(rec.scanProof.completedAtMono)~="number" or
    os.clock()<rec.scanProof.completedAtMono or
    os.clock()-rec.scanProof.completedAtMono>30 then
  return nil
 end
 return rec.inv
end
local function readOwn()
 local ok,inv,why=pcall(scanner.getOwnInventory)
 if not ok or why or type(inv)~="table" then return nil end
 return inv
end
local function sameContext(root,partner)
 return E[KEY]==S and game.JobId==job and
   players.LocalPlayer==me and partner.Parent==players and
   root==tradeRoot()
end
local function sc(session,partner)
 return {session=session,jobId=job,
  accountId=me.UserId,partnerId=partner.UserId}
end
S.state="WAIT_MANUAL_TRADE"
print("[GINGERSCOPE STAGE34] READ-ONLY. Open ONE manual trade if you choose; no script clicks or item moves.")
task.spawn(function()
 local started=os.clock()
 while not S.reportReady and E[KEY]==S and
  game.JobId==job and os.clock()-started<120 do
  local root=tradeRoot()
  local partner=partnerFor(root)
  local partnerInv=partner and partnerInventory(partner)
  if root and partner and partnerInv then
   local bound=sc("stage34:"..tostring(os.clock()),partner)
   local ledger={module=mods.ledger,
     instance=mods.ledger.new(bound,os.clock(),
       {maxBeforeToClose=30,minPostGap=.75,maxPostAge=30})}
   local own=readOwn()
   local t=os.clock()
   if not sameContext(root,partner) then
    finish("BASELINE_SCOPE_CHANGED",nil,ledger);return
   end
   if mods.ledger.before(ledger.instance,own,t,bound)~="OBSERVED" then
    finish("OWN_INVENTORY_BASELINE_INVALID",nil,ledger);return
   end
   local match={module=mods.compare,scope=bound,
    instance=mods.compare.new(bound,os.clock(),
     {minStableGap=.15,maxCloseLag=.45})}
   local observer=mods.observer.new({
    game=game,players=players,root=root,
    session=bound.session,jobId=job,localUserId=me.UserId,
    partnerUserId=partner.UserId,contract=mods.contract,
    ownInventory=own,opponentInventory=partnerInv,
    marketFresh=function()return false end})
   S.state="OBSERVING_SCOPED_OFFERS"
   print("[GINGERSCOPE STAGE34] BASELINE + CANONICAL OFFER OBSERVER BOUND. Manual trade only; close within 30s.")
   while not S.reportReady and E[KEY]==S and
     game.JobId==job and os.clock()-t<30 do
    if partner.Parent~=players or players.LocalPlayer~=me then
     finish("PARTNER_OR_ACCOUNT_CHANGED",match,ledger);return
    end
    local current=tradeRoot()
    if current and current~=root then
     finish("BOUND_TRADE_ROOT_CHANGED",match,ledger);return
    end
    local ok,o,diag=pcall(mods.observer.capture,observer)
    if not ok or type(o)~="table" or type(diag)~="table" then
     finish("NATIVE_OBSERVER_EXCEPTION",match,ledger);return
    end
    local now=os.clock()
    if o.tradeOpen==false then
     if current then
      finish("GUI_CLOSE_SCOPE_UNVERIFIED",match,ledger);return
     end
     local done=mods.compare.close(match.instance,now,bound)
     local closed=mods.ledger.close(ledger.instance,
       "CLOSED_UNKNOWN",now,bound)
     if done~="CLOSED_UNKNOWN" or closed~="OBSERVED" then
      finish("STABLE_FINAL_OFFERS_OR_CLOSE_UNVERIFIED",match,ledger)
      return
     end
     S.state="POST_CLOSE_READBACKS"
     for sequence=2,3 do
      task.wait(sequence==2 and 1.1 or 1.25)
      if E[KEY]~=S or game.JobId~=job or
        players.LocalPlayer~=me or partner.Parent~=players
        or tradeRoot() then
       finish("POST_CLOSE_SESSION_CHANGED",match,ledger);return
      end
      local inv=readOwn()
      local checked=mods.ledger.after(
        ledger.instance,inv,os.clock(),bound,sequence)
      if checked=="INCOMPLETE" or checked=="POST_READS_DISAGREE" then
       finish("POST_CLOSE_READBACKS_UNVERIFIED",match,ledger);return
      end
     end
     finish("TWO_POST_CLOSE_OWN_READS_FINISHED",match,ledger)
     return
    end
    if o.tradeOpen~=true then
     finish("TRADE_OPEN_STATE_UNKNOWN",match,ledger);return
    end
    local status=mods.compare.observe(match.instance,o,diag,now,bound)
    if status=="INCOMPLETE" then
     finish("CANONICAL_OFFER_CONTEXT_INVALID",match,ledger);return
    end
    task.wait(.09)
   end
   finish("TRADE_WINDOW_NOT_CLOSED_WITHIN_30S",match,ledger)
   return
  end
  task.wait(.2)
 end
 finish("NO_VERIFIED_SCOPED_MANUAL_TRADE_WINDOW")
end)
return S
