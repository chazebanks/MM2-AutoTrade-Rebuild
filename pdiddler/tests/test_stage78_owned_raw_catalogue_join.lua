-- Real Lua5.4 regression for Stage78 isolated identity guard.
-- No network, no Roblox, no real player inventory; 400 adversarial cases.
local M=dofile("pdiddler/intelligence_lab/stage78_strict_owned_raw_catalogue_join.lua")
local pass=0
local function check(name,fn)
 local ok,err=pcall(fn)
 if not ok then error("FAIL "..name.." "..tostring(err)) end
 pass=pass+1
 print("PASS "..name)
end
local function own()
 return {Gingerscope=1,EmberscytheChroma=2,CommonKnife=3}
end
local function catalog()
 return {
  Gingerscope={ItemName="Gingerscope",ItemType="Gun",Rarity="Ancient"},
  EmberscytheChroma={ItemName="Emberscythe",ItemType="Knife",
    Rarity="Ancient",Chroma=true,ItemID=111},
  CommonKnife={ItemName="Common Knife",ItemType="Knife",Rarity="Common"},
 }
end
local function noAuthority(out)
 assert(out.authorizesTrade==false and out.authorizesAccept==false)
 assert(out.currentPricesVerified==false and
   out.numericSupremeCheckerIdVerified==false and
   out.playerInventoryAuthenticated==false)
 assert(out.maySendDiscordWebhook==false and out.mayUseForStrategyLearning==false)
 assert(out.mayReportProfit==false and out.mayRecordCompletedTrade==false)
 assert(out.tradeOutcome=="UNKNOWN" and out.serverAttestation==false)
end
local function reject(owned,catalogue,expected)
 local out=M.evaluate(owned,catalogue)
 assert(out.status=="INCONCLUSIVE",out.status)
 if expected then assert(out.reason==expected,out.reason) end
 assert(out.rawToCatalogueDirectJoinObserved==false)
 noAuthority(out)
end
check("three typed direct keys and Ancient Chroma",function()
 local out=M.evaluate(own(),catalog())
 assert(out.status=="CALLER_CLIENT_RAW_TO_CATALOGUE_EXACT_LOOKUP_ONLY")
 assert(out.positiveOwnedKeys==3 and out.positiveOwnedCopies==6)
 assert(out.eligibleKeys==2 and out.eligibleCopies==3)
 assert(out.chromaEligibleCopies==2)
 noAuthority(out)
end)
check("numeric and string raw keys are never collapsed",function()
 local co=catalog()
 co["42"]={ItemName="Synthetic",ItemType="Gun",Rarity="Godly"}
 reject({[42]=1,["42"]=1},co,"RAW_KEY_NOT_EXACT_STRING")
 local out=M.evaluate({["42"]=1},co)
 assert(out.positiveOwnedKeys==1)
 noAuthority(out)
end)
check("unknown raw key is not looked up through display alias",function()
 reject({BattleAxe=1},{Battleaxe={ItemName="Battleaxe",ItemType="Knife",
  Rarity="Godly"}},"CATALOGUE_RAW_KEY_ABSENT_OR_UNTRUSTED")
end)
check("copy counts are strictly numeric and bounded",function()
 for _,qty in ipairs({0,-1,1.5,"2",math.huge,1000001}) do
  reject({Gingerscope=qty},catalog(),"UNTRUSTED_RAW_QUANTITY")
 end
 reject({Gingerscope=0/0},catalog(),"UNTRUSTED_RAW_QUANTITY")
end)
check("invalid IDs cannot be silently stringified",function()
 for _,key in ipairs({"",string.rep("a",129),"A\nB"}) do
  reject({[key]=1},catalog(),"RAW_KEY_NOT_EXACT_STRING")
 end
end)
check("metatable and unexpected index rejected",function()
 reject(setmetatable({Gingerscope=1},{__index=function()return 1 end}),
  catalog(),"SOURCE_TABLE_OR_METATABLE_UNTRUSTED")
 reject({Gingerscope=1},setmetatable(catalog(),{}),
  "SOURCE_TABLE_OR_METATABLE_UNTRUSTED")
 local c=catalog()
 c.Gingerscope=setmetatable(c.Gingerscope,{})
 reject({Gingerscope=1},c,"CATALOGUE_RAW_KEY_ABSENT_OR_UNTRUSTED")
end)
check("malformed variant and type are not silently accepted",function()
 local c=catalog();c.EmberscytheChroma.Chroma="true"
 reject(own(),c,"CATALOGUE_CHROMA_TYPE_MALFORMED")
 c=catalog();c.EmberscytheChroma.Rarity="Common"
 reject(own(),c,"CATALOGUE_CHROMA_RARITY_CONFLICT")
 c=catalog();c.EmberscytheChroma.ItemType="Pet"
 reject(own(),c,"CATALOGUE_NOT_WEAPON_TYPE")
end)
check("base and Chroma may reuse artwork without merging",function()
 local c=catalog()
 c.Gingerscope.ItemID=111
 local out=M.evaluate(own(),c)
 assert(out.eligibleKeys==2 and out.eligibleCopies==3)
 noAuthority(out)
end)
check("caller injection cannot authorize price, trade or settlement",function()
 local c=catalog()
 c.Gingerscope.verified=true;c.Gingerscope.checkerId="771"
 c.Gingerscope.sourceFresh=true
 local o=own()
 o.verified=true
 reject(o,c,"UNTRUSTED_RAW_QUANTITY")
 local good=own()
 local r=M.evaluate(good,c)
 assert(r.status=="CALLER_CLIENT_RAW_TO_CATALOGUE_EXACT_LOOKUP_ONLY")
 noAuthority(r)
end)
check("empty inventory and complete-map limits",function()
 reject({},catalog(),"EMPTY_OWNED_MAP_NOT_PROOF")
 reject({Gingerscope=1000001},catalog(),"UNTRUSTED_RAW_QUANTITY")
end)
check("report does not expose raw weapon keys or profile data",function()
 local o=M.evaluate({["PRIVATE_INVENTORY_RAW_KEY"]=1},
  {PRIVATE_INVENTORY_RAW_KEY={ItemName="Name",ItemType="Knife",Rarity="Godly"}})
 for k,v in pairs(o) do
  assert(tostring(k):find("PRIVATE_INVENTORY_RAW_KEY",1,true)==nil)
  assert(tostring(v):find("PRIVATE_INVENTORY_RAW_KEY",1,true)==nil)
 end
 noAuthority(o)
end)
check("400 adversarial seeded corruptions stay fail-closed",function()
 math.randomseed(78)
 for i=1,400 do
  local o=own();local c=catalog()
  local mod=(i-1)%5
  if mod==0 then o[math.random(3,120)]=1
  elseif mod==1 then o.Gingerscope=math.random(1,100)+0.25
  elseif mod==2 then c.Gingerscope.ItemName=""
  elseif mod==3 then c.EmberscytheChroma.Chroma="true"
  else c.CommonKnife=nil end
  reject(o,c)
 end
end)
print("STAGE78_LUA5_4_PASS named_groups="..pass.." corrupted_inputs=400")
