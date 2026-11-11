-- Stage80 real Lua5.4 offline regression. Aggregate-only, 400 seeded mutations.
local M=dofile("pdiddler/intelligence_lab/stage80_owned_metadata_reason.lua")
local groups=0
local function test(name,fn)
 local ok,why=pcall(fn)
 if not ok then error("FAIL "..name.." "..tostring(why)) end
 groups=groups+1
 print("PASS "..name)
end
local function sample()
 local o,c={},{}
 -- Recreate Stage79 aggregate counts WITHOUT implying exact owned identities.
 -- 69 eligible keys, 76 copies; four Chroma copies.
 for i=1,69 do
  local k="Eligible"..i;local q=i<=7 and 2 or 1
  o[k]=q;c[k]={ItemName="Public Eligible "..i,ItemType=i%2==0 and "Gun" or "Knife",
    Rarity=i<=10 and "Ancient" or "Godly",Chroma=i>=11 and i<=14}
 end
 -- 113 common weapon keys, 380 copies.
 for i=1,113 do
  local k="Common"..i;o[k]=i<=41 and 4 or 3
  c[k]={ItemName="Common "..i,ItemType="Knife",Rarity="Common"}
 end
 -- One WELL-FORMED non-weapon entry in a table called Weapons.
 o["MiscExample"]=1
 c["MiscExample"]={ItemName="A key item",ItemType="Misc",Rarity="Common"}
 return o,c
end
local function safety(r)
 for _,k in ipairs({"readOnly","clientOnly"}) do assert(r[k]==true,k) end
 for _,k in ipairs({
  "serverAttestation","authenticatedOwnedInventory","currentPricesVerified",
  "numericSupremeCheckerIdVerified","serverCompletionProven","authorizesTrade",
  "authorizesAccept","mayRecordCompletedTrade","mayRecordRejectedTrade",
  "mayReportProfit","maySendDiscordWebhook","mayUseForStrategyLearning"
 }) do assert(r[k]==false,k) end
 assert(r.tradeOutcome=="UNKNOWN")
 for k,v in pairs(r) do
  assert(not tostring(k):find("MiscExample",1,true))
  assert(not tostring(v):find("MiscExample",1,true))
 end
end
test("183 original string keys 457 copies one well formed Misc",function()
 local o,c=sample();local r=M.audit(o,c)
 assert(r.status=="CLIENT_MISC_EXCLUDED_FROM_WEAPON_CATEGORY_ONLY",r.status)
 assert(r.ownedKeys==183 and r.ownedCopies==457)
 assert(r.weaponKeys==182 and r.miscKeys==1 and r.miscCopies==1)
 assert(r.eligibleWeaponKeys==69 and r.eligibleWeaponCopies==76)
 assert(r.chromaEligibleCopies==4 and r.numericKeyCount==0)
 safety(r)
end)
test("only standard weapon keys receives separate client label",function()
 local o,c=sample();o.MiscExample=nil;c.MiscExample=nil
 local r=M.audit(o,c)
 assert(r.status=="CLIENT_WEAPON_CATEGORY_METADATA_CONSISTENT_ONLY")
 assert(r.miscKeys==0 and r.weaponKeys==182)
 safety(r)
end)
test("unknown missing name versus legitimate Misc",function()
 local o,c=sample();c.MiscExample.ItemName=nil
 local r=M.audit(o,c)
 assert(r.status=="INCONCLUSIVE" and r.missingNameKeys==1 and r.miscKeys==0)
 safety(r)
end)
test("unknown missing type versus legitimate Misc",function()
 local o,c=sample();c.MiscExample.ItemType=nil
 local r=M.audit(o,c)
 assert(r.status=="INCONCLUSIVE" and r.missingTypeKeys==1 and r.miscKeys==0)
 safety(r)
end)
test("unknown missing rarity versus legitimate Misc",function()
 local o,c=sample();c.MiscExample.Rarity=nil
 local r=M.audit(o,c)
 assert(r.status=="INCONCLUSIVE" and r.missingRarityKeys==1)
 safety(r)
end)
test("unknown category is not silently skipped",function()
 local o,c=sample();c.MiscExample.ItemType="Pet"
 local r=M.audit(o,c)
 assert(r.status=="INCONCLUSIVE" and r.unknownItemTypeKeys==1)
 safety(r)
end)
test("Chroma on Misc not accepted as ordinary nonweapon",function()
 local o,c=sample();c.MiscExample.Chroma=true
 local r=M.audit(o,c)
 assert(r.status=="INCONCLUSIVE" and r.chromaRarityConflictKeys==1)
 safety(r)
end)
test("malformed Chroma type on eligible weapon excluded",function()
 local o,c=sample();c.Eligible11.Chroma="true"
 local r=M.audit(o,c)
 assert(r.status=="INCONCLUSIVE" and r.invalidChromaTypeKeys==1)
 safety(r)
end)
test("numeric and string key types are not coerced",function()
 local o,c=sample();o[42]=1;c["42"]={ItemName="Synthetic",ItemType="Knife",Rarity="Godly"}
 local r=M.audit(o,c)
 assert(r.status=="INCONCLUSIVE" and r.numericKeyCount==1)
 assert(r.stringKeyCount==183 and r.weaponKeys==182)
 safety(r)
end)
test("unmatched own key reports aggregate only",function()
 local o,c=sample();c.Common1=nil
 local r=M.audit(o,c)
 assert(r.status=="INCONCLUSIVE" and r.missingCatalogueKeys==1)
 safety(r)
end)
test("malformed qty and metatable fail closed",function()
 local o,c=sample();o.Common1="2"
 local r=M.audit(o,c)
 assert(r.status=="INCONCLUSIVE" and r.invalidQuantityKeys==1)
 safety(r)
 o,c=sample();c.MiscExample=setmetatable(c.MiscExample,{})
 r=M.audit(o,c)
 assert(r.status=="INCONCLUSIVE" and r.untrustedMetadataKeys==1)
 safety(r)
end)
test("empty map and invalid top level do not authorize",function()
 local r=M.audit({},{});assert(r.status=="INCONCLUSIVE")
 safety(r)
 r=M.audit(setmetatable({},{}),{});assert(r.status=="INCONCLUSIVE")
 safety(r)
end)
test("same artwork ItemID does not collapse category",function()
 local o,c=sample();c.MiscExample.ItemID=42;c.Eligible10.ItemID=42
 local r=M.audit(o,c)
 assert(r.status=="CLIENT_MISC_EXCLUDED_FROM_WEAPON_CATEGORY_ONLY")
 assert(r.miscKeys==1 and r.weaponKeys==182)
 safety(r)
end)
test("400 deterministic corruptions always inconclusive",function()
 math.randomseed(80)
 for i=1,400 do
  local o,c=sample()
  local j=i%8
  if j==0 then c.MiscExample.ItemType="Unknown"
  elseif j==1 then c.MiscExample.ItemName=nil
  elseif j==2 then c.MiscExample.Rarity=nil
  elseif j==3 then c.Eligible11.Chroma="true"
  elseif j==4 then o[math.random(42,12000)]=1
  elseif j==5 then c.Common50=nil
  elseif j==6 then o.Eligible1=1.5
  else c.MiscExample.Chroma=true end
  local r=M.audit(o,c)
  assert(r.status=="INCONCLUSIVE","case "..i.." unexpectedly passed")
  safety(r)
 end
end)
print("STAGE80_PURE_LUA_PASS groups="..groups.." corruptions=400")
