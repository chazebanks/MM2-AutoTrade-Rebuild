"""Adversarial source and original-key tests for direct MM2Values page parser."""
from __future__ import annotations

from copy import deepcopy
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import unittest

from pdiddler.system2.c9_mm2values_firstparty_189 import (
    MM2ValuesBlocked, PAGES, collect, norm, parse_home, parse_tier,
    validate_freshness, fetch_page,
)

SRC = Path(__file__).resolve().parents[2] / "pdiddler/system2"
OLD = json.loads((SRC / "c9_research_public_189_crosswalk.json").read_text("utf-8"))
NOW = "2026-11-15T20:19:53Z"
PRICES = {"Gingerscope": 16000, "Harvester": 275, "Icepiercer": 185,
          "EmberscytheChroma": 12250, "FlowerwoodKnife": 230}


def build_html():
    html = {}
    for category in ("ancient", "godly", "chroma"):
        items = [r for r in OLD["items"] if r["marketCategory"] == category]
        if category == "ancient":
            items.append({"rawGameKeyCandidate": "EXCLUDED_NIK",
                          "marketName": "Niks Scythe", "mm2Listed": 250000000})
        cards = []
        for r in items:
            name = r["marketName"]
            price = PRICES.get(r["rawGameKeyCandidate"], r["mm2Listed"])
            if category == "chroma":
                label = f'<b><div id="chromas" class="chroma-text">{name}</div></b>'
            else:
                label = f"<b>{name}</b>"
            cards.append(
                '<div class="stackable">'
                f'<img src="https://www.mm2values.com/img/fixture.png">'
                f'{label}<br> Value: {price:,}<br>Range: N/A '
                '<br>Demand: 5 - Rarity: 4<br>Stability: Stable<hr>'
                '<input type="button" value="SV"></div>'
            )
        html[category] = (f"<html><body><div class='main-content'>"
                          f"<span class='itemheader'>- ancient items -</span>"
                          if category=="ancient" else
                          f"<html><body><div class='main-content'>"
                          f"<span class='itemheader'>- {category} items -</span>")
        html[category] += "".join(cards) + "</div></body></html>"
    html["home"] = ("<html><body><main><b>VALUES UPDATED: "
                    "11/13/2026 12:19:30pm EST</b></main></body></html>"
                    + "<!-- public content -->" * 40)
    return html


class FirstPartyMM2Values189(unittest.TestCase):
    def setUp(self):
        self.pages = build_html()

    def call(self,pages=None,mapped=None,now=NOW):
        return collect(self.pages if pages is None else pages,
                       OLD if mapped is None else mapped,
                       captured_utc=now,
                       transport_label="FIRECRAWL_MEDIATED_HTTPS_RESEARCH")

    def test_all_original_189_keys_and_one_explicitly_excluded_extra(self):
        x=self.call()
        self.assertEqual(len(x["rows"]),189)
        self.assertEqual(x["matchedHistoricalGameKeys"],189)
        self.assertEqual(x["categoryGameKeys"],{"ancient":15,"godly":128,"chroma":46})
        self.assertEqual(x["excludedReviewedExtraAncients"],1)
        self.assertEqual({z["rawGameKeyCandidate"] for z in x["rows"]},
                         {z["rawGameKeyCandidate"] for z in OLD["items"]})
        self.assertNotIn("EXCLUDED_NIK",{z["rawGameKeyCandidate"] for z in x["rows"]})
        self.assertEqual(sum(z["outgoingGingerscopeProtected"] for z in x["rows"]),1)
        self.assertEqual(x["status"],"FIRST_PARTY_MM2VALUES_189_RESEARCH_NOT_TRADABLE")

    def test_known_new_first_party_values_are_separate_from_aggregator(self):
        x=self.call()
        by={z["rawGameKeyCandidate"]:z for z in x["rows"]}
        for key,value in PRICES.items():
            self.assertEqual(by[key]["mm2FirstPartyListed"],value)
        self.assertEqual(by["EmberscytheChroma"]["mm2FirstPartyListed"],12250)
        self.assertEqual(by["EmberscytheChroma"]["historicalAggregatorMM2ListedForAuditOnly"],12000)
        self.assertTrue(by["Gingerscope"]["outgoingGingerscopeProtected"])
        self.assertEqual(x["sourceTransport"],"FIRECRAWL_MEDIATED_HTTPS_RESEARCH")
        self.assertFalse(x["firstPartyDirectGithubFetchVerified"])

    def test_does_not_authorize_trades_learning_or_live_pricing(self):
        x=self.call()
        for key in ("researchOnly",):
            self.assertIs(x[key],True)
        for key in ("safeForLiveMarketQuotes","authorizesTrade","authorizesOffer",
                    "authorizesAccept","mayReportProfit","mayUseForStrategyLearning",
                    "tradeCompletionProven","actualRobloxItemIdentityVerified",
                    "measuredRetradability","firstPartyPublisherSignatureVerified"):
            self.assertIs(x[key],False)
        for row in x["rows"]:
            self.assertFalse(row["authenticatedRobloxItemInstance"])
            self.assertFalse(row["measuredCounterpartyTradeFill"])

    def test_page_category_missing_or_duplicate_wont_pass(self):
        for bad in ("ancient","godly","chroma"):
            pages=self.pages.copy()
            pages[bad]=pages[bad].replace('<div class="stackable">',"<div class='missing-card'>",1)
            with self.subTest(category=bad), self.assertRaisesRegex(MM2ValuesBlocked,"CARD_COUNT"):
                self.call(pages=pages)

    def test_unapproved_190th_key_or_change_in_extra_cannot_pass(self):
        pages=self.pages.copy()
        pages["ancient"]=pages["ancient"].replace("Niks Scythe","Other Synthetic Ancient")
        with self.assertRaisesRegex(MM2ValuesBlocked,"NEW_OR_MISSING_PUBLIC_ITEM"):
            self.call(pages=pages)

    def test_public_alias_mismatch_must_not_guess_item_instance(self):
        pages=self.pages.copy()
        pages["godly"]=pages["godly"].replace("Flowerwood Knife","Unknown Flowerwood")
        with self.assertRaisesRegex(MM2ValuesBlocked,"PUBLIC_NAME_NOT_FOUND"):
            self.call(pages=pages)

    def test_public_duplicate_name_blocked_even_when_counts_right(self):
        pages=self.pages.copy()
        pages["godly"]=pages["godly"].replace("Flowerwood Knife","Harvester")
        with self.assertRaises(MM2ValuesBlocked):
            self.call(pages=pages)

    def test_original_registry_content_and_hash_not_rewritten(self):
        x=deepcopy(OLD)
        x["items"][0]["mm2Listed"]=999999
        with self.assertRaisesRegex(MM2ValuesBlocked,"HISTORICAL_189_PIN_CHANGED"):
            self.call(mapped=x)
        x=deepcopy(OLD)
        x["items"][0]["outgoingGingerscopeProtected"]=True
        # This modifies crosswalk content and must be caught even before guard.
        with self.assertRaisesRegex(MM2ValuesBlocked,"HISTORICAL_189_PIN_CHANGED"):
            self.call(mapped=x)

    def test_wrong_html_header_and_fake_page_identity(self):
        pages=self.pages.copy()
        pages["godly"]=pages["godly"].replace("godly items","common items",1)
        with self.assertRaisesRegex(MM2ValuesBlocked,"WRONG_CATEGORY_HEADER"):
            self.call(pages=pages)
    def test_artwork_url_does_not_authenticate_or_poison_price_rows(self):
        pages=self.pages.copy()
        pages["godly"]=pages["godly"].replace("https://www.mm2values.com/img/fixture.png",
                                               "https://example.invalid/img/fixture.png",1)
        candidate=self.call(pages=pages)
        baseline=self.call()
        self.assertEqual(candidate["rows"],baseline["rows"])
        self.assertNotIn("example.invalid",json.dumps(candidate["rows"]))

    def test_invalid_cards_do_not_silently_fallback(self):
        for from_text,to_text in [
            ("Value: 16,000","Value: Priceless"),
            ("Demand: 5 - Rarity: 4","Demand: UNKNOWN - Rarity: 4"),
            ("Stability: Stable","Stability: "),
            ("Range: N/A","Range: "),
        ]:
            pages=self.pages.copy()
            pages["ancient"]=pages["ancient"].replace(from_text,to_text,1)
            with self.subTest(text=from_text),self.assertRaises(MM2ValuesBlocked):
                self.call(pages=pages)

    def test_official_clock_timezone_and_staleness_fail_closed(self):
        pages=self.pages.copy()
        pages["home"]=pages["home"].replace("12:19:30pm EST","12:19:30pm EDT")
        with self.assertRaisesRegex(MM2ValuesBlocked,"PUBLISHER_TIMEZONE_CONFLICT"):
            self.call(pages=pages)
        with self.assertRaisesRegex(MM2ValuesBlocked,"PUBLISHER_CLOCK_STALE_OR_FUTURE"):
            self.call(now="2026-12-01T00:00:00Z")
        with self.assertRaisesRegex(MM2ValuesBlocked,"PUBLISHER_CLOCK_STALE_OR_FUTURE"):
            self.call(now="2026-11-13T00:00:00Z")

    def test_six_hour_source_ttl_and_future_block(self):
        x=self.call()
        source=datetime.fromisoformat(x["sourceCapturedUtc"].replace("Z","+00:00"))
        self.assertEqual(validate_freshness(x,now_utc=(source+timedelta(hours=6))
                         .isoformat().replace("+00:00","Z"))["sourceAgeSeconds"],21600)
        for offset in (-1,21601):
            with self.subTest(offset=offset),self.assertRaisesRegex(MM2ValuesBlocked,
                             "CAPTURE_EXPIRED_OR_FUTURE"):
                validate_freshness(x,now_utc=(source+timedelta(seconds=offset))
                                   .isoformat().replace("+00:00","Z"))

    def test_bad_capture_clock_and_transport_refused(self):
        with self.assertRaises(MM2ValuesBlocked):
            self.call(now="2026-11-15T20:19:53")
        with self.assertRaises(MM2ValuesBlocked):
            collect(self.pages,OLD,captured_utc=NOW,transport_label="PUBLISHER_SIGNED")

    def test_direct_fetch_rejects_url_outside_authorized_four_pages(self):
        with self.assertRaisesRegex(MM2ValuesBlocked,"UNREVIEWED_URL"):
            fetch_page("https://example.invalid/fake")

    def test_source_field_does_not_claim_mm2tradehub_is_first_party(self):
        x=self.call()
        self.assertEqual(x["sourceSite"],"https://www.mm2values.com/")
        self.assertEqual(x["publisherUpdatedAt"],"2026-11-13T12:19:30-05:00")
        self.assertTrue(all("mm2values.com" in s for s in x["pageURLs"].values()))
        self.assertNotIn("MM2TradeHub",json.dumps(x))


if __name__=="__main__":
    unittest.main()
