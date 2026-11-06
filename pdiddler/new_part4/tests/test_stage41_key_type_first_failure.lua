-- Stage41 pure tests: observed key type, tested-vs-untested, first failed gate.
local dir=arg[1] or "pdiddler/new_part4"
local M=assert(loadfile(dir.."/p4_stage41_key_type_first_failure.lua"))()
local count=0
local PRIVATE="PrivateRawWeaponKey-DoNotExport"
local me,partner={},{}
local function eq(a,b,what)assert(a==b,(what or "value")..": "..tostring(a).." vs "..tostring(b))end
local function test(name,fn)
 local ok,why=pcall(fn)
 if not ok then error(name..": "..tostring(why),0)end
 count=count+1
end
local function fixture(key)
 return {Locked=false,LastOffer=7,
  Player1={Player=me,Accepted=false,Offer={{key,1,"Weapons"}}},
  Player2={Player=partner,Accepted=false,Offer={}}}
end
local flags={"rawItemIdConfirmed","rawKeyPresentConfirmed","exactWeaponIdentityConfirmed",
 "ownerSideSlotBound","eventSessionAssociationProven","serverCompletionProven",
 "authorizesTrade","authorizesAccept","mayRecordCompletedTrade","mayReportProfit"}
local function safe(r)
 for _,k in ipairs(flags)do eq(r[k],false,k)end
 eq(r.readOnly,true,"read-only")
 eq(r.layoutHypothesisOnly,true,"not authentic schema")
 eq(r.tradeOutcome,"UNKNOWN","not a completed trade")
 local function noSecrets(x)
  if type(x)=="string" then
   assert(not x:find(PRIVATE,1,true),"raw key leaked")
   assert(not x:find("https?://"),"URL leaked")
  elseif type(x)=="table" then
   for k,v in pairs(x)do noSecrets(k);noSecrets(v)end
  else assert(type(x)=="number" or type(x)=="boolean","unsupported report data")end
 end
 noSecrets(r)
 return r
end
local function inspect(t,key,label)
 return safe(M.inspect(table.pack(t),key,label or "Batwing",me,partner))
end
test("string key and full synthetic matching layout, no authority",function()
 local r=inspect(fixture(PRIVATE),PRIVATE)
 eq(r.candidateKeyType,"STRING");eq(r.candidateKeyEqualsVisibleLabel,"FALSE")
 eq(r.firstFailedStage,"NONE");eq(r.hypothesisMatched,true)
 eq(r.tripletKeyIndex,1)
end)
test("numeric key is accepted unlike legacy Stage40, type checked",function()
 local r=inspect(fixture(87042),87042)
 eq(r.candidateKeyType,"NUMBER");eq(r.legacyStage40RejectedNumericKey,true)
 eq(r.candidateKeyEqualsVisibleLabel,"FALSE");eq(r.hypothesisMatched,true)
 eq(r.firstFailedStage,"NONE");eq(r.tripletKeyIndex,1)
end)
test("numeric key and root mismatch produce real first failure, not input failure",function()
 local t=fixture(87042);t.Locked=nil;t.Status=false
 local r=inspect(t,87042)
 eq(r.firstFailedStage,"ROOT_FIELDSET_MISMATCH")
 eq(r.rootFieldSetMatches,"FALSE")
 eq(r.player1ObjectEqualsLocal,"UNTESTED")
 eq(r.tripletQuantityIsOne,"UNTESTED")
 eq(r.candidateKeyEqualsVisibleLabel,"FALSE")
end)
test("string key equal to display label is explicitly compared",function()
 local r=inspect(fixture("Batwing"),"Batwing")
 eq(r.candidateKeyEqualsVisibleLabel,"TRUE")
 eq(r.hypothesisMatched,true)
end)
test("invalid key does not claim label comparison",function()
 local r=inspect(fixture(PRIVATE),math.huge)
 eq(r.candidateKeyType,"UNSUPPORTED")
 eq(r.candidateKeyEqualsVisibleLabel,"UNTESTED")
 eq(r.firstFailedStage,"CANDIDATE_KEY_INVALID")
end)
test("invalid packed arguments reject before candidate key operations",function()
 for _,a in ipairs({{n=2,[1]=fixture(PRIVATE)}, {n=1,[1]=fixture(PRIVATE),[2]=false},
  {n=1}, {n=1,[1]=fixture(PRIVATE),extra=true}})do
  local r=safe(M.inspect(a,PRIVATE,"Batwing",me,partner))
  eq(r.firstFailedStage,"ARGUMENT_PACK_INVALID")
  eq(r.candidateKeyEqualsVisibleLabel,"UNTESTED")
 end
end)
test("unsupported label fails closed while key type still reported",function()
 local r=inspect(fixture(PRIVATE),PRIVATE,"")
 eq(r.firstFailedStage,"DISPLAY_LABEL_INVALID")
 eq(r.candidateKeyEqualsVisibleLabel,"UNTESTED")
end)
test("missing partner cannot fake player equality",function()
 local r=safe(M.inspect(table.pack(fixture(PRIVATE)),PRIVATE,"Batwing",me,nil))
 eq(r.firstFailedStage,"PARTNER_CONTEXT_INVALID")
 eq(r.player1ObjectEqualsLocal,"UNTESTED")
end)
test("root value-type mismatch occurs after keyset check",function()
 local t=fixture(PRIVATE);t.LastOffer=math.huge
 local r=inspect(t,PRIVATE)
 eq(r.rootFieldSetMatches,"TRUE")
 eq(r.rootValueTypesMatch,"FALSE")
 eq(r.firstFailedStage,"ROOT_VALUE_TYPE_MISMATCH")
 eq(r.playerFieldSetsMatch,"UNTESTED")
end)
test("player fieldset mismatch leaves identity comparisons UNTESTED",function()
 local t=fixture(PRIVATE);t.Player1.Unknown=true
 local r=inspect(t,PRIVATE)
 eq(r.firstFailedStage,"PLAYER_FIELDSET_MISMATCH")
 eq(r.player1ObjectEqualsLocal,"UNTESTED")
 eq(r.player2ObjectEqualsPartner,"UNTESTED")
end)
test("reversed player objects are independently measured mismatches",function()
 local t=fixture(PRIVATE)
 t.Player1.Player=partner;t.Player2.Player=me
 local r=inspect(t,PRIVATE)
 eq(r.firstFailedStage,"PLAYER_OBJECT_MISMATCH")
 eq(r.player1ObjectEqualsLocal,"FALSE")
 eq(r.player2ObjectEqualsPartner,"FALSE")
 eq(r.offerShapesMatch,"UNTESTED")
end)
test("accepted indicator fails before inspecting offer rows",function()
 local t=fixture(PRIVATE);t.Player1.Accepted=true
 local r=inspect(t,PRIVATE)
 eq(r.firstFailedStage,"ACCEPT_STATE_MISMATCH")
 eq(r.playerAcceptedFlagsFalse,"FALSE")
 eq(r.offerShapesMatch,"UNTESTED")
end)
test("offer shape mismatch leaves row fields untested",function()
 local t=fixture(PRIVATE);t.Player2.Offer={{PRIVATE,1,"Weapons"}}
 local r=inspect(t,PRIVATE)
 eq(r.firstFailedStage,"OFFER_LIST_MISMATCH")
 eq(r.tripletKeyEqualsCatalogue,"UNTESTED")
end)
test("malformed triplet reports its exact failure",function()
 local t=fixture(PRIVATE);t.Player1.Offer[1][4]=true
 local r=inspect(t,PRIVATE)
 eq(r.firstFailedStage,"OFFER_ROW_SHAPE_MISMATCH")
 eq(r.tripletQuantityIsOne,"UNTESTED")
end)
test("wrong item quantity is measured, not a false identity claim",function()
 local t=fixture(PRIVATE);t.Player1.Offer[1][2]=2
 local r=inspect(t,PRIVATE)
 eq(r.firstFailedStage,"ROW_LITERAL_MISMATCH")
 eq(r.tripletKeyEqualsCatalogue,"TRUE")
 eq(r.tripletQuantityIsOne,"FALSE")
 eq(r.tripletCategoryIsWeapons,"TRUE")
end)
test("numeric key in second row position does not silently assume first slot",function()
 local t=fixture(87042)
 t.Player1.Offer[1]={"SomeOtherLabel",87042,"Weapons"}
 local r=inspect(t,87042)
 eq(r.tripletKeyIndex,2)
 eq(r.tripletKeyEqualsCatalogue,"FALSE")
 eq(r.firstFailedStage,"ROW_LITERAL_MISMATCH")
end)
test("numeric key in third row position retained as positional evidence only",function()
 local t=fixture(87042)
 t.Player1.Offer[1]={"SomeOtherLabel",1,87042}
 local r=inspect(t,87042)
 eq(r.tripletKeyIndex,3)
 eq(r.tripletKeyEqualsCatalogue,"FALSE")
 eq(r.firstFailedStage,"ROW_LITERAL_MISMATCH")
end)
test("candidate value 1 matches quantity as well: ambiguity is not inferred as key position",function()
 local t=fixture(1)
 local r=inspect(t,1)
 eq(r.firstFailedStage,"MULTIPLE_KEY_POSITIONS")
 eq(r.tripletKeyIndex,1)
 eq(r.hypothesisMatched,false)
end)
test("table with metatable is rejected before indexing",function()
 local t=fixture(PRIVATE)
 setmetatable(t.Player1,{__index=function()error("must not run")end})
 local r=inspect(t,PRIVATE)
 eq(r.firstFailedStage,"PLAYER_FIELDSET_MISMATCH")
end)
test("unexpected root key is only root failure, not fake downstream",function()
 local t=fixture(PRIVATE);t.Extra=123
 local r=inspect(t,PRIVATE)
 eq(r.firstFailedStage,"ROOT_FIELDSET_MISMATCH")
 eq(r.playerAcceptedFlagsFalse,"UNTESTED")
end)
test("wrong category tested only after valid row shape",function()
 local t=fixture(PRIVATE);t.Player1.Offer[1][3]="Pets"
 local r=inspect(t,PRIVATE)
 eq(r.firstFailedStage,"ROW_LITERAL_MISMATCH")
 eq(r.tripletCategoryIsWeapons,"FALSE")
end)
print("Stage41 key type first-failure pure: "..count.." passed, 0 failed")
