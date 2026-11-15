"""C8 end-to-end OFFLINE original C3 scanner/P4 GUI -> C6 chat -> C7 native
V2 body -> strict Python receiver. The P3 request and terminal closure in
this case are explicitly synthetic, not MM2 server or Discord network events.
Run C3 native Lune fixture generation first; never fake a missing fixture.
"""
from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path
import unittest

from pdiddler.system2.discord_v2_event_intake import review
from pdiddler.system2.private_v2_response_learning_gate import (
    compile_client_evidence,
)

FIXTURE = Path(__file__).with_name(".generated_system2_c8_original_c6_v2.json")
CHANNEL = "1523456789012345678"
WEBHOOK = "1623456789012345678"


class C8OriginalC3C6ToC7PythonReceiver(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not FIXTURE.is_file():
            raise AssertionError("ORIGINAL_C3_P4_C6_C7_LUNE_RUN_REQUIRED")
        cls.fixture = json.loads(FIXTURE.read_text())
        if cls.fixture.get("fixtureOnly") is not True or (
            cls.fixture.get("transportNeverSent") is not True
            or cls.fixture.get("syntheticP3Request") is not True
            or cls.fixture.get("syntheticP4Closure") is not True
            or cls.fixture.get("actualOriginalC3C6C7CodeExecuted") is not True
        ):
            raise AssertionError("ORIGINAL_C8_NATIVE_LAB_PROVENANCE_FLAGS_MISSING")
        if len(cls.fixture["records"]) != 5:
            raise AssertionError("ORIGINAL_C8_NATIVE_EVENT_COUNT_CHANGED")
        cls.rows = []
        for i, payload in enumerate(cls.fixture["records"], 1):
            cls.rows.append({
                **payload,
                "channel_id": CHANNEL,
                "webhook_id": WEBHOOK,
                "message_id": str(1723456789111200000 + i),
                "recorded_at_utc": f"2026-11-15T16:00:{i:02d}Z",
            })

    def evidence(self, rows=None, *, origin=False):
        return compile_client_evidence(
            self.rows if rows is None else rows,
            expected_channel_id=CHANNEL,
            expected_webhook_id=WEBHOOK,
            private_collector_origin=origin,
        )

    def test_actual_native_speaker_classification_to_receiver(self):
        result = review(
            self.rows,
            expected_channel_id=CHANNEL,
            expected_webhook_id=WEBHOOK,
        )
        self.assertEqual(result["status"],
                         "PRIVATE_BOT_V2_ENVELOPE_SHAPE_REVIEW_ONLY", result)
        self.assertEqual(result["messageClaimCount"], 5)
        self.assertEqual(result["distinctSessionCount"], 1)
        self.assertEqual(result["realTrainingRowsAuthorized"], 0)
        self.assertFalse(result["privateBotNetworkDeliveryAuthenticated"])
        self.assertEqual(
            [r["kind"] for r in self.rows],
            ["MAIN_REQUEST_PENDING", "PARTNER_REQUEST_ACCEPTED",
             "PARTNER_OFFER_REVISION", "CHAT_DIRECT_CLIENT_ATTRIBUTED",
             "CLIENT_WINDOW_CLOSED_UNKNOWN"],
        )

    def test_real_original_C6_direct_not_a_settled_trade(self):
        result = self.evidence()
        self.assertEqual(
            result["status"],
            "PRIVATE_BOT_V2_RESPONSE_EPISODES_CLASSIFIED_RESEARCH_ONLY",
            result,
        )
        self.assertEqual(result["clientRequestAcceptedCount"], 1)
        self.assertEqual(result["chatDirectClientClaimCount"], 1)
        self.assertEqual(result["clientTradePartnerIndicatorsFinalRevision"], 0)
        self.assertEqual(result["knownTradeSettlements"], 0)
        self.assertEqual(result["confirmedTradeAcceptanceDenominator"], 0)
        self.assertEqual(result["realResponseRewardLabelsForModel"], 0)
        self.assertFalse(result["mayUseForStrategyLearning"])
        self.assertFalse(result["mayReportProfit"])
        self.assertFalse(result["maySendDiscordWebhook"])
        self.assertFalse(result["authorizesAccept"])
        self.assertFalse(result["deployableLearnedModelAvailable"])
        self.assertFalse(result["privateCollectorOriginClaim"])

    def test_caller_claim_of_private_delivery_is_not_settlement(self):
        result = self.evidence(origin=True)
        self.assertTrue(result["privateCollectorOriginClaim"])
        self.assertFalse(result["archiveHasRealNetworkEvidenceAttestation"])
        self.assertEqual(result["knownTradeSettlements"], 0)
        self.assertFalse(result["authorizesTrade"])
        self.assertFalse(result["mayUseForStrategyLearning"])

    def test_duplicate_transport_no_double_counted_trade(self):
        result = self.evidence(self.rows + deepcopy(self.rows))
        self.assertEqual(result["transportMessagesDeduplicated"], 5)
        self.assertEqual(result["clientRequestAcceptedCount"], 1)
        self.assertEqual(result["knownTradeSettlements"], 0)

    def test_forged_server_settlement_field_rejected(self):
        poisoned = deepcopy(self.rows)
        poisoned[-1]["serverTradeSettlementProven"] = True
        r = self.evidence(poisoned)
        self.assertEqual(r["status"], "BLOCKED", r)
        self.assertFalse(r["mayUseForStrategyLearning"])
        self.assertFalse(r["authorizesAccept"])

    def test_modified_native_direct_kind_rejected(self):
        poisoned = deepcopy(self.rows)
        poisoned[3]["kind"] = "CLIENT_SERVER_ACCEPT_PROVEN"
        r = self.evidence(poisoned)
        self.assertEqual(r["status"], "BLOCKED", r)
        self.assertEqual(r["realCompletedTradesUsedForLearning"], 0)

    def test_private_identity_does_not_cross_to_v2_body(self):
        serialized = FIXTURE.read_text()
        for raw in (
            "MAIN_ORIGINAL_JOB_001", "REAL_P3_LEASE_001",
            "121111112", "565555552", "MainTestUser_Alpha",
            "@MainTestUser_Alpha", "webhook_id", "channel_id",
            "recorded_at_utc", "rawChat", "Gingerscope",
        ):
            self.assertNotIn(raw, serialized)
        self.assertEqual(self.fixture["transportNeverSent"], True)
        self.assertEqual(self.fixture["syntheticP3Request"], True)
        self.assertEqual(self.fixture["syntheticP4Closure"], True)


if __name__ == "__main__":
    unittest.main()
