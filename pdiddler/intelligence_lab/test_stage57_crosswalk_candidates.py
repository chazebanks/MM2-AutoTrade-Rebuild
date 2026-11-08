"""Stage57: test the REAL read-only Lua catalogue mapping census against fake game objects.
No Delta remote invocation, item value authority, trade acceptance, or external connection.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
PROBE=ROOT/"pdiddler/new_part4/STAGE57_READONLY_CROSSWALK_CANDIDATES.lua"

FAKE_GAME=r'''
local probe=arg[1]
local realPrint,realRequire,realSetclipboard,realToclipboard,realGetgenv=
 print,require,setclipboard,toclipboard,getgenv
local realInstance,realUDim2,realUDim,realVector2,realColor3,realEnum=
 Instance,UDim2,UDim,Vector2,Color3,Enum
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
 local created={}
 local players=nil
 if opts.uiMock or opts.uiMockThrow then
  local gui={FindFirstChild=function()return nil end}
  players={LocalPlayer={FindFirstChildOfClass=function(_,class)
   if class=="PlayerGui" then return gui end
  end}}
  Instance={new=function(kind)
   if opts.uiMockThrow then error("SECRET_GUI_ERROR") end
   local o={Kind=kind}
   function o:IsA(x)return self.Kind==x end
   function o:Destroy()self.Parent=nil end
   if kind=="TextButton" then
    o.Activated={Connect=function(_,callback)o.onClose=callback end}
   end
   created[#created+1]=o
   return o
  end}
  local function shape(...)
   return {mockGeometry=true}
  end
  UDim2={new=shape,fromOffset=shape}
  UDim={new=shape}
  Vector2={new=shape}
  Color3={fromRGB=shape}
  Enum={Font={Gotham="Gotham",GothamBold="GothamBold"},
        TextXAlignment={Left="Left"},TextYAlignment={Top="Top"}}
 else Instance=nil;UDim2=nil;UDim=nil;Vector2=nil;Color3=nil;Enum=nil end
 local module={payload=sync}
 local db={FindFirstChild=function(_,key)
  if key=="Sync" and not opts.noSync then return module end
 end}
 local rs={FindFirstChild=function(_,key)
  if key=="Database" then return db end
 end}
 local function jsonVal(value,forceArray)
 local kind=type(value)
 if kind=="string" then return string.format("%q",value) end
 if kind=="number" or kind=="boolean" then return tostring(value) end
 if kind~="table" then error("unexpected field type") end
 local arr=#value>0 or forceArray==true
 local out={}
 if arr then
  for i=1,#value do out[#out+1]=jsonVal(value[i]) end
  return "["..table.concat(out,",").."]"
 end
 for k,x in pairs(value) do
  local v=jsonVal(x,k=="candidateItems")
  out[#out+1]=string.format("%q:%s",tostring(k),v)
 end
 table.sort(out)
 return "{"..table.concat(out,",").."}"
end
local http={JSONEncode=function(_,v)
 if opts.encoderThrows then error("SECRET_JSON_ERROR") end
 return jsonVal(v)
end}
 game={PlaceId=opts.place or 142823291,JobId="SECRET_JOB_ID",
  GetService=function(_,key)
   if key=="Players" then return players end
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
 Instance=realInstance;UDim2=realUDim2;UDim=realUDim
 Vector2=realVector2;Color3=realColor3;Enum=realEnum
 assert(ok,err)
 local reportLines,guideLines,clipboardLines={},{},{}
 for _,ln in ipairs(written) do
  if ln:find("[GINGERSCOPE STAGE57 CROSSWALK CANDIDATES]",1,true)==1 then
   reportLines[#reportLines+1]=ln
  elseif ln:find("[STAGE57 GUIDE]",1,true)==1 then
   guideLines[#guideLines+1]=ln
  elseif ln:find("[STAGE57] CLIPBOARD_",1,true)==1 then
   clipboardLines[#clipboardLines+1]=ln end
 end
 assert(#reportLines==1,"one anonymous report expected")
 assert(#guideLines>=2,"runtime steps and completion/failure instruction missing")
 assert(guideLines[1]:find("STEP 1/2",1,true),"runtime step1 missing")
 if opts.uiMock then
  local screen,body=nil,nil
  for _,v in ipairs(created) do
   if v.Kind=="ScreenGui" then screen=v end
   if v.Kind=="TextLabel" and v.Text~="STAGE 57  |  CATALOG REVIEW" then body=v end
  end
  assert(screen and screen.Parent~=nil,"persistent in-game instruction screen missing")
  assert(body and body.Text:find("PASTE",1,true),"on-screen final action missing")
 end
 local s=reportLines[1]
 if opts.encoderThrows then
  assert(#clipboardLines==0,"failed JSON may not print a copy success")
  assert(guideLines[#guideLines]:find("could not encode",1,true),
    "failed encode must instruct user on next action")
  assert(s:find("REPORT_ENCODING_FAILED",1,true),"missing JSON failure")
  assert(#copied==0,"unencoded data must never reach clipboard")
  return s
 end
 assert(#clipboardLines==1,"one copied/unavailable status line required")
 assert(guideLines[#guideLines]:find("PASTE",1,true),
  "the operator must receive an explicit in-session paste instruction")
 local expectCopy=(primaryAvailable and not opts.primaryThrows and not opts.primaryReturnsFalse)
  or opts.clipboardFallback==true or opts.envClipboard==true
 if expectCopy then
  assert(#copied==1 and copied[1]==s,"clipboard must equal only anonymized report")
  assert(clipboardLines[1]=="[STAGE57] CLIPBOARD_COPIED",
   "missing successful clipboard status")
 else
  assert(#copied==0,"clipboard unexpectedly modified")
  assert(clipboardLines[1]=="[STAGE57] CLIPBOARD_UNAVAILABLE_COPY_REPORT_FROM_CONSOLE",
   "console fallback status missing")
 end
 for _,bad in ipairs({"SECRET_JOB_ID","SECRET_ALTERNATE_JOB",
                      "SECRET_ARTWORK_ASSET","SECRET_CLIPBOARD_ERROR",
                      "http://","https://"})do
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
case("in-game persistent instruction panel shows next action",function()
 local s=call({Bioblade=sample("Bioblade","Godly","Knife",false)},{uiMock=true})
 assert(getNumber(s,"eligible")==1)
end)
case("UI unavailable fails safely to readable console instructions",function()
 local s=call({Bioblade=sample("Bioblade","Godly","Knife",false)},{uiMockThrow=true})
 assert(getNumber(s,"eligible")==1)
end)
case("only level2 game catalogue metadata is exported",function()
 local s=call({SecretIcewingKey=sample("Icewing","Ancient","Knife",false)})
 assert(getNumber(s,"evidenceCandidateCount")==1)
 assert(getNumber(s,"evidenceExportedCount")==1)
 assert(s:find('"rawKey":"SecretIcewingKey"',1,true),"no exact raw catalogue key")
 assert(s:find('"checkerId":"4"',1,true),"wrong checker identity")
 assert(s:find('"secondLevel":true',1,true),"level2 reason missing")
 assert(s:find('"sourceYear":""',1,true),"missing source field must stay empty")
 assert(s:find('"tradeOutcome":"UNKNOWN"',1,true))
end)
case("two placeholder aliases only, no trade inventory reads",function()
 local s=call({
   SecretMortal=sample("Mortal","Godly","Knife",true),
   SecretImmortal=sample("Immortal","Godly","Gun",true)})
 assert(getNumber(s,"evidenceCandidateCount")==2)
 assert(getNumber(s,"evidenceExportedCount")==2)
 assert(s:find('"placeholderArt":true',1,true))
 assert(s:find('"checkerId":"1033"',1,true))
 assert(s:find('"checkerId":"1034"',1,true))
end)
case("malformed game-only key cannot be silently exported",function()
 local s=call({["Secret/InjectedKey"]=sample("Mortal","Godly","Knife",true)})
 status(s,"CANDIDATE_EXPORT_NOT_COMPLETE")
 assert(getNumber(s,"evidenceUnsafeFields")==1)
 assert(getNumber(s,"evidenceExportedCount")==0)
 assert(s:find('"candidateItems":[]',1,true),"no partial candidate details allowed")
 assert(not s:find("Secret/InjectedKey",1,true),"invalid key leaked")
end)
case("deterministic review sort regardless of catalogue traversal",function()
 local a=call({ZZZ_Immortal=sample("Immortal","Godly","Gun",true),
              AAA_Mortal=sample("Mortal","Godly","Knife",true)})
 local b=call({AAA_Mortal=sample("Mortal","Godly","Knife",true),
              ZZZ_Immortal=sample("Immortal","Godly","Gun",true)})
 assert(a==b,"review ordering must be deterministic")
end)
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
realPrint("STAGE57_ACTUAL_LUA_28_NAMED_400_SEEDED_PASS")
'''

class Stage57CandidateEvidenceTests(unittest.TestCase):
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
        for mandatory in (
            'R.evidenceCandidateCount=#candidateKeys',
            'R.evidenceExportedCount=#R.candidateItems',
            'if i<=12 then R.candidateItems[#R.candidateItems+1]=candidates[key]',
            'return emit("CANDIDATE_EXPORT_NOT_COMPLETE")',
            'row.secondLevel=true', 'row.placeholderArt=true',
            'row.nearRunner=true', 'local function cleanText',
            'local function appendEvidence'):
            self.assertIn(mandatory,s)
        self.assertNotIn('GetProfileData',s)
        self.assertNotIn('Players:GetPlayers',s)

        for term in ("local function buildInstructionPanel()",
                     'screen.Name="GINGERSCOPE_STAGE57_INSTRUCTIONS"',
                     "local function tellOperator(message)",
                     'tellOperator("STEP 1/2:',
                     'tellOperator("STEP 2/2:',
                     "TEST DONE. Selected game-catalog evidence copied.",
                     "Clipboard unavailable. Open Delta console",
                     'local copied=copySummary(line)'):
            with self.subTest(term=term):
                self.assertIn(term,s)

        self.assertIn("if s~=announced then",s)

        for clip in ("local function tryClipboard", "local function copySummary",
                     "tryClipboard(setclipboard,line)",
                     "tryClipboard(toclipboard,line)",
                     'print("[STAGE57] CLIPBOARD_COPIED")',
                     'print("[STAGE57] CLIPBOARD_UNAVAILABLE_COPY_REPORT_FROM_CONSOLE")'):
            self.assertIn(clip,s)
        self.assertIn('local line=marker.." "..result',s)
        self.assertIn('local copied=copySummary(line)',s)
        for forbidden in (':FireServer(', ':InvokeServer(', 'TeleportToPlaceInstance(',
                          'mouse1click(', ':HttpGet(', 'loadstring(', ':PostAsync('):
            self.assertNotIn(forbidden,s)

    @unittest.skipUnless(shutil.which("lua5.4"),"CI installs Lua 5.4")
    def test_real_lua_full_probe_adversarial(self):
        with tempfile.TemporaryDirectory(prefix="stage57_") as td:
            path=Path(td)/"fake_game.lua"
            path.write_text(FAKE_GAME,encoding="utf-8")
            p=subprocess.run(["lua5.4",str(path),str(PROBE)],
                             cwd=ROOT,capture_output=True,text=True,timeout=40)
        self.assertEqual(p.returncode,0,p.stdout+"\n"+p.stderr)
        self.assertIn("STAGE57_ACTUAL_LUA_28_NAMED_400_SEEDED_PASS",p.stdout)

if __name__=="__main__":
    unittest.main()
