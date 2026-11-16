"""Immutable, HISTORICAL C9 Supreme/MM2 dual-list reconciliation.

Research only: official-origin Supreme is Firecrawl-mediated and unsigned;
MM2 listed values are via an aggregator, not a direct MM2Values publisher fetch.
This archive DOES NOT make the legacy Nov 15 data live/current or authorize
price-backed offers, final Accept, settlement claims, or strategy learning.
"""
from __future__ import annotations

import argparse
from datetime import timezone
import hashlib
import json
from pathlib import Path

from pdiddler.system2.c9_supreme_mediated_189_research_gate import (
    SupremeEvidenceBlocked, timeparse, validate,
)

SCHEMA = "gingerscope-c9-historical-dual-list-reconciliation-v1"
AGGREGATOR_GIT_BLOB = "89898dd4ec04f13ec9302ee505907e7fd65dafa2"
OFFICIAL_GIT_BLOB = "fad9ab01bbfe0131d15bf9ed0bf13cfe9eda0554"
AGGREGATOR_ROWS_SHA256 = "6540923609ddd6344306bb248861eddba7dd46cd00ba016f446eda3327f152ac"
HISTORICAL_REGISTRY_BLOB = "40e2a0ff01b70b2d0181c62cae347a08da82bcb8"
CENSUS = {"ancient": 15, "godly": 128, "chroma": 46}
EXPECTED_CONFLICT_COUNT = 34
MAX_AGE_SECONDS = 6 * 3600


class HistoricalReconciliationBlocked(ValueError):
    pass


def refuse(reason: str):
    raise HistoricalReconciliationBlocked(reason)


def git_blob_sha(source: bytes) -> str:
    if type(source) is not bytes:
        refuse("C9_ARCHIVE_SOURCE_BYTES_REQUIRED")
    return hashlib.sha1(b"blob " + str(len(source)).encode() + b"\0" + source).hexdigest()


def canonical(data) -> bytes:
    return json.dumps(data, sort_keys=True, separators=(",", ":"), ensure_ascii=True,
                      allow_nan=False).encode("utf-8")


def sha256(data) -> str:
    return hashlib.sha256(canonical(data)).hexdigest()


def checked_sources(original_bytes: bytes, supreme_bytes: bytes):
    if git_blob_sha(original_bytes) != AGGREGATOR_GIT_BLOB:
        refuse("C9_ARCHIVED_AGGREGATOR_GIT_BLOB_CHANGED")
    if git_blob_sha(supreme_bytes) != OFFICIAL_GIT_BLOB:
        refuse("C9_ARCHIVED_SUPREME_GIT_BLOB_CHANGED")
    try:
        original = json.loads(original_bytes)
        supreme = json.loads(supreme_bytes)
    except (UnicodeDecodeError, json.JSONDecodeError, TypeError):
        refuse("C9_ARCHIVED_JSON_INVALID")
    if not isinstance(original, dict) or not isinstance(supreme, dict):
        refuse("C9_ARCHIVED_SOURCE_SHAPE_INVALID")
    rows = original.get("items")
    if type(rows) is not list or len(rows) != 189 or (
        original.get("crosswalkRowsSha256") != AGGREGATOR_ROWS_SHA256 or
        sha256(rows) != AGGREGATOR_ROWS_SHA256 or
        original.get("historicalRegistryBlob") != HISTORICAL_REGISTRY_BLOB or
        original.get("categoryGameKeys") != CENSUS or
        original.get("researchOnly") is not True or
        original.get("authorizesTrade") is not False or
        original.get("authorizesAccept") is not False or
        original.get("mayUseForLiveOffer") is not False
    ):
        refuse("C9_ARCHIVED_AGGREGATOR_OR_REGISTRY_NOT_PINNED")
    if (supreme.get("officialPriceDisagreementCount") != EXPECTED_CONFLICT_COUNT or
        supreme.get("originalAggregatorRowsSha256") != AGGREGATOR_ROWS_SHA256):
        refuse("C9_ARCHIVED_SUPREME_HISTORICAL_MISMATCH_CHANGED")
    return original, supreme


def reconcile(original_bytes: bytes, supreme_bytes: bytes, *, evaluated_utc: str):
    """Reconcile archived sources at a historical test clock, NOT at wall-clock now."""
    original, supreme = checked_sources(original_bytes, supreme_bytes)
    try:
        validation = validate(supreme, original, evaluated_utc)
    except (SupremeEvidenceBlocked, ValueError, KeyError, TypeError) as exc:
        refuse("C9_ORIGINAL_SUPREME_GATE_BLOCKED:" + str(exc))
    if (validation.get("matchedHistoricalGameKeys") != 189 or
        validation.get("marketSupremePriceConflictCount") != EXPECTED_CONFLICT_COUNT or
        validation.get("safeForAutonomousTrade") is not False or
        validation.get("status") != "BLOCKED_UNTIL_DUAL_SOURCE_RESEARCH_RECONCILIATION"):
        refuse("C9_SOURCE_VALIDATION_NOT_HISTORICALLY_CONSISTENT")
    now = timeparse(evaluated_utc)
    mm2_time = timeparse(original.get("sourceRetrievedUtc"))
    supreme_time = timeparse(supreme.get("sourceCapturedUtc"))
    ages = ((now - mm2_time).total_seconds(), (now - supreme_time).total_seconds())
    if any(not 0 <= age <= MAX_AGE_SECONDS for age in ages):
        refuse("C9_ARCHIVE_ONE_SOURCE_EXPIRED_OR_FUTURE")
    by_key = {r["rawGameKeyCandidate"]: r for r in original["items"]}
    official = {r["rawGameKeyCandidate"]: r for r in supreme["rows"]}
    if (len(by_key) != len(official) or len(by_key) != 189 or
        set(by_key) != set(official)):
        refuse("C9_ARCHIVE_KEY_CENSUS_MISMATCH")
    output_rows = []
    for key in sorted(by_key):
        old, new = by_key[key], official[key]
        if (old["marketCategory"] != new["category"] or
            new["aggregatorSupremeListedAtCapture"] != old["supremeListed"] or
            old["outgoingGingerscopeProtected"] is not (key == "Gingerscope") or
            new["outgoingGingerscopeProtected"] is not (key == "Gingerscope") or
            old["exactGameInstanceProven"] is not False):
            refuse("C9_ARCHIVE_SOURCE_KEY_OR_TARGET_PROTECTION_CHANGED")
        output_rows.append({
            "rawGameKeyCandidate": key,
            "category": old["marketCategory"],
            "historicalGameRarity": old["gameRarity"],
            "historicalGameChroma": old["gameChroma"],
            "historicalGameItemType": old["gameItemType"],
            "aggregatorMarketSlug": old["marketSlug"],
            "mm2ListedViaAggregator": old["mm2Listed"],
            "aggregatorDemandOrdinal": old["demandOrdinal"],
            "aggregatorStabilityLabel": old["stabilityLabel"],
            "supremeOfficialOriginListedViaFirecrawl": new["officialSupremeListed"],
            "supremeOfficialItemId": new["officialItemId"],
            "supremeDemandOrdinal": new["officialDemand"],
            "supremeStabilityLabel": new["officialStability"],
            "legacyAggregatorSupremeColumnForAuditOnly": old["supremeListed"],
            "legacySupremeDisagreesWithOfficial": new["aggregatorSupremeColumnMismatch"],
            "explicitReviewedFlowerwoodAlias": new["explicitReviewedNameAlias"],
            "outgoingGingerscopeProtected": key == "Gingerscope",
            "rawGameItemInstanceAuthenticated": False,
            "measuredTradeLiquidity": False,
        })
    count = sum(x["legacySupremeDisagreesWithOfficial"] for x in output_rows)
    if count != EXPECTED_CONFLICT_COUNT or not next(
        x for x in output_rows if x["rawGameKeyCandidate"] == "Gingerscope"
    )["outgoingGingerscopeProtected"]:
        refuse("C9_ARCHIVED_RECONCILIATION_DISAGREEMENT_COUNT_CHANGED")
    return {
        "schema": SCHEMA,
        "status": "HISTORICAL_189_SUPREME_COLUMN_RECONCILED_RESEARCH_ONLY",
        "sourceEdition": "2026-11-15",
        "historicalEvaluationUtc": now.astimezone(timezone.utc).isoformat(),
        "officialSupremePublicationISO": supreme["sourceOfficialPublicationISO"],
        "mm2AggregatorCapturedUtc": mm2_time.astimezone(timezone.utc).isoformat(),
        "supremeOfficialOriginCapturedUtc": supreme_time.astimezone(timezone.utc).isoformat(),
        "mm2ListedProvenance": "MM2TradeHub aggregator attributed to MM2Values; NOT independently publisher-fetched",
        "supremeListedProvenance": "SupremeValues official-origin pages via Firecrawl; NOT publisher-signed or direct GitHub fetch",
        "originalHistoricalRegistryGitBlob": HISTORICAL_REGISTRY_BLOB,
        "immutableAggregatorGitBlob": AGGREGATOR_GIT_BLOB,
        "immutableSupremeReceiptGitBlob": OFFICIAL_GIT_BLOB,
        "originalAggregatorRowsSha256": AGGREGATOR_ROWS_SHA256,
        "reconciledRowsSha256": sha256(output_rows),
        "matchedHistoricalGameKeys": 189,
        "categories": CENSUS.copy(),
        "legacyAggregatorSupremeConflictsReplaced": count,
        "officialSupremeDemandSeparatedFromAggregatorDemand": True,
        "bothSourcesIndependentlyPublisherAuthenticated": False,
        "researchOnly": True,
        "currentMarketFreshnessProven": False,
        "safeForLivePricing": False,
        "safeForAutonomousTrade": False,
        "authorizesOffer": False,
        "authorizesAccept": False,
        "authorizesTrade": False,
        "mayUseForStrategyLearning": False,
        "mayReportProfit": False,
        "serverTradeSettlementVerified": False,
        "rows": output_rows,
    }


def verify_reconciled(archived, original_bytes: bytes, supreme_bytes: bytes):
    """Exact archive verification. NEVER promotes archival output to current."""
    if type(archived) is not dict or archived.get("schema") != SCHEMA or (
        archived.get("researchOnly") is not True or
        archived.get("safeForLivePricing") is not False or
        archived.get("authorizesTrade") is not False or
        archived.get("authorizesAccept") is not False or
        archived.get("authorizesOffer") is not False or
        archived.get("mayUseForStrategyLearning") is not False):
        refuse("C9_ARCHIVE_OUTPUT_UNSAFE_OR_INVALID")
    exact = reconcile(original_bytes, supreme_bytes,
                      evaluated_utc=archived.get("historicalEvaluationUtc"))
    if archived != exact:
        refuse("C9_ARCHIVE_OUTPUT_DATA_OR_PROVENANCE_TAMPERED")
    return {"status": "HISTORICAL_RECONCILIATION_AUDITED_NOT_LIVE",
            "matchedHistoricalGameKeys": 189,
            "legacyAggregatorSupremeConflictsReplaced": EXPECTED_CONFLICT_COUNT,
            "authorizesTrade": False, "safeForLivePricing": False}


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--original", type=Path, required=True)
    p.add_argument("--supreme", type=Path, required=True)
    p.add_argument("--evaluated-utc", required=True,
                   help="Historical verification clock; NEVER current snapshot authority")
    p.add_argument("--output", type=Path, required=True)
    args = p.parse_args(argv)
    try:
        report = reconcile(args.original.read_bytes(), args.supreme.read_bytes(),
                           evaluated_utc=args.evaluated_utc)
        args.output.write_text(json.dumps(report, sort_keys=True, indent=2) + "\n")
        verify_reconciled(report, args.original.read_bytes(), args.supreme.read_bytes())
        print("C9_HISTORICAL_DUAL_LIST_RECONCILIATION=PASS")
        print("C9_HISTORICAL_PRICES_CORRECTED=" +
              str(report["legacyAggregatorSupremeConflictsReplaced"]))
        print("C9_CURRENT_LIVE_PRICING_AUTHORIZED=FALSE")
        return 0
    except (HistoricalReconciliationBlocked, OSError, ValueError, TypeError) as exc:
        print("C9_HISTORICAL_DUAL_LIST_RECONCILIATION=BLOCKED")
        print("C9_REASON=" + str(exc))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
