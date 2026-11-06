-- Stage41: read-only type/first-failure diagnostic for the historical Stage40
-- *unverified* trade-table hypothesis. Never authenticates an item or trade.
local M={}
local typ,rawget,next,getmetatable=type,rawget,next,getmetatable
local T="TRUE"
local F="FALSE"
local U="UNTESTED"
local function finite(v)
 return typ(v)=="number" and v==v and v~=math.huge and v~=-math.huge
end
local function rawKeyKind(v)
 if typ(v)=="string" and #v>0 and #v<=256 then return "STRING" end
 if finite(v) then return "NUMBER" end
 return "UNSUPPORTED"
end
local function exactShape(value,expected,maxEntries)
 if typ(value)~="table" or getmetatable(value)~=nil then return false end
 local count=0
 for key in next,value do
  count=count+1
  if count>maxEntries or expected[key]~=true then return false end
 end
 for key in next,expected do if rawget(value,key)==nil then return false end end
 return true
end
local PACK={n=true,[1]=true}
local ROOT={LastOffer=true,Locked=true,Player1=true,Player2=true}
local PLAYER={Player=true,Accepted=true,Offer=true}
local OFFER={[1]=true}
local ROW={[1]=true,[2]=true,[3]=true}
local EMPTY={}
local function tri(v)return v and T or F end
local function report()
 return {
  schema="gingerscope-stage41-key-type-first-failure-v1",
  status="UNTESTED",firstFailedStage="UNTESTED",
  candidateKeyType="UNSUPPORTED",legacyStage40RejectedNumericKey=false,
  candidateKeyEqualsVisibleLabel=U,
  argumentPackValid=U,rootFieldSetMatches=U,rootValueTypesMatch=U,
  playerFieldSetsMatch=U,playerAcceptedFlagsFalse=U,
  player1ObjectEqualsLocal=U,player2ObjectEqualsPartner=U,
  offerShapesMatch=U,offerRowShapeMatches=U,
  tripletKeyEqualsCatalogue=U,tripletQuantityIsOne=U,
  tripletCategoryIsWeapons=U,tripletKeyIndex=0,
  hypothesisMatched=false,layoutHypothesisOnly=true,
  rawItemIdConfirmed=false,rawKeyPresentConfirmed=false,
  exactWeaponIdentityConfirmed=false,ownerSideSlotBound=false,
  eventSessionAssociationProven=false,serverCompletionProven=false,
  authorizesTrade=false,authorizesAccept=false,
  mayRecordCompletedTrade=false,mayReportProfit=false,
  readOnly=true,tradeOutcome="UNKNOWN",
 }
end
function M.inspect(args,key,visibleName,me,partner)
 local r=report()
 local function fail(reason)
  r.firstFailedStage=reason
  r.status="HYPOTHESIS_REJECTED"
  return r
 end
 r.candidateKeyType=rawKeyKind(key)
 r.legacyStage40RejectedNumericKey=r.candidateKeyType=="NUMBER"
 if not exactShape(args,PACK,2) or rawget(args,"n")~=1 then
  r.argumentPackValid=F
  return fail("ARGUMENT_PACK_INVALID")
 end
 r.argumentPackValid=T
 if r.candidateKeyType=="UNSUPPORTED" then return fail("CANDIDATE_KEY_INVALID") end
 if typ(visibleName)~="string" or #visibleName==0 or #visibleName>256 then
  return fail("DISPLAY_LABEL_INVALID")
 end
 r.candidateKeyEqualsVisibleLabel=tri(key==visibleName)
 if me==nil or partner==nil or me==partner then return fail("PARTNER_CONTEXT_INVALID") end
 local root=rawget(args,1)
 r.rootFieldSetMatches=tri(exactShape(root,ROOT,4))
 if r.rootFieldSetMatches==F then return fail("ROOT_FIELDSET_MISMATCH") end
 r.rootValueTypesMatch=tri(typ(rawget(root,"Locked"))=="boolean"
  and finite(rawget(root,"LastOffer")))
 if r.rootValueTypesMatch==F then return fail("ROOT_VALUE_TYPE_MISMATCH") end
 local a,b=rawget(root,"Player1"),rawget(root,"Player2")
 r.playerFieldSetsMatch=tri(exactShape(a,PLAYER,3) and exactShape(b,PLAYER,3))
 if r.playerFieldSetsMatch==F then return fail("PLAYER_FIELDSET_MISMATCH") end
 r.player1ObjectEqualsLocal=tri(rawequal(rawget(a,"Player"),me))
 r.player2ObjectEqualsPartner=tri(rawequal(rawget(b,"Player"),partner))
 if r.player1ObjectEqualsLocal==F or r.player2ObjectEqualsPartner==F then
  return fail("PLAYER_OBJECT_MISMATCH")
 end
 r.playerAcceptedFlagsFalse=tri(rawget(a,"Accepted")==false
  and rawget(b,"Accepted")==false)
 if r.playerAcceptedFlagsFalse==F then return fail("ACCEPT_STATE_MISMATCH") end
 local own,other=rawget(a,"Offer"),rawget(b,"Offer")
 r.offerShapesMatch=tri(exactShape(own,OFFER,1) and exactShape(other,EMPTY,0))
 if r.offerShapesMatch==F then return fail("OFFER_LIST_MISMATCH") end
 local row=rawget(own,1)
 r.offerRowShapeMatches=tri(exactShape(row,ROW,3))
 if r.offerRowShapeMatches==F then return fail("OFFER_ROW_SHAPE_MISMATCH") end
 for i=1,3 do
  if rawequal(rawget(row,i),key) then
   if r.tripletKeyIndex~=0 then return fail("MULTIPLE_KEY_POSITIONS") end
   r.tripletKeyIndex=i
  end
 end
 r.tripletKeyEqualsCatalogue=tri(rawequal(rawget(row,1),key))
 r.tripletQuantityIsOne=tri(rawget(row,2)==1 and finite(rawget(row,2)))
 r.tripletCategoryIsWeapons=tri(rawget(row,3)=="Weapons")
 if r.tripletKeyEqualsCatalogue==F or r.tripletQuantityIsOne==F
  or r.tripletCategoryIsWeapons==F then
  return fail("ROW_LITERAL_MISMATCH")
 end
 r.firstFailedStage="NONE"
 r.status="UNAUTHENTICATED_LAYOUT_HYPOTHESIS_FITS"
 r.hypothesisMatched=true
 return r
end
return M
