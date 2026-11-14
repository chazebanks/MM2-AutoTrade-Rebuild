"""Fail-closed contract and adversarial tests for actual public tier pages, no HTTP."""
import unittest
from pdiddler.system2 import mm2tradehub_market_candidate as m

NOW = "2026-11-14T20:00:00Z"


def card(category, i, mm2="35", supreme="33", demand="5", stability="Stable", slug=None):
    slug = slug or ("gingerscope" if category == "ancient" and i == 1 else f"{category}-weapon-{i}")
    name = "Gingerscope" if slug == "gingerscope" else f"Weapon {i}"
    return (f'<a class="group card" href="https://mm2tradehub.com/values/{slug}">'
            f'<div><h3>{name}</h3><div>{category.title()} · TIER 5</div>'
            f'<div class="vs-row vs-mm2"><span class="vs-num">{mm2}</span></div>'
            f'<div class="vs-row vs-supreme"><span class="vs-num">{supreme}</span></div>'
            f'<div><span title="Demand {demand}">Demand</span><span>{stability}</span></div>'
            '</div></a>')


def tier(category):
    html = ''.join(card(category, i) for i in range(1, m.CATEGORIES[category] + 1))
    return (f'<html><head><title>MM2 {category.title()} Values (November 2026)</title></head>'
            '<body><main>' + html + '</main></body></html>')


def homepage(date="November 13, 2026"):
    return '<html><main><h1>MM2 Value List</h1><p>The MM2 list itself was last rebuilt on ' + date + '.</p></main></html>'


def fixture(path):
    return homepage() if path == '/values' else tier(path.split('/')[-1])


class CandidateMarketTests(unittest.TestCase):
    def test_positive_209_items_and_gingerscope(self):
        result = m.collect(fixture, NOW)
        self.assertEqual(result['itemCount'], 209)
        self.assertEqual(result['siteEditionDate'], '2026-11-13')
        self.assertFalse(result['canFeedLiveTrade'])
        self.assertFalse(result['exactGameWeaponIdentityProven'])
        self.assertFalse(result['authorizesAccept'])
        self.assertEqual([v for v in result['items'] if v['providerSlug'] == 'gingerscope'][0]['providerCategory'], 'ancient')

    def test_realistic_numeric_notation(self):
        self.assertEqual(m.price_of('16K'), 16000)
        self.assertEqual(m.price_of('2.5M'), 2500000)
        self.assertEqual(m.price_of('1.9K'), 1900)
        self.assertEqual(m.price_of('350'), 350)
        self.assertIsNone(m.price_of('Priceless'))
        self.assertIsNone(m.price_of('Award only'))

    def test_chroma_variant_not_claimed_as_real_game_id(self):
        row = m.parse_tier(tier('chroma'), 'chroma')[0]
        self.assertIsNone(row['rawGameWeaponKey'])
        self.assertFalse(row['chromaSubtypeVerified'])

    def test_truncated_page_fails(self):
        def get(path):
            return fixture(path).replace(card('ancient', 16), '') if path.endswith('ancient') else fixture(path)
        with self.assertRaisesRegex(m.MarketBlocked, 'CATEGORY_ITEM_COUNT_INCOMPLETE'):
            m.collect(get, NOW)

    def test_duplicated_card_fails(self):
        duplicate = tier('ancient').replace('</main>', card('ancient', 1) + '</main>')
        with self.assertRaisesRegex(m.MarketBlocked, 'DUPLICATE_ITEM_LINK'):
            m.parse_tier(duplicate, 'ancient')

    def test_wrong_category_fails(self):
        bad = tier('ancient').replace('Ancient · TIER 5', 'Godly · TIER 5', 1)
        with self.assertRaisesRegex(m.MarketBlocked, 'CARD_CATEGORY_MISMATCH'):
            m.parse_tier(bad, 'ancient')

    def test_wrong_host_fails(self):
        bad = tier('ancient').replace('https://mm2tradehub.com/values/', 'https://evil.invalid/values/', 1)
        with self.assertRaisesRegex(m.MarketBlocked, 'ITEM_HREF_OUTSIDE_SOURCE'):
            m.parse_tier(bad, 'ancient')

    def test_missing_source_prices_fail(self):
        bad = tier('ancient').replace('vs-row vs-supreme', 'vs-row vs-unrelated', 1)
        with self.assertRaisesRegex(m.MarketBlocked, 'SOURCE_PRICE_ROWS_MISSING'):
            m.parse_tier(bad, 'ancient')

    def test_missing_demand_fails(self):
        bad = tier('ancient').replace('title="Demand 5"', 'title="Not demand"', 1)
        with self.assertRaisesRegex(m.MarketBlocked, 'DEMAND_MARKER_MISSING'):
            m.parse_tier(bad, 'ancient')

    def test_stale_source_fails(self):
        with self.assertRaisesRegex(m.MarketBlocked, 'EDITION_STALE_OR_FUTURE'):
            m.parse_edition(homepage('October 13, 2026'), NOW)

    def test_future_source_fails(self):
        with self.assertRaisesRegex(m.MarketBlocked, 'EDITION_STALE_OR_FUTURE'):
            m.parse_edition(homepage('December 13, 2026'), NOW)

    def test_missing_timestamp_fails(self):
        with self.assertRaisesRegex(m.MarketBlocked, 'EDITION_PUBLICATION_DATE_MISSING'):
            m.parse_edition(homepage('last Tuesday'), NOW)

    def test_out_of_range_demand_fails(self):
        bad = tier('ancient').replace('title="Demand 5"', 'title="Demand 99"', 1)
        with self.assertRaisesRegex(m.MarketBlocked, 'DEMAND_OUT_OF_RANGE'):
            m.parse_tier(bad, 'ancient')

    def test_zero_or_noninteger_price_fails(self):
        with self.assertRaisesRegex(m.MarketBlocked, 'PRICE_OUT_OF_BOUNDS'):
            m.price_of('0')
        with self.assertRaisesRegex(m.MarketBlocked, 'PRICE_OUT_OF_BOUNDS'):
            m.price_of('1.5')

    def test_source_changed_title_fails(self):
        bad = tier('ancient').replace('Ancient Values', 'Unrelated Values')
        with self.assertRaisesRegex(m.MarketBlocked, 'CATEGORY_PAGE_TITLE_MISMATCH'):
            m.parse_tier(bad, 'ancient')

    def test_deterministic_hash(self):
        self.assertEqual(m.collect(fixture, NOW)['sourceTierPageSha256'], m.collect(fixture, NOW)['sourceTierPageSha256'])

    def test_reject_unknown_network_path(self):
        with self.assertRaisesRegex(m.MarketBlocked, 'UNRECOGNIZED_FETCH_PATH'):
            m.LiveHTMLTransport()('/api/secret')


if __name__ == '__main__':
    unittest.main()
