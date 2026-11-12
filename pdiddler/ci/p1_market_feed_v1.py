"""MarketFeedV1: OFFLINE-ONLY, strict, no-network candidate feed validator.

No credential, request, cache import, Lua action, price approval or Discord output.
Inputs are *caller supplied* and never authenticate a source or game raw key.
A hypothetical green result is a shadow research fixture, NOT a live price.
"""
from __future__ import annotations

from datetime import datetime, timezone
import hashlib
import json
import math
import re

from pdiddler.ci import p1_source_rights_gate as rights
from pdiddler.intelligence_lab import stage121_source_to_strategy_firewall as stage121

SCHEMA = "gingerscope-market-feed-v1"
MODES = {"SYNTHETIC_OFFLINE_ONLY", "EXTERNAL_UNTRUSTED"}
RARITIES = {"Ancient", "Godly"}
VARIANTS = {"Base", "Chroma"}
STAMP = re.compile(r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{1,6})?Z$")
ID = re.compile(r"^[A-Za-z0-9_:.\-]{1,96}$")
MAX_ITEMS = 5000
MAX_AGE_SECONDS = 7 * 86400  # Research screen only, NOT approved live TTL.
DEVIATION_LIMIT = 0.50  # Quarantine relative changes >50%; research heuristic.

class FeedError(ValueError):
    """A fixed, non-sensitive rejection reason."""
    def __init__(self, code):
        super().__init__(code)
        self.code = code

def require(ok, code):
    if not ok:
        raise FeedError(code)

def exact_fields(obj, fields, code):
    require(type(obj) is dict and set(obj) == set(fields), code)

def when(value, code):
    require(type(value) is str and STAMP.fullmatch(value) is not None, code)
    try:
        dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except (ValueError, OverflowError):
        raise FeedError(code) from None
    require(dt.utcoffset() is not None and dt.utcoffset().total_seconds() == 0, code)
    return dt.astimezone(timezone.utc)

def fixed_id(value, code, *, synthetic=False):
    require(type(value) is str and ID.fullmatch(value) is not None, code)
    if synthetic:
        require(value.startswith("TEST_"), "SYNTHETIC_IDENTITIES_MUST_BE_TEST_ONLY")
    return value

def denied(status, reason, *, count=0, mode=None, age_days=None, digest=None):
    """Only aggregate evidence; do not echo input source IDs, item labels or secrets."""
    return {
        "schema": "gingerscope-market-feed-v1-research-result",
        "status": status,
        "reason": reason,
        "observedItemCount": count,
        "sourcePublisherAgeDaysResearchOnly": age_days,
        "computedPayloadSha256NotAuthentication": digest,
        "mode": mode if mode in MODES else "INVALID",
        "sourceRightsAuthenticated": False,
        "gameRawItemIdentityAuthenticated": False,
        "confirmedMarketQuote": False,
        "currentTradeValueAuthorized": False,
        "sourceDataPermissionIndependentlyVerified": False,
        "readyForLivePlanner": False,
        "mayAdvanceP2": False,
        "tradeOutcome": "UNKNOWN",
        **rights.DENIED,
        **stage121.FALSE,
    }

def _evaluate(envelope, observed_utc):
    exact_fields(envelope,
                 ("schema", "mode", "httpStatus", "provider", "snapshot",
                  "coverage", "previous"), "INVALID_ENVELOPE_FIELDS")
    require(envelope["schema"] == SCHEMA, "INVALID_SCHEMA")
    mode = envelope["mode"]
    require(type(mode) is str and mode in MODES, "INVALID_MODE")
    synthetic = mode == "SYNTHETIC_OFFLINE_ONLY"
    status = envelope["httpStatus"]
    require(type(status) is int and 100 <= status <= 599, "INVALID_HTTP_STATUS")
    # The cache MUST NOT recover an unverified or unauthorized HTTP failure.
    if status == 401:
        return denied("KEY_REQUIRED", "HTTP_401_API_KEY_REQUIRED", mode=mode)
    if status == 403:
        return denied("LICENSE_BLOCKED", "HTTP_403_ACCESS_RESTRICTED", mode=mode)
    if status == 429:
        return denied("RATE_LIMITED", "HTTP_429_NO_FALLBACK", mode=mode)
    if status != 200:
        return denied("SOURCE_UNAVAILABLE", "HTTP_NOT_200", mode=mode)

    exact_fields(envelope["provider"],
                 ("name", "declaredRights", "upstreamProvenance",
                  "timestampMeaning", "identityEvidence"), "INVALID_PROVIDER_FIELDS")
    provider = envelope["provider"]
    fixed_id(provider["name"], "PROVIDER_NAME_INVALID", synthetic=synthetic)
    exact_fields(envelope["snapshot"],
                 ("version", "publishedAtUtc", "retrievedAtUtc", "expiresAtUtc",
                  "units", "items"), "INVALID_SNAPSHOT_FIELDS")
    snap = envelope["snapshot"]
    fixed_id(snap["version"], "SNAPSHOT_VERSION_INVALID", synthetic=synthetic)
    fixed_id(snap["units"], "PRICE_UNIT_INVALID", synthetic=synthetic)
    now = when(observed_utc, "OBSERVATION_CLOCK_INVALID")
    pub = when(snap["publishedAtUtc"], "PUBLISHER_CLOCK_INVALID")
    fetched = when(snap["retrievedAtUtc"], "RETRIEVAL_CLOCK_INVALID")
    expires = when(snap["expiresAtUtc"], "EXPIRY_CLOCK_INVALID")
    require(fetched <= now and pub <= fetched, "SOURCE_CLOCK_ORDER_INVALID")
    require(expires > pub, "EXPIRY_BEFORE_PUBLICATION")
    age = (now - pub).total_seconds()
    age_days = round(age / 86400, 4)
    # Do not let a provider/caller use its retrieval date as publication proof.
    candidate = {
        "provider": provider["name"],
        "declaredRights": provider["declaredRights"],
        "upstreamProvenance": provider["upstreamProvenance"],
        "timestampMeaning": provider["timestampMeaning"],
        "publisherUpdatedUtc": snap["publishedAtUtc"],
        "identityEvidence": provider["identityEvidence"],
    }
    try:
        screen = rights.screen_public_candidate(candidate, observed_utc=observed_utc)
    except ValueError:
        raise FeedError("RIGHTS_METADATA_INVALID") from None
    reasons = set(screen["blockers"])
    if reasons & {"PUBLISHER_RESTRICTS_REUSE", "REUSE_RIGHTS_NOT_DECLARED",
                  "UPSTREAM_DATA_REUSE_RIGHTS_NOT_PROVEN",
                  "SUPREME_DERIVED_SOURCE_REUSE_NOT_CLEARED",
                  "ORIGINAL_SOURCE_PROVENANCE_UNKNOWN"}:
        return denied("LICENSE_BLOCKED", "SOURCE_RIGHTS_OR_DERIVATION_NOT_CLEARED",
                      mode=mode, age_days=age_days)
    if ("PUBLISHER_CLOCK_NOT_PROVEN" in reasons or
        "FUTURE_PUBLISHER_TIME" in reasons or
        "RESEARCH_DATA_STALE" in reasons or
        age > MAX_AGE_SECONDS or now >= expires):
        return denied("STALE", "PUBLISHER_TIME_UNTRUSTED_OR_EXPIRED",
                      mode=mode, age_days=age_days)
    if reasons & {"ITEM_IDENTITY_COLLISION", "GAME_RAW_ITEM_IDENTITY_NOT_PROVEN"}:
        return denied("MAPPING_UNVERIFIED", "GAME_RAW_MAPPING_NOT_AUTHENTICATED",
                      mode=mode, age_days=age_days)
    require(not reasons, "UNHANDLED_RIGHTS_SCREEN_BLOCKER")
    require(type(snap["items"]) is list and 0 < len(snap["items"]) <= MAX_ITEMS,
            "ITEM_COUNT_INVALID")
    exact_fields(envelope["coverage"], ("expectedGameRawKeys",),
                 "INVALID_COVERAGE_FIELDS")
    expected = envelope["coverage"]["expectedGameRawKeys"]
    require(type(expected) is list and 0 < len(expected) <= MAX_ITEMS,
            "EXPECTED_KEYS_INVALID")
    expected_keys = [fixed_id(k, "EXPECTED_KEY_INVALID", synthetic=synthetic)
                     for k in expected]
    require(len(expected_keys) == len(set(expected_keys)),
            "DUPLICATE_EXPECTED_RAW_KEY")
    raw_keys, provider_keys, rows = set(), set(), {}
    for entry in snap["items"]:
        exact_fields(entry, ("providerKey", "gameRawKey", "rarity", "variant",
                             "year", "value", "publishedAtUtc"),
                     "INVALID_ITEM_FIELDS")
        key = fixed_id(entry["gameRawKey"], "GAME_RAW_KEY_INVALID", synthetic=synthetic)
        provider_key = fixed_id(entry["providerKey"], "PROVIDER_KEY_INVALID",
                                synthetic=synthetic)
        require(key not in raw_keys and provider_key not in provider_keys,
                "DUPLICATE_OR_VARIANT_MAPPING_COLLISION")
        raw_keys.add(key)
        provider_keys.add(provider_key)
        require(type(entry["rarity"]) is str and entry["rarity"] in RARITIES,
                "ITEM_CATEGORY_INVALID")
        require(type(entry["variant"]) is str and entry["variant"] in VARIANTS,
                "ITEM_VARIANT_INVALID")
        year = entry["year"]
        require(year is None or (type(year) is int and 2000 <= year <= 2100),
                "ITEM_YEAR_INVALID")
        value = entry["value"]
        require(type(value) in (float, int) and math.isfinite(value) and value > 0,
                "ITEM_VALUE_INVALID")
        row_pub = when(entry["publishedAtUtc"], "ITEM_PUBLISHER_CLOCK_INVALID")
        require(row_pub <= pub, "ITEM_NEWER_THAN_PUBLISHER_SNAPSHOT")
        require((now - row_pub).total_seconds() <= MAX_AGE_SECONDS,
                "ITEM_INDEPENDENT_UPDATE_STALE")
        rows[key] = float(value)
    if not set(expected_keys).issubset(raw_keys):
        return denied("INCOMPLETE", "MISSING_EXPECTED_ITEM_COVERAGE",
                      count=len(rows), mode=mode, age_days=age_days)
    # previous is a caller-supplied *comparison*, not proof of price truth.
    previous = envelope["previous"]
    if previous is not None:
        exact_fields(previous, ("provider", "units", "version",
                                "publishedAtUtc", "items"),
                     "INVALID_PREVIOUS_FIELDS")
        fixed_id(previous["provider"], "PREVIOUS_PROVIDER_INVALID", synthetic=synthetic)
        fixed_id(previous["units"], "PREVIOUS_UNITS_INVALID", synthetic=synthetic)
        require(previous["provider"] == provider["name"], "CROSS_PROVIDER_PRICE_COMPARISON")
        require(previous["units"] == snap["units"], "CROSS_UNIT_PRICE_COMPARISON")
        fixed_id(previous["version"], "PREVIOUS_VERSION_INVALID", synthetic=synthetic)
        before = when(previous["publishedAtUtc"], "PREVIOUS_PUBLISHER_CLOCK_INVALID")
        require(before < pub and previous["version"] != snap["version"],
                "PUBLISHER_ROLLBACK_OR_REPLAY")
        prior_items = previous["items"]
        require(type(prior_items) is list and len(prior_items) <= MAX_ITEMS,
                "PREVIOUS_ITEMS_INVALID")
        seen = set()
        for old in prior_items:
            exact_fields(old, ("gameRawKey", "value"), "INVALID_PREVIOUS_ITEM_FIELDS")
            key = fixed_id(old["gameRawKey"], "PREVIOUS_RAW_KEY_INVALID",
                           synthetic=synthetic)
            require(key not in seen, "PREVIOUS_DUPLICATE_RAW_KEY")
            seen.add(key)
            val = old["value"]
            require(type(val) in (float, int) and math.isfinite(val) and val > 0,
                    "PREVIOUS_PRICE_INVALID")
            if key in rows and abs(rows[key] - val) / val > DEVIATION_LIMIT:
                return denied("REVIEW_REQUIRED", "SUSPICIOUS_VALUE_SHIFT",
                              count=len(rows), mode=mode, age_days=age_days)
    payload_sha = hashlib.sha256(json.dumps(
        envelope, sort_keys=True, separators=(",", ":"), allow_nan=False
    ).encode("utf-8")).hexdigest()
    # The ONLY positive classification is for a synthetic offline fixture.
    return denied("SYNTHETIC_READY_FOR_SHADOW" if synthetic
                  else "LIVE_CANDIDATE_UNVERIFIED",
                  "OFFLINE_SHADOW_FIXTURE_ONLY" if synthetic
                  else "EXTERNAL_SOURCE_NOT_AUTHENTICATED_BY_CALLER_METADATA",
                  count=len(rows), mode=mode, age_days=age_days,
                  digest=payload_sha)

def validate_feed(envelope, *, observed_utc):
    """Safe total classifier; malformed/untrusted inputs never become prices.

    Emits no item-level value or user-provided text, so cannot be used as a
    relabeling/redistribution API. `SYNTHETIC_READY_FOR_SHADOW` != trade grant.
    """
    try:
        return _evaluate(envelope, observed_utc)
    except (FeedError, ValueError, TypeError, OverflowError) as exc:
        code = exc.code if isinstance(exc, FeedError) else "INPUT_PROCESSING_FAILED"
        mode = envelope.get("mode") if type(envelope) is dict else None
        return denied("BLOCKED", code, mode=mode)
