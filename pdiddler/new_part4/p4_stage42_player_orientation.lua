-- Stage42: fixed-shape, read-only exact player reference *orientation* probe.
-- The event field names are a CLIENT hypothesis; a perfect local orientation
-- match is NOT an authenticated server trade, slot, or session binding.
local M={}
local typ,rawget,next,getmetatable,rawequal=type,rawget,next,getmetatable,rawequal
local ROOT={LastOffer=true,Locked=true,Player1=true,Player2=true}
local SIDE={Player=true,Accepted=true,Offer=true}
local PACK={n=true,[1]=true}
local function exactKeys(t,keys,cap)
 if typ(t)~="table" or getmetatable(t)~=nil then return false end
 local count=0
 for k in next,t do
  count=count+1
  if count>cap or keys[k]~=true then return false end
 end
 for k in next,keys do if rawget(t,k)==nil then return false end end
 return true
end
local function leafType(v)
 local t=typ(v)
 if t=="string" then return "STRING" end
 if t=="number" then return "NUMBER" end
 if t=="boolean" then return "BOOLEAN" end
 if t=="userdata" then return "USERDATA" end
 if t=="table" then return "TABLE" end
 if t=="nil" then return "NIL" end
 return "OTHER"
end
local function report()
 return {
  schema="gingerscope-stage42-player-orientation-v1",
  status="INCOMPLETE",orientation="UNTESTED",
  firstStopReason="UNTESTED",
  rootAndSideShapeValid=false,
  comparisonComplete=false,
  player1ValueType="UNTESTED",player2ValueType="UNTESTED",
  player1EqualsLocal="UNTESTED",player1EqualsPartner="UNTESTED",
  player2EqualsLocal="UNTESTED",player2EqualsPartner="UNTESTED",
  localPlayerFirst=false,localPlayerSecond=false,
  offerSideAssumed=false,orientationIsClientObservationOnly=true,
  rawItemIdConfirmed=false,rawKeyPresentConfirmed=false,
  ownerSideSlotBound=false,eventSessionAssociationProven=false,
  serverCompletionProven=false,exactWeaponIdentityConfirmed=false,
  causalAttributionProven=false,authorizesTrade=false,
  authorizesAccept=false,mayRecordCompletedTrade=false,
  mayReportProfit=false,readOnly=true,tradeOutcome="UNKNOWN",
 }
end
local function tri(v)return v and "TRUE" or "FALSE" end
function M.inspect(args,me,partner)
 local r=report()
 if not exactKeys(args,PACK,2) or rawget(args,"n")~=1 then
  r.firstStopReason="ARGUMENT_PACK_INVALID";return r
 end
 if me==nil or partner==nil or rawequal(me,partner) then
  r.firstStopReason="PLAYER_CONTEXT_INVALID";return r
 end
 local root=rawget(args,1)
 if not exactKeys(root,ROOT,4) then
  r.firstStopReason="ROOT_SCHEMA_MISMATCH";return r
 end
 local p1=rawget(root,"Player1")
 local p2=rawget(root,"Player2")
 if not exactKeys(p1,SIDE,3) or not exactKeys(p2,SIDE,3) then
  r.firstStopReason="PLAYER_FIELDSET_MISMATCH";return r
 end
 r.rootAndSideShapeValid=true
 local a=rawget(p1,"Player")
 local b=rawget(p2,"Player")
 r.player1ValueType=leafType(a)
 r.player2ValueType=leafType(b)
 local aMe=rawequal(a,me)
 local aThem=rawequal(a,partner)
 local bMe=rawequal(b,me)
 local bThem=rawequal(b,partner)
 r.player1EqualsLocal=tri(aMe)
 r.player1EqualsPartner=tri(aThem)
 r.player2EqualsLocal=tri(bMe)
 r.player2EqualsPartner=tri(bThem)
 r.comparisonComplete=true
 local first=aMe and bThem and not aThem and not bMe
 local second=aThem and bMe and not aMe and not bThem
 r.localPlayerFirst=first
 r.localPlayerSecond=second
 if first then
  r.orientation="LOCAL_FIRST"
  r.status="CLIENT_REFERENCE_ORIENTATION_OBSERVED"
  r.firstStopReason="NONE"
 elseif second then
  r.orientation="LOCAL_SECOND"
  r.status="CLIENT_REFERENCE_ORIENTATION_OBSERVED"
  r.firstStopReason="NONE"
 elseif aMe or aThem or bMe or bThem then
  r.orientation="PARTIAL_OR_DUPLICATE"
  r.firstStopReason="NO_UNIQUE_COMPLEMENTARY_PAIR"
 else
  r.orientation="NO_EXACT_PAIR"
  r.firstStopReason="NO_MATCHING_PLAYER_REFERENCES"
 end
 return r
end
return M
