-- Stage43: passive single-event player-aware own Batwing tuple hypothesis.
-- NEVER an authenticated session, server item, trade or final Accept signal.
-- Only valid in the existing 1-receipt / stable-GUI / manual-own-Batwing probe.
local M={}
local typ,rawget,next,getmetatable,rawequal=type,rawget,next,getmetatable,rawequal
local ROOT={LastOffer=true,Locked=true,Player1=true,Player2=true}
local SIDE={Player=true,Accepted=true,Offer=true}
local PACK={n=true,[1]=true}
local ONLY_ROW={[1]=true}
local TRIPLE={[1]=true,[2]=true,[3]=true}
local EMPTY={}
local T,F,U="TRUE","FALSE","UNTESTED"
local function tri(x) return x and T or F end
local function finite(v) return typ(v)=="number" and v==v and v~=math.huge and v~=-math.huge end
local function validKey(v)
 return (typ(v)=="string" and #v>0 and #v<=256) or finite(v)
end
local function exactKeys(t,kset,cap)
 if typ(t)~="table" or getmetatable(t)~=nil then return false end
 local count=0
 for k in next,t do
  count=count+1
  if count>cap or kset[k]~=true then return false end
 end
 for k in next,kset do if rawget(t,k)==nil then return false end end
 return true
end
local function result()
 return {
  schema="gingerscope-stage43-dynamic-own-offer-v1",
  status="INCOMPLETE",firstFailedStage="UNTESTED",
  candidateKeyType="UNSUPPORTED",orientation="UNTESTED",
  localOfferTable="UNTESTED",partnerOfferTable="UNTESTED",
  rootAndSideSchemaValid=false,orientationCompared=false,
  ownSingleRow=U,partnerOfferEmpty=U,bothAcceptedFalse=U,
  ownRowTripleShape=U,ownKeyMatches=U,ownQuantityOne=U,
  ownCategoryWeapons=U,rawKeyMatchPosition=0,
  clientOwnOfferTupleMatches=false,clientEventLayoutOnly=true,
  eventSessionAssociationProven=false,causalAttributionProven=false,
  ownerSideSlotBound=false,rawItemIdConfirmed=false,
  exactWeaponIdentityConfirmed=false,rawKeyPresentConfirmed=false,
  serverCompletionProven=false,serverAttestation=false,
  authorizesTrade=false,authorizesAccept=false,
  mayReportProfit=false,mayRecordCompletedTrade=false,
  tradeOutcome="UNKNOWN",readOnly=true,
 }
end
function M.inspect(args,key,me,partner)
 local r=result()
 local function fail(reason)
  r.firstFailedStage=reason
  r.status="HYPOTHESIS_REJECTED"
  return r
 end
 r.candidateKeyType=typ(key)=="string" and "STRING" or (finite(key) and "NUMBER" or "UNSUPPORTED")
 if not exactKeys(args,PACK,2) or rawget(args,"n")~=1 then return fail("ARGUMENT_PACK_INVALID") end
 if not validKey(key) then return fail("CANDIDATE_KEY_INVALID") end
 if me==nil or partner==nil or rawequal(me,partner) then return fail("PLAYER_CONTEXT_INVALID") end
 local root=rawget(args,1)
 if not exactKeys(root,ROOT,4) then return fail("ROOT_FIELDSET_MISMATCH") end
 if typ(rawget(root,"Locked"))~="boolean" or not finite(rawget(root,"LastOffer")) then
  return fail("ROOT_VALUE_TYPE_MISMATCH")
 end
 local p1,p2=rawget(root,"Player1"),rawget(root,"Player2")
 if not exactKeys(p1,SIDE,3) or not exactKeys(p2,SIDE,3) then
  return fail("PLAYER_FIELDSET_MISMATCH")
 end
 r.rootAndSideSchemaValid=true
 local a,b=rawget(p1,"Player"),rawget(p2,"Player")
 local first=rawequal(a,me) and rawequal(b,partner) and not rawequal(a,partner) and not rawequal(b,me)
 local second=rawequal(a,partner) and rawequal(b,me) and not rawequal(a,me) and not rawequal(b,partner)
 r.orientationCompared=true
 if not first and not second then
  r.orientation="NO_UNIQUE_COMPLEMENTARY_PAIR"
  return fail("PLAYER_OBJECT_PAIR_MISMATCH")
 end
 r.orientation=first and "LOCAL_FIRST" or "LOCAL_SECOND"
 r.localOfferTable=first and "PLAYER1" or "PLAYER2"
 r.partnerOfferTable=first and "PLAYER2" or "PLAYER1"
 local own=first and p1 or p2
 local other=first and p2 or p1
 r.bothAcceptedFalse=tri(rawget(p1,"Accepted")==false and rawget(p2,"Accepted")==false)
 if r.bothAcceptedFalse==F then return fail("ACCEPT_STATE_MISMATCH") end
 local ownOffer,otherOffer=rawget(own,"Offer"),rawget(other,"Offer")
 r.ownSingleRow=tri(exactKeys(ownOffer,ONLY_ROW,1))
 r.partnerOfferEmpty=tri(exactKeys(otherOffer,EMPTY,0))
 if r.ownSingleRow==F or r.partnerOfferEmpty==F then return fail("OFFER_LIST_MISMATCH") end
 local row=rawget(ownOffer,1)
 r.ownRowTripleShape=tri(exactKeys(row,TRIPLE,3))
 if r.ownRowTripleShape==F then return fail("OFFER_ROW_SHAPE_MISMATCH") end
 for i=1,3 do
  if rawequal(rawget(row,i),key) then
   if r.rawKeyMatchPosition~=0 then return fail("RAW_KEY_POSITION_AMBIGUOUS") end
   r.rawKeyMatchPosition=i
  end
 end
 r.ownKeyMatches=tri(rawequal(rawget(row,1),key))
 r.ownQuantityOne=tri(rawget(row,2)==1 and finite(rawget(row,2)))
 r.ownCategoryWeapons=tri(rawget(row,3)=="Weapons")
 if r.ownKeyMatches==F or r.ownQuantityOne==F or r.ownCategoryWeapons==F then
  return fail("ROW_CONTENT_MISMATCH")
 end
 r.status="CLIENT_SNAPSHOT_TUPLE_MATCHED_UNAUTHENTICATED"
 r.firstFailedStage="NONE"
 r.clientOwnOfferTupleMatches=true
 return r
end
return M
