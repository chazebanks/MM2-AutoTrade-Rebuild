local dir=arg[1] or "pdiddler/new_part4"
local M=assert(loadfile(dir.."/p4_stage46_starttrade_tuple_semantics.lua"))()
local me={Name="DeltaAccount",DisplayName="DeltaAlias"}
local partner={Name="TrustedAccount",DisplayName="TrustedAlias"}
local stranger={Name="Another",DisplayName="AnotherAlias"}
local SECRET="SECRET_STRING_SESSION_OR_ACCOUNT_TOKEN"
local passed=0
local function eq(a,b,msg)assert(a==b,(msg or "value")..":"..tostring(a).." != "..tostring(b))end
local function test(label,fn)
 local ok,err=pcall(fn);if not ok then error(label..": "..tostring(err),0)end
 passed=passed+1
end
local auth={"eventSessionAssociationProven","causalAttributionProven",
 "serverAttestation","serverCompletionProven","hasAuthenticatedSessionIdentifier",
 "sessionIdProven","ownerSideSlotBound","rawItemIdConfirmed",
 "exactWeaponIdentityConfirmed","rawKeyPresentConfirmed","authorizesAccept",
 "authorizesTrade","mayRecordCompletedTrade","mayReportProfit"}
local function safe(r)
 eq(r.readOnly,true);eq(r.clientOnly,true);eq(r.tradeOutcome,"UNKNOWN")
 for _,k in ipairs(auth)do eq(r[k],false,"authority "..k)end
 local function walk(v)
  if type(v)=="string"then
   assert(not v:find(SECRET,1,true),"secret string leaked")
   assert(not v:find("TrustedAccount",1,true),"partner username leaked")
   assert(not v:find("DeltaAccount",1,true),"local username leaked")
  elseif type(v)=="table"then
   for k,x in pairs(v)do walk(k);walk(x)end
  end
 end
 walk(r);return r
end
local function tbl(secondLocal)
 local first=secondLocal and partner or me
 local last=secondLocal and me or partner
 return {LastOffer=1760000000,Locked=false,
  Player1={Player=first,Accepted=false,Offer={}},
  Player2={Player=last,Accepted=false,Offer={}}}
end
local function check(t,str,localActor,otherActor)
 return safe(M.inspect(table.pack(t,str),localActor or me,otherActor or partner))
end
test("P2 empty table plus partner username matches only client hypothesis",function()
 local r=check(tbl(true),partner.Name)
 eq(r.clientTupleHypothesisMatched,true)
 eq(r.tableLayout,"EMPTY_TRADE_TABLE_CLIENT_LAYOUT_MATCH")
 eq(r.orientation,"LOCAL_SECOND")
 eq(r.stringClassification,"PARTNER_USERNAME_EXACT")
 eq(r.actorReferencesMatched,true);eq(r.bothOffersEmpty,true)
end)
test("P1 actor reversal also matches",function()
 local r=check(tbl(false),partner.Name)
 eq(r.clientTupleHypothesisMatched,true);eq(r.orientation,"LOCAL_FIRST")
end)
test("partner display-only string matches partner role",function()
 local r=check(tbl(true),partner.DisplayName)
 eq(r.clientTupleHypothesisMatched,true)
 eq(r.stringClassification,"PARTNER_DISPLAY_ONLY")
end)
test("same username/display same actor is not ambiguous across actors",function()
 local b={Name=partner.Name,DisplayName=partner.Name}
 local r=check({LastOffer=4,Locked=false,
 Player1={Player=me,Accepted=false,Offer={}},
 Player2={Player=b,Accepted=false,Offer={}}},b.Name,me,b)
 eq(r.stringClassification,"PARTNER_USERNAME_EXACT")
 eq(r.clientTupleHypothesisMatched,true)
end)
test("local username is not partner matched",function()
 local r=check(tbl(true),me.Name)
 eq(r.stringClassification,"LOCAL_USERNAME_EXACT")
 eq(r.clientTupleHypothesisMatched,false)
end)
test("local display is not partner matched",function()
 local r=check(tbl(true),me.DisplayName)
 eq(r.stringClassification,"LOCAL_DISPLAY_ONLY")
 eq(r.clientTupleHypothesisMatched,false)
end)
test("same string assigned to both actor names is ambiguous",function()
 local b={Name=me.Name,DisplayName="Other"}
 local r=check({LastOffer=4,Locked=false,
 Player1={Player=me,Accepted=false,Offer={}},
 Player2={Player=b,Accepted=false,Offer={}}},me.Name,me,b)
 eq(r.stringClassification,"AMBIGUOUS_BOTH_ACTORS")
 eq(r.clientTupleHypothesisMatched,false)
end)
test("unmatched string never called session ID",function()
 local r=check(tbl(true),SECRET)
 eq(r.stringClassification,"OTHER_STRING_UNCLASSIFIED")
 eq(r.clientTupleHypothesisMatched,false)
end)
test("empty string remains explicitly unclassified",function()
 local r=check(tbl(true),"")
 eq(r.stringClassification,"EMPTY_STRING")
end)
test("extra root key rejects known table hypothesis",function()
 local t=tbl(true);t.SomeExtra=SECRET
 local r=check(t,partner.Name)
 eq(r.tableLayout,"ROOT_FIELDSET_MISMATCH")
 eq(r.clientTupleHypothesisMatched,false)
end)
test("missing root key rejects",function()
 local t=tbl(true);t.Locked=nil
 eq(check(t,partner.Name).tableLayout,"ROOT_FIELDSET_MISMATCH")
end)
test("wrong Locked type rejects root values",function()
 local t=tbl(true);t.Locked=1
 eq(check(t,partner.Name).tableLayout,"ROOT_TYPES_MISMATCH")
end)
test("NaN LastOffer cannot pass finite check",function()
 local t=tbl(true);t.LastOffer=0/0
 eq(check(t,partner.Name).tableLayout,"ROOT_TYPES_MISMATCH")
end)
test("infinite LastOffer cannot pass",function()
 local t=tbl(true);t.LastOffer=math.huge
 eq(check(t,partner.Name).tableLayout,"ROOT_TYPES_MISMATCH")
end)
test("other actor reference does not match",function()
 local t=tbl(true);t.Player1.Player=stranger
 eq(check(t,partner.Name).tableLayout,"ACTOR_PAIR_MISMATCH")
end)
test("duplicate own actor reference cannot pass",function()
 local t=tbl(true);t.Player1.Player=me
 eq(check(t,partner.Name).tableLayout,"ACTOR_PAIR_MISMATCH")
end)
test("local accepted true rejects initial client state",function()
 local t=tbl(true);t.Player2.Accepted=true
 eq(check(t,partner.Name).tableLayout,"ACCEPT_STATE_MISMATCH")
end)
test("partner accepted true rejects",function()
 local t=tbl(true);t.Player1.Accepted=true
 eq(check(t,partner.Name).tableLayout,"ACCEPT_STATE_MISMATCH")
end)
test("nonempty partner offer rejects",function()
 local t=tbl(true);t.Player1.Offer={{SECRET,1,"Weapons"}}
 eq(check(t,partner.Name).tableLayout,"OFFERS_NOT_EMPTY")
end)
test("nonempty local offer rejects",function()
 local t=tbl(true);t.Player2.Offer={{SECRET,1,"Weapons"}}
 eq(check(t,partner.Name).tableLayout,"OFFERS_NOT_EMPTY")
end)
test("root with metatable rejected without executing getter",function()
 local t=tbl(true);setmetatable(t,{__index=function()error("UNSAFE")end})
 eq(check(t,partner.Name).tableLayout,"ROOT_FIELDSET_MISMATCH")
end)
test("side with metatable rejected without executing getter",function()
 local t=tbl(true);setmetatable(t.Player1,{__index=function()error("UNSAFE")end})
 eq(check(t,partner.Name).tableLayout,"PLAYER_FIELDSET_MISMATCH")
end)
test("offer with metatable rejects without getter",function()
 local t=tbl(true);setmetatable(t.Player1.Offer,{__index=function()error("UNSAFE")end})
 eq(check(t,partner.Name).tableLayout,"OFFERS_NOT_EMPTY")
end)
test("side extra field rejects",function()
 local t=tbl(true);t.Player1.Secret=SECRET
 eq(check(t,partner.Name).tableLayout,"PLAYER_FIELDSET_MISMATCH")
end)
test("incorrect argument order rejects",function()
 local r=safe(M.inspect(table.pack(partner.Name,tbl(true)),me,partner))
 eq(r.reason,"ARGUMENT_TYPES_MISMATCH")
end)
test("missing args fail pack check",function()
 local r=safe(M.inspect(table.pack(tbl(true)),me,partner))
 eq(r.reason,"ARGUMENT_PACK_OR_COUNT_MISMATCH")
end)
test("more than two args fail pack check",function()
 local r=safe(M.inspect(table.pack(tbl(true),partner.Name,SECRET),me,partner))
 eq(r.reason,"ARGUMENT_PACK_OR_COUNT_MISMATCH")
end)
test("extra pack field rejects",function()
 local r=safe(M.inspect({n=2,[1]=tbl(true),[2]=partner.Name,SECRET=SECRET},me,partner))
 eq(r.reason,"ARGUMENT_PACK_OR_COUNT_MISMATCH")
end)
test("metatable argpack rejects without getter",function()
 local a=setmetatable(table.pack(tbl(true),partner.Name),{__index=function()error("UNSAFE")end})
 eq(safe(M.inspect(a,me,partner)).reason,"ARGUMENT_PACK_OR_COUNT_MISMATCH")
end)
test("overlong second string rejected without export",function()
 eq(check(tbl(true),string.rep("Z",257)).reason,"STRING_LENGTH_UNSUPPORTED")
end)
test("same actor for both sides rejected",function()
 local r=safe(M.inspect(table.pack(tbl(true),partner.Name),me,me))
 eq(r.reason,"ACTOR_CONTEXT_INVALID")
end)
test("missing actor rejected",function()
 local r=safe(M.inspect(table.pack(tbl(true),partner.Name),me,nil))
 eq(r.reason,"ACTOR_CONTEXT_INVALID")
end)
test("missing player Name rejected",function()
 local t=tbl(true)
 local b={DisplayName="Bad"};t.Player1.Player=b
 local r=safe(M.inspect(table.pack(t,partner.Name),me,b))
 eq(r.reason,"ACTOR_CONTEXT_INVALID")
end)
test("nonstring DisplayName must not coerce or leak",function()
 local b={Name=partner.Name,DisplayName={secret=SECRET}}
 local t=tbl(true);t.Player1.Player=b
 local r=check(t,partner.Name,me,b)
 eq(r.stringMatchesPartnerDisplay,false)
 eq(r.stringClassification,"PARTNER_USERNAME_EXACT")
end)
print("Stage46 StartTrade tuple pure: "..passed.." passed, 0 failed")
