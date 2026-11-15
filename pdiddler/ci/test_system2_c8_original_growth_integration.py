"""C8 first original-source integration: actual market -> client shadow -> C5 replay.

Unlike the C8 admission fixture tests, these call the actual production research
modules with the existing frozen test market and client inventory envelope.
No game, private Discord, chat, or network access.
"""
import unittest
from pdiddler.ci.test_market_research_reader import data
from pdiddler.ci.test_client_inventory_shadow import _env
from pdiddler.system2.client_inventory_shadow import evaluate
from pdiddler.system2.multitrade_growth_replay import simulate
from pdiddler.system2.trade_scenario_lab import SIMULATION_KIND

NOW="2026-11-14T01:15:40.000Z"

def step(give, receive):
    return dict(kind=SIMULATION_KIND,
                outgoingSlots=[dict(rawGameKey=k,quantity=q) for k,q in give],
                incomingSlots=[dict(rawGameKey=k,quantity=q) for k,q in receive])

class C8OriginalGrowthReplay(unittest.TestCase):
    def setUp(self):
        self.market=data()
        self.market["captureWindowUTC"]={"exportedAt":"2026-11-14T00:28:09.127Z"}
        self.inventory=_env(self.market,quantities={"test_key_100":1},
                            extras={"CommonKnife":1})
        self.shadow=evaluate(self.market,self.inventory,evaluated_at_utc=NOW)
        self.assertEqual(self.shadow["status"],
                         "RESEARCH_CLIENT_INVENTORY_SHADOW_READY",self.shadow)

    def replay(self,steps,shadow=None,market=None):
        return simulate(market if market is not None else self.market,
                        shadow if shadow is not None else self.shadow,
                        steps,evaluated_at_utc=NOW)

    def test_original_three_step_compounding(self):
        r=self.replay([
            step([("test_key_100",1)],[("test_key_105",1)]),
            step([("test_key_105",1)],[("test_key_110",1)]),
            step([("test_key_110",1)],[("test_key_120",1)])])
        self.assertEqual(r["status"],"OFFLINE_GROWTH_PATH_SIMULATED",r)
        self.assertEqual(r["hypotheticalListedValueGrowth"],20)
        self.assertEqual(r["simulatedSteps"],3)
        self.assertTrue(r["allLaterInventoriesHypothetical"])
        for key in ("authorizesOffer","authorizesTrade","authorizesAccept",
                    "serverTradeCompletionProven"):
            self.assertIs(r[key],False)

    def test_original_source_drift_blocks(self):
        market=dict(self.market);market["sourceExportSha256"]="0"*64
        self.assertEqual(self.replay([step([("test_key_100",1)],
                                         [("test_key_105",1)])],market=market)["status"],
                         "BLOCKED")

    def test_original_inventory_authority_forgery_blocks(self):
        shadow=dict(self.shadow);shadow["authorizesAccept"]=True
        self.assertEqual(self.replay([step([("test_key_100",1)],
                                         [("test_key_105",1)])],shadow=shadow)["status"],
                         "BLOCKED")

    def test_original_impossible_second_step_blocks(self):
        r=self.replay([step([("test_key_100",1)],[("test_key_105",1)]),
                       step([("test_key_100",1)],[("test_key_110",1)])])
        self.assertEqual(r["status"],"BLOCKED",r)
        self.assertFalse(r["authorizesOffer"])

    def test_original_five_physical_slots_blocks(self):
        r=self.replay([step([("test_key_100",1)],
                       [("test_key_105",1)]*5)])
        self.assertEqual(r["status"],"BLOCKED",r)
        self.assertFalse(r["authorizesTrade"])

if __name__=="__main__":
    unittest.main()
