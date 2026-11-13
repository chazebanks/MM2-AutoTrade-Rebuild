"""No network, no user identifiers. Tests the REAL System2 research module."""
import csv
from datetime import date, timedelta
import io
import unittest

from pdiddler.system2.licensed_listing_observation import (
    SOURCE, audit_csv, SCHEMA,
)

NOW = "2026-11-13T14:00:00Z"
FIELDS = ["game", "item", "slug", "day", "selling", "buying"]
R = [
    ("Murder Mystery 2", "Test Axe", "test-axe", "2026-11-11", "0", ""),
    ("Murder Mystery 2", "Test Axe", "test-axe", "2026-11-12", "3", "1"),
    ("Murder Mystery 2", "Another Item", "other-item", "2026-11-11", "7", "0"),
    ("Adopt Me", "Adopt Test", "adopt-test", "2026-11-12", "500", ""),
]


def encode(rows=R, columns=FIELDS):
    out = io.StringIO(newline="")
    w = csv.writer(out, lineterminator="\n")
    w.writerow(columns)
    w.writerows(rows)
    return out.getvalue().encode("utf-8")


def valid(rows=R, *, picked="test-axe", observed=NOW, source=SOURCE):
    return audit_csv(encode(rows), evaluated_utc=observed,
                     source_url=source, item_slug=picked)


class TestLicensedListingObservation(unittest.TestCase):

    def test_sampled_nonprice_research(self):
        r = valid()
        self.assertEqual(r["status"], "RESEARCH_LISTING_OBSERVATIONS_ONLY")
        self.assertEqual(r["schema"], SCHEMA)
        self.assertEqual(r["mm2ObservationRows"], 3)
        self.assertEqual(r["datasetRows"], 4)
        self.assertEqual(r["mm2DistinctSlugs"], 2)
        self.assertEqual(r["mm2DistinctObservedDays"], 2)
        self.assertEqual(r["mm2LatestObservedDay"], "2026-11-12")
        self.assertEqual(r["datasetAgeCalendarDays"], 1)
        self.assertEqual(len(r["inputSha256"]), 64)
        self.assertIn("FairStash", r["attribution"])
        self.assertIn("creativecommons.org", r["licenseUrl"])

    def test_item_two_observed_days_not_a_price(self):
        p = valid()["itemObservation"]
        self.assertEqual(p["latestDaySellingObserved"], 3)
        self.assertEqual(p["previousCalendarDaySellingObserved"], 0)
        self.assertEqual(p["latestDayBuyingObserved"], 1)
        self.assertIsNone(p["previousCalendarDayBuyingObserved"])
        self.assertTrue(p["dayGapIsUnknownNotZero"])
        self.assertFalse(p["rawGameItemKeyAuthenticated"])
        self.assertFalse(p["executableLiquiditySignal"])

    def test_absent_last_day_is_unknown_not_zero(self):
        rows = [R[0], R[2], (
            "Murder Mystery 2", "Another Item", "other-item",
            "2026-11-12", "9", "2")]
        p = valid(rows)["itemObservation"]
        self.assertFalse(p["observedOnDatasetLatestDay"])
        self.assertIsNone(p["latestDaySellingObserved"])
        self.assertEqual(p["lastSeenDay"], "2026-11-11")

    def test_missing_item_is_unknown_not_zero(self):
        p = valid(picked="not-listed")["itemObservation"]
        self.assertFalse(p["observedAnyDay"])
        self.assertIsNone(p["latestDaySellingObserved"])
        self.assertIsNone(p["lastSeenDay"])

    def test_explicit_zero_distinct_from_missing_row(self):
        rows = [
            ("MM2", "Test Axe", "test-axe", "2026-11-12", "0", "0")
        ]
        p = valid(rows)["itemObservation"]
        self.assertTrue(p["observedOnDatasetLatestDay"])
        self.assertEqual(p["latestDaySellingObserved"], 0)
        self.assertEqual(p["latestDayBuyingObserved"], 0)

    def test_buying_empty_is_unknown_not_zero(self):
        rows = [("mm2", "Test Axe", "test-axe", "2026-11-12", "1", "")]
        r = valid(rows)
        self.assertEqual(r["mm2RowsWithBuyingUnknown"], 1)
        self.assertIsNone(r["itemObservation"]["latestDayBuyingObserved"])

    def test_conservative_stale_blocks_even_after_fresh_read(self):
        r = valid(R, observed="2026-11-19T12:00:00Z")
        self.assertEqual(r["status"], "BLOCKED_STALE_LISTING_SAMPLE")
        self.assertEqual(r["reason"], "LAST_MM2_OBSERVATION_TOO_OLD")
        self.assertFalse(r["mayFeedLiveStrategy"])

    def test_untrusted_source_url_blocks(self):
        r = valid(source="https://fake.example/data/supply.csv")
        self.assertEqual((r["status"], r["reason"]),
                         ("BLOCKED", "SOURCE_URL_NOT_CANONICAL"))

    def test_invalid_clock_timezone(self):
        for bad in ("2026-11-13", "2026-11-13T14:00:00+02:00",
                    "2026-11-13T99:00:00Z", "", None, 101):
            with self.subTest(bad=bad):
                self.assertEqual(valid(observed=bad)["status"], "BLOCKED")

    def test_future_mm2_observation_not_allowed(self):
        rows = [("MM2", "Test Axe", "test-axe", "2026-11-14", "1", "")]
        self.assertEqual(valid(rows)["reason"], "MM2_FUTURE_OBSERVATION")

    def test_duplicate_slug_day_blocks(self):
        rows = [R[0], R[0]]
        self.assertEqual(valid(rows)["reason"], "MM2_DUPLICATE_SLUG_DAY")

    def test_slug_label_collision_blocks(self):
        rows = [R[0], ("MM2", "Different Axe", "test-axe",
                       "2026-11-12", "3", "")]
        self.assertEqual(valid(rows)["reason"],
                         "MM2_ITEM_SLUG_LABEL_COLLISION")

    def test_negative_or_noninteger_counts_block(self):
        for value in ("-1", "NaN", "1.5", "1e5", "∞", " 2", "01", ""):
            with self.subTest(value=value):
                rows = [("MM2", "Test Axe", "test-axe",
                         "2026-11-12", value, "")]
                self.assertEqual(valid(rows)["reason"],
                                 "INVALID_SELLING_COUNT")

    def test_invalid_buying_blocks_even_with_valid_selling(self):
        for buying in ("-1", "NaN", "1.2", "00", " 1"):
            with self.subTest(buying=buying):
                rows = [("MM2", "Test Axe", "test-axe",
                         "2026-11-12", "2", buying)]
                self.assertEqual(valid(rows)["reason"],
                                 "INVALID_BUYING_COUNT")

    def test_no_mm2_rows_not_a_positive_dataset(self):
        self.assertEqual(valid([R[3]])["reason"], "MM2_ROWS_MISSING")

    def test_other_game_untrusted_measurements_ignored(self):
        rows = [R[0], R[1], ("Other Game", "Giant Price", "ignore",
                              "2050-01-01", "-500", "not numeric")]
        r = valid(rows)
        self.assertEqual(r["mm2ObservationRows"], 2)
        self.assertEqual(r["status"], "RESEARCH_LISTING_OBSERVATIONS_ONLY")

    def test_csv_header_exact(self):
        for head in ([*FIELDS, "price"], FIELDS[:5],
                     ["item", "game", *FIELDS[2:]]):
            with self.subTest(head=head):
                r = audit_csv(encode(columns=head), evaluated_utc=NOW)
                self.assertEqual(r["reason"], "CSV_COLUMNS_NOT_CANONICAL")

    def test_extra_csv_cell_rejected(self):
        rows = [("MM2", "Test Axe", "test-axe",
                 "2026-11-12", "2", "0", "SNEAKY")]
        self.assertEqual(valid(rows)["reason"], "CSV_ROW_INVALID")

    def test_invalid_unicode_rejected(self):
        self.assertEqual(audit_csv(b"\xff\xfe", evaluated_utc=NOW)["reason"],
                         "CSV_UTF8_INVALID")

    def test_binary_nul_rejected(self):
        self.assertEqual(audit_csv(encode() + b"\x00",
                                   evaluated_utc=NOW)["reason"],
                         "CSV_BINARY_CONTENT_INVALID")

    def test_utf8_bom_allowed(self):
        raw = b"\xef\xbb\xbf" + encode()
        self.assertEqual(audit_csv(raw, evaluated_utc=NOW)["status"],
                         "RESEARCH_LISTING_OBSERVATIONS_ONLY")

    def test_formula_labels_blocked(self):
        for first in ("=", "+", "-", "@"):
            with self.subTest(first=first):
                rows = [("MM2", first + "cmd()", "test-axe",
                         "2026-11-12", "1", "")]
                self.assertEqual(valid(rows)["reason"],
                                 "MM2_ITEM_LABEL_INVALID")

    def test_control_character_label_blocked(self):
        rows = [("MM2", "Test\nAxe", "test-axe",
                 "2026-11-12", "2", "")]
        self.assertEqual(valid(rows)["reason"], "MM2_ITEM_LABEL_INVALID")

    def test_bad_slug_or_selected_slug_blocked(self):
        rows = [("MM2", "Test Axe", "../admin",
                 "2026-11-12", "1", "")]
        self.assertEqual(valid(rows)["reason"], "MM2_SLUG_INVALID")
        self.assertEqual(valid(picked="../admin")["reason"],
                         "SELECTED_SLUG_INVALID")

    def test_impossible_calendar_day(self):
        rows = [("MM2", "Test Axe", "test-axe",
                 "2026-02-30", "1", "")]
        self.assertEqual(valid(rows)["reason"], "INVALID_DAY")

    def test_empty_and_oversized_inputs(self):
        self.assertEqual(audit_csv(b"", evaluated_utc=NOW)["reason"],
                         "CSV_SIZE_INVALID")
        self.assertEqual(audit_csv(b"x" * 16_000_001,
                                   evaluated_utc=NOW)["reason"],
                         "CSV_SIZE_INVALID")

    def test_real_provider_comment_preamble_before_columns(self):
        """FairStash's own mirror CSV begins with # descriptive lines."""
        raw = (b"# FairStash: observations, not prices\n"
               b"# CC BY 4.0 but this comment does not authenticate origin\n"
               + encode())
        r = audit_csv(raw, evaluated_utc=NOW, item_slug="test-axe")
        self.assertEqual(r["status"], "RESEARCH_LISTING_OBSERVATIONS_ONLY")
        self.assertEqual(r["untrustedHeaderCommentLines"], 2)
        self.assertEqual(r["itemObservation"]["latestDaySellingObserved"], 3)
        self.assertFalse(r["sourceHttpOriginIndependentlyAuthenticated"])

    def test_historical_mirror_is_stale_even_when_fetched_now(self):
        raw = (b"# Older repository mirror, not current official export\n"
               b"# Days checked so far: mm2 3\n"
               + encode([("mm2", "Test Axe", "test-axe",
                          "2026-09-08", "9", "1")]))
        r = audit_csv(raw, evaluated_utc=NOW, item_slug="test-axe")
        self.assertEqual(r["status"], "BLOCKED_STALE_LISTING_SAMPLE")
        self.assertEqual(r["mm2LatestObservedDay"], "2026-09-08")
        self.assertFalse(r["mayFeedLiveStrategy"])

    def test_genuine_mirror_issues_block_instead_of_fabricating_keys(self):
        rows = [
            ("mm2", "Chroma Beach Set 2026", "",
             "2026-09-08", "12", ""),
        ]
        self.assertEqual(valid(rows)["reason"], "MM2_SLUG_INVALID")
        duplicate = [
            ("mm2", "Test Axe", "test-axe",
             "2026-09-08", "1", ""),
            ("mm2", "Test Axe", "test-axe",
             "2026-09-08", "3", ""),
        ]
        self.assertEqual(valid(duplicate)["reason"],
                         "MM2_DUPLICATE_SLUG_DAY")

    def test_midstream_comment_or_giant_preamble_blocks(self):
        raw = encode() + b"# fake publisher freshness 2026-11-13\n"
        self.assertEqual(audit_csv(raw, evaluated_utc=NOW)["reason"],
                         "CSV_ROW_INVALID")
        raw = b"# x\n" * 33 + encode()
        self.assertEqual(audit_csv(raw, evaluated_utc=NOW)["reason"],
                         "CSV_PREAMBLE_INVALID")

    def test_authority_invariants_for_all_results(self):
        cases = [
            valid(), valid(observed="2026-11-19T00:00:00Z"),
            audit_csv(b"\xff", evaluated_utc=NOW),
            valid(source="https://fake.example"),
        ]
        false = [
            "sourceHttpOriginIndependentlyAuthenticated",
            "gameRawKeyIdentityProven", "itemTradeSettlementProven",
            "observedCompletedTradeLiquidityVerified",
            "actualInventorySupplyMeasured", "postedListingsAreCompletedTrades",
            "missingDaysAreZeros", "priceDataPresent",
            "verifiedMarketQuote", "mayFeedStage120AsVerifiedMarket",
            "mayFeedLiveStrategy", "authorizesTrade", "authorizesOffer",
            "authorizesAccept", "mayReportProfit",
            "maySendDiscordWebhook", "mayUseForStrategyLearning",
            "serverCompletionProven",
        ]
        for r in cases:
            for key in false:
                self.assertIs(r[key], False, (r["status"], key))
            self.assertEqual(r["tradeOutcome"], "UNKNOWN")
            self.assertNotIn("value", r)
            self.assertNotIn("profit", r)
            self.assertNotIn("realLiquidity", r)

    def test_100_deterministic_mutations_never_grant_authority(self):
        base = list(R)
        for n in range(100):
            rows = list(base)
            bad = str(n) + (".0" if n % 2 else "x")
            rows[0] = ("MM2", "Test Axe", "test-axe",
                       "2026-11-11", bad, "")
            with self.subTest(n=n):
                r = valid(rows)
                self.assertEqual(r["status"], "BLOCKED")
                self.assertFalse(r["authorizesOffer"])
                self.assertFalse(r["authorizesAccept"])


if __name__ == "__main__":
    unittest.main()
