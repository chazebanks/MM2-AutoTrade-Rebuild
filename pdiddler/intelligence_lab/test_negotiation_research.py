"""Stage 7 deterministic contract tests, no native trading or private exports."""
from __future__ import annotations

from datetime import datetime, timezone, timedelta
from decimal import Decimal
from pathlib import Path
import json
import random
import unittest

from evaluator import AssessmentError, Catalog, Item
from market_bridge import load_market
from negotiation_research import study_counteroffers

HERE = Path(__file__).parent
NOW = datetime(2026, 11, 5, 16, 20, tzinfo=timezone.utc)


def market_with_harvester():
    market = load_market(json.loads((HERE / "market_excerpt_fixture.json").read_text()), NOW)
    items = dict(market.catalog.items)
    items["ancient:526:checker-id"] = Item(
        "ancient:526:checker-id", Decimal(250), 3, "stable",
    )
    items["godly:404:checker-id"] = Item("godly:404:checker-id", Decimal(18), 1, "stable")
    items["godly:55:checker-id"] = Item("godly:55:checker-id", Decimal(2), 1, "stable")
    return Catalog(items, market.catalog.observed_at, market.catalog.valid_until, market.catalog.source)


def ours():
    # Synthetic fixture, deliberately not a real player's full inventory.
    return {
        "chroma:810:checker-id":1,"chroma:1029:checker-id":1,
        "godly:1031:checker-id":1,"godly:1032:checker-id":1,
        "godly:984:checker-id":1,"godly:481:checker-id":2,
        "godly:448:checker-id":1,"chroma:527:checker-id":1,
        "godly:21:checker-id":1,"godly:46:checker-id":2,
        "godly:572:checker-id":1,"godly:27:checker-id":1,
    }


HARV = "ancient:526:checker-id"
LOG = "godly:404:checker-id"


class NegotiationContract(unittest.TestCase):
    def setUp(self):
        self.cat = market_with_harvester()
        self.own = ours()
        self.op = {HARV:1}

    def run_harvester(self, **kwargs):
        return study_counteroffers(self.own,self.op,{HARV:1},self.cat,NOW,**kwargs)

    def test_bounded_harvester_upgrade_is_visible(self):
        r=self.run_harvester(limit=100)
        self.assertEqual(r.target_listed_value,Decimal(250))
        self.assertEqual(r.max_study_concession,Decimal("12.50"))
        found=[x for x in r.bounded_concessions if x.give_value == 258]
        self.assertTrue(found)
        x=found[0]
        self.assertEqual(x.our_listed_gain,Decimal(-8))
        self.assertEqual(x.seller_surplus,Decimal(8))
        self.assertEqual(x.our_four_copy_delta,Decimal(115))
        self.assertEqual(x.decision,"offline-human-review-only")
        self.assertIn("bounded-nominal-overpay-experimental",x.source_flags)
        self.assertFalse(r.native_ready)

    def test_best_gains_and_concessions_are_distinct_lanes(self):
        r=self.run_harvester()
        self.assertTrue(r.accumulating)
        self.assertTrue(r.four_copy_growth)
        self.assertTrue(r.value_matched)
        self.assertTrue(r.bounded_concessions)
        self.assertTrue(all(q.seller_surplus > 0 for q in r.bounded_concessions))
        self.assertTrue(all(q.our_listed_gain > 0 for q in r.accumulating))
        self.assertTrue(all(q.our_four_copy_delta > 0 for q in r.four_copy_growth))

    def test_hard_four_physical_copies(self):
        r=self.run_harvester(limit=100)
        for lane in (r.value_matched,r.bounded_concessions,r.four_copy_growth,r.accumulating):
            for row in lane:
                self.assertLessEqual(row.offered_copy_count,4)
                self.assertEqual(row.offered_copy_count,sum(q for _,q in row.give))

    def test_loss_never_exceeds_min_of_fraction_and_absolute_cap(self):
        r=self.run_harvester(limit=100,max_concession_abs=Decimal(7))
        self.assertEqual(r.max_study_concession,Decimal(7))
        self.assertTrue(all(Decimal(0) < x.seller_surplus <= 7 for x in r.bounded_concessions))
        r=self.run_harvester(limit=100,max_concession_ratio=Decimal("0.02"))
        self.assertEqual(r.max_study_concession,Decimal(5))
        self.assertTrue(all(x.seller_surplus <= 5 for x in r.bounded_concessions))

    def test_no_loss_without_progress(self):
        small_own={"godly:984:checker-id":1,"godly:481:checker-id":1,"godly:46:checker-id":1,
                   "chroma:810:checker-id":1,"chroma:1029:checker-id":1,
                   "godly:1031:checker-id":1,"godly:1032:checker-id":1}
        # With existing huge holdings, receiving a small one doesn't affect top four.
        r=study_counteroffers(small_own, {LOG:1},{LOG:1},self.cat,NOW)
        self.assertFalse(r.bounded_concessions)

    def test_demand_one_target_cannot_unlock_overpay(self):
        op={LOG:1}
        r=study_counteroffers(self.own, op,{LOG:1},self.cat,NOW)
        self.assertFalse(r.bounded_concessions)

    def test_overpay_requires_stable_verified_upgrade(self):
        # Chroma Embersickle is fluctuating and cannot be a loss target.
        key="chroma:1029:checker-id"
        n={"godly:1031:checker-id":2,"godly:1032:checker-id":2,"godly:984:checker-id":1,
           "chroma:810:checker-id":1,"chroma:8:checker-id":1}
        r=study_counteroffers(n,{key:1},{key:1},self.cat,NOW,search_budget=1000)
        self.assertFalse(r.bounded_concessions)

    def test_quote_ownership_strict(self):
        with self.assertRaisesRegex(AssessmentError,"receive-quantity-unproven"):
            study_counteroffers(self.own,self.op,{HARV:2},self.cat,NOW)
        with self.assertRaisesRegex(AssessmentError,"receive-identity-unverified"):
            study_counteroffers(self.own,{"x:y:z":1},{"x:y:z":1},self.cat,NOW)

    def test_receive_copy_cap(self):
        with self.assertRaisesRegex(AssessmentError,"receive-physical-copies-exceed-four"):
            study_counteroffers(self.own,{HARV:5},{HARV:5},self.cat,NOW)

    def test_expired_snapshot_fails_closed(self):
        with self.assertRaisesRegex(AssessmentError,"price-snapshot-not-valid"):
            study_counteroffers(self.own,self.op,{HARV:1},self.cat,
                                datetime(2026,11,5,22,0,tzinfo=timezone.utc))

    def test_budgets_error_no_silent_truncation(self):
        with self.assertRaisesRegex(AssessmentError,"negotiation-search-budget-exceeded"):
            self.run_harvester(search_budget=1)
        for bad in (0,-1,True,1.2):
            with self.subTest(bad=bad):
                with self.assertRaises(AssessmentError):
                    self.run_harvester(search_budget=bad)

    def test_invalid_caps_rejected(self):
        for kwargs in (
            {"min_coverage":Decimal("1.01")},
            {"max_concession_ratio":Decimal("1.01")},
            {"max_concession_abs":Decimal(-1)},
            {"max_concession_abs":True},
            {"limit":101},
            {"limit":0},
        ):
            with self.subTest(kwargs=kwargs):
                with self.assertRaises(AssessmentError):
                    self.run_harvester(**kwargs)

    def test_repeatable_and_input_not_mutated(self):
        x=dict(self.own);y=dict(self.op)
        first=self.run_harvester()
        second=self.run_harvester()
        self.assertEqual(first,second)
        self.assertEqual(x,self.own)
        self.assertEqual(y,self.op)

    def test_empty_own_bundle_rejected(self):
        with self.assertRaisesRegex(AssessmentError,"invalid-or-empty-bundle"):
            study_counteroffers({},self.op,{HARV:1},self.cat,NOW)

    def test_zero_concession_keeps_equal_and_profitable_quotes(self):
        r=self.run_harvester(max_concession_abs=Decimal(0))
        self.assertFalse(r.bounded_concessions)
        self.assertTrue(all(x.our_listed_gain >= 0 for x in r.value_matched))

    def test_equal_or_profit_offers_still_have_seller_quality_flags(self):
        r=self.run_harvester(limit=100)
        self.assertTrue(any("seller-offer-has-weaker-source-demand-distribution" in x.source_flags
                            for x in r.value_matched))
        self.assertTrue(any("seller-must-accept-multiple-copies" in x.source_flags
                            for x in r.value_matched))

    def test_sorted_lanes_deterministic_under_insertion_order(self):
        x=dict(reversed(list(self.own.items())))
        other=study_counteroffers(x,self.op,{HARV:1},self.cat,NOW)
        self.assertEqual(self.run_harvester(),other)

    def test_low_value_opponent_cannot_help_four_copy_with_high_value_base(self):
        r=study_counteroffers(self.own,{LOG:1},{LOG:1},self.cat,NOW)
        self.assertFalse(r.four_copy_growth)

    def test_simulated_small_catalogue_property_bounds(self):
        rng=random.Random(72)
        for _ in range(18):
            own={k:q for k,q in self.own.items() if rng.random()<0.5}
            if not own:
                own={"godly:1031:checker-id":1}
            r=study_counteroffers(own,self.op,{HARV:1},self.cat,NOW,search_budget=50000,limit=100)
            for quote in (*r.value_matched,*r.bounded_concessions,*r.four_copy_growth,*r.accumulating):
                self.assertTrue(quote.give)
                self.assertLessEqual(quote.offered_copy_count,4)
                self.assertLessEqual(quote.seller_surplus,r.max_study_concession)
                self.assertGreaterEqual(quote.coverage,Decimal("0.90"))
                if quote.our_listed_gain<0:
                    self.assertGreater(quote.our_four_copy_delta,0)
                for k,q in quote.give:
                    self.assertLessEqual(q,own[k])

if __name__=='__main__':
    unittest.main()