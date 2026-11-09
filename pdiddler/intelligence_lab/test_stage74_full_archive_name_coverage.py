"""Stage74 full historical catalogue coverage, with zero live trading authority."""
from __future__ import annotations

import importlib.util
import os
import random
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODULE = ROOT / "scripts/stage74_full_archive_name_coverage.py"
GAMEDATA = Path(os.getenv("STAGE74_PINNED_GAME", "/tmp/stage74_pinned_game.lua"))
SOURCEDATA = Path(os.getenv("STAGE74_PINNED_SOURCE", "/tmp/stage74_pinned_supreme.json"))
spec = importlib.util.spec_from_file_location("stage74_archive", MODULE)
assert spec and spec.loader
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

FORBIDDEN_AUTHORITY = (
    "currentGameCatalogAuthenticated", "playerInventoryRead",
    "sourcePublisherCurrentVerified", "currentPricesVerified",
    "numericSupremeCheckerIdProvenByGame", "rawGameToSupremeCheckerApproved",
    "authorizesTrade", "authorizesAccept", "mayReportProfit",
    "mayRecordCompletedTrade", "mayRecordRejectedTrade",
    "mayUseForStrategyLearning", "maySendDiscordWebhook",
)

class Stage74ArchiveCoverageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not GAMEDATA.is_file() or not SOURCEDATA.is_file():
            if os.getenv("STAGE74_REQUIRE_PINNED_FIXTURES")=="1":
                raise RuntimeError("Both exact Git-blob-pinned public source files required")
            raise unittest.SkipTest("Dedicated Stage74 pinned public-source fixtures unavailable in generic offline suite")
        cls.game = GAMEDATA.read_bytes()
        cls.source = SOURCEDATA.read_bytes()

    def assertSafe(self, result):
        for flag in FORBIDDEN_AUTHORITY:
            self.assertIs(result[flag], False, flag)
        self.assertNotIn("rawKeys", result)
        self.assertNotIn("checkerIds", result)
        self.assertEqual(result["tradeOutcome"], "UNKNOWN")

    def test_real_archival_cross_reference_all_190(self):
        self.assertEqual(m.blob_sha(self.game), m.CATALOG_BLOB)
        self.assertEqual(m.blob_sha(self.source), m.SUPREME_BLOB)
        got = m.evaluate(self.game, self.source)
        self.assertEqual(got["status"], "ARCHIVED_PUBLIC_NAME_COVERAGE_ONLY")
        self.assertSafe(got)
        self.assertEqual(got["archiveTopLevelRows"], 995)
        self.assertEqual(got["archiveEligibleRows"], 190)
        self.assertEqual(got["snapshotCanonicalRows"], 190)
        self.assertEqual(got["uniquePublicNameAndCategoryMatches"], 178)
        self.assertEqual(got["ambiguousPublicNameMatches"], 0)
        self.assertEqual(got["sourceNamesAbsentFromArchive"], 12)
        self.assertEqual(
            got["matchedByCategory"],
            {"ancient": 14, "godly": 123, "chroma": 41},
        )
        absent={(r["page"],r["name"]) for r in got["absentPublicSourceNames"]}
        self.assertEqual(len(absent),12)
        self.assertIn(("ancient","Emberbow"),absent)
        self.assertIn(("chroma","Chroma Mortal"),absent)
        self.assertIn(("godly","Battleaxe II"),absent)
        self.assertNotIn(("ancient","Gingerscope"),absent)
        self.assertNotIn(("chroma","Chroma Evergun"),absent)

    def test_public_source_rows_ensure_no_duplicate_page_and_name(self):
        import json
        rows = m.parse_market_rows(self.source)
        self.assertEqual(len(rows),190)
        self.assertNotEqual(("godly","Candleflame"),("chroma","Chroma Candleflame"))
        self.assertIn(("godly","Candleflame"),rows)
        self.assertIn(("chroma","Chroma Candleflame"),rows)

    def test_variant_and_category_guards(self):
        self.assertEqual(
            m.game_page_name({
                "ItemName":"Evergun", "Rarity":"Godly",
                "ItemType":"Gun", "ItemID":123,
                "Chroma":True}),
            ("chroma","Chroma Evergun")
        )
        self.assertEqual(
            m.game_page_name({
                "ItemName":"Evergun", "Rarity":"Godly",
                "ItemType":"Gun", "ItemID":123}),
            ("godly","Evergun")
        )
        self.assertEqual(
            m.game_page_name({
                "ItemName":"Gingerscope", "Rarity":"Ancient",
                "ItemType":"Gun", "ItemID":123}),
            ("ancient","Gingerscope")
        )
        # New public 2026 game metadata has Chroma Ancient weapons.
        self.assertEqual(
            m.game_page_name({
                "ItemName":"Emberscythe", "Rarity":"Ancient",
                "ItemType":"Knife", "ItemID":123,
                "Chroma":True}),
            ("chroma","Chroma Emberscythe")
        )
        self.assertIsNone(m.game_page_name({
            "ItemName":"Cat","Rarity":"Common","ItemType":"Pet","ItemID":1,
        }))
        for broken in [
            {"ItemName":"Chroma Evergun","Rarity":"Godly","ItemType":"Gun",
             "Chroma":True,"ItemID":123},
            {"ItemName":"Chroma Evergun","Rarity":"Ancient","ItemType":"Gun",
             "Chroma":True,"ItemID":123},
            {"ItemName":"Evergun","Rarity":"Godly","ItemType":"Gun",
             "Chroma":"true","ItemID":123},
            {"ItemName":"Evergun","Rarity":"Godly","ItemType":"Gun",
             "Chroma":True,"ItemID":"123"},
            {"ItemName":"E\nvergun","Rarity":"Godly","ItemType":"Gun",
             "Chroma":False,"ItemID":123},
        ]:
            with self.subTest(broken=broken),self.assertRaises(ValueError):
                m.game_page_name(broken)

    def test_raw_game_ids_and_supreme_market_local_ids_are_never_joined(self):
        src=MODULE.read_text()
        self.assertIn("numericSupremeCheckerIdProvenByGame=False",src)
        for s in ("FireServer(", "InvokeServer(", "setclipboard(",
                  "requests.get(", "urllib.request", "DiscordWebhook(", "HttpGet("):
            self.assertNotIn(s,src)
        got=m.evaluate(self.game,self.source)
        self.assertSafe(got)
        self.assertNotIn("sourcePrices",got)
        self.assertNotIn("totalValue",got)

    def test_corrupted_original_bytes_never_promote(self):
        rng=random.Random(74107410)
        for n in range(240):
            mutate_game=n%2==0
            original=self.game if mutate_game else self.source
            mutated=bytearray(original)
            k=rng.randrange(len(mutated))
            mutated[k]^=1 << rng.randrange(8)
            got=m.evaluate(bytes(mutated) if mutate_game else self.game,
                           self.source if mutate_game else bytes(mutated))
            self.assertEqual(got["status"],"INCONCLUSIVE",(n,k))
            self.assertSafe(got)

    def test_missing_and_truncated_bytes_fail_closed(self):
        for a,b in [(None,self.source),(self.game,None),
                    (b"",self.source),(self.game,b""),
                    (self.game[:-1],self.source),
                    (self.game,self.source[:-1])]:
            result=m.evaluate(a,b)
            self.assertEqual(result["status"],"INCONCLUSIVE")
            self.assertSafe(result)

    def test_eligibility_excludes_other_types_and_missing_metadata(self):
        # Source-level matching is not a live player's eligibility check.
        assert m.game_page_name({
            "Rarity":"Legendary","ItemName":"Gingerscope",
            "ItemType":"Gun","ItemID":111}) is None
        assert m.game_page_name({
            "Rarity":"Ancient","ItemName":"Gingerscope",
            "ItemType":"Pet","ItemID":111}) is None

if __name__=="__main__":
    unittest.main()
