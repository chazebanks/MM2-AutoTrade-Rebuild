-- Stage90: one-shot local GUI STRUCTURE ONLY; no game remotes or clicks.
local E=(type(getgenv)=="function" and getgenv()) or _G
local KEY="GINGERSCOPE_STAGE90_CARD_LAYOUT_AUDIT"
local targetName=E.PDIDDLER_STAGE90_TARGET_USERNAME
if E.PDIDDLER_STAGE90_READONLY_ARMED~=true
   or type(targetName)~="string" or
   not targetName:match("^[A-Za-z0-9_]+$") or
   #targetName<3 or #targetName>20 then
 warn("[STAGE90] explicitly arm and set exact test username")
 return nil
end
if game.PlaceId~=142823291 or E[KEY]~=nil then
 warn("[STAGE90] wrong game or already observed in this session")
 return nil
end
for _,name in ipairs({
 "GINGERSCOPE_STAGE89_SINGLE_REQUEST_DIAGNOSTIC",
 "GINGERSCOPE_STAGE88_CONTACT_READONLY_PREVIEW",
 "PDIDDLER_OUTGOING_SESSION","PDIDDLER_OUTGOING_CONTROLLER",
 "PDIDDLER_PART4_SESSION","PDIDDLER_PART4_CONTROLLER",
 "PDIDDLER_HOPPING_SESSION","PDIDDLER_STATUS_OWNER",
 "PDIDDLER_GINGERSCOPE_REPLACEMENT_PREVIEW"
}) do
 if E[name]~=nil then
  warn("[STAGE90] another trade/scan script is in this session; rejoin")
  return nil
 end
end
local R={
 schema="gingerscope-stage90-card-layout-readonly-v1",
 status="INITIALIZING",reason="NOT_OBSERVED",
 readOnly=true,clientOnly=true,
 targetInServer=false,matchedCurrentPlayer=false,
 directPopupVisible=0,directHeaderMatches=0,directHeaderAbsent=0,
 directTradeButtonVisible=0,
 boardCount=0,visibleBoardCount=0,
 alternateTradeControlCount=0,profileTradeCards=0,
 alternativeExactCardTextMatches=0,alternativeNearbyHeaderMatches=0,
 visibleTextNodesInspected=0,layout="NOT_OBSERVED",
 samples=0,elapsedSeconds=0,
 actualRequestTaps=0,actualOffers=0,actualAccepts=0,
 actualDeclines=0,actualTeleports=0,
 priceVerified=false,serverAttestation=false,
 authorizesTrade=false,authorizesAccept=false,
 mayRecordCompletedTrade=false,mayReportProfit=false,
 maySendDiscordWebhook=false,mayUseForStrategyLearning=false,
 tradeOutcome="UNKNOWN"
}
local I={running=true,report=R,jobId=tostring(game.JobId)}
E[KEY]=I
local started=os.clock()
local Players=game:GetService("Players")
local LP=Players.LocalPlayer
local PG=LP and LP:FindFirstChildOfClass("PlayerGui")
local function live()
 return I.running and game.PlaceId==142823291
  and tostring(game.JobId)==I.jobId
  and E[KEY]==I and LP~=nil and PG~=nil
  and LP.Parent==Players and PG.Parent==LP
  and LP:FindFirstChildOfClass("PlayerGui")==PG
end
local function emit(status,reason)
 I.running=false
 R.status=status;R.reason=reason
 R.elapsedSeconds=math.floor(os.clock()-started)
 local ok,text=pcall(function()
  return game:GetService("HttpService"):JSONEncode(R)
 end)
 if ok and type(text)=="string" and #text<3000 then
  local line="[GINGERSCOPE STAGE90 CARD LAYOUT] "..text
  print(line)
  if type(setclipboard)=="function" then pcall(setclipboard,line) end
 else
  warn("[STAGE90] aggregate report unavailable")
 end
 return I
end
if not live() then
 return emit("HELD","CLIENT_SESSION_OR_GUI_UNAVAILABLE")
end
local target=nil
for _,p in ipairs(Players:GetPlayers()) do
 if p~=LP and p.Parent==Players and type(p.Name)=="string"
    and p.Name:lower()==targetName:lower() then
  if target then return emit("HELD","AMBIGUOUS_TARGET_USERNAME") end
  target=p
 end
end
if not target or Players:GetPlayerByUserId(target.UserId)~=target then
 return emit("HELD","TARGET_NOT_IN_CURRENT_SERVER")
end
R.targetInServer=true
R.matchedCurrentPlayer=true
-- Historical original v18 sender has two supported GUI structures; audit
-- which is present WITHOUT enabling the fallback for clicking.
local ROOT="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/14fefa245f0e3b72303f72b93101dd9b773e5e7d/"
local ok,source=pcall(function()
 return game:HttpGet(ROOT.."pdiddler/intelligence_lab/stage90_card_layout_readonly.lua",true)
end)
if not ok or type(source)~="string" or #source<2500 or not live() then
 return emit("INCONCLUSIVE","PINNED_READONLY_LAYOUT_MODULE_UNAVAILABLE")
end
local fn,err=loadstring(source,"=stage90-readonly-layout")
if not fn then return emit("INCONCLUSIVE","READONLY_LAYOUT_MODULE_SYNTAX") end
local loaded,inspector=pcall(fn)
if not loaded or type(inspector)~="table" or
   type(inspector.inspect)~="function" then
 return emit("INCONCLUSIVE","READONLY_LAYOUT_MODULE_INVALID")
end
-- Allow time to open the player card AFTER invoking Delta, since opening
-- an executor overlay may dismiss an already-open MM2 popup on iPad.
local deadline=os.clock()+20
local best=nil
local matches={"DIRECT_POPUP_HEADER_MATCH","ALTERNATIVE_CARD_CONTAINS_EXACT_USERNAME","SIBLING_USERNAME_NEAR_PROFILE_TRADE"}
while live() and os.clock()<deadline do
 if Players:GetPlayerByUserId(target.UserId)~=target then
  return emit("HELD","TARGET_INSTANCE_CHANGED")
 end
 local safe,record=pcall(inspector.inspect,PG,target.Name)
 if not safe or type(record)~="table" then
  return emit("INCONCLUSIVE","GUI_INSPECTION_FAILED")
 end
 R.samples=R.samples+1
 -- Never transmit any usernames, GUI object refs, absolute coordinates
 -- or text extracted from a player card.
 for _,name in ipairs({
  "boardCount","visibleBoardCount","directPopupVisible",
  "directHeaderAbsent","directTradeButtonVisible","directHeaderMatches",
  "alternateTradeControlCount","profileTradeCards",
  "alternativeExactCardTextMatches","alternativeNearbyHeaderMatches",
  "visibleTextNodesInspected"
 }) do
  if type(record[name])~="number" or record[name]<0 or record[name]>12000 then
   return emit("INCONCLUSIVE","INVALID_AGGREGATE_LAYOUT_VALUE")
  end
  R[name]=math.max(R[name] or 0,record[name])
 end
 if record.layout=="DIRECT_POPUP_HEADER_MATCH" or
    record.layout=="ALTERNATIVE_CARD_CONTAINS_EXACT_USERNAME" or
    record.layout=="SIBLING_USERNAME_NEAR_PROFILE_TRADE" then
  R.layout=record.layout
  break
 end
 R.layout=record.layout
 task.wait(0.2)
end
if not live() then return emit("HELD","SESSION_CHANGED_AFTER_INSPECTION") end
local found=R.layout=="DIRECT_POPUP_HEADER_MATCH" or
 R.layout=="ALTERNATIVE_CARD_CONTAINS_EXACT_USERNAME" or
 R.layout=="SIBLING_USERNAME_NEAR_PROFILE_TRADE"
return emit(found and "CARD_LAYOUT_OBSERVED" or "CARD_LAYOUT_UNRESOLVED",
 found and "LOCAL_GUI_STRUCTURE_ONLY_NO_REQUEST" or "NO_EXACT_CARD_LAYOUT_SEEN")
