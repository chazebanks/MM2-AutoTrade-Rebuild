#!/usr/bin/env python3
"""Stage69: read-only, fail-closed audit of three first-party Supreme pages.

This DOES NOT create or publish a pricing profile, alter trading, or authorize
current quotes. It compares the existing canonical 190-entry snapshot to
freshly observed original-page HTML and quarantines every discrepancy.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import time
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
PARSER = ROOT / "pdiddler/intelligence_lab/stage69_supreme_parser_reference.py"
SPEC = importlib.util.spec_from_file_location("stage69_original_supreme", PARSER)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("missing immutable historical source parser")
P = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(P)

PAGE_ORDER = ("ancient", "chroma", "godly")
SLUG = {"ancient": "ancients", "chroma": "chromas", "godly": "godlies"}
EXPECTED = {"ancient": 16, "chroma": 46, "godly": 128}
MAX_BYTES = 5 * 1024 * 1024
MAX_PUBLISHER_AGE = 72 * 3600  # Existing policy only; not silently extended.

def observation(status: str, reason: str) -> dict:
    return {
        "schema": "gingerscope-stage69-supreme-research-source-audit-v1",
        "status": status,
        "reason": reason,
        "researchOnly": True,
        "fullCatalogueCompletenessVerified": False,
        "rawWeaponToSupremeCheckerIdAuthenticated": False,
        "exactVariantIdentityAuthenticated": False,
        "publisherDateIndependentlyAuthenticated": False,
        "liveReady": False,
        "authorizesTrading": False,
        "authorizesAccept": False,
        "mayReportProfit": False,
        "mayUseForStrategyLearning": False,
        "mayPublishLiveSnapshot": False,
        "outgoingPaused": True,
        "sourceChecks": [],
        "changes": [],
        "unmappedSourceNames": [],
        "missingCanonicalNames": [],
    }

def utc_string(epoch: int) -> str:
    return datetime.fromtimestamp(epoch, timezone.utc).isoformat(
        timespec="seconds"
    ).replace("+00:00", "Z")

def load_official_pages_live():
    """Network use is limited to 3 fixed Supreme endpoints; no side effects."""
    results = {}
    for page in PAGE_ORDER:
        url = f"https://supremevalues.com/mm2/{SLUG[page]}"
        req = Request(url, headers={
            "User-Agent": "gingerscope-stage69-READ-ONLY-source-audit/1.0",
            "Cache-Control": "no-cache",
        })
        with urlopen(req, timeout=30) as response:
            if response.geturl().split("?")[0].rstrip("/") != url:
                raise ValueError(f"unexpected redirect for {page}")
            data = response.read(MAX_BYTES + 1)
        if len(data) > MAX_BYTES or not data:
            raise ValueError(f"source payload invalid for {page}")
        results[page] = (data, int(time.time()))
    return results

def load_supplied_pages(directory: Path):
    results = {}
    for page in PAGE_ORDER:
        file = directory / f"pdiddler-supreme-{SLUG[page]}.html"
        raw = file.read_bytes()
        if not raw or len(raw) > MAX_BYTES:
            raise ValueError(f"source payload invalid for {page}")
        results[page] = (raw, int(file.stat().st_mtime))
    return results

def audit(pages: object, old: object, *, now: int) -> dict:
    report = observation("SOURCE_INVALID", "UNVALIDATED")
    if not isinstance(pages, dict) or set(pages) != set(PAGE_ORDER):
        report["reason"] = "MISSING_OR_EXTRA_SOURCE_PAGES"
        return report
    if not isinstance(old, dict) or not isinstance(old.get("rows"), list):
        report["reason"] = "BASELINE_SNAPSHOT_INVALID"
        return report
    older = old["rows"]
    counts = Counter(r.get("page") for r in older if isinstance(r, dict))
    if dict(counts) != EXPECTED or len(older) != 190:
        report["reason"] = "BASELINE_COVERAGE_UNTRUSTED"
        return report
    baseline = {}
    for row in older:
        key = (row.get("page"), row.get("name", "").casefold())
        if (key in baseline or not isinstance(row.get("id"), str)
                or not row["id"].isdigit()
                or not isinstance(row.get("name"), str)
                or not row["name"]):
            report["reason"] = "DUPLICATE_OR_AMBIGUOUS_BASELINE"
            return report
        baseline[key] = row

    parsed, pub_dates = {}, set()
    for page in PAGE_ORDER:
        pair = pages[page]
        if (not isinstance(pair, tuple) or len(pair) != 2
                or type(pair[0]) is not bytes or type(pair[1]) is not int
                or not pair[0] or len(pair[0]) > MAX_BYTES
                or pair[1] > now or pair[1] < 0):
            report["reason"] = "SOURCE_BYTES_OR_OBSERVATION_CLOCK_INVALID"
            return report
        blob, observed = pair
        try:
            text = blob.decode("utf-8", errors="strict")
            rows, published = P.parse_page(text, page)
            publication = P.epoch(published)
        except (UnicodeError, ValueError, TypeError) as exc:
            report["reason"] = "STRUCTURED_SOURCE_PARSER_REJECTED"
            report["failedCategory"] = page
            report["parserErrorType"] = type(exc).__name__
            return report
        if publication > observed or publication < 0:
            report["reason"] = "PUBLISHER_DATE_AFTER_RETRIEVAL"
            return report
        pub_dates.add(published)
        parsed[page] = rows
        report["sourceChecks"].append({
            "category": page,
            "officialUrl": f"https://supremevalues.com/mm2/{SLUG[page]}",
            "rawSha256": hashlib.sha256(blob).hexdigest(),
            "retrievedAtUtc": utc_string(observed),
            "siteClaimedPublisherTimestampUtc": published,
            "sitePublisherAgeSeconds": now - publication,
            "sourceRows": len(rows),
            "expectedCanonicalRows": EXPECTED[page],
        })
    if len(pub_dates) != 1:
        report["reason"] = "CONFLICTING_PUBLISHER_TIMESTAMPS"
        return report

    report["claimedSitePublisherTimestampUtc"] = next(iter(pub_dates))
    # Site publisher time is only a FIRST-PARTY CLAIM until separately audited.
    if any(
        check["sitePublisherAgeSeconds"] > MAX_PUBLISHER_AGE
        for check in report["sourceChecks"]
    ):
        report["reason"] = "SITE_PUBLICATION_OLDER_THAN_EXISTING_72H_POLICY"
        return report

    seen = set()
    for page in PAGE_ORDER:
        for row in parsed[page]:
            key = (page, row["name"].casefold())
            seen.add(key)
            original = baseline.get(key)
            if original is None:
                report["unmappedSourceNames"].append({
                    "category": page, "name": row["name"],
                })
                continue
            for field in ("supremeValue", "demand", "stability"):
                if original.get(field) != row.get(field):
                    report["changes"].append({
                        "category": page,
                        "canonicalIdFromOldSnapshotNotReauthenticated": original["id"],
                        "canonicalName": original["name"],
                        "field": field,
                        "before": original.get(field),
                        "observed": row.get(field),
                    })
    for page, name in sorted(set(baseline) - seen):
        report["missingCanonicalNames"].append({
            "category": page, "name": baseline[(page, name)]["name"],
        })
    counts_current = {p: len(parsed[p]) for p in PAGE_ORDER}
    report["sourceCounts"] = counts_current
    report["comparedCanonicalEntries"] = len(seen & set(baseline))
    report["baselineEntries"] = len(baseline)

    if (counts_current != EXPECTED or report["unmappedSourceNames"]
            or report["missingCanonicalNames"]):
        report["status"] = "REVIEW_REQUIRED"
        report["reason"] = "SOURCE_INVENTORY_OR_MAPPING_DRIFT"
    elif report["changes"]:
        report["status"] = "REVIEW_REQUIRED"
        report["reason"] = "SOURCE_VALUES_OR_MARKET_METADATA_CHANGED"
    else:
        report["status"] = "MATCHES_OLD_SNAPSHOT_RESEARCH_ONLY"
        report["reason"] = "SOURCE_CLAIMS_MATCH_BUT_ITEM_ID_AND_TRADE_AUTHORITY_NOT_PROVEN"
    return report

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--baseline", type=Path, required=True)
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--fetch-live", action="store_true")
    src.add_argument("--source-dir", type=Path)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    report = observation("SOURCE_INVALID", "UNVALIDATED")
    try:
        old = json.loads(args.baseline.read_text(encoding="utf-8"))
        source = load_official_pages_live() if args.fetch_live else load_supplied_pages(args.source_dir)
        report = audit(source, old, now=int(time.time()))
    except Exception as exc:
        # Never print raw HTML, account details, response contents or secrets.
        report["reason"] = "SOURCE_FETCH_OR_BASELINE_READ_FAILED"
        report["exceptionType"] = type(exc).__name__
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True)+"\n", encoding="utf-8")
    print(json.dumps({
        "status": report["status"],
        "reason": report["reason"],
        "changes": len(report["changes"]),
        "missing": len(report["missingCanonicalNames"]),
        "new": len(report["unmappedSourceNames"]),
        "outgoingPaused": True,
        "output": str(args.output),
    }, sort_keys=True))
    if report["status"] == "SOURCE_INVALID":
        raise SystemExit(2)

if __name__ == "__main__":
    main()
