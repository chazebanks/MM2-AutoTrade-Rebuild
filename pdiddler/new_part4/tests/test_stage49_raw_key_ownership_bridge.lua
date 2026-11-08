-- Stage49: test the ACTUAL pure Lua raw Sync/Profile/Scanner key bridge.
local dir=arg[1] or "pdiddler/new_part4"
local M=assert(loadfile(dir.."/p4_stage49_raw_key_ownership_bridge.lua"))()
local SECRET="UserSecretShouldNeverAppearInResult"
local raw="Batwing_Internal_99"
local done=0
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b))end
local function test(label,fn)
 local ok,err=pcall(fn)
 if not ok then error(label..": "..tostring(err),0) end
 done=done+1
end
local flags={"offerKeyOriginVerified","checkerIdentityVerified","uniqueWeaponInstanceProven",
 "rawItemIdConfirmed","rawKeyPresentConfirmed","ownerSideSlotBound",
 "hasAuthenticatedSessionIdentifier","eventSessionAssociationProven",
 "causalAttributionProven","serverAttestation","serverCompletionProven",
 "authorizesTrade","authorizesAccept","mayRecordCompletedTrade","mayReportProfit"}
local function clean(r)
 eq(r.readOnly,true);eq(r.clientOnly,true);eq(r.tradeOutcome,"UNKNOWN")
 for _,v in ipairs(flags) do eq(r[v],false)end
 local function walk(t)
  if type(t)=="string" then
   for _,s in ipairs({SECRET,raw,"Batwing","Chroma Phantom","wrong secret"}) do
    assert(not t:find(s,1,true),"raw value leaked")end
  elseif type(t)=="table" then
   for k,x in pairs(t)do walk(k);walk(x)end
  end
 end
 walk(r)
 return r
end
local function fixture()
 local metadata={ItemName="Batwing",Rarity="Ancient",ItemType="Knife",Tradable=true}
 local w={[raw]=metadata}
 local sync={Weapons=w,Item=w}
 local owned={[raw]=2}
 local scanner={rawOwned=2,unmapped=0,badQty=0,unpriced=0,items={{
  id=raw,cat="Weapons",name="Batwing",type="Knife",
  page="ancient",qty=2,checkerId="9999999",valueSource=SECRET}}}
 return sync,owned,scanner
end
local function inspect(s,o,c,k,q)
 return clean(M.inspect(s,o,c,k or raw,q or 1))
end
test("matching raw Sync/Owned/scanner key is client-only NOT checker ID",function()
 local a,b,c=fixture()
 local r=inspect(a,b,c)
 eq(r.status,"CLIENT_RAW_KEY_OWNERSHIP_CORRESPONDENCE_ONLY")
 eq(r.reason,"NONE");eq(r.rawKeyType,"STRING")
 eq(r.exactRawKeyInSync,true);eq(r.exactRawKeyInOwned,true)
 eq(r.scannerRowRawKeyMatched,true);eq(r.scannerRowCountMatched,true)
 eq(r.rawKeyOwnedClientMatch,true);eq(r.syncAliasMode,"SHARED_TABLE")
 eq(r.checkerMappingMode,"UNATTESTED_SCANNER_RESOLVER")
 eq(r.checkerIdentityVerified,false)
end)
test("a stringified market checker id never becomes equality proof",function()
 local a,b,c=fixture()
 c.items[1].checkerId=SECRET
 local r=inspect(a,b,c)
 eq(r.rawKeyOwnedClientMatch,true);eq(r.checkerIdentityVerified,false)
end)
test("missing Item alias tolerated with explicit category",function()
 local a,b,c=fixture();a.Item=nil
 local r=inspect(a,b,c)
 eq(r.syncAliasMode,"WEAPONS_ONLY");eq(r.rawKeyOwnedClientMatch,true)
end)
test("distinct unused Item table tolerated",function()
 local a,b,c=fixture();a.Item={}
 local r=inspect(a,b,c)
 eq(r.syncAliasMode,"DISTINCT_TABLES");eq(r.rawKeyOwnedClientMatch,true)
end)
test("distinct Item alias to SAME metadata allowed",function()
 local a,b,c=fixture();a.Item={[raw]=a.Weapons[raw]}
 local r=inspect(a,b,c)
 eq(r.rawKeyOwnedClientMatch,true)
end)
test("distinct Item alias to DIFFERENT row rejected",function()
 local a,b,c=fixture();a.Item={[raw]={ItemName="Batwing"}}
 eq(inspect(a,b,c).reason,"SYNC_RAW_KEY_COLLISION")
end)
test("candidate not in Sync rejected",function()
 local a,b,c=fixture()
 eq(inspect(a,b,c,"UnknownRaw",1).reason,"CANDIDATE_KEY_MISSING_IN_SYNC")
end)
test("valid numeric Sync/Owned key never coerced to scanner string",function()
 local a,b,c=fixture()
 local meta=a.Weapons[raw];a.Weapons={[42]=meta};a.Item=a.Weapons
 b={[42]=2};c.items[1].id="42"
 eq(inspect(a,b,c,42,1).reason,"NUMERIC_KEY_SCANNER_COERCION_UNVERIFIED")
end)
test("same text numeric and string Sync keys rejected",function()
 local a,b,c=fixture()
 a.Weapons[42]=a.Weapons[raw];a.Weapons["42"]=a.Weapons[raw]
 eq(inspect(a,b,c).reason,"STRING_NUMERIC_KEY_COLLISION")
end)
test("same text numeric and string Owned keys rejected",function()
 local a,b,c=fixture()
 b[42]=1;b["42"]=1;c.rawOwned=4
 eq(inspect(a,b,c).reason,"RAW_OWNED_KEY_TYPE_COLLISION")
end)
test("unknown raw-owned key fails",function()
 local a,b,c=fixture();b[raw]=nil;c.rawOwned=0
 eq(inspect(a,b,c).reason,"RAW_KEY_NOT_OWNED")
end)
test("offer above owned stock fails",function()
 local a,b,c=fixture()
 eq(inspect(a,b,c,raw,3).reason,"INSUFFICIENT_RAW_OWNED_COPIES")
end)
test("scanner rawOwned total must equal full profile even including low tiers",function()
 local a,b,c=fixture();b.SomeCommon=4
 eq(inspect(a,b,c).reason,"SCANNER_PROFILE_TOTAL_DISAGREES")
 c.rawOwned=6
 eq(inspect(a,b,c).rawKeyOwnedClientMatch,true)
end)
test("scanner target row quantity mismatch fails",function()
 local a,b,c=fixture();c.items[1].qty=1
 eq(inspect(a,b,c).reason,"SCANNER_OWNED_QUANTITY_MISMATCH")
end)
test("duplicate scanner raw keys fail",function()
 local a,b,c=fixture();c.items[2]={
  id=raw,cat="Weapons",name="Batwing",page="ancient",
  type="Knife",qty=2}
 eq(inspect(a,b,c).reason,"DUPLICATE_SCANNER_RAW_KEY")
end)
test("missing target scanner row cannot prove ownership cross reader",function()
 local a,b,c=fixture();c.items[1].id="Unrelated"
 eq(inspect(a,b,c).reason,"SCANNER_RAW_KEY_NOT_UNIQUE")
end)
test("malformed scanner slot fails",function()
 local a,b,c=fixture();c.items[1].qty="2"
 eq(inspect(a,b,c).reason,"SCANNER_ROW_UNTRUSTED")
end)
test("scanner extra keyed row cannot bypass array audit",function()
 local a,b,c=fixture();c.items.EXTRA={}
 eq(inspect(a,b,c).reason,"SCANNER_ARRAY_SPARSE_OR_EXTRA")
end)
test("unmapped inventory fails closed",function()
 local a,b,c=fixture();c.unmapped=1
 eq(inspect(a,b,c).reason,"SCANNER_INCOMPLETE_OR_UNMAPPED")
end)
test("bad quantity fails closed",function()
 local a,b,c=fixture();c.badQty=1
 eq(inspect(a,b,c).reason,"SCANNER_INCOMPLETE_OR_UNMAPPED")
end)
test("profile owned invalid count rejects",function()
 local a,b,c=fixture();b[raw]=0/0
 eq(inspect(a,b,c).reason,"RAW_OWNED_COUNT_UNTRUSTED")
end)
test("profile Owned string count can pass only exact raw key",function()
 local a,b,c=fixture();b[raw]="2"
 eq(inspect(a,b,c).rawKeyOwnedClientMatch,true)
end)
test("profile unknown key type rejected",function()
 local a,b,c=fixture();b[{}]=1
 eq(inspect(a,b,c).reason,"RAW_OWNED_MAP_UNTRUSTED")
end)
test("scanner metadata type mismatch fails",function()
 local a,b,c=fixture();c.items[1].type="Gun"
 eq(inspect(a,b,c).reason,"SCANNER_ROW_METADATA_MISMATCH")
end)
test("scanner category mismatch fails",function()
 local a,b,c=fixture();c.items[1].cat="Pets"
 eq(inspect(a,b,c).reason,"SCANNER_ROW_METADATA_MISMATCH")
end)
test("scanner name mismatch fails",function()
 local a,b,c=fixture();c.items[1].name="Different"
 eq(inspect(a,b,c).reason,"SCANNER_ROW_METADATA_MISMATCH")
end)
test("Sync Godly Gun supported",function()
 local a,b,c=fixture()
 a.Weapons[raw].Rarity="Godly";a.Weapons[raw].ItemType="Gun"
 c.items[1].page="godly";c.items[1].type="Gun"
 eq(inspect(a,b,c).rawKeyOwnedClientMatch,true)
end)
test("Sync chroma requires scanner chroma display prefix",function()
 local a,b,c=fixture()
 a.Weapons[raw].Rarity="Godly";a.Weapons[raw].Chroma=true
 c.items[1].page="chroma";c.items[1].name="Chroma Batwing"
 eq(inspect(a,b,c).rawKeyOwnedClientMatch,true)
end)
test("chroma scanner with ordinary label fails",function()
 local a,b,c=fixture();a.Weapons[raw].Chroma=true
 c.items[1].page="chroma"
 eq(inspect(a,b,c).reason,"SCANNER_ROW_METADATA_MISMATCH")
end)
test("evolution-stage sync record rejected",function()
 local a,b,c=fixture();a.Weapons[raw].EvoIndex=1
 eq(inspect(a,b,c).reason,"SYNC_ITEM_NOT_VERIFIED_ELIGIBLE")
end)
test("untradeable sync record rejected",function()
 local a,b,c=fixture();a.Weapons[raw].CanTrade=false
 eq(inspect(a,b,c).reason,"SYNC_ITEM_NOT_VERIFIED_ELIGIBLE")
end)
test("not eligible rarity sync record rejected",function()
 local a,b,c=fixture();a.Weapons[raw].Rarity="Legendary"
 eq(inspect(a,b,c).reason,"SYNC_ITEM_NOT_VERIFIED_ELIGIBLE")
end)
test("Sync with metatable rejected",function()
 local a,b,c=fixture();setmetatable(a,{__index=function()error("unsafe")end})
 eq(inspect(a,b,c).reason,"UNTRUSTED_INPUT_SHAPE")
end)
test("Sync row with metatable rejected",function()
 local a,b,c=fixture();setmetatable(a.Weapons[raw],{__index=function()error("unsafe")end})
 eq(inspect(a,b,c).reason,"SYNC_CATALOGUE_UNTRUSTED")
end)
test("scanner row with metatable rejected",function()
 local a,b,c=fixture();setmetatable(c.items[1],{__index=function()error("unsafe")end})
 eq(inspect(a,b,c).reason,"SCANNER_ROW_UNTRUSTED")
end)
test("zero requested quantity rejected",function()
 local a,b,c=fixture()
 local r=clean(M.inspect(a,b,c,raw,0))
 eq(r.reason,"INVALID_KEY_OR_REQUESTED_QUANTITY")
end)
test("wrong string key profile numeric is never coerced",function()
 local a,b,c=fixture();b={[42]=2};c.rawOwned=2
 eq(inspect(a,b,c).reason,"RAW_KEY_NOT_OWNED")
end)
test("entire catalogue size limit rejects before setting true",function()
 local a,b,c=fixture()
 for i=1,2501 do a.Weapons["X_"..i]={
  ItemName="Other",ItemType="Knife",Rarity="Ancient"} end
 eq(inspect(a,b,c).reason,"SYNC_CATALOGUE_OVERSIZE")
end)
print("Stage49 exact raw-key ownership bridge: "..done.." passed, 0 failed")
