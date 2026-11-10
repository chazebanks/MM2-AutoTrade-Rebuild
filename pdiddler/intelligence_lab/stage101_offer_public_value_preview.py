"""Stage101: read-only offered-name → historical public Supreme research preview.

Consumes an output reconstructed from original pinned Stage82/84→Stage94 public
sources, plus SAME local Stage98-like offer epoch snapshot. Neither source
authenticates current account contents or original MM2 raw offer weapon IDs.

No Roblox, web requests, Discord, game events, Accept or actual trading.
"""
from __future__ import annotations

from collections import Counter, defaultdict
from datetime import datetime, timezone
import re
from typing import Any

SCHEMA="gingerscope-stage101-name-only-public-value-preview-v1"
ORIGINAL_SOURCE_SCHEMA="gingerscope-stage94-public-catalogue-new-publisher-research-join-v1"
PUBLISHED="2026-11-09T18:58:33Z"
EXPIRES="2026-11-10T22:26:48Z"
CATEGORIES={"ancient":15, "godly":128, "chroma":46}
MAX_ITEM_QUANTITY=4
FALSE={
    "readOnly":True,
    "researchOnly":True,
    "nameOnlyUnbound":True,
    "currentGameItemIdentityAuthenticated":False,
    "numericSupremeCheckerIdVerified":False,
    "rawOfferKeyBoundToPhysicalSlot":False,
    "uniqueWeaponInstanceProven":False,
    "currentPricesVerified":False,
    "priceForTradeVerified":False,
    "sourcePublisherFreshForTrade":False,
    "authenticatedOwnedInventory":False,
    "serverTradeRevisionProven":False,
    "serverAttestation":False,
    "serverCompletionProven":False,
    "eventSessionAssociationProven":False,
    "callbackCausalityProven":False,
    "authorizesTrade":False,
    "authorizesAccept":False,
    "mayRecordCompletedTrade":False,
    "mayReportProfit":False,
    "maySendDiscordWebhook":False,
    "mayUseForStrategyLearning":False,
    "tradeOutcome":"UNKNOWN",
}
class Rejected(ValueError):
    pass
def require(v:bool,msg:str)->None:
    if not v:
        raise Rejected(msg)
def _epoch(iso:str)->int:
    return int(datetime.fromisoformat(iso.replace("Z","+00:00")).timestamp())
def _name(t:object)->str:
    if type(t) is not str or not 1<=len(t)<=128:
        raise Rejected("GUI_LABEL_INVALID")
    if re.search(r"[\x00-\x1f\x7f]",t):
        raise Rejected("GUI_LABEL_CONTROL_CHARACTER")
    value=" ".join(t.split())
    require(len(value)>0,"GUI_LABEL_EMPTY")
    return value.casefold()
def _denied(reason:str)->dict[str,Any]:
    return {"schema":SCHEMA,"status":"INCONCLUSIVE","reason":reason,
            "sourcePriceState":"UNAVAILABLE","offerReferenceCompleteness":"UNKNOWN",
            "ourReferenceTotal":None,"theirReferenceTotal":None,
            "illustrativeReferenceDifference":None,"rows":[],
            "localOfferEpoch":None,**FALSE}
def _source(source:object,now:int)->tuple[list[dict[str,Any]],str]:
    require(type(now) is int and 1_600_000_000<now<2_100_000_000,
            "EVALUATION_CLOCK_UNTRUSTED")
    require(type(source) is dict,"STAGE94_ORIGINAL_SOURCE_REQUIRED")
    require(source.get("schema")==ORIGINAL_SOURCE_SCHEMA and
            source.get("status") in ("PUBLIC_RESEARCH_JOIN_READY",
                                     "PUBLIC_JOIN_ARCHIVED_SOURCE_EXPIRED") and
            source.get("publisher")==PUBLISHED and source.get("sourceExpiry")==EXPIRES and
            source.get("publicCandidates")==189 and
            source.get("newPublicationDetailSlugsIndependentlyReparsed") is True and
            source.get("publicPricelessWithoutSlug")==1 and
            source.get("publicGameOnlyWithoutOldSourceRow")==10 and
            source.get("researchOnly") is True and
            source.get("readOnly") is True and
            source.get("currentPricesVerified") is False and
            source.get("priceForTradeVerified") is False and
            source.get("rawGameToMarketIdentityAuthenticated") is False and
            source.get("numericSupremeCheckerIdVerified") is False and
            source.get("authorizesTrade") is False and
            source.get("authorizesAccept") is False and
            source.get("serverCompletionProven") is False,
            "STAGE94_PREVIEW_OR_AUTHORITY_PROVENANCE_INVALID")
    rows=source.get("rows")
    require(type(rows) is list and len(rows)==189,"STAGE94_PUBLIC_COVERAGE_MISSING")
    seenRaw=set()
    seenPageName=set()
    categoryCount=Counter()
    for r in rows:
        require(type(r) is dict,"SOURCE_ROW_INVALID")
        page=r.get("page")
        raw=r.get("historicalPublicRawKey")
        label=r.get("publicItemName")
        value=r.get("researchSourceValue")
        demand=r.get("researchDemand")
        stability=r.get("researchStability")
        require(page in CATEGORIES and type(raw) is str and
                1<=len(raw)<=128 and type(label) is str and
                type(value) is int and 0<value<1_000_000_000 and
                type(demand) is int and 0<=demand<=11 and
                type(stability) is str and 1<=len(stability)<=60 and
                r.get("historicalPublicCandidateOnly") is True and
                r.get("priceForTradeVerified") is False,
                "SOURCE_ROW_OR_VARIANT_INVALID")
        normalized=_name(label)
        require((page=="chroma")==normalized.startswith("chroma "),
                "SOURCE_CHROMA_VARIANT_MISMATCH")
        require(raw not in seenRaw and (page,normalized) not in seenPageName,
                "DUPLICATE_PUBLIC_REFERENCE")
        seenRaw.add(raw)
        seenPageName.add((page,normalized))
        categoryCount[page]+=1
    require(dict(categoryCount)==CATEGORIES,"STAGE94_CATEGORY_COVERAGE_CHANGED")
    require(now>=_epoch(PUBLISHED),"SOURCE_PUBLICATION_NOT_YET_REACHED")
    # Stage94's own 'fresh' flag was computed during archival job runtime.
    # Recompute expiry at *this* evaluation time; never renew by fetching HTML.
    return rows,("HISTORICAL_RESEARCH_WITHIN_CAPTURE_WINDOW"
                 if now<_epoch(EXPIRES)
                 else "ARCHIVED_RESEARCH_CAPTURE_EXPIRED")
def _offer(o:object)->tuple[list[dict[str,Any]],int]:
    require(type(o) is dict and
            o.get("exactPartnerClientBound") is True and
            o.get("stage9ObserverBound") is True and
            o.get("acceptedIndicatorsFalse") is True and
            o.get("pendingOfferMutation") is False and
            type(o.get("localOfferEpoch")) is int and
            1<=o["localOfferEpoch"]<=1_000_000 and
            type(o.get("stableGuiReads")) is int and
            o["stableGuiReads"]>=2 and
            o.get("clientOnly") is True and
            o.get("serverTradeRevisionProven") is False and
            o.get("rawItemIdConfirmed") is False,
            "CLIENT_OFFER_NOT_STABLE_OR_TRUSTED_FOR_PREVIEW")
    out=[]
    for side in ("ours","theirs"):
        slots=o.get(side)
        require(type(slots) is list and len(slots)<=4,"CLIENT_OFFER_SLOT_COUNT_INVALID")
        seenSlots=set()
        count=0
        for slot in slots:
            require(type(slot) is dict and set(slot)=={"slot","label","chroma","quantity"},
                    "CLIENT_OFFER_SLOT_SHAPE_INVALID")
            idx=slot["slot"]
            qty=slot["quantity"]
            require(type(idx) is int and 1<=idx<=4 and idx not in seenSlots and
                    type(qty) is int and 1<=qty<=MAX_ITEM_QUANTITY and
                    type(slot["chroma"]) is bool,
                    "CLIENT_OFFER_QUANTITY_OR_CHROMA_INVALID")
            seenSlots.add(idx)
            count+=qty
            require(count<=4,"CONSERVATIVE_FOUR_COPY_OFFER_LIMIT")
            out.append({"side":side,"slot":idx,"label":slot["label"],
                        "normalized":_name(slot["label"]),
                        "chroma":slot["chroma"],"quantity":qty})
    return out,o["localOfferEpoch"]
def preview_public_reference(source:object,offer:object,*,now_epoch:int)->dict[str,Any]:
    """Client-visible display-label candidates only; never current trade quotes."""
    try:
        public,priceState=_source(source,now_epoch)
        slots,epoch=_offer(offer)
        byName=defaultdict(list)
        for row in public:
            byName[_name(row["publicItemName"])].append(row)
        out=[]
        totals={"ours":0,"theirs":0}
        coverage={"ours":True,"theirs":True}
        matched=0
        ambiguous=0
        unmatched=0
        for slot in slots:
            matches=[row for row in byName[slot["normalized"]]
                     if (row["page"]=="chroma")==slot["chroma"]]
            if slot["chroma"] and not slot["normalized"].startswith("chroma "):
                # Do NOT invent a 'Chroma ' prefix: visible UI differs from
                # canonical public names, and raw ID was not linked.
                matches=[]
            if len(matches)==1:
                v=matches[0]
                matched+=1
                q=slot["quantity"]
                subtotal=v["researchSourceValue"]*q
                totals[slot["side"]]+=subtotal
                out.append({"side":slot["side"],"slot":slot["slot"],"quantity":q,
                            "visibleLabel":slot["label"],
                            "matchStatus":"UNIQUE_PUBLIC_NAME_VARIANT_CANDIDATE",
                            "identityEvidence":"NAME_ONLY_NOT_RAW_KEY_BOUND",
                            "publicReferenceName":v["publicItemName"],
                            "publicReferencePage":v["page"],
                            "historicalPublicRawKey":None,
                            "publicValuePerCopyResearch":v["researchSourceValue"],
                            "publicValueSubtotalResearch":subtotal,
                            "publicDemandResearch":v["researchDemand"],
                            "publicStabilityResearch":v["researchStability"],
                            "liquidity":"UNVERIFIED",
                            "priceForTradeVerified":False})
            else:
                state=("AMBIGUOUS_PUBLIC_NAME" if len(matches)>1
                       else "NO_EXACT_PUBLIC_NAME_VARIANT_MATCH")
                ambiguous+=len(matches)>1
                unmatched+=len(matches)==0
                coverage[slot["side"]]=False
                out.append({"side":slot["side"],"slot":slot["slot"],
                            "quantity":slot["quantity"],
                            "visibleLabel":slot["label"],
                            "matchStatus":state,
                            "identityEvidence":"UNBOUND",
                            "publicValuePerCopyResearch":None,
                            "publicValueSubtotalResearch":None,
                            "publicDemandResearch":None,
                            "publicStabilityResearch":None,
                            "liquidity":"UNVERIFIED",
                            "priceForTradeVerified":False})
        # Even a UNIQUE public name match CANNOT verify the actual item ID.
        # An archived source may display recorded values, but NEVER create
        # a fresh two-sided comparable estimate from a stale publication.
        withinWindow=priceState=="HISTORICAL_RESEARCH_WITHIN_CAPTURE_WINDOW"
        bothComplete=coverage["ours"] and coverage["theirs"]
        bothNonempty=bool(offer["ours"]) and bool(offer["theirs"])
        canCompare=withinWindow and bothComplete and bothNonempty
        status=("HISTORICAL_PUBLIC_CANDIDATES_RESEARCH_ONLY"
                if matched and not ambiguous and not unmatched
                else "PUBLIC_NAME_MATCH_INCOMPLETE_RESEARCH_ONLY")
        return {
            "schema":SCHEMA,
            "status":status,
            "reason":"GUI_LABELS_NOT_AUTHENTICATED_WEAPON_IDS",
            "sourcePriceState":priceState,
            "originalSourcePublication":PUBLISHED,
            "originalSourceExpiry":EXPIRES,
            "offerReferenceCompleteness":(
                "BOTH_SIDES_PUBLIC_NAME_CANDIDATES" if bothComplete and bothNonempty
                else "PARTIAL_OR_UNMATCHED"),
            "matchedCandidateSlots":matched,
            "ambiguousSlots":int(ambiguous),
            "unmatchedSlots":int(unmatched),
            "ourReferenceTotal":totals["ours"] if canCompare else None,
            "theirReferenceTotal":totals["theirs"] if canCompare else None,
            "illustrativeReferenceDifference":(
                totals["theirs"]-totals["ours"] if canCompare else None),
            "rows":out,
            "localOfferEpoch":epoch,
            **FALSE
        }
    except (Rejected,TypeError,ValueError,KeyError,AttributeError,
            OverflowError,UnicodeError,RecursionError):
        return _denied("RESEARCH_SOURCE_OR_CLIENT_INPUT_INVALID")
