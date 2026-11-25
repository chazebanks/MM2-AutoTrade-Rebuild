"""Reviewable direct captures and edition transitions through production admission."""
from collections import Counter
from hashlib import sha256
import json
import unittest

from pdiddler.system2 import supreme_market_editions as market
from pdiddler.system2.supreme_only_strategy_research import SupremeOnlyBlocked, review
from pdiddler.system2.manual_portfolio_review import DEFAULT_CATALOG


BASE_PUBLICATION = "2026-11-26T01:00:00-05:00"
BASE_CAPTURE = "2026-11-26T07:00:00Z"
NEXT_PUBLICATION = "2026-11-27T01:00:00-05:00"
NEXT_CAPTURE = "2026-11-27T07:00:00Z"


def card(page, item, name, price, *, demand="2", stability="Stable", span="[N/A]", hidden=False):
    hide = ' style="display:none"' if hidden else ''
    return (
        f'<div class="itemcolumn" data-value="{price}" data-demand="{demand}" '
        f'data-stability="{stability}" data-event="Christmas" data-year="2025"{hide}>'
        f'<div class="itemcell" id="{item}"><button data-name="{name}"></button>'
        f'<div class="itemhead"><a class="itemlink" href="{page}?item={item}">{name}</a></div>'
        f'<div class="itembody"><b class="itemvalue">{price}</b>'
        f'<b class="itemrange">{span}</b><b class="itemstability">{stability}</b></div></div></div>'
    )


def archive(*, changed=False, publish=None, capture=None, tamper=False, mixed_clock=False,
            target_missing=False):
    stamp = publish or (NEXT_PUBLICATION if changed else BASE_PUBLICATION)
    captured = capture or (NEXT_CAPTURE if changed else BASE_CAPTURE)
    banner = (
        f'<div id="sv-values-updated" data-updated-iso="{stamp}">Values Last Updated</div>'
        '<aside>' + 'x' * 500 + '</aside>'
    )
    ancient = "/mm2/ancients"
    godly = "/mm2/godlies"
    chroma = "/mm2/chromas"
    pages = {
        "home": banner + f'<section id="updatelog">SUPREME VALUES UPDATE {stamp[8:10]}/11/2026 (DD/MM/YYYY)</section>',
        "ancient": banner + '<h1>MM2 Ancient Values</h1>' + ('' if target_missing else card(
            ancient, "Gingerscope", "Gingerscope", 160 if changed else 150, demand="5" if changed else "4",
            stability="Fluctuating" if changed else "Stable", span="140 - 165" if changed else "[N/A]",
        )) + (
            '<div class="itemcolumn"><div class="itemcell"><div class="itemhead">Priceless Hatchet</div>'
            '<div class="itembody">Value - <b>Priceless</b></div></div></div>'
        ),
        "godly": banner + '<h1>MM2 Godly Values</h1>' + card(
            godly, "Bioblade", "Bioblade", 21 if changed else 10
        ) + (card(godly, "UnknownVariant", "Example Variant", 100) if changed else card(
            godly, "RemovedWeapon", "Removed Weapon", 13
        )) + card(godly, "HiddenDuplicate", "Hidden Duplicate", 1000, hidden=True) + (
            card(godly, "RemovedWeapon", "Removed Weapon", 13, hidden=True) if changed else ""
        ),
        "chroma": banner + '<h1>MM2 Chroma Values</h1>' + card(chroma, "CLuger", "Chroma Luger", 24) + (
            '<section data-tier="pets">' + card(chroma, "CPet", "Chroma Pet", 2) + '</section>'
        ),
    }
    if mixed_clock:
        pages["chroma"] = pages["chroma"].replace(stamp, NEXT_PUBLICATION)
    return json.dumps({
        "schema": "gingerscope-supreme-reviewed-pages-v1",
        "sourceCapturedUtc": captured,
        "pages": {k: {"url": market.PUBLISHER_URLS[k], "html": html,
                      "sha256": "0" * 64 if tamper and k == "chroma" else sha256(html.encode()).hexdigest()}
                  for k, html in pages.items()},
    }, sort_keys=True).encode()


def loaded(*, changed=False):
    raw = archive(changed=changed)
    return market.load_edition(raw, evaluated_at_utc=NEXT_CAPTURE if changed else BASE_CAPTURE,
                               expected_sha256=sha256(raw).hexdigest())


class MarketEditionTests(unittest.TestCase):
    def test_pinned_edition_uses_original_cutoff_and_range_receipt(self):
        raw = DEFAULT_CATALOG.read_bytes()
        edition = market.load_edition(raw, evaluated_at_utc="2026-11-25T12:09:59Z")
        self.assertEqual(edition.provenance["expiresUtc"], "2026-11-25T12:09:59Z")
        self.assertEqual(edition.summary()["categories"], {"ancient": 15, "godly": 128, "chroma": 46})
        self.assertEqual(sum(row["published_range"] is not None for row in edition.rows.values()), 17)
        with self.assertRaisesRegex(SupremeOnlyBlocked, "EXPIRED"):
            market.load_edition(raw, evaluated_at_utc="2026-11-25T12:10:00Z")

    def test_different_census_uses_publisher_ids_and_distinguishes_exclusions(self):
        edition = loaded(changed=True)
        summary = edition.summary()
        self.assertEqual(summary["categories"], {"ancient": 1, "godly": 2, "chroma": 1})
        self.assertEqual(edition.rows["Gingerscope"]["published_range"], {"low": 140, "high": 165})
        variant = next(row for row in edition.rows.values() if row["officialItemId"] == "UnknownVariant")
        self.assertIsNone(variant["historicalRawGameKeyCandidate"])
        self.assertEqual(variant["publisherVariant"], {"event": "Christmas", "year": "2025"})
        outcomes = Counter(row["reason"] for row in summary["excluded"])
        self.assertEqual(outcomes, {"PRICES_UNAVAILABLE": 1, "HIDDEN": 2, "PET": 1})
        self.assertFalse(edition.provenance["sourceSignatureVerified"])

    def test_new_capture_integrity_requires_independent_archive_pin_and_consistent_pages(self):
        raw = archive()
        with self.assertRaisesRegex(SupremeOnlyBlocked, "REVIEWED_SHA256_REQUIRED"):
            market.load_edition(raw, evaluated_at_utc=BASE_CAPTURE)
        with self.assertRaisesRegex(SupremeOnlyBlocked, "ARCHIVE_SHA256_MISMATCH"):
            market.load_edition(raw + b"\n", evaluated_at_utc=BASE_CAPTURE, expected_sha256=sha256(raw).hexdigest())
        corrupt = archive(tamper=True)
        with self.assertRaisesRegex(SupremeOnlyBlocked, "PAGE_SHA256_MISMATCH"):
            market.load_edition(corrupt, evaluated_at_utc=BASE_CAPTURE,
                                expected_sha256=sha256(corrupt).hexdigest())
        mixed = archive(mixed_clock=True)
        with self.assertRaisesRegex(SupremeOnlyBlocked, "PUBLICATION_CHANGED_DURING_CAPTURE"):
            market.load_edition(mixed, evaluated_at_utc=BASE_CAPTURE, expected_sha256=sha256(mixed).hexdigest())

    def test_same_historical_publication_cannot_reset_expiry(self):
        raw = archive(publish="2026-11-23T19:13:44-05:00", capture="2026-11-25T12:10:00Z")
        with self.assertRaisesRegex(SupremeOnlyBlocked, "SOURCE_EXPIRED"):
            market.load_edition(raw, evaluated_at_utc="2026-11-25T12:10:00Z",
                                expected_sha256=sha256(raw).hexdigest())

    def test_clocks_outside_utc_datetime_bounds_fail_closed(self):
        raw = DEFAULT_CATALOG.read_bytes()
        for malformed in ("0001-01-01T00:00:00+23:59", "9999-12-31T23:59:59-23:59"):
            with self.subTest(clock=malformed), self.assertRaisesRegex(SupremeOnlyBlocked, "CLOCK_INVALID"):
                market.load_edition(raw, evaluated_at_utc=malformed)

    def test_transitions_expose_economic_and_census_changes_and_reject_rollback(self):
        previous, current = loaded(), loaded(changed=True)
        delta = market.compare_editions(previous, current)
        self.assertEqual(delta["added"], ["godly:UnknownVariant"])
        self.assertEqual(delta["removed"], ["godly:RemovedWeapon"])
        self.assertEqual(delta["newly_excluded"], {"godly:RemovedWeapon": ["HIDDEN"]})
        self.assertEqual(delta["changes"]["ancient:Gingerscope"]["listed_value"], {"before": 150, "after": 160})
        self.assertEqual(set(delta["changes"]["ancient:Gingerscope"]),
                         {"listed_value", "demand", "stability", "published_range"})
        self.assertTrue(delta["invalidates_prior_evaluations"])
        self.assertFalse(market.compare_editions(current, current)["invalidates_prior_evaluations"])
        with self.assertRaisesRegex(SupremeOnlyBlocked, "PUBLICATION_ROLLBACK"):
            market.compare_editions(current, previous)

    def test_reviewer_distinguishes_known_priceless_excluded_and_unknown_identity(self):
        edition = loaded(changed=True)
        self.assertEqual(edition.identity_status("ancient:Gingerscope"), "PRICED_WEAPON")
        self.assertEqual(edition.identity_status("godly:HiddenDuplicate"), "HIDDEN")
        self.assertEqual(edition.identity_status("chroma:CPet"), "PET")
        self.assertEqual(edition.identity_status("ancient:Priceless Hatchet"), "PRICES_UNAVAILABLE")
        self.assertEqual(edition.identity_status("godly:UnrecognizedItem"), "UNKNOWN")

    def test_removed_target_remains_protected_and_unknown_without_blocking_other_analysis(self):
        raw = archive(changed=True, target_missing=True)
        edition = market.load_edition(raw, evaluated_at_utc=NEXT_CAPTURE, expected_sha256=sha256(raw).hexdigest())
        self.assertEqual(edition.summary()["gingerscope"], {
            "publisher_id": "ancient:Gingerscope", "listed_value": None, "outgoing_protected": True,
        })
        self.assertIn("ancient:Gingerscope", market.compare_editions(loaded(), edition)["removed"])
        keys = {row["officialItemId"]: k for k, row in edition.rows.items()}
        option = {"kind": "HYPOTHETICAL_RESEARCH_ONLY", "valuationSource": "SUPREME_ONLY",
                  "give": [{"rawGameKeyCandidate": keys["Bioblade"], "quantity": 1}],
                  "receive": [{"rawGameKeyCandidate": keys["CLuger"], "quantity": 1}]}
        result = review(None, owned={keys["Bioblade"]: 1}, alternatives=[option],
                        evaluated_at_utc=NEXT_CAPTURE, edition=edition)
        self.assertIsNone(result["gingerscopeSupremeTargetValue"])
        self.assertEqual(result["hypotheticalAlternatives"][0]["supremeListedValueGain"], 3)

    def test_review_reuses_validated_new_edition_and_expiry_protection(self):
        edition = loaded(changed=True)
        item = next(k for k, row in edition.rows.items() if row["officialItemId"] == "Bioblade")
        alternative = {"kind": "HYPOTHETICAL_RESEARCH_ONLY", "valuationSource": "SUPREME_ONLY",
                       "give": [{"rawGameKeyCandidate": item, "quantity": 1}],
                       "receive": [{"rawGameKeyCandidate": "Gingerscope", "quantity": 1}]}
        report = review(None, owned={item: 1}, alternatives=[alternative],
                        evaluated_at_utc=NEXT_CAPTURE, edition=edition)
        self.assertEqual(report["hypotheticalAlternatives"][0]["supremeListedValueGain"], 139)
        expired = review(None, owned={item: 1}, alternatives=[alternative],
                         evaluated_at_utc="2026-11-27T13:00:01Z", edition=edition)
        self.assertEqual(expired["status"], "BLOCKED")
        self.assertIn("EXPIRED", expired["reason"])
        alternative["give"], alternative["receive"] = alternative["receive"], alternative["give"]
        protected = review(None, owned={"Gingerscope": 1}, alternatives=[alternative],
                           evaluated_at_utc=NEXT_CAPTURE, edition=edition)
        self.assertEqual(protected["reason"], "SUPREME_ONLY_GINGERSCOPE_NEVER_OUTGOING")


if __name__ == "__main__":
    unittest.main()
