"""Read-only deterministic full-inventory -> 5-type shortlist for future planner.

Not a live inventory reader, not a verified MM2 identity mapper, not a price
authority, not an offer/executor. No silent truncation: all exclusions/counts
are returned. Synthetic source evidence only for offline test fixtures.
"""
from __future__ import annotations

from typing import Any

SCHEMA="gingerscope-future-inventory-shortlist-v1"
MAX_INPUT_TYPES=500
MAX_SELECTED_TYPES=5
MAX_PLANNER_COPIES=2
MAX_SLOTS=4

def _base(status,reason):
    return {
        "schema":SCHEMA,"status":status,"reason":reason,
        "ourShortlist":[],"theirShortlist":[],
        "counts":{"ourInput":0,"theirInput":0,
                  "ourExcludedIdentityOrProfile":0,
                  "theirExcludedIdentityOrProfile":0,
                  "theirExcludedMarketOrBudget":0,
                  "ourQuantityCapped":0,"theirQuantityCapped":0,
                  "ourNotSelected":0,"theirNotSelected":0},
        "theoreticalMaxListedOffer":0,
        "shortlistCoverageComplete":False,
        "fullInventoryOptimizationProven":False,
        "counterpartyInventoryAuthenticated":False,
        "weaponIdentityAuthenticated":False,
        "serverCompletionProven":False,
        "authorizesTrade":False,"authorizesAccept":False,
        "mayReportProfit":False,"mayUseForStrategyLearning":False,
        "tradeOutcome":"UNKNOWN",
    }

def _read_inventory(rows: object):
    if not isinstance(rows,list) or not 1<=len(rows)<=MAX_INPUT_TYPES:
        return None
    result={}
    for r in rows:
        if not isinstance(r,dict) or set(r)!={"key","quantity"}:
            return None
        key,count=r["key"],r["quantity"]
        if (not isinstance(key,str) or not 1<=len(key)<=80 or key in result
                or type(count) is not int or not 1<=count<=100):
            return None
        result[key]=count
    return result

def _profile(row):
    if not isinstance(row,dict):
        return False
    if row.get("identityLinkEvidence")!="INDEPENDENT_EXACT":
        return False
    for k,minimum,maximum in (("value",1,1_000_000),
                               ("demand",1,10),("liquidity",1,10)):
        v=row.get(k)
        if type(v) is not int or not minimum<=v<=maximum:
            return False
    return row.get("stability") in {"Stable","Overpaid For","Rising","Declining"}

def _quality(key,market):
    row=market[key]
    # Ranking only, NOT offered/realized profit or opponent willingness.
    stable=2 if row["stability"]=="Stable" else (
        1 if row["stability"]=="Overpaid For" else 0)
    return row["demand"]*5+row["liquidity"]*5+stable*3

def _band(value,anchor):
    # Stratified selection preserves low/mid/high upgrade opportunities.
    ratio=value/anchor
    return 0 if ratio<=0.10 else 1 if ratio<=0.30 else (
        2 if ratio<=0.65 else 3)

def _select(items:dict[str,int],market:dict,anchor:int):
    if not items:return []
    bins={}
    for key in sorted(items):
        profile=market[key]
        b=_band(profile["value"],anchor)
        bins.setdefault(b,[]).append(key)
    for arr in bins.values():
        arr.sort(key=lambda k:(-_quality(k,market),-market[k]["value"],k))
    selected=[]
    # One per market-price band first, to avoid choosing only highest value.
    for tier in (0,1,2,3):
        if tier in bins and len(selected)<MAX_SELECTED_TYPES:
            selected.append(bins[tier].pop(0))
    remaining=[key for group in bins.values() for key in group]
    remaining.sort(key=lambda k:(-_quality(k,market),-market[k]["value"],k))
    selected.extend(remaining[:MAX_SELECTED_TYPES-len(selected)])
    return [{"key":k,"quantity":min(items[k],MAX_PLANNER_COPIES)}
            for k in selected]

def shortlist(ours:object,theirs:object,catalog:object,*,now:int,
              max_overpay_pct:int=50)->dict[str,Any]:
    a=_read_inventory(ours);b=_read_inventory(theirs)
    if a is None or b is None:
        return _base("BLOCKED","FULL_INVENTORY_INPUT_INVALID")
    out=_base("BLOCKED","MARKET_EVIDENCE_INVALID")
    out["counts"]["ourInput"]=len(a);out["counts"]["theirInput"]=len(b)
    if (type(now) is not int or not 1_700_000_000<=now<=2_100_000_000 or
        type(max_overpay_pct) is not int or not 0<=max_overpay_pct<=100):
        return out
    if not isinstance(catalog,dict) or catalog.get("source")!="SUPREME_DISPLAY_RESEARCH_ONLY":
        return out
    pub=catalog.get("publisherUpdatedAtUnix");fetched=catalog.get("retrievedAtUnix")
    if (type(pub) is not int or type(fetched) is not int or
            not 1_700_000_000<=pub<=fetched<=now or now-pub>48*3600 or
            not isinstance(catalog.get("version"),str) or not catalog["version"]):
        return out
    market=catalog.get("items")
    if not isinstance(market,dict):return out

    our_good={k:v for k,v in a.items() if _profile(market.get(k))}
    their_good={k:v for k,v in b.items() if _profile(market.get(k))}
    out["counts"]["ourExcludedIdentityOrProfile"]=len(a)-len(our_good)
    out["counts"]["theirExcludedIdentityOrProfile"]=len(b)-len(their_good)
    out["counts"]["ourQuantityCapped"]=sum(v>MAX_PLANNER_COPIES for v in our_good.values())
    out["counts"]["theirQuantityCapped"]=sum(v>MAX_PLANNER_COPIES for v in their_good.values())
    if not our_good:
        out["status"]="NO_USABLE_OWN_PROFILE";out["reason"]="ALL_OWN_MAPPINGS_UNVERIFIED"
        return out
    # Theoretical upper bound assumes four distinct item-type slots, with up
    # to two copies per type. Not a feasible offer or a confirmed item mapping.
    max_offer=sum(sorted(
        (market[k]["value"]*min(v,MAX_PLANNER_COPIES)
         for k,v in our_good.items()),reverse=True)[:MAX_SLOTS])
    out["theoreticalMaxListedOffer"]=max_offer
    allowed_value=max_offer*(100+max_overpay_pct)//100
    affordable={k:v for k,v in their_good.items()
                if market[k]["value"]<=allowed_value and
                   market[k]["demand"]>=4 and market[k]["liquidity"]>=4 and
                   market[k]["stability"] in {"Stable","Overpaid For"}}
    out["counts"]["theirExcludedMarketOrBudget"]=len(their_good)-len(affordable)
    if not affordable:
        out["status"]="NO_AFFORDABLE_PARTNER_ITEMS"
        out["reason"]="NONE_PASS_VALUE_OR_DEMAND_LIQUIDITY"
        return out
    own_anchor=max(market[k]["value"] for k in our_good)
    our_selected=_select(our_good,market,own_anchor)
    their_selected=_select(affordable,market,max(1,max_offer))
    out["ourShortlist"]=our_selected
    out["theirShortlist"]=their_selected
    out["counts"]["ourNotSelected"]=len(our_good)-len(our_selected)
    out["counts"]["theirNotSelected"]=len(affordable)-len(their_selected)
    out["status"]="RESEARCH_SHORTLIST_ONLY"
    out["reason"]="BOUNDED_STRATIFIED_PRESELECTION_REQUIRES_LATER_PLAN_GUARD"
    # Even if the supplied pool had <=5 items, this does not prove the
    # external inventories or server profiles are complete.
    return out
