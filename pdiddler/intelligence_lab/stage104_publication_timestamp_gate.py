"""Stage104: original first-party Supreme 3-category PUBLISHER STAMP / row audit.

RESEARCH ONLY. Does not fetch URLs, refresh prices or modify any live trade
files. Input HTML must be separately acquired from canonical first-party HTTPS
pages with independent retrieval evidence. Parser is the exact pinned Stage69
public HTML reader, not an untrusted alternative. Its parse result still isn't
an official MM2 game item ID or a verified market quote.

Key bug guarded: /mm2/chromas.php can return an older page (Nov6) while
/mm2/chromas returns Nov9; never combine them or extend capture expiry on
a re-crawl bearing the same publisher timestamp.
"""
from __future__ import annotations

from datetime import datetime, timezone
import hashlib
import json
import re
from typing import Callable
from urllib.parse import urlsplit

SCHEMA="gingerscope-stage104-supreme-source-stamp-gate-v1"
PRIOR="2026-11-09T18:58:33Z"
PAGE_COUNTS={"ancient":16,"godly":128,"chroma":46}
PATHS={"ancient":"/mm2/ancients","godly":"/mm2/godlies",
       "chroma":"/mm2/chromas"}
HOSTS={"supremevalues.com","www.supremevalues.com"}
DENY={
    "researchOnly":True,"readOnly":True,"publisherRefreshApproved":False,
    "publicObservationAuthenticatedAsGameTrade":False,
    "rawGameWeaponKeyAuthenticated":False,
    "numericSupremeCheckerIdVerified":False,
    "currentPricesVerified":False,"priceForTradeVerified":False,
    "authenticatedOwnedInventory":False,
    "serverAttestation":False,"serverCompletionProven":False,
    "authorizesTrade":False,"authorizesAccept":False,
    "mayRecordCompletedTrade":False,"mayReportProfit":False,
    "maySendDiscordWebhook":False,"mayUseForStrategyLearning":False,
    "tradeOutcome":"UNKNOWN",
}
class Reject(ValueError): pass

def _utc(iso:str)->int:
    if not isinstance(iso,str) or not re.fullmatch(
        r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ",iso):
        raise Reject("TIMESTAMP_NOT_UTC_ISO")
    return int(datetime.fromisoformat(iso.replace("Z","+00:00")).timestamp())

def _deny(reason:str)->dict:
    return {"schema":SCHEMA,"status":"INCONCLUSIVE","reason":reason,
            "observedPublisherUtc":None,
            "previousPublisherUtc":PRIOR,
            "canonicalSourcePageCount":0,
            "rowChangeCount":None,"canonicalParsedRecordDigest":None,
            "sourceHtmlSha256":{}, "rawPagePublishedDates":{},
            "fixedPriorExpiryPreserved":True,**DENY}

def _rowcanon(rows:list)->list:
    out=[]
    names=set()
    for r in rows:
        if not isinstance(r,dict) or set(r)!={
            "name","supremeValue","supremeLabel","demand","stability"
        }:
            raise Reject("UNEXPECTED_PUBLISHER_RECORD_SHAPE")
        name=r["name"]
        value=r["supremeValue"]
        demand=r["demand"]
        stability=r["stability"]
        if not isinstance(name,str) or not 1<=len(name)<=128 or re.search(
            r"[\x00-\x1f\x7f]",name):
            raise Reject("BAD_PUBLIC_WEAPON_NAME")
        folded=name.casefold()
        if folded in names: raise Reject("DUPLICATED_PUBLIC_WEAPON_NAME")
        names.add(folded)
        if value is not None and (
          type(value) not in (int,float) or not 0<value<1e9):
            raise Reject("BAD_PUBLIC_VALUE")
        if type(demand) is not int or not 0<=demand<=11 or not isinstance(
            stability,str) or not stability or len(stability)>80:
            raise Reject("BAD_PUBLIC_DEMAND_OR_STABILITY")
        out.append((folded,value,demand,stability))
    return sorted(out)

def _hashrows(rows:dict)->str:
    return hashlib.sha256(json.dumps(rows,sort_keys=True,ensure_ascii=True,
             separators=(",",":")).encode()).hexdigest()

def audit_publication(
    captures:dict,
    *,
    prior_published:str,
    prior_records:dict,
    evaluation_utc:str,
    parse_page:Callable[[str,str],tuple[list,str]],
)->dict:
    """Compare separately acquired, exact canonical raw HTML to a PINNED prior.

    Success means only 'research evidence'. New publisher date remains
    REVIEW_REQUIRED, never publishes to a trader.
    """
    try:
        if not callable(parse_page): raise Reject("TRUSTED_PARSER_MISSING")
        now=_utc(evaluation_utc)
        old=_utc(prior_published)
        if prior_published!=PRIOR:
            raise Reject("UNEXPECTED_PREVIOUS_PUBLISHER_VERSION")
        if not isinstance(prior_records,dict) or set(prior_records)!=set(PATHS):
            raise Reject("PINNED_BASELINE_RECORDS_MISSING")
        prior={p:_rowcanon(prior_records[p]) for p in PATHS}
        if any(len(prior[p])!=PAGE_COUNTS[p] for p in PATHS):
            raise Reject("PINNED_BASELINE_CATEGORY_COVERAGE_CHANGED")
        if not isinstance(captures,dict) or set(captures)!=set(PATHS):
            raise Reject("THREE_CANONICAL_SOURCE_PAGES_REQUIRED")
        origins=set()
        parsed={}
        hashes={}
        stamps={}
        for page in PATHS:
            item=captures[page]
            if not isinstance(item,dict) or set(item)!={
                "url","html","httpStatus","retrievedAtUtc"
            }:
                raise Reject("SOURCE_EVIDENCE_FIELDS_INVALID")
            url=item["url"]
            if type(url) is not str:
                raise Reject("SOURCE_URL_MISSING")
            dest=urlsplit(url)
            if (dest.scheme!="https" or dest.hostname not in HOSTS
                or dest.port not in (None,443)
                or dest.path!=PATHS[page] or dest.query or dest.fragment
                or dest.username or dest.password):
                raise Reject("NONCANONICAL_OR_STALE_ALIAS_URL")
            origins.add(dest.hostname)
            if item["httpStatus"]!=200:
                raise Reject("SOURCE_FETCH_HTTP_NOT_200")
            b=item["html"]
            if type(b) is not bytes or not 1000<len(b)<800000:
                raise Reject("SOURCE_RAW_HTML_MISSING_OR_INCOMPLETE")
            observed=_utc(item["retrievedAtUtc"])
            if observed>now or observed<old:
                raise Reject("IMPOSSIBLE_SOURCE_OBSERVATION_TIME")
            decoded=b.decode("utf-8")
            rows,published=parse_page(decoded,page)
            stamp=_utc(published)
            if stamp>observed:
                raise Reject("PUBLISHER_STAMP_NEWER_THAN_CAPTURE")
            if len(rows)!=PAGE_COUNTS[page]:
                raise Reject("NEW_OR_MISSING_WEAPONS_REVIEW_REQUIRED")
            parsed[page]=_rowcanon(rows)
            hashes[page]=hashlib.sha256(b).hexdigest()
            stamps[page]=published
        if len(origins)!=1:
            raise Reject("MIXED_SOURCE_ORIGIN_NEEDS_REVIEW")
        if len(set(stamps.values()))!=1:
            raise Reject("MIXED_PUBLICATION_TIMESTAMPS")
        current=next(iter(stamps.values()))
        changed=sum(
            a!=b for p in PATHS for a,b in zip(prior[p],parsed[p])
        )
        candidate={
            "schema":SCHEMA,
            "observedPublisherUtc":current,
            "previousPublisherUtc":prior_published,
            "canonicalSourcePageCount":3,
            "rowChangeCount":changed,
            "canonicalParsedRecordDigest":_hashrows(parsed),
            "sourceHtmlSha256":hashes,
            "rawPagePublishedDates":stamps,
            "fixedPriorExpiryPreserved":True,
            **DENY
        }
        if _utc(current)<old:
            candidate.update(status="INCONCLUSIVE",
                             reason="STALE_PUBLISHER_VERSION_REJECTED")
        elif current==prior_published:
            candidate.update(status="NO_NEW_PUBLISHER_PUBLICATION",
                reason=("SOURCE_PUBLISHER_DATE_UNCHANGED_NO_REFRESH"
                        if changed==0 else
                        "UNCHANGED_PUBLISHER_DATE_BUT_ROW_DRIFT_REVIEW_REQUIRED"))
        else:
            candidate.update(status="NEW_PUBLISHER_CANDIDATE_REVIEW_REQUIRED",
                reason=("NEW_PUBLICATION_DATE_AND_RESEARCH_ROWS_CHANGED"
                        if changed else
                        "NEW_PUBLICATION_DATE_WITHOUT_RECORD_CHANGE_REVIEW_REQUIRED"))
        # This output NEVER changes Stage102 archive, updates its expiry,
        # updates a production value module or enables final Accept.
        return candidate
    except (Reject,ValueError,KeyError,TypeError,UnicodeError,
            OverflowError,AttributeError):
        return _deny("CANONICAL_SOURCE_OR_PUBLISHER_EVIDENCE_INVALID")
