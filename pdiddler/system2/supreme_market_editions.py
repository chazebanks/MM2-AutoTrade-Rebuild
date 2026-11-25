"""Immutable Supreme-only pricing for offline advisory analysis.

The legacy inputs use their compiled archive pins. A new direct page capture
requires an expected SHA-256 from independent review. Hashes establish byte
integrity against that review, and carry no publisher signature or trade authority.
"""
from __future__ import annotations

import argparse
from collections import Counter
from copy import deepcopy
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from hashlib import sha256
import json
from pathlib import Path
import re
from types import MappingProxyType
from typing import Mapping
from urllib.parse import parse_qs, urlsplit

from pdiddler.system2 import manual_portfolio_review as manual
from pdiddler.system2.supreme_only_strategy_research import (
    CATALOG_BLOB_SHA, MAX_CAPTURE_AGE_SECONDS, MAX_PUBLICATION_AT_CAPTURE_SECONDS,
    NOV25_CATALOG_BLOB_SHA, NOV25_SOURCE_CAPTURE, NOV25_SOURCE_PUBLICATION, SOURCE,
    SOURCE_CAPTURE, SOURCE_PUBLICATION, TARGET, blob_sha, demand, deny, source_rows, utc,
)

SCHEMA = "gingerscope-supreme-reviewed-pages-v1"
PUBLISHER_URLS = {
    "home": "https://supremevalues.com/",
    "ancient": "https://supremevalues.com/mm2/ancients",
    "godly": "https://supremevalues.com/mm2/godlies",
    "chroma": "https://supremevalues.com/mm2/chromas",
}
CATEGORIES = ("ancient", "godly", "chroma")
MAX_ARCHIVE_BYTES = 12_000_000
MAX_PAGE_BYTES = 2_000_000
MAX_ITEMS = 400
_HASH = re.compile(r"[0-9a-f]{64}\Z")
_ITEM_ID = re.compile(r"[A-Za-z0-9 _.'-]{1,120}\Z")
_PRICE_TEXT = r"(?:[1-9][0-9]{0,9}|[1-9][0-9]{0,2}(?:,[0-9]{3}){1,3})"
_PRICE = re.compile(_PRICE_TEXT)
_RANGE = re.compile(rf"({_PRICE_TEXT})\s*[-–]\s*({_PRICE_TEXT})\Z")
_PERCENT = re.compile(r"[+-]?\d{1,8}(?:\.\d{1,8})?\Z")
_PUBLIC_FIELDS = {
    "officialName": "name", "supremeListed": "listed_value", "supremeDemand": "demand",
    "supremeStability": "stability", "published_range": "published_range",
    "publisherVariant": "publisher_variant", "publisherChangePercent": "publisher_change_percent",
    "historicalRawGameKeyCandidate": "raw_identity_provenance",
}


def _z(stamp):
    return stamp.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def _public_id(row):
    return f"{row['category']}:{row['officialItemId']}"


def _plain(value):
    return dict(value) if isinstance(value, Mapping) else value


def _capture_age(provenance, evaluated_at_utc):
    now = utc(evaluated_at_utc)
    capture = utc(provenance["capturedUtc"], captured=True)
    if now < capture:
        deny("SUPREME_ONLY_CAPTURE_FROM_FUTURE")
    if now > utc(provenance["expiresUtc"], captured=True):
        deny("SUPREME_ONLY_SOURCE_EXPIRED_NO_OTHER_LIST_FALLBACK")
    return int((now - capture).total_seconds())


def _exclusions_by_identity(exclusions):
    result = {}
    for row in exclusions:
        key = f"{row['category']}:{row['publisher_id'] or row['name']}"
        result.setdefault(key, set()).add(row["reason"])
    return result


@dataclass(frozen=True)
class MarketEdition:
    rows: Mapping
    _provenance: dict
    _excluded: tuple
    _statuses: Mapping = field(init=False, repr=False)

    def __post_init__(self):
        statuses = {
            key: next(iter(reasons)) if len(reasons) == 1 else "AMBIGUOUS"
            for key, reasons in _exclusions_by_identity(self._excluded).items()
        }
        statuses.update({_public_id(row): "PRICED_WEAPON" for row in self.rows.values()})
        object.__setattr__(self, "_statuses", MappingProxyType(statuses))

    @property
    def identity(self):
        return self._provenance["archiveSha256"]

    @property
    def provenance(self):
        return deepcopy(self._provenance)

    def identity_status(self, publisher_item_id: str) -> str:
        """Classify an exact publisher ID or a displayed priceless name."""
        if type(publisher_item_id) is not str:
            deny("SUPREME_ONLY_PUBLISHER_ID_TYPE_INVALID")
        return self._statuses.get(publisher_item_id, "UNKNOWN")

    def require_current(self, evaluated_at_utc):
        return {**self.provenance, "captureAgeSeconds": _capture_age(self._provenance, evaluated_at_utc)}

    def summary(self):
        counts = Counter(row["category"] for row in self.rows.values())
        target = self.rows.get(TARGET)
        return {
            **self.provenance,
            "categories": {category: counts[category] for category in CATEGORIES},
            "priced_items": len(self.rows),
            "published_range_rows": sum(row["published_range"] is not None for row in self.rows.values()),
            "excluded": deepcopy(list(self._excluded)),
            "gingerscope": {
                "publisher_id": _public_id(target) if target else f"ancient:{TARGET}",
                "listed_value": target["supremeListed"] if target else None,
                "outgoing_protected": True,
            },
        }


def _edition(rows, provenance, exclusions, raw, at):
    immutable_rows = MappingProxyType({
        key: MappingProxyType({
            field: MappingProxyType(value) if type(value) is dict else value
            for field, value in row.items()
        }) for key, row in rows.items()
    })
    archive_hash = sha256(raw).hexdigest()
    return MarketEdition(immutable_rows, {
        **provenance,
        "captureAgeSeconds": _capture_age(provenance, at),
        "editionId": archive_hash,
        "archiveSha256": archive_hash,
        "valueSource": SOURCE,
        "sourceSignatureVerified": False,
        "authorizesTrade": False,
        "mayUseForStrategyLearning": False,
    }, tuple(exclusions))


def _legacy(catalog, evaluated_at_utc):
    rows, provenance = source_rows(catalog, evaluated_at_utc=evaluated_at_utc)
    ranges = manual._publisher_ranges(catalog, provenance)
    excluded, pages = [], {}
    if provenance["catalogGitBlob"] == NOV25_CATALOG_BLOB_SHA:
        # The pinned range reader validates the receipt bytes before extracting ranges.
        # Derive exclusions from those same verified bytes.
        receipt_raw = manual.PARITY_RECEIPT.read_bytes()
        if blob_sha(receipt_raw) != manual.PARITY_RECEIPT_BLOB:
            deny("SUPREME_ONLY_PINNED_PARITY_RECEIPT_CHANGED")
        for category, page in json.loads(receipt_raw)["pages"].items():
            pages[category] = {key: page[key] for key in ("url", "sha256", "byteCount")}
            for field, reason in (("hidden", "HIDDEN"), ("unpriced", "PRICES_UNAVAILABLE"), ("pets", "PET")):
                excluded.extend({"category": category, "publisher_id": name if field != "unpriced" else None,
                                 "name": name if field == "unpriced" else None, "reason": reason}
                                for name in page["excluded"][field])
    for key, row in rows.items():
        row["published_range"] = ranges.get(_public_id(row))
        row["historicalRawGameKeyCandidate"] = key
    provenance.update({
        "expiresUtc": _z(utc(provenance["capturedUtc"]) + timedelta(seconds=MAX_CAPTURE_AGE_SECONDS)),
        "editionTier": "REPOSITORY_PINNED_RESEARCH",
        "pageEvidence": pages,
    })
    return _edition(rows, provenance, excluded, catalog, evaluated_at_utc)


def _unique_keys(pairs):
    obj = dict(pairs)
    if len(obj) != len(pairs):
        deny("SUPREME_ONLY_ARCHIVE_DUPLICATE_FIELDS")
    return obj


def _path_html(archive):
    pages = archive["pages"]
    if type(pages) is not dict or pages.keys() != PUBLISHER_URLS.keys():
        deny("SUPREME_ONLY_FOUR_OFFICIAL_PAGES_REQUIRED")
    result, evidence = {}, {}
    for category, url in PUBLISHER_URLS.items():
        page = pages[category]
        if (type(page) is not dict or page.keys() != {"url", "sha256", "html"}
                or page["url"] != url or type(page["html"]) is not str):
            deny("SUPREME_ONLY_OFFICIAL_PAGE_CONTRACT_INVALID")
        source = page["html"].encode("utf-8")
        if not 500 < len(source) < MAX_PAGE_BYTES:
            deny("SUPREME_ONLY_OFFICIAL_PAGE_SIZE_INVALID")
        if page["sha256"] != sha256(source).hexdigest():
            deny("SUPREME_ONLY_PAGE_SHA256_MISMATCH")
        result[category] = page["html"]
        evidence[category] = {"url": url, "sha256": page["sha256"], "byteCount": len(source)}
    return result, evidence


def _number(text):
    if type(text) is not str or not _PRICE.fullmatch(text):
        deny("SUPREME_ONLY_OFFICIAL_PRICE_LABEL_INVALID")
    result = int(text.replace(",", ""))
    if result >= 10**10:
        deny("SUPREME_ONLY_OFFICIAL_PRICE_OUT_OF_RANGE")
    return result


def _range(card, value):
    node = card.select_one(".itemrange")
    if node is None or node.get_text(strip=True) in {"N/A", "[N/A]"}:
        return None
    match = _RANGE.fullmatch(node.get_text(strip=True))
    if not match:
        deny("SUPREME_ONLY_OFFICIAL_RANGE_LABEL_INVALID")
    low, high = (_number(part) for part in match.groups())
    if low > value or high < value:
        deny("SUPREME_ONLY_OFFICIAL_RANGE_DOES_NOT_CONTAIN_LISTED_VALUE")
    return {"low": low, "high": high}


def _card(category, card):
    cell = card.select_one(".itemcell, .itemcell-exp")
    if cell is None:
        deny("SUPREME_ONLY_OFFICIAL_CARD_CELL_MISSING")
    publisher_id = cell.get("id")
    if publisher_id is not None and not _ITEM_ID.fullmatch(publisher_id):
        deny("SUPREME_ONLY_OFFICIAL_ITEM_ID_INVALID")
    button = cell.select_one("button[data-name]")
    heading = cell.select_one(".itemhead")
    name = button["data-name"] if button else heading.get_text(strip=True) if heading else None
    if not name or len(name) > 110 or name != name.strip():
        deny("SUPREME_ONLY_OFFICIAL_ITEM_NAME_INVALID")
    tier = card.find_parent("section", attrs={"data-tier": True})
    value_node = cell.select_one(".itemvalue")
    # The publisher marks pets by a separate tier and hides duplicate/internal cards.
    if tier is not None and tier.get("data-tier").lower() == "pets":
        exclusion = "PET"
    elif card.has_attr("hidden") or re.search(r"display\s*:\s*none(?:\s*[;!]|\s*\Z)", card.get("style", ""), re.I):
        exclusion = "HIDDEN"
    elif ((value_node and value_node.get_text(strip=True).lower() == "priceless")
          or (not card.has_attr("data-value") and cell.find("b", string=re.compile(r"^\s*Priceless\s*$", re.I)))):
        exclusion = "PRICES_UNAVAILABLE"
    else:
        exclusion = None
    if exclusion:
        return None, {"category": category, "publisher_id": publisher_id, "name": name, "reason": exclusion}
    if not (publisher_id and button and value_node):
        deny("SUPREME_ONLY_OFFICIAL_PRICED_CARD_INCOMPLETE")
    link = cell.select_one("a.itemlink[href]")
    target = urlsplit(link["href"]) if link else None
    if (target is None or target.netloc or target.scheme or target.path != urlsplit(PUBLISHER_URLS[category]).path
            or parse_qs(target.query) != {"item": [publisher_id]}):
        deny("SUPREME_ONLY_OFFICIAL_ITEM_ID_AND_LINK_DISAGREE")
    quote = _number(card.get("data-value"))
    if quote != _number(value_node.get_text(strip=True)):
        deny("SUPREME_ONLY_VISIBLE_AND_MACHINE_QUOTES_DISAGREE")
    ordinal = card.get("data-demand")
    if not ordinal or len(ordinal) > 16:
        deny("SUPREME_ONLY_PUBLISHER_DEMAND_INVALID")
    demand(ordinal)
    label = card.get("data-stability")
    visible_label = cell.select_one(".itemstability")
    if not label or len(label) > 80 or visible_label is None or visible_label.get_text(strip=True) != label:
        deny("SUPREME_ONLY_VISIBLE_AND_MACHINE_STABILITY_DISAGREE")
    variant = {field: card.get(f"data-{field}") or None for field in ("event", "year")}
    if any(value is not None and len(value) > 80 for value in variant.values()):
        deny("SUPREME_ONLY_OFFICIAL_VARIANT_INVALID")
    change = card.get("data-changepct")
    if change is not None and not _PERCENT.fullmatch(change):
        deny("SUPREME_ONLY_OFFICIAL_CHANGE_PERCENT_INVALID")
    return {
        "category": category, "officialName": name, "officialItemId": publisher_id,
        "supremeListed": quote, "supremeDemand": ordinal, "supremeStability": label,
        "published_range": _range(card, quote), "publisherVariant": variant,
        "publisherChangePercent": change,
    }, None


def _read_capture(catalog, evaluated_at_utc):
    # Reuse the existing original-publisher parser for the publication clock and
    # headings. Import only for reviewed page archives so pinned replay stays stdlib-only.
    from pdiddler.system2.c9_supreme_firstparty_189_research import (
        BeautifulSoup, OFFICIAL_PAGE_HEADINGS, SupremeBlocked, UPDATE, extract_publisher_clock,
    )

    try:
        doc = json.loads(catalog, object_pairs_hook=_unique_keys)
        if (type(doc) is not dict or doc.keys() != {"schema", "sourceCapturedUtc", "pages"}
                or doc["schema"] != SCHEMA):
            deny("SUPREME_ONLY_REVIEWED_ARCHIVE_SCHEMA_INVALID")
        capture = utc(doc["sourceCapturedUtc"], captured=True)
        pages, evidence = _path_html(doc)
        publications = {extract_publisher_clock(html).isoformat() for html in pages.values()}
        if len(publications) != 1:
            deny("SUPREME_ONLY_PUBLICATION_CHANGED_DURING_CAPTURE")
        publication = datetime.fromisoformat(publications.pop())
        if not timedelta(0) <= capture - publication <= timedelta(seconds=MAX_PUBLICATION_AT_CAPTURE_SECONDS):
            deny("SUPREME_ONLY_PUBLISHER_EDITION_EXPIRED_OR_FUTURE")
        home_log = BeautifulSoup(pages["home"], "html.parser").select_one("#updatelog")
        home_date = UPDATE.search(home_log.get_text(" ", strip=True)) if home_log else None
        if not home_date or tuple(map(int, home_date.groups())) != (publication.day, publication.month, publication.year):
            deny("SUPREME_ONLY_OFFICIAL_CHANGELOG_AND_PUBLICATION_DISAGREE")
    except (UnicodeError, json.JSONDecodeError, RecursionError):
        deny("SUPREME_ONLY_REVIEWED_ARCHIVE_JSON_INVALID")
    except SupremeBlocked as exc:
        deny(str(exc))

    try:
        expires = capture + timedelta(seconds=MAX_CAPTURE_AGE_SECONDS)
    except OverflowError:
        deny("SUPREME_ONLY_CAPTURE_CLOCK_EXPIRY_OUT_OF_RANGE")
    for historical_pub, historical_capture in (
        (NOV25_SOURCE_PUBLICATION, NOV25_SOURCE_CAPTURE), (SOURCE_PUBLICATION, SOURCE_CAPTURE),
    ):
        if publication == utc(historical_pub):
            expires = min(expires, utc(historical_capture) + timedelta(seconds=MAX_CAPTURE_AGE_SECONDS))
    provenance = {
        "publisherUpdatedAt": publication.isoformat(),
        "capturedUtc": _z(capture),
        "expiresUtc": _z(expires),
        "catalogGitBlob": blob_sha(catalog),
        "editionTier": "OPERATOR_PINNED_PUBLISHER_PAGE_RESEARCH",
        "pageEvidence": evidence,
    }
    _capture_age(provenance, evaluated_at_utc)
    historical, _ = source_rows(manual.DEFAULT_CATALOG.read_bytes(), evaluated_at_utc=NOV25_SOURCE_CAPTURE)
    historical_ids = {_public_id(row): key for key, row in historical.items()}
    rows, excluded = {}, []
    for category in CATEGORIES:
        soup = BeautifulSoup(pages[category], "html.parser")
        heading = soup.find("h1")
        if not heading or heading.get_text(" ", strip=True) != OFFICIAL_PAGE_HEADINGS[category]:
            deny("SUPREME_ONLY_OFFICIAL_CATEGORY_HEADING_CHANGED")
        cards = soup.select("div.itemcolumn")
        if not cards or len(cards) > MAX_ITEMS:
            deny("SUPREME_ONLY_OFFICIAL_CATEGORY_CARD_COUNT_INVALID")
        for card in cards:
            row, exclusion = _card(category, card)
            if exclusion is not None:
                excluded.append(exclusion)
                continue
            publisher_id = _public_id(row)
            historic_key = historical_ids.get(publisher_id)
            # Internal identifiers for new rows carry no asserted native key.
            key = historic_key or f"supreme_{sha256(publisher_id.encode()).hexdigest()}"
            if key in rows:
                deny("SUPREME_ONLY_OFFICIAL_ITEM_ID_DUPLICATE")
            if row["officialName"].casefold() == TARGET.casefold() and key != TARGET:
                deny("SUPREME_ONLY_GINGERSCOPE_IDENTITY_REQUIRES_REVIEW")
            rows[key] = {**row, "rawGameKeyCandidate": key, "historicalRawGameKeyCandidate": historic_key,
                         "outgoingGingerscopeProtected": key == TARGET}
    if len(rows) > MAX_ITEMS:
        deny("SUPREME_ONLY_OFFICIAL_CATALOG_CARD_COUNT_INVALID")
    return _edition(rows, provenance, excluded, catalog, evaluated_at_utc)


def load_edition(catalog: bytes, *, evaluated_at_utc: str, expected_sha256: str | None = None) -> MarketEdition:
    if type(catalog) is not bytes or not 0 < len(catalog) <= MAX_ARCHIVE_BYTES:
        deny("SUPREME_ONLY_ARCHIVE_BYTES_OR_SIZE_INVALID")
    if expected_sha256 is not None:
        if type(expected_sha256) is not str or not _HASH.fullmatch(expected_sha256):
            deny("SUPREME_ONLY_REVIEWED_SHA256_INVALID")
        if sha256(catalog).hexdigest() != expected_sha256:
            deny("SUPREME_ONLY_ARCHIVE_SHA256_MISMATCH")
    if blob_sha(catalog) in {NOV25_CATALOG_BLOB_SHA, CATALOG_BLOB_SHA}:
        return _legacy(catalog, evaluated_at_utc)
    if expected_sha256 is None:
        deny("SUPREME_ONLY_REVIEWED_SHA256_REQUIRED")
    return _read_capture(catalog, evaluated_at_utc)


def compare_editions(previous: MarketEdition, current: MarketEdition) -> dict:
    previous_clock = utc(previous.provenance["publisherUpdatedAt"])
    current_clock = utc(current.provenance["publisherUpdatedAt"])
    if current_clock < previous_clock:
        deny("SUPREME_ONLY_PUBLICATION_ROLLBACK")
    if current_clock == previous_clock and current.identity != previous.identity:
        deny("SUPREME_ONLY_PUBLISHER_VERSION_NOT_ADVANCED")
    before = {_public_id(row): row for row in previous.rows.values()}
    after = {_public_id(row): row for row in current.rows.values()}
    excluded_before = _exclusions_by_identity(previous._excluded)
    excluded_after = _exclusions_by_identity(current._excluded)
    removed = before.keys() - after.keys()
    changes = {}
    for item in sorted(before.keys() & after.keys()):
        fields = {
            label: {"before": _plain(before[item].get(key)), "after": _plain(after[item].get(key))}
            for key, label in _PUBLIC_FIELDS.items() if before[item].get(key) != after[item].get(key)
        }
        if fields:
            changes[item] = fields
    return {
        "previous_edition": previous.identity, "current_edition": current.identity,
        "added": sorted(after.keys() - before.keys()), "removed": sorted(removed),
        "changes": changes, "excluded_before": previous.summary()["excluded"],
        "excluded_after": current.summary()["excluded"],
        "newly_excluded": {key: sorted(reasons) for key, reasons in sorted(excluded_after.items())
                           if key in removed or reasons != excluded_before.get(key)},
        "invalidates_prior_evaluations": previous.identity != current.identity,
    }


def capture_official(output: Path) -> str:
    """Save original public HTML for independent review, creating a new file."""
    from pdiddler.system2.c9_supreme_firstparty_189_research import fetch_official_page

    started = datetime.now(timezone.utc)
    pages = {}
    for category, url in PUBLISHER_URLS.items():
        html = fetch_official_page("" if category == "home" else urlsplit(url).path)
        pages[category] = {"url": url, "sha256": sha256(html.encode()).hexdigest(), "html": html}
    # Age is measured from the oldest request rather than the end of capture.
    raw = json.dumps({"schema": SCHEMA, "sourceCapturedUtc": _z(started), "pages": pages},
                     ensure_ascii=False, sort_keys=True).encode()
    if len(raw) > MAX_ARCHIVE_BYTES:
        deny("SUPREME_ONLY_ARCHIVE_BYTES_OR_SIZE_INVALID")
    with output.open("xb") as file:
        file.write(raw)
    return sha256(raw).hexdigest()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="New file for direct Supreme pages pending review")
    args = parser.parse_args(argv)
    try:
        print(capture_official(args.output))
    except (OSError, ValueError) as exc:
        parser.exit(2, f"Supreme capture failed: {exc}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
