-- Stage79 SINGLE one-shot, read-only own raw type census, on MAIN iPad/Delta.
-- Answers a NEW question: what are ORIGINAL Weapons.Owned Lua key types, and
-- do string keys directly match SAME-CLIENT Sync.Weapons entries?
-- NEVER enter a trade, offer, accept, decline, hop, price or run P4/Discord.
-- No weapon names/raw keys/profile/JobId/username are printed or copied.
local MARK="[GINGERSCOPE STAGE79 OWNED TYPE] "
local KEY="GINGERSCOPE_STAGE79_SINGLE_OWNED_TYPE_PROBE"
local PIN="a2da4d53b7ee92b289b9c58a34ac08e7ded6731a"
local URL="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"..
  PIN.."/pdiddler/intelligence_lab/stage79_typed_owned_census.lua"
local E=(type(getgenv)=="function" and getgenv()) or _G
local job=tostring(game and game.JobId or "")
if E[KEY]~=nil then
 warn("[STAGE79] already run in this game session; rejoin before another diagnostic")
 return E[KEY]
end
local R={
 schema="gingerscope-stage79-client-owned-typed-key-census-v1",
 status="INITIALIZING",reason="NOT_OBSERVED",
 readOnly=true,clientOnly=true,tradeOutcome="UNKNOWN",
 originalOwnedKeyTypesObserved=false,directCatalogueJoinObserved=false,
 authenticatedOwnedInventory=false,serverAttestation=false,
 serverCompletionProven=false,rawToSupremeCheckerVerified=false,
 sourcePublisherFresh=false,currentPricesVerified=false,
 authorizesTrade=false,authorizesAccept=false,mayReportProfit=false,
 mayRecordCompletedTrade=false,mayRecordRejectedTrade=false,
 maySendDiscordWebhook=false,mayUseForStrategyLearning=false,
 ownedKeyCount=0,positiveCopyCount=0,stringKeyCount=0,
 numericKeyCount=0,otherKeyCount=0,invalidQuantityCount=0,
 unmatchedStringKeyCount=0,malformedCatalogueEntryCount=0,
 directCatalogueKeyCount=0,eligibleKeyCount=0,eligibleCopies=0,
 chromaEligibleCopies=0,coercionCollisionPairs=0,
 sourceKind="CLIENT_GETPROFILEDATA_AND_REPLICATED_SYNC_UNATTESTED",
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
  g.Name="GINGERSCOPE_STAGE79_READONLY"
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
  message.Text="STAGE79 | ONE READ-ONLY OWNED-TYPE OBSERVATION"
  message.Parent=panel
  g.Parent=pg
 end)
end
local function say(t)
 print("[STAGE79 GUIDE] "..t)
 if message then pcall(function()message.Text=t end) end
end
local function clip(t)
 for _,fn in ipairs({setclipboard,toclipboard}) do
  if type(fn)=="function" then
   local ok,success=pcall(fn,t)
   if ok and success~=false then return true end
  end
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
  warn("[STAGE79] JSON output unavailable")
  return R
 end
 local line=MARK..json
 local copied=clip(line)
 print(line)
 if copied then
  say("DONE: copied STAGE79 aggregate report. Paste in ChatGPT. NO TRADE.")
 else
  say("DONE: use one [GINGERSCOPE STAGE79 OWNED TYPE] Delta console line.")
 end
 return R
end
gui()
say("One bounded OWN inventory read; no trades or item names reported.")
if not game or game.PlaceId~=142823291 then
 return done("WRONG_GAME","PLACE_ID_NOT_MM2")
end
for _,other in ipairs({
 "PDIDDLER_STAGE25_SCANNER_ONLY","PDIDDLER_STAGE32_RESULT_CORRELATION_PROBE",
 "PDIDDLER_OUTGOING_SESSION","PDIDDLER_PART4_SESSION",
 "PDIDDLER_PART5_CONTROLLER","PDIDDLER_HOPPING_SESSION",
 "PDIDDLER_GINGERSCOPE_REPLACEMENT_PREVIEW",
 "PDIDDLER_STAGE66_SAME_WINDOW_CLIENT_ONLY",
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
 local fn=assert(loadstring(src,"=gingerscope-stage79-audit"))
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
   or audit.authorizesTrade~=false or audit.authorizesAccept~=false then
 return done("AUDIT_FAILED_CLOSED","AGGREGATE_ANALYZER_FAILED")
end
local allow={
 "status","reason","originalOwnedKeyTypesObserved",
 "directCatalogueJoinObserved","ownedKeyCount","positiveCopyCount",
 "stringKeyCount","numericKeyCount","otherKeyCount",
 "invalidQuantityCount","unmatchedStringKeyCount",
 "malformedCatalogueEntryCount","directCatalogueKeyCount",
 "eligibleKeyCount","eligibleCopies","chromaEligibleCopies",
 "coercionCollisionPairs"
}
for _,field in ipairs(allow) do R[field]=audit[field] end
return done()
