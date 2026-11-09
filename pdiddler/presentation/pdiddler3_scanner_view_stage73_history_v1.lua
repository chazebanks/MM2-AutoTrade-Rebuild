-- Stage73 scanner-only view for historical source-name references.
local HISTORICAL_PREVIEW=...
assert(type(HISTORICAL_PREVIEW)=="table" and
 type(HISTORICAL_PREVIEW.preview)=="function",
 "Stage73 read-only reference module missing")
-- History mode has no current-price path, regardless of the device clock.
local V={}
local function integer(n) return type(n)=='number' and n>=0 and n<math.huge and n==math.floor(n) end
local function quantity(n) return integer(n) and n>0 end
local function asset(it) return tostring(it.page or '')..':'..tostring(it.id or '') end
local function copyCount(n) return integer(n) and tostring(math.floor(n)) or '?' end
function V.inventory(inv,profile)
 local version=type(profile)=='table' and tostring(profile.version or 'unavailable') or 'unavailable'
 local available=type(inv)=='table' and type(inv.items)=='table'
 local shape=available
 local rows,indices={},{}
 if available then
  for index,it in pairs(inv.items) do
   if integer(index) and index>0 then indices[#indices+1]=index
   else shape=false end
  end
  table.sort(indices)
  for index,rawIndex in ipairs(indices) do
   if index~=rawIndex then shape=false end
   rows[#rows+1]=inv.items[rawIndex]
  end
 end
 local counters={}
 for _,key in ipairs({'unmapped','unpriced','badQty'}) do
  local value=available and inv[key] or nil
  counters[#counters+1]=key..'='..copyCount(value)
 end
 local parts,seen,count={},{},0
 local countKnown=shape and integer(inv.unmapped) and inv.unmapped==0 and integer(inv.badQty) and inv.badQty==0
 for _,raw in ipairs(rows) do
  local it=type(raw)=='table' and raw or {}
  local key=asset(it)
  if seen[key] then countKnown=false end
  seen[key]=true
  local qty=it.qty
  local qtyKnown=quantity(qty)
  if qtyKnown then count=count+qty else countKnown=false end
  local name=tostring(it.name or it.id or 'Unidentified item')
  parts[#parts+1]=name..' x'..(qtyKnown and copyCount(qty) or '?')
   ..' (UNVERIFIED: price expired or unavailable)'
 end
 local itemsText=#parts>0 and table.concat(parts,', ') or available and 'No eligible items in verified rows' or 'Inventory UNVERIFIED'
 local countText=countKnown and integer(count) and copyCount(count) or 'UNVERIFIED'
 local detail='Eligible copies: '..countText..' | Total value: UNVERIFIED\nItems: '..itemsText
  ..'\nSource: Supreme | '..version..' | prices expired or unavailable'
  ..'\nVerification: '..table.concat(counters,' | ')
 local shown=0
 if available then
  local ok,h=pcall(HISTORICAL_PREVIEW.preview,inv,profile)
  if ok and type(h)=="table" and h.status=="HISTORICAL_REFERENCE_ONLY"
    and h.outgoingPaused==true and h.totalText=="UNVERIFIED"
    and h.portfolioTotal==nil and h.authorizesTrade==false
    and h.authorizesAccept==false and h.identityMappingVerified==false
    and type(h.rows)=="table" then
   local refs={}
   for _,label in ipairs(h.rows) do
    if type(label)=="string" and
        label:find("Historical Supreme ref:",1,true)
        and label:find("UNVERIFIED, NOT FOR TRADING",1,true)
        and #refs<3 then
     refs[#refs+1]=label
    end
   end
   shown=#refs
   if shown>0 then
    detail=detail..'\nHISTORICAL REFERENCES ONLY (UNVERIFIED; NO TRADING)'
     ..'\nSource published: '..tostring(h.sourcePublishedAt)
     ..'\n'..table.concat(refs,'\n')
     ..(h.historicalReferenceCount>shown and
        '\nAdditional historical references omitted from preview' or '')
   end
  end
 end
 return {countText=countText,totalText='UNVERIFIED',itemsText=itemsText,
   detail=detail,priceState='expired',historicalReferencesShown=shown}
end
local requests={sending=true,requesting=true,accepted=true,declined=true,ignored=true,
 notready=true,unavailable=true,left=true,sendfailed=true,processed=true}
function V.row(rec,_,request,profile)
 local rarity=type(rec)=='table' and tostring(rec.state or 'unknown') or 'unknown'
 local state=rarity
 local detail='Inventory rarity: '..rarity:upper()..'\n'..V.inventory(type(rec)=='table' and rec.inv or nil,profile).detail
  ..'\nOutgoing: UNKNOWN | Paused: Supreme prices expired or unavailable'
 if type(request)=='table' and requests[request.state] then
  state=request.state
  if type(request.extra)=='string' and request.extra~='' then detail=request.extra..'\n'..detail end
 end
 return state,detail
end
function V.summary(white,black,unknown)
 local text='Inventory rarity: Whitelist '..copyCount(white)..' | Blacklist '..copyCount(black)..' | Unknown '..copyCount(unknown)
 return text..'\nOutgoing: paused - Supreme prices expired or unavailable'
end
return V
