"""Stage 26: byte-exact promotion of reviewed dated Supreme profile.

No web requests, snapshot refresh, invented timestamps, or live trade authority.
This test checks the ACTUAL artifact SHA256 hashes from GitHub Actions.
"""
from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SNAPS = ROOT / "snapshots"
NEW_LUA = SNAPS / "pdiddler_supreme_snapshot_2026_11_06.lua"
NEW_JSON = SNAPS / "supreme_snapshot_2026_11_06.json"
OLD_JSON = SNAPS / "supreme_snapshot_2026_11_04.json"
MANIFEST = ROOT / "source_evidence" / "stage26_dated_profile_promotion.json"
PREVIEW = ROOT / "new_part4" / "REPLACEMENT_INTEGRATION_PREVIEW.lua"
SCAN_BOOT = ROOT / "new_part4" / "STAGE25_SCANNER_ONLY_BOOT.lua"

EXPECTED = {
    NEW_LUA.name: "f296cd33637cb62980fd87096c3b3b651cd22ffb32f6348e26dccdf96891ffa5",
    NEW_JSON.name: "9f93f743ea6c7c8475cf5510f7abc9fcbb08e51b4e5da9db5bd7578bb0d19bc3",
}
IMMUTABLE_SOURCE_COMMIT = "d9d7970f281f725ff21d1a409495fcc197e3d2dc"


def epoch(raw: str) -> int:
    d = datetime.fromisoformat(raw.replace("Z", "+00:00"))
    if d.tzinfo is None:
        raise ValueError("source timestamp must be timezone-aware")
    return int(d.timestamp())


class Stage26Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.old = json.loads(OLD_JSON.read_text())
        cls.new = json.loads(NEW_JSON.read_text())
        cls.manifest = json.loads(MANIFEST.read_text())

    def test_promotion_files_are_exact_verbatim_ci_artifact_bytes(self):
        for file in (NEW_LUA, NEW_JSON):
            blob = file.read_bytes()
            self.assertEqual(hashlib.sha256(blob).hexdigest(), EXPECTED[file.name])
            self.assertEqual(
                len(blob),
                self.manifest["candidateFiles"][str(file.relative_to(ROOT.parent))]["bytes"],
            )
            self.assertEqual(
                self.manifest["candidateFiles"][str(file.relative_to(ROOT.parent))]["sha256"],
                EXPECTED[file.name],
            )

    def test_no_change_to_any_of_190_canonical_items(self):
        a = {(r["page"], r["id"]): r for r in self.old["rows"]}
        b = {(r["page"], r["id"]): r for r in self.new["rows"]}
        self.assertEqual(len(a), 190)
        self.assertEqual(a, b)
        self.assertEqual(self.new["coverage"]["finite"], 189)
        self.assertEqual(self.new["coverage"]["unpriced"], 1)
        scope = b["ancient", "771"]
        self.assertEqual(scope["name"], "Gingerscope")
        self.assertEqual(scope["supremeValue"], 16000)
        self.assertEqual(scope["demand"], 5)
        self.assertTrue(scope["verified"])

    def test_publication_vs_observation_are_separately_preserved(self):
        n = self.new
        self.assertEqual(n["publishedAt"], self.old["publishedAt"])
        self.assertEqual(n["observedAt"], "2026-11-06T00:47:22Z")
        self.assertEqual(n["expiresAt"], "2026-11-07T00:47:22Z")
        self.assertLess(epoch(n["publishedAt"]), epoch(n["observedAt"]))
        self.assertEqual(epoch(n["expiresAt"]) - epoch(n["observedAt"]), 86400)
        self.assertLessEqual(epoch(n["expiresAt"]) - epoch(n["publishedAt"]), 259200)
        self.assertEqual(self.manifest["publication"], n["publishedAt"])
        self.assertEqual(self.manifest["observed"], n["observedAt"])
        self.assertEqual(self.manifest["expires"], n["expiresAt"])
        self.assertFalse(self.manifest["autoRefresh"])
        self.assertFalse(self.manifest["autoDeploy"])
        self.assertFalse(self.manifest["authorizesTrade"])
        self.assertFalse(self.manifest["authorizesAccept"])

    def test_three_independent_source_sha256_ids_and_expected_publication(self):
        expected = {
            "ancient": "d2604ed6b8f431453a3eabd78c11daf7404c5bfe4532a30b61a52623ba1a3cd7",
            "chroma": "eea50fa7752d3de8e69f5804dcbddd3c1d992982b00d554549357abb0c5fad8f",
            "godly": "dd3614b3bec0202e3ac89aa316b49a349c95f1a90618ea6bee6fc5075a163e7c",
        }
        self.assertEqual({k: v["sha256"] for k, v in self.new["sources"].items()}, expected)
        for data in self.new["sources"].values():
            self.assertEqual(data["observedAt"], self.new["observedAt"])
            self.assertEqual(data["publishedAt"], self.new["publishedAt"])

    def test_preview_uses_specific_commit_and_source_no_implicit_latest(self):
        p = PREVIEW.read_text()
        self.assertIn(
            'profile={"snapshots/pdiddler_supreme_snapshot_2026_11_06.lua","'
            + IMMUTABLE_SOURCE_COMMIT + '"}', p,
        )
        self.assertNotIn('profile={"snapshots/pdiddler_supreme_snapshot_2026_11_04.lua"', p)
        self.assertIn('assert(I.profile.isFresh()', p)
        self.assertIn('PDIDDLER_ALLOW_REPLACEMENT_PREVIEW~=true', p)
        self.assertIn('p4.run(I.scanner,I.profile)', p)
        self.assertNotIn('p4.run(I.scanner,I.profile,', p)
        self.assertNotIn('PDIDDLER_ALLOW_REPLACEMENT_PREVIEW=true', p)
        self.assertNotIn('pdiddler4_balancer_SUPREME_v11_VALUE_FIRST.lua', p)
        self.assertNotIn('minimumProfit=15', p)

    def test_scanner_diagnostic_is_still_scanner_only(self):
        p = SCAN_BOOT.read_text()
        self.assertIn('pdiddler_supreme_snapshot_2026_11_06.lua', p)
        self.assertIn(IMMUTABLE_SOURCE_COMMIT, p)
        self.assertIn('PDIDDLER_ALLOW_SCANNER_ONLY_TEST~=true', p)
        self.assertIn('noOutgoing=true,noHopping=true', p)
        self.assertIn('authorizesTrade=false,authorizesAccept=false', p)
        for call in ('OfferItem:FireServer', 'AcceptTrade:FireServer', 'transport.bootstrap('):
            self.assertNotIn(call, p)

    def test_original_2026_11_04_profile_is_preserved_with_original_expiry(self):
        old_lua = (SNAPS / "pdiddler_supreme_snapshot_2026_11_04.lua").read_text()
        self.assertIn('expiresAt="2026-11-05T21:55:32Z"', old_lua)
        self.assertEqual(self.old["expiresAt"], "2026-11-05T21:55:32Z")

    @unittest.skipUnless(shutil.which("lua5.4"), "Lua5.4 installed in GitHub CI")
    def test_actual_lua_consumer_enforces_fixed_boundary(self):
        test_path = ROOT / "new_part4" / "tests" / "test_stage26_dated_profile.lua"
        run = subprocess.run(
            ["lua5.4", str(test_path), str(ROOT / "new_part4")],
            cwd=str(ROOT.parent),
            text=True,
            capture_output=True,
            check=False,
            timeout=15,
        )
        self.assertEqual(run.returncode, 0, run.stdout + "\n" + run.stderr)
        self.assertIn("Stage26 exact-date market source and fail-closed expiry", run.stdout)


if __name__ == "__main__":
    unittest.main()
