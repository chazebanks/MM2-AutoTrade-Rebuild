"""System2 Part5 offline multi-trade compounding and adversarial replay tests."""
from __future__ import annotations
import unittest

from pdiddler.ci.test_market_research_reader import data
from pdiddler.ci.test_client_inventory_shadow import _env
from pdiddler.system2.client_inventory_shadow import evaluate
from pdiddler.system2.multitrade_growth_replay import simulate
from pdiddler.system2.trade_scenario_lab import SIMULATION_KIND


def t(out,rec):
    return {
        "kind":SIMULATION_KIND,
        "outgoingSlots":[{"rawGameKey":k,"quantity":q} for k,q in out],
        "incomingSlots":[{"rawGameKey":k,"quantity":q} for k,q in rec],
    }


class MultitradeGrowthTests(unittest.TestCase):
    def setUp(self):
        self.market=data()
        self.market["captureWindowUTC"]={"exportedAt":"2026-11-14T00:28:09.127Z"}
        self.owned({"test_key_100":1})
    def owned(self,counts):
        inventory=_env(self.market,quantities=counts,extras={"CommonKnife":1})
        self.shadow=evaluate(self.market,inventory,evaluated_at_utc="2026-11-14T01:15:40.000Z")
        self.assertEqual(self.shadow["status"],"RESEARCH_CLIENT_INVENTORY_SHADOW_READY",self.shadow)
    def runpath(self,*steps):
        return simulate(self.market,self.shadow,list(steps))
    def blocked(self,why,*steps):
        r=self.runpath(*steps)
        self.assertIn(r["status"],("BLOCKED","BLOCKED_LOSS_POLICY"),r)
        self.assertIn(why,r["reason"],r)
        self.assertFalse(r["authorizesTrade"])
        self.assertFalse(r["authorizesAccept"])
    def test_three_sequential_plus_five_growth(self):
        r=self.runpath(
            t([("test_key_100",1)],[("test_key_105",1)]),
            t([("test_key_105",1)],[("test_key_110",1)]),
            t([("test_key_110",1)],[("test_key_120",1)]),
        )
        self.assertEqual(r["status"],"OFFLINE_GROWTH_PATH_SIMULATED",r)
        self.assertEqual([x["listedDelta"] for x in r["steps"]],[5,5,10])
        self.assertEqual(r["hypotheticalListedValueGrowth"],20)
        self.assertEqual(r["endingHypotheticalListedPortfolioValue"],121)
        self.assertEqual(r["startingListedPortfolioValue"],101)
        self.assertEqual(r["endingHypotheticalGapToGingerscope"],15879)
        self.assertFalse(r["authorizesOffer"])
        self.assertFalse(r["mayUseForStrategyLearning"])
    def test_acquisition_target_two_step_is_hypothetical(self):
        self.owned({"Celestial":1})
        r=self.runpath(
            t([("Celestial",1)],[("EmberbowChroma",1)]),
            t([("EmberbowChroma",1)],[("Gingerscope",1)]),
        )
        self.assertEqual(r["status"],"OFFLINE_GROWTH_PATH_SIMULATED")
        self.assertTrue(r["goalTargetHypotheticallyReceived"])
        self.assertEqual(r["hypotheticalEndingProtectedGingerscopeCopies"],1)
        self.assertEqual(r["endingHypotheticalGapToGingerscope"],0)
        self.assertFalse(r["serverCompletionProven"])
        self.assertFalse(r["currentGameItemInstanceProven"])
    def test_target_cannot_be_resold_after_theoretical_acquisition(self):
        self.owned({"Celestial":1})
        self.blocked("STEP_2_PROTECTED_GINGERSCOPE_NEVER_OUTGOING",
            t([("Celestial",1)],[("Gingerscope",1)]),
            t([("Gingerscope",1)],[("EmberbowChroma",6)]))
    def test_existing_target_already_owned_never_outgoing(self):
        self.owned({"Gingerscope":1,"Celestial":1})
        self.blocked("STEP_1_PROTECTED_GINGERSCOPE_NEVER_OUTGOING",
            t([("Gingerscope",1)],[("EmberbowChroma",6)]),
            t([("EmberbowChroma",1)],[("Gingerscope",1)]))
    def test_loss_at_second_stage_stops_entire_path(self):
        r=self.runpath(
            t([("test_key_100",1)],[("test_key_110",1)]),
            t([("test_key_110",1)],[("test_key_90",1)]))
        self.assertEqual(r["status"],"BLOCKED_LOSS_POLICY")
        self.assertEqual(r["blockedAtStep"],2)
        self.assertEqual(r["hypotheticalCompletedSteps"],1)
        self.assertFalse(r["validatedApprovedLossBudget"])
    def test_loss_at_first_stage_blocks(self):
        self.blocked("STEP_1_UNAPPROVED_LISTED_LOSS",
            t([("test_key_100",1)],[("test_key_90",1)]),
            t([("test_key_90",1)],[("test_key_120",1)]))
    def test_unauthorized_gift_step_is_not_growth(self):
        self.blocked("PHYSICAL_OFFER_SLOT_COUNT_INVALID",
            t([],[("Gingerscope",1)]),t([("Gingerscope",1)],[("Celestial",1)]))
    def test_five_physical_slots_rejected(self):
        self.owned({f"test_key_{i}":1 for i in range(100,105)})
        self.blocked("PHYSICAL_OFFER_SLOT_COUNT_INVALID",
            t([(f"test_key_{i}",1) for i in range(100,105)],[("Gingerscope",1)]),
            t([("Gingerscope",1)],[("Celestial",1)]))
    def test_stacks_exceed_four_copies_but_not_four_slots(self):
        self.owned({"Celestial":1})
        r=self.runpath(
            t([("Celestial",1)],[("test_key_100",20)]),
            t([("test_key_100",20)],[("Gingerscope",1)]))
        self.assertEqual(r["status"],"OFFLINE_GROWTH_PATH_SIMULATED",r)
        self.assertEqual(r["steps"][1]["outgoingPhysicalSlots"],1)
        self.assertEqual(r["steps"][1]["outgoingCopies"],20)
        self.assertIn("STACKED_COPIES_ARE_NOT_PHYSICAL_SLOTS",r["steps"][1]["warnings"])
    def test_future_item_unowned_in_hypothesis(self):
        self.blocked("STEP_2_HYPOTHETICAL_STOCK_SHORTFALL",
            t([("test_key_100",1)],[("test_key_105",1)]),
            t([("Celestial",1)],[("Gingerscope",1)]))
    def test_future_overdraw_a_stack(self):
        self.blocked("STEP_2_HYPOTHETICAL_STOCK_SHORTFALL",
            t([("test_key_100",1)],[("test_key_105",2)]),
            t([("test_key_105",3)],[("Gingerscope",1)]))
    def test_unknown_item_refused(self):
        self.blocked("STEP_1_UNKNOWN_RAW_KEY",
            t([("test_key_100",1)],[("NotOn189",1)]),
            t([("NotOn189",1)],[("Gingerscope",1)]))
    def test_bad_incoming_qty(self):
        self.blocked("UNKNOWN_DUPLICATE_OR_INVALID_SLOT",
            t([("test_key_100",1)],[("test_key_105",True)]),
            t([("test_key_105",1)],[("Gingerscope",1)]))
    def test_future_live_stage_forgery_rejected(self):
        a=t([("test_key_100",1)],[("test_key_105",1)])
        a["kind"]="LIVE_MM2"
        self.blocked("EXPLICIT_SYNTHETIC_SCENARIO_REQUIRED",a,
            t([("test_key_105",1)],[("Gingerscope",1)]))
    def test_one_step_is_not_multitrade_plan(self):
        self.blocked("GROWTH_PATH_REQUIRES_TWO_TO_EIGHT",
            t([("test_key_100",1)],[("test_key_105",1)]))
    def test_nine_steps_max_is_bounded(self):
        steps=[t([("test_key_100",1)],[("test_key_105",1)]) for _ in range(9)]
        self.blocked("GROWTH_PATH_REQUIRES_TWO_TO_EIGHT",*steps)
    def test_source_poison_refused(self):
        self.market["sourceExportSha256"]="0"*64
        self.blocked("UNEXPECTED_MAPPED_SOURCE_VERSION",
            t([("test_key_100",1)],[("test_key_105",1)]),
            t([("test_key_105",1)],[("Gingerscope",1)]))
    def test_shadow_authority_mutation_refused(self):
        self.shadow["authorizesAccept"]=True
        self.blocked("UNVERIFIED_OR_MUTATED_INVENTORY_SHADOW",
            t([("test_key_100",1)],[("test_key_105",1)]),
            t([("test_key_105",1)],[("Gingerscope",1)]))
    def test_zero_gain_sidegrade_not_falsely_claimed_growth(self):
        # Two equal listed synthetic keys: descriptive zero-gain move.
        for r in self.market["records"]:
            if r["rawGameKeyCandidate"]=="test_key_105":
                r["decimalValue"]=101
                r["rangeLow"]=101
                r["rangeHigh"]=101
        r=self.runpath(
            t([("test_key_100",1)],[("test_key_105",1)]),
            t([("test_key_105",1)],[("test_key_110",1)]))
        self.assertEqual(r["steps"][0]["listedDelta"],0)
        self.assertIn("NO_LISTED_VALUE_GROWTH_THIS_STEP",r["steps"][0]["warnings"])
        self.assertEqual(r["hypotheticalListedValueGrowth"],10)
    def test_round_trip_loop_does_not_count_as_compounding(self):
        for r in self.market["records"]:
            if r["rawGameKeyCandidate"]=="test_key_105":
                r["decimalValue"]=101
                r["rangeLow"]=101
                r["rangeHigh"]=101
        self.blocked("STEP_2_PORTFOLIO_CYCLE_DETECTED",
            t([("test_key_100",1)],[("test_key_105",1)]),
            t([("test_key_105",1)],[("test_key_100",1)]))
    def test_fake_liquidity_not_turned_into_probability(self):
        r=self.runpath(
            t([("test_key_100",1)],[("test_key_105",1)]),
            t([("test_key_105",1)],[("test_key_110",1)]))
        self.assertIsNone(r["partnerAcceptanceProbability"])
        self.assertEqual(r["empiricalLiquidityEvidence"],"UNKNOWN")
        self.assertFalse(r["autoAcceptAuthorized"])
    def test_mutation_replay_deterministic(self):
        steps=[
            t([("test_key_100",1)],[("test_key_105",1)]),
            t([("test_key_105",1)],[("test_key_110",1)]),
        ]
        self.assertEqual(simulate(self.market,self.shadow,steps),
                         simulate(self.market,self.shadow,steps))

if __name__=="__main__":
    unittest.main()
