"""Stage82 full pinned public game→official Supreme website slug registry tests."""
from __future__ import annotations

from copy import deepcopy
import importlib.util
import json
import os
from pathlib import Path
import random
import unittest

ROOT=Path(__file__).resolve().parents[2]
MODULE=ROOT/"pdiddler/intelligence_lab/stage82_public_source_slug_resolver.py"
spec=importlib.util.spec_from_file_location("stage82",MODULE)
m=importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

class Stage82(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        paths=("STAGE82_GAME","STAGE82_ROSTER","STAGE82_ANCIENTS",
               "STAGE82_GODLIES","STAGE82_CHROMAS",
               "STAGE82_STAGE77","STAGE82_STAGE81")
        if any(not os.environ.get(k) for k in paths):
            if os.environ.get("STAGE82_REQUIRE_PINNED")=="1":
                raise AssertionError("focused CI requires every actual immutable public source")
            cls.sources=None
            return
        cls.sources=(
            Path(os.environ["STAGE82_GAME"]).read_bytes(),
            Path(os.environ["STAGE82_ROSTER"]).read_bytes(),
            {
                "ancient":Path(os.environ["STAGE82_ANCIENTS"]).read_bytes(),
                "godly":Path(os.environ["STAGE82_GODLIES"]).read_bytes(),
                "chroma":Path(os.environ["STAGE82_CHROMAS"]).read_bytes(),
            },
            Path(os.environ["STAGE82_STAGE77"]).read_bytes(),
            Path(os.environ["STAGE82_STAGE81"]).read_bytes(),
        )
        cls.registry=m.build(*cls.sources)
        if cls.registry["status"]!="PUBLIC_GAME_KEY_TO_WEBSITE_SLUG_CANDIDATES_ONLY":
            raise AssertionError("actual six-source registry failed: "+str(cls.registry))

    def src(self):
        if self.sources is None: self.skipTest("actual archive fixtures only in dedicated CI")
        return self.sources

    def closed(self,r):
        self.assertIs(r["readOnly"],True)
        self.assertIs(r["researchOnly"],True)
        self.assertEqual(r["tradeOutcome"],"UNKNOWN")
        for flag in (
            "actualOwnedInventoryRead","serverAttestation",
            "authenticatedOwnedInventory","currentGameCatalogueAuthenticated",
            "websiteOriginServerAttested","currentPricesVerified","sourcePublisherFresh",
            "numericSupremeCheckerIdVerified","currentOwnedRawToMarketSlugVerified",
            "rawGameToNumericCheckerVerified","authorizesTrade","authorizesAccept",
            "mayRecordCompletedTrade","mayRecordRejectedTrade",
            "mayReportProfit","maySendDiscordWebhook","mayUseForStrategyLearning",
            "serverCompletionProven"
        ):
            self.assertIs(r[flag],False,flag)

    def test_six_actual_pinned_sources_and_full_189_candidates(self):
        r=self.registry
        self.assertEqual(r["matchingPublicGameWeaponKeys"],189)
        self.assertEqual(len(r["candidates"]),189)
        self.assertEqual(r["eligiblePublicGameKeys"],200)
        self.assertEqual(r["publicGameKeysAbsentFromOldSupremeRoster"],10)
        self.assertEqual(r["pricelessNoOfficialSlug"],1)
        self.assertEqual(r["pageCounts"],{"ancient":15,"godly":128,"chroma":46})
        self.assertEqual(r["sourcePublisherExpiryUtc"],"2026-11-09T15:56:07Z")
        self.assertTrue(r["historicalWebsiteAgeExpired"])
        self.assertEqual(len(r["candidateRegistrySha256"]),64)
        self.closed(r)

    def test_exact_public_example_urls_and_variant_class(self):
        c=self.registry["candidates"]
        names={
            "Gingerscope":("ancient","Gingerscope","Gun","Ancient",False),
            "EmberscytheChroma":("chroma","CEmberscythe","Knife","Ancient",True),
            "BattleAxe":("godly","Battleaxe","Knife","Godly",False),
            "BattleAxe2":("godly","BA2","Knife","Godly",False),
        }
        for key,(page,slug,kind,rarity,chroma) in names.items():
            with self.subTest(key=key):
                row=c[key]
                self.assertEqual(
                    (row["page"],row["slug"],row["gameItemType"],
                     row["gameRarity"],row["gameChroma"]),
                    (page,slug,kind,rarity,chroma))
                result=m.lookup_public_candidate(self.registry,key)
                self.assertEqual(result["status"],"PUBLIC_REFERENCE_LINK_ONLY",result)
                self.assertEqual(result["publicReference"]["url"],row["url"])
                self.assertEqual(result["publicReference"]["slug"],slug)
                self.assertNotIn("checkerId",result["publicReference"])
                self.closed(result)

    def test_priceless_has_no_invented_slug_and_ten_game_only_items(self):
        a,_,_,stage77,_=self.src()
        src=m._pinned_module(stage77,m.STAGE77_BLOB,"tested77.py")
        game=src.game_rows(a)
        public=[k for k,x in game.items() if x.get("ItemName")=="Nik's Scythe"
                and x.get("Rarity")=="Ancient" and x.get("ItemType") in ("Knife","Gun")]
        self.assertEqual(len(public),1)
        self.assertNotIn(public[0],self.registry["candidates"])
        self.assertEqual(m.lookup_public_candidate(self.registry,public[0])["status"],"UNMAPPED_PUBLIC_KEY")
        self.closed(m.lookup_public_candidate(self.registry,public[0]))
        self.assertEqual(self.registry["publicGameKeysAbsentFromOldSupremeRoster"],10)

    def test_numeric_old_checker_ids_are_not_lookup_keys(self):
        for val in ("771",771,"1",None,"","Gingerscope ","GINGERSCOPE",["Gingerscope"]):
            r=m.lookup_public_candidate(self.registry,val)
            self.assertIn(r["status"],("INCONCLUSIVE","UNMAPPED_PUBLIC_KEY"))
            self.closed(r)
        self.assertIn("Gingerscope",self.registry["candidates"])

    def test_report_never_exports_old_numeric_checker_or_prices(self):
        result=self.registry
        self.assertTrue(all("checkerId" not in x and "supremeValue" not in x
                            and "price" not in x and "historicalNumericId" not in x
                            for x in result["candidates"].values()))
        for row in result["candidates"].values():
            self.assertIs(row["currentOwnedRawKeyVerified"],False)
            self.assertIs(row["priceForTradeVerified"],False)
        self.assertNotIn('"username"',json.dumps(result))
        self.assertNotIn('"jobId"',json.dumps(result))
        self.closed(result)

    def test_injected_caller_authority_does_not_pass_through(self):
        report=deepcopy(self.registry)
        target=report["candidates"]["Gingerscope"]
        target["checkerId"]="771"
        target["supremeValue"]=16000
        target["verified"]=True
        result=m.lookup_public_candidate(report,"Gingerscope")
        self.assertEqual(result["status"],"INCONCLUSIVE")  # digest changed
        self.closed(result)

    def test_forged_website_urls_and_chroma_status_fail(self):
        for label,new in (
            ("url","https://evil.example/mm2/ancients?item=Gingerscope"),
            ("slug","Gingerscope&admin=1"),
            ("page","godly"),
            ("gameChroma",True),
            ("gameItemType","Pet"),
            ("displayName","Wrong"),
        ):
            report=deepcopy(self.registry)
            report["candidates"]["Gingerscope"][label]=new
            r=m.lookup_public_candidate(report,"Gingerscope")
            self.assertEqual(r["status"],"INCONCLUSIVE",label)
            self.closed(r)

    def test_incomplete_registry_or_caller_injection_fails(self):
        r=m.lookup_public_candidate({}, "Gingerscope")
        self.assertEqual(r["status"],"INCONCLUSIVE")
        self.closed(r)
        report=deepcopy(self.registry)
        report["candidates"].pop("Gingerscope")
        r=m.lookup_public_candidate(report,"Gingerscope")
        self.assertEqual(r["status"],"INCONCLUSIVE")
        self.closed(r)

    def test_400_mutated_original_byte_sources_fail_closed(self):
        a,roster,pages,st77,st81=self.src()
        rng=random.Random(8201)
        for i in range(400):
            aa=a;rr=roster;pp=dict(pages);p77=st77;p81=st81
            mutation=i%7
            if mutation==0: aa+=bytes([rng.randrange(256)])
            elif mutation==1: rr+=bytes([rng.randrange(256)])
            elif mutation==2: p77+=bytes([rng.randrange(256)])
            elif mutation==3: p81+=bytes([rng.randrange(256)])
            else:
                page=("ancient","godly","chroma")[mutation-4]
                pp[page]+=bytes([rng.randrange(256)])
            result=m.build(aa,rr,pp,p77,p81)
            self.assertEqual(result["status"],"INCONCLUSIVE",i)
            self.assertFalse(result["candidates"],i)
            self.closed(result)

    def test_original_inputs_only_no_game_calls(self):
        src=MODULE.read_text()
        for bad in ("InvokeServer(","FireServer(","GetProfileData(","setclipboard(",
                    "HttpGet(","game:GetService(","TeleportService"):
            self.assertNotIn(bad,src)
        self.assertIn('"researchOnly": True',src)
        self.assertIn('stage81_result = preflight.run(roster,pages,stage77)',src)

if __name__=="__main__":
    unittest.main()
