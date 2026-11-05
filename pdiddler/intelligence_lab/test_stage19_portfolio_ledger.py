"""Stage 19 Python ledger tests: ALL holdings and completions are synthetic."""
from __future__ import annotations

from datetime import datetime, timezone, timedelta
from decimal import Decimal
import copy
import unittest

from evaluator import AssessmentError, Catalog, Item
from stage19_portfolio_ledger import (
    AccountSnapshot, CompletedEvent, portfolio_readiness,
    reconcile_value_change,
)

A="godly:111:checker-id"
B="chroma:222:checker-id"
C="godly:333:checker-id"
D="godly:444:checker-id"
G="ancient:771:checker-id"
BEFORE=datetime(2026,11,5,12,tzinfo=timezone.utc)
AFTER=BEFORE+timedelta(hours=2)


def market(*, later=False):
    values={A:1100 if later else 1000,B:500,C:90,D:40,G:16000}
    items={k:Item(k,Decimal(v),3,"stable") for k,v in values.items()}
    start=(BEFORE+timedelta(hours=1)) if later else (BEFORE-timedelta(hours=1))
    end=(AFTER+timedelta(hours=1)) if later else (AFTER+timedelta(hours=1))
    return Catalog(items,start,end,"synthetic-prices-only")


def snap(label,inventory,when=BEFORE,*,native=True,complete=True):
    return AccountSnapshot(label,inventory,when,
                           "native_claimed" if native else "provisional",
                           complete)


def starting(when=BEFORE):
    return (snap("main",{A:1,C:1},when),
            snap("alt",{B:1,C:2},when))


class Stage19Tests(unittest.TestCase):
    def test_accounts_must_not_be_silently_combined_for_a_trade(self):
        rows=(snap("main",{A:1,C:1,D:1}),snap("alt",{B:1,C:2}))
        result=portfolio_readiness(rows,market(),BEFORE)
        self.assertEqual(result.combined_listed_lower_bound,Decimal(1810))
        self.assertEqual(result.best_current_account_four_copy,Decimal(1130))
        self.assertEqual(result.theoretical_consolidated_four_copy,Decimal(1680))
        self.assertEqual(result.theoretical_consolidation_uplift,Decimal(550))
        self.assertEqual(result.best_current_account_gap,Decimal(14870))
        self.assertFalse(result.goal_owned)
        self.assertFalse(result.authorizes_trade)
        self.assertFalse(result.authorizes_accept)

    def test_stack_ceiling_separate_from_conservative_four_copies(self):
        rows=(snap("main",{C:6,D:6}),)
        r=portfolio_readiness(rows,market(),BEFORE)
        self.assertEqual(r.best_current_account_four_copy,Decimal(360))
        self.assertEqual(r.accounts[0].theoretical_four_type_stack_ceiling,Decimal(780))
        self.assertFalse(r.authorizes_trade)

    def test_goal_acquisition_is_explicit_and_overrides_progress_gap_interpretation(self):
        r=portfolio_readiness((snap("main",{G:1}),),market(),BEFORE)
        self.assertTrue(r.goal_owned)
        self.assertTrue(r.accounts[0].goal_owned)
        self.assertEqual(r.accounts[0].four_copy_gap,Decimal(0))

    def test_older_screenshots_are_provisional_and_stale(self):
        rows=(snap("main",{A:1},BEFORE-timedelta(hours=3),
                   native=False,complete=False),)
        r=portfolio_readiness(rows,market(),BEFORE)
        self.assertFalse(r.completeness_proven)
        self.assertFalse(r.evidence_fresh)
        self.assertEqual(r.combined_listed_lower_bound,Decimal(1000))
        self.assertFalse(r.authorizes_trade)

    def test_unknown_price_yields_only_a_lower_bound(self):
        rows=(snap("main",{A:1,"godly:999:checker-id":3}),)
        r=portfolio_readiness(rows,market(),BEFORE)
        self.assertEqual(r.combined_listed_lower_bound,Decimal(1000))
        self.assertEqual(r.accounts[0].unknown_copies,3)
        self.assertFalse(r.completeness_proven)

    def test_dup_account_or_bad_quantity_is_rejected(self):
        with self.assertRaisesRegex(AssessmentError,"duplicate-account-label"):
            portfolio_readiness((snap("main",{A:1}),snap("main",{B:1})),market(),BEFORE)
        with self.assertRaisesRegex(AssessmentError,"account-item-count-invalid"):
            portfolio_readiness((snap("main",{A:True}),),market(),BEFORE)

    def test_future_capture_is_not_valid_current_evidence(self):
        with self.assertRaisesRegex(AssessmentError,"future-account-capture"):
            portfolio_readiness((snap("main",{A:1},BEFORE+timedelta(seconds=1)),),
                                market(),BEFORE)

    def test_external_trade_gain_and_market_revaluation_are_distinct(self):
        before=starting()
        after=(snap("main",{A:1,B:1},AFTER),snap("alt",{B:1,C:2},AFTER))
        event=CompletedEvent("proof-001","external_trade",{"main":{C:-1,B:1}})
        r=reconcile_value_change(before,after,market(),market(later=True),
                                 BEFORE,AFTER,(event,))
        self.assertEqual(r.before_value,Decimal(1770))
        self.assertEqual(r.after_value,Decimal(2280))
        self.assertEqual(r.completed_external_trades_at_old_prices,Decimal(410))
        self.assertEqual(r.market_repricing_on_after_holdings,Decimal(100))
        self.assertEqual(r.portfolio_change,Decimal(510))
        self.assertEqual(r.internal_transfer_value,Decimal(0))
        self.assertEqual(r.included_events,1)
        self.assertEqual(r.evidence_status,"caller-native-evidence-structurally-reconciled")
        self.assertFalse(r.authorizes_trade)

    def test_market_only_no_trade_has_zero_trade_profit(self):
        before=starting()
        after=starting(AFTER)
        r=reconcile_value_change(before,after,market(),market(later=True),BEFORE,AFTER)
        self.assertEqual(r.completed_external_trades_at_old_prices,0)
        self.assertEqual(r.market_repricing_on_after_holdings,Decimal(100))
        self.assertEqual(r.portfolio_change,Decimal(100))

    def test_internal_alt_to_main_transfer_does_not_mint_profit(self):
        before=starting()
        after=(snap("main",{A:1,B:1,C:1},AFTER),snap("alt",{C:2},AFTER))
        transfer=CompletedEvent("transfer-001","owned_transfer",
                                {"main":{B:1},"alt":{B:-1}})
        r=reconcile_value_change(before,after,market(),market(),BEFORE,AFTER,(transfer,))
        self.assertEqual(r.completed_external_trades_at_old_prices,0)
        self.assertEqual(r.market_repricing_on_after_holdings,0)
        self.assertEqual(r.portfolio_change,0)
        self.assertEqual(r.internal_transfer_value,0)

    def test_inventory_change_without_event_cannot_be_called_profit(self):
        before=starting()
        after=(snap("main",{A:1,B:1},AFTER),snap("alt",{B:1,C:2},AFTER))
        with self.assertRaisesRegex(AssessmentError,"unexplained-inventory-change"):
            reconcile_value_change(before,after,market(),market(),BEFORE,AFTER)

    def test_provisional_screenshot_cannot_prove_completed_trade(self):
        before=starting()
        after=(snap("main",{A:1,B:1},AFTER,native=False,complete=False),
               snap("alt",{B:1,C:2},AFTER))
        e=CompletedEvent("proof","external_trade",{"main":{C:-1,B:1}})
        with self.assertRaisesRegex(AssessmentError,"ledger-event-evidence-not-authoritative"):
            reconcile_value_change(before,after,market(),market(),BEFORE,AFTER,(e,))

    def test_false_completed_event_or_duplicate_proof_is_rejected(self):
        before=starting()
        after=(snap("main",{A:1,B:1},AFTER),snap("alt",{B:1,C:2},AFTER))
        e=CompletedEvent("proof","external_trade",{"main":{C:-1,B:1}},
                         completion_claimed=False)
        with self.assertRaisesRegex(AssessmentError,"ledger-event-completion-unproven"):
            reconcile_value_change(before,after,market(),market(),BEFORE,AFTER,(e,))
        e=CompletedEvent("proof","external_trade",{"main":{C:-1,B:1}})
        with self.assertRaisesRegex(AssessmentError,"ledger-duplicate-or-invalid-event-proof"):
            reconcile_value_change(before,after,market(),market(),BEFORE,AFTER,(e,e))

    def test_transfer_cannot_duplicate_or_destroy_weapons(self):
        before=starting()
        after=(snap("main",{A:1,B:1,C:1},AFTER),snap("alt",{B:1,C:2},AFTER))
        bad=CompletedEvent("x","owned_transfer",{"main":{B:1},"alt":{C:-1}})
        with self.assertRaisesRegex(AssessmentError,"ledger-transfer-must-conserve-assets"):
            reconcile_value_change(before,after,market(),market(),BEFORE,AFTER,(bad,))

    def test_events_cannot_sell_weapons_before_they_are_owned(self):
        before=starting()
        after=starting(AFTER)
        # Two invented trades cancel out in the final snapshot. The first
        # falsely gives two A copies even though the account holds only one.
        first=CompletedEvent("earlier","external_trade",
                             {"main":{A:-2,B:1}})
        second=CompletedEvent("later","external_trade",
                              {"main":{B:-1,A:2}})
        with self.assertRaisesRegex(AssessmentError,
                                    "ledger-event-not-owned-at-time"):
            reconcile_value_change(before,after,market(),market(),
                                   BEFORE,AFTER,(first,second))

    def test_unpriced_event_asset_cannot_be_valued_as_zero(self):
        before=starting()
        after=(snap("main",{A:1,"godly:999:checker-id":1},AFTER),
               snap("alt",{B:1,C:2},AFTER))
        e=CompletedEvent("proof","external_trade",
                         {"main":{C:-1,"godly:999:checker-id":1}})
        with self.assertRaisesRegex(AssessmentError,"accounting-price-or-identity-unverified"):
            reconcile_value_change(before,after,market(),market(),BEFORE,AFTER,(e,))

    def test_account_time_mismatch_fails(self):
        before=starting()
        after=(snap("main",{A:1,C:1},AFTER),
               snap("alt",{B:1,C:2},AFTER-timedelta(seconds=2)))
        with self.assertRaisesRegex(AssessmentError,"ledger-account-snapshot-time-mismatch"):
            reconcile_value_change(before,after,market(),market(),BEFORE,AFTER)

    def test_portfolio_evaluation_has_no_input_mutation(self):
        before=starting()
        baseline=copy.deepcopy(before)
        r1=portfolio_readiness(before,market(),BEFORE)
        r2=portfolio_readiness(before,market(),BEFORE)
        self.assertEqual(r1,r2)
        self.assertEqual(before,baseline)

    def test_event_values_are_conservative_integer_quantities(self):
        before=starting()
        after=(snap("main",{A:1,B:1},AFTER),snap("alt",{B:1,C:2},AFTER))
        event=CompletedEvent("e","external_trade",{"main":{C:-1,B:True}})
        with self.assertRaisesRegex(AssessmentError,"ledger-event-item-or-quantity-invalid"):
            reconcile_value_change(before,after,market(),market(),BEFORE,AFTER,(event,))


if __name__ == "__main__":
    unittest.main()
