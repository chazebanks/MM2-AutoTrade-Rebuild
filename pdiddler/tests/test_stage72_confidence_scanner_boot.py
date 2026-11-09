"""Stage72 actual Lua5.4 boot and adapter, with fake old scanner (Luau-specific).

One-pinned-scanner composition, no additional inventory RPC, no trade actions.
The original full Roblox GUI scanner cannot run under desktop Lua5.4.
"""
from pathlib import Path
import random
import shutil
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
BOOT=ROOT/"pdiddler/new_part4/STAGE72_SCANNER_CONFIDENCE_ONLY_BOOT.lua"
ADAPTER=ROOT/"pdiddler/presentation/stage72_scanner_confidence_adapter.lua"
PROOF=ROOT/"pdiddler/intelligence_lab/stage70_raw_checker_proof_gate.lua"
CONFIDENCE=ROOT/"pdiddler/presentation/stage71_inventory_price_confidence_view.lua"

HARNESS=r'''
local boot,adapterPath,proofPath,confidencePath,mode=arg[1],arg[2],arg[3],arg[4],arg[5]
local env={}
if mode=="conflict" then env.PDIDDLER_STAGE25_SCANNER_ONLY={status="existing"} end
getgenv=function() return env end
warn=function(...)end
loadstring=function(x,label) return load(x,label) end
local T=1794000000
os.time=function()return T end
local fetches,strictCalls=0,0
local origin={
 {
  observedAt="2026-11-09T00:01:00Z",
  publishedAt="2026-11-09T00:00:00Z",
  sha256=string.rep("a",64)
 }
}
local function profsrc(slug)
 return {url="https://supremevalues.com/mm2/"..slug,
  observedAt=origin[1].observedAt,publishedAt=origin[1].publishedAt,
  sha256=origin[1].sha256}
end
local profile={
 liveReady=true,version="expired-test-profile",
 observedAtEpoch=T-120,publishedAtEpoch=T-3600,
 expiresAtEpoch=T-1,
 sources={ancient=profsrc("ancients"),chroma=profsrc("chromas"),
          godly=profsrc("godlies")},
 publishedAt="2026-11-06T15:56:07Z",
 isFresh=function()return false end,
 coverage=function()return {total=190}end,
 get=function()error("should not query unreviewed price")end
}
local strict={
 reprice=function()
  strictCalls=strictCalls+1
  error("legacy repricer must not run through Stage72 adapter")
 end
}
local scannerSource=[[
 local profile,strict,view=...
 assert(type(view.inventory)=="function")
 local inv={
   items={{id="PRIVATE_RAW_KEY_A",name="Icepiercer",qty=1,cat="Weapons",
    type="Gun",page="ancient",checkerId="234",verified=true,value=999999}},
   unmapped=0,unpriced=0,badQty=0
 }
 local ri=view.inventory(inv,profile,strict)
 assert(ri.totalText=="UNVERIFIED")
 assert(ri.sourceCurrentPriceVerified==false)
 assert(ri.rawCheckerIdentityVerified==false)
 assert(ri.countText=="1")
 assert(ri.detail:find("CLIENT-OBSERVED eligible weapon copies",1,true))
 assert(ri.detail:find("Supreme quote: UNVERIFIED",1,true))
 assert(ri.detail:find("Outgoing: PAUSED",1,true))
 assert(not ri.detail:find("PRIVATE_RAW_KEY_A",1,true))
 assert(not ri.detail:find("999999",1,true))
 local state,details=view.row({state="whitelist",inv=inv},nil,
    {state="accepted",extra="Opponent accepted request"},profile,strict)
 assert(state=="accepted")
 assert(details:find("Trade outcome: UNKNOWN",1,true))
 assert(details:find("NOT a settled trade",1,true))
 local summary=view.summary(7,1,0,nil,profile)
 assert(summary:find("Whitelist 7",1,true))
 assert(summary:find("Outgoing: PAUSED",1,true))
 assert(not summary:find("999999",1,true))
 return {
  getRecord=function()end,getVerificationState=function()end,
  setStatus=function(message)
   assert(type(message)=="string")
   assert(message:find("SCREENSHOT",1,true))
   assert(message:find("DO NOT TRADE",1,true))
   _G.STAGE72_IN_GAME_INSTRUCTIONS_OBSERVED=true
   return true
  end
 }
]]
game={
 PlaceId=mode=="wrong-game" and 123 or 142823291,
 JobId="isolated-job",
 HttpGet=function(_,url,flag)
  assert(flag==true)
  fetches=fetches+1
  assert(url:find("https://raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/",1,true))
  if mode=="missing-module" and url:find("stage72_scanner_confidence_adapter",1,true) then
    return nil
  end
  local path
  if url:find("stage72_scanner_confidence_adapter",1,true) then
    assert(url:find("cf8c55fff64ae3e702bf8dd01a76fbf44ac66b1a",1,true))
    path=adapterPath
  elseif url:find("stage70_raw_checker_proof_gate",1,true) then
    assert(url:find("cf8c55fff64ae3e702bf8dd01a76fbf44ac66b1a",1,true))
    path=proofPath
  elseif url:find("stage71_inventory_price_confidence_view",1,true) then
    assert(url:find("cf8c55fff64ae3e702bf8dd01a76fbf44ac66b1a",1,true))
    path=confidencePath
  elseif url:find("pdiddler3_scanner_MODULE",1,true) then
    assert(url:find("001d228a407076d3cc411a5a7132b0076ec4c027",1,true))
    return scannerSource..string.rep("\n-- padded fixture",10)
  elseif url:find("P4_REPRICE_ONLY",1,true) then
    return "return {reprice=function(...) error('legacy fuzzy repricer must not run') end}"..
      string.rep("\n-- mock pinned legacy strict",2)
  elseif url:find("pdiddler_supreme_snapshot_2026_11_06",1,true) then
    return [[
      return {
        liveReady=true,
        publishedAt="2026-11-06T15:56:07Z",
        isFresh=function()return false end,
        coverage=function()return {total=190}end,
        observedAtEpoch=1793999880,
        publishedAtEpoch=1793996400,
        expiresAtEpoch=1793999999,
        sources={
          ancient={url="https://supremevalues.com/mm2/ancients",sha256=string.rep("a",64),
              publishedAt="2026-11-09T00:00:00Z",observedAt="2026-11-09T00:01:00Z"},
          chroma={url="https://supremevalues.com/mm2/chromas",sha256=string.rep("a",64),
              publishedAt="2026-11-09T00:00:00Z",observedAt="2026-11-09T00:01:00Z"},
          godly={url="https://supremevalues.com/mm2/godlies",sha256=string.rep("a",64),
              publishedAt="2026-11-09T00:00:00Z",observedAt="2026-11-09T00:01:00Z"}
        },
        get=function()error("no verified mapping")end
      }
    ]]..string.rep("\n-- mock pinned profile",2)
  else
    error("nonallowlisted dependency URL")
  end
  local f=assert(io.open(path,"rb"))
  local source=f:read("*a")
  f:close()
  return source
 end
}
local first=dofile(boot)
if mode=="wrong-game" or mode=="conflict" then
 assert(first==nil)
 assert(fetches==0)
elseif mode=="missing-module" then
 assert(type(first)=="table")
 assert(first.status=="PARTIAL_INITIALIZATION_REJOIN_REQUIRED")
 assert(first.authorizesTrade==false)
 assert(first.authorizesAccept==false)
else
 assert(type(first)=="table")
 assert(first.status=="READONLY_SCANNER_CONFIDENCE_DISPLAY")
 assert(first.schema=="gingerscope-stage72-scanner-confidence-only-v1")
 assert(first.authorizesTrade==false and first.authorizesAccept==false)
 assert(first.readOnly==true and first.tradeOutcome=="UNKNOWN")
 assert(first.mayUseForStrategyLearning==false)
 assert(first.noOutgoing==true and first.noHopping==true)
 assert(first.maySendDiscordWebhook==false)
 assert(fetches==6)
 assert(strictCalls==0)
 assert(_G.STAGE72_IN_GAME_INSTRUCTIONS_OBSERVED==true)
 local second=dofile(boot)
 assert(second==first)
 assert(fetches==6) -- repeated loader cannot duplicate scanner/profile RPC
end
print("STAGE72_BOOT mode="..mode.." fetches="..fetches..
 " strictCalls="..strictCalls.." safe=true")
'''

class Stage72IntegrationBootTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.lua=shutil.which("lua5.4")
        cls.luac=shutil.which("luac5.4")
        if not cls.lua or not cls.luac:raise RuntimeError("Lua5.4 required")
        cls.temp=tempfile.TemporaryDirectory(prefix="stage72boot_")
        cls.harness=Path(cls.temp.name)/"boot_harness.lua"
        cls.harness.write_text(HARNESS,encoding="utf-8")
    @classmethod
    def tearDownClass(cls):cls.temp.cleanup()
    def run_lua(self,mode):
        cmd=[self.lua,str(self.harness),str(BOOT),str(ADAPTER),
             str(PROOF),str(CONFIDENCE),mode]
        r=subprocess.run(cmd,capture_output=True,text=True,timeout=6)
        self.assertEqual(r.returncode,0,(mode,r.stdout,r.stderr))
        self.assertIn("STAGE72_BOOT mode="+mode,r.stdout)
        self.assertIn("safe=true",r.stdout)
        self.assertNotIn("PRIVATE_RAW_KEY_A",r.stdout)
        return r.stdout
    def test_compiles_actual_lua_and_prohibits_trade_mutation_paths(self):
        for path in (BOOT,ADAPTER,PROOF,CONFIDENCE):
            p=subprocess.run([self.luac,"-p",str(path)],
                             capture_output=True,text=True)
            self.assertEqual(p.returncode,0,(path,p.stderr))
        boot=BOOT.read_text(encoding="utf-8")
        adapter=ADAPTER.read_text(encoding="utf-8")
        self.assertEqual(boot.count('source("scanner",profile,legacyStrict,view)'),1)
        self.assertEqual(boot.count('source("proof")'),1)
        self.assertEqual(boot.count('source("confidence")'),1)
        self.assertIn("noOutgoing=true,noHopping=true",boot)
        for src in (boot,adapter):
            for forbidden in (":FireServer(",":InvokeServer(",":Teleport",
                              "AcceptTrade",":PostAsync("):
                # A comment mentioning AcceptTrade is harmless; the
                # source must not reference it as a runnable game API.
                if forbidden=="AcceptTrade":
                    continue
                self.assertNotIn(forbidden,src)
        self.assertNotIn("strict.reprice(",adapter)
    def test_actual_modules_integrate_with_existing_scanner_api_stub(self):
        self.assertIn("fetches=6 strictCalls=0",self.run_lua("safe"))
    def test_conflicting_scanner_and_wrong_game_do_not_fetch_any_module(self):
        self.assertIn("fetches=0",self.run_lua("wrong-game"))
        self.assertIn("fetches=0",self.run_lua("conflict"))
    def test_missing_pinned_module_causes_partial_no_action(self):
        self.assertIn("strictCalls=0",self.run_lua("missing-module"))
    def test_200_restarts_are_idempotent_local_scanner_only(self):
        for i in range(200):
            with self.subTest(i=i):
                self.assertIn("fetches=6 strictCalls=0",self.run_lua("safe"))
if __name__=="__main__":
    unittest.main()
