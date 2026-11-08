"""Full inventory shortlist offline deterministic/adversarial tests."""
import copy
import importlib.util
import random
import unittest
from pathlib import Path
ROOT=Path(__file__).parent
SPEC=importlib.util.spec_from_file_location("shortlist",ROOT/"future_full_inventory_shortlist.py")
MOD=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MOD)
NOW=1794159000
def entry(value=100,d=6,l=6,s="Stable",identity="INDEPENDENT_EXACT"):
    return {"value":value,"demand":d,"liquidity":l,"stability":s,
            "identityLinkEvidence":identity}
def fixture(nown=10,ntheir=12):
    ours=[{"key":f"a{i:03d}","quantity":1+(i%4)} for i in range(nown)]
    theirs=[{"key":f"b{i:03d}","quantity":1+(i%3)} for i in range(ntheir)]
    items={x["key"]:entry(20+(i*31)%600) for i,x in enumerate(ours)}
    items.update({x["key"]:entry(25+(i*37)%650) for i,x in enumerate(theirs)})
    market={"version":"SYNTHETIC-V1","source":"SUPREME_DISPLAY_RESEARCH_ONLY",
            "publisherUpdatedAtUnix":NOW-100,
            "retrievedAtUnix":NOW-10,"items":items}
    return ours,theirs,market
def safe(v):
    assert v["tradeOutcome"]=="UNKNOWN"
    for k in ("shortlistCoverageComplete","fullInventoryOptimizationProven",
              "counterpartyInventoryAuthenticated","weaponIdentityAuthenticated",
              "serverCompletionProven","authorizesTrade","authorizesAccept",
              "mayReportProfit","mayUseForStrategyLearning"):
        assert v[k] is False,(k,v)

class ShortlistTests(unittest.TestCase):
    def check(self,data=None,**kwargs):
        a,b,m=data or fixture()
        out=MOD.shortlist(a,b,m,now=NOW,**kwargs);safe(out)
        return out

    def test_112_type_inventory_382_copy_scale(self):
        a,b,m=fixture(112,60)
        # Raise quantity from 1-4 to about three; no overflow.
        for i,row in enumerate(a):
            row["quantity"]=2+(i%3)
        out=self.check((a,b,m))
        self.assertEqual(out["status"],"RESEARCH_SHORTLIST_ONLY")
        self.assertEqual(out["counts"]["ourInput"],112)
        self.assertEqual(out["counts"]["theirInput"],60)
        self.assertLessEqual(len(out["ourShortlist"]),5)
        self.assertLessEqual(len(out["theirShortlist"]),5)
        self.assertGreater(out["counts"]["ourQuantityCapped"],0)
        self.assertTrue(all(z["quantity"]<=2 for z in out["ourShortlist"]))
        self.assertEqual(out["counts"]["ourInput"],
                         out["counts"]["ourExcludedIdentityOrProfile"]+
                         out["counts"]["ourNotSelected"]+len(out["ourShortlist"]))
        self.assertEqual(out["counts"]["theirInput"],
                         out["counts"]["theirExcludedIdentityOrProfile"]+
                         out["counts"]["theirExcludedMarketOrBudget"]+
                         out["counts"]["theirNotSelected"]+len(out["theirShortlist"]))

    def test_always_deterministic_and_nonmutating(self):
        a,b,m=fixture(30,30)
        initial=copy.deepcopy((a,b,m))
        self.assertEqual(self.check((a,b,m)),self.check((a,b,m)))
        self.assertEqual((a,b,m),initial)

    def test_no_real_mapping_means_no_false_candidates(self):
        a,b,m=fixture()
        for e in m["items"].values():e["identityLinkEvidence"]="PROVISIONAL"
        x=self.check((a,b,m))
        self.assertEqual(x["status"],"NO_USABLE_OWN_PROFILE")
        self.assertEqual(x["ourShortlist"],[])

    def test_gingerscope_far_beyond_inventory_bounds_excluded(self):
        a,b,m=fixture(6,4)
        for row in a:m["items"][row["key"]]=entry(90)
        b.append({"key":"Gingerscope","quantity":1})
        m["items"]["Gingerscope"]=entry(16000,d=5,l=5)
        x=self.check((a,b,m))
        self.assertEqual(x["status"],"RESEARCH_SHORTLIST_ONLY")
        self.assertNotIn("Gingerscope",[z["key"] for z in x["theirShortlist"]])
        self.assertGreater(x["counts"]["theirExcludedMarketOrBudget"],0)
        self.assertLess(x["theoreticalMaxListedOffer"],16000)

    def test_four_value_bands_preserved_when_possible(self):
        a=[{"key":f"a{i}","quantity":1} for i in range(5)]
        b=[{"key":f"b{i}","quantity":1} for i in range(3)]
        m=fixture(1,1)[2]
        m["items"]={f"a{i}":entry(v) for i,v in enumerate([10,25,50,85,100])}
        m["items"].update({f"b{i}":entry(v) for i,v in enumerate([15,50,90])})
        x=self.check((a,b,m))
        self.assertEqual(x["status"],"RESEARCH_SHORTLIST_ONLY")
        self.assertEqual(len(x["ourShortlist"]),5)
        self.assertEqual(set(z["key"] for z in x["ourShortlist"]),{z["key"] for z in a})

    def test_invalid_source_and_malformed_pool_never_emit_shortlist(self):
        a,b,m=fixture()
        a.append(copy.deepcopy(a[0]))
        x=self.check((a,b,m))
        self.assertEqual(x["status"],"BLOCKED")
        a,b,m=fixture()
        m["publisherUpdatedAtUnix"]=None
        x=self.check((a,b,m))
        self.assertEqual(x["status"],"BLOCKED")
        a,b,m=fixture()
        a=a*60
        x=self.check((a,b,m))
        self.assertEqual(x["status"],"BLOCKED")

    def test_market_uncertainty_is_explicitly_counted(self):
        a,b,m=fixture()
        m["items"]["a000"]["identityLinkEvidence"]="UNVERIFIED"
        m["items"]["b000"]["demand"]=0
        x=self.check((a,b,m))
        self.assertEqual(x["counts"]["ourExcludedIdentityOrProfile"],1)
        self.assertEqual(x["counts"]["theirExcludedIdentityOrProfile"],1)
        self.assertNotIn("a000",[z["key"] for z in x["ourShortlist"]])

    def test_1000_bad_inputs_stay_non_authoritative(self):
        rng=random.Random(6089)
        for i in range(1000):
            a,b,m=fixture()
            v=i%10
            if v==0:a[0]["quantity"]=True
            elif v==1:a[0]["quantity"]=0
            elif v==2:b[0]["key"]=""
            elif v==3:b[0]["quantity"]=101
            elif v==4:a[0]=None
            elif v==5:m["publisherUpdatedAtUnix"]=NOW+1
            elif v==6:m["source"]="UNKNOWN"
            elif v==7:m["items"]=None
            elif v==8:a[0]["key"]=rng.choice(["","a001"])
            elif v==9:b.append(copy.deepcopy(b[0]))
            out=self.check((a,b,m))
            self.assertEqual(out["status"],"BLOCKED",(i,out))

    def test_no_live_game_calls_or_server_auth(self):
        s=(ROOT/"future_full_inventory_shortlist.py").read_text()
        for x in ("HttpGet(","FireServer(", "InvokeServer(", "Teleport",
                  "requests.get(", "PostAsync(", "setclipboard("):
            self.assertNotIn(x,s)

if __name__=="__main__":
    unittest.main()
