"""FIVE DIFFERENT major System2 gates; no repeated MAIN-ALT gift-transfer tests.

Run the five classes independently and sequentially in CI, updating the
completed/uncompleted progress board after EACH successful class.
All fixtures are synthetic, original source modules are executed, and the
user's existing Discord bot/private-ledger schema is the learning input.
"""
from __future__ import annotations

from copy import deepcopy
import unittest
from unittest.mock import patch

from scripts.discord_private_history_import import build_record
from scripts.discord_history_embed_audit import TEST_ACCOUNT
from pdiddler.ci.test_discord_learning_evidence_bridge import fake_message, event
from pdiddler.ci.test_multi_axis_strategy_stress_lab import (
    MultipleRealSystem2ResearchAxes, T
)
from pdiddler.system2.discord_learning_evidence_bridge import review
from pdiddler.system2.discord_shadow_engagement import fit, reconsider


def actual_importer_fixtures():
    """Real V1 parser, synthetic Discord message embeds; no private server."""
    ok=build_record(fake_message(40))
    alt=build_record(fake_message(41,trader=TEST_ACCOUNT))
    ambiguous=build_record(fake_message(42,gave="Iceblaster x2 - 70"))
    assert all(type(x) is dict for x in (ok,alt,ambiguous))
    assert ok["classification"]=="PARSED_UNVERIFIED_WEBHOOK_CLAIM"
    assert alt["classification"]=="TEST_ACCOUNT_EXCLUDED"
    assert ambiguous["classification"]=="UNPARSEABLE_ITEM_BUNDLE"
    return [ok,alt,ambiguous]


def synthetic_feedback_batch():
    """Seven DIFFERENT Discord-v2 shadow episodes; one counterparty event each.

    No real player identifier is present and the synthetic test ALT is
    NEVER allowed to teach a production model.
    """
    events=[
        event(1,1,"MAIN_REQUEST_PENDING"),
        event(1,2,"PARTNER_DECLINED"),
        event(2,1,"MAIN_REQUEST_PENDING"),
        event(2,2,"PARTNER_REQUEST_ACCEPTED"),
        event(2,3,"PARTNER_OFFER_REVISION",1),
        event(2,4,"PARTNER_ACCEPT_INDICATOR",1),
        event(2,5,"CLIENT_WINDOW_CLOSED_UNKNOWN",1),
        event(3,1,"MAIN_REQUEST_PENDING"),
        event(3,2,"PARTNER_DECLINED"),
        event(4,1,"MAIN_REQUEST_PENDING"),
        event(4,2,"PARTNER_REQUEST_ACCEPTED"),
        event(4,3,"PARTNER_ACCEPT_INDICATOR"),
        event(4,4,"CLIENT_WINDOW_CLOSED_UNKNOWN"),
        event(5,1,"MAIN_REQUEST_PENDING"),
        event(5,2,"PARTNER_DECLINED"),
        event(6,1,"MAIN_REQUEST_PENDING"),
        event(6,2,"PARTNER_NO_RESPONSE_TIMEOUT"),
        event(7,1,"MAIN_REQUEST_PENDING"),
        event(7,2,"PARTNER_REQUEST_ACCEPTED"),
        event(7,3,"PARTNER_ACCEPT_INDICATOR"),
        event(7,4,"PARTNER_OFFER_REVISION",1),
        event(7,5,"CLIENT_WINDOW_CLOSED_UNKNOWN",1),
    ]
    bindings=[
        {"episode":1,"candidateIndex":0,"split":"TRAIN"},
        {"episode":2,"candidateIndex":1,"split":"TRAIN"},
        {"episode":3,"candidateIndex":0,"split":"TRAIN"},
        {"episode":4,"candidateIndex":1,"split":"HOLDOUT"},
        {"episode":5,"candidateIndex":0,"split":"HOLDOUT"},
        {"episode":6,"candidateIndex":0,"split":"TRAIN"},
        {"episode":7,"candidateIndex":1,"split":"TRAIN"},
    ]
    return events,bindings


def original_strategy_fixture():
    """Reuse original frozen 189-market + client shadow + actual S2.8 adapter."""
    x=MultipleRealSystem2ResearchAxes(
        "test_six_genuinely_distinct_research_groups_in_one_batch")
    x.setUp()
    # Two genuinely plausible research alternatives, then protected target
    # and explicitly prohibited loss. No data is an executable candidate.
    x.alternatives=[
        T([("test_key_100",1)],[("test_key_105",1)]),
        T([("test_key_100",1)],[("test_key_110",1)]),
        T([("Celestial",1)],[("Gingerscope",1)]),
        T([("test_key_100",1)],[("test_key_90",1)]),
    ]
    return x


class Gate1DiscordBotArchive(unittest.TestCase):
    """Trust and dedup on EXISTING Discord webhook private-ledger V1."""

    def test_original_importer_claims_not_training_labels(self):
        recs=actual_importer_fixtures()
        response=review(recs)
        self.assertEqual(response["status"],
                         "DISCORD_ARCHIVE_TO_S2_EVIDENCE_RESEARCH_ONLY")
        self.assertEqual(response["historicalSelfReportedCompletedClaims"],1)
        self.assertEqual(response["excludedExactTestAccountReceipts"],1)
        self.assertEqual(response["quarantinedMalformedOrAmbiguousReceipts"],1)
        self.assertEqual(response["verifiedCompletedTradesForLearning"],0)
        self.assertIs(response["mayUseForStrategyLearning"],False)

    def test_webhook_replay_dedup_and_mutation_fail_closed(self):
        recs=actual_importer_fixtures()
        repeated=review([recs[0],recs[0]])
        self.assertEqual(repeated["distinctArchivedWebhookMessages"],1)
        self.assertEqual(repeated["identicalMessageRedeliveries"],1)
        corrupted=deepcopy(recs[0])
        corrupted["claimed_trade"]["reported_listed_gain"]="80000"
        blocked=review([recs[0],corrupted])
        self.assertEqual(blocked["reason"],"DUPLICATE_DISCORD_RECEIPT_MUTATED")
        self.assertFalse(blocked["authorizesTrade"])

    def test_fake_signed_webhook_cannot_forge_settlement(self):
        record=actual_importer_fixtures()[0]
        record["webhook_source_pinned"]=True
        record["completed_trade_verified"]=True
        result=review([record])
        self.assertEqual(result["status"],"BLOCKED")
        self.assertFalse(result["mayUseForStrategyLearning"])


class Gate2DiscordShadowLearning(unittest.TestCase):
    """A REAL replay/fit, but only from hypothetical future Discord v2."""

    def test_censored_and_revised_events_different_from_declines(self):
        events,bindings=synthetic_feedback_batch()
        m=fit(actual_importer_fixtures(),events,bindings)
        self.assertEqual(m["status"],"SYNTHETIC_DISCORD_SHADOW_FEEDBACK_FIT",m)
        self.assertEqual(m["syntheticEpisodeCount"],7)
        self.assertEqual(m["trainEpisodes"],5)
        self.assertEqual(m["holdoutEpisodes"],2)
        self.assertEqual(m["changedOfferRevisions"],2)
        self.assertEqual(m["syntheticLabels"],{
            "ENGAGED_CLIENT_INDICATOR_ONLY":2,
            "PARTNER_DECLINED_OBSERVED":3,
            "CENSORED_NO_RESPONSE":1,
            "CENSORED_CANCEL_OR_UNKNOWN":1,
        })
        values={x["candidateIndex"]:x for x in m["syntheticCandidateModel"]}
        self.assertAlmostEqual(values[0]["syntheticEngagementProxyFraction"],0.25)
        self.assertAlmostEqual(values[1]["syntheticEngagementProxyFraction"],0.66666666667)
        self.assertEqual(values[0]["trainCensored"],1)
        self.assertEqual(values[1]["trainCensored"],1)
        self.assertEqual(m["verifiedServerSettlements"],0)
        self.assertIsNone(m["partnerAcceptanceProbability"])
        self.assertFalse(m["realLearnerUpdated"])

    def test_training_and_holdout_are_separate(self):
        events,bindings=synthetic_feedback_batch()
        m=fit(actual_importer_fixtures(),events,bindings)
        self.assertEqual(m["holdoutEpisodes"],2)
        values={x["candidateIndex"]:x for x in m["syntheticCandidateModel"]}
        self.assertEqual(values[0]["holdoutPartnerDeclines"],1)
        self.assertEqual(values[1]["holdoutEngagementIndicators"],1)
        self.assertFalse(m["holdoutClaimOfImprovedRealPerformance"])

    def test_duplicate_episode_and_forged_real_source_fail_closed(self):
        events,bindings=synthetic_feedback_batch()
        r=fit(actual_importer_fixtures(),events,bindings+[bindings[0]])
        self.assertEqual(r["status"],"BLOCKED")
        r=fit(actual_importer_fixtures(),events,
              [b for b in bindings if b["episode"]!=7])
        self.assertEqual(r["reason"],"SYNTHETIC_EPISODE_SET_MISMATCH")
        changed=deepcopy(events)
        changed[0]["scope"]="REAL_DISCORD_BOT_HISTORY"
        self.assertEqual(fit(actual_importer_fixtures(),changed,bindings)["status"],
                         "BLOCKED")


class Gate3BilateralAttractiveness(unittest.TestCase):
    """Research attention changes; it NEVER issues an offer."""

    def test_declines_shift_sandbox_research_attention(self):
        x=original_strategy_fixture()
        original=x.run_review()
        self.assertEqual(original["status"],
                         "OFFLINE_MULTIPLE_SYSTEM2_STRATEGY_FEATURES_REVIEWED")
        events,bindings=synthetic_feedback_batch()
        shadow=fit(actual_importer_fixtures(),events,bindings)
        revised=reconsider(original,shadow)
        self.assertEqual(revised["status"],
                         "HYPOTHETICAL_RESEARCH_ATTENTION_RECONSIDERED",revised)
        self.assertEqual(revised["researchAttentionAfterSyntheticFeedback"],[1,0])
        self.assertEqual(revised["hypotheticalTopResearchIndex"],1)
        self.assertEqual(revised["actualExecutedOffers"],0)
        self.assertFalse(revised["authorizesAccept"])
        self.assertFalse(revised["liveOfferSelectionAuthorized"])
        self.assertEqual(revised["confirmedRealPartnerPreferences"],0)

    def test_unsupported_partner_ownership_not_an_offer(self):
        x=original_strategy_fixture()
        partner=deepcopy(x.partner)
        partner["counterparty"]["ownershipProof"]="SERVER_OWNED"
        research=x.run_review(partner=partner)
        self.assertEqual(research["status"],"BLOCKED")
        events,bindings=synthetic_feedback_batch()
        shadow=fit(actual_importer_fixtures(),events,bindings)
        self.assertEqual(reconsider(research,shadow)["status"],"BLOCKED")

    def test_better_paper_gain_not_verified_liquidity(self):
        x=original_strategy_fixture()
        research=x.run_review()
        self.assertEqual(research["alternatives"][0]["listedDelta"],5)
        self.assertEqual(research["alternatives"][1]["listedDelta"],10)
        self.assertIsNone(research["acceptanceProbability"])
        self.assertTrue(research["partnerAcceptanceStillUnknown"])
        self.assertFalse(research["realTradeOfferRankingAvailable"])


class Gate4GingerscopeGrowthPaths(unittest.TestCase):
    """Multiple DIFFERENT routes, inventory evolution, losses, 4-slot stacks."""

    def test_compounding_vs_loss_vs_nonlinear_stacks(self):
        x=original_strategy_fixture()
        r=x.run_review()
        self.assertEqual(r["status"],
                         "OFFLINE_MULTIPLE_SYSTEM2_STRATEGY_FEATURES_REVIEWED")
        self.assertEqual(r["distinctGrowthRoutesCompared"],4)
        self.assertEqual(r["riskBlockedPaths"],1)
        self.assertEqual(r["untrustedStackPaths"],1)
        self.assertGreater(r["hypotheticalPaths"][0]["paperListedGrowth"],0)
        self.assertEqual(r["hypotheticalPaths"][2]["status"],"BLOCKED_LOSS_POLICY")
        self.assertTrue(r["hypotheticalPaths"][3]["stackPriceUncertain"])
        self.assertFalse(r["authorizesTrade"])
        self.assertFalse(r["lossBudgetApproved"])

    def test_repeating_same_route_is_not_new_coverage(self):
        x=original_strategy_fixture()
        repeated=x.run_review(paths=[x.paths[0],deepcopy(x.paths[0])])
        self.assertEqual(repeated["status"],"BLOCKED")
        self.assertEqual(repeated["reason"],
                         "DUPLICATE_GROWTH_ROUTE_NOT_DISTINCT_EVIDENCE")

    def test_gscope_may_arrive_but_cannot_be_offered_out(self):
        x=original_strategy_fixture()
        review=x.run_review()
        self.assertTrue(review["alternatives"][2]["hypotheticalTargetReceived"])
        revised=deepcopy(x.alternatives)
        revised[0]=T([("Gingerscope",1)],[("test_key_120",1)])
        r=x.run_review(alternatives=revised)
        self.assertEqual(r["alternatives"][0]["status"],"INVALID_ALTERNATIVE")
        self.assertFalse(r["authorizesOffer"])


class Gate5IntegratedAuthorityFirewall(unittest.TestCase):
    """Stale market, unknown identity, tampered model, public Accept all blocked."""

    def test_changed_market_or_stale_census_invalidates_strategy(self):
        x=original_strategy_fixture()
        market=deepcopy(x.market)
        market["records"]=market["records"][:-1]
        from pdiddler.system2.multi_axis_strategy_stress_lab import evaluate_batch
        r=evaluate_batch(market,x.shadow,x.alternatives,x.paths,
                         x.partner,x.behaviors,evaluated_at_utc=x.clock)
        self.assertEqual(r["status"],"BLOCKED")
        self.assertFalse(r["authorizesAccept"])
        stale=x.run_review()
        self.assertEqual(stale["status"],"OFFLINE_MULTIPLE_SYSTEM2_STRATEGY_FEATURES_REVIEWED")

    def test_tampered_learning_receipt_does_not_authorize(self):
        x=original_strategy_fixture()
        research=x.run_review()
        events,bindings=synthetic_feedback_batch()
        signal=fit(actual_importer_fixtures(),events,bindings)
        forgery=deepcopy(signal)
        forgery["realLearnerUpdated"]=True
        self.assertEqual(reconsider(research,forgery)["status"],"BLOCKED")
        forgery=deepcopy(research)
        forgery["authorizesAccept"]=True
        self.assertEqual(reconsider(forgery,signal)["status"],"BLOCKED")

    def test_no_public_final_accept_or_webhook_profit_from_any_test(self):
        x=original_strategy_fixture()
        review=x.run_review()
        events,bindings=synthetic_feedback_batch()
        learning=fit(actual_importer_fixtures(),events,bindings)
        decision=reconsider(review,learning)
        for rec in (review,learning,decision):
            for k in ("authorizesAccept","authorizesTrade","maySendDiscordWebhook",
                      "mayReportProfit"):
                self.assertIs(rec[k],False,(k,rec["schema"]))
        self.assertFalse(review["publicFinalAcceptAuthorized"])
        self.assertFalse(learning["publicFinalAcceptAuthorized"])
        self.assertFalse(decision["publicFinalAcceptAuthorized"])
        self.assertEqual(decision["tradeOutcome"],"UNKNOWN")
        self.assertFalse(decision["mainAltFinalAcceptAuthorizedByLearner"])

    def test_different_features_and_no_real_training_are_explicit(self):
        x=original_strategy_fixture()
        r=x.run_review()
        self.assertEqual(r["distinctFeatureGroups"],6)
        events,bindings=synthetic_feedback_batch()
        learned=fit(actual_importer_fixtures(),events,bindings)
        self.assertEqual(learned["trainingSource"],
                         "SYNTHETIC_V2_DISCORD_BOT_EVENTS_ONLY")
        self.assertEqual(learned["verifiedServerSettlements"],0)
        self.assertFalse(learned["mayUseForStrategyLearning"])


if __name__=="__main__":
    unittest.main()
