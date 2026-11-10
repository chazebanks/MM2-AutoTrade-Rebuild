"""Stage108: immutable historical MM2 catalogue ↔ public Supreme NAME coverage.

RESEARCH ONLY. The Stage83 Lua registry is not a current game server catalogue;
Nov9 official Supreme HTML pages are historical, not a current trading quote.
Numeric Supreme checker IDs are website-local, NOT MM2 raw weapon identifiers.
NO arbitrary string normalization, fuzzy matching or user-injected aliases.
Never export any player's raw keys, inventory, item values or account IDs.
"""
from __future__ import annotations

import hashlib
import re

SCHEMA="gingerscope-stage108-strict-public-name-coverage-v1"
REGISTRY_BLOB="40e2a0ff01b70b2d0181c62cae347a08da82bcb8"
SOURCE_BLOBS={
    "ancient":"ce8178ab9579e8782d8f72a6dac051756a728506",
    "godly":"d3cf222a8e10cff3a9fb051b16188192389c4b2d",
    "chroma":"6c77624cac3df96168b008e9bc8eca68a2d78cf9",
}
SOURCE_PUBLISHER="2026-11-09T18:58:33Z"
REGISTRY_PUBLISHER="2026-11-06T15:56:07Z"
COUNTS={"ancient":16,"godly":128,"chroma":46}
ENTRY_PATTERN=re.compile(
    r'^\s*\["([^"\n]+)"\]\s*=\s*\{"([^"\n]+)",\s*'
    r'"([^"\n]+)",\s*"([^"\n]+)",\s*(true|false),\s*'
    r'"([^"\n]+)",\s*"([^"\n]+)"\},?\s*$',re.M,
)

class Reject(ValueError):
    pass


def _gitblob(raw:bytes)->str:
    return hashlib.sha1(b"blob "+str(len(raw)).encode()+b"\0"+raw).hexdigest()


def _deny(reason:str,**extra)->dict:
    return {
        "schema":SCHEMA,"status":"INCONCLUSIVE","reason":reason,
        "readOnly":True,"researchOnly":True,"clientOnly":False,
        "sourceStatus":"PINNED_HISTORICAL_NAME_ONLY",
        "currentGameCatalogAuthenticated":False,
        "currentPricesVerified":False,"priceForTradeVerified":False,
        "numericSupremeCheckerIdVerified":False,
        "rawItemIdConfirmed":False,
        "rawKeyToCurrentSiteItemVerified":False,
        "serverAttestation":False,"serverCompletionProven":False,
        "authorizesTrade":False,"authorizesAccept":False,
        "mayReportProfit":False,"maySendDiscordWebhook":False,
        "mayUseForStrategyLearning":False,"tradeOutcome":"UNKNOWN",
        **extra,
    }


def parse_registry(source:bytes)->list[dict]:
    if not isinstance(source,bytes):
        raise Reject("REGISTRY_BYTES_MISSING")
    if _gitblob(source)!=REGISTRY_BLOB:
        raise Reject("REGISTRY_HISTORICAL_BLOB_MISMATCH")
    s=source.decode("utf-8")
    if ('publisherUtc = "'+REGISTRY_PUBLISHER+'"') not in s:
        raise Reject("REGISTRY_PUBLISHER_UNEXPECTED")
    rows=[]
    for m in ENTRY_PATTERN.finditer(s):
        key,name,item_type,rarity,chroma,page,_public_slug=m.groups()
        rows.append({"key":key,"name":name,"type":item_type,
                     "rarity":rarity,"chroma":chroma=="true","page":page})
    if len(rows)!=189:
        raise Reject("STAGE83_REGISTRY_COVERAGE_CHANGED")
    return rows


def compare_public_names(entries:list[dict],source:dict)->dict:
    """Compare exact category+variant+case-folded source names only.

    Case differences are separately reported; punctuation, apostrophes,
    synonyms, abbreviated display names and source-local numeric IDs NEVER
    cause an automatic match. Raises Reject on ambiguous source identity.
    """
    if not isinstance(entries,list) or not isinstance(source,dict) or (
        set(source)!=set(COUNTS)
    ):
        raise Reject("PUBLIC_NAME_COVERAGE_INPUT_INVALID")
    source_names={}
    for page,rows in source.items():
        if not isinstance(rows,list):
            raise Reject("PUBLIC_SOURCE_RECORD_SHAPE_INVALID")
        source_names[page]={}
        for row in rows:
            if (not isinstance(row,dict) or
                not isinstance(row.get("name"),str) or
                not 1<=len(row["name"])<=128 or
                re.search(r"[\x00-\x1f\x7f]",row["name"])):
                raise Reject("PUBLIC_SOURCE_NAME_INVALID")
            name=row["name"]
            lower=name.casefold()
            if lower in source_names[page]:
                raise Reject("DUPLICATE_PUBLIC_SOURCE_NAME")
            source_names[page][lower]=name
    raw_keys=set()
    known_targets=set()
    matched_targets=set()
    case_sensitive=case_only=unresolved=0
    for e in entries:
        if not isinstance(e,dict) or any(x not in e for x in (
            "key","name","type","rarity","chroma","page"
        )):
            raise Reject("REGISTRY_ROW_INVALID")
        key,name,typ,rarity,chroma,page=(e[x] for x in (
            "key","name","type","rarity","chroma","page"
        ))
        if (not isinstance(key,str) or not 1<=len(key)<=128 or
            not isinstance(name,str) or not 1<=len(name)<=128 or
            typ not in ("Knife","Gun") or rarity not in ("Godly","Ancient") or
            type(chroma) is not bool or page not in COUNTS or
            re.search(r"[\x00-\x1f\x7f]",key+name) or
            (chroma and page!="chroma") or
            (not chroma and page=="chroma") or
            (page=="ancient" and rarity!="Ancient") or
            (page=="godly" and rarity!="Godly") or
            (chroma and name.casefold().startswith("chroma "))):
            raise Reject("REGISTRY_CATEGORY_VARIANT_INVALID")
        if key in raw_keys:
            raise Reject("DUPLICATE_REGISTRY_RAW_KEY")
        raw_keys.add(key)
        canonical=("Chroma "+name) if chroma else name
        target=(page,canonical.casefold())
        if target in known_targets:
            raise Reject("MULTIPLE_RAW_KEYS_SHARE_PUBLIC_SOURCE_NAME")
        known_targets.add(target)
        named=source_names[page].get(target[1])
        if named is None:
            unresolved+=1
            continue
        matched_targets.add(target)
        if named==canonical:
            case_sensitive+=1
        else:
            case_only+=1
    return {
        "registryPublicKeyCount":len(entries),
        "supremeOfficialWeaponRowCount":sum(map(len,source.values())),
        "caseExactPublicNameCount":case_sensitive,
        "caseOnlyDifferences":case_only,
        "casefoldExactPublicNameCount":case_sensitive+case_only,
        "unresolvedRegistryNameCount":unresolved,
        "unmatchedSupremeSourceNameCount":sum(map(len,source.values()))
                                        -len(matched_targets),
    }


def audit(registry_bytes:bytes,html_pages:dict,parse_page)->dict:
    if not isinstance(registry_bytes,bytes) or not isinstance(html_pages,dict):
        return _deny("PUBLIC_ORIGINAL_SOURCE_BYTES_MISSING")
    if not callable(parse_page) or set(html_pages)!=set(COUNTS):
        return _deny("CANONICAL_SOURCE_PARSER_OR_PAGES_MISSING")
    if _gitblob(registry_bytes)!=REGISTRY_BLOB or any(
        not isinstance(html_pages[p],bytes) or
        _gitblob(html_pages[p])!=SOURCE_BLOBS[p] for p in COUNTS
    ):
        return _deny("IMMUTABLE_PUBLIC_SOURCE_CHANGED")
    try:
        entries=parse_registry(registry_bytes)
        parsed={}
        for page in COUNTS:
            rows,published=parse_page(html_pages[page].decode("utf-8"),page)
            if not isinstance(rows,list) or len(rows)!=COUNTS[page]:
                raise Reject("FIRST_PARTY_WEAPON_PAGE_COVERAGE_CHANGED")
            if published!=SOURCE_PUBLISHER:
                raise Reject("SOURCE_PUBLISHER_VERSION_UNEXPECTED")
            parsed[page]=rows
        counts=compare_public_names(entries,parsed)
    except (Reject,UnicodeError,ValueError,TypeError,KeyError,AttributeError):
        return _deny("ORIGINAL_PUBLIC_CATALOGUE_NAME_BRIDGE_INCONCLUSIVE")
    return _deny("HISTORICAL_ONLY_NO_GAME_OR_PRICE_AUTHORITY",
                 status="HISTORICAL_PUBLIC_NAME_COVERAGE_PARTIAL",
                 registryReferencePublisherUtc=REGISTRY_PUBLISHER,
                 officialSourcePublisherUtc=SOURCE_PUBLISHER,
                 **counts)
