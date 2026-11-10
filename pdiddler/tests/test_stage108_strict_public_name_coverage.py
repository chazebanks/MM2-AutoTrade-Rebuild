"""Stage108 original-source PUBLIC name coverage; all identity/price authority denied.

Pinned Stage83 Lua public-name registry, 3 pinned Stage84 original Supreme
HTML pages, and the unchanged Stage69 real HTML parser. No live Roblox state.
The tests are intentionally independent of any supposed raw->checker mapping.
"""
from __future__ import annotations

import copy
import hashlib
import importlib
import importlib.util
import os
from pathlib import Path
import unittest

REGISTRY_BLOB="40e2a0ff01b70b2d0181c62cae347a08da82bcb8"
PARSER_BLOB="d5843a57f34078cbe7213aa78a4aa12a5775c016"
SOURCE_BLOBS={
    "ancient":"ce8178ab9579e8782d8f72a6dac051756a728506",
    "godly":"d3cf222a8e10cff3a9fb051b16188192389c4b2d",
    "chroma":"6c77624cac3df96168b008e9bc8eca68a2d78cf9",
}
PATH={"ancient":"ancients","godly":"godlies","chroma":"chromas"}


def gitsha(raw:bytes)->str:
    return hashlib.sha1(b"blob "+str(len(raw)).encode()+b"\0"+raw).hexdigest()


class Stage108SourceNameOnly(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if os.getenv("STAGE108_REQUIRE_PINNED")!="1":
            raise unittest.SkipTest("Stage108 requires original pinned source bytes")
        registry=Path(os.environ["STAGE108_ORIGINAL_STAGE83"])
        parser=Path(os.environ["STAGE108_ORIGINAL_PARSER"])
        src=Path(os.environ["STAGE108_ORIGINAL_HTML_DIR"])
        if gitsha(registry.read_bytes())!=REGISTRY_BLOB:
            raise RuntimeError("Stage83 original game-public source changed")
        if gitsha(parser.read_bytes())!=PARSER_BLOB:
            raise RuntimeError("Stage69 actual parser changed")
        spec=importlib.util.spec_from_file_location("stage108_verified_original_parser",parser)
        p=importlib.util.module_from_spec(spec)
        spec.loader.exec_module(p)
        cls.registry=registry.read_bytes()
        cls.pages={}
        cls.parse=staticmethod(p.parse_page)
        for category,path in PATH.items():
            raw=(src/(path+".html")).read_bytes()
            if gitsha(raw)!=SOURCE_BLOBS[category]:
                raise RuntimeError("Nov9 original Supreme source changed")
            rows,published=p.parse_page(raw.decode("utf-8"),category)
            cls.pages[category]=raw
            cls.assertSourceRows=(len(rows),published)
        cls.mod=importlib.import_module("pdiddler.intelligence_lab.stage108_strict_public_name_coverage")

    def evaluate(self,registry=None,pages=None):
        return self.mod.audit(self.registry if registry is None else registry,
                              self.pages if pages is None else pages,self.parse)

    def denied(self,report):
        for field in ("currentGameCatalogAuthenticated",
                      "currentPricesVerified","priceForTradeVerified",
                      "numericSupremeCheckerIdVerified","rawItemIdConfirmed",
                      "rawKeyToCurrentSiteItemVerified","serverAttestation",
                      "serverCompletionProven","authorizesTrade",
                      "authorizesAccept","mayReportProfit",
                      "maySendDiscordWebhook","mayUseForStrategyLearning"):
            self.assertIs(report[field],False,field)
        self.assertIs(report["readOnly"],True)
        self.assertEqual(report["tradeOutcome"],"UNKNOWN")

    def test_original_lua_registry_against_all_three_real_nov9_html_sources(self):
        r=self.evaluate()
        self.assertEqual(r["status"],"HISTORICAL_SITE_NAME_COVERAGE_ALL_REGISTRY_ENTRIES_UNATTRIBUTED",r)
        self.assertEqual(r["registryPublicKeyCount"],189)
        self.assertEqual(r["supremeOfficialWeaponRowCount"],190)
        self.assertEqual(r["caseExactPublicNameCount"],187,r)
        self.assertEqual(r["caseOnlyDifferences"],2)
        self.assertEqual(r["casefoldExactPublicNameCount"],189)
        self.assertEqual(r["unresolvedRegistryNameCount"],0)
        self.assertEqual(r["unmatchedSupremeSourceNameCount"],1)
        self.assertEqual(r["officialSourcePublisherUtc"],"2026-11-09T18:58:33Z")
        self.assertEqual(r["registryReferencePublisherUtc"],"2026-11-06T15:56:07Z")
        self.denied(r)
        self.assertNotIn("Scythe",str(r))
        self.assertNotIn("venossgaming90190",str(r))

    def test_no_fuzzy_or_punctuation_alias_promotions(self):
        entries=[
            {"key":"T","name":"Traveler's Axe","type":"Knife","rarity":"Ancient",
             "chroma":False,"page":"ancient"},
            {"key":"C","name":"Traveler's Gun","type":"Gun","rarity":"Godly",
             "chroma":True,"page":"chroma"},
        ]
        source={"ancient":[{"name":"Traveler"}],
                "godly":[],
                "chroma":[{"name":"Chroma Traveler"}]}
        r=self.mod.compare_public_names(entries,source)
        self.assertEqual(r["casefoldExactPublicNameCount"],0)
        self.assertEqual(r["unresolvedRegistryNameCount"],2)

    def test_chroma_and_base_variants_match_only_their_exact_categories(self):
        entries=[
            {"key":"Base","name":"Candleflame","type":"Knife","rarity":"Godly",
             "chroma":False,"page":"godly"},
            {"key":"Colored","name":"Candleflame","type":"Knife","rarity":"Godly",
             "chroma":True,"page":"chroma"},
        ]
        source={"ancient":[],"godly":[{"name":"Candleflame"}],
                "chroma":[{"name":"Chroma Candleflame"}]}
        r=self.mod.compare_public_names(entries,source)
        self.assertEqual(r["casefoldExactPublicNameCount"],2)
        self.assertEqual(r["unresolvedRegistryNameCount"],0)
        source["chroma"][0]["name"]="Candleflame"
        r=self.mod.compare_public_names(entries,source)
        self.assertEqual(r["casefoldExactPublicNameCount"],1)
        self.assertEqual(r["unresolvedRegistryNameCount"],1)

    def test_case_only_is_tracked_separately_not_made_a_new_weapon(self):
        entries=[{"key":"B","name":"BattleAxe","type":"Knife",
                  "rarity":"Godly","chroma":False,"page":"godly"}]
        source={"godly":[{"name":"Battleaxe"}],"ancient":[],"chroma":[]}
        r=self.mod.compare_public_names(entries,source)
        self.assertEqual(r["caseExactPublicNameCount"],0)
        self.assertEqual(r["caseOnlyDifferences"],1)
        self.assertEqual(r["casefoldExactPublicNameCount"],1)
        self.assertEqual(r["unresolvedRegistryNameCount"],0)

    def test_duplicate_exact_target_or_game_raw_key_is_not_unique_identity(self):
        original={"key":"A","name":"Candleflame","type":"Knife",
                  "rarity":"Godly","chroma":False,"page":"godly"}
        for entries in ([original,dict(original,key="B")],
                        [original,dict(original)]):
            with self.subTest(entries=entries):
                with self.assertRaises(self.mod.Reject):
                    self.mod.compare_public_names(entries,{
                       "ancient":[],"godly":[{"name":"Candleflame"}],"chroma":[]})
        with self.assertRaises(self.mod.Reject):
            self.mod.compare_public_names([original],{"ancient":[],
              "godly":[{"name":"Candleflame"},{"name":"Candleflame"}],"chroma":[]})

    def test_original_source_bytes_mutated_or_missing_do_not_create_matches(self):
        cases=[]
        altered=copy.deepcopy(self.pages)
        altered["chroma"]=altered["chroma"]+b"<!--source changed-->"
        cases.append(altered)
        altered=copy.deepcopy(self.pages)
        del altered["ancient"]
        cases.append(altered)
        for pages in cases:
            r=self.evaluate(pages=pages)
            self.assertEqual(r["status"],"INCONCLUSIVE",r)
            self.denied(r)
        r=self.evaluate(registry=self.registry+b" ")
        self.assertEqual(r["status"],"INCONCLUSIVE")
        self.denied(r)

    def test_no_numeric_market_values_or_site_checker_ids_exposed(self):
        r=self.evaluate()
        self.denied(r)
        for k in ("prices","values","checkerIds","rawIds","rawKeyToSiteId",
                  "completeValue","currentPrice","profit"):
            self.assertNotIn(k,r)
        self.assertEqual(r["sourceStatus"],"PINNED_HISTORICAL_NAME_ONLY")

if __name__=="__main__":
    unittest.main()
