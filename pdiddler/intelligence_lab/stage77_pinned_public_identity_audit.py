"""Stage77: independently pinned THIRD-PARTY game catalogue ↔ captured FIRST-PARTY website HTML.

Pure offline, public-source RESEARCH ONLY. A website name/URL is not a Roblox
owned-item key or authenticated server attestation, and no pricing/trading is
permitted by any result. Source blobs must match their immutable Git object IDs.
"""
from __future__ import annotations

import hashlib
import re
from html.parser import HTMLParser
from urllib.parse import urlsplit, parse_qsl

SCHEMA = 'gingerscope-stage77-pinned-public-source-evidence-v1'
GAME_BLOB = '2be54c3f5c6b715844728c01a65cc2f24a55c02d'
SITE_BLOBS = {
    'ancients': '7e11a2d835eadbb522d351bdabe393a7c9688f4b',
    'godlies': '2e4a0c1b8df894f9037e737ba80919b9b2d0c9ae',
    'chromas': '0d2d156d9d9c499ef0e1213376796c1a916e6ce1',
}
# Reviewed target keys and FIRST-PARTY website detail slugs, NEVER numeric checker IDs.
# All other attributes are checked in independent source bytes at runtime.
TARGETS = {
    'Gingerscope': ('ancients', 'Gingerscope', 'Gingerscope', 'Gun', 'Ancient', False, 'Gingerscope'),
    'EmberscytheChroma': ('chromas', 'CEmberscythe', 'Emberscythe', 'Knife', 'Ancient', True, 'Chroma Emberscythe'),
    'BattleAxe': ('godlies', 'Battleaxe', 'BattleAxe', 'Knife', 'Godly', False, 'Battleaxe'),
    'BattleAxe2': ('godlies', 'BA2', 'BattleAxe II', 'Knife', 'Godly', False, 'Battleaxe II'),
}
GAME_ROW = re.compile(r'(?m)^  \["([^"\n]+)"\]\s*=\s*\{\s*\n([\s\S]*?)^  \},?')
GAME_FIELD = re.compile(r'(?m)^    \["(ItemName|ItemType|Rarity|Chroma)"\]\s*=\s*("[^"\n]*"|true|false)\s*,?\s*$')
VOID = frozenset('area base br col embed hr img input link meta param source track wbr sep'.split())

FLAGS = {
    'researchOnly': True, 'observedPublicSourcesOnly': True,
    'currentGameCatalogueAuthenticated': False, 'authenticatedOwnedInventory': False,
    'serverAttestation': False, 'numericSupremeCheckerIdVerified': False,
    'sourcePublisherFresh': False, 'currentPricesVerified': False,
    'authorizesTrade': False, 'authorizesAccept': False,
    'mayReportProfit': False, 'mayRecordCompletedTrade': False,
    'mayRecordRejectedTrade': False, 'maySendDiscordWebhook': False,
    'mayUseForStrategyLearning': False, 'tradeOutcome': 'UNKNOWN',
}

def git_blob_sha(payload: bytes) -> str:
    return hashlib.sha1(b'blob ' + str(len(payload)).encode() + b'\0' + payload).hexdigest()

def report(status: str, reason: str, **details):
    return {'schema': SCHEMA, 'status': status, 'reason': reason, **FLAGS, **details}

class N:
    def __init__(self, tag='', attrs=()):
        self.tag, self.attrs, self.children = tag, dict(attrs), []

    def walk(self):
        yield self
        for child in self.children:
            if isinstance(child, N):
                yield from child.walk()

    def text(self):
        return ' '.join(x.text() if isinstance(x, N) else x for x in self.children).strip()

    def has_class(self, name):
        return name in self.attrs.get('class', '').split()

class D(HTMLParser):
    def __init__(self, source: str):
        super().__init__(convert_charrefs=True)
        self.root = N()
        self.stack = [self.root]
        self.feed(source)
        self.close()

    def handle_starttag(self, tag, attrs):
        node = N(tag, attrs)
        self.stack[-1].children.append(node)
        if tag not in VOID:
            self.stack.append(node)

    def handle_startendtag(self, tag, attrs):
        self.stack[-1].children.append(N(tag, attrs))

    def handle_endtag(self, tag):
        for i in range(len(self.stack) - 1, 0, -1):
            if self.stack[i].tag == tag:
                del self.stack[i:]
                break

    def handle_data(self, value):
        self.stack[-1].children.append(value)

def one(seq, why):
    if len(seq) != 1:
        raise ValueError(f'not exactly one {why}: {len(seq)}')
    return seq[0]

def game_rows(raw: bytes):
    decoded = raw.decode('utf-8')
    result = {}
    for match in GAME_ROW.finditer(decoded):
        key = match.group(1)
        if key in result:
            raise ValueError('duplicate raw game key')
        fields = {}
        for fld in GAME_FIELD.finditer(match.group(2)):
            k, v = fld.groups()
            if k in fields:
                raise ValueError('duplicate direct game attribute')
            fields[k] = (v == 'true') if v in ('true', 'false') else v[1:-1]
        result[key] = fields
    if len(result) != 1040:
        raise ValueError('not expected 1040 raw public catalogue rows')
    return result

def website_records(raw: bytes, page: str):
    if page not in SITE_BLOBS:
        raise ValueError('unknown first-party category')
    doc = D(raw.decode('utf-8'))
    nodes = list(doc.root.walk())
    expected_title = {'ancients': 'Ancient', 'godlies': 'Godly', 'chromas': 'Chroma'}[page]
    titles = [n.text() for n in nodes if n.tag == 'title']
    if len(titles) != 1 or f'MM2 {expected_title} Values' not in titles[0]:
        raise ValueError('site page title/category mismatch')
    # Archived page-global source date is NOT proof of CURRENT price freshness.
    if len({n.attrs['data-updated-iso'] for n in nodes if 'data-updated-iso' in n.attrs}) != 1:
        raise ValueError('source publication attribute absent or ambiguous')
    rows = {}
    for col in (n for n in nodes if n.has_class('itemcolumn')):
        descendants = list(col.walk())
        identities = [n for n in descendants if n.tag == 'div' and
                      (n.has_class('itemcell') or n.has_class('itemcell-exp')) and n.attrs.get('id')]
        if len(identities) != 1:
            raise ValueError('missing/duplicated site row identity')
        slug = identities[0].attrs['id']
        if slug in rows:
            raise ValueError('duplicate site row slug')
        link = one([n for n in descendants if n.tag == 'a' and n.has_class('itemlink')], 'site item link')
        url = link.attrs.get('href')
        canonical = f'https://supremevalues.com/mm2/{page}?item={slug}'
        if url != canonical:
            raise ValueError('market URL not exact first-party canonical slug')
        buttons = [n.attrs['data-name'] for n in descendants if n.tag == 'button' and 'data-name' in n.attrs]
        name = one(buttons, 'source data-name')
        if link.text() != name:
            raise ValueError('source item link and data-name differ')
        body = one([n for n in descendants if n.has_class('itembody')], 'source item body').text()
        if page == 'chromas':
            m = re.search(r'\bClass\s*-\s*(Ancient|Godly)\b', body)
            if m is None:
                raise ValueError('missing Chroma base class')
            base = m.group(1)
        else:
            base = expected_title
        rows[slug] = (name, base)
    if not rows:
        raise ValueError('source rows absent')
    return rows

def run(game: bytes, website: dict[str, bytes]):
    if not isinstance(game, bytes) or not isinstance(website, dict):
        return report('INCONCLUSIVE', 'INVALID_SOURCE_TYPES')
    if git_blob_sha(game) != GAME_BLOB:
        return report('INCONCLUSIVE', 'PINNED_GAME_PUBLIC_BLOB_MISMATCH')
    if set(website) != set(SITE_BLOBS) or any(not isinstance(x, bytes) for x in website.values()):
        return report('INCONCLUSIVE', 'INCOMPLETE_OR_UNEXPECTED_WEBSITE_SOURCES')
    if any(git_blob_sha(website[p]) != blob for p, blob in SITE_BLOBS.items()):
        return report('INCONCLUSIVE', 'PINNED_FIRST_PARTY_HTML_BLOB_MISMATCH')
    try:
        game_catalog = game_rows(game)
        market_catalog = {p: website_records(v, p) for p, v in website.items()}
        matched, distinct_slug = 0, 0
        for key, (page, slug, expected_game_name, kind, rarity, chroma, market_name) in TARGETS.items():
            game_row = game_catalog.get(key)
            if game_row is None:
                raise ValueError('raw key absent in public catalogue')
            if (game_row.get('ItemName'), game_row.get('ItemType'),
                    game_row.get('Rarity'), game_row.get('Chroma', False)) != (
                    expected_game_name, kind, rarity, chroma):
                raise ValueError('public game type/name/variant mismatch')
            site_item = market_catalog[page].get(slug)
            if site_item != (market_name, rarity):
                raise ValueError('public market item slug/name/class mismatch')
            if slug != key:
                distinct_slug += 1
            matched += 1
    except (UnicodeError, ValueError, KeyError, TypeError, OverflowError, RecursionError):
        return report('INCONCLUSIVE', 'PUBLIC_SOURCE_FORMAT_OR_IDENTITY_UNREVIEWED')
    return report('PINNED_PUBLIC_SOURCES_CORRESPOND_ONLY',
                  'NOT_PROOF_OF_OWNED_ITEM_OR_CURRENT_PRICE',
                  independentlyPinnedSourceCount=4,
                  corroboratedPublicKeyNames=matched,
                  distinctWebsiteSlugs=distinct_slug,
                  sourcePageRows={p: len(market_catalog[p]) for p in sorted(market_catalog)},
                  gamePublicRows=len(game_catalog))
