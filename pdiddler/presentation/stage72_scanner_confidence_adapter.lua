-- Stage72: fail-closed adapter for original T4.4 scanner presentation API.
-- Designed ONLY for isolated scanner-only Stage72 loader; no outgoing,
-- OfferItem, AcceptTrade, hopping, price authority, Discord or learning.
local Adapter={}
local function safe(x,limit)
 local s=type(x)=="string" and x or ""
 s=s:gsub("[%c]"," "):gsub("%s+"," ")
 s=s:gsub("^%s+",""):gsub("%s+$","")
 if #s==0 then return "UNKNOWN" end
 if #s>(limit or 100) then s=s:sub(1,limit or 100).."...(truncated)" end
 return s
end
local function copies(x)
 return type(x)=="number" and x==x and x>=0
  and x<=1000000 and x==math.floor(x) and tostring(x) or "?"
end
function Adapter.new(proof,confidence)
 if type(proof)~="table" or type(proof.evaluate)~="function"
   or type(confidence)~="table" or type(confidence.describe)~="function" then
  return nil,"MISSING_RESEARCH_PROOF_DEPENDENCIES"
 end
 local View={}
 local function describe(inv,profile)
  local ok,r=pcall(confidence.describe,inv,profile,proof)
  if not ok or type(r)~="table"
   or r.schema~="gingerscope-stage71-inventory-price-confidence-v1"
   or r.authorizesTrade~=false or r.authorizesAccept~=false
   or r.marketValuesShown~=false or r.authoritativeTotal~=nil
   or type(r.text)~="string" then
    return {
      schema="gingerscope-stage71-inventory-price-confidence-v1",
      inventoryState="UNAVAILABLE",itemCountKnown=false,
      priceState="SOURCE_AND_ITEM_ID_NOT_VALIDATED",
      text="Inventory observation unavailable\nSupreme quote: UNVERIFIED\n"..
        "Total verified value: UNVERIFIED (not 0)\n"..
        "Outgoing: PAUSED | Auto Accept: DISABLED | Discord learning: DISABLED"
    }
  end
  return r
 end
 function View.inventory(inv,profile,strict)
  -- "strict" is the legacy P4 reprice adapter passed by the scanner.
  -- NEVER call it: its name+checkerId test can promote fuzzy/alias mapping.
  local r=describe(inv,profile)
  local n=r.itemCountKnown==true and copies(r.itemCount) or "UNVERIFIED"
  return {
   countText=n,totalText="UNVERIFIED",
   itemsText="Prices UNVERIFIED: see client-observed weapon rows below",
   detail=r.text,priceState=r.priceState,
   inventoryState=r.inventoryState,
   sourceCurrentPriceVerified=false,
   rawCheckerIdentityVerified=false,
   authorizesTrade=false,authorizesAccept=false
  }
 end
 local requests={
  sending=true,requesting=true,accepted=true,declined=true,
  ignored=true,notready=true,unavailable=true,left=true,
  sendfailed=true,processed=true
 }
 function View.row(rec,outgoing,request,profile,strict)
  local rarity=type(rec)=="table" and safe(rec.state,25) or "UNKNOWN"
  local r=View.inventory(type(rec)=="table" and rec.inv or nil,profile,strict)
  local state=rarity:lower()
  local detail="Inventory rarity: "..rarity:upper().."\n"..r.detail
  if type(request)=="table" and requests[request.state] then
   state=request.state
   if type(request.extra)=="string" and request.extra~="" then
    detail="Request note (NOT a settled trade): "..safe(request.extra,120)
      .."\n"..detail
   end
  end
  -- No caller-provided outgoing state can override this scanner-only policy.
  detail=detail.."\nTrade outcome: UNKNOWN (scanner-only observation)"
  return state,detail
 end
 function View.summary(white,black,unknown,outgoing,profile)
  return "Inventory rarity: Whitelist "..copies(white)
    .." | Blacklist "..copies(black)
    .." | Unknown "..copies(unknown)
    .."\nInventory detection: client-observed only; prices separately UNVERIFIED"
    .."\nOutgoing: PAUSED | No numeric trading authority"
 end
 return View,nil
end
return Adapter
