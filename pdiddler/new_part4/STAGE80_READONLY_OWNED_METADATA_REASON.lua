-- Stage80 SINGLE one-shot, read-only Owned metadata reason probe on MAIN iPad.
-- Answers ONE question: was the Stage79 rejected entry a valid Misc item,
-- incomplete source metadata or an unsafe category (aggregate counts only)?
-- NEVER enter a trade, offer, accept, decline, hop, price or run P4/Discord.
-- No weapon names/raw keys/profile/JobId/username are printed or copied.
local MARK="[GINGERSCOPE STAGE80 METADATA REASON] "
local KEY="GINGERSCOPE_STAGE80_ONE_METADATA_REASON_PROBE"
local PIN="d5d6cc9cbe52beb105766e0590529da6d2075794"
local URL="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"..
  PIN.."/pdiddler/intelligence_lab/stage80_owned_metadata_reason.lua"
local E=(type(getgenv)=="function" and getgenv()) or _G
local job=tostring(game and game.JobId or "")
if E[KEY]~=nil then
 warn("[STAGE80] already run in this game session; rejoin before another diagnostic")
 return E[KEY]
end
local R={
 schema="gingerscope-stage80-owned-catalogue-field-reasons-v1",
 status="INITIALIZING",reason="NOT_OBSERVED",
 readOnly=true,clientOnly=true,tradeOutcome="UNKNOWN",
 originalOwnedTypesObserved=false,metadataReasonsObserved=false,
 authenticatedOwnedInventory=false,serverAttestation=false,
 serverCompletionProven=false,rawToSupremeCheckerVerified=false,
 sourcePublisherFresh=false,currentPricesVerified=false,
 authorizesTrade=false,authorizesAccept=false,mayReportProfit=false,
 mayRecordCompletedTrade=false,mayRecordRejectedTrade=false,
 maySendDiscordWebhook=false,mayUseForStrategyLearning=false,
 ownedKeys=0,ownedCopies=0,stringKeyCount=0,numericKeyCount=0,otherKeyCount=0,
 invalidQuantityKeys=0,missingCatalogueKeys=0,untrustedMetadataKeys=0,
 missingNameKeys=0,missingTypeKeys=0,missingRarityKeys=0,
 miscKeys=0,miscCopies=0,unknownItemTypeKeys=0,
 invalidChromaTypeKeys=0,chromaRarityConflictKeys=0,
 weaponKeys=0,weaponCopies=0,eligibleWeaponKeys=0,eligibleWeaponCopies=0,
 chromaEligibleCopies=0,originalOwnedTypesObserved=false,
 metadataReasonsObserved=false,sourceScope="UNATTESTED_SAME_CLIENT_TABLES",
 numericSupremeCheckerIdVerified=false,currentGameCatalogueAuthenticated=false,
}
E[KEY]=R
local message=nil
local function gui()
 pcall(function()
  if type(Instance)~="table" or type(Instance.new)~="function" then return end
  local players=game:GetService("Players")
  local lp=players and players.LocalPlayer
  local pg=lp and lp:FindFirstChildOfClass("PlayerGui")
  if not pg then return end
  local g=Instance.new("ScreenGui")
  g.Name="GINGERSCOPE_STAGE80_READONLY"
  g.ResetOnSpawn=false;g.DisplayOrder=155
  local panel=Instance.new("Frame")
  panel.Size=UDim2.fromOffset(410,116)
  panel.AnchorPoint=Vector2.new(0.5,0)
  panel.Position=UDim2.new(0.5,0,0,50)
  panel.BackgroundColor3=Color3.fromRGB(40,18,67)
  panel.BorderSizePixel=0
  panel.Parent=g
  message=Instance.new("TextLabel")
  message.Size=UDim2.new(1,-22,1,-16)
  message.Position=UDim2.fromOffset(11,8)
  message.BackgroundTransparency=1
  message.TextColor3=Color3.fromRGB(245,238,255)
  message.TextWrapped=true
  message.TextSize=15
  message.Text="STAGE80 | READ-ONLY METADATA REASON"
  message.Parent=panel
  g.Parent=pg
 end)
end
local function say(t)
 print("[STAGE80 GUIDE] "..t)
 if message then pcall(function()message.Text=t end) end
end
local function clip(t)
 -- Do not use ipairs({setclipboard,toclipboard}): a missing first function
 -- makes ipairs stop before reaching a valid fallback clipboard function.
 if type(setclipboard)=="function" then
  local ok,success=pcall(setclipboard,t)
  if ok and success~=false then return true end
 end
 if type(toclipboard)=="function" then
  local ok,success=pcall(toclipboard,t)
  if ok and success~=false then return true end
 end
 return false
end
local function done(status,reason)
 if status~=nil then R.status=status end
 if reason~=nil then R.reason=reason end
 local ok,json=pcall(function()
  return game:GetService("HttpService"):JSONEncode(R)
 end)
 if not ok or type(json)~="string" or #json>3900 then
  say("RESULT SERIALIZATION FAILED. No trading was performed.")
  warn("[STAGE80] JSON output unavailable")
  return R
 end
 local line=MARK..json
 local copied=clip(line)
 print(line)
 if copied then
  say("DONE: copied STAGE80 aggregate report. Paste in ChatGPT. NO TRADE.")
 else
  say("DONE: use one [GINGERSCOPE STAGE80 METADATA REASON] Delta console line.")
 end
 return R
end
gui()
say("One bounded read: classify the one prior metadata exception without names.")
if not game or game.PlaceId~=142823291 then
 return done("WRONG_GAME","PLACE_ID_NOT_MM2")
end
for _,other in ipairs({
 "PDIDDLER_STAGE25_SCANNER_ONLY","PDIDDLER_STAGE32_RESULT_CORRELATION_PROBE",
 "PDIDDLER_OUTGOING_SESSION","PDIDDLER_PART4_SESSION",
 "PDIDDLER_PART5_CONTROLLER","PDIDDLER_HOPPING_SESSION",
 "PDIDDLER_GINGERSCOPE_REPLACEMENT_PREVIEW",
 "PDIDDLER_STAGE66_SAME_WINDOW_CLIENT_ONLY",
 "GINGERSCOPE_STAGE79_SINGLE_OWNED_TYPE_PROBE",
 "GINGERSCOPE_STAGE75_READONLY_13_TARGETS"
}) do
 if E[other]~=nil then
  return done("OTHER_SESSION_ACTIVE_REJOIN_REQUIRED","REQUIRES_ISOLATED_GAME_CLIENT")
 end
end
local ok,rs=pcall(function()return game:GetService("ReplicatedStorage")end)
if not ok or not rs then return done("REPLICATION_UNAVAILABLE","NO_REPLICATED_STORAGE") end
local db=rs:FindFirstChild("Database")
local syncModule=db and db:FindFirstChild("Sync")
if not syncModule then return done("SYNC_MISSING","NO_SYNC_MODULE") end
local syncOk,sync=pcall(require,syncModule)
if (not syncOk or type(sync)~="table") and type(setthreadidentity)=="function" then
 local previous
 if type(getthreadidentity)=="function" then
  pcall(function()previous=getthreadidentity()end)
 end
 pcall(setthreadidentity,2)
 syncOk,sync=pcall(require,syncModule)
 pcall(setthreadidentity,previous or 8)
end
if not syncOk or type(sync)~="table" or type(sync.Weapons)~="table" then
 return done("SYNC_UNAVAILABLE","CLIENT_CATALOGUE_UNREADABLE")
end
local loadOK,analyzer=pcall(function()
 local src=game:HttpGet(URL,true)
 assert(type(src)=="string" and #src>250,"source unavailable")
 local fn=assert(loadstring(src,"=gingerscope-stage80-audit"))
 local obj=fn()
 assert(type(obj)=="table" and type(obj.audit)=="function","audit invalid")
 return obj
end)
if not loadOK then return done("HELPER_UNAVAILABLE","PINNED_READONLY_SOURCE_FAILED") end
local remotes=rs:FindFirstChild("Remotes")
local folder=remotes and remotes:FindFirstChild("Inventory")
local rf=folder and folder:FindFirstChild("GetProfileData")
if not rf or not rf:IsA("RemoteFunction") then
 return done("OWN_PROFILE_REMOTE_MISSING","GETPROFILEDATA_NOT_AVAILABLE")
end
if tostring(game.JobId or "")~=job then
 return done("SESSION_CHANGED","JOB_CHANGED_BEFORE_REQUEST")
end
local ended=false
local result=nil
local receivedOK=false
-- EXACTLY ONE INVOKE. A timeout never retries or authorizes future work.
task.spawn(function()
 receivedOK,result=pcall(function()return rf:InvokeServer()end)
 ended=true
end)
local deadline=os.clock()+4.5
while not ended and os.clock()<deadline do task.wait(0.05) end
if not ended then return done("OWN_READ_TIMED_OUT","ONE_CALL_ONLY_NO_RETRY") end
if tostring(game.JobId or "")~=job then return done("SESSION_CHANGED","JOB_CHANGED_AFTER_REQUEST") end
if not receivedOK or type(result)~="table" then
 return done("PROFILE_UNREADABLE","ONE_READ_FAILED")
end
local function unwrap(x,depth)
 if type(x)~="table" or getmetatable(x)~=nil or depth>4 then return nil end
 if type(x.Weapons)=="table" and type(x.Weapons.Owned)=="table" then return x end
 for _,name in ipairs({"ProfileData","Profile","PlayerData","Data","Inventory","FullInventory"}) do
  local v=rawget(x,name)
  local p=unwrap(v,depth+1)
  if p then return p end
 end
end
local profile=unwrap(result,0)
if not profile then return done("PROFILE_SHAPE_UNAVAILABLE","NO_OWNED_WEAPONS_TABLE") end
local success,audit=pcall(analyzer.audit,profile.Weapons.Owned,sync.Weapons)
-- Raw profile keys and tables are never stored under getgenv() or reported.
result=nil
profile=nil
if not success or type(audit)~="table" or audit.readOnly~=true
   or audit.authorizesTrade~=false or audit.authorizesAccept~=false
   or audit.mayUseForStrategyLearning~=false or audit.mayReportProfit~=false
   or audit.currentPricesVerified~=false then
 return done("AUDIT_FAILED_CLOSED","AGGREGATE_ANALYZER_FAILED")
end
local allow={
 "status","reason","originalOwnedTypesObserved","metadataReasonsObserved",
 "ownedKeys","ownedCopies","stringKeyCount","numericKeyCount","otherKeyCount",
 "invalidQuantityKeys","missingCatalogueKeys","untrustedMetadataKeys",
 "missingNameKeys","missingTypeKeys","missingRarityKeys",
 "miscKeys","miscCopies","unknownItemTypeKeys","invalidChromaTypeKeys",
 "chromaRarityConflictKeys","weaponKeys","weaponCopies",
 "eligibleWeaponKeys","eligibleWeaponCopies","chromaEligibleCopies"
}
for _,field in ipairs(allow) do R[field]=audit[field] end
return done()
