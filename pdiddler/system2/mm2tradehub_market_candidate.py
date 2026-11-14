"""Fail-closed MM2 Trade Hub public tier-page market candidate collector.

Research output only: provider names, web slugs and prices DO NOT establish
MM2 raw weapon instance identities, verified live counterparties or liquidity.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import sys
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from pathlib import Path
from urllib.parse import urlparse
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

from bs4 import BeautifulSoup

SITE = "https://mm2tradehub.com"
SCHEMA = "gingerscope-system2-mm2tradehub-public-html-candidate-v1"
CATEGORIES = {"ancient": 16, "godly": 128, "chroma": 65}
DATE = re.compile(r"(?:last rebuilt on|Source list rebuilt)\s+([A-Z][a-z]+\s+\d{1,2},\s+\d{4})", re.I)
SLUG = re.compile(r"^[a-z0-9][a-z0-9-]{1,149}$")
PRICE = re.compile(r"^(\d+(?:\.\d+)?)\s*([KMB]?)$", re.I)
DEMAND = re.compile(r"^Demand\s+(\d+(?:\.\d+)?)$", re.I)


class MarketBlocked(Exception):
    pass


def fail(reason):
    raise MarketBlocked(reason)


def price_of(label):
    if not isinstance(label, str):
        fail("PRICE_LABEL_TYPE_CHANGED")
    label = label.strip().replace(",", "")
    match = PRICE.fullmatch(label)
    if not match:
        return None
    try:
        value = Decimal(match.group(1)) * (10 ** {"": 0, "K": 3, "M": 6, "B": 9}[match.group(2).upper()])
    except (InvalidOperation, OverflowError):
        fail("PRICE_PARSE_FAILED")
    if value <= 0 or value >= 10**10 or value != value.to_integral_value():
        fail("PRICE_OUT_OF_BOUNDS")
    return int(value)


def parse_tier(html, category):
    if category not in CATEGORIES:
        fail("CATEGORY_NOT_SUPPORTED")
    if not isinstance(html, str) or not 500 < len(html) < 2_000_000:
        fail("HTML_SIZE_INVALID")
    soup = BeautifulSoup(html, "html.parser")
    title = soup.title.get_text(" ", strip=True) if soup.title else ""
    if not re.search(r"\b" + category + r"\s+values\b", title, re.I):
        fail("CATEGORY_PAGE_TITLE_MISMATCH")
    rows = []
    seen = {}
    card_count = 0
    for card in soup.select("a.group.card"):
        card_count += 1
        href = card.get("href")
        parsed = urlparse(href or "")
        trusted_alias = parsed.scheme == "https" and parsed.netloc in (
            "mm2tradehub.com", "www.mm2tradehub.com", "mm2values.app", "www.mm2values.app")
        trusted_relative = parsed.scheme == "" and parsed.netloc == ""
        if not (trusted_alias or trusted_relative):
            fail("ITEM_HREF_OUTSIDE_SOURCE")
        if not parsed.path.startswith("/values/") or parsed.query or parsed.fragment:
            fail("ITEM_LINK_FORMAT_CHANGED")
        slug = parsed.path.removeprefix("/values/")
        if not SLUG.fullmatch(slug):
            fail("ITEM_SLUG_INVALID")
        heading = card.find("h3")
        if not heading:
            fail("ITEM_NAME_MISSING")
        name = heading.get_text(" ", strip=True)
        if not 2 <= len(name) <= 110:
            fail("ITEM_NAME_INVALID")
        cate_text = heading.find_next_sibling("div")
        if not cate_text or category not in cate_text.get_text(" ", strip=True).lower().split(" · ")[0]:
            fail("CARD_CATEGORY_MISMATCH")
        node1 = card.select_one(".vs-row.vs-mm2 .vs-num")
        node2 = card.select_one(".vs-row.vs-supreme .vs-num")
        if (node1 is None) != (node2 is None):
            fail("SOURCE_PRICE_ROWS_MISSING")
        if node1 is None and node2 is None:
            solo = card.select_one(".vs-row.vs-row--only")
            num = solo.select_one(".vs-num") if solo else None
            tag = solo.select_one(".vs-tag") if solo else None
            if num is None or tag is None:
                fail("SOURCE_PRICE_ROWS_MISSING")
            tag_text = tag.get_text(" ", strip=True)
            if tag_text == "MM2":
                node1 = num
            elif tag_text == "Supreme":
                node2 = num
            else:
                fail("SOURCE_PRICE_TAG_UNKNOWN")
        mm2_text = node1.get_text(" ", strip=True) if node1 else "UNAVAILABLE"
        supreme_text = node2.get_text(" ", strip=True) if node2 else "UNAVAILABLE"
        mm2, supreme = price_of(mm2_text), price_of(supreme_text)
        demand_nodes = card.select("[title^='Demand ']")
        if len(demand_nodes) != 1:
            fail("DEMAND_MARKER_MISSING")
        match = DEMAND.fullmatch(demand_nodes[0].get("title", ""))
        if not match:
            fail("DEMAND_FIELD_INVALID")
        demand = Decimal(match.group(1))
        if not 0 <= demand <= 11:
            fail("DEMAND_OUT_OF_RANGE")
        stability_node = demand_nodes[0].find_next_sibling("span")
        stability = stability_node.get_text(" ", strip=True) if stability_node else None
        if stability and len(stability) > 80:
            fail("STABILITY_FIELD_INVALID")
        row = {
            "providerName": name, "providerSlug": slug, "providerCategory": category,
            "mm2SourceLabel": mm2_text, "mm2Listed": mm2,
            "supremeSourceLabel": supreme_text, "supremeListed": supreme,
            "demandOrdinal": str(demand.normalize()), "stabilityLabel": stability,
            "rawGameWeaponKey": None, "chromaSubtypeVerified": False,
            "completedTradeLiquidityMeasured": False,
        }
        existing = seen.get(slug)
        if existing is not None:
            # The source displays identical duplicate Chroma cards (19 as of
            # Nov 14). Collapse only exact duplicate observations, never
            # conflicting price, demand, stability or identity evidence.
            if existing != row:
                fail("CONFLICTING_DUPLICATE_ITEM")
            continue
        seen[slug] = row
        rows.append(row)
    if card_count != CATEGORIES[category]:
        fail("CATEGORY_ITEM_COUNT_INCOMPLETE")
    return rows


def parse_edition(html, fetched_utc):
    if not isinstance(html, str):
        fail("EDITION_HTML_INVALID")
    soup = BeautifulSoup(html, "html.parser")
    main = soup.find("main")
    text = main.get_text(" ", strip=True) if main else ""
    found = DATE.search(text)
    if not found:
        fail("EDITION_PUBLICATION_DATE_MISSING")
    try:
        published = datetime.strptime(found.group(1), "%B %d, %Y").replace(tzinfo=timezone.utc)
        now = datetime.fromisoformat(fetched_utc.replace("Z", "+00:00"))
    except (ValueError, TypeError):
        fail("EDITION_TIMESTAMP_INVALID")
    if now.tzinfo is None or not 0 <= (now - published).total_seconds() <= 4 * 86400:
        fail("EDITION_STALE_OR_FUTURE")
    return published.date().isoformat()


def collect(fetch, now):
    """fetch(path)->html text; all-or-nothing raw source validation."""
    edition_html = fetch("/values")
    published = parse_edition(edition_html, now)
    entries, page_hashes, seen = [], {}, set()
    for category in CATEGORIES:
        html = fetch("/values/category/" + category)
        page_hashes[category] = hashlib.sha256(html.encode("utf-8")).hexdigest()
        for item in parse_tier(html, category):
            if item["providerSlug"] in seen:
                fail("CROSS_CATEGORY_SLUG_COLLISION")
            seen.add(item["providerSlug"])
            entries.append(item)
    entries.sort(key=lambda r: (r["providerCategory"], r["providerSlug"]))
    if not any(r["providerSlug"] == "gingerscope" and r["providerCategory"] == "ancient" and r["mm2Listed"] is not None for r in entries):
        fail("TARGET_GINGERSCOPE_NOT_PRICED")
    return {
        "schema": SCHEMA, "status": "CURRENT_PUBLIC_SOURCE_CANDIDATE",
        "website": SITE, "retrievedUtc": now, "siteEditionDate": published,
        "sourceTierPageSha256": page_hashes,
        "categoryCounts": {cat: sum(r["providerCategory"] == cat for r in entries) for cat in CATEGORIES},
        "displayCardCounts": dict(CATEGORIES),
        "deduplicatedCardCount": sum(CATEGORIES.values()) - len(entries),
        "itemCount": len(entries), "items": entries,
        "exactGameWeaponIdentityProven": False, "providerTimestampPrecision": "date-only",
        "canFeedLiveTrade": False, "authorizesOffer": False,
        "authorizesAccept": False, "verifiedServerSettlement": False,
    }


class LiveHTMLTransport:
    def __call__(self, path):
        if path not in ("/values",) + tuple("/values/category/" + k for k in CATEGORIES):
            fail("UNRECOGNIZED_FETCH_PATH")
        request = Request(SITE + path, headers={"Accept": "text/html", "User-Agent": "GingerscopeMarketDiagnostic/1.0"})
        try:
            with urlopen(request, timeout=22) as response:
                if response.status != 200:
                    fail("SOURCE_HTTP_NOT_200")
                if "text/html" not in response.headers.get("Content-Type", ""):
                    fail("SOURCE_CONTENT_TYPE_NOT_HTML")
                raw = response.read(2_000_001)
        except HTTPError as exc:
            fail("SOURCE_HTTP_" + str(exc.code))
        except (URLError, TimeoutError, OSError):
            fail("SOURCE_TRANSPORT_FAILURE")
        if len(raw) > 2_000_000:
            fail("SOURCE_HTML_TOO_LARGE")
        try:
            return raw.decode("utf-8")
        except UnicodeDecodeError:
            fail("SOURCE_HTML_ENCODING_INVALID")


def main():
    output = os.environ.get("GINGERSCOPE_MARKET_OUTPUT", "")
    if not output.startswith("/"):
        print("MARKET_STATUS=OUTPUT_PATH_MISSING")
        return 2
    try:
        timestamp = datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
        result = collect(LiveHTMLTransport(), timestamp)
        Path(output).write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print("MARKET_STATUS=CURRENT_PUBLIC_SOURCE_CANDIDATE")
        print("ITEM_COUNT=" + str(result["itemCount"]))
        print("EDITION=" + result["siteEditionDate"])
        print("LIVE_TRADE_AUTHORITY=FALSE")
        return 0
    except MarketBlocked as exc:
        print("MARKET_STATUS=BLOCKED")
        print("MARKET_REASON=" + str(exc))
        return 2


if __name__ == "__main__":
    sys.exit(main())
