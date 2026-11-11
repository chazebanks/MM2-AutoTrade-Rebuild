"""Stage120 REAL PR106 planner + corrected PR182 offer guard integration.

ALL inventory, source, offer, identity and session values are SYNTHETIC.
No game remotes, production adapters, public prices, or trade permissions.
"""
from __future__ import annotations
from copy import deepcopy
import importlib.util
from pathlib import Path
import os
import random
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
SPEC=importlib.util.spec_from_file_location(
    "stage120", ROOT/"pdiddler/intelligence_lab/stage120_corrected_guard_preview.py")
assert SPEC and SPEC.loader
M=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)
NOW=1794420000
PLAN=Path(os.getenv("STAGE120_PLANNER","/tmp/gingerscope-stage120/planner.py"))
GUARD=Path(os.getenv("STAGE120_CORRECTED_GUARD","/tmp/gingerscope-stage120/guard.py"))


def item(v, demand=6, liquidity=6, stability="Stable", identity="INDEPENDENT_EXACT"):
    return {"value":v,"demand":demand,"liquidity":liquidity,
            "stability":stability,"identityLinkEvidence":identity}

def market(items=None):
    return {"source":"SUPREME_DISPLAY_RESEARCH_ONLY","version":M.MARKET_VERSION,
            "publisherUpdatedAtUnix":NOW-600,"retrievedAtUnix":NOW-3,
            "sourceValidUntilUnix":NOW+200,
            "items":items or {"test_ours":item(100),"test_theirs":item(105)}}

def rows(*pairs):
    return [{"key":k,"quantity":q} for k,q in pairs]

def binding():
    return {"fixtureKind":"SYNTHETIC_OFFLINE_TEST","sessionId":"test_session",
            "jobId":"test_job","partnerKey":"test_partner","offerRevision":19}

def observed(prepared,at=NOW):
    p=deepcopy(prepared["proposal"])
    return {**p,"observedAtUnix":at,"tradeOpen":True,
            "exactPartnerBound":True,"ourAccepted":False,
            "theirAccepted":False,"offerMutationPending":False}


class Stage120(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sourcesReady=PLAN.is_file() and GUARD.is_file()
        if os.getenv("STAGE120_REQUIRE_PINNED")=="1":
            assert cls.sourcesReady,"Pinned actual source files required"
        if cls.sourcesReady:
            assert M._blob(PLAN)==M.PLANNER_BLOB
            assert M._blob(GUARD)==M.GUARD_BLOB

    def require(self):
        if not self.sourcesReady:
            self.skipTest("Only exact-source CI provides frozen original modules")

    def safe(self,r):
        for key,value in M.FLAGS.items():
            self.assertEqual(r.get(key),value,(key,r))
        self.assertNotIn("AcceptTrade",str(r))
        self.assertNotIn("FireServer",str(r))

    def prepare(self,ours=None,theirs=None,m=None,b=None,now=NOW):
        self.require()
        result=M.prepare(
            ours if ours is not None else rows(("test_ours",1)),
            theirs if theirs is not None else rows(("test_theirs",1)),
            m if m is not None else market(),b if b is not None else binding(),
            now=now,planner_path=PLAN,guard_path=GUARD)
        self.safe(result)
        return result

    def verify(self,prepared,obs=None,m=None,now=NOW):
        self.require()
        r=M.verify(prepared,obs if obs is not None else observed(prepared),
                   m if m is not None else market(),now=now,guard_path=GUARD)
        self.safe(r)
        return r

    def test_actual_pinned_blobs_are_distinct_and_corrected(self):
        self.require()
        self.assertEqual(M._blob(PLAN),M.PLANNER_BLOB)
        self.assertEqual(M._blob(GUARD),M.GUARD_BLOB)
        self.assertNotEqual(M.GUARD_BLOB,"c5b87f159de5224d231b111da2541b8b23ac6284")
        self.assertIn("PROTECTED_GINGERSCOPE_OUTGOING",GUARD.read_text())

    def test_plus_five_no_old_plus_fifteen_and_no_auto(self):
        p=self.prepare()
        self.assertEqual(p["status"],"SYNTHETIC_PROPOSAL_ONLY",p)
        self.assertEqual(p["listedGainResearchOnly"],5)
        self.assertEqual(p["candidateKind"],"SIDEGRADE")
        r=self.verify(p)
        self.assertEqual(r["status"],"IDEAL_SYNTHETIC_MATCH_ONLY")
        self.assertEqual(r["listedGainResearchOnly"],5)

    def test_actual_old_planner_upgrade_vs_corrected_guard(self):
        m=market({"test_a":item(50),"test_b":item(50),"test_big":item(105)})
        p=self.prepare(rows(("test_a",1),("test_b",1)),rows(("test_big",1)),m)
        self.assertEqual(p["candidateKind"],"UPGRADE")
        self.assertEqual(p["status"],"SYNTHETIC_PROPOSAL_ONLY")
        self.assertEqual(self.verify(p,m=m)["status"],"IDEAL_SYNTHETIC_MATCH_ONLY")

    def test_actual_old_planner_liquid_downgrade_vs_corrected_guard(self):
        m=market({"test_big":item(100),"test_a":item(55),
                  "test_b":item(55)})
        p=self.prepare(rows(("test_big",1)),rows(("test_a",1),("test_b",1)),m)
        self.assertEqual(p["candidateKind"],"DOWNGRADE")
        self.assertEqual(p["listedGainResearchOnly"],10)
        self.assertEqual(self.verify(p,m=m)["status"],"IDEAL_SYNTHETIC_MATCH_ONLY")

    def test_never_propose_outgoing_gingerscope_even_huge_listed_gain(self):
        m=market({"Gingerscope":item(100),
                  "test_theirs":item(190)})
        p=self.prepare(rows(("Gingerscope",1)),rows(("test_theirs",1)),m)
        self.assertEqual(p["status"],"NO_PROPOSAL",p)
        self.assertEqual(p["reason"],"PROTECTED_GINGERSCOPE_OUTGOING")
        self.assertNotIn("proposal",p)

    def test_ingoing_gingerscope_research_still_allowed(self):
        m=market({"test_ours":item(100),"Gingerscope":item(105)})
        p=self.prepare(rows(("test_ours",1)),rows(("Gingerscope",1)),m)
        self.assertEqual(p["status"],"SYNTHETIC_PROPOSAL_ONLY",p)
        self.assertEqual(self.verify(p,m=m)["status"],"IDEAL_SYNTHETIC_MATCH_ONLY")

    def test_corrected_guard_tracks_physical_slots_not_total_stacks(self):
        self.require()
        g=M._source(GUARD,M.GUARD_BLOB,"guard")
        m=market({"test_ours":item(100),"test_theirs":item(105)})
        p={"sessionId":"test_session","jobId":"test_job",
           "partnerKey":"test_partner","catalogVersion":M.MARKET_VERSION,
           "offerRevision":19,"observedAtUnix":NOW,
           "ours":[{"index":1,"key":"test_ours","quantity":5}],
           "theirs":[{"index":1,"key":"test_theirs","quantity":6}]}
        q={**deepcopy(p),"tradeOpen":True,"exactPartnerBound":True,
           "ourAccepted":False,"theirAccepted":False,"offerMutationPending":False}
        r=g.evaluate(p,q,m,now=NOW,minimum_gain=0)
        self.assertEqual(r["status"],"RESEARCH_CANDIDATE_ONLY",r)
        self.assertEqual(r["projectedListedGain"],130)
        self.assertEqual(r["authorizesAccept"],False)
        p["theirs"]=[{"index":i,"key":"test_theirs","quantity":1} for i in range(1,6)]
        q["theirs"]=deepcopy(p["theirs"])
        self.assertEqual(g.evaluate(p,q,m,now=NOW)["reason"],"OFFER_SLOTS_UNREADABLE_OR_EMPTY")
        # Planner still has conservative total-copy limit: never call
        # Stage120 a proof it can propose actual >4-copy stacked deals.

    def test_fixed_source_expiry_beats_new_retrieval_timestamp(self):
        m=market()
        m["sourceValidUntilUnix"]=NOW-1
        m["retrievedAtUnix"]=NOW
        self.assertEqual(self.prepare(m=m)["reason"],"SOURCE_FIXED_EXPIRY_OR_PUBLISHER_INVALID")
        p=self.prepare()
        m=market()
        m["sourceValidUntilUnix"]=NOW-1
        self.assertEqual(self.verify(p,m=m)["reason"],"SOURCE_EXPIRED_OR_CHANGED_SINCE_PREPARE")

    def test_publisher_stale_even_with_padded_future_expiry(self):
        m=market()
        m["publisherUpdatedAtUnix"]=NOW-(49*3600)
        m["sourceValidUntilUnix"]=NOW+900
        self.assertEqual(self.prepare(m=m)["status"],"BLOCKED")

    def test_low_demand_or_liquidity_cannot_leverage_big_paper_profit(self):
        for e in (item(200,demand=1),item(200,liquidity=1),
                  item(200,stability="Declining")):
            m=market({"test_ours":item(100),"test_theirs":e})
            r=self.prepare(m=m)
            self.assertNotEqual(r["status"],"SYNTHETIC_PROPOSAL_ONLY")

    def test_no_trust_when_item_public_identity_unverified(self):
        m=market({"test_ours":item(100),
                  "test_theirs":item(105,identity="NAME_ONLY")})
        p=self.prepare(m=m)
        self.assertEqual(p["status"],"NO_PROPOSAL")

    def test_change_or_accepted_state_fails_after_candidate(self):
        p=self.prepare()
        for key,value in [("offerRevision",20),("partnerKey","test_other"),
                          ("jobId","test_else"),("tradeOpen",False),
                          ("theirAccepted",True),("ourAccepted",True),
                          ("offerMutationPending",True),
                          ("observedAtUnix",NOW-30)]:
            o=observed(p)
            o[key]=value
            r=self.verify(p,o)
            self.assertEqual(r["status"],"REPLAN_REQUIRED",(key,r))

    def test_frozen_source_modified_even_whitespace_blocks(self):
        self.require()
        with tempfile.TemporaryDirectory() as root:
            bad=Path(root)/"guard.py"
            bad.write_bytes(GUARD.read_bytes()+b"\n# mutation\n")
            r=M.prepare(rows(("test_ours",1)),rows(("test_theirs",1)),market(),
                        binding(),now=NOW,planner_path=PLAN,guard_path=bad)
            self.assertEqual(r["reason"],"FROZEN_COMPONENT_PROVENANCE_FAILED")
            self.safe(r)

    def test_forged_nonfixture_inventory_rejected(self):
        b=binding()
        b["fixtureKind"]="LIVE_MM2"
        self.assertEqual(self.prepare(b=b)["status"],"BLOCKED")
        self.assertEqual(self.prepare(ours=rows(("Harvester",1)))["status"],"BLOCKED")
        self.assertEqual(self.prepare(ours=rows(("test_ours",True)))["status"],"BLOCKED")

    def test_900_deterministic_offer_mutations_all_default_deny(self):
        p=self.prepare()
        rng=random.Random(120226)
        for i in range(900):
            o=observed(p)
            case=i%12
            if case==0:o["theirs"][0]["quantity"]+=1
            elif case==1:o["ours"][0]["key"]="Gingerscope"
            elif case==2:o["offerRevision"]+=1
            elif case==3:o["sessionId"]="test_other"
            elif case==4:o["partnerKey"]="test_other"
            elif case==5:o["jobId"]="test_other"
            elif case==6:o["ourAccepted"]=True
            elif case==7:o["theirAccepted"]=True
            elif case==8:o["offerMutationPending"]=True
            elif case==9:o["observedAtUnix"]=NOW-9
            elif case==10:o["tradeOpen"]=False
            else:o["exactPartnerBound"]=False
            if i%37==0:
                # Mutation is not a trading action, and user input may be malicious.
                o["offerRevision"]=rng.randrange(20,100)
            x=self.verify(p,o)
            self.assertEqual(x["status"],"REPLAN_REQUIRED",(i,x))
            self.safe(x)

    def test_no_network_gameplay_or_false_authority_in_source(self):
        text=(ROOT/"pdiddler/intelligence_lab/stage120_corrected_guard_preview.py").read_text()
        for token in ("FireServer(",":InvokeServer(","AcceptTrade","TeleportToPlaceInstance(",
                      "HttpGet(","setclipboard(","requests.get(","urllib.request.urlopen("):
            self.assertNotIn(token,text)
        for token in ("PLANNER_BLOB","GUARD_BLOB","sourceValidUntilUnix",
                      "PROTECTED_GINGERSCOPE_OUTGOING", "min_gain=0"):
            self.assertIn(token,text)


if __name__=="__main__":
    unittest.main()
