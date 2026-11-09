-- Stage88 ONE-SHOT CONTACT-ONLY live scanner preview.
-- This is NOT the replacement trader: no P3 outgoing physical requests, P4,
-- P5 hopping, Add/Remove/Accept/Decline, price quotes or Discord.
-- Executable Roblox client diagnostic only after separate manual arming.
local E=(type(getgenv)=="function" and getgenv()) or _G
local KEY="GINGERSCOPE_STAGE88_CONTACT_READONLY_PREVIEW"
local SCHEMA="gingerscope-stage88-contact-readonly-preview-v1"
if E.PDIDDLER_STAGE88_CONTACT_READONLY_ARMED~=true then
 warn("[STAGE88] NOT ARMED: no scanning started")
 return nil
end
if game.PlaceId~=142823291 then
 warn("[STAGE88] WRONG GAME: only original MM2")
 return nil
end
-- Read-only scanner remains installed after stop, so NEVER restart in same job.
if E[KEY]~=nil then
 warn("[STAGE88] already attempted this game session; rejoin before another run")
 return E[KEY]
end
for _,key in ipairs({
 "PDIDDLER_GINGERSCOPE_REPLACEMENT_PREVIEW",
 "PDIDDLER_GINGERSCOPE_CONTACT_ONLY_PREVIEW",
 "PDIDDLER_PART4_SESSION","PDIDDLER_PART4_CONTROLLER",
 "PDIDDLER_OUTGOING_SESSION","PDIDDLER_OUTGOING_CONTROLLER",
 "PDIDDLER_HOPPING_SESSION","PDIDDLER_PART5_CONTROLLER",
 "PDIDDLER_GINGERSCOPE_REPLACEMENT_PREVIEW",
 "PDIDDLER_INTEGRATION_V15_8","PDIDDLER_INTEGRATION_V15_7_INVENTORY_GROWTH",
 "GINGERSCOPE_STAGE83_READONLY_AGGREGATE_COVERAGE"
}) do
 if E[key]~=nil then
  warn("[STAGE88] another scripted client/session observed; fresh rejoin required")
  return nil
 end
end
local OUT={
 schema=SCHEMA,status="STARTING",reason="INITIALIZING",
 readOnly=true,clientOnly=true,contactPreviewOnly=true,
 historicalPublicCoverageAcceptedAsAuthority=false,
 actualSendRequests=0,actualOffers=0,actualAccepts=0,actualDeclines=0,
 actualTeleports=0,serverCompletionProven=false,
 sourcePublisherFresh=false,currentPricesVerified=false,
 numericSupremeCheckerIdVerified=false,authenticatedOwnedInventory=false,
 serverAttestation=false,authorizesTrade=false,authorizesAccept=false,
 mayReportProfit=false,mayRecordCompletedTrade=false,
 maySendDiscordWebhook=false,mayUseForStrategyLearning=false,
 tradeOutcome="UNKNOWN",
 observations=0,reachable=0,unprofitable=0,unknown=0,
 ownContactEvidenceReady=false,elapsedSeconds=0
}
local I={jobId=tostring(game.JobId),running=true,dirty=false,report=OUT}
E[KEY]=I
local started=os.clock()
local Players=game:GetService("Players")
local LP=Players.LocalPlayer
local originalGui=LP and LP:FindFirstChildOfClass("PlayerGui")
local function live()
 return I.running and E[KEY]==I and tostring(game.JobId)==I.jobId
end
local function currentContext()
 if not live() or not LP or LP.Parent~=Players or
    LP:FindFirstChildOfClass("PlayerGui")~=originalGui then
  return false,"job-player-or-gui-changed"
 end
 if E.PDIDDLER_STATUS_OWNER~=nil
    or E.PDIDDLER_OUTGOING_BUSY_SESSION~=nil
    or E.PDIDDLER_PART4_SESSION~=nil
    or E.PDIDDLER_OUTGOING_SESSION~=nil
    or E.PDIDDLER_HOPPING_SESSION~=nil
    or E.PDIDDLER_PART5_CONTROLLER~=nil then
  return false,"another-transaction-or-navigation-owned"
 end
 for _,name in ipairs({"TradeGUI","TradeGUI_Phone"}) do
  local gui=originalGui and originalGui:FindFirstChild(name)
  local container=gui and gui:FindFirstChild("Container")
  local trade=container and container:FindFirstChild("Trade")
  if trade and gui.Enabled~=false and trade.Visible~=false then
   return false,"trade-gui-active"
  end
 end
 return true,"contact-only-safe"
end
local function publish()
 OUT.elapsedSeconds=math.floor(math.max(0,os.clock()-started))
 local ok,encoded=pcall(function()
  return game:GetService("HttpService"):JSONEncode(OUT)
 end)
 if ok and type(encoded)=="string" and #encoded<3000 then
  local line="[GINGERSCOPE STAGE88 CONTACT PREVIEW] "..encoded
  print(line)
  if type(setclipboard)=="function" then pcall(setclipboard,line) end
 else
  warn("[STAGE88] local report serialization unavailable")
 end
end
function I.stop()
 I.running=false
 OUT.status="STOPPED"
 OUT.reason="MANUAL_STOP_SCANNER_REMAINS_INSTALLED_REJOIN_REQUIRED"
 publish()
end
if not LP or not originalGui or not game:IsLoaded() then
 OUT.status="HELD"
 OUT.reason="LOCAL_PLAYER_OR_GAME_NOT_READY"
 I.running=false
 publish()
 return I
end
local ROOT="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
-- The game scanner is the original reviewed Stage51 client code, but no
-- original Stage51 bootstrap, P4, P5, outgoing rotator or Discord is loaded.
local source={
 scanner={"7a289d62ef3f0be0a299506eb451c57435493be3",
          "pdiddler/presentation/pdiddler3_scanner_MODULE_v6_10_CURRENT_PRESENTATION.lua"},
 view={"a00be9c54825b9b91fcfa394dc11d300fcce3575",
       "pdiddler/presentation/pdiddler3_scanner_view_contact_v1.lua"},
 feasibility={"f1a0492ab5959f31be3544bf04ee8a514e09255f",
              "pdiddler/new_part4/P3_ELIGIBILITY_NO_LEGACY_PROFIT.lua"},
 eligibility={"f1a0492ab5959f31be3544bf04ee8a514e09255f",
              "pdiddler/pdiddler3_outgoing_eligibility_v2_SCANNER_EVIDENCE.lua"}
}
local function reviewed(name,...)
 local spec=assert(source[name],"unreviewed-source-name")
 local body=game:HttpGet(ROOT..spec[1].."/"..spec[2],true)
 assert(type(body)=="string" and #body>500,"immutable-source-unavailable")
 local fn,err=loadstring(body,"="..name)
 assert(fn,err)
 local output=fn(...)
 assert(type(output)=="table","immutable-source-invalid")
 return output
end
task.spawn(function()
 local scanner
 local ok,err=xpcall(function()
  local safe,reason=currentContext()
  if not safe then error(reason,0) end
  local view=reviewed("view")
  -- The original scanner presentation understands this "expired/unverified"
  -- profile. Never supply a made-up fresh date or a working price repricer.
  local noQuote={
   version="STAGE88_NO_VERIFIED_QUOTE",
   isFresh=function()return false end,
   liveReady=false
  }
  local strict={reprice=function()return nil,"PRICES_UNVERIFIED_CONTACT_ONLY" end}
  I.dirty=true -- scanner may install listeners even if initialization fails.
  scanner=reviewed("scanner",noQuote,strict,view)
  assert(type(scanner.getVerificationState)=="function" and
         type(scanner.getOwnInventory)=="function" and
         type(scanner.setOutgoingState)=="function" and
         type(scanner.setOutgoingSummary)=="function",
         "scanner-evidence-api-missing")
  local p3=reviewed("feasibility")
  assert(type(p3.validateContactInventory)=="function" and
         type(p3.evaluateContact)=="function","contact-feasibility-api-missing")
  local eligibility=reviewed("eligibility")
  assert(type(eligibility.new)=="function","contact-evidence-controller-missing")
  local contextFn=function()
   local allowed,reason2=currentContext()
   return {job=game.JobId,gui=LP:FindFirstChildOfClass("PlayerGui"),
    outgoing=nil,session=nil,part4Session=nil,transaction=false,
    phase="CONTACT_PREVIEW",activeTarget=nil,
    allowed=allowed,reason=reason2}
  end
  local controller=eligibility.new({
   scanner=scanner,feasibility=p3,profile=noQuote,strict=strict,
   now=os.clock,context=contextFn,
   readOwn=scanner.getOwnInventory,
   render=function(player,state,reason2)
    local safe3=currentContext()
    if not safe3 then return false end
    return scanner.setOutgoingState(player,state,reason2)
   end
  })
  OUT.status="OBSERVING"
  OUT.reason="CONTACT_ONLY_PRICES_UNVERIFIED_NO_REQUESTS"
  local deadline=os.clock()+35
  local observed=false
  while live() and os.clock()<deadline do
   local allowed,holdReason=currentContext()
   if not allowed then
    OUT.status="HELD"
    OUT.reason=holdReason
    break
   end
   local proofReady=controller:refresh(false)
   if proofReady then OUT.ownContactEvidenceReady=true end
   local roster={}
   for _,player in ipairs(Players:GetPlayers()) do
    if player~=LP and player.Parent==Players then roster[#roster+1]=player end
   end
   local result=controller:queue(roster,{})
   OUT.observations=OUT.observations+1
   OUT.reachable=result.counts.reachable
   OUT.unprofitable=result.counts.unprofitable
   OUT.unknown=result.counts.unknown
   scanner.setOutgoingSummary(result.counts)
   observed=true
   task.wait(0.5)
  end
  if not live() then
   OUT.status="HELD"
   OUT.reason="job-player-or-gui-changed"
  elseif OUT.status=="OBSERVING" then
   OUT.status=observed and "CLIENT_CONTACT_READINESS_OBSERVED" or "INCONCLUSIVE"
   OUT.reason=observed and "NO_REQUESTS_PRICES_UNVERIFIED" or "NO_COMPLETE_SCAN"
  end
 end,function(e)return tostring(e)end)
 I.running=false
 if not ok then
  OUT.status="INCONCLUSIVE"
  OUT.reason="INITIALIZATION_OR_SCAN_FAILED"
  warn("[STAGE88] diagnostic failed without request/offer/Accept: "..tostring(err))
 end
 publish()
end)
return I
