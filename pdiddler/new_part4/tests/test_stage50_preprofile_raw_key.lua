local dir=arg[1] or "pdiddler/new_part4"
local M=assert(loadfile(dir.."/p4_stage50_preprofile_raw_key.lua"))()
local SECRET="AccountProfileSecretNotToExport"
local raw="Private_Batwing_Raw_Key"
local bad="Private_Other_Raw_Key"
local flags={"rawOfferKeyBoundToPreprofile","offerKeyOriginVerified","checkerIdentityVerified",
 "uniqueWeaponInstanceProven","rawItemIdConfirmed","rawKeyPresentConfirmed",
 "ownerSideSlotBound","eventSessionAssociationProven","causalAttributionProven",
 "serverAttestation","serverCompletionProven","authorizesAccept","authorizesTrade",
 "mayRecordCompletedTrade","mayReportProfit"}
local passed=0
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b))end
local function check(r)
 eq(r.clientOnly,true);eq(r.readOnly,true);eq(r.tradeOutcome,"UNKNOWN")
 for _,f in ipairs(flags)do eq(r[f],false) end
 local function walk(v)
  if type(v)=="string"then
   for _,s in ipairs({SECRET,raw,bad,"Batwing"})do
    assert(not v:find(s,1,true),"raw key/profile leaked")end
  elseif type(v)=="table"then
   for k,x in pairs(v)do walk(k);walk(x)end
  end
 end
 walk(r);return r
end
local function test(name,fn)
 local ok,why=pcall(fn)
 if not ok then error(name..": "..tostring(why),0)end
 passed=passed+1
end
test("positive exact string key 1 copy is client only",function()
 local r=check(M.inspect({[raw]=1},raw))
 eq(r.status,"CLIENT_PREPROFILE_RAW_KEY_MATCH_UNAUTHENTICATED")
 eq(r.profileCandidateClientMatched,true)
 eq(r.rawOwnedExactKeyPresent,true)
 eq(r.rawOwnedMapComplete,true)
 eq(r.rawCandidateType,"STRING")
end)
test("positive string count supported only if strictly digits",function()
 local r=check(M.inspect({[raw]="3"},raw))
 eq(r.profileCandidateClientMatched,true)
end)
test("numeric raw key exact equals numeric Owned key",function()
 local r=check(M.inspect({[42]=2},42))
 eq(r.rawCandidateType,"NUMBER");eq(r.profileCandidateClientMatched,true)
end)
test("string and numeric matching PRINTABLE key are not identical",function()
 local r=check(M.inspect({[42]=2},"42"))
 eq(r.reason,"KEY_NOT_PRESENT_IN_PREPROFILE")
end)
test("numeric and string same spelling are rejected even if target one",function()
 local r=check(M.inspect({[42]=2,["42"]=2},"42"))
 eq(r.reason,"PROFILE_STRING_NUMERIC_KEY_COLLISION")
 eq(r.profileCandidateClientMatched,false)
end)
test("missing key not misidentified by display name",function()
 local r=check(M.inspect({[bad]=3},"Batwing"))
 eq(r.reason,"KEY_NOT_PRESENT_IN_PREPROFILE")
end)
test("present zero copies refuses",function()
 local r=check(M.inspect({[raw]=0},raw))
 eq(r.reason,"KEY_ZERO_PREPROFILE_COPIES")
end)
test("other held items do not affect candidate membership",function()
 local r=check(M.inspect({[raw]=1,[bad]=18,OtherCommon=12},raw))
 eq(r.profileCandidateClientMatched,true)
end)
test("malformed other item count rejects complete map",function()
 local r=check(M.inspect({[raw]=1,[bad]="NaN"},raw))
 eq(r.reason,"PROFILE_QUANTITY_INVALID")
end)
test("NaN count never passes",function()
 local r=check(M.inspect({[raw]=0/0},raw))
 eq(r.reason,"PROFILE_QUANTITY_INVALID")
end)
test("infinite count never passes",function()
 local r=check(M.inspect({[raw]=math.huge},raw))
 eq(r.reason,"PROFILE_QUANTITY_INVALID")
end)
test("negative count never passes",function()
 local r=check(M.inspect({[raw]=-1},raw))
 eq(r.reason,"PROFILE_QUANTITY_INVALID")
end)
test("fractional count never passes",function()
 local r=check(M.inspect({[raw]=1.5},raw))
 eq(r.reason,"PROFILE_QUANTITY_INVALID")
end)
test("boolean count never passes",function()
 local r=check(M.inspect({[raw]=true},raw))
 eq(r.reason,"PROFILE_QUANTITY_INVALID")
end)
test("mixed zero common item accepted if candidate held",function()
 local r=check(M.inspect({[raw]=1,Other=0},raw))
 eq(r.profileCandidateClientMatched,true)
end)
test("zero raw target count fails but map valid",function()
 local r=check(M.inspect({[raw]=0,Other=2},raw))
 eq(r.rawOwnedMapComplete,true);eq(r.profileCandidateClientMatched,false)
end)
test("unexpected table key rejects",function()
 local r=check(M.inspect({[raw]=1,[{}]=3},raw))
 eq(r.reason,"PROFILE_KEY_INVALID")
end)
test("metatable Owned refused without getter",function()
 local o=setmetatable({[raw]=1},{__index=function()error("do-not-invoke")end})
 eq(check(M.inspect(o,raw)).reason,"PROFILE_OWNED_NOT_PLAIN_TABLE")
end)
test("unsupported key rejected early",function()
 local r=check(M.inspect({[raw]=1},{}))
 eq(r.reason,"KEY_TYPE_UNSUPPORTED")
end)
test("unsupported empty string raw key refused",function()
 eq(check(M.inspect({[raw]=1},"")).reason,"KEY_TYPE_UNSUPPORTED")
end)
test("overlong raw key refused without raw export",function()
 eq(check(M.inspect({[raw]=1},string.rep("Z",257))).reason,"KEY_TYPE_UNSUPPORTED")
end)
test("nil profile rejected",function()
 eq(check(M.inspect(nil,raw)).reason,"PROFILE_OWNED_NOT_PLAIN_TABLE")
end)
test("empty owned map not a positive result",function()
 eq(check(M.inspect({},raw)).reason,"KEY_NOT_PRESENT_IN_PREPROFILE")
end)
test("sparse/extra raw owned keys scan remains bounded",function()
 local o={[raw]=1}
 for i=1,2501 do o["K_"..i]=1 end
 eq(check(M.inspect(o,raw)).reason,"PROFILE_OWNED_OVERSIZE")
end)
test("total > 1 million refuses",function()
 local o={[raw]=1,[bad]=1000000}
 eq(check(M.inspect(o,raw)).reason,"PROFILE_QUANTITY_TOTAL_EXCESS")
end)
test("read-copy of pre profile not frozen requires no mutation assumption",function()
 local o={[raw]=1}
 local r1=check(M.inspect(o,raw))
 o[raw]=nil
 local r2=check(M.inspect(o,raw))
 eq(r1.profileCandidateClientMatched,true)
 eq(r2.profileCandidateClientMatched,false)
end)
print("Stage50 preprofile raw key pure: "..passed.." passed, 0 failed")
