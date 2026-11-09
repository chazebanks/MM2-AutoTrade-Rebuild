"""Stage74 follow-up: pinned Oct18 third-party catalogue, NAME-only evidence."""
from __future__ import annotations
import importlib.util
import os
from pathlib import Path
import random
import unittest

ROOT=Path(__file__).resolve().parents[2]
P=ROOT/"scripts/stage74_full_archive_name_coverage.py"
SPEC=importlib.util.spec_from_file_location("stage74_newer",P)
assert SPEC and SPEC.loader
m=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(m)
CATALOG=Path(os.getenv("STAGE74_PINNED_NEWER",
                       "/tmp/stage74_oct18_public_db.lua"))
MARKET=Path(os.getenv("STAGE74_PINNED_SOURCE",
                      "/tmp/stage74_pinned_supreme.json"))
NEVER=(
    "currentGameCatalogAuthenticated","playerInventoryRead",
    "sourcePublisherCurrentVerified","currentPricesVerified",
    "numericSupremeCheckerIdProvenByGame","rawGameToSupremeCheckerApproved",
    "authorizesTrade","authorizesAccept","mayRecordCompletedTrade",
    "mayRecordRejectedTrade","mayUseForStrategyLearning","maySendDiscordWebhook",
    "mayReportProfit",
)

class Stage74NewerPublicTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not CATALOG.is_file() or not MARKET.is_file():
            raise RuntimeError("Exact public Oct18 game copy and Nov4 snapshot required")
        cls.catalog=CATALOG.read_bytes()
        cls.market=MARKET.read_bytes()

    def safe(self,x):
        self.assertEqual(x["tradeOutcome"],"UNKNOWN")
        for flag in NEVER:self.assertIs(x[flag],False,flag)
        for forbidden in ("rawKeys","playerNames","checkerIds","sourcePrices",
                          "portfolioValue","expectedProfit","verifiedTotal"):
            self.assertNotIn(forbidden,x)

    def test_exact_pinned_oct18_public_copy_gains_ten_modern_names(self):
        self.assertEqual(m.blob_sha(self.catalog),m.NEWER_PUBLIC_BLOB)
        z=m.evaluate_newer_public(self.catalog,self.market)
        self.assertEqual(z["status"],"THIRD_PARTY_PUBLIC_NAME_CORROBORATION_ONLY")
        self.safe(z)
        self.assertEqual(z["newerPublicEntries"],1040)
        self.assertEqual(z["newerPublicEligibleRows"],200)
        self.assertEqual(z["snapshotCanonicalRows"],190)
        self.assertEqual(z["uniquePublicNameAndCategoryMatches"],188)
        self.assertEqual(z["ambiguousPublicNameMatches"],0)
        self.assertEqual(z["sourceNamesAbsentFromArchive"],2)
        self.assertEqual(z["matchedByCategory"],
                         {"ancient":16,"godly":126,"chroma":46})
        self.assertEqual({(x["page"],x["name"])
                          for x in z["absentPublicSourceNames"]},
                         {("godly","Battleaxe"),("godly","Battleaxe II")})
        self.assertEqual(z["newerSourcePublisher"],"THIRD_PARTY_UNVERIFIED")
        self.assertIs(z["newerSourceMirroredToDb2SameGitBlob"],True)

    def test_ten_new_2026_event_labels_are_bounded_correspondences(self):
        d=m.parse_newer_public_entries(self.catalog.decode("utf-8"))
        source=m.parse_market_rows(self.market)
        ten={
            ("ancient","Emberbow"),("ancient","Emberscythe"),
            ("godly","Immortal"),("godly","Mortal"),("godly","Embersickle"),
            ("chroma","Chroma Emberbow"),("chroma","Chroma Emberscythe"),
            ("chroma","Chroma Immortal"),("chroma","Chroma Mortal"),
            ("chroma","Chroma Embersickle"),
        }
        matches={}
        for item in d.values():
            pair=m.game_page_name(item)
            if pair is not None:matches[pair]=matches.get(pair,0)+1
        self.assertTrue(all(matches.get(z)==1 and z in source for z in ten))
        self.assertEqual(len(ten),10)
        self.safe(m.evaluate_newer_public(self.catalog,self.market))

    def test_battleaxe_casing_not_silently_fuzzy_joined(self):
        d=m.parse_newer_public_entries(self.catalog.decode("utf-8"))
        self.assertEqual(m.game_page_name(d["BattleAxe"]),("godly","BattleAxe"))
        self.assertEqual(m.game_page_name(d["BattleAxe2"]),("godly","BattleAxe II"))
        s=m.parse_market_rows(self.market)
        self.assertIn(("godly","Battleaxe"),s)
        self.assertIn(("godly","Battleaxe II"),s)
        self.assertNotIn(("godly","BattleAxe"),s)
        self.assertNotIn(("godly","BattleAxe II"),s)

    def test_chroma_distinct_and_no_fuzzy_identity(self):
        d=m.parse_newer_public_entries(self.catalog.decode("utf-8"))
        self.assertEqual(m.game_page_name(d["MortalChroma"]),
                         ("chroma","Chroma Mortal"))
        self.assertEqual(m.game_page_name(d["Mortal"]),
                         ("godly","Mortal"))
        self.assertEqual(m.game_page_name(d["ImmortalChroma"]),
                         ("chroma","Chroma Immortal"))
        self.assertEqual(m.game_page_name(d["Immortal"]),
                         ("godly","Immortal"))
        self.assertEqual(m.game_page_name(d["EmberbowChroma"]),
                         ("chroma","Chroma Emberbow"))
        self.assertEqual(m.game_page_name(d["EmberscytheChroma"]),
                         ("chroma","Chroma Emberscythe"))
        self.assertEqual(d["EmberscytheChroma"]["Rarity"],"Ancient")
        self.assertEqual(d["EmberbowChroma"]["Rarity"],"Ancient")
        # Public game art/item asset IDs may be reused by related variants.
        # Never treat asset IDs as unique raw owned keys or Supreme checker IDs.
        self.assertEqual(d["EmberscytheChroma"]["ItemID"],
                         d["Emberscythe"]["ItemID"])

    def test_three_corruption_classes_fail_closed(self):
        for which in ("source","market","missing"):
            a=self.catalog
            b=self.market
            if which=="source":a=a[:100]+b"BAD"+a[100:]
            if which=="market":b=b[:100]+b"BAD"+b[100:]
            if which=="missing":a=None
            out=m.evaluate_newer_public(a,b)
            self.assertEqual(out["status"],"INCONCLUSIVE")
            self.safe(out)

    def test_200_seeded_byte_mutations_never_promote(self):
        rng=random.Random(741840)
        for i in range(200):
            src=self.catalog if i%2==0 else self.market
            buf=bytearray(src)
            j=rng.randrange(len(buf))
            buf[j]^=1 << rng.randrange(8)
            out=m.evaluate_newer_public(
                bytes(buf) if i%2==0 else self.catalog,
                self.market if i%2==0 else bytes(buf)
            )
            self.assertEqual(out["status"],"INCONCLUSIVE",(i,j))
            self.safe(out)

    def test_mutated_parser_shape_rejects_duplicate_direct_field(self):
        text=self.catalog.decode("utf-8")
        before='    ["ItemName"] = "Gingerscythe",'
        self.assertIn(before,text)
        mutated=text.replace(before,before+'\n'+before,1)
        with self.assertRaisesRegex(ValueError,"duplicate third-party direct"):
            m.parse_newer_public_entries(mutated)

if __name__=="__main__":
    unittest.main()
