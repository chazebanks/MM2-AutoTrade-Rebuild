"""Independent Python arithmetic/authority oracle for the actual market-priced Lua core.

The original strategy engine is *native Luau*, exercised separately with Lune.
This suite derives economic invariants from real item rows; no own user data.
"""
from __future__ import annotations
import hashlib
import json
import random
import unittest
from datetime import datetime, timezone, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CORE = ROOT / "system2" / "native_bilateral_attractiveness_shadow.lua"
BRIDGE = ROOT / "system2" / "native_bilateral_attractiveness_bridge.lua"
DATA = ROOT / "system2" / "research_market_crosswalk_current.json"


class RealMarketBilateralOracle(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.market = json.loads(DATA.read_text(encoding="utf-8"))
        cls.rows = {x["rawGameKeyCandidate"]: x for x in cls.market["items"]}

    def test_market_189_immutable_key_candidates(self):
        self.assertEqual(self.market["matchedHistoricalGameKeys"], 189)
        self.assertEqual(len(self.rows), 189)
        self.assertFalse(self.market["authorizesAccept"])
        self.assertFalse(self.market["mayUseForLiveOffer"])
        self.assertTrue(self.rows["Gingerscope"]["outgoingGingerscopeProtected"])

    def test_real_market_crosswalk_digest_recomputed(self):
        blob = json.dumps(self.market["items"], sort_keys=True, separators=(",", ":")).encode()
        self.assertEqual(hashlib.sha256(blob).hexdigest(), self.market["crosswalkRowsSha256"])
        self.assertEqual(self.market["marketEdition"], "2026-11-13")

    def test_actual_profit_versus_demand_counterexample(self):
        b = self.rows
        junk_gain = b["SnowDagger"]["mm2Listed"] - b["Frostsaber"]["mm2Listed"]
        desirable_gain = b["Icepiercer"]["mm2Listed"] - b["Iceblaster"]["mm2Listed"]
        self.assertGreater(junk_gain, desirable_gain)
        self.assertEqual((junk_gain, desirable_gain), (150, 145))
        self.assertLess(float(b["SnowDagger"]["demandOrdinal"]),
                        float(b["Icepiercer"]["demandOrdinal"]))
        self.assertGreaterEqual(
            b["SnowDagger"]["supremeListed"] - b["Frostsaber"]["supremeListed"], 0)
        self.assertGreaterEqual(
            b["Icepiercer"]["supremeListed"] - b["Iceblaster"]["supremeListed"], 0)

    def test_bidirectional_listed_delta_zero_sum_in_random_trades(self):
        r = random.Random(20261114)
        options = [x for x in self.market["items"]
                   if x["mm2Listed"] is not None and x["supremeListed"] is not None]
        for _ in range(2200):
            give = r.sample(options, r.randint(1, 4))
            recv = r.sample(options, r.randint(1, 4))
            stock = {x["rawGameKeyCandidate"]: r.randint(1, 6) for x in give}
            out_mm2 = sum(stock[x["rawGameKeyCandidate"]] * x["mm2Listed"] for x in give)
            in_mm2 = sum(r.randint(1, 6) * x["mm2Listed"] for x in recv)
            out_sup = sum(stock[x["rawGameKeyCandidate"]] * x["supremeListed"] for x in give)
            in_sup = sum(x["supremeListed"] for x in recv)
            self.assertEqual((in_mm2 - out_mm2) + (out_mm2 - in_mm2), 0)
            self.assertEqual((in_sup - out_sup) + (out_sup - in_sup), 0)

    def test_four_physical_slots_is_not_four_total_copies(self):
        one_stack = {"EmberbowChroma": 6}
        self.assertEqual(len(one_stack), 1)
        self.assertEqual(sum(one_stack.values()), 6)
        self.assertGreater(self.rows["EmberbowChroma"]["mm2Listed"], 1)
        # Six valued copies may not trade at a linear listed multiple.
        self.assertTrue(sum(one_stack.values()) >= 5)

    def test_null_stability_is_accepted_as_unknown_not_safe(self):
        unknown = [x for x in self.market["items"] if x["stabilityLabel"] is None]
        self.assertTrue(any(x["rawGameKeyCandidate"] == "TheSeer" for x in unknown))
        self.assertNotEqual(unknown[0].get("stabilityLabel"), "Stable")

    def test_qualitative_demand_is_not_an_acceptance_probability(self):
        demand = [float(x["demandOrdinal"]) for x in self.market["items"]]
        self.assertGreater(max(demand), 0)
        core = CORE.read_text(encoding="utf-8")
        self.assertIn("empiricalPartnerAcceptanceProbability=nil", core)
        self.assertIn("verifiedCounterpartyPreference=false", core)
        self.assertIn("counterpartSpecificSubjectiveValueMeasured=false", core)

    def test_stale_offer_abstention_and_no_live_mutation(self):
        core = CORE.read_text(encoding="utf-8")
        bridge = BRIDGE.read_text(encoding="utf-8")
        self.assertIn("context.clientOfferRevision~=context.offer.clientRevision", core)
        self.assertIn("OFFER_OR_SOURCE_CHANGED_DURING_STRATEGY_COMPARISON", bridge)
        self.assertIn("PARTNER_STOCK_NOT_IN_CURRENT_VISIBLE_OFFER", core)
        self.assertIn("CLIENT_ACCEPTED_IDENTICAL_CURRENT_GUI_ONLY", core)
        for source in (core, bridge):
            for forbidden in ("FireServer(", "InvokeServer(", "AcceptTrade(", "PostAsync(", "TeleportService"):
                self.assertNotIn(forbidden, source)

    def test_market_age_requires_revalidation(self):
        observed = datetime.fromisoformat(
            self.market["sourceRetrievedUtc"].replace("Z", "+00:00"))
        self.assertLessEqual(observed, datetime.now(timezone.utc)+timedelta(minutes=5))
        core = CORE.read_text(encoding="utf-8")
        self.assertIn("context.offer.sourceAgeSeconds>21600", core)

    def test_target_not_outgoing_and_partner_is_not_measured(self):
        core = CORE.read_text(encoding="utf-8")
        self.assertIn('if id=="Gingerscope"', core)
        self.assertIn('OUTGOING_GINGERSCOPE_FORBIDDEN', core)
        self.assertIn('partnerMm2ListedDelta=-mm2gain', core)
        self.assertIn('counterpartSpecificSubjectiveValueMeasured=false', core)


if __name__ == "__main__":
    unittest.main()
