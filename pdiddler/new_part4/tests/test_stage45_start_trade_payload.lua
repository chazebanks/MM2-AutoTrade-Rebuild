local dir=arg[1] or "pdiddler/new_part4"
local M=assert(loadfile(dir.."/p4_stage45_start_trade_payload.lua"))()
local me,partner,foreign={}, {}, {}
local SECRET="SecretSessionValue_MUST_NOT_LEAK"
local passed=0
local function eq(a,b,msg) assert(a==b,(msg or "value")..": "..tostring(a).." != "..tostring(b)) end
local function test(name,fn)
 local ok,err=pcall(fn)
 if not ok then error(name..": "..tostring(err),0) end
 passed=passed+1
end
local authority={"hasAuthenticatedSessionIdentifier","sessionIdProven",
 "eventSessionAssociationProven","causalAttributionProven","serverAttestation",
 "serverCompletionProven","ownerSideSlotBound","rawItemIdConfirmed",
 "authorizesTrade","authorizesAccept","mayRecordCompletedTrade","mayReportProfit"}
local function safe(r)
 eq(r.readOnly,true);eq(r.tradeOutcome,"UNKNOWN")
 for _,k in ipairs(authority) do eq(r[k],false,"authority "..k) end
 local function scan(v)
  if type(v)=="string" then assert(not v:find(SECRET,1,true),"secret escaped")
  elseif type(v)=="table" then for k,x in pairs(v) do scan(k);scan(x) end end
 end
 scan(r);return r
end
local function inspect(...) return safe(M.inspect(table.pack(...),me,partner)) end
test("no args are measurable but not session proof",function()
 local r=inspect();eq(r.argumentCount,0);eq(r.reason,"NONE")
 eq(r.directPrimitiveCandidateCount,0)
end)
test("single partner reference",function()
 local r=inspect(partner);eq(r.argumentTypes[1],"PARTNER_PLAYER_REF")
 eq(r.partnerPlayerReferenceCount,1);eq(r.playerPairReferencesObserved,false)
end)
test("both player references in either order",function()
 local r=inspect(partner,me);eq(r.playerPairReferencesObserved,true)
 eq(r.argumentTypes[1],"PARTNER_PLAYER_REF");eq(r.argumentTypes[2],"LOCAL_PLAYER_REF")
end)
test("same player twice cannot count as pair",function()
 local r=inspect(me,me);eq(r.playerPairReferencesObserved,false)
end)
test("unclassified string never exported",function()
 local r=inspect(SECRET);eq(r.argumentTypes[1],"STRING")
 eq(r.unclassifiedStringCount,1);eq(r.directPrimitiveCandidateCount,1)
end)
test("unclassified number is not authenticated id",function()
 local r=inspect(123456);eq(r.unclassifiedNumberCount,1)
 eq(r.hasAuthenticatedSessionIdentifier,false)
end)
test("foreign reference is not bound partner",function()
 local r=inspect(foreign);eq(r.argumentTypes[1],"TABLE")
 eq(r.partnerPlayerReferenceCount,0)
end)
test("booleans, tables, nil holes classified",function()
 local r=safe(M.inspect({n=4,[1]=true,[2]={secret=SECRET},[4]=false},me,partner))
 eq(r.argumentTypes[1],"BOOLEAN");eq(r.argumentTypes[2],"TABLE")
 eq(r.argumentTypes[3],"NIL");eq(r.argumentTypes[4],"BOOLEAN")
end)
test("no recursive table read or metatable invocation",function()
 local v=setmetatable({}, {__index=function()error("UNSAFE TABLE GET")end})
 local r=inspect(v);eq(r.argumentTypes[1],"TABLE")
end)
test("invalid argument array field rejects",function()
 local r=safe(M.inspect({n=1,[1]=partner,hack=SECRET},me,partner))
 eq(r.reason,"ARGUMENT_PACK_INVALID")
end)
test("argument count limit rejects",function()
 local r=safe(M.inspect({n=7},me,partner));eq(r.reason,"ARGUMENT_COUNT_UNSUPPORTED")
end)
test("bad negative n rejects",function()
 local r=safe(M.inspect({n=-1},me,partner));eq(r.reason,"ARGUMENT_COUNT_UNSUPPORTED")
end)
test("metatable pack rejects",function()
 local a=setmetatable({n=1,[1]=partner},{__index=function()error("NO")end})
 local r=safe(M.inspect(a,me,partner));eq(r.reason,"ARGUMENT_PACK_INVALID")
end)
test("same actor context rejects",function()
 local r=safe(M.inspect(table.pack(),me,me));eq(r.reason,"ACTOR_CONTEXT_INVALID")
end)
test("nil actor rejects",function()
 local r=safe(M.inspect(table.pack(partner),me,nil));eq(r.reason,"ACTOR_CONTEXT_INVALID")
end)
test("non-finite numeric payload refuses",function()
 local r=safe(M.inspect(table.pack(math.huge),me,partner))
 eq(r.reason,"NONFINITE_NUMBER")
end)
test("candidate primitives do not permit trade",function()
 local r=inspect(SECRET,8675309,me,partner,false)
 eq(r.directPrimitiveCandidateCount,2)
 eq(r.playerPairReferencesObserved,true)
 eq(r.sessionIdProven,false)
end)
print("Stage45 StartTrade client argument types pure: "..passed.." passed, 0 failed")
