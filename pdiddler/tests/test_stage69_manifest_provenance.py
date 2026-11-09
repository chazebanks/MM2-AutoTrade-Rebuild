"""Regression tests for Stage69 external import clock and Git blob source integrity."""
import copy
from pathlib import Path
import json
import random
import tempfile
import unittest

from pdiddler.stage69_manifest_provenance import (
    SLUGS, SCHEMA, ACQUISITION, git_blob_sha1, read_manifest
)

OBSERVED = "2026-11-09T05:05:01.574Z"
PUBLISHED = "2026-11-06T10:56:07-05:00"
NOW = 1794201000  # explicit bounded test clock, NOT live authority

def stamp_epoch(value):
    from datetime import datetime
    return int(datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp())


class Stage69PinnedExternalSourceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="stage69_manifest_")
        self.directory = Path(self.temp.name)/"source"
        self.directory.mkdir()
        self.manifest = self.directory/"source_manifest.json"
        self.data = {
            "schema": SCHEMA,
            "purpose": "RESEARCH_ONLY_NO_TRADE_AUTHORITY",
            "acquisition": ACQUISITION,
            "items": [],
        }
        for kind, slug in SLUGS.items():
            # Input-size guard also catches truncated pages before parsing.
            contents = (f"HTML_{slug}"+" "*26_000).encode()
            path = self.directory/f"{slug}.html"
            path.write_bytes(contents)
            self.data["items"].append({
                "page": kind,
                "url": f"https://supremevalues.com/mm2/{slug}",
                "path": str(path),
                "observedAt": OBSERVED,
                "sourcePublisherIso": PUBLISHED,
                "sourceGitBlobSha": git_blob_sha1(contents),
                "scrapeId": "synthetic-scrape-receipt",
                "bytesUtf8": len(contents),
            })
        self._write()

    def tearDown(self):
        self.temp.cleanup()

    def _write(self):
        self.manifest.write_text(json.dumps(self.data, indent=2), encoding="utf-8")

    def check(self, clock=None):
        return read_manifest(
            self.manifest, self.directory,
            now_epoch=stamp_epoch(OBSERVED)+400 if clock is None else clock,
        )

    def test_three_original_sources_same_timestamps_not_git_checkout_mtime(self):
        result = self.check()
        self.assertEqual(set(result), set(SLUGS))
        for page, val in result.items():
            self.assertEqual(val["observedAtEpoch"], stamp_epoch(OBSERVED))
            self.assertEqual(val["publisher"], PUBLISHED)
            self.assertEqual(val["acquisition"], ACQUISITION)
            self.assertTrue(val["content"].startswith(b"HTML_"))
        # Changing file mtime must NEVER relabel the recorded acquisition.
        import os
        for page in SLUGS:
            os.utime(self.directory/f"{SLUGS[page]}.html", (1800000000, 1800000000))
        reread=self.check()
        self.assertEqual([r["observedAtEpoch"] for r in result.values()],
                         [r["observedAtEpoch"] for r in reread.values()])

    def test_failing_blob_mutation_prevents_source_import(self):
        f=self.directory/"ancients.html"
        f.write_bytes(f.read_bytes().replace(b"HTML_ancients", b"HTML_ancientX"))
        with self.assertRaisesRegex(ValueError, "source bytes|source Git blob"):
            self.check()

    def test_published_clock_cannot_be_replaced_by_retrieval_clock(self):
        self.data["items"][0]["sourcePublisherIso"]="2026-11-09T05:06:00Z"
        self._write()
        with self.assertRaisesRegex(ValueError, "reversed"):
            self.check()

    def test_missing_extra_duplicate_and_fake_source_are_rejected(self):
        changes=[
            lambda x:x["items"].pop(),
            lambda x:x["items"].append(copy.deepcopy(x["items"][0])),
            lambda x:x["items"][1].__setitem__("page","ancient"),
            lambda x:x["items"][0].__setitem__("url","https://another-source.invalid"),
            lambda x:x["items"][0].__setitem__("path","/tmp/fake.html"),
            lambda x:x["items"][0].__setitem__("sourceGitBlobSha","a"*40),
            lambda x:x["items"][0].__setitem__("bytesUtf8",10),
            lambda x:x["items"][0].__setitem__("bytesUtf8",True),
            lambda x:x["items"][0].__setitem__("scrapeId",""),
            lambda x:x["items"][0].__setitem__("verified",True),
            lambda x:x.__setitem__("acquisition","unknown source"),
            lambda x:x.__setitem__("purpose","AUTHORIZE_AUTO_TRADE"),
            lambda x:x.__setitem__("sourceTime",OBSERVED),
        ]
        base=copy.deepcopy(self.data)
        for i,mutation in enumerate(changes):
            with self.subTest(i=i):
                self.data=copy.deepcopy(base)
                mutation(self.data)
                self._write()
                with self.assertRaises(ValueError):
                    self.check()

    def test_time_future_and_more_than_24_hours_old_is_rejected(self):
        now=stamp_epoch(OBSERVED)
        self.assertEqual(len(self.check(now+86399)), 3)
        with self.assertRaisesRegex(ValueError, "older than 24 hours"):
            self.check(now+86401)
        with self.assertRaisesRegex(ValueError, "future"):
            self.check(now-1)

    def test_missing_manifest_or_symlink_does_not_gain_authority(self):
        self.manifest.unlink()
        with self.assertRaisesRegex(ValueError, "manifest missing"):
            self.check()
        self._write()
        path=self.directory/"godlies.html"
        path.unlink()
        path.symlink_to(self.directory/"ancients.html")
        with self.assertRaises(ValueError):
            self.check()

    def test_bounded_150_randomized_manifest_corruptions(self):
        base=copy.deepcopy(self.data)
        rng=random.Random(69069)
        for i in range(150):
            self.data=copy.deepcopy(base)
            row=self.data["items"][rng.randrange(3)]
            n=rng.randrange(10)
            if n==0:row["url"]="https://fake.invalid"
            elif n==1:row["path"]="bad/path"
            elif n==2:row["observedAt"]="yesterday"
            elif n==3:row["sourcePublisherIso"]="2099-01-01T01:00:00Z"
            elif n==4:row["sourceGitBlobSha"]="0"*40
            elif n==5:row["bytesUtf8"]=-1
            elif n==6:row["page"]="other"
            elif n==7:row["scrapeId"]=""
            elif n==8:self.data["purpose"]="TRADING"
            else:row["verified"]=True
            self._write()
            with self.subTest(i=i,n=n),self.assertRaises(ValueError):
                self.check()

if __name__ == "__main__":
    unittest.main()
