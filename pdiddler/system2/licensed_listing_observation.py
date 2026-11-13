"""System 2, first independent signal: licensed MM2 listing OBSERVATIONS.

Input is a LOCAL copy of FairStash's explicitly CC BY 4.0 supply CSV.
This module NEVER downloads, scrapes, or serves someone else's value list.
Counts are samples of posted offers, not price, fills, player inventory,
actual item supply, independently verified liquidity or a game raw key.

This is deliberately NOT a P3/P4 script or a source of live quote authority.
Website: https://fairstash.app/data
Published dataset: https://fairstash.app/data/supply.csv
License: https://creativecommons.org/licenses/by/4.0/
"""
from __future__ import annotations

import csv
from datetime import date, datetime, timezone
import hashlib
import io
import re

SCHEMA = "gingerscope-system2-listed-offer-observation-research-v1"
SOURCE = "https://fairstash.app/data/supply.csv"
ATTRIBUTION = "FairStash (https://fairstash.app), CC BY 4.0"
LICENSE = "https://creativecommons.org/licenses/by/4.0/"
HEADER = ["game", "item", "slug", "day", "selling", "buying"]
MM2 = {"murder mystery 2", "mm2"}
SLUG = re.compile(r"^[a-z0-9][a-z0-9_-]{0,127}$")
WHOLE = re.compile(r"^(0|[1-9][0-9]{0,7})$")
UTC = re.compile(r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$")
MAX_BYTES = 16_000_000
MAX_ROWS = 250_000
MAX_RESEARCH_AGE_DAYS = 2  # Conservative research screen; NEVER a live-price TTL.


class InvalidListingSource(ValueError):
    def __init__(self, code: str):
        super().__init__(code)
        self.code = code


def require(ok: bool, why: str) -> None:
    if not ok:
        raise InvalidListingSource(why)


def stamp(s: str) -> datetime:
    require(type(s) is str and bool(UTC.fullmatch(s)), "INVALID_UTC_CLOCK")
    try:
        result = datetime.fromisoformat(s.replace("Z", "+00:00"))
    except ValueError:
        raise InvalidListingSource("INVALID_UTC_CLOCK") from None
    require(result.utcoffset().total_seconds() == 0, "INVALID_UTC_CLOCK")
    return result


def day(s: str) -> date:
    require(type(s) is str and
            bool(re.fullmatch(r"\d{4}-\d\d-\d\d", s)), "INVALID_DAY")
    try:
        return date.fromisoformat(s)
    except ValueError:
        raise InvalidListingSource("INVALID_DAY") from None


def nonnegative(s: str, label: str) -> int:
    require(type(s) is str and bool(WHOLE.fullmatch(s)),
            "INVALID_" + label)
    return int(s)


def response(status: str, reason: str, **details) -> dict:
    """Fixed, fail-closed authority surface independent of caller claims."""
    return {
        # Untrusted/unforeseen detail keys can never replace source metadata
        # or the mandatory disabled-authority contract.
        **details,
        "schema": SCHEMA, "status": status, "reason": reason,
        "provider": "FairStash", "datasetUrl": SOURCE,
        "attribution": ATTRIBUTION, "licenseUrl": LICENSE,
        "sourceHttpOriginIndependentlyAuthenticated": False,
        "gameRawKeyIdentityProven": False,
        "itemTradeSettlementProven": False,
        "observedCompletedTradeLiquidityVerified": False,
        "actualInventorySupplyMeasured": False,
        "postedListingsAreCompletedTrades": False,
        "missingDaysAreZeros": False,
        "priceDataPresent": False,
        "verifiedMarketQuote": False,
        "mayFeedStage120AsVerifiedMarket": False,
        "mayFeedLiveStrategy": False,
        "authorizesTrade": False, "authorizesOffer": False,
        "authorizesAccept": False, "mayReportProfit": False,
        "maySendDiscordWebhook": False, "mayUseForStrategyLearning": False,
        "serverCompletionProven": False, "tradeOutcome": "UNKNOWN",
    }


def _audit(raw: bytes, *, evaluated_utc: str, source_url: str,
           item_slug: str | None = None) -> dict:
    require(type(raw) is bytes and 0 < len(raw) <= MAX_BYTES,
            "CSV_SIZE_INVALID")
    require(source_url == SOURCE, "SOURCE_URL_NOT_CANONICAL")
    current = stamp(evaluated_utc)
    if item_slug is not None:
        require(type(item_slug) is str and bool(SLUG.fullmatch(item_slug)),
                "SELECTED_SLUG_INVALID")
    try:
        data = raw.decode("utf-8-sig")
    except UnicodeDecodeError:
        raise InvalidListingSource("CSV_UTF8_INVALID") from None
    require("\x00" not in data, "CSV_BINARY_CONTENT_INVALID")
    # The provider's GitHub mirror (confirmed Nov13) prefixes descriptive
    # comment lines. Comments are NOT an authenticated publisher watermark,
    # rights grant or measurement date. Only allow them BEFORE the header;
    # comments midstream are malformed observations, not skipped silently.
    lines = data.splitlines(keepends=True)
    comments = 0
    while comments < len(lines) and lines[comments].startswith("#"):
        require(comments < 32 and len(lines[comments]) <= 1024,
                "CSV_PREAMBLE_INVALID")
        comments += 1
    require(comments < len(lines), "CSV_COLUMNS_NOT_CANONICAL")
    reader = csv.DictReader(
        io.StringIO("".join(lines[comments:]), newline=""), strict=True)
    require(reader.fieldnames == HEADER, "CSV_COLUMNS_NOT_CANONICAL")

    mm2_rows = 0
    all_rows = 0
    buying_missing = 0
    observed_zero = 0
    seen: set[tuple[str, str]] = set()
    names: dict[str, str] = {}
    sample_days: set[date] = set()
    item_history: dict[date, tuple[int, int | None]] = {}
    all_mm2_days: set[date] = set()
    for row in reader:
        all_rows += 1
        require(all_rows <= MAX_ROWS, "CSV_TOO_MANY_ROWS")
        require(None not in row and row.get(None) is None and
                all(type(row[k]) is str for k in HEADER),
                "CSV_ROW_INVALID")
        g = row["game"].strip().lower()
        if g not in MM2:
            continue  # The licensed file also covers two other games.
        mm2_rows += 1
        slug = row["slug"]
        label = row["item"]
        require(bool(SLUG.fullmatch(slug)), "MM2_SLUG_INVALID")
        require(0 < len(label) <= 180 and
                not any(ord(c) < 32 for c in label) and
                not label.startswith(("=", "+", "-", "@")),
                "MM2_ITEM_LABEL_INVALID")
        value_day = day(row["day"])
        require(value_day <= current.date(), "MM2_FUTURE_OBSERVATION")
        selling = nonnegative(row["selling"], "SELLING_COUNT")
        buying = (None if row["buying"] == "" else
                  nonnegative(row["buying"], "BUYING_COUNT"))
        key = (slug, row["day"])
        require(key not in seen, "MM2_DUPLICATE_SLUG_DAY")
        seen.add(key)
        require(slug not in names or names[slug] == label,
                "MM2_ITEM_SLUG_LABEL_COLLISION")
        names[slug] = label
        all_mm2_days.add(value_day)
        if buying is None:
            buying_missing += 1
        if selling == 0:
            observed_zero += 1
        if slug == item_slug:
            item_history[value_day] = (selling, buying)

    require(mm2_rows > 0 and all_mm2_days, "MM2_ROWS_MISSING")
    last = max(all_mm2_days)
    first = min(all_mm2_days)
    age = (current.date() - last).days
    require(age >= 0, "MM2_FUTURE_OBSERVATION")
    item = None
    if item_slug is not None:
        value = item_history.get(last)
        previous = item_history.get(last.fromordinal(last.toordinal() - 1))
        item = {
            "slug": item_slug,
            "observedAnyDay": bool(item_history),
            "observedOnDatasetLatestDay": value is not None,
            # Missing row is UNKNOWN, not observed 0, no claim of no listings.
            "latestDaySellingObserved": value[0] if value else None,
            "latestDayBuyingObserved": value[1] if value else None,
            "previousCalendarDaySellingObserved":
                previous[0] if previous else None,
            "previousCalendarDayBuyingObserved":
                previous[1] if previous else None,
            "dayGapIsUnknownNotZero": True,
            "lastSeenDay": (max(item_history).isoformat()
                            if item_history else None),
            "rawGameItemKeyAuthenticated": False,
            "executableLiquiditySignal": False,
        }
    # File SHA proves byte consistency of THIS supplied copy, not publisher
    # HTTP origin, upstream trade settlement, license holder identity or URL.
    summary = {
        "inputSha256": hashlib.sha256(raw).hexdigest(),
        "untrustedHeaderCommentLines": comments,
        "datasetRows": all_rows,
        "mm2ObservationRows": mm2_rows,
        "mm2DistinctSlugs": len(names),
        "mm2DistinctObservedDays": len(all_mm2_days),
        "mm2FirstObservedDay": first.isoformat(),
        "mm2LatestObservedDay": last.isoformat(),
        "datasetAgeCalendarDays": age,
        "mm2RowsWithBuyingUnknown": buying_missing,
        "mm2RowsWithObservedSellingZero": observed_zero,
        "sampleWindowCoverageUnknown": True,
        "itemObservation": item,
    }
    if age > MAX_RESEARCH_AGE_DAYS:
        return response("BLOCKED_STALE_LISTING_SAMPLE",
                        "LAST_MM2_OBSERVATION_TOO_OLD", **summary)
    return response("RESEARCH_LISTING_OBSERVATIONS_ONLY",
                    "LICENSED_SAMPLED_POSTS_NOT_PRICES_OR_FILLS", **summary)


def audit_csv(raw: bytes, *, evaluated_utc: str, source_url: str = SOURCE,
              item_slug: str | None = None) -> dict:
    """Total classifier: even a good result NEVER grants trading authority."""
    try:
        return _audit(raw, evaluated_utc=evaluated_utc, source_url=source_url,
                      item_slug=item_slug)
    except (InvalidListingSource, csv.Error, ValueError, TypeError,
            OverflowError, KeyError) as exc:
        why = (exc.code if isinstance(exc, InvalidListingSource)
               else "CSV_PARSE_OR_INPUT_INVALID")
        return response("BLOCKED", why)
