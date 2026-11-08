"""Stage56: test the REAL read-only Lua catalogue mapping census against fake game objects.
No Delta remote invocation, item value authority, trade acceptance, or external connection.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
PROBE=ROOT/"pdiddler/new_part4/STAGE56_READONLY_NORMALIZATION_RISK_BUCKETS.lua"

FAKE_GAME=r'''
local probe=arg[1]
local realPrint,realRequire,realSetclipboard,realToclipboard,realGetgenv=
 print,require,setclipboard,toclipboard,getgenv
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
 local copied={}
 local primaryAvailable=opts.clipboardPrimary~=false
 setclipboard=primaryAvailable and function(report)
  if opts.primaryThrows then error("SECRET_CLIPBOARD_ERROR") end
  if opts.primaryReturnsFalse then return false end
  copied[#copied+1]=report
 end or nil
 toclipboard=opts.clipboardFallback and function(report)
  copied[#copied+1]=report
 end or nil
 getgenv=opts.envClipboard and function()
  return {setclipboard=function(report) copied[#copied+1]=report end}
 end or nil
 local module={payload=sync}
 local db={FindFirstChild=function(_,key)
  if key=="Sync" and not opts.noSync then return module end
 end}
 local rs={FindFirstChild=function(_,key)
  if key=="Database" then return db end
 end}
 local http={JSONEncode=function(_,v)
  if opts.encoderThrows then error("SECRET_JSON_ERROR") end
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
 setclipboard=realSetclipboard
 toclipboard=realToclipboard
 getgenv=realGetgenv
 assert(ok,err)
 local s=written[1]
 assert(type(s)=="string" and
  s:find("[GINGERSCOPE STAGE56 NORMALIZATION RISK BUCKETS]",1,true),"marker missing")
 if opts.encoderThrows then
  assert(#written==1,"JSON failure must not print a fabricated report")
  assert(s:find("REPORT_ENCODING_FAILED",1,true),"missing JSON failure")
  assert(#copied==0,"unencoded data must never reach clipboard")
  return s
 end
 assert(#written==2,"one JSON report + one clipboard status required")
 local expectCopy=(primaryAvailable and not opts.primaryThrows and not opts.primaryReturnsFalse)
  or opts.clipboardFallback==true or opts.envClipboard==true
 if expectCopy then
  assert(#copied==1 and copied[1]==s,"clipboard must equal only anonymized report")
  assert(written[2]=="[STAGE56] CLIPBOARD_COPIED","missing successful clipboard status")
 else
  assert(#copied==0,"clipboard unexpectedly modified")
  assert(written[2]=="[STAGE56] CLIPBOARD_UNAVAILABLE_COPY_REPORT_FROM_CONSOLE",
   "console fallback status missing")
 end
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
case("clipboard primary supported",function()
 local s=call({Bioblade=sample("Bioblade","Godly","Knife",false)})
 assert(getNumber(s,"explicitInternal")==1)
end)
case("clipboard missing still emits console JSON",function()
 local s=call({Bioblade=sample("Bioblade","Godly","Knife",false)},
  {clipboardPrimary=false})
 assert(getNumber(s,"explicitInternal")==1)
end)
case("fallback to toclipboard when primary throws",function()
 local s=call({Bioblade=sample("Bioblade","Godly","Knife",false)},
  {primaryThrows=true,clipboardFallback=true})
 assert(getNumber(s,"explicitInternal")==1)
end)
case("false-returning primary uses toclipboard",function()
 local s=call({Bioblade=sample("Bioblade","Godly","Knife",false)},
  {primaryReturnsFalse=true,clipboardFallback=true})
 assert(getNumber(s,"explicitInternal")==1)
end)
case("getgenv-only clipboard supported",function()
 local s=call({Bioblade=sample("Bioblade","Godly","Knife",false)},
  {clipboardPrimary=false,envClipboard=true})
 assert(getNumber(s,"explicitInternal")==1)
end)
case("all clipboard methods unavailable still prints",function()
 local s=call({Bioblade=sample("Bioblade","Godly","Knife",false)},
  {clipboardPrimary=false,clipboardFallback=false})
 assert(getNumber(s,"explicitInternal")==1)
end)
case("failed JSON encode copies nothing",function()
 local s=call({}, {encoderThrows=true})
 assert(s:find("REPORT_ENCODING_FAILED",1,true))
end)
case("fuzzy direct raw and display with clear margin",function()
 local s=call({Gingerscope=sample("Gingerscope","Ancient","Gun",false)})
 assert(getNumber(s,"fuzzy")==1)
 assert(getNumber(s,"fuzzyDirectRaw")==1)
 assert(getNumber(s,"fuzzyDirectName")==1)
 assert(getNumber(s,"fuzzyBothDirect")==1)
 assert(getNumber(s,"fuzzyScore400to499")==1)
 assert(getNumber(s,"fuzzyRunnerGap100Plus")==1)
 assert(getNumber(s,"fuzzyScoreReproductionErrors")==0)
end)
case("fuzzy transformed-only matching must not be called direct",function()
 local s=call({Batwing=sample("Batwing","Ancient","Knife",false)})
 assert(getNumber(s,"fuzzy")==1)
 assert(getNumber(s,"fuzzyTransformedOnly")==1)
 assert(getNumber(s,"fuzzyDirectRaw")==0)
 assert(getNumber(s,"fuzzyDirectName")==0)
 assert(getNumber(s,"fuzzyScore300to399")==1)
 assert(getNumber(s,"fuzzyScoreReproductionErrors")==0)
end)
case("Chroma abbreviation transformation is separate from name exactness",function()
 local s=call({SecretChromaKey=sample("Bauble","Godly","Knife",true)})
 assert(getNumber(s,"fuzzy")==1)
 assert(getNumber(s,"transformedCount")==1)
 assert(getNumber(s,"transformedChroma")==1)
 assert(getNumber(s,"transformedNonChroma")==0)
 assert(getNumber(s,"transformedLevel1")==1)
 assert(getNumber(s,"transformedChromaPrefixHint")==1)
 assert(getNumber(s,"transformedNoMatchingLevel")==0)
end)
case("legacy updated suffix removed at level1",function()
 local s=call({SecretLegacyKey=sample("Ginger Luger","Godly","Gun",false)})
 assert(getNumber(s,"fuzzy")==1)
 assert(getNumber(s,"transformedCount")==1)
 assert(getNumber(s,"transformedLevel1")==1)
 assert(getNumber(s,"transformedUpV2Hint")==1)
 assert(getNumber(s,"transformedNonChroma")==1)
end)
case("type suffix needs level2 but should remain unauthenticated",function()
 local s=call({SecretIcewingKey=sample("Icewing","Ancient","Knife",false)})
 assert(getNumber(s,"fuzzy")==1)
 assert(getNumber(s,"transformedCount")==1)
 assert(getNumber(s,"transformedLevel1")==0)
 assert(getNumber(s,"transformedLevel2Only")==1)
 assert(getNumber(s,"transformedNoMatchingLevel")==0)
end)
case("stripping embedded year token never authenticates variant",function()
 local s=call({SecretYearKey=sample("Constellation","Godly","Knife",false,2024)})
 assert(getNumber(s,"fuzzy")==1)
 assert(getNumber(s,"transformedCount")==1)
 assert(getNumber(s,"transformedYearHint")==1)
 assert(getNumber(s,"transformedLevel1")==1)
end)
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
realPrint("STAGE56_ACTUAL_LUA_24_NAMED_400_SEEDED_PASS")
'''

class Stage56NormalizationTests(unittest.TestCase):
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
        for label in ("fuzzyScoreBelow300","fuzzyScore300to399",
                      "fuzzyScore400to499","fuzzyScore500Plus",
                      "fuzzyDirectRaw","fuzzyDirectName","fuzzyBothDirect",
                      "fuzzyTransformedOnly","fuzzyRunnerGap1to20",
                      "fuzzyRunnerGap21to99","fuzzyRunnerGap100Plus",
                      "fuzzyNonUniqueBestScore","fuzzyScoreReproductionErrors",
                      "FUZZY_SCORE_REPRODUCTION_OR_TIE_ANOMALY"):
            self.assertIn(label,s)
        # Regression: aggregate counters MUST be initialized before any client
        # observations or fail-closed terminal status checks access them.
        header=s.split("-- Best-effort local clipboard convenience",1)[0]
        for initialized in (
            "fuzzyScoreBelow300=0","fuzzyScore300to399=0",
            "fuzzyScore400to499=0","fuzzyScore500Plus=0",
            "fuzzyDirectRaw=0","fuzzyDirectName=0","fuzzyBothDirect=0",
            "fuzzyTransformedOnly=0","fuzzyNonUniqueBestScore=0",
            "fuzzyRunnerGap1to20=0","fuzzyRunnerGap21to99=0",
            "fuzzyRunnerGap100Plus=0","fuzzyScoreReproductionErrors=0"
        ):
            self.assertIn(initialized,header)
        self.assertIn("local function auditScore(meta,rec)",s)
        self.assertIn("local function gradeFuzzy(meta,rec,why)",s)
        for name in ("transformedCount=0","transformedChroma=0",
                     "transformedNonChroma=0","transformedLevel1=0",
                     "transformedLevel2Only=0","transformedNoMatchingLevel=0",
                     "transformedYearHint=0","transformedChromaPrefixHint=0",
                     "transformedUpV2Hint=0","transformedNearRunner=0",
                     "transformedNoObviousTokenHint=0"):
            self.assertIn(name,s.split("-- Best-effort local clipboard convenience")[0])
        self.assertIn("local function gradeTransformation(meta,rec,gap)",s)
        self.assertIn("TRANSFORM_CLASSIFICATION_INCONSISTENT",s)

        self.assertIn("if s~=announced then",s)

        for clip in ("local function tryClipboard", "local function copySummary",
                     "tryClipboard(setclipboard,line)",
                     "tryClipboard(toclipboard,line)",
                     'print("[STAGE56] CLIPBOARD_COPIED")',
                     'print("[STAGE56] CLIPBOARD_UNAVAILABLE_COPY_REPORT_FROM_CONSOLE")'):
            self.assertIn(clip,s)
        self.assertIn('local line=marker.." "..result',s)
        self.assertIn('local copied=copySummary(line)',s)
        for forbidden in (':FireServer(', ':InvokeServer(', 'TeleportToPlaceInstance(',
                          'mouse1click(', ':HttpGet(', 'loadstring(', ':PostAsync('):
            self.assertNotIn(forbidden,s)

    @unittest.skipUnless(shutil.which("lua5.4"),"CI installs Lua 5.4")
    def test_real_lua_full_probe_adversarial(self):
        with tempfile.TemporaryDirectory(prefix="stage56_") as td:
            path=Path(td)/"fake_game.lua"
            path.write_text(FAKE_GAME,encoding="utf-8")
            p=subprocess.run(["lua5.4",str(path),str(PROBE)],
                             cwd=ROOT,capture_output=True,text=True,timeout=40)
        self.assertEqual(p.returncode,0,p.stdout+"\n"+p.stderr)
        self.assertIn("STAGE56_ACTUAL_LUA_24_NAMED_400_SEEDED_PASS",p.stdout)

if __name__=="__main__":
    unittest.main()
