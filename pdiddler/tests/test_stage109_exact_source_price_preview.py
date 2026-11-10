"""Stage109 exact public-source price PREVIEW, not trade valuation.

Executes immutable original Stage69 parser / Stage83 public registry and full
original Stage84 Nov9 Supreme HTML sources. The game catalogue is SYNTHETIC
for CI: no claim that an actual server or current user owns any item.
"""
from __future__ import annotations
import copy
import importlib
import os
from pathlib import Path
import random
import unittest
from unittest import mock
from datetime import datetime, timezone

class Stage109StrictPublicValueBridge(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if os.getenv("STAGE109_REQUIRE_PINNED")!="1":
            raise unittest.SkipTest("Stage109 original public-source regression requires pinned fixtures")
        from pdiddler.intelligence_lab.stage108_strict_public_name_coverage import parse_registry
        cls.reg=Path(os.environ["STAGE109_ORIGINAL_STAGE83"]).read_bytes()
        cls.parser=Path(os.environ["STAGE109_ORIGINAL_PARSER"]).read_bytes()
        root=Path(os.environ["STAGE109_ORIGINAL_HTML_DIR"])
        cls.html={p:(root/(f+".html")).read_bytes() for p,f in (
            ("ancient","ancients"),("godly","godlies"),("chroma","chromas"))}
        cls.entries={e["key"]:e for e in parse_registry(cls.reg)}
        cls.preview=staticmethod(importlib.import_module(
            "pdiddler.intelligence_lab.stage109_exact_source_price_preview").preview)
    def setUp(self):
        # Replaying a Nov10 original publication in future CI must remain
        # deterministic; production preview uses REAL unpatched wall clock.
        pinned=datetime.fromisoformat("2026-11-10T09:00:00+00:00")
        mod=importlib.import_module(
            "pdiddler.intelligence_lab.stage109_exact_source_price_preview")
        patcher=mock.patch.object(mod,"_wall_epoch",
                                  return_value=int(pinned.timestamp()))
        patcher.start()
        self.addCleanup(patcher.stop)

    def catalogue(self,*keys):
        return {key:{"ItemName":self.entries[key]["name"],
                     "ItemType":self.entries[key]["type"],
                     "Rarity":self.entries[key]["rarity"],
                     "Chroma":self.entries[key]["chroma"]}
                for key in keys}
    @staticmethod
    def offer(key,quantity=1):
        return {"rawKey":key,"quantity":quantity}
    def check_denied(self,r):
        for k in ("authorizesTrade","authorizesAccept","currentPricesVerified",
                  "priceForTradeVerified","rawKeyToCurrentSiteItemVerified",
                  "gameServerCatalogAuthenticated","rawItemIdConfirmed",
                  "numericSupremeCheckerIdVerified","serverAttestation",
                  "serverCompletionProven","mayRecordCompletedTrade",
                  "mayReportProfit","maySendDiscordWebhook",
                  "mayUseForStrategyLearning"):
            self.assertIs(r[k],False,k)
        self.assertEqual(r["tradeOutcome"],"UNKNOWN")
        self.assertIs(r["readOnly"],True)
        self.assertIs(r["publicHistoricalOnly"],True)
    def evaluate(self,ours=None,theirs=None,catalogue=None,
                 when="2026-11-10T12:00:00Z",html=None,parser=None):
        a=[self.offer("Scythe",5)] if ours is None else ours
        b=[self.offer("Gingerscope")] if theirs is None else theirs
        cat=self.catalogue("Scythe","Gingerscope") if catalogue is None else catalogue
        return self.preview(self.reg,
                            self.parser if parser is None else parser,
                            self.html if html is None else html,
                            cat,a,b,when)
    def test_full_original_source_pin_uses_site_names_no_numeric_checker_id(self):
        r=self.evaluate()
        self.assertEqual(r["status"],"PUBLIC_SOURCE_INDICATIVE_TOTALS_CLIENT_UNATTRIBUTED",r)
        self.assertEqual(r["ourPublicReferenceValue"],210)  # Batwing 42 x5
        self.assertEqual(r["theirPublicReferenceValue"],16000)
        self.assertEqual(r["illustrativeDifference"],15790)
        self.assertEqual(r["ourSlotCount"],1);self.assertEqual(r["theirSlotCount"],1)
        self.assertEqual(r["ourCopyCount"],5)
        self.assertEqual(r["sourcePublisherUtc"],"2026-11-09T18:58:33Z")
        self.assertEqual(r["sourceFixedExpiryUtc"],"2026-11-10T22:26:48Z")
        self.assertNotIn("Scythe",str(r));self.assertNotIn("Gingerscope",str(r))
        self.check_denied(r)
    def test_two_distinct_stacked_slots_not_four_total_copies(self):
        c=self.catalogue("Scythe","Emberbow","Gingerscope")
        r=self.evaluate(ours=[self.offer("Scythe",3),self.offer("Emberbow",4)],
                        catalogue=c)
        self.assertEqual(r["status"],"PUBLIC_SOURCE_INDICATIVE_TOTALS_CLIENT_UNATTRIBUTED",r)
        self.assertEqual(r["ourPublicReferenceValue"],3*42+4*650)
        self.assertEqual(r["theirPublicReferenceValue"],16000)
        self.assertEqual(r["ourSlotCount"],2)
        self.assertEqual(r["ourCopyCount"],7);self.check_denied(r)
    def test_chroma_and_normal_same_display_name_have_distinct_site_values(self):
        c=self.catalogue("Immortal","ImmortalChroma")
        r=self.evaluate(ours=[self.offer("Immortal")],
                        theirs=[self.offer("ImmortalChroma")],catalogue=c)
        self.assertEqual(r["status"],"PUBLIC_SOURCE_INDICATIVE_TOTALS_CLIENT_UNATTRIBUTED",r)
        self.assertNotEqual(r["ourPublicReferenceValue"],r["theirPublicReferenceValue"])
        self.check_denied(r)
    def test_protected_gingerscope_outgoing_has_no_numeric_total(self):
        c=self.catalogue("Gingerscope","Scythe")
        r=self.evaluate(ours=[self.offer("Gingerscope")],
                        theirs=[self.offer("Scythe")],catalogue=c)
        self.assertEqual(r["reason"],"PROTECTED_GINGERSCOPE_OUTGOING",r)
        self.assertIsNone(r["ourPublicReferenceValue"])
        self.assertIsNone(r["theirPublicReferenceValue"])
        self.check_denied(r)
    def test_expired_original_capture_must_not_keep_publishing_numeric_previews(self):
        r=self.evaluate(when="2026-11-10T22:26:48Z")
        self.assertEqual(r["reason"],"FIXED_ORIGINAL_PUBLIC_CAPTURE_EXPIRED",r)
        self.assertIsNone(r["ourPublicReferenceValue"])
        self.assertIsNone(r["illustrativeDifference"])
        self.check_denied(r)
        r=self.evaluate(when="2026-11-11T08:00:00Z")
        self.assertEqual(r["reason"],"FIXED_ORIGINAL_PUBLIC_CAPTURE_EXPIRED")
        self.check_denied(r)
    def test_extra_original_client_sync_fields_must_not_be_misread_as_identity_error(self):
        # Live Sync.Weapons entries can expose asset/thumbnail or unrelated
        # metadata fields; only exact identity fields should participate.
        c=self.catalogue("Scythe","Gingerscope")
        c["Scythe"]["ItemID"]=12345678  # Game asset metadata, not a Supreme ID
        c["Scythe"]["DisplayOrder"]=7
        c["Scythe"].pop("Chroma")  # missing false is valid in original Stage101
        c["Scythe"]["checkerId"]="forged-771"
        c["Scythe"]["verified"]=True
        r=self.evaluate(catalogue=c)
        self.assertEqual(r["status"],
                         "PUBLIC_SOURCE_INDICATIVE_TOTALS_CLIENT_UNATTRIBUTED",r)
        self.assertEqual(r["ourPublicReferenceValue"],210)
        self.assertFalse(r["numericSupremeCheckerIdVerified"])
        self.check_denied(r)
    def test_caller_cannot_rewind_wall_clock_to_reactivate_expired_capture(self):
        mod=importlib.import_module(
            "pdiddler.intelligence_lab.stage109_exact_source_price_preview")
        with mock.patch.object(mod,"_wall_epoch",return_value=1794353209):
            # Simulated actual wall time AFTER fixed Nov10 capture expiry;
            # an attacker supplies a pre-expiry client timestamp.
            r=self.evaluate(when="2026-11-10T12:00:00Z")
            self.assertEqual(r["reason"],
                             "FIXED_ORIGINAL_PUBLIC_CAPTURE_EXPIRED",r)
            self.assertIsNone(r["ourPublicReferenceValue"])
            self.check_denied(r)
    def test_forged_metadata_variant_type_and_unknown_raw_key_not_priceable(self):
        base=self.catalogue("Scythe","Gingerscope")
        for part,mutated in (
            ("name",{**base["Scythe"],"ItemName":"Gingerscope"}),
            ("chroma",{**base["Scythe"],"Chroma":True}),
            ("type",{**base["Scythe"],"ItemType":"Gun"}),
            ("rarity",{**base["Scythe"],"Rarity":"Godly"}),
        ):
            with self.subTest(part=part):
                c=copy.deepcopy(base);c["Scythe"]=mutated
                r=self.evaluate(catalogue=c)
                self.assertEqual(r["status"],"INCONCLUSIVE",r)
                self.assertIsNone(r["ourPublicReferenceValue"]);self.check_denied(r)
        r=self.evaluate(ours=[self.offer("NotReallyBatwing")])
        self.assertEqual(r["status"],"INCONCLUSIVE");self.check_denied(r)
    def test_untrusted_parser_or_corrupt_original_html_fails_before_value_mapping(self):
        r=self.evaluate(parser=self.parser+b"\n# altered!")
        self.assertEqual(r["status"],"INCONCLUSIVE")
        self.check_denied(r)
        t=copy.deepcopy(self.html);t["godly"]=t["godly"]+b"<!--altered-->"
        r=self.evaluate(html=t);self.assertEqual(r["status"],"INCONCLUSIVE")
        self.check_denied(r)
    def test_five_distinct_physical_slots_quantity_zero_and_duplicate_types_rejected(self):
        c=self.catalogue("Scythe","Emberbow","Harvester","Icepiercer","Icewing","Gingerscope")
        for offer in (
            [self.offer(x) for x in ("Scythe","Emberbow","Harvester","Icepiercer","Icewing")],
            [self.offer("Scythe",0)],
            [self.offer("Scythe",1000001)],
            [self.offer("Scythe",3),self.offer("Scythe",2)],
        ):
            r=self.evaluate(ours=offer,catalogue=c)
            self.assertEqual(r["status"],"INCONCLUSIVE",r)
            self.check_denied(r)
    def test_source_name_alias_or_override_does_not_bind_without_game_metadata(self):
        c=self.catalogue("Scythe","Gingerscope")
        c["Scythe"]={**c["Scythe"],"ItemName":"Bat Wing",
                     "checkerId":771,"verified":True}
        r=self.evaluate(catalogue=c)
        self.assertEqual(r["status"],"INCONCLUSIVE")
        self.check_denied(r)
    def test_250_seeded_bad_offer_mutants_cannot_authorize_real_trade(self):
        rng=random.Random(109)
        for i in range(250):
            c=self.catalogue("Scythe","Gingerscope")
            a=[self.offer("Scythe",5)]
            b=[self.offer("Gingerscope")]
            kind=i%10
            if kind==0:a[0]["quantity"]=0
            if kind==1:a[0]["quantity"]=float("nan")
            if kind==2:a[0]["rawKey"]="Unknown"
            if kind==3:c["Scythe"]["ItemType"]="Gun"
            if kind==4:c["Gingerscope"]["Chroma"]=True
            if kind==5:a.append(self.offer("Scythe",2))
            if kind==6:a[0]["checkerId"]=771
            if kind==7:a[0]["quantity"]=rng.choice((1000001,-3))
            if kind==8:c["Scythe"]["ItemName"]=rng.choice(("Bat Wing","Seer"))
            if kind==9:a[0]["quantity"]=rng.randint(1,100)
            r=self.evaluate(ours=a,theirs=b,catalogue=c)
            self.check_denied(r)
            if kind!=9:
                self.assertNotEqual(r["status"],
                    "PUBLIC_SOURCE_INDICATIVE_TOTALS_CLIENT_UNATTRIBUTED")
    def test_legacy_historical_source_never_confused_for_current_server_attestation(self):
        r=self.evaluate()
        self.check_denied(r)
        self.assertFalse(r["gameServerCatalogAuthenticated"])
        self.assertFalse(r["rawKeyToCurrentSiteItemVerified"])
        self.assertFalse(r["priceForTradeVerified"])
        self.assertNotIn("siteCheckerId",r)
        self.assertNotIn("rawKey",r)

if __name__=="__main__":
    unittest.main()
