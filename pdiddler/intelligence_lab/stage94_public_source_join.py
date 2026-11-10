"""Stage94: strict PUBLIC-ONLY bridge between original Stage82 historical MM2
catalogue -> Supreme slugs and the actual Stage84 Nov9 source publication.

No Roblox client, account holdings, trading, price-for-trade, or automated
Accept. The output is a RESEARCH reference, not authenticated raw game ID.
Inputs must be independently rebuilt from SHA-pinned original source bytes
by the caller; this pure join cannot authenticate arbitrary supplied objects.
"""
from __future__ import annotations
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
import math
import re

SCHEMA="gingerscope-stage94-public-catalogue-new-publisher-research-join-v1"
OLD_SCHEMA="gingerscope-stage82-pinned-public-game-to-website-slug-candidates-v1"
NEW_SCHEMA="gingerscope-stage84-new-first-party-publication-research-only-v1"
PUBLISHER="2026-11-09T18:58:33Z"
EXPIRES="2026-11-10T22:26:48Z"
CATEGORY={"ancient":"ancients","godly":"godlies","chroma":"chromas"}
EXPECTED={"ancient":15,"godly":128,"chroma":46}
NEW_BLOBS={"ancient":"ce8178ab9579e8782d8f72a6dac051756a728506",
           "godly":"d3cf222a8e10cff3a9fb051b16188192389c4b2",
           "chroma":"6c77624cac3df96168b008e9bc8eca68a2d78cf9"}
DENIED={
 "readOnly":True,"researchOnly":True,"clientOnly":False,
 "actualOwnedInventoryRead":False,"authenticatedOwnedInventory":False,
 "serverAttestation":False,"serverCompletionProven":False,
 "currentGameCatalogueAuthenticated":False,
 "numericSupremeCheckerIdVerified":False,
 "rawGameToMarketIdentityAuthenticated":False,
 "priceForTradeVerified":False,"currentPricesVerified":False,
 "authorizesTrade":False,"authorizesAccept":False,
 "mayRecordCompletedTrade":False,"mayReportProfit":False,
 "maySendDiscordWebhook":False,"mayUseForStrategyLearning":False,
 "tradeOutcome":"UNKNOWN",
}
class JoinRejected(ValueError):
    pass
def _deny(why):
    return {"schema":SCHEMA,"status":"INCONCLUSIVE","reason":why,
            "sourceResearchFreshAtEvaluation":False,
            "publicCandidates":0,"rows":[],**DENIED}
def _require(x,why):
    if not x: raise JoinRejected(why)
def _time(s):
    _require(type(s) is str and re.fullmatch(
      r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z",s),"TIMESTAMP_MALFORMED")
    return int(datetime.fromisoformat(s.replace("Z","+00:00")).timestamp())
def join_public_sources(old,updated,*,at_epoch):
    """Full 189-link historical join; no current ownership or trade authority."""
    try:
        _require(type(at_epoch) is int and 0<at_epoch<9999999999,
                 "EVALUATION_CLOCK_INVALID")
        _require(type(old) is dict and type(updated) is dict,
                 "SOURCE_OBJECTS_REQUIRED")
        _require(old.get("schema")==OLD_SCHEMA and
                 old.get("status")=="PUBLIC_GAME_KEY_TO_WEBSITE_SLUG_CANDIDATES_ONLY" and
                 old.get("researchOnly") is True and old.get("readOnly") is True and
                 old.get("currentPricesVerified") is False and
                 old.get("authenticatedOwnedInventory") is False and
                 old.get("authorizesTrade") is False and
                 old.get("authorizesAccept") is False,
                 "OLD_PUBLIC_REFERENCE_NOT_REVIEWED")
        candidates=old.get("candidates")
        _require(type(candidates) is dict and len(candidates)==189 and
                 old.get("matchingPublicGameWeaponKeys")==189 and
                 old.get("eligiblePublicGameKeys")==200 and
                 old.get("publicGameKeysAbsentFromOldSupremeRoster")==10 and
                 old.get("pricelessNoOfficialSlug")==1,
                 "OLD_PUBLIC_REFERENCE_COVERAGE_INCOMPLETE")
        digest=hashlib.sha256(json.dumps(candidates,sort_keys=True,
                       separators=(",",":"),ensure_ascii=True).encode()).hexdigest()
        _require(digest==old.get("candidateRegistrySha256"),
                 "OLD_PUBLIC_REFERENCE_CHANGED")
        _require(updated.get("stage84Schema")==NEW_SCHEMA and
                 updated.get("researchOnly") is True and
                 updated.get("currentPricesVerified") is False and
                 updated.get("numericSupremeCheckerIdVerified") is False and
                 updated.get("rawGameMappingsVerified") is False and
                 updated.get("authorizesTrade") is False and
                 updated.get("authorizesAccept") is False and
                 updated.get("serverCompletionProven") is False and
                 updated.get("publisherWithin72HoursAtAcquisition") is True,
                 "NEW_SOURCE_PRICE_AUTHORITY_OR_ORIGIN_INVALID")
        _require(updated.get("publishedAt")==PUBLISHER and
                 updated.get("expiresAt")==EXPIRES,
                 "NEW_PUBLISHER_OR_RECEIPT_EXPIRY_CHANGED")
        sources=updated.get("sources")
        _require(type(sources) is dict and set(sources)==set(CATEGORY),
                 "NEW_SOURCE_PROVENANCE_MISSING")
        for p,plural in CATEGORY.items():
            src=sources[p]
            _require(type(src) is dict and
                     src.get("url")==f"https://supremevalues.com/mm2/{plural}" and
                     src.get("publishedAt")==PUBLISHER and
                     src.get("sourceGitBlobSha")==NEW_BLOBS[p] and
                     type(src.get("sha256")) is str and
                     len(src["sha256"])==64,
                     "NEW_SOURCE_RECORD_CHANGED")
            _require(_time(src.get("observedAt"))>=_time(PUBLISHER) and
                     _time(src.get("observedAt"))<_time(EXPIRES),
                     "NEW_SOURCE_OBSERVATION_INVALID")
        rows=updated.get("rows")
        _require(type(rows) is list and len(rows)==190 and
                 updated.get("coverage",{}).get("total")==190 and
                 updated.get("coverage",{}).get("finite")==189 and
                 updated.get("coverage",{}).get("unpriced")==1,
                 "NEW_SOURCE_ROW_COUNT_INVALID")
        rowmap={}
        counts=Counter()
        for row in rows:
            _require(type(row) is dict,"NEW_SOURCE_ROW_MALFORMED")
            p,name=row.get("page"),row.get("name")
            _require(p in CATEGORY and type(name) is str and
                     0<len(name)<=128 and not re.search(r"[\x00-\x1f]",name) and
                     row.get("sourceRecordMatched") is True and
                     row.get("verified") is False and
                     row.get("rawGameMappingVerified") is False and
                     row.get("priceForTradeVerified") is False,
                     "NEW_SOURCE_ROW_NOT_UNVERIFIED")
            k=p,name.casefold()
            _require(k not in rowmap,"NEW_SOURCE_DUPLICATE_ROW")
            rowmap[k]=row
            counts[p]+=1
            value=row.get("supremeValue")
            _require(value is None or
                     (type(value) is int and 0<value<1000000000),
                     "NEW_SOURCE_NONFINITE_VALUE")
            _require(type(row.get("demand")) is int and
                     0<=row["demand"]<=11 and
                     type(row.get("stability")) is str and
                     0<len(row["stability"])<=60,
                     "NEW_SOURCE_DEMAND_STABILITY_INVALID")
        _require(dict(counts)=={"ancient":16,"godly":128,"chroma":46},
                 "NEW_SOURCE_CATEGORY_COUNTS_INVALID")
        priceless=rowmap.get(("ancient","nik's scythe"))
        _require(type(priceless) is dict and priceless.get("supremeValue") is None and
                 sum(r["supremeValue"] is None for r in rowmap.values())==1,
                 "PRICELESS_SPECIAL_CASE_MISMATCH")
        joined=[];used=set();seen=set()
        for raw,cat in candidates.items():
            _require(type(raw) is str and 0<len(raw)<=128 and
                     type(cat) is dict,"PUBLIC_RAW_KEY_MALFORMED")
            p,name,slug=cat.get("page"),cat.get("displayName"),cat.get("slug")
            _require(p in CATEGORY and type(name) is str and
                     type(slug) is str and
                     re.fullmatch(r"[A-Za-z0-9_'-]+",slug) is not None and
                     cat.get("url")==f"https://supremevalues.com/mm2/{CATEGORY[p]}?item={slug}" and
                     cat.get("identityEvidence")=="HISTORICAL_PUBLIC_NAME_CATEGORY_VARIANT_CORRESPONDENCE_ONLY" and
                     cat.get("currentOwnedRawKeyVerified") is False and
                     cat.get("priceForTradeVerified") is False and
                     type(cat.get("gameChroma")) is bool and
                     (p=="chroma")==cat["gameChroma"] and
                     cat.get("gameItemType") in ("Knife","Gun") and
                     cat.get("gameRarity") in ("Ancient","Godly") and
                     (p=="chroma" or p==cat["gameRarity"].lower()),
                     "OLD_PUBLIC_VARIANT_OR_URL_MISMATCH")
            _require(type(name) is str and
                     (p,name.casefold()) in rowmap and
                     (p,name.casefold()) not in used and
                     (p,slug) not in seen,
                     "SOURCES_NOT_ONE_TO_ONE")
            used.add((p,name.casefold()));seen.add((p,slug))
            src=rowmap[(p,name.casefold())]
            _require(src["supremeValue"] is not None,
                     "PRICELESS_WITH_PUBLIC_SLUG_INVALID")
            joined.append({
                "historicalPublicRawKey":raw,
                "publicItemName":src["name"],
                "page":p,"sourceSlug":slug,
                "researchSourceValue":src["supremeValue"],
                "researchDemand":src["demand"],
                "researchStability":src["stability"],
                "historicalPublicCandidateOnly":True,
                "priceForTradeVerified":False,
            })
        _require(len(used)==189 and dict(Counter(x["page"] for x in joined))==EXPECTED,
                 "PUBLIC_TO_PUBLISHED_COVERAGE_INCOMPLETE")
        _require(set(rowmap)-used=={("ancient","nik's scythe")},
                 "NEW_SOURCE_UNEXPECTED_UNMAPPED_ROW")
        joined.sort(key=lambda x:(x["page"],x["publicItemName"].casefold(),x["historicalPublicRawKey"]))
        source_fresh=at_epoch<_time(EXPIRES) and at_epoch>=_time(PUBLISHER)
        return {
            "schema":SCHEMA,
            "status":"PUBLIC_RESEARCH_JOIN_READY" if source_fresh
                     else "PUBLIC_JOIN_ARCHIVED_SOURCE_EXPIRED",
            "reason":"PUBLIC_ARCHIVE_ONLY_NOT_CURRENT_AUTHENTICATED_GAME_ITEM",
            "sourceResearchFreshAtEvaluation":source_fresh,
            "publisher":PUBLISHER,"sourceExpiry":EXPIRES,
            "publicCandidates":len(joined),
            "priceEligiblePublicCandidates":len(joined),
            "publicPricelessWithoutSlug":1,
            "publicGameOnlyWithoutOldSourceRow":10,
            "rows":joined,**DENIED
        }
    except (JoinRejected,ValueError,TypeError,KeyError,OverflowError,
            RecursionError,AttributeError,UnicodeError) as exc:
        return _deny(str(exc) if type(exc) is JoinRejected else
                     "PUBLIC_JOIN_VALIDATION_ERROR")
