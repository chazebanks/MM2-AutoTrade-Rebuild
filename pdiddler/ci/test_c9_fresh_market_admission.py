"""Offline hostile/source-replay tests for C9 real four-page research gate."""
from __future__ import annotations
import copy
import unittest

from pdiddler.system2 import c9_fresh_market_admission as c9
from pdiddler.system2.public_market_gamekey_crosswalk import crosswalk
from pdiddler.ci.test_system2_public_market_gamekey_crosswalk import (
    NOW, REGISTRY, market,
)


class FreshMarketC9(unittest.TestCase):
    def setUp(self):
        self.source = market()
        self.mapping = crosswalk(self.source, REGISTRY, evaluated_utc=NOW)

    def review(self, *, source=None, mapping=None, at=NOW):
        return c9.admit(
            self.source if source is None else source, REGISTRY,
            evaluated_utc=at,
            claimed_mapping=self.mapping if mapping is None else mapping)

    def test_189_and_source_provenance_is_research_only(self):
        result = self.review()
        self.assertEqual(
            result["status"],
            "PUBLIC_C9_RESEARCH_SOURCE_ADMITTED_NOT_LIVE_AUTHORITY")
        self.assertEqual(result["matchedHistoricalGameKeys"], 189)
        self.assertTrue(result["fourPageReadObserved"])
        self.assertTrue(result["outgoingGingerscopeProtected"])
        self.assertTrue(result["researchOnly"])
        self.assertEqual(result["sourceAgeSeconds"], 91)
        for field in (
            "sourcePublisherSignatureVerified",
            "rawGameItemInstanceIdentityVerified",
            "completedTradeOrRetradabilityProven",
            "ownerInventoryObserved",
            "liveRuntimeSnapshotAvailable",
            "authorizesTrade", "authorizesOffer", "authorizesAccept",
            "mayUseForLiveOffer", "mayReportProfit",
            "mayUseForStrategyLearning",
        ):
            self.assertIs(result[field], False, field)

    def test_source_age_boundary_closed_but_not_future(self):
        self.assertEqual(self.review(at="2026-11-15T02:38:29Z")[
            "sourceAgeSeconds"], 21600)
        with self.assertRaisesRegex(
            c9.SourceBlocked, "C9_REAL_SOURCE_AGE_EXPIRED_OR_FUTURE"
        ):
            self.review(at="2026-11-15T02:38:30Z")
        with self.assertRaisesRegex(
            c9.SourceBlocked, "C9_REAL_SOURCE_AGE_EXPIRED_OR_FUTURE"
        ):
            self.review(at="2026-11-14T20:38:28Z")

    def test_never_restamp_expired_source(self):
        source = copy.deepcopy(self.source)
        source["retrievedUtc"] = "2026-11-14T14:38:29Z"
        with self.assertRaisesRegex(c9.SourceBlocked, "C9_REAL_SOURCE_AGE"):
            self.review(source=source)

    def test_source_and_mapped_rows_must_be_same_actual_replay(self):
        source = copy.deepcopy(self.source)
        source["items"][0]["mm2Listed"] += 1
        with self.assertRaisesRegex(
            c9.SourceBlocked, "C9_CROSSWALK_NOT_EXACTLY_REPRODUCIBLE"
        ):
            self.review(source=source)

    def test_forged_trade_permission_fails(self):
        x = copy.deepcopy(self.source)
        x["authorizesAccept"] = True
        with self.assertRaisesRegex(
            c9.SourceBlocked, "C9_ORIGINAL_SOURCE_MAPPING_BLOCKED"
        ):
            self.review(source=x)

    def test_forged_market_rows_sha_fails(self):
        mapped = copy.deepcopy(self.mapping)
        mapped["crosswalkRowsSha256"] = "0" * 64
        with self.assertRaisesRegex(
            c9.SourceBlocked, "C9_CROSSWALK_NOT_EXACTLY_REPRODUCIBLE"
        ):
            self.review(mapping=mapped)

    def test_missing_current_rows_denied(self):
        source = copy.deepcopy(self.source)
        source["items"].pop()
        with self.assertRaisesRegex(
            c9.SourceBlocked, "C9_ORIGINAL_SOURCE_MAPPING_BLOCKED"
        ):
            self.review(source=source)

    def test_new_unknown_game_key_does_not_get_fuzzy_alias(self):
        source = copy.deepcopy(self.source)
        target = next(
            row for row in source["items"]
            if row["providerSlug"] == "gingerscope"
        )
        target["providerName"] = "GingerscopeFake"
        with self.assertRaisesRegex(
            c9.SourceBlocked, "C9_ORIGINAL_SOURCE_MAPPING_BLOCKED"
        ):
            self.review(source=source)

    def test_no_user_private_data_needed_in_attestation(self):
        r = self.review()
        self.assertNotIn("ownCounts", r)
        self.assertNotIn("jobId", r)
        self.assertNotIn("leaseId", r)
        self.assertNotIn("partnerUserId", r)
        self.assertNotIn("items", r)
        self.assertEqual(len(r["rawFourPageCandidateSha256"]), 64)
        self.assertEqual(len(r["crosswalkRowsSha256"]), 64)

    def test_timezone_missing_or_invalid(self):
        for value in (None, "2026-11-14T20:40:00+00:00", "invalid"):
            with self.subTest(value=value), self.assertRaises(
                c9.SourceBlocked
            ):
                self.review(at=value)


if __name__ == "__main__":
    unittest.main()
