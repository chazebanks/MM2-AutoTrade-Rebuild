"""Synthetic adversarial tests for actual first-party Supreme site collector.

These offline DOM fixtures are NOT first-party network evidence. The separate
GitHub Actions workflow must fetch all four actual official web pages.
"""
from __future__ import annotations

from html import escape
from pathlib import Path
import copy
import json
import unittest

from pdiddler.system2 import c9_supreme_firstparty_189_research as s

ROOT = Path(__file__).resolve().parents[2]
MAPPED = json.loads((ROOT / "pdiddler/system2/c9_research_public_189_crosswalk.json").read_text())
STAMP = "2026-11-15T11:59:41-05:00"
UTC = "2026-11-15T19:30:00Z"


def head(extra=""):
    return ('<div id="sv-values-updated" data-updated-iso="' + STAMP
            + '">Values Last Updated - November 15th, 2026 at 11:59 AM</div>' + extra)


def fixture():
    out = {"home": "<html>" + head() + """
    <div id="updatelog">SUPREME VALUES UPDATE 15/11/2026 (DD/MM/YYYY):
      NEW ITEMS: Immortal reduced to 120</div></html>"""}
    titles = s.OFFICIAL_PAGE_HEADINGS
    for category in s.CATEGORIES:
        cols = []
        for row in MAPPED["items"]:
            if row["marketCategory"] != category:
                continue
            name = s.MANUAL_NAME_ALIASES.get(
                row["rawGameKeyCandidate"], row["marketName"])
            value = row["supremeListed"]
            if value is None:  # First-party Flowerwood exists; aggregator missing.
                value = 235
            cols.append(
                '<div class="itemcolumn" data-value="' + str(value)
                + '" data-demand="5" data-stability="Stable">'
                + '<div class="itemcell" id="' + escape(row["rawGameKeyCandidate"])
                + '"><button data-name="' + escape(name, quote=True)
                + '"></button></div></div>')
        out[category] = ("<html><head><title>" + titles[category]
                         + "</title></head>" + head()
                         + "<h1>" + titles[category] + "</h1>"
                         + '<section class="grid">' + "".join(cols)
                         + "</section></html>")
    return out


class C9FirstPartySupreme(unittest.TestCase):
    def test_exact_original_189_and_flowerwood_alias(self):
        r = s.audit(fixture(), MAPPED, captured_utc=UTC)
        self.assertEqual(r["matchedHistoricalGameKeys"], 189)
        self.assertEqual(r["categoryMatchedCounts"], {"ancient": 15, "godly": 128, "chroma": 46})
        self.assertEqual(r["sourceOfficialPublicationISO"], STAMP)
        self.assertTrue(r["all189OfficialPricesAndDemandParsed"])
        self.assertFalse(r["publisherHTTPSDirectlyFetched"])
        self.assertFalse(r["publisherCryptographicSignatureVerified"])
        self.assertFalse(r["authorizesTrade"])
        self.assertFalse(r["mayUseForStrategyLearning"])
        self.assertEqual(
            len([x for x in r["rows"] if x["nameAliasManuallyReviewed"]]), 1)
        self.assertTrue(next(x for x in r["rows"] if
                             x["rawGameKeyCandidate"] == "Gingerscope")[
                                 "outgoingGingerscopeProtected"])
        self.assertEqual(r["changedSupremePriceCount"], 1,
                         "Synthetic fixture changes ONLY aggregator-missing Flowerwood")

    def test_mapped_price_change_detected(self):
        p = fixture()
        p["ancient"] = p["ancient"].replace('data-value="270"', 'data-value="275"', 1)
        r = s.audit(p, MAPPED, captured_utc=UTC)
        self.assertGreaterEqual(r["changedSupremePriceCount"], 2)
        self.assertIn("Harvester", r["changedGameKeys"])
        self.assertFalse(r["canFeedAutomatedTrade"])

    def test_update_mid_capture_rejected(self):
        p = fixture()
        p["chroma"] = p["chroma"].replace(STAMP, "2026-11-15T12:00:41-05:00", 1)
        with self.assertRaisesRegex(s.SupremeBlocked, "CHANGED_DURING_FOUR_PAGE"):
            s.audit(p, MAPPED, captured_utc=UTC)

    def test_change_log_date_disagrees(self):
        p = fixture()
        p["home"] = p["home"].replace("UPDATE 15/11/2026", "UPDATE 13/11/2026")
        with self.assertRaisesRegex(s.SupremeBlocked, "CHANGELOG_AND_HEADER"):
            s.audit(p, MAPPED, captured_utc=UTC)

    def test_page_heading_changed(self):
        p = fixture()
        p["godly"] = p["godly"].replace("<h1>MM2 Godly Values</h1>",
                                         "<h1>MM2 Other Values</h1>")
        with self.assertRaisesRegex(s.SupremeBlocked, "HEADING_CHANGED"):
            s.audit(p, MAPPED, captured_utc=UTC)

    def test_missing_full_game_key_rejected(self):
        p = fixture()
        p["ancient"] = p["ancient"].replace('data-name="Gingerscope"',
                                             'data-name="NotGingerscope"')
        with self.assertRaises(s.SupremeBlocked):
            s.audit(p, MAPPED, captured_utc=UTC)

    def test_unreviewed_alias_rejected(self):
        p = fixture()
        p["godly"] = p["godly"].replace('data-name="Snowcannon"',
                                         'data-name="Chroma Snowcannon"')
        with self.assertRaisesRegex(s.SupremeBlocked, "NOT_EXACTLY_FOUND"):
            s.audit(p, MAPPED, captured_utc=UTC)

    def test_duplicate_official_name_rejected(self):
        p = fixture()
        p["ancient"] = p["ancient"].replace('data-name="Icepiercer"',
                                             'data-name="Gingerscope"')
        with self.assertRaisesRegex(s.SupremeBlocked, "DUPLICATE"):
            s.audit(p, MAPPED, captured_utc=UTC)

    def test_non_numeric_value_rejected(self):
        p = fixture()
        p["ancient"] = p["ancient"].replace('data-value="16000"',
                                             'data-value="Priceless"')
        with self.assertRaisesRegex(s.SupremeBlocked, "MAPPED_PRICE_INVALID"):
            s.audit(p, MAPPED, captured_utc=UTC)

    def test_forged_gingerscope_outbound_flag_rejected(self):
        m = copy.deepcopy(MAPPED)
        for row in m["items"]:
            if row["rawGameKeyCandidate"] == "Gingerscope":
                row["outgoingGingerscopeProtected"] = False
        with self.assertRaisesRegex(s.SupremeBlocked, "GINGERSCOPE_OUTBOUND"):
            s.audit(fixture(), m, captured_utc=UTC)

    def test_wrong_original_registry_rejected(self):
        m = copy.deepcopy(MAPPED)
        m["historicalRegistryBlob"] = "0" * 40
        with self.assertRaisesRegex(s.SupremeBlocked, "MAPPING_NOT_REVIEWED"):
            s.audit(fixture(), m, captured_utc=UTC)

    def test_future_or_stale_published_date(self):
        with self.assertRaisesRegex(s.SupremeBlocked, "STALE_OR_FUTURE"):
            s.audit(fixture(), MAPPED, captured_utc="2026-11-15T13:00:00Z")
        with self.assertRaisesRegex(s.SupremeBlocked, "STALE_OR_FUTURE"):
            s.audit(fixture(), MAPPED, captured_utc="2026-12-15T13:00:00Z")

    def test_invalid_utc(self):
        for now in (None, "2026-11-15T19:30:00-05:00", "broken", 7):
            with self.subTest(now=now), self.assertRaises(s.SupremeBlocked):
                s.audit(fixture(), MAPPED, captured_utc=now)

    def test_bad_demand_and_stability(self):
        p = fixture()
        p["godly"] = p["godly"].replace('data-demand="5"', 'data-demand="NaN"', 1)
        with self.assertRaisesRegex(s.SupremeBlocked, "DEMAND_FIELD_MISSING"):
            s.audit(p, MAPPED, captured_utc=UTC)
        p = fixture()
        p["chroma"] = p["chroma"].replace('data-stability="Stable"',
                                           'data-stability=""', 1)
        with self.assertRaisesRegex(s.SupremeBlocked, "STABILITY_FIELD_MISSING"):
            s.audit(p, MAPPED, captured_utc=UTC)


if __name__ == "__main__":
    unittest.main()
