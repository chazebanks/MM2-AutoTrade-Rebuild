-- Stage75: BOUNDED, READ-ONLY local MM2 catalogue metadata equality.
-- Independent October 18 public third-party source: mm2scripthub/mm2 db
-- commit 0f2715187e7eae36eea4bd97afee809478fc877d, Git blob 2be54c3...
-- NOT original Roblox publisher attestation; not a price / market checker ID.
-- No user inventory, player identities, trades, remotes, server hops, or learning.
local MARK="[GINGERSCOPE STAGE75 CATALOGUE EQUALITY]"
local R={
 schema="gingerscope-stage75-client-catalogue-twelve-v1",
 status="INCOMPLETE",readOnly=true,clientOnly=true,sourceClass="THIRD_PARTY_PUBLIC_SOURCE",
 sourcePublicationAuthenticated=false,currentGameCatalogAuthenticated=false,
 sourceFresh=false,serverAttestation=false,rawGameToSupremeCheckerApproved=false,
 uniqueWeaponInstanceProven=false,authorizesTrade=false,authorizesAccept=false,
 mayReportProfit=false,mayRecordCompletedTrade=false,mayRecordRejectedTrade=false,
 mayUseForStrategyLearning=false,maySendDiscordWebhook=false,tradeOutcome="UNKNOWN",
 targetCount=12,catalogueRowsObserved=0,catalogueAccessible=false,
 targetMatches=0,targetMissing=0,targetMismatched=0,artIdReusedVariantPairs=0,
 targetChecks={},reportGenerated=false,clipboardPasteVerified=false
}
-- Public immutable external SOURCE label expectations, not player item keys.
-- Case-sensitive: BattleAxe differs from Supreme's spelling Battleaxe.
-- Chroma Emberscythe/Emberbow are Ancient+Chroma, NOT Godly.
-- Image/item asset IDs may be SHARED between base and Chroma; never use
-- an ItemID to infer a unique owned weapon or Supreme record identity.
local TARGETS={
 {"Emberbow","Emberbow","Gun","Ancient",false,"2026","109700223945658"},
 {"Emberscythe","Emberscythe","Knife","Ancient",false,"2026","113246722870618"},
 {"Mortal","Mortal","Knife","Godly",false,"2026","72199828838672"},
 {"Immortal","Immortal","Gun","Godly",false,"2026","112675577042738"},
 {"Embersickle","Embersickle","Knife","Godly",false,"2026","113946366917108"},
 {"EmberbowChroma","Emberbow","Gun","Ancient",true,"2026","109700223945658"},
 {"EmberscytheChroma","Emberscythe","Knife","Ancient",true,"2026","113246722870618"},
 {"MortalChroma","Mortal","Knife","Godly",true,"2026","72199828838672"},
 {"ImmortalChroma","Immortal","Gun","Godly",true,"2026","112675577042738"},
 {"EmbersickleChroma","Embersickle","Knife","Godly",true,"2026","113946366917108"},
 {"BattleAxe","BattleAxe","Knife","Godly",false,"2017","1133237368"},
 {"BattleAxe2","BattleAxe II","Knife","Godly",false,"2018","2513535503"}
}
local gui,guiStatus
local function guide(message)
 if guiStatus and gui and gui.Parent then
  pcall(function()guiStatus.Text=message end)
 end
 print("[STAGE75 GUIDE] "..message)
end
local function panel()
 pcall(function()
  if type(Instance)~="table" or type(Instance.new)~="function" then return end
  local pl=game:GetService("Players")
  local pg=pl and pl.LocalPlayer and pl.LocalPlayer:FindFirstChildOfClass("PlayerGui")
  if not pg then return end
  local old=pg:FindFirstChild("GINGERSCOPE_STAGE75_CATALOG_GUIDE")
  if old then old:Destroy() end
  local screen=Instance.new("ScreenGui")
  screen.Name="GINGERSCOPE_STAGE75_CATALOG_GUIDE"
  screen.ResetOnSpawn=false
  screen.IgnoreGuiInset=false
  screen.DisplayOrder=160
  local frame=Instance.new("Frame")
  frame.Size=UDim2.fromOffset(385,148)
  frame.Position=UDim2.new(0.5,0,0,50)
  frame.AnchorPoint=Vector2.new(0.5,0)
  frame.BackgroundColor3=Color3.fromRGB(38,21,65)
  frame.BorderSizePixel=0
  frame.Parent=screen
  local corner=Instance.new("UICorner")
  corner.CornerRadius=UDim.new(0,10)
  corner.Parent=frame
  local title=Instance.new("TextLabel")
  title.BackgroundTransparency=1
  title.Size=UDim2.new(1,-20,0,30)
  title.Position=UDim2.fromOffset(10,7)
  title.Text="STAGE 75 | READ-ONLY CATALOG"
  title.TextSize=16
  title.Font=Enum.Font.GothamBold
  title.TextColor3=Color3.fromRGB(242,232,255)
  title.TextXAlignment=Enum.TextXAlignment.Left
  title.Parent=frame
  local status=Instance.new("TextLabel")
  status.BackgroundTransparency=1
  status.Size=UDim2.new(1,-22,0,95)
  status.Position=UDim2.fromOffset(11,43)
  status.Font=Enum.Font.Gotham
  status.TextSize=14
  status.TextWrapped=true
  status.TextXAlignment=Enum.TextXAlignment.Left
  status.TextYAlignment=Enum.TextYAlignment.Top
  status.TextColor3=Color3.fromRGB(242,232,255)
  status.Text="Preparing read-only checks..."
  status.Parent=frame
  screen.Parent=pg
  gui,guiStatus=screen,status
 end)
end
local function tryCopy(fn,line)
 if type(fn)~="function" then return false end
 local ok,v=pcall(fn,line)
 return ok and v~=false
end
local function copyReport(line)
 local choices={}
 local function add(fn)
  if type(fn)~="function" then return end
  for _,p in ipairs(choices) do if p==fn then return end end
  choices[#choices+1]=fn
 end
 add(setclipboard);add(toclipboard)
 if type(getgenv)=="function" then
  local ok,e=pcall(getgenv)
  if ok and type(e)=="table" then
   add(e.setclipboard);add(e.toclipboard)
  end
 end
 for _,fn in ipairs(choices) do
  if tryCopy(fn,line) then return true end
 end
 return false
end
local function emit(status)
 R.status=status
 local ok,payload=pcall(function()
  return game:GetService("HttpService"):JSONEncode(R)
 end)
 if not ok or type(payload)~="string" or #payload==0 or #payload>6000 then
  guide("REPORT FAILED. Check Delta console.\nNO TRADING")
  print(MARK.." REPORT_ENCODING_FAILED")
  return R
 end
 R.reportGenerated=true
 -- Serialize again to include the generated flag, but do not include
 -- the clipboard flag in the copied payload: clipboard API is not OS proof.
 local ok2,report=pcall(function()
  return game:GetService("HttpService"):JSONEncode(R)
 end)
 if not ok2 or type(report)~="string" or #report>6000 then
  guide("REPORT FAILED. Use Delta console.\nNO TRADING")
  print(MARK.." REPORT_ENCODING_FAILED")
  return R
 end
 local line=MARK.." "..report
 local copied=copyReport(line)
 print(line) -- exactly one complete console fallback
 if copied then
  guide("DONE: "..tostring(R.targetMatches).."/12 public labels matched\nPrices UNVERIFIED | NO TRADING\nCopy requested; PASTE report in ChatGPT")
 else
  guide("DONE: catalogue check complete\nNO TRADING | prices UNVERIFIED\nClipboard failed; copy Delta console report")
 end
 return R
end
local function safeYear(value)
 if type(value)~="number" and type(value)~="string" then return "" end
 local s=tostring(value)
 if s:match("^%d%d%d%d$") then return s end
 return ""
end
local function validArtId(n)
 return type(n)=="number" and n>0 and n<1e16 and n==math.floor(n)
end
local function check(row,expected)
 if type(row)~="table" then return "MISSING" end
 local nonChroma=(row.Chroma==nil or row.Chroma==false)
 local variantMatch=(expected[5] and row.Chroma==true) or
                    (not expected[5] and nonChroma)
 if not variantMatch then return "CHROMA_VARIANT_MISMATCH" end
 if row.ItemName~=expected[2] then return "NAME_MISMATCH" end
 if row.ItemType~=expected[3] then return "TYPE_MISMATCH" end
 if row.Rarity~=expected[4] then return "RARITY_MISMATCH" end
 if safeYear(row.Year)~=expected[6] or row.Event~="Halloween" then
  return "EVENT_YEAR_MISMATCH"
 end
 if not validArtId(row.ItemID) then return "INVALID_ASSET_METADATA" end
 if tostring(row.ItemID)~=expected[7] then return "ASSET_METADATA_CHANGED" end
 return "SOURCE_METADATA_EQUALITY_ONLY"
end
panel()
guide("STEP 1/2: Checking 12 public items\nNO PLAYER INVENTORY OR TRADES\nReport will auto-copy")
if type(game)~="table" and type(game)~="userdata" then
 return emit("GAME_UNAVAILABLE")
end
if game.PlaceId~=142823291 then return emit("WRONG_GAME") end
local job=tostring(game.JobId or "")
local ok,rs=pcall(function()return game:GetService("ReplicatedStorage")end)
if not ok or not rs then return emit("REPLICATED_STORAGE_UNAVAILABLE") end
local db=rs:FindFirstChild("Database")
local syncObj=db and db:FindFirstChild("Sync")
if not syncObj then return emit("SYNC_MODULE_MISSING") end
local success,sync=pcall(require,syncObj)
if (not success or type(sync)~="table") and type(setthreadidentity)=="function" then
 local prev=nil
 if type(getthreadidentity)=="function" then
  pcall(function()prev=getthreadidentity()end)
 end
 pcall(setthreadidentity,2)
 success,sync=pcall(require,syncObj)
 pcall(setthreadidentity,prev or 8)
end
if not success or type(sync)~="table" or type(sync.Weapons)~="table" then
 return emit("SYNC_UNAVAILABLE")
end
if tostring(game.JobId or "")~=job then return emit("SERVER_CHANGED") end
R.catalogueAccessible=true
local count=0
for _ in pairs(sync.Weapons) do
 count=count+1
 if count>3000 then return emit("UNEXPECTED_CATALOGUE_SIZE") end
end
R.catalogueRowsObserved=count
guide("STEP 2/2: Checking catalogue labels\nNO TRADES OR PLAYER INVENTORY\nReport will auto-copy")
for i,exp in ipairs(TARGETS) do
 local state=check(sync.Weapons[exp[1]],exp)
 if state=="MISSING" then R.targetMissing=R.targetMissing+1
 elseif state=="SOURCE_METADATA_EQUALITY_ONLY" then R.targetMatches=R.targetMatches+1
 else R.targetMismatched=R.targetMismatched+1 end
 R.targetChecks[#R.targetChecks+1]={case=string.format("T%02d",i),state=state}
end
for i=1,5 do
 local base=sync.Weapons[TARGETS[i][1]]
 local chroma=sync.Weapons[TARGETS[i+5][1]]
 if type(base)=="table" and type(chroma)=="table"
   and validArtId(base.ItemID) and base.ItemID==chroma.ItemID then
  R.artIdReusedVariantPairs=R.artIdReusedVariantPairs+1
 end
end
if tostring(game.JobId or "")~=job then
 R.targetMatches=0;R.targetMissing=0;R.targetMismatched=0
 R.targetChecks={}
 return emit("SERVER_CHANGED")
end
if R.targetMatches+R.targetMissing+R.targetMismatched~=12 then
 return emit("TARGET_ACCOUNTING_INVALID")
end
if R.targetMissing>0 or R.targetMismatched>0 then
 return emit("CLIENT_CATALOGUE_DIFFERENCE_OBSERVED")
end
return emit("CLIENT_PUBLIC_METADATA_EQUALITY_OBSERVED_UNVERIFIED")
