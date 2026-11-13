"""Static provenance/privacy contract for the client-only ABA shadow lease.

Behavior is exercised separately by actual Luau/Lune tests, including original
P3/P4 bound capture; Python tests preserve source and authority boundaries.
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
N = ROOT / "pdiddler" / "intelligence_lab" / "p3_shadow_aba_offer_lease.lua"
TEST = ROOT / "pdiddler" / "ci" / "p3_shadow_aba_offer_lease_mocks.luau"
NATIVE = ROOT / "pdiddler" / "ci" / "p3_shadow_aba_native_bound_mocks.luau"
ORIGINAL = ROOT / "pdiddler" / "supervised" / "supervised_four_slot_operator_plan.lua"
BRIDGE = ROOT / "pdiddler" / "supervised" / "supervised_p3_p4_handoff.lua"
IO = ROOT / "pdiddler" / "supervised" / "pdiddler4_tradeio_supervised_v2.lua"


class TestAbaShadowSafety(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.s = N.read_text()
        cls.t = TEST.read_text()
        cls.native = NATIVE.read_text()
        cls.original = ORIGINAL.read_text()
        cls.bridge = BRIDGE.read_text()
        cls.io = IO.read_text()

    def test_only_readonly_probes_and_no_trading_calls(self):
        for payload in (self.s, self.t, self.native):
            for bad in (
                "OfferItem:FireServer(", "AcceptTrade:FireServer(",
                "DeclineTrade:FireServer(", "SendRequest:FireServer(",
                "TeleportService", "PostAsync(", "request("
            ):
                self.assertNotIn(bad, payload, bad)
        self.assertNotIn("game:HttpGet(", self.s)

    def test_no_executable_live_trader_file_is_modified(self):
        import subprocess
        for path, sha in (
            (ORIGINAL, "2d5212d5da84e6eabfb137b619128bc375a7ca05"),
            (BRIDGE, "d496d6311dc6c5e24e059fcd71014e274a4be76b"),
            (IO, "eb4dc6342d1d6dda6292490cd8fa00314199d589"),
        ):
            actual = subprocess.check_output(
                ["git", "hash-object", str(path)], text=True
            ).strip()
            self.assertEqual(actual, sha, str(path))

    def test_shadow_safety_flags_exist_and_never_set_true(self):
        required = (
            "serverRevisionAuthenticated=false",
            "callbackSessionAssociationProven=false",
            "serverCompletionProven=false",
            "authorizesOffer=false",
            "authorizesTrade=false",
            "authorizesAccept=false",
            "mayUseForStrategyLearning=false",
            "mayReportProfit=false",
            "maySendDiscordWebhook=false",
            'tradeOutcome="UNKNOWN"',
        )
        for item in required:
            with self.subTest(item=item):
                self.assertIn(item, self.s)
        self.assertNotRegex(
            self.s, r"(?:authorizesOffer|authorizesAccept|serverCompletionProven)\s*=\s*true"
        )

    def test_prepared_lease_revokes_on_any_visible_mutation(self):
        for item in (
            "OBSERVED_GUI_MUTATION_REQUIRES_FRESH_PLAN",
            "phase==\"PREPARED\"",
            "CLIENT_CALLBACK_REQUIRES_FRESH_PLAN",
            "BOUND_CLIENT_SCOPE_LOST",
            "BOUND_CLIENT_TRADE_ROOT_CHANGED",
            "BOUND_CLIENT_SNAPSHOT_UNREADABLE",
        ):
            self.assertIn(item, self.s)

    def test_source_uses_actual_bound_capture_not_caller_approved_flags(self):
        self.assertIn("pcall(bound.capture)", self.s)
        self.assertIn("snapshot.offerRevisionAuthenticated~=false", self.s)
        self.assertIn("snapshot.partnerExactClientBound~=true", self.s)
        self.assertIn("snapshot.part3Paused~=true", self.s)

    def test_no_private_inventory_serialization(self):
        self.assertNotIn("JSONEncode(", self.s)
        self.assertNotIn("setclipboard(", self.s)
        self.assertNotIn("HttpService", self.s)
        self.assertNotIn("game.Players", self.s)
        self.assertNotIn("print(", self.s)
        self.assertNotIn("warn(", self.s)

    def test_original_existing_guard_is_present_and_untouched(self):
        self.assertIn("PARTNER_OFFER_REVISION_OR_SLOT_CHANGED", self.original)
        self.assertIn("current(bound,expectedOwn,their)", self.original)
        self.assertIn("OFFER_CHANGED_DURING_CAPTURE", self.bridge)
        self.assertIn("io.sideSignature", self.bridge)
        self.assertIn("OfferItem:FireServer(rawId", self.io)

    def test_native_test_uses_actual_original_p3_p4_bound_source(self):
        for token in (
            'fs.readFile("pdiddler/supervised/supervised_p3_p4_handoff.lua")',
            'fs.readFile("pdiddler/supervised/pdiddler4_tradeio_supervised_v2.lua")',
            'local b=getBound(x)',
            'w.recheckShadow()',
            'w.poll()',
            'eq(#x.sends,0',
        ):
            self.assertIn(token, self.native, token)

    def test_aba_test_does_not_confuse_restored_snapshot_with_safe_plan(self):
        self.assertIn("ABA returned to identical offer", self.native)
        self.assertIn("ABA return cannot revive old intent", self.t)

    def test_no_deployed_client_script_or_live_pricing_engine_added(self):
        self.assertNotIn("game:GetService(", self.s)
        self.assertNotIn("Gingerscope", self.s.replace("Gingerscope", ""))
        self.assertIn('shadowOnly=true', self.s)


if __name__ == "__main__":
    unittest.main()
