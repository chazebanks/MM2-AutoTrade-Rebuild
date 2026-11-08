"""Stage54: test the REAL read-only Lua catalogue mapping census against fake game objects.
No Delta remote invocation, item value authority, trade acceptance, or external connection.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
PROBE=ROOT/"pdiddler/new_part4/STAGE54_READONLY_MAPPING_COVERAGE.lua"

FAKE_GAME=r'''
local probe=arg[1]
local realPrint,realRequire=print,require
local written={}
local function sample(name,rarity,typ,chroma,year)
 return {ItemName=name,Rarity=rarity or "Godly",ItemType=typ or "Knife",
         Chroma=chroma==true,Year=year,Image="SECRET_ARTWORK_ASSET"}
end
local function getNumber(s,key)
 return tonumber(s:match('"'..key..'":(%d+)')) or 0
end
local function call(weapons,opts)
 opts=opts or {}
 local sync={Weapons=weapons}
 local module={payload=sync}
 local db={FindFirstChild=function(_,key)
  if key=="Sync" and not opts.noSync then return module end
 end}
 local rs={FindFirstChild=function(_,key)
  if key=="Database" then return db end
 end}
 local http={JSONEncode=function(_,v)
  local out={}
  for k,x in pairs(v)do
   local enc
   if type(x)=="string" then enc=string.format("%q",x)
   elseif type(x)=="number" or type(x)=="boolean" then enc=tostring(x)
   else error("unexpected field") end
   out[#out+1]=string.format("%q:%s",k,enc)
  end
  table.sort(out)
  return "{"..table.concat(out,",").."}"
 end}
 game={PlaceId=opts.place or 142823291,JobId="SECRET_JOB_ID",
  GetService=function(_,key)
   if key=="ReplicatedStorage" then return rs end
   if key=="HttpService" then return http end
  end}
 require=function(o)
  if opts.failRequire then error("SECRET_REQUIRE_ERROR") end
  if opts.changeJob then game.JobId="SECRET_ALTERNATE_JOB" end
  return o.payload
 end
 written={}
 print=function(s)written[#written+1]=tostring(s)end
 local ok,err=pcall(dofile,probe)
 print=realPrint
 require=realRequire
 assert(ok,err)
 assert(#written==1,"single anonymous audit output")
 local s=written[1]
 assert(s:find("[GINGERSCOPE STAGE54 MAPPING COVERAGE]",1,true),"marker missing")
 for _,bad in ipairs({"SECRET","Bioblade","Amerilaser","Batwing",
                      "Constellation","Mortal","http://","https://"})do
  assert(not s:find(bad,1,true),"sensitive game field leaked: "..bad)
 end
 for _,flag in ipairs({'"mappingAuthenticated":false',
  '"externalCheckerIdentityVerified":false','"readOnly":true',
  '"sourceSnapshotIsFrozen":true','"currentPriceSourceUsed":false',
  '"serverCompletionProven":false','"authorizesAccept":false',
  '"authorizesTrade":false','"mayReportProfit":false',
  '"mayRecordCompletedTrade":false','"tradeOutcome":"UNKNOWN"'}) do
  assert(s:find(flag,1,true),"safety flag missing: "..flag)
 end
 return s
end
local count=0
local function case(desc,fn)
 local ok,why=pcall(fn)
 if not ok then error(desc.." => "..tostring(why)) end
 count=count+1
end
local function status(s,k)
 assert(s:find('"status":"'..k..'"',1,true),"status "..k.." not in "..s)
end
case("empty source",function()
 local s=call({})
 status(s,"CLIENT_MAPPING_COVERAGE_UNVERIFIED")
 assert(getNumber(s,"eligible")==0)
end)
case("exact internal key",function()
 local s=call({Bioblade=sample("Bioblade","Godly","Knife",false)})
 status(s,"CLIENT_MAPPING_COVERAGE_UNVERIFIED")
 assert(getNumber(s,"explicitInternal")==1)
 assert(getNumber(s,"eligible")==1)
end)
case("human-entered display alias",function()
 local s=call({UnknownRawKey=sample("Amerilaser","Godly","Gun",false)})
 assert(getNumber(s,"displayAlias")==1)
end)
case("fuzzy Batwing",function()
 local s=call({Batwing=sample("Batwing","Ancient","Knife",false)})
 assert(getNumber(s,"fuzzy")==1)
end)
case("two raw keys map to same external ID",function()
 local s=call({Unique1=sample("Amerilaser","Godly","Gun",false),
               Unique2=sample("Amerilaser","Godly","Gun",false)})
 status(s,"CLIENT_MAPPING_RISK_COUNTS_UNVERIFIED")
 assert(getNumber(s,"duplicateTargetGroups")==1)
 assert(getNumber(s,"duplicateTargetEntries")==2)
end)
case("chroma placeholder is counted but never authenticated",function()
 local s=call({UnknownRaw=sample("Mortal","Godly","Knife",true)})
 status(s,"CLIENT_MAPPING_RISK_COUNTS_UNVERIFIED")
 assert(getNumber(s,"displayAlias")==1)
 assert(getNumber(s,"placeholderArtworkMatches")==1)
 assert(getNumber(s,"filteredChroma")==1)
end)
case("year hint mismatch signals review",function()
 local s=call({Constellation=sample("Constellation","Godly","Knife",false,2022)})
 status(s,"CLIENT_MAPPING_RISK_COUNTS_UNVERIFIED")
 assert(getNumber(s,"yearHintsComparable")==1)
 assert(getNumber(s,"yearHintConflicts")==1)
end)
case("unknowns never turn into authenticated",function()
 local s=call({UnknownNotInSource=sample("CompletelyUnfindable","Godly","Knife",false)})
 assert(getNumber(s,"ambiguous")+getNumber(s,"unresolved")>=1)
 assert(getNumber(s,"otherResolverFail")==0)
end)
case("evolution entries excluded",function()
 local x=sample("Reaver_Ancient","Ancient","Knife",false)
 x.EvoBaseID="Reaver";local s=call({BadEvo=x})
 assert(getNumber(s,"eligible")==0)
 assert(getNumber(s,"excluded")==1)
end)
case("explicit non-tradable excluded",function()
 local x=sample("Bioblade","Godly","Knife",false)
 x.Tradable=false;local s=call({Bioblade=x})
 assert(getNumber(s,"eligible")==0)
end)
case("other tier excluded",function()
 local s=call({Common=sample("Ordinary","Common","Knife",false)})
 assert(getNumber(s,"eligible")==0)
end)
case("invalid metadata blocked",function()
 status(call({SECRET_BAD_ENTRY=23}),"INVALID_CATALOG_SHAPE")
end)
case("numeric printable key collision blocked",function()
 status(call({[21]=sample("Bioblade"),["21"]=sample("Bioblade")}),
        "INVALID_CATALOG_SHAPE")
end)
case("wrong place blocked",function()
 status(call({},{place=1}),"WRONG_GAME")
end)
case("missing Sync module blocked",function()
 status(call({},{noSync=true}),"SYNC_MODULE_MISSING")
end)
case("require failure censored",function()
 status(call({},{failRequire=true}),"SYNC_UNAVAILABLE")
end)
case("job change blocked",function()
 status(call({},{changeJob=true}),"SERVER_CHANGED")
end)
case("missing Weapons blocked",function()
 status(call(nil),"WEAPONS_CATALOG_MISSING")
end)
math.randomseed(5408)
local names={"Bioblade","Amerilaser","Batwing","Mortal",
             "CompletelyUnfindable","Constellation"}
for i=1,400 do
 local choice=math.random(1,#names)
 local name=names[choice]
 local typ=(name=="Amerilaser") and "Gun" or "Knife"
 local rarity=(name=="Batwing") and "Ancient" or "Godly"
 local chroma=name=="Mortal"
 local yr=(name=="Constellation") and (math.random(0,1)==0 and 2024 or 2022) or nil
 local s=call({["SECRET_USER_KEY_"..i]=sample(name,rarity,typ,chroma,yr)})
 assert(getNumber(s,"eligible")==1)
 assert(getNumber(s,"catalogRows")==1)
 assert(getNumber(s,"otherResolverFail")==0)
end
realPrint("STAGE54_ACTUAL_LUA_18_NAMED_400_SEEDED_PASS")
'''

class Stage54CoverageTests(unittest.TestCase):
    def test_source_pinned_frozen_reference_only(self):
        s=PROBE.read_text(encoding="utf-8")
        self.assertIn("Source resolver copied verbatim",s)
        self.assertIn("7a289d62ef3f0be0a299506eb451c57435493be3",s)
        rows=s.split("-- BEGIN FROZEN IMAGE REF (not prices)")[1].split(
            "-- END FROZEN IMAGE REF")[0]
        rows=rows.split("Checker.raw=[==[",1)[1].split("]==]",1)[0]
        entries=[x.split("|") for x in rows.strip().splitlines()]
        self.assertEqual(len(entries),190)
        self.assertEqual(set(e[0] for e in entries),{"ancient","chroma","godly"})
        self.assertTrue(all(len(e)==4 and e[2]=="0" for e in entries))
        self.assertEqual(len(set((e[0],e[1]) for e in entries)),190)
        self.assertEqual(sum(1 for e in entries if e[0]=="chroma"
                             and e[3]=="coming.png"),2)
        self.assertIn("local function checkerResolve(name,opts)",s)
        self.assertIn("local function checkerInternalAlias(page,meta)",s)
        self.assertIn("local function checkerAlias(page,name,typ)",s)
        self.assertIn("local function qualifyingMeta(meta)",s)
        self.assertNotIn("mappingAuthenticated=true",s)
        for forbidden in (':FireServer(', ':InvokeServer(', 'TeleportToPlaceInstance(',
                          'mouse1click(', ':HttpGet(', 'loadstring(', ':PostAsync('):
            self.assertNotIn(forbidden,s)

    @unittest.skipUnless(shutil.which("lua5.4"),"CI installs Lua 5.4")
    def test_real_lua_full_probe_adversarial(self):
        with tempfile.TemporaryDirectory(prefix="stage54_") as td:
            path=Path(td)/"fake_game.lua"
            path.write_text(FAKE_GAME,encoding="utf-8")
            p=subprocess.run(["lua5.4",str(path),str(PROBE)],
                             cwd=ROOT,capture_output=True,text=True,timeout=40)
        self.assertEqual(p.returncode,0,p.stdout+"\n"+p.stderr)
        self.assertIn("STAGE54_ACTUAL_LUA_18_NAMED_400_SEEDED_PASS",p.stdout)

if __name__=="__main__":
    unittest.main()
