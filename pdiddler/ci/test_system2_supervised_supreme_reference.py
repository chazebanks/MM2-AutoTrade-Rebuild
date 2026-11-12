"""Offline regressions for System 2 manual website reference, no requests."""
import unittest

from pdiddler.system2.supervised_supreme_reference import (
    CALCULATOR, CATEGORIES, DENIED, make_review_packet,
)

def item(label="Test Weapon", quantity=1, category="Godly"):
    return {"label": label, "quantity": quantity, "category": category}

class SupervisedReferenceTests(unittest.TestCase):
    def test_normal_packet_has_only_human_reference(self):
        p = make_review_packet({"ownOffer": [item()], "theirOffer": [item("Test Other", 2, "Ancient")]})
        self.assertEqual(p["status"], "HUMAN_SUPREME_REVIEW_REQUIRED")
        self.assertEqual(p["calculatorUrl"], CALCULATOR)
        self.assertEqual(p["physicalSlotCount"], {"ownOffer": 1, "theirOffer": 1})
        self.assertEqual(p["tradeOutcome"], "UNKNOWN")
        self.assertTrue(all(p[key] is False for key in DENIED))
        self.assertNotIn("value", p["observedUnverifiedOffer"]["ownOffer"][0])
        self.assertNotIn("demand", p["observedUnverifiedOffer"]["ownOffer"][0])
    def test_supported_link_is_official(self):
        self.assertEqual(set(CATEGORIES), {"Ancient", "Godly", "Chroma"})
        self.assertTrue(all(url.startswith("https://supremevalues.com/mm2/") for url in CATEGORIES.values()))
    def test_four_physical_slots_does_not_cap_stacked_copies(self):
        p = make_review_packet({"ownOffer": [item("Test Stack", 12)]*4, "theirOffer": []})
        self.assertEqual(p["physicalSlotCount"]["ownOffer"], 4)
        self.assertEqual(p["observedUnverifiedOffer"]["ownOffer"][0]["quantity"], 12)
    def test_fifth_physical_slot_rejected(self):
        with self.assertRaisesRegex(ValueError, "FOUR_PHYSICAL"):
            make_review_packet({"ownOffer": [item()]*5, "theirOffer": []})
    def test_protects_outgoing_gingerscope(self):
        for label in ("Gingerscope", "  Gingerscope  ", "Ginger Scope", "GINGERSCOPE"):
            with self.subTest(label=label):
                with self.assertRaises(ValueError):
                    make_review_packet({"ownOffer": [item(label)], "theirOffer": []})
    def test_gingerscope_can_be_incoming(self):
        p = make_review_packet({"ownOffer": [], "theirOffer": [item("Gingerscope", 1, "Ancient")]})
        self.assertEqual(p["physicalSlotCount"]["theirOffer"], 1)
    def test_rejects_supreme_market_copy_fields(self):
        for extra in ("value", "demand", "stability", "rarity", "lastUpdated", "price", "source"):
            with self.subTest(field=extra):
                bad = item()
                bad[extra] = 100
                with self.assertRaisesRegex(ValueError, "MARKET_FIELD"):
                    make_review_packet({"ownOffer": [bad], "theirOffer": []})
    def test_rejects_top_level_extra_fields(self):
        with self.assertRaisesRegex(ValueError, "INVALID_REVIEW_FIELDS"):
            make_review_packet({"ownOffer": [], "theirOffer": [], "autoAccept": True})
    def test_rejects_bad_quantities_and_bool(self):
        for q in (0, -1, True, 1.5, "4", 1_000_001):
            with self.subTest(quantity=q):
                with self.assertRaisesRegex(ValueError, "STACK_QUANTITY"):
                    make_review_packet({"ownOffer": [item(quantity=q)], "theirOffer": []})
    def test_rejects_bad_categories(self):
        for category in ("Unknown", "Rare", None, 1):
            with self.subTest(category=category):
                with self.assertRaisesRegex(ValueError, "INVALID_CATEGORY"):
                    make_review_packet({"ownOffer": [item(category=category)], "theirOffer": []})
    def test_rejects_untrusted_urls_and_control_char_in_labels(self):
        for label in ("https://evil.example", "Test\nWeapon", " trailing", ""):
            with self.subTest(label=label):
                with self.assertRaisesRegex(ValueError, "INVALID_ITEM_LABEL"):
                    make_review_packet({"ownOffer": [item(label=label)], "theirOffer": []})
    def test_none_wrong_types_invalid(self):
        for value in (None, [], "test", {"ownOffer": (), "theirOffer": []},
                      {"ownOffer": [], "theirOffer": None}):
            with self.subTest(value=value):
                with self.assertRaises(ValueError):
                    make_review_packet(value)

if __name__ == "__main__":
    unittest.main()
