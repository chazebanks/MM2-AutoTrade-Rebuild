"""Stage 5 offline inventory-growth TDD: realistic invariants, no observed acceptance."""
from __future__ import annotations

from datetime import datetime, timezone, timedelta
from decimal import Decimal
import copy
import json
from pathlib import Path
import random
import unittest

from evaluator import AssessmentError, Catalog, Item
from growth_planner import plan_growth
from market_bridge import load_market

HERE=Path(__file__).parent
NOW=datetime(2026,11,5,13,53,10,tzinfo=timezone.utc)
def k(page,id):return f"{page}:{id}:checker-id"
def fixture():return load_market(json.loads((HERE/'market_excerpt_fixture.json').read_text()), NOW).catalog

class GrowthTests(unittest.TestCase):
    def setUp(self):
        self.cat=fixture()
        self.own={k('chroma','810'):1,k('chroma','1029'):1,
                  k('godly','1031'):2,k('godly','1032'):2,
                  k('godly','481'):3,k('godly','448'):2,k('godly','27'):1,
                  k('godly','21'):1}
        self.their={k('chroma','1033'):1,k('godly','481'):2,k('godly','524'):1}
    def plan(self,**kwargs):return plan_growth(self.own,self.their,self.cat,NOW,**kwargs)
    def test_has_distinct_growth_lanes_and_goal_from_catalogue(self):
        result=self.plan()
        self.assertEqual(result.observed_targets,3)
        self.assertEqual(result.gingerscope_listed_value,Decimal(16000))
        self.assertGreater(result.reviewable_quotes,0)
        self.assertTrue(result.wealth_candidates)
        self.assertTrue(result.four_copy_candidates)
        self.assertTrue(all(c.decision=='offline-human-review-only' for c in result.wealth_candidates))
    def test_initial_gaps_are_not_total_inventory_gaps(self):
        r=self.plan()
        self.assertEqual(r.own_four_copy_ceiling,Decimal(3870))
        self.assertEqual(r.gingerscope_four_copy_gap,Decimal(12130))
        self.assertGreater(r.own_listed_lower_bound,r.own_four_copy_ceiling)
    def test_source_verified_chroma_mortal_upgrade(self):
        r=self.plan(goals=[{k('chroma','1033'):1}],limit=50)
        target=[x for x in r.four_copy_candidates if x.four_copy_delta>0]
        self.assertTrue(target)
        self.assertEqual(target[0].receive,((k('chroma','1033'),1),))
        self.assertTrue(all(x.listed_gain>=0 and x.four_copy_delta>0 for x in target))
    def test_wealth_lane_descends_by_gain_and_never_relabels_probability(self):
        a=self.plan(limit=50)
        self.assertEqual(list(a.wealth_candidates), sorted(a.wealth_candidates,key=lambda x:-x.listed_gain))
        self.assertTrue(all(x.listed_gain>0 for x in a.wealth_candidates))
        self.assertTrue(all(not hasattr(x,'acceptance_probability') for x in a.wealth_candidates))
    def test_profit_does_not_mask_lost_four_copy_or_bad_stability(self):
        # A 2,300 anchor is exchanged for 4 copies of 600 = 2,400.
        # Total grows +100, yet conservative four-copy strength drops:
        # the fifth+ copies cannot all fit into one four-copy offer.
        own={k('chroma','810'):1,k('chroma','1029'):1,
             k('godly','1031'):1,k('godly','1032'):1}
        receiving=k('godly','99999')
        items=dict(self.cat.items)
        items[receiving]=Item(receiving,600,1,'fluctuating')
        market=Catalog(items,self.cat.observed_at,self.cat.valid_until,self.cat.source)
        result=plan_growth(own,{receiving:4},market,NOW,goals=[{receiving:4}],
                           min_review_coverage=Decimal('0.9'),limit=20)
        self.assertTrue(result.wealth_candidates)
        loss=[x for x in result.wealth_candidates if x.listed_gain>0 and x.four_copy_delta<0]
        self.assertTrue(loss)
        self.assertIn('four-copy-power-lost-even-if-nominal-profit-positive',loss[0].flags)
        self.assertIn('received-includes-low-source-demand',loss[0].flags)
        self.assertIn('received-includes-fluctuating-or-underpaid-status',loss[0].flags)
        self.assertTrue(any(x==loss[0] for x in result.caution_candidates))

    def test_downgrade_copy_growth_is_flagged(self):
        own={k('godly','481'):1}  #33
        their={k('godly','27'):4}  #28 (not a positive gain, so no wealth candidate)
        r=plan_growth(own,their,self.cat,NOW,goals=[{k('godly','27'):4}],
                      min_review_coverage=Decimal(0))
        self.assertFalse(r.wealth_candidates)
        # A different incoming four copies can be valid given low-value outgoing.
        own2={k('godly','27'):1}  #7
        their2={k('godly','481'):2}  #66
        r2=plan_growth(own2,their2,self.cat,NOW,goals=[{k('godly','481'):2}],
                       min_review_coverage=Decimal(0))
        self.assertTrue(r2.wealth_candidates)
        self.assertIn('downgrade-increases-copy-count',r2.wealth_candidates[0].flags)
        self.assertEqual(r2.wealth_candidates[0].category,'downgrade')
    def test_unknown_opponent_items_are_not_discovered(self):
        opp=dict(self.their);opp['common:fake:1']=3
        r=plan_growth(self.own,opp,self.cat,NOW)
        self.assertEqual(r.observed_targets,3)
    def test_explicit_unknown_target_rejected(self):
        with self.assertRaisesRegex(AssessmentError,'requested-item-not-verified'):
            plan_growth(self.own,{**self.their,'common:fake:1':1},self.cat,NOW,goals=[{'common:fake:1':1}])
        with self.assertRaisesRegex(AssessmentError,'requested-quantity-not-owned'):
            self.plan(goals=[{k('chroma','1033'):2}])
        with self.assertRaisesRegex(AssessmentError,'target-exceeds-conservative-four-copy-limit'):
            self.plan(goals=[{k('godly','481'):5}])
    def test_no_hidden_profit_floor(self):
        # +0 and +1 can exist, unlike historical +15 minimum.
        own={k('godly','21'):1} #23
        opp={k('godly','21'):1}
        # overlap prevents exchange of same item; use a synthetic similarly-valued variant
        it=dict(self.cat.items)
        fake=k('godly','10001'); it[fake]=Item(fake,Decimal(24),3,'stable')
        market=Catalog(it,self.cat.observed_at,self.cat.valid_until,self.cat.source)
        r=plan_growth(own,{fake:1},market,NOW)
        self.assertEqual(r.wealth_candidates[0].listed_gain,Decimal(1))
    def test_risk_status_receiving_unstable_is_flagged(self):
        own={k('godly','481'):3,k('godly','27'):1}
        theirs={k('godly','1031'):1}
        # No non-overpay offer >=90% likely; opt into diagnostic 0 coverage.
        r=plan_growth(own,theirs,self.cat,NOW,min_review_coverage=Decimal(0))
        self.assertTrue(r.wealth_candidates)
        self.assertIn('received-includes-fluctuating-or-underpaid-status',r.wealth_candidates[0].flags)
    def test_stale_market_fails_closed(self):
        with self.assertRaisesRegex(AssessmentError,'price-snapshot-not-valid'):
            plan_growth(self.own,self.their,self.cat,NOW+timedelta(days=2))
    def test_no_overpay_no_mutation_and_determinism(self):
        ours=copy.deepcopy(self.own); theirs=copy.deepcopy(self.their)
        a=self.plan(limit=15); b=self.plan(limit=15)
        self.assertEqual(a,b)
        self.assertEqual(self.own,ours);self.assertEqual(self.their,theirs)
        for c in a.wealth_candidates+a.four_copy_candidates+a.quality_candidates+a.caution_candidates:
            self.assertGreaterEqual(c.listed_gain,Decimal(0))
            self.assertLessEqual(c.offered_copies,4)
            self.assertLessEqual(c.received_copies,4)
            self.assertEqual(c.received_value-c.offered_value,c.listed_gain)
    def test_explicit_pair_targets_only_when_requested(self):
        r=self.plan(include_pairs=True)
        self.assertEqual(r.observed_targets,6)
        s=self.plan(goals=[{k('godly','481'):1,k('godly','524'):1}])
        self.assertEqual(s.observed_targets,1)
        self.assertTrue(all(x.receive==((k('godly','481'),1),(k('godly','524'),1)) for x in s.wealth_candidates))
    def test_partial_inventory_is_explicit_and_not_called_complete(self):
        own=dict(self.own);own['common:unknown:unmapped']=10
        their=dict(self.their);their['common:unknown:other']=2
        r=plan_growth(own,their,self.cat,NOW)
        self.assertEqual(r.own_unpriced_copies,10)
        self.assertEqual(r.opponent_unpriced_copies,2)
        self.assertGreater(r.own_listed_lower_bound,Decimal(0))

    def test_no_viable_review_quote_returns_hold_reason(self):
        r=plan_growth({k('godly','27'):1},{k('ancient','771'):1},self.cat,NOW)
        self.assertEqual(r.no_candidate_reason,'no-verified-quote-within-display-gate')
        self.assertFalse(r.wealth_candidates)

    def test_target_budget_fail_closed(self):
        with self.assertRaisesRegex(AssessmentError,'growth-target-budget-exceeded'):
            self.plan(max_targets=1)
        with self.assertRaisesRegex(AssessmentError,'growth-target-budget-exceeded'):
            self.plan(include_pairs=True,max_targets=4)
    def test_quote_search_budget_fail_closed(self):
        with self.assertRaisesRegex(AssessmentError,'quote-search-budget-exceeded'):
            self.plan(search_budget_each=1)
    def test_no_direct_gingerscope_quote_from_own_inventory(self):
        r=plan_growth(self.own,{k('ancient','771'):1},self.cat,NOW)
        self.assertEqual(r.reviewable_quotes,0)
        self.assertEqual(r.four_copy_candidates,())
        self.assertEqual(r.wealth_candidates,())
        self.assertEqual(r.gingerscope_listed_value,Decimal(16000))
    def test_cannot_overfill_quantities(self):
        with self.assertRaisesRegex(AssessmentError,'invalid-asset-quantity'):
            plan_growth({k('godly','27'):0},self.their,self.cat,NOW)
    def test_empty_explicit_list_yields_hold_not_fabricated_trade(self):
        result=self.plan(goals=[])
        self.assertEqual(result.observed_targets,0)
        self.assertEqual(result.reviewable_quotes,0)
        self.assertEqual(result.wealth_candidates,())
    def test_parameter_validation(self):
        with self.assertRaisesRegex(AssessmentError,'invalid-target-budget'):
            self.plan(max_targets=0)
        with self.assertRaisesRegex(AssessmentError,'invalid-result-budget'):
            self.plan(limit=101)
        with self.assertRaisesRegex(AssessmentError,'invalid-quote-coverage-gate'):
            self.plan(min_review_coverage=Decimal('1.2'))
        with self.assertRaisesRegex(AssessmentError,'invalid-pair-discovery'):
            self.plan(include_pairs=1)
    def test_randomized_candidate_invariants(self):
        rng=random.Random(20261105)
        for _ in range(60):
            owned={key:rng.randint(1,num) for key,num in self.own.items() if rng.random()>.4}
            if not owned: owned={k('godly','27'):1}
            r=plan_growth(owned,{k('chroma','1033'):1},self.cat,NOW,limit=5)
            for c in r.wealth_candidates+r.four_copy_candidates:
                self.assertEqual(c.gingerscope_gap_after,max(Decimal(0),Decimal(16000)-c.four_copy_after))
                self.assertEqual(sum(q for _,q in c.give),c.offered_copies)

if __name__=='__main__':unittest.main()
