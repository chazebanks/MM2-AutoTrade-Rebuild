"""C9 first-party Supreme Values 189-key publisher comparison (READ ONLY).

Fetches ORIGINAL official Supreme Values pages, not aggregator Supreme column,
maps every previously verified ORIGINAL Stage83 weapon key by exact public name
(and one explicitly reviewed Flowerwood alias). Producer does not infer Roblox
weapon instances, completed trades, buyer willingness or trade authorization.
No source timestamps are ever restamped to hide publisher/collector staleness.
"""
from __future__ import annotations

from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from hashlib import sha256
from pathlib import Path
from urllib.parse import urlparse
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError
import argparse
import json
import re
import sys

from bs4 import BeautifulSoup

SCHEMA = "gingerscope-c9-supreme-direct-189-research-audit-v1"
SOURCE = "https://supremevalues.com"
CATEGORIES = {"ancient": "ancients", "godly": "godlies", "chroma": "chromas"}
CATEGORY_KEYS = {"ancient": 15, "godly": 128, "chroma": 46}
OFFICIAL_PAGE_HEADINGS = {"ancient": "MM2 Ancient Values",
                          "godly": "MM2 Godly Values",
                          "chroma": "MM2 Chroma Values"}
MANUAL_NAME_ALIASES = {"FlowerwoodKnife": "Flowerwood"}
ISO = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}$")
PRICE = re.compile(r"^[1-9][0-9]{0,9}$")
DEMAND = re.compile(r"^\d+(?:\.\d+)?$")
UPDATE = re.compile(r"SUPREME VALUES UPDATE\s+(\d{2})/(\d{2})/(\d{4})\s*\(DD/MM/YYYY\)", re.I)
MAX_SOURCE_AGE = 21600


class SupremeBlocked(ValueError):
    pass


def fail(reason):
    raise SupremeBlocked(reason)


def norm(s):
    if not isinstance(s, str):
        fail("OFFICIAL_ITEM_NAME_MISSING")
    return re.sub(r"[^a-z0-9]", "", s.lower())


def exact_utc(s):
    if type(s) is not str or not s.endswith("Z"):
        fail("C9_UTC_Z_TIMESTAMP_REQUIRED")
    try:
        t = datetime.fromisoformat(s[:-1] + "+00:00")
    except (ValueError, TypeError, OverflowError):
        fail("C9_UTC_TIMESTAMP_INVALID")
    return t


def extract_publisher_clock(html):
    soup = BeautifulSoup(html, "html.parser")
    div = soup.select_one("#sv-values-updated")
    if div is None:
        fail("OFFICIAL_SUPREME_HEADER_MISSING")
    stamp = div.get("data-updated-iso")
    if not isinstance(stamp, str) or not ISO.fullmatch(stamp):
        fail("OFFICIAL_SUPREME_TIMED_UPDATE_MISSING")
    try:
        t = datetime.fromisoformat(stamp)
    except (ValueError, OverflowError):
        fail("OFFICIAL_SUPREME_UPDATE_CLOCK_INVALID")
    if t.utcoffset() is None or t.utcoffset().total_seconds() not in (-18000, -14400):
        fail("OFFICIAL_SUPREME_UPDATE_ZONE_INVALID")
    if not div.get_text(" ", strip=True).startswith("Values Last Updated"):
        fail("OFFICIAL_SUPREME_VISIBLE_HEADER_MISMATCH")
    return t


def extract_category(html, category):
    if category not in CATEGORIES:
        fail("OFFICIAL_CATEGORY_NOT_APPROVED")
    if type(html) is not str or not 500 < len(html) < 2_000_000:
        fail("OFFICIAL_CATEGORY_HTML_SIZE_INVALID")
    soup = BeautifulSoup(html, "html.parser")
    heading = soup.find("h1")
    if not heading or heading.get_text(" ", strip=True) != OFFICIAL_PAGE_HEADINGS[category]:
        fail("OFFICIAL_CATEGORY_HEADING_CHANGED")
    rows = {}
    for col in soup.select('div.itemcolumn[data-value]'):
        cell = col.select_one("div.itemcell[id], div.itemcell-exp[id]")
        button = cell.select_one("button[data-name]") if cell else None
        if not cell or not button:
            fail("OFFICIAL_ITEM_CARD_SHAPE_CHANGED")
        name = button.get("data-name")
        key = norm(name)
        if not key or key in rows:
            fail("OFFICIAL_CATEGORY_DUPLICATE_OR_INVALID_NAME")
        value = col.get("data-value")
        if not isinstance(value, str) or len(value) > 16:
            fail("OFFICIAL_PRICE_LABEL_INVALID")
        demand = col.get("data-demand")
        stability = col.get("data-stability")
        if not isinstance(demand, str) or not DEMAND.fullmatch(demand):
            fail("OFFICIAL_DEMAND_FIELD_MISSING")
        if not isinstance(stability, str) or not (1 <= len(stability) <= 80):
            fail("OFFICIAL_STABILITY_FIELD_MISSING")
        try:
            d = Decimal(demand)
        except InvalidOperation:
            fail("OFFICIAL_DEMAND_FIELD_INVALID")
        if not 0 <= d <= 11:
            fail("OFFICIAL_DEMAND_OUT_OF_RANGE")
        rows[key] = {
            "publicName": name, "supremeItemId": cell.get("id"),
            "priceText": value, "supremeDemand": str(d.normalize()),
            "supremeStability": stability
        }
    if len(rows) < CATEGORY_KEYS[category]:
        fail("OFFICIAL_CATEGORY_COVERAGE_TOO_SMALL")
    return rows


def audit(pages: dict, mapped: dict, *, captured_utc: str,
          direct_https_validated: bool = False) -> dict:
    at = exact_utc(captured_utc)
    if type(mapped) is not dict or mapped.get("schema") != "gingerscope-system2-exact-market-gamekey-crosswalk-v1" or mapped.get("matchedHistoricalGameKeys") != 189 or mapped.get("historicalRegistryBlob") != "40e2a0ff01b70b2d0181c62cae347a08da82bcb8" or len(mapped.get("items", [])) != 189:
        fail("C9_ORIGINAL_189_MAPPING_NOT_REVIEWED")
    if type(pages) is not dict or set(pages) != {"home", "ancient", "godly", "chroma"}:
        fail("C9_FOUR_OFFICIAL_PAGES_REQUIRED")
    stamps = [extract_publisher_clock(pages[k]) for k in ("home", "ancient", "godly", "chroma")]
    if len(set(stamps)) != 1:
        fail("OFFICIAL_UPDATE_CHANGED_DURING_FOUR_PAGE_CAPTURE")
    published = stamps[0]
    age = (at - published.astimezone(timezone.utc)).total_seconds()
    if not 0 <= age <= 4 * 86400:
        fail("OFFICIAL_PUBLICATION_STALE_OR_FUTURE")
    home = BeautifulSoup(pages["home"], "html.parser")
    log = home.select_one("#updatelog")
    found = UPDATE.search(log.get_text(" ", strip=True)) if log else None
    if not found or (int(found[1]), int(found[2]), int(found[3])) != (published.day, published.month, published.year):
        fail("OFFICIAL_CHANGELOG_AND_HEADER_DATE_MISMATCH")
    all_official = {k: extract_category(pages[k], k) for k in CATEGORIES}
    keyed = set()
    result = []
    differing = []
    categories = {k: 0 for k in CATEGORIES}
    for row in mapped["items"]:
        if type(row) is not dict:
            fail("C9_ORIGINAL_KEY_ROW_MALFORMED")
        game_key, category = row.get("rawGameKeyCandidate"), row.get("marketCategory")
        if type(game_key) is not str or game_key in keyed or category not in CATEGORIES:
            fail("C9_ORIGINAL_KEY_AMBIGUOUS")
        keyed.add(game_key)
        label = MANUAL_NAME_ALIASES.get(game_key, row.get("marketName"))
        official = all_official[category].get(norm(label))
        if not official:
            fail("OFFICIAL_GAME_KEY_NOT_EXACTLY_FOUND:" + game_key)
        raw_price = official["priceText"]
        if not PRICE.fullmatch(raw_price):
            fail("OFFICIAL_MAPPED_PRICE_INVALID:" + game_key)
        price = int(raw_price)
        if price <= 0 or price >= 10**10:
            fail("OFFICIAL_MAPPED_PRICE_OUT_OF_BOUNDS:" + game_key)
        previous = row.get("supremeListed")
        if previous is not None and (type(previous) is not int or previous <= 0):
            fail("PREVIOUS_AGGREGATE_SUPREME_PRICE_INVALID:" + game_key)
        conflict = previous != price
        if conflict:
            differing.append(game_key)
        if game_key == "Gingerscope" and row.get("outgoingGingerscopeProtected") is not True:
            fail("C9_GINGERSCOPE_OUTBOUND_PROTECTION_LOST")
        if game_key != "Gingerscope" and row.get("outgoingGingerscopeProtected") is True:
            fail("C9_UNREVIEWED_PROTECTED_KEY")
        categories[category] += 1
        result.append({
            "rawGameKeyCandidate": game_key,
            "category": category,
            "supremePublicItemName": official["publicName"],
            "supremePublicItemId": official["supremeItemId"],
            "supremeOfficialListed": price,
            "supremeAggregateColumnPreviouslyListed": previous,
            "supremePriceDisagreesWithAggregator": conflict,
            "supremeDemandOfficial": official["supremeDemand"],
            "supremeStabilityOfficial": official["supremeStability"],
            "nameAliasManuallyReviewed": game_key in MANUAL_NAME_ALIASES,
            "outgoingGingerscopeProtected": game_key == "Gingerscope",
        })
    if len(keyed) != 189 or categories != CATEGORY_KEYS or result[0]["rawGameKeyCandidate"] is None:
        fail("C9_ORIGINAL_EXACT_189_COVERAGE_CHANGED")
    if sum(r["outgoingGingerscopeProtected"] for r in result) != 1:
        fail("C9_GINGERSCOPE_PROTECTION_AMBIGUOUS")
    result.sort(key=lambda x: x["rawGameKeyCandidate"])
    page_hash = {k: sha256(pages[k].encode()).hexdigest() for k in sorted(pages)}
    return {
        "schema": SCHEMA,
        "status": "FIRST_PARTY_189_SUPREME_RESEARCH_RECONCILED_NONACTIONABLE",
        "source": SOURCE,
        "sourceOfficialPublicationISO": published.isoformat(),
        "sourceCapturedUtc": captured_utc,
        "publicationAgeAtCaptureSeconds": int(age),
        "maxResearchAgeSeconds": MAX_SOURCE_AGE,
        "publicPageSha256": page_hash,
        "historicalRegistryBlob": mapped["historicalRegistryBlob"],
        "aggregatorRowsSha256": mapped["crosswalkRowsSha256"],
        "matchedHistoricalGameKeys": 189,
        "categoryMatchedCounts": categories,
        "changedSupremePriceCount": len(differing),
        "changedGameKeys": sorted(differing),
        "all189OfficialPricesAndDemandParsed": True,
        "publisherHTTPSDirectlyFetched": direct_https_validated is True,
        "publisherCryptographicSignatureVerified": False,
        "sourceIndependentOfAggregateSupremeColumn": True,
        "timeOfPublisherPublicationNotTradeFillProbability": True,
        "researchOnly": True,
        "canFeedAutomatedTrade": False,
        "canOverrideHistoricalMarketHashes": False,
        "authorizesOffer": False,
        "authorizesAccept": False,
        "authorizesTrade": False,
        "mayReportProfit": False,
        "mayUseForStrategyLearning": False,
        "rows": result,
    }


def fetch_official_page(path):
    if path not in ("", "/mm2/ancients", "/mm2/godlies", "/mm2/chromas"):
        fail("OFFICIAL_UNAPPROVED_FETCH_PATH")
    req = Request(SOURCE + path, headers={
        "User-Agent": "Mozilla/5.0 (compatible; GingerscopeMarketResearch/1.0; +https://github.com/chazebanks/MM2-AutoTrade-Rebuild)",
        "Accept": "text/html", "Accept-Language": "en-US,en;q=0.9"
    })
    try:
        with urlopen(req, timeout=24) as r:
            target = urlparse(r.geturl())
            if r.status != 200 or target.scheme != "https" or target.hostname not in ("supremevalues.com", "www.supremevalues.com"):
                fail("OFFICIAL_SOURCE_ORIGIN_OR_STATUS_CHANGED")
            if "text/html" not in r.headers.get("Content-Type", ""):
                fail("OFFICIAL_CONTENT_TYPE_NOT_HTML")
            raw = r.read(2_000_001)
    except HTTPError as exc:
        fail("OFFICIAL_SOURCE_HTTP_" + str(exc.code))
    except (URLError, TimeoutError, OSError):
        fail("OFFICIAL_SOURCE_NETWORK_UNAVAILABLE")
    if not 500 < len(raw) < 2_000_000:
        fail("OFFICIAL_SOURCE_RESPONSE_SIZE_INVALID")
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        fail("OFFICIAL_SOURCE_NOT_UTF8")


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--mapped", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--capture-utc")
    args = p.parse_args()
    try:
        captured_utc = args.capture_utc or datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
        # Each page fetched independently; clock equality detects mid-run update.
        pages = {name: fetch_official_page(path) for name, path in (
            ("home", ""), ("ancient", "/mm2/ancients"),
            ("godly", "/mm2/godlies"), ("chroma", "/mm2/chromas")
        )}
        # Capture-time timestamp must record the END of the network fetch.
        now = datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
        if args.capture_utc is None:
            captured_utc = now
        evidence = audit(pages, json.loads(args.mapped.read_text()),
                         captured_utc=captured_utc, direct_https_validated=True)
        args.output.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
        print("C9_SUPREME_RESEARCH_STATUS=" + evidence["status"])
        print("OFFICIAL_SUPREME_PUBLISHED=" + evidence["sourceOfficialPublicationISO"])
        print("ORIGINAL_GAME_KEYS=" + str(evidence["matchedHistoricalGameKeys"]))
        print("AGGREGATE_SUPREME_PRICE_DISAGREEMENTS=" + str(evidence["changedSupremePriceCount"]))
        print("C9_SUPREME_TRADE_AUTHORITY=FALSE")
        return 0
    except (SupremeBlocked, ValueError, OSError) as exc:
        print("C9_SUPREME_RESEARCH_STATUS=BLOCKED")
        print("C9_SUPREME_REASON=" + str(exc))
        return 2


if __name__ == "__main__":
    sys.exit(main())
