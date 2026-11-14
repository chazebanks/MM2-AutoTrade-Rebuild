"""S2.7: tests DIFFERENT player reactions and failure modes, not repeat gifts."""
import unittest
import random
from pdiddler.system2.counterparty_response_learning_lab import replay, DENIED

def E(ep,seq,kind,rev=0,**mutate):
    rec = {
        "schema":"SYNTHETIC_S2_RESPONSE_EVENT","episode":ep,"seq":seq,
        "kind":kind,"revision":rev,"scope":"SYNTHETIC_MAIN_PARTNER_ONLY",
    }
    rec.update(mutate)
    return rec

class DistinctCounterpartyBehaviors(unittest.TestCase):
    def assert_denied(self,r):
        self.assertFalse(r["authorizesAccept"])
        self.assertFalse(r["publicFinalAcceptAuthorized"])
        self.assertFalse(r["exactMainAltAutoAcceptAuthorizedByThisModule"])
        self.assertFalse(r["mayUseForStrategyLearning"])
        self.assertFalse(r["serverCompletionProven"])
        self.assertFalse(r["empiricalLiquidityProven"])
        self.assertFalse(r["learnedPartnerPersonality"])
        self.assertIsNone(r["acceptanceProbability"])
        self.assertEqual(r["tradeOutcome"],"UNKNOWN")
        self.assertEqual(r["verifiedRealSettlements"],0)
        self.assertFalse(r["maySendDiscordWebhook"])

    def test_multiple_genuinely_distinct_behavior_sequences(self):
        events = [
            E(1,1,"MAIN_REQUEST_PENDING"),
            E(1,2,"PARTNER_NO_RESPONSE_TIMEOUT"),
            E(2,1,"MAIN_REQUEST_PENDING"),
            E(2,2,"PARTNER_DECLINED"),
            E(3,1,"MAIN_REQUEST_PENDING"),
            E(3,2,"PARTNER_REQUEST_ACCEPTED"),
            E(3,3,"PARTNER_OFFER_REVISION",1),
            E(3,4,"CHAT_AMBIGUOUS",1),
            E(3,5,"PARTNER_CANCELLED",1),
            E(4,1,"MAIN_REQUEST_PENDING"),
            E(4,2,"PARTNER_REQUEST_ACCEPTED"),
            E(4,3,"CHAT_DIRECT_CLIENT_ATTRIBUTED"),
            E(4,4,"PARTNER_OFFER_REVISION",1),
            E(4,5,"PARTNER_ACCEPT_INDICATOR",1),
            E(4,6,"MAIN_ACCEPT_INDICATOR",1),
            E(4,7,"CLIENT_INVENTORY_DELTA_OBSERVED",1),
            E(4,8,"CLIENT_WINDOW_CLOSED_UNKNOWN",1),
            E(5,1,"MAIN_REQUEST_PENDING"),
            E(5,2,"PARTNER_REQUEST_ACCEPTED"),
            E(5,3,"CHAT_OTHER_CONVERSATION"),
            E(5,4,"MAIN_CANCELLED"),
            E(6,1,"MAIN_REQUEST_PENDING"),
            E(6,2,"PARTNER_REQUEST_ACCEPTED"),
            E(6,3,"PARTNER_ACCEPT_INDICATOR"),
            E(6,4,"PARTNER_OFFER_REVISION",1),
            E(6,5,"CHAT_DIRECT_CLIENT_ATTRIBUTED",1),
        ]
        result = replay(events)
        self.assertEqual(result["status"],"OFFLINE_DIFFERENT_BEHAVIOR_TRAJECTORIES_REPLAYED")
        self.assertEqual(result["distinctSyntheticEpisodes"],6)
        self.assertEqual(result["outcomeDistribution"],{
            "UNANSWERED_NOT_DECLINED":1,
            "EXPLICIT_PARTNER_DECLINE":1,
            "PARTNER_CANCEL_RECORDED_NOT_DECLINE":1,
            "CLOSED_UNKNOWN_NO_SERVER_SETTLEMENT":1,
            "MAIN_WITHDRAWAL_NOT_PARTNER_PREFERENCE":1,
            "IN_PROGRESS_CENSORED":1,
        })
        self.assertEqual(result["chatAmbiguousUnattributed"],1)
        self.assertEqual(result["chatOtherConversation"],1)
        self.assertEqual(result["chatDirectClientAttributed"],2)
        self.assertEqual(result["changedOfferRevisions"],3)
        self.assertEqual(result["everObservedPartnerAcceptanceIndicators"],2)
        self.assertEqual(result["currentRevisionAcceptanceIndicators"],1)
        self.assertEqual(result["clientOnlyInventoryDeltaNotes"],1)
        self.assert_denied(result)

    def test_changed_offer_invalidates_old_acceptance(self):
        result = replay([
            E(1,1,"MAIN_REQUEST_PENDING"),E(1,2,"PARTNER_REQUEST_ACCEPTED"),
            E(1,3,"PARTNER_ACCEPT_INDICATOR"),
            E(1,4,"PARTNER_OFFER_REVISION",1),
        ])
        self.assertEqual(result["currentRevisionAcceptanceIndicators"],0)
        self.assertEqual(result["everObservedPartnerAcceptanceIndicators"],1)
        self.assert_denied(result)

    def test_partner_reaccepts_new_revision(self):
        result = replay([
            E(1,1,"MAIN_REQUEST_PENDING"),E(1,2,"PARTNER_REQUEST_ACCEPTED"),
            E(1,3,"PARTNER_OFFER_REVISION",1),
            E(1,4,"PARTNER_ACCEPT_INDICATOR",1),
            E(1,5,"MAIN_ACCEPT_INDICATOR",1),
        ])
        self.assertEqual(result["currentRevisionAcceptanceIndicators"],1)
        self.assert_denied(result)

    def test_no_reply_not_decline(self):
        result=replay([E(1,1,"MAIN_REQUEST_PENDING"),E(1,2,"PARTNER_NO_RESPONSE_TIMEOUT")])
        self.assertEqual(result["outcomeDistribution"],{"UNANSWERED_NOT_DECLINED":1})

    def test_accept_then_close_still_unknown(self):
        result=replay([
            E(1,1,"MAIN_REQUEST_PENDING"),E(1,2,"PARTNER_REQUEST_ACCEPTED"),
            E(1,3,"PARTNER_ACCEPT_INDICATOR"),E(1,4,"MAIN_ACCEPT_INDICATOR"),
            E(1,5,"CLIENT_INVENTORY_DELTA_OBSERVED"),E(1,6,"CLIENT_WINDOW_CLOSED_UNKNOWN"),
        ])
        self.assertEqual(result["verifiedRealSettlements"],0)
        self.assert_denied(result)

    def test_invalid_sequences_fail_closed(self):
        bad = [
            [E(1,1,"PARTNER_DECLINED")],
            [E(1,1,"MAIN_REQUEST_PENDING",1)],
            [E(1,2,"MAIN_REQUEST_PENDING")],
            [E(1,1,"MAIN_REQUEST_PENDING"),E(1,1,"PARTNER_DECLINED")],
            [E(1,1,"MAIN_REQUEST_PENDING"),E(1,3,"PARTNER_DECLINED")],
            [E(1,1,"MAIN_REQUEST_PENDING"),E(1,2,"PARTNER_DECLINED"),
             E(1,3,"CHAT_DIRECT_CLIENT_ATTRIBUTED")],
            [E(1,1,"MAIN_REQUEST_PENDING"),E(1,2,"PARTNER_OFFER_REVISION",1)],
            [E(1,1,"MAIN_REQUEST_PENDING"),E(1,2,"PARTNER_REQUEST_ACCEPTED"),
             E(1,3,"PARTNER_OFFER_REVISION",2)],
            [E(1,1,"MAIN_REQUEST_PENDING"),E(1,2,"PARTNER_REQUEST_ACCEPTED"),
             E(1,3,"PARTNER_OFFER_REVISION",1),E(1,4,"CHAT_AMBIGUOUS",0)],
            [E(1,1,"MAIN_REQUEST_PENDING"),E(1,2,"PARTNER_REQUEST_ACCEPTED"),
             E(1,3,"MAIN_ACCEPT_INDICATOR")],
            [E(1,1,"MAIN_REQUEST_PENDING"),E(1,2,"PARTNER_REQUEST_ACCEPTED"),
             E(1,3,"PARTNER_NO_RESPONSE_TIMEOUT")],
            [E(1,1,"MAIN_REQUEST_PENDING"),E(1,2,"CLIENT_WINDOW_CLOSED_UNKNOWN")],
            [E(1,1,"MAIN_REQUEST_PENDING"),E(1,2,"PARTNER_REQUEST_ACCEPTED"),
             E(1,3,"CLIENT_WINDOW_CLOSED_UNKNOWN"),E(1,4,"CLIENT_INVENTORY_DELTA_OBSERVED")],
            [E(1,1,"MAIN_REQUEST_PENDING"),E(1,2,"NOT_AN_EVENT")],
            [E(1,1,"MAIN_REQUEST_PENDING",scope="REAL_PLAYER")],
            [E(1,1,"MAIN_REQUEST_PENDING",username="private")],
            [E(1,1,"MAIN_REQUEST_PENDING",seq=True)],
            [E(1,1,"MAIN_REQUEST_PENDING",episode=0)],
        ]
        for index,events in enumerate(bad):
            with self.subTest(index=index):
                result=replay(events)
                self.assertEqual(result["status"],"BLOCKED")
                self.assert_denied(result)

    def test_replay_episode_interleaving_and_bounds(self):
        events=[E(1,1,"MAIN_REQUEST_PENDING"),E(2,1,"MAIN_REQUEST_PENDING"),
                E(1,2,"PARTNER_DECLINED"),E(2,2,"PARTNER_NO_RESPONSE_TIMEOUT")]
        self.assertEqual(replay(events)["distinctSyntheticEpisodes"],2)
        self.assertEqual(replay([])["status"],"BLOCKED")
        self.assertEqual(replay(events*251)["status"],"BLOCKED")
        self.assertEqual(replay([E(i,1,"MAIN_REQUEST_PENDING") for i in range(1,34)])["status"],"BLOCKED")

    def test_fuzz_random_distinct_synthetic_sessions_fail_closed_on_replay(self):
        rng=random.Random(274)
        for _ in range(250):
            n=rng.randint(1,16)
            events=[]
            for ep in range(1,n+1):
                events.append(E(ep,1,"MAIN_REQUEST_PENDING"))
                events.append(E(ep,2,rng.choice([
                    "PARTNER_DECLINED","PARTNER_NO_RESPONSE_TIMEOUT",
                    "CHAT_AMBIGUOUS","PARTNER_REQUEST_ACCEPTED",
                ])))
            result=replay(events)
            self.assert_denied(result)
            self.assertEqual(result["distinctCounterpartyIdentitiesVerified"] if result["status"]!="BLOCKED" else 0,0)
            # Duplicated seq is not a new independent interaction.
            dup=events+[events[-1]]
            self.assertEqual(replay(dup)["status"],"BLOCKED")

if __name__=="__main__":
    unittest.main()
