"""Stage81: review historical 190-row Supreme roster ↔ actual first-party public item slugs.

Only immutable archived public material. Never treats the old site-local
numeric checker index as a first-party ID or as a real MM2 Owned raw item ID.
No price valuation, trading, settlement, reporting or market learning.
"""
from __future__ import annotations

from collections import Counter
from datetime import datetime, timedelta, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import re

SCHEMA = "gingerscope-stage81-pinned-first-party-slug-coverage-v1"
HISTORICAL_SHA = "a85af4f6137278540e1fed0c27e7e801553e4111"
PARSER_SHA = "754fbe3189d5108272c32a27fc52bf3834011d38"
HTML_SHA = {
    "ancient": "7e11a2d835eadbb522d351bdabe393a7c9688f4b",
    "godly": "2e4a0c1b8df894f9037e737ba80919b9b2d0c9ae",
    "chroma": "0d2d156d9d9c499ef0e1213376796c1a916e6ce1",
}
SLUG_PAGES = {"ancient":"ancients", "godly":"godlies", "chroma":"chromas"}
SOURCE_COUNTS = {"ancient":16, "godly":128, "chroma":46}
PUBLIC_SLUG_COUNTS = {"ancient":15, "godly":128, "chroma":46}
PUBLICATION_UTC = "2026-11-06T15:56:07+00:00"
FLAGS = {
    "readOnly":True, "researchOnly":True, "clientInventoryRead":False,
    "authenticatedOwnedInventory":False, "currentGameCatalogueAuthenticated":False,
    "websiteOriginServerAttested":False, "numericSupremeCheckerIdVerified":False,
    "rawGameToWebsiteSlugVerified":False, "rawGameToNumericCheckerVerified":False,
    "sourcePublisherFresh":False, "currentPricesVerified":False,
    "authorizesTrade":False, "authorizesAccept":False,
    "mayRecordCompletedTrade":False, "mayRecordRejectedTrade":False,
    "mayReportProfit":False, "maySendDiscordWebhook":False,
    "mayUseForStrategyLearning":False, "serverCompletionProven":False,
    "tradeOutcome":"UNKNOWN",
}

def git_blob(content:bytes)->str:
    return hashlib.sha1(b"blob "+str(len(content)).encode()+b"\0"+content).hexdigest()

def result(status:str, reason:str, **metrics)->dict:
    return {"schema":SCHEMA, "status":status, "reason":reason, **FLAGS, **metrics}

def _one_page_pub(blob:bytes)->datetime:
    source=blob.decode("utf-8")
    stamps=set(re.findall(r'data-updated-iso="([^"]+)"',source))
    if len(stamps)!=1:
        raise ValueError("page publisher timestamp missing or ambiguous")
    d=datetime.fromisoformat(next(iter(stamps)).replace("Z","+00:00"))
    if d.tzinfo is None or d.utcoffset() is None:
        raise ValueError("publisher timestamp has no offset")
    return d.astimezone(timezone.utc)

def _parse_reviewed_module(src:bytes):
    # Only code from our OWN previously reviewed Stage77 module, exact Git blob,
    # NOT from any third-party website or game source.
    if git_blob(src)!=PARSER_SHA:
        raise ValueError("Stage77 parser changed")
    import tempfile
    with tempfile.TemporaryDirectory() as directory:
        p=Path(directory)/"st81_pinned_parser.py"
        p.write_bytes(src)
        spec=importlib.util.spec_from_file_location("_stage81_checked_pinned_parser",p)
        if spec is None or spec.loader is None:
            raise ValueError("reviewed parser unavailable")
        module=importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

def run(archive:bytes, first_party:dict[str,bytes], parser_src:bytes, *,
        asof:str="2026-11-09T20:00:00+00:00")->dict:
    if type(archive) is not bytes or type(parser_src) is not bytes or type(first_party) is not dict:
        return result("INCONCLUSIVE","INPUT_SOURCE_TYPES_INVALID")
    if git_blob(archive)!=HISTORICAL_SHA or git_blob(parser_src)!=PARSER_SHA:
        return result("INCONCLUSIVE","ORIGINAL_ARCHIVE_OR_REVIEWED_PARSER_HASH_CHANGED")
    if set(first_party)!=set(HTML_SHA) or any(type(v) is not bytes or git_blob(v)!=HTML_SHA[k] for k,v in first_party.items()):
        return result("INCONCLUSIVE","THREE_ORIGINAL_WEBSITE_HTML_BLOB_HASHES_INVALID")
    try:
        d=datetime.fromisoformat(asof.replace("Z","+00:00"))
        if d.tzinfo is None or d.utcoffset() is None:
            raise ValueError("evaluation time needs timezone")
        if d.astimezone(timezone.utc)<datetime.fromisoformat(PUBLICATION_UTC):
            raise ValueError("as-of date precedes publication")
        source=json.loads(archive)
        if source.get("schemaVersion")!=1 or len(source.get("rows",[]))!=190:
            raise ValueError("historical source roster shape")
        reviewed=_parse_reviewed_module(parser_src)
        pages={}
        publisher=[]
        for category, raw in first_party.items():
            items=reviewed.website_records(raw,SLUG_PAGES[category])
            if len(items)!=PUBLIC_SLUG_COUNTS[category]:
                raise ValueError("reviewed first-party item slug coverage changed")
            if len(set(items))!=len(items):
                raise ValueError("duplicate website slug")
            pubs=_one_page_pub(raw)
            publisher.append(pubs)
            pages[category]=items
        if len(set(publisher))!=1 or publisher[0]!=datetime.fromisoformat(PUBLICATION_UTC):
            raise ValueError("site publisher clock drift")
        # Site detail row names must be unique, not merely URL slugs unique.
        canonical={}
        for page, items in pages.items():
            for slug,(display_name,base_class) in items.items():
                if not isinstance(slug,str) or not isinstance(display_name,str):
                    raise ValueError("untrusted website item type")
                key=(page,display_name.casefold())
                if key in canonical:
                    raise ValueError("duplicate item display name within page")
                canonical[key]=(slug,base_class)
        expected=Counter()
        observed_ids=set()
        matched=0; priceless=0; false_site_local=0
        for row in source["rows"]:
            if type(row) is not dict:
                raise ValueError("nonrecord historical roster entry")
            page,name,num=row.get("page"),row.get("name"),row.get("id")
            if page not in SOURCE_COUNTS or not isinstance(name,str) or not name:
                raise ValueError("historical row name/category malformed")
            if not isinstance(num,str) or not re.fullmatch(r"[0-9]+",num):
                raise ValueError("historical numeric checker index missing")
            if (page,num) in observed_ids:
                raise ValueError("duplicate historical checker index")
            observed_ids.add((page,num))
            expected[page]+=1
            if page=="ancient" and name=="Nik's Scythe":
                if row.get("supremeValue") is not None:
                    raise ValueError("Nik's Scythe priceless exception drift")
                if (page,name.casefold()) in canonical:
                    raise ValueError("unreviewed first-party Nik slug appeared")
                priceless+=1
                continue
            identity=canonical.get((page,name.casefold()))
            if identity is None:
                raise ValueError("historical canonical name not unique in first-party HTML")
            slug,base_class=identity
            expected_base="Ancient" if page=="ancient" else "Godly" if page=="godly" else None
            if expected_base is not None and base_class!=expected_base:
                raise ValueError("website rarity category mismatch")
            if page=="chroma" and base_class not in ("Ancient","Godly"):
                raise ValueError("website Chroma class mismatch")
            # Numeric old checker ID is NOT in first-party website record.
            # This validates the name/category bridge ONLY, never the number.
            false_site_local+=int(slug==num)
            matched+=1
        if dict(expected)!=SOURCE_COUNTS or matched!=189 or priceless!=1 or len(canonical)!=189:
            raise ValueError("190 roster-to-189 slug partition invalid")
        published=publisher[0]
        expiry=published+timedelta(hours=72)
        asof_dt=d.astimezone(timezone.utc)
    except (ValueError,UnicodeError,TypeError,KeyError,AttributeError,OverflowError,
            json.JSONDecodeError,ImportError,RuntimeError,RecursionError):
        return result("INCONCLUSIVE","ARCHIVED_PUBLIC_SLUG_OR_DATE_REVIEW_FAILED")
    return result(
        "PUBLIC_WEBSITE_SLUG_COVERAGE_CONFIRMED_RESEARCH_ONLY",
        "LEGACY_NUMERIC_CHECKER_INDEX_NOT_FIRST_PARTY_OR_GAME_ID_PROOF",
        archivedRosterRows=sum(expected.values()),
        firstPartyPublicSlugs=matched,
        pricelessNoSlugRows=priceless,
        byCategory={p:{"roster":SOURCE_COUNTS[p],"websiteSlugs":PUBLIC_SLUG_COUNTS[p]}
                    for p in ("ancient","godly","chroma")},
        historicalNumericIdCoincidentallyMatchesWebsiteSlug=false_site_local,
        publisherTimestampUtc=published.isoformat().replace("+00:00","Z"),
        hardPublisherExpiryUtc=expiry.isoformat().replace("+00:00","Z"),
        observedAsOfUtc=asof_dt.isoformat().replace("+00:00","Z"),
        publisherOlderThan72Hours=asof_dt>=expiry,
        currentAuthoritativeValueCount=0,
    )
