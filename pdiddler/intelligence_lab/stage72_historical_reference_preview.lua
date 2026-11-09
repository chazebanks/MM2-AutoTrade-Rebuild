-- Stage72 isolated read-only market reference presentation.
-- It does NOT verify ownership, raw->checker identity, current values or
-- any trading decision. Never set a profile/item verified flag.
-- An exact public NAME and category match is INDICATIVE ONLY.
local M={}
local EXPECTED={ancient="https://supremevalues.com/mm2/ancients",
 godly="https://supremevalues.com/mm2/godlies",
 chroma="https://supremevalues.com/mm2/chromas"}
local function finite(n)
 return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge
end
local function integer(n)
 return finite(n) and n>=1 and n<=1000000 and n==math.floor(n)
end
local function safe(s)
 return type(s)=="string" and #s>0 and #s<=128
   and not s:find("[%c]")
end
local function format(n)
 if not finite(n) then return "UNVERIFIED" end
 if n==math.floor(n) then return tostring(math.floor(n)) end
 return string.format("%.2f",n)
end
local function output(status,reason)
 return {
  schema="gingerscope-stage72-indicative-historical-view-v1",
  status=status,reason=reason,readOnly=true,
  sourcePublishedAt="UNVERIFIED",
  sourceExpired=true,sourceAuthenticityProven=false,
  identityMappingVerified=false,sourceCurrentVerified=false,
  historicalReferenceCount=0,unmatchedCount=0,
  rows={},totalText="UNVERIFIED",portfolioTotal=nil,
  valuedInventoryComplete=false,
  outgoingPaused=true,
  numericTradingAuthority=false,
  authorizesTrade=false,authorizesAccept=false,
  mayReportProfit=false,mayRecordCompletedTrade=false,
  mayRecordRejectedTrade=false,mayUseForStrategyLearning=false,
  maySendDiscordWebhook=false
 }
end
local function sourceIndex(profile)
 if type(profile)~="table" or type(profile.profiles)~="table"
    or type(profile.sources)~="table"
    or not safe(profile.version)
    or not safe(profile.sourceTimestamp)
    or not finite(profile.publishedAtEpoch)
    or not finite(profile.observedAtEpoch)
    or not finite(profile.expiresAtEpoch) then
  return nil,"SOURCE_METADATA_MISSING"
 end
 local now=os.time()
 if not finite(now)
    or profile.publishedAtEpoch>profile.observedAtEpoch
    or profile.observedAtEpoch>now or profile.expiresAtEpoch>now+86400*2
    or profile.publishedAtEpoch<0 then
  return nil,"SOURCE_CLOCK_UNTRUSTED"
 end
 for page,url in pairs(EXPECTED) do
  local src=profile.sources[page]
  if type(src)~="table" or src.url~=url
     or type(src.sha256)~="string" or #src.sha256~=64
     or not src.sha256:match("^[0-9a-f]+$") then
   return nil,"SOURCE_PROVENANCE_SHAPE_INVALID"
  end
 end
 local index,rows={},0
 for _,r in pairs(profile.profiles) do
  if type(r)~="table" or not EXPECTED[r.page]
     or not safe(r.sourceName)
     or type(r.id)~="string" or not r.id:match("^%d+$")
     or type(r.name)~="string" then
   return nil,"SOURCE_ITEM_SCHEMA_INVALID"
  end
  local key=r.page.."|"..r.sourceName
  if index[key] then
   return nil,"DUPLICATE_PUBLIC_SOURCE_NAME_OR_VARIANT"
  end
  index[key]=r
  rows=rows+1
  if rows>10000 then return nil,"SOURCE_ITEM_COUNT_OVERFLOW" end
 end
 -- Locked initial source dataset; the next schema requires separate review
 -- when publisher expands beyond these 190 category-specific weapon names.
 if rows~=190 then return nil,"UNREVIEWED_SOURCE_COVERAGE" end
 return index,nil
end
function M.preview(inv,profile)
 local out=output("UNVERIFIED","NOT_EVALUATED")
 if type(inv)~="table" or type(inv.items)~="table" then
  out.reason="INVENTORY_UNAVAILABLE"
  return out
 end
 local source,why=sourceIndex(profile)
 if not source then
  out.reason=why or "SOURCE_UNAVAILABLE"
  return out
 end
 out.status="HISTORICAL_REFERENCE_ONLY"
 out.reason="NAME_MATCH_IS_NOT_RAW_IDENTITY_OR_LIVE_TRADE_QUOTE"
 out.sourcePublishedAt=profile.sourceTimestamp
 -- Even a recently published source will never be a verified trade price.
 -- "sourceExpired" reflects publisher/retrieval TTL only.
 out.sourceExpired = (os.time() >= profile.expiresAtEpoch)
 local count=0
 for i,it in pairs(inv.items) do
  if type(i)~="number" or i~=math.floor(i) or i<1 or i>10000
     or type(it)~="table" then
   out.status="UNVERIFIED"
   out.reason="MALFORMED_INVENTORY_ROWS"
   out.rows={}
   out.historicalReferenceCount=0
   return out
  end
  count=count+1
  if count>10000 then return output("UNVERIFIED","INVENTORY_ROWS_OVERFLOW") end
 end
 for i=1,count do
  if type(inv.items[i])~="table" then
   return output("UNVERIFIED","SPARSE_INVENTORY_ROWS")
  end
 end
 local seen={}
 for _,it in ipairs(inv.items) do
  local name,page=it.name,it.page
  if not safe(name) or not EXPECTED[page]
      or not safe(it.id)
      or seen[it.id]
      or it.cat~="Weapons" or
      (it.type~="Gun" and it.type~="Knife")
      or not integer(it.qty) then
   return output("UNVERIFIED","INVALID_OR_DUPLICATE_INPUT_ITEM")
  end
  seen[it.id]=true
  local rec=source[page.."|"..name]
  local chromaName=name:sub(1,7)=="Chroma "
  local pageNameCorrect=(page=="chroma")==chromaName
  local ok=pageNameCorrect and type(rec)=="table"
    and finite(rec.supremeValue) and rec.supremeValue>0
  local display=name.." x"..format(it.qty)
  if ok then
   -- This is a historical public NAME reference, not an authenticated raw
   -- key mapping. Never aggregate into a supposedly verified total.
   out.historicalReferenceCount=out.historicalReferenceCount+1
   display=display.." | Historical Supreme ref: "..
     format(rec.supremeValue).." each (UNVERIFIED, NOT FOR TRADING)"
  else
   out.unmatchedCount=out.unmatchedCount+1
   display=display.." | Historical ref: UNVERIFIED (no exact public name)"
  end
  out.rows[#out.rows+1]=display
 end
 return out
end
return M
