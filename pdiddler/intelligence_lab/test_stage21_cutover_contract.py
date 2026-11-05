"""Stage 21 Python-first regression audit of the replacement-only runtime path."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1] / "new_part4"

class ReplacementCutoverTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.boot = (ROOT / "REPLACEMENT_INTEGRATION_PREVIEW.lua").read_text()
        cls.p4 = (ROOT / "PDIDDLER_PART4_REPLACEMENT.lua").read_text()
        cls.price = (ROOT / "P4_REPRICE_ONLY.lua").read_text()
        cls.elig = (ROOT / "P3_ELIGIBILITY_NO_LEGACY_PROFIT.lua").read_text()

    def test_legacy_part4_and_policy_are_not_loaded(self):
        for name in (
            "pdiddler4_balancer_SUPREME_v11_VALUE_FIRST.lua",
            "pdiddler4_supreme_policy_v10_INVENTORY_GROWTH.lua",
            "pdiddler4_early_counter_policy_v5_OPPONENT_ADDED.lua",
            "pdiddler4_accept_ui_gate_v1.lua",
        ):
            self.assertNotIn(name, self.boot)
        self.assertIn("new_part4/PDIDDLER_PART4_REPLACEMENT.lua", self.boot)
        self.assertIn("new_part4/P3_ELIGIBILITY_NO_LEGACY_PROFIT.lua", self.boot)
        self.assertIn("new_part4/P4_REPRICE_ONLY.lua", self.boot)

    def test_no_old_balancer_invocation(self):
        self.assertIn('p4.run(I.scanner,I.profile)',self.boot)
        self.assertNotIn('I.earlyPolicy=',self.boot)
        self.assertNotIn('I.acceptGate=',self.boot)
        self.assertNotIn('MARKET_PLANNER=',self.p4)
        self.assertNotIn('P.minimumProfit',self.price)
        self.assertNotIn('P.minimumProfit',self.elig)

    def test_new_entrypoint_preserves_p3_and_p5(self):
        for term in ('module("scanner"', 'module("outgoing"',
                     'module("transport"', 'module("policy"',
                     'I.outgoing=api(', 'I.part4=api('):
            self.assertIn(term,self.boot)

    def test_no_deceptive_live_accept_or_native_offer_in_p4(self):
        for source in (self.p4,self.elig,self.price):
            for banned in (
                'OfferItem:FireServer','AcceptTrade','DeclineTrade:FireServer',
                'mouse1click','VirtualInputManager','keyPress','queue_on_teleport'
            ):
                self.assertNotIn(banned,source)
        self.assertIn('authorizesTrade=false',self.p4)
        self.assertIn('authorizesAccept=false',self.p4)
        self.assertNotIn('buildPlans',self.price)

    def test_new_bootstrap_requires_opt_in_and_fresh_market(self):
        self.assertIn('PDIDDLER_ALLOW_REPLACEMENT_PREVIEW~=true',self.boot)
        self.assertIn('assert(I.profile.isFresh()',self.boot)
        self.assertIn('REPLACEMENT_PREVIEW',self.boot)

    def test_part4_uses_stage9_observer_instead_of_own_trade_parser(self):
        self.assertIn('readModule("p4_observer_contract")',self.p4)
        self.assertIn('readModule("p4_native_observer")',self.p4)
        self.assertIn('native.capture',self.p4)
        self.assertNotIn('require("pdiddler4',self.p4)

    def test_part3_profit_gating_removed_but_inventory_checks_remain(self):
        self.assertIn('function M.evaluate(',self.elig)
        self.assertIn('function M.validateInventory(',self.elig)
        self.assertIn('both-inventories-verified;new-strategy-review-required',self.elig)
        self.assertNotIn('policy.buildPlans',self.elig.split('function M.evaluate(')[1])
        self.assertNotIn('minimumProfit=',self.elig)
        for check in ('fingerprint','unmapped','unpriced','badQty','checkerId'):
            self.assertIn(check,self.elig)

    def test_pure_repricer_cannot_make_trade_decisions(self):
        self.assertIn('function M.reprice(',self.price)
        self.assertIn('profile.get',self.price)
        self.assertNotIn('function M.tradeDecision',self.price)
        self.assertNotIn('function M.buildPlans',self.price)
        self.assertNotIn('minimumProfit',self.price)

    def test_no_hardcoded_users_or_webhooks_in_new_code(self):
        for text in (self.elig,self.price,self.p4):
            self.assertNotIn('discord.com/api/webhooks/',text)
            self.assertNotIn('venossgaming',text)
            self.assertNotIn('https://supremevalues.com',text)

if __name__=="__main__":
    unittest.main()
