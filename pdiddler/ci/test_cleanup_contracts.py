"""Cleanup regression: preserve canonical duplicate blobs; detect dangling path references."""
from __future__ import annotations
import hashlib
import json
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
REGISTER = ROOT / "pdiddler/history/REMOVED_DUPLICATES_2026_11_11.json"

def blob_sha(raw: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()

class CleanupContracts(unittest.TestCase):
    def test_retained_sources_match_archived_git_blobs(self):
        data = json.loads(REGISTER.read_text())
        self.assertEqual(len(data["deleted"]), 3)
        for entry in data["deleted"]:
            self.assertFalse((ROOT / entry["path"]).exists())
            canonical = ROOT / entry["canonicalRetained"]
            self.assertTrue(canonical.is_file(), entry["canonicalRetained"])
            self.assertEqual(blob_sha(canonical.read_bytes()), entry["gitBlob"])

    def test_no_dangling_removed_filename_references(self):
        data = json.loads(REGISTER.read_text())
        aliases = [Path(e["path"]).name for e in data["deleted"]]
        for path in ROOT.rglob("*"):
            if path.is_dir() or ".git" in path.parts or path == REGISTER:
                continue
            if path.suffix not in {".lua",".luau",".py",".sh",".yml",".yaml"}:
                continue
            content = path.read_text(encoding="utf-8")
            for alias in aliases:
                self.assertNotIn(alias, content, f"{path.relative_to(ROOT)} references deleted alias {alias}")

    def test_short_entrypoint_retains_critical_boundaries(self):
        entry = (ROOT / "pdiddler/START_HERE.md").read_text()
        for phrase in ("continuity.manager verify", "growth_policy.json",
                       "Stage119", "Stage120", "Stage121",
                       "not a", "No historical handoff was deleted"):
            self.assertIn(phrase, entry)

    def test_agent_preflight_prefers_compact_entrypoint(self):
        for p in ("AGENTS.md",".github/copilot-instructions.md"):
            self.assertIn("pdiddler/START_HERE.md", (ROOT / p).read_text())

if __name__ == "__main__":
    unittest.main()
