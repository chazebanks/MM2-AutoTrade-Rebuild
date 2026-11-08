"""Stage53: execute the ACTUAL read-only Lua catalogue census against fake MM2.
This deliberately never tests or asserts Supreme checker-ID authentication.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile
import textwrap
import unittest

ROOT = Path(__file__).resolve().parents[2]
PROBE = ROOT / "pdiddler/new_part4/STAGE53_READONLY_CATALOG_OVERWRITE_AUDIT.lua"

LUA_CASES = r'''
local probe=arg[1]
local output={}
local realPrint=print
print=function(s) output[#output+1]=tostring(s) end
local function row(chroma, year, rarity, typ)
 return {ItemName="Mortal",Rarity=rarity or "Godly",
  ItemType=typ or "Knife",Chroma=chroma,Year=year,
  Event="Halloween",ItemID="TestItem",Image="rbxassetid://12345678"}
end
local function call(a,b,settings)
 settings=settings or {}
 output={}
 local sync={Weapons=a,Item=b}
 if settings.sameTable then sync.Item=sync.Weapons end
 local mod={payload=sync}
 local db={FindFirstChild=function(_,key)if key=="Sync" then return mod end end}
 local rs={FindFirstChild=function(_,key)if key=="Database" then return db end end}
 local http={JSONEncode=function(_,value)
  local parts={}
  for k,v in pairs(value)do
   local val
   if type(v)=="string" then val=string.format("%q",v)
   elseif type(v)=="boolean" or type(v)=="number" then val=tostring(v)
   else error("unexpected serialized field") end
   parts[#parts+1]=string.format("%q:%s",k,val)
  end
  table.sort(parts)
  return "{"..table.concat(parts,",").."}"
 end}
 game={
  PlaceId=settings.place or 142823291,
  JobId="SAFE_JOB_INTERNAL",
  GetService=function(_,key)
   if key=="ReplicatedStorage"then return rs end
   if key=="HttpService"then return http end
  end
 }
 if settings.noSync then db.FindFirstChild=function()return nil end end
 local nativeRequire=require
 require=function(o)
  if settings.changeJob then game.JobId="CHANGED_JOB_INTERNAL" end
  if settings.errorRequire then error("SECRET_BOT_TOKEN_SHOULD_NOT_LEAK")end
  return o.payload
 end
 local ok,res=pcall(dofile,probe)
 require=nativeRequire
 assert(ok,res)
 assert(#output==1,"must print exactly one censored report")
 local s=output[1]
 assert(s:find("[GINGERSCOPE STAGE53 CATALOG CENSUS]",1,true),"marker")
 for _,forbidden in ipairs({"SECRET","SAFE_JOB_INTERNAL","CHANGED_JOB_INTERNAL","TestItem","Mortal","12345678","TestRawKey"})do
  assert(not s:find(forbidden,1,true),"privacy leak: "..forbidden)
 end
 assert(s:find('"authorizesTrade":false',1,true))
 assert(s:find('"authorizesAccept":false',1,true))
 assert(s:find('"mappingAuthenticated":false',1,true))
 assert(s:find('"serverCompletionProven":false',1,true))
 assert(s:find('"mayReportProfit":false',1,true))
 assert(s:find('"tradeOutcome":"UNKNOWN"',1,true))
 return s
end
local function check(s,status)
 assert(s:find('"status":"'..status..'"',1,true),status.." missing in "..s)
end
local passed=0
local function case(name,fn)
 local ok,err=pcall(fn)
 if not ok then error(name..": "..tostring(err)) end
 passed=passed+1
end
case("same table",function()
 local t={TestRawKey=row(true,"2024")}
 local s=call(t,t,{sameTable=true})
 check(s,"SAME_TABLE_CLIENT_ONLY")
end)
case("same table still rejects invalid rows",function()
 local t={TestRawKey=123}
 check(call(t,t,{sameTable=true}),"INVALID_CATALOG_SHAPE")
end)
case("optional Sync.Item absent no overwrite",function()
 check(call({TestRawKey=row(true,"2024")},nil),"ITEM_SOURCE_ABSENT_NO_OVERWRITE")
end)
case("complete identical entries",function()
 local s=call({TestRawKey=row(true,"2024")},{TestRawKey=row(true,"2024")})
 check(s,"CLIENT_OVERLAP_CONSISTENT_UNAUTHENTICATED")
 assert(s:find('"exactOverlaps":1',1,true))
end)
case("chroma mismatch",function()
 local s=call({TestRawKey=row(true,"2024")},{TestRawKey=row(false,"2024")})
 check(s,"CATALOG_METADATA_CONFLICT")
end)
case("year mismatch",function()
 local s=call({TestRawKey=row(true,"2023")},{TestRawKey=row(true,"2024")})
 check(s,"CATALOG_METADATA_CONFLICT")
end)
case("rarity mismatch",function()
 local s=call({TestRawKey=row(false,"2023","Ancient")},{TestRawKey=row(false,"2023","Godly")})
 check(s,"CATALOG_METADATA_CONFLICT")
end)
case("itemtype mismatch",function()
 local s=call({TestRawKey=row(true,"2023","Godly","Knife")},{TestRawKey=row(true,"2023","Godly","Gun")})
 check(s,"CATALOG_METADATA_CONFLICT")
end)
case("missing Year cannot become exact",function()
 local s=call({TestRawKey=row(true,"2023")},{TestRawKey=row(true,nil)})
 check(s,"CATALOG_METADATA_PARTIAL")
end)
case("missing image cannot become exact",function()
 local b=row(true,"2024");b.Image=nil
 check(call({TestRawKey=row(true,"2024")},{TestRawKey=b}),"CATALOG_METADATA_PARTIAL")
end)
case("different key is not mapped",function()
 check(call({TestRawKey=row(true,"2024")},{AnotherKey=row(true,"2024")}),"NO_ELIGIBLE_OVERLAP_OBSERVED")
end)
case("numeric-string same printable key",function()
 check(call({[7]=row(true,"2024"),["7"]=row(true,"2024")},{}),"INVALID_CATALOG_SHAPE")
end)
case("invalid data type",function()
 check(call({TestRawKey=123},{}),"INVALID_CATALOG_SHAPE")
end)
case("eligibility disagreement",function()
 check(call({TestRawKey=row(true,"2024")},{TestRawKey=row(false,"2024","Common")}),"CATALOG_METADATA_CONFLICT")
end)
case("wrong place",function()
 check(call({}, {}, {place=1}),"WRONG_GAME")
end)
case("missing sync",function()
 check(call({}, {}, {noSync=true}),"SYNC_MODULE_MISSING")
end)
case("require error censored",function()
 check(call({}, {}, {errorRequire=true}),"SYNC_UNAVAILABLE")
end)
case("server change",function()
 check(call({}, {}, {changeJob=true}),"SERVER_CHANGED")
end)
-- 400 seeded permutations. A contradictory field must never be reported
-- consistent; missing fields must never be promoted to exact matches.
math.randomseed(5308)
for i=1,400 do
 local a=row(true,"2024")
 local b=row(true,"2024")
 local choice=math.random(1,6)
 if choice==1 then b.Chroma=false
 elseif choice==2 then b.Year="2022"
 elseif choice==3 then b.ItemName="IMMORTAL"
 elseif choice==4 then b.ItemType="Gun"
 elseif choice==5 then b.Year=nil
 elseif choice==6 then b.ItemID=nil end
 local s=call({TestRawKey=a},{TestRawKey=b})
 if choice<=4 then check(s,"CATALOG_METADATA_CONFLICT")
 else check(s,"CATALOG_METADATA_PARTIAL") end
end
case("400 seeded source mutations",function() end)
realPrint("STAGE53_ACTUAL_NATIVE_LUA_419_CASES_PASS")
'''

class Stage53CatalogCensusTests(unittest.TestCase):
    def test_real_source_contains_required_guards(self):
        src = PROBE.read_text(encoding="utf-8")
        for needle in (
            'schema="gingerscope-stage53-catalog-overwrite-v1"',
            'mappingAuthenticated=false', 'serverCompletionProven=false',
            'authorizesTrade=false', 'authorizesAccept=false',
            'mayRecordCompletedTrade=false', 'mayReportProfit=false',
            'tradeOutcome="UNKNOWN"',
            'if out[k] then collision=collision+1',
            'if left.eligible~=right.eligible then',
            'elseif match=="PARTIAL" then',
            'if tostring(game.JobId or "")~=initialJob then',
        ):
            with self.subTest(needle=needle):
                self.assertIn(needle, src)
        for forbidden in (':FireServer(', ':InvokeServer(', ':PostAsync(',
                          ':HttpGet(', 'loadstring(', 'mouse1click(',
                          'TeleportToPlaceInstance(', 'getconnections('):
            self.assertNotIn(forbidden,src)
        self.assertNotIn('mappingAuthenticated=true',src)

    @unittest.skipUnless(shutil.which("lua5.4"), "CI installs Lua 5.4")
    def test_actual_lua_full_launcher_with_400_seeded_adversarial_cases(self):
        with tempfile.TemporaryDirectory(prefix="stage53_") as folder:
            p = Path(folder) / "stage53_native_cases.lua"
            p.write_text(LUA_CASES, encoding="utf-8")
            run = subprocess.run(
                ["lua5.4", str(p), str(PROBE)],
                cwd=ROOT, capture_output=True, text=True, timeout=25,
                check=False
            )
        self.assertEqual(run.returncode,0,run.stdout+"\n"+run.stderr)
        self.assertIn("STAGE53_ACTUAL_NATIVE_LUA_419_CASES_PASS",run.stdout)

if __name__=="__main__":
    unittest.main()
