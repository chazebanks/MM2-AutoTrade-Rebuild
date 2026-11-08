-- Stage53: READ-ONLY Sync.Weapons vs Sync.Item overwrite/variant census.
-- Does not bind an MM2 raw weapon key to a Supreme checker ID.
-- Counts only; never emits item names, raw IDs, player identities or source payloads.
local MARK="[GINGERSCOPE STAGE53 CATALOG CENSUS]"
local report={
 schema="gingerscope-stage53-catalog-overwrite-v1",
 readOnly=true, clientOnly=true,
 mappingAuthenticated=false, uniqueWeaponInstanceProven=false,
 eventSessionAssociationProven=false, serverAttestation=false,
 serverCompletionProven=false, authorizesTrade=false,
 authorizesAccept=false, mayRecordCompletedTrade=false,
 mayReportProfit=false, tradeOutcome="UNKNOWN",
 status="INCOMPLETE",
 weaponsRows=0, itemRows=0, weaponsEligible=0, itemEligible=0,
 overlapEligible=0, exactOverlaps=0, partialOverlaps=0,
 conflictingOverlaps=0, eligibilityDisagreements=0,
 printableKeyCollisions=0, invalidRows=0, sameTable=false
}
local function emit(status)
 report.status=status
 local ok,serialized=pcall(function()
  return game:GetService("HttpService"):JSONEncode(report)
 end)
 if ok then print(MARK.." "..serialized)
 else print(MARK.." REPORT_ENCODING_FAILED") end
 return report
end
local function norm(x)
 if x==nil then return nil end
 local v=tostring(x):lower():gsub("[^%w]","")
 return v~="" and v or nil
end
local function present(x)
 return x~=nil and tostring(x)~=""
end
local function asset(x)
 if not present(x) then return nil end
 local t=tostring(x)
 return t:match("(%d%d%d%d%d+)") or norm(t)
end
local function shape(d)
 local rarity=norm(d.Rarity)
 local typ=norm(d.ItemType)
 local chroma=d.Chroma
 local eligible=(chroma==true or rarity=="ancient" or rarity=="godly")
  and (typ=="knife" or typ=="gun")
 return {
  eligible=eligible,
  name=norm(d.ItemName or d.Name),
  rarity=rarity, typ=typ,
  chroma=type(chroma)=="boolean" and tostring(chroma) or nil,
  year=norm(d.Year or d.EventYear),
  event=norm(d.Event or d.Season),
  itemId=norm(d.ItemID),
  artwork=asset(d.Image or d.Icon or d.Texture)
 }
end
local function collect(src)
 local out,n,eligible,invalid,collision={},{},{},{},{}
 -- Locals above intentionally initialized below; no external state is retained.
 out={}; n=0; eligible=0; invalid=0; collision=0
 for raw,d in pairs(src) do
  if (type(raw)~="string" and type(raw)~="number") or type(d)~="table" then
   invalid=invalid+1
  else
   n=n+1
   local k=tostring(raw)
   local v=shape(d)
   if v.eligible then eligible=eligible+1 end
   if out[k] then collision=collision+1
   else out[k]=v end
  end
 end
 return out,n,eligible,invalid,collision
end
local function relation(a,b)
 local conflict,unknown=false,false
 -- Missing information is NOT evidence of equality.
 for _,field in ipairs({"name","rarity","typ","chroma","year","event","itemId","artwork"}) do
  local x,y=a[field],b[field]
  if x==nil or y==nil then unknown=true
  elseif x~=y then conflict=true end
 end
 if conflict then return "CONFLICT" end
 if unknown then return "PARTIAL" end
 return "EXACT_CLIENT_FIELDS"
end
if type(game)~="userdata" and type(game)~="table" then return emit("GAME_UNAVAILABLE") end
if game.PlaceId~=142823291 then return emit("WRONG_GAME") end
local initialJob=tostring(game.JobId or "")
local ok,RS=pcall(function()return game:GetService("ReplicatedStorage")end)
if not ok or not RS then return emit("REPLICATED_STORAGE_UNAVAILABLE") end
local db=RS:FindFirstChild("Database")
local syncModule=db and db:FindFirstChild("Sync")
if not syncModule then return emit("SYNC_MODULE_MISSING") end
local success,sync=pcall(require,syncModule)
if (not success or type(sync)~="table") and setthreadidentity then
 local old
 if getthreadidentity then pcall(function()old=getthreadidentity()end)end
 pcall(setthreadidentity,2)
 success,sync=pcall(require,syncModule)
 pcall(setthreadidentity,old or 8)
end
if not success or type(sync)~="table" then return emit("SYNC_UNAVAILABLE") end
if tostring(game.JobId or "")~=initialJob then return emit("SERVER_CHANGED") end
if type(sync.Weapons)~="table" or type(sync.Item)~="table" then
 return emit("SYNC_SOURCE_MISSING")
end
local wa,wn,we,wi,wc=collect(sync.Weapons)
local ia,an,ae,ai,ac=collect(sync.Item)
report.weaponsRows=wn
report.itemRows=an
report.weaponsEligible=we
report.itemEligible=ae
report.invalidRows=wi+ai
report.printableKeyCollisions=wc+ac
report.sameTable=(sync.Weapons==sync.Item)
if report.sameTable then
 return emit(report.printableKeyCollisions>0 and "AMBIGUOUS_PRINTABLE_KEYS" or "SAME_TABLE_CLIENT_ONLY")
end
for key,left in pairs(wa) do
 local right=ia[key]
 if right and (left.eligible or right.eligible) then
  report.overlapEligible=report.overlapEligible+1
  if left.eligible~=right.eligible then
   report.eligibilityDisagreements=report.eligibilityDisagreements+1
  end
  local match=relation(left,right)
  if match=="CONFLICT" then report.conflictingOverlaps=report.conflictingOverlaps+1
  elseif match=="PARTIAL" then report.partialOverlaps=report.partialOverlaps+1
  else report.exactOverlaps=report.exactOverlaps+1 end
 end
end
if tostring(game.JobId or "")~=initialJob then return emit("SERVER_CHANGED") end
if report.invalidRows>0 or report.printableKeyCollisions>0 then return emit("INVALID_CATALOG_SHAPE") end
if report.conflictingOverlaps>0 or report.eligibilityDisagreements>0 then return emit("CATALOG_METADATA_CONFLICT") end
if report.partialOverlaps>0 then return emit("CATALOG_METADATA_PARTIAL") end
if report.overlapEligible==0 then return emit("NO_ELIGIBLE_OVERLAP_OBSERVED") end
return emit("CLIENT_OVERLAP_CONSISTENT_UNAUTHENTICATED")
