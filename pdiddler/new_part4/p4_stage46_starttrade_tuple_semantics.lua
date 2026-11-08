-- Stage46: type-safe, no-raw-value inspection of TWO StartTrade arguments.
-- Narrow hypothesis: first TABLE resembles prior client TradeTable layout;
-- second STRING equals visible bound partner's username.
-- NEVER treat a match as event-to-session identity, final Accept or trade authority.
local M={}
local typ,rawget,next,getmetatable,rawequal=type,rawget,next,getmetatable,rawequal
local ROOT={LastOffer=true,Locked=true,Player1=true,Player2=true}
local SIDE={Player=true,Accepted=true,Offer=true}
local function exact(t,keys,maxn)
 if typ(t)~="table" or getmetatable(t)~=nil then return false end
 local n=0
 for k in next,t do
  n=n+1
  if n>maxn or keys[k]~=true then return false end
 end
 for k in next,keys do if rawget(t,k)==nil then return false end end
 return true
end
local function finite(n)
 return typ(n)=="number" and n==n and n~=math.huge and n~=-math.huge
end
local function result()
 return {schema="gingerscope-stage46-starttrade-tuple-semantic-census-v1",
  status="INCOMPLETE",reason="UNTESTED",
  argumentCount=0,argumentTypes={},
  stringClassification="UNTESTED",stringMatchesPartnerUsername=false,
  stringMatchesPartnerDisplay=false,stringMatchesLocalUsername=false,
  stringMatchesLocalDisplay=false,
  tableLayout="UNTESTED",rootAndSideSchemaValid=false,
  bothAcceptedFalse=false,bothOffersEmpty=false,
  orientation="UNTESTED",actorReferencesMatched=false,
  clientTupleHypothesisMatched=false,clientOnly=true,readOnly=true,
  tradeOutcome="UNKNOWN",eventSessionAssociationProven=false,
  causalAttributionProven=false,serverAttestation=false,
  serverCompletionProven=false,hasAuthenticatedSessionIdentifier=false,
  sessionIdProven=false,ownerSideSlotBound=false,rawItemIdConfirmed=false,
  exactWeaponIdentityConfirmed=false,rawKeyPresentConfirmed=false,
  authorizesAccept=false,authorizesTrade=false,
  mayRecordCompletedTrade=false,mayReportProfit=false}
end
function M.inspect(args,me,partner)
 local r=result()
 if not exact(args,{n=true,[1]=true,[2]=true},3)
  or rawget(args,"n")~=2 then
  -- The pack's two argument slots may be nil in other protocols. This
  -- experiment only classifies the specifically observed TABLE,STRING pair.
  r.reason="ARGUMENT_PACK_OR_COUNT_MISMATCH";return r
 end
 if me==nil or partner==nil or rawequal(me,partner)
  or typ(me.Name)~="string" or typ(partner.Name)~="string"
  or me.Name=="" or partner.Name=="" then
  r.reason="ACTOR_CONTEXT_INVALID";return r
 end
 local first,second=rawget(args,1),rawget(args,2)
 r.argumentCount=2
 r.argumentTypes={"TABLE","STRING"}
 if typ(first)~="table" or typ(second)~="string" then
  r.reason="ARGUMENT_TYPES_MISMATCH";return r
 end
 if #second>256 then r.reason="STRING_LENGTH_UNSUPPORTED";return r end
 local pName=partner.Name
 local lName=me.Name
 local pDisplay=typ(partner.DisplayName)=="string" and partner.DisplayName or nil
 local lDisplay=typ(me.DisplayName)=="string" and me.DisplayName or nil
 r.stringMatchesPartnerUsername=second==pName
 r.stringMatchesPartnerDisplay=pDisplay~=nil and second==pDisplay
 r.stringMatchesLocalUsername=second==lName
 r.stringMatchesLocalDisplay=lDisplay~=nil and second==lDisplay
 local pm=r.stringMatchesPartnerUsername or r.stringMatchesPartnerDisplay
 local lm=r.stringMatchesLocalUsername or r.stringMatchesLocalDisplay
 if second=="" then r.stringClassification="EMPTY_STRING"
 elseif pm and lm then r.stringClassification="AMBIGUOUS_BOTH_ACTORS"
 elseif r.stringMatchesPartnerUsername then r.stringClassification="PARTNER_USERNAME_EXACT"
 elseif r.stringMatchesPartnerDisplay then r.stringClassification="PARTNER_DISPLAY_ONLY"
 elseif r.stringMatchesLocalUsername then r.stringClassification="LOCAL_USERNAME_EXACT"
 elseif r.stringMatchesLocalDisplay then r.stringClassification="LOCAL_DISPLAY_ONLY"
 else r.stringClassification="OTHER_STRING_UNCLASSIFIED" end
 if not exact(first,ROOT,4) then r.tableLayout="ROOT_FIELDSET_MISMATCH"
 else
  local p1,p2=rawget(first,"Player1"),rawget(first,"Player2")
  if not finite(rawget(first,"LastOffer"))
   or typ(rawget(first,"Locked"))~="boolean" then
   r.tableLayout="ROOT_TYPES_MISMATCH"
  elseif not exact(p1,SIDE,3) or not exact(p2,SIDE,3) then
   r.tableLayout="PLAYER_FIELDSET_MISMATCH"
  else
   r.rootAndSideSchemaValid=true
   local a,b=rawget(p1,"Player"),rawget(p2,"Player")
   local localFirst=rawequal(a,me) and rawequal(b,partner)
    and not rawequal(a,partner) and not rawequal(b,me)
   local localSecond=rawequal(a,partner) and rawequal(b,me)
    and not rawequal(a,me) and not rawequal(b,partner)
   if localFirst then r.orientation="LOCAL_FIRST"
   elseif localSecond then r.orientation="LOCAL_SECOND"
   else r.orientation="NO_UNIQUE_COMPLEMENTARY_PAIR" end
   r.actorReferencesMatched=localFirst or localSecond
   if not r.actorReferencesMatched then
    r.tableLayout="ACTOR_PAIR_MISMATCH"
   else
    r.bothAcceptedFalse=rawget(p1,"Accepted")==false and rawget(p2,"Accepted")==false
    local offer1,offer2=rawget(p1,"Offer"),rawget(p2,"Offer")
    r.bothOffersEmpty=exact(offer1,{},0) and exact(offer2,{},0)
    if not r.bothAcceptedFalse then r.tableLayout="ACCEPT_STATE_MISMATCH"
    elseif not r.bothOffersEmpty then r.tableLayout="OFFERS_NOT_EMPTY"
    else r.tableLayout="EMPTY_TRADE_TABLE_CLIENT_LAYOUT_MATCH" end
   end
  end
 end
 r.clientTupleHypothesisMatched=r.tableLayout=="EMPTY_TRADE_TABLE_CLIENT_LAYOUT_MATCH"
  and (r.stringClassification=="PARTNER_USERNAME_EXACT"
       or r.stringClassification=="PARTNER_DISPLAY_ONLY")
 r.status="CLIENT_TUPLE_CLASSIFIED_UNAUTHENTICATED"
 r.reason="NONE"
 return r
end
return M
