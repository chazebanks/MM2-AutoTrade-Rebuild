-- Real pure source, deterministic synthetic original MM2 owned/Sync fixtures.
-- No game calls, no mutable offers, no external API and no trade remotes.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local model=luau.load(fs.readFile(
 "pdiddler/supervised/p3_one_item_owned_selection.lua"),
 {injectGlobals=true})()
local tests=0
local function eq(a,b,msg)
 tests+=1
 assert(a==b,tostring(msg)..": "..tostring(a).." != "..tostring(b))
end
local function sync()
 return {Weapons={
  Iceblaster={ItemName="Iceblaster",ItemType="Gun",Rarity="Godly"},
  Gingerscope={ItemName="Gingerscope",ItemType="Gun",Rarity="Ancient"},
  ChromaFang={ItemName="Fang",ItemType="Knife",Rarity="Godly",Chroma=true},
  CommonKnife={ItemName="Default",ItemType="Knife",Rarity="Common"},
  OldToken={ItemName="Old Token",ItemType="Pet",Rarity="Godly"},
  Batwing={ItemName="Batwing",ItemType="Knife",Rarity="Ancient"},
  NotTradeable={ItemName="NotTradeable",ItemType="Knife",Rarity="Godly",Tradable=false},
  Reaver_Ancient={ItemName="Reaver",ItemType="Knife",Rarity="Ancient",EvoBaseID="Reaver"},
 },Item={}}
end
local function profile(owned) return {ProfileData={Weapons={Owned=owned}}}end
do
 local r=model.build(profile({Iceblaster=3,Gingerscope=1,ChromaFang=2,CommonKnife=1,OldToken=3,NotTradeable=1,Reaver_Ancient=1}),sync())
 eq(r.status,"CLIENT_ELIGIBLE_OWN_CHOICES","eligible own weapons found")
 eq(#r.choices,2,"common, pets, protected Gingerscope and untradable excluded")
 eq(r.choices[1].display,"Fang","display sorted by human name")
 eq(r.choices[1].raw,"ChromaFang","original game key retained")
 eq(r.choices[1].chroma,true,"Chroma tag preserved")
 eq(r.choices[1].qty,2,"quantity shown, one item per offer")
 eq(r.choices[2].raw,"Iceblaster","second owned candidate")
 eq(r.choices[2].qty,3,"stack owned quantity displayed")
 eq(r.authorizesOffer,false,"picker cannot authorize offers")
 eq(r.authorizesAccept,false,"picker cannot authorize Accept")
 eq(r.tradeOutcome,"UNKNOWN","no settlement")
 eq(r.mayReportProfit,false,"never pricing/profit")
end
for _,input in ipairs({
 {raw={Weapons={}},why="CURRENT_OWN_PROFILE_UNREADABLE"},
 {raw={Profile={Weapons={Owned={UnknownGodly=1}}}},why="OWN_WEAPON_METADATA_UNRESOLVED"},
 {raw=profile({Iceblaster=-1}),why="OWN_WEAPON_QUANTITY_INVALID"},
 {raw=profile({Iceblaster="one"}),why="OWN_WEAPON_QUANTITY_INVALID"},
 {raw=profile({Iceblaster=1.5}),why="OWN_WEAPON_QUANTITY_INVALID"},
 {raw=profile({CommonKnife=3}),why="NO_ELIGIBLE_CURRENT_OWN_WEAPONS"},
 {raw=profile({Gingerscope=1}),why="NO_ELIGIBLE_CURRENT_OWN_WEAPONS"},
 {raw=profile({Iceblaster=0}),why="NO_ELIGIBLE_CURRENT_OWN_WEAPONS"},
}) do
 local r=model.build(input.raw,sync())
 eq(r.status,"BLOCKED","ineligible/ambiguous inventory blocked")
 eq(r.reason,input.why,"precise static reason")
 eq(#r.choices,0,"no misleading menu choices on failure")
end
do
 local s=sync()
 s.Item.Iceblaster={ItemName="Fake Iceblaster",ItemType="Gun",Rarity="Godly"}
 local r=model.build(profile({Iceblaster=1}),s)
 eq(r.reason,"CURRENT_GAME_WEAPON_CATALOG_UNREADABLE",
  "conflicting Sync vs Item can never spoof a weapon")
end
do
 local r=model.build(profile({Iceblaster=1}),{})
 eq(r.reason,"CURRENT_GAME_WEAPON_CATALOG_UNREADABLE","missing game catalogue")
end
do
 local s=sync()
 s.Weapons.Iceblaster.Untradable=true
 local r=model.build(profile({Iceblaster=1}),s)
 eq(r.status,"BLOCKED","nontradable item never offered")
end
do
 local s=sync()
 s.Weapons.ChromaFang.ItemName="Chroma Fang"
 local r=model.build(profile({ChromaFang=1}),s)
 eq(r.status,"CLIENT_ELIGIBLE_OWN_CHOICES","chroma prefix safely stripped")
 eq(r.choices[1].display,"Fang","exact base GUI expected")
 eq(r.choices[1].chroma,true,"tag required")
end
do
 local s=sync()
 s.Weapons.BadHuge={ItemName="A Weapon With A Name Longer Than Twenty Four",
  ItemType="Gun",Rarity="Godly"}
 local r=model.build(profile({Iceblaster=1,BadHuge=1}),s)
 eq(r.status,"CLIENT_ELIGIBLE_OWN_CHOICES","ignore oversized item without blocking other choices")
 eq(#r.choices,1,"name-too-long cannot be selected")
end
do
 local s=sync()
 s.Weapons.AncientSword={ItemName="AncientSword",ItemType="Knife",Rarity="Ancient"}
 local r=model.build({Data={Weapons={Owned={AncientSword="1",Iceblaster="0"}}}},s)
 eq(r.status,"CLIENT_ELIGIBLE_OWN_CHOICES","nested current profile and numeric qty string")
 eq(r.choices[1].raw,"AncientSword","raw identity preserved from actual profile")
end
print("[PASS] original MM2 current OWNED x Sync pure protected item picker:",tests)
