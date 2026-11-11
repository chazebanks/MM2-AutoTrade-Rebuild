"""P1 HTTPS transport headers-only diagnostic. No source admission or game actions.

Executed only after the original immutable Stage111 capture returned inconclusive.
Never reads or stores response HTML, cookies, credentials, or raw response headers.
"""
from __future__ import annotations

from datetime import datetime, timezone
import json
from pathlib import Path
from urllib.parse import urlparse

CANONICAL = "https://supremevalues.com/mm2/ancients"
SCHEMA = "gingerscope-p1-transport-headers-only-diagnostic-v1"
REQUEST_HEADERS = {
    "Accept": "text/html",
    "Cache-Control": "no-cache, no-store",
    "Pragma": "no-cache",
    "User-Agent": "MM2SourceResearchArchive/1.0",
}
DENIED = {
    "mayUpdatePriceFiles": False,
    "mayUpdateProduction": False,
    "authorizesTrade": False,
    "authorizesOffer": False,
    "authorizesAccept": False,
    "serverCompletionProven": False,
    "mayReportProfit": False,
    "maySendDiscordWebhook": False,
    "mayUseForStrategyLearning": False,
}


def _utc_now():
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def _status_reason(status):
    if status == 200:
        return "HTTP_200_HEADERS_ONLY_NOT_SOURCE_ADMISSION"
    if status in (301, 302, 303, 307, 308):
        return "HTTP_REDIRECT_REVIEW_REQUIRED"
    if status in (401, 403, 407, 429):
        return "HTTP_ACCESS_RESTRICTED_" + str(status)
    if status is not None and status >= 500:
        return "HTTP_SERVER_ERROR"
    return "HTTP_UNEXPECTED_STATUS"


def _redirect_category(value):
    if not isinstance(value, str) or not value.strip():
        return "NONE"
    target = urlparse(value)
    if not target.netloc:
        return "RELATIVE_NO_REDIRECT_FOLLOWED"
    if target.scheme != "https":
        return "NON_HTTPS"
    if target.hostname == "supremevalues.com":
        return "CANONICAL_HOST"
    if target.hostname == "www.supremevalues.com":
        return "WWW_HOST"
    return "OTHER_HOST"


def probe(session, clock=_utc_now):
    """One identical no-redirect, TLS-verified, streamed request; reads no body."""
    observation = {
        "schema": SCHEMA,
        "observedAtUtc": clock(),
        "requestedUrl": CANONICAL,
        "status": "DIAGNOSTIC_ONLY",
        "httpStatus": None,
        "reason": "TRANSPORT_EXCEPTION_SANITIZED",
        "responseUrlExact": False,
        "contentTypeClass": "UNAVAILABLE",
        "redirectLocationClass": "NONE",
        "serverClass": "UNAVAILABLE",
        "cloudflareChallengeHeader": False,
        "retryAfterPresent": False,
        "bodyRead": False,
        "storedResponseBytes": 0,
        "authenticatesExternalSource": False,
        **DENIED,
    }
    response = None
    try:
        response = session.get(
            CANONICAL, headers=dict(REQUEST_HEADERS), timeout=(8, 20),
            allow_redirects=False, verify=True, stream=True,
        )
        status = getattr(response, "status_code", None)
        if type(status) is not int or not 100 <= status <= 599:
            return observation
        headers = response.headers
        ctype = headers.get("Content-Type", "").split(";", 1)[0].strip().lower()
        server = headers.get("Server", "").strip().lower()
        observation.update(
            httpStatus=status,
            reason=_status_reason(status),
            responseUrlExact=getattr(response, "url", None) == CANONICAL,
            contentTypeClass=(
                "TEXT_HTML" if ctype == "text/html" else
                "OTHER" if ctype else "UNAVAILABLE"
            ),
            redirectLocationClass=_redirect_category(headers.get("Location")),
            serverClass=("CLOUDFLARE" if server == "cloudflare" else
                         "OTHER" if server else "UNAVAILABLE"),
            cloudflareChallengeHeader=(
                headers.get("cf-mitigated", "").strip().lower() == "challenge"
            ),
            retryAfterPresent=bool(headers.get("Retry-After")),
        )
        return observation
    except Exception:
        # Do not expose exception messages, network details or headers.
        return observation
    finally:
        if response is not None:
            response.close()


def main():
    import argparse
    import requests
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    with requests.Session() as session:
        session.trust_env = False
        result = probe(session)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, sort_keys=True, indent=2) + "\n")
    print("P1_TRANSPORT_DIAGNOSTIC", json.dumps(result, sort_keys=True))
    return 0  # Successful diagnosis is NEVER successful source admission.


if __name__ == "__main__":
    raise SystemExit(main())
