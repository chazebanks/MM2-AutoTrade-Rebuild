"""Adversarial S2 C7 private Discord V2 client response/learning-evidence tests.

All synthetic sender/Discord records. No private bot token, network or player ID.
"""
from __future__ import annotations
from copy import deepcopy
from datetime import datetime,timezone,timedelta
from hashlib import sha256
import unittest

from pdiddler.system2.discord_v2_event_intake import SCHEMA,SOURCE,CLIENT_PROOF
from pdiddler.system2.private_v2_response_learning_gate import compile_client_evidence,SCHEMA as REPORT

CHANNEL="1523456789012345678"
WEBHOOK="1623456789012345678"
def h(value):
    return sha256(value.encode()).hexdigest()

def row(ep,seq,kind,rev=0,*,partner=None,scope="PUBLIC_CLIENT_OBSERVATION",
        stamp=None, message=None):
    t=(datetime(2026,11,14,12,0,0,tzinfo=timezone.utc)+
       timedelta(seconds=ep*60+seq) if stamp is None else stamp)
    return {
        "schema":SCHEMA,"source":SOURCE,"scope":scope,
        "channel_id":CHANNEL,"message_id":str(message or
            (1723456789000000000+ep*1000+seq)),
        "webhook_id":WEBHOOK,"recorded_at_utc":t.isoformat().replace("+00:00","Z"),
        "event_id":h(f"{ep}:{seq}:{kind}:{rev}"),
        "job_digest":h("job"+str(ep)),"session_digest":h("session"+str(ep)),
        "partner_digest":h("partner"+str(partner or ep)),
        "lease_digest":h("lease"+str(ep)),
        "event_seq":seq,"revision":rev,"kind":kind,
        "client_provenance":CLIENT_PROOF,
    }
def gate(events,origin=True):
    return compile_client_evidence(events,expected_channel_id=CHANNEL,
       expected_webhook_id=WEBHOOK,private_collector_origin=origin)
class V2EvidenceTest(unittest.TestCase):
    def blocked(self,records,why):
        v=gate(records)
        self.assertEqual(v["status"],"BLOCKED",v)
        self.assertEqual(v["reason"],why,v)
        self.assertEqual(v["mayUseForStrategyLearning"],False)
        self.assertFalse(v["authorizesAccept"])

    def test_real_client_request_decline_vs_nonresponse(self):
        events=[row(1,1,"MAIN_REQUEST_PENDING"),row(1,2,"PARTNER_DECLINED"),
                row(2,1,"MAIN_REQUEST_PENDING"),
                row(2,2,"PARTNER_NO_RESPONSE_TIMEOUT"),
                row(3,1,"MAIN_REQUEST_PENDING"),
                row(3,2,"PARTNER_REQUEST_ACCEPTED"),
                row(3,3,"PARTNER_OFFER_REVISION",1),
                row(3,4,"PARTNER_ACCEPT_INDICATOR",1),
                row(3,5,"CLIENT_WINDOW_CLOSED_UNKNOWN",1)]
        a=gate(events)
        self.assertEqual(a["status"],
            "PRIVATE_BOT_V2_RESPONSE_EPISODES_CLASSIFIED_RESEARCH_ONLY")
        self.assertEqual(a["clientRequestAcceptedCount"],1)
        self.assertEqual(a["explicitClientRequestDeclinedCount"],1)
        self.assertEqual(a["requestCensoredOrPendingCount"],1)
        self.assertEqual(a["clientTradePartnerIndicatorsFinalRevision"],1)
        self.assertEqual(a["knownTradeSettlements"],0)
        self.assertEqual(a["confirmedTradeAcceptanceDenominator"],0)
        self.assertIsNone(a["measuredTradeAcceptanceProbability"])
        self.assertFalse(a["modelDeploymentAuthorized"])
        self.assertNotIn(h("session1"),str(a))
        self.assertNotIn(h("partner1"),str(a))
        self.assertNotIn(CHANNEL,str(a))
        self.assertNotIn(WEBHOOK,str(a))

    def test_main_alt_sessions_never_contribute_real_response_denominator(self):
        rows=[row(1,1,"MAIN_REQUEST_PENDING",scope="MAIN_ALT_TEST"),
              row(1,2,"PARTNER_DECLINED",scope="MAIN_ALT_TEST"),
              row(2,1,"MAIN_REQUEST_PENDING"),
              row(2,2,"PARTNER_DECLINED")]
        a=gate(rows)
        self.assertEqual(a["excludedMainAltTestSessionClaims"],1)
        self.assertEqual(a["publicClientSessionClaims"],1)
        self.assertEqual(a["explicitClientRequestDeclinedCount"],1)
        self.assertFalse(a["partnerDisjointHoldoutReady"])

    def test_duplicate_discord_delivery_never_two_requests(self):
        rows=[row(1,1,"MAIN_REQUEST_PENDING"),row(1,2,"PARTNER_DECLINED")]
        a=gate(rows+rows)
        self.assertEqual(a["transportMessagesDeduplicated"],2)
        self.assertEqual(a["publicClientSessionClaims"],1)

    def test_mutated_duplicate_discord_message_rejected(self):
        a=row(1,1,"MAIN_REQUEST_PENDING");b=deepcopy(a)
        b["partner_digest"]=h("changed")
        self.blocked([a,b],"STRICT_V2_REVIEW_DISCORD_V2_MUTATED_DUPLICATE_RECEIPT")

    def test_replayed_event_in_different_discord_message_rejected(self):
        a=row(1,1,"MAIN_REQUEST_PENDING");b=deepcopy(a)
        b["message_id"]=str(int(a["message_id"])+100)
        self.blocked([a,b],"STRICT_V2_REVIEW_DISCORD_V2_EVENT_REPLAYED_WITH_DIFFERENT_MESSAGE")

    def test_client_accept_indicator_never_server_settlement(self):
        x=[row(1,1,"MAIN_REQUEST_PENDING"),
           row(1,2,"PARTNER_REQUEST_ACCEPTED"),
           row(1,3,"MAIN_OFFER_REVISION",1),
           row(1,4,"PARTNER_ACCEPT_INDICATOR",1),
           row(1,5,"MAIN_ACCEPT_INDICATOR",1),
           row(1,6,"CLIENT_INVENTORY_DELTA_OBSERVED",1),
           row(1,7,"CLIENT_WINDOW_CLOSED_UNKNOWN",1)]
        v=gate(x)
        self.assertEqual(v["clientTradePartnerIndicatorsFinalRevision"],1)
        self.assertEqual(v["clientInventoryDeltaClaims"],1)
        self.assertEqual(v["realCompletedTradesUsedForLearning"],0)
        self.assertEqual(v["tradeOutcome"],"UNKNOWN")
        self.assertEqual(v["realResponseRewardLabelsForModel"],0)

    def test_partner_indicator_invalidated_on_offer_revision(self):
        x=[row(1,1,"MAIN_REQUEST_PENDING"),
           row(1,2,"PARTNER_REQUEST_ACCEPTED"),
           row(1,3,"PARTNER_ACCEPT_INDICATOR"),
           row(1,4,"MAIN_OFFER_REVISION",1),
           row(1,5,"CLIENT_WINDOW_CLOSED_UNKNOWN",1)]
        self.assertEqual(gate(x)["clientTradePartnerIndicatorsFinalRevision"],0)

    def test_client_nonresponse_cancel_and_unknown_not_partner_declines(self):
        x=[]
        pairs=[
            ["MAIN_REQUEST_PENDING","PARTNER_NO_RESPONSE_TIMEOUT"],
            ["MAIN_REQUEST_PENDING","PARTNER_REQUEST_ACCEPTED","PARTNER_CANCELLED"],
            ["MAIN_REQUEST_PENDING","PARTNER_REQUEST_ACCEPTED","MAIN_CANCELLED"],
            ["MAIN_REQUEST_PENDING","PARTNER_REQUEST_ACCEPTED","CLIENT_WINDOW_CLOSED_UNKNOWN"],
            ["MAIN_REQUEST_PENDING"],
        ]
        for ep,choices in enumerate(pairs,1):
            x.extend(row(ep,j,kind) for j,kind in enumerate(choices,1))
        a=gate(x)
        self.assertEqual(a["explicitClientRequestDeclinedCount"],0)
        self.assertEqual(a["clientRequestAcceptedCount"],3)
        self.assertEqual(a["requestCensoredOrPendingCount"],2)
        self.assertEqual(a["knownTradeSettlements"],0)

    def test_temporal_receipt_rollback_rejected(self):
        x=[row(1,1,"MAIN_REQUEST_PENDING"),
           row(1,2,"PARTNER_DECLINED",stamp=datetime(2026,11,14,10,0,0,
                                                       tzinfo=timezone.utc))]
        self.blocked(x,"DISCORD_DELIVERY_TIME_ROLLBACK")

    def test_unordered_sequence_fails_strict_v2(self):
        x=[row(1,2,"PARTNER_DECLINED"),row(1,1,"MAIN_REQUEST_PENDING")]
        self.blocked(x,"STRICT_V2_REVIEW_DISCORD_V2_REQUEST_BASELINE_REQUIRED")

    def test_offer_revision_gap_fails(self):
        x=[row(1,1,"MAIN_REQUEST_PENDING"),
           row(1,2,"PARTNER_REQUEST_ACCEPTED"),
           row(1,3,"PARTNER_OFFER_REVISION",2)]
        self.blocked(x,"STRICT_V2_REVIEW_DISCORD_V2_UNBOUND_OFFER_REVISION")

    def test_real_private_collector_flag_is_caller_assertion_not_crypto_proof(self):
        x=[row(1,1,"MAIN_REQUEST_PENDING")]
        a=gate(x,True);b=gate(x,False)
        self.assertTrue(a["privateCollectorOriginClaim"])
        self.assertFalse(b["privateCollectorOriginClaim"])
        for v in (a,b):
            self.assertFalse(v["archiveHasRealNetworkEvidenceAttestation"])
            self.assertFalse(v["independentlyAuthenticatedClientIdentity"])
            self.assertFalse(v["discordTransportIsGameServerProof"])

    def test_no_real_v2_archive_yet_blocks(self):
        self.blocked([],"NO_PRIVATE_V2_ENVELOPES_YET")

    def test_partner_disjoint_holdout_12_unique_4_holdout(self):
        x=[]
        for ep in range(1,13):
            x.extend([row(ep,1,"MAIN_REQUEST_PENDING"),
                      row(ep,2,"PARTNER_DECLINED")])
        a=gate(x)
        self.assertTrue(a["partnerDisjointHoldoutReady"])
        self.assertEqual((a["partnerDisjointTrainGroups"],
                          a["partnerDisjointHoldoutGroups"]),(8,4))
        self.assertFalse(a["deployableLearnedModelAvailable"])

    def test_12_sessions_only_two_unique_partners_cannot_claim_holdout(self):
        x=[]
        for ep in range(1,13):
            x.extend([row(ep,1,"MAIN_REQUEST_PENDING",partner=ep%2+1),
                      row(ep,2,"PARTNER_DECLINED",partner=ep%2+1)])
        a=gate(x)
        self.assertFalse(a["partnerDisjointHoldoutReady"])
        self.assertEqual(a["publicDistinctPartnerDigestsCount"],2)

    def test_mixed_same_partner_main_alt_does_not_create_new_public_identity(self):
        x=[row(1,1,"MAIN_REQUEST_PENDING",partner=1,scope="MAIN_ALT_TEST"),
           row(2,1,"MAIN_REQUEST_PENDING",partner=1),
           row(3,1,"MAIN_REQUEST_PENDING",partner=1)]
        a=gate(x)
        self.assertEqual(a["publicDistinctPartnerDigestsCount"],1)
        self.assertEqual(a["publicClientSessionClaims"],2)
        self.assertEqual(a["excludedMainAltTestSessionClaims"],1)

    def test_chat_kinds_do_not_create_verified_preference_or_reward(self):
        x=[row(1,1,"MAIN_REQUEST_PENDING"),
           row(1,2,"PARTNER_REQUEST_ACCEPTED"),
           row(1,3,"CHAT_DIRECT_CLIENT_ATTRIBUTED"),
           row(1,4,"CHAT_AMBIGUOUS"),
           row(1,5,"CLIENT_WINDOW_CLOSED_UNKNOWN")]
        a=gate(x)
        self.assertEqual(a["chatDirectClientClaimCount"],1)
        self.assertEqual(a["chatAmbiguousClientClaimCount"],1)
        self.assertFalse(a["liveOfferFeatureBindingProven"])
        self.assertFalse(a["mayUseForStrategyLearning"])

    def test_spoofed_name_or_item_feature_never_accepted(self):
        x=[row(1,1,"MAIN_REQUEST_PENDING")]
        for name,val in [("player_name","a"),("item","Harvester"),
                         ("completed",True),("claimed_profit",1000)]:
            y=deepcopy(x[0]);y[name]=val
            self.blocked([y],"STRICT_V2_REVIEW_DISCORD_V2_FIELDS_NOT_EXACT")

    def test_empty_scope_or_secrets_not_printed(self):
        x=[row(1,1,"MAIN_REQUEST_PENDING")]
        a=gate(x)
        self.assertNotIn(x[0]["event_id"],str(a))
        self.assertNotIn(x[0]["session_digest"],str(a))
        self.assertNotIn(x[0]["partner_digest"],str(a))
        self.assertIsNone(a["measuredTradeAcceptanceProbability"])

if __name__=="__main__":
    unittest.main()
