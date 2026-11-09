"""Stage69 source-row proof is NOT MM2 raw weapon/checker-ID price authority."""
from copy import deepcopy
from contextlib import chdir, redirect_stdout
import io
import json
from pathlib import Path
import random
import tempfile
import unittest
from unittest.mock import patch

from pdiddler import refresh_supreme_snapshot as R
from pdiddler import stage25_market_diff as D
from pdiddler import stage69_manifest_provenance as M

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
    for row in result["rows"]:
        row["sourceRecordMatched"]=True
    return R.quarantine_research_only(result)

class SourceGameMappingSeparation(unittest.TestCase):
    def test_direct_cli_writes_only_research_json_without_mapping_authority(self):
        source_dir = ROOT / "research_source_html/stage69_2026_11_09"
        observed = R.epoch("2026-11-09T06:09:00Z")

        def read_captured_source(request, *, timeout):
            slug = request.full_url.rsplit("/", 1)[-1]
            return io.BytesIO((source_dir / (slug + ".html")).read_bytes())

        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            args = [
                "refresh_supreme_snapshot.py",
                "--mapping", str(ROOT / "snapshots/supreme_snapshot_2026_11_04.json"),
                "--date", "2026-11-09",
                "--output-dir", directory,
            ]
            with (patch("sys.argv", args),
                  patch.object(R.time, "time", return_value=observed),
                  patch.object(R, "urlopen", side_effect=read_captured_source),
                  redirect_stdout(io.StringIO())):
                R.main()

            self.assertEqual([p.name for p in output.iterdir()],
                             ["supreme_snapshot_2026_11_09.json"])
            snapshot = json.loads((output / "supreme_snapshot_2026_11_09.json").read_text())

        self.assertEqual(snapshot["sourceAcquisition"], "DIRECT_SUPREME_FETCH_REVIEW_ONLY")
        self.assertEqual(len(snapshot["rows"]), 190)
        self.assertIs(snapshot["liveReady"], False)
        self.assertIs(snapshot["authorizesTrade"], False)
        self.assertTrue(all(
            row["sourceRecordMatched"] is True
            and row["rawGameMappingVerified"] is False
            and row["priceForTradeVerified"] is False
            and row["verified"] is False
            for row in snapshot["rows"]
        ))
        report = D.compare(OLD, snapshot, now_epoch=observed)
        self.assertEqual(report["status"], "REVIEW_ONLY_NO_TRADE_AUTHORITY")
        self.assertEqual(report["changedItems"], 21)

    def test_pinned_manifest_replays_with_original_expiry_and_rejects_expired_use(self):
        source_dir = Path("pdiddler/research_source_html/stage69_2026_11_09")
        replay_at = R.epoch("2026-11-09T06:09:00Z")
        expires_at = "2026-11-09T15:56:07Z"
        with tempfile.TemporaryDirectory() as directory:
            args = [
                "refresh_supreme_snapshot.py",
                "--mapping", str(ROOT / "snapshots/supreme_snapshot_2026_11_04.json"),
                "--input-dir", str(source_dir),
                "--source-manifest", str(source_dir / "source_manifest.json"),
                "--research-only",
                "--date", "2026-11-09",
            ]
            replay = Path(directory) / "replay"
            expired = Path(directory) / "expired"
            with chdir(ROOT.parent), patch.dict("sys.modules", {"stage69_manifest_provenance": M}):
                with (patch("sys.argv", args + ["--output-dir", str(replay)]),
                      patch.object(R.time, "time", return_value=replay_at),
                      redirect_stdout(io.StringIO())):
                    R.main()
                with (patch("sys.argv", args + ["--output-dir", str(expired)]),
                      patch.object(R.time, "time", return_value=R.epoch(expires_at)),
                      self.assertRaisesRegex(ValueError, "publication exceeds 72h")):
                    R.main()
            self.assertFalse(expired.exists())
            self.assertEqual([p.name for p in replay.iterdir()],
                             ["supreme_snapshot_2026_11_09.json"])
            snapshot = json.loads((replay / "supreme_snapshot_2026_11_09.json").read_text())
        self.assertEqual(snapshot["expiresAt"], expires_at)
        self.assertEqual(snapshot["sourceAcquisition"], "EXTERNAL_SCRAPE_REVIEW_ONLY")
        self.assertIs(snapshot["liveReady"], False)
        report = D.compare(OLD, snapshot, now_epoch=replay_at)
        self.assertEqual(report["status"], "REVIEW_ONLY_NO_TRADE_AUTHORITY")
        self.assertEqual(report["changedItems"], 21)

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

    def test_caller_cannot_claim_proof_by_changing_one_flag(self):
        original=candidate()
        mutations=[
            ("root-authorizesTrade",lambda s:s.__setitem__("authorizesTrade",True)),
            ("root-authorizesAccept",lambda s:s.__setitem__("authorizesAccept",True)),
            ("root-autoDeploy",lambda s:s.__setitem__("autoDeploy",True)),
            ("root-liveReady",lambda s:s.__setitem__("liveReady",True)),
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

if __name__=="__main__":
    unittest.main()
