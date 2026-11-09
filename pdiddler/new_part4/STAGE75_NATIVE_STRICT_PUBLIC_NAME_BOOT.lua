-- Stage75: one-shot MAIN iPad public game catalogue ↔ historical source names.
-- READ-ONLY. No player inventory, trade remote, outgoing, Accept, item prices,
-- Discord, telemetry uploads or player/user/job identifiers in report.
local E=(type(getgenv)=="function" and getgenv()) or _G
local KEY="GINGERSCOPE_STAGE75_NAME_ONLY"
local MARKER="[GINGERSCOPE STAGE75 PUBLIC NAME ONLY]"
local JOB=tostring(game.JobId or "")
local S={status="PREPARING",clipboardStatus="NOT_ATTEMPTED",
 authorizesTrade=false,authorizesAccept=false,readOnly=true}
local textLabel=nil
local function gui(message)
 local ok=pcall(function()
  if type(Instance)~="table" or type(Instance.new)~="function" then return end
  local players=game:GetService("Players")
  local p=players and players.LocalPlayer
  local pg=p and p:FindFirstChildOfClass("PlayerGui")
  if not pg then return end
  local screen=Instance.new("ScreenGui")
  screen.Name="GingerscopeStage75PublicNameOnly"
  screen.ResetOnSpawn=false
  screen.DisplayOrder=160
  local frame=Instance.new("Frame")
  frame.Size=UDim2.fromOffset(440,146)
  frame.Position=UDim2.fromOffset(15,180)
  frame.BackgroundColor3=Color3.fromRGB(55,22,88)
  frame.BorderSizePixel=0
  frame.Parent=screen
  local label=Instance.new("TextLabel")
  label.Name="Instructions"
  label.Size=UDim2.new(1,-20,1,-16)
  label.Position=UDim2.fromOffset(10,8)
  label.BackgroundTransparency=1
  label.TextColor3=Color3.fromRGB(242,220,255)
  label.Font=Enum.Font.GothamBold
  label.TextSize=16
  label.TextXAlignment=Enum.TextXAlignment.Left
  label.TextYAlignment=Enum.TextYAlignment.Top
  label.TextWrapped=true
  label.Text=message
  label.Parent=frame
  screen.Parent=pg
  textLabel=label
 end)
 if not ok then textLabel=nil end
end
local function status(message)
 S.guiStatus=message
 if textLabel then pcall(function()textLabel.Text=message end)end
 print("[STAGE75] "..message)
end
gui("STAGE75 | READ-ONLY NAME CHECK\nNo trading or inventory. Checking public game catalogue only; result will copy automatically.")
status("STEP 1/2: inspecting public Sync.Weapons catalogue; NO TRADES")
local function base(reason)
 return {
  schema="gingerscope-stage75-client-catalogue-public-name-only-v1",
  status=reason,readOnly=true,clientOnly=true,sourceFresh=false,
  currentPlayerInventoryRead=false,gameCatalogueServerAuthenticated=false,
  rawToCheckerIdAuthenticated=false,numericSupremePriceVerified=false,
  authorizesAccept=false,authorizesTrade=false,
  mayReportProfit=false,mayRecordCompletedTrade=false,
  mayRecordRejectedTrade=false,mayUseForStrategyLearning=false,
  maySendDiscordWebhook=false,tradeOutcome="UNKNOWN"
 }
end
local function copy(text)
 local fns={setclipboard,toclipboard,E.setclipboard,E.toclipboard}
 local seen={}
 local attempted=false
 for _,fn in ipairs(fns) do
  if type(fn)=="function" and not seen[fn] then
   seen[fn]=true attempted=true
   local ok,returned=pcall(fn,text)
   if ok and returned~=false then return "COPY_REQUEST_SUCCEEDED" end
  end
 end
 return attempted and "COPY_FAILED" or "COPY_UNAVAILABLE"
end
local function finish(value)
 S.report=value
 local ok,payload=pcall(function()
  return game:GetService("HttpService"):JSONEncode(value)
 end)
 if not ok or type(payload)~="string" or #payload==0 or #payload>10000 then
  S.status="REPORT_ENCODING_FAILED"
  status("ST75 ERROR: report unavailable. Use Delta console; NO TRADING")
  return S
 end
 S.clipboardStatus=copy(payload)
 print(MARKER.." "..payload)
 S.status=value.status
 local message=S.clipboardStatus=="COPY_REQUEST_SUCCEEDED"
   and "COPY SENT (PASTE CHECK)" or "COPY FAILED (USE CONSOLE)"
 status("ST75 COMPLETE | "..message.."\n"
  .."Exact public-name matches: "..tostring(value.strictMatches or 0)
  .." / "..tostring(value.sourceRows or 190)
  .." | NO PRICES; OUTGOING PAUSED")
 return S
end
if game.PlaceId~=142823291 then return finish(base("WRONG_GAME")) end
if type(E[KEY])=="table" and E[KEY].jobId==JOB then
 warn("[STAGE75] already ran this server; no duplicate report")
 return E[KEY]
end
for _,name in ipairs({"PDIDDLER_PART4_CONTROLLER","PDIDDLER_OUTGOING_SESSION",
 "PDIDDLER_PART4_SESSION","PDIDDLER_HOPPING_SESSION",
 "PDIDDLER_STAGE25_SCANNER_ONLY","PDIDDLER_GINGERSCOPE_REPLACEMENT_PREVIEW"}) do
 if E[name]~=nil then return finish(base("ANOTHER_SESSION_PRESENT")) end
end
S.jobId=JOB
E[KEY]=S
-- All payload scripts are immutable Git SHA-pinned, and contain no prices.
local ROOT="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"
local CORE_COMMIT="f651b9dc381671b58608cafa06eafd6ab4908a4d"
local INDEX_COMMIT="4b8a66d1432446bf6e11b9c9183b0a3232797d73"
local function loadPinned(commit,path)
 local url=ROOT..commit.."/pdiddler/"..path
 local source=game:HttpGet(url,true)
 assert(type(source)=="string" and #source>40)
 local fn,why=loadstring(source,"=stage75-pinned")
 assert(fn,why)
 return assert(fn())
end
local loaded,source,engine=pcall(function()
 local a=loadPinned(INDEX_COMMIT,"intelligence_lab/stage75_historical_public_name_index.lua")
 local b=loadPinned(CORE_COMMIT,"intelligence_lab/stage75_strict_live_public_name_comparison.lua")
 return a,b
end)
if not loaded or type(source)~="table" or type(engine)~="table"
 or type(engine.evaluate)~="function" then
 return finish(base("PINNED_READONLY_MODULE_UNAVAILABLE"))
end
status("STEP 2/2: examining replicated public game metadata; NO PLAYER INVENTORY")
local ok,sync=pcall(function()
 local rs=game:GetService("ReplicatedStorage")
 local database=rs:FindFirstChild("Database")
 local module=database and database:FindFirstChild("Sync")
 assert(module,"game Sync module absent")
 return require(module)
end)
if (not ok or type(sync)~="table") and type(setthreadidentity)=="function" then
 local old
 if type(getthreadidentity)=="function" then
  pcall(function()old=getthreadidentity()end)
 end
 pcall(setthreadidentity,2)
 ok,sync=pcall(function()
  local rs=game:GetService("ReplicatedStorage")
  local db=rs:FindFirstChild("Database")
  return require(assert(db and db:FindFirstChild("Sync")))
 end)
 pcall(setthreadidentity,old or 8)
end
if not ok or type(sync)~="table" then
 return finish(base("PUBLIC_SYNC_CATALOGUE_UNAVAILABLE"))
end
if tostring(game.JobId or "")~=JOB then
 return finish(base("SERVER_CHANGED_ABORT"))
end
local processed,result=pcall(engine.evaluate,sync,source)
if not processed or type(result)~="table"
 or result.schema~="gingerscope-stage75-client-catalogue-public-name-only-v1"
 or result.authorizesTrade~=false or result.authorizesAccept~=false
 or result.sourceFresh~=false or result.currentPlayerInventoryRead~=false
 or result.gameCatalogueServerAuthenticated~=false
 or result.numericSupremePriceVerified~=false
 or result.mayUseForStrategyLearning~=false
 or result.maySendDiscordWebhook~=false then
 return finish(base("UNTRUSTED_OR_FAILED_COMPARISON"))
end
if tostring(game.JobId or "")~=JOB then
 return finish(base("SERVER_CHANGED_ABORT"))
end
return finish(result)
