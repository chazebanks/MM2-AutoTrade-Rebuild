"""Stage111: read-only canonical HTTPS Supreme source capture and archive.

Never approves or updates public-market prices, game inventory, Discord
settlements or trade/Accept automation. Transport TLS certificate checks
are requested by an HTTPS client, but no source response is server-signed
and an injected HTTP session does NOT provide independent authentication.
A claimed NEW source publication remains MANUAL REVIEW candidate only.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import sys

from .stage110_trusted_source_admission import (
    admit, PARSER_GIT_BLOB, PINNED_PRIOR_GIT_BLOBS, _git_blob, _report
)
from .stage104_publication_timestamp_gate import _deny

SCHEMA="gingerscope-stage111-readonly-canonical-https-source-archive-v1"
CANONICAL_URLS={
    "ancient":"https://supremevalues.com/mm2/ancients",
    "godly":"https://supremevalues.com/mm2/godlies",
    "chroma":"https://supremevalues.com/mm2/chromas",
}
HTML_FILES={
    "ancient":"source_ancient.html",
    "godly":"source_godly.html",
    "chroma":"source_chroma.html",
}
MAX_HTML_BYTES=799999
REQUEST_TIMEOUT=(8,20)
UTC=re.compile(r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$")


class CaptureRejected(ValueError):
    def __init__(self,code):
        super().__init__(code)
        self.code=code


def _clock_utc()->str:
    return datetime.now(timezone.utc).isoformat(
        timespec="seconds").replace("+00:00","Z")


def _checked_utc(value)->str:
    if not isinstance(value,str) or not UTC.fullmatch(value):
        raise CaptureRejected("SOURCE_CAPTURE_CLOCK_INVALID")
    try:
        datetime.fromisoformat(value.replace("Z","+00:00"))
    except ValueError as exc:
        raise CaptureRejected("SOURCE_CAPTURE_CLOCK_INVALID") from exc
    return value


def _source_digest(data:bytes)->str:
    return hashlib.sha256(data).hexdigest()


def _fetch_one(session,category,clock):
    url=CANONICAL_URLS[category]
    # Do not follow redirects, including alternative .php or stale aliases.
    # No proxies or credentials are provided by the capture module.
    response=None
    try:
        response=session.get(
            url,headers={
                "Accept":"text/html",
                "Cache-Control":"no-cache, no-store",
                "Pragma":"no-cache",
                "User-Agent":"MM2SourceResearchArchive/1.0",
            },
            timeout=REQUEST_TIMEOUT,
            allow_redirects=False,
            verify=True,
            stream=True,
        )
        if (getattr(response,"status_code",None)!=200):
            raise CaptureRejected("CANONICAL_SOURCE_HTTP_NOT_200")
        if (getattr(response,"url",None)!=url):
            raise CaptureRejected("CANONICAL_SOURCE_REDIRECT_OR_URL_MISMATCH")
        header=getattr(response,"headers",{})
        if not isinstance(header,dict) and not hasattr(header,"get"):
            raise CaptureRejected("CANONICAL_SOURCE_HTTP_HEADERS_UNAVAILABLE")
        ctype=header.get("Content-Type","")
        if (not isinstance(ctype,str) or
            not ctype.lower().split(";",1)[0].strip()=="text/html"):
            raise CaptureRejected("CANONICAL_SOURCE_UNEXPECTED_MEDIA_TYPE")
        chunks=[]
        size=0
        for chunk in response.iter_content(chunk_size=32768):
            if not isinstance(chunk,bytes):
                raise CaptureRejected("CANONICAL_SOURCE_BODY_NOT_BYTES")
            size+=len(chunk)
            if size>MAX_HTML_BYTES:
                raise CaptureRejected("CANONICAL_SOURCE_BODY_EXCEEDS_LIMIT")
            chunks.append(chunk)
        raw=b"".join(chunks)
        if not 1000<len(raw)<800000:
            raise CaptureRejected("CANONICAL_SOURCE_BODY_INCOMPLETE")
        # Content-Length is an on-wire byte count. Requests.iter_content
        # decompresses gzip/deflate/br before yielding bytes. Only compare
        # counts for an identity (uncompressed) HTTP representation.
        declared=header.get("Content-Length")
        if declared is not None:
            if (not isinstance(declared,str) or
                not re.fullmatch(r"[0-9]{1,12}",declared)):
                raise CaptureRejected("CANONICAL_SOURCE_CONTENT_LENGTH_INVALID")
            encoding=header.get("Content-Encoding","")
            if (not isinstance(encoding,str) or
                (encoding.strip().lower() in ("","identity") and
                 int(declared)!=len(raw))):
                raise CaptureRejected("CANONICAL_SOURCE_CONTENT_LENGTH_MISMATCH")
        observed=_checked_utc(clock())
        capture={
            "url":url,
            "html":raw,
            "httpStatus":200,
            "retrievedAtUtc":observed,
        }
        public={
            "url":url,
            "retrievedAtUtc":observed,
            "httpStatus":200,
            "sha256":_source_digest(raw),
            "rawHtmlByteCount":len(raw),
        }
        return capture,public
    except CaptureRejected:
        raise
    except Exception as exc:
        # Never leak exception content (which may include proxy details,
        # headers, credentials, request implementation or full HTML).
        raise CaptureRejected("CANONICAL_SOURCE_TRANSPORT_READ_FAILED") from exc
    finally:
        if response is not None:
            close=getattr(response,"close",None)
            if callable(close):
                close()


def _manifest(captures,public,admission)->dict:
    return {
        "schema":SCHEMA,
        "status":admission["status"],
        "reason":admission["reason"],
        "captureCompleteness":"THREE_CANONICAL_PAGES" if len(captures)==3
                              else "INCOMPLETE_CAPTURE",
        "capturedSources":public,
        "admission":admission,
        "transportCertificateVerificationRequested":True,
        "httpRedirectsDisabled":True,
        "authenticatesExternalSource":False,
        "mayExtendOriginalCaptureExpiry":False,
        "mayUpdatePriceFiles":False,
        "mayUpdateProduction":False,
        "mayRecordCompletedTrade":False,
        "mayReportProfit":False,
        "maySendDiscordWebhook":False,
        "mayUseForStrategyLearning":False,
    }


def _write_research_bundle(path:Path,captures:dict,manifest:dict)->None:
    # These are diagnostic artifacts ONLY; no game/price database path is
    # touched. No publishing or Git write on any source-candidate status.
    path.mkdir(parents=True,exist_ok=True)
    (path/"source_audit.json").write_text(
        json.dumps(manifest,indent=2,sort_keys=True,ensure_ascii=True)+"\n",
        encoding="utf-8")
    for category,capture in captures.items():
        (path/HTML_FILES[category]).write_bytes(capture["html"])


def collect_and_admit(
    session,
    *,
    parser_bytes:bytes,
    prior_html:dict,
    clock=_clock_utc,
    artifact_dir:Path|None=None,
)->dict:
    """Fetch exactly three HTTPS source pages, preserve raw bytes and status.

    Test session injection does not authenticate TLS, DNS or the publisher.
    Stage110's admission output always denies current price/trading authority.
    """
    captures={}
    public={}
    try:
        # Fail BEFORE external requests on altered local parser/baseline.
        if type(parser_bytes) is not bytes or _git_blob(parser_bytes)!=PARSER_GIT_BLOB:
            raise CaptureRejected("PINNED_ORIGINAL_PARSER_MISMATCH")
        if (type(prior_html) is not dict or
            set(prior_html)!=set(PINNED_PRIOR_GIT_BLOBS) or
            any(type(prior_html[page]) is not bytes or
                _git_blob(prior_html[page])!=expected
                for page,expected in PINNED_PRIOR_GIT_BLOBS.items())):
            raise CaptureRejected("PINNED_ORIGINAL_PRIOR_HTML_MISMATCH")
        for page in CANONICAL_URLS:
            capture,pub=_fetch_one(session,page,clock)
            captures[page]=capture
            public[page]=pub
        now=_checked_utc(clock())
        admission=admit(
            captures,
            original_parser_bytes=parser_bytes,
            pinned_prior_html=prior_html,
            evaluation_utc=now,
        )
    except CaptureRejected as exc:
        admission=_report(_deny(exc.code))
    except Exception:
        admission=_report(_deny("CANONICAL_SOURCE_CAPTURE_INCONCLUSIVE"))
    result=_manifest(captures,public,admission)
    if artifact_dir is not None:
        _write_research_bundle(Path(artifact_dir),captures,result)
    return result


def main(argv:list[str]|None=None)->int:
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--parser",type=Path,required=True)
    p.add_argument("--prior-html-dir",type=Path,required=True)
    p.add_argument("--output-dir",type=Path,required=True)
    args=p.parse_args(argv)
    import requests
    source=args.prior_html_dir
    # Explicit reviewed filenames avoid accidental singular/plural drift.
    prior={
        "ancient":(source/"ancients.html").read_bytes(),
        "godly":(source/"godlies.html").read_bytes(),
        "chroma":(source/"chromas.html").read_bytes(),
    }
    with requests.Session() as session:
        session.trust_env=False
        result=collect_and_admit(
            session,parser_bytes=args.parser.read_bytes(),
            prior_html=prior,clock=_clock_utc,artifact_dir=args.output_dir,
        )
    print("STAGE111_SUPREME_SOURCE_CAPTURE",
          "status="+result["status"],
          "reason="+result["reason"],
          "pages="+str(len(result["capturedSources"])),
          "publisher="+str(result["admission"].get("observedPublisherUtc")),
          "mayUpdatePriceFiles=false",
          "authorizesAccept=false")
    if (result["status"]=="NO_NEW_PUBLISHER_PUBLICATION" and
        result["reason"]=="SOURCE_PUBLISHER_DATE_UNCHANGED_NO_REFRESH"):
        return 0
    # A NEW publisher or same-date row drift is a deliberate manual-review
    # signal; the artifact retains source pages and hash evidence.
    if (result["status"]=="NEW_PUBLISHER_CANDIDATE_REVIEW_REQUIRED" or
        result["reason"]=="UNCHANGED_PUBLISHER_DATE_BUT_ROW_DRIFT_REVIEW_REQUIRED"):
        return 3
    return 2


if __name__=="__main__":
    raise SystemExit(main())
