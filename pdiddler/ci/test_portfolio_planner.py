"""Bounded paper planning against the reviewed Supreme source."""
from collections import Counter
from copy import deepcopy
from hashlib import sha256
from itertools import product
import unittest

from hypothesis import example, given, settings, strategies as st

from pdiddler.ci.test_supreme_market_editions import NEXT_CAPTURE, archive
from pdiddler.system2.manual_portfolio_review import DEFAULT_CATALOG, RequestError
from pdiddler.system2.portfolio_planner import evaluate_offer, plan
from pdiddler.system2.supreme_market_editions import load_edition


ARCHIVE = DEFAULT_CATALOG.read_bytes()
AT = "2026-11-25T07:52:05Z"
SMALL_PRICES = {"godly:Fang": 10, "godly:Bioblade": 8, "godly:Chill": 10,
                "godly:Boneblade": 7, "godly:Gemstone": 15}
SMALL_STOCK = st.dictionaries(st.sampled_from(tuple(SMALL_PRICES)), st.integers(1, 2), min_size=1, max_size=3)


def search(main, partners, **options):
    return plan(ARCHIVE, main, partners, evaluated_at_utc=AT, **options)


class PortfolioPlannerTests(unittest.TestCase):
    def test_competing_paths_can_use_recycled_assets_with_one_use_partners(self):
        main = {"godly:Fang": 1, "ancient:Gingerscope": 1, "godly:Unpriced": 1}
        partners = [{"godly:Gemstone": 1}, {"godly:Plasmabeam": 1}, {"godly:Green_Luger": 1}]
        initial = deepcopy((main, partners))
        report = search(main, partners, max_steps=3)
        self.assertEqual((main, partners), initial)
        self.assertGreaterEqual(len(report["routes"]), 2)
        self.assertTrue(any(len(route["steps"]) == 3 for route in report["routes"]))
        self.assertTrue(any(row["main_listed_delta"] == 5 for row in report["alternatives"]))
        for route in report["routes"]:
            stock = Counter(main)
            seen = set()
            for row in route["steps"]:
                self.assertNotIn(row["opportunity_index"], seen)
                seen.add(row["opportunity_index"])
                self.assertEqual(row["main_listed_delta"], -row["counterparty_listed_delta"])
                for key, qty in row["give"].items():
                    self.assertNotEqual(key, "ancient:Gingerscope")
                    self.assertGreaterEqual(stock[key], qty)
                    stock[key] -= qty
                stock.update(row["receive"])
            self.assertEqual(route["ending_account"]["gingerscope_copies"], 1)
            self.assertIsNone(route["ending_account"]["total_listed_value"])
        self.assertIsNone(report["realized_growth"])

    def test_equal_value_round_trip_is_recognized_as_a_cycle(self):
        report = search({"godly:Fang": 1}, [{"godly:Chill": 1}, {"godly:Fang": 1}], max_steps=2)
        self.assertGreater(report["search"]["cycles_excluded"], 0)
        self.assertEqual(report["routes"], [])

    def test_retention_and_budget_cover_more_than_first_candidate(self):
        main = {"godly:Fang": 4, "godly:Chill": 4, "godly:Clockwork": 4, "godly:Heat": 4,
                "godly:Spider": 4}
        partners = [{"godly:Plasmabeam": 4, "godly:Green_Luger": 4, "godly:Gemstone": 4,
                     "godly:Iceflake": 4, "godly:Old_Glory": 4}]
        options = {"max_steps": 1, "max_pairs": 61, "max_bundles_per_side": 11,
                   "copies_per_slot": 4}
        report = search(main, partners, **options)
        self.assertEqual(report["search"]["pairs_examined"], 61)
        self.assertTrue(report["search"]["pair_budget_truncated"])
        self.assertTrue(report["search"]["bundle_budget_truncated"])
        self.assertGreater(len({tuple(row["give"]) for row in report["alternatives"]}), 1)
        self.assertEqual(report, search(dict(reversed(list(main.items()))), partners, **options))

    def test_target_remains_available_when_incoming_bundle_budget_is_tiny(self):
        result = search({"godly:Fang": 1}, [{"ancient:Corrupt": 1, "ancient:Gingerscope": 1,
                                             "godly:Gemstone": 1}], max_bundles_per_side=1)
        self.assertTrue(any(row["includes_incoming_gingerscope"] for row in result["alternatives"]))
        self.assertTrue(result["search"]["bundle_budget_truncated"])

    def test_small_pair_budget_still_examines_one_root_pair(self):
        result = search({"godly:Fang": 1}, [{"godly:Gemstone": 1}, {"godly:Green_Luger": 1}],
                        max_steps=2, max_pairs=1)
        self.assertEqual(result["search"]["pairs_examined"], 1)
        self.assertEqual(len(result["alternatives"]), 1)
        self.assertTrue(result["search"]["pair_budget_truncated"])

    @given(main=SMALL_STOCK, partner=SMALL_STOCK)
    @settings(max_examples=40, derandomize=True)
    @example(main={"godly:Fang": 1, "godly:Bioblade": 1, "godly:Chill": 1},
             partner={"godly:Fang": 1, "godly:Boneblade": 1, "godly:Gemstone": 1})
    def test_small_pair_counts_match_exhaustive_independent_calculation(self, main, partner):
        def enumerate_stock(stock):
            return [dict(zip(stock, quantities)) for quantities in
                    product(*(range(stock[key] + 1) for key in stock)) if any(quantities)]

        bundles = [enumerate_stock(stock) for stock in (main, partner)]
        # The two sides can have disjoint item domains. Sum missing quantities
        # as zero across their union for the independent arithmetic.
        deltas = [sum(SMALL_PRICES[k] * (incoming.get(k, 0) - outgoing.get(k, 0)) for k in SMALL_PRICES)
                  for outgoing, incoming in product(*bundles)
                  if not any(outgoing.get(k) and incoming.get(k) for k in SMALL_PRICES)]
        report = search(main, [partner], max_steps=1, copies_per_slot=2)
        self.assertEqual(report["search"]["pairs_examined"], len(bundles[0]) * len(bundles[1]))
        self.assertEqual(report["search"]["non_loss_pairs"], sum(n >= 0 for n in deltas))
        self.assertEqual(report["search"]["listed_loss_pairs_excluded"], sum(n < 0 for n in deltas))
        self.assertEqual(max((row["main_listed_delta"] for row in report["alternatives"]), default=None),
                         max((delta for delta in deltas if delta >= 0), default=None))

    def test_observed_paper_offer_preserves_bilateral_ranges_and_uncertainty(self):
        give = {"ancient:Emberbow": 1}
        receive = {"ancient:Emberscythe": 1}
        row = evaluate_offer(ARCHIVE, give, receive, give, receive, evaluated_at_utc=AT)
        self.assertEqual(row["published_range_deltas"], {
            "main_low": -50, "main_high": 50, "counterparty_low": -50, "counterparty_high": 50,
        })
        self.assertFalse(row["authorizes_trade"])
        self.assertIsNone(row["acceptance_probability"])

    def test_nominal_gain_can_reduce_single_account_purchase_capacity(self):
        give = {"ancient:Harvester": 1}
        own = {**give, "godly:Borealis": 1, "godly:Australis": 1, "godly:Icecream": 1}
        partner = {"godly:Embersickle": 1, "godly:Immortal": 1, "godly:Mortal": 1}
        row = evaluate_offer(ARCHIVE, own, partner, give, partner, evaluated_at_utc=AT)
        self.assertEqual(row["main_listed_delta"], 60)
        self.assertEqual(row["main_four_slot_capacity_change"], -180)
        self.assertIn("PAPER_PURCHASING_POWER_DETERIORATION", row["warnings"])
        self.assertIn("PAPER_PORTFOLIO_DEMAND_DETERIORATION", row["warnings"])

    def test_listed_loss_is_research_only_and_never_a_route(self):
        main = {"godly:Fang": 1}
        partners = [{"godly:Boneblade": 1}, {"godly:Gemstone": 1}]
        default = search(main, partners)
        self.assertEqual(default["listed_loss_research"], [])
        report = search(main, partners, include_loss_research=True)
        self.assertTrue(report["listed_loss_research"])
        self.assertTrue(report["alternatives"])
        self.assertTrue(all(row["main_listed_delta"] >= 0 for row in report["alternatives"]))
        self.assertTrue(all(row["disposition"] == "LISTED_LOSS_RESEARCH_ONLY" and not row["authorizes_trade"]
                            for row in report["listed_loss_research"]))

    def test_explicit_invalid_offer_cannot_use_protection_unknowns_or_extra_slots(self):
        main = {"ancient:Gingerscope": 1, "godly:Fang": 1, "godly:Unknown": 1,
                "godly:Chill": 1, "godly:Clockwork": 1, "godly:Heat": 1, "godly:Spider": 1}
        partner = {"godly:Gemstone": 1, "godly:Fang": 1}
        for give, receive in [
            ({"ancient:Gingerscope": 1}, {"godly:Gemstone": 1}),
            ({"godly:Unknown": 1}, {"godly:Gemstone": 1}),
            ({"godly:Fang": 2}, {"godly:Gemstone": 1}),
            ({"godly:Bioblade": 1}, {"godly:Gemstone": 1}),
            ({"godly:Fang": True}, {"godly:Gemstone": 1}),
            ({"godly:Fang": 1}, {"godly:Fang": 1}),
            ({key: 1 for key in ("godly:Fang", "godly:Chill", "godly:Clockwork", "godly:Heat", "godly:Spider")},
             {"godly:Gemstone": 1}),
        ]:
            with self.subTest(give=give), self.assertRaises(RequestError):
                evaluate_offer(ARCHIVE, main, partner, give, receive, evaluated_at_utc=AT, copies_per_slot=4)

    def test_stack_research_counts_copies_separately_and_never_advises(self):
        main = {"godly:Boneblade": 4, "godly:Orange_Seer": 4}
        partner = {"godly:Gemstone": 4}
        row = evaluate_offer(ARCHIVE, main, partner, main, partner,
                             evaluated_at_utc=AT, copies_per_slot=4)
        self.assertEqual((row["main_slots"], row["main_copies"]), (2, 8))
        self.assertEqual(row["disposition"], "STACK_ASSUMPTION_RESEARCH_ONLY")
        self.assertIsNone(row["published_range_deltas"])

    def test_source_expiry_and_tampering_are_errors(self):
        for raw, at in ((ARCHIVE, "2026-11-25T12:10:00Z"), (ARCHIVE+b" ", AT)):
            with self.assertRaises(ValueError):
                plan(raw, {"godly:Boneblade": 1}, [{"godly:Fang": 1}], evaluated_at_utc=at)

    def test_preloaded_market_edition_is_rechecked_for_expiry(self):
        edition = load_edition(ARCHIVE, evaluated_at_utc=AT)
        self.assertEqual(search({"godly:Boneblade": 1}, [{"godly:Fang": 1}], edition=edition)["source"],
                         edition.provenance)
        with self.assertRaises(ValueError):
            plan(ARCHIVE, {"godly:Boneblade": 1}, [{"godly:Fang": 1}], edition=edition,
                 evaluated_at_utc="2026-11-25T12:10:00Z")

    def test_missing_target_price_preserves_holdings_and_allows_unrelated_advice(self):
        raw = archive(changed=True, target_missing=True)
        edition = load_edition(raw, evaluated_at_utc=NEXT_CAPTURE, expected_sha256=sha256(raw).hexdigest())
        result = plan(raw, {"ancient:Gingerscope": 1, "godly:Bioblade": 1},
                      [{"chroma:CLuger": 1}], evaluated_at_utc=NEXT_CAPTURE, edition=edition)
        self.assertIsNone(result["target_listed_value"])
        self.assertIsNone(result["starting_account"]["four_slot_single_copy_target_gap"])
        self.assertEqual(result["starting_account"]["gingerscope_copies"], 1)
        self.assertEqual(result["starting_account"]["unpriced_copies"], 1)
        self.assertEqual(result["alternatives"][0]["give"], {"godly:Bioblade": 1})
        self.assertEqual(result["alternatives"][0]["main_after"]["gingerscope_copies"], 1)

    def test_target_is_held_after_acquisition_and_route_can_continue(self):
        report = search({"ancient:Travelers_Axe": 1, "godly:Boneblade": 1},
                        [{"ancient:Gingerscope": 1}, {"godly:Fang": 1}], max_steps=2)
        route = next(route for route in report["routes"] if route["steps"][0]["includes_incoming_gingerscope"])
        self.assertEqual(route["ending_account"]["gingerscope_copies"], 1)
        self.assertNotIn("ancient:Gingerscope", route["steps"][1]["give"])
        self.assertGreater(route["steps"][1]["main_listed_delta"], 0)


if __name__ == "__main__":
    unittest.main()
