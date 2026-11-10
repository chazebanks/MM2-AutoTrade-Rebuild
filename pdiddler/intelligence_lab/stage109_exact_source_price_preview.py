"""Stage109 purely illustrative, published-site-value research from client raw keys.

NEVER current game ownership, an authenticated market quote, unique instance,
server trade session, completed trade or automatic offer/Accept authority.
Site-local numeric checker IDs are not required to join exact PUBLIC names.
All source bytes must match immutable original reviewed Git blob digests;
the original Stage69 HTML parser itself is verified BEFORE execution.
"""
from __future__ import annotations

from datetime import datetime, timezone
import hashlib
import math
import re
import types
from pdiddler.intelligence_lab.stage108_strict_public_name_coverage import (
    parse_registry, compare_public_names, Reject as RegistryReject
)

SCHEMA="gingerscope-stage109-exact-public-source-client-preview-v1"
REGISTRY_BLOB="40e2a0ff01b70b2d0181c62cae347a08da82bcb8"
PARSER_BLOB="d5843a57f34078cbe7213aa78a4aa12a5775c016"
PAGE_BLOBS={
    "ancient":"ce8178ab9579e8782d8f72a6dac051756a728506",
    "godly":"d3cf222a8e10cff3a9fb051b16188192389c4b2d",
    "chroma":"6c77624cac3df96168b008e9bc8eca68a2d78cf9",
}
PUBLISHER="2026-11-09T18:58:33Z"
CAPTURE_EXPIRES="2026-11-10T22:26:48Z"
COUNTS={"ancient":16,"godly":128,"chroma":46}
ALLOW_METADATA={"ItemName","ItemType","Rarity","Chroma"}


def _blob(raw:bytes)->str:
    return hashlib.sha1(b"blob "+str(len(raw)).encode()+b"\0"+raw).hexdigest()


def _report(status:str,reason:str,**additional)->dict:
    return {
        "schema":SCHEMA,"status":status,"reason":reason,
        "readOnly":True,"publicHistoricalOnly":True,
        "sourcePublisherUtc":PUBLISHER,
        "sourceFixedExpiryUtc":CAPTURE_EXPIRES,
        "sourceValueType":"HISTORICAL_PUBLISHER_REFERENCE_NOT_A_TRADE_QUOTE",
        "ourPublicReferenceValue":None,"theirPublicReferenceValue":None,
        "illustrativeDifference":None,
        "ourSlotCount":0,"theirSlotCount":0,
        "ourCopyCount":0,"theirCopyCount":0,
        "gameServerCatalogAuthenticated":False,
        "rawKeyToCurrentSiteItemVerified":False,
        "numericSupremeCheckerIdVerified":False,
        "rawItemIdConfirmed":False,
        "currentPricesVerified":False,
        "priceForTradeVerified":False,
        "serverAttestation":False,"serverCompletionProven":False,
        "authorizesTrade":False,"authorizesAccept":False,
        "mayRecordCompletedTrade":False,
        "mayReportProfit":False,"maySendDiscordWebhook":False,
        "mayUseForStrategyLearning":False,
        "tradeOutcome":"UNKNOWN",
        **additional,
    }


def _epoch(value:str)->int:
    if not isinstance(value,str) or not re.fullmatch(
        r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ",value
    ):
        raise ValueError("invalid UTC datetime")
    return int(datetime.fromisoformat(value.replace("Z","+00:00")).timestamp())


def _original_source(registry:bytes,parser:bytes,html:dict):
    if (not isinstance(registry,bytes) or _blob(registry)!=REGISTRY_BLOB or
        not isinstance(parser,bytes) or _blob(parser)!=PARSER_BLOB or
        not isinstance(html,dict) or set(html)!=set(PAGE_BLOBS) or
        any(not isinstance(html[p],bytes) or
            _blob(html[p])!=PAGE_BLOBS[p] for p in PAGE_BLOBS)):
        raise ValueError("original source not verified")

    # Original parser is executable only AFTER its exact Git blob is verified.
    module=types.ModuleType("_stage109_original_stage69_public_parser")
    exec(compile(parser,"PINNED_ORIGINAL_STAGE69.py","exec"),module.__dict__)
    parse_page=getattr(module,"parse_page",None)
    if not callable(parse_page):
        raise ValueError("original parser missing")
    registry_rows=parse_registry(registry)
    page_rows={}
    for page in COUNTS:
        rows,published=parse_page(html[page].decode("utf-8"),page)
        if published!=PUBLISHER or len(rows)!=COUNTS[page]:
            raise ValueError("original publisher or coverage changed")
        page_rows[page]=rows
    if compare_public_names(
        registry_rows,page_rows
    )["casefoldExactPublicNameCount"]!=189:
        raise ValueError("incomplete original public correspondence")
    return {e["key"]:e for e in registry_rows}, {
        (page,row["name"].casefold()):row for page,rows in page_rows.items()
        for row in rows
    }


def _side(items,catalogue,registry,site):
    if (not isinstance(items,list) or len(items)>4 or
        not isinstance(catalogue,dict)):
        raise ValueError("invalid client input")
    used=set()
    amount=0
    copies=0
    for row in items:
        if not isinstance(row,dict) or set(row)!={"rawKey","quantity"}:
            raise ValueError("untrusted offer row")
        key,quantity=row["rawKey"],row["quantity"]
        if (not isinstance(key,str) or not key or key in used or
            type(quantity) is not int or not 1<=quantity<=1_000_000):
            raise ValueError("invalid client raw key or stacked quantity")
        used.add(key)
        public=registry.get(key)
        meta=catalogue.get(key)
        if (not isinstance(public,dict) or not isinstance(meta,dict) or
            set(meta)!=ALLOW_METADATA or
            meta["ItemName"]!=public["name"] or
            meta["ItemType"]!=public["type"] or
            meta["Rarity"]!=public["rarity"] or
            type(meta["Chroma"]) is not bool or
            meta["Chroma"]!=public["chroma"]):
            raise ValueError("local client catalog does not match public source")
        name=("Chroma "+public["name"]) if public["chroma"] else public["name"]
        priced=site.get((public["page"],name.casefold()))
        if priced is None:
            raise ValueError("no exact source site public-name record")
        value=priced.get("supremeValue")
        if type(value) not in (int,float) or (
            not math.isfinite(value) or value<=0 or value>1_000_000_000
        ):
            raise ValueError("source no numeric public value")
        amount+=value*quantity
        copies+=quantity
        if amount>1_000_000_000_000_000_000:
            raise ValueError("research subtotal too large")
    return amount,copies


def preview(registry_bytes:bytes,parser_bytes:bytes,html_pages:dict,
            local_client_catalogue:dict,our_rows:list,their_rows:list,
            evaluated_utc:str)->dict:
    """Pure deterministic, de-identified aggregate; NEVER a trading decision."""
    try:
        if _epoch(evaluated_utc) < _epoch(PUBLISHER):
            return _report("INCONCLUSIVE","IMPOSSIBLE_PRE_PUBLICATION_OBSERVATION")
        if _epoch(evaluated_utc)>=_epoch(CAPTURE_EXPIRES):
            return _report("INCONCLUSIVE","FIXED_ORIGINAL_PUBLIC_CAPTURE_EXPIRED")
        if (not isinstance(our_rows,list) or not isinstance(their_rows,list)
            or not isinstance(local_client_catalogue,dict)):
            return _report("INCONCLUSIVE","CLIENT_CATALOGUE_OR_OFFERS_UNAVAILABLE")
        # Even hypothetical research view cannot suggest giving away the
        # user's permanently protected Gingerscope, regardless of listed gain.
        if any(isinstance(r,dict) and r.get("rawKey")=="Gingerscope"
               for r in our_rows):
            return _report("INCONCLUSIVE","PROTECTED_GINGERSCOPE_OUTGOING")
        registry,site=_original_source(registry_bytes,parser_bytes,html_pages)
        ours,our_copies=_side(our_rows,local_client_catalogue,registry,site)
        theirs,their_copies=_side(their_rows,local_client_catalogue,registry,site)
        if not our_rows or not their_rows:
            return _report("INCONCLUSIVE","NO_BOTH_SIDED_CLIENT_OFFER")
        return _report(
            "PUBLIC_SOURCE_INDICATIVE_TOTALS_CLIENT_UNATTRIBUTED",
            "EXACT_HISTORICAL_PUBLIC_NAME_NOT_CURRENT_ITEM_OR_PRICE",
            ourPublicReferenceValue=ours,
            theirPublicReferenceValue=theirs,
            illustrativeDifference=theirs-ours,
            ourSlotCount=len(our_rows),theirSlotCount=len(their_rows),
            ourCopyCount=our_copies,theirCopyCount=their_copies,
        )
    except (ValueError,TypeError,KeyError,AttributeError,OverflowError,
            UnicodeError,RegistryReject):
        return _report("INCONCLUSIVE","ORIGINAL_PUBLIC_OR_CLIENT_EVIDENCE_UNVERIFIED")
