"""Crosswalk tests against the *original* 189 raw-key registry blob.

All market content in this suite is synthetic; live GitHub workflow separately
fetches the real pages, runs the same mapper, and archives its actual output.
"""
import copy
import json
import os
import unittest
from datetime import datetime, timezone
from pathlib import Path

from pdiddler.system2.catalog_discovery_diff import load_historical_registry
from pdiddler.system2 import public_market_gamekey_crosswalk as cw

NOW = "2026-11-14T20:40:00Z"
REGISTRY = Path(os.environ["GINGERSCOPE_PINNED_STAGE83"]).read_bytes()


def market():
    original = load_historical_registry(REGISTRY)
    rows = []
    for (plural, _image), source in sorted(original.items()):
        cat = cw.CATEGORY_MAP[plural]
        raw = source["rawGameKeyCandidate"]
        name = source["expectedName"]
        if raw in cw.ALIASES:
            cat, slug, name = cw.ALIASES[raw]
        else:
            slug = raw.lower().replace("_", "-")
        rows.append({
            "providerName": name, "providerSlug": slug, "providerCategory": cat,
            "mm2SourceLabel": "35", "mm2Listed": 35,
            "supremeSourceLabel": "32", "supremeListed": 32,
            "demandOrdinal": "5", "stabilityLabel": "Stable",
            "rawGameWeaponKey": None, "chromaSubtypeVerified": False,
            "completedTradeLiquidityMeasured": False,
        })
    rows.append({
        "providerName": "Niks Scythe", "providerSlug": "niks-scythe",
        "providerCategory": "ancient", "mm2SourceLabel": "250M",
        "mm2Listed": 250000000, "supremeSourceLabel": "Priceless",
        "supremeListed": None, "demandOrdinal": "11",
        "stabilityLabel": "Overpaid for", "rawGameWeaponKey": None,
        "chromaSubtypeVerified": False, "completedTradeLiquidityMeasured": False,
    })
    return {
        "schema": cw.SOURCE_SCHEMA, "status": "CURRENT_PUBLIC_SOURCE_CANDIDATE",
        "website": "https://mm2tradehub.com", "retrievedUtc": "2026-11-14T20:38:29Z",
        "siteEditionDate": "2026-11-13",
        "sourceTierPageSha256": {x: "a" * 64 for x in cw.CATEGORIES},
        "categoryCounts": cw.SITE_COUNTS.copy(),
        "displayCardCounts": cw.DISPLAY_COUNTS.copy(),
        "deduplicatedCardCount": 19, "itemCount": 190,
        "items": rows, "providerTimestampPrecision": "date-only",
        "canFeedLiveTrade": False, "authorizesOffer": False,
        "authorizesAccept": False, "verifiedServerSettlement": False,
        "exactGameWeaponIdentityProven": False,
    }


class Crosswalk(unittest.TestCase):
    def run_crosswalk(self, market_override=None, registry_override=None, now=NOW):
        return cw.crosswalk(market_override if market_override is not None else market(),
                            registry_override if registry_override is not None else REGISTRY,
                            evaluated_utc=now)

    def test_original_189_and_special_cases(self):
        r = self.run_crosswalk()
        self.assertEqual(r["matchedHistoricalGameKeys"], 189)
        self.assertEqual(r["categoryGameKeys"], {"ancient": 15, "godly": 128, "chroma": 46})
        self.assertEqual(r["excludedAdditionalMarketCards"], 1)
        self.assertEqual(r["explicitAliasMatches"], 1)
        self.assertEqual(len(r["items"]), 189)
        self.assertFalse(r["authorizesTrade"])
        self.assertFalse(r["actualCurrentOwnedInventoryVerified"])
        self.assertTrue(r["marketDatasetNotSignedByPublisher"])
        idx = {q["rawGameKeyCandidate"]: q for q in r["items"]}
        self.assertEqual(idx["FlowerwoodKnife"]["marketSlug"], "flowerwood-knife")
        self.assertEqual(idx["FlowerwoodKnife"]["expectedGameName"], "Flowerwood")
        self.assertEqual(idx["FlowerwoodGun"]["marketName"], "Flowerwood Gun")
        self.assertTrue(idx["Gingerscope"]["outgoingGingerscopeProtected"])
        self.assertTrue(idx["EmberbowChroma"]["gameChroma"])
        self.assertEqual(idx["EmberbowChroma"]["gameRarity"], "Ancient")
        self.assertEqual(idx["ChromaDarkbringer"]["gameRarity"], "Godly")
        self.assertNotIn("Niks Scythe", [x["marketName"] for x in r["items"]])

    def test_hash_determinism(self):
        self.assertEqual(self.run_crosswalk()["crosswalkRowsSha256"],
                         self.run_crosswalk()["crosswalkRowsSha256"])

    def test_unknown_game_id_no_fuzzy_fallback(self):
        r = self.run_crosswalk()
        self.assertEqual(cw.reconcile_one_client_metadata(r, "gingerscope", {})["reason"],
                         "RAW_KEY_NOT_EXACTLY_MAPPED")

    def test_game_metadata_exact_name_and_variant(self):
        r = self.run_crosswalk()
        ok = cw.reconcile_one_client_metadata(r, "EmberbowChroma",
            {"ItemName": "Emberbow", "ItemType": "Gun", "Rarity": "Ancient", "Chroma": True})
        self.assertEqual(ok["status"], "LOCAL_METADATA_MATCH_RESEARCH_ONLY")
        self.assertFalse(ok["authorizesAccept"])

    def test_no_chroma_label_variant_confusion(self):
        r = self.run_crosswalk()
        bad = cw.reconcile_one_client_metadata(r, "EmberbowChroma",
            {"ItemName": "Emberbow", "ItemType": "Gun", "Rarity": "Ancient", "Chroma": False})
        self.assertEqual(bad["reason"], "LIVE_GAME_TYPE_RARITY_OR_VARIANT_CONFLICT")

    def test_flowerwood_exact_base_name(self):
        r = self.run_crosswalk()
        good = cw.reconcile_one_client_metadata(r, "FlowerwoodKnife",
            {"ItemName": "Flowerwood", "ItemType": "Knife", "Rarity": "Godly", "Chroma": False})
        self.assertEqual(good["status"], "LOCAL_METADATA_MATCH_RESEARCH_ONLY")
        bad = cw.reconcile_one_client_metadata(r, "FlowerwoodKnife",
            {"ItemName": "Flowerwood Gun", "ItemType": "Knife", "Rarity": "Godly", "Chroma": False})
        self.assertEqual(bad["reason"], "LIVE_GAME_NAME_DIFFERENT_FROM_HISTORICAL_KEY")

    def test_evolution_or_untradable_blocked(self):
        r = self.run_crosswalk()
        for field, val in (("EvoIndex", 3), ("Tradable", False), ("NonTradable", True)):
            meta = {"ItemName": "Emberbow", "ItemType": "Gun", "Rarity": "Ancient", "Chroma": False}
            meta[field] = val
            self.assertEqual(cw.reconcile_one_client_metadata(r, "Emberbow", meta)["reason"],
                             "GAME_ITEM_EXPLICITLY_INELIGIBLE")

    def test_forged_source_trade_authority(self):
        x = market()
        x["authorizesOffer"] = True
        with self.assertRaisesRegex(cw.MappingBlocked, "FORGED_SOURCE_AUTHORITY"):
            self.run_crosswalk(x)

    def test_source_expiry_and_future(self):
        with self.assertRaisesRegex(cw.MappingBlocked, "SOURCE_RETRIEVAL_STALE"):
            self.run_crosswalk(now="2026-11-15T04:00:00Z")
        with self.assertRaisesRegex(cw.MappingBlocked, "SOURCE_RETRIEVAL_STALE"):
            self.run_crosswalk(now="2026-11-14T20:37:00Z")

    def test_registry_mutation_blocks(self):
        self.assertEqual(len(load_historical_registry(REGISTRY)), 189)
        tampered = REGISTRY.replace(b'Gingerscope', b'Gingersc0pe', 1)
        with self.assertRaisesRegex(cw.MappingBlocked, "HISTORICAL_REGISTRY_PIN_OR_SHAPE_INVALID"):
            self.run_crosswalk(registry_override=tampered)

    def test_chroma_variant_confusion_rejected(self):
        x = market()
        chroma = next(y for y in x["items"] if y["providerSlug"] == "emberbowchroma")
        chroma["providerCategory"] = "godly"
        with self.assertRaises(cw.MappingBlocked):
            self.run_crosswalk(x)

    def test_flowerwood_alias_must_be_exact(self):
        x = market()
        row = next(y for y in x["items"] if y["providerSlug"] == "flowerwood-knife")
        row["providerSlug"] = "flowerwood-gun"
        with self.assertRaisesRegex(cw.MappingBlocked, "EXPLICIT_ALIAS_TARGET_MISSING_OR_CHANGED"):
            self.run_crosswalk(x)

    def test_missing_item_rejected(self):
        x = market()
        x["items"] = [a for a in x["items"] if a["providerSlug"] != "gingerscope"]
        x["itemCount"] = len(x["items"])
        with self.assertRaisesRegex(cw.MappingBlocked, "SOURCE_UNIQUE_ROW_COUNT_CHANGED"):
            self.run_crosswalk(x)

    def test_unknown_extra_item_rejected(self):
        x = market()
        n = next(a for a in x["items"] if a["providerSlug"] == "niks-scythe")
        n["providerSlug"] = "unknown-expensive-thing"
        with self.assertRaisesRegex(cw.MappingBlocked, "UNREVIEWED_MARKET_ITEM_NOT_IN_GAME_REGISTRY"):
            self.run_crosswalk(x)

    def test_pretend_niks_is_eligible_not_allowed(self):
        x = market()
        n = next(a for a in x["items"] if a["providerSlug"] == "niks-scythe")
        n["providerName"] = "Gingerscope"
        with self.assertRaises(cw.MappingBlocked):
            self.run_crosswalk(x)

    def test_duplicate_chroma_normalized_name_rejected(self):
        x = market()
        rows = [a for a in x["items"] if a["providerCategory"] == "chroma"]
        rows[0]["providerName"] = rows[1]["providerName"]
        with self.assertRaisesRegex(cw.MappingBlocked, "AMBIGUOUS_MARKET_NAME_VARIANT"):
            self.run_crosswalk(x)

    def test_source_name_drift_fails_no_fuzzy_alias(self):
        x = market()
        x["items"][0]["providerName"] = "Different Name"
        with self.assertRaises(cw.MappingBlocked):
            self.run_crosswalk(x)

    def test_invalid_price_demand_and_variant_authority(self):
        for field, value, reason in (
            ("mm2Listed", -12, "MARKET_PRICE_INVALID"),
            ("demandOrdinal", "NaN", "MARKET_DEMAND_INVALID"),
            ("rawGameWeaponKey", "Gingerscope", "MARKET_ROW_IDENTITY_UNVERIFIED"),
            ("chromaSubtypeVerified", True, "MARKET_ROW_IDENTITY_UNVERIFIED"),
        ):
            x = market()
            x["items"][0][field] = value
            with self.assertRaisesRegex(cw.MappingBlocked, reason):
                self.run_crosswalk(x)

    def test_refuse_price_source_forged_edition(self):
        x = market()
        x["siteEditionDate"] = "2026-09-01"
        with self.assertRaisesRegex(cw.MappingBlocked, "SOURCE_EDITION_STALE"):
            self.run_crosswalk(x)

    def test_all_189_have_distinct_raw_key_and_market_slug(self):
        r = self.run_crosswalk()
        self.assertEqual(len({i["rawGameKeyCandidate"] for i in r["items"]}), 189)
        self.assertEqual(len({i["marketSlug"] for i in r["items"]}), 189)

    def test_protected_target_not_outgoing_even_if_client_matches(self):
        r = self.run_crosswalk()
        target = cw.reconcile_one_client_metadata(r, "Gingerscope",
            {"ItemName": "Gingerscope", "ItemType": "Gun", "Rarity": "Ancient", "Chroma": False})
        self.assertEqual(target["status"], "LOCAL_METADATA_MATCH_RESEARCH_ONLY")
        self.assertFalse(target["mayUseForLiveOffer"])


if __name__ == "__main__":
    unittest.main()
