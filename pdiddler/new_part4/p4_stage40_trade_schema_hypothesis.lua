-- Stage40: strict, read-only hypothesis tester for anonymous third-party trade
-- schema. The third-party script is NOT authenticated MM2 source. Matching
-- layout and value equality is client evidence only, NEVER server-session proof.
local M={}
local type,rawget,next,getmetatable=type,rawget,next,getmetatable
local function report()
 return {
  schema="gingerscope-stage40-candidate-trade-layout-v1",
  status="HYPOTHESIS_NOT_MATCHED",hypothesisMatched=false,
  candidateKeyEqualsVisibleLabel=false,
  player1ObjectEqualsLocal=false,player2ObjectEqualsPartner=false,
  player1OfferHasOneRow=false,player2OfferEmpty=false,
  tripletKeyEqualsCatalogue=false,tripletQuantityIsOne=false,
  tripletCategoryIsWeapons=false,
  wholeEventSchemaAuthenticated=false,rawItemIdConfirmed=false,
  rawKeyPresentConfirmed=false,ownerSideSlotBound=false,
  eventSessionAssociationProven=false,serverCompletionProven=false,
  exactWeaponIdentityConfirmed=false,causalAttributionProven=false,
  authorizesTrade=false,authorizesAccept=false,
  mayRecordCompletedTrade=false,mayReportProfit=false,
  readOnly=true,tradeOutcome="UNKNOWN",hypothesisOnly=true,
 }
end
local function finite(x)
 return type(x)=="number" and x==x and x~=math.huge and x~=-math.huge
end
local function exactKeys(t,expected)
 if type(t)~="table" or getmetatable(t)~=nil then return false end
 local n=0
 for k in next,t do
  if expected[k]~=true then return false end
  n=n+1
 end
 for k in next,expected do if rawget(t,k)==nil then return false end end
 local target=0
 for _ in next,expected do target=target+1 end
 return n==target
end
local TOP={LastOffer=true,Locked=true,Player1=true,Player2=true}
local SIDE={Player=true,Accepted=true,Offer=true}
local ONE={[1]=true}
local ROW={[1]=true,[2]=true,[3]=true}
function M.inspect(args,key,visibleName,me,partner)
 local r=report()
 if not exactKeys(args,{n=true,[1]=true}) or rawget(args,"n")~=1
  or rawget(args,1)==nil or type(key)~="string" or #key==0 or #key>256
  or type(visibleName)~="string" or #visibleName==0 or #visibleName>256
  or me==nil or partner==nil or me==partner then return r end
 r.candidateKeyEqualsVisibleLabel=(key==visibleName)
 local root=rawget(args,1)
 if not exactKeys(root,TOP) then return r end
 if type(rawget(root,"Locked"))~="boolean" or not finite(rawget(root,"LastOffer")) then return r end
 local a,b=rawget(root,"Player1"),rawget(root,"Player2")
 if not exactKeys(a,SIDE) or not exactKeys(b,SIDE) then return r end
 -- == tests object identity privately; do not dereference userdata.
 r.player1ObjectEqualsLocal=rawget(a,"Player")==me
 r.player2ObjectEqualsPartner=rawget(b,"Player")==partner
 if type(rawget(a,"Accepted"))~="boolean" or type(rawget(b,"Accepted"))~="boolean" then return r end
 if rawget(a,"Accepted")~=false or rawget(b,"Accepted")~=false then return r end
 local ao,bo=rawget(a,"Offer"),rawget(b,"Offer")
 if not exactKeys(ao,ONE) or not exactKeys(bo,{}) then return r end
 r.player1OfferHasOneRow=true;r.player2OfferEmpty=true
 local row=rawget(ao,1)
 if not exactKeys(row,ROW) then return r end
 r.tripletKeyEqualsCatalogue=rawget(row,1)==key
 r.tripletQuantityIsOne=rawget(row,2)==1 and finite(rawget(row,2))
 r.tripletCategoryIsWeapons=rawget(row,3)=="Weapons"
 r.hypothesisMatched=r.player1ObjectEqualsLocal and r.player2ObjectEqualsPartner
  and r.tripletKeyEqualsCatalogue and r.tripletQuantityIsOne and r.tripletCategoryIsWeapons
 if r.hypothesisMatched then r.status="ANONYMOUS_LAYOUT_HYPOTHESIS_FITS_UNAUTHENTICATED" end
 return r
end
return M
