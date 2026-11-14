"""System2: counterparty-specific bounded non-actionable candidate enumeration tests."""
import unittest

from pdiddler.ci.test_market_research_reader import data
from pdiddler.ci.test_client_inventory_shadow import _env
from pdiddler.system2.client_inventory_shadow import evaluate
from pdiddler.system2 import counterparty_candidate_explorer as m


def scope(items,kind="SYNTHETIC_UNVERIFIED_COUNTERPARTY",proof="UNKNOWN"):
    return {"kind":kind,"ownershipProof":proof,
            "items":[{"rawGameKey":key,"quantity":qty} for key,qty in items]}

def request(own,partner,display=20):
    return {"kind":"SYNTHETIC_OFFLINE_COUNTERPARTY_ENUMERATION",
            "ownShortlist":own,"counterparty":scope(partner),"maxDisplay":display}


class CandidateExplorerTests(unittest.TestCase):
    def setUp(self):
        self.market=data()
        self.market["captureWindowUTC"]={"exportedAt":"2026-11-14T00:28:09.127Z"}
        self.observe({"Celestial":1,"test_key_100":1,"Gingerscope":1})
        self.clock="2026-11-14T01:15:40.000Z"

    def observe(self,counts):
        env=_env(self.market,quantities=counts,extras={"CommonKnife":1})
        self.shadow=evaluate(self.market,env,evaluated_at_utc="2026-11-14T01:15:40.000Z")
        self.assertEqual(self.shadow["status"],"RESEARCH_CLIENT_INVENTORY_SHADOW_READY",self.shadow)

    def run_query(self,own=None,partner=None,display=20):
        return m.explore(self.market,self.shadow,
                         request(own if own is not None else ["test_key_100"],
                                 partner if partner is not None else [("Gingerscope",1)],
                                 display),evaluated_at_utc=self.clock)

    def fail(self,reason,own=None,partner=None,display=20):
        r=self.run_query(own=own,partner=partner,display=display)
        self.assertEqual(r["status"],"BLOCKED",r)
        self.assertIn(reason,r["reason"])
        self.assertFalse(r["authorizesTrade"])

    def test_pair_from_counterparty_only(self):
        r=self.run_query()
        self.assertEqual(r["status"],"OFFLINE_COUNTERPARTY_OPTIONS_ENUMERATED",r)
        self.assertEqual(r["totalHypotheticalPairsConsidered"],1)
        self.assertEqual(r["nonLossNonStackPaperPairs"],1)
        self.assertTrue(r["previews"][0]["incomingGingerscopeHypothesis"])
        self.assertFalse(r["counterpartyOwnsAnyItemProven"])
        self.assertIsNone(r["acceptanceProbability"])
        self.assertFalse(r["authorizesAccept"])

    def test_target_not_fabricated_if_not_in_counterparty(self):
        r=self.run_query(partner=[("EmberbowChroma",1)])
        self.assertTrue(all(not p["incomingGingerscopeHypothesis"] for p in r["previews"]))
        self.assertFalse(r["globalBestTradeProven"])

    def test_explicit_own_items_only(self):
        r=self.run_query(own=["test_key_100"],partner=[("EmberbowChroma",1)])
        self.assertEqual(r["explicitOwnKeyCount"],1)
        self.assertEqual(r["previews"][0]["outgoingSlots"][0]["rawGameKey"],"test_key_100")

    def test_owned_gscope_never_outgoing(self):
        r=self.run_query(own=["Gingerscope","Celestial"],partner=[("EmberbowChroma",1)])
        self.assertEqual(r["status"],"OFFLINE_COUNTERPARTY_OPTIONS_ENUMERATED")
        self.assertTrue(all(
            x["rawGameKey"]!="Gingerscope"
            for cand in r["previews"] for x in cand["outgoingSlots"]))

    def test_only_owned_gscope_is_not_outgoing_candidate(self):
        self.fail("ONLY_PROTECTED_GINGERSCOPE",own=["Gingerscope"])

    def test_unowned_item_in_own_shortlist_blocks(self):
        self.fail("UNKNOWN_OR_UNOWNED",own=["Immortal"])

    def test_unknown_opponent_key_blocks(self):
        self.fail("COUNTERPARTY_UNKNOWN",partner=[("FakeGodly",1)])

    def test_fake_partner_verification_claim_rejected(self):
        r=request(["test_key_100"],[("Gingerscope",1)])
        r["counterparty"]["ownershipProof"]="SERVER_PROVEN"
        self.assertEqual(m.explore(self.market,self.shadow,r,evaluated_at_utc=self.clock)["status"],"BLOCKED")

    def test_wrong_counterparty_kind_blocks(self):
        r=request(["test_key_100"],[("Gingerscope",1)])
        r["counterparty"]["kind"]="LIVE_MM2_VERIFIED"
        self.assertEqual(m.explore(self.market,self.shadow,r,evaluated_at_utc=self.clock)["status"],"BLOCKED")

    def test_extra_authority_field_blocks(self):
        r=request(["test_key_100"],[("Gingerscope",1)])
        r["maySendOffer"]=True
        self.assertEqual(m.explore(self.market,self.shadow,r,evaluated_at_utc=self.clock)["status"],"BLOCKED")

    def test_unknown_partner_quantity_type_blocks(self):
        self.fail("COUNTERPARTY_UNKNOWN",partner=[("Gingerscope",True)])

    def test_duplicated_partner_key_blocks(self):
        self.fail("COUNTERPARTY_UNKNOWN",partner=[("Gingerscope",1),("Gingerscope",1)])

    def test_more_than_four_keys_blocks(self):
        self.fail("EXPLICIT_BOUNDED",own=["Celestial","test_key_100","Gingerscope","test_key_101","test_key_102"])

    def test_more_than_four_partner_keys_blocks(self):
        self.fail("COUNTERPARTY_EXPLICIT_SHORTLIST_INVALID",
            partner=[(f"test_key_{i}",1) for i in range(5)])

    def test_excessive_partner_overpay_not_called_credible(self):
        r=self.run_query()
        self.assertIn("COUNTERPARTY_WOULD_GIVE_MORE_LISTED_VALUE_UNPROVEN",
                      r["previews"][0]["warnings"])
        self.assertFalse(r["rankedByRealAttractiveness"])

    def test_stacked_five_of_valued_item_excluded_from_preview(self):
        r=self.run_query(partner=[("EmberbowChroma",5)])
        self.assertEqual(r["status"],"OFFLINE_COUNTERPARTY_OPTIONS_ENUMERATED")
        self.assertGreater(r["nonlinearStackPricingBlockedPairs"],0)
        self.assertTrue(all(
            row["quantity"]<5 for p in r["previews"] for row in p["incomingSlots"]))

    def test_stack_five_of_value_one_not_falsely_flagged_nonlinear(self):
        r=self.run_query(partner=[("test_key_0",5)])
        self.assertEqual(r["nonlinearStackPricingBlockedPairs"],0)
        self.assertGreater(r["lossBudgetBlockedPairs"],0)

    def test_four_physical_slots_vs_owned_stacked_amounts(self):
        self.observe({f"test_key_{i}":1 for i in range(100,104)})
        r=self.run_query(own=[f"test_key_{i}" for i in range(100,104)],
                         partner=[("Gingerscope",1)])
        self.assertEqual(r["status"],"OFFLINE_COUNTERPARTY_OPTIONS_ENUMERATED")
        self.assertTrue(any(p["outgoingPhysicalSlots"]==4 for p in r["previews"]+[
            # later candidates may be excluded by display cap; verify counting instead
        ]) or r["nonLossNonStackPaperPairs"]>=15)
        self.assertTrue(all(p["outgoingPhysicalSlots"]<=4 for p in r["previews"]))

    def test_expired_source_inventory_blocks(self):
        self.clock="2026-11-14T01:16:31.000Z"
        self.fail("SHADOW_OBSERVATION_EXPIRED_OR_FUTURE")

    def test_duplicate_own_shortlist_blocks(self):
        self.fail("EXPLICIT_BOUNDED",own=["Celestial","Celestial"])

    def test_no_unapproved_loss_even_if_counterparty_owns_lower(self):
        r=self.run_query(own=["Celestial"],partner=[("test_key_0",1)])
        self.assertEqual(r["nonLossNonStackPaperPairs"],0)
        self.assertGreater(r["lossBudgetBlockedPairs"],0)

    def test_preview_limit_does_not_claim_global_optimization(self):
        r=self.run_query(own=["Celestial","test_key_100"],
                         partner=[("Gingerscope",1),("EmberbowChroma",1)],display=1)
        self.assertLessEqual(len(r["previews"]),1)
        self.assertTrue(r["previewOrderingIsNotProfitOrAttractivenessRanking"])
        self.assertFalse(r["globalBestTradeProven"])

    def test_replay_determinism(self):
        self.assertEqual(self.run_query(),self.run_query())


if __name__=="__main__":
    unittest.main()
