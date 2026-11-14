"""System 2: source-publication + client-census revision synchronization (OFFLINE).

The existing SHA-pinned Nov13 operator export is a research source, NOT a
publisher-authenticated current quote. The scanner envelope, trade binding and
webpage publication observations are caller-supplied. No output can authorize
real Roblox actions; this gate only detects when a RESEARCH decision must be
invalidated. Never substitute page timestamps for Stage111 raw HTML archives.
"""
from __future__ import annotations

from datetime import datetime, timezone
import hashlib
import json
import re

from pdiddler.system2.operator_capture_adapter import (
    ingest, EXPORT_SHA256, AUTHORITY_DENIED,
)
from pdiddler.system2.client_inventory_shadow import (
    evaluate as shadow_inventory, _utc as parse_utc,
)
from pdiddler.system2.sealed_decision_source import (
    canonical_record_hash, EXPECTED_ROWS_SHA256,
)

SCHEMA = "gingerscope-system2-market-inventory-sync-research-v1"
OBSERVATION_KIND = "SYNTHETIC_PUBLICATION_OBSERVATION"
TRADE_KIND = "SYNTHETIC_UNVERIFIED_TRADE_BINDING"
CANONICAL = (
    "https://supremevalues.com/",
    "https://supremevalues.com/mm2/ancients",
    "https://supremevalues.com/mm2/chromas",
    "https://supremevalues.com/mm2/godlies",
)
MAX_PAGE_FETCH_AGE_SECONDS = 180
MAX_CAPTURE_RESEARCH_AGE_SECONDS = 86400
MAX_OFFER_BINDING_AGE_SECONDS = 60

def _result(status, reason, **data):
    return {
        "schema": SCHEMA, "status": status, "reason": reason,
        "clientEvidenceTrust": "CALLER_SUPPLIED_RESEARCH_ONLY",
        "publisherEditionAuthenticated": False,
        "publisherArchiveVerifiedForDecision": False,
        "currentGameInventoryProven": False,
        "activeTradeSessionProven": False,
        "currentOfferRevisionProven": False,
        "marketSourceUsableForLiveOffer": False,
        "mayUseForLiveStrategy": False,
        "liveSyncAuthenticated": False,
        "requiresIndependentNativeWitness": True,
        **data, **AUTHORITY_DENIED,
    }

def _sha(value):
    return hashlib.sha256(
        json.dumps(value, sort_keys=True, separators=(",", ":"),
                   ensure_ascii=False, allow_nan=False).encode("utf-8")
    ).hexdigest()

def _timestamp(value):
    return parse_utc(value)

def _utc_iso(value):
    return value.isoformat(timespec="milliseconds").replace("+00:00", "Z")

def _publication(pages, now):
    """Cross-check all four canonical webpage publication watermarks.

    Even all-four matching is OBSERVATION ONLY, not source cryptographic proof.
    """
    if type(pages) is not dict or set(pages) != {"kind", "pages"} or (
        pages["kind"] != OBSERVATION_KIND
        or type(pages["pages"]) is not list or len(pages["pages"]) != 4
    ):
        raise ValueError("FOUR_CANONICAL_PUBLICATION_PAGES_REQUIRED")
    observed = {}
    for row in pages["pages"]:
        if (type(row) is not dict or set(row) !=
                {"url", "publisherUpdatedAtUTC", "fetchedAtUTC"}
                or type(row["url"]) is not str
                or row["url"] not in CANONICAL
                or row["url"] in observed):
            raise ValueError("PAGE_URL_DUPLICATE_OR_UNEXPECTED")
        updated = _timestamp(row["publisherUpdatedAtUTC"])
        fetched = _timestamp(row["fetchedAtUTC"])
        if (updated > fetched or fetched > now or
                (now-fetched).total_seconds() > MAX_PAGE_FETCH_AGE_SECONDS):
            raise ValueError("PAGE_FETCH_FUTURE_STALE_OR_PUBLISHER_FUTURE")
        observed[row["url"]] = (updated, fetched)
    if set(observed) != set(CANONICAL):
        raise ValueError("CANONICAL_PUBLICATION_PAGE_COVERAGE_MISSING")
    published = {x[0] for x in observed.values()}
    if len(published) != 1:
        raise ValueError("PUBLISHER_PAGE_VERSION_DISAGREEMENT")
    fetched_times = [x[1] for x in observed.values()]
    if (max(fetched_times)-min(fetched_times)).total_seconds() > 60:
        raise ValueError("CANONICAL_PAGE_FETCHES_NOT_COHERENT")
    return next(iter(published))

def _trade_binding(binding, client_job, client_captured, now):
    if (type(binding) is not dict or set(binding) != {
        "kind", "jobId", "tradeLeaseId", "partnerUserId", "offerRevision",
        "offerObservedAtUTC", "tradeWindowOpen"
    } or binding["kind"] != TRADE_KIND):
        raise ValueError("RESEARCH_TRADE_BINDING_REQUIRED")
    if (type(binding["jobId"]) is not str or
        binding["jobId"] != client_job or
        type(binding["tradeLeaseId"]) is not str or
        not re.fullmatch(r"[A-Za-z0-9_-]{8,100}", binding["tradeLeaseId"])
        or type(binding["partnerUserId"]) is not int or
        binding["partnerUserId"] <= 0
        or type(binding["offerRevision"]) is not int or
        binding["offerRevision"] < 0
        or type(binding["tradeWindowOpen"]) is not bool):
        raise ValueError("TRADE_BINDING_ID_OR_REVISION_INVALID")
    seen = _timestamp(binding["offerObservedAtUTC"])
    if (seen > now or
        (now-seen).total_seconds() > MAX_OFFER_BINDING_AGE_SECONDS
        or seen < client_captured):
        raise ValueError("TRADE_BINDING_STALE_OR_BEFORE_OWN_CENSUS")
    if not binding["tradeWindowOpen"]:
        raise ValueError("TRADE_WINDOW_NOT_ACTIVE")
    return {
        "jobIdHash": hashlib.sha256(binding["jobId"].encode()).hexdigest(),
        "tradeLeaseHash": hashlib.sha256(binding["tradeLeaseId"].encode()).hexdigest(),
        "partnerUserIdHash": hashlib.sha256(str(binding["partnerUserId"]).encode()).hexdigest(),
        "offerRevision": binding["offerRevision"],
        "offerObservedAtUTC": _utc_iso(seen),
    }

def observe(*, export_bytes, stage83_lua_bytes, client_envelope,
            trade_binding, publication_pages, evaluated_at_utc):
    """Create a research-only snapshot, sealed against the exact existing export.

    Never makes its own passed metadata proof of current native/game provenance.
    Returns a limited stamp without any player details or full 189 price rows.
    """
    try:
        now = _timestamp(evaluated_at_utc)
        if type(export_bytes) is not bytes or type(stage83_lua_bytes) is not bytes:
            raise ValueError("ORIGINAL_SOURCE_BYTES_REQUIRED")
        source = ingest(export_bytes, stage83_lua_bytes)
        if (source.get("sourceExportSha256") != EXPORT_SHA256 or
            canonical_record_hash(source.get("records")) != EXPECTED_ROWS_SHA256):
            raise ValueError("PINNED_COMPLETE_189_ROWS_MISMATCH")
        publisher = _publication(publication_pages, now)
        exported = _timestamp(source["captureWindowUTC"]["exportedAt"])
        if exported > now:
            raise ValueError("SOURCE_EXPORT_FROM_FUTURE")
        if publisher > exported:
            raise ValueError("NEWER_PUBLISHER_PUBLICATION_REQUIRES_NEW_RAW_ARCHIVE")
        if (now-exported).total_seconds() > MAX_CAPTURE_RESEARCH_AGE_SECONDS:
            raise ValueError("SOURCE_EXPORT_RESEARCH_AGE_REQUIRES_REVIEW")
        shadow = shadow_inventory(
            source, client_envelope, evaluated_at_utc=evaluated_at_utc
        )
        if shadow.get("status") != "RESEARCH_CLIENT_INVENTORY_SHADOW_READY":
            raise ValueError(
                "SCANNER_SHADOW_INVALID:" + str(shadow.get("reason", "UNKNOWN"))[:120]
            )
        client_time = _timestamp(client_envelope["capturedAt"])
        binding = _trade_binding(
            trade_binding, client_envelope["jobId"], client_time, now
        )
        inv = client_envelope["inventory"]
        # Never include obsolete scanner value, old total or valueSource in
        # the semantic census. No stale October pricing is accepted.
        decisive_items = [
            {key: row[key] for key in ("id", "qty", "name", "page",
                                      "type", "identity")}
            for row in inv["items"]
        ]
        decisive_items.sort(key=lambda row: row["id"])
        census_sha = _sha({
            "items": decisive_items,
            "seen": sorted(inv["seen"]),
            "rawOwned": inv["rawOwned"],
            "unmapped": inv["unmapped"],
            "badQty": inv["badQty"],
        })
        stamp = {
            "marketExportSha256": EXPORT_SHA256,
            "mappedRowsSha256": EXPECTED_ROWS_SHA256,
            "publisherVisibleWatermarkUTC": _utc_iso(publisher),
            "researchExportedAtUTC": _utc_iso(exported),
            "inventoryCensusSha256": census_sha,
            "clientSnapshotAtUTC": _utc_iso(client_time),
            "evaluatedAtUTC": _utc_iso(now),
            **binding,
        }
        return _result(
            "RESEARCH_SNAPSHOT_ONLY",
            "PUBLISHER_VERSION_AND_NATIVE_SESSION_STILL_NOT_AUTHENTICATED",
            researchStamp=stamp,
        )
    except (ValueError, TypeError, KeyError, AttributeError, UnicodeError,
            OverflowError, json.JSONDecodeError) as error:
        return _result("BLOCKED", str(error)[:220])

def compare(previous, *, export_bytes, stage83_lua_bytes,
            client_envelope, trade_binding, publication_pages,
            evaluated_at_utc):
    """Re-evaluate everything; issue explicit invalidation for any revision.

    A caller-provided previous stamp cannot be an authentication authority.
    """
    if (type(previous) is not dict or
        previous.get("schema") != SCHEMA or
        previous.get("status") != "RESEARCH_SNAPSHOT_ONLY" or
        type(previous.get("researchStamp")) is not dict or
        any(previous.get(k) != v for k, v in AUTHORITY_DENIED.items())):
        return _result("BLOCKED", "PRIOR_RESEARCH_STAMP_UNTRUSTED")
    prev = previous["researchStamp"]
    if set(prev) != {
        "marketExportSha256", "mappedRowsSha256",
        "publisherVisibleWatermarkUTC", "researchExportedAtUTC",
        "inventoryCensusSha256", "clientSnapshotAtUTC",
        "evaluatedAtUTC", "jobIdHash", "tradeLeaseHash",
        "partnerUserIdHash", "offerRevision", "offerObservedAtUTC",
    }:
        return _result("BLOCKED", "PRIOR_RESEARCH_STAMP_SHAPE_INVALID")
    # The previous stamp is caller-supplied. Validate its timestamp before
    # consulting current inputs: a correctly shaped but impossible date must
    # fail closed, not raise an uncaught exception during comparison.
    try:
        previous_evaluated = _timestamp(prev["evaluatedAtUTC"])
    except (ValueError, TypeError, OverflowError):
        return _result("BLOCKED", "PRIOR_RESEARCH_STAMP_TIMESTAMP_INVALID",
                       researchDecisionReusable=False)
    current = observe(
        export_bytes=export_bytes, stage83_lua_bytes=stage83_lua_bytes,
        client_envelope=client_envelope, trade_binding=trade_binding,
        publication_pages=publication_pages, evaluated_at_utc=evaluated_at_utc,
    )
    if current["status"] != "RESEARCH_SNAPSHOT_ONLY":
        return _result(
            "INVALIDATED", "FRESH_RESEARCH_OBSERVATION_BLOCKED:" +
            current.get("reason", "UNKNOWN")[:150],
            researchDecisionReusable=False,
        )
    now_stamp = current["researchStamp"]
    if previous_evaluated > _timestamp(now_stamp["evaluatedAtUTC"]):
        return _result("INVALIDATED", "RESEARCH_CLOCK_ROLLBACK",
                       researchDecisionReusable=False)
    reasons = []
    for k in ("marketExportSha256", "mappedRowsSha256",
              "publisherVisibleWatermarkUTC", "researchExportedAtUTC"):
        if now_stamp[k] != prev[k]:
            reasons.append("PUBLISHER_OR_MARKET_SOURCE_CHANGED")
            break
    for k in ("jobIdHash", "tradeLeaseHash", "partnerUserIdHash"):
        if now_stamp[k] != prev[k]:
            reasons.append("SERVER_PARTNER_OR_TRADE_LEASE_CHANGED")
            break
    if now_stamp["offerRevision"] != prev["offerRevision"]:
        reasons.append("OFFER_REVISION_CHANGED")
    if now_stamp["inventoryCensusSha256"] != prev["inventoryCensusSha256"]:
        reasons.append("OWN_INVENTORY_CENSUS_CHANGED")
    # Same capture time with a new semantic census is especially suspicious.
    # It is already invalidated by the census comparison.
    if reasons:
        return _result(
            "INVALIDATED", "DEPENDENT_DECISION_INPUT_CHANGED",
            invalidationReasons=reasons,
            researchDecisionReusable=False,
        )
    return _result(
        "UNCHANGED_RESEARCH_ONLY",
        "CENSUS_AND_REVISIONS_MATCH_BUT_NATIVE_TRUST_NOT_PROVEN",
        researchDecisionReusableForSyntheticReplayOnly=True,
        researchDecisionReusable=False,
        publisherEditionAuthenticated=False,
        sourceExportSha256=EXPORT_SHA256,
        nextResearchStamp=now_stamp,
    )
