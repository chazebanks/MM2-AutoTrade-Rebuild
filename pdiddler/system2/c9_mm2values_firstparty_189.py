"""Research-only first-party MM2Values.com current-source collector for C9.

Uses mm2values.com's own published cards, NOT MM2TradeHub's attributed prices.
Exact historical Stage83 raw-key names still need live game instance evidence.
No offer, final Accept, trade settlement, learned profit or market authority.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from hashlib import sha256
import json
from pathlib import Path
import re
from urllib.parse import urlparse
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError
from zoneinfo import ZoneInfo

from bs4 import BeautifulSoup

SCHEMA = "gingerscope-c9-mm2values-firstparty-189-research-v1"
CROSSWALK_SCHEMA = "gingerscope-system2-exact-market-gamekey-crosswalk-v1"
SITE = "https://www.mm2values.com/"
PAGES = {
    "home": SITE,
    "ancient": SITE + "?p=ancient",
    "godly": SITE + "?p=godly",
    "chroma": SITE + "?p=chroma",
}
PAGE_COUNT = {"ancient": 16, "godly": 128, "chroma": 46}
KEY_COUNT = {"ancient": 15, "godly": 128, "chroma": 46}
REVIEWED_EXTRAS = {"ancient": {"niksscythe"}, "godly": set(), "chroma": set()}
REGISTRY_GIT_BLOB = "40e2a0ff01b70b2d0181c62cae347a08da82bcb8"
HISTORICAL_ROWS_SHA256 = "6540923609ddd6344306bb248861eddba7dd46cd00ba016f446eda3327f152ac"
MAX_CAPTURE_AGE = 21600
MAX_PUBLISHER_AGE = 4 * 86400
PUBLISHER_CLOCK = re.compile(
    r"VALUES UPDATED:\s*(\d{2}/\d{2}/\d{4})\s+(\d{1,2}:\d{2}:\d{2})\s*(am|pm)\s+(EST|EDT)\b",
    re.IGNORECASE,
)
DECIMAL = re.compile(r"^\d+(?:\.\d+)?$")


class MM2ValuesBlocked(ValueError):
    pass


def deny(reason):
    raise MM2ValuesBlocked(reason)


def timeparse(s):
    if type(s) is not str or not s.endswith("Z"):
        deny("C9_FIRSTPARTY_UTC_Z_TIMESTAMP_REQUIRED")
    try:
        return datetime.fromisoformat(s[:-1] + "+00:00")
    except (ValueError, OverflowError):
        deny("C9_FIRSTPARTY_TIMESTAMP_INVALID")


def norm(label):
    if type(label) is not str:
        deny("C9_FIRSTPARTY_NAME_TYPE_INVALID")
    return re.sub(r"[^a-z0-9]", "", label.lower())


def rows_sha(rows):
    return sha256(json.dumps(rows, sort_keys=True, separators=(",", ":"),
                             ensure_ascii=True, allow_nan=False).encode()).hexdigest()


def parse_home(html):
    if type(html) is not str or not 500 < len(html) < 2_000_000:
        deny("C9_FIRSTPARTY_HOME_HTML_INVALID")
    soup = BeautifulSoup(html, "html.parser")
    found = PUBLISHER_CLOCK.search(soup.get_text(" ", strip=True))
    if not found:
        deny("C9_FIRSTPARTY_PUBLISHER_UPDATE_CLOCK_MISSING")
    date, clock, meridiem, tzlabel = found.groups()
    try:
        naive = datetime.strptime(f"{date} {clock}{meridiem.upper()}",
                                  "%m/%d/%Y %I:%M:%S%p")
        published = naive.replace(tzinfo=ZoneInfo("America/New_York"))
    except (ValueError, OverflowError):
        deny("C9_FIRSTPARTY_PUBLISHER_UPDATE_CLOCK_INVALID")
    if published.strftime("%Z").upper() != tzlabel.upper():
        deny("C9_FIRSTPARTY_PUBLISHER_TIMEZONE_CONFLICT")
    return published


def field(strings, prefix):
    matches = [s[len(prefix):].strip() for s in strings if s.startswith(prefix)]
    if len(matches) != 1:
        deny("C9_FIRSTPARTY_CARD_FIELD_MISSING_OR_DUPLICATE_" + prefix.rstrip(":"))
    return matches[0]


def numeric(label, *, maximum=10**10, decimal=False):
    if type(label) is not str:
        deny("C9_FIRSTPARTY_PRICE_OR_SCORE_INVALID")
    x = label.replace(",", "")
    if decimal:
        if not DECIMAL.fullmatch(x):
            deny("C9_FIRSTPARTY_SCORE_FORMAT_CHANGED")
        try:
            val = Decimal(x)
        except InvalidOperation:
            deny("C9_FIRSTPARTY_SCORE_INVALID")
        if not val.is_finite() or not 0 <= val <= 11:
            deny("C9_FIRSTPARTY_SCORE_OUT_OF_RANGE")
        return str(val.normalize())
    if not x.isascii() or not x.isdigit() or len(x) > 11:
        deny("C9_FIRSTPARTY_PRICE_FORMAT_CHANGED")
    val = int(x)
    if not 0 < val < maximum:
        deny("C9_FIRSTPARTY_PRICE_OUT_OF_BOUNDS")
    return val


def parse_tier(html, category):
    if category not in PAGE_COUNT or type(html) is not str or (
        not 500 < len(html) < 2_000_000
    ):
        deny("C9_FIRSTPARTY_TIER_HTML_OR_CATEGORY_INVALID")
    soup = BeautifulSoup(html, "html.parser")
    section = soup.select_one(".main-content")
    title = section.select_one(".itemheader") if section else None
    if title is None or category + " items" not in title.get_text(" ", strip=True).lower():
        deny("C9_FIRSTPARTY_WRONG_CATEGORY_HEADER")
    cards = section.select("div.stackable")
    if len(cards) != PAGE_COUNT[category]:
        deny("C9_FIRSTPARTY_CARD_COUNT_CHANGED_" + category)
    found = {}
    for card in cards:
        title = card.select_one("b")
        if title is None:
            deny("C9_FIRSTPARTY_CARD_NAME_MISSING")
        name = title.get_text(" ", strip=True)
        key = norm(name)
        if not 2 <= len(name) <= 110 or not key or key in found:
            deny("C9_FIRSTPARTY_DUPLICATE_OR_INVALID_PUBLIC_NAME")
        img = card.select_one("img[src]")
        if not img or not img.get("src", "").startswith(SITE + "img/"):
            deny("C9_FIRSTPARTY_CARD_ART_ORIGIN_CHANGED")
        strings = list(card.stripped_strings)
        value = numeric(field(strings, "Value:"))
        demand_rarity = field(strings, "Demand:")
        parsed = re.fullmatch(r"(\d+(?:\.\d+)?)\s*-\s*Rarity:\s*(\d+(?:\.\d+)?)",
                              demand_rarity)
        if not parsed:
            deny("C9_FIRSTPARTY_DEMAND_RARITY_FIELD_INVALID")
        demand = numeric(parsed.group(1), decimal=True)
        rarity = numeric(parsed.group(2), decimal=True)
        stability = field(strings, "Stability:")
        if not 1 <= len(stability) <= 80 or "<" in stability:
            deny("C9_FIRSTPARTY_STABILITY_INVALID")
        # Preserve range as a description; it is NOT an executable price.
        rng = field(strings, "Range:")
        if not 1 <= len(rng) <= 80:
            deny("C9_FIRSTPARTY_RANGE_INVALID")
        found[key] = {
            "firstPartyName": name, "mm2FirstPartyListed": value,
            "mm2DemandOrdinal": demand, "mm2RarityOrdinal": rarity,
            "mm2StabilityLabel": stability, "mm2RangeLabel": rng,
        }
    return found


def collect(pages, old_crosswalk, *, captured_utc, transport_label):
    """Validate a four-page same-capture research candidate; never live-trade."""
    at = timeparse(captured_utc)
    if type(pages) is not dict or set(pages) != set(PAGES) or (
        type(transport_label) is not str or transport_label not in
        ("DIRECT_HTTPS_GITHUB_RESEARCH", "FIRECRAWL_MEDIATED_HTTPS_RESEARCH")
    ):
        deny("C9_FIRSTPARTY_FOUR_PAGE_TRANSPORT_REQUIRED")
    if type(old_crosswalk) is not dict or (
        old_crosswalk.get("schema") != CROSSWALK_SCHEMA or
        old_crosswalk.get("historicalRegistryBlob") != REGISTRY_GIT_BLOB or
        old_crosswalk.get("matchedHistoricalGameKeys") != 189 or
        old_crosswalk.get("crosswalkRowsSha256") != HISTORICAL_ROWS_SHA256 or
        type(old_crosswalk.get("items")) is not list or
        len(old_crosswalk["items"]) != 189 or
        rows_sha(old_crosswalk["items"]) != HISTORICAL_ROWS_SHA256 or
        old_crosswalk.get("researchOnly") is not True or
        old_crosswalk.get("authorizesTrade") is not False or
        old_crosswalk.get("authorizesAccept") is not False
    ):
        deny("C9_FIRSTPARTY_HISTORICAL_189_PIN_CHANGED")
    published = parse_home(pages["home"])
    age = (at - published.astimezone(timezone.utc)).total_seconds()
    if not 0 <= age <= MAX_PUBLISHER_AGE:
        deny("C9_FIRSTPARTY_PUBLISHER_CLOCK_STALE_OR_FUTURE")
    parsed = {key: parse_tier(pages[key], key) for key in PAGE_COUNT}
    historical = {key: {} for key in KEY_COUNT}
    output = []
    for item in old_crosswalk["items"]:
        if type(item) is not dict:
            deny("C9_FIRSTPARTY_ORIGINAL_ROW_INVALID")
        key,category = item.get("rawGameKeyCandidate"),item.get("marketCategory")
        if type(key) is not str or category not in historical or key in historical[category]:
            deny("C9_FIRSTPARTY_ORIGINAL_DUPLICATE_OR_BAD_CATEGORY")
        historical[category][key] = item
        match = norm(item.get("marketName"))
        actual = parsed[category].get(match)
        if actual is None:
            deny("C9_FIRSTPARTY_RAW_KEY_PUBLIC_NAME_NOT_FOUND:" + key)
        if item.get("outgoingGingerscopeProtected") is not (key == "Gingerscope"):
            deny("C9_FIRSTPARTY_GINGERSCOPE_OUTBOUND_GUARD_CHANGED")
        if item.get("exactGameInstanceProven") is not False:
            deny("C9_FIRSTPARTY_FALSE_CLIENT_IDENTITY_AUTHORITY")
        output.append({
            "rawGameKeyCandidate": key, "category": category,
            "firstPartyName": actual["firstPartyName"],
            "mm2FirstPartyListed": actual["mm2FirstPartyListed"],
            "mm2DemandOrdinal": actual["mm2DemandOrdinal"],
            "mm2RarityOrdinal": actual["mm2RarityOrdinal"],
            "mm2StabilityLabel": actual["mm2StabilityLabel"],
            "mm2RangeLabel": actual["mm2RangeLabel"],
            "historicalAggregatorMM2ListedForAuditOnly": item["mm2Listed"],
            "outgoingGingerscopeProtected": key == "Gingerscope",
            "authenticatedRobloxItemInstance": False,
            "measuredCounterpartyTradeFill": False,
        })
    if {key: len(val) for key,val in historical.items()} != KEY_COUNT:
        deny("C9_FIRSTPARTY_189_COVERAGE_INCOMPLETE")
    for category in KEY_COUNT:
        used = {norm(row["marketName"]) for row in historical[category].values()}
        if set(parsed[category]) - used != REVIEWED_EXTRAS[category]:
            deny("C9_FIRSTPARTY_NEW_OR_MISSING_PUBLIC_ITEM_" + category)
        if len(used) != len(historical[category]):
            deny("C9_FIRSTPARTY_MULTIPLE_RAW_KEYS_MAP_TO_ONE_NAME")
    if len(output) != 189 or sum(x["outgoingGingerscopeProtected"] for x in output) != 1:
        deny("C9_FIRSTPARTY_PROTECTED_TARGET_OR_ROW_COUNT_CHANGED")
    output.sort(key=lambda x: x["rawGameKeyCandidate"])
    differences = sorted(x["rawGameKeyCandidate"] for x in output if
                         x["mm2FirstPartyListed"] != x["historicalAggregatorMM2ListedForAuditOnly"])
    return {
        "schema": SCHEMA, "status": "FIRST_PARTY_MM2VALUES_189_RESEARCH_NOT_TRADABLE",
        "sourceSite": SITE, "pageURLs": PAGES.copy(),
        "publisherUpdatedAt": published.isoformat(),
        "sourceCapturedUtc": at.isoformat().replace("+00:00", "Z"),
        "publisherAgeAtCaptureSeconds": int(age),
        "sourceTransport": transport_label,
        "firstPartyDirectGithubFetchVerified": transport_label == "DIRECT_HTTPS_GITHUB_RESEARCH",
        "firstPartyPublisherSignatureVerified": False,
        "pageHtmlSha256": {key: sha256(pages[key].encode("utf-8")).hexdigest() for key in PAGES},
        "pageHtmlBytes": {key: len(pages[key].encode("utf-8")) for key in PAGES},
        "historicalRegistryBlob": REGISTRY_GIT_BLOB,
        "historicalAggregatorRowsSha256": HISTORICAL_ROWS_SHA256,
        "matchedHistoricalGameKeys": 189, "categoryGameKeys": KEY_COUNT.copy(),
        "excludedReviewedExtraAncients": 1,
        "aggregatorMM2PriceConflicts": len(differences),
        "aggregatorMM2PriceDisagreementKeys": differences,
        "rowsSha256": rows_sha(output),
        "researchOnly": True, "safeForLiveMarketQuotes": False,
        "actualRobloxItemIdentityVerified": False,
        "tradeCompletionProven": False, "measuredRetradability": False,
        "authorizesTrade": False, "authorizesOffer": False,
        "authorizesAccept": False, "mayReportProfit": False,
        "mayUseForStrategyLearning": False, "rows": output,
    }


def validate_freshness(report, *, now_utc):
    if type(report) is not dict or report.get("schema") != SCHEMA or (
        report.get("researchOnly") is not True or
        report.get("authorizesTrade") is not False or
        report.get("authorizesAccept") is not False or
        report.get("safeForLiveMarketQuotes") is not False
    ):
        deny("C9_FIRSTPARTY_UNSAFE_REPORT")
    now = timeparse(now_utc)
    cap = timeparse(report.get("sourceCapturedUtc"))
    age = (now-cap).total_seconds()
    if not 0 <= age <= MAX_CAPTURE_AGE:
        deny("C9_FIRSTPARTY_CAPTURE_EXPIRED_OR_FUTURE")
    return {"status": "FRESH_CAPTURE_CLIENT_RESEARCH_ONLY",
            "sourceAgeSeconds": int(age), "authorizesTrade": False}


def fetch_page(url):
    if url not in PAGES.values():
        deny("C9_FIRSTPARTY_UNREVIEWED_URL")
    req = Request(url, headers={"User-Agent": "GingerscopeResearch/1.0",
                                "Accept": "text/html"})
    try:
        with urlopen(req, timeout=20) as r:
            parsed = urlparse(r.geturl())
            if r.status != 200 or parsed.scheme != "https" or (
                parsed.hostname not in ("www.mm2values.com", "mm2values.com")
            ) or "text/html" not in r.headers.get("Content-Type", ""):
                deny("C9_FIRSTPARTY_HTTP_ORIGIN_OR_TYPE_CHANGED")
            body = r.read(2_000_001)
    except HTTPError as e:
        deny("C9_FIRSTPARTY_HTTP_" + str(e.code))
    except (URLError, TimeoutError, OSError):
        deny("C9_FIRSTPARTY_DIRECT_NETWORK_UNAVAILABLE")
    if not 500 < len(body) < 2_000_000:
        deny("C9_FIRSTPARTY_BODY_SIZE_INVALID")
    try:
        return body.decode("utf-8")
    except UnicodeDecodeError:
        deny("C9_FIRSTPARTY_NON_UTF8_RESPONSE")


def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--original", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    args=p.parse_args(argv)
    try:
        pages={key:fetch_page(url) for key,url in PAGES.items()}
        captured=datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00","Z")
        old=json.loads(args.original.read_text(encoding="utf-8"))
        report=collect(pages,old,captured_utc=captured,
                       transport_label="DIRECT_HTTPS_GITHUB_RESEARCH")
        validate_freshness(report,now_utc=captured)
        args.output.write_text(json.dumps(report,sort_keys=True,indent=2)+"\n",encoding="utf-8")
        print("C9_FIRSTPARTY_MM2VALUES_189="+report["status"])
        print("C9_FIRSTPARTY_MM2VALUES_PUBLISHED="+report["publisherUpdatedAt"])
        print("C9_AGGREGATOR_MM2_DISAGREEMENTS="+str(report["aggregatorMM2PriceConflicts"]))
        print("C9_TRADE_AUTHORITY=FALSE")
        return 0
    except (MM2ValuesBlocked,TypeError,ValueError,OSError,KeyError) as e:
        print("C9_FIRSTPARTY_MM2VALUES_189=BLOCKED")
        print("C9_REASON="+str(e))
        return 2


if __name__=="__main__":
    raise SystemExit(main())
