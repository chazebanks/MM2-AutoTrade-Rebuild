"""Stage86 actual PR106 planner → PR105 guard contract integration tests.

Every key, market price, counterparty, session and proposal is SYNTHETIC.
No MM2, Roblox, executor, server, trade, settlement or market call.
"""
from __future__ import annotations

from copy import deepcopy
import importlib.util
import os
from pathlib import Path
import random
import unittest

ROOT=Path(__file__).resolve().parents[2]
FILE=ROOT/"pdiddler/intelligence_lab/stage86_planner_guard_dryrun.py"
SPEC=importlib.util.spec_from_file_location("stage86",FILE)
assert SPEC and SPEC.loader
S=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(S)
NOW=1794159000

def row(key,quantity=1):
    return {"key":key,"quantity":quantity}

def market(items=None):
    def e(v,dem=6,liq=6,stab="Stable"):
        return {"value":v,"demand":dem,"liquidity":liq,"stability":stab,
                "identityLinkEvidence":"INDEPENDENT_EXACT"}
    return {
        "source":"SUPREME_DISPLAY_RESEARCH_ONLY",
        "version":S.MARKET_VERSION,
        "publisherUpdatedAtUnix":NOW-100,"retrievedAtUnix":NOW-5,
        "items":items or {"test_ours":e(100),"test_theirs":e(105)},
    }

def binding():
    return {"sessionId":"test_session","jobId":"test_job",
            "partnerKey":"test_partner","offerRevision":17,
            "fixtureKind":"SYNTHETIC_OFFLINE_TEST"}

class Stage86(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.p=Path(os.environ.get("STAGE86_ORIGINAL_PLANNER","/not/provided"))
        cls.g=Path(os.environ.get("STAGE86_ORIGINAL_GUARD","/not/provided"))
        if os.environ.get("STAGE86_REQUIRE_PINNED")=="1":
            assert cls.p.is_file() and cls.g.is_file(),"Missing original source dependencies"
        if not (cls.p.is_file() and cls.g.is_file()):
            cls.sources_ready=False
        else:
            assert S.git_blob(cls.p.read_bytes())==S.PLANNER_BLOB
            assert S.git_blob(cls.g.read_bytes())==S.GUARD_BLOB
            cls.sources_ready=True

    def require_sources(self):
        if not self.sources_ready:
            self.skipTest("Only focused CI provides BOTH original immutable modules")

    def safe(self,r):
        for k,v in S.FALSE.items():
            self.assertEqual(r[k],v,k)
        self.assertNotIn("test_session",str({k:v for k,v in r.items()
            if k not in ("proposal",)}))
        self.assertNotIn("test_partner",str({k:v for k,v in r.items()
            if k not in ("proposal",)}))

    def propose(self,ours=None,theirs=None,m=None,b=None,now=NOW):
        self.require_sources()
        r=S.propose(
            ours if ours is not None else [row("test_ours")],
            theirs if theirs is not None else [row("test_theirs")],
            m if m is not None else market(),
            b if b is not None else binding(),
            now=now,planner_path=self.p,guard_path=self.g)
        self.safe(r)
        return r

    def verify(self,p,obs=None,m=None,now=NOW):
        self.require_sources()
        r=S.verify(p,obs,m if m is not None else market(),now=now,guard_path=self.g)
        self.safe(r)
        return r

    def test_pinned_source_files_are_real_and_distinct(self):
        self.require_sources()
        self.assertEqual(S.git_blob(self.p.read_bytes()),S.PLANNER_BLOB)
        self.assertEqual(S.git_blob(self.g.read_bytes()),S.GUARD_BLOB)
        self.assertNotEqual(S.PLANNER_BLOB,S.GUARD_BLOB)

    def test_plus_five_sidegrade_proposal_and_guard_manual_only(self):
        p=self.propose()
        self.assertEqual(p["status"],"SYNTHETIC_PROPOSAL_READY")
        self.assertEqual(p["listedGainResearchOnly"],5)
        self.assertEqual(p["candidateKind"],"SIDEGRADE")
        self.assertEqual(p["proposal"]["ours"],[{"index":1,"key":"test_ours","quantity":1}])
        self.assertEqual(p["proposal"]["theirs"],[{"index":1,"key":"test_theirs","quantity":1}])
        r=self.verify(p,S.synthetic_observation(p["proposal"],NOW))
        self.assertEqual(r["status"],"IDEAL_SYNTHETIC_SNAPSHOT_MATCH_ONLY")
        self.assertEqual(r["listedGainResearchOnly"],5)

    def test_two_small_items_into_one_upgrade(self):
        e=lambda v:{"value":v,"demand":6,"liquidity":6,"stability":"Stable",
                    "identityLinkEvidence":"INDEPENDENT_EXACT"}
        m=market({"test_a":e(50),"test_b":e(50),"test_strong":e(105)})
        p=self.propose([row("test_a"),row("test_b")],[row("test_strong")],m)
        self.assertEqual(p["status"],"SYNTHETIC_PROPOSAL_READY",p)
        self.assertEqual(p["candidateKind"],"UPGRADE")
        self.assertEqual(sum(i["quantity"] for i in p["proposal"]["ours"]),2)
        self.assertEqual(sum(i["quantity"] for i in p["proposal"]["theirs"]),1)
        r=self.verify(p,S.synthetic_observation(p["proposal"],NOW),m)
        self.assertEqual(r["status"],"IDEAL_SYNTHETIC_SNAPSHOT_MATCH_ONLY")

    def test_one_strong_item_into_two_downgrade(self):
        e=lambda v:{"value":v,"demand":7,"liquidity":8,"stability":"Stable",
                    "identityLinkEvidence":"INDEPENDENT_EXACT"}
        m=market({"test_strong":e(100),"test_a":e(55),"test_b":e(55)})
        p=self.propose([row("test_strong")],[row("test_a"),row("test_b")],m)
        self.assertEqual(p["status"],"SYNTHETIC_PROPOSAL_READY",p)
        self.assertEqual(p["candidateKind"],"DOWNGRADE")
        self.assertEqual(sum(i["quantity"] for i in p["proposal"]["theirs"]),2)
        r=self.verify(p,S.synthetic_observation(p["proposal"],NOW),m)
        self.assertEqual(r["status"],"IDEAL_SYNTHETIC_SNAPSHOT_MATCH_ONLY")

    def test_opponent_removes_item_after_positive_display(self):
        p=self.propose()
        obs=S.synthetic_observation(p["proposal"],NOW)
        obs["theirs"]=[]
        result=self.verify(p,obs)
        self.assertEqual(result["status"],"REJECTED_REPLAN_REQUIRED")
        self.assertEqual(result["reason"],"OFFER_SLOTS_UNREADABLE_OR_EMPTY")

    def test_offer_revision_change_invalidates_frozen_candidate(self):
        p=self.propose()
        obs=S.synthetic_observation(p["proposal"],NOW)
        obs["offerRevision"]+=1
        result=self.verify(p,obs)
        self.assertEqual(result["reason"],"OFFER_REVISION_CHANGED")

    def test_same_revision_different_stack_or_slot_refused(self):
        p=self.propose()
        obs=S.synthetic_observation(p["proposal"],NOW)
        obs["theirs"][0]["quantity"]=2
        self.assertEqual(self.verify(p,obs)["reason"],"OFFER_SLOTS_CHANGED")
        obs=S.synthetic_observation(p["proposal"],NOW)
        obs["theirs"][0]["index"]=2
        self.assertEqual(self.verify(p,obs)["reason"],"OFFER_SLOTS_CHANGED")

    def test_partner_server_and_catalogue_binding_changes_block(self):
        p=self.propose()
        for attr in ("partnerKey","jobId","sessionId","catalogVersion"):
            with self.subTest(field=attr):
                obs=S.synthetic_observation(p["proposal"],NOW)
                obs[attr]="test_changed"
                r=self.verify(p,obs)
                self.assertEqual(r["status"],"REJECTED_REPLAN_REQUIRED")

    def test_accepted_pending_stale_or_closed_offer_refused(self):
        p=self.propose()
        for attr,value in (("ourAccepted",True),("theirAccepted",None),
                           ("offerMutationPending",True),("tradeOpen",False),
                           ("exactPartnerBound",False),("observedAtUnix",NOW-10)):
            with self.subTest(field=attr):
                obs=S.synthetic_observation(p["proposal"],NOW)
                obs[attr]=value
                r=self.verify(p,obs)
                self.assertEqual(r["status"],"REJECTED_REPLAN_REQUIRED")

    def test_unknown_identity_price_freshness_and_low_liquidity_refuse_proposal(self):
        variants=[]
        x=market();x["items"]["test_ours"]["identityLinkEvidence"]="UNVERIFIED";variants.append(x)
        x=market();x["publisherUpdatedAtUnix"]=NOW-49*3600;variants.append(x)
        x=market();x["items"]["test_theirs"]["liquidity"]=1;variants.append(x)
        x=market();x["items"]["test_theirs"]["stability"]="Declining";variants.append(x)
        for m in variants:
            with self.subTest(market=m):
                r=self.propose(m=m)
                self.assertEqual(r["status"],"NO_PROPOSAL",r)

    def test_never_use_real_accounts_or_non_synthetic_prices(self):
        for name in ("Gingerscope","MY_PRIVATE_KEY","venossgaming90190","test"):
            p=self.propose(ours=[row(name)])
            self.assertEqual(p["status"],"BLOCKED")
            self.assertEqual(p["reason"],"NON_SYNTHETIC_OR_INVALID_INPUT")
        x=market();x["version"]="STAGE84_LIVE_190"
        p=self.propose(m=x)
        self.assertEqual(p["status"],"BLOCKED")
        x=market();x["source"]="REAL_ROBLOX"
        self.assertEqual(self.propose(m=x)["status"],"BLOCKED")
        b=binding();b["fixtureKind"]="LIVE_GAME"
        self.assertEqual(self.propose(b=b)["status"],"BLOCKED")

    def test_both_original_modules_reject_tampered_git_bytes(self):
        self.require_sources()
        with __import__("tempfile").TemporaryDirectory() as folder:
            alt=Path(folder)/"planner.py"
            alt.write_bytes(self.p.read_bytes()+b"\n# modified")
            r=S.propose([row("test_ours")],[row("test_theirs")],market(),binding(),
                         now=NOW,planner_path=alt,guard_path=self.g)
            self.assertEqual(r["status"],"BLOCKED")
            self.assertEqual(r["reason"],"ORIGINAL_COMPONENT_PROVENANCE_FAILED")

    def test_500_seeded_snapshot_changes_never_claim_a_trade(self):
        p=self.propose()
        rng=random.Random(8604)
        for i in range(500):
            obs=S.synthetic_observation(p["proposal"],NOW)
            mutation=i%10
            if mutation==0:obs["offerRevision"]+=1
            elif mutation==1:obs["theirs"]=[]
            elif mutation==2:obs["ours"][0]["quantity"]+=1
            elif mutation==3:obs["theirs"][0]["key"]="test_changed"
            elif mutation==4:obs["jobId"]="test_wrong_job"
            elif mutation==5:obs["partnerKey"]="test_wrong_partner"
            elif mutation==6:obs["tradeOpen"]=False
            elif mutation==7:obs["ourAccepted"]=True
            elif mutation==8:obs["theirAccepted"]=True
            else:obs["offerMutationPending"]=True
            r=self.verify(p,obs)
            with self.subTest(i=i):
                self.assertEqual(r["status"],"REJECTED_REPLAN_REQUIRED",r)
                self.assertIs(r["authorizesAccept"],False)

    def test_no_game_calls_or_raw_trade_authority_in_adapter(self):
        s=FILE.read_text()
        for forbidden in ("FireServer(","InvokeServer(","GetProfileData(",
                          "AcceptTrade","TeleportService","PostAsync(",
                          "requests.get(","getconnections("):
            self.assertNotIn(forbidden,s)
        self.assertIn('"manualFinalAcceptRequired":True',s)
        self.assertIn('"actualGameOfferExecuted":False',s)

if __name__=="__main__":
    unittest.main()
