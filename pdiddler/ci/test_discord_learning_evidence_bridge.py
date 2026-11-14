"""Source-accurate System2 Discord bot learner ingestion tests.

Uses ORIGINAL historical importer build_record with synthetic Discord embeds,
not fabricated ledger rows. No Discord network, credentials, public archive,
real player identities, asset prices, actual trades or training.
"""
from __future__ import annotations

from copy import deepcopy
import json
import random
import unittest
from scripts.discord_private_history_import import build_record
from scripts.discord_history_embed_audit import TEST_ACCOUNT
from pdiddler.system2.discord_learning_evidence_bridge import (
    review, DENIED, WEBHOOK_FIXTURE_SCHEMA
)

WEBHOOK="1565287412106797999"
IDBASE=1565287412106700000

def fake_message(offset=1,trader="synthetic_player",gave="Eternal IV - 10\nNightblade - 20",
                 received="Iceblaster - 35",values="You: 30 | Them: 35",
                 profit="+5 (16.7%)"):
    return {
        "id":str(IDBASE+offset),
        "webhook_id":WEBHOOK,
        "timestamp":"2026-11-13T12:34:00+00:00",
        "embeds":[{
            "title":"MM2 Trade Completed",
            "fields":[
                {"name":"Trader","value":trader},
                {"name":"Profit","value":profit},
                {"name":"Mode","value":"Auto-managed"},
                {"name":"You gave","value":gave},
                {"name":"You received","value":received},
                {"name":"Values","value":values},
            ]
        }]
    }

def event(ep,seq,kind,rev=0):
    return {
        "schema":WEBHOOK_FIXTURE_SCHEMA,
        "episode":ep,"seq":seq,"kind":kind,"revision":rev,
        "scope":"SYNTHETIC_DISCORD_BOT_TEST_ONLY",
    }

class DiscordLearnerEvidenceTests(unittest.TestCase):
    def deny(self,r):
        for k in (
            "mayUseForStrategyLearning", "mayUpdateLiveTradingPolicy",
            "mayLearnProfitFromHistoricalSelfReports", "maySendDiscordWebhook",
            "authorizesAccept", "publicAutoAcceptAuthorized",
            "mainAltAutoAcceptAuthorizedByThisAdapter", "serverCompletionProven",
            "historicalWebhookClaimsVerifiedAsSettlement"
        ):
            self.assertIs(r[k],False,k)
        self.assertEqual(r["verifiedCompletedTradesForLearning"],0)
        self.assertEqual(r["attributedRealPartnerRefusalsForLearning"],0)
        self.assertIsNone(r["realAcceptanceProbability"])
        self.assertEqual(r["tradeOutcome"],"UNKNOWN")

    def fixture_records(self):
        a=build_record(fake_message(1))
        b=build_record(fake_message(2,trader=TEST_ACCOUNT))
        c=build_record(fake_message(3,gave="Iceblaster x2 - 70"))
        self.assertIsNotNone(a)
        self.assertIsNotNone(b)
        self.assertIsNotNone(c)
        self.assertEqual(a["classification"],"PARSED_UNVERIFIED_WEBHOOK_CLAIM")
        self.assertEqual(b["classification"],"TEST_ACCOUNT_EXCLUDED")
        self.assertEqual(c["classification"],"UNPARSEABLE_ITEM_BUNDLE")
        return a,b,c

    def test_actual_original_discord_importer_to_s2(self):
        records=self.fixture_records()
        r=review(list(records))
        self.assertEqual(r["status"],"DISCORD_ARCHIVE_TO_S2_EVIDENCE_RESEARCH_ONLY",r)
        self.assertEqual(r["distinctArchivedWebhookMessages"],3)
        self.assertEqual(r["historicalSelfReportedCompletedClaims"],1)
        self.assertEqual(r["excludedExactTestAccountReceipts"],1)
        self.assertEqual(r["quarantinedMalformedOrAmbiguousReceipts"],1)
        self.assertEqual(r["verifiedCompletedTradesForLearning"],0)
        self.assertFalse(r["actualDiscordRejectionEventPipelineImplemented"])
        self.assertEqual(r["futureWebhookOutcomeEventsActuallyCaptured"],0)
        self.deny(r)
        output=json.dumps(r,sort_keys=True)
        for forbidden in ("synthetic_player",TEST_ACCOUNT,
                          "Iceblaster","Nightblade",records[0]["message_id"],
                          WEBHOOK):
            self.assertNotIn(forbidden,output)

    def test_source_webhook_pin_is_not_server_trade_authority(self):
        a=build_record(fake_message(1),expected_webhook_id=WEBHOOK)
        self.assertTrue(a["webhook_source_pinned"])
        r=review([a])
        self.assertEqual(r["locallyPinnedWebhookIdClaims"],1)
        self.assertEqual(r["historicalSelfReportedCompletedClaims"],1)
        self.deny(r)

    def test_duplicate_webhook_delivery_is_not_another_trade(self):
        a,b,_=self.fixture_records()
        r=review([a,a,b,a])
        self.assertEqual(r["distinctArchivedWebhookMessages"],2)
        self.assertEqual(r["identicalMessageRedeliveries"],2)
        self.assertEqual(r["historicalSelfReportedCompletedClaims"],1)
        self.deny(r)

    def test_mutated_duplicate_is_rejected(self):
        a,_,_=self.fixture_records()
        changed=deepcopy(a)
        changed["claimed_trade"]["reported_listed_gain"]="9000"
        r=review([a,changed])
        self.assertEqual(r["status"],"BLOCKED")
        self.assertEqual(r["reason"],"DUPLICATE_DISCORD_RECEIPT_MUTATED")
        self.deny(r)

    def test_forged_learning_settlement_and_profile_fields_block(self):
        a,_,_=self.fixture_records()
        for field,value in (
            ("completed_trade_verified",True),
            ("learning_eligible",True),
            ("authorizes_accept",True),
            ("authorizes_trade",True),
            ("server_settlement","CONFIRMED"),
            ("may_report_profit",True),
            ("webhook_source_pinned","YES")
        ):
            with self.subTest(field=field):
                payload=deepcopy(a)
                payload[field]=value
                r=review([payload])
                self.assertEqual(r["status"],"BLOCKED")
                self.deny(r)
        for key,value in (
            ("username","real_name"), ("bot_token","SECRET"),
            ("server_transaction_id","FAKE_SIGNED"),
            ("verified_profit",42),
        ):
            payload=deepcopy(a)
            payload[key]=value
            r=review([payload])
            self.assertEqual(r["status"],"BLOCKED")
            self.deny(r)

    def test_forged_alt_trading_details_cannot_enter_learner(self):
        _,alt,_=self.fixture_records()
        payload=deepcopy(alt)
        payload["claimed_trade"]={"fake":"fake"}
        r=review([payload])
        self.assertEqual(r["reason"],"TEST_ACCOUNT_DATA_MUST_NOT_REACH_LEARNER")
        self.deny(r)

    def test_discord_future_event_draft_covers_different_behavior_not_one_gift(self):
        a,alt,other=self.fixture_records()
        events=[
            event(1,1,"MAIN_REQUEST_PENDING"),
            event(1,2,"PARTNER_NO_RESPONSE_TIMEOUT"),
            event(2,1,"MAIN_REQUEST_PENDING"),
            event(2,2,"PARTNER_DECLINED"),
            event(3,1,"MAIN_REQUEST_PENDING"),
            event(3,2,"PARTNER_REQUEST_ACCEPTED"),
            event(3,3,"PARTNER_OFFER_REVISION",1),
            event(3,4,"CHAT_AMBIGUOUS",1),
            event(3,5,"PARTNER_CANCELLED",1),
            event(4,1,"MAIN_REQUEST_PENDING"),
            event(4,2,"PARTNER_REQUEST_ACCEPTED"),
            event(4,3,"PARTNER_ACCEPT_INDICATOR"),
            event(4,4,"CLIENT_WINDOW_CLOSED_UNKNOWN"),
        ]
        r=review([a,alt,other],synthetic_future_webhook_events=events)
        self.assertEqual(r["status"],"DISCORD_ARCHIVE_TO_S2_EVIDENCE_RESEARCH_ONLY",r)
        self.assertEqual(r["syntheticFutureResponseEpisodesTested"],4)
        self.assertIn("UNANSWERED_NOT_DECLINED",r["syntheticFutureReactionClasses"])
        self.assertIn("EXPLICIT_PARTNER_DECLINE",r["syntheticFutureReactionClasses"])
        self.assertIn("PARTNER_CANCEL_RECORDED_NOT_DECLINE",r["syntheticFutureReactionClasses"])
        self.assertIn("CLOSED_UNKNOWN_NO_SERVER_SETTLEMENT",r["syntheticFutureReactionClasses"])
        self.assertEqual(r["futureWebhookOutcomeEventsActuallyCaptured"],0)
        self.deny(r)

    def test_future_event_cannot_claim_real_discord_stream_exists(self):
        a,_,_=self.fixture_records()
        mutated=event(1,1,"MAIN_REQUEST_PENDING")
        mutated["scope"]="REAL_DISCORD_ARCHIVE"
        r=review([a],synthetic_future_webhook_events=[mutated])
        self.assertEqual(r["status"],"BLOCKED")
        self.assertEqual(r["reason"],"FUTURE_DISCORD_EVENT_CONTRACT_INVALID")
        self.deny(r)
        mutated=event(1,1,"MAIN_REQUEST_PENDING")
        mutated["completed"]=True
        r=review([a],synthetic_future_webhook_events=[mutated])
        self.assertEqual(r["status"],"BLOCKED")
        self.deny(r)

    def test_bad_offer_revision_sequence_does_not_train(self):
        a,_,_=self.fixture_records()
        events=[event(1,1,"MAIN_REQUEST_PENDING"),event(1,2,"PARTNER_REQUEST_ACCEPTED"),
                event(1,3,"PARTNER_OFFER_REVISION",1),event(1,4,"PARTNER_ACCEPT_INDICATOR",0)]
        r=review([a],synthetic_future_webhook_events=events)
        self.assertEqual(r["status"],"BLOCKED")
        self.assertEqual(r["reason"],"UNVERIFIED_RESPONSE_SEQUENCE_INVALID")
        self.deny(r)

    def test_wrong_channel_webhook_message_id_and_schema_block(self):
        a,_,_=self.fixture_records()
        for field,value in (
            ("channel_id","00000000000000000"),
            ("source_webhook_id","FAKE"),
            ("message_id","X"),
            ("schema","mm2-discord-private-evidence-ledger-v2"),
            ("source","SERVER_SIGNED_TRUTH"),
            ("classification","ACTUAL_VERIFIED_SETTLEMENT"),
        ):
            with self.subTest(field=field):
                payload=deepcopy(a)
                payload[field]=value
                r=review([payload])
                self.assertEqual(r["status"],"BLOCKED")
                self.deny(r)

    def test_seeded_many_historical_receipts_stay_research_only(self):
        rng=random.Random(277)
        data=[]
        for i in range(160):
            m=fake_message(200+i)
            if rng.randrange(4)==0:
                m["embeds"][0]["fields"][0]["value"]=TEST_ACCOUNT
            data.append(build_record(m,expected_webhook_id=WEBHOOK))
        r=review(data)
        self.assertEqual(r["status"],"DISCORD_ARCHIVE_TO_S2_EVIDENCE_RESEARCH_ONLY")
        self.assertEqual(r["distinctArchivedWebhookMessages"],160)
        self.assertEqual(r["verifiedCompletedTradesForLearning"],0)
        self.deny(r)

if __name__ == "__main__":
    unittest.main()
