-- Project Gingerscope: valuation-only adapter for existing scanner GUI and P3.
-- REPLACES the old +15 Supreme trading policy in the new bootstrap.
-- No plan selection, profit floor, bargaining, OfferItem, Accept or Trade action.
local M={}
local function finite(n)
 return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge
end
local function integer(n)
 return finite(n) and n>=1 and n==math.floor(n) and n<=1000000
end
local function normal(s)
 return tostring(s or ""):gsub("’","'"):lower()
  :gsub("^%s+",""):gsub("%s+$",""):gsub("%s+"," ")
end
function M.reprice(inv,profile)
 if type(inv)~="table" or type(inv.items)~="table" then
  return nil,"inventory-unavailable"
 end
 local out={}
 for k,v in pairs(inv) do out[k]=v end
 out.items={}
 out.unmapped=tonumber(inv.unmapped) or 0
 out.unpriced=tonumber(inv.unpriced) or 0
 out.badQty=tonumber(inv.badQty) or 0
 local fresh=false
 if type(profile)=="table" and type(profile.isFresh)=="function" then
  local ok,v=pcall(profile.isFresh)
  fresh=ok and v==true
 end
 local seen={}
 for _,it in ipairs(inv.items) do
  local page=type(it)=="table" and it.page or nil
  local id=type(it)=="table" and it.id or nil
  local checker=type(it)=="table" and it.checkerId or nil
  local key=tostring(page)..":"..tostring(id)
  local r=nil
  if fresh and type(profile.get)=="function" and type(checker)=="string"
      and checker:match("^%d+$") and (page=="ancient" or page=="chroma" or page=="godly") then
   local ok,result=pcall(profile.get,page,checker)
   if ok then r=result end
  end
  local formatOK=type(it)=="table" and it.cat=="Weapons"
       and (it.type=="Knife" or it.type=="Gun")
  if not formatOK then
   out.unmapped=out.unmapped+1
  elseif not integer(it.qty) or seen[key] then
   out.badQty=out.badQty+1
  elseif type(id)~="string" or id=="" or type(checker)~="string"
      or not checker:match("^%d+$") or not r or r.verified~=true
      or tostring(r.page)~=tostring(page) or tostring(r.id)~=tostring(checker)
      or normal(r.name)~=normal(it.name)
      or not finite(r.supremeValue) or r.supremeValue<=0
      or not finite(r.demand) or r.demand<0 or r.demand>11
      or type(r.stability)~="string" or r.stability=="" then
   out.unpriced=out.unpriced+1
  else
   local copy={}
   for k,v in pairs(it) do copy[k]=v end
   copy.value=r.supremeValue
   copy.supremeValue=r.supremeValue
   copy.demand=r.demand
   copy.stability=r.stability
   out.items[#out.items+1]=copy
  end
  seen[key]=true
 end
 out.value=0
 for _,it in ipairs(out.items) do out.value=out.value+it.value*it.qty end
 out.total=out.value
 out.supremeVersion=profile and profile.version
 if not fresh then return out,"supreme-profile-stale" end
 return out,nil
end
return M
