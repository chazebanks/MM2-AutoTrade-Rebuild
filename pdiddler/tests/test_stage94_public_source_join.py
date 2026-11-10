"""Stage94 executes ACTUAL pinned Stage82 and Stage84 source modules, and tests
the research-only 189 public-key bridge; no user inventory or trading APIs."""
from __future__ import annotations
import copy
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import random
import unittest

from pdiddler.intelligence_lab.stage94_public_source_join import join_public_sources

ROOT=Path("/tmp/gingerscope94")
NEW=Path("pdiddler/research_source_html/stage84_2026_11_09")
T_OK=int(datetime(2026,11,9,23,0,0,tzinfo=timezone.utc).timestamp())
T_BAD=int(datetime(2026,11,10,22,26,48,tzinfo=timezone.utc).timestamp())

def load(path,name):
    spec=importlib.util.spec_from_file_location(name,path)
    if spec is None or spec.loader is None: raise RuntimeError(name)
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

def blob(path):
    b=Path(path).read_bytes()
    return hashlib.sha1(b"blob "+str(len(b)).encode()+b"\0"+b).hexdigest()

def _digest(items):
    return hashlib.sha256(json.dumps(items,sort_keys=True,
      separators=(",",":"),ensure_ascii=True).encode()).hexdigest()

class ActualOriginalPublicSourceJoin(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if os.getenv("STAGE94_REQUIRE_PINNED") != "1":
            raise RuntimeError("Exact pinned original-source CI environment required")
        expected={
          "game.lua":"2be54c3f5c6b715844728c01a65cc2f24a55c02d",
          "roster.json":"a85af4f6137278540e1fed0c27e7e801553e4111",
          "stage77.py":"754fbe3189d5108272c32a27fc52bf3834011d38",
          "stage81.py":"bff17e1c164d7075a975b0a5e1da27ac2d20a2ba",
          "old_ancients.html":"7e11a2d835eadbb522d351bdabe393a7c9688f4b",
          "old_godlies.html":"2e4a0c1b8df894f9037e737ba80919b9b2d0c9ae",
          "old_chromas.html":"0d2d156d9d9c499ef0e1213376796c1a916e6ce1",
          "stage82.py":"91362b647a8cc630e4fabcf7aa5d65eb44adb399",
          "stage84.py":"2a5aba0e339a3a27cd43e20d2a7731ac37c99822",
          "parser.py":"d5843a57f34078cbe7213aa78a4aa12a5775c016",
          "receipt.py":"9b6faa9f7a9890d69635542529703fedc8e4d55f",
        }
        for p,d in expected.items():
            assert blob(ROOT/p)==d,(p,"reviewed original Git blob changed")
        for p,d in {
          "ancients.html":"ce8178ab9579e8782d8f72a6dac051756a728506",
          "godlies.html":"d3cf222a8e10cff3a9fb051b16188192389c4b2d",
          "chromas.html":"6c77624cac3df96168b008e9bc8eca68a2d78cf9",
          "source_manifest.json":"7e47985b626d3a6904b1b05aa3dd0474f3f2cdb3",
        }.items():
            assert blob(NEW/p)==d,(p,"new first-party source blob changed")
        s82=load(ROOT/"stage82.py","stage94_pinned_stage82")
        s84=load(ROOT/"stage84.py","stage94_pinned_stage84")
        cls.old=s82.build(
          (ROOT/"game.lua").read_bytes(),
          (ROOT/"roster.json").read_bytes(),
          {p:(ROOT/{"ancient":"old_ancients.html","godly":"old_godlies.html","chroma":"old_chromas.html"}[p]).read_bytes()
           for p in ("ancient","godly","chroma")},
          (ROOT/"stage77.py").read_bytes(),
          (ROOT/"stage81.py").read_bytes()
        )
        # NOTE source keys old actual are ancients/godlies/chromas; map explicitly
        cls.new=s84.load_inputs(NEW,NEW/"source_manifest.json",
            ROOT/"parser.py",ROOT/"receipt.py",ROOT/"roster.json",now_epoch=T_OK)
        if cls.old.get("status")!="PUBLIC_GAME_KEY_TO_WEBSITE_SLUG_CANDIDATES_ONLY":
            raise AssertionError("Stage82 original did not build 189 public references")
        if len(cls.new["rows"])!=190:
            raise AssertionError("Stage84 original did not build 190 fresh source rows")
    def join(self,old=None,new=None,now=T_OK):
        return join_public_sources(self.old if old is None else old,
                                   self.new if new is None else new,at_epoch=now)
    def test_actual_189_public_prices_research_only(self):
        r=self.join()
        self.assertEqual(r["status"],"PUBLIC_RESEARCH_JOIN_READY",r["reason"])
        self.assertTrue(r["sourceResearchFreshAtEvaluation"])
        self.assertEqual(len(r["rows"]),189)
        self.assertEqual(r["publicCandidates"],189)
        lookup={x["publicItemName"]:x for x in r["rows"]}
        self.assertEqual(lookup["Gingerscope"]["researchSourceValue"],16000)
        self.assertEqual(lookup["Emberbow"]["researchSourceValue"],650)
        self.assertEqual(lookup["Harvester"]["researchSourceValue"],260)
        self.assertEqual(r["publicPricelessWithoutSlug"],1)
        self.assertEqual(r["publicGameOnlyWithoutOldSourceRow"],10)
    def test_hard_expiry_never_becomes_live_quote(self):
        r=self.join(now=T_BAD)
        self.assertEqual(r["status"],"PUBLIC_JOIN_ARCHIVED_SOURCE_EXPIRED")
        self.assertFalse(r["sourceResearchFreshAtEvaluation"])
        self.assertEqual(len(r["rows"]),189)
        self.assertFalse(r["currentPricesVerified"])
        self.assertFalse(r["authorizesTrade"])
    def test_no_permission_escalation_or_account_artifacts(self):
        for when in (T_OK,T_BAD):
            r=self.join(now=when)
            for flag in ("actualOwnedInventoryRead","authenticatedOwnedInventory",
                         "serverAttestation","serverCompletionProven",
                         "rawGameToMarketIdentityAuthenticated",
                         "numericSupremeCheckerIdVerified","priceForTradeVerified",
                         "currentPricesVerified","authorizesTrade","authorizesAccept",
                         "mayRecordCompletedTrade","mayReportProfit",
                         "maySendDiscordWebhook","mayUseForStrategyLearning"):
                self.assertIs(r[flag],False,flag)
            self.assertEqual(r["tradeOutcome"],"UNKNOWN")
            for row in r["rows"]:
                self.assertEqual(row["historicalPublicCandidateOnly"],True)
                self.assertIs(row["priceForTradeVerified"],False)
                self.assertNotIn("ownedQty",row)
                self.assertNotIn("accountId",row)
                self.assertNotIn("checkerId",row)
                self.assertNotIn("userId",row)
    def test_original_old_reference_digest_mismatch_rejected(self):
        o=copy.deepcopy(self.old)
        raw=next(iter(o["candidates"]))
        o["candidates"][raw]["slug"]="forged"
        self.assertEqual(self.join(old=o)["status"],"INCONCLUSIVE")
    def test_digest_recomputed_but_wrong_variant_still_rejected(self):
        o=copy.deepcopy(self.old)
        raw=next(iter(o["candidates"]))
        o["candidates"][raw]["gameChroma"]=not o["candidates"][raw]["gameChroma"]
        o["candidateRegistrySha256"]=_digest(o["candidates"])
        self.assertEqual(self.join(old=o)["status"],"INCONCLUSIVE")
    def test_raw_source_row_reordering_is_deterministic(self):
        n=copy.deepcopy(self.new)
        random.Random(94).shuffle(n["rows"])
        self.assertEqual(self.join(new=n)["rows"],self.join()["rows"])
    def test_publisher_and_source_provenance_mutations_fail(self):
        for key,bad in (("publishedAt","2026-11-10T18:58:33Z"),
                        ("expiresAt","2026-11-19T22:26:48Z"),
                        ("currentPricesVerified",True),
                        ("authorizesAccept",True)):
            n=copy.deepcopy(self.new)
            n[key]=bad
            self.assertEqual(self.join(new=n)["status"],"INCONCLUSIVE",key)
        n=copy.deepcopy(self.new)
        n["sources"]["godly"]["sourceGitBlobSha"]="0"*40
        self.assertEqual(self.join(new=n)["status"],"INCONCLUSIVE")
    def test_duplicate_price_missing_and_bad_quantity_fail(self):
        for mutate in ("duplicate","removed","unverified","zero","strprice","priceless"):
            n=copy.deepcopy(self.new)
            if mutate=="duplicate": n["rows"][1]=copy.deepcopy(n["rows"][0])
            if mutate=="removed": n["rows"].pop()
            if mutate=="unverified": n["rows"][1]["verified"]=True
            if mutate=="zero": n["rows"][1]["supremeValue"]=0
            if mutate=="strprice": n["rows"][1]["supremeValue"]="100"
            if mutate=="priceless": n["rows"][1]["supremeValue"]=None
            self.assertEqual(self.join(new=n)["status"],"INCONCLUSIVE",mutate)
    def test_exact_public_name_category_match_needed(self):
        n=copy.deepcopy(self.new)
        n["rows"][1]["name"]="Gingerscope Forgery"
        self.assertEqual(self.join(new=n)["status"],"INCONCLUSIVE")
        o=copy.deepcopy(self.old)
        raw=next(iter(o["candidates"]))
        o["candidates"][raw]["page"]="chroma"
        o["candidateRegistrySha256"]=_digest(o["candidates"])
        self.assertEqual(self.join(old=o)["status"],"INCONCLUSIVE")
    def test_malformed_inputs_and_time_fail_closed(self):
        for old,new,when in (
           (None,None,T_OK),({},self.new,T_OK),(self.old,{},T_OK),
           (self.old,self.new,"bad"),(self.old,self.new,-1),
           (self.old,self.new,False),
        ):
            r=join_public_sources(old,new,at_epoch=when)
            self.assertEqual(r["status"],"INCONCLUSIVE")
            self.assertEqual(r["rows"],[])
    def test_400_seeded_corruptions_never_authorize(self):
        rng=random.Random(940009)
        for idx in range(400):
            o=copy.deepcopy(self.old)
            n=copy.deepcopy(self.new)
            op=idx%8
            if op==0:
                k=rng.choice(list(o["candidates"]))
                o["candidates"][k]["slug"]+="x"
            if op==1:
                k=rng.choice(list(o["candidates"]))
                o["candidates"][k]["page"]="INVALID"
                o["candidateRegistrySha256"]=_digest(o["candidates"])
            if op==2:
                n["rows"][rng.randrange(190)]["verified"]=True
            if op==3:
                n["rows"][rng.randrange(190)]["demand"]=-100
            if op==4:
                n["sources"][rng.choice(("ancient","godly","chroma"))]["sourceGitBlobSha"]="f"*40
            if op==5:
                n["rows"][rng.randrange(190)]["supremeValue"]="not-numeric"
            if op==6:
                n["rows"][rng.randrange(190)]["sourceRecordMatched"]=False
            if op==7:
                n["rows"][rng.randrange(190)]["name"]="forged_unique_name"
            r=self.join(old=o,new=n)
            self.assertEqual(r["status"],"INCONCLUSIVE",idx)
            self.assertFalse(r["authorizesTrade"])
            self.assertFalse(r["currentPricesVerified"])
            self.assertEqual(r["rows"],[])
if __name__=="__main__":
    unittest.main()
