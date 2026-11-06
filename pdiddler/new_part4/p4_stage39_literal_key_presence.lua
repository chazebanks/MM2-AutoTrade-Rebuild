-- Stage39 PURE, read-only primitive literal equality census.
-- This is not a resolver: matching a catalogue raw key in an unknown event
-- DOES NOT bind the key to player, side, displayed slot, or server transaction.
-- Never return raw keys, arbitrary field names, strings, values or paths.
local M={}
local typ,rawNext,rawGet,meta=type,next,rawget,getmetatable
local MAX_ARGS,MAX_DEPTH,MAX_TABLES,MAX_ENTRIES,MAX_STRING=8,4,32,128,4096
local function finite(x)
 return typ(x)=="number" and x==x and x~=math.huge and x~=-math.huge
end
local function validKey(x)
 if typ(x)=="string" then return #x>0 and #x<=256 end
 return finite(x)
end
local function out()
 return {schema="gingerscope-stage39-primitive-key-presence-v1",
  status="INCOMPLETE",reason="UNINSPECTED",traversalComplete=false,
  candidateValueMatches=0,candidateMapKeyMatches=0,
  otherCatalogueValueMatches=0,otherCatalogueMapKeyMatches=0,
  matchedCandidateByDepth={0,0,0,0},
  matchedOtherByDepth={0,0,0,0},opaqueLeafCount=0,
  totalTables=0,totalEntries=0,repeatedTables=0,
  literalEqualityOnly=true,rawIdAuthority=false,slotBindingAuthority=false,
  rawItemIdConfirmed=false,rawKeyPresentConfirmed=false,
  ownerSideSlotBound=false,eventSessionAssociationProven=false,
  exactWeaponIdentityConfirmed=false,serverCompletionProven=false,
  authorizesTrade=false,authorizesAccept=false,mayRecordCompletedTrade=false,
  mayReportProfit=false,readOnly=true,tradeOutcome="UNKNOWN"}
end
function M.inspect(args,candidate,keys)
 local r=out()
 local function fail(reason)
  r.status="INCOMPLETE"
  if r.reason=="UNINSPECTED" or r.reason=="PRIMITIVE_SCAN_COMPLETE" then r.reason=reason end
 end
 if not validKey(candidate) or typ(keys)~="table" or meta(keys)~=nil
  or rawGet(keys,candidate)~=true or typ(args)~="table" or meta(args)~=nil then
  fail("INVALID_INPUT");return r
 end
 local n=rawGet(args,"n")
 if not finite(n) or n<0 or n>MAX_ARGS or n%1~=0 then fail("INVALID_PACK");return r end
 local k=nil
 while true do
  k=rawNext(args,k)
  if k==nil then break end
  if k~="n" and (not finite(k) or k<1 or k>n or k%1~=0) then
   fail("INVALID_PACK");return r
  end
 end
 local status="PRIMITIVE_SCAN_COMPLETE"
 local seen,active={},{}
 local function complain(s)
  if status=="PRIMITIVE_SCAN_COMPLETE" then status=s end
 end
 local function compare(value,depth,isKey)
  local t=typ(value)
  if t=="string" then
   if #value>MAX_STRING then complain("STRING_LIMIT");return end
  elseif t=="number" then
   if not finite(value) then complain("NONFINITE_NUMBER");return end
  elseif t=="userdata" or t=="thread" or t=="function" then
   r.opaqueLeafCount=r.opaqueLeafCount+1
   return
  elseif t~="boolean" and t~="nil" and t~="table" then
   complain("UNSUPPORTED_VALUE");return
  end
  if t=="number" or t=="string" then
   if value==candidate then
    if isKey then r.candidateMapKeyMatches=r.candidateMapKeyMatches+1
    else r.candidateValueMatches=r.candidateValueMatches+1 end
    r.matchedCandidateByDepth[depth]=r.matchedCandidateByDepth[depth]+1
   elseif rawGet(keys,value)==true then
    if isKey then r.otherCatalogueMapKeyMatches=r.otherCatalogueMapKeyMatches+1
    else r.otherCatalogueValueMatches=r.otherCatalogueValueMatches+1 end
    r.matchedOtherByDepth[depth]=r.matchedOtherByDepth[depth]+1
   end
  end
 end
 local visit
 visit=function(t,depth)
  if depth>MAX_DEPTH then complain("DEPTH_LIMIT");return end
  if seen[t] then
   r.repeatedTables=r.repeatedTables+1
   if active[t] then complain("CYCLE")
   elseif seen[t]~=depth then complain("ALIAS_DEPTH_UNVERIFIED") end
   return
  end
  if r.totalTables>=MAX_TABLES then complain("TABLE_LIMIT");return end
  if meta(t)~=nil then complain("METATABLE");return end
  seen[t]=depth;active[t]=true;r.totalTables=r.totalTables+1
  local key=nil
  while true do
   local value
   key,value=rawNext(t,key)
   if key==nil then break end
   if r.totalEntries>=MAX_ENTRIES then complain("ENTRY_LIMIT");break end
   r.totalEntries=r.totalEntries+1
   local kt=typ(key)
   if kt~="string" and kt~="number" and kt~="boolean" then
    complain("UNSUPPORTED_KEY_TYPE")
   else
    compare(key,depth,true)
   end
   if typ(value)=="table" then visit(value,depth+1)
   else compare(value,depth,false) end
  end
  active[t]=nil
 end
 for i=1,n do
  local v=rawGet(args,i)
  if typ(v)=="table" then visit(v,1)
  else compare(v,1,false) end
 end
 if status=="PRIMITIVE_SCAN_COMPLETE" then
  r.traversalComplete=true
  r.status="PRIMITIVE_LITERAL_COUNTS_UNBOUND"
  r.reason="PRIMITIVE_SCAN_COMPLETE"
 else r.reason=status end
 return r
end
return M
