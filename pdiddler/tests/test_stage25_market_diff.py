"""Stage 25 Python tests: reviewed price diff without source-date laundering."""
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path
import importlib.util
import json
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("stage25_market_diff", ROOT / "stage25_market_diff.py")
D = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(D)
ORIGINAL = json.loads((ROOT / "snapshots" / "supreme_snapshot_2026_11_04.json").read_text())
OBSERVED = "2026-11-06T00:47:22Z"
EXPIRY = "2026-11-07T00:47:22Z"
NOW = D.utc_epoch("2026-11-06T00:55:00Z")


def next_candidate():
    candidate = deepcopy(ORIGINAL)
    candidate["version"] = "supreme-2026-11-06-test"
    candidate["snapshotDate"] = "2026-11-06"
    candidate["observedAt"] = OBSERVED
    candidate["expiresAt"] = EXPIRY
    for v in candidate["sources"].values():
        v["observedAt"] = OBSERVED
    return candidate


class Stage25MarketDiff(unittest.TestCase):
    def test_same_publication_with_new_observation_is_not_a_new_publication(self):
        r = D.compare(ORIGINAL, next_candidate(), now_epoch=NOW)
        self.assertEqual(r["canonicalCount"], 190)
        self.assertEqual(r["changedItems"], 0)
        self.assertEqual(r["unchangedItems"], 190)
        self.assertEqual(r["publicationClassification"], "SAME_PUBLICATION_NEW_RETRIEVAL")
        self.assertFalse(r["publicationChanged"])
        self.assertFalse(r["autoDeploy"])
        self.assertFalse(r["authorizesTrade"])
        self.assertFalse(r["authorizesAccept"])

    def test_actual_price_delta_is_detected_even_if_published_timestamp_unchanged(self):
        c = next_candidate()
        scope = next(r for r in c["rows"] if r["page"] == "ancient" and r["id"] == "771")
        scope["supremeValue"] = 16001
        result = D.compare(ORIGINAL, c, now_epoch=NOW)
        self.assertEqual(result["changedItems"], 1)
        self.assertEqual(result["changed"][0]["name"], "Gingerscope")
        self.assertEqual(result["changed"][0]["before"]["supremeValue"], 16000)
        self.assertEqual(result["changed"][0]["after"]["supremeValue"], 16001)
        self.assertFalse(result["publicationChanged"])

    def test_canonical_name_change_is_not_a_silent_map_rebuild(self):
        c = next_candidate()
        c["rows"][1]["name"] = "Not Gingerscope"
        with self.assertRaisesRegex(ValueError, "canonical name changed"):
            D.compare(ORIGINAL, c, now_epoch=NOW)

    def test_missing_eligible_ancient_is_not_silent(self):
        c = next_candidate()
        c["rows"].pop(1)
        with self.assertRaisesRegex(ValueError, "incomplete canonical coverage"):
            D.compare(ORIGINAL, c, now_epoch=NOW)

    def test_forged_retrieval_time_is_rejected(self):
        c = next_candidate()
        c["observedAt"] = "2026-11-04T21:55:32Z"
        with self.assertRaisesRegex(ValueError, "invalid or reversed"):
            D.compare(ORIGINAL, c, now_epoch=NOW)

    def test_extended_expiration_without_matching_source_time_rejected(self):
        c = next_candidate()
        c["expiresAt"] = "2026-11-08T00:47:22Z"
        with self.assertRaisesRegex(ValueError, "expiry is not tied"):
            D.compare(ORIGINAL, c, now_epoch=NOW)

    def test_expired_candidate_must_not_pass(self):
        c = next_candidate()
        with self.assertRaisesRegex(ValueError, "candidate is not current"):
            D.compare(ORIGINAL, c, now_epoch=D.utc_epoch(EXPIRY))

    def test_old_source_publication_cannot_be_backdated(self):
        c = next_candidate()
        c["publishedAt"] = "2026-11-03T17:27:12Z"
        with self.assertRaisesRegex(ValueError, "invalid or reversed"):
            D.compare(ORIGINAL, c, now_epoch=NOW)

    def test_mismatched_source_url_rejected(self):
        c = next_candidate()
        c["sources"]["chroma"]["url"] = "https://example.com/fake"
        with self.assertRaisesRegex(ValueError, "unexpected source URL"):
            D.compare(ORIGINAL, c, now_epoch=NOW)

    def test_nonfinite_price_and_bool_price_rejected(self):
        for bad in (float("nan"), True, -50):
            c = next_candidate()
            c["rows"][1]["supremeValue"] = bad
            with self.assertRaisesRegex(ValueError, "invalid quote"):
                D.compare(ORIGINAL, c, now_epoch=NOW)


if __name__ == "__main__":
    unittest.main()
