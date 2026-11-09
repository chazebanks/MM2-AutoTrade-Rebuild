-- Stage83 actual Lua5.4 offline public registry + private aggregate coverage tests.
-- All Owned inputs here are synthetic, never the real user's inventory.
local M=dofile("pdiddler/intelligence_lab/stage83_private_aggregate_coverage.lua")
local REG=dofile("pdiddler/intelligence_lab/stage83_public_slug_registry.lua")
local groups=0
local function group(name,fn)
 local ok,err=pcall(fn)
 if not ok then error("FAIL "..name.." "..tostring(err)) end
 groups=groups+1;print("PASS "..name)
end
local function clone(src)
 local v={}
 for k,x in pairs(src) do
  if type(x)=="table" then v[k]=clone(x) else v[k]=x end
 end
 return v
end
local function meta(raw)
 local x=assert(REG.entries[raw],"missing source fixture "..tostring(raw))
 return {ItemName=x[1],ItemType=x[2],Rarity=x[3],Chroma=x[4]}
end
local function fixtures()
 local own={
  Gingerscope=1,EmberscytheChroma=2,BattleAxe2=1,
  CommonExample=3,MiscExample=1,FreshNeverPriced=2
 }
 local cat={
  Gingerscope=meta("Gingerscope"),
  EmberscytheChroma=meta("EmberscytheChroma"),
  BattleAxe2=meta("BattleAxe2"),
  CommonExample={ItemName="Synthetic common",ItemType="Knife",Rarity="Common"},
  MiscExample={ItemName="Synthetic miscellaneous",ItemType="Misc",Rarity="Common"},
  FreshNeverPriced={ItemName="Synthetic new item",ItemType="Gun",Rarity="Godly"},
 }
 return own,cat
end
local function safety(r)
 assert(r.readOnly==true and r.clientOnly==true)
 assert(r.sourcePublisherFresh==false and r.currentPricesVerified==false)
 assert(r.authenticatedOwnedInventory==false and r.serverAttestation==false)
 assert(r.numericSupremeCheckerIdVerified==false)
 assert(r.currentOwnedRawToMarketSlugVerified==false)
 assert(r.authorizesTrade==false and r.authorizesAccept==false)
 assert(r.mayReportProfit==false and r.mayRecordCompletedTrade==false)
 assert(r.mayRecordRejectedTrade==false and r.mayUseForStrategyLearning==false)
 assert(r.maySendDiscordWebhook==false and r.tradeOutcome=="UNKNOWN")
 for k,v in pairs(r) do
  for _,private in ipairs({"FreshNeverPriced","EmberscytheChroma","MiscExample"}) do
   assert(not tostring(k):find(private,1,true))
   assert(not tostring(v):find(private,1,true))
  end
 end
end
local function fail(owned,cat,registry)
 local r=M.audit(owned,cat,registry or REG)
 assert(r.status=="INCONCLUSIVE","unexpected pass "..r.status)
 safety(r)
 return r
end
group("real 189-entry pinned public-only registry",function()
 local n,pages=0,{}
 assert(REG.schema=="gingerscope-stage83-public-slug-registry-v1")
 assert(REG.publisherExpiryUtc=="2026-11-09T15:56:07Z")
 assert(REG.currentPricesVerified==false)
 for _,d in pairs(REG.entries) do
  n=n+1
  pages[d[5]]=(pages[d[5]] or 0)+1
 end
 assert(n==189 and pages.ancient==15 and pages.godly==128 and pages.chroma==46)
end)
group("positive source coverage and unknown/new public name isolation",function()
 local own,cat=fixtures()
 local r=M.audit(own,cat,REG)
 assert(r.status=="CLIENT_HISTORICAL_PUBLIC_REFERENCE_COVERAGE_ONLY",r.reason)
 assert(r.historicalPublicRegistryEntries==189)
 assert(r.ownedKeys==6 and r.ownedCopies==10)
 assert(r.stringOwnedKeys==6 and r.numericOwnedKeys==0)
 assert(r.clientWeaponKeys==5 and r.clientWeaponCopies==9)
 assert(r.miscKeys==1 and r.miscCopies==1)
 assert(r.eligibleKeys==4 and r.eligibleCopies==6)
 assert(r.eligibleChromaCopies==2)
 assert(r.historicalReferenceEligibleKeys==3 and r.historicalReferenceEligibleCopies==4)
 assert(r.historicalUnmappedEligibleKeys==1 and r.historicalUnmappedEligibleCopies==2)
 assert(r.historicalVariantDriftEligibleKeys==0 and r.historicalVariantDriftEligibleCopies==0)
 safety(r)
end)
group("public catalogue Chroma Ancient is not forced to Godly",function()
 local own,cat=fixtures()
 local r=M.audit(own,cat,REG)
 assert(r.historicalReferenceEligibleKeys==3)
 assert(meta("EmberscytheChroma").Rarity=="Ancient")
 safety(r)
end)
group("game ItemName drift does not silently match site slug",function()
 local own,cat=fixtures();cat.Gingerscope.ItemName="GingerscopeFuzzy"
 local r=M.audit(own,cat,REG)
 assert(r.status=="CLIENT_HISTORICAL_PUBLIC_REFERENCE_COVERAGE_ONLY")
 assert(r.historicalVariantDriftEligibleKeys==1)
 assert(r.historicalReferenceEligibleKeys==2)
 safety(r)
end)
group("chroma marker drift is explicitly counted",function()
 local own,cat=fixtures();cat.EmberscytheChroma.Chroma=false
 local r=M.audit(own,cat,REG)
 assert(r.historicalVariantDriftEligibleKeys==1)
 assert(r.historicalReferenceEligibleCopies==2)
 safety(r)
end)
group("rarity drift and same art ItemID cannot create identity",function()
 local own,cat=fixtures();cat.Gingerscope.Rarity="Godly"
 cat.Gingerscope.ItemID=123;cat.BattleAxe2.ItemID=123
 local r=M.audit(own,cat,REG)
 assert(r.historicalVariantDriftEligibleKeys==1)
 safety(r)
end)
group("numeric and string Owned keys never coerce into one identity",function()
 local own,cat=fixtures()
 own[42]=1;cat["42"]=meta("Gingerscope")
 local r=fail(own,cat)
 assert(r.numericOwnedKeys==1 and r.stringOwnedKeys==6)
end)
group("malformed quantities cannot pass",function()
 for _,q in ipairs({0,-1,1.25,"2",math.huge}) do
  local own,cat=fixtures();own.Gingerscope=q
  local r=fail(own,cat)
  assert(r.invalidQuantities==1)
 end
end)
group("missing metadata and unknown category fail closed",function()
 local own,cat=fixtures();cat.Gingerscope=nil
 local r=fail(own,cat);assert(r.unmappedClientKeys==1)
 own,cat=fixtures();cat.MiscExample.ItemType="Pet"
 r=fail(own,cat);assert(r.unsupportedClientCategoryKeys==1)
 own,cat=fixtures();cat.Gingerscope.Chroma="true"
 r=fail(own,cat);assert(r.untrustedMetadataKeys==1)
end)
group("table metatables blocked and zero-owner is inconclusive",function()
 local own,cat=fixtures()
 fail(setmetatable(own,{}),cat)
 own,cat=fixtures()
 cat.Gingerscope=setmetatable(cat.Gingerscope,{})
 fail(own,cat)
 fail({},cat)
end)
group("tampered registry size, slugs and source authority rejected",function()
 local own,cat=fixtures()
 local r=clone(REG);r.entries.Gingerscope=nil
 fail(own,cat,r)
 r=clone(REG);r.entries.Gingerscope[6]="Other&slug"
 fail(own,cat,r)
 r=clone(REG);r.sourcePublisherFresh=true
 local out=M.audit(own,cat,r)
 assert(out.currentPricesVerified==false and out.authorizesTrade==false)
 safety(out)
end)
group("forged source value and market ID never transmitted",function()
 local own,cat=fixtures()
 cat.Gingerscope.checkerId="771"
 cat.Gingerscope.supremeValue=16000
 cat.Gingerscope.verified=true
 local r=M.audit(own,cat,REG)
 assert(r.status=="CLIENT_HISTORICAL_PUBLIC_REFERENCE_COVERAGE_ONLY")
 assert(r.currentPricesVerified==false)
 for k,v in pairs(r) do
  assert(not tostring(k):find("checkerId",1,true))
  assert(not tostring(v):find("16000",1,true))
 end
 safety(r)
end)
group("one legitimate Misc under Weapons.Owned not malformed",function()
 local own,cat=fixtures()
 local r=M.audit(own,cat,REG)
 assert(r.miscKeys==1 and r.untrustedMetadataKeys==0)
 assert(r.clientWeaponKeys+r.miscKeys==r.ownedKeys)
 safety(r)
end)
group("400 deterministic corruptions rejected, including original key types",function()
 math.randomseed(83)
 for i=1,400 do
  local own,cat=fixtures()
  local j=i%8
  if j==0 then own[math.random(50,9000)]=1
  elseif j==1 then own.Gingerscope="2"
  elseif j==2 then cat.Gingerscope.ItemName=""
  elseif j==3 then cat.Gingerscope.Chroma="false"
  elseif j==4 then cat.MiscExample.ItemType="Pet"
  elseif j==5 then cat.FreshNeverPriced=nil
  elseif j==6 then own.CommonExample=1.5
  else cat.BattleAxe2=setmetatable(cat.BattleAxe2,{}) end
  fail(own,cat)
 end
end)
print("STAGE83_PURE_LUA_PASS groups="..groups.." corruptions=400")
