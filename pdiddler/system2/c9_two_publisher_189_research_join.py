"""C9 two-source 189-key research join, NEVER a trading/strategy execution authority.

MM2Values data: GitHub Actions DIRECT HTTPS official site, immutable run
43803829067 artifact 14197458080; SHA256 pin below. Supreme source: separate
four-page Firecrawl-mediated, unsigned official-origin receipt, Git blob pin
checked by the inherited PR309 gate. Both sources must independently pass
their clocks, payload identity, provenance, exactly 189 historical game keys,
and previously guarded Gingerscope outbound status.

This is a comparison, not a recommendation: numbers called demand or stability
are PUBLISHER DESCRIPTIONS, not measured liquidity/acceptance probabilities.
"""
from __future__ import annotations

import argparse
from datetime import timezone
from decimal import Decimal, InvalidOperation
import hashlib
import json
from pathlib import Path
import re
import sys

from pdiddler.system2.c9_mm2values_firstparty_189 import (
    MM2ValuesBlocked, PAGES as MM2_PAGES, SCHEMA as MM2_SCHEMA,
    rows_sha, validate_freshness, norm, MAX_CAPTURE_AGE,
)
from pdiddler.system2.c9_supreme_fresh_mediated_archive_gate import (
    C9SupremeRenewalBlocked, audit as audit_supreme, git_blob_sha,
    RENEWED_RECEIPT_BLOB, PRIOR_RECEIPT_BLOB, ORIGINAL_CROSSWALK_BLOB,
)
from pdiddler.system2.c9_supreme_mediated_189_research_gate import timeparse

SCHEMA = "gingerscope-c9-two-independent-publishers-189-source-join-v1"
MM2_SHA256 = "b69d3652c6db22f238fb9e0f60be16b244e7a223fda08f1f8d3f82235a863b38"
MM2_ROWS_SHA256 = "0e99859a2a187b8b9cfc4461cb993783912e6be6918aa9a71f5e76df7f940ffa"
MM2_SOURCE_CAPTURE = "2026-11-16T04:23:49Z"
MM2_PUBLISHER_ISSUE = "2026-11-13T12:19:30-05:00"
MM2_DIRECT_RUN = 43803829067
MM2_DIRECT_ARTIFACT = 14197458080
PINNED_MM2_AGGREGATE_CONFLICTS = 22
PINNED_SUPREME_AGGREGATE_CONFLICTS = 34
COUNT = {"ancient": 15, "godly": 128, "chroma": 46}
MAX_PUBLISHER_AGE = 4 * 86400
MAX_SOURCE_SKEW = 3600
ALIASES = {"FlowerwoodKnife": "Flowerwood"}
HEX64 = re.compile(r"^[0-9a-f]{64}$")
PRICE_CEILING = 10**10
SAFE_FALSE_FLAGS = (
    "authorizesTrade", "authorizesOffer", "authorizesAccept",
    "mayUseForStrategyLearning", "mayReportProfit",
)


class TwoPublisherBlocked(ValueError):
    pass


def deny(reason):
    raise TwoPublisherBlocked(reason)


def read_pinned(raw, digest, label):
    if type(raw) is not bytes or hashlib.sha256(raw).hexdigest() != digest:
        deny("C9_TWO_SOURCE_SHA256_PIN_FAILED_" + label)
    try:
        value = json.loads(raw)
    except (UnicodeError, ValueError, TypeError):
        deny("C9_TWO_SOURCE_JSON_PARSE_FAILED_" + label)
    if type(value) is not dict:
        deny("C9_TWO_SOURCE_DOCUMENT_NOT_OBJECT_" + label)
    return value


def utc_time(label):
    try:
        instant = timeparse(label)
    except (ValueError, TypeError, OverflowError):
        deny("C9_TWO_SOURCE_TIMESTAMP_INVALID")
    return instant.astimezone(timezone.utc)


def strict_age(now, captured, publisher, label):
    evaluation = utc_time(now)
    cap = utc_time(captured)
    edition = utc_time(publisher)
    capture_age = (evaluation-cap).total_seconds()
    edition_age = (cap-edition).total_seconds()
    if capture_age < 0:
        deny("C9_TWO_SOURCE_" + label + "_CAPTURE_FROM_FUTURE")
    if capture_age > MAX_CAPTURE_AGE:
        deny("C9_TWO_SOURCE_" + label + "_CAPTURE_EXPIRED")
    if edition_age < 0 or edition_age > MAX_PUBLISHER_AGE:
        deny("C9_TWO_SOURCE_" + label + "_PUBLISHER_EDITION_NOT_CURRENT")
    return {"sourceAgeSeconds": int(capture_age),
            "publisherAgeAtCaptureSeconds": int(edition_age)}


def negative_licenses(record, label):
    if type(record) is not dict or any(record.get(k) is not False for k in SAFE_FALSE_FLAGS):
        deny("C9_TWO_SOURCE_" + label + "_CLAIMED_TRADING_OR_LEARNING_AUTHORITY")


def map_exact(data, expected, *, kind):
    if type(data) is not list or len(data) != 189:
        deny("C9_TWO_SOURCE_" + kind + "_CENSUS_NOT_189")
    mapping, counts = {}, {k: 0 for k in COUNT}
    for row in data:
        if type(row) is not dict:
            deny("C9_TWO_SOURCE_" + kind + "_ROW_INVALID")
        key = row.get("rawGameKeyCandidate")
        cat = row.get("category") if kind != "REGISTRY" else row.get("marketCategory")
        if (type(key) is not str or not key.isascii() or
            not re.fullmatch(r"[A-Za-z0-9_]+", key) or key in mapping or
            cat not in COUNT):
            deny("C9_TWO_SOURCE_" + kind + "_DUPLICATE_KEY_OR_CATEGORY")
        if row.get("outgoingGingerscopeProtected") is not (key == "Gingerscope"):
            deny("C9_TWO_SOURCE_" + kind + "_GINGERSCOPE_GUARD_FAILED")
        mapping[key] = row
        counts[cat] += 1
    if counts != COUNT or (expected is not None and set(mapping) != expected):
        deny("C9_TWO_SOURCE_" + kind + "_RAW_KEY_COVERAGE_OR_CATEGORY_CHANGED")
    return mapping


def safe_ordinal(value, label):
    if type(value) is not str:
        deny("C9_TWO_SOURCE_" + label + "_ORDINAL_INVALID")
    try:
        dec = Decimal(value)
    except (InvalidOperation, ValueError, TypeError):
        deny("C9_TWO_SOURCE_" + label + "_ORDINAL_INVALID")
    if not dec.is_finite() or dec < 0 or dec > 11:
        deny("C9_TWO_SOURCE_" + label + "_ORDINAL_OUT_OF_BOUNDS")
    return value


def strictly_compare(mm2, supreme, crosswalk):
    """Internal pure crosswalk: user-visible prices remain unattributed as trades."""
    registry = map_exact(crosswalk["items"], None, kind="REGISTRY")
    mm2_rows = map_exact(mm2["rows"], set(registry), kind="MM2")
    supreme_rows = map_exact(supreme["rows"], set(registry), kind="SUPREME")
    mm2_diffs, supreme_diffs, compare = set(), set(), []
    for key in sorted(registry):
        original, m, s = registry[key], mm2_rows[key], supreme_rows[key]
        category = original["marketCategory"]
        if m["category"] != category or s["category"] != category:
            deny("C9_TWO_SOURCE_CROSS_CATEGORY_MATCH_" + key)
        if norm(m.get("firstPartyName")) != norm(original["marketName"]):
            deny("C9_TWO_SOURCE_MM2_PUBLIC_LABEL_MISMATCH_" + key)
        if norm(s.get("officialName")) != norm(ALIASES.get(key, original["marketName"])):
            deny("C9_TWO_SOURCE_SUPREME_PUBLIC_LABEL_MISMATCH_" + key)
        if (m.get("authenticatedRobloxItemInstance") is not False or
            m.get("measuredCounterpartyTradeFill") is not False or
            original.get("exactGameInstanceProven") is not False):
            deny("C9_TWO_SOURCE_UNVERIFIED_CLIENT_INSTANCE_PROMOTED_" + key)
        for value,label in (
            (m.get("mm2FirstPartyListed"),"MM2"), (s.get("officialSupremeListed"),"SUPREME")
        ):
            if type(value) is not int or value <= 0 or value >= PRICE_CEILING:
                deny("C9_TWO_SOURCE_" + label + "_LISTED_VALUE_INVALID_" + key)
        if (m.get("historicalAggregatorMM2ListedForAuditOnly") !=
            original["mm2Listed"] or
            s.get("aggregatorSupremeListedAtCapture") != original["supremeListed"]):
            deny("C9_TWO_SOURCE_AGGREGATOR_AUDIT_ROW_CHANGED_" + key)
        mm2_differ = m["mm2FirstPartyListed"] != original["mm2Listed"]
        supreme_differ = s["officialSupremeListed"] != original["supremeListed"]
        if supreme_differ is not s.get("aggregatorSupremeColumnMismatch"):
            deny("C9_TWO_SOURCE_SUPREME_CONFLICT_FLAG_FORGED_" + key)
        if mm2_differ: mm2_diffs.add(key)
        if supreme_differ: supreme_diffs.add(key)
        for field,value in (
            ("MM2_DEMAND",m.get("mm2DemandOrdinal")),
            ("MM2_RARITY",m.get("mm2RarityOrdinal")),
            ("SUPREME_DEMAND",s.get("officialDemand"))
        ): safe_ordinal(value,field)
        for stability in (m.get("mm2StabilityLabel"),s.get("officialStability")):
            if type(stability) is not str or not 1 <= len(stability) <= 80:
                deny("C9_TWO_SOURCE_STABILITY_LABEL_INVALID_" + key)
        if type(s.get("officialItemId")) is not str or not 1 <= len(s["officialItemId"]) <= 100:
            deny("C9_TWO_SOURCE_SUPREME_ID_INVALID_" + key)
        compare.append({
            "rawGameKeyCandidate": key,
            "historicalCategoryCandidate": category,
            "mm2Values": {
                "listed": m["mm2FirstPartyListed"], "demand": m["mm2DemandOrdinal"],
                "rarity": m["mm2RarityOrdinal"], "stability": m["mm2StabilityLabel"],
                "publicName": m["firstPartyName"], "rangeDescription": m["mm2RangeLabel"],
            },
            "supremeValues": {
                "listed": s["officialSupremeListed"], "demand": s["officialDemand"],
                "stability": s["officialStability"], "publicName": s["officialName"],
                "officialItemId": s["officialItemId"],
            },
            "publisherListedDifference": m["mm2FirstPartyListed"] - s["officialSupremeListed"],
            "oldAggregatorMM2ColumnMismatch": mm2_differ,
            "oldAggregatorSupremeColumnMismatch": supreme_differ,
            "outgoingGingerscopeProtected": key=="Gingerscope",
            "rawRobloxItemIdentityProven": False,
            "empiricalCounterpartyAcceptanceProbability": None,
            "empiricalRetradeLiquidity": "UNKNOWN",
        })
    if mm2_diffs != set(mm2["aggregatorMM2PriceDisagreementKeys"]):
        deny("C9_TWO_SOURCE_MM2_CONFLICT_LIST_FORGED")
    if supreme_diffs != set(supreme["officialPriceDisagreementGameKeys"]):
        deny("C9_TWO_SOURCE_SUPREME_CONFLICT_LIST_FORGED")
    if (len(mm2_diffs) != PINNED_MM2_AGGREGATE_CONFLICTS or
        len(supreme_diffs) != PINNED_SUPREME_AGGREGATE_CONFLICTS):
        deny("C9_TWO_SOURCE_LEGACY_AUDIT_CONFLICT_COUNT_CHANGED")
    return compare,mm2_diffs,supreme_diffs


def join(mm2_bytes, supreme_bytes, prior_bytes, registry_bytes, *, evaluated_utc):
    """Research-only join of REAL immutable Nov16 MM2 and Supreme source captures."""
    mm2 = read_pinned(mm2_bytes, MM2_SHA256, "MM2")
    if git_blob_sha(supreme_bytes) != RENEWED_RECEIPT_BLOB or (
        git_blob_sha(prior_bytes) != PRIOR_RECEIPT_BLOB or
        git_blob_sha(registry_bytes) != ORIGINAL_CROSSWALK_BLOB
    ):
        deny("C9_TWO_SOURCE_GIT_BLOB_PIN_FAILED")
    try:
        supreme=json.loads(supreme_bytes)
        crosswalk=json.loads(registry_bytes)
    except (UnicodeError, ValueError,TypeError):
        deny("C9_TWO_SOURCE_PINNED_SUPREME_OR_REGISTRY_INVALID")
    if (mm2.get("schema") != MM2_SCHEMA or
        mm2.get("status") != "FIRST_PARTY_MM2VALUES_189_RESEARCH_NOT_TRADABLE" or
        mm2.get("sourceSite") != "https://www.mm2values.com/" or
        mm2.get("pageURLs") != MM2_PAGES or
        mm2.get("sourceTransport") != "DIRECT_HTTPS_GITHUB_RESEARCH" or
        mm2.get("firstPartyDirectGithubFetchVerified") is not True or
        mm2.get("firstPartyPublisherSignatureVerified") is not False or
        mm2.get("publisherUpdatedAt") != MM2_PUBLISHER_ISSUE or
        mm2.get("sourceCapturedUtc") != MM2_SOURCE_CAPTURE or
        mm2.get("rowsSha256") != MM2_ROWS_SHA256 or
        mm2.get("matchedHistoricalGameKeys") != 189 or
        mm2.get("categoryGameKeys") != COUNT or
        mm2.get("excludedReviewedExtraAncients") != 1 or
        mm2.get("aggregatorMM2PriceConflicts") != PINNED_MM2_AGGREGATE_CONFLICTS or
        mm2.get("researchOnly") is not True or
        mm2.get("safeForLiveMarketQuotes") is not False or
        mm2.get("actualRobloxItemIdentityVerified") is not False or
        mm2.get("measuredRetradability") is not False or
        mm2.get("tradeCompletionProven") is not False
    ):
        deny("C9_TWO_SOURCE_MM2_CAPTURE_PROVENANCE_OR_SHAPE_INVALID")
    if rows_sha(mm2.get("rows")) != MM2_ROWS_SHA256:
        deny("C9_TWO_SOURCE_MM2_ROW_SHA_CHANGED")
    for v in mm2.get("pageHtmlSha256", {}).values():
        if type(v) is not str or not HEX64.fullmatch(v):
            deny("C9_TWO_SOURCE_MM2_PAGE_SHA_INVALID")
    if set(mm2.get("pageHtmlSha256",{})) != set(MM2_PAGES):
        deny("C9_TWO_SOURCE_MM2_FOUR_PAGE_SHA_REQUIRED")
    negative_licenses(mm2,"MM2")
    negative_licenses(supreme,"SUPREME")
    try:
        validated_mm2=validate_freshness(mm2,now_utc=evaluated_utc)
        validated_supreme=audit_supreme(
            supreme_bytes,prior_bytes,registry_bytes,at_utc=evaluated_utc)
    except (MM2ValuesBlocked,C9SupremeRenewalBlocked,ValueError,KeyError,TypeError) as exc:
        deny("C9_TWO_SOURCE_UPSTREAM_RESEARCH_GATE_BLOCKED:"+str(exc))
    mm2_age=strict_age(evaluated_utc,mm2["sourceCapturedUtc"],mm2["publisherUpdatedAt"],"MM2")
    supreme_age=strict_age(evaluated_utc,supreme["sourceCapturedUtc"],
                            supreme["sourceOfficialPublicationISO"],"SUPREME")
    diff=abs((utc_time(mm2["sourceCapturedUtc"]) - utc_time(supreme["sourceCapturedUtc"])).total_seconds())
    if diff>MAX_SOURCE_SKEW:
        deny("C9_TWO_SOURCE_CAPTURE_SKEW_TOO_HIGH")
    if validated_mm2["authorizesTrade"] is not False or (
        validated_supreme["currentMm2valuesIndependentSnapshotBound"] is not False):
        deny("C9_TWO_SOURCE_UNEXPECTED_UPSTREAM_AUTHORITY")
    compare, mm2_diffs, supreme_diffs = strictly_compare(mm2,supreme,crosswalk)
    overlap = mm2_diffs & supreme_diffs
    return {
        "schema": SCHEMA,
        "status": "TWO_PUBLISHER_189_READONLY_RESEARCH_JOINED_NOT_TRADE_READY",
        "evaluatedUtc": utc_time(evaluated_utc).isoformat(),
        "rawGameKeyCandidateCount": len(compare),
        "categoryCounts": COUNT.copy(),
        "sourceCaptureSkewSeconds": int(diff),
        "mm2Publisher": {
            "origin":"https://www.mm2values.com/","transport":"DIRECT_GITHUB_HTTPS",
            "publisherUpdatedAt":mm2["publisherUpdatedAt"],
            "capturedUtc":mm2["sourceCapturedUtc"],
            "ageSeconds":mm2_age["sourceAgeSeconds"],
            "receiptSha256":MM2_SHA256,"rowsSha256":MM2_ROWS_SHA256,
            "originVerifiedByPublisherSignature":False,
            "originalArtifactRun":MM2_DIRECT_RUN,
            "originalArtifactId":MM2_DIRECT_ARTIFACT,
        },
        "supremePublisher":{
            "origin":"https://supremevalues.com/","transport":"FIRECRAWL_MEDIATED_HTTPS",
            "publisherUpdatedAt":supreme["sourceOfficialPublicationISO"],
            "capturedUtc":supreme["sourceCapturedUtc"],
            "ageSeconds":supreme_age["sourceAgeSeconds"],
            "receiptGitBlob":RENEWED_RECEIPT_BLOB,
            "originVerifiedByPublisherSignature":False,
        },
        "mm2ComparedWithOldAggregatorConflictCount":len(mm2_diffs),
        "supremeComparedWithOldAggregatorConflictCount":len(supreme_diffs),
        "bothOldAggregatorColumnsChangedForSameKeys":len(overlap),
        "distinctOldAggregatorConflictKeys":len(mm2_diffs|supreme_diffs),
        "samePublisherValuesAcrossTwoSitesNotRequired":True,
        "sourceDemandIsNotEmpiricalLiquidity":True,
        "realTradeCompletionProven":False,
        "accountInventoryVerified":False,
        "actualRobloxItemIdentityVerified":False,
        "publisherCryptographicSignaturesVerified":False,
        "fourPhysicalTradeSlotsValidated":False,
        "autonomousStrategyRankingAuthorized":False,
        "safeForLiveMarketQuotes":False,
        "researchOnly":True,
        "authorizesTrade":False,"authorizesOffer":False,"authorizesAccept":False,
        "mayUseForStrategyLearning":False,"mayReportProfit":False,
        "rowsSha256": hashlib.sha256(json.dumps(compare,sort_keys=True,separators=(",",":"),ensure_ascii=True).encode()).hexdigest(),
        "rows":compare,
    }


def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--mm2",type=Path,required=True)
    p.add_argument("--supreme",type=Path,required=True)
    p.add_argument("--older-supreme",type=Path,required=True)
    p.add_argument("--crosswalk",type=Path,required=True)
    p.add_argument("--evaluated-utc",required=True)
    p.add_argument("--output",type=Path,required=True)
    x=p.parse_args(argv)
    try:
        r=join(x.mm2.read_bytes(),x.supreme.read_bytes(),
               x.older_supreme.read_bytes(),x.crosswalk.read_bytes(),
               evaluated_utc=x.evaluated_utc)
        x.output.write_text(json.dumps(r,sort_keys=True,indent=2)+"\n",encoding="utf-8")
        print("C9_TWO_SOURCE_JOIN="+r["status"])
        print("C9_TWO_SOURCE_KEYS="+str(r["rawGameKeyCandidateCount"]))
        print("C9_TWO_SOURCE_OLD_AGGREGATOR_OVERLAP="+str(r["bothOldAggregatorColumnsChangedForSameKeys"]))
        print("C9_AUTONOMOUS_TRADE_AUTHORIZED=FALSE")
        return 0
    except (TwoPublisherBlocked,ValueError,TypeError,OSError) as error:
        print("C9_TWO_SOURCE_JOIN=BLOCKED")
        print("C9_TWO_SOURCE_REASON="+str(error))
        return 2


if __name__=="__main__":
    sys.exit(main())
