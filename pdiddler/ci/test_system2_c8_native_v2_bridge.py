"""C8: actual native Luau V2 staging -> real Python private receiver -> C8 gate.

Lune must generate the synthetic fixture immediately before these tests. The
native fixture uses a deliberately non-cryptographic digest and proves NO
authenticated network transport or game server settlement.
"""
import copy
import json
import unittest
from pathlib import Path
from pdiddler.system2.private_v2_response_learning_gate import compile_client_evidence
from pdiddler.system2.c8_replay_admission import review, REQUIRED
from pdiddler.ci.test_system2_native_to_private_v2_compatibility import (
    CHANNEL, WEBHOOK, FIXTURE,
)

CONTEXT=dict(sourceSha256="a"*64,jobId="synthetic-job-only",
             leaseId="synthetic-lease-only",partnerUserId=12345,
             offerRevision=1,inventoryCensusSha256="b"*64)

def _receipts(feedback):
    # Other five receipts are placeholders, not proof of their native execution.
    base={k:dict(context=copy.deepcopy(CONTEXT),status="RESEARCH_ONLY",
                 readOnly=True,authorizesTrade=False,authorizesOffer=False,
                 authorizesAccept=False,authorizesChat=False,
                 mayUseForStrategyLearning=False,mayReportProfit=False,
                 maySendDiscordWebhook=False,serverCompletionProven=False)
          for k in REQUIRED}
    base["growth"].update(schema="gingerscope-system2-multitrade-growth-replay-v1",
                          status="OFFLINE_GROWTH_PATH_SIMULATED")
    base["chat"]["personalReplyProven"]=False
    base["feedback"].update(feedback)
    base["feedback"]["context"]=copy.deepcopy(CONTEXT)
    base["feedback"]["serverCompletionProven"]=False
    return base

class C8NativeV2Bridge(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not FIXTURE.is_file():
            raise AssertionError("C8_NATIVE_LUNE_STAGING_REQUIRED")
        fixture=json.loads(FIXTURE.read_text())
        assert fixture["fixtureOnly"] is True
        assert fixture["transportNeverSent"] is True
        cls.rows=[dict(body,channel_id=CHANNEL,webhook_id=WEBHOOK,
                       message_id=str(1723456789111100000+i),
                       recorded_at_utc=f"2026-11-14T17:00:{i:02d}Z")
                  for i,body in enumerate(fixture["records"],1)]
    def feedback(self,rows=None):
        return compile_client_evidence(
            self.rows if rows is None else rows,
            expected_channel_id=CHANNEL,expected_webhook_id=WEBHOOK,
            private_collector_origin=False)
    def test_native_envelope_to_real_feedback_to_c8(self):
        feedback=self.feedback()
        self.assertEqual(feedback["status"],
                         "PRIVATE_BOT_V2_RESPONSE_EPISODES_CLASSIFIED_RESEARCH_ONLY",
                         feedback)
        result=review(_receipts(feedback),expected_context=CONTEXT)
        self.assertEqual(result["status"],"OFFLINE_C8_COMPONENT_CONTEXTS_ALIGNED",
                         result)
        self.assertFalse(result["mayUseForStrategyLearning"])
        self.assertFalse(result["serverCompletionProven"])
        self.assertFalse(result["liveSourceBindingProven"])
    def test_replayed_native_messages_never_become_trade_labels(self):
        feedback=self.feedback(self.rows+self.rows)
        self.assertEqual(feedback["transportMessagesDeduplicated"],6)
        self.assertEqual(feedback["realResponseRewardLabelsForModel"],0)
        self.assertEqual(feedback["knownTradeSettlements"],0)
        self.assertFalse(review(_receipts(feedback),expected_context=CONTEXT)
                         ["mayUseForStrategyLearning"])
    def test_native_feedback_forged_settlement_is_blocked(self):
        feedback=self.feedback()
        feedback["knownTradeSettlements"]=1
        result=review(_receipts(feedback),expected_context=CONTEXT)
        self.assertEqual(result["reason"],"C8_SETTLEMENT_NOT_INDEPENDENTLY_PROVEN")
    def test_native_feedback_forged_feature_labels_blocked(self):
        feedback=self.feedback()
        feedback["realResponseRewardLabelsForModel"]=1
        result=review(_receipts(feedback),expected_context=CONTEXT)
        self.assertEqual(result["reason"],"C8_UNVERIFIED_FEEDBACK_LABELS")
    def test_native_feedback_wrong_session_context_blocked(self):
        feedback=self.feedback()
        receipts=_receipts(feedback)
        receipts["feedback"]["context"]["leaseId"]="different-lease"
        result=review(receipts,expected_context=CONTEXT)
        self.assertEqual(result["reason"],"C8_COMPONENT_CONTEXT_DRIFT_FEEDBACK")

if __name__=="__main__":
    unittest.main()
