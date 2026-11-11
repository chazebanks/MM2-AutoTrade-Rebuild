-- Stage65 OFFLINE ONLY. No game services, invokes, event listeners, UI,
-- network, files, clipboard, trading, market/pricing or Discord.
-- Historical v1456 MM2 client passed AcceptTrade(true, items) item row as
-- AddNewItem(item[1], item[3], item[2]); this is UNVERIFIED in current MM2.
-- Caller must supply local pre/post raw Weapons.Owned maps and callback rows.
-- This evaluates primitive equality only. NEVER server/settlement/strategy proof.
local M={}
local SCHEMA="gingerscope-stage65-private-raw-key-equality-v1"
local function result(state,reason)
 return {
  schema=SCHEMA,status=state,reason=reason,readOnly=true,
  rawCallbackKeyEqualsOwnGainedKey=(state=="PRIVATE_RAW_PRIMITIVE_EQUALITY_CLIENT_ONLY"),
  historicalPopupTripletShapeObserved=(state=="PRIVATE_RAW_PRIMITIVE_EQUALITY_CLIENT_ONLY"),
  sameAuthenticatedTransaction=false,serverAttestation=false,
  serverCompletionProven=false,serverTransactionIdAuthenticated=false,
  causalTradeAttributionProven=false,
  callbackKeySemanticIdentityProven=false,exactWeaponIdentityConfirmed=false,
  exactWeaponInstanceIdentityProven=false,weaponCategoryProven=false,
  syncedCatalogIdentityProven=false,marketCheckerIdentityProven=false,
  serverOwnedInventorySourceAuthenticated=false,
  offerRevisionAuthenticated=false,partnerIdentityAuthenticated=false,
  mayRecordCompletedTrade=false,mayRecordRejectedTrade=false,
  mayReportProfit=false,mayUseForStrategyLearning=false,
  authorizesTrade=false,authorizesAccept=false,tradeOutcome="UNKNOWN",
  itemNameOrKeyExported=false
 }
end
local function invalid(why)
 return result("INCONCLUSIVE",why)
end
local function integer(v,lo,hi)
 return type(v)=="number" and v==v and
   v~=math.huge and v~=-math.huge and v==math.floor(v) and
   v>=lo and v<=hi
end
local function key(v)
 return type(v)=="string" and #v>=1 and #v<=128 and
   v:find("[%c]")==nil
end
local function fields(t,expected)
 if type(t)~="table" then return false end
 local n=0
 for k in pairs(t) do
  if not expected[k] then return false end
  n=n+1
 end
 return n==3
end
local function rawOwned(map)
 if type(map)~="table" then return nil,"MAP_MISSING" end
 local out,count,total={},0,0
 for raw,qty in pairs(map) do
  if not key(raw) or not integer(qty,0,1000000) then
   return nil,"INVALID_RAW_OWNED_KEY_OR_QUANTITY"
  end
  count=count+1
  if count>10000 then return nil,"TOO_MANY_RAW_WEAPON_KEYS" end
  total=total+qty
  if total>1000000 then return nil,"TOO_MANY_RAW_OWNED_COPIES" end
  if qty>0 then out[raw]=qty end
 end
 if total==0 then
  return nil,"EMPTY_RAW_WEAPONS_UNVERIFIED"
 end
 return out,nil
end
local function sameSnapshot(a,b)
 for k,v in pairs(a) do if b[k]~=v then return false end end
 for k,v in pairs(b) do if a[k]~=v then return false end end
 return true
end
local function changed(before,after)
 local changedTypes,gains,losses,rawGain=0,0,0,nil
 for k,v in pairs(before) do
  local delta=(after[k] or 0)-v
  if delta~=0 then
   changedTypes=changedTypes+1
   if delta>0 then gains=gains+delta;rawGain=k
   else losses=losses-delta end
  end
 end
 for k,v in pairs(after) do
  if before[k]==nil then
   changedTypes=changedTypes+1;gains=gains+v;rawGain=k
  end
 end
 if changedTypes~=1 or gains~=1 or losses~=0 then
  return nil
 end
 return rawGain
end
local function oneTriplet(rows)
 if type(rows)~="table" then return nil,"ROWS_MISSING" end
 local count=0
 for k in pairs(rows) do
  if k~=1 then return nil,"MULTIPLE_OR_NONARRAY_ROWS" end
  count=count+1
 end
 if count~=1 or type(rows[1])~="table" then
  return nil,"MISSING_SINGLE_RECEIVED_ROW"
 end
 local row=rows[1]
 local fieldsSeen=0
 for k in pairs(row) do
  if k~=1 and k~=2 and k~=3 then
   return nil,"NONTRIPLET_RECEIVED_ROW"
  end
  fieldsSeen=fieldsSeen+1
 end
 if fieldsSeen~=3 or not key(row[1]) or
    not integer(row[2],1,1) or row[3]~="Weapons" then
  return nil,"UNVERIFIED_RECEIPT_TRIPLET_SHAPE"
 end
 return row[1],nil
end
function M.evaluate(input)
 -- String comparisons are exact, no case folding, aliasing, checker guesses,
 -- hashing, fuzzy name matches, market IDs or output item keys.
 if type(input)~="table" then return invalid("INPUT_MISSING") end
 local count=0
 local allowed={beforeOwned=true,post1Owned=true,post2Owned=true,
    receivedItems=true,callbackFirstArg=true,scopedInOneGui=true}
 for field in pairs(input) do
  if not allowed[field] then return invalid("EXTRA_OR_UNTRUSTED_SOURCE_FIELD") end
  count=count+1
 end
 if count~=6 then return invalid("INCOMPLETE_SOURCE_FIELDS") end
 if input.callbackFirstArg~=true or input.scopedInOneGui~=true then
  return invalid("CALLBACK_NOT_TRUE_OR_GUI_UNSCOPED")
 end
 local before,eb=rawOwned(input.beforeOwned)
 if not before then return invalid("BEFORE_"..eb) end
 local first,e1=rawOwned(input.post1Owned)
 if not first then return invalid("POST1_"..e1) end
 local second,e2=rawOwned(input.post2Owned)
 if not second then return invalid("POST2_"..e2) end
 if not sameSnapshot(first,second) then
  return invalid("POST_CLOSE_RAW_SNAPSHOTS_DISAGREE")
 end
 local gained=changed(before,second)
 if not gained then
  return invalid("NOT_EXACTLY_ONE_RAW_WEAPON_GAIN")
 end
 local callbackKey,why=oneTriplet(input.receivedItems)
 if not callbackKey then return invalid(why) end
 if callbackKey~=gained then
  return invalid("CALLBACK_KEY_DIFFERS_FROM_RAW_GAIN")
 end
 return result("PRIVATE_RAW_PRIMITIVE_EQUALITY_CLIENT_ONLY",
     "private-exact-string-equality-is-not-server-transaction-proof")
end
return M
