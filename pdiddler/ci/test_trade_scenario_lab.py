"""System 2 Part 3: multi-component OFFLINE scenario planning assertions.

Uses the existing separately tested synthetic 189-price dataset + scanner shadow,
NOT fabricated current MM2/partner data. There are NO real trade actions here.
"""
from __future__ import annotations
from copy import deepcopy
import unittest

from pdiddler.ci.test_market_research_reader import data
from pdiddler.ci.test_client_inventory_shadow import _env
from pdiddler.system2 import client_inventory_shadow as b
from pdiddler.system2 import trade_scenario_lab as lab


def trade(out,inc):
    return {
        "kind": lab.SIMULATION_KIND,
        "outgoingSlots":[{"rawGameKey":key,"quantity":qty} for key,qty in out],
        "incomingSlots":[{"rawGameKey":key,"quantity":qty} for key,qty in inc],
    }


class ScenarioTests(unittest.TestCase):
    def setUp(self):
        self.market=data()
        self.evaluated_at="2026-11-14T01:15:40.000Z"
        self.market["captureWindowUTC"]={"exportedAt":"2026-11-14T00:28:09.127Z"}
        self.observe({"Celestial":2,"EmberbowChroma":6,"Gingerscope":1})
    def observe(self,counts):
        env=_env(self.market,quantities=counts,extras={"CommonKnife":1})
        self.shadow=b.evaluate(self.market,env,evaluated_at_utc="2026-11-14T01:15:40.000Z")
        self.assertEqual(self.shadow["status"],"RESEARCH_CLIENT_INVENTORY_SHADOW_READY",self.shadow)
    def review(self,offer,receive):
        return lab.inspect(self.market,self.shadow,trade(offer,receive),evaluated_at_utc=self.evaluated_at)
    def deny(self,offer,receive,reason):
        result=self.review(offer,receive)
        self.assertEqual(result["status"],"BLOCKED",result)
        self.assertIn(reason,result["reason"],result)
        self.assertFalse(result["authorizesTrade"])
        self.assertFalse(result["authorizesAccept"])
    def test_plus_five_is_not_old_plus_fifteen_rule(self):
        self.observe({"test_key_100":1})
        r=self.review([("test_key_100",1)],[("test_key_105",1)])
        self.assertEqual(r["status"],"OFFLINE_SCENARIO_REVIEWED")
        self.assertEqual(r["listedDelta"],5)
        self.assertEqual(r["scenarioKind"],"SIDEGRADE")
        self.assertIsNone(r["acceptanceProbability"])
    def test_two_to_one_upgrade(self):
        self.observe({"Celestial":1,"Emberbow":1})
        r=self.review([("Celestial",1),("Emberbow",1)],[("EmberbowChroma",1)])
        self.assertEqual(r["scenarioKind"],"UPGRADE")
        self.assertEqual(r["listedDelta"],3400)
        self.assertEqual(r["outgoingPhysicalSlots"],2)
        self.assertEqual(r["incomingPhysicalSlots"],1)
        self.assertEqual(r["status"],"OFFLINE_SCENARIO_REVIEWED")
    def test_one_to_two_downgrade_plus_five(self):
        self.observe({"test_key_100":1})
        r=self.review([("test_key_100",1)],[("test_key_69",1),("test_key_35",1)])
        self.assertEqual(r["scenarioKind"],"DOWNGRADE")
        self.assertEqual(r["listedDelta"],5)
    def test_controlled_loss_not_approved(self):
        r=self.review([("EmberbowChroma",1)],[("Celestial",1),("Emberbow",1)])
        self.assertEqual(r["scenarioKind"],"DOWNGRADE")
        self.assertEqual(r["listedDelta"],-3400)
        self.assertEqual(r["status"],"OFFLINE_LOSS_SCENARIO_BLOCKED_POLICY")
        self.assertFalse(r["controlledLossTradeAuthorized"])
        self.assertIn("UNAPPROVED_LISTED_VALUE_LOSS",r["warnings"])
    def test_gingerscope_incoming_allowed_hypothetically(self):
        r=self.review([("EmberbowChroma",1)],[("Gingerscope",1)])
        self.assertEqual(r["status"],"OFFLINE_SCENARIO_REVIEWED")
        self.assertTrue(r["hypotheticalTargetReceived"])
        self.assertIn("TARGET_INCOMING_HYPOTHETICAL_NOT_ACQUIRED",r["warnings"])
        self.assertFalse(r["authorizesAccept"])
    def test_gingerscope_outgoing_never_even_for_huge_gain(self):
        self.deny([("Gingerscope",1)],[("EmberbowChroma",6)],"GINGERSCOPE_NEVER_OUTGOING")
    def test_empty_own_gift_can_be_displayed_not_executed(self):
        r=self.review([],[("Gingerscope",1)])
        self.assertEqual(r["outgoingPhysicalSlots"],0)
        self.assertIn("EMPTY_OUTGOING_HYPOTHETICAL_GIFT",r["warnings"])
        self.assertFalse(r["authorizesTrade"])
    def test_four_physical_slots_supported(self):
        self.observe({"test_key_100":1,"test_key_101":1,"test_key_102":1,"test_key_103":1})
        r=self.review([("test_key_100",1),("test_key_101",1),("test_key_102",1),("test_key_103",1)],[("Celestial",1)])
        self.assertEqual(r["outgoingPhysicalSlots"],4)
        self.assertEqual(r["status"],"OFFLINE_SCENARIO_REVIEWED")
    def test_five_outgoing_slots_blocked(self):
        self.observe({f"test_key_{i}":1 for i in range(100,105)})
        self.deny([(f"test_key_{i}",1) for i in range(100,105)],[("Gingerscope",1)],"PHYSICAL_OFFER_SLOT_COUNT_INVALID")
    def test_five_incoming_slots_blocked(self):
        self.deny([("Celestial",1)],[(f"test_key_{i}",1) for i in range(100,105)],"PHYSICAL_OFFER_SLOT_COUNT_INVALID")
    def test_six_stacked_copies_still_one_slot(self):
        r=self.review([("EmberbowChroma",6)],[("Gingerscope",1)])
        self.assertEqual(r["outgoingPhysicalSlots"],1)
        self.assertEqual(r["outgoingCopies"],6)
        self.assertIn("STACKED_COPIES_DISTINCT_FROM_PHYSICAL_SLOTS",r["warnings"])
    def test_not_own_enough_stacked_copies(self):
        self.deny([("EmberbowChroma",7)],[("Gingerscope",1)],"OUTGOING_EXCEEDS")
    def test_own_gingerscope_does_not_become_offer(self):
        self.deny([("Gingerscope",1)],[("Gingerscope",1)],"GINGERSCOPE_NEVER_OUTGOING")
    def test_non_owned_item_blocked(self):
        self.deny([("Emberbow",1)],[("Gingerscope",1)],"OUTGOING_EXCEEDS")
    def test_unknown_received_item(self):
        self.deny([("Celestial",1)],[("FakeItem",1)],"UNKNOWN_EXACT")
    def test_unknown_own_item(self):
        self.deny([("FakeItem",1)],[("Celestial",1)],"UNKNOWN_EXACT")
    def test_duplicate_slot(self):
        self.deny([("Celestial",1),("Celestial",1)],[("Gingerscope",1)],"UNKNOWN_DUPLICATE")
    def test_duplicate_incoming_slot(self):
        self.deny([("Celestial",1)],[("Emberbow",1),("Emberbow",2)],"UNKNOWN_DUPLICATE")
    def test_invalid_bool_quantity(self):
        self.deny([("Celestial",True)],[("Gingerscope",1)],"UNKNOWN_DUPLICATE")
    def test_invalid_string_quantity(self):
        self.deny([("Celestial","2")],[("Gingerscope",1)],"UNKNOWN_DUPLICATE")
    def test_expired_or_unknown_market_sha(self):
        self.market["sourceExportSha256"]="0"*64
        self.deny([("Celestial",1)],[("Gingerscope",1)],"UNEXPECTED_MAPPED_SOURCE_VERSION")
    def test_invalid_shadow_origin(self):
        self.shadow["clientInventoryAuthenticity"]="CLIENT_SERVER_VERIFIED"
        self.deny([("Celestial",1)],[("Gingerscope",1)],"UNVERIFIED_OR_MUTATED")
    def test_forged_shadow_accept_permission(self):
        self.shadow["authorizesAccept"]=True
        self.deny([("Celestial",1)],[("Gingerscope",1)],"UNVERIFIED_OR_MUTATED")
    def test_forged_shadow_subtotal(self):
        self.shadow["records"][0]["listedSubtotal"]=999
        self.deny([("Celestial",1)],[("Gingerscope",1)],"SHADOW_MARKET_IDENTITY")
    def test_mutated_shadow_counts(self):
        self.shadow["eligibleCopies"]+=2
        self.deny([("Celestial",1)],[("Gingerscope",1)],"SHADOW_CENSUS_OR_TOTAL")
    def test_modified_market_price_not_hidden_in_shadow(self):
        self.market["records"][0]["decimalValue"]+=500
        self.deny([("Celestial",1)],[("Gingerscope",1)],"SHADOW_MARKET_IDENTITY")
    def test_demand_not_liquidity(self):
        r=self.review([("Celestial",1)],[("Gingerscope",1)])
        self.assertIn("NO_VERIFIED_COUNTERPARTY_LIQUIDITY_OR_ACCEPTANCE_DATA",r["warnings"])
        self.assertEqual(r["partnerAppeal"],"UNMEASURED")
        self.assertEqual(r["executedTradeLiquidity"],"UNKNOWN")
        self.assertIsNone(r["acceptanceProbability"])
    def test_range_downside_warning_is_not_auto_accept(self):
        self.observe({"Emberbow":1})
        r=self.review([("Emberbow",1)],[("test_key_100",6)])
        self.assertIn("WORST_CASE_RANGE_LOSS_POSSIBLE",r["warnings"])
        self.assertFalse(r["authorizesOffer"])
    def test_no_fabricated_profit_or_completed_trade(self):
        r=self.review([("Celestial",1)],[("Gingerscope",1)])
        self.assertNotIn("realizedProfit",r)
        self.assertFalse(r["mayReportProfit"])
        self.assertFalse(r["serverCompletionProven"])
        self.assertEqual(r["tradeOutcome"],"UNKNOWN")
    def test_inventory_observation_does_not_prove_partner_stock(self):
        r=self.review([("Celestial",1)],[("Gingerscope",1)])
        self.assertFalse(r["partnerInventoryAuthenticityProven"])
        self.assertFalse(r["fourPhysicalSlotExecutionProven"])
    def test_malformed_scenario_blocks(self):
        r=lab.inspect(self.market,self.shadow,{"kind":"LIVE_MM2","outgoingSlots":[],"incomingSlots":[{"rawGameKey":"Gingerscope","quantity":1}]},evaluated_at_utc=self.evaluated_at)
        self.assertEqual(r["status"],"BLOCKED")
    def test_mutable_scenario_authorize_false(self):
        r=lab.inspect(self.market,self.shadow,{**trade([("Celestial",1)],[("Gingerscope",1)]),"authorizesTrade":True},evaluated_at_utc=self.evaluated_at)
        self.assertEqual(r["status"],"BLOCKED")
    def test_reused_shadow_after_60_seconds_is_blocked(self):
        self.evaluated_at="2026-11-14T01:16:31.000Z"
        self.deny([("Celestial",1)],[("Gingerscope",1)],"SHADOW_OBSERVATION_EXPIRED_OR_FUTURE")

    def test_future_client_shadow_is_blocked(self):
        self.evaluated_at="2026-11-14T01:15:29.000Z"
        self.deny([("Celestial",1)],[("Gingerscope",1)],"SHADOW_OBSERVATION_EXPIRED_OR_FUTURE")

    def test_strategy_requires_explicit_evaluation_clock(self):
        result=lab.inspect(self.market,self.shadow,trade([("Celestial",1)],[("Gingerscope",1)]))
        self.assertEqual(result["status"],"BLOCKED")
        self.assertEqual(result["reason"],"SHADOW_OBSERVATION_TIMESTAMP_INVALID")

    def test_six_identical_valuable_copies_not_linear_trading_value(self):
        self.observe({"EmberbowChroma":6})
        result=self.review([("EmberbowChroma",6)],[("Gingerscope",1)])
        self.assertFalse(result["listedDeltaReliableForNegotiation"])
        self.assertEqual(result["outgoingUncertainStackKeys"],["EmberbowChroma"])
        self.assertIn("PUBLISHER_STACK_PRICE_NONLINEAR_UNVERIFIED",result["warnings"])
        self.assertFalse(result["authorizesTrade"])

    def test_four_identical_copies_does_not_trigger_five_stack_warning(self):
        self.observe({"EmberbowChroma":4})
        result=self.review([("EmberbowChroma",4)],[("Gingerscope",1)])
        self.assertTrue(result["listedDeltaReliableForNegotiation"])
        self.assertNotIn("PUBLISHER_STACK_PRICE_NONLINEAR_UNVERIFIED",result["warnings"])

    def test_five_copies_of_single_value_item_does_not_trigger_warning(self):
        self.observe({"test_key_0":5})
        result=self.review([("test_key_0",5)],[("Gingerscope",1)])
        self.assertTrue(result["listedDeltaReliableForNegotiation"])
        self.assertEqual(result["outgoingUncertainStackKeys"],[])

    def test_value_weighted_demand_does_not_overweight_cheap_weapons(self):
        self.observe({"test_key_100":1})
        result=self.review([("test_key_100",1)],
                           [("Celestial",1),("EmberbowChroma",1)])
        expected=(1950*5+6000*6)/7950
        self.assertAlmostEqual(result["incomingDemandValueWeightedMean"],expected,places=7)
        self.assertNotAlmostEqual(result["incomingDemandValueWeightedMean"],5.5,places=3)
        self.assertTrue(result["listedDeltaReliableForNegotiation"])

    def test_replay_is_deterministic(self):
        s=trade([("Celestial",1)],[("EmberbowChroma",1)])
        self.assertEqual(lab.inspect(self.market,self.shadow,s,evaluated_at_utc=self.evaluated_at),lab.inspect(self.market,self.shadow,s,evaluated_at_utc=self.evaluated_at))


if __name__=="__main__":
    unittest.main()
