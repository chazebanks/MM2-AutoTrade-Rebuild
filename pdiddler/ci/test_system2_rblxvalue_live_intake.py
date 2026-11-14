"""Deterministic RBLXValue v2 contract tests. No real API calls or secrets."""
import unittest
from copy import deepcopy
from pdiddler.system2 import rblxvalue_v2_market_import as m


def item(i, category, **replace):
    result = {
        "id": i, "name": f"Weapon {i}", "slug": f"weapon-{i}",
        "category": category, "type": "Knife", "value": 10,
        "value_source_a": 9, "value_source_b": 11,
        "demand": 5, "stability": "Stable",
        "last_updated": "2026-11-14 13:00:00",
    }
    result.update(replace)
    return result


def fake(pages=None, meta=None):
    pages = pages if pages is not None else {
        "ancient": [item(1, "ancient")],
        "godly": [item(2, "godly")],
        "chroma": [item(3, "chroma")],
    }
    meta = meta if meta is not None else {
        "last_updated": "2026-11-14 13:00:00",
        "totals": {"items": 1091},
        "sources": ["mm2values", "supremevalues"],
    }

    def get(path, args):
        if path == "/meta":
            return deepcopy(meta)
        all_rows = pages[args["category"]]
        offset = args["offset"]
        current = all_rows[offset:offset + args["limit"]]
        return {"items": deepcopy(current), "total": len(all_rows),
                "count": len(current), "limit": args["limit"], "offset": offset}
    return get


class MarketSourceContract(unittest.TestCase):
    def got(self, get):
        return m.collect(get, retrieved_utc="2026-11-14T19:00:00Z")

    def test_three_categories_and_no_live_authority(self):
        result = self.got(fake())
        self.assertEqual(len(result["weaponCandidates"]), 3)
        self.assertFalse(result["authorizesTrade"])
        self.assertFalse(result["providerTimestampTimezoneVerified"])
        self.assertTrue(all(x["rawGameWeaponId"] is None for x in result["weaponCandidates"]))

    def test_multiple_pages_and_arbitrary_copy_catalog(self):
        pages = {"ancient": [item(i, "ancient") for i in range(1, 108)],
                 "godly": [item(200, "godly")], "chroma": [item(300, "chroma")]}
        self.assertEqual(len(self.got(fake(pages))["weaponCandidates"]), 109)

    def test_nonweapon_not_promoted_to_tradable_weapon(self):
        pages = {"ancient": [item(1, "ancient", type="Pet"), item(2, "ancient")],
                 "godly": [item(3, "godly")], "chroma": [item(4, "chroma")]}
        self.assertEqual(len(self.got(fake(pages))["weaponCandidates"]), 3)

    def test_fractional_blended_value_preserved(self):
        pages = {"ancient": [item(1, "ancient", value="26.5")],
                 "godly": [item(2, "godly")], "chroma": [item(3, "chroma")]}
        self.assertEqual(self.got(fake(pages))["weaponCandidates"][0]["valueEstimate"], "26.5")

    def test_duplicate_id_across_categories(self):
        pages = {"ancient": [item(1, "ancient")],
                 "godly": [item(1, "godly")], "chroma": [item(3, "chroma")]}
        with self.assertRaisesRegex(m.DataFailure, "ITEM_DUPLICATE"):
            self.got(fake(pages))

    def test_duplicate_slug_across_categories(self):
        pages = {"ancient": [item(1, "ancient")],
                 "godly": [item(2, "godly", slug="weapon-1")],
                 "chroma": [item(3, "chroma")]}
        with self.assertRaisesRegex(m.DataFailure, "ITEM_DUPLICATE"):
            self.got(fake(pages))

    def test_category_filter_mismatch(self):
        pages = {"ancient": [item(1, "godly")],
                 "godly": [item(2, "godly")], "chroma": [item(3, "chroma")]}
        with self.assertRaisesRegex(m.DataFailure, "CATEGORY_FILTER_MISMATCH"):
            self.got(fake(pages))

    def test_missing_page(self):
        original = fake()
        def get(path, args):
            if path == "/items" and args["category"] == "godly":
                return {"total": 1, "items": []}
            return original(path, args)
        with self.assertRaisesRegex(m.DataFailure, "ITEM_PAGE_MISSING"):
            self.got(get)

    def test_false_total(self):
        original = fake()
        def get(path, args):
            x = original(path, args)
            if path == "/items" and args["category"] == "ancient":
                x["total"] = 0
            return x
        with self.assertRaisesRegex(m.DataFailure, "ITEM_PAGE_MISSING"):
            self.got(get)

    def test_demand_out_of_range(self):
        pages = {"ancient": [item(1, "ancient", demand=20)],
                 "godly": [item(2, "godly")], "chroma": [item(3, "chroma")]}
        with self.assertRaisesRegex(m.DataFailure, "DEMAND_FIELD_INVALID"):
            self.got(fake(pages))

    def test_missing_meta_timestamp(self):
        with self.assertRaisesRegex(m.DataFailure, "META_UPDATED_TIMESTAMP_MISSING"):
            self.got(fake(meta={"totals": {"items": 1091}}))

    def test_bad_meta_source_list(self):
        with self.assertRaisesRegex(m.DataFailure, "META_SOURCE_LIST_INVALID"):
            self.got(fake(meta={"last_updated": "2026-11-14 13:00:00",
                                "totals": {"items": 1091}, "sources": "supremevalues"}))

    def test_reject_unverified_retrieval_clock(self):
        with self.assertRaisesRegex(m.DataFailure, "RETRIEVAL_CLOCK"):
            m.collect(fake(), retrieved_utc="yesterday")

    def test_bad_key_fails_before_network(self):
        for key in ("", "test", "bad\nkey"):
            with self.assertRaisesRegex(m.DataFailure, "API_KEY_MISSING_OR_INVALID_FORMAT"):
                m.HTTPTransport(key)

    def test_deterministic_fingerprint(self):
        self.assertEqual(self.got(fake())["candidateRowsSha256"],
                         self.got(fake())["candidateRowsSha256"])

    def test_provider_error_does_not_make_partial_success(self):
        original = fake()
        def get(path, args):
            if path == "/items":
                return {"error": True, "message": "untrusted"}
            return original(path, args)
        with self.assertRaisesRegex(m.DataFailure, "ITEM_PAGE_INVALID"):
            self.got(get)


if __name__ == "__main__":
    unittest.main()
