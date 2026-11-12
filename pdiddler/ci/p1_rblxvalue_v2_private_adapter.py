"""RBLXValue v2 private RESEARCH probe, not a production market importer.

No HTTP at import or in CI; the only live endpoint exposed by CLI is /v2/meta.
This connector NEVER issues a verified quote, exposes a key or calls P3/P4.
Data include Supreme/MM2Values-derived values whose reuse has NOT been cleared.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import socket
import ssl
import urllib.error
import urllib.request
from datetime import datetime
from typing import Callable

from pdiddler.ci.p1_source_rights_gate import DENIED
from pdiddler.intelligence_lab.stage121_source_to_strategy_firewall import FALSE

BASE = "https://api.rblxvalue.com/v2"
ALLOWED_PATHS = {"/meta", "/items"}
MAX_BYTES = 512_000
ITEM_LIMIT = 100
MAX_TOTAL = 5000
REQUIRED_CREDIT = "Data from rblxvalue.com"
TIME_NAIVE = re.compile(r"^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$")
STATUS_MAP = {
    401: ("KEY_REQUIRED", "API_KEY_MISSING_OR_INVALID"),
    403: ("ACCESS_RESTRICTED", "API_KEY_NOT_ACTIVE_OR_RESTRICTED"),
    429: ("RATE_LIMITED", "API_LIMIT_REACHED_NO_RETRY"),
}

class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None

def _no_redirect_get(path: str, api_key: str) -> tuple[int, bytes]:
    """Single authenticated request, no redirects, retries, persistence or printing."""
    if path not in ALLOWED_PATHS:
        raise ValueError("ENDPOINT_NOT_ALLOWED")
    if not isinstance(api_key, str) or not 12 <= len(api_key) <= 256:
        raise ValueError("PRIVATE_KEY_REQUIRED")
    request = urllib.request.Request(
        BASE + path,
        headers={"X-Api-Key": api_key, "Accept": "application/json"},
        method="GET",
    )
    opener = urllib.request.build_opener(_NoRedirect())
    try:
        with opener.open(request, timeout=8) as response:
            status = response.getcode()
            raw = response.read(MAX_BYTES + 1)
        if len(raw) > MAX_BYTES:
            return 413, b""
        return status, raw
    except urllib.error.HTTPError as ex:
        # Do not inspect, print or store response bodies and/or secrets.
        return ex.code, b""
    except urllib.error.URLError as ex:
        # Error *types* only; never serialize exception messages, URLs,
        # response bodies or credential-bearing diagnostic strings.
        if isinstance(ex.reason, socket.gaierror):
            return 590, b""
        if isinstance(ex.reason, ssl.SSLError):
            return 591, b""
        if isinstance(ex.reason, (socket.timeout, TimeoutError)):
            return 593, b""
        return 599, b""
    except ssl.SSLError:
        return 591, b""
    except (socket.timeout, TimeoutError):
        return 593, b""
    except OSError:
        return 599, b""

def _denied(status: str, reason: str, **safe_fields):
    # Never serialize API keys, raw items, original IDs or full data bodies.
    return {
        "schema": "gingerscope-p1-rblxvalue-v2-private-probe-v1",
        "status": status, "reason": reason, **safe_fields,
        "providerApiContacted": False,
        "datasetAuthorshipProven": False,
        "sourcePublishTimeAuthenticated": False,
        "upstreamRightsApproved": False,
        "gameRawKeyMappingProven": False,
        "marketFeedReadyForProduction": False,
        "confirmedMarketQuote": False,
        "tradeOutcome": "UNKNOWN",
        **DENIED, **FALSE,
    }

def _valid_naive_clock(value):
    if not isinstance(value, str) or TIME_NAIVE.fullmatch(value) is None:
        return False
    try:
        datetime.strptime(value, "%Y-%m-%d %H:%M:%S")
        return True
    except ValueError:
        return False

def _decode_json(status, body):
    if type(status) is not int:
        return None, _denied("BLOCKED", "UNTRUSTED_HTTP_STATUS")
    if status in STATUS_MAP:
        a, b = STATUS_MAP[status]
        return None, _denied(a, b)
    # Fixed status codes are safe to report. We cannot diagnose the previous
    # SOURCE_UNAVAILABLE without distinguishing a 404/5xx from DNS/TLS failure.
    # Never include response bodies or error exception strings in output.
    network_failure = {
        590: "NETWORK_DNS_FAILURE",
        591: "NETWORK_TLS_FAILURE",
        593: "NETWORK_TIMEOUT",
        599: "NETWORK_OR_PROXY_FAILURE",
    }
    if status in network_failure:
        return None, _denied("SOURCE_UNAVAILABLE", network_failure[status])
    if status in (301, 302, 303, 307, 308):
        return None, _denied("SOURCE_UNAVAILABLE", "HTTP_REDIRECT_NOT_FOLLOWED")
    if 400 <= status <= 598:
        return None, _denied("SOURCE_UNAVAILABLE", "HTTP_STATUS_" + str(status))
    if status != 200:
        return None, _denied("SOURCE_UNAVAILABLE", "UNEXPECTED_HTTP_STATUS")
    if type(body) is not bytes or not 1 <= len(body) <= MAX_BYTES:
        return None, _denied("BLOCKED", "INVALID_API_PAYLOAD_SIZE")
    try:
        doc = json.loads(body.decode("utf-8"))
    except (ValueError, UnicodeError):
        return None, _denied("BLOCKED", "INVALID_API_JSON")
    if type(doc) is not dict or doc.get("error") is True:
        return None, _denied("BLOCKED", "API_ERROR_OR_NON_OBJECT")
    return doc, None

def classify_meta(status: int, body: bytes):
    doc, failure = _decode_json(status, body)
    if failure is not None:
        return failure
    try:
        totals = doc["totals"]
        last_run = doc["last_run"]
        last_updated = doc["last_updated"]
        sources = doc["sources"]
        interval = doc["update_interval_hours"]
        if (type(totals) is not dict or type(last_run) is not dict or
            type(totals.get("items")) is not int or
            not 0 < totals["items"] <= MAX_TOTAL or
            type(interval) not in (int, float) or not 0 < interval <= 168 or
            type(sources) is not list or
            not all(type(s) is str for s in sources) or
            type(doc.get("credit")) not in (str, type(None))):
            raise ValueError
    except (KeyError, ValueError, TypeError):
        return _denied("BLOCKED", "INVALID_META_CONTRACT")
    # The documented format has no offset and /items says UTC+2.
    # Do NOT infer UTC or treat it as the underlying publishers' timestamps.
    naive = _valid_naive_clock(last_updated)
    if not naive or not _valid_naive_clock(last_run.get("run_time")):
        return _denied("BLOCKED", "META_CLOCK_NOT_VERIFIABLE")
    recognized = set(sources)
    if recognized != {"mm2values", "supremevalues"}:
        return _denied("BLOCKED", "UNEXPECTED_UPSTREAM_SOURCE_SET")
    return _denied(
        "RESEARCH_META_ONLY", "AGGREGATOR_CLOCK_WITHOUT_TZ_OR_UPSTREAM_PROOF",
        datasetItemsReported=totals["items"],
        aggregatorRefreshHours=interval,
        aggregatorClockTimeZone="UNSPECIFIED",
        aggregatorLastUpdatedUnzoned=last_updated,
        aggregatorLastRunUnzoned=last_run["run_time"],
        knownSupremeDerivedData=True,
        creditRequired=doc["credit"] is not None,
    )

def classify_item_page(status: int, body: bytes, *, requested_limit=ITEM_LIMIT, requested_offset=0):
    """Check official v2 page shape; intentionally never return raw values."""
    doc, failure = _decode_json(status, body)
    if failure is not None:
        return failure
    if (type(requested_limit) is not int or not 1 <= requested_limit <= ITEM_LIMIT or
        type(requested_offset) is not int or requested_offset < 0):
        return _denied("BLOCKED", "REQUEST_PAGINATION_INVALID")
    total, limit, offset, count = (
        doc.get("total"), doc.get("limit"), doc.get("offset"), doc.get("count"))
    rows = doc.get("items")
    if not (type(total) is int and 0 <= total <= MAX_TOTAL and
            type(limit) is int and limit == requested_limit and
            type(offset) is int and offset == requested_offset and
            type(count) is int and
            type(rows) is list and 0 <= count == len(rows) <= requested_limit and
            offset + count <= total):
        return _denied("BLOCKED", "INVALID_PAGE_COUNT_OR_OFFSET")
    if count == 0 and offset < total:
        return _denied("BLOCKED", "MISSING_PAGE_ROWS")
    categories = {
        "ancient", "godly", "chroma", "legendary", "vintage", "rare",
        "uncommon", "common", "pets", "misc", "unique",
    }
    ids, slugs = set(), set()
    naive_clocks = 0
    for item in rows:
        if type(item) is not dict:
            return _denied("BLOCKED", "INVALID_ITEM_ROW")
        item_id = item.get("id")
        slug = item.get("slug")
        category = item.get("category")
        if (type(item_id) is not int or item_id <= 0 or
            type(slug) is not str or not re.fullmatch(r"[a-z0-9-]{1,96}", slug) or
            type(category) is not str or category not in categories):
            return _denied("BLOCKED", "INVALID_ITEM_IDENTITY_FIELDS")
        if item_id in ids or slug in slugs:
            return _denied("BLOCKED", "DUPLICATE_ITEM_OR_ALIAS_COLLISION")
        ids.add(item_id)
        slugs.add(slug)
        value = item.get("value")
        # no float precision games, NaN/Infinity, absent values or bool
        if type(value) is not int or value < 0 or value > 1_000_000_000:
            return _denied("BLOCKED", "INVALID_PUBLISHED_PRICE")
        for field in ("value_source_a", "value_source_b"):
            source_value = item.get(field)
            if source_value is not None and (
                type(source_value) is not int or
                not 0 <= source_value <= 1_000_000_000
            ):
                return _denied("BLOCKED", "INVALID_UPSTREAM_SOURCE_VALUE")
        clock = item.get("last_updated")
        if not _valid_naive_clock(clock):
            return _denied("BLOCKED", "ITEM_CLOCK_UNVERIFIED")
        naive_clocks += 1
        demand = item.get("demand")
        if demand is not None and (type(demand) is not int or not 0 <= demand <= 10):
            return _denied("BLOCKED", "INVALID_DEMAND")
    return _denied(
        "RESEARCH_ITEM_PAGE_ONLY", "UNLICENSED_SOURCE_AND_UNMAPPED_GAME_KEYS",
        pageItems=count, totalProviderItems=total, itemClockTimeZone="UNSPECIFIED",
        naiveItemClocks=naive_clocks, sourceDerivedFromSupreme=True,
        rawGameWeaponKeysPresent=False, itemPricesReturned=False,
        hasAnotherPage=offset + count < total,
    )

def probe_private_meta(*, enabled: bool, secret: str | None,
                       transport: Callable[[str, str], tuple[int, bytes]] = _no_redirect_get):
    """Single one-shot metadata probe. Runs NOTHING unless *explicitly enabled*."""
    if enabled is not True:
        return _denied("DISABLED", "PRIVATE_PROBE_NOT_ARMED")
    if type(secret) is not str or not 12 <= len(secret) <= 256:
        return _denied("KEY_REQUIRED", "PRIVATE_ENVIRONMENT_KEY_MISSING")
    # Distinguish an unexpected transport bug from an unexpected metadata
    # parser bug. Do not emit exception messages, tracebacks or request URLs.
    # These fixed categories cannot leak the X-Api-Key or private proxy values.
    def error_class(exc):
        if isinstance(exc, (TypeError, ValueError, AttributeError, KeyError)):
            return type(exc).__name__.upper()
        if isinstance(exc, ssl.SSLError):
            return "TLS"
        if isinstance(exc, (OSError, TimeoutError)):
            return "OS_OR_NETWORK"
        return "UNCLASSIFIED"
    try:
        status, body = transport("/meta", secret)
    except Exception as exc:
        return _denied("SOURCE_UNAVAILABLE",
                       "TRANSPORT_EXCEPTION_" + error_class(exc))
    try:
        result = classify_meta(status, body)
        # This flag means only that the single API request was attempted.
        result["providerApiContacted"] = True
        return result
    except Exception as exc:
        return _denied("BLOCKED",
                       "PARSER_EXCEPTION_" + error_class(exc))

def main(argv=None):
    parser = argparse.ArgumentParser(description="One-shot private RBLXValue metadata research probe")
    parser.add_argument("--probe-meta", action="store_true",
                        help="Explicit opt-in, requires separate environment switch and key")
    args = parser.parse_args(argv)
    enabled = args.probe_meta and os.environ.get("P1_PRIVATE_METADATA_PROBE") == "YES"
    secret = os.environ.get("RBLXVALUE_API_KEY") if enabled else None
    result = probe_private_meta(enabled=enabled, secret=secret)
    # All replies have no item values, raw item identities, or key/token material.
    print(json.dumps(result, sort_keys=True))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
