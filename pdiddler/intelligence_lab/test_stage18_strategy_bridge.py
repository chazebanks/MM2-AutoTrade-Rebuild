"""Stage 18 end-to-end OFFLINE integration tests, all portfolios synthetic."""
from __future__ import annotations

import copy
from datetime import datetime, timezone, timedelta
from decimal import Decimal
import shutil
import unittest

from evaluator import AssessmentError, Catalog, Item
from stage18_strategy_bridge import integrate, review_in_lua, _lua_literal

A = "godly:11:checker-id"
B = "godly:12:checker-id"
C = "ancient:13:checker-id"
GOAL = "ancient:771:checker-id"
NOW = datetime(2026, 11, 5, 12, tzinfo=timezone.utc)


def setup():
    items = {
        A: Item(A, Decimal(95), 2, "stable"),
        B: Item(B, Decimal(6), 3, "stable"),
        C: Item(C, Decimal(100), 5, "stable"),
        GOAL: Item(GOAL, Decimal(16000), 5, "stable"),
    }
    market = Catalog(items, NOW - timedelta(hours=1),
                     NOW + timedelta(hours=1), "synthetic-only-stage18")
    return {A: 1, B: 1}, {C: 1}, {C: 1}, market


class Stage18BridgeTests(unittest.TestCase):
    def test_stage7_stage5_both_reused_and_no_hidden_15_floor(self):
        own, other, target, market = setup()
        result = integrate(own, other, target, market, NOW)
        self.assertGreater(len(result.candidates), 0)
        quote = next(x for x in result.candidates
                     if x.give == ((A, 1),))
        self.assertEqual(quote.our_listed_gain, Decimal(5))
        self.assertIn("value_matched", quote.stage7_lanes)
        self.assertTrue(quote.stage5_lanes)  # Stage 5 actually ran
        self.assertIsNotNone(quote.gingerscope_gap_after)
        self.assertEqual(result.lua_candidates[
            list(result.candidates).index(quote)]["give"],
            [{"id": A, "qty": 1}])
        self.assertFalse(result.quote_safe)
        self.assertFalse(result.authorizes_trade)
        self.assertFalse(result.authorizes_accept)
        self.assertFalse(result.native_ready)
        self.assertFalse(result.scan_age_proven)

    def test_exact_prices_not_inferred_ranges_or_flippability(self):
        own, other, target, market = setup()
        r = integrate(own, other, target, market, NOW)
        row = r.lua_context["market"]["items"][A]
        self.assertEqual(row["valueCents"], 9500)
        self.assertEqual(row["demand"], 2)
        self.assertNotIn("lowCents", row)
        self.assertNotIn("highCents", row)
        self.assertNotIn("flippability", row)
        self.assertEqual(r.lua_context["market"]["sourceId"],
                         "synthetic-only-stage18")

    def test_already_owned_quantities_are_not_mutated(self):
        own, other, target, market = setup()
        initial = copy.deepcopy((own, other, target))
        a = integrate(own, other, target, market, NOW)
        b = integrate(own, other, target, market, NOW)
        self.assertEqual(a, b)
        self.assertEqual(initial, (own, other, target))

    def test_unowned_requested_target_rejected(self):
        own, other, target, market = setup()
        with self.assertRaisesRegex(AssessmentError,
                                    "stage18-target-not-owned-by-opponent"):
            integrate(own, other, {C: 2}, market, NOW)

    def test_invalid_display_name_or_tier_fails(self):
        own, other, target, market = setup()
        with self.assertRaisesRegex(AssessmentError,
                                    "stage18-noncanonical-identity"):
            integrate({**own, "Laser": 1}, other, target, market, NOW)
        with self.assertRaisesRegex(AssessmentError,
                                    "stage18-noncanonical-identity"):
            integrate({"vintage:11:checker-id": 1}, other, target, market, NOW)

    def test_expired_market_does_not_just_extend_timestamp(self):
        own, other, target, market = setup()
        with self.assertRaises(AssessmentError):
            integrate(own, other, target, market,
                      market.valid_until + timedelta(seconds=1))
        with self.assertRaisesRegex(AssessmentError,
                                    "stage18-source-expired"):
            integrate(own, other, target, market, market.valid_until)

    def test_no_valid_quote_is_no_candidate_not_invented(self):
        own, other, target, market = setup()
        result = integrate({B: 1}, other, target, market, NOW)
        self.assertFalse(result.candidates)
        self.assertEqual(result.lua_candidates, ())
        self.assertEqual(review_in_lua(result), ())

    def test_missing_goal_blocked(self):
        own, other, target, market = setup()
        market = Catalog({k: v for k, v in market.items.items()
                          if k != GOAL}, market.observed_at,
                         market.valid_until, market.source)
        with self.assertRaisesRegex(AssessmentError,
                                    "stage18-goal-unverified"):
            integrate(own, other, target, market, NOW)

    def test_strict_review_cap_and_search_budget(self):
        own, other, target, market = setup()
        with self.assertRaisesRegex(AssessmentError, "stage18-review-budget-invalid"):
            integrate(own, other, target, market, NOW, limit_per_lane=33)
        with self.assertRaises(AssessmentError):
            integrate(own, other, target, market, NOW, search_budget=1)

    def test_safe_lua_literal_escapes_user_strings_as_data(self):
        raw = 'x"};error("injection")--\n'
        encoded = _lua_literal(raw)
        self.assertNotIn('error(', encoded)
        self.assertNotIn("\n", encoded)
        self.assertIn("\\120", encoded)
        with self.assertRaisesRegex(AssessmentError, "serializer"):
            _lua_literal(object())

    @unittest.skipUnless(shutil.which("lua5.4"),
                         "Lua5.4 installed in GitHub CI; offline module run")
    def test_real_stage17_lua_receives_stage7_stage5_candidates(self):
        own, other, target, market = setup()
        prepared = integrate(own, other, target, market, NOW)
        reviewed = review_in_lua(prepared)
        self.assertEqual(len(reviewed), len(prepared.candidates))
        quote = next(x for x in reviewed
                     if x["ourGainCents"] == 500)
        self.assertEqual(quote["sellerSurplusCents"], -500)
        self.assertEqual(quote["sellerCase"], "UNPROVEN_SELLER_CASE")
        self.assertTrue(quote["reviewOnly"])
        self.assertFalse(quote["authorizesTrade"])
        self.assertFalse(quote["authorizesAccept"])


if __name__ == "__main__":
    unittest.main()
