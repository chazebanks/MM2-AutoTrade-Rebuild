"""C9 candidate research source admission over GENUINE four-page HTML capture.

This checks a raw source against the original immutable Stage83 keys.
It is NOT a publisher signature, game identity proof, trading permission or
empirically demonstrated liquidity.
"""
from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

from pdiddler.system2 import public_market_gamekey_crosswalk as cw

SCHEMA = "gingerscope-c9-current-189-research-source-admission-v1"
SIX_HOURS_SECONDS = 21600
MAX_PAGE_FINGERPRINTS = 3


class SourceBlocked(ValueError):
    pass


def strict_utc(iso: str) -> datetime:
    if type(iso) is not str or not iso.endswith("Z"):
        raise SourceBlocked("C9_EXACT_UTC_Z_REQUIRED")
    try:
        instant = datetime.fromisoformat(iso.replace("Z", "+00:00"))
    except (TypeError, ValueError, OverflowError) as exc:
        raise SourceBlocked("C9_UTC_INVALID") from exc
    if instant.utcoffset().total_seconds() != 0 or instant.year < 2026:
        raise SourceBlocked("C9_UTC_INVALID")
    return instant


def admit(source: dict, registry_bytes: bytes, *,
          evaluated_utc: str, claimed_mapping: dict | None = None) -> dict:
    """Only returns research-only attestation; never returns a trade action."""
    now, at = strict_utc(evaluated_utc), strict_utc(
        source.get("retrievedUtc") if type(source) is dict else None)
    age = (now - at).total_seconds()
    if not (0 <= age <= SIX_HOURS_SECONDS):
        raise SourceBlocked("C9_REAL_SOURCE_AGE_EXPIRED_OR_FUTURE")
    try:
        verified = cw.crosswalk(
            source, registry_bytes, evaluated_utc=evaluated_utc)
    except (cw.MappingBlocked, ValueError, TypeError) as exc:
        raise SourceBlocked("C9_ORIGINAL_SOURCE_MAPPING_BLOCKED:" +
                            str(exc)) from exc
    if claimed_mapping is not None and verified != claimed_mapping:
        raise SourceBlocked("C9_CROSSWALK_NOT_EXACTLY_REPRODUCIBLE")
    if not isinstance(verified.get("sourcePageSha256"), dict) or (
        len(verified["sourcePageSha256"]) != MAX_PAGE_FINGERPRINTS
    ):
        raise SourceBlocked("C9_ALL_THREE_TIER_PAGES_REQUIRED")
    rows = verified["items"]
    if len(rows) != 189 or (
        {r["rawGameKeyCandidate"] for r in rows}
        != {r["rawGameKeyCandidate"] for r in verified["items"]}
    ):
        raise SourceBlocked("C9_EXACT_189_KEY_COVERAGE_REQUIRED")
    if len({r["rawGameKeyCandidate"] for r in rows}) != 189:
        raise SourceBlocked("C9_DUPLICATE_GAME_KEY")
    target = [r for r in rows if r["rawGameKeyCandidate"] == "Gingerscope"]
    if len(target) != 1 or target[0]["outgoingGingerscopeProtected"] is not True:
        raise SourceBlocked("C9_TARGET_NOT_IMMUTABLY_PROTECTED")
    source_hash = hashlib.sha256(
        json.dumps(source, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()
    return {
        "schema": SCHEMA,
        "status": "PUBLIC_C9_RESEARCH_SOURCE_ADMITTED_NOT_LIVE_AUTHORITY",
        "website": "https://mm2tradehub.com",
        "siteEditionDate": verified["marketEdition"],
        "sourceRetrievedUtc": verified["sourceRetrievedUtc"],
        "evaluatedUtc": evaluated_utc,
        "sourceAgeSeconds": int(age),
        "rawFourPageCandidateSha256": source_hash,
        "crosswalkRowsSha256": verified["crosswalkRowsSha256"],
        "historicalRegistryBlob": verified["historicalRegistryBlob"],
        "matchedHistoricalGameKeys": 189,
        "fourPageReadObserved": True,
        "tierSourcePageSha256": verified["sourcePageSha256"],
        "outgoingGingerscopeProtected": True,
        "researchOnly": True,
        "sourcePublisherSignatureVerified": False,
        "providerMarketDataNotIndependent": True,
        "rawGameItemInstanceIdentityVerified": False,
        "completedTradeOrRetradabilityProven": False,
        "ownerInventoryObserved": False,
        "liveRuntimeSnapshotAvailable": False,
        "sourceCanBeReusedAfterSixHours": False,
        "authorizesTrade": False,
        "authorizesOffer": False,
        "authorizesAccept": False,
        "mayUseForLiveOffer": False,
        "mayReportProfit": False,
        "mayUseForStrategyLearning": False,
    }


def main() -> int:
    import argparse
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--source", type=Path, required=True)
    p.add_argument("--registry", type=Path, required=True)
    p.add_argument("--crosswalk", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--evaluated-utc", required=True)
    args = p.parse_args()
    try:
        result = admit(
            json.loads(args.source.read_text(encoding="utf-8")),
            args.registry.read_bytes(),
            evaluated_utc=args.evaluated_utc,
            claimed_mapping=json.loads(args.crosswalk.read_text(encoding="utf-8")))
        args.output.write_text(
            json.dumps(result, sort_keys=True, indent=2) + "\n",
            encoding="utf-8")
        print("C9_PUBLIC_RESEARCH_SOURCE_STATUS=" + result["status"])
        print("C9_MARKET_EDITION=" + result["siteEditionDate"])
        print("C9_SOURCE_AGE_SECONDS=" + str(result["sourceAgeSeconds"]))
        print("C9_TARGET_OUTBOUND_AUTHORIZED=FALSE")
        print("C9_LIVE_TRADING_AUTHORIZED=FALSE")
        return 0
    except (SourceBlocked, OSError, ValueError, TypeError) as exc:
        print("C9_PUBLIC_RESEARCH_SOURCE_STATUS=BLOCKED")
        print("C9_SOURCE_REASON=" + str(exc))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
