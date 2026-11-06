-- Stage30: ONE manual MM2 trade, read-only native client-signal census.
-- Never sends RemoteEvents/RemoteFunctions or clicks GUI trade controls.
-- Captures ONLY sanitized event names, occurrence times, and partner departure.
-- Remote names or GUI closure NEVER establish authenticated completion.
local E=(getgenv and getgenv()) or _G
local KEY="PDIDDLER_STAGE30_PASSIVE_SIGNALS"
if game.PlaceId~=142823291 then warn("[STAGE30] Not in MM2") return end
for _,k in ipairs({KEY,"PDIDDLER_STAGE29_POSTCLOSE_PROBE",
 "PDIDDLER_STAGE28_PASSIVE_ACCEPT_PROBE","PDIDDLER_STAGE27_NATIVE_LAB",
 "PDIDDLER_GINGERSCOPE_REPLACEMENT_PREVIEW",
 "PDIDDLER_PART4_SESSION","PDIDDLER_OUTGOING_SESSION",
 "PDIDDLER_PART5_CONTROLLER","PDIDDLER_INTEGRATION_V15_8_VALUE_FIRST"}) do
 if E[k]~=nil then warn("[STAGE30] Other session active; rejoin first") return end
end
local repo="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
local S26="a2a2e601be864f970da0a69c436ab3b12efd8112"
local S28="800ec9aa5f38b7d06e3af1bbf492dfd79ade3951"
local S30="b18ea4ff12bc68798ccc61dd2cd14edfc337d056"
local players=game:GetService("Players")
local me=assert(players.LocalPlayer,"local player not ready")
local job=game.JobId
local S={phase="STARTING",done=false,connections={},
   reportOnly=true,authorizesAccept=false,serverCompletionProven=false}
E[KEY]=S
local function import(commit,name)
 local url=repo..commit.."/pdiddler/new_part4/"..name..".lua"
 local src=game:HttpGet(url,true)
 assert(type(src)=="string" and #src>40,"module unavailable")
 local fn,err=loadstring(src,"="..name);assert(fn,err)
 local out=fn();assert(type(out)=="table","module invalid")
 return out
end
local function disconnect()
 for _,c in ipairs(S.connections) do
   pcall(function()c:Disconnect()end)
 end
 S.connections={}
end
local function report(reason)
 if S.done then return end
 S.done=true;disconnect()
 local signals=S.signals and S.signalCore.summary(S.signals) or {
   schema="gingerscope-stage30-client-trade-signal-census-v1",
   status="INCOMPLETE",catalogRemoteEvents=0,
   catalogNames={},signalReceipts=0,signals={},
   tradeOutcome="UNKNOWN"}
 local acceptance=S.timeline and S.timelineCore.summary(S.timeline) or {}
 signals.probeStopReason=reason
 signals.observedTheirAccept=acceptance.theirAcceptIndicatorEverVisible==true
 signals.observedOurAccept=acceptance.ourAcceptIndicatorEverVisible==true
 signals.bothAcceptedStableObserved=acceptance.bothAcceptedStableObserved==true
 signals.observerClosureStatus=acceptance.closureStatus or "not-observed"
 signals.unknownCompletionEvidence=true
 signals.authorizesTrade=false
 signals.authorizesAccept=false
 signals.serverAttestation=false
 signals.serverCompletionProven=false
 signals.mayRecordCompletedTrade=false
 signals.mayReportProfit=false
 local ok,encoded=pcall(function()
  return game:GetService("HttpService"):JSONEncode(signals)
 end)
 if ok then
  if type(setclipboard)=="function" then pcall(setclipboard,encoded)end
  print("[GINGERSCOPE STAGE30 ANONYMIZED] "..encoded)
 else warn("[STAGE30] JSON encoding failed; no trade actions")end
 S.result=signals;S.phase="FINISHED_READ_ONLY"
end
local ok,mods=pcall(function()
 return {observer=import(S26,"p4_native_observer"),
   contract=import(S26,"p4_observer_contract"),
   timeline=import(S28,"p4_stage28_accept_timeline"),
   census=import(S30,"p4_stage30_client_signal_census")}
end)
if not ok then report("MODULES_UNAVAILABLE");return S end
S.timelineCore=mods.timeline;S.signalCore=mods.census
local owner=E.PDIDDLER_STAGE25_SCANNER_ONLY
if not owner then
 E.PDIDDLER_ALLOW_SCANNER_ONLY_TEST=true
 local booted,value=pcall(function()
  local src=game:HttpGet(repo..S26..
   "/pdiddler/new_part4/STAGE25_SCANNER_ONLY_BOOT.lua",true)
  return assert(loadstring(src,"=stage25-readonly"))()
 end)
 if not booted then report("SCANNER_START_FAILED");return S end
 owner=value
end
if type(owner)~="table" or
 owner.status~="SCANNER_ONLY_NO_TRADE_AUTHORITY"
 or type(owner.rawScanner)~="table" then
 report("SCANNER_NOT_READY");return S
end
local scanner=owner.rawScanner
local function visible(node,stop)
 while node do
  if node:IsA("ScreenGui") and node.Enabled~=true then return false end
  if node:IsA("GuiObject") and node.Visible~=true then return false end
  if node==stop then return true end
  node=node.Parent
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
local function partnerOf(root)
 local side=root and root:FindFirstChild("TheirOffer")
 local node=side and side:FindFirstChild("Username")
 local raw=node and tostring(node.Text or "") or ""
 local name=(raw:match("^%s*%((.-)%)%s*$") or raw):gsub("^@","")
 name=name:gsub("^%s+",""):gsub("%s+$","")
 if name=="" then return nil end
 for _,p in ipairs(players:GetPlayers()) do
  if p~=me and p.Parent==players and p.Name:lower()==name:lower() then
   return p
  end
 end
end
local function verifiedOpponent(p)
 if not p then return nil end
 local read,rec=pcall(scanner.getRecord,p.UserId)
 local verify,state=pcall(scanner.getVerificationState,p.UserId)
 if not read or not verify or type(rec)~="table"
  or type(state)~="table" or state.record~=rec or rec.player~=p
  or state.scanning==true or state.retryScheduled==true
  or type(rec.inv)~="table" or type(rec.scanProof)~="table"
  or rec.scanProof.jobId~=job or
  rec.scanProof.playerUserId~=p.UserId
  or rec.scanProof.fingerprint~=rec.inv.fingerprint
  or type(rec.scanProof.completedAtMono)~="number"
  or os.clock()<rec.scanProof.completedAtMono
  or os.clock()-rec.scanProof.completedAtMono>30 then return nil end
 return rec.inv
end
local function readOwn()
 local valid,inv,why=pcall(scanner.getOwnInventory)
 if not valid or why or type(inv)~="table" then return nil end
 return inv
end
local function watchRemotes(census,partner)
 -- Only evidence source that existing MM2 scripts establish:
 -- ReplicatedStorage.Trade. No global hooks or event payload capture.
 local rs=game:GetService("ReplicatedStorage")
 local folder=rs:FindFirstChild("Trade")
 if not folder then return false,"TRADE_REMOTE_FOLDER_NOT_FOUND" end
 local all=folder:GetDescendants()
 local named,keys={},{}
 for _,node in ipairs(all) do
  if node:IsA("RemoteEvent") then
   local n=node.Name
   if type(n)~="string" or #n==0 or #n>48
      or not n:match("^[%w_%-]+$") or keys[n] then
    return false,"REMOTE_NAMES_AMBIGUOUS"
   end
   keys[n]=node
   named[#named+1]=n
   if #named>32 then return false,"REMOTE_LISTENER_LIMIT" end
  end
 end
 table.sort(named)
 local catalog,why=mods.census.catalog(census,named,os.clock())
 if not catalog then return false,why end
 for _,name in ipairs(named) do
  local remote=keys[name]
  local okConn,conn=pcall(function()
   return remote.OnClientEvent:Connect(function()
    if S.done or game.JobId~=job or players.LocalPlayer~=me then return end
    if partner.Parent~=players then return end
    -- Nothing reads or logs any event arguments; only local delivery.
    mods.census.received(census,name,os.clock())
   end)
  end)
  if not okConn or not conn then return false,"REMOTE_LISTENER_BIND_FAILED" end
  S.connections[#S.connections+1]=conn
 end
 local okLeft,connection=pcall(function()
  return players.PlayerRemoving:Connect(function(p)
   if not S.done and p==partner then
     mods.census.partnerDeparture(census,os.clock())
   end
  end)
 end)
 if not okLeft or not connection then return false,"PARTNER_DEPARTURE_BIND_FAILED" end
 S.connections[#S.connections+1]=connection
 return true,"READ_ONLY_CATALOG_BOUND"
end
S.phase="AWAIT_MANUAL_TRADE"
print("[GINGERSCOPE STAGE30] PASSIVE only. Open manual trade, then close it. No Accept needed.")
task.spawn(function()
 local started=os.clock()
 while not S.done and game.JobId==job and os.clock()-started<120 do
  local root=tradeRoot()
  local partner=partnerOf(root)
  local their=partner and verifiedOpponent(partner)
  if root and partner and their then
   local own=readOwn()
   if not own or root~=tradeRoot() or game.JobId~=job then
     report("BOUND_TRADE_CHANGED_DURING_READ");return
   end
   local session="stage30:"..tostring(started)
   S.timeline=mods.timeline.new(session,os.clock())
   S.signals=mods.census.new({session=session},os.clock())
   local handle=mods.observer.new({game=game,players=players,
    root=root,session=session,jobId=job,
    partnerUserId=partner.UserId,localUserId=me.UserId,
    contract=mods.contract,ownInventory=own,
    opponentInventory=their,marketFresh=function()return false end})
   local bound,bindWhy=watchRemotes(S.signals,partner)
   if not bound then
    report("REMOTE_CENSUS_UNAVAILABLE:"..tostring(bindWhy));return
   end
   S.phase="OBSERVING_NATIVE_CLIENT_SIGNALS"
   print("[GINGERSCOPE STAGE30] TRADE BOUND. Close manually within 30s. No Accept.")
   local untilTime=os.clock()+30
   while not S.done and game.JobId==job and os.clock()<untilTime do
    local okCapture,o,d=pcall(mods.observer.capture,handle)
    if not okCapture then report("NATIVE_CAPTURE_FAILED");return end
    local kind=mods.timeline.ingest(S.timeline,o,d,os.clock())
    if kind=="INVALID" then
     mods.census.finish(S.signals,"SESSION_CHANGED",os.clock())
     report("SCOPE_INVALID");return
    end
    if kind=="CLOSED_UNKNOWN" then
      mods.census.closed(S.signals,kind,os.clock())
      task.wait(2.1) -- bounded post-closure signal observation only
      mods.census.finish(S.signals,"OBSERVATION_FINISHED",os.clock())
      report("CLOSE_AND_SIGNAL_GRACE_FINISHED");return
    end
    task.wait(.09)
   end
   mods.census.finish(S.signals,"WINDOW_TIMED_OUT",os.clock())
   report("BOUND_TRADE_NOT_CLOSED_WITHIN_30S");return
  end
  task.wait(.2)
 end
 report("NO_VERIFIED_TRADE_OR_SERVER_CHANGED")
end)
return S
