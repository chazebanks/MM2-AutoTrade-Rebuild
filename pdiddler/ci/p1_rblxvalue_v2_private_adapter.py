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
import subprocess
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
MAX_ERROR_BYTES = 4096
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

def _curl_get(path: str, api_key: str) -> tuple[int, bytes]:
    """Single authenticated HTTPS request via curl, no redirects or retries.

    curl config is supplied through stdin, not argv or disk. Never emit stderr,
    headers, response bodies, or credentials into CI logs.
    """
    if path not in ALLOWED_PATHS:
        raise ValueError("ENDPOINT_NOT_ALLOWED")
    if not isinstance(api_key, str) or not 12 <= len(api_key) <= 256:
        raise ValueError("PRIVATE_KEY_REQUIRED")
    if not api_key.isascii() or re.fullmatch(r"[A-Za-z0-9_-]{12,256}", api_key) is None:
        raise ValueError("PRIVATE_KEY_FORMAT_INVALID")
    config = (
        'url = "' + BASE + path + '"\\n'
        'request = "GET"\\n'
        'header = "Accept: application/json"\\n'
        'header = "X-Api-Key: ' + api_key + '"\\n'
        'silent\\n'
        'max-time = 8\\n'
    )
    try:
        completed = subprocess.run(
            ["curl", "--config", "-", "--proto", "=https",
             "--max-redirs", "0", "--max-time", "8",
             "--write-out", "\\n%{http_code}"],
            input=config.encode("ascii"), capture_output=True,
            timeout=12, check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return 599, b""
    if completed.returncode != 0:
        return 599, b""
    raw = completed.stdout
    # The last line is a fixed-format status code emitted by curl.
    if b"\\n" not in raw:
        return 599, b""
    body, code = raw.rsplit(b"\\n", 1)
    if len(code) != 3 or not code.isdigit():
        return 599, b""
    status = int(code)
    if len(body) > (MAX_ERROR_BYTES if status == 403 else MAX_BYTES):
        return (403 if status == 403 else 413), b""
    if status != 200 and status != 403:
        return status, b""
    return status, body

def _no_redirect_get(path: str, api_key: str) -> tuple[int, bytes]:
    """Single authenticated request, no redirects, retries, persistence or printing."""
    if path not in ALLOWED_PATHS:
        raise ValueError("ENDPOINT_NOT_ALLOWED")
    if not isinstance(api_key, str) or not 12 <= len(api_key) <= 256:
        raise ValueError("PRIVATE_KEY_REQUIRED")
    # urllib's HTTP header encoder can fail on invisible Unicode characters.
    # Never normalize, strip, echo or repair a supplied credential silently.
    if not api_key.isascii() or re.fullmatch(r"[A-Za-z0-9_-]{12,256}", api_key) is None:
        raise ValueError("PRIVATE_KEY_FORMAT_INVALID")
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
        # Only HTTP 403 gets a bounded, transient read. The classifier below
        # emits fixed labels, NEVER the error body, headers, URL or API key.
        if ex.code == 403:
            try:
                raw = ex.read(MAX_ERROR_BYTES + 1)
                return 403, raw if len(raw) <= MAX_ERROR_BYTES else b""
            except (OSError, ValueError, AttributeError):
                return 403, b""
            finally:
                ex.close()
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

def _safe_detail_claim(value):
    """Recognize exact, bounded HTTP 403 detail phrases without logging text.

    A detail can be emitted by a proxy instead of RBLXValue; each code
    describes a *claim*, NOT authenticated publisher evidence. Anything not
    explicitly recognized stays generic, including URLs, tokens and usernames.
    """
    if type(value) is not str or not 1 <= len(value) <= 512:
        return "HTTP_403_JSON_STRING_DETAIL_NO_MESSAGE"
    phrase = " ".join(value.casefold().split()).rstrip(".!")
    messages = {
        "invalid api key": "HTTP_403_DETAIL_KEY_INVALID_CLAIM",
        "api key invalid": "HTTP_403_DETAIL_KEY_INVALID_CLAIM",
        "api key is invalid": "HTTP_403_DETAIL_KEY_INVALID_CLAIM",
        "invalid or inactive api key": "HTTP_403_DETAIL_KEY_INVALID_OR_INACTIVE_CLAIM",
        "inactive api key": "HTTP_403_DETAIL_KEY_INACTIVE_CLAIM",
        "api key inactive": "HTTP_403_DETAIL_KEY_INACTIVE_CLAIM",
        "api key is inactive": "HTTP_403_DETAIL_KEY_INACTIVE_CLAIM",
        "expired api key": "HTTP_403_DETAIL_KEY_EXPIRED_CLAIM",
        "api key expired": "HTTP_403_DETAIL_KEY_EXPIRED_CLAIM",
        "api key has expired": "HTTP_403_DETAIL_KEY_EXPIRED_CLAIM",
        "suspended api key": "HTTP_403_DETAIL_KEY_SUSPENDED_CLAIM",
        "api key suspended": "HTTP_403_DETAIL_KEY_SUSPENDED_CLAIM",
        "api key is suspended": "HTTP_403_DETAIL_KEY_SUSPENDED_CLAIM",
        "api key revoked": "HTTP_403_DETAIL_KEY_REVOKED_CLAIM",
        "api key disabled": "HTTP_403_DETAIL_KEY_DISABLED_CLAIM",
        "missing api key": "HTTP_403_DETAIL_KEY_MISSING_CLAIM",
        "account banned": "HTTP_403_DETAIL_ACCOUNT_BANNED_CLAIM",
        "account is banned": "HTTP_403_DETAIL_ACCOUNT_BANNED_CLAIM",
        "account temporarily banned": "HTTP_403_DETAIL_ACCOUNT_BANNED_CLAIM",
        "account suspended": "HTTP_403_DETAIL_ACCOUNT_SUSPENDED_CLAIM",
        "account is suspended": "HTTP_403_DETAIL_ACCOUNT_SUSPENDED_CLAIM",
        "forbidden": "HTTP_403_DETAIL_ACCESS_DENIED_CLAIM",
        "access denied": "HTTP_403_DETAIL_ACCESS_DENIED_CLAIM",
    }
    return messages.get(phrase, "HTTP_403_JSON_STRING_DETAIL_NO_MESSAGE")


def _forbidden_reason(body):
    """Safely classify a 403 envelope; *not proof* of publisher identity.

    JSON can originate at an edge proxy too. Only fixed reason labels leave
    this function; received body content is never logged or cached.
    """
    if type(body) is not bytes or not body:
        return "HTTP_403_EMPTY_OR_UNAVAILABLE_BODY"
    if len(body) > MAX_ERROR_BYTES:
        return "HTTP_403_OVERSIZED_BODY"
    try:
        doc = json.loads(body.decode("utf-8"))
    except (UnicodeError, ValueError):
        return "HTTP_403_NON_JSON_POSSIBLE_EDGE_BLOCK"
    if type(doc) is not dict:
        return "HTTP_403_UNRECOGNIZED_JSON"
    msg = doc.get("message")
    # A 403 JSON object does not establish who generated it. Restrict shape
    # classification to fixed return codes: no keys, user data, response text
    # or arbitrary field names may enter an Actions log.
    if type(msg) is not str or not 1 <= len(msg) <= 512:
        if type(doc.get("error")) is str:
            return "HTTP_403_JSON_STRING_ERROR_NO_MESSAGE"
        if type(doc.get("detail")) is str:
            return _safe_detail_claim(doc["detail"])
        if type(doc.get("errors")) is list:
            return "HTTP_403_JSON_ERRORS_ARRAY_NO_MESSAGE"
        if type(doc.get("error")) is bool:
            return "HTTP_403_JSON_BOOLEAN_ERROR_NO_MESSAGE"
        if type(doc.get("code")) in (str, int):
            return "HTTP_403_JSON_CODE_NO_MESSAGE"
        return "HTTP_403_JSON_OTHER_FIELDS_NO_MESSAGE"
    message = msg.lower()
    if "not activated" in message or "not active" in message or "activate" in message:
        return "HTTP_403_JSON_KEY_ACTIVATION_CLAIM"
    if "expired" in message or "expiry" in message:
        return "HTTP_403_JSON_KEY_EXPIRED_CLAIM"
    if "suspended" in message or "revoked" in message:
        return "HTTP_403_JSON_KEY_SUSPENDED_CLAIM"
    if "invalid" in message or "incorrect" in message:
        return "HTTP_403_JSON_KEY_INVALID_CLAIM"
    if "forbidden" in message or "access denied" in message or "blocked" in message:
        return "HTTP_403_JSON_ACCESS_DENIED_CLAIM"
    return "HTTP_403_JSON_MESSAGE_UNCLASSIFIED"


def _decode_json(status, body):
    if type(status) is not int:
        return None, _denied("BLOCKED", "UNTRUSTED_HTTP_STATUS")
    if status == 403:
        return None, _denied("ACCESS_RESTRICTED", _forbidden_reason(body))
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
                       transport: Callable[[str, str], tuple[int, bytes]] = _curl_get):
    """Single one-shot metadata probe. Runs NOTHING unless *explicitly enabled*."""
    if enabled is not True:
        return _denied("DISABLED", "PRIVATE_PROBE_NOT_ARMED")
    if type(secret) is not str or not 12 <= len(secret) <= 256:
        return _denied("KEY_REQUIRED", "PRIVATE_ENVIRONMENT_KEY_MISSING")
    if not secret.isascii():
        return _denied("KEY_FORMAT_INVALID", "PRIVATE_KEY_NON_ASCII_CHARACTERS")
    if re.fullmatch(r"[A-Za-z0-9_-]{12,256}", secret) is None:
        return _denied("KEY_FORMAT_INVALID", "PRIVATE_KEY_FORMAT_UNEXPECTED_CHARACTERS")
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
