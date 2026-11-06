-- Stage42 pure probe regression (offline ONLY, never MM2 server proof)
local dir=arg[1] or "pdiddler/new_part4"
local M=assert(loadfile(dir.."/p4_stage42_player_orientation.lua"))()
local passed=0
local a,b={},{}
local PRIVATE="NeverPrintThePrivatePlayerSecret"
local function test(name,fn)
 local ok,why=pcall(fn)
 if not ok then error(name..": "..tostring(why),0)end
 passed=passed+1
end
local function eq(x,y,why)assert(x==y,(why or "value")..": "..tostring(x).." vs "..tostring(y))end
local function fake(p1,p2)
 return {LastOffer=1760000001,Locked=false,
  Player1={Player=p1,Accepted=false,Offer={{"Item",1,"Weapons"}}},
  Player2={Player=p2,Accepted=false,Offer={}}}
end
local function safe(r)
 for _,k in ipairs({"rawItemIdConfirmed","rawKeyPresentConfirmed",
   "ownerSideSlotBound","eventSessionAssociationProven","serverCompletionProven",
   "exactWeaponIdentityConfirmed","causalAttributionProven","authorizesTrade",
   "authorizesAccept","mayRecordCompletedTrade","mayReportProfit","offerSideAssumed"}) do
  eq(r[k],false,"authority "..k)
 end
 eq(r.readOnly,true)
 eq(r.orientationIsClientObservationOnly,true)
 eq(r.tradeOutcome,"UNKNOWN")
 local function clean(v,seen)
  if type(v)=="string" then
   assert(not v:find(PRIVATE,1,true),"secret string emitted")
  elseif type(v)=="table" then
   seen=seen or {};assert(not seen[v],"cyclic report");seen[v]=true
   for k,x in pairs(v) do clean(k,seen);clean(x,seen)end
   seen[v]=nil
  else assert(type(v)=="boolean" or type(v)=="number","unexpected exported value type")end
 end
 clean(r);return r
end
local function inspect(t,localObj,partnerObj)
 return safe(M.inspect(table.pack(t),localObj or a,partnerObj or b))
end
test("local first precisely complementary pair",function()
 local r=inspect(fake(a,b))
 eq(r.status,"CLIENT_REFERENCE_ORIENTATION_OBSERVED")
 eq(r.orientation,"LOCAL_FIRST")
 eq(r.player1EqualsLocal,"TRUE");eq(r.player1EqualsPartner,"FALSE")
 eq(r.player2EqualsLocal,"FALSE");eq(r.player2EqualsPartner,"TRUE")
 eq(r.comparisonComplete,true);eq(r.rootAndSideShapeValid,true)
end)
test("local second reverses server label ordering without guessing",function()
 local r=inspect(fake(b,a))
 eq(r.orientation,"LOCAL_SECOND");eq(r.status,"CLIENT_REFERENCE_ORIENTATION_OBSERVED")
 eq(r.player1EqualsLocal,"FALSE");eq(r.player1EqualsPartner,"TRUE")
 eq(r.player2EqualsLocal,"TRUE");eq(r.player2EqualsPartner,"FALSE")
 eq(r.localPlayerSecond,true)
 eq(r.ownerSideSlotBound,false)
end)
test("both unrelated objects are no pair",function()
 local r=inspect(fake({},{}))
 eq(r.orientation,"NO_EXACT_PAIR")
 eq(r.firstStopReason,"NO_MATCHING_PLAYER_REFERENCES")
 eq(r.comparisonComplete,true)
end)
test("duplicate local reference is not a complementary pair",function()
 local r=inspect(fake(a,a))
 eq(r.orientation,"PARTIAL_OR_DUPLICATE")
 eq(r.localPlayerFirst,false);eq(r.localPlayerSecond,false)
end)
test("duplicate partner reference is not a complementary pair",function()
 local r=inspect(fake(b,b))
 eq(r.orientation,"PARTIAL_OR_DUPLICATE")
end)
test("single first local match is partial, not orientation",function()
 local r=inspect(fake(a,{}))
 eq(r.orientation,"PARTIAL_OR_DUPLICATE")
 eq(r.player2EqualsPartner,"FALSE")
end)
test("single first partner match is partial, not orientation",function()
 local r=inspect(fake(b,{}))
 eq(r.orientation,"PARTIAL_OR_DUPLICATE")
end)
test("single second local match is partial, not orientation",function()
 local r=inspect(fake({},a))
 eq(r.orientation,"PARTIAL_OR_DUPLICATE")
end)
test("single second partner match is partial, not orientation",function()
 local r=inspect(fake({},b))
 eq(r.orientation,"PARTIAL_OR_DUPLICATE")
end)
test("plain string player value cannot masquerade as a Player object",function()
 local r=inspect(fake("a","b"))
 eq(r.orientation,"NO_EXACT_PAIR");eq(r.player1ValueType,"STRING")
 eq(r.player2ValueType,"STRING")
end)
test("non-Player typed values only report coarse type",function()
 local r=inspect(fake(4,true))
 eq(r.orientation,"NO_EXACT_PAIR")
 eq(r.player1ValueType,"NUMBER");eq(r.player2ValueType,"BOOLEAN")
end)
test("distinct local and partner contexts required",function()
 local r=safe(M.inspect(table.pack(fake(a,b)),a,a))
 eq(r.firstStopReason,"PLAYER_CONTEXT_INVALID")
 eq(r.orientation,"UNTESTED")
 eq(r.player1EqualsLocal,"UNTESTED")
end)
test("missing partner context rejected",function()
 local r=safe(M.inspect(table.pack(fake(a,b)),a,nil))
 eq(r.firstStopReason,"PLAYER_CONTEXT_INVALID")
end)
test("missing event argument rejected",function()
 local r=safe(M.inspect(table.pack(),a,b))
 eq(r.firstStopReason,"ARGUMENT_PACK_INVALID")
end)
test("extra arguments rejected",function()
 local r=safe(M.inspect(table.pack(fake(a,b),fake(a,b)),a,b))
 eq(r.firstStopReason,"ARGUMENT_PACK_INVALID")
end)
test("extra packed keys rejected",function()
 local r=safe(M.inspect({n=1,[1]=fake(a,b),extra=true},a,b))
 eq(r.firstStopReason,"ARGUMENT_PACK_INVALID")
end)
test("wrong root fields must not leak player comparisons",function()
 local t=fake(a,b);t.Locked=nil;t.OtherField=false
 local r=inspect(t)
 eq(r.firstStopReason,"ROOT_SCHEMA_MISMATCH")
 eq(r.comparisonComplete,false)
 eq(r.player1EqualsLocal,"UNTESTED")
end)
test("extra root field rejected",function()
 local t=fake(a,b);t.Extra=true
 local r=inspect(t)
 eq(r.firstStopReason,"ROOT_SCHEMA_MISMATCH")
end)
test("invalid player side map rejected before any identity comparisons",function()
 local t=fake(a,b);t.Player2.Extra=true
 local r=inspect(t)
 eq(r.firstStopReason,"PLAYER_FIELDSET_MISMATCH")
 eq(r.player1EqualsLocal,"UNTESTED")
end)
test("metatable callbacks not invoked",function()
 local t=fake(a,b)
 setmetatable(t.Player1,{__index=function()error("METAMETHOD CALLED")end})
 local r=inspect(t)
 eq(r.firstStopReason,"PLAYER_FIELDSET_MISMATCH")
end)
test("field type nil cannot compare successfully",function()
 local t=fake(a,b);t.Player1.Player=nil
 local r=inspect(t)
 eq(r.firstStopReason,"PLAYER_FIELDSET_MISMATCH")
end)
test("owner ordering not inferred from an offered key",function()
 local t=fake(b,a)
 t.Player1.Offer={};t.Player2.Offer={{PRIVATE,1,"Weapons"}}
 local r=inspect(t)
 eq(r.orientation,"LOCAL_SECOND")
 eq(r.ownerSideSlotBound,false)
end)
print("Stage42 player orientation pure: "..passed.." passed, 0 failed")
