-- Stage43 pure Lua: bounded, fail-closed, no raw values in report.
local dir=arg[1] or "pdiddler/new_part4"
local M=assert(loadfile(dir.."/p4_stage43_dynamic_own_offer.lua"))()
local me,them={},{}
local PRIVATE="PRIVATE_BATWING_RAW_SYNC_KEY_DO_NOT_OUTPUT"
local pass=0
local function eq(a,b,msg)assert(a==b,(msg or "value")..": "..tostring(a).." vs "..tostring(b))end
local function test(name,f)
 local ok,why=pcall(f)
 if not ok then error(name..": "..tostring(why),0)end
 pass=pass+1
end
local function fixture(position,key)
 key=key or PRIVATE
 local root={LastOffer=1760000000,Locked=false,
  Player1={Player=position==1 and me or them,Accepted=false,Offer={}},
  Player2={Player=position==1 and them or me,Accepted=false,Offer={}}}
 local own=position==1 and root.Player1 or root.Player2
 own.Offer={{key,1,"Weapons"}}
 return root
end
local authorities={"eventSessionAssociationProven","causalAttributionProven",
 "ownerSideSlotBound","rawItemIdConfirmed","exactWeaponIdentityConfirmed",
 "rawKeyPresentConfirmed","serverCompletionProven","serverAttestation",
 "authorizesTrade","authorizesAccept","mayReportProfit","mayRecordCompletedTrade"}
local function safe(r)
 eq(r.readOnly,true);eq(r.clientEventLayoutOnly,true)
 eq(r.tradeOutcome,"UNKNOWN")
 for _,k in ipairs(authorities)do eq(r[k],false,k)end
 local function clean(x,seen)
  if type(x)=="string" then
   assert(not x:find(PRIVATE,1,true),"RAW KEY EXPORTED")
   assert(not x:find("https?://"),"URL EXPORTED")
  elseif type(x)=="table" then
   seen=seen or {};assert(not seen[x],"CYCLE")
   seen[x]=true;for k,v in pairs(x)do clean(k,seen);clean(v,seen)end;seen[x]=nil
  else
   assert(type(x)=="number" or type(x)=="boolean","UNEXPECTED OUTPUT TYPE")
  end
 end
 clean(r);return r
end
local function inspect(root,key)
 return safe(M.inspect(table.pack(root),key or PRIVATE,me,them))
end
test("forward owner-relative raw tuple matches",function()
 local r=inspect(fixture(1))
 eq(r.orientation,"LOCAL_FIRST");eq(r.localOfferTable,"PLAYER1")
 eq(r.clientOwnOfferTupleMatches,true);eq(r.rawKeyMatchPosition,1)
 eq(r.status,"CLIENT_SNAPSHOT_TUPLE_MATCHED_UNAUTHENTICATED")
end)
test("reverse owner-relative raw tuple matches",function()
 local r=inspect(fixture(2))
 eq(r.orientation,"LOCAL_SECOND");eq(r.localOfferTable,"PLAYER2")
 eq(r.partnerOfferTable,"PLAYER1");eq(r.clientOwnOfferTupleMatches,true)
 eq(r.ownSingleRow,"TRUE");eq(r.partnerOfferEmpty,"TRUE")
 eq(r.bothAcceptedFalse,"TRUE");eq(r.firstFailedStage,"NONE")
end)
test("missing local player in both fields rejects",function()
 local a,b=fixture(1),{}
 a.Player1.Player=b
 local r=inspect(a);eq(r.firstFailedStage,"PLAYER_OBJECT_PAIR_MISMATCH")
 eq(r.clientOwnOfferTupleMatches,false)
end)
test("both fields local rejects",function()
 local a=fixture(1);a.Player2.Player=me
 local r=inspect(a);eq(r.firstFailedStage,"PLAYER_OBJECT_PAIR_MISMATCH")
end)
test("both fields partner rejects",function()
 local a=fixture(1);a.Player1.Player=them
 local r=inspect(a);eq(r.firstFailedStage,"PLAYER_OBJECT_PAIR_MISMATCH")
end)
test("partial actor identity rejects",function()
 local a=fixture(1);a.Player2.Player={}
 local r=inspect(a);eq(r.firstFailedStage,"PLAYER_OBJECT_PAIR_MISMATCH")
end)
test("missing partner rejects before any identity checks",function()
 local r=safe(M.inspect(table.pack(fixture(1)),PRIVATE,me,nil))
 eq(r.firstFailedStage,"PLAYER_CONTEXT_INVALID")
 eq(r.orientationCompared,false)
end)
test("same actor for local and partner rejects",function()
 local r=safe(M.inspect(table.pack(fixture(1)),PRIVATE,me,me))
 eq(r.firstFailedStage,"PLAYER_CONTEXT_INVALID")
end)
test("zero event arguments rejects",function()
 local r=safe(M.inspect(table.pack(),PRIVATE,me,them))
 eq(r.firstFailedStage,"ARGUMENT_PACK_INVALID")
end)
test("two event arguments rejects",function()
 local r=safe(M.inspect(table.pack(fixture(1),fixture(2)),PRIVATE,me,them))
 eq(r.firstFailedStage,"ARGUMENT_PACK_INVALID")
end)
test("extra packed arg rejects",function()
 local r=safe(M.inspect({n=1,[1]=fixture(1),unexpected=true},PRIVATE,me,them))
 eq(r.firstFailedStage,"ARGUMENT_PACK_INVALID")
end)
test("wrong root key rejects before orientation",function()
 local a=fixture(1);a.Locked=nil;a.NewField=false
 local r=inspect(a);eq(r.firstFailedStage,"ROOT_FIELDSET_MISMATCH")
 eq(r.orientation,"UNTESTED")
end)
test("wrong root numeric type rejects",function()
 local a=fixture(1);a.LastOffer="yesterday"
 eq(inspect(a).firstFailedStage,"ROOT_VALUE_TYPE_MISMATCH")
end)
test("wrong root boolean type rejects",function()
 local a=fixture(1);a.Locked=1
 eq(inspect(a).firstFailedStage,"ROOT_VALUE_TYPE_MISMATCH")
end)
test("side unknown extra field rejects",function()
 local a=fixture(1);a.Player2.Etc=true
 eq(inspect(a).firstFailedStage,"PLAYER_FIELDSET_MISMATCH")
end)
test("own Accept true is not a valid empty-accept snapshot",function()
 local a=fixture(2);a.Player2.Accepted=true
 local r=inspect(a);eq(r.firstFailedStage,"ACCEPT_STATE_MISMATCH")
 eq(r.bothAcceptedFalse,"FALSE")
end)
test("partner Accept true invalidates test snapshot",function()
 local a=fixture(2);a.Player1.Accepted=true
 eq(inspect(a).firstFailedStage,"ACCEPT_STATE_MISMATCH")
end)
test("partner offers unrelated item rejects",function()
 local a=fixture(2);a.Player1.Offer={{"Other",1,"Weapons"}}
 local r=inspect(a);eq(r.firstFailedStage,"OFFER_LIST_MISMATCH")
 eq(r.partnerOfferEmpty,"FALSE")
end)
test("own empty offer rejects",function()
 local a=fixture(2);a.Player2.Offer={}
 eq(inspect(a).firstFailedStage,"OFFER_LIST_MISMATCH")
end)
test("own two-row offer rejects",function()
 local a=fixture(2);a.Player2.Offer={{PRIVATE,1,"Weapons"},{"Other",1,"Weapons"}}
 eq(inspect(a).firstFailedStage,"OFFER_LIST_MISMATCH")
end)
test("own malformed row rejects",function()
 local a=fixture(2);a.Player2.Offer[1][4]=true
 eq(inspect(a).firstFailedStage,"OFFER_ROW_SHAPE_MISMATCH")
end)
test("different weapon key cannot masquerade as Batwing",function()
 local a=fixture(2);a.Player2.Offer[1][1]="NotBatwing"
 local r=inspect(a);eq(r.firstFailedStage,"ROW_CONTENT_MISMATCH")
 eq(r.ownKeyMatches,"FALSE")
end)
test("wrong quantity rejects",function()
 local a=fixture(2);a.Player2.Offer[1][2]=2
 local r=inspect(a);eq(r.firstFailedStage,"ROW_CONTENT_MISMATCH")
 eq(r.ownQuantityOne,"FALSE")
end)
test("wrong category rejects",function()
 local a=fixture(2);a.Player2.Offer[1][3]="Pets"
 local r=inspect(a);eq(r.firstFailedStage,"ROW_CONTENT_MISMATCH")
 eq(r.ownCategoryWeapons,"FALSE")
end)
test("numeric raw Sync key succeeds, never coerces",function()
 local a=fixture(2,72933)
 local r=inspect(a,72933);eq(r.candidateKeyType,"NUMBER")
 eq(r.clientOwnOfferTupleMatches,true)
end)
test("numeric key 1 ambiguous with quantity 1 rejects",function()
 local a=fixture(2,1)
 eq(inspect(a,1).firstFailedStage,"RAW_KEY_POSITION_AMBIGUOUS")
end)
test("raw key equal to category Weapons is ambiguous",function()
 local a=fixture(2,"Weapons")
 eq(inspect(a,"Weapons").firstFailedStage,"RAW_KEY_POSITION_AMBIGUOUS")
end)
test("unsupported key type rejected",function()
 local r=inspect(fixture(2),{})
 eq(r.firstFailedStage,"CANDIDATE_KEY_INVALID")
end)
test("metatable on player map cannot execute callbacks",function()
 local a=fixture(2)
 setmetatable(a.Player2,{__index=function()error("CALLBACK BAD")end})
 eq(inspect(a).firstFailedStage,"PLAYER_FIELDSET_MISMATCH")
end)
test("name-only same printed label cannot pass raw key comparison",function()
 local a=fixture(2);a.Player2.Offer[1][1]="Batwing"
 eq(inspect(a).clientOwnOfferTupleMatches,false)
end)
test("reversed owner but target appears in partner Offer rejects",function()
 local a=fixture(2);a.Player2.Offer={}
 a.Player1.Offer={{PRIVATE,1,"Weapons"}}
 local r=inspect(a)
 eq(r.orientation,"LOCAL_SECOND")
 eq(r.clientOwnOfferTupleMatches,false)
 eq(r.firstFailedStage,"OFFER_LIST_MISMATCH")
end)
print("Stage43 dynamic own-offer pure: "..pass.." passed, 0 failed")
