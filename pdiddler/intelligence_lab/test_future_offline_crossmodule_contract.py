"""Cross-PR Gingerscope offline protocol contract: shortlist -> planner ->
snapshot guard -> unsent Discord preview. Exact pinned, read-only source commits.

NONE of the inputs or 'proof' strings is authenticated. Even a synthetic
cross-module PASS NEVER enables trade, Accept, settlement, market learning,
Discord posting, or realized profit reporting.
"""
from __future__ import annotations

import copy
import importlib.util
from pathlib import Path
import random
import subprocess
import unittest

REPO=Path(__file__).resolve().parents[2]
PINNED={
    "pr105":"44375d272826aadc6f22fcb180275c87cf5bf5c3",
    "pr106":"85bd69065ebf4b942d809c41a7c27959bf50f273",
    "pr109":"9b831a1e9c2d09ac864e91e3fb7855e7943c2dad",
    "pr110":"c02d5b7c17350cdb95dd6cb43ed7cd8ecb9e7dfc",
}
NAMES={
    "pr105":"offer_snapshot_guard.py",
    "pr106":"future_portfolio_planner.py",
    "pr109":"future_discord_trade_preview.py",
    "pr110":"future_full_inventory_shortlist.py",
}
NOW=1_794_159_000

def load_module(label):
    root=REPO/".offline_sources"/label
    path=root/"pdiddler"/"intelligence_lab"/NAMES[label]
    if not path.is_file():
        raise AssertionError(f"missing pinned source checkout {label}; no fallback to main: {path}")
    actual=subprocess.check_output(["git","-C",str(root),"rev-parse","HEAD"],text=True).strip()
    if actual!=PINNED[label]:
        raise AssertionError(f"source commit mismatch for {label}: {actual}, required {PINNED[label]}")
    spec=importlib.util.spec_from_file_location("contract_"+label,path)
    assert spec and spec.loader
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

def synthetic():
    # Entire catalogue is SYNTHETIC. This literal is a test fixture and
    # explicitly NOT authenticated Stage53-58 live weapon identity.
    def item(value,demand=8,liquidity=8):
        return {"identityLinkEvidence":"INDEPENDENT_EXACT","value":value,
                "demand":demand,"liquidity":liquidity,"stability":"Stable"}
    market={"source":"SUPREME_DISPLAY_RESEARCH_ONLY","version":"SIMULATED-NOV08",
            "publisherUpdatedAtUnix":NOW-100,"retrievedAtUnix":NOW-2,
            "items":{
                "OwnA":item(100),"OwnB":item(200),"OwnC":item(80),
                "TheirA":item(110),"TheirB":item(230),
                "TheirC":item(90),"TheirD":item(400)}}
    own=[{"key":"OwnA","quantity":1},{"key":"OwnB","quantity":1},
         {"key":"OwnC","quantity":1}]
    theirs=[{"key":"TheirA","quantity":1},{"key":"TheirB","quantity":1},
            {"key":"TheirC","quantity":1},{"key":"TheirD","quantity":1}]
    return own,theirs,market

def assert_never_authority(tc,output):
    for k in ("authorizesTrade","authorizesAccept","serverCompletionProven",
              "mayReportProfit"):
        tc.assertIs(output[k],False,(k,output))
    for k in ("mayRecordCompletedTrade","mayUseForStrategyLearning"):
        if k in output: tc.assertIs(output[k],False,(k,output))
    if "tradeOutcome" in output:
        tc.assertEqual(output["tradeOutcome"],"UNKNOWN")

def exact_snapshot(candidate,market):
    def convert(key):
        return [{"index":i,"key":row["key"],"quantity":row["quantity"]}
                for i,row in enumerate(candidate[key],1)]
    base={"sessionId":"SYNTHEST-SESSION","jobId":"SYNTHEST-JOB",
          "partnerKey":"OPAQUE-SIMULATED","catalogVersion":market["version"],
          "offerRevision":7,"observedAtUnix":NOW-1,
          "ours":convert("offer"),"theirs":convert("receive")}
    observed={**copy.deepcopy(base),"observedAtUnix":NOW,
              "tradeOpen":True,"exactPartnerBound":True,
              "ourAccepted":False,"theirAccepted":False,
              "offerMutationPending":False}
    return base,observed

def preview_payload(candidate,market,starting_value):
    def to_rows(key):
        return [{"name":r["key"],"quantity":r["quantity"],
                 "listedValue":market["items"][r["key"]]["value"],
                 "demand":market["items"][r["key"]]["demand"],
                 "liquidity":market["items"][r["key"]]["liquidity"],
                 "stability":market["items"][r["key"]]["stability"]}
                for r in candidate[key]]
    return {"gave":to_rows("offer"),"received":to_rows("receive"),
            "startingInventoryListedValue":starting_value,
            "catalogVersion":market["version"]}

class OfflineCrossModuleContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.selector=load_module("pr110")
        cls.planner=load_module("pr106")
        cls.guard=load_module("pr105")
        cls.preview=load_module("pr109")

    def chain(self,own,theirs,market):
        selected=self.selector.shortlist(own,theirs,market,now=NOW)
        assert_never_authority(self,selected)
        self.assertEqual(selected["status"],"RESEARCH_SHORTLIST_ONLY",selected)
        self.assertTrue(selected["ourShortlist"] and selected["theirShortlist"])
        self.assertLessEqual(len(selected["ourShortlist"]),5)
        self.assertLessEqual(len(selected["theirShortlist"]),5)
        planned=self.planner.plan(selected["ourShortlist"],selected["theirShortlist"],
                                  market,now=NOW,max_results=10)
        assert_never_authority(self,planned)
        self.assertEqual(planned["status"],"CANDIDATES_PREPARED",planned)
        return selected,planned

    def test_full_synthetic_chain_is_consistent_without_authority(self):
        own,theirs,market=synthetic()
        before=copy.deepcopy((own,theirs,market))
        selected,planned=self.chain(own,theirs,market)
        starting=sum(market["items"][r["key"]]["value"]*r["quantity"] for r in own)
        self.assertGreaterEqual(len(planned["candidates"]),1)
        for candidate in planned["candidates"]:
            self.assertLessEqual(len(candidate["offer"]),4)
            self.assertLessEqual(len(candidate["receive"]),4)
            proposal,observed=exact_snapshot(candidate,market)
            inspected=self.guard.evaluate(proposal,observed,market,now=NOW)
            assert_never_authority(self,inspected)
            self.assertEqual(inspected["status"],"RESEARCH_CANDIDATE_ONLY",inspected)
            self.assertEqual(inspected["projectedListedGain"],
                             candidate["projectedListedGain"])
            self.assertEqual(inspected["valueOffered"],candidate["offeredListedValue"])
            self.assertEqual(inspected["valueRequested"],candidate["receivedListedValue"])
            report=self.preview.build_preview(preview_payload(candidate,market,starting))
            assert_never_authority(self,report)
            self.assertIs(report["maySendWebhook"],False)
            self.assertEqual(report["status"],"PREVIEW_ONLY",report)
            self.assertIn("NOT VERIFIED",report["embedPreview"]["title"])
            self.assertIn("NOT realized profit",
                          report["embedPreview"]["fields"][2]["value"])
            self.assertIn("NOT a verified inventory readback",
                          report["embedPreview"]["fields"][3]["value"])
        self.assertEqual(before,(own,theirs,market),"pure modules mutated inputs")

    def test_unverified_identity_does_not_enter_shortlist_or_planner(self):
        own,theirs,market=synthetic()
        for item in market["items"].values():
            item["identityLinkEvidence"]="PROVISIONAL"
        selected=self.selector.shortlist(own,theirs,market,now=NOW)
        self.assertEqual(selected["status"],"NO_USABLE_OWN_PROFILE")
        self.assertEqual(selected["ourShortlist"],[])
        assert_never_authority(self,selected)
        planned=self.planner.plan(own,theirs,market,now=NOW)
        self.assertEqual(planned["status"],"BLOCKED")
        assert_never_authority(self,planned)

        _,_,good_market=synthetic()
        trial={"offer":[{"key":"OwnA","quantity":1}],
               "receive":[{"key":"TheirA","quantity":1}]}
        proposal,seen=exact_snapshot(trial,good_market)
        good_market["items"]["TheirA"]["identityLinkEvidence"]="PROVISIONAL"
        rejected=self.guard.evaluate(proposal,seen,good_market,now=NOW)
        self.assertEqual(rejected["reason"],"RAW_KEY_TO_DISPLAY_ID_UNVERIFIED")
        assert_never_authority(self,rejected)

    def test_mutation_revision_price_and_accept_invalidated_1000_cases(self):
        own,theirs,market=synthetic()
        _,p=self.chain(own,theirs,market)
        candidate=p["candidates"][0]
        rand=random.Random(20261108)
        for index in range(1000):
            catalog=copy.deepcopy(market)
            proposal,seen=exact_snapshot(candidate,catalog)
            side=index%18
            if side==0: seen["offerRevision"]+=1
            elif side==1: seen["sessionId"]="new"
            elif side==2: seen["jobId"]="new"
            elif side==3: seen["partnerKey"]="new"
            elif side==4: seen["tradeOpen"]=False
            elif side==5: seen["exactPartnerBound"]=False
            elif side==6: seen["theirAccepted"]=True
            elif side==7: seen["ourAccepted"]=True
            elif side==8: seen["offerMutationPending"]=True
            elif side==9: seen["observedAtUnix"]=NOW-12
            elif side==10: proposal["theirs"][0]["quantity"]+=1
            elif side==11: seen["ours"][0]["quantity"]+=1
            elif side==12: seen["theirs"][0]["key"]="OwnA"
            elif side==13: catalog["source"]="OTHER"
            elif side==14: catalog["publisherUpdatedAtUnix"]=NOW-200000
            elif side==15: catalog["items"][candidate["receive"][0]["key"]]["identityLinkEvidence"]="NOT_PROVEN"
            elif side==16: catalog["items"][candidate["receive"][0]["key"]]["demand"]=1
            else: catalog["items"][candidate["receive"][0]["key"]]["stability"]="Declining"
            result=self.guard.evaluate(proposal,seen,catalog,now=NOW)
            self.assertEqual(result["status"],"REJECTED",(index,result))
            assert_never_authority(self,result)

    def test_no_real_inventory_or_trade_report_from_chain(self):
        own,theirs,market=synthetic()
        selected,planned=self.chain(own,theirs,market)
        self.assertFalse(selected["fullInventoryOptimizationProven"])
        self.assertFalse(planned["globalInventoryOptimalityProven"])
        self.assertFalse(planned["counterpartyConsentProven"])
        self.assertFalse(planned["weaponIdentityAuthenticated"])
        for c in planned["candidates"]:
            self.assertNotIn("serverTransactionId",c)
            self.assertNotIn("completedTrade",c)
            self.assertNotIn("webhookToken",c)

if __name__=="__main__":
    unittest.main()
