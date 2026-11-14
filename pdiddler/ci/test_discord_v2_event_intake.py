"""Adversarial source tests for the EXISTING bot's proposed V2 private envelope.
No real Discord network or MM2 trade runs occur here.
"""
from __future__ import annotations
from copy import deepcopy
from hashlib import sha256
import unittest

from pdiddler.system2.discord_v2_event_intake import (
    SCHEMA, SOURCE, CLIENT_PROOF, review,
)

CHANNEL="1523456789012345678"
WEBHOOK="1623456789012345678"
def h(s):
    return sha256(s.encode("ascii")).hexdigest()

def row(ep,seq,kind,rev=0,*,msg=None,scope="MAIN_ALT_TEST"):
    return {
        "schema":SCHEMA,"source":SOURCE,"scope":scope,
        "channel_id":CHANNEL,"webhook_id":WEBHOOK,
        "message_id":str(msg or (1723456789012000000+ep*1000+seq)),
        "recorded_at_utc":"2026-11-14T15:30:00Z",
        "event_id":h(f"{ep}|{seq}|{kind}|{rev}"),
        "job_digest":h("job"),"session_digest":h(f"session{ep}"),
        "partner_digest":h(f"partner{ep}"),"lease_digest":h(f"lease{ep}"),
        "event_seq":seq,"revision":rev,"kind":kind,
        "client_provenance":CLIENT_PROOF,
    }

def parse(events):
    return review(events,expected_channel_id=CHANNEL,expected_webhook_id=WEBHOOK)

class StrictPrivateDiscordV2(unittest.TestCase):
    def deny(self,result):
        for name in ("privateBotNetworkDeliveryAuthenticated","gameServerSettlementVerified",
                     "historicalV1ClaimsUsedAsRewards","mayUseForStrategyLearning",
                     "mayReportProfit","maySendDiscordWebhook","authorizesOffer",
                     "authorizesTrade","authorizesAccept","publicFinalAcceptAuthorized"):
            self.assertIs(result[name],False,name)
        self.assertEqual(result["tradeOutcome"],"UNKNOWN")
        self.assertIsNone(result["realPlayerAcceptanceProbability"])

    def blocked(self,rows,reason):
        r=parse(rows)
        self.assertEqual(r["status"],"BLOCKED",r)
        self.assertEqual(r["reason"],reason,r)
        self.deny(r)

    def test_distinct_live_negative_and_revisions_not_fake_completed_trades(self):
        rows=[
            row(1,1,"MAIN_REQUEST_PENDING"),
            row(1,2,"PARTNER_DECLINED"),
            row(2,1,"MAIN_REQUEST_PENDING"),
            row(2,2,"PARTNER_NO_RESPONSE_TIMEOUT"),
            row(3,1,"MAIN_REQUEST_PENDING"),
            row(3,2,"PARTNER_REQUEST_ACCEPTED"),
            row(3,3,"PARTNER_OFFER_REVISION",1),
            row(3,4,"PARTNER_ACCEPT_INDICATOR",1),
            row(3,5,"CLIENT_WINDOW_CLOSED_UNKNOWN",1),
            row(4,1,"MAIN_REQUEST_PENDING"),
            row(4,2,"PARTNER_REQUEST_ACCEPTED"),
            row(4,3,"MAIN_OFFER_REVISION",1),
            row(4,4,"PARTNER_CANCELLED",1),
        ]
        r=parse(rows)
        self.assertEqual(r["status"],"PRIVATE_BOT_V2_ENVELOPE_SHAPE_REVIEW_ONLY",r)
        self.assertEqual(r["distinctSessionCount"],4)
        self.assertEqual(r["exactMainAltTestSessionsExcludedFromLearning"],4)
        self.assertEqual(r["kindCounts"]["EXPLICIT_PARTNER_DECLINE_CLIENT"],1)
        self.assertEqual(r["kindCounts"]["CENSORED_NO_RESPONSE"],1)
        self.assertEqual(r["kindCounts"]["PARTNER_CANCELLED"],1)
        self.assertEqual(r["kindCounts"]["CLIENT_WINDOW_CLOSED_UNKNOWN"],1)
        self.assertEqual(r["kindCounts"]["REVISION"],2)
        self.assertEqual(r["realTrainingRowsAuthorized"],0)
        self.deny(r)
        self.assertNotIn(CHANNEL,str(r))
        self.assertNotIn(WEBHOOK,str(r))

    def test_idempotent_redelivery_does_not_count_as_two_results(self):
        r=parse([row(1,1,"MAIN_REQUEST_PENDING"),row(1,2,"PARTNER_DECLINED"),
                 row(1,2,"PARTNER_DECLINED")])
        self.assertEqual(r["messageClaimCount"],2)
        self.assertEqual(r["idempotentRedeliveries"],1)
        self.assertEqual(r["kindCounts"]["EXPLICIT_PARTNER_DECLINE_CLIENT"],1)
        self.deny(r)

    def test_mutated_same_discord_id_blocked(self):
        a=row(1,1,"MAIN_REQUEST_PENDING")
        b=deepcopy(a);b["job_digest"]=h("forged")
        self.blocked([a,b],"DISCORD_V2_MUTATED_DUPLICATE_RECEIPT")

    def test_same_event_id_different_message_is_not_new_evidence(self):
        a=row(1,1,"MAIN_REQUEST_PENDING")
        b=deepcopy(a);b["message_id"]=str(int(a["message_id"])+1)
        self.blocked([a,b],"DISCORD_V2_EVENT_REPLAYED_WITH_DIFFERENT_MESSAGE")

    def test_cannot_switch_partner_job_lease_or_scope_mid_session(self):
        a=row(1,1,"MAIN_REQUEST_PENDING")
        for k,v in [("partner_digest",h("wrong")),("job_digest",h("wrong")),
                    ("lease_digest",h("wrong")),("scope","PUBLIC_CLIENT_OBSERVATION")]:
            with self.subTest(k=k):
                b=row(1,2,"PARTNER_DECLINED")
                b[k]=v
                self.blocked([a,b],"DISCORD_V2_PARTNER_JOB_OR_LEASE_SWITCH")

    def test_gap_and_reverse_sequence_blocked(self):
        self.blocked([row(1,1,"MAIN_REQUEST_PENDING"),
                      row(1,3,"PARTNER_DECLINED")],
                     "DISCORD_V2_OUT_OF_ORDER_OR_GAP")
        self.blocked([row(1,2,"PARTNER_DECLINED")],
                     "DISCORD_V2_REQUEST_BASELINE_REQUIRED")

    def test_revision_must_be_active_and_sequential(self):
        a=row(1,1,"MAIN_REQUEST_PENDING")
        self.blocked([a,row(1,2,"PARTNER_OFFER_REVISION",1)],
                     "DISCORD_V2_UNBOUND_OFFER_REVISION")
        b=row(1,2,"PARTNER_REQUEST_ACCEPTED")
        self.blocked([a,b,row(1,3,"PARTNER_OFFER_REVISION",2)],
                     "DISCORD_V2_UNBOUND_OFFER_REVISION")
        self.blocked([a,b,row(1,3,"MAIN_ACCEPT_INDICATOR",1)],
                     "DISCORD_V2_STALE_OR_FUTURE_REVISION")

    def test_decline_no_response_cancellation_are_not_interchangeable(self):
        a=row(1,1,"MAIN_REQUEST_PENDING")
        b=row(1,2,"PARTNER_REQUEST_ACCEPTED")
        self.blocked([a,b,row(1,3,"PARTNER_NO_RESPONSE_TIMEOUT")],
                     "DISCORD_V2_TIMEOUT_NOT_PENDING")
        self.blocked([a,row(1,2,"PARTNER_CANCELLED")],
                     "DISCORD_V2_CANCEL_OR_CLOSE_BEFORE_TRADE")

    def test_post_terminal_event_cannot_create_second_outcome(self):
        self.blocked([row(1,1,"MAIN_REQUEST_PENDING"),
                      row(1,2,"PARTNER_DECLINED"),
                      row(1,3,"PARTNER_REQUEST_ACCEPTED")],
                     "DISCORD_V2_EVENT_AFTER_TERMINAL")

    def test_accept_indicator_and_client_delta_are_not_settlement(self):
        rows=[
            row(1,1,"MAIN_REQUEST_PENDING"),
            row(1,2,"PARTNER_REQUEST_ACCEPTED"),
            row(1,3,"PARTNER_OFFER_REVISION",1),
            row(1,4,"PARTNER_ACCEPT_INDICATOR",1),
            row(1,5,"CLIENT_INVENTORY_DELTA_OBSERVED",1),
            row(1,6,"CLIENT_WINDOW_CLOSED_UNKNOWN",1),
        ]
        r=parse(rows)
        self.assertEqual(r["kindCounts"]["CLIENT_INDICATOR_NO_SETTLEMENT"],2)
        self.assertEqual(r["kindCounts"]["CLIENT_WINDOW_CLOSED_UNKNOWN"],1)
        self.deny(r)

    def test_unknown_fields_identifiers_and_forged_live_authority_rejected(self):
        base=row(1,1,"MAIN_REQUEST_PENDING")
        for k,v in [("username","privateplayer"),("server_settlement",True),
                    ("authorizesAccept",True),("rawWeaponName","Iceblaster")]:
            with self.subTest(field=k):
                b=deepcopy(base);b[k]=v
                self.blocked([b],"DISCORD_V2_FIELDS_NOT_EXACT")

    def test_source_and_bad_hash_rejected(self):
        for k,v in [("channel_id","000000000000000000"),
                    ("webhook_id","000000000000000000"),
                    ("scope","NO_SCOPE")]:
            with self.subTest(k=k):
                b=row(1,1,"MAIN_REQUEST_PENDING");b[k]=v
                self.blocked([b],"DISCORD_V2_CHANNEL_SOURCE_OR_SCOPE_INVALID")
        b=row(1,1,"MAIN_REQUEST_PENDING")
        b["partner_digest"]="plaintext-account"
        self.blocked([b],"DISCORD_V2_EVENT_BINDING_OR_KIND_INVALID")

    def test_bool_numeric_and_bad_timestamps_block(self):
        for k,v,reason in [("event_seq",True,"DISCORD_V2_FIELDS_NOT_EXACT"),
                           ("revision",False,"DISCORD_V2_FIELDS_NOT_EXACT"),
                           ("recorded_at_utc","nope","DISCORD_V2_TIMESTAMP_INVALID"),
                           ("recorded_at_utc","2026-02-30T00:00:00Z",
                            "DISCORD_V2_TIMESTAMP_INVALID")]:
            with self.subTest(k=k,v=v):
                b=row(1,1,"MAIN_REQUEST_PENDING");b[k]=v
                self.blocked([b],reason)

    def test_synthetic_public_scope_still_no_training(self):
        rows=[row(1,1,"MAIN_REQUEST_PENDING",scope="PUBLIC_CLIENT_OBSERVATION"),
              row(1,2,"PARTNER_DECLINED",scope="PUBLIC_CLIENT_OBSERVATION")]
        r=parse(rows)
        self.assertEqual(r["exactMainAltTestSessionsExcludedFromLearning"],0)
        self.assertEqual(r["realTrainingRowsAuthorized"],0)
        self.deny(r)

    def test_v1_completion_embed_not_accepted_as_v2(self):
        self.blocked([{"schema":"mm2-discord-private-evidence-ledger-v1",
                       "classification":"PARSED_UNVERIFIED_WEBHOOK_CLAIM"}],
                     "DISCORD_V2_FIELDS_NOT_EXACT")

if __name__=="__main__":
    unittest.main()
