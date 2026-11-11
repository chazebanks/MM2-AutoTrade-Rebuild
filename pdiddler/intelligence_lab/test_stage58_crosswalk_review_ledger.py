"""Stage58: regression gates for public display identity evidence, NOT raw-key proof.

The tests never contact Roblox, Supreme, Discord, marketplaces or the user.
They load exactly the static ledger proposed for the draft Stage58 review.
"""
from __future__ import annotations

import copy
import importlib.util
import json
import random
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / "scripts/validate_crosswalk_review.py"
SPEC = importlib.util.spec_from_file_location("crosswalk_review", PATH)
assert SPEC is not None and SPEC.loader is not None
MOD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MOD)

LEDGER = ROOT / "pdiddler/intelligence_lab/STAGE58_CROSSWALK_REVIEW_ONLY_LEDGER.json"

class Stage58CrosswalkLedgerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = json.loads(LEDGER.read_text(encoding="utf-8"))

    def fresh(self):
        return copy.deepcopy(self.data)

    def assert_rejected(self, changed, label="invalid mutation"):
        with self.subTest(label=label):
            with self.assertRaises((MOD.EvidenceError, TypeError, ValueError, KeyError)):
                MOD.validate(changed)

    def test_exact_ten_source_candidates_and_zero_trade_authority(self):
        self.assertEqual(MOD.validate(self.data), 10)
        self.assertEqual(len(self.data["candidates"]), 10)
        self.assertEqual(
            [r["rawKey"] for r in self.data["candidates"]],
            sorted(MOD.EXPECTED)
        )
        self.assertEqual(
            sum(r["client"]["sourceYear"] is None for r in self.data["candidates"]),5
        )
        self.assertEqual(
            sum("PLACEHOLDER_ARTWORK" in r["review"]["flags"]
                for r in self.data["candidates"]), 2
        )
        self.assertEqual(
            sum("LEVEL2_NORMALIZATION" in r["review"]["flags"]
                for r in self.data["candidates"]), 7
        )
        self.assertEqual(
            sum("NEAR_RUNNER_SCORE" in r["review"]["flags"]
                for r in self.data["candidates"]), 1
        )
        self.assertFalse(self.data["safety"]["authorizesAccept"])
        self.assertFalse(self.data["safety"]["mayReportProfit"])
        self.assertFalse(self.data["safety"]["externalCheckerIdAuthenticated"])

    def test_absent_field_is_not_auto_completed_from_external_year(self):
        d=self.fresh()
        i=next(i for i,r in enumerate(d["candidates"]) if r["rawKey"]=="Bloom")
        d["candidates"][i]["client"]["sourceYear"]="2025"
        self.assert_rejected(d, "backfilled client year")
        d=self.fresh()
        d["candidates"][i]["review"]["clientYearAgreement"]="MATCH"
        self.assert_rejected(d,"unknown year promoted to verified")

    def test_cookiecane_and_gingermint_cannot_be_merged(self):
        d=self.fresh()
        row=next(x for x in d["candidates"] if x["rawKey"]=="Gingermint_K")
        self.assertEqual(row["client"]["displayName"],"Cookiecane")
        self.assertEqual(row["client"]["weaponType"],"Knife")
        self.assertEqual(row["publicDisplay"]["name"],"Cookiecane")
        self.assertIn("DIFFERENT_ITEM_GINGERMINT_IS_GUN",row["review"]["flags"])
        d2=self.fresh()
        x=next(x for x in d2["candidates"] if x["rawKey"]=="Gingermint_K")
        x["publicDisplay"]["name"]="Gingermint"
        self.assert_rejected(d2, "literal raw name is not display identity")

    def test_placeholders_and_checker_ids_always_unattested(self):
        for name in ("MortalChroma","ImmortalChroma"):
            row=next(x for x in self.data["candidates"] if x["rawKey"]==name)
            self.assertEqual(row["provisionalChecker"]["image"],"coming.png")
            self.assertEqual(row["client"]["sourceYear"],"2026")
            self.assertFalse(row["review"]["checkerNumericIdIndependentlyAttested"])
            self.assertFalse(row["review"]["mayFinalizeAccept"])
            d=self.fresh()
            x=next(x for x in d["candidates"] if x["rawKey"]==name)
            x["review"]["checkerNumericIdIndependentlyAttested"]=True
            self.assert_rejected(d, "one placeholder upgraded to authenticated")

    def test_single_field_attacks_are_blocked(self):
        modifications = [
            ("approve accept", lambda d: d["safety"].__setitem__("authorizesAccept",True)),
            ("certify ID", lambda d: d["safety"].__setitem__("externalCheckerIdAuthenticated",True)),
            ("certify settlement",lambda d: d["safety"].__setitem__("serverCompletionProven",True)),
            ("allow PnL",lambda d: d["safety"].__setitem__("mayReportProfit",True)),
            ("inject value",lambda d: d["candidates"][0].__setitem__("marketValue",300)),
            ("inject profit",lambda d: d["candidates"][0].__setitem__("profit",100)),
            ("inject job id",lambda d: d["candidates"][0].__setitem__("jobId","A")),
            ("replace wiki domain",lambda d: d["candidates"][0]["publicDisplay"]["sources"][0].__setitem__("url","https://attacker.example/wiki")),
            ("disguise bad domain",lambda d: d["candidates"][0]["publicDisplay"]["sources"][0].__setitem__("url","https://mm2wiki.org.attacker.test/fake")),
            ("wrong source scheme",lambda d: d["candidates"][0]["publicDisplay"]["sources"][0].__setitem__("url","http://mm2wiki.org/wiki/bloom")),
            ("drop first wiki",lambda d: d["candidates"][0]["publicDisplay"]["sources"].pop(0)),
            ("extra unknown row",lambda d: d["candidates"].append(copy.deepcopy(d["candidates"][0]))),
            ("duplicate client key",lambda d: d["candidates"][1].__setitem__("rawKey",d["candidates"][0]["rawKey"])),
            ("change source date",lambda d: d.__setitem__("reviewAsOfUtc","2099-01-01")),
            ("fake source count",lambda d: d["source"].__setitem__("catalogueCandidateCount",11)),
            ("source authenticated",lambda d: d["source"].__setitem__("gameMetadataAuthority","OFFICIAL_SERVER")),
            ("swap checker id",lambda d: d["candidates"][0]["provisionalChecker"].__setitem__("id","1033")),
            ("generic event becomes year",lambda d: d["candidates"][0]["client"].__setitem__("sourceYear","0001")),
            ("invalid item id",lambda d: d["candidates"][0]["client"].__setitem__("itemIdHint","SECRET")),
            ("wrong public origin",lambda d: d["candidates"][0]["publicDisplay"].__setitem__("originYear",2018)),
            ("remove placeholder review",lambda d: next(x for x in d["candidates"] if x["rawKey"]=="MortalChroma")["review"].__setitem__("flags",[])),
            ("certify item copy",lambda d: d["candidates"][0]["review"].__setitem__("uniqueItemInstanceProven",True)),
            ("certify explicit link",lambda d: d["candidates"][0]["review"].__setitem__("rawKeyToPublicNameIndependentlyAttested",True)),
            ("trade approval",lambda d: d["candidates"][0]["review"].__setitem__("mayAutoTrade",True)),
        ]
        for description,change in modifications:
            d=self.fresh()
            change(d)
            self.assert_rejected(d,description)

    def test_600_deterministic_adversarial_ledger_mutations(self):
        rng=random.Random(5808)
        for n in range(600):
            d=self.fresh()
            idx=rng.randrange(10)
            record=d["candidates"][idx]
            variant=n%10
            if variant==0:
                d["safety"]["authorizesTrade"]=True
            elif variant==1:
                record["review"]["checkerNumericIdIndependentlyAttested"]=True
            elif variant==2:
                record["publicDisplay"]["originYear"]=2000+rng.randrange(0,27)
                if record["publicDisplay"]["originYear"]==MOD.EXPECTED[record["rawKey"]][-1]:
                    record["publicDisplay"]["originYear"]=2099
            elif variant==3:
                record["client"]["weaponType"]=rng.choice(["Sword","Pistol","Unknown"])
            elif variant==4:
                record["provisionalChecker"]["id"]="99999"
            elif variant==5:
                record["publicDisplay"]["sources"][0]["url"]="https://evil.example/"+str(n)
            elif variant==6:
                record["review"]["status"]="SERVER_ATTESTED"
            elif variant==7:
                record["review"]["mayReportProfit"]=True
            elif variant==8:
                record["client"]["itemIdHint"]="abc"
            elif variant==9:
                record["client"]["sourceYear"]="0001"
            self.assert_rejected(d,f"seeded mutation {n}")

if __name__ == "__main__":
    unittest.main()
