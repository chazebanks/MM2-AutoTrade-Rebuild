"""Five DIFFERENT System2 major-capability gates, all using existing modules.

Run each class independently. These are synthetic/offline integration regressions,
NOT five repeated real-world ALT gifts and NOT five deployed live features.
No bot tokens, Discord fetch, player identity, live prices or final Accept.
Each gate records a distinct failure mode plus an explicit unresolved
production prerequisite that must not be misrepresented as completed.
"""
from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path
import unittest

from scripts.discord_private_history_import import build_record
from scripts.discord_history_embed_audit import TEST_ACCOUNT
from pdiddler.ci.test_discord_learning_evidence_bridge import fake_message, event
from pdiddler.ci.test_multi_axis_strategy_stress_lab import (
    MultipleRealSystem2ResearchAxes, P
)
from pdiddler.ci.test_market_inventory_revision_gate import (
    MarketInventoryRevisionTests, pages
)
from pdiddler.system2.discord_learning_evidence_bridge import review as discord_review
from pdiddler.system2.counterparty_response_learning_lab import (
    replay, EVENT_SCHEMA
)

ROOT=Path(__file__).resolve().parents[2]
FIXTURE_METHOD="test_six_genuinely_distinct_research_groups_in_one_batch"


def research_fixture():
    fixture=MultipleRealSystem2ResearchAxes(FIXTURE_METHOD)
    fixture.setUp()
    return fixture


def revision_fixture():
    fixture=MarketInventoryRevisionTests(
        "test_same_full_census_and_same_offer_revision_is_research_only"
    )
    fixture.setUp()
    return fixture


def assert_no_live_authority(test, r):
    for field in ("authorizesOffer","authorizesTrade","authorizesAccept",
                  "serverCompletionProven"):
        test.assertIs(r[field],False,field)


class Gate1DiscordFeedback(unittest.TestCase):
    """The EXISTING Discord private importer, not a duplicate learner."""

    def test_historical_claim_alt_and_quarantine_remain_nontraining(self):
        claimed=build_record(fake_message(101))
        alt=build_record(fake_message(102,trader=TEST_ACCOUNT))
        malformed=build_record(fake_message(103,gave="Example x2 - 20"))
        r=discord_review([claimed,alt,malformed,deepcopy(claimed)])
        self.assertEqual(r["status"],"DISCORD_ARCHIVE_TO_S2_EVIDENCE_RESEARCH_ONLY")
        self.assertEqual(r["distinctArchivedWebhookMessages"],3)
        self.assertEqual(r["identicalMessageRedeliveries"],1)
        self.assertEqual(r["historicalSelfReportedCompletedClaims"],1)
        self.assertEqual(r["excludedExactTestAccountReceipts"],1)
        self.assertEqual(r["quarantinedMalformedOrAmbiguousReceipts"],1)
        self.assertEqual(r["verifiedCompletedTradesForLearning"],0)
        self.assertIs(r["mayUseForStrategyLearning"],False)
        self.assertIs(r["mayLearnProfitFromHistoricalSelfReports"],False)
        self.assertIs(r["actualDiscordNetworkRead"],False)
        self.assertIs(r["actualDiscordRejectionEventPipelineImplemented"],False)
        output=json.dumps(r)
        for private in (TEST_ACCOUNT,claimed["message_id"],claimed["source_webhook_id"]):
            self.assertNotIn(private,output)
        assert_no_live_authority(self,r)

    def test_false_webhook_settlement_and_mutated_delivery_are_blocked(self):
        claimed=build_record(fake_message(104))
        fake=deepcopy(claimed)
        fake["completed_trade_verified"]=True
        r=discord_review([fake])
        self.assertEqual(r["status"],"BLOCKED")
        self.assertEqual(r["reason"],"HISTORICAL_UNVERIFIED_AUTHORITY_FORGERY")
        fake=deepcopy(claimed)
        fake["claimed_trade"]["reported_listed_gain"]="999999"
        r=discord_review([claimed,fake])
        self.assertEqual(r["status"],"BLOCKED")
        self.assertEqual(r["reason"],"DUPLICATE_DISCORD_RECEIPT_MUTATED")
        assert_no_live_authority(self,r)


class Gate2CounterpartyBehavior(unittest.TestCase):
    """Censored no-reply != decline, revision changes, and chat attribution."""

    def test_diverse_discord_event_proposal_not_real_learning(self):
        claimed=build_record(fake_message(120))
        events=[
            event(1,1,"MAIN_REQUEST_PENDING"), event(1,2,"PARTNER_NO_RESPONSE_TIMEOUT"),
            event(2,1,"MAIN_REQUEST_PENDING"), event(2,2,"PARTNER_DECLINED"),
            event(3,1,"MAIN_REQUEST_PENDING"),
            event(3,2,"PARTNER_REQUEST_ACCEPTED"),
            event(3,3,"CHAT_AMBIGUOUS"),
            event(3,4,"PARTNER_OFFER_REVISION",1),
            event(3,5,"PARTNER_ACCEPT_INDICATOR",1),
            event(3,6,"PARTNER_OFFER_REVISION",2),
            event(3,7,"CHAT_OTHER_CONVERSATION",2),
            event(3,8,"PARTNER_CANCELLED",2),
            event(4,1,"MAIN_REQUEST_PENDING"),
            event(4,2,"PARTNER_REQUEST_ACCEPTED"),
            event(4,3,"PARTNER_ACCEPT_INDICATOR"),
            event(4,4,"MAIN_ACCEPT_INDICATOR"),
            event(4,5,"CLIENT_WINDOW_CLOSED_UNKNOWN"),
        ]
        r=discord_review([claimed],synthetic_future_webhook_events=events)
        self.assertEqual(r["status"],"DISCORD_ARCHIVE_TO_S2_EVIDENCE_RESEARCH_ONLY",r)
        self.assertEqual(r["syntheticFutureResponseEpisodesTested"],4)
        self.assertEqual(r["futureWebhookOutcomeEventsActuallyCaptured"],0)
        self.assertFalse(r["mayUseForStrategyLearning"])
        self.assertFalse(r["actualDiscordRejectionEventPipelineImplemented"])
        self.assertEqual(set(r["syntheticFutureReactionClasses"]),{
            "UNANSWERED_NOT_DECLINED","EXPLICIT_PARTNER_DECLINE",
            "PARTNER_CANCEL_RECORDED_NOT_DECLINE",
            "CLOSED_UNKNOWN_NO_SERVER_SETTLEMENT",
        })
        self.assertFalse(r["learnedPartnerPersonality"] if "learnedPartnerPersonality" in r else False)
        assert_no_live_authority(self,r)

    def test_accept_indicators_are_invalidated_on_new_offer_revision(self):
        def e(seq,kind,rev=0):
            return {"schema":EVENT_SCHEMA,"episode":1,"seq":seq,"kind":kind,
                    "revision":rev,"scope":"SYNTHETIC_MAIN_PARTNER_ONLY"}
        events=[
            e(1,"MAIN_REQUEST_PENDING"),e(2,"PARTNER_REQUEST_ACCEPTED"),
            e(3,"PARTNER_ACCEPT_INDICATOR"),
            e(4,"MAIN_ACCEPT_INDICATOR"),
            e(5,"PARTNER_OFFER_REVISION",1),
            e(6,"CHAT_DIRECT_CLIENT_ATTRIBUTED",1),
        ]
        r=replay(events)
        self.assertEqual(r["status"],"OFFLINE_DIFFERENT_BEHAVIOR_TRAJECTORIES_REPLAYED")
        self.assertEqual(r["currentRevisionAcceptanceIndicators"],0)
        self.assertEqual(r["everObservedPartnerAcceptanceIndicators"],1)
        self.assertEqual(r["changedOfferRevisions"],1)
        self.assertIs(r["learnedPartnerPersonality"],False)
        self.assertIs(r["mayUseForStrategyLearning"],False)
        assert_no_live_authority(self,r)
        events[-1]["revision"]=0
        self.assertEqual(replay(events)["status"],"BLOCKED")


class Gate3BilateralAttractiveness(unittest.TestCase):
    """New integration: partner shortlist COVERS each receive-side candidate?"""

    def test_paper_gain_is_not_partner_inventory_or_consent(self):
        f=research_fixture()
        r=f.run_review()
        self.assertEqual(r["status"],"OFFLINE_MULTIPLE_SYSTEM2_STRATEGY_FEATURES_REVIEWED",r)
        self.assertEqual(r["distinctGrowthRoutesCompared"],4)
        self.assertEqual(r["syntheticAlternativesNotInDeclaredPartnerShortlist"],3)
        rows=r["alternatives"]
        self.assertEqual(rows[0]["listedDelta"],5)
        self.assertEqual(rows[0]["syntheticPartnerIncomingCoverage"],
                         "NOT_IN_SYNTHETIC_PARTNER_SHORTLIST")
        self.assertEqual(rows[1]["syntheticPartnerIncomingCoverage"],
                         "COVERED_BY_UNVERIFIED_SYNTHETIC_SHORTLIST")
        self.assertTrue(rows[1]["hypotheticalTargetReceived"])
        self.assertIs(rows[1]["realPartnerOwnershipOrConsentProven"],False)
        self.assertIs(rows[1]["actionableCandidate"],False)
        self.assertFalse(r["realTradeOfferRankingAvailable"])
        assert_no_live_authority(self,r)

    def test_change_partner_hypothetical_inventory_changes_coverage_not_approval(self):
        f=research_fixture()
        before=f.run_review()
        f.partner=P([("test_key_105",1)])
        after=f.run_review()
        self.assertEqual(after["status"],"OFFLINE_MULTIPLE_SYSTEM2_STRATEGY_FEATURES_REVIEWED")
        self.assertEqual(before["alternatives"][0]["syntheticPartnerIncomingCoverage"],
                         "NOT_IN_SYNTHETIC_PARTNER_SHORTLIST")
        self.assertEqual(after["alternatives"][0]["syntheticPartnerIncomingCoverage"],
                         "COVERED_BY_UNVERIFIED_SYNTHETIC_SHORTLIST")
        self.assertEqual(after["alternatives"][1]["syntheticPartnerIncomingCoverage"],
                         "NOT_IN_SYNTHETIC_PARTNER_SHORTLIST")
        self.assertFalse(after["partnerAcceptanceStillUnknown"] is False)
        self.assertIs(after["counterpartyConsentProven"],False)
        assert_no_live_authority(self,after)


class Gate4GingerscopeGrowth(unittest.TestCase):
    """Multiple strategies, not repeated real transfers or fabricated fills."""

    def test_compounding_vs_loss_path_vs_non_linear_stack(self):
        f=research_fixture()
        r=f.run_review()
        self.assertEqual(r["status"],"OFFLINE_MULTIPLE_SYSTEM2_STRATEGY_FEATURES_REVIEWED",r)
        routes=r["hypotheticalPaths"]
        self.assertEqual(len(routes),4)
        self.assertGreater(routes[0]["paperListedGrowth"],0)
        self.assertGreater(routes[1]["paperListedGrowth"],0)
        self.assertEqual(routes[2]["status"],"BLOCKED_LOSS_POLICY")
        self.assertIs(routes[3]["stackPriceUncertain"],True)
        self.assertEqual(r["riskBlockedPaths"],1)
        self.assertEqual(r["untrustedStackPaths"],1)
        self.assertEqual(r["verifiedRealOutcomeRowsForTraining"],0)
        self.assertFalse(r["marketPricesApprovedForExecution"])
        assert_no_live_authority(self,r)

    def test_duplicate_growth_route_cannot_be_counted_as_distinct_strategy(self):
        f=research_fixture()
        r=f.run_review(paths=[f.paths[0],deepcopy(f.paths[0])])
        self.assertEqual(r["status"],"BLOCKED")
        self.assertEqual(r["reason"],"DUPLICATE_GROWTH_ROUTE_NOT_DISTINCT_EVIDENCE")
        assert_no_live_authority(self,r)


class Gate5FreshnessRiskAndAcceptBoundary(unittest.TestCase):
    """A different layer: revision, source, budget and final-Accept authority."""

    def test_new_offer_revision_invalidates_previous_strategy(self):
        f=revision_fixture()
        old=f.baseline()
        f.advance()
        f.binding["offerRevision"]=f.binding["offerRevision"]+1
        r=f.compare(old)
        self.assertEqual(r["status"],"INVALIDATED")
        self.assertIn("OFFER_REVISION_CHANGED",r["invalidationReasons"])
        self.assertFalse(r["researchDecisionReusable"])
        self.assertFalse(r["mayUseForLiveStrategy"])
        assert_no_live_authority(self,r)

    def test_same_offer_new_partner_or_publisher_invalidates(self):
        f=revision_fixture()
        old=f.baseline()
        f.advance()
        f.binding["partnerUserId"]+=1
        r=f.compare(old)
        self.assertEqual(r["status"],"INVALIDATED")
        self.assertIn("SERVER_PARTNER_OR_TRADE_LEASE_CHANGED",r["invalidationReasons"])
        f=revision_fixture()
        old=f.baseline()
        f.advance()
        f.web=pages(publisher="2026-11-14T00:59:00.000Z",
                    fetched="2026-11-14T01:15:48.000Z")
        r=f.compare(old)
        self.assertEqual(r["status"],"INVALIDATED")
        self.assertFalse(r["marketSourceUsableForLiveOffer"])
        assert_no_live_authority(self,r)

    def test_risk_budget_disabled_and_public_auto_accept_never_granted(self):
        p=json.loads((ROOT/"pdiddler/strategy/growth_policy.json").read_text())
        self.assertIs(p["deploymentAuthorized"],False)
        self.assertIs(p["autonomousLossTradesAuthorized"],False)
        self.assertEqual(p["riskBudget"]["approvalStatus"],"NOT_SPECIFIED_NOT_APPROVED")
        for field in ("maxLossPerTrade","maxCumulativeLoss",
                      "maxLossFractionPerTrade","maximumFrequency"):
            self.assertIsNone(p["riskBudget"][field])
        f=research_fixture()
        r=f.run_review()
        self.assertEqual(r["status"],"OFFLINE_MULTIPLE_SYSTEM2_STRATEGY_FEATURES_REVIEWED")
        self.assertEqual(r["finalAcceptScope"],
                         "EXACT_MAIN_ALT_SUPERVISED_ONLY_SEPARATE_POLICY")
        self.assertIs(r["publicFinalAcceptAuthorized"],False)
        self.assertIs(r["authorizesAccept"],False)
        self.assertIs(r["lossBudgetApproved"],False)
        assert_no_live_authority(self,r)


if __name__=="__main__":
    unittest.main()
