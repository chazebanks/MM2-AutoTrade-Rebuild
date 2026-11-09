-- Stage88 CONTACT-ONLY scanner presentation. Prices still use the original strict policy;
-- never turn an omitted/unverified eligible row into a zero-value item.
local V={}
local function finite(n) return type(n)=='number' and n==n and n~=math.huge and n~=-math.huge end
local function integer(n) return finite(n) and n>=0 and n==math.floor(n) end
local function quantity(n) return integer(n) and n>0 end
local function format(n)
 if not finite(n) then return 'UNVERIFIED' end
 if n==math.floor(n) then return tostring(math.floor(n)) end
 return string.format('%.2f',n)
end
local function asset(it) return tostring(it.page or '')..':'..tostring(it.id or '') end
local function copyCount(n) return integer(n) and format(n) or '?' end
local function current(profile)
 if type(profile)~='table' or type(profile.isFresh)~='function' then return false end
 local ok,result=pcall(profile.isFresh);return ok and result==true
end
function V.inventory(inv,profile,strict)
 local version=type(profile)=='table' and tostring(profile.version or 'unavailable') or 'unavailable'
 local source='Source: Supreme | '..version
 local fresh=current(profile)
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
 local counters={};local complete=shape
 for _,key in ipairs({'unmapped','unpriced','badQty'}) do
  local value=available and inv[key] or nil
  counters[#counters+1]=key..'='..copyCount(value)
  if not integer(value) or value~=0 then complete=false end
 end
 local priced
 if shape and fresh and type(strict)=='table' and type(strict.reprice)=='function' then
  local ok,result,why=pcall(strict.reprice,inv,profile)
  if ok and not why and type(result)=='table' and type(result.items)=='table' then priced=result end
 end
 local byAsset,duplicates,seen={},{},{}
 for _,it in ipairs(rows) do
  if type(it)=='table' then
   local key=asset(it)
   if seen[key] then duplicates[key]=true;complete=false end
   seen[key]=true
  end
 end
 for _,it in ipairs((priced and priced.items) or {}) do
  if type(it)=='table' then byAsset[asset(it)]=it end
 end
 local parts,count,total,unresolved={},0,0,0
 local countKnown=shape and integer(inv.unmapped) and inv.unmapped==0 and integer(inv.badQty) and inv.badQty==0
 for _,raw in ipairs(rows) do
  local it=type(raw)=='table' and raw or {}
  local qty=it.qty
  local qtyKnown=quantity(qty)
  if qtyKnown then count=count+qty else countKnown=false end
  local name=tostring(it.name or it.id or 'Unidentified item')
  local suffix=' x'..(qtyKnown and format(qty) or '?')
  local verified=byAsset[asset(it)]
  if duplicates[asset(it)] then verified=nil;countKnown=false end
  local unit=verified and verified.value
  if qtyKnown and finite(unit) and unit>0 and verified.qty==qty then
   local subtotal=unit*qty
   if finite(subtotal) then
    total=total+subtotal;parts[#parts+1]=name..suffix..' ('..format(subtotal)..')'
   else
    unresolved=unresolved+1;parts[#parts+1]=name..suffix..' (UNVERIFIED)'
   end
  else
   unresolved=unresolved+1
   local label=not fresh and 'UNVERIFIED: price expired or unavailable'
    or not qtyKnown and 'UNVERIFIED: invalid quantity'
    or 'UNPRICED / UNVERIFIED'
   parts[#parts+1]=name..suffix..' ('..label..')'
  end
 end
 if unresolved>0 or not priced then complete=false end
 if not shape then countKnown=false end
 local itemsText=#parts>0 and table.concat(parts,', ') or available and 'No eligible items in verified rows' or 'Inventory UNVERIFIED'
 local totalText
 if fresh and complete then totalText=format(total)
 elseif fresh and total>0 then totalText=format(total)..' verified subtotal + UNVERIFIED'
 else totalText='UNVERIFIED' end
 local state=not fresh and 'expired' or not available and 'unavailable' or complete and 'current' or 'partial'
 local countText=countKnown and format(count) or 'UNVERIFIED'
 local detail='Eligible copies: '..countText..' | Total value: '..totalText..'\nItems: '..itemsText..'\n'..source
 if not fresh then detail=detail..' | prices expired or unavailable' end
 if not complete then detail=detail..'\nVerification: '..table.concat(counters,' | ') end
 return {countText=countText,totalText=totalText,itemsText=itemsText,detail=detail,priceState=state}
end
local requests={sending=true,requesting=true,accepted=true,declined=true,ignored=true,
 notready=true,unavailable=true,left=true,sendfailed=true,processed=true}
local function reasonText(reason)
 local text=tostring(reason or 'awaiting assessment')
 if text=='own-proof-pending' or text=='own-inventory-unavailable' or text=='own-inventory-busy' or text=='own-read-unavailable'
  or text=='no-verified-owned-giveaway' then return 'Own proof pending ('..text..')' end
 if text:sub(1,17)=='own-proof-paused:' then return 'Paused ('..text..')' end
 if text=='transaction-owned' or text=='request-or-trade-owned' or text=='native-workflow-owned'
  or text=='part4-active' or text=='outgoing-owned' then return 'Paused ('..text..')' end
 return text
end
function V.row(rec,outgoing,request,profile,strict)
 local rarity=type(rec)=='table' and tostring(rec.state or 'unknown') or 'unknown'
 local state=rarity
 local detail='Inventory rarity: '..rarity:upper()..'\n'..V.inventory(type(rec)=='table' and rec.inv or nil,profile,strict).detail
 -- Contact readiness and price authority are independent on Stage88.
 -- Do not hide a known client contact candidate because a quote expired.
 if type(outgoing)=='table' then
  detail=detail..'\nContact only: '..tostring(outgoing.state or 'unknown'):upper()..' | '..reasonText(outgoing.reason)
 else detail=detail..'\nContact only: awaiting assessment' end
 if not current(profile) then
  detail=detail..'\nPRICES UNVERIFIED | No offer or final Accept authorized'
 end
 if type(request)=='table' and requests[request.state] then
  state=request.state
  if type(request.extra)=='string' and request.extra~='' then detail=request.extra..'\n'..detail end
 end
 return state,detail
end
function V.summary(white,black,unknown,outgoing,profile)
 local text='Inventory rarity: Whitelist '..copyCount(white)..' | Blacklist '..copyCount(black)..' | Unknown '..copyCount(unknown)
 if type(outgoing)~='table' then
  text=text..'\nContact only: awaiting assessment'
 else
  text=text..'\nContact candidates: Reachable '..copyCount(outgoing.reachable)
   ..' | No eligible items '..copyCount(outgoing.unprofitable)
   ..' | Unknown '..copyCount(outgoing.unknown)
 end
 if not current(profile) then
  text=text..'\nPRICES UNVERIFIED | No offers or Accept'
 end
 return text
end
return V
