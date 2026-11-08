"""Property tests for source-dispersion bounds, never game/price authority."""
from __future__ import annotations

import copy
import importlib.util
import random
import unittest
from pathlib import Path

PATH=Path(__file__).with_name("dual_source_sensitivity.py")
SPEC=importlib.util.spec_from_file_location("source_sensitivity",PATH)
assert SPEC is not None and SPEC.loader is not None
M=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)
SNAP=M.load_snapshot()

def row(item,qty=1):
    return [{"displayName":item,"quantity":qty}]

def fail_closed(result):
    assert result["exactGameItemIdentityProven"] is False
    assert result["publisherCurrencyAndTimeVerified"] is False
    assert result["sourceDisplayAliasesAuthenticated"] is False
    assert result["actualTradeProfitProven"] is False
    assert result["quotedGainRobustlyPositive"] in (True,False)
    for k in ("authorizesTrade","authorizesAccept","mayReportProfit",
              "mayRecordCompletedTrade","mayUseForStrategyLearning",
              "serverCompletionProven"):
        assert result[k] is False,(k,result)
    assert result["tradeOutcome"]=="UNKNOWN"

class SourceSensitivityTests(unittest.TestCase):
    def test_emberbow_to_emberscythe_source_disagreement_reverses_apparent_gain(self):
        s=M.calculate(row("Emberbow"),row("Emberscythe"),snapshot=SNAP)
        # Supreme: 500 - 525 = -25. MM2Values: 450 - 450 = 0.
        # Across mixed source assumptions, worst-case is 450 - 525 = -75.
        self.assertEqual(s["perSourceListedGain"],{"supreme":-25,"mm2values":0})
        self.assertEqual((s["minListedGain"],s["maxListedGain"]),(-75,50))
        self.assertEqual(s["status"],"SOURCE_DISAGREEMENT_EXPOSES_DOWNSIDE")
        fail_closed(s)
    def test_chroma_emberscythe_gingerscope_display_margin_not_earning_proof(self):
        s=M.calculate(row("Chroma Emberscythe"),row("Gingerscope"),snapshot=SNAP)
        self.assertEqual(s["perSourceListedGain"],{"supreme":0,"mm2values":3500})
        self.assertEqual((s["minListedGain"],s["maxListedGain"]),(0,3500))
        self.assertEqual(s["status"],"SOURCE_DISAGREEMENT_EXPOSES_DOWNSIDE")
        fail_closed(s)
    def test_harvester_for_two_other_weapons_demand_not_covered(self):
        s=M.calculate(row("Harvester"),
                      [*row("Icepiercer"),*row("Batwing",3)],snapshot=SNAP)
        self.assertEqual(s["perSourceListedGain"],{"supreme":36,"mm2values":50})
        self.assertEqual((s["minListedGain"],s["maxListedGain"]),(36,50))
        self.assertTrue(s["quotedGainRobustlyPositive"])
        self.assertEqual(s["status"],"CROSS_SOURCE_DISPLAY_MARGIN_POSITIVE_ONLY")
        # The result deliberately does NOT infer whether the recipient items
        # are liquid, tradable, desirable, or from verified MM2 game raw keys.
        fail_closed(s)
    def test_unsupported_identity_publisher_proof_never_promoted(self):
        s=copy.deepcopy(SNAP)
        s["safety"]["sourceNamesMappedToGameKeys"]=True
        x=M.calculate(row("Gingerscope"),row("Chroma Emberscythe"),snapshot=s)
        self.assertEqual(x["status"],"REJECTED")
        self.assertEqual(x["reason"],"SOURCE_UNTRUSTED_AUTHORITY")
        fail_closed(x)
    def test_unknown_items_slots_and_quantities_are_rejected(self):
        attacks=[
            (row("UNKNOWN"),row("Harvester")),
            ([],row("Harvester")),
            (row("Harvester"),[]),
            ([{"displayName":"Harvester","quantity":True}],row("Icepiercer")),
            ([{"displayName":"Harvester","quantity":-1}],row("Icepiercer")),
            ([{"displayName":"Harvester","quantity":21}],row("Icepiercer")),
            (row("Harvester")*5,row("Icepiercer")),
        ]
        for a,b in attacks:
            x=M.calculate(a,b,snapshot=SNAP)
            self.assertEqual(x["status"],"REJECTED")
            fail_closed(x)
    def test_600_mutated_source_evidence_fails_closed_or_rejects(self):
        rng=random.Random(6059)
        for i in range(600):
            snapshot=copy.deepcopy(SNAP)
            side=rng.randrange(10)
            d=snapshot["records"][side]
            mode=i%12
            if mode==0:snapshot["safety"]["authorizesTrade"]=True
            elif mode==1:snapshot["safety"]["mayReportProfit"]=True
            elif mode==2:d["tradeAuthority"]=True
            elif mode==3:d["rawKeyCheckerIdentityAttested"]=True
            elif mode==4:d["supremeListedValue"]=-1
            elif mode==5:d["mm2valuesListedValue"]="UNKNOWN"
            elif mode==6:d["displayName"]="Harvester" # Could equal current name
            elif mode==7:snapshot["observedDateUtc"]="2099-01-01"
            elif mode==8:snapshot["records"].pop()
            elif mode==9:snapshot["schema"]="LIVE_AUTHENTICATED"
            elif mode==10:d["supremeListedValue"]=False
            elif mode==11:d["mm2valuesListedValue"]=1000001
            x=M.calculate(row("Emberbow"),row("Emberscythe"),snapshot=snapshot)
            # Display-name-only model must never authorize a client/server trade,
            # even if a malicious but arithmetic-looking snapshot is passed in.
            fail_closed(x)
            if mode in (0,1,2,3,4,5,7,8,9,10,11):
                self.assertEqual(x["status"],"REJECTED",(i,x))
    def test_source_bounds_contain_single_site_projected_gains(self):
        names=[r["displayName"] for r in SNAP["records"]]
        rng=random.Random(2208)
        for _ in range(500):
            a=rng.choice(names)
            b=rng.choice(names)
            quantity=rng.randrange(1,5)
            x=M.calculate(row(a,quantity),row(b,quantity),snapshot=SNAP)
            if x["status"]=="REJECTED":
                self.fail(str(x))
            for result in x["perSourceListedGain"].values():
                self.assertLessEqual(x["minListedGain"],result)
                self.assertLessEqual(result,x["maxListedGain"])
            fail_closed(x)

if __name__=="__main__":
    unittest.main()
