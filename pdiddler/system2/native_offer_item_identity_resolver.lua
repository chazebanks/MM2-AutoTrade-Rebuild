-- System 2: exact offered-item resolution BEFORE any strategic evaluation.
-- A label is never authoritative where variants, tiers or aliases collide.
-- This module contains no Roblox globals, actions, prices or learner status.
-- It returns a precise non-identifying failure reason; unknowns STOP.
local M={}
local MAX_CATALOG=12000
local MAX_STACK=10000
local CROSS_TIER_NAME_COLLISIONS={laser=true} -- original Stage9 observed
local function key(k)
 return type(k)=="string" and #k>=1 and #k<=90 and
  k:match("^[A-Za-z0-9_]+$")~=nil
end
local function norm(s)
 if type(s)~="string" or #s<1 or #s>160 then return nil end
 local n=s:lower():gsub("^%s+",""):gsub("%s+$",""):gsub("%s+"," ")
 return #n>0 and n or nil
end
local function expectedMeta(m)
 if type(m)~="table" then return nil end
 local label=norm(m.ItemName or m.Name)
 local typ=norm(m.ItemType)
 local rarity=norm(m.Rarity)
 if not label or not typ or not rarity or
  (m.Chroma~=nil and type(m.Chroma)~="boolean") then return nil end
 local chroma=m.Chroma==true
 local base=label
 if chroma and label:sub(1,7)=="chroma " then base=label:sub(8) end
 local eligible=(typ=="gun" or typ=="knife") and
  (rarity=="godly" or rarity=="ancient") and
  m.Tradable~=false and m.CanTrade~=false and
  m.Untradable~=true and m.NonTradable~=true and
  m.EvoBaseID==nil and m.EvoIndex==nil and
  base~="???" and #base>0
 return {name=base,chroma=chroma,eligible=eligible,
  rarity=rarity,kind=typ}
end
local function equalMeta(a,b)
 return a.name==b.name and a.chroma==b.chroma and
  a.eligible==b.eligible and a.rarity==b.rarity and
  a.kind==b.kind
end
function M.buildCatalog(sync)
 if type(sync)~="table" or type(sync.Weapons)~="table" then
  return nil,"LIVE_WEAPON_CATALOG_MISSING"
 end
 local byId,byName={},{}
 local count=0
 for _,section in ipairs({"Weapons","Item"}) do
  local rows=sync[section]
  if rows~=nil and type(rows)~="table" then
   return nil,"LIVE_CATALOG_SECTION_INVALID"
  end
  if rows then
   for id,meta in pairs(rows) do
    count+=1
    if count>MAX_CATALOG then return nil,"LIVE_CATALOG_OVERSIZED" end
    if key(id) and type(meta)=="table" then
     local r=expectedMeta(meta)
     if not r then return nil,"LIVE_CATALOG_METADATA_INVALID" end
     if byId[id] then
      if not equalMeta(byId[id],r) then
       return nil,"LIVE_CATALOG_DUPLICATE_RAW_KEY_CONFLICT"
      end
     else
      byId[id]=r
      byName[r.name]=byName[r.name] or {}
      table.insert(byName[r.name],id)
     end
    end
   end
  end
 end
 if next(byId)==nil then return nil,"LIVE_CATALOG_EMPTY" end
 return {byId=byId,byName=byName},nil
end
local function parseLabel(display)
 local n=norm(display)
 if not n then return nil,nil,"SLOT_VISIBLE_NAME_MISSING" end
 local prefixed=n:sub(1,7)=="chroma "
 if prefixed then n=n:sub(8) end
 if #n==0 then return nil,nil,"SLOT_VISIBLE_NAME_INVALID" end
 return n,prefixed,nil
end
local function exactAttr(attrs)
 if type(attrs)~="table" then return nil,"SLOT_RAW_ATTRIBUTES_MISSING" end
 local found
 local n=0
 for k,v in pairs(attrs) do
  n+=1
  if n>5 or not ({ItemId=true,ItemID=true,ID=true,WeaponId=true,WeaponID=true})[k] then
   return nil,"SLOT_UNEXPECTED_RAW_ATTRIBUTE"
  end
  if v~=nil then
   if not key(v) then return nil,"SLOT_RAW_ATTRIBUTE_MALFORMED" end
   if found and found~=v then return nil,"SLOT_CONFLICTING_RAW_ATTRIBUTES" end
   found=v
  end
 end
 return found,nil
end
function M.resolve(index,slot,parseQty)
 if type(index)~="table" or type(index.byId)~="table" or
  type(index.byName)~="table" or type(slot)~="table" or
  type(parseQty)~="function" then
  return nil,nil,"SLOT_RESOLVER_INPUT_INVALID"
 end
 for k in pairs(slot) do
  if k~="label" and k~="amountText" and k~="chromaTag" and k~="rawAttrs" then
   return nil,nil,"SLOT_UNEXPECTED_INPUT_FIELD"
  end
 end
 if type(slot.chromaTag)~="boolean" then
  return nil,nil,"SLOT_CHROMA_TAG_STATE_UNAVAILABLE"
 end
 if type(slot.amountText)~="string" then
  return nil,nil,"SLOT_QUANTITY_LABEL_MISSING"
 end
 local success,quantity=pcall(parseQty,slot.amountText)
 if not success or type(quantity)~="number" or
   quantity~=math.floor(quantity) or
   quantity<1 or quantity>MAX_STACK then
  return nil,nil,"SLOT_QUANTITY_INVALID_OR_UNPROVEN"
 end
 local name,titleChroma,why=parseLabel(slot.label)
 if not name then return nil,nil,why end
 local id,attributeWhy=exactAttr(slot.rawAttrs)
 if attributeWhy then return nil,nil,attributeWhy end
 local variantIndicated=titleChroma or slot.chromaTag
 local chosen
 if id then
  chosen=index.byId[id]
  if not chosen then return nil,nil,"RAW_ID_NOT_IN_LIVE_CATALOG" end
  if chosen.name~=name then
   return nil,nil,"RAW_ID_VISIBLE_NAME_MISMATCH"
  end
  if variantIndicated and chosen.chroma~=true then
   return nil,nil,"RAW_ID_CHROMA_VARIANT_CONFLICT"
  end
 else
  local list=index.byName[name]
  if type(list)~="table" or #list==0 then
   return nil,nil,"VISIBLE_NAME_NOT_IN_LIVE_CATALOG"
  end
  if CROSS_TIER_NAME_COLLISIONS[name] then
   return nil,nil,"KNOWN_CROSS_TIER_NAME_COLLISION_NEEDS_RAW_ID"
  end
  local matches={}
  for _,k in ipairs(list) do
   local rec=index.byId[k]
   if rec and (not variantIndicated or rec.chroma==true) then
    matches[#matches+1]=k
   end
  end
  if #matches~=1 then
   return nil,nil,"NAME_ONLY_CATALOG_VARIANT_OR_ALIAS_AMBIGUOUS"
  end
  id=matches[1];chosen=index.byId[id]
 end
 if chosen.eligible~=true then
  return nil,nil,"OFFERED_WEAPON_INELIGIBLE_OR_EXCLUDED"
 end
 return id,quantity,"RESOLVED_CLIENT_CATALOG_ONLY"
end
return M
