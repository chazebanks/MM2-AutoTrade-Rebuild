-- Stage44 pure read-only client UpdateTrade offer-state inspector.
-- It does not prove event causality, current server session, item instance,
-- transfer, settlement, consent or authorization to trade.
local M={}
local typ,rawget,next,getmetatable,rawequal=type,rawget,next,getmetatable,rawequal
local ROOT={LastOffer=true,Locked=true,Player1=true,Player2=true}
local SIDE={Player=true,Accepted=true,Offer=true}
local PACK={n=true,[1]=true}
local ONE={[1]=true}
local ROW={[1]=true,[2]=true,[3]=true}
local EMPTY={}
local function finite(v)return typ(v)=="number" and v==v and v~=math.huge and v~=-math.huge end
local function validKey(v)return (typ(v)=="string" and #v>0 and #v<=256) or finite(v) end
local function exactKeys(v,expected,cap)
 if typ(v)~="table" or getmetatable(v)~=nil then return false end
 local n=0
 for k in next,v do n=n+1;if n>cap or expected[k]~=true then return false end end
 for k in next,expected do if rawget(v,k)==nil then return false end end
 return true
end
local function result()
 return {schema="gingerscope-stage44-client-offer-state-v1",
  status="INCOMPLETE",firstFailedStage="UNTESTED",
  state="UNTESTED",orientation="UNTESTED",localOfferTable="UNTESTED",
  partnerOfferTable="UNTESTED",candidateKeyType="UNSUPPORTED",
  rootAndSideSchemaValid=false,complementaryPlayersMatched=false,
  bothAcceptedFalse=false,partnerOfferEmpty=false,
  ownSingleRow=false,ownRowTripleShape=false,
  ownKeyMatches=false,ownQuantityOne=false,ownCategoryWeapons=false,
  rawKeyMatchPosition=0,clientStateMatched=false,clientOnly=true,
  eventSessionAssociationProven=false,causalAttributionProven=false,
  ownerSideSlotBound=false,rawItemIdConfirmed=false,
  exactWeaponIdentityConfirmed=false,rawKeyPresentConfirmed=false,
  serverCompletionProven=false,serverAttestation=false,
  authorizesTrade=false,authorizesAccept=false,mayReportProfit=false,
  mayRecordCompletedTrade=false,readOnly=true,tradeOutcome="UNKNOWN"}
end
function M.inspect(args,key,me,partner)
 local r=result()
 local function fail(reason)
  r.firstFailedStage=reason;r.status="HYPOTHESIS_REJECTED"
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
 if not first and not second then return fail("PLAYER_OBJECT_PAIR_MISMATCH") end
 r.complementaryPlayersMatched=true
 r.orientation=first and "LOCAL_FIRST" or "LOCAL_SECOND"
 r.localOfferTable=first and "PLAYER1" or "PLAYER2"
 r.partnerOfferTable=first and "PLAYER2" or "PLAYER1"
 local own=first and p1 or p2
 local other=first and p2 or p1
 r.bothAcceptedFalse=rawget(p1,"Accepted")==false and rawget(p2,"Accepted")==false
 if not r.bothAcceptedFalse then return fail("ACCEPT_STATE_MISMATCH") end
 local their=rawget(other,"Offer")
 r.partnerOfferEmpty=exactKeys(their,EMPTY,0)
 if not r.partnerOfferEmpty then return fail("PARTNER_OFFER_NOT_EMPTY") end
 local ours=rawget(own,"Offer")
 if exactKeys(ours,EMPTY,0) then
  r.state="BOTH_EMPTY";r.status="CLIENT_SNAPSHOT_STATE_MATCHED_UNAUTHENTICATED"
  r.firstFailedStage="NONE";r.clientStateMatched=true;return r
 end
 r.ownSingleRow=exactKeys(ours,ONE,1)
 if not r.ownSingleRow then return fail("OWN_OFFER_SHAPE_MISMATCH") end
 local row=rawget(ours,1)
 r.ownRowTripleShape=exactKeys(row,ROW,3)
 if not r.ownRowTripleShape then return fail("OWN_ROW_SHAPE_MISMATCH") end
 for i=1,3 do
  if rawequal(rawget(row,i),key) then
   if r.rawKeyMatchPosition~=0 then return fail("RAW_KEY_POSITION_AMBIGUOUS") end
   r.rawKeyMatchPosition=i
  end
 end
 r.ownKeyMatches=rawequal(rawget(row,1),key)
 r.ownQuantityOne=finite(rawget(row,2)) and rawget(row,2)==1
 r.ownCategoryWeapons=rawget(row,3)=="Weapons"
 if not r.ownKeyMatches or not r.ownQuantityOne or not r.ownCategoryWeapons then
  return fail("OWN_ROW_CONTENT_MISMATCH")
 end
 r.state="OWN_ONE_BATWING"
 r.status="CLIENT_SNAPSHOT_STATE_MATCHED_UNAUTHENTICATED"
 r.firstFailedStage="NONE";r.clientStateMatched=true
 return r
end
return M
