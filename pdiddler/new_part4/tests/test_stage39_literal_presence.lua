-- Stage39 actual Lua pure tests; synthetic payloads cannot establish MM2 field semantics.
local dir=arg[1] or "pdiddler/new_part4"
local M=assert(loadfile(dir.."/p4_stage39_literal_key_presence.lua"))()
local passed=0
local function test(name,fn)
 local ok,why=pcall(fn)
 if not ok then error(name..": "..tostring(why),0)end
 passed=passed+1
end
local C="Private_Batwing_Catalogue_Key"
local O="Private_Other_Weapon_Key"
local K={[C]=true,[O]=true}
local function safe(r)
 assert(type(r)=="table" and r.schema=="gingerscope-stage39-primitive-key-presence-v1")
 assert(r.literalEqualityOnly==true and r.readOnly==true)
 for _,k in ipairs({"rawIdAuthority","slotBindingAuthority","rawItemIdConfirmed",
 "rawKeyPresentConfirmed","ownerSideSlotBound","eventSessionAssociationProven",
 "exactWeaponIdentityConfirmed","serverCompletionProven","authorizesTrade",
 "authorizesAccept","mayRecordCompletedTrade","mayReportProfit"})do
  assert(r[k]==false,k.." promoted")
 end
 local function crawl(v,seen)
  if type(v)=="string" then
   assert(not v:find("Private_",1,true),"raw key/value escaped")
  elseif type(v)=="table" then
   seen=seen or {};assert(not seen[v],"output loop");seen[v]=true
   for k,x in pairs(v)do crawl(k,seen);crawl(x,seen)end;seen[v]=nil
  else assert(type(v)=="number" or type(v)=="boolean","non JSON export")end
 end
 crawl(r)
end
test("exact same-type string value",function()
 local r=M.inspect(table.pack({[1]=C,[2]=O},true),C,K)
 safe(r);assert(r.traversalComplete and r.candidateValueMatches==1 and r.otherCatalogueValueMatches==1)
 assert(r.candidateMapKeyMatches==0)
end)
test("same literal as table map key",function()
 local r=M.inspect(table.pack({[C]=true,[O]=false}),C,K)
 safe(r);assert(r.candidateMapKeyMatches==1 and r.otherCatalogueMapKeyMatches==1)
 assert(r.candidateValueMatches==0)
end)
test("deep array exact matches with anonymous structural positions",function()
 local r=M.inspect(table.pack({a={b={{C,C,3}}},other={}}),C,K)
 safe(r);assert(r.candidateValueMatches==2 and r.matchedCandidateByDepth[4]==2)
end)
test("negative control is present but Batwing candidate absent",function()
 local r=M.inspect(table.pack({a=O}),C,K)
 safe(r);assert(r.candidateValueMatches==0 and r.otherCatalogueValueMatches==1)
end)
test("a user-visible label is not a raw key",function()
 local r=M.inspect(table.pack({"Batwing","batwing"}),C,K)
 safe(r);assert(r.candidateValueMatches==0)
end)
test("opaque userdata counted without indexing or stringifying",function()
 local r=M.inspect(table.pack({a=io.stdout,b=io.stderr,c=C}),C,K)
 safe(r);assert(r.opaqueLeafCount==2 and r.traversalComplete)
 assert(r.candidateValueMatches==1 and r.status=="PRIMITIVE_LITERAL_COUNTS_UNBOUND")
end)
test("number and same digits string never conflated",function()
 local r=M.inspect(table.pack({"12345",12345}),12345,{[12345]=true})
 safe(r);assert(r.candidateValueMatches==1)
end)
test("nil argument holes and no extra keys",function()
 local r=M.inspect(table.pack(nil,{C},nil),C,K)
 safe(r);assert(r.candidateValueMatches==1)
end)
test("invalid packed args fail closed",function()
 for _,pack in ipairs({{}, {n=9}, {n=1,[2]=C}, {n=-1}})do
  local r=M.inspect(pack,C,K)
  safe(r);assert(not r.traversalComplete and r.status=="INCOMPLETE")
 end
end)
test("wrong candidate/source rejected",function()
 for _,cand in ipairs({"","Absent",{},math.huge})do
  local r=M.inspect(table.pack(C),cand,K)
  safe(r);assert(r.reason=="INVALID_INPUT")
 end
end)
test("cycle fail closed",function()
 local t={};t.self=t
 local r=M.inspect(table.pack(t),C,K)
 safe(r);assert(r.status=="INCOMPLETE" and r.reason=="CYCLE")
end)
test("cross-depth alias conservative",function()
 local deep={a=C};local t={x=deep,y={z=deep}}
 local r=M.inspect(table.pack(t),C,K)
 safe(r);assert(r.status=="INCOMPLETE" and r.reason=="ALIAS_DEPTH_UNVERIFIED")
end)
test("metatable cannot be traversed",function()
 local r=M.inspect(table.pack(setmetatable({a=C},{__index=function()error("called")end})),C,K)
 safe(r);assert(r.status=="INCOMPLETE" and r.reason=="METATABLE")
end)
test("too deep fails closed",function()
 local r=M.inspect(table.pack({{{{{C}}}}}),C,K)
 safe(r);assert(r.status=="INCOMPLETE" and r.reason=="DEPTH_LIMIT")
end)
test("entry limit fails closed",function()
 local t={};for i=1,150 do t["k"..i]=C end
 local r=M.inspect(table.pack(t),C,K)
 safe(r);assert(r.status=="INCOMPLETE" and r.reason=="ENTRY_LIMIT")
end)
test("table limit fails closed",function()
 local t={};for i=1,36 do t[i]={v=C}end
 local r=M.inspect(table.pack(t),C,K)
 safe(r);assert(r.status=="INCOMPLETE" and r.reason=="TABLE_LIMIT")
end)
test("untrusted opaque values never stringify",function()
 local r=M.inspect(table.pack({fn=function()error("should never call")end,t=coroutine.create(function()end)}),C,K)
 safe(r);assert(r.traversalComplete and r.opaqueLeafCount==2)
end)
print("Stage39 literal presence pure: "..passed.." passed, 0 failed")
