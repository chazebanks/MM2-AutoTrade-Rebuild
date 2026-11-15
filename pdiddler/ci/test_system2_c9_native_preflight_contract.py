"""Validate the ACTUAL Lune C9 preflight output, not a Python-fabricated receipt.

The native mocked Roblox services intentionally make this a lab observation:
it never authenticates a real iPad session, market publisher or settled trade.
Native production-source fixture must be generated before this test runs.
"""
from __future__ import annotations

import json
from pathlib import Path
import unittest

ROOT = Path(__file__).parent
FIXTURE = ROOT / ".generated_system2_c9_native_preflight_synthetic.json"
NATIVE = ROOT.parent / "system2" / "native_c9_device_readonly_preflight.lua"


class C9OriginalNativeBoundary(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not FIXTURE.is_file():
            raise AssertionError("RUN_ORIGINAL_C3_P4_C9_LUNE_PREFLIGHT_FIRST")
        cls.text = FIXTURE.read_text()
        cls.fixture = json.loads(cls.text)
        assert cls.fixture["schema"] == "gingerscope-c9-test-receipt-v1"
        assert cls.fixture["syntheticRobloxServices"] is True
        assert cls.fixture["originalSourceModulesExecuted"] is True
        assert cls.fixture["actualNativeIpadRun"] is False
        assert cls.fixture["transportNeverSent"] is True

    def test_original_gui_and_growth_strategy_are_client_only(self):
        seen = self.fixture["observations"]
        self.assertEqual(
            seen["inventoryAndGui"]["status"],
            "C9_LOCAL_READONLY_INVENTORY_AND_GUI_OBSERVED",
        )
        self.assertEqual(
            seen["growthPreview"]["status"],
            "C9_LOCAL_READONLY_STRATEGY_RESEARCH_OBSERVED",
        )
        self.assertEqual(seen["growthPreview"]["reviewedOptionCount"], 2)
        self.assertEqual(
            len(seen["growthPreview"]["researchAttentionOrder"]), 2
        )
        for case in ("inventoryAndGui", "growthPreview"):
            row = seen[case]
            self.assertEqual(
                row["schema"], "gingerscope-c9-client-readonly-native-preflight-v1"
            )
            for claim in (
                "authorizesTrade", "authorizesOffer", "authorizesAccept",
                "authorizesChat", "mayReportProfit", "maySendDiscordWebhook",
                "mayUseForStrategyLearning", "serverSettlementProven",
                "actualDeviceExternallyVerified",
                "publisherAuthenticatedForLive", "rawItemInstancesProven",
                "originalP3P4ServerLeaseProven", "liveLossBudgetApproved",
            ):
                self.assertIs(row[claim], False, (case, claim))
            self.assertIs(row["clientOnly"], True)
            self.assertIs(row["readOnly"], True)

    def test_six_distinct_failures_remain_denied(self):
        expected = {
            "sourceExpired": "C9_SOURCE_TOO_OLD_OR_CLOCK_INVALID",
            "sourceEpochForgery": "C9_SOURCE_TIMESTAMP_NOT_BOUND_TO_MARKET",
            "leaseRevoked": "C9_REVIEWED_P3_P4_LEASE_INACTIVE",
            "partnerLeft": "C9_PROTECTED_PARTNER_NOT_PRESENT",
            "rawItemIdMissing": "C9_OFFER_RAW_INSTANCE_IDENTITY_UNPROVEN",
            "clientOfferAba": "C9_NATIVE_FINAL_GUI_OR_SESSION_CHANGED",
        }
        for k, reason in expected.items():
            with self.subTest(case=k):
                row = self.fixture["observations"][k]
                self.assertEqual(row["status"], "BLOCKED")
                self.assertEqual(row["reason"], reason)
                for flag in ("authorizesOffer", "authorizesAccept",
                             "authorizesTrade", "mayUseForStrategyLearning"):
                    self.assertIs(row[flag], False)

    def test_no_private_client_content_in_any_receipt(self):
        # These literals are solely the synthetic private mock inputs.
        for token in (
            "MAIN_ORIGINAL_JOB_001", "REAL_P3_LEASE_001",
            "121111112", "565555552", "MainTestUser_Alpha",
            "Frostsaber", "Harvester", "Icepiercer", "SnowDagger",
            "rawChat", "webhook_id", "channel_id", "recorded_at_utc",
        ):
            self.assertNotIn(token, self.text)
        self.assertNotIn("ownCounts", self.text)
        self.assertNotIn("sessionScope", self.text)

    def test_preflight_cannot_invoke_original_game_actions(self):
        src = NATIVE.read_text()
        for action in (
            "FireServer(", "InvokeServer(", "AcceptTrade(",
            "DeclineTrade(", "TeleportService", "PostAsync(",
            "SendAsync(", "HttpGet(", "mouse1click(", "setclipboard(",
            "loadstring(", "request({",
        ):
            self.assertNotIn(action, src)
        self.assertIn("SOURCE_TIMESTAMP_NOT_BOUND_TO_MARKET", src)
        self.assertIn("SOURCE_TOO_OLD_OR_CLOCK_INVALID", src)
        self.assertIn("sameCounts(a.ownCounts,b.ownCounts)", src)
        self.assertIn("sameSide(x.our,y.our)", src)
        self.assertIn("sameSide(x.their,y.their)", src)


if __name__ == "__main__":
    unittest.main()
