"""System2 Part4: deterministic attractiveness evidence and hostile alternative tests."""
from __future__ import annotations
from copy import deepcopy
import unittest

from pdiddler.ci.test_market_research_reader import data
from pdiddler.ci.test_client_inventory_shadow import _env
from pdiddler.system2.client_inventory_shadow import evaluate
from pdiddler.system2 import attractiveness_evidence_lab as m
from pdiddler.system2.trade_scenario_lab import SIMULATION_KIND


def alt(out,inc):
    return {
        "kind": SIMULATION_KIND,
        "outgoingSlots":[{"rawGameKey":k,"quantity":q} for k,q in out],
        "incomingSlots":[{"rawGameKey":k,"quantity":q} for k,q in inc],
    }


class AttractivenessTests(unittest.TestCase):
    def setUp(self):
        self.market=data()
        self.evaluated_at="2026-11-14T01:15:40.000Z"
        self.market["captureWindowUTC"]={"exportedAt":"2026-11-14T00:28:09.127Z"}
        self.observe({"Celestial":2,"EmberbowChroma":6,"Gingerscope":1})
    def observe(self,own):
        snap=_env(self.market,quantities=own,extras={"CommonKnife":1})
        self.shadow=evaluate(self.market,snap,evaluated_at_utc="2026-11-14T01:15:40.000Z")
        self.assertEqual(self.shadow["status"],"RESEARCH_CLIENT_INVENTORY_SHADOW_READY",self.shadow)
    def compare(self,*options):
        return m.compare(self.market,self.shadow,list(options),evaluated_at_utc=self.evaluated_at)
    def test_two_alternatives_researched_without_offer_authority(self):
        x=self.compare(
            alt([("Celestial",1)],[("Gingerscope",1)]),
            alt([("EmberbowChroma",1)],[("Celestial",1),("Emberbow",1)]),
        )
        self.assertEqual(x["status"],"OFFLINE_ATTRACTIVENESS_EVIDENCE_COMPARISON_ONLY",x)
        self.assertEqual(x["nonLossResearchAlternatives"],1)
        self.assertEqual(x["lossBlockedAlternatives"],1)
        self.assertEqual(x["researchAttentionIndices"],[0])
        self.assertTrue(x["alternatives"][1]["hasNoLossAlternativeInBatch"])
        self.assertFalse(x["authorizesTrade"])
        self.assertIsNone(x["verifiedTradeAcceptanceProbability"])
    def test_target_not_claimed_acquired(self):
        x=self.compare(
            alt([("Celestial",1)],[("Gingerscope",1)]),
            alt([("Celestial",1)],[("EmberbowChroma",1)]),
        )
        self.assertIn("GINGERSCOPE_HYPOTHETICALLY_INCOMING_NOT_ACQUIRED",x["alternatives"][0]["evidenceWarnings"])
        self.assertFalse(x["mayUseForStrategyLearning"])
    def test_large_gain_low_demand_has_explicit_warning(self):
        x=self.compare(
            alt([("Celestial",1)],[("test_key_175",12)]),
            alt([("Celestial",1)],[("EmberbowChroma",1)]),
        )
        self.assertIn("LOW_ORDINAL_PUBLISHER_DEMAND_LABEL",x["alternatives"][0]["evidenceWarnings"])
        self.assertFalse(x["alternatives"][0]["verifiedPartnerAppeal"])
        self.assertEqual(x["actualRetradeLiquidity"],"UNKNOWN")
    def test_received_fluctuating_source_label_warns(self):
        x=self.compare(
            alt([("Celestial",1)],[("EmberbowChroma",1)]),
            alt([("Celestial",1)],[("Gingerscope",1)]),
        )
        self.assertIn("PUBLISHER_FLUCTUATING_RANGE_UNCERTAINTY",x["alternatives"][0]["evidenceWarnings"])
        self.assertNotIn("PUBLISHER_FLUCTUATING_RANGE_UNCERTAINTY",x["alternatives"][1]["evidenceWarnings"])
    def test_publisher_doing_well_not_punished_as_instability(self):
        for r in self.market["records"]:
            if r["rawGameKeyCandidate"]=="EmberbowChroma":
                r["stability"]="Doing Well"
        comparison=self.compare(
            alt([("Celestial",1)],[("EmberbowChroma",1)]),
            alt([("Celestial",1)],[("Gingerscope",1)]))
        self.assertEqual(comparison["status"],"OFFLINE_ATTRACTIVENESS_EVIDENCE_COMPARISON_ONLY")
        warnings=comparison["alternatives"][0]["evidenceWarnings"]
        self.assertNotIn("PUBLISHER_FLUCTUATING_RANGE_UNCERTAINTY",warnings)
        self.assertNotIn("PUBLISHER_FREQUENT_UNDERPAYS",warnings)
        self.assertFalse(comparison["alternatives"][0]["verifiedPartnerAppeal"])

    def test_publisher_underpaid_for_warns_about_underpays(self):
        for r in self.market["records"]:
            if r["rawGameKeyCandidate"]=="EmberbowChroma":
                r["stability"]="Underpaid For"
        comparison=self.compare(
            alt([("Celestial",1)],[("EmberbowChroma",1)]),
            alt([("Celestial",1)],[("Gingerscope",1)]))
        warnings=comparison["alternatives"][0]["evidenceWarnings"]
        self.assertIn("PUBLISHER_FREQUENT_UNDERPAYS",warnings)
        self.assertNotIn("PUBLISHER_FLUCTUATING_RANGE_UNCERTAINTY",warnings)

    def test_unknown_source_stability_fails_closed(self):
        for r in self.market["records"]:
            if r["rawGameKeyCandidate"]=="EmberbowChroma":
                r["stability"]="Completely Perfect"
        comparison=self.compare(
            alt([("Celestial",1)],[("EmberbowChroma",1)]),
            alt([("Celestial",1)],[("Gingerscope",1)]))
        self.assertEqual(comparison["status"],"BLOCKED")
        self.assertEqual(comparison["reason"],"UNKNOWN_PUBLISHER_STABILITY_LABEL")
        self.assertFalse(comparison["authorizesTrade"])

    def test_concentration_worse_after_upgrade(self):
        self.observe({"test_key_100":1,"test_key_101":1})
        x=self.compare(
            alt([("test_key_100",1)],[("Gingerscope",1)]),
            alt([("test_key_100",1)],[("test_key_105",1)]),
        )
        one=x["alternatives"][0]
        self.assertGreater(one["afterListedConcentration"],one["beforeListedConcentration"])
        self.assertIn("PORTFOLIO_LISTED_VALUE_CONCENTRATION_INCREASES",one["evidenceWarnings"])
        self.assertTrue(x["researchAttentionOrderIsNotAnOfferRanking"])
    def test_range_downside_even_with_plus_five(self):
        self.observe({"Emberbow":1})
        x=self.compare(
            alt([("Emberbow",1)],[("test_key_130",5)]),
            alt([("Emberbow",1)],[("Gingerscope",1)]),
        )
        self.assertEqual(x["alternatives"][0]["listedDelta"],5)
        self.assertLess(x["alternatives"][0]["worstCaseRangeDelta"],0)
        self.assertIn("PRICE_RANGE_DOWNSIDE_EXPOSED",x["alternatives"][0]["evidenceWarnings"])
    def test_losses_remain_blocked_even_without_alternatives(self):
        x=self.compare(
            alt([("EmberbowChroma",1)],[("Celestial",1)]),
            alt([("EmberbowChroma",1)],[("Emberbow",1)]),
        )
        self.assertEqual(x["nonLossResearchAlternatives"],0)
        self.assertEqual(x["lossBlockedAlternatives"],2)
        self.assertEqual(x["researchAttentionIndices"],[])
        self.assertFalse(x["alternatives"][0]["hasNoLossAlternativeInBatch"])
    def test_alternative_with_gingerscope_outgoing_is_rejected(self):
        x=self.compare(
            alt([("Gingerscope",1)],[("EmberbowChroma",6)]),
            alt([("Celestial",1)],[("Gingerscope",1)]),
        )
        self.assertEqual(x["invalidAlternatives"],1)
        self.assertIn("GINGERSCOPE_NEVER_OUTGOING",x["alternatives"][0]["reason"])
        self.assertEqual(x["nonLossResearchAlternatives"],1)
    def test_unknown_candidate_only_invalidates_that_alternative(self):
        x=self.compare(
            alt([("Celestial",1)],[("FakeWeapon",1)]),
            alt([("Celestial",1)],[("Gingerscope",1)]),
        )
        self.assertEqual(x["invalidAlternatives"],1)
        self.assertEqual(x["alternatives"][1]["status"],"OFFLINE_RESEARCH_CANDIDATE_ONLY")
    def test_duplicate_alternatives_rejected(self):
        a=alt([("Celestial",1)],[("Gingerscope",1)])
        self.assertEqual(self.compare(a,deepcopy(a))["status"],"BLOCKED")
    def test_only_one_alternative_rejected(self):
        self.assertEqual(m.compare(self.market,self.shadow,[alt([("Celestial",1)],[("Gingerscope",1)])],evaluated_at_utc=self.evaluated_at)["status"],"BLOCKED")
    def test_thirteen_alternatives_rejected(self):
        x=[alt([("Celestial",1)],[(f"test_key_{i}",1)]) for i in range(13)]
        self.assertEqual(m.compare(self.market,self.shadow,x,evaluated_at_utc=self.evaluated_at)["status"],"BLOCKED")
    def test_forged_live_kind_blocked(self):
        a=alt([("Celestial",1)],[("Gingerscope",1)])
        a["kind"]="LIVE_MM2"
        self.assertEqual(self.compare(a,alt([("Celestial",1)],[("EmberbowChroma",1)]))["status"],"BLOCKED")
    def test_shadows_with_forged_authority_rejected(self):
        self.shadow["authorizesTrade"]=True
        self.assertEqual(self.compare(alt([("Celestial",1)],[("Gingerscope",1)]),
                                     alt([("Celestial",1)],[("EmberbowChroma",1)]))["status"],"BLOCKED")
    def test_source_version_changes_rejected(self):
        self.market["sourceExportSha256"]="0"*64
        self.assertEqual(self.compare(alt([("Celestial",1)],[("Gingerscope",1)]),
                                     alt([("Celestial",1)],[("EmberbowChroma",1)]))["status"],"BLOCKED")
    def test_expired_shadow_rejected_before_any_alternative(self):
        self.evaluated_at="2026-11-14T01:16:31.000Z"
        result=self.compare(
            alt([("Celestial",1)],[("Gingerscope",1)]),
            alt([("Celestial",1)],[("EmberbowChroma",1)]))
        self.assertEqual(result["status"],"BLOCKED")
        self.assertEqual(result["reason"],"SHADOW_OBSERVATION_EXPIRED_OR_FUTURE")

    def test_missing_clock_rejected(self):
        result=m.compare(self.market,self.shadow,[
            alt([("Celestial",1)],[("Gingerscope",1)]),
            alt([("Celestial",1)],[("EmberbowChroma",1)])])
        self.assertEqual(result["status"],"BLOCKED")
        self.assertEqual(result["reason"],"SHADOW_OBSERVATION_TIMESTAMP_INVALID")

    def test_high_paper_profit_stack_excluded_from_attention_order(self):
        self.observe({"Celestial":1})
        result=self.compare(
            alt([("Celestial",1)],[("test_key_175",12)]),
            alt([("Celestial",1)],[("Gingerscope",1)]))
        stack=result["alternatives"][0]
        self.assertEqual(stack["status"],"PAPER_STACK_VALUE_UNCERTAIN")
        self.assertFalse(stack["listedDeltaReliableForNegotiation"])
        self.assertEqual(result["stackPriceUncertainAlternatives"],1)
        self.assertEqual(result["researchAttentionIndices"],[1])
        self.assertIn("PUBLISHER_NONLINEAR_STACK_PRICE_NEEDS_INDEPENDENT_EVIDENCE",
                      stack["evidenceWarnings"])

    def test_below_five_stack_may_still_be_research_only(self):
        self.observe({"Celestial":1})
        result=self.compare(
            alt([("Celestial",1)],[("test_key_175",4)]),
            alt([("Celestial",1)],[("Gingerscope",1)]))
        self.assertEqual(result["stackPriceUncertainAlternatives"],0)
        self.assertTrue(result["alternatives"][0]["listedDeltaReliableForNegotiation"])
        self.assertFalse(result["alternatives"][0]["mayUseForTrade"])

    def test_same_alternatives_deterministic(self):
        a=alt([("Celestial",1)],[("Gingerscope",1)])
        c=alt([("Celestial",1)],[("EmberbowChroma",1)])
        self.assertEqual(self.compare(a,c),self.compare(a,c))
    def test_no_real_profit_or_learning(self):
        x=self.compare(alt([("Celestial",1)],[("Gingerscope",1)]),
                       alt([("Celestial",1)],[("EmberbowChroma",1)]))
        self.assertFalse(x["mayReportProfit"])
        self.assertFalse(x["serverCompletionProven"])
        self.assertFalse(x["liveOfferRankingAuthorized"])
        self.assertFalse(x["empiricallyCalibratedStrategy"])
    def test_source_demand_is_ordinal_only(self):
        x=self.compare(alt([("Celestial",1)],[("Gingerscope",1)]),
                       alt([("Celestial",1)],[("EmberbowChroma",1)]))
        self.assertEqual(x["alternatives"][0]["incomingDemandValueWeightedMean"],5)
        self.assertEqual(x["alternatives"][1]["incomingDemandValueWeightedMean"],6)
        self.assertIsNone(x["verifiedTradeAcceptanceProbability"])
    def test_two_hypothetical_alternatives_not_sequential(self):
        x=self.compare(alt([("Celestial",2)],[("Gingerscope",1)]),
                       alt([("Celestial",2)],[("EmberbowChroma",1)]))
        self.assertEqual(x["alternatives"][0]["beforeListedConcentration"],
                         x["alternatives"][1]["beforeListedConcentration"])
        self.assertEqual(x["baselineListedValue"],self.shadow["listedEligibleTotal"])

if __name__=="__main__":
    unittest.main()
