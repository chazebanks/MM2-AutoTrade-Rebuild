"""Stage71: pinned real archival MM2 catalog vs Supreme canonical names only.

Passing here NEVER produces MM2 server authentication, an approved raw->checker
mapping, a current market value or trading/learning authority.
"""
from __future__ import annotations

import importlib.util
import json
import os
from pathlib import Path
import random
import unittest

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/"scripts/stage71_archived_catalog_source_name_bridge.py"
SPEC=importlib.util.spec_from_file_location("stage71_bridge",SOURCE)
assert SPEC and SPEC.loader
M=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)
ARCHIVE_PATH=Path(os.environ.get("STAGE71_ARCHIVED_GAME_CATALOG",
                                 "/tmp/stage71_pinned_sync_item.lua"))
SUPREME_PATH=ROOT/"pdiddler/snapshots/supreme_snapshot_2026_11_04.json"

def no_trade_authority(test,got):
    for key in ("sourceNameMatchIsRawCheckerIdAuthentication",
                "numericSupremeCheckerIdProvenByGame",
                "currentGameCatalogAuthenticated",
                "currentUserInventoryRead",
                "mayProvideIndicativeResearchOnly",
                "mayMarkWeaponValueVerified",
                "mayRecordCompletedTrade",
                "mayRecordRejectedTrade",
                "mayUseForStrategyLearning",
                "mayReportProfit",
                "authorizesAccept",
                "authorizesTrade"):
        test.assertIs(got[key],False,key)
    test.assertEqual(got["sourceStatus"],
                     "HISTORICAL_ARCHIVE_NOT_CURRENT_GAME_SERVER")
    test.assertEqual(got["supremePriceStatus"],
                     "HISTORICAL_RESEARCH_SNAPSHOT_NOT_LIVE")
    test.assertNotIn("rawKeys",got)
    test.assertNotIn("checkerIds",got)

class Stage71SourceCorroborationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not ARCHIVE_PATH.exists():
            raise RuntimeError("Exact pinned public MM2 game catalog required")
        cls.archive=ARCHIVE_PATH.read_bytes()
        cls.source=SUPREME_PATH.read_bytes()

    def test_real_pinned_archive_historical_name_and_variant_only(self):
        self.assertEqual(M.blob_sha(self.archive),M.CATALOG_BLOB)
        self.assertEqual(M.blob_sha(self.source),M.SUPREME_BLOB)
        result=M.evaluate(self.archive,self.source)
        self.assertEqual(result["status"],
                         "ARCHIVED_CATALOG_SOURCE_NAME_MATCH_ONLY")
        self.assertEqual(result["historicalPublicNameMatches"],6)
        self.assertEqual(result["unsupportedModernItems"],4)
        self.assertTrue(result["archiveBlobPinned"])
        no_trade_authority(self,result)

    def test_known_game_entries_prove_variant_separation(self):
        decoded=self.archive.decode("utf-8")
        expected={
            "Gingerscope": ("ancient","Gingerscope","Gun"),
            "Candleflame": ("godly","Candleflame","Knife"),
            "CandleflameChroma": ("chroma","Chroma Candleflame","Knife"),
            "TreeGun2023": ("godly","Evergun","Gun"),
            "TreeGun2023Chroma": ("chroma","Chroma Evergun","Gun"),
            "Darkshot": ("godly","Darkshot","Gun"),
        }
        for raw,(page,label,weapon_type) in expected.items():
            with self.subTest(item=raw):
                item=M._extract_entry(decoded,raw)
                self.assertEqual(M._expected_page(item),(page,label))
                self.assertEqual(item["ItemType"],weapon_type)
                self.assertGreater(item["ItemID"],0)
        self.assertNotIn("Emberbow =",decoded)
        self.assertNotIn("Emberscythe =",decoded)

    def test_archived_source_is_not_server_transaction_numeric_checker(self):
        source_text=SOURCE.read_text(encoding="utf-8")
        for forbidden in ("requests.", "httpx", "urllib.request",
                          "FireServer", "InvokeServer", "HttpGet",
                          "DiscordWebhook(", "setclipboard(", "Supabase"):
            self.assertNotIn(forbidden,source_text)
        x=M.evaluate(self.archive,self.source)
        no_trade_authority(self,x)
        self.assertEqual(x["numericSupremeCheckerIdProvenByGame"],False)

    def test_invalid_catalog_metadata_rejected_at_parser_boundary(self):
        synthetic='\tFictional = {\n\t\tItemName = "Fictional",\n'+\
                  '\t\tItemName = "Duplicated",\n'+\
                  '\t\tItemType = "Gun",\n\t\tRarity = "Godly",\n'+\
                  '\t\tItemID = 123,\n\t},\n'
        with self.assertRaisesRegex(ValueError,"duplicate direct archived field"):
            M._extract_entry(synthetic,"Fictional")
        for item in (
            {"ItemName":"Evergun","ItemType":"Pet","Rarity":"Godly","Chroma":True},
            {"ItemName":"Evergun","ItemType":"Gun","Rarity":"Common","Chroma":False},
            {"ItemName":"","ItemType":"Gun","Rarity":"Godly","Chroma":False},
            {"ItemName":"Evergun","ItemType":"Gun","Rarity":"Ancient","Chroma":True},
        ):
            with self.subTest(item=item),self.assertRaises(ValueError):
                M._expected_page(item)

    def test_source_bytes_or_snapshot_bytes_mutation_never_forges_match(self):
        a=bytearray(self.archive)
        b=bytearray(self.source)
        for i in (0,len(a)//2,len(a)-1):
            altered=bytearray(a)
            altered[i]=(altered[i]+1)%256
            result=M.evaluate(bytes(altered),self.source)
            self.assertEqual(result["status"],"INCONCLUSIVE")
            no_trade_authority(self,result)
        for i in (0,len(b)//2,len(b)-1):
            altered=bytearray(b)
            altered[i]=(altered[i]+1)%256
            result=M.evaluate(self.archive,bytes(altered))
            self.assertEqual(result["status"],"INCONCLUSIVE")
            no_trade_authority(self,result)

    def test_250_seeded_archival_or_market_payload_corruptions(self):
        rng=random.Random(717171)
        for j in range(250):
            which=rng.randrange(2)
            original=self.archive if which==0 else self.source
            mutated=bytearray(original)
            ix=rng.randrange(len(mutated))
            mutated[ix]^=1 << rng.randrange(8)
            a=bytes(mutated) if which==0 else self.archive
            b=bytes(mutated) if which==1 else self.source
            out=M.evaluate(a,b)
            self.assertEqual(out["status"],"INCONCLUSIVE",(j,which,ix))
            no_trade_authority(self,out)

if __name__=="__main__":
    unittest.main()
