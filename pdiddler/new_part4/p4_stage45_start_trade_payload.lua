-- Stage45: privacy-preserving, bounded StartTrade OnClientEvent argument census.
-- Observe ONLY primitive TYPES and direct Player reference equality. This is NOT
-- a server session identifier or a trade/Accept/completion authorization.
local M={}
local T=type
local function result()
 return {schema="gingerscope-stage45-start-trade-argument-census-v1",
  status="INCOMPLETE",reason="UNTESTED",argumentCount=0,
  argumentTypes={},localPlayerReferenceCount=0,partnerPlayerReferenceCount=0,
  unclassifiedStringCount=0,unclassifiedNumberCount=0,
  booleanCount=0,tableCount=0,opaqueCount=0,nilCount=0,
  directPrimitiveCandidateCount=0,playerPairReferencesObserved=false,
  hasAuthenticatedSessionIdentifier=false,sessionIdProven=false,
  eventSessionAssociationProven=false,causalAttributionProven=false,
  serverAttestation=false,serverCompletionProven=false,
  ownerSideSlotBound=false,rawItemIdConfirmed=false,
  authorizesTrade=false,authorizesAccept=false,
  mayRecordCompletedTrade=false,mayReportProfit=false,
  readOnly=true,tradeOutcome="UNKNOWN"}
end
function M.inspect(args,me,partner)
 local r=result()
 if T(args)~="table" or getmetatable(args)~=nil then
  r.reason="ARGUMENT_PACK_INVALID";return r
 end
 local n=rawget(args,"n")
 if T(n)~="number" or n~=math.floor(n) or n<0 or n>6 then
  r.reason="ARGUMENT_COUNT_UNSUPPORTED";return r
 end
 local found=0
 for k in next,args do
  found=found+1
  if k~="n" and (T(k)~="number" or k~=math.floor(k) or k<1 or k>n) then
   r.reason="ARGUMENT_PACK_INVALID";return r
  end
 end
 if found>n+1 then r.reason="ARGUMENT_PACK_INVALID";return r end
 if me==nil or partner==nil or rawequal(me,partner) then
  r.reason="ACTOR_CONTEXT_INVALID";return r
 end
 r.argumentCount=n
 for i=1,n do
  local a=rawget(args,i)
  local typ
  if rawequal(a,me) then
   typ="LOCAL_PLAYER_REF";r.localPlayerReferenceCount=r.localPlayerReferenceCount+1
  elseif rawequal(a,partner) then
   typ="PARTNER_PLAYER_REF";r.partnerPlayerReferenceCount=r.partnerPlayerReferenceCount+1
  elseif a==nil then
   typ="NIL";r.nilCount=r.nilCount+1
  else
   local vt=T(a)
   if vt=="number" then
    if a~=a or a==math.huge or a==-math.huge then
     r.reason="NONFINITE_NUMBER";return r
    end
    typ="NUMBER";r.unclassifiedNumberCount=r.unclassifiedNumberCount+1
   elseif vt=="string" then
    typ="STRING";r.unclassifiedStringCount=r.unclassifiedStringCount+1
   elseif vt=="boolean" then
    typ="BOOLEAN";r.booleanCount=r.booleanCount+1
   elseif vt=="table" then
    -- No table contents are read or included. Metatable scripts cannot execute.
    typ="TABLE";r.tableCount=r.tableCount+1
   else
    typ="OPAQUE";r.opaqueCount=r.opaqueCount+1
   end
  end
  r.argumentTypes[i]=typ
 end
 r.directPrimitiveCandidateCount=r.unclassifiedNumberCount+r.unclassifiedStringCount
 r.playerPairReferencesObserved=r.localPlayerReferenceCount==1 and r.partnerPlayerReferenceCount==1
 r.status="ANONYMIZED_CLIENT_ARGUMENT_TYPES_ONLY";r.reason="NONE"
 return r
end
return M
