-- Stage50 PURE, no-Roblox-API read-only key check for a PRE-offer own profile.
-- Input raw Owned is client-reported, not server-attested; raw candidate key
-- from Stage44 UpdateTrade is a local client observation, not a session token.
local M={}
local typ,rawget,next,getmetatable=type,rawget,next,getmetatable
local function validKey(k)
 return (typ(k)=="string" and #k>0 and #k<=256) or
  (typ(k)=="number" and k==k and k~=math.huge and k~=-math.huge)
end
local function validCount(v)
 if typ(v)=="string" then
  if #v>7 or not v:match("^%d+$") then return nil end
  v=tonumber(v)
 end
 if typ(v)~="number" or v~=v or v==math.huge or v==-math.huge
  or v~=math.floor(v) or v<0 or v>1000000 then return nil end
 return v
end
local function result()
 return {schema="gingerscope-stage50-preoffer-profile-raw-key-v1",
  status="INCOMPLETE",reason="UNTESTED",clientOnly=true,readOnly=true,
  rawCandidateType="UNSUPPORTED",rawOwnedCopyAtLeastOne=false,
  rawOwnedMapComplete=false,rawOwnedExactKeyPresent=false,
  profileCandidateClientMatched=false,rawOfferKeyBoundToPreprofile=false,
  offerKeyOriginVerified=false,checkerIdentityVerified=false,
  uniqueWeaponInstanceProven=false,rawItemIdConfirmed=false,
  rawKeyPresentConfirmed=false,ownerSideSlotBound=false,
  eventSessionAssociationProven=false,causalAttributionProven=false,
  serverAttestation=false,serverCompletionProven=false,
  authorizesAccept=false,authorizesTrade=false,mayRecordCompletedTrade=false,
  mayReportProfit=false,tradeOutcome="UNKNOWN"}
end
local function fail(r,reason)r.reason=reason;return r end
function M.inspect(rawOwned,key)
 local r=result()
 r.rawCandidateType=typ(key)=="string" and "STRING" or
  (typ(key)=="number" and "NUMBER" or "UNSUPPORTED")
 if not validKey(key) then return fail(r,"KEY_TYPE_UNSUPPORTED") end
 if typ(rawOwned)~="table" or getmetatable(rawOwned)~=nil then
  return fail(r,"PROFILE_OWNED_NOT_PLAIN_TABLE") end
 local count,total,spellings=0,0,{}
 local ownedCount=nil
 for k,v in next,rawOwned do
  count=count+1
  if count>2500 then return fail(r,"PROFILE_OWNED_OVERSIZE") end
  if not validKey(k) then return fail(r,"PROFILE_KEY_INVALID") end
  local spelled=tostring(k)
  if spellings[spelled]~=nil and spellings[spelled]~=k then
   return fail(r,"PROFILE_STRING_NUMERIC_KEY_COLLISION")end
  spellings[spelled]=k
  local n=validCount(v)
  if n==nil then return fail(r,"PROFILE_QUANTITY_INVALID") end
  total=total+n
  if total>1000000 then return fail(r,"PROFILE_QUANTITY_TOTAL_EXCESS")end
  if k==key then ownedCount=n end
 end
 r.rawOwnedMapComplete=true
 if ownedCount==nil then return fail(r,"KEY_NOT_PRESENT_IN_PREPROFILE")end
 if ownedCount<1 then return fail(r,"KEY_ZERO_PREPROFILE_COPIES")end
 r.rawOwnedExactKeyPresent=true;r.rawOwnedCopyAtLeastOne=true
 r.profileCandidateClientMatched=true
 r.status="CLIENT_PREPROFILE_RAW_KEY_MATCH_UNAUTHENTICATED"
 r.reason="NONE"
 return r
end
return M
