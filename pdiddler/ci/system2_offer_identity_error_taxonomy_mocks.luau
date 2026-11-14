-- Execute actual System2 pure offered-item identity resolver and original
-- Stage9 quantity parser. No game, no offers, no live accounts or money.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local code=fs.readFile("pdiddler/system2/native_offer_item_identity_resolver.lua")
local original=fs.readFile("pdiddler/new_part4/p4_observer_contract.lua")
local resolver=luau.load(code)()
local stage9=luau.load(original)()
local cnt=0
local function eq(a,b,why)
 cnt+=1
 assert(a==b,why.." ["..tostring(a).." != "..tostring(b).."]")
end
local function yes(a,why)
 cnt+=1;assert(a,why)
end
local function row(name,typ,rarity,chroma)
 return {Name=name,ItemType=typ or "Knife",Rarity=rarity or "Godly",
  Chroma=chroma or false}
end
local base={
 Weapons={
  StandardTool=row("Fang","Knife","Godly",false),
  ChromaTool=row("Fang","Knife","Godly",true),
  LaserGodly=row("Laser","Gun","Godly",false),
  LaserVintage=row("Laser","Gun","Vintage",false),
  NormalTool=row("Ember","Gun","Ancient",false),
  AnotherTool=row("Other","Knife","Godly",false),
  AliasTool=row("Other","Knife","Godly",false),
  BogusEvo={Name="Unwanted",ItemType="Knife",Rarity="Godly",EvoBaseID="Ev"},
  LimitedTool=row("Starter","Knife","Common",false),
 },
 Item={
  NormalTool=row("Ember","Gun","Ancient",false),
 }
}
local cat,err=resolver.buildCatalog(base)
eq(err,nil,"valid catalog")
yes(type(cat.byId)=="table","catalog raw key index exists")
local function slot(label,qty,chroma,attributes)
 return {label=label,amountText=qty or "",chromaTag=chroma==true,
 rawAttrs=attributes or {}}
end
local function find(v)
 return resolver.resolve(cat,v,stage9.parseQuantity)
end
local function good(v,id,qty,why)
 local k,q,r=find(v)
 eq(k,id,why.." ID")
 eq(q,qty,why.." quantity")
 eq(r,"RESOLVED_CLIENT_CATALOG_ONLY",why.." status not authoritative")
end
local function deny(v,why,desc)
 local a,b,c=find(v)
 eq(a,nil,desc.." no key")
 eq(b,nil,desc.." no qty")
 eq(c,why,desc.." exact taxonomy")
end
good(slot("Ember",""),"NormalTool",1,"unique exact catalog name")
good(slot("   EmBer  ","x5"),"NormalTool",5,"five-copy one-slot normalizes")
good(slot("Other","×3",false,{WeaponID="AnotherTool"}),
  "AnotherTool",3,"ambiguous name resolved by exact raw key")
good(slot("Other","X2",false,{ItemID="AliasTool"}),"AliasTool",2,
  "other duplicate alias resolved by independently bound ID")
good(slot("Laser","",false,{ItemId="LaserGodly"}),
  "LaserGodly",1,"known cross-tier collision with exact raw key")
good(slot("Chroma Fang","x2"),"ChromaTool",2,
  "explicit chroma title resolves matching variant")
good(slot("Fang","",true),"ChromaTool",1,
  "visible Chroma tag resolves matching variant")
good(slot("Fang","",false,{ID="ChromaTool"}),
  "ChromaTool",1,"known exact raw ID proves variant even without tag")
good(slot("Ember","1",false,{ItemId="NormalTool",WeaponID="NormalTool"}),
  "NormalTool",1,"multiple agreeing raw-id attributes")
deny(slot("Fang",""),"NAME_ONLY_CATALOG_VARIANT_OR_ALIAS_AMBIGUOUS",
  "chroma vs non-chroma name-only collision")
deny(slot("Other",""),"NAME_ONLY_CATALOG_VARIANT_OR_ALIAS_AMBIGUOUS",
  "duplicate standard names no guess")
deny(slot("Laser",""),"KNOWN_CROSS_TIER_NAME_COLLISION_NEEDS_RAW_ID",
  "Vintage+Godly laser label can't decide by name")
deny(slot("Laser","",false,{ItemId="LaserVintage"}),
  "OFFERED_WEAPON_INELIGIBLE_OR_EXCLUDED","exact Vintage Laser not eligible")
deny(slot("Starter",""),"OFFERED_WEAPON_INELIGIBLE_OR_EXCLUDED",
  "Common ineligible even unique label")
deny(slot("Unwanted",""),"OFFERED_WEAPON_INELIGIBLE_OR_EXCLUDED",
  "evolving weapon not allowed")
deny(slot("Fang","",true,{ItemId="StandardTool"}),
  "RAW_ID_CHROMA_VARIANT_CONFLICT","chroma tag contradicts raw ID")
deny(slot("Wrong","",false,{ItemId="NormalTool"}),
  "RAW_ID_VISIBLE_NAME_MISMATCH","raw ID mismatches visible label")
deny(slot("Ember","",false,{ItemId="Nonexistent"}),
  "RAW_ID_NOT_IN_LIVE_CATALOG","unknown raw slot ID")
deny(slot("Unknown",""),"VISIBLE_NAME_NOT_IN_LIVE_CATALOG",
  "new live item missing from catalog")
deny(slot("Ember","x0"),"SLOT_QUANTITY_INVALID_OR_UNPROVEN",
  "zero quantity is invalid")
deny(slot("Ember","-1"),"SLOT_QUANTITY_INVALID_OR_UNPROVEN",
  "negative invalid")
deny(slot("Ember","x10001"),"SLOT_QUANTITY_INVALID_OR_UNPROVEN",
  "too many copies invalid")
deny(slot("Ember","xNaN"),"SLOT_QUANTITY_INVALID_OR_UNPROVEN",
  "malformed qty invalid")
deny(slot("Ember","0.5"),"SLOT_QUANTITY_INVALID_OR_UNPROVEN",
  "fraction invalid")
deny(slot("Ember","",false,{ItemId="NormalTool",WeaponId="ChromaTool"}),
  "SLOT_CONFLICTING_RAW_ATTRIBUTES",
  "two different raw-game-key attrs")
deny(slot("Ember","",false,{HackerField="NormalTool"}),
  "SLOT_UNEXPECTED_RAW_ATTRIBUTE","unknown attr field")
deny(slot("Ember","",false,{ItemId=123}),
  "SLOT_RAW_ATTRIBUTE_MALFORMED","numeric attr not guessed")
local v=slot("Ember")
v.label=""
deny(v,"SLOT_VISIBLE_NAME_MISSING","missing GUI item text")
v=slot("Ember");v.amountText=nil
deny(v,"SLOT_QUANTITY_LABEL_MISSING","missing GUI amount label")
v=slot("Ember");v.chromaTag=nil
deny(v,"SLOT_CHROMA_TAG_STATE_UNAVAILABLE","missing tag observation")
v=slot("Ember");v.rawAttrs=nil
deny(v,"SLOT_RAW_ATTRIBUTES_MISSING","missing raw attribute capture")
v=slot("Ember");v.maybeAuthority=true
deny(v,"SLOT_UNEXPECTED_INPUT_FIELD","forged resolution authority")
local x,e=resolver.buildCatalog({Weapons={}})
eq(x,nil,"empty source blocked");eq(e,"LIVE_CATALOG_EMPTY","empty source reason")
x,e=resolver.buildCatalog({Weapons=base.Weapons,
 Item={NormalTool=row("Changed name","Gun","Ancient",false)}})
eq(x,nil,"two game catalogs with same ID disagreement blocked")
eq(e,"LIVE_CATALOG_DUPLICATE_RAW_KEY_CONFLICT","catalog conflict reason")
x,e=resolver.buildCatalog({Weapons={
 Broken={Name="Oops",ItemType="Knife",Rarity="Godly",Chroma="yes"}
}})
eq(x,nil,"invalid chroma metadata rejected")
eq(e,"LIVE_CATALOG_METADATA_INVALID","malformed metadata reason")
-- No title means user cannot identify the actual sixth item or its
-- raw game key from prior STOP reason. Never convert synthetic cases
-- into an assertion that the exact user's unknown item is now resolved.
print("[PASS] System2 distinct offered-item failure taxonomy and original Stage9 quantity:",cnt,"Lune assertions")
