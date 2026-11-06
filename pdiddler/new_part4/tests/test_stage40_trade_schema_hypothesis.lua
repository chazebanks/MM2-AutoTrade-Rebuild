local dir=arg[1] or "pdiddler/new_part4"
local M=assert(loadfile(dir.."/p4_stage40_trade_schema_hypothesis.lua"))()
local passed=0
local KEY="PrivateKey-DoNotExport"
local LOCAL,OTHER={},{}
local function test(name,fn)
 local ok,e=pcall(fn)
 if not ok then error(name..": "..tostring(e),0)end
 passed=passed+1
end
local function tableFor(key,me,p)
 return {LastOffer=1760000000,Locked=false,
  Player1={Player=me,Accepted=false,Offer={{key,1,"Weapons"}}},
  Player2={Player=p,Accepted=false,Offer={}}}
end
local function safe(r)
 for _,k in ipairs({"wholeEventSchemaAuthenticated","rawItemIdConfirmed",
 "rawKeyPresentConfirmed","ownerSideSlotBound","eventSessionAssociationProven",
 "serverCompletionProven","exactWeaponIdentityConfirmed","causalAttributionProven",
 "authorizesTrade","authorizesAccept","mayRecordCompletedTrade","mayReportProfit"})do
  assert(r[k]==false,"authority promoted "..k)
 end
 assert(r.hypothesisOnly and r.readOnly and r.tradeOutcome=="UNKNOWN")
 local function clean(v)
  if type(v)=="string" then
   assert(not v:find(KEY,1,true),"secret key escaped")
  elseif type(v)=="table" then for k,x in pairs(v) do clean(k);clean(x)end end
 end
 clean(r)
end
local function inspect(t,key,label,me,partner)
 local r=M.inspect(table.pack(t),key or KEY,label or "Batwing",me or LOCAL,partner or OTHER)
 safe(r);return r
end
test("exact anonymous candidate structure matches one-side raw key + 2 player object identities",function()
 local r=inspect(tableFor(KEY,LOCAL,OTHER))
 assert(r.hypothesisMatched and r.player1ObjectEqualsLocal and r.player2ObjectEqualsPartner)
 assert(r.tripletKeyEqualsCatalogue and r.tripletQuantityIsOne and r.tripletCategoryIsWeapons)
 assert(r.player1OfferHasOneRow and r.player2OfferEmpty)
end)
test("same key as displayed label is disclosed only as boolean, never treated as authentication",function()
 local r=inspect(tableFor("Batwing",LOCAL,OTHER),"Batwing","Batwing")
 assert(r.candidateKeyEqualsVisibleLabel and r.hypothesisMatched)
 assert(not r.rawItemIdConfirmed)
end)
test("opposite-side offer rejects own-side hypothesis",function()
 local t=tableFor(KEY,LOCAL,OTHER)
 t.Player2.Offer=t.Player1.Offer;t.Player1.Offer={}
 local r=inspect(t);assert(not r.hypothesisMatched)
end)
test("reversed owner objects reject hypothesis",function()
 local r=inspect(tableFor(KEY,OTHER,LOCAL))
 assert(not r.hypothesisMatched and not r.player1ObjectEqualsLocal and not r.player2ObjectEqualsPartner)
end)
test("wrong item key rejects",function()
 local r=inspect(tableFor("OtherKey",LOCAL,OTHER))
 assert(not r.hypothesisMatched and not r.tripletKeyEqualsCatalogue)
end)
test("wrong quantity rejects",function()
 local t=tableFor(KEY,LOCAL,OTHER);t.Player1.Offer[1][2]=2
 local r=inspect(t);assert(not r.hypothesisMatched and not r.tripletQuantityIsOne)
end)
test("wrong category rejects",function()
 local t=tableFor(KEY,LOCAL,OTHER);t.Player1.Offer[1][3]="Pets"
 local r=inspect(t);assert(not r.hypothesisMatched)
end)
test("accepted trade is not eligible even if other structure fits",function()
 local t=tableFor(KEY,LOCAL,OTHER);t.Player1.Accepted=true
 local r=inspect(t);assert(not r.hypothesisMatched)
end)
test("unknown extra top-level field rejects rather than guessing",function()
 local t=tableFor(KEY,LOCAL,OTHER);t.Other=123
 local r=inspect(t);assert(not r.hypothesisMatched)
end)
test("unknown extra side-level field rejects",function()
 local t=tableFor(KEY,LOCAL,OTHER);t.Player1.Test=true
 local r=inspect(t);assert(not r.hypothesisMatched)
end)
test("unexpected extra offer row rejects",function()
 local t=tableFor(KEY,LOCAL,OTHER);t.Player1.Offer[2]={KEY,1,"Weapons"}
 local r=inspect(t);assert(not r.hypothesisMatched)
end)
test("unexpected triplet fourth element rejects",function()
 local t=tableFor(KEY,LOCAL,OTHER);t.Player1.Offer[1][4]=true
 local r=inspect(t);assert(not r.hypothesisMatched)
end)
test("metatables rejected, no metamethod executes",function()
 local t=tableFor(KEY,LOCAL,OTHER)
 setmetatable(t.Player1.Offer[1],{__index=function()error("should not run")end})
 local r=inspect(t);assert(not r.hypothesisMatched)
end)
test("nonfinite number rejects",function()
 local t=tableFor(KEY,LOCAL,OTHER);t.LastOffer=math.huge
 local r=inspect(t);assert(not r.hypothesisMatched)
end)
test("invalid packed input and missing context reject",function()
 local t=tableFor(KEY,LOCAL,OTHER)
 for _,args in ipairs({{}, {n=2,[1]=t}, {n=1,[1]=t,[2]=t}})do
  local r=M.inspect(args,KEY,"Batwing",LOCAL,OTHER)
  safe(r)
  if args.n~=1 then assert(not r.hypothesisMatched)end
 end
 local r=M.inspect(table.pack(t),KEY,"Batwing",nil,OTHER);safe(r);assert(not r.hypothesisMatched)
end)
print("Stage40 candidate schema pure: "..passed.." passed, 0 failed")
