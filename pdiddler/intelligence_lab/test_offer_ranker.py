"""Stage 4: review-only quote ranking, no Roblox / network / live acceptance."""
import copy
import json
import random
import unittest
from datetime import datetime, timezone, timedelta
from decimal import Decimal
from pathlib import Path

from evaluator import AssessmentError, Item, Catalog
from market_bridge import load_market
from offer_ranker import rank_offers

HERE = Path(__file__).parent
NOW = datetime(2026, 11, 5, 13, 53, 10, tzinfo=timezone.utc)


def market_fixture():
    return load_market(json.loads((HERE / "market_excerpt_fixture.json").read_text()), NOW).catalog


def key(page, id):
    return f"{page}:{id}:checker-id"


class QuoteRankingTests(unittest.TestCase):
    def setUp(self):
        self.catalog = market_fixture()
        self.own = {
            key("chroma", "810"): 1,  # 2300, stable
            key("chroma", "1029"): 1,  # 1300, fluctuating
            key("godly", "1031"): 2,  # 135 each
            key("godly", "1032"): 2,  # 135 each
            key("godly", "481"): 3,  # 33 each
            key("godly", "27"): 1,  # 7
            key("godly", "21"): 1,  # 23
        }
        self.their = {key("chroma", "1033"): 1}  # 1600, Doing Well
        self.want = {key("chroma", "1033"): 1}

    def rank(self, **kwargs):
        return rank_offers(self.own, self.their, self.want, self.catalog, NOW, **kwargs)

    def test_deterministic_and_non_overpay(self):
        left = self.rank(limit=12)
        right = self.rank(limit=12)
        self.assertEqual(left, right)
        self.assertGreater(left.evaluated_combinations, 1)
        self.assertTrue(left.offers)
        self.assertTrue(all(o.gain >= 0 for o in left.offers))
        self.assertTrue(all(len(o.give) <= 4 and sum(q for _,q in o.give) <= 4 for o in left.offers))
        self.assertEqual(left.target_value, Decimal("16000"))

    def test_sorted_primarily_by_quote_value_coverage(self):
        quotes = self.rank(limit=50).offers
        self.assertEqual(list(quotes), sorted(quotes, key=lambda x: -x.coverage))
        self.assertGreater(quotes[0].coverage, Decimal("0.95"))
        self.assertEqual(quotes[0].receive_value, Decimal(1600))

    def test_not_speculative_boneblade_only_when_better_quotes_exist(self):
        quotes = self.rank().offers
        self.assertNotEqual(quotes[0].give, ((key("godly", "27"), 1),))
        self.assertLess(quotes[0].gain, Decimal(100))
        self.assertEqual(quotes[0].review_label, "offline-human-review-only")
        self.assertNotIn("probability", quotes[0].__dataclass_fields__)

    def test_checked_owned_quantities_and_receive(self):
        bad = dict(self.own)
        bad[key("godly", "27")] = 0
        with self.assertRaisesRegex(AssessmentError, "invalid-asset-quantity"):
            rank_offers(bad, self.their, self.want, self.catalog, NOW)
        with self.assertRaisesRegex(AssessmentError, "receive-quantity-not-owned"):
            rank_offers(self.own, self.their, {key("chroma", "1033"): 2}, self.catalog, NOW)

    def test_four_copy_limit_not_four_distinct_types(self):
        with self.assertRaisesRegex(AssessmentError, "receive-exceeds-conservative-four-copy-limit"):
            rank_offers(self.own, {key("chroma", "1033"):5}, {key("chroma", "1033"):5}, self.catalog, NOW)
        quotes = self.rank().offers
        self.assertTrue(all(sum(q for _,q in offer.give) <= 4 for offer in quotes))

    def test_no_overpay_unless_explicit(self):
        own = {key("chroma", "810"): 1}
        opponent = {key("chroma", "1029"): 1}
        receive = {key("chroma", "1029"): 1}
        safe = rank_offers(own, opponent, receive, self.catalog, NOW)
        self.assertEqual(len(safe.offers), 0)
        loss = rank_offers(own, opponent, receive, self.catalog, NOW, allow_overpay=True)
        self.assertEqual(len(loss.offers), 1)
        self.assertEqual(loss.offers[0].gain, Decimal("-1000"))
        self.assertIn("nominal-list-value-decreases", loss.offers[0].notes)

    def test_unknown_or_nontradable_items_cannot_enter_quote(self):
        with self.assertRaisesRegex(AssessmentError, "receive-item-unverified"):
            rank_offers(self.own, {"common:gift:unknown":1}, {"common:gift:unknown":1}, self.catalog, NOW)
        k = key("godly", "27")
        items = dict(self.catalog.items)
        items[k] = Item(k, 7, 1, "stable", tradable=False)
        cat = Catalog(items, self.catalog.observed_at, self.catalog.valid_until, self.catalog.source)
        own = {k:1}
        result = rank_offers(own, self.their, self.want, cat, NOW)
        self.assertEqual(result.offers, ())

    def test_goal_not_hardcoded_and_catalog_expiry(self):
        with self.assertRaisesRegex(AssessmentError, "unverified-goal-price"):
            self.rank(goal_id="ancient:unknown:checker-id")
        with self.assertRaisesRegex(AssessmentError, "price-snapshot-not-valid"):
            rank_offers(self.own, self.their, self.want, self.catalog, NOW+timedelta(days=2))

    def test_same_item_cannot_appear_on_both_sides(self):
        opponent = {key("chroma", "810"): 1}
        receive = {key("chroma", "810"): 1}
        result = rank_offers(self.own, opponent, receive, self.catalog, NOW)
        self.assertTrue(all(key("chroma", "810") not in dict(o.give) for o in result.offers))

    def test_fail_closed_on_bounded_search(self):
        with self.assertRaisesRegex(AssessmentError, "quote-search-budget-exceeded"):
            self.rank(max_combinations=1)
        with self.assertRaisesRegex(AssessmentError, "invalid-search-budget"):
            self.rank(max_combinations=0)
        with self.assertRaisesRegex(AssessmentError, "unsupported-conservative-copy-cap"):
            self.rank(max_copies=5)

    def test_preserves_inventory_and_item_quality(self):
        before = dict(self.own)
        after = dict(self.their)
        candidates = self.rank().offers
        self.assertEqual(self.own, before)
        self.assertEqual(self.their, after)
        self.assertTrue(all(o.opening_item in self.own for o in candidates))
        self.assertTrue(all(0 <= o.opening_demand_ordinal <= 11 for o in candidates))
        self.assertTrue(all(o.goal_four_copy_gap_after is not None for o in candidates))

    def test_two_distinct_review_lanes_without_fake_acceptance_score(self):
        r=self.rank(limit=12)
        self.assertTrue(r.progression_offers)
        self.assertEqual(len(r.progression_offers), len(r.offers))
        self.assertTrue(all(r.progression_offers[i].four_copy_delta >= r.progression_offers[i+1].four_copy_delta
                            for i in range(len(r.progression_offers)-1)))
        self.assertTrue(all(o.review_label == "offline-human-review-only" for o in r.progression_offers))

    def test_accumulation_review_lane_tracks_profit_not_closeness(self):
        ranked=self.rank(limit=100)
        self.assertTrue(ranked.accumulation_offers)
        gains=[x.gain for x in ranked.accumulation_offers]
        self.assertEqual(gains,sorted(gains,reverse=True))
        self.assertTrue(all(x.gain>=0 for x in ranked.accumulation_offers))
        self.assertEqual(ranked.accumulation_offers[0].review_label,'offline-human-review-only')

    def test_low_demand_items_flagged_not_called_personally_unwanted(self):
        b = rank_offers({key("godly", "27"):1}, self.their, self.want, self.catalog, NOW, min_review_coverage=Decimal(0))
        self.assertEqual(len(b.offers),1)
        self.assertIn("all-offered-items-have-low-source-demand",b.offers[0].notes)
        self.assertIn("counterparty-would-be-giving-more-listed-value",b.offers[0].notes)
        self.assertTrue(all("acceptance" not in f for f in b.offers[0].notes))

    def test_no_silent_truncation_or_numeric_loss_reinterpretation(self):
        # No loss allowed by default, even when the after-portfolio might be more concentrated.
        res=self.rank(limit=3)
        self.assertLessEqual(len(res.offers),3)
        self.assertEqual(res.valid_non_overpay_combinations+res.wide_gap_combinations, res.evaluated_combinations)

    def test_huge_gingerscope_underquote_is_not_presented_as_reviewable(self):
        goal = {key("ancient", "771"):1}
        r = rank_offers(self.own, goal, goal, self.catalog, NOW)
        self.assertEqual(r.offers, ())
        self.assertLess(r.best_listed_coverage, r.min_review_coverage)
        self.assertGreater(r.wide_gap_combinations,0)

    def test_review_gap_is_configurable_and_not_acceptance_probability(self):
        under = rank_offers({key("godly", "27"):1}, self.their, self.want, self.catalog, NOW)
        self.assertEqual(under.offers, ())
        raw = rank_offers({key("godly", "27"):1}, self.their, self.want, self.catalog, NOW, min_review_coverage=Decimal("0"))
        self.assertEqual(len(raw.offers),1)
        self.assertTrue(raw.offers[0].coverage < Decimal("0.01"))
        with self.assertRaisesRegex(AssessmentError,"invalid-quote-coverage-gate"):
            self.rank(min_review_coverage=Decimal("1.10"))

    def test_seeded_fuzz_matches_exact_offer_value(self):
        rng = random.Random(20261105)
        available = list(self.own)
        for _ in range(100):
            chosen = {k:rng.randint(1,self.own[k]) for k in available if rng.random()<0.45}
            if not chosen:
                chosen = {key("godly", "27"):1}
            result=rank_offers(chosen,self.their,self.want,self.catalog,NOW,limit=7)
            for offer in result.offers:
                self.assertEqual(offer.give_value, sum((self.catalog.items[k].value*q for k,q in offer.give),Decimal(0)))
                self.assertEqual(offer.gain, offer.receive_value - offer.give_value)
                self.assertLessEqual(sum(q for _,q in offer.give),4)


if __name__ == "__main__":
    unittest.main()
