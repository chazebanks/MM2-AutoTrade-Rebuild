-- Stage83: ONE read-only client Owned→historical public URL coverage audit.
-- Never run while P4/rotation/offer/Accept/Discord or other probes are active.
-- Does NOT print raw owned keys, names, item URLs, account identifiers or prices.
local MARK="[GINGERSCOPE STAGE83 PUBLIC COVERAGE] "
local KEY="GINGERSCOPE_STAGE83_READONLY_AGGREGATE_COVERAGE"
-- Helper + static public-only registry are from the SAME immutable Git commit.
-- This commit predates the wrapper, so the loader never fetches mutable main.
local PIN="42ab03b81fe1ab69613ec8b5797dad95252ee4d8"
local ROOT="https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/"..PIN..
 "/pdiddler/intelligence_lab/"
local E=(type(getgenv)=="function" and getgenv()) or _G
local job=tostring(game and game.JobId or "")
if E[KEY]~=nil then
 warn("[STAGE83] already attempted in this client session; no automatic retry")
 return E[KEY]
end
local R={
 schema="gingerscope-stage83-private-aggregate-slug-coverage-v1",
 status="INITIALIZING",reason="NO_OBSERVATION_YET",readOnly=true,clientOnly=true,
 sourceKind="UNATTESTED_CLIENT_AND_HISTORICAL_PUBLIC_REFERENCES",
 originalOwnedKeyTypesObserved=false,exactClientCatalogueLookupObserved=false,
 historicalPublicReferenceCoverageObserved=false,
 sourcePublisherFresh=false,currentPricesVerified=false,
 numericSupremeCheckerIdVerified=false,authenticatedOwnedInventory=false,
 currentGameCatalogueAuthenticated=false,serverAttestation=false,
 currentOwnedRawToMarketSlugVerified=false,serverCompletionProven=false,
 authorizesTrade=false,authorizesAccept=false,mayReportProfit=false,
 mayRecordCompletedTrade=false,mayRecordRejectedTrade=false,
 maySendDiscordWebhook=false,mayUseForStrategyLearning=false,tradeOutcome="UNKNOWN",
 historicalPublicRegistryEntries=0,ownedKeys=0,ownedCopies=0,
 stringOwnedKeys=0,numericOwnedKeys=0,otherOwnedKeys=0,
 invalidQuantities=0,unmappedClientKeys=0,untrustedMetadataKeys=0,
 clientWeaponKeys=0,clientWeaponCopies=0,miscKeys=0,miscCopies=0,
 eligibleKeys=0,eligibleCopies=0,eligibleChromaCopies=0,
 historicalReferenceEligibleKeys=0,historicalReferenceEligibleCopies=0,
 historicalUnmappedEligibleKeys=0,historicalUnmappedEligibleCopies=0,
 historicalVariantDriftEligibleKeys=0,historicalVariantDriftEligibleCopies=0,
 unsupportedClientCategoryKeys=0,
}
E[KEY]=R
local note=nil
pcall(function()
 if type(Instance)~="table" or type(Instance.new)~="function" then return end
 local lp=game:GetService("Players").LocalPlayer
 local pg=lp and lp:FindFirstChildOfClass("PlayerGui")
 if not pg then return end
 local screen=Instance.new("ScreenGui")
 screen.Name="GINGERSCOPE_STAGE83_READONLY";screen.ResetOnSpawn=false
 screen.DisplayOrder=155
 local frame=Instance.new("Frame")
 frame.Size=UDim2.fromOffset(410,116)
 frame.Position=UDim2.new(0.5,0,0,50)
 frame.AnchorPoint=Vector2.new(0.5,0)
 frame.BackgroundColor3=Color3.fromRGB(40,18,67)
 frame.BorderSizePixel=0;frame.Parent=screen
 note=Instance.new("TextLabel")
 note.Size=UDim2.new(1,-22,1,-16)
 note.Position=UDim2.fromOffset(11,8)
 note.BackgroundTransparency=1;note.TextWrapped=true
 note.TextColor3=Color3.fromRGB(245,238,255)
 note.TextSize=15
 note.Text="STAGE83 | READ-ONLY PUBLIC REFERENCE COVERAGE"
 note.Parent=frame
 screen.Parent=pg
end)
local function tell(message)
 print("[STAGE83 GUIDE] "..message)
 if note then pcall(function()note.Text=message end) end
end
local function copy(t)
 if type(setclipboard)=="function" then
  local ok,ret=pcall(setclipboard,t)
  if ok and ret~=false then return true end
 end
 if type(toclipboard)=="function" then
  local ok,ret=pcall(toclipboard,t)
  if ok and ret~=false then return true end
 end
 return false
end
local function done(status,reason)
 if status then R.status=status end
 if reason then R.reason=reason end
 local ok,encoded=pcall(function()
  return game:GetService("HttpService"):JSONEncode(R)
 end)
 if not ok or type(encoded)~="string" or #encoded>3800 then
  tell("Result could not be serialized; no trade actions used.")
  warn("[STAGE83] aggregate JSON output unavailable")
  return R
 end
 local line=MARK..encoded
 local copied=copy(line)
 print(line)
 tell(copied and "DONE: copied one aggregate line. No trade was made." or
     "DONE: copy ONE [GINGERSCOPE STAGE83 PUBLIC COVERAGE] console line.")
 return R
end
tell("One own-profile read. No trading, prices or item names reported.")
if not game or game.PlaceId~=142823291 then
 return done("WRONG_GAME","NOT_ORIGINAL_MM2")
end
-- Same isolation intent as Stage79/80, plus their completed one-shot session flags.
for _,other in ipairs({
 "GINGERSCOPE_STAGE79_SINGLE_OWNED_TYPE_PROBE",
 "GINGERSCOPE_STAGE80_ONE_METADATA_REASON_PROBE",
 "GINGERSCOPE_STAGE75_READONLY_13_TARGETS",
 "PDIDDLER_STAGE25_SCANNER_ONLY",
 "PDIDDLER_STAGE32_RESULT_CORRELATION_PROBE",
 "PDIDDLER_PART4_SESSION","PDIDDLER_OUTGOING_SESSION",
 "PDIDDLER_PART5_CONTROLLER","PDIDDLER_HOPPING_SESSION",
 "PDIDDLER_STAGE66_SAME_WINDOW_CLIENT_ONLY",
 "PDIDDLER_GINGERSCOPE_REPLACEMENT_PREVIEW"
}) do
 if E[other]~=nil then
  return done("OTHER_SESSION_ACTIVE_REJOIN_REQUIRED","ISOLATE_FROM_OTHER_PROBES")
 end
end
local ok,rs=pcall(function()return game:GetService("ReplicatedStorage")end)
if not ok or not rs then return done("REPLICATION_UNAVAILABLE","NO_REPLICATED_STORAGE") end
local db=rs:FindFirstChild("Database")
local sm=db and db:FindFirstChild("Sync")
if not sm then return done("SYNC_UNAVAILABLE","SYNC_MODULE_NOT_FOUND") end
local loaded,sync=pcall(require,sm)
if (not loaded or type(sync)~="table") and type(setthreadidentity)=="function" then
 local previous=nil
 if type(getthreadidentity)=="function" then
  pcall(function()previous=getthreadidentity()end)
 end
 pcall(setthreadidentity,2)
 loaded,sync=pcall(require,sm)
 pcall(setthreadidentity,previous or 8)
end
if not loaded or type(sync)~="table" or type(sync.Weapons)~="table" then
 return done("SYNC_UNAVAILABLE","CURRENT_CATALOGUE_UNREADABLE")
end
local hasHelper,helper,registry=pcall(function()
 local a=game:HttpGet(ROOT.."stage83_private_aggregate_coverage.lua",true)
 local b=game:HttpGet(ROOT.."stage83_public_slug_registry.lua",true)
 assert(type(a)=="string" and #a>250,"helper unavailable")
 assert(type(b)=="string" and #b>10000,"public registry unavailable")
 local h=assert(loadstring(a,"=stage83-pure-aggregate"))()
 local r=assert(loadstring(b,"=stage83-public-only-registry"))()
 assert(type(h)=="table" and type(h.audit)=="function","analyzer missing")
 assert(type(r)=="table" and type(r.entries)=="table","public registry missing")
 return h,r
end)
if not hasHelper then
 return done("PINNED_PUBLIC_HELPER_UNAVAILABLE","NO_UNVERIFIED_SOURCE_FALLBACK")
end
local remotes=rs:FindFirstChild("Remotes")
local inventory=remotes and remotes:FindFirstChild("Inventory")
local ownRemote=inventory and inventory:FindFirstChild("GetProfileData")
if not ownRemote or not ownRemote:IsA("RemoteFunction") then
 return done("OWN_PROFILE_REMOTE_MISSING","READ_ONLY_REMOTE_NOT_FOUND")
end
if tostring(game.JobId or "")~=job then
 return done("SESSION_CHANGED","JOB_CHANGED_BEFORE_READ")
end
local ended=false
local response=nil
local success=false
-- EXACTLY ONE read-only remote invocation. Timeout does not cancel a pending
-- invocation and MUST NOT start a retry automatically.
task.spawn(function()
 success,response=pcall(function()return ownRemote:InvokeServer()end)
 ended=true
end)
local deadline=os.clock()+4.5
while not ended and os.clock()<deadline do task.wait(0.05) end
if not ended then return done("OWN_READ_TIMED_OUT","NO_RETRY") end
if tostring(game.JobId or "")~=job then
 return done("SESSION_CHANGED","JOB_CHANGED_AFTER_READ")
end
if not success or type(response)~="table" then
 return done("PROFILE_UNREADABLE","SINGLE_READ_FAILED")
end
local function unwrap(value,depth)
 if type(value)~="table" or getmetatable(value)~=nil or depth>4 then return nil end
 if type(value.Weapons)=="table" and type(value.Weapons.Owned)=="table" then return value end
 for _,label in ipairs({"ProfileData","Profile","PlayerData","Data","Inventory","FullInventory"}) do
  local found=unwrap(rawget(value,label),depth+1)
  if found then return found end
 end
end
local profile=unwrap(response,0)
if not profile then return done("PROFILE_SHAPE_UNAVAILABLE","OWNED_WEAPONS_TABLE_NOT_FOUND") end
local safe,aggregates=pcall(helper.audit,profile.Weapons.Owned,sync.Weapons,registry)
-- Do not persist the raw profile or public key map in getgenv().
response=nil;profile=nil;registry=nil;helper=nil
if not safe or type(aggregates)~="table" or
   aggregates.readOnly~=true or aggregates.authorizesTrade~=false or
   aggregates.authorizesAccept~=false or aggregates.currentPricesVerified~=false or
   aggregates.mayReportProfit~=false or aggregates.mayUseForStrategyLearning~=false or
   aggregates.authenticatedOwnedInventory~=false then
 return done("AGGREGATION_FAILED_CLOSED","UNREVIEWED_HELPER_OUTPUT")
end
local allowed={
 "status","reason","historicalPublicRegistryEntries",
 "originalOwnedKeyTypesObserved","exactClientCatalogueLookupObserved",
 "historicalPublicReferenceCoverageObserved",
 "ownedKeys","ownedCopies","stringOwnedKeys","numericOwnedKeys","otherOwnedKeys",
 "invalidQuantities","unmappedClientKeys","untrustedMetadataKeys",
 "clientWeaponKeys","clientWeaponCopies","miscKeys","miscCopies",
 "eligibleKeys","eligibleCopies","eligibleChromaCopies",
 "historicalReferenceEligibleKeys","historicalReferenceEligibleCopies",
 "historicalUnmappedEligibleKeys","historicalUnmappedEligibleCopies",
 "historicalVariantDriftEligibleKeys","historicalVariantDriftEligibleCopies",
 "unsupportedClientCategoryKeys"
}
for _,name in ipairs(allowed) do R[name]=aggregates[name] end
return done()
