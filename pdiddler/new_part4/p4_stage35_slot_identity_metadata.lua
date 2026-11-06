-- Stage35: PURE slot metadata SHAPE normalizer. No item values, IDs,
-- icon asset URLs, UI text, player names, calls, or transaction authority.
local M={}
local function safe(v)
 return type(v)=="string" and #v>=1 and #v<=50 and
  v:match("^[%a_][%w_]*$")~=nil
end
local function pathSafe(v)
 if type(v)~="string" or #v>150 or #v==0 then return false end
 for p in v:gmatch("[^%.]+") do if not safe(p) then return false end end
 return true
end
local function candidate(name)
 local x=name:lower()
 return x=="id" or x=="itemid" or x=="item_id" or
  x=="weaponid" or x=="weapon_id" or x=="itemkey" or
  x=="weaponkey" or x=="itemdata" or x=="weapondata" or
  x=="itemname" or x=="weaponname" or x=="itemtype" or
  x=="rarity" or x=="chroma" or x=="icon" or x=="image" or
  x=="thumbnail" or x:find("itemid",1,true)~=nil or
  x:find("weaponid",1,true)~=nil
end
local function numeric(v)
 return type(v)=="number" and v==v and v>=0 and v<math.huge
     and v==math.floor(v)
end
local function compact(rows,kind)
 local out,seen={},{}
 if type(rows)~="table" then return out,false end
 if #rows>180 then return out,false end
 for _,r in ipairs(rows) do
  if type(r)~="table" then return {},false end
  local path=r.path
  if pathSafe(path) and not seen[path] and #out<20 then
   if kind=="attrs" then
    if candidate(path) and (r.valueType=="string" or
      r.valueType=="number" or r.valueType=="boolean") and
      type(r.nonempty)=="boolean" then
     out[#out+1]={path=path,valueType=r.valueType,
       nonempty=r.nonempty}
     seen[path]=true
    end
   elseif kind=="values" then
    local last=path:match("([^%.]+)$")
    if candidate(last) and (r.valueType=="string" or
      r.valueType=="number" or r.valueType=="boolean") and
      type(r.nonempty)=="boolean" then
     out[#out+1]={path=path,valueType=r.valueType,
       nonempty=r.nonempty}
     seen[path]=true
    end
   elseif kind=="images" then
    if (r.kind=="ImageLabel" or r.kind=="ImageButton") and
       type(r.nonempty)=="boolean" and
       type(r.spriteRect)=="boolean" then
     out[#out+1]={path=path,nonempty=r.nonempty,
       spriteRect=r.spriteRect}
     seen[path]=true
    end
   end
  end
 end
 table.sort(out,function(a,b)return a.path<b.path end)
 return out,true
end
function M.report(raw)
 local base={schema="gingerscope-stage35-slot-identity-metadata-shape-v1",
  status="INCOMPLETE",reason="no-populated-native-offer-slot",
  slotLocated=false,offerSide=nil,slotIndex=nil,
  itemNameLabelPresent=false,attributeCandidates={},
  candidateValueNodes={},imageNodes={},
  candidateIdFieldPresent=false,filledImageNodePresent=false,
  rawIdAuthenticated=false,exactItemIdentityConfirmed=false,
  readOnly=true,tradeOutcome="UNKNOWN",
  serverAttestation=false,serverCompletionProven=false,
  causalAttributionProven=false,
  authorizesTrade=false,authorizesAccept=false,
  mayRecordCompletedTrade=false,mayReportProfit=false}
 if type(raw)~="table" then return base end
 if raw.side~="TheirOffer" and raw.side~="YourOffer" then
  base.reason="offer-side-not-bound";return base
 end
 if not numeric(raw.index) or raw.index<1 or raw.index>4 then
  base.reason="offer-slot-index-invalid";return base
 end
 if raw.slotVisible~=true then
  base.reason="offer-slot-not-visible";return base
 end
 if raw.itemNameLabelPresent~=true and
    raw.itemNameLabelPresent~=false then
  base.reason="display-label-presence-unverified";return base
 end
 local attrs,aok=compact(raw.attributes,"attrs")
 local values,vok=compact(raw.valueNodes,"values")
 local images,iok=compact(raw.imageNodes,"images")
 if not (aok and vok and iok) then
  base.reason="native-metadata-structure-invalid";return base
 end
 base.status="SLOT_METADATA_SHAPE_OBSERVED"
 base.reason="structural-candidates-only-not-identity-proof"
 base.slotLocated=true;base.offerSide=raw.side;base.slotIndex=raw.index
 base.itemNameLabelPresent=raw.itemNameLabelPresent
 base.attributeCandidates=attrs
 base.candidateValueNodes=values
 base.imageNodes=images
 for _,r in ipairs(attrs) do
  if r.nonempty and (r.path:lower():find("id",1,true) or
      r.path:lower():find("key",1,true)) then
    base.candidateIdFieldPresent=true
  end
 end
 for _,r in ipairs(values) do
  if r.nonempty and (r.path:lower():find("id",1,true) or
      r.path:lower():find("key",1,true)) then
    base.candidateIdFieldPresent=true
  end
 end
 for _,r in ipairs(images) do
  if r.nonempty then base.filledImageNodePresent=true end
 end
 return base
end
return M
