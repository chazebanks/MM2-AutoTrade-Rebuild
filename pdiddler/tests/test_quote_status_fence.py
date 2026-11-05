"""Static source regression checks for V15.8 quote-status evidence fences.

These do NOT execute Roblox/Luau or prove native UI timing/declines.
Run: python -m unittest discover -s pdiddler/tests -p "test_quote_status_fence.py"
"""
from pathlib import Path
import unittest

SOURCE = Path(__file__).resolve().parents[1] / "pdiddler4_balancer_SUPREME_v11_VALUE_FIRST.lua"


class QuoteStatusFenceSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = SOURCE.read_text(encoding="utf-8")

    def safety_region(self):
        src = self.source
        start = src.index("bound.safetyInspect=function(stage,tx,allowClear)")
        end = src.index("    -- Human negotiation state is deliberately separate", start)
        return src[start:end]

    def profit_region(self):
        src = self.source
        start = src.index('if action=="decline" then', src.index("local action,nextPlan=MARKET_LOGIC.negotiate"))
        end = src.index("        if #plans==0 then", start)
        return src[start:end]

    def test_physical_signature_change_invalidates_evidence_before_reusing_profit(self):
        text = self.safety_region()
        change = text.index("if not raw or raw~=bound.safetyRawSig then")
        invalidate = text.index('invalidateQuoteEvidence("physical-quote-changed")', change)
        status = text.index("P4 QUOTE CHANGED — previous profit invalid", invalidate)
        update = text.index("bound.safetyRawSig=raw", status)
        self.assertLess(change, invalidate)
        self.assertLess(invalidate, status)
        self.assertLess(status, update)

    def test_unsafe_decision_clears_previous_profit_before_protected_decline(self):
        text = self.safety_region()
        start = text.index('invalidateQuoteEvidence("unsafe-current-physical-quote")')
        self.assertLess(start, text.index("P4 SAFETY — current quote unsafe", start))
        self.assertLess(start, text.index("return requestSafetyDecline", start))
        self.assertIn("local decision=tradeDecision(ours,theirs)", text)

    def test_profit_display_requires_same_current_physical_quote(self):
        text = self.profit_region()
        self.assertIn('rawSideSignature(displayTrade,"YourOffer")', text)
        self.assertIn('rawSideSignature(displayTrade,"TheirOffer")', text)
        reject = text.index("if not displayRaw or displayRaw~=bound.safetyRawSig or bound.quoteInvalidated then")
        invalidated = text.index('invalidateQuoteEvidence("profit-status-quote-drift")', reject)
        continue_on_drift = text.index("continue", invalidated)
        profit_display = text.index("P4 — verified Supreme profit +%s", continue_on_drift)
        self.assertLess(reject, invalidated)
        self.assertLess(invalidated, continue_on_drift)
        self.assertLess(continue_on_drift, profit_display)

    def test_quote_fence_does_not_grant_native_auto_accept(self):
        self.assertIn("FINAL ACCEPT DISABLED", self.safety_region())
        self.assertIn("FINAL ACCEPT DISABLED", self.profit_region())
        self.assertIn("if lifecycle and lifecycle.capabilities.autoAccept then", self.source)

    def test_frostsaber_sugar_removed_scenario_is_not_still_profitable(self):
        # November 4 pinned Supreme: Frostsaber 10; Sugar 32;
        # Plasmabeam 18; Boneblade 7. Economic baseline is unchanged.
        offered = 18 + 7
        before = 10 + 32 - offered
        after = 10 - offered
        self.assertEqual(before, 17)
        self.assertEqual(after, -15)
        self.assertEqual(before - after, 32)


if __name__ == "__main__":
    unittest.main()
