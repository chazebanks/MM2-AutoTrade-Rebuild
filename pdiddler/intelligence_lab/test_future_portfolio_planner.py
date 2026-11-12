"""Offline future Gingerscope upgrade/downgrade planner contract tests."""
from __future__ import annotations
import copy
import importlib.util
import random
import unittest
from pathlib import Path

ROOT=Path(__file__).parent
SPEC=importlib.util.spec_from_file_location("future_portfolio_planner",ROOT/"future_portfolio_planner.py")
MOD=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MOD)
NOW=1794159000


def entry(value, demand=6, liquidity=6, stability="Stable",identity="INDEPENDENT_EXACT"):
    # Purely synthetic provenance; not a real ID authority.
    return {"value":value,"demand":demand,"liquidity":liquidity,
            "stability":stability,"identityLinkEvidence":identity}


def sample():
    mine=[{"key":"mine","quantity":1}]
    theirs=[{"key":"theirs","quantity":1}]
    market={"source":"SUPREME_DISPLAY_RESEARCH_ONLY",
            "version":"SYNTHETIC-NEVER-LIVE",
            "publisherUpdatedAtUnix":NOW-100,"retrievedAtUnix":NOW-5,
            "items":{"mine":entry(100),"theirs":entry(105)}}
    return mine,theirs,market


def no_authority(r):
    assert r["tradeOutcome"]=="UNKNOWN"
    for key in ("globalInventoryOptimalityProven","counterpartyConsentProven",
                "weaponIdentityAuthenticated","serverCompletionProven",
                "mayRecordCompletedTrade","mayUseForStrategyLearning",
                "mayReportProfit","authorizesTrade","authorizesAccept"):
        assert r[key] is False,(key,r)


class FuturePortfolioPlannerTests(unittest.TestCase):
    def run_plan(self,inputs=None,**kw):
        a,b,m=inputs or sample()
        result=MOD.plan(a,b,m,now=NOW,**kw)
        no_authority(result)
        return result

    def test_small_gain_does_not_inherit_legacy_plus_15(self):
        x=self.run_plan()
        self.assertEqual(x["status"],"CANDIDATES_PREPARED")
        self.assertEqual(x["candidates"][0]["projectedListedGain"],5)
        self.assertEqual(x["candidates"][0]["type"],"SIDEGRADE")
        self.assertTrue(x["enumerationCompleteForProvidedShortlists"])

    def test_two_smalls_into_one_upgrade(self):
        a=[{"key":"a","quantity":1},{"key":"b","quantity":1}]
        b=[{"key":"strong","quantity":1}]
        m=sample()[2]
        m["items"]={"a":entry(50),"b":entry(50),"strong":entry(105)}
        x=self.run_plan((a,b,m))
        self.assertEqual(x["status"],"CANDIDATES_PREPARED")
        self.assertEqual(x["candidates"][0]["type"],"UPGRADE")
        self.assertEqual(sum(z["quantity"] for z in x["candidates"][0]["offer"]),2)

    def test_one_into_two_downgrade(self):
        a=[{"key":"strong","quantity":1}]
        b=[{"key":"a","quantity":1},{"key":"b","quantity":1}]
        m=sample()[2]
        m["items"]={"strong":entry(100),"a":entry(55),"b":entry(55)}
        x=self.run_plan((a,b,m))
        self.assertEqual(x["status"],"CANDIDATES_PREPARED")
        self.assertEqual(x["candidates"][0]["type"],"DOWNGRADE")

    def test_stack_quantity_and_capacity_immutable(self):
        a,b,m=sample()
        a[0]["quantity"]=2
        b[0]["quantity"]=2
        x=self.run_plan((a,b,m))
        self.assertEqual(x["status"],"CANDIDATES_PREPARED")
        for proposed in x["candidates"]:
            self.assertLessEqual(len(proposed["offer"]),4)
            self.assertLessEqual(len(proposed["receive"]),4)
            self.assertTrue(all(1<=z["quantity"]<=2 for z in proposed["offer"]))
        self.assertEqual(a[0]["quantity"],2)

    def test_regression_four_physical_slots_can_hold_eight_stacked_copies(self):
        # Exactly four occupied trade slots, two copies per slot; the old
        # total-copy <=4 cap wrongly rejects this unique positive proposal.
        ours=[{"key":k,"quantity":2} for k in ("a","b","c","d")]
        theirs=[{"key":"target","quantity":1}]
        market=sample()[2]
        market["items"]={k:entry(5) for k in ("a","b","c","d")}
        market["items"]["target"]=entry(60)
        x=self.run_plan((ours,theirs,market))
        self.assertEqual(x["status"],"CANDIDATES_PREPARED")
        c=x["candidates"][0]
        self.assertEqual(len(c["offer"]),4)
        self.assertEqual(sum(z["quantity"] for z in c["offer"]),8)
        self.assertEqual(c["projectedListedGain"],20)
        self.assertEqual(c["type"],"UPGRADE")
        self.assertTrue(x["enumerationCompleteForProvidedShortlists"])

    def test_no_silent_top_five_from_full_inventory(self):
        a,b,m=sample()
        a=[{"key":f"item-{i}","quantity":1} for i in range(6)]
        x=self.run_plan((a,b,m))
        self.assertEqual(x["status"],"BLOCKED")
        self.assertEqual(x["reason"],"INVALID_OR_TOO_LARGE_INPUT_SHORTLIST")
        self.assertFalse(x["enumerationCompleteForProvidedShortlists"])

    def test_bad_identity_freshness_and_desirability(self):
        changes=[
            ("UNKNOWN_OR_UNPROVEN_ITEM_IDENTITY",
             lambda a,b,m:m["items"]["theirs"].__setitem__("identityLinkEvidence","PROVISIONAL")),
            ("PUBLISHER_EVIDENCE_MISSING_OR_EXPIRED",
             lambda a,b,m:m.__setitem__("publisherUpdatedAtUnix",None)),
            ("PUBLISHER_EVIDENCE_MISSING_OR_EXPIRED",
             lambda a,b,m:m.__setitem__("publisherUpdatedAtUnix",NOW-200000)),
            ("UNKNOWN_MARKET_VALUE_OR_DESIRABILITY",
             lambda a,b,m:m["items"]["theirs"].__setitem__("value",True)),
            ("NO_NONNEGATIVE_SAFE_RESEARCH_PROPOSAL",
             lambda a,b,m:m["items"]["theirs"].__setitem__("liquidity",1)),
            ("NO_NONNEGATIVE_SAFE_RESEARCH_PROPOSAL",
             lambda a,b,m:m["items"]["theirs"].__setitem__("stability","Declining")),
        ]
        for reason,change in changes:
            with self.subTest(reason=reason):
                a,b,m=sample();change(a,b,m)
                x=self.run_plan((a,b,m))
                self.assertEqual(x["reason"],reason)

    def test_cross_side_same_item_never_fake_concentration_gain(self):
        a,b,m=sample()
        b=[{"key":"mine","quantity":1}]
        x=self.run_plan((a,b,m))
        self.assertEqual(x["status"],"NO_CANDIDATES")

    def test_deterministic_and_no_mutation(self):
        a,b,m=sample()
        old=copy.deepcopy((a,b,m))
        x=self.run_plan((a,b,m),max_results=10)
        y=self.run_plan((a,b,m),max_results=10)
        self.assertEqual(x,y)
        self.assertEqual((a,b,m),old)

    def test_min_gain_policy_customizable_no_old_fixed_floor(self):
        x=self.run_plan(min_gain=5)
        self.assertEqual(x["status"],"CANDIDATES_PREPARED")
        x=self.run_plan(min_gain=15)
        self.assertEqual(x["status"],"NO_CANDIDATES")

    def test_one_side_with_5_types_search_bounded_and_complete(self):
        a=[{"key":f"a{i}","quantity":2} for i in range(5)]
        b=[{"key":f"b{i}","quantity":2} for i in range(5)]
        m=sample()[2]
        m["items"]={}
        for i in range(5):
            m["items"][f"a{i}"]=entry(50+i*5)
            m["items"][f"b{i}"]=entry(55+i*5)
        x=self.run_plan((a,b,m))
        self.assertEqual(x["status"],"CANDIDATES_PREPARED")
        self.assertLessEqual(x["candidatePairsConsidered"],9025)
        self.assertEqual(len(x["candidates"]),5)
        for candidate in x["candidates"]:
            for side in ("offer","receive"):
                self.assertLessEqual(sum(row["quantity"] for row in candidate[side]),4)

    def test_600_adversarial_inputs_never_authorize(self):
        rng=random.Random(6084)
        for i in range(600):
            a,b,m=sample()
            mode=i%12
            if mode==0:a[0]["quantity"]=rng.randrange(3,100)
            elif mode==1:b[0]["quantity"]=False
            elif mode==2:a.append(copy.deepcopy(a[0]))
            elif mode==3:m["items"]["theirs"]["demand"]=0
            elif mode==4:m["items"]["theirs"]["liquidity"]=0
            elif mode==5:m["items"]["theirs"]["value"]=10**30
            elif mode==6:m["source"]="UNPROVEN"
            elif mode==7:m["retrievedAtUnix"]=NOW+100
            elif mode==8:m["items"]["mine"]["identityLinkEvidence"]="GUESS"
            elif mode==9:b[0]["key"]=""
            elif mode==10:m["items"]["mine"]["value"]=rng.randrange(200,500)
            elif mode==11:m["items"]["theirs"]["stability"]="Declining"
            x=self.run_plan((a,b,m))
            self.assertIn(x["status"],{"BLOCKED","NO_CANDIDATES"},(i,x))
            self.assertFalse(x["enumerationCompleteForProvidedShortlists"] if x["status"]=="BLOCKED" else x["authorizesTrade"])

    def test_code_never_contacts_game_or_reports_settlement(self):
        source=(ROOT/"future_portfolio_planner.py").read_text()
        for token in (":FireServer(",":InvokeServer(","HttpGet(", "setclipboard(",
                      "AcceptTrade", "requests.get(", "PostAsync("):
            self.assertNotIn(token,source)
        self.assertIn('"serverCompletionProven": False',source)
        self.assertIn('"authorizesAccept": False',source)


if __name__=="__main__":
    unittest.main()
