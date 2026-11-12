"""P1 source-use permission checkpoint. Metadata-only; never requests market pages.

Research conclusion: website accessibility, third-party APIs, source publication
timestamps, and having archived HTML do not independently prove permission to
import Supreme Values tables into an automated application. A future explicit
publisher grant requires separate reviewed implementation and independent
verification. This module has no override/allow path.
"""
from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
import argparse
import json

SCHEMA = "gingerscope-p1-source-rights-gate-v1"
DENIED = {
    "sourceCaptureAuthorized": False,
    "firstPartyMarketDatasetLicensed": False,
    "alternateProviderRightsVerified": False,
    "verifiedMarketQuote": False,
    "mayUpdatePriceFiles": False,
    "mayUpdateProduction": False,
    "marketSourceUsableForLiveOffer": False,
    "mayFeedStage120AsVerifiedMarket": False,
    "authorizesOffer": False,
    "authorizesTrade": False,
    "authorizesAccept": False,
    "serverCompletionProven": False,
    "mayReportProfit": False,
    "maySendDiscordWebhook": False,
    "mayUseForStrategyLearning": False,
}


def receipt(now=None):
    """A timestamp on this receipt is NOT a publisher snapshot time."""
    if now is None:
        now = datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
    return {
        "schema": SCHEMA,
        "status": "BLOCKED",
        "reason": "NO_VERIFIED_SOURCE_DATA_REUSE_PERMISSION",
        "diagnosis": "GITHUB_HTTPS_403_CLOUDFLARE_CHALLENGE_PREVIOUSLY_OBSERVED",
        "researchReceiptUtc": now,
        "publisherUpdatedUtc": None,
        "source": "https://supremevalues.com/tos",
        "sourceTerms": "PROHIBIT_COPYING_VALUE_LIST_FOR_APPLICATION_WITHOUT_SEPARATE_PERMISSION",
        "contact": "https://supremevalues.com/tos",
        "requestRequired": "WRITTEN_PUBLISHER_AUTHORIZATION_FOR_THIS_USE_AND_DOCUMENTED_APPROVED_FEED",
        "alternative": "RBLXValue developer API is documented; source-derived rights are unverified",
        "historicalSourceCollectorStatus": "SUSPENDED_NO_NETWORK_REQUESTS_BY_THIS_WORKFLOW",
        "independentPublisherRevisionVerified": False,
        "permissionEvidenceVerified": False,
        "tradeOutcome": "UNKNOWN",
        **DENIED,
    }



# Research candidate screening complements the permanent source-rights veto.
# It NEVER grants a license or market authority based on caller-provided metadata.
CANDIDATE_RIGHTS = {"CC_BY_4_DECLARED", "API_ACCESS_ONLY", "UNKNOWN", "RESTRICTED"}
CANDIDATE_ORIGINS = {"INDEPENDENT_CLAIM", "SUPREME_DERIVED", "MIXED_DERIVED", "UNKNOWN"}
PUBLISHER_TIME = {"PUBLISHER_TIMESTAMP", "AGGREGATOR_REFRESH", "DISPLAY_DATE_ONLY", "UNKNOWN"}
IDENTITY_STATUS = {"EXACT_GAME_RAW_KEY_CLAIM", "AMBIGUOUS_COLLISION", "UNKNOWN"}
RESEARCH_MAX_AGE_DAYS = 7  # Screening heuristic only; NOT a live data policy.


def _candidate_time(value):
    if type(value) is not str:
        return None
    try:
        dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except (ValueError, OverflowError):
        return None
    if dt.tzinfo is None or dt.utcoffset() is None:
        return None
    return dt.astimezone(timezone.utc)


def screen_public_candidate(candidate, *, observed_utc):
    """Classify supplied *research metadata*; never fetch or trust the dataset.

    Even a plausible independent, fresh, licensed source must be separately
    authenticated, reviewed for rights/scope, raw item identity and coverage.
    This function CANNOT authorize a trader, quote or completed-trade label.
    """
    if type(candidate) is not dict:
        raise ValueError("INVALID_CANDIDATE_OBJECT")
    required = {"provider", "declaredRights", "upstreamProvenance",
                "timestampMeaning", "publisherUpdatedUtc", "identityEvidence"}
    if set(candidate) != required:
        raise ValueError("INVALID_CANDIDATE_FIELDS")
    if type(candidate["provider"]) is not str or not 1 <= len(candidate["provider"]) <= 120:
        raise ValueError("INVALID_PROVIDER")
    for field, allowed in (
        ("declaredRights", CANDIDATE_RIGHTS),
        ("upstreamProvenance", CANDIDATE_ORIGINS),
        ("timestampMeaning", PUBLISHER_TIME),
        ("identityEvidence", IDENTITY_STATUS),
    ):
        if type(candidate[field]) is not str or candidate[field] not in allowed:
            raise ValueError("INVALID_" + field.upper())

    observation = _candidate_time(observed_utc)
    if observation is None:
        raise ValueError("INVALID_OBSERVATION_CLOCK")
    published = _candidate_time(candidate["publisherUpdatedUtc"])
    reasons = []
    rights = candidate["declaredRights"]
    if rights == "RESTRICTED":
        reasons.append("PUBLISHER_RESTRICTS_REUSE")
    elif rights == "UNKNOWN":
        reasons.append("REUSE_RIGHTS_NOT_DECLARED")
    elif rights == "API_ACCESS_ONLY":
        reasons.append("UPSTREAM_DATA_REUSE_RIGHTS_NOT_PROVEN")
    # CC_BY_4_DECLARED is a claim within metadata, not authenticated permission.
    if candidate["upstreamProvenance"] in ("SUPREME_DERIVED", "MIXED_DERIVED"):
        reasons.append("SUPREME_DERIVED_SOURCE_REUSE_NOT_CLEARED")
    elif candidate["upstreamProvenance"] == "UNKNOWN":
        reasons.append("ORIGINAL_SOURCE_PROVENANCE_UNKNOWN")

    if candidate["timestampMeaning"] != "PUBLISHER_TIMESTAMP" or published is None:
        reasons.append("PUBLISHER_CLOCK_NOT_PROVEN")
        age = None
    else:
        age = (observation - published).total_seconds() / 86400
        if age < 0:
            reasons.append("FUTURE_PUBLISHER_TIME")
        elif age > RESEARCH_MAX_AGE_DAYS:
            reasons.append("RESEARCH_DATA_STALE")
    if candidate["identityEvidence"] == "AMBIGUOUS_COLLISION":
        reasons.append("ITEM_IDENTITY_COLLISION")
    elif candidate["identityEvidence"] == "UNKNOWN":
        reasons.append("GAME_RAW_ITEM_IDENTITY_NOT_PROVEN")

    return {
        "schema": "gingerscope-p1-provider-research-screen-v1",
        "providerLabelUnverified": candidate["provider"],
        "status": "BLOCKED_CANDIDATE" if reasons else "RESEARCH_REVIEW_ONLY",
        "blockers": reasons,
        "publisherAgeDaysIfProven": None if age is None else round(age, 4),
        "researchThresholdDaysNotPricePermission": RESEARCH_MAX_AGE_DAYS,
        "permissionEvidenceVerified": False,
        "providerIndependentProvenanceVerified": False,
        "serverSettledTradeEvidenceVerified": False,
        "mayAdvanceP2": False,
        "tradeOutcome": "UNKNOWN",
        **DENIED,
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args(argv)
    result = receipt()
    assert all(result[k] is False for k in DENIED)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    print("P1_SOURCE_RIGHTS", result["status"], result["reason"], "no network capture", "all live authority false")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
