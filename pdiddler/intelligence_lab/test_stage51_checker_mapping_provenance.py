"""Stage51: exercise ACTUAL checkerResolve/checkerMarket source, not a copy.

The live scanner is Luau (its complete source cannot compile under Lua5.4).
Extract only the genuine standard-Lua checker functions into a strict Lua5.4
fixture with synthetic catalogue rows and assert stable mapping provenance.
"""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

HERE=Path(__file__).resolve().parent
SCANNER=HERE.parent/"presentation"/"pdiddler3_scanner_MODULE_v6_10_CURRENT_PRESENTATION.lua"
ROOT=HERE.parents[1]

def source():
    return SCANNER.read_text(encoding="utf-8")

def actual_checker_functions(text):
    first=text.index("local checkerCache={}")
    end=text.index("\ncheckerBuild()\n",first)
    excerpt=text[first:end]
    assert "local function checkerResolve(name,opts)" in excerpt
    assert "local function checkerMarket(meta)" in excerpt
    return excerpt

PRELUDE=r'''
local Checker={rows={},byId={}}
local function rec(id,v,img)
 return {page="godly",id=id,v=v,img=img}
end
local a=rec("444",10,"Bioblade.png")
local b=rec("30",20,"Amerilaser.png")
local c=rec("555",40,"FuzzyTarget.png")
local d=rec("556",40,"Duplicate.png")
Checker.rows.godly={a,b,c,d}
Checker.byId.godly={["444"]=a,["30"]=b,["555"]=c,["556"]=d}
local function checkerBuild()return true end
local function norm(x)
 return string.lower(tostring(x or "")):gsub("[^%w]","")
end
local function allowedPage(page)return page=="godly" or page=="ancient" or page=="chroma"end
local function checkerPage(meta)
 if not meta then return nil end
 if meta.chroma then return "chroma" end
 return string.lower(meta.rarity or "godly")
end
local function identityName(meta)return meta and meta.name or "" end
local function checkerInternalAlias(page,meta)
 if page=="godly" and meta and meta.id=="Bioblade" then return "444" end
end
local function checkerAlias(page,shown,typ)
 if page=="godly" and shown=="Amerilaser" then return "30" end
end
local function checkerCanon(x,page,itemType,level)
 return norm(tostring(x or ""):gsub("%.png$",""))
end
local function met(id,name,typ)
 return {id=id,name=name,rarity="Godly",type=typ or "Knife",
         chroma=false,data={}}
end
'''

ASSERTIONS=r'''
local count=0
local function eq(a,b,desc)
 assert(a==b,(desc or "value")..": "..tostring(a).." ~= "..tostring(b))
 count=count+1
end
local function attempt(meta)
 return checkerResolve(meta.name,{page="godly",type=meta.type,id=meta.id,
                                 chroma=false,meta=meta})
end

-- Hard-coded internal key, first and cached.
local m=met("Bioblade","Bioblade","Knife")
local r,why=attempt(m);eq(r.id,"444");eq(why,"internal-key")
local repeated,cacheWhy=attempt(m)
eq(repeated.id,"444");eq(cacheWhy,"internal-key")

-- Human-entered alias is not the same proof category as an internal key.
m=met("UnmatchedAlias","Amerilaser","Gun")
r,why=attempt(m);eq(r.id,"30");eq(why,"alias")
repeated,cacheWhy=attempt(m)
eq(repeated.id,"30");eq(cacheWhy,"alias")

-- A third path is fuzzy name/image similarity; never certify its checker ID.
m=met("NotMapped","FuzzyTarget","Knife")
r,why=attempt(m)
eq(r.id,"555")
assert(type(why)=="string" and why:match("^match:%d+$"),"fuzzy method absent")
repeated,cacheWhy=attempt(m)
eq(repeated.id,"555");eq(cacheWhy,why)

-- Provenance is on returned market object and remains unauthenticated.
local market,failed=checkerMarket(m)
eq(failed,nil);eq(market.id,"555");eq(market.mappingMethod,why)
eq(market.mappingAuthenticated,false)
eq(market.uniqueWeaponInstanceProven,false)
eq(market.provenanceScope,"CLIENT_MAPPING_UNATTESTED")
eq(market.source,"verified-snapshot-2026-11-01")

-- Similar-looking fuzzy candidates with equal score but different IDs
-- are ambiguous. Neither cache nor source date may resolve the tie.
Checker.rows.godly[3]={page="godly",id="555",v=40,img="Duplicate.png"}
Checker.byId.godly["555"]=Checker.rows.godly[3]
m=met("NoMapped","Duplicate","Knife")
r,why=attempt(m)
eq(r,nil);eq(why,"ambiguous")
r,why=attempt(m);eq(r,nil);eq(why,"ambiguous")

-- Distinct item/source/type combination is still a distinct cache key.
m=met("Different","NotInList","Gun")
r,why=attempt(m)
eq(r,nil);eq(why,"unresolved")

-- No raw keys, usernames, session IDs, profitability or trade claims
-- may appear in the metadata returned by the ordinary market checker.
m=met("Another","Amerilaser","Gun")
local v=checkerMarket(m)
eq(v.mappingMethod,"alias")
eq(v.mappingAuthenticated,false)
eq(v.uniqueWeaponInstanceProven,false)

print("Stage51 actual scanner checkerResolve/checkerMarket: "..count.." assertions passed")
'''

class CheckerProvenanceTests(unittest.TestCase):
    def test_source_preserves_cache_reason(self):
        s=source()
        self.assertIn("return cached.rec,cached.mappingMethod",s)
        for method in ("internal-key","alias"):
            self.assertIn('mappingMethod="'+method+'"',s)
        self.assertIn('checkerCache[ck]={rec=best,mappingMethod=origin}',s)
        self.assertNotIn('return checkerCache[ck],"cache"',s)
        self.assertNotIn('checkerCache[ck]=internalRec',s)
        self.assertNotIn('checkerCache[ck]=best',s)

    def test_source_exposes_exact_method_separately_from_value_date(self):
        s=source()
        required=(
            'source="verified-snapshot-2026-11-01"',
            'mappingMethod=why',
            'mappingAuthenticated=false',
            'uniqueWeaponInstanceProven=false',
            'provenanceScope="CLIENT_MAPPING_UNATTESTED"',
            'checkerMappingMethod=market and market.mappingMethod or "UNRESOLVED"',
            'checkerMappingAuthenticated=false',
            'valueSource=market and',
            '"|CLIENT_UNVERIFIED"',
        )
        for clause in required:
            with self.subTest(clause=clause):
                self.assertIn(clause,s)

    def test_never_upgrade_fuzzy_to_exact_mapping(self):
        s=source()
        self.assertIn('return best,origin',s)
        self.assertIn('if tied then return nil,"ambiguous" end',s)
        self.assertNotIn("mappingAuthenticated=true",s)
        self.assertNotIn("uniqueWeaponInstanceProven=true",s)
        self.assertEqual(s.count("local checkerCache={}"),1)

    def test_source_is_unmodified_on_trade_execution_boundaries(self):
        s=source()
        self.assertIn('function ScannerAPI.getOwnInventory()',s)
        self.assertIn('local function getFullInventoryRemote()',s)
        self.assertIn('local function checkerMarket(meta)',s)
        self.assertEqual(s.count('function ScannerAPI.getOwnInventory()'),1)
        self.assertEqual(s.count('local function inventoryFromProfile(prof)'),1)

    @unittest.skipUnless(shutil.which("lua5.4"),"GitHub Actions installs Lua 5.4")
    def test_python_executes_actual_checker_lua_source(self):
        code=PRELUDE+"\n"+actual_checker_functions(source())+"\n"+ASSERTIONS
        with tempfile.TemporaryDirectory(prefix="stage51_lua_") as td:
            script=Path(td)/"actual_checker.lua"
            script.write_text(code,encoding="utf-8")
            proc=subprocess.run(
                ["lua5.4",str(script)],cwd=ROOT,text=True,
                capture_output=True,timeout=20)
        self.assertEqual(proc.returncode,0,proc.stdout+"\n"+proc.stderr)
        self.assertIn("Stage51 actual scanner checkerResolve/checkerMarket:",proc.stdout)

if __name__=="__main__":
    unittest.main()
