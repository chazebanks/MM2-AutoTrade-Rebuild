-- Gingerscope Stage28: PASSIVE native Accept/Close evidence probe.
-- No OfferItem, native click, Accept, Decline, trade request, hop or webhook.
-- Reuses existing Stage25 scanner and Stage9 native observer. The entire
-- output is anonymized client observation; NEVER a completed-trade report.
local E=(getgenv and getgenv()) or _G
local KEY="PDIDDLER_STAGE28_PASSIVE_ACCEPT_PROBE"
if game.PlaceId~=142823291 then
 warn("[STAGE28] Not in MM2; no actions")
 return
end
if E[KEY] or E.PDIDDLER_STAGE27_NATIVE_LAB
  or E.PDIDDLER_GINGERSCOPE_REPLACEMENT_PREVIEW
  or E.PDIDDLER_PART4_SESSION or E.PDIDDLER_OUTGOING_SESSION
  or E.PDIDDLER_PART5_CONTROLLER
  or E.PDIDDLER_INTEGRATION_V15_8_VALUE_FIRST then
 warn("[STAGE28] Another test/trader may be active; rejoin first")
 return
end
local ROOT="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
local STAGE26="a2a2e601be864f970da0a69c436ab3b12efd8112"
local STAGE28="76d5b59f85dc713a9c43893b1572b96bbfafd9d9"
local players=game:GetService("Players")
local localPlayer=assert(players.LocalPlayer,"local player unavailable")
local job=game.JobId
local function import(sha,relative)
 local src=game:HttpGet(ROOT..sha.."/pdiddler/new_part4/"..relative..".lua",true)
 assert(type(src)=="string" and #src>40,"observer module unavailable")
 local fn,err=loadstring(src,"="..relative)
 assert(fn,err)
 local value=fn()
 assert(type(value)=="table","observer module invalid")
 return value
end
local S={status="LOADING_READ_ONLY",job=job,started=os.clock(),
  captured=false,authorizesAccept=false,authorizesTrade=false,
  serverCompletionProven=false,serverAttestation=false}
E[KEY]=S
local function report(reason,timeline)
 if S.captured then return end
 S.captured=true
 local summary=timeline and timeline.module and timeline.module.summary(timeline.state)
   or {
    schema="gingerscope-stage28-acceptance-timeline-v1",
    status=S.status,reason=reason,
    closureStatus="unobserved",serverCompletionProven=false,
    authorizesTrade=false,authorizesAccept=false,
    mayRecordCompletedTrade=false,mayReportProfit=false,
    serverAttestation=false
   }
 summary.statusReason=reason
 summary.observerSource="stage9-client-gui"
 summary.readOnly=true
 summary.tradeCompletionEvidence="NOT_ESTABLISHED"
 summary.authorizesTrade=false
 summary.authorizesAccept=false
 summary.serverCompletionProven=false
 summary.mayRecordCompletedTrade=false
 summary.mayReportProfit=false
 summary.serverAttestation=false
 local ok,json=pcall(function()
   return game:GetService("HttpService"):JSONEncode(summary)
 end)
 if ok then
  if type(setclipboard)=="function" then pcall(setclipboard,json) end
  print("[GINGERSCOPE STAGE28 ANONYMIZED] "..json)
 else warn("[STAGE28] JSON encode unavailable; no trade actions") end
 S.status="FINISHED_READ_ONLY"
 S.result=summary
end
local ok,modules=pcall(function()
 return {contract=import(STAGE26,"p4_observer_contract"),
   native=import(STAGE26,"p4_native_observer"),
   timeline=import(STAGE28,"p4_stage28_accept_timeline")}
end)
if not ok then
 S.status="OBSERVER_SOURCE_UNAVAILABLE"
 report(S.status)
 return S
end
local scannerOwner=E.PDIDDLER_STAGE25_SCANNER_ONLY
if not scannerOwner then
 E.PDIDDLER_ALLOW_SCANNER_ONLY_TEST=true
 local okBoot,boot=pcall(function()
  local src=game:HttpGet(ROOT..STAGE26..
   "/pdiddler/new_part4/STAGE25_SCANNER_ONLY_BOOT.lua",true)
  return assert(loadstring(src,"=stage25-readonly"))()
 end)
 if not okBoot then
  S.status="SCANNER_BOOT_UNAVAILABLE"
  report(S.status)
  return S
 end
 scannerOwner=boot
end
if type(scannerOwner)~="table"
  or scannerOwner.status~="SCANNER_ONLY_NO_TRADE_AUTHORITY"
  or type(scannerOwner.rawScanner)~="table" then
 S.status="SCANNER_NOT_READY"
 report(S.status)
 return S
end
local scanner=scannerOwner.rawScanner
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
 local pg=localPlayer:FindFirstChildOfClass("PlayerGui")
 if not pg then return nil end
 for _,name in ipairs({"TradeGUI_Phone","TradeGUI"}) do
  local screen=pg:FindFirstChild(name)
  local box=screen and screen:FindFirstChild("Container")
  local root=box and box:FindFirstChild("Trade")
  if root and visible(root,pg) then return root end
 end
end
local function partnerOf(root)
 local side=root and root:FindFirstChild("TheirOffer")
 local username=side and side:FindFirstChild("Username")
 local raw=username and tostring(username.Text or "") or ""
 local name=(raw:match("^%s*%((.-)%)%s*$") or raw):gsub("^@","")
 name=name:gsub("^%s+",""):gsub("%s+$","")
 if name=="" then return nil end
 for _,p in ipairs(players:GetPlayers()) do
  if p~=localPlayer and p.Parent==players and
    p.Name:lower()==name:lower() then return p end
 end
end
local function scanPartner(p)
 if not p then return nil end
 local okRec,rec=pcall(scanner.getRecord,p.UserId)
 local okState,state=pcall(scanner.getVerificationState,p.UserId)
 if not okRec or not okState or type(rec)~="table"
  or type(state)~="table" or rec.player~=p
  or type(rec.inv)~="table" or type(rec.scanProof)~="table"
  or state.record~=rec or state.scanning==true
  or state.retryScheduled==true
  or rec.scanProof.jobId~=job or
  rec.scanProof.playerUserId~=p.UserId
  or rec.scanProof.fingerprint~=rec.inv.fingerprint
  or type(rec.scanProof.completedAtMono)~="number"
  or os.clock()-rec.scanProof.completedAtMono<0
  or os.clock()-rec.scanProof.completedAtMono>30 then
  return nil
 end
 return rec.inv
end
local function scanOwn()
 local good,inv,err=pcall(scanner.getOwnInventory)
 if not good or err or type(inv)~="table" or
  type(inv.items)~="table" then
  return {items={},unmapped=1,unpriced=1,badQty=1}
 end
 return inv
end
S.status="AWAITING_MANUAL_TRADE"
print("[GINGERSCOPE STAGE28] PASSIVE acceptance probe ready. Open a manual trade; do NOT press Accept.")
task.spawn(function()
 local started=os.clock()
 while E[KEY]==S and job==game.JobId and os.clock()-started<120 do
  local root=tradeRoot()
  local partner=partnerOf(root)
  local their=partner and scanPartner(partner)
  if root and partner and their then
   -- One own read at bind; no inventory RPC inside the Stage9 polling loop.
   local own=scanOwn()
   if game.JobId~=job or root~=tradeRoot() then
    report("TRADE_CONTEXT_CHANGED_DURING_BIND")
    return
   end
   local session="stage28:"..tostring(started)
   local handle=modules.native.new({game=game,players=players,
      root=root,session=session,jobId=job,
      partnerUserId=partner.UserId,localUserId=localPlayer.UserId,
      contract=modules.contract,ownInventory=own,
      opponentInventory=their,marketFresh=function()return false end})
   local timeline={module=modules.timeline,
       state=modules.timeline.new(session,os.clock())}
   S.status="OBSERVING_ACCEPT_INDICATORS"
   local observing=os.clock()
   while E[KEY]==S and game.JobId==job and
     os.clock()-observing<90 do
    local okCapture,o,diagnostics=pcall(modules.native.capture,handle)
    if not okCapture then
     report("NATIVE_CAPTURE_EXCEPTION",timeline)
     return
    end
    local kind=modules.timeline.ingest(timeline.state,o,diagnostics,os.clock())
    if kind=="INVALID" then
     report("OBSERVATION_SCOPE_INVALID",timeline)
     return
    end
    if kind=="CLOSED_UNKNOWN" then
     report("TRADE_WINDOW_CLOSED_UNKNOWN",timeline)
     return
    end
    task.wait(0.09)
   end
   report("TIMED_OUT_WITHOUT_VERIFIED_CLOSURE",timeline)
   return
  end
  task.wait(0.2)
 end
 report(job~=game.JobId and "SERVER_CHANGED" or "NO_VERIFIED_TRADE_IN_WINDOW")
end)
return S
