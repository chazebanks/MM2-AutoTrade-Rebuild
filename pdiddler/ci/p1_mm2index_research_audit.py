"""Offline MM2 Index schema/coverage auditor; never an authenticated Supreme quote.

Consumes a local caller-provided JSON document only (NO NETWORK).
CC BY attribution, a new fetch, and a "high" confidence label cannot prove
server-completed MM2 trades, unambiguous client weapon IDs, or live value authority.
"""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import json
import math
from pathlib import Path

from pdiddler.ci.p1_source_rights_gate import DENIED

SCHEMA = "gingerscope-p1-mm2index-independent-research-audit-v1"
SOURCE_URL = "https://mm2index.com/api/values.json"
LICENSE_URL = "https://creativecommons.org/licenses/by/4.0/"
MAX_RESEARCH_AGE_DAYS = 7  # Conservative offline research screen, NOT trading authorization.
CONFIDENCE = {"high", "medium", "low"}
TARGET_TIERS = {"Ancient", "Godly", "Chroma"}


class SourceAuditError(ValueError):
    pass


def _require(test, reason):
    if not test:
        raise SourceAuditError(reason)


def _when(value, reason):
    _require(type(value) is str, reason)
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except (ValueError, OverflowError) as exc:
        raise SourceAuditError(reason) from exc
    _require(parsed.tzinfo is not None and parsed.utcoffset() is not None, reason)
    return parsed.astimezone(timezone.utc)


def audit(payload, *, observed_utc):
    _require(type(payload) is dict, "DATASET_NOT_OBJECT")
    meta, items = payload.get("meta"), payload.get("items")
    _require(type(meta) is dict and type(items) is list, "META_ITEMS_SCHEMA_INVALID")
    _require(meta.get("source") == "MM2 Index", "PROVIDER_IDENTITY_MISMATCH")
    _require(meta.get("url") == "https://mm2index.com", "PROVIDER_ORIGIN_MISMATCH")
    _require(meta.get("game") == "Murder Mystery 2", "WRONG_GAME")
    _require(meta.get("unit") == "MM2 value units", "UNSUPPORTED_UNITS")
    license_text = meta.get("license")
    _require(type(license_text) is str and
             license_text.startswith("CC BY 4.0"), "LICENSE_MISSING_OR_DIFFERENT")
    _require(meta.get("method") == "https://mm2index.com/methodology", "METHOD_UNKNOWN")
    _require(type(meta.get("count")) is int and meta["count"] == len(items), "COUNT_MISMATCH")
    _require(type(meta.get("withheld")) is int and meta["withheld"] >= 0, "WITHHELD_COUNT_INVALID")
    _require(len(items) > 0, "EMPTY_DATASET")
    published = _when(meta.get("updated"), "PUBLISHER_CLOCK_INVALID")
    observed = _when(observed_utc, "OBSERVATION_CLOCK_INVALID")
    age_days = (observed - published).total_seconds() / 86400.0
    _require(age_days >= 0, "FUTURE_PUBLISHER_TIMESTAMP")
    known_keys, known_slugs = set(), set()
    tiers, confidences = Counter(), Counter()
    eligible_tiers, eligible_conf = Counter(), Counter()
    chroma_sets = 0
    gscope = None

    for idx, item in enumerate(items):
        _require(type(item) is dict, "ROW_NOT_OBJECT")
        key, slug, name, tier = (item.get(s) for s in ("key", "slug", "name", "tier"))
        _require(all(type(x) is str and x.strip() and len(x) <= 150
                     for x in (key, slug, name, tier)), "ITEM_IDENTITY_INVALID")
        _require(key not in known_keys and slug not in known_slugs,
                 "DUPLICATE_KEY_OR_SLUG")
        known_keys.add(key)
        known_slugs.add(slug)
        value = item.get("value")
        _require(type(value) in (int, float) and math.isfinite(value)
                 and value > 0, "VALUE_INVALID")
        confidence, count = item.get("confidence"), item.get("observations")
        _require(confidence in CONFIDENCE, "CONFIDENCE_INVALID")
        _require(type(count) is int and count >= 0, "OBSERVATION_COUNT_INVALID")
        _require(type(item.get("derivation")) is str and
                 bool(item["derivation"].strip()), "DERIVATION_MISSING")
        chroma, is_set = item.get("chroma"), item.get("set")
        _require(type(chroma) is bool and type(is_set) is bool, "CHROMA_SET_FLAGS_INVALID")
        _require((tier == "Chroma") == chroma, "CHROMA_TIER_CONFLICT")
        _require(tier != "Set" or is_set, "SET_TIER_CONFLICT")
        tiers[tier] += 1
        confidences[confidence] += 1
        if tier in TARGET_TIERS and not is_set:
            eligible_tiers[tier] += 1
            eligible_conf[confidence] += 1
        if tier == "Chroma" and is_set:
            chroma_sets += 1
        if key == "gingerscope":
            _require(tier == "Ancient" and not chroma and not is_set,
                     "TARGET_ITEM_IDENTITY_INCONCLUSIVE")
            gscope = {
                "providerKey": key,
                "providerValue": value,
                "confidenceLabel": confidence,
                "observationsFromPostsNotVerifiedFills": count,
                "method": item["derivation"],
                "gameRawWeaponKeyVerified": False,
            }

    _require(gscope is not None, "TARGET_NOT_PUBLISHED")
    eligible_n = sum(eligible_tiers.values())
    _require(eligible_n <= len(items), "INVALID_TIER_COUNTS")
    stale = age_days > MAX_RESEARCH_AGE_DAYS
    return {
        "schema": SCHEMA,
        "status": "BLOCKED_STALE_PROVIDER" if stale else "RESEARCH_ONLY_NOT_LIVE",
        "reason": "PROVIDER_SNAPSHOT_EXPIRED_FOR_RESEARCH" if stale
                  else "INDEPENDENT_RESEARCH_NOT_GAME_IDENTITY_OR_LIVE_QUOTE",
        "sourceUrl": SOURCE_URL,
        "providerName": "MM2 Index — NOT Supreme Values",
        "publisherUpdatedUtc": published.isoformat().replace("+00:00", "Z"),
        "observedAtUtc": observed.isoformat().replace("+00:00", "Z"),
        "ageDays": round(age_days, 4),
        "researchFreshnessThresholdDaysNotTradeApproval": MAX_RESEARCH_AGE_DAYS,
        "licenseDeclared": "CC BY 4.0",
        "attribution": "MM2 Index (https://mm2index.com), licensed under CC BY 4.0",
        "licenseUrl": LICENSE_URL,
        "datasetModified": False,
        "licenseGrantOwnershipIndependentlyVerified": False,
        "totalPublished": len(items),
        "totalWithheldUnknownTier": meta["withheld"],
        "totalUniverseAsProviderReports": len(items) + meta["withheld"],
        "tierCountsPublishedOnly": dict(sorted(tiers.items())),
        "confidenceCountsPublishedOnly": dict(sorted(confidences.items())),
        "individualTradableTierCountsPublishedOnly": {
            x: eligible_tiers[x] for x in sorted(TARGET_TIERS)},
        "individualTradableTierConfidenceCountsPublishedOnly": dict(sorted(eligible_conf.items())),
        "publishedChromaSetsExcludedFromIndividualWeapons": chroma_sets,
        "target": gscope,
        "providerOnlyMissingItemKeysUnavailable": True,
        "withheldTierBreakdownUnknown": True,
        "chromaAncientVersusGodlyRawIdentityUnknown": True,
        "observedTradesIndependentlyProvenSettled": False,
        "providerValuesComparableToSupremeWithoutCalibration": False,
        "mayAdvanceP2": False,
        "tradeOutcome": "UNKNOWN",
        **DENIED,
    }


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--input", type=Path, required=True)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args(argv)
    # No network access, collector import or secret handling in this module.
    obj = json.loads(args.input.read_text(encoding="utf-8"))
    now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    try:
        result = audit(obj, observed_utc=now)
        exit_code = 0
    except (SourceAuditError, TypeError, ValueError) as exc:
        result = {
            "schema": SCHEMA, "status": "BLOCKED_INVALID_SOURCE",
            "reason": exc.args[0] if isinstance(exc, SourceAuditError) else "INVALID_JSON_OR_SCHEMA",
            "tradeOutcome": "UNKNOWN", "mayAdvanceP2": False, **DENIED,
        }
        exit_code = 2
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("P1_MM2INDEX_AUDIT", result["status"], result["reason"], "market authority false")
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
