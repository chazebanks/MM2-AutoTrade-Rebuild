-- Pure, offline-testable current-own-profile choice extraction for MAIN.
-- No Roblox services, I/O, market prices, trade requests or Item offers.
-- All claims are CLIENT-SIDE and will be checked again by the PR216 runner.
local M={}
local function result(status,reason,choices)
 return {
  schema="gingerscope-p3-owned-choice-v1",
  status=status,reason=reason,choices=choices or {},
  rawItemIdsAuthenticated=false,pricesAuthenticated=false,
  authorizesOffer=false,authorizesAccept=false,
  serverCompletionProven=false,mayReportProfit=false,
  maySendDiscordWebhook=false,tradeOutcome="UNKNOWN",
 }
end
local function norm(s)
 return type(s)=="string" and s:lower():gsub("[^%w]","") or ""
end
local function protected(s)
 return norm(s):find("gingerscope",1,true)~=nil
end
local function rawValid(s)
 return type(s)=="string" and #s>0 and #s<=24
  and s:match("^[A-Za-z0-9_]+$")~=nil
end
local function nameValid(s)
 return type(s)=="string" and #s>0 and #s<=24 and
  not s:find("[%c]") and not s:match("^%s") and
  not s:match("%s$")
end
local function ownedProfile(raw,depth)
 if type(raw)~="table" or depth>4 then return nil end
 if type(raw.Weapons)=="table" and type(raw.Weapons.Owned)=="table" then
  return raw
 end
 for _,k in ipairs({"ProfileData","Profile","PlayerData","Data",
                     "Inventory","FullInventory"}) do
  local x=ownedProfile(raw[k],depth+1)
  if x then return x end
 end
 return nil
end
local function integerQty(x)
 if type(x)=="string" then
  if not x:match("^%d+$") or #x>9 then return nil end
  x=tonumber(x)
 end
 if type(x)~="number" or x~=x or x<0 or x>1000000 or
    x~=math.floor(x) then return nil end
 return x
end
local function metaShape(d)
 if type(d)~="table" then return nil end
 local base=d.ItemName or d.Name
 if not nameValid(base) then return nil end
 local chroma=d.Chroma==true
 local rarity=norm(d.Rarity)
 local kind=norm(d.ItemType)
 if kind~="knife" and kind~="gun" then return nil end
 if not chroma and rarity~="ancient" and rarity~="godly" then
  return nil
 end
 if d.EvoBaseID~=nil or d.EvoIndex~=nil or
   d.Tradable==false or d.CanTrade==false or
   d.Untradable==true or d.NonTradable==true then
  return nil
 end
 local display=base
 if chroma then
  -- Underlying original trade GUI shows a Chroma tag with the BASE name.
  -- If the catalogue already prefixes "Chroma", strip exactly that prefix.
  display=display:gsub("^[Cc][Hh][Rr][Oo][Mm][Aa]%s+","")
 end
 if not nameValid(display) or protected(base) or protected(display) then
  return nil
 end
 return {
  display=display,chroma=chroma,
  kind=kind,rarity=rarity,
 }
end
-- Build the same game-raw-key metadata index as the immutable original
-- scanner, and fail closed if the two native source sections conflict.
local function indexCatalog(sync)
 if type(sync)~="table" or
    type(sync.Weapons)~="table" then return nil end
 local meta={}
 for _,part in ipairs({sync.Weapons,sync.Item}) do
  if type(part)=="table" then
   for k,d in pairs(part) do
    local id=tostring(k)
    if not rawValid(id) then return nil end
    local record=metaShape(d)
    local prev=meta[id]
    if prev and record and
      (prev.display~=record.display or prev.chroma~=record.chroma or
       prev.kind~=record.kind or prev.rarity~=record.rarity) then
      return nil
    end
    -- A non-tradable / missing-metadata entry cannot erase a documented
    -- tradable entry from the other catalog; final user selection still
    -- requires the live PR216 scanner's own independent current check.
    if record then meta[id]=record end
   end
  end
 end
 return meta
end
function M.build(rawProfile,sync)
 local profile=ownedProfile(rawProfile,0)
 if not profile then
  return result("BLOCKED","CURRENT_OWN_PROFILE_UNREADABLE")
 end
 local meta=indexCatalog(sync)
 if not meta then
  return result("BLOCKED","CURRENT_GAME_WEAPON_CATALOG_UNREADABLE")
 end
 local choices={}
 local owned=profile.Weapons.Owned
 local seenCount=0
 for raw,count in pairs(owned) do
  seenCount+=1
  if seenCount>4000 then
   return result("BLOCKED","OWN_PROFILE_TOO_LARGE")
  end
  if type(raw)~="string" or not rawValid(raw) or
     protected(raw) then
   return result("BLOCKED","OWN_WEAPON_RAW_KEY_INVALID_OR_PROTECTED")
  end
  local qty=integerQty(count)
  if qty==nil then
   return result("BLOCKED","OWN_WEAPON_QUANTITY_INVALID")
  end
  -- An unmapped key will also make immutable scanner's own-inventory
  -- exact validation fail. Refuse to present a misleading selectable list.
  if qty>0 and not meta[raw] then
   -- Do not allow unknown/game-only keys to be offered under this pilot.
   return result("BLOCKED","OWN_WEAPON_METADATA_UNRESOLVED")
  end
  if qty>0 and meta[raw] then
   local m=meta[raw]
   choices[#choices+1]={
    raw=raw,display=m.display,
    chroma=m.chroma,kind=m.kind,qty=qty,
   }
  end
 end
 if #choices==0 then
  return result("BLOCKED","NO_ELIGIBLE_CURRENT_OWN_WEAPONS")
 end
 if #choices>256 then
  return result("BLOCKED","TOO_MANY_ELIGIBLE_OWN_WEAPONS")
 end
 table.sort(choices,function(a,b)
  local akey=a.display:lower()
  local bkey=b.display:lower()
  if akey~=bkey then return akey<bkey end
  return a.raw<b.raw
 end)
 return result("CLIENT_ELIGIBLE_OWN_CHOICES",
   "SELECT_ONE_ITEM_MANUALLY_NO_TRADE_AUTHORITY",choices)
end
return M
