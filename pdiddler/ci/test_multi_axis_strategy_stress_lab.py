"""System2 DIFFERENT strategic feature tests using original 189-row fixture.

Not a second round of five identical ALT gifts: these cover two-sided value,
partner willingness, concentration, 4-slot stacks, loss policy, alternative
Gingerscope routes, chat attribution and censored outcome evidence.
"""
from __future__ import annotations

from copy import deepcopy
import unittest
from unittest.mock import patch

from pdiddler.ci.test_market_research_reader import data
from pdiddler.ci.test_client_inventory_shadow import _env
from pdiddler.system2.client_inventory_shadow import evaluate as census
from pdiddler.system2.trade_scenario_lab import SIMULATION_KIND
from pdiddler.system2.counterparty_response_learning_lab import EVENT_SCHEMA
from pdiddler.system2 import multi_axis_strategy_stress_lab as multi


def T(out,inc):
    return {
        "kind":SIMULATION_KIND,
        "outgoingSlots":[{"rawGameKey":k,"quantity":q} for k,q in out],
        "incomingSlots":[{"rawGameKey":k,"quantity":q} for k,q in inc],
    }

def P(items):
    return {
        "kind":"SYNTHETIC_OFFLINE_COUNTERPARTY_ENUMERATION",
        "ownShortlist":["test_key_100"],
        "counterparty":{
            "kind":"SYNTHETIC_UNVERIFIED_COUNTERPARTY",
            "items":[{"rawGameKey":k,"quantity":q} for k,q in items],
            "ownershipProof":"UNKNOWN",
        },
        "maxDisplay":10,
    }

def E(ep,seq,kind,revision=0):
    return {
        "schema":EVENT_SCHEMA,"scope":"SYNTHETIC_MAIN_PARTNER_ONLY",
        "episode":ep,"seq":seq,"kind":kind,"revision":revision
    }


class MultipleRealSystem2ResearchAxes(unittest.TestCase):
    def setUp(self):
        self.clock="2026-11-14T01:15:40.000Z"
        self.market=data()
        self.market["captureWindowUTC"]={"exportedAt":"2026-11-14T00:28:09.127Z"}
        env=_env(self.market,quantities={"test_key_100":1,"Celestial":1,"Gingerscope":1},
                 extras={"CommonKnife":1})
        self.shadow=census(self.market,env,evaluated_at_utc=self.clock)
        self.assertEqual(self.shadow["status"],"RESEARCH_CLIENT_INVENTORY_SHADOW_READY")
        self.alternatives=[
            T([("test_key_100",1)],[("test_key_105",1)]), # small +5 compounding option
            T([("Celestial",1)],[("Gingerscope",1)]),     # target hypothesis
            T([("test_key_100",1)],[("test_key_90",1)]),   # forbidden listed loss
            T([("Celestial",1)],[("test_key_100",20)]),   # non-linear stack
        ]
        self.paths=[
            [
                T([("test_key_100",1)],[("test_key_105",1)]),
                T([("test_key_105",1)],[("test_key_110",1)]),
                T([("test_key_110",1)],[("test_key_120",1)]),
            ],
            [
                T([("test_key_100",1)],[("test_key_110",1)]),
                T([("test_key_110",1)],[("test_key_115",1)]),
                T([("test_key_115",1)],[("test_key_125",1)]),
            ],
            [
                T([("test_key_100",1)],[("test_key_90",1)]),
                T([("test_key_90",1)],[("test_key_130",1)]),
            ],
            [
                T([("Celestial",1)],[("test_key_100",20)]),
                T([("test_key_100",20)],[("Gingerscope",1)]),
            ],
        ]
        self.partner=P([("Gingerscope",1)])
        self.behaviors=[
            E(1,1,"MAIN_REQUEST_PENDING"),E(1,2,"PARTNER_DECLINED"),
            E(2,1,"MAIN_REQUEST_PENDING"),E(2,2,"PARTNER_NO_RESPONSE_TIMEOUT"),
            E(3,1,"MAIN_REQUEST_PENDING"),E(3,2,"PARTNER_REQUEST_ACCEPTED"),
            E(3,3,"PARTNER_OFFER_REVISION",1),
            E(3,4,"CHAT_AMBIGUOUS",1),
            E(3,5,"PARTNER_ACCEPT_INDICATOR",1),
            E(3,6,"MAIN_ACCEPT_INDICATOR",1),
            E(3,7,"CLIENT_WINDOW_CLOSED_UNKNOWN",1),
        ]

    def run_review(self,alternatives=None,paths=None,partner=None,behaviors=None):
        return multi.evaluate_batch(
            self.market,self.shadow,
            self.alternatives if alternatives is None else alternatives,
            self.paths if paths is None else paths,
            self.partner if partner is None else partner,
            self.behaviors if behaviors is None else behaviors,
            evaluated_at_utc=self.clock
        )

    def check_never_live(self,receipt):
        for k in ("authorizesOffer","authorizesTrade","authorizesAccept",
                  "publicFinalAcceptAuthorized","serverCompletionProven",
                  "mayReportProfit","maySendDiscordWebhook",
                  "mayUseForStrategyLearning","realStrategyLearningEnabled",
                  "sourceCurrentPublisherAuthenticated","counterpartyConsentProven",
                  "lossBudgetApproved"):
            self.assertIs(receipt[k],False,k)
        self.assertIsNone(receipt["acceptanceProbability"])
        self.assertEqual(receipt["tradeOutcome"],"UNKNOWN")
        self.assertEqual(receipt["finalAcceptScope"],
                         "EXACT_MAIN_ALT_SUPERVISED_ONLY_SEPARATE_POLICY")

    def test_six_genuinely_distinct_research_groups_in_one_batch(self):
        r=self.run_review()
        self.assertEqual(r["status"],"OFFLINE_MULTIPLE_SYSTEM2_STRATEGY_FEATURES_REVIEWED",r)
        self.assertEqual(r["distinctFeatureGroups"],6)
        self.assertEqual(r["distinctGrowthRoutesCompared"],4)
        self.assertEqual(r["syntheticReactionEpisodes"],3)
        self.assertGreater(r["syntheticPartnerPairsConsidered"],0)
        self.assertEqual(r["playerResponseOutcomeDistribution"],{
            "EXPLICIT_PARTNER_DECLINE":1,
            "UNANSWERED_NOT_DECLINED":1,
            "CLOSED_UNKNOWN_NO_SERVER_SETTLEMENT":1,
        })
        self.assertEqual(r["chatAmbiguousMessages"],1)
        self.assertTrue(r["partnerAcceptanceStillUnknown"])
        self.assertEqual(r["verifiedRealOutcomeRowsForTraining"],0)
        self.check_never_live(r)

    def test_plus_five_and_demand_warning_are_not_fake_acceptance_odds(self):
        r=self.run_review()
        choices=r["alternatives"]
        self.assertEqual(choices[0]["listedDelta"],5)
        self.assertIsNone(r["acceptanceProbability"])
        self.assertTrue(choices[0]["requiresVerifiedPartnerAppeal"])
        self.assertTrue(r["researchAttentionOrderIsNotAnOfferRanking"])
        self.assertFalse(r["realTradeOfferRankingAvailable"])

    def test_target_gscope_never_outgoing_even_if_hypothetical_incoming(self):
        r=self.run_review()
        self.assertTrue(any("GINGERSCOPE_HYPOTHETICALLY_INCOMING_NOT_ACQUIRED"
                            in x["warnings"] for x in r["alternatives"]))
        self.assertTrue(any(x["hypotheticalTargetReceived"] for x in r["alternatives"]))
        self.assertEqual(r["verifiedRealOutcomeRowsForTraining"],0)

    def test_loss_policy_and_stacked_copy_warning_in_different_routes(self):
        r=self.run_review()
        self.assertEqual(r["riskBlockedPaths"],1)
        self.assertEqual(r["untrustedStackPaths"],1)
        self.assertEqual(r["hypotheticalPaths"][2]["status"],"BLOCKED_LOSS_POLICY")
        self.assertTrue(r["hypotheticalPaths"][3]["stackPriceUncertain"])
        self.assertGreater(r["hypotheticalPaths"][0]["paperListedGrowth"],0)
        self.check_never_live(r)

    def test_ignoring_counterparty_scope_cannot_be_passed_off_as_real(self):
        forged=deepcopy(self.partner)
        forged["counterparty"]["ownershipProof"]="SERVER_PROVEN"
        r=self.run_review(partner=forged)
        self.assertEqual(r["status"],"BLOCKED")
        self.assertEqual(r["reason"],"SYNTHETIC_PARTNER_SCOPE_NOT_ADMITTED")
        self.check_never_live(r)

    def test_identical_path_is_not_new_strategic_coverage(self):
        r=self.run_review(paths=[self.paths[0],deepcopy(self.paths[0])])
        self.assertEqual(r["status"],"BLOCKED")
        self.assertEqual(r["reason"],"DUPLICATE_GROWTH_ROUTE_NOT_DISTINCT_EVIDENCE")
        self.check_never_live(r)

    def test_bad_chat_replay_not_learning(self):
        bad=self.behaviors + [E(3,7,"CHAT_DIRECT_CLIENT_ATTRIBUTED",1)]
        r=self.run_review(behaviors=bad)
        self.assertEqual(r["status"],"BLOCKED")
        self.assertEqual(r["reason"],"SYNTHETIC_REACTION_REPLAY_NOT_ADMITTED")
        self.check_never_live(r)

    def test_no_auto_accept_even_given_all_synthetic_positive_looking_paths(self):
        r=self.run_review(paths=[self.paths[0],self.paths[1]])
        self.assertEqual(r["status"],"OFFLINE_MULTIPLE_SYSTEM2_STRATEGY_FEATURES_REVIEWED")
        self.check_never_live(r)

    def test_changed_historical_source_or_stale_inventory_blocks_batch(self):
        modified=deepcopy(self.market)
        modified["records"]=modified["records"][:-1]
        r=multi.evaluate_batch(modified,self.shadow,self.alternatives,self.paths,
                               self.partner,self.behaviors,evaluated_at_utc=self.clock)
        self.assertEqual(r["status"],"BLOCKED")
        self.check_never_live(r)
        r=multi.evaluate_batch(self.market,self.shadow,self.alternatives,self.paths,
                               self.partner,self.behaviors,
                               evaluated_at_utc="2026-11-15T04:11:20.000Z")
        self.assertEqual(r["status"],"BLOCKED")
        self.check_never_live(r)

    def test_source_status_spoofing_rejected(self):
        with patch("pdiddler.system2.multi_axis_strategy_stress_lab.compare",
                   return_value={"status":"LIVE_ACCEPT_AUTHORIZED","authorizesAccept":True}):
            r=self.run_review()
            self.assertEqual(r["status"],"BLOCKED")
            self.check_never_live(r)
        with patch("pdiddler.system2.multi_axis_strategy_stress_lab.simulate",
                   return_value={"status":"LIVE_TRADE","authorizesTrade":True}):
            r=self.run_review(paths=self.paths[:2])
            self.assertEqual(r["status"],"BLOCKED")
            self.check_never_live(r)

if __name__=="__main__":
    unittest.main()
