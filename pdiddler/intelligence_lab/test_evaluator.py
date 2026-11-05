"""TDD fixture tests: no live inventory values or external network dependencies."""
import unittest
import random
from datetime import datetime, timezone
from decimal import Decimal
from evaluator import Item, Catalog, AssessmentError, money, evaluate, compare, portfolio_metrics

T0 = datetime(2026, 11, 5, 12, tzinfo=timezone.utc)
T1 = datetime(2026, 11, 6, 12, tzinfo=timezone.utc)


def sample_catalog():
    # Synthetic units, NOT a current Supreme price snapshot.
    items = {
        "chroma:watergun:sample": Item("chroma:watergun:sample", Decimal("2300"), 5, "stable"),
        "chroma:embersickle:sample": Item("chroma:embersickle:sample", Decimal("1300"), 5, "fluctuating"),
        "godly:immortal:sample": Item("godly:immortal:sample", Decimal("135"), 5, "stable"),
        "godly:mortal:sample": Item("godly:mortal:sample", Decimal("135"), 3, "stable"),
        "godly:boneblade:sample": Item("godly:boneblade:sample", Decimal("7"), 1, "stable"),
        "godly:appealing:sample": Item("godly:appealing:sample", Decimal("130"), 8, "stable"),
        "godly:volatile:sample": Item("godly:volatile:sample", Decimal("150"), 2, "fluctuating"),
        "ancient:gingerscope:2023": Item("ancient:gingerscope:2023", Decimal("16000"), 5, "stable"),
        "pet:snowman:sample": Item("pet:snowman:sample", Decimal("20"), 1, "stable", tradable=False),
    }
    return Catalog(items, datetime(2026,11,5,0,tzinfo=timezone.utc), T1, "synthetic-test-only")


class TestAssessment(unittest.TestCase):
    def setUp(self):
        self.m = sample_catalog()
        self.ours = {"godly:boneblade:sample":1, "godly:immortal:sample":2}
        self.theirs = {"godly:appealing:sample":1,"godly:volatile:sample":1}

    def test_no_fixed_profit_floor(self):
        a=evaluate(self.ours,self.theirs,{"godly:immortal:sample":1},{"godly:appealing:sample":1},self.m,T0)
        self.assertEqual(a.net_listed_value,Decimal("-5"))
        self.assertEqual(a.decision,"human-review-only")
        self.assertIn("nominal-list-value-decreases",a.warnings)

    def test_positive_nominal_result_does_not_claim_acceptance(self):
        a=evaluate(self.ours,self.theirs,{"godly:boneblade:sample":1},{"godly:volatile:sample":1},self.m,T0)
        self.assertEqual(a.net_listed_value,Decimal("143"))
        self.assertIn("demand-profile-not-unambiguously-better",a.warnings)
        self.assertEqual(a.decision,"human-review-only")

    def test_compare_improvement_dominance(self):
        self.ours={"godly:boneblade:sample":1}
        self.theirs={"godly:appealing:sample":1,"godly:immortal:sample":1}
        # Same full portfolio qualities and equal nominal value is a tie.
        a=evaluate(self.ours,self.theirs,{"godly:boneblade:sample":1},{"godly:appealing:sample":1},self.m,T0)
        self.assertEqual(compare(a,a),"equal")

    def test_no_mutation_and_duplicates(self):
        original=dict(self.ours)
        a=evaluate(self.ours,self.theirs,{"godly:immortal:sample":1},{"godly:appealing:sample":1},self.m,T0)
        self.assertEqual(self.ours,original)
        self.assertEqual(a.after.priced_value_lower_bound,Decimal("272"))

    def test_demand_and_stability_comparison(self):
        self.ours={"godly:boneblade:sample":1}
        a=evaluate(self.ours,self.theirs,{"godly:boneblade:sample":1},{"godly:appealing:sample":1},self.m,T0)
        b=evaluate(self.ours,self.theirs,{"godly:boneblade:sample":1},{"godly:volatile:sample":1},self.m,T0)
        self.assertEqual(a.demand_profile,"better")
        self.assertEqual(b.demand_profile,"better")
        self.assertEqual(compare(a,b),"incomparable")  # more value vs better demand+stable share

    def test_pairwise_tradeoff_is_not_falsely_dominated(self):
        self.ours={"godly:boneblade:sample":1}
        self.theirs={"godly:appealing:sample":1,"godly:immortal:sample":1}
        a=evaluate(self.ours,self.theirs,{"godly:boneblade:sample":1},{"godly:appealing:sample":1},self.m,T0)
        b=evaluate(self.ours,self.theirs,{"godly:boneblade:sample":1},{"godly:immortal:sample":1},self.m,T0)
        self.assertEqual(compare(a,b),"incomparable")  # demand difference, but b has higher listed value

    def test_four_copy_and_four_stack_ceiling_differ(self):
        holdings={"godly:immortal:sample":2,"godly:mortal:sample":2,"chroma:watergun:sample":1,"chroma:embersickle:sample":1}
        m=portfolio_metrics(holdings,self.m)
        self.assertEqual(m.four_copy_ceiling,Decimal("3870"))
        self.assertEqual(m.four_type_stack_ceiling,Decimal("4140"))

    def test_unknown_portfolio_item_is_not_zero_valued(self):
        holdings=dict(self.ours)
        holdings["uncommon:gift:unknown-year"]=7
        a=evaluate(holdings,self.theirs,{"godly:boneblade:sample":1},{"godly:appealing:sample":1},self.m,T0)
        self.assertEqual(a.before.unpriced_units,7)
        self.assertIn("portfolio-totals-are-lower-bounds",a.warnings)
        with self.assertRaisesRegex(AssessmentError,"unknown-traded-item"):
            evaluate(holdings,{"uncommon:gift:unknown-year":1},{"godly:boneblade:sample":1},{"uncommon:gift:unknown-year":1},self.m,T0)

    def test_goal_price_comes_from_catalog_and_gap_decreases(self):
        a=evaluate(self.ours,self.theirs,{"godly:boneblade:sample":1},{"godly:appealing:sample":1},self.m,T0,goal_identity="ancient:gingerscope:2023")
        self.assertEqual(a.goal_value,Decimal(16000))
        self.assertLess(a.goal_four_copy_gap_after,a.goal_four_copy_gap_before)
        self.assertLess(a.goal_four_stack_gap_after,a.goal_four_stack_gap_before)

    def test_missing_goal_is_not_hardcoded(self):
        with self.assertRaisesRegex(AssessmentError,"unverified-goal-price"):
            evaluate(self.ours,self.theirs,{"godly:boneblade:sample":1},{"godly:appealing:sample":1},self.m,T0,goal_identity="ancient:ghost:2023")

    def test_untradable_pet_never_counts_as_offerable_value(self):
        holdings={"pet:snowman:sample":1,"godly:boneblade:sample":1}
        m=portfolio_metrics(holdings,self.m)
        self.assertEqual(m.four_copy_ceiling,Decimal(7))
        self.assertEqual(m.priced_value_lower_bound,Decimal(7))
        self.assertEqual(m.nontradable_units,1)

    def test_variant_identity_and_nontradable(self):
        with self.assertRaisesRegex(AssessmentError,"item-identity-missing-variant"):
            Item("Gifts",5,3,"stable")
        with self.assertRaisesRegex(AssessmentError,"unverified-or-nontradable-item"):
            evaluate(self.ours,{"pet:snowman:sample":1},{"godly:boneblade:sample":1},{"pet:snowman:sample":1},self.m,T0)

    def test_overdraw_cannot_be_executed(self):
        with self.assertRaisesRegex(AssessmentError,"not-owned-give-quantity"):
            evaluate(self.ours,self.theirs,{"godly:immortal:sample":3},{"godly:appealing:sample":1},self.m,T0)
        with self.assertRaisesRegex(AssessmentError,"not-owned-receive-quantity"):
            evaluate(self.ours,self.theirs,{"godly:boneblade:sample":1},{"godly:appealing:sample":2},self.m,T0)

    def test_four_slot_check(self):
        catalog=sample_catalog()
        key="godly:added:sample"
        catalog.items[key]=Item(key,Decimal(4),5,"stable")
        ours={"godly:boneblade:sample":1,"godly:immortal:sample":1,"godly:mortal:sample":1,"chroma:embersickle:sample":1,key:1}
        with self.assertRaisesRegex(AssessmentError,"too-many-distinct-slots"):
            evaluate(ours,self.theirs,ours,{"godly:appealing:sample":1},catalog,T0)

    def test_stale_prices_block(self):
        with self.assertRaisesRegex(AssessmentError,"price-snapshot-not-valid"):
            evaluate(self.ours,self.theirs,{"godly:boneblade:sample":1},{"godly:appealing:sample":1},self.m,datetime(2026,11,7,tzinfo=timezone.utc))

    def test_same_item_both_sides_block(self):
        with self.assertRaisesRegex(AssessmentError,"same-item-on-both-sides"):
            evaluate(self.ours,{"godly:immortal:sample":1},{"godly:immortal:sample":1},{"godly:immortal:sample":1},self.m,T0)

    def test_seeded_2500_scenarios_preserve_exact_owned_delta(self):
        rng=random.Random(284716)
        outgoing=["godly:boneblade:sample","godly:immortal:sample","godly:mortal:sample"]
        incoming=["godly:appealing:sample","godly:volatile:sample"]
        for _ in range(2500):
            own={key:rng.randint(1,4) for key in outgoing}
            opponent={key:rng.randint(1,4) for key in incoming}
            offer={key:rng.randint(1,own[key]) for key in outgoing if rng.random()<0.75}
            received={key:rng.randint(1,opponent[key]) for key in incoming if rng.random()<0.8}
            if not offer or not received: continue
            original_ours,original_theirs=dict(own),dict(opponent)
            assessed=evaluate(own,opponent,offer,received,self.m,T0,goal_identity="ancient:gingerscope:2023")
            exact=sum((self.m.items[k].value*n for k,n in received.items()),Decimal(0))-sum((self.m.items[k].value*n for k,n in offer.items()),Decimal(0))
            self.assertEqual(assessed.net_listed_value,exact)
            self.assertEqual(own,original_ours)
            self.assertEqual(opponent,original_theirs)
            self.assertGreaterEqual(assessed.after.priced_value_lower_bound,Decimal(0))
            self.assertLessEqual(assessed.after.four_copy_ceiling,assessed.after.priced_value_lower_bound)
            self.assertLessEqual(assessed.after.four_type_stack_ceiling,assessed.after.priced_value_lower_bound)
            self.assertEqual(assessed.decision,"human-review-only")

    def test_invalid_money(self):
        for bad in ("NaN","Infinity",-3,True,"1.001"):
            with self.subTest(bad=bad),self.assertRaises(AssessmentError):
                money(bad)


if __name__ == "__main__":
    unittest.main()

