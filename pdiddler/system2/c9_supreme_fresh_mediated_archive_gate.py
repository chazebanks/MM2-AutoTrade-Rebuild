"""C9 renewed official-origin Supreme four-page research receipt admission.

The Nov16 Firecrawl rawHtml capture was directly matched to all 189 published
card name/ID/value/demand/stability fields. This code validates its immutable
public research receipt, the original 189 key registry, and the older edition.
It is NOT a producer of private game item identity, a publisher-signed feed,
a continuous refresh service, or trade/settlement authorization.
"""
from __future__ import annotations

import argparse
from datetime import timezone
import hashlib
import json
from pathlib import Path
import sys

from pdiddler.system2.c9_supreme_mediated_189_research_gate import (
    SupremeEvidenceBlocked,
    timeparse,
    validate,
)

SCHEMA = "gingerscope-c9-supreme-fresh-mediated-source-archive-audit-v1"
RENEWED_RECEIPT_BLOB = "b5afb393fc6646e02e19af899b8f066dd2df5708"
PRIOR_RECEIPT_BLOB = "fad9ab01bbfe0131d15bf9ed0bf13cfe9eda0554"
ORIGINAL_CROSSWALK_BLOB = "89898dd4ec04f13ec9302ee505907e7fd65dafa2"
RENEWED_CAPTURE_ISO = "2026-11-16T04:36:35.765Z"
REVIEWED_PUBLICATION_ISO = "2026-11-15T11:59:41-05:00"
PRIOR_CAPTURE_ISO = "2026-11-15T20:19:23.723Z"
CATEGORIES = {"ancient": 15, "godly": 128, "chroma": 46}
CURRENT_SITE_PAGE_KEYS = ("home", "ancient", "godly", "chroma")
APPROVED_PAGES = {
    "home": "https://supremevalues.com/",
    "ancient": "https://supremevalues.com/mm2/ancients",
    "godly": "https://supremevalues.com/mm2/godlies",
    "chroma": "https://supremevalues.com/mm2/chromas",
}


class C9SupremeRenewalBlocked(ValueError):
    pass


def deny(message):
    raise C9SupremeRenewalBlocked(message)


def git_blob_sha(raw):
    if type(raw) is not bytes:
        deny("C9_SUPREME_PINNED_BYTES_REQUIRED")
    return hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()


def parse_pinned(raw, blob, name):
    if git_blob_sha(raw) != blob:
        deny("C9_SUPREME_SOURCE_GIT_BLOB_MISMATCH_" + name)
    try:
        data = json.loads(raw)
    except (UnicodeError, json.JSONDecodeError):
        deny("C9_SUPREME_PINNED_JSON_INVALID_" + name)
    if type(data) is not dict:
        deny("C9_SUPREME_PINNED_OBJECT_REQUIRED_" + name)
    return data


def audit(renewed_bytes, old_bytes, historical_crosswalk_bytes, *, at_utc):
    renewed = parse_pinned(renewed_bytes, RENEWED_RECEIPT_BLOB, "NEW")
    old = parse_pinned(old_bytes, PRIOR_RECEIPT_BLOB, "OLD")
    crosswalk = parse_pinned(historical_crosswalk_bytes, ORIGINAL_CROSSWALK_BLOB, "REGISTRY")
    if renewed.get("sourceCapturedUtc") != RENEWED_CAPTURE_ISO or (
        old.get("sourceCapturedUtc") != PRIOR_CAPTURE_ISO or
        renewed.get("sourceOfficialPublicationISO") != REVIEWED_PUBLICATION_ISO or
        old.get("sourceOfficialPublicationISO") != REVIEWED_PUBLICATION_ISO
    ):
        deny("C9_SUPREME_CAPTURE_OR_PUBLICATION_REVISION_INCONSISTENT")
    cap = timeparse(RENEWED_CAPTURE_ISO)
    prior = timeparse(PRIOR_CAPTURE_ISO)
    if cap <= prior:
        deny("C9_SUPREME_CAPTURE_NOT_NEWER")
    pages = renewed.get("pageEvidence")
    if type(pages) is not dict or set(pages) != set(CURRENT_SITE_PAGE_KEYS):
        deny("C9_SUPREME_NOT_FOUR_REVIEWED_PAGES")
    if any(pages[k].get("url") != APPROVED_PAGES[k] or
           pages[k].get("transport") != "Firecrawl rawHtml" or
           pages[k].get("statusCode") != 200 for k in CURRENT_SITE_PAGE_KEYS):
        deny("C9_SUPREME_NOT_SAME_OFFICIAL_SOURCE")
    ids = [pages[k].get("scrapeId") for k in CURRENT_SITE_PAGE_KEYS]
    if len(set(ids)) != 4:
        deny("C9_SUPREME_PAGE_CAPTURE_IDS_NOT_DISTINCT")
    if renewed.get("sourceAcquisitionMethod") != old.get("sourceAcquisitionMethod"):
        deny("C9_SUPREME_PROVENANCE_CHANGED")
    if (renewed.get("categoryMatchedCounts") != CATEGORIES or
        renewed.get("matchedHistoricalGameKeys") != 189 or
        renewed.get("officialPriceDisagreementCount") != 34 or
        len(renewed.get("rows", [])) != 189):
        deny("C9_SUPREME_CAPTURE_CENSUS_CHANGED")
    # Both captures were genuinely checked against the official 11/15 edition.
    # An edition-invariant card change is a source inconsistency, not permission
    # to trust an old observation.
    prior_rows = {r["rawGameKeyCandidate"]: r for r in old["rows"]}
    latest_rows = {r["rawGameKeyCandidate"]: r for r in renewed["rows"]}
    if len(prior_rows) != 189 or len(latest_rows) != 189 or (
        set(prior_rows) != set(latest_rows)
    ):
        deny("C9_SUPREME_SOURCE_IDENTITY_CENSUS_CHANGED")
    for key in prior_rows:
        for field in (
            "category", "officialItemId", "officialName",
            "officialSupremeListed", "officialDemand", "officialStability",
            "explicitReviewedNameAlias", "outgoingGingerscopeProtected",
        ):
            if prior_rows[key].get(field) != latest_rows[key].get(field):
                deny("C9_SUPREME_SAME_PUBLICATION_CARD_INCONSISTENT")
    try:
        research = validate(renewed, crosswalk, at_utc)
    except (SupremeEvidenceBlocked, ValueError, TypeError, KeyError) as error:
        deny("C9_SUPREME_BASE_GATE_BLOCKED:" + str(error))
    if (research.get("matchedHistoricalGameKeys") != 189 or
        research.get("marketSupremePriceConflictCount") != 34 or
        research.get("safeForAutonomousTrade") is not False):
        deny("C9_SUPREME_189_AUDIT_INCONSISTENT")
    # This status refers to the obsolete aggregator Supreme column; it does
    # not imply the official-origin row data are wrong or give trading rights.
    return {
        "schema": SCHEMA,
        "status": "FRESH_CAPTURE_RESEARCH_AUDITED_NO_MARKET_OR_TRADE_AUTHORITY",
        "officialPublisherEdition": REVIEWED_PUBLICATION_ISO,
        "capturedUtc": RENEWED_CAPTURE_ISO,
        "evaluatedUtc": timeparse(at_utc).astimezone(timezone.utc).isoformat(),
        "sourceAgeSeconds": research["sourceAgeSeconds"],
        "historicalGameKeys": 189,
        "officialRowsUnchangedSincePreviousSameEdition": True,
        "supremeColumnPriorAggregatorConflicts": 34,
        "officialOriginThroughFirecrawl": True,
        "publisherCryptographicSignatureVerified": False,
        "directGithubFirstPartyFetchVerified": False,
        "sourceReceiptGitBlob": RENEWED_RECEIPT_BLOB,
        "earlierReceiptGitBlob": PRIOR_RECEIPT_BLOB,
        "historicalCrosswalkGitBlob": ORIGINAL_CROSSWALK_BLOB,
        "currentMm2valuesIndependentSnapshotBound": False,
        "liveRobloxWeaponIdentityVerified": False,
        "serverTradeSettlementProven": False,
        "researchOnly": True,
        "safeForLivePricing": False,
        "authorizesTrade": False,
        "authorizesOffer": False,
        "authorizesAccept": False,
        "mayUseForStrategyLearning": False,
        "mayReportProfit": False,
    }


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--renewed", type=Path, required=True)
    p.add_argument("--older", type=Path, required=True)
    p.add_argument("--crosswalk", type=Path, required=True)
    p.add_argument("--at-utc", required=True,
                   help="Research evaluation clock; archive WILL expire after six hours.")
    args = p.parse_args(argv)
    try:
        result = audit(args.renewed.read_bytes(), args.older.read_bytes(),
                       args.crosswalk.read_bytes(), at_utc=args.at_utc)
        print("C9_SUPREME_CAPTURE_AUDIT=" + result["status"])
        print("C9_SOURCE_AGE_SECONDS=" + str(result["sourceAgeSeconds"]))
        print("C9_VERIFIED_HISTORICAL_GAME_KEYS=189")
        print("C9_LIVE_TRADE_AUTHORIZED=FALSE")
        return 0
    except (C9SupremeRenewalBlocked, ValueError, OSError, TypeError) as error:
        print("C9_SUPREME_CAPTURE_AUDIT=BLOCKED")
        print("C9_CAPTURE_REASON=" + str(error))
        return 2


if __name__ == "__main__":
    sys.exit(main())
