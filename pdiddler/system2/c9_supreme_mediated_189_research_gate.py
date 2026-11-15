"""C9 strict research-only validator of Firecrawl-MEDIATED official-origin Supreme receipt.

This does NOT make Firecrawl a signed publisher or the website directly
accessible from GitHub Actions (the actual direct network attempt got HTTP 403).
It verifies original 189 game-key coverage, captured primary-source fields,
public-provenance labels, hard source TTL, zero trade authority, and conflicts.
"""
from __future__ import annotations

from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from pathlib import Path
import argparse
import json
import re
import sys

SCHEMA = "gingerscope-c9-supreme-firstparty-origin-189-mediated-receipt-v1"
ROWS = "gingerscope-system2-exact-market-gamekey-crosswalk-v1"
SOURCE = "https://supremevalues.com/"
MAX_AGE_SECONDS = 21600
PATHS = {
    "home": SOURCE, "ancient": SOURCE + "mm2/ancients",
    "godly": SOURCE + "mm2/godlies", "chroma": SOURCE + "mm2/chromas"
}
EXPECTED = {"ancient": 15, "godly": 128, "chroma": 46}
ALIASES = {"FlowerwoodKnife": "Flowerwood"}
UUID = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
KEY = re.compile(r"^[A-Za-z0-9_]+$")


class SupremeEvidenceBlocked(ValueError):
    pass


def deny(s):
    raise SupremeEvidenceBlocked(s)


def timeparse(iso):
    if type(iso) is not str:
        deny("C9_SUPREME_TIME_INVALID")
    try:
        when = datetime.fromisoformat(iso.replace("Z", "+00:00"))
    except (ValueError, OverflowError):
        deny("C9_SUPREME_TIME_INVALID")
    if when.tzinfo is None:
        deny("C9_SUPREME_TIME_HAS_NO_ZONE")
    return when


def norm(label):
    return re.sub(r"[^a-z0-9]", "", label.lower()) if type(label) is str else ""


def validate(snapshot: dict, original: dict, now_utc: str) -> dict:
    now = timeparse(now_utc)
    if type(snapshot) is not dict or snapshot.get("schema") != SCHEMA or (
        snapshot.get("status") != "OFFICIAL_ORIGIN_MEDIATED_RESEARCH_ONLY_NOT_SIGNED"
    ):
        deny("C9_UNREVIEWED_SUPREME_TRANSPORT")
    if type(original) is not dict or original.get("schema") != ROWS or (
        original.get("matchedHistoricalGameKeys") != 189
    ) or len(original.get("items", [])) != 189:
        deny("C9_SUPREME_ORIGINAL_GAME_REGISTRY_NOT_VERIFIED")
    for text, expected in (
        ("originalHistoricalRegistryBlob", original["historicalRegistryBlob"]),
        ("originalAggregatorRowsSha256", original["crosswalkRowsSha256"]),
        ("matchedHistoricalGameKeys", 189),
        ("all189OfficialPricesAndDemandParsed", True),
        ("officialPublisherSignatureVerified", False),
        ("directGitHubRunnerFirstPartyFetchSucceeded", False),
        ("researchOnly", True), ("autoTradeAuthorized", False),
        ("authorizesTrade", False), ("authorizesOffer", False),
        ("authorizesAccept", False), ("mayReportProfit", False),
        ("mayUseForStrategyLearning", False),
        ("rawWeaponInstanceIdentitiesVerified", False),
        ("serverTradeSettlementVerified", False),
    ):
        if snapshot.get(text) is not expected and snapshot.get(text) != expected:
            deny("C9_SUPREME_UNSAFE_PROVENANCE_FLAG_" + text)
    if snapshot.get("sourceHome") != SOURCE or (
        "Firecrawl official HTTPS rawHtml" not in
        str(snapshot.get("sourceAcquisitionMethod", ""))
    ):
        deny("C9_SUPREME_MEDIATED_ORIGIN_MISLABELED")
    pages = snapshot.get("pageEvidence")
    if type(pages) is not dict or set(pages) != set(PATHS):
        deny("C9_SUPREME_FOUR_FIRST_PARTY_PAGE_PROOFS_REQUIRED")
    for section, expected in PATHS.items():
        p = pages[section]
        if type(p) is not dict or p.get("url") not in (
            expected, expected.replace("https://supremevalues.com/", "https://www.supremevalues.com/")
        ) or type(p.get("statusCode")) is not int or p["statusCode"] != 200 or (
            not isinstance(p.get("scrapeId"), str) or not UUID.fullmatch(p["scrapeId"])
        ) or type(p.get("rawHtmlBytes")) is not int or not (
            500 < p["rawHtmlBytes"] < 2_000_000
        ):
            deny("C9_SUPREME_PAGE_ORIGIN_OR_CAPTURE_UNPROVEN_" + section)
    pub = timeparse(snapshot.get("sourceOfficialPublicationISO"))
    cap = timeparse(snapshot.get("sourceCapturedUtc"))
    if pub.utcoffset().total_seconds() not in (-18000, -14400):
        deny("C9_SUPREME_PUBLISHER_NY_ZONE_INVALID")
    if not 0 <= (cap - pub).total_seconds() <= 4 * 86400:
        deny("C9_SUPREME_OFFICIAL_PUBLICATION_FUTURE_OR_STALE")
    age = (now - cap).total_seconds()
    if not 0 <= age <= MAX_AGE_SECONDS:
        deny("C9_SUPREME_CAPTURE_EXPIRED_OR_FUTURE")
    if type(snapshot.get("rows")) is not list or len(snapshot["rows"]) != 189:
        deny("C9_SUPREME_189_ROW_CENSUS_INVALID")
    by_key = {r.get("rawGameKeyCandidate"): r for r in original["items"]}
    if len(by_key) != 189:
        deny("C9_ORIGINAL_KEY_DUPLICATED")
    seen,changes,counts,protected = set(), [], {k: 0 for k in EXPECTED}, []
    for row in snapshot["rows"]:
        if type(row) is not dict or type(row.get("rawGameKeyCandidate")) is not str or (
            not KEY.fullmatch(row["rawGameKeyCandidate"])
        ):
            deny("C9_SUPREME_ITEM_KEY_INVALID")
        key = row["rawGameKeyCandidate"]
        if key in seen or key not in by_key:
            deny("C9_SUPREME_ITEM_KEY_DUPLICATED_OR_UNREVIEWED")
        seen.add(key)
        original_row = by_key[key]
        category = original_row["marketCategory"]
        if row.get("category") != category:
            deny("C9_SUPREME_ITEM_CATEGORY_CHANGED")
        if norm(row.get("officialName")) != norm(
            ALIASES.get(key, original_row["marketName"])
        ):
            deny("C9_SUPREME_MANUAL_NAME_NOT_EXACT")
        if row.get("explicitReviewedNameAlias") is not (key in ALIASES):
            deny("C9_SUPREME_UNREVIEWED_NAME_ALIAS")
        if not isinstance(row.get("officialItemId"), str) or not (
            1 <= len(row["officialItemId"]) <= 100
        ):
            deny("C9_SUPREME_OFFICIAL_ITEM_ID_MISSING")
        value = row.get("officialSupremeListed")
        if type(value) is not int or not 0 < value < 10**10:
            deny("C9_SUPREME_PUBLISHED_VALUE_INVALID")
        if type(row.get("aggregatorSupremeListedAtCapture")) is not type(
            original_row["supremeListed"]
        ) or row.get("aggregatorSupremeListedAtCapture") != original_row["supremeListed"]:
            deny("C9_SUPREME_AGGREGATOR_SNAPSHOT_MUTATED")
        differing = value != original_row["supremeListed"]
        if row.get("aggregatorSupremeColumnMismatch") is not differing:
            deny("C9_SUPREME_FORGED_PRICE_MATCH")
        if differing:
            changes.append(key)
        try:
            demand = Decimal(row.get("officialDemand", ""))
        except (InvalidOperation, TypeError, ValueError):
            deny("C9_SUPREME_DEMAND_INVALID")
        if not demand.is_finite() or not 0 <= demand <= 11 or (
            not isinstance(row.get("officialStability"), str)
        ) or not 1 <= len(row["officialStability"]) <= 80:
            deny("C9_SUPREME_DEMAND_OR_STABILITY_INVALID")
        if row.get("outgoingGingerscopeProtected") is not (key == "Gingerscope"):
            deny("C9_SUPREME_GINGERSCOPE_PROTECTION_FAILED")
        if key == "Gingerscope":
            if value <= 0 or original_row.get("outgoingGingerscopeProtected") is not True:
                deny("C9_SUPREME_TARGET_NOT_PROTECTED")
            protected.append(key)
        counts[category] += 1
    if seen != set(by_key) or counts != EXPECTED or protected != ["Gingerscope"]:
        deny("C9_SUPREME_KEY_CATEGORY_COVERAGE_INCOMPLETE")
    if snapshot.get("categoryMatchedCounts") != counts or (
        snapshot.get("officialPriceDisagreementCount") != len(changes)
    ) or snapshot.get("officialPriceDisagreementGameKeys") != sorted(changes):
        deny("C9_SUPREME_DIFF_COUNTS_FORGED")
    return {
        "schema": "gingerscope-c9-supreme-origin-cross-source-validated-v1",
        "status": "BLOCKED_UNTIL_DUAL_SOURCE_RESEARCH_RECONCILIATION" if changes else
                  "PUBLIC_RESEARCH_ONLY_NO_TRADE_AUTHORITY",
        "sourceOfficialPublicationISO": pub.isoformat(),
        "sourceCapturedUtc": cap.astimezone(timezone.utc).isoformat(),
        "sourceAgeSeconds": int(age),
        "matchedHistoricalGameKeys": 189,
        "marketSupremePriceConflictCount": len(changes),
        "safeForAutonomousTrade": False,
        "safeToClaimOfficialPublisherSignature": False,
        "safeToUseUnmodifiedAggregateSupremeColumnForGrowthRanking": len(changes) == 0,
        "authorizesOffer": False,
        "authorizesAccept": False,
        "mayUseForStrategyLearning": False,
    }


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--snapshot", type=Path, required=True)
    p.add_argument("--original", type=Path, required=True)
    p.add_argument("--evaluated-utc", required=True)
    args = p.parse_args()
    try:
        report = validate(json.loads(args.snapshot.read_text()),
                          json.loads(args.original.read_text()),
                          args.evaluated_utc)
        print("C9_SUPREME_MEDIATED_RESEARCH_VALIDATED=TRUE")
        print("C9_SUPREME_PRICE_CONFLICTS=" +
              str(report["marketSupremePriceConflictCount"]))
        print("C9_GROWTH_RANKING_STATUS=" + report["status"])
        print("C9_TRADE_AUTHORITY=FALSE")
        return 0
    except (SupremeEvidenceBlocked, ValueError, OSError) as exc:
        print("C9_SUPREME_MEDIATED_RESEARCH_VALIDATED=FALSE")
        print("C9_SUPREME_REASON=" + str(exc))
        return 2


if __name__ == "__main__":
    sys.exit(main())
