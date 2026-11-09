"""Stage72 actual Lua5.4 historical reference preview, never trading authority."""
from __future__ import annotations
import random
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
LUA=ROOT/"pdiddler/intelligence_lab/stage72_historical_reference_preview.lua"
SNAPSHOT=ROOT/"pdiddler/snapshots/pdiddler_supreme_snapshot_2026_11_06.lua"
MOCK=r'''
local mode,script,snapshot=arg[1],arg[2],arg[3]
os.time=function()return 1794201000 end
local P=assert(dofile(snapshot))
local V=assert(dofile(script))
local inv={items={
 {id="RAW_A",name="Gingerscope",page="ancient",cat="Weapons",
   type="Gun",qty=1},
 {id="RAW_B",name="Candleflame",page="godly",cat="Weapons",
   type="Knife",qty=1},
 {id="RAW_C",name="Chroma Candleflame",page="chroma",cat="Weapons",
   type="Knife",qty=1},
 {id="RAW_D",name="Emberbow",page="ancient",cat="Weapons",
   type="Gun",qty=1}
}}
if mode=="alias" then inv.items[1].name="GSCOPE"
elseif mode=="wrong-page" then inv.items[1].page="godly"
elseif mode=="bad-chroma" then inv.items[3].name="Candleflame"
elseif mode=="wrong-category" then inv.items[1].cat="Pets"
elseif mode=="wrong-type" then inv.items[1].type="Pet"
elseif mode=="bad-qty" then inv.items[1].qty=1.5
elseif mode=="huge-qty" then inv.items[1].qty=10^12
elseif mode=="duplicate-id" then inv.items[2].id=inv.items[1].id
elseif mode=="sparse" then inv.items={[1]=inv.items[1],[3]=inv.items[3]}
elseif mode=="foreign-key" then inv.items.extra=inv.items[1]
elseif mode=="empty" then inv.items={}
elseif mode=="source-missing" then P.sources.ancient=nil
elseif mode=="source-bad-url" then P.sources.godly.url="https://fake.invalid"
elseif mode=="source-future-observed" then P.observedAtEpoch=1800000000
elseif mode=="source-bad-version" then P.version=nil
elseif mode=="source-too-new-expiry" then P.expiresAtEpoch=1800000000
elseif mode=="duplicate-source" then
 P.profiles["ancient:EXTRA"]={
   page="ancient",id="123456",name="Gingerscope",
   sourceName="Gingerscope",supremeValue=999
 }
elseif mode=="source-price-nan" then
 P.profiles["ancient:771"].supremeValue=0/0
elseif mode=="client-fake-value" then
 inv.items[1].value=2^60
 inv.items[1].verified=true
 inv.items[1].checkerId="NOT_THE_SAME_ID"
 inv.items[1].marketVerified=true
elseif mode=="client-fake-verified" then
 inv.items[3].verified=true
 inv.items[3].rawCheckerCrosswalkProven=true
elseif mode=="fuzz" then
 local seed=tonumber(arg[4]) or 0
 local n=seed%17
 if n==0 then inv.items[1].name="Bad Item"
 elseif n==1 then inv.items[3].name="Candleflame"
 elseif n==2 then inv.items[1].page="chroma"
 elseif n==3 then inv.items[1].type="Pet"
 elseif n==4 then inv.items[2].id="RAW_A"
 elseif n==5 then inv.items[2].qty=0
 elseif n==6 then P.sources.godly.url="https://fake.invalid"
 elseif n==7 then P.profiles["ancient:771"].supremeValue=-100
 elseif n==8 then inv.items[1].checkerId="99999999"
 elseif n==9 then inv.items[1].verified=true
 elseif n==10 then inv.items[1].value=9999999
 elseif n==11 then P.observedAtEpoch=1800000000
 elseif n==12 then P.version=nil
 elseif n==13 then P.expiresAtEpoch=1800000000
 elseif n==14 then inv.items[1].name="Emberbow"
 elseif n==15 then inv.items[1].qty=0/0
 else P.sources.ancient.sha256="bad" end
end
local R=V.preview(inv,P)
assert(type(R)=="table")
assert(R.schema=="gingerscope-stage72-indicative-historical-view-v1")
assert(R.readOnly==true)
assert(R.outgoingPaused==true)
assert(R.totalText=="UNVERIFIED" and R.portfolioTotal==nil)
assert(R.valuedInventoryComplete==false)
assert(R.sourceAuthenticityProven==false)
assert(R.identityMappingVerified==false)
assert(R.sourceCurrentVerified==false)
assert(R.numericTradingAuthority==false)
assert(R.authorizesTrade==false and R.authorizesAccept==false)
assert(R.mayReportProfit==false)
assert(R.mayRecordCompletedTrade==false)
assert(R.mayRecordRejectedTrade==false)
assert(R.mayUseForStrategyLearning==false)
assert(R.maySendDiscordWebhook==false)
for _,line in ipairs(R.rows) do
 assert(not line:find("VERIFIED TOTAL",1,true))
 assert(not line:find("TRADE ALLOWED",1,true))
 assert(line:find("UNVERIFIED",1,true))
end
local bads={
 ["wrong-category"]=true,["wrong-type"]=true,["bad-qty"]=true,
 ["huge-qty"]=true,["duplicate-id"]=true,["sparse"]=true,
 ["foreign-key"]=true,["source-missing"]=true,
 ["source-bad-url"]=true,["source-future-observed"]=true,
 ["source-bad-version"]=true,["source-too-new-expiry"]=true,
 ["duplicate-source"]=true
}
if mode=="base" or mode=="client-fake-value"
   or mode=="client-fake-verified" then
 assert(R.status=="HISTORICAL_REFERENCE_ONLY")
 assert(R.historicalReferenceCount==4)
 assert(R.unmatchedCount==0)
 assert(#R.rows==4)
 assert(R.sourceExpired==true)
 assert(R.rows[1]:find("16000",1,true)~=nil)
 assert(R.rows[4]:find("400",1,true)~=nil)
elseif mode=="empty" then
 assert(R.historicalReferenceCount==0 and #R.rows==0)
elseif mode=="source-price-nan" then
 assert(R.historicalReferenceCount==3 and R.unmatchedCount==1)
elseif mode=="alias" or mode=="wrong-page" or mode=="bad-chroma" then
 assert(R.historicalReferenceCount==3 and R.unmatchedCount==1)
elseif bads[mode] then
 assert(#R.rows==0)
 assert(R.historicalReferenceCount==0)
elseif mode=="fuzz" then
 -- All mutated input patterns must stay explicitly UNVERIFIED and nontrading.
 assert(R.totalText=="UNVERIFIED" and R.authorizesTrade==false)
end
print("STAGE72_PREVIEW mode="..mode..
 " refs="..R.historicalReferenceCount..
 " unmatched="..R.unmatchedCount..
 " status="..R.status..
 " outgoingPaused="..tostring(R.outgoingPaused))
'''
class Stage72ActualLuaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.lua=shutil.which("lua5.4")
        cls.luac=shutil.which("luac5.4")
        if not cls.lua or not cls.luac:
            raise RuntimeError("Native Lua5.4 required for Stage72")
        cls.temp=tempfile.TemporaryDirectory(prefix="stage72_preview_")
        cls.harness=Path(cls.temp.name)/"preview.lua"
        cls.harness.write_text(MOCK,encoding="utf-8")
    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()
    def invoke(self,mode,seed=None):
        cmd=[self.lua,str(self.harness),mode,str(LUA),str(SNAPSHOT)]
        if seed is not None:
            cmd.append(str(seed))
        r=subprocess.run(cmd,capture_output=True,text=True,timeout=5)
        self.assertEqual(r.returncode,0,(mode,seed,r.stdout[-500:],r.stderr[-1500:]))
        self.assertIn("STAGE72_PREVIEW",r.stdout)
        self.assertIn("outgoingPaused=true",r.stdout)
        self.assertNotIn("RAW_A",r.stdout)
        return r.stdout
    def test_actual_module_compiles_and_has_no_game_side_effects(self):
        for p in (LUA,SNAPSHOT):
            q=subprocess.run([self.luac,"-p",str(p)],
                             capture_output=True,text=True)
            self.assertEqual(q.returncode,0,(str(p),q.stderr))
        source=LUA.read_text(encoding="utf-8")
        for word in ("FireServer(", "InvokeServer(", "HttpGet(", "setclipboard(",
                     "request(", "DiscordWebhook(", "getgenv(", "OfferItem",
                     "AcceptTrade", "mayUseForStrategyLearning=true"):
            self.assertNotIn(word,source)
    def test_old_pinned_sixth_nov_snapshot_displays_not_trading_quote(self):
        out=self.invoke("base")
        self.assertIn("refs=4 unmatched=0",out)
        self.assertIn("status=HISTORICAL_REFERENCE_ONLY",out)
    def test_alias_chroma_and_page_ambiguities_are_not_matched(self):
        for mode in ("alias","wrong-page","bad-chroma","source-price-nan"):
            with self.subTest(mode=mode):
                self.assertIn("refs=3 unmatched=1",self.invoke(mode))
    def test_client_forged_checker_and_price_flags_never_change_status(self):
        for mode in ("client-fake-value","client-fake-verified"):
            with self.subTest(mode=mode):
                self.assertIn("refs=4 unmatched=0",self.invoke(mode))
    def test_invalid_rows_future_source_and_duplicate_names_fail_closed(self):
        for mode in ("wrong-category","wrong-type","bad-qty","huge-qty",
                     "duplicate-id","sparse","foreign-key","source-missing",
                     "source-bad-url","source-future-observed",
                     "source-bad-version","source-too-new-expiry",
                     "duplicate-source"):
            with self.subTest(mode=mode):
                self.assertIn("refs=0",self.invoke(mode))
    def test_empty_inv_never_claims_numeric_total(self):
        self.assertIn("refs=0",self.invoke("empty"))
    def test_300_seeded_mutated_observations_do_not_gain_trading_authority(self):
        rng=random.Random(727272)
        for i in range(300):
            seed=rng.randrange(0,10000000)
            self.assertIn("outgoingPaused=true",self.invoke("fuzz",seed))
if __name__=="__main__":
    unittest.main()
