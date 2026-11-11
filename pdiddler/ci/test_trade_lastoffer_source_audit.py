"""Offline-only assertions for the LastOffer equality research module.

These verify absence of gameplay authority and anchor the original Stage101
contract. They do not authenticate any current MM2 server revision.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
MODULE = ROOT / "pdiddler/intelligence_lab/trade_lastoffer_client_audit.lua"
TESTS = ROOT / "pdiddler/ci/test_trade_lastoffer_client_audit.lua"
NATIVE = ROOT / "pdiddler/supervised/SUPERVISED_P3_STAGE101_IDENTITY_NATIVE.lua"
WITNESS = ROOT / "pdiddler/supervised/supervised_p3_p4_stage101_identity_witness.lua"

class LastOfferSourceAudit(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = MODULE.read_text(encoding="utf-8")
        cls.tests = TESTS.read_text(encoding="utf-8")

    def test_no_live_roblox_actions(self):
        for data in (self.source, self.tests):
            for forbidden in (
                "FireServer(", "InvokeServer(", "OnClientEvent:Connect(",
                "HttpGet(", "PostAsync(", "Teleport(", "loadstring(",
                "setclipboard(", "toclipboard(", "require(game",
            ):
                self.assertNotIn(forbidden, data)

    def test_all_authority_flags_constant_false(self):
        for exact in (
            "serverTradeRevisionProven=false",
            "eventSessionAssociationProven=false",
            "callbackCausalityProven=false",
            "serverCompletionProven=false",
            "authorizesTrade=false",
            "authorizesOffer=false",
            "authorizesAccept=false",
            "mayRecordCompletedTrade=false",
            "mayReportProfit=false",
            "maySendDiscordWebhook=false",
            "mayUseForStrategyLearning=false",
            'tradeOutcome="UNKNOWN"',
            "clientGuiCrossChecked=false",
            "lastOfferValueExposed=false",
        ):
            self.assertIn(exact, self.source)

    def test_private_values_not_returned(self):
        self.assertIn("last=candidate", self.source)
        self.assertIn("last=nil", self.source)
        self.assertIn("return result(", self.source)
        self.assertNotIn("return candidate", self.source)
        self.assertNotIn("return last", self.source)
        self.assertNotIn("tokenValue=", self.source)
        self.assertNotIn("rawOffer=", self.source)

    def test_original_stage101_still_authority_denied(self):
        native = NATIVE.read_text(encoding="utf-8")
        witness = WITNESS.read_text(encoding="utf-8")
        self.assertIn("rawItemIdConfirmed=false", native)
        self.assertIn("eventSessionAssociationProven=false", native)
        self.assertIn("serverTradeRevisionProven=false", native)
        self.assertIn('tradeOutcome="UNKNOWN"', native)
        self.assertIn('local ROOT={LastOffer=true,Locked=true,Player1=true,Player2=true}', witness)
        self.assertIn("authorizesAccept=false", witness)

    def test_lua_tests_cover_races(self):
        for phrase in (
            "same token with changed offer",
            "changed LastOffer with changed offer",
            "same offer changed token",
            "mutable callback table",
            "reject wrong scope",
            "indistinguishable late old event",
            "malformed tokens",
            "swapped Player1/2",
        ):
            self.assertIn(phrase, self.tests)

if __name__ == "__main__":
    unittest.main()
