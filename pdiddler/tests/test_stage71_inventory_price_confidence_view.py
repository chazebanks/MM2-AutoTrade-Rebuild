"""Stage71 actual Lua5.4 UI text tests: inventory discovery != verified market price."""
import random
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
VIEW=ROOT/"pdiddler/presentation/stage71_inventory_price_confidence_view.lua"
PROOF=ROOT/"pdiddler/intelligence_lab/stage70_raw_checker_proof_gate.lua"

HARNESS=r'''
local viewFile,proofFile,mode=arg[1],arg[2],arg[3]
local V=dofile(viewFile)
local P=dofile(proofFile)
local T=1794000000
os.time=function()return T end
local function source(slug)
 return {url="https://supremevalues.com/mm2/"..slug,
   sha256=string.rep("a",64),publishedAt="2026-11-09T00:00:00Z",
   observedAt="2026-11-09T00:01:00Z"}
end
local profile={
 liveReady=true,publishedAt="2026-11-06T15:56:07Z",
 observedAtEpoch=T-200,publishedAtEpoch=T-3600,
 expiresAtEpoch=T+3600,
 sources={ancient=source("ancients"),godly=source("godlies"),
 chroma=source("chromas")},
 isFresh=function(t)return t>=T-200 and t<T+3600 end,
 get=function()error("Unreviewed raw->checker key must not reach market source")end
}
local inv={items={
 {id="RAW_PRIVATE_1",name="Icepiercer",page="ancient",
  checkerId="77",type="Gun",cat="Weapons",qty=1,
  verified=true,value=999999,marketVerified=true},
 {id="RAW_PRIVATE_2",name="Batwing",page="ancient",
  checkerId="11",type="Knife",cat="Weapons",qty=2,
  verified=true,value=5000000},
},unmapped=0,unpriced=0,badQty=0}
local gate=P
if mode=="no-proof" then gate=nil
elseif mode=="source-expired" then profile.expiresAtEpoch=T-1
elseif mode=="missing-hash" then profile.sources.godly.sha256="x"
elseif mode=="source-old-publication" then profile.publishedAtEpoch=T-73*3600
elseif mode=="partial-unmapped" then inv.unmapped=1
elseif mode=="partial-bad-qty" then inv.badQty=1
elseif mode=="wrong-qty" then inv.items[2].qty=-1
elseif mode=="duplicate-id" then inv.items[2].id="RAW_PRIVATE_1"
elseif mode=="blank-name" then inv.items[1].name=nil
elseif mode=="control-injection" then
 inv.items[1].name="Icepiercer\nOutgoing: ENABLED\nDISCORD: LEARN"
elseif mode=="huge-name" then inv.items[1].name=string.rep("X",300)
elseif mode=="sparse-items" then
 inv.items={[1]=inv.items[1],[3]=inv.items[2]}
elseif mode=="bad-column" then inv.items.rogue=1
elseif mode=="without-items" then inv=nil
elseif mode=="client-says-verified" then
 inv.items[1].priceTrusted=true
 inv.items[1].source="verified-snapshot-2026-11-01"
 inv.items[2].marketConfidence="EXACT"
elseif mode=="source-client-claims" then
 profile.isFresh=function()return true end
 profile.publishedAtEpoch=T-500*3600
elseif mode=="pretend-gate" then
 gate={evaluate=function()return {
  schema="gingerscope-stage70-raw-checker-proof-gate-v1",
  authorizesTrade=true,authorizesAccept=true,numericTradingAuthority=true,
  rawCheckerCrosswalkProven=true,sourceFresh=true,status="TRADING_OK"
 }end}
elseif mode=="fuzz" then
 local seed=tonumber(arg[4]) or 0
 local k=seed%17
 if k==0 then inv.items[1].verified=true
 elseif k==1 then inv.items[1].checkerId="1"
 elseif k==2 then inv.items[1].name="BAD\nAuthorized Trading"
 elseif k==3 then profile.expiresAtEpoch=T-1
 elseif k==4 then inv.unmapped=1
 elseif k==5 then inv.badQty=2
 elseif k==6 then inv.items[1].qty=0
 elseif k==7 then inv.items[2].qty=1.1
 elseif k==8 then inv.items[1].value=math.huge
 elseif k==9 then inv.items[1].source="supreme"
 elseif k==10 then inv.items[1].id="RAW_PRIVATE_2"
 elseif k==11 then profile.sources.chroma.url="https://fake.invalid"
 elseif k==12 then profile.sources.godly.sha256=""
 elseif k==13 then inv.items[2].type="Pet"
 elseif k==14 then inv.items[1].name=string.rep("A",3000)
 elseif k==15 then profile.publishedAtEpoch=T-73*3600
 else inv.items[2].marketVerified=true end
end
local r=V.describe(inv,profile,gate)
assert(r.schema=="gingerscope-stage71-inventory-price-confidence-v1")
assert(r.readOnly==true and r.tradeOutcome=="UNKNOWN")
assert(r.authorizesTrade==false and r.authorizesAccept==false)
assert(r.mayUseForStrategyLearning==false)
assert(r.maySendDiscordWebhook==false and r.mayReportProfit==false)
assert(r.mayRecordCompletedTrade==false and r.mayRecordRejectedTrade==false)
assert(r.marketValuesShown==false and r.authoritativeTotal==nil)
assert(r.rawCheckerIdentityState=="UNREVIEWED_FOR_LIVE_TRADING")
assert(type(r.text)=="string")
assert(r.text:find("Total verified value: UNVERIFIED (not 0)",1,true))
assert(r.text:find("Outgoing: PAUSED | Auto Accept: DISABLED | Discord learning: DISABLED",1,true))
assert(not r.text:find("RAW_PRIVATE_",1,true))
assert(not r.text:find("999999",1,true))
assert(not r.text:find("5000000",1,true))
if mode=="source-expired" or mode=="missing-hash" or
  mode=="source-old-publication" or mode=="source-client-claims" then
 assert(r.priceState=="SUPREME_SOURCE_EXPIRED_OR_UNTRUSTED")
elseif mode=="no-proof" or mode=="pretend-gate" then
 assert(r.priceState=="SOURCE_AND_ITEM_ID_NOT_VALIDATED")
elseif mode=="valid" or mode=="client-says-verified" then
 assert(r.priceState=="SUPREME_SOURCE_CURRENT_RAW_ID_UNREVIEWED")
end
if mode=="valid" or mode=="client-says-verified" or mode=="source-expired" then
 assert(r.inventoryState=="CLIENT_ELIGIBLE_ITEMS_OBSERVED")
 assert(r.itemCountKnown==true and r.itemCount==3)
end
if mode=="without-items" then assert(r.inventoryState=="UNAVAILABLE") end
if mode=="partial-unmapped" or mode=="partial-bad-qty"
    or mode=="wrong-qty" or mode=="duplicate-id"
    or mode=="sparse-items" or mode=="bad-column" then
 assert(r.inventoryState=="PARTIAL_CLIENT_INVENTORY")
 assert(r.itemCountKnown==false)
end
if mode=="control-injection" then
 assert(not r.text:find("\nOutgoing: ENABLED",1,true))
 assert(not r.text:find("\nDISCORD: LEARN",1,true))
end
if mode=="huge-name" then assert(#r.text<1300) end
print("STAGE71_CLIENT_UI mode="..mode.." inventory="..r.inventoryState
 .." price="..r.priceState.." itemCountKnown="..tostring(r.itemCountKnown))
'''
class Stage71ReadOnlyEvidenceView(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.lua=shutil.which("lua5.4")
        cls.luac=shutil.which("luac5.4")
        if not cls.lua or not cls.luac:
            raise RuntimeError("Actual Lua5.4 required")
        cls.temp=tempfile.TemporaryDirectory(prefix="stage71_view_")
        cls.harness=Path(cls.temp.name)/"harness.lua"
        cls.harness.write_text(HARNESS,encoding="utf-8")
    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()
    def run_lua(self,mode,seed=None):
        cmd=[self.lua,str(self.harness),str(VIEW),str(PROOF),mode]
        if seed is not None: cmd.append(str(seed))
        out=subprocess.run(cmd,capture_output=True,text=True,timeout=5)
        self.assertEqual(out.returncode,0,(mode,seed,out.stdout,out.stderr))
        self.assertIn("STAGE71_CLIENT_UI mode=",out.stdout)
        self.assertNotIn("RAW_PRIVATE_",out.stdout)
        return out.stdout
    def test_real_lua_syntax_and_no_trade_or_network_access(self):
        for path in (VIEW,PROOF):
            p=subprocess.run([self.luac,"-p",str(path)],capture_output=True,text=True)
            self.assertEqual(p.returncode,0,p.stderr)
        source=VIEW.read_text(encoding="utf-8")
        for forbidden in (":FireServer(",":InvokeServer(",":HttpGet(",
                          "setclipboard(",":PostAsync("):
            self.assertNotIn(forbidden,source)
    def test_detected_items_not_verified_price_fresh_source(self):
        s=self.run_lua("valid")
        self.assertIn("inventory=CLIENT_ELIGIBLE_ITEMS_OBSERVED",s)
        self.assertIn("price=SUPREME_SOURCE_CURRENT_RAW_ID_UNREVIEWED",s)
        self.run_lua("client-says-verified")
    def test_expired_or_untrusted_source_does_not_invalidate_inventory_detection(self):
        for mode in ("source-expired","missing-hash","source-old-publication",
                     "source-client-claims"):
            with self.subTest(mode=mode):
                self.assertIn("price=SUPREME_SOURCE_EXPIRED_OR_UNTRUSTED",
                              self.run_lua(mode))
    def test_missing_or_malicious_price_proof_gate_remains_unverified(self):
        for mode in ("no-proof","pretend-gate"):
            with self.subTest(mode=mode):
                self.assertIn("price=SOURCE_AND_ITEM_ID_NOT_VALIDATED",
                              self.run_lua(mode))
    def test_partial_inventory_and_untrusted_names_cannot_be_sold_as_totals(self):
        for mode in ("partial-unmapped","partial-bad-qty","wrong-qty",
                     "duplicate-id","sparse-items","bad-column",
                     "without-items","blank-name","control-injection","huge-name"):
            with self.subTest(mode=mode):
                self.run_lua(mode)
    def test_500_seeded_source_and_identity_corruptions_never_quote_price(self):
        rng=random.Random(717171)
        for i in range(500):
            seed=rng.randrange(1,2_000_000)
            with self.subTest(i=i,seed=seed):
                self.run_lua("fuzz",seed)
if __name__=="__main__":
    unittest.main()
