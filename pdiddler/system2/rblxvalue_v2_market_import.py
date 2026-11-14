"""Authenticated RBLXValue v2 item-feed intake for Gingerscope research.

Fetch real API pages; preserve source provenance. Never guess the Roblox game
item key, infer liquidity, place offers, approve Accept, or report profit.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import sys
import time
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

CATEGORIES = ("ancient", "godly", "chroma")
API_ROOT = "https://api.rblxvalue.com/v2"
PAGE_SIZE = 100
MAX_PAGES = 20
SCHEMA = "gingerscope-rblxvalue-v2-live-item-candidate-v1"
SLUG = re.compile(r"^[a-z0-9][a-z0-9-]{0,119}$")


class DataFailure(Exception):
    """Stable public reason code, never raw provider responses."""


def _fail(reason):
    raise DataFailure(reason)


def _decimal(value):
    if value is None:
        return None
    if type(value) is bool or not isinstance(value, (int, float, str, Decimal)):
        _fail("NONNUMERIC_ITEM_VALUE")
    try:
        num = Decimal(str(value))
    except (InvalidOperation, ValueError):
        _fail("NONNUMERIC_ITEM_VALUE")
    if not num.is_finite() or num < 0 or num >= 10**9:
        _fail("OUT_OF_RANGE_ITEM_VALUE")
    return str(num.normalize())


def _short(value, limit=150):
    return type(value) is str and 0 < len(value) <= limit and not any(ord(c) < 32 for c in value)


def _item(value, category):
    if type(value) is not dict or type(value.get("id")) is not int or value["id"] < 1:
        _fail("INVALID_ITEM_ID")
    name, slug = value.get("name"), value.get("slug")
    if not _short(name) or type(slug) is not str or not SLUG.fullmatch(slug):
        _fail("INVALID_NAME_OR_SLUG")
    actual_category = value.get("category")
    if type(actual_category) is not str or actual_category.lower() != category:
        _fail("CATEGORY_FILTER_MISMATCH")
    weapon_type = value.get("type")
    if type(weapon_type) is not str or weapon_type.lower() not in ("knife", "gun"):
        return None
    demand = value.get("demand")
    if demand is not None and (type(demand) is not int or not 0 <= demand <= 10):
        _fail("DEMAND_FIELD_INVALID")
    stability = value.get("stability")
    if stability is not None and not _short(stability, 80):
        _fail("STABILITY_FIELD_INVALID")
    updated = value.get("last_updated")
    if updated is not None and not _short(updated, 60):
        _fail("ITEM_TIMESTAMP_INVALID")
    return {
        "providerId": value["id"], "providerSlug": slug, "providerName": name,
        "providerCategory": category, "weaponType": weapon_type.lower(),
        "valueEstimate": _decimal(value.get("value")),
        "mm2ValuesListed": _decimal(value.get("value_source_a")),
        "supremeListed": _decimal(value.get("value_source_b")),
        "demandOrdinal": demand, "stabilityLabel": stability,
        "providerUpdatedAtUnzoned": updated, "rawGameWeaponId": None,
        "gameVariantProven": False, "counterpartyLiquidityMeasured": False,
    }


def _meta(payload):
    if type(payload) is not dict or payload.get("error") is True:
        _fail("META_RESPONSE_INVALID")
    stamp = payload.get("last_updated")
    if not _short(stamp, 60):
        _fail("META_UPDATED_TIMESTAMP_MISSING")
    totals = payload.get("totals")
    if type(totals) is not dict or type(totals.get("items")) is not int or not 1 <= totals["items"] <= 20000:
        _fail("META_ITEM_COUNT_INVALID")
    sources = payload.get("sources", [])
    if type(sources) is not list or len(sources) > 20 or any(type(x) is not str for x in sources):
        _fail("META_SOURCE_LIST_INVALID")
    return {"providerLastUpdatedUnzoned": stamp, "providerItemCount": totals["items"],
            "providerSources": sources[:8]}


def collect(transport, *, retrieved_utc):
    """transport(path, params) -> JSON object; explicit full-pagination validation."""
    if type(retrieved_utc) is not str or not retrieved_utc.endswith("Z"):
        _fail("RETRIEVAL_CLOCK_UNVERIFIED")
    try:
        datetime.fromisoformat(retrieved_utc.replace("Z", "+00:00"))
    except (ValueError, OverflowError):
        _fail("RETRIEVAL_CLOCK_INVALID")
    # Read one authenticated item page first; this isolates item-key access from
    # a separately blocked public metadata endpoint without redundant probes.
    rows, seen_id, seen_slug = [], set(), set()
    counts = {}
    for category in CATEGORIES:
        offset, total = 0, None
        for _ in range(MAX_PAGES):
            page = transport("/items", {"category": category, "limit": PAGE_SIZE, "offset": offset})
            if type(page) is not dict or page.get("error") is True:
                _fail("ITEM_PAGE_INVALID")
            batch, page_total = page.get("items"), page.get("total")
            if (type(batch) is not list or type(page_total) is not int
                    or not 0 <= page_total <= 20000 or len(batch) > PAGE_SIZE
                    or (total is not None and page_total != total)):
                _fail("ITEM_PAGINATION_CONTRACT_CHANGED")
            total = page_total
            if (offset < total and not batch) or offset + len(batch) > total:
                _fail("ITEM_PAGE_MISSING_OR_OVERFLOW")
            count = page.get("count", len(batch))
            if type(count) is not int or count != len(batch):
                _fail("ITEM_PAGE_COUNT_MISMATCH")
            for original in batch:
                item = _item(original, category)
                if item is None:
                    continue
                if item["providerId"] in seen_id or item["providerSlug"] in seen_slug:
                    _fail("ITEM_DUPLICATE_ID_OR_SLUG")
                seen_id.add(item["providerId"])
                seen_slug.add(item["providerSlug"])
                rows.append(item)
            offset += len(batch)
            if offset == total:
                counts[category] = {
                    "returned": offset,
                    "weaponCandidates": sum(r["providerCategory"] == category for r in rows),
                }
                break
        else:
            _fail("ITEM_PAGINATION_LIMIT_EXCEEDED")
    meta = _meta(transport("/meta", {}))
    rows.sort(key=lambda r: (r["providerCategory"], r["providerId"]))
    digest = hashlib.sha256(json.dumps(rows, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    return {
        "schema": SCHEMA, "status": "FETCHED_RESEARCH_ONLY", "retrievedAtUtc": retrieved_utc,
        **meta, "categories": counts, "weaponCandidates": rows,
        "candidateRowsSha256": digest, "providerTimestampTimezoneVerified": False,
        "actualMM2RawIdentityMatched": False,
        "providerPriceSourceAdmissionComplete": False,
        "mayUseForLiveOffer": False, "authorizesTrade": False,
        "authorizesAccept": False, "mayReportProfit": False,
    }


class HTTPTransport:
    def __init__(self, key):
        if not _short(key, 512) or not key.startswith("rbx_"):
            _fail("API_KEY_MISSING_OR_INVALID_FORMAT")
        self.key, self.calls = key, 0

    def __call__(self, path, params):
        if path not in ("/meta", "/items"):
            _fail("UNEXPECTED_PROVIDER_ENDPOINT")
        if self.calls >= 60:
            _fail("REQUEST_BUDGET_EXCEEDED")
        if self.calls:
            time.sleep(2.2)
        self.calls += 1
        url = API_ROOT + path + ("?" + urlencode(params) if params else "")
        headers = {"Accept": "application/json"}
        # Provider documentation states /v2/meta is public; only item pages use the secret.
        if path == "/items":
            headers["X-Api-Key"] = self.key
        request = Request(url, headers=headers, method="GET")
        try:
            with urlopen(request, timeout=18) as response:
                if response.status != 200:
                    _fail("PROVIDER_HTTP_NOT_200")
                raw = response.read(3_000_001)
            if len(raw) > 3_000_000:
                _fail("PROVIDER_RESPONSE_TOO_LARGE")
            result = json.loads(raw, parse_float=Decimal)
            if type(result) is not dict:
                _fail("PROVIDER_RESPONSE_NOT_OBJECT")
            return result
        except HTTPError as exc:
            endpoint = "META" if path == "/meta" else "ITEMS"
            reason = {401: "AUTH_REJECTED", 403: "ACCESS_DENIED",
                      429: "RATE_LIMITED"}.get(exc.code, "HTTP_FAILURE")
            # Distinguish provider JSON denial from an upstream gateway challenge.
            # Never echo exception text, response body, URLs, or API credentials.
            if exc.code == 403:
                header = exc.headers or {}
                if str(header.get("cf-mitigated", "")).lower() == "challenge":
                    reason = "GATEWAY_CHALLENGE"
                elif "application/json" in str(header.get("content-type", "")).lower():
                    reason = "API_FORBIDDEN"
            _fail("PROVIDER_" + endpoint + "_" + reason)
        except (URLError, TimeoutError, OSError):
            _fail("PROVIDER_NETWORK_UNAVAILABLE")
        except (json.JSONDecodeError, UnicodeDecodeError, ValueError):
            _fail("PROVIDER_JSON_INVALID")


def main():
    from pathlib import Path
    output = os.environ.get("GINGERSCOPE_MARKET_OUTPUT")
    if not output or not output.startswith("/"):
        print("MARKET_FETCH_STATUS=INVALID_OUTPUT_PATH")
        return 2
    try:
        transport = HTTPTransport(os.environ.get("RBLXVALUE_API_KEY", ""))
        timestamp = datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
        record = collect(transport, retrieved_utc=timestamp)
        Path(output).write_text(json.dumps(record, sort_keys=True, indent=2) + "\n", encoding="utf-8")
        print("MARKET_FETCH_STATUS=FETCHED_RESEARCH_ONLY")
        print("MARKET_FETCH_WEAPON_CANDIDATES=" + str(len(record["weaponCandidates"])))
        print("MARKET_FETCH_SHA256=" + record["candidateRowsSha256"])
        print("LIVE_TRADING_AUTHORIZED=FALSE")
        return 0
    except DataFailure as exc:
        print("MARKET_FETCH_STATUS=BLOCKED")
        print("MARKET_FETCH_REASON=" + str(exc))
        return 2


if __name__ == "__main__":
    sys.exit(main())
