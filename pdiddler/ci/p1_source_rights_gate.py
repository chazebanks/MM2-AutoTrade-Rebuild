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
