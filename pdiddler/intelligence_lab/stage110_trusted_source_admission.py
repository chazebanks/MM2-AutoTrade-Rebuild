"""Stage110: hash-locked original Supreme parser and prior HTML admission.

This is an OFFLINE evidence-qualification wrapper around the reviewed Stage104
publisher-date auditor (Stage107 source roster+Priceless-label patch).
The existing pure auditor's caller-selected parser/prior records are useful
for unit tests, but must never alone qualify a new first-party data capture.

Even a syntactically new publication inside caller-provided HTML is only
REVIEW_REQUIRED. Network origin, TLS identity, source authenticity, actual
game item IDs, present prices and settlement are NOT attested by this wrapper.
"""
from __future__ import annotations

import hashlib
import types
from .stage104_publication_timestamp_gate import (
    audit_publication, _deny, PRIOR, PAGE_COUNTS, PATHS
)

PARSER_GIT_BLOB="d5843a57f34078cbe7213aa78a4aa12a5775c016"
PINNED_PRIOR_GIT_BLOBS={
    "ancient":"ce8178ab9579e8782d8f72a6dac051756a728506",
    "godly":"d3cf222a8e10cff3a9fb051b16188192389c4b2d",
    "chroma":"6c77624cac3df96168b008e9bc8eca68a2d78cf9",
}
SCHEMA="gingerscope-stage110-source-admission-research-only-v1"


def _git_blob(raw:bytes)->str:
    return hashlib.sha1(
        b"blob "+str(len(raw)).encode("ascii")+b"\0"+raw
    ).hexdigest()


def _report(original:dict,*,parser_ok:bool=False,prior_ok:bool=False)->dict:
    # The source auditor's existing false authority fields are preserved,
    # regardless of a caller's advertised URL, HTTP status or timestamp.
    return {
        **original,
        "admissionSchema":SCHEMA,
        "readOnly":True,
        "researchOnly":True,
        "exactOriginalParserBlobVerified":parser_ok,
        "exactPinnedPriorHtmlVerified":prior_ok,
        "externalCaptureAuthenticated":False,
        "newResearchDatasetPublished":False,
        "newCaptureExpiryUtc":None,
    }


def admit(
    captures:dict,
    *,
    original_parser_bytes:bytes,
    pinned_prior_html:dict,
    evaluation_utc:str,
)->dict:
    """Admit only a MANUAL REVIEW candidate from externally acquired HTML.

    No arbitrary parse callback or historic baseline can be supplied.
    Exact original Git bytes are independently verified before any dynamic
    source code is executed, preserving Stage69's vetted parser contract.
    """
    try:
        if (type(original_parser_bytes) is not bytes or
            _git_blob(original_parser_bytes)!=PARSER_GIT_BLOB):
            return _report(_deny("PINNED_ORIGINAL_PARSER_MISMATCH"))
        if (type(pinned_prior_html) is not dict or
            set(pinned_prior_html)!=set(PINNED_PRIOR_GIT_BLOBS) or
            any(type(pinned_prior_html[page]) is not bytes or
                _git_blob(pinned_prior_html[page])!=digest
                for page,digest in PINNED_PRIOR_GIT_BLOBS.items())):
            return _report(
                _deny("PINNED_ORIGINAL_PRIOR_HTML_MISMATCH"),
                parser_ok=True,
            )

        module=types.ModuleType("_stage110_hash_verified_original_parser")
        exec(compile(original_parser_bytes,
                     "PINNED_STAGE69_SUPREME_HTML_PARSER.py",
                     "exec"),module.__dict__)
        parser=getattr(module,"parse_page",None)
        if not callable(parser):
            return _report(_deny("PINNED_ORIGINAL_PARSER_MISSING"),
                           parser_ok=True,prior_ok=True)

        baseline={}
        for page in PATHS:
            rows,publisher=parser(pinned_prior_html[page].decode("utf-8"),page)
            if (publisher!=PRIOR or type(rows) is not list or
                len(rows)!=PAGE_COUNTS[page]):
                return _report(_deny("PINNED_PRIOR_PUBLISHER_INVALID"),
                               parser_ok=True,prior_ok=True)
            baseline[page]=rows

        candidate=audit_publication(
            captures,
            prior_published=PRIOR,
            prior_records=baseline,
            evaluation_utc=evaluation_utc,
            parse_page=parser,
        )
        # audit_publication itself denies every trading action and does not
        # promote a new publisher stamp into the system's price database.
        return _report(candidate,parser_ok=True,prior_ok=True)
    except (ValueError,TypeError,KeyError,AttributeError,
            UnicodeError,OverflowError,SyntaxError):
        return _report(_deny("ORIGINAL_PARSER_OR_PRIOR_SOURCE_INVALID"))
