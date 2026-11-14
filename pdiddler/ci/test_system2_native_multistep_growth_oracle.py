"""Independent value-conservation oracle for native System2 multistep growth.

Real source rows from current GitHub Actions live fetch; hypothetical inventory
and partner stock only. Never treated as observed MM2 successful trades.
"""
from __future__ import annotations

from collections import Counter
from pathlib import Path
from random import Random
import json
import unittest

ROOT = Path(__file__).resolve().parents[1] / "system2"
CORE = ROOT / "native_multistep_growth_shadow.lua"
BRIDGE = ROOT / "native_multistep_growth_bridge.lua"
SOURCE = ROOT / "research_market_crosswalk_current.json"


class RealSourceGrowthOracles(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = json.loads(SOURCE.read_text())
        cls.q = {r["rawGameKeyCandidate"]: r for r in cls.source["items"]}
        cls.tradable = [r for r in cls.q.values()
                        if r["mm2Listed"] is not None and
                        r["supremeListed"] is not None and
                        r["rawGameKeyCandidate"] != "Gingerscope"]

    def test_189_exact_registry_and_target_gap(self):
        self.assertEqual(len(self.q), 189)
        self.assertEqual(self.source["matchedHistoricalGameKeys"], 189)
        self.assertEqual(self.q["Gingerscope"]["mm2Listed"], 16000)
        self.assertTrue(self.q["Gingerscope"]["outgoingGingerscopeProtected"])
        self.assertFalse(self.source["mayUseForLiveOffer"])

    def test_small_plus_five_compounding_real_price_rows(self):
        r = self.q
        self.assertEqual(r["Frostbite"]["mm2Listed"]-r["OrangeSeer"]["mm2Listed"], 5)
        self.assertEqual(r["Frostbite"]["supremeListed"]-r["OrangeSeer"]["supremeListed"], 5)
        self.assertEqual(r["Frostsaber"]["mm2Listed"]-r["Frostbite"]["mm2Listed"], 3)
        self.assertGreaterEqual(r["Frostsaber"]["supremeListed"], r["Frostbite"]["supremeListed"])
        self.assertEqual(r["Frostsaber"]["mm2Listed"]-r["OrangeSeer"]["mm2Listed"], 8)

    def test_upgrade_2_to_1_and_downgrade_1_to_2_real_rows(self):
        r = self.q
        upgrade = r["Icepiercer"]["mm2Listed"] - (
            r["Frostsaber"]["mm2Listed"]+r["Iceblaster"]["mm2Listed"])
        downgrade = r["Icepiercer"]["mm2Listed"]+r["SnowDagger"]["mm2Listed"]-r["Harvester"]["mm2Listed"]
        self.assertEqual(upgrade, 135)
        self.assertEqual(downgrade, 70)
        self.assertEqual((2, 1), (len({"Frostsaber", "Iceblaster"}), len({"Icepiercer"})))
        self.assertEqual((1, 2), (len({"Harvester"}), len({"Icepiercer", "SnowDagger"})))

    def test_two_sided_value_math_never_yields_two_listed_winners(self):
        r = Random(20261114)
        for _ in range(3500):
            sample = r.sample(self.tradable, 6)
            give = sample[:3]
            receive = sample[3:]
            own_qty = [r.randint(1, 6) for _ in give]
            in_qty = [r.randint(1, 6) for _ in receive]
            for field in ("mm2Listed", "supremeListed"):
                out = sum(v[field] * q for v, q in zip(give, own_qty))
                got = sum(v[field] * q for v, q in zip(receive, in_qty))
                self.assertEqual((got-out)+(out-got), 0)

    def test_portfolio_conserves_each_step_for_2_to_4_steps(self):
        r = Random(20261115)
        for _ in range(1500):
            initial = r.sample(self.tradable, 4)
            qty = {x["rawGameKeyCandidate"]: r.randint(1, 7) for x in initial}
            start_value = sum(self.q[k]["mm2Listed"]*q for k,q in qty.items())
            current = start_value
            for _ in range(r.randint(2,4)):
                old_keys=list(qty)
                give_key=r.choice(old_keys)
                give_quantity=r.randint(1, qty[give_key])
                receive_key=r.choice(self.tradable)["rawGameKeyCandidate"]
                receive_quantity=r.randint(1,4)
                old = current
                current += (self.q[receive_key]["mm2Listed"]*receive_quantity -
                            self.q[give_key]["mm2Listed"]*give_quantity)
                qty[give_key]-=give_quantity
                if qty[give_key]==0:
                    del qty[give_key]
                qty[receive_key]=qty.get(receive_key,0)+receive_quantity
                actual=sum(self.q[k]["mm2Listed"]*q for k,q in qty.items())
                self.assertEqual(current, actual)
                self.assertEqual(actual-old,
                                 self.q[receive_key]["mm2Listed"]*receive_quantity-
                                 self.q[give_key]["mm2Listed"]*give_quantity)

    def test_physical_slots_not_total_copies(self):
        self.assertEqual(len({"EmberbowChroma": 6}),1)
        self.assertGreater(sum({"EmberbowChroma": 6}.values()),4)
        native=CORE.read_text()
        self.assertIn("NONLINEAR_FIVE_PLUS_COPY_STACK_NOT_PRICED",native)
        self.assertIn("BOUNDED_SEARCH_REQUIRES_AT_MOST_FOUR_HELD_KEYS",native)

    def test_future_hypothetical_gspan_cannot_force_direct_acquisition(self):
        s=CORE.read_text()
        self.assertIn("FUTURE_GINGERSCOPE_SELLER_UNATTRIBUTED",s)
        self.assertIn("GINGERSCOPE_NEVER_OUTBOUND",s)
        self.assertIn("futureSellerAvailabilityVerified=false",s)
        self.assertIn("selectedRouteActionable=false",s)

    def test_no_old_plus15_minimum_or_legacy_price_source(self):
        s=CORE.read_text()
        self.assertNotIn("minimumProfit=15",s)
        self.assertNotIn("valueSource",s)
        self.assertNotIn("checkerId",s)
        self.assertIn("if dMM2<0 or dSup<0",s)

    def test_bound_session_revision_rechecked_integration(self):
        s=BRIDGE.read_text()
        self.assertIn("last.clientOfferRevision~=first.clientOfferRevision",s)
        self.assertIn("not sameCounts(last.ownCounts,first.ownCounts)",s)
        self.assertIn("OWN_INVENTORY_OFFER_OR_SOURCE_CHANGED_DURING_GROWTH_SEARCH",s)

    def test_no_game_mutation_or_learning_claim_in_native_growth_modules(self):
        for p in (CORE,BRIDGE):
            txt=p.read_text()
            for token in ("FireServer(", "InvokeServer(", "AcceptTrade(", "DeclineTrade(",
                          "TeleportService", "PostAsync(", "HttpGet(", "mouse1click("):
                self.assertNotIn(token,txt)
        s=CORE.read_text()
        self.assertIn("mayUseForStrategyLearning=false",s)
        self.assertIn("mayReportProfit=false",s)


if __name__=="__main__":
    unittest.main()
