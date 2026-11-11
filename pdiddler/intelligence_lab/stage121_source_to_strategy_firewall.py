"""Stage121: source-to-strategy firewall on EXISTING Stage111 research receipts.

No publisher/parser/capture reimplementation. This only classifies a previous
Stage111/110 result before ANY synthetic Stage120 planner might mistake it for
a current MM2 quote, an authenticated game-key, or measured liquidity.

A caller-supplied source manifest cannot authenticate its own network origin.
Even all-positive syntax yields RESEARCH_ONLY, never live market/trade authority.
"""
from __future__ import annotations
from datetime import datetime, timezone
import re

SCHEMA="gingerscope-stage121-market-evidence-firewall-v1"
STAGE111="gingerscope-stage111-readonly-canonical-https-source-archive-v1"
STAGE110="gingerscope-stage110-source-admission-research-only-v1"
PREVIOUS_PUBLISHER="2026-11-09T18:58:33Z"
PREVIOUS_FIXED_EXPIRY="2026-11-10T22:26:48Z"
PAGES={
    "ancient":"https://supremevalues.com/mm2/ancients",
    "godly":"https://supremevalues.com/mm2/godlies",
    "chroma":"https://supremevalues.com/mm2/chromas",
}
UTC=re.compile(r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$")
HASH=re.compile(r"^[0-9a-f]{64}$")
FALSE={
    "readOnly":True,"researchOnly":True,"marketSourceUsableForLiveOffer":False,
    "publishedCurrentPriceAuthenticated":False,
    "independentLiveGameKeyIdentityVerified":False,
    "observedCompletedTradeLiquidityVerified":False,
    "verifiedMarketQuote":False,
    "mayFeedStage120AsVerifiedMarket":False,
    "authorizesOffer":False,"authorizesTrade":False,"authorizesAccept":False,
    "mayRecordCompletedTrade":False,"mayReportProfit":False,
    "maySendDiscordWebhook":False,"mayUseForStrategyLearning":False,
    "serverCompletionProven":False,"tradeOutcome":"UNKNOWN",
}

def _report(status, reason, **data):
    return {"schema":SCHEMA,"status":status,"reason":reason,
            "sourcePublisherUtc":None,"priorExpiryUtc":PREVIOUS_FIXED_EXPIRY,
            **data,**FALSE}

def _epoch(value):
    if type(value) is not str or not UTC.fullmatch(value):
        raise ValueError("UTC required")
    d=datetime.fromisoformat(value.replace("Z","+00:00"))
    if d.tzinfo is None or d.utcoffset().total_seconds()!=0:
        raise ValueError("wrong zone")
    return int(d.timestamp())

def assess(manifest, *, evaluated_utc, candidate_market=None, trade_activity=None):
    """Enforce the boundary AFTER original Stage111/110 has done its own job.

    Does not upgrade original Stage111's injected/mock HTTPS transport into a
    trusted network origin. Rejects all supplied "real" price or liquidity
    candidates, even if they have fresh-looking third-party import timestamps.
    """
    try:
        now=_epoch(evaluated_utc)
        old=_epoch(PREVIOUS_PUBLISHER)
        fixed=_epoch(PREVIOUS_FIXED_EXPIRY)
    except (ValueError,TypeError,OverflowError):
        return _report("BLOCKED","EVALUATION_CLOCK_INVALID")

    # Purposefully DO NOT treat supplied candidate prices or posted requests
    # as independent, executed trade market evidence. Nor silently discard it.
    if candidate_market is not None:
        return _report("BLOCKED","UNVERIFIED_PRICE_INPUT_CANNOT_PROMOTE_RESEARCH")
    if trade_activity is not None:
        return _report("BLOCKED","TRADE_POSTINGS_ARE_NOT_VERIFIED_COMPLETED_FILLS")

    if type(manifest) is not dict or manifest.get("schema")!=STAGE111:
        return _report("BLOCKED","STAGE111_SOURCE_CAPTURE_MISSING")
    if manifest.get("captureCompleteness")!="THREE_CANONICAL_PAGES":
        return _report("BLOCKED","THREE_CANONICAL_CAPTURE_REQUIRED")
    captured=manifest.get("capturedSources")
    if type(captured) is not dict or set(captured)!=set(PAGES):
        return _report("BLOCKED","CANONICAL_CAPTURE_ROWS_MISSING")
    retrieved=[]
    for category,url in PAGES.items():
        row=captured.get(category)
        if type(row) is not dict or row.get("url")!=url or (
            type(row.get("sha256")) is not str or
            HASH.fullmatch(row["sha256"]) is None or
            type(row.get("rawHtmlByteCount")) is not int or
            not 1000<row["rawHtmlByteCount"]<800000 or
            type(row.get("httpStatus")) is not int or
            row["httpStatus"]!=200
        ):
            return _report("BLOCKED","CANONICAL_CAPTURE_METADATA_INVALID")
        try:
            fetched=_epoch(row.get("retrievedAtUtc"))
        except (ValueError,TypeError,OverflowError):
            return _report("BLOCKED","CANONICAL_CAPTURE_CLOCK_INVALID")
        if fetched>now or fetched<old:
            return _report("BLOCKED","CANONICAL_CAPTURE_CLOCK_OUT_OF_RANGE")
        retrieved.append(fetched)
    a=manifest.get("admission")
    if type(a) is not dict or a.get("admissionSchema")!=STAGE110:
        return _report("BLOCKED","ORIGINAL_STAGE110_ADMISSION_MISSING")
    if a.get("exactOriginalParserBlobVerified") is not True or (
        a.get("exactPinnedPriorHtmlVerified") is not True
    ):
        return _report("BLOCKED","ORIGINAL_HASH_LOCKS_UNVERIFIED")
    # The original modules *always* deny source-authentication and live quotes.
    # Any other flags suggest a forged result. Never accept self-asserted trust.
    for flag in ("externalCaptureAuthenticated","newResearchDatasetPublished",
                 "publisherRefreshApproved","currentPricesVerified",
                 "priceForTradeVerified","rawGameWeaponKeyAuthenticated",
                 "numericSupremeCheckerIdVerified","authorizesTrade",
                 "authorizesAccept","serverCompletionProven",
                 "mayUseForStrategyLearning"):
        if a.get(flag) is not False:
            return _report("BLOCKED","STAGE110_DENIED_AUTHORITY_CONTRACT_CHANGED")
    for flag in ("authenticatesExternalSource","mayExtendOriginalCaptureExpiry",
                 "mayUpdatePriceFiles","mayUpdateProduction",
                 "maySendDiscordWebhook","mayUseForStrategyLearning"):
        if manifest.get(flag) is not False:
            return _report("BLOCKED","STAGE111_DENIED_AUTHORITY_CONTRACT_CHANGED")
    if a.get("fixedPriorExpiryPreserved") is not True or (
        a.get("newCaptureExpiryUtc") is not None
    ):
        return _report("BLOCKED","ORIGINAL_EXPIRY_ILLEGITIMATELY_EXTENDED")
    if a.get("tradeOutcome")!="UNKNOWN":
        return _report("BLOCKED","ORIGINAL_TRADE_OUTCOME_FORGED")
    if a.get("canonicalSourcePageCount")!=3:
        return _report("BLOCKED","ORIGINAL_CANONICAL_PAGE_COUNT_INVALID")
    dates=a.get("rawPagePublishedDates")
    if type(dates) is not dict or set(dates)!=set(PAGES) or len(set(dates.values()))!=1:
        return _report("BLOCKED","MIXED_OR_MISSING_PUBLISHER_DATES")
    publisher=a.get("observedPublisherUtc")
    if type(publisher) is not str or publisher!=next(iter(dates.values())):
        return _report("BLOCKED","PUBLISHER_DATE_NOT_SOURCE_BOUND")
    if manifest.get("status")!=a.get("status") or manifest.get("reason")!=a.get("reason"):
        return _report("BLOCKED","SOURCE_ADMISSION_STATUS_MISMATCH")
    try:
        stamp=_epoch(publisher)
    except (TypeError,ValueError,OverflowError):
        return _report("BLOCKED","PUBLISHER_DATE_INVALID")
    if stamp>min(retrieved):
        return _report("BLOCKED","PUBLISHER_DATE_AFTER_CAPTURE")
    if stamp<old:
        return _report("BLOCKED","OLDER_PUBLISHER_NOT_CURRENT")
    if stamp==old:
        if manifest.get("status")!="NO_NEW_PUBLISHER_PUBLICATION":
            return _report("BLOCKED","UNCHANGED_PUBLISHER_STATUS_CONTRADICTION")
        if now>=fixed:
            return _report("BLOCKED","OLD_PUBLICATION_FIXED_EXPIRY_PASSED",
                           sourcePublisherUtc=publisher)
        return _report("RESEARCH_ONLY","NO_NEW_PUBLICATION_KEEP_EXISTING_EXPIRY",
                       sourcePublisherUtc=publisher)
    # A genuinely newer stamp can be investigated as an archival *candidate*,
    # but Stage111's own protocol cannot authorize current price usage.
    if manifest.get("status")!="NEW_PUBLISHER_CANDIDATE_REVIEW_REQUIRED":
        return _report("BLOCKED","NEW_PUBLISHER_STATUS_CONTRADICTION")
    return _report("RESEARCH_ONLY","NEW_PUBLISHER_REQUIRES_INDEPENDENT_REVIEW",
                   sourcePublisherUtc=publisher)

