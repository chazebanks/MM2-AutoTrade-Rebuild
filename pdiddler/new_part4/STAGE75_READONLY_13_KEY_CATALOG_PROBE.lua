-- Gingerscope Stage75: SINGLE read-only live client *catalogue* 13-key comparison.
-- Pinned third-party source is NOT Roblox-authenticated server data.
-- No player inventories, remote trading, current values, P4, Accept, hopping,
-- webhook, Discord learning or claimed completed trades.
-- Public expected source: mm2scripthub/mm2 db @ 0f2715187e7eae36eea4bd97afee809478fc877d
-- Exact Git source blob SHA: 2be54c3f5c6b715844728c01a65cc2f24a55c02d
-- Runtime reads ONLY 13 direct Sync.Weapons catalogue keys, never pairs() full scan.
local MARKER="[GINGERSCOPE STAGE75 CLIENT CATALOG] "
local KEY="GINGERSCOPE_STAGE75_READONLY_13_TARGETS"
local E=(type(getgenv)=="function" and getgenv()) or _G
local originalJob=type(game)=="table" or type(game)=="userdata"
originalJob=originalJob and tostring(game.JobId or "") or ""
local existing=E[KEY]
if type(existing)=="table" and existing.jobId==originalJob then
    warn("[GINGERSCOPE STAGE75] already running in this server; no second report")
    return existing
end
local R={
  schema="gingerscope-stage75-readonly-13-catalogue-keys-v1",
  sourceKind="THIRD_PARTY_PUBLIC_ARCHIVE_UNVERIFIED",
  sourcePin="mm2scripthub/mm2 db 0f2715187e7eae36eea4bd97afee809478fc877d",
  status="NOT_STARTED", readOnly=true, clientOnly=true,
  gameCatalogueClientObserved=false, authenticatedServerInventory=false,
  sourcePublisherCurrentVerified=false, currentPricesVerified=false,
  rawToSupremeCheckerVerified=false, serverAttestation=false,
  authorizesTrade=false, authorizesAccept=false, mayReportProfit=false,
  mayRecordCompletedTrade=false, mayRecordRejectedTrade=false,
  mayUseForStrategyLearning=false, maySendDiscordWebhook=false,
  tradeOutcome="UNKNOWN", expectedTargets=13, examinedTargets=0,
  exactTargets=0, mismatchedTargets=0, missingTargets=0,
  malformedTargets=0, overlappingItemIdPairs=0,
  testResults={}, jobId=originalJob,
}
-- Never serialize job identifiers, even a temporary local one.
local function payload()
  local p={}
  for k,v in pairs(R) do if k~="jobId" then p[k]=v end end
  return p
end
-- Frozen 13 public *catalogue* raw keys, not player inventories.
local TARGETS={
  {raw="Gingerscope",name="Gingerscope",kind="Gun",rarity="Ancient",chroma=false},
  {raw="Emberbow",name="Emberbow",kind="Gun",rarity="Ancient",chroma=false},
  {raw="Emberscythe",name="Emberscythe",kind="Knife",rarity="Ancient",chroma=false},
  {raw="EmberbowChroma",name="Emberbow",kind="Gun",rarity="Ancient",chroma=true},
  {raw="EmberscytheChroma",name="Emberscythe",kind="Knife",rarity="Ancient",chroma=true},
  {raw="Mortal",name="Mortal",kind="Knife",rarity="Godly",chroma=false},
  {raw="Immortal",name="Immortal",kind="Gun",rarity="Godly",chroma=false},
  {raw="MortalChroma",name="Mortal",kind="Knife",rarity="Godly",chroma=true},
  {raw="ImmortalChroma",name="Immortal",kind="Gun",rarity="Godly",chroma=true},
  {raw="Embersickle",name="Embersickle",kind="Knife",rarity="Godly",chroma=false},
  {raw="EmbersickleChroma",name="Embersickle",kind="Knife",rarity="Godly",chroma=true},
  {raw="BattleAxe",name="BattleAxe",kind="Knife",rarity="Godly",chroma=false},
  {raw="BattleAxe2",name="BattleAxe II",kind="Knife",rarity="Godly",chroma=false},
}
local panel, guide
local function gui()
  local ok=pcall(function()
    if type(Instance)~="table" or type(Instance.new)~="function" then return end
    local ps=game:GetService("Players")
    local localPlayer=ps and ps.LocalPlayer
    local pg=localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")
    if not pg then return end
    local old=pg:FindFirstChild("GINGERSCOPE_STAGE75_GUIDE")
    if old then old:Destroy() end
    local screen=Instance.new("ScreenGui")
    screen.Name="GINGERSCOPE_STAGE75_GUIDE"
    screen.ResetOnSpawn=false
    screen.DisplayOrder=155
    local frame=Instance.new("Frame")
    frame.Size=UDim2.fromOffset(405,160)
    frame.Position=UDim2.new(0.5,0,0,54)
    frame.AnchorPoint=Vector2.new(0.5,0)
    frame.BackgroundColor3=Color3.fromRGB(35,19,64)
    frame.BorderSizePixel=0
    frame.Parent=screen
    local corner=Instance.new("UICorner")
    corner.CornerRadius=UDim.new(0,9)
    corner.Parent=frame
    local title=Instance.new("TextLabel")
    title.Size=UDim2.new(1,-50,0,34)
    title.Position=UDim2.fromOffset(10,6)
    title.BackgroundTransparency=1
    title.Font=Enum.Font.GothamBold
    title.TextSize=17
    title.TextColor3=Color3.fromRGB(237,229,255)
    title.TextXAlignment=Enum.TextXAlignment.Left
    title.Text="STAGE75  |  CATALOGUE ONLY"
    title.Parent=frame
    local body=Instance.new("TextLabel")
    body.Size=UDim2.new(1,-24,0,96)
    body.Position=UDim2.fromOffset(12,45)
    body.BackgroundTransparency=1
    body.Font=Enum.Font.Gotham
    body.TextSize=15
    body.TextWrapped=true
    body.TextXAlignment=Enum.TextXAlignment.Left
    body.TextYAlignment=Enum.TextYAlignment.Top
    body.TextColor3=Color3.fromRGB(247,241,255)
    body.Text="Preparing read-only catalogue check..."
    body.Parent=frame
    local close=Instance.new("TextButton")
    close.Size=UDim2.fromOffset(32,30)
    close.Position=UDim2.new(1,-39,0,8)
    close.BackgroundTransparency=1
    close.Font=Enum.Font.GothamBold
    close.TextSize=20
    close.TextColor3=Color3.fromRGB(236,229,250)
    close.Text="X"
    close.Parent=frame
    close.Activated:Connect(function()screen:Destroy()end)
    screen.Parent=pg
    panel=screen
    guide=body
  end)
  return ok and guide~=nil
end
local function say(s)
  print("[STAGE75 GUIDE] "..s)
  if guide and panel and panel.Parent then
    pcall(function() guide.Text=s end)
  end
end
local function tryClipboard(fn,line)
  if type(fn)~="function" then return false end
  local ok,ret=pcall(fn,line)
  return ok and ret~=false
end
local function copy(line)
  if tryClipboard(setclipboard,line) then return true end
  if tryClipboard(toclipboard,line) then return true end
  if type(getgenv)=="function" then
    local ok,v=pcall(getgenv)
    if ok and type(v)=="table" then
      if tryClipboard(v.setclipboard,line) then return true end
      if tryClipboard(v.toclipboard,line) then return true end
    end
  end
  return false
end
local function emit(status)
  R.status=status
  local encoded,text=pcall(function()
    return game:GetService("HttpService"):JSONEncode(payload())
  end)
  if not encoded or type(text)~="string" or #text>7000 then
    say("TEST FAILED: cannot encode read-only result. See Delta console.")
    warn("[GINGERSCOPE STAGE75] report encoding unavailable")
    return R
  end
  local line=MARKER..text
  R.clipboardAttemptSucceeded=copy(line) -- transport, NOT OS paste attestation
  print(line)
  if R.clipboardAttemptSucceeded then
    say("DONE: "..R.exactTargets.."/13 exact CLIENT catalogue fields.\n"
       .."COPY SENT (PASTE TO CHATGPT). NO TRADING / PRICES.")
  else
    say("DONE: "..R.exactTargets.."/13 exact CLIENT catalogue fields.\n"
       .."COPY FAILED: use ONE full STAGE75 line in Delta console.")
  end
  return R
end
gui()
say("READ-ONLY. STEP 1/2: Check 13 public game CATALOGUE keys.\n"
   .."No inventory, trading, player names, prices or game remotes.")
E[KEY]=R
if type(game)~="table" and type(game)~="userdata" then return emit("GAME_UNAVAILABLE") end
if game.PlaceId~=142823291 then return emit("WRONG_GAME") end
local forbidden={
 "PDIDDLER_OUTGOING_SESSION","PDIDDLER_PART4_SESSION",
 "PDIDDLER_HOPPING_SESSION","PDIDDLER_PART4_CONTROLLER",
 "PDIDDLER_GINGERSCOPE_REPLACEMENT_PREVIEW",
 "PDIDDLER_STAGE63_SAME_WINDOW_CLIENT_ONLY",
 "PDIDDLER_STAGE66_SAME_WINDOW_CLIENT_ONLY",
 "PDIDDLER_STAGE68_CLIENT_RUN_ONLY",
}
for _,name in ipairs(forbidden) do
  if E[name]~=nil then return emit("OTHER_SESSION_ACTIVE_REJOIN_REQUIRED") end
end
local ok,rs=pcall(function()return game:GetService("ReplicatedStorage")end)
if not ok or not rs then return emit("REPLICATED_STORAGE_UNAVAILABLE") end
local db=rs:FindFirstChild("Database")
local module=db and db:FindFirstChild("Sync")
if not module then return emit("SYNC_MODULE_MISSING") end
local success,sync=pcall(require,module)
if (not success or type(sync)~="table") and type(setthreadidentity)=="function" then
  local oldIdentity
  if type(getthreadidentity)=="function" then
    pcall(function()oldIdentity=getthreadidentity()end)
  end
  pcall(setthreadidentity,2)
  success,sync=pcall(require,module)
  pcall(setthreadidentity,oldIdentity or 8)
end
if not success or type(sync)~="table" or type(sync.Weapons)~="table" then
  return emit("SYNC_CATALOG_UNAVAILABLE")
end
if tostring(game.JobId or "")~=originalJob then return emit("SERVER_CHANGED") end
R.gameCatalogueClientObserved=true
say("STEP 2/2: Compare 13 EXACT client keys. No fuzzy aliases.\n"
   .."One anonymized result will copy automatically; no taps required.")
-- Only 13 public, known catalogue keys. NEVER use pairs(sync.Weapons), Owned,
-- player inventory or a trade event. Reject all malformed live metadata.
local namesSeen={}
local assetIds={}
for _,target in ipairs(TARGETS) do
  local d=sync.Weapons[target.raw]
  local label=target.chroma and "Chroma "..target.name or target.name
  local row={sourceName=label,sourceRawKey=target.raw,status="MISSING"}
  R.examinedTargets=R.examinedTargets+1
  if d==nil then
    R.missingTargets=R.missingTargets+1
  elseif type(d)~="table" or type(d.ItemName)~="string"
     or type(d.ItemType)~="string" or type(d.Rarity)~="string"
     or (d.Chroma~=nil and type(d.Chroma)~="boolean") then
    row.status="MALFORMED"
    R.malformedTargets=R.malformedTargets+1
  else
    local name=d.ItemName
    local rarity=d.Rarity
    local kind=d.ItemType
    local isChroma=d.Chroma==true
    -- Never trust arbitrary client labels; only the baked PUBLIC expected
    -- labels may appear in a report. NO raw observed values or asset IDs.
    if name==target.name and rarity==target.rarity
       and kind==target.kind and isChroma==target.chroma then
      row.status="EXACT"
      R.exactTargets=R.exactTargets+1
    else
      row.status="MISMATCH"
      R.mismatchedTargets=R.mismatchedTargets+1
    end
    -- Asset ID is sometimes shared between base and Chroma. Record ONLY
    -- the aggregate number of overlapping source asset IDs, never values.
    local itemId=d.ItemID
    if type(itemId)=="number" and itemId>0 and itemId<1e15
       and itemId==math.floor(itemId) then
      local prior=assetIds[itemId]
      if prior and prior~=target.raw then
        R.overlappingItemIdPairs=R.overlappingItemIdPairs+1
      else
        assetIds[itemId]=target.raw
      end
    end
  end
  local nameKey=(target.chroma and "chroma|" or target.rarity.."|")..target.name
  if namesSeen[nameKey] then
    R.status="STATIC_TARGET_COLLISION"
    return emit("STATIC_TARGET_COLLISION")
  end
  namesSeen[nameKey]=true
  R.testResults[#R.testResults+1]=row
end
if tostring(game.JobId or "")~=originalJob then return emit("SERVER_CHANGED") end
if #R.testResults~=13 or R.examinedTargets~=13 then
  return emit("INCOMPLETE_CLIENT_CATALOG")
end
if R.exactTargets==13 then
  return emit("EXACT_13_PUBLIC_CATALOG_FIELDS_CLIENT_ONLY")
end
return emit("PARTIAL_CLIENT_CATALOG_FIELDS_UNVERIFIED")
