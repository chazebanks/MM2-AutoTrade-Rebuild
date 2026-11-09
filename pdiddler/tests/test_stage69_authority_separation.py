"""Stage69 source-row proof is NOT MM2 raw weapon/checker-ID price authority."""
from copy import deepcopy
import json
from pathlib import Path
import random
import unittest

from pdiddler import refresh_supreme_snapshot as R
from pdiddler import stage25_market_diff as D

ROOT=Path(__file__).resolve().parents[1]
OLD=json.loads((ROOT/"snapshots/supreme_snapshot_2026_11_04.json").read_text())
OBS="2026-11-06T00:47:22Z"
EXP="2026-11-07T00:47:22Z"
NOW=D.utc_epoch("2026-11-06T01:00:00Z")

def candidate():
    result=deepcopy(OLD)
    result["version"]="stage69-verified-public-source-not-game-id"
    result["snapshotDate"]="2026-11-06"
    result["observedAt"]=OBS
    result["expiresAt"]=EXP
    for source in result["sources"].values():
        source["observedAt"]=OBS
    return R.quarantine_research_only(result)

class SourceGameMappingSeparation(unittest.TestCase):
    def test_all_190_source_records_match_but_zero_game_raw_ids_authorized(self):
        snapshot=candidate()
        self.assertEqual(len(snapshot["rows"]),190)
        self.assertEqual(snapshot["sourceRowsMatched"],True)
        self.assertIs(snapshot["rawGameMappingsVerified"],False)
        self.assertIs(snapshot["authorizesTrade"],False)
        self.assertIs(snapshot["authorizesAccept"],False)
        self.assertIs(snapshot["autoDeploy"],False)
        for row in snapshot["rows"]:
            self.assertIs(row["sourceRecordMatched"],True)
            self.assertIs(row["rawGameMappingVerified"],False)
            self.assertIs(row["priceForTradeVerified"],False)
            self.assertIs(row["verified"],False)
        report=D.compare(OLD,snapshot,now_epoch=NOW)
        self.assertEqual(report["canonicalCount"],190)
        self.assertEqual(report["changedItems"],0)
        self.assertEqual(report["status"],"REVIEW_ONLY_NO_TRADE_AUTHORITY")
        self.assertIs(report["autoDeploy"],False)

    def test_research_rows_can_never_be_converted_to_live_ready_lua(self):
        with self.assertRaisesRegex(ValueError,"research-only"):
            R.lua_snapshot(candidate())
        # Even when someone strips the top-level 'researchOnly' marker,
        # per-row raw ID uncertainty still blocks the executable converter.
        snap=candidate()
        snap.pop("researchOnly")
        with self.assertRaisesRegex(ValueError,"raw-game-unverified"):
            R.lua_snapshot(snap)

    def test_caller_cannot_claim_proof_by_changing_one_flag(self):
        original=candidate()
        mutations=[
            ("root-authorizesTrade",lambda s:s.__setitem__("authorizesTrade",True)),
            ("root-authorizesAccept",lambda s:s.__setitem__("authorizesAccept",True)),
            ("root-autoDeploy",lambda s:s.__setitem__("autoDeploy",True)),
            ("root-rawMapping",lambda s:s.__setitem__("rawGameMappingsVerified",True)),
            ("root-sourceNotMatched",lambda s:s.__setitem__("sourceRowsMatched",False)),
            ("row-rawMapping",lambda s:s["rows"][0].__setitem__("rawGameMappingVerified",True)),
            ("row-price",lambda s:s["rows"][1].__setitem__("priceForTradeVerified",True)),
            ("row-verified",lambda s:s["rows"][2].__setitem__("verified",True)),
            ("row-no-source",lambda s:s["rows"][3].__setitem__("sourceRecordMatched",False)),
        ]
        for name,change in mutations:
            with self.subTest(name=name):
                a=deepcopy(original)
                change(a)
                with self.assertRaisesRegex(ValueError,"promot|research candidate"):
                    D.compare(OLD,a,now_epoch=NOW)

    def test_500_seeded_false_provenance_escalations_all_fail(self):
        rng=random.Random(69070)
        for i in range(500):
            a=candidate()
            row=a["rows"][rng.randrange(len(a["rows"]))]
            mode=rng.randrange(5)
            if mode==0:row["verified"]=True
            elif mode==1:row["rawGameMappingVerified"]=True
            elif mode==2:row["priceForTradeVerified"]=True
            elif mode==3:a["authorizesTrade"]=True
            else:a["rawGameMappingsVerified"]=True
            with self.subTest(i=i,mode=mode):
                with self.assertRaises(ValueError):
                    D.compare(OLD,a,now_epoch=NOW)

    def test_preexisting_lua_module_regression_unchanged(self):
        # Archived frozen source baseline was allowed to generate Lua in
        # Stage25 historical tests. This isn't proof that its raw mapping
        # would be safe for an autotrader today.
        legacy=deepcopy(OLD)
        script=R.lua_snapshot(legacy)
        self.assertIn("liveReady=true",script)
        self.assertIn("function S.isFresh(now)",script)

if __name__=="__main__":
    unittest.main()
