"""Cross-language integration test: actually emitted Luau V2 BODY passes Python V2 schema.

All sources synthetic, no private data/Discord network. The fake test digest
function in native Lune is intentionally NOT SHA-256. This test proves only
body field names, phase/revision semantics, and source-receiver compatibility.
"""
from __future__ import annotations
from pathlib import Path
import json
import unittest
from pdiddler.system2.discord_v2_event_intake import review
from pdiddler.system2.private_v2_response_learning_gate import compile_client_evidence

CHANNEL="1523456789012345678"
WEBHOOK="1623456789012345678"
FIXTURE=Path(__file__).with_name(".generated_system2_v2_synthetic.json")
class NativeToPrivateV2Receiver(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        assert FIXTURE.is_file(), "RUN_NATIVE_LUNE_STAGING_FIRST"
        cls.data=json.loads(FIXTURE.read_text())
        assert cls.data["fixtureOnly"] is True
        assert cls.data["transportNeverSent"] is True
        cls.rows=[]
        for i,body in enumerate(cls.data["records"],1):
            cls.rows.append({
                **body,
                "channel_id":CHANNEL,
                "webhook_id":WEBHOOK,
                "message_id":str(1723456789111100000+i),
                "recorded_at_utc":f"2026-11-14T17:00:{i:02d}Z",
            })
    def test_same_schema_native_python_private_collector(self):
        r=review(self.rows,expected_channel_id=CHANNEL,
                 expected_webhook_id=WEBHOOK)
        self.assertEqual(r["status"],
            "PRIVATE_BOT_V2_ENVELOPE_SHAPE_REVIEW_ONLY",r)
        self.assertEqual(r["messageClaimCount"],6)
        self.assertEqual(r["distinctSessionCount"],1)
        self.assertEqual(r["realTrainingRowsAuthorized"],0)
        self.assertFalse(r["privateBotNetworkDeliveryAuthenticated"])

    def test_client_unknown_closure_never_completion(self):
        r=compile_client_evidence(
            self.rows,expected_channel_id=CHANNEL,
            expected_webhook_id=WEBHOOK,private_collector_origin=False)
        self.assertEqual(r["status"],
            "PRIVATE_BOT_V2_RESPONSE_EPISODES_CLASSIFIED_RESEARCH_ONLY",r)
        self.assertEqual(r["clientRequestAcceptedCount"],1)
        self.assertEqual(r["chatDirectClientClaimCount"],1)
        self.assertEqual(r["clientTradePartnerIndicatorsFinalRevision"],1)
        self.assertEqual(r["knownTradeSettlements"],0)
        self.assertEqual(r["realResponseRewardLabelsForModel"],0)
        self.assertFalse(r["mayUseForStrategyLearning"])
        self.assertFalse(r["privateCollectorOriginClaim"])

    def test_raw_info_never_crosses_native_bridge(self):
        text=FIXTURE.read_text()
        for phrase in ("FAKE_JOB_ID_COMP7","FAKE_LEASE_ID_COMP7",
                       "500010001","500010002","MainTestUser_Alpha",
                       "webhook_id","channel_id","recorded_at_utc"):
            self.assertNotIn(phrase,text)

    def test_duplicates_are_idempotent_not_two_server_trades(self):
        rows=self.rows+self.rows
        r=compile_client_evidence(
            rows,expected_channel_id=CHANNEL,
            expected_webhook_id=WEBHOOK,private_collector_origin=False)
        self.assertEqual(r["transportMessagesDeduplicated"],6)
        self.assertEqual(r["knownTradeSettlements"],0)

if __name__=="__main__":
    unittest.main()
