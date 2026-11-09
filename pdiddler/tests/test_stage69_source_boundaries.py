"""Stage69 contract: real Nov6 publisher clock and hidden/pet source rows.

Synthetic markup built to exercise the existing original Supreme parser.
No refresh, network, prices to production, trades or live authorization.
"""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "refresh_supreme_snapshot", ROOT/"pdiddler/refresh_supreme_snapshot.py")
R = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(R)

PUBLISHED = "2026-11-06T10:56:07-05:00"
PUBLISHED_UTC = "2026-11-06T15:56:07Z"

def row(name, value="525", demand=5, stability="Fluctuating", hidden=False):
    style = ' style="display:none"' if hidden else ""
    return (
        f'<div class="itemcolumn"{style} data-value="{value}" '
        f'data-stability="{stability}" data-demand="{demand}">'
        f'<button data-name="{name}"></button>'
        f'<div class="itemhead">{name}</div>'
        f'<div class="itembody">Value - <b class="itemvalue">{value}</b><br>'
        f'Stability - <b class="itemstability">{stability}</b><br>'
        f'Demand - <b>{demand}</b><sep>Rarity - <b>3</b></div></div>'
    )

def page(kind, content, publication=PUBLISHED):
    return (f'<html><head><title>MM2 {kind.title()} Values - Supreme Values</title></head>'
            f'<body><div data-updated-iso="{publication}"></div>{content}</body></html>')

class Stage69PublisherAndCategoryEdges(unittest.TestCase):
    def test_publisher_clock_is_website_date_not_retrieval_time(self):
        rows, published = R.parse_page(page("ancient", row("Emberbow")), "ancient")
        self.assertEqual(published, PUBLISHED_UTC)
        self.assertEqual(rows[0]["supremeValue"], 525)
        self.assertEqual(rows[0]["name"], "Emberbow")
        self.assertEqual(rows[0]["demand"], 5)

    def test_hidden_godly_rows_cannot_poison_price_quote(self):
        text = page("godly", row("Mortal", "130", 3, "Fluctuating")
                    + row("Batwing", "1000000", hidden=True)
                    + row("Black Luger", "1000000", hidden=True))
        rows, published = R.parse_page(text, "godly")
        self.assertEqual([r["name"] for r in rows], ["Mortal"])
        self.assertEqual(published, PUBLISHED_UTC)

    def test_chroma_fire_pets_are_not_eligible_weapons(self):
        text = page(
            "chroma",
            '<section class="grid" data-tier="weapons">'
            + row("Chroma Emberbow", "6000", 6) + '</section>'
            + '<section class="grid" data-tier="pets">'
            + row("Chroma Fire Bat", "3", 1, "Stable")
            + row("Chroma Fire Pig", "3", 1, "Stable")
            + '</section>'
        )
        rows, _ = R.parse_page(text, "chroma")
        self.assertEqual([x["name"] for x in rows], ["Chroma Emberbow"])

    def test_new_hidden_or_pet_identity_requires_review(self):
        for kind, html in (
            ("godly", page("godly", row("Unknown Hidden Gun", hidden=True))),
            ("chroma", page("chroma",
                           '<section data-tier="pets">'
                           + row("Chroma Fire Dragon", "3") + '</section>')),
        ):
            with self.subTest(kind=kind), self.assertRaisesRegex(
                    ValueError, "unreviewed excluded"):
                R.parse_page(html, kind)

    def test_value_attribute_mismatch_and_mixed_publisher_fail(self):
        drift = page("ancient", row("Emberbow").replace('data-value="525"',
                                                       'data-value="400"'))
        with self.assertRaisesRegex(ValueError, "value attribute"):
            R.parse_page(drift, "ancient")
        two = page("godly", row("Mortal")) + (
            '<div data-updated-iso="2026-11-07T10:56:07-05:00"></div>')
        with self.assertRaisesRegex(ValueError, "publication"):
            R.parse_page(two, "godly")

    def test_pub_age_is_not_faked_by_retrieval_epoch(self):
        source_pub = R.epoch(PUBLISHED_UTC)
        # Old policy: an observation at +60h remains limited by +72h pub.
        o = source_pub + 60 * 3600
        src = {
            "ancient": {"observedAt": R.iso(o), "publishedAt": PUBLISHED_UTC},
            "godly": {"observedAt": R.iso(o), "publishedAt": PUBLISHED_UTC},
            "chroma": {"observedAt": R.iso(o), "publishedAt": PUBLISHED_UTC},
        }
        self.assertEqual(R.expiry(src), source_pub + 72 * 3600)
        # A new retrieval at +73h cannot make old publication current.
        src2 = {k: {"observedAt": R.iso(source_pub + 73 * 3600),
                    "publishedAt": PUBLISHED_UTC} for k in src}
        self.assertLess(R.expiry(src2), source_pub + 73 * 3600)

if __name__ == "__main__":
    unittest.main()
