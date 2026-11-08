local dir=arg[1] or "pdiddler/new_part4"
local M=assert(loadfile(dir.."/p4_stage44_client_offer_state.lua"))()
local me,partner={},{}
local KEY="PrivateRawBatwingSyncKey_NotForOutput"
local pass=0
local function eq(a,b,what)assert(a==b,(what or "value")..":"..tostring(a).."!="..tostring(b))end
local function test(name,fn)
 local ok,err=pcall(fn)
 if not ok then error(name..": "..tostring(err),0)end
 pass=pass+1
end
local function fixture(orientation,withItem,key)
 key=key or KEY
 local x={LastOffer=1760000000,Locked=false,
 Player1={Player=orientation=="LOCAL_FIRST" and me or partner,Accepted=false,Offer={}},
 Player2={Player=orientation=="LOCAL_FIRST" and partner or me,Accepted=false,Offer={}}}
 if withItem then
  (orientation=="LOCAL_FIRST" and x.Player1 or x.Player2).Offer={{key,1,"Weapons"}}
 end
 return x
end
local authority={"eventSessionAssociationProven","causalAttributionProven",
 "ownerSideSlotBound","rawItemIdConfirmed","exactWeaponIdentityConfirmed",
 "rawKeyPresentConfirmed","serverCompletionProven","serverAttestation",
 "authorizesTrade","authorizesAccept","mayReportProfit","mayRecordCompletedTrade"}
local function safe(r)
 eq(r.readOnly,true);eq(r.clientOnly,true);eq(r.tradeOutcome,"UNKNOWN")
 for _,k in ipairs(authority)do eq(r[k],false,"authority:"..k)end
 local function clean(v,seen)
  if type(v)=="string" then
   assert(not v:find(KEY,1,true),"private key leaked")
   assert(not v:find("https?://"),"URL leaked")
  elseif type(v)=="table" then
   seen=seen or {};assert(not seen[v],"cyclic")
   seen[v]=true;for k,x in pairs(v)do clean(k,seen);clean(x,seen)end;seen[v]=nil
  else
   assert(type(v)=="number" or type(v)=="boolean","unexpected report data")
  end
 end
 clean(r);return r
end
local function inspect(x,key)
 return safe(M.inspect(table.pack(x),key or KEY,me,partner))
end
test("P2 Batwing add matches",function()
 local r=inspect(fixture("LOCAL_SECOND",true))
 eq(r.orientation,"LOCAL_SECOND");eq(r.localOfferTable,"PLAYER2")
 eq(r.state,"OWN_ONE_BATWING");eq(r.clientStateMatched,true)
 eq(r.firstFailedStage,"NONE");eq(r.ownKeyMatches,true)
 eq(r.ownQuantityOne,true);eq(r.ownCategoryWeapons,true)
end)
test("P2 empty after manual removal matches",function()
 local r=inspect(fixture("LOCAL_SECOND",false))
 eq(r.orientation,"LOCAL_SECOND");eq(r.state,"BOTH_EMPTY")
 eq(r.clientStateMatched,true);eq(r.ownSingleRow,false)
end)
test("P1 Batwing add matches",function()
 local r=inspect(fixture("LOCAL_FIRST",true))
 eq(r.orientation,"LOCAL_FIRST");eq(r.localOfferTable,"PLAYER1")
 eq(r.state,"OWN_ONE_BATWING");eq(r.clientStateMatched,true)
end)
test("P1 empty after removal matches",function()
 local r=inspect(fixture("LOCAL_FIRST",false))
 eq(r.orientation,"LOCAL_FIRST");eq(r.state,"BOTH_EMPTY")
end)
test("no first arg rejects",function()
 local r=safe(M.inspect(table.pack(),KEY,me,partner))
 eq(r.firstFailedStage,"ARGUMENT_PACK_INVALID")
end)
test("two args reject",function()
 local r=safe(M.inspect(table.pack(fixture("LOCAL_SECOND",true),false),KEY,me,partner))
 eq(r.firstFailedStage,"ARGUMENT_PACK_INVALID")
end)
test("extra pack field rejects",function()
 local r=safe(M.inspect({n=1,[1]=fixture("LOCAL_SECOND",true),extra=7},KEY,me,partner))
 eq(r.firstFailedStage,"ARGUMENT_PACK_INVALID")
end)
test("invalid key rejects",function()
 eq(inspect(fixture("LOCAL_SECOND",true),{}).firstFailedStage,"CANDIDATE_KEY_INVALID")
end)
test("missing partner rejects",function()
 local r=safe(M.inspect(table.pack(fixture("LOCAL_SECOND",true)),KEY,me,nil))
 eq(r.firstFailedStage,"PLAYER_CONTEXT_INVALID")
end)
test("same local and partner rejects",function()
 local r=safe(M.inspect(table.pack(fixture("LOCAL_SECOND",true)),KEY,me,me))
 eq(r.firstFailedStage,"PLAYER_CONTEXT_INVALID")
end)
test("different root fieldset rejects",function()
 local a=fixture("LOCAL_SECOND",true);a.Locked=nil;a.Another=false
 eq(inspect(a).firstFailedStage,"ROOT_FIELDSET_MISMATCH")
end)
test("root nonfinite lastOffer rejects",function()
 local a=fixture("LOCAL_SECOND",true);a.LastOffer=math.huge
 eq(inspect(a).firstFailedStage,"ROOT_VALUE_TYPE_MISMATCH")
end)
test("wrong side player fields reject",function()
 local a=fixture("LOCAL_SECOND",true);a.Player1.New=true
 eq(inspect(a).firstFailedStage,"PLAYER_FIELDSET_MISMATCH")
end)
test("metatable refuses arbitrary getters",function()
 local a=fixture("LOCAL_SECOND",true);setmetatable(a.Player1,{__index=function()error("UNSAFE")end})
 eq(inspect(a).firstFailedStage,"PLAYER_FIELDSET_MISMATCH")
end)
test("other userdata-like references reject",function()
 local a=fixture("LOCAL_SECOND",true);a.Player1.Player={}
 eq(inspect(a).firstFailedStage,"PLAYER_OBJECT_PAIR_MISMATCH")
end)
test("duplicate local references reject",function()
 local a=fixture("LOCAL_SECOND",true);a.Player1.Player=me
 eq(inspect(a).firstFailedStage,"PLAYER_OBJECT_PAIR_MISMATCH")
end)
test("one side accepted invalidates all",function()
 local a=fixture("LOCAL_SECOND",true);a.Player2.Accepted=true
 eq(inspect(a).firstFailedStage,"ACCEPT_STATE_MISMATCH")
end)
test("partner accepted invalidates empty",function()
 local a=fixture("LOCAL_SECOND",false);a.Player1.Accepted=true
 eq(inspect(a).firstFailedStage,"ACCEPT_STATE_MISMATCH")
end)
test("partner offer nonempty rejects even with local correct",function()
 local a=fixture("LOCAL_SECOND",true);a.Player1.Offer={{"Other",1,"Weapons"}}
 eq(inspect(a).firstFailedStage,"PARTNER_OFFER_NOT_EMPTY")
end)
test("two own rows reject",function()
 local a=fixture("LOCAL_SECOND",true);a.Player2.Offer[2]={"Other",1,"Weapons"}
 eq(inspect(a).firstFailedStage,"OWN_OFFER_SHAPE_MISMATCH")
end)
test("malformed row rejects",function()
 local a=fixture("LOCAL_SECOND",true);a.Player2.Offer[1][4]=false
 eq(inspect(a).firstFailedStage,"OWN_ROW_SHAPE_MISMATCH")
end)
test("wrong raw key rejects",function()
 local a=fixture("LOCAL_SECOND",true);a.Player2.Offer[1][1]="Batwing"
 local r=inspect(a);eq(r.firstFailedStage,"OWN_ROW_CONTENT_MISMATCH")
 eq(r.ownKeyMatches,false)
end)
test("wrong quantity rejects",function()
 local a=fixture("LOCAL_SECOND",true);a.Player2.Offer[1][2]=2
 eq(inspect(a).firstFailedStage,"OWN_ROW_CONTENT_MISMATCH")
end)
test("wrong weapon category rejects",function()
 local a=fixture("LOCAL_SECOND",true);a.Player2.Offer[1][3]="Pets"
 eq(inspect(a).firstFailedStage,"OWN_ROW_CONTENT_MISMATCH")
end)
test("raw numeric key accepts by exact Lua type",function()
 local a=fixture("LOCAL_SECOND",true,8239)
 local r=inspect(a,8239)
 eq(r.candidateKeyType,"NUMBER");eq(r.state,"OWN_ONE_BATWING")
end)
test("numeric key one duplicates quantity and rejects",function()
 local a=fixture("LOCAL_SECOND",true,1)
 eq(inspect(a,1).firstFailedStage,"RAW_KEY_POSITION_AMBIGUOUS")
end)
test("string key Weapons duplicates category and rejects",function()
 local a=fixture("LOCAL_SECOND",true,"Weapons")
 eq(inspect(a,"Weapons").firstFailedStage,"RAW_KEY_POSITION_AMBIGUOUS")
end)
test("raw key in wrong index rejects",function()
 local a=fixture("LOCAL_SECOND",true)
 a.Player2.Offer[1]={"DifferentKey",KEY,"Weapons"}
 eq(inspect(a).firstFailedStage,"OWN_ROW_CONTENT_MISMATCH")
end)
test("Batwing in partner's offer with own empty rejects",function()
 local a=fixture("LOCAL_SECOND",false);a.Player1.Offer={{KEY,1,"Weapons"}}
 eq(inspect(a).firstFailedStage,"PARTNER_OFFER_NOT_EMPTY")
end)
test("empty state with weird own numerical entry rejects",function()
 local a=fixture("LOCAL_SECOND",false);a.Player2.Offer={[3]=true}
 eq(inspect(a).firstFailedStage,"OWN_OFFER_SHAPE_MISMATCH")
end)
print("Stage44 client offer state pure: "..pass.." passed, 0 failed")
