"""System2 research-only bounded counterparty-specific proposal enumeration.

This closes one narrow gap between a path REPLAYER and hypothetical available
offers: every potential received item must occur in a separately supplied
synthetic counterparty shortlist. No real MM2 source proves the counterparty
actually owns or will part with an item. No fake liquidity/acceptance evidence
and no automatic trade ranking. Four physical slots != total stacked copies.
"""
from __future__ import annotations

from itertools import product

from pdiddler.system2.market_research_reader import _index, TARGET_KEY
from pdiddler.system2.trade_scenario_lab import _owned_from_shadow, _totals
from pdiddler.system2.operator_capture_adapter import AUTHORITY_DENIED

SCHEMA = "gingerscope-system2-counterparty-bounded-candidates-v1"
MAX_KEYS_PER_SHORTLIST = 4
MAX_DISPLAY = 20


def _result(status, reason, **data):
    return {
        "schema": SCHEMA,
        "status": status,
        "reason": reason,
        "simulationOnly": True,
        "counterpartyOwnsAnyItemProven": False,
        "counterpartyConsentProven": False,
        "clientIdentityAuthenticated": False,
        "independentlyVerifiedLiquidityAvailable": False,
        "acceptanceProbability": None,
        "globalBestTradeProven": False,
        "rankedByRealAttractiveness": False,
        "exactFourPhysicalSlotsSimulated": True,
        "neverOfferGingerscope": True,
        "autoTradeAuthorized": False,
        **data,
        **AUTHORITY_DENIED,
    }


def _shortlist_keys(value):
    if (type(value) is not list or
            not 1 <= len(value) <= MAX_KEYS_PER_SHORTLIST or
            any(type(k) is not str or not k for k in value) or
            len(set(value)) != len(value)):
        raise ValueError("EXPLICIT_BOUNDED_OWN_SHORTLIST_REQUIRED")
    return sorted(value)


def _partner_scope(value, idx):
    if (type(value) is not dict or set(value) != {"kind","items","ownershipProof"}
        or value["kind"] != "SYNTHETIC_UNVERIFIED_COUNTERPARTY"
        or value["ownershipProof"] != "UNKNOWN"):
        raise ValueError("SYNTHETIC_COUNTERPARTY_PROOF_CONTRACT_REQUIRED")
    items=value["items"]
    if type(items) is not list or not 1 <= len(items) <= MAX_KEYS_PER_SHORTLIST:
        raise ValueError("COUNTERPARTY_EXPLICIT_SHORTLIST_INVALID")
    result={}
    for item in items:
        if type(item) is not dict or set(item)!={"rawGameKey","quantity"}:
            raise ValueError("COUNTERPARTY_ITEM_FIELDS_INVALID")
        key, qty=item["rawGameKey"],item["quantity"]
        if (type(key) is not str or key not in idx or key in result
            or type(qty) is not int or not 1 <= qty <= 10000):
            raise ValueError("COUNTERPARTY_UNKNOWN_OR_DUPLICATE_KEY_OR_BAD_QTY")
        result[key]=qty
    return dict(sorted(result.items()))


def _bundles(shortlist):
    """Bounded deterministic 1-4 physical slot combinations.

    Tests qty1, qty2 when held, and one whole stack (possibly >4 copies)
    without silently assuming full stacks trade at linear base value.
    """
    keys=sorted(shortlist)
    variants=[]
    for key in keys:
        qty=shortlist[key]
        counts=sorted({0,1,min(2,qty),qty})
        variants.append(counts)
    for quantities in product(*variants):
        picked={key:qty for key,qty in zip(keys,quantities) if qty>0}
        if 1<=len(picked)<=4:
            yield picked


def explore(mapped, shadow, request, *, evaluated_at_utc=None):
    try:
        idx=_index(mapped)
        owned,_=_owned_from_shadow(shadow,idx,evaluated_at_utc=evaluated_at_utc)
        if (type(request) is not dict
            or set(request)!={"kind","ownShortlist","counterparty","maxDisplay"}
            or request["kind"]!="SYNTHETIC_OFFLINE_COUNTERPARTY_ENUMERATION"
            or type(request["maxDisplay"]) is not int
            or not 1<=request["maxDisplay"]<=MAX_DISPLAY):
            raise ValueError("EXPLICIT_RESEARCH_ENUMERATION_REQUEST_REQUIRED")
        own_keys=_shortlist_keys(request["ownShortlist"])
        if any(key not in idx or key not in owned for key in own_keys):
            raise ValueError("UNKNOWN_OR_UNOWNED_EXPLICIT_OWN_SHORTLIST_KEY")
        own={key:owned[key] for key in own_keys if key!=TARGET_KEY}
        if not own:
            raise ValueError("ONLY_PROTECTED_GINGERSCOPE_OWNED_NO_OUTGOING")
        their=_partner_scope(request["counterparty"],idx)
        # Separate source proofs required in later native integration.
        # Do NOT pretend this synthetic partner census is a real player profile.
        outgoing=list(_bundles(own))
        incoming=list(_bundles(their))
        if len(outgoing)*len(incoming)>100000:
            raise ValueError("EXPLICIT_SHORTLIST_COMBINATORICS_TOO_LARGE")
        previews=[]
        considered=0;nonloss=0;excluded_stack=0;excluded_loss=0;overlap=0
        for o in outgoing:
            out=_totals(o,idx)
            for rec in incoming:
                considered+=1
                if set(o)&set(rec):
                    overlap+=1
                    continue
                received=_totals(rec,idx)
                delta=received["listed"]-out["listed"]
                if delta<0:
                    excluded_loss+=1
                    continue
                if (out["publisherStackPricingUncertainKeys"] or
                        received["publisherStackPricingUncertainKeys"]):
                    excluded_stack+=1
                    continue
                nonloss+=1
                if len(previews)<request["maxDisplay"]:
                    previews.append({
                        "outgoingSlots":[{"rawGameKey":k,"quantity":q} for k,q in o.items()],
                        "incomingSlots":[{"rawGameKey":k,"quantity":q} for k,q in rec.items()],
                        "outgoingPhysicalSlots":len(o),
                        "incomingPhysicalSlots":len(rec),
                        "listedDelta":delta,
                        "worstCaseRangeDelta":received["low"]-out["high"],
                        "incomingGingerscopeHypothesis":TARGET_KEY in rec,
                        "warnings":[
                            "SYNTHETIC_COUNTERPARTY_OWNERSHIP_NOT_PROVEN",
                            "COUNTERPARTY_WILLINGNESS_AND_RETRADE_LIQUIDITY_UNKNOWN",
                            *(
                                ["COUNTERPARTY_WOULD_GIVE_MORE_LISTED_VALUE_UNPROVEN"]
                                if delta>0 else []
                            ),
                        ],
                        "actionAuthorized":False,
                    })
        # A preview limited to the deterministic FIRST N is deliberately not
        # a profit ranking: absence from preview is not evidence of infeasibility.
        return _result(
            "OFFLINE_COUNTERPARTY_OPTIONS_ENUMERATED",
            "SHORTLIST_ONLY_NO_COUNTERPARTY_OWNERSHIP_OR_LIQUIDITY_PROOF",
            explicitOwnKeyCount=len(own_keys),
            explicitCounterpartyKeyCount=len(their),
            enumeratedAllPairsForProvidedShortlists=True,
            totalHypotheticalPairsConsidered=considered,
            nonLossNonStackPaperPairs=nonloss,
            lossBudgetBlockedPairs=excluded_loss,
            nonlinearStackPricingBlockedPairs=excluded_stack,
            overlappingItemKeyPairsSkipped=overlap,
            previewLimitedTo=request["maxDisplay"],
            previewOrderingIsNotProfitOrAttractivenessRanking=True,
            previews=previews,
        )
    except (ValueError,TypeError,KeyError,AttributeError,OverflowError) as error:
        return _result("BLOCKED",str(error)[:210])
