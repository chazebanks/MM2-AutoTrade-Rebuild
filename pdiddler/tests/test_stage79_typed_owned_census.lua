-- Stage79 actual Lua5.4 offline adversarial test runner.
local M=dofile("pdiddler/intelligence_lab/stage79_typed_owned_census.lua")
local count=0
local function test(name,fn)
 local ok,err=pcall(fn)
 if not ok then error("FAIL "..name.." "..tostring(err)) end
 count=count+1
 print("PASS "..name)
end
local function cat()
 return {
  Gingerscope={ItemName="Gingerscope",ItemType="Gun",Rarity="Ancient"},
  EmberscytheChroma={ItemName="Emberscythe",ItemType="Knife",Rarity="Ancient",Chroma=true},
  Common={ItemName="Common",ItemType="Knife",Rarity="Common"},
  ["42"]={ItemName="Synthetic42",ItemType="Gun",Rarity="Godly"}
 }
end
local function own()
 return {Gingerscope=1,EmberscytheChroma=2,Common=3}
end
local function safe(r)
 assert(r.readOnly==true and r.clientOnly==true)
 for _,field in ipairs({
  "authenticatedOwnedInventory","serverAttestation","serverCompletionProven",
  "rawToSupremeCheckerVerified","sourcePublisherFresh","currentPricesVerified",
  "mayReportProfit","mayRecordCompletedTrade","mayRecordRejectedTrade",
  "maySendDiscordWebhook","mayUseForStrategyLearning","authorizesTrade",
  "authorizesAccept"
 }) do assert(r[field]==false,field) end
 assert(r.tradeOutcome=="UNKNOWN")
 for k,v in pairs(r) do
  assert(tostring(k):find("Gingerscope",1,true)==nil)
  assert(tostring(v):find("Gingerscope",1,true)==nil)
 end
end
local function fail(o,c,reason)
 local r=M.audit(o,c)
 assert(r.status=="INCONCLUSIVE",r.status)
 if reason then assert(r.reason==reason,r.reason) end
 assert(r.directCatalogueJoinObserved==false)
 safe(r)
 return r
end
test("full three-key typed join and Ancient Chroma",function()
 local r=M.audit(own(),cat())
 assert(r.status=="CLIENT_TYPED_OWNED_DIRECT_CATALOGUE_MATCH_ONLY")
 assert(r.originalOwnedKeyTypesObserved==true and r.directCatalogueJoinObserved==true)
 assert(r.ownedKeyCount==3 and r.positiveCopyCount==6)
 assert(r.stringKeyCount==3 and r.numericKeyCount==0)
 assert(r.directCatalogueKeyCount==3 and r.eligibleCopies==3 and r.chromaEligibleCopies==2)
 safe(r)
end)
test("numeric keys remain typed and unverified",function()
 local r=fail({[42]=1},cat())
 assert(r.numericKeyCount==1 and r.stringKeyCount==0 and r.directCatalogueKeyCount==0)
end)
test("actual legacy tostring collision counted without key export",function()
 local r=fail({[42]=1,["42"]=1},cat())
 assert(r.coercionCollisionPairs==1 and r.numericKeyCount==1)
 assert(r.stringKeyCount==1 and r.directCatalogueKeyCount==1)
end)
test("non-string table-key types fail closed",function()
 local t={}
 local r=fail({[t]=1},cat())
 assert(r.otherKeyCount==1 and r.directCatalogueKeyCount==0)
end)
test("bad numeric and text quantities",function()
 for _,v in ipairs({0,-1,1.5,"2",math.huge}) do
  local r=fail({Gingerscope=v},cat())
  assert(r.invalidQuantityCount==1)
 end
 fail({Gingerscope=0/0},cat())
end)
test("catalogue absence not repaired by fuzzy display alias",function()
 local c=cat(); c.Gingerscope=nil
 local r=fail({Gingerscope=1},c)
 assert(r.unmatchedStringKeyCount==1)
end)
test("wrong rarity or Chroma types fail appropriately",function()
 local c=cat();c.EmberscytheChroma.Chroma="true"
 local r=fail(own(),c)
 assert(r.malformedCatalogueEntryCount==1)
 c=cat();c.EmberscytheChroma.Rarity="Common"
 r=fail(own(),c)
 assert(r.malformedCatalogueEntryCount==1)
end)
test("metatable injection is blocked",function()
 fail(setmetatable(own(),{}),cat(),"SOURCE_TABLE_UNAVAILABLE")
 local c=cat();c.Gingerscope=setmetatable(c.Gingerscope,{})
 local r=fail(own(),c)
 assert(r.malformedCatalogueEntryCount==1)
end)
test("unsupported item type and invalid metadata",function()
 local c=cat();c.Gingerscope.ItemType="Pet"
 local r=fail(own(),c)
 assert(r.malformedCatalogueEntryCount==1)
 c=cat();c.Gingerscope.ItemName=""
 r=fail(own(),c)
 assert(r.malformedCatalogueEntryCount==1)
end)
test("empty Owned map returns no proof",function()
 local r=fail({},cat(),"EMPTY_OWNED_TABLE_UNINFORMATIVE")
 assert(r.originalOwnedKeyTypesObserved==true)
end)
test("unsupported key character never appears in output",function()
 local c=cat();c["UNSAFE\nRAW"]={ItemName="Name",ItemType="Gun",Rarity="Godly"}
 local r=fail({["UNSAFE\nRAW"]=1},c)
 assert(r.directCatalogueKeyCount==0)
 for _,v in pairs(r) do assert(not tostring(v):find("UNSAFE",1,true)) end
end)
test("art ItemID overlap cannot merge distinct keys",function()
 local c=cat()
 c.Gingerscope.ItemID=12345;c.EmberscytheChroma.ItemID=12345
 local r=M.audit(own(),c)
 assert(r.status=="CLIENT_TYPED_OWNED_DIRECT_CATALOGUE_MATCH_ONLY")
 assert(r.eligibleKeyCount==2 and r.directCatalogueKeyCount==3)
 safe(r)
end)
test("caller supplied authority fields are ignored",function()
 local c=cat();c.Gingerscope.verified=true;c.Gingerscope.checkerId=771
 c.Gingerscope.serverAttestation=true;c.Gingerscope.priceFresh=true
 local r=M.audit(own(),c)
 assert(r.status=="CLIENT_TYPED_OWNED_DIRECT_CATALOGUE_MATCH_ONLY")
 safe(r)
end)
test("owned key/copy limits are bounded",function()
 local r=fail({Gingerscope=1000001},cat())
 assert(r.reason=="OWNED_TYPE_QUANTITY_OR_CATALOGUE_DISCREPANCY")
 local c=cat()
 local o={Gingerscope=999999,Common=2}
 r=fail(o,c,"OWNED_COPY_LIMIT_EXCEEDED")
 safe(r)
end)
test("400 deterministic negative cases are rejected",function()
 math.randomseed(79)
 for i=1,400 do
  local c=cat();local o=own()
  local j=i%7
  if j==0 then o[math.random(100,999)]=1
  elseif j==1 then o.Gingerscope=math.random(0,30)+0.3
  elseif j==2 then c.Gingerscope.ItemName=""
  elseif j==3 then o.Unrecognized=1
  elseif j==4 then c.EmberscytheChroma.Chroma=1
  elseif j==5 then o.Common="2"
  else c.Common=nil end
  local r=M.audit(o,c)
  assert(r.status=="INCONCLUSIVE","mutation "..i.." unexpectedly passed")
  safe(r)
 end
end)
print("STAGE79_PURE_LUA_PASS groups="..count.." corruptions=400")
