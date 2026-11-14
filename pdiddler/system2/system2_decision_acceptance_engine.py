"""Decision-level System2 acceptance engine. Research-only, zero MM2 actions.

These are FIVE *actual algorithmic capabilities*, not five P3/P4 trade windows:
1. fail-closed source/item/census admission,
2. bilateral risk/demand/concentration comparison,
3. bounded multi-step target-directed growth routes,
4. event/revision-aware adaptive responses,
5. outcome-quality/holdout-aware feedback learning.

All economic prices, ownership and opponent preferences here are TEST FIXTURES.
Even successful calculations NEVER assert real current market quotes, true
counterparty willingness, verified settled trades, live learning or offer rights.
A live proof needs a separately authenticated observation+publisher pipeline.
"""
from __future__ import annotations
from collections import Counter
from datetime import datetime,timezone
from math import isfinite
import hashlib
import json

SCHEMA="gingerscope-system2-decision-acceptance-engine-v1"
CATALOG="SYNTHETIC_S2_EXACT_RAW_KEY_MARKET_FIXTURE"
TARGET="Gingerscope"
STABILITY={"Stable","Doing Well","Improving","Rising","Overpaid For",
           "Fluctuating","Receding","Underpaid For","Decreasing","Unsafe"}
BAD_STABILITY={"Unsafe","Decreasing","Underpaid For","Receding"}
PROVENANCE_DENIAL={
    "realMarketSourceAuthenticated":False,
    "realGameWeaponIdentityAuthenticated":False,
    "actualCounterpartyWillingnessProven":False,
    "realLiquidityMeasured":False,
    "serverSettlementProven":False,
    "actualLearningDeployed":False,
    "mayUseForLiveOffer":False,
    "authorizesTrade":False,
    "authorizesAccept":False,
    "mayReportProfit":False,
    "maySendDiscordWebhook":False,
    "protectedGingerscopeOutgoing":False,
}
class Blocked(Exception):
    pass

def _out(capability,status,reason,**fields):
    return {"schema":SCHEMA,"capability":capability,
            "status":status,"reason":reason,
            "fixtureOnly":True,"originalMM2LivePass":False,
            **fields, **PROVENANCE_DENIAL}

def _utc(v):
    if type(v) is not str or len(v)>40:
        raise Blocked("INVALID_RESEARCH_CLOCK")
    try:
        d=datetime.fromisoformat(v.replace("Z","+00:00"))
        if d.tzinfo is None:
            raise ValueError
        return d.astimezone(timezone.utc)
    except (ValueError,OverflowError):
        raise Blocked("INVALID_RESEARCH_CLOCK") from None

def _json_hash(v):
    return hashlib.sha256(json.dumps(v,sort_keys=True,separators=(",",":"),
                      allow_nan=False).encode()).hexdigest()

def _source(source,at):
    if type(source) is not dict or set(source)!={
        "schema","publicationAt","expiresAt","quotes"} or source["schema"]!=CATALOG:
        raise Blocked("SYNTHETIC_QUOTE_SOURCE_REQUIRED")
    current=_utc(at)
    since,expire=_utc(source["publicationAt"]),_utc(source["expiresAt"])
    if since>current or expire<=current or expire<=since or (expire-since).total_seconds()>86400:
        raise Blocked("SOURCE_STALE_FUTURE_OR_OVERLONG")
    rows=source["quotes"]
    if type(rows) is not dict or not 2<=len(rows)<=300 or TARGET not in rows:
        raise Blocked("EXACT_HISTORICAL_KEY_CATALOG_MISSING")
    for key,row in rows.items():
        if (type(key) is not str or not 1<=len(key)<=100 or
            type(row) is not dict or set(row)!={"value","low","high","demand","stability","category","chroma"} or
            any(type(row[k]) is not int for k in ("value","low","high","demand")) or
            not 0<row["low"]<=row["value"]<=row["high"]<10**9 or
            not 0<=row["demand"]<=10 or row["stability"] not in STABILITY or
            row["category"] not in ("Godly","Ancient","Chroma Godly","Chroma Ancient") or
            type(row["chroma"]) is not bool):
            raise Blocked("QUOTE_EXACT_KEY_RANGE_OR_VARIANT_INVALID")
        if row["chroma"] != row["category"].startswith("Chroma "):
            raise Blocked("CHROMA_RAW_VARIANT_MISMATCH")
    return rows,_json_hash(source)

def _portfolio(value,keys,cap=10000):
    if type(value) is not dict or len(value)>300:
        raise Blocked("INVALID_SYNTHETIC_INVENTORY")
    out={}
    for k,q in value.items():
        if type(k) is not str or k not in keys or type(q) is not int or not 0<=q<=cap:
            raise Blocked("OWN_INVENTORY_ID_OR_QUANTITY_UNKNOWN")
        if q:
            out[k]=q
    return out

def _slots(rows,quotes,*,empty=False):
    if type(rows) is not list or not (0 if empty else 1)<=len(rows)<=4:
        raise Blocked("PHYSICAL_SLOTS_MUST_BE_ZERO_TO_FOUR")
    out={}
    for row in rows:
        if type(row) is not dict or set(row)!={"key","copies"}:
            raise Blocked("PHYSICAL_SLOT_FIELDS_INVALID")
        k,q=row["key"],row["copies"]
        if type(k) is not str or k not in quotes or k in out or type(q) is not int or not 1<=q<=10000:
            raise Blocked("UNRESOLVED_OR_DUPLICATE_EXACT_SLOT")
        out[k]=q
    return out

def _total(slots,rows,key="value"):
    return sum(rows[k][key]*q for k,q in slots.items())

def _after(inventory,give,get):
    new=dict(inventory)
    for k,q in give.items():
        if k==TARGET:
            raise Blocked("PROTECTED_GINGERSCOPE_NEVER_OUTBOUND")
        if new.get(k,0)<q:
            raise Blocked("OFFER_MORE_COPIES_THAN_OWNED")
        new[k]-=q
        if new[k]==0:
            del new[k]
    for k,q in get.items():
        new[k]=new.get(k,0)+q
        if new[k]>10000:
            raise Blocked("POST_TRADE_STACK_OVERFLOW")
    return new

def _quality(holdings,quotes):
    total=_total(holdings,quotes)
    if total<=0:
        return {"total":0,"concentrationBasisPoints":0,
                "demandWeightedBasisPoints":0,"unstableBasisPoints":0}
    maxkey=max(holdings,key=lambda k:holdings[k]*quotes[k]["value"])
    concentration=10000*holdings[maxkey]*quotes[maxkey]["value"]//total
    demand=sum(holdings[k]*quotes[k]["value"]*quotes[k]["demand"] for k in holdings)
    unstable=sum(holdings[k]*quotes[k]["value"] for k in holdings
                 if quotes[k]["stability"] in BAD_STABILITY)
    return {"total":total,"concentrationBasisPoints":concentration,
            "demandWeightedBasisPoints":1000*demand//total,
            "unstableBasisPoints":10000*unstable//total}

def _base(catalog,inventory,at):
    rows,seal=_source(catalog,at)
    owned=_portfolio(inventory,rows)
    return rows,owned,seal

def inventory_admission(*,catalog,inventory,at,offer=None):
    name="MARKET_INVENTORY_AUTHENTICITY"
    try:
        quotes,owned,seal=_base(catalog,inventory,at)
        outgoing=_slots(offer or [],quotes,empty=True)
        _after(owned,outgoing,{})
        summary=_quality(owned,quotes)
        return _out(name,"RESEARCH_DECISION_PASS","EXACT_KEY_QUANTITY_AND_SOURCE_AGE_VALIDATED",
                    sourceFixtureSha256=seal,visiblePhysicalOfferSlots=len(outgoing),
                    outgoingCopies=sum(outgoing.values()),portfolio=summary,
                    authenticatedCurrentPriceRequiredBeforeLive=True)
    except (Blocked,TypeError,ValueError,KeyError) as e:
        return _out(name,"BLOCKED",str(e) if isinstance(e,Blocked) else "BAD_INPUT")

def bilateral_decision(*,catalog,inventory,at,alternatives):
    """Compare genuine different *possible* choices, not an offer to execute.

    First filter against budget, physical layout, exact stock and worst-case
    downside. Then robust surplus > concentration > ordinal demand. No claimed
    willing partner, no real acceptance model, no production ranking.
    """
    name="BILATERAL_ATTRACTIVENESS"
    try:
        q,own,seal=_base(catalog,inventory,at)
        if type(alternatives) is not list or not 2<=len(alternatives)<=20:
            raise Blocked("MULTIPLE_DISTINCT_ALTERNATIVES_REQUIRED")
        considered=[]
        seen=set()
        for i,option in enumerate(alternatives):
            if type(option) is not dict or set(option)!={"give","receive","partnerIntent"}:
                raise Blocked("INVALID_BILATERAL_OPTION")
            g=_slots(option["give"],q);t=_slots(option["receive"],q)
            intent=option["partnerIntent"]
            if (type(intent) is not dict or
                set(intent)!={"kind","wantedKey","subjectiveValuePremium"} or
                intent["kind"]!="SYNTHETIC_REVEALED_PARTNER_PREFERENCE" or
                type(intent["wantedKey"]) is not str or
                intent["wantedKey"] not in g or
                type(intent["subjectiveValuePremium"]) is not int or
                not 0<=intent["subjectiveValuePremium"]<=10000):
                raise Blocked("PARTNER_PREFERENCE_SCOPE_OR_EVIDENCE_MISSING")
            signature=(tuple(sorted(g.items())),tuple(sorted(t.items())))
            if signature in seen:
                raise Blocked("DUPLICATE_COUNTERFACTUAL")
            seen.add(signature)
            candidate=_after(own,g,t)
            nominal=_total(t,q)-_total(g,q)
            robust=_total(t,q,"low")-_total(g,q,"high")
            quality=_quality(candidate,q)
            # An unknown seller cannot be assigned a probability here.
            # We are not claiming a single public list permits both parties
            # to gain listed value. The partner's SUBJECTIVE revealed-value
            # premium is an explicit unverified fixture, not market evidence.
            partnerSurplus=(_total(g,q)+
                intent["subjectiveValuePremium"]*g[intent["wantedKey"]]-
                _total(t,q))
            allowed=nominal>=0 and robust>=0 and partnerSurplus>=0
            considered.append({"index":i,"nominalGain":nominal,
             "rangeWorstCaseGain":robust,"postInventory":quality,
             "researchViable":allowed,
             "hypotheticalPartnerSubjectiveSurplus":partnerSurplus,
             "counterpartyAppeal":"SYNTHETIC_PREFERENCE_ONLY",
             "empiricalFillRate":None,
             "realCounterpartyPreferenceProven":False})
        accepted=[a for a in considered if a["researchViable"]]
        if not accepted:
            return _out(name,"ABSTAIN","NO_BILATERALLY_FEASIBLE_RANGE_SAFE_OPTION",
                        sourceFixtureSha256=seal,alternatives=considered,selectedIndex=None)
        # A conservative rule: avoid portfolio fragility before chasing
        # the biggest on-paper gain. If tied, choose robustness and demand.
        def rank(v):
            p=v["postInventory"]
            return (-p["unstableBasisPoints"],-p["concentrationBasisPoints"],
                    v["rangeWorstCaseGain"],v["hypotheticalPartnerSubjectiveSurplus"],
                    p["demandWeightedBasisPoints"],-v["index"])
        winner=max(accepted,key=rank)
        return _out(name,"RESEARCH_DECISION_PASS","CONSERVATIVE_COUNTERFACTUAL_SELECTED",
                    sourceFixtureSha256=seal,selectedIndex=winner["index"],
                    considered=considered,
                    counterpartPreferenceAssumptionExplicit=True,
                    actualCounterpartPreferenceAuthenticated=False,
                    reasonForAttention="ROBUST_RANGE_PORTFOLIO_RISK_NOT_POSTED_PROFIT",
                    deploymentWouldRequireMeasuredPartnerPreference=True)
    except (Blocked,ValueError,TypeError,KeyError) as e:
        return _out(name,"BLOCKED",str(e) if isinstance(e,Blocked) else "BAD_INPUT")

def growth_route_decision(*,catalog,inventory,at,routes):
    """Compare two or more bounded 2–6-step *provided* paths, not invent sellers."""
    name="MULTISTEP_GINGERSCOPE_GROWTH"
    try:
        quotes,start,seal=_base(catalog,inventory,at)
        if type(routes) is not list or not 2<=len(routes)<=10:
            raise Blocked("MULTIPLE_GROWTH_ROUTES_REQUIRED")
        audited=[]
        for index,route in enumerate(routes):
            if type(route) is not list or not 2<=len(route)<=6:
                raise Blocked("GROWTH_ROUTE_REQUIRES_TWO_TO_SIX_STEPS")
            own=dict(start)
            minimum_robust=10**9
            seen={tuple(sorted(own.items()))}
            for step in route:
                if type(step) is not dict or set(step)!={"give","receive"}:
                    raise Blocked("BAD_GROWTH_STEP")
                g=_slots(step["give"],quotes);t=_slots(step["receive"],quotes)
                candidate=_after(own,g,t)
                nominal=_total(t,quotes)-_total(g,quotes)
                robust=_total(t,quotes,"low")-_total(g,quotes,"high")
                if nominal<0:
                    raise Blocked("LOSS_BUDGET_NULL_NEVER_APPROVED")
                if robust<0:
                    raise Blocked("RANGE_DOWNSIDE_UNFUNDED")
                identity=tuple(sorted(candidate.items()))
                if identity in seen:
                    raise Blocked("CIRCULAR_REPACKAGING_NOT_GROWTH")
                seen.add(identity)
                minimum_robust=min(minimum_robust,robust)
                own=candidate
            quality=_quality(own,quotes)
            remaining=max(0,quotes[TARGET]["value"]-quality["total"])
            audited.append({"index":index,
              "startingListedValue":_total(start,quotes),
              "endingListedValue":quality["total"],
              "remainingNominalTargetGap":remaining,
              "quality":quality,"minimumStepWorstCaseGain":minimum_robust,
              "futurePartnerAvailabilityVerified":False,
              "syntheticSteps":len(route)})
        # Target gap first, then structural quality; no fake counterparties.
        winner=min(audited,key=lambda c:(
            c["remainingNominalTargetGap"],
            c["quality"]["unstableBasisPoints"],
            c["quality"]["concentrationBasisPoints"],
            -c["quality"]["demandWeightedBasisPoints"],
            -c["minimumStepWorstCaseGain"],c["index"]))
        return _out(name,"RESEARCH_DECISION_PASS","BEST_OF_EXPLICIT_HYPOTHETICAL_ROUTES",
                    sourceFixtureSha256=seal,selectedRouteIndex=winner["index"],
                    auditedRoutes=audited,
                    futureSellersInvented=False,
                    gameTargetAcquisitionProven=False,
                    noAuthorizedListedLoss=True)
    except (Blocked,ValueError,TypeError,KeyError) as e:
        return _out(name,"BLOCKED",str(e) if isinstance(e,Blocked) else "BAD_INPUT")

def adaptive_response(*,events,expected_session,expected_partner):
    """Direct partner's revision/decline/timeout drives a conditional response.

    A one-off change never justifies labelling greed or personality. No chat
    is attributed to us unless explicitly and separately authenticated.
    """
    name="PLAYER_RESPONSE_ADAPTATION"
    try:
        if type(expected_session) is not str or not expected_session or type(expected_partner) is not str or not expected_partner:
            raise Blocked("EXACT_SESSION_AND_PARTNER_REQUIRED")
        if type(events) is not list or not 1<=len(events)<=100:
            raise Blocked("RESPONSE_EVENT_SEQUENCE_REQUIRED")
        prev_seq,rev,terminal=0,0,False
        old_decision_reusable=True
        plan="WAIT_FOR_PARTNER"
        seen_terminal=False
        for event in events:
            if (type(event) is not dict or set(event)!={"session","partner",
                "seq","revision","kind","scope"} or
                event["scope"]!="SYNTHETIC_EXACT_PARTNER" or
                event["session"]!=expected_session or event["partner"]!=expected_partner or
                type(event["seq"]) is not int or event["seq"]!=prev_seq+1 or
                type(event["revision"]) is not int or event["revision"]<rev):
                raise Blocked("UNATTRIBUTED_OR_REORDERED_PARTNER_EVENT")
            if terminal:
                raise Blocked("EVENT_ARRIVED_AFTER_TERMINAL")
            prev_seq=event["seq"]
            kind=event["kind"]
            if kind=="PARTNER_OFFER_REVISED":
                if event["revision"]!=rev+1:
                    raise Blocked("OFFER_REVISION_NOT_MONOTONIC")
                rev=event["revision"]
                old_decision_reusable=False
                plan="REPRICE_AND_RECONSIDER_BEFORE_ANY_ACTION"
            elif event["revision"]!=rev:
                raise Blocked("OFFER_REVISION_CHANGED_WITHOUT_CAUSE")
            elif kind=="PARTNER_DECLINED":
                plan="STOP_AND_ROTATE_FUTURE_PARTNER"; terminal=True
            elif kind=="PARTNER_NO_RESPONSE_TIMEOUT":
                plan="MARK_CENSORED_AND_ROTATE";terminal=True
            elif kind=="PARTNER_CANCELLED":
                plan="CANCELLED_NO_PERSONALITY_LABEL";terminal=True
            elif kind=="CLIENT_WINDOW_CLOSED_UNKNOWN":
                plan="ABSTAIN_UNVERIFIED_OUTCOME";terminal=True
            elif kind=="CHAT_OTHER_CONVERSATION":
                pass
            elif kind=="CHAT_DIRECT_ATTRIBUTED":
                # No classifier has proven meaning yet.
                plan="PASSIVE_CHAT_INTENT_REVIEW_ONLY"
            elif kind=="PARTNER_OFFER_STABLE":
                if rev==0: plan="PREVIEW_ONLY_NO_FINAL_ACCEPT"
            else:
                raise Blocked("UNRECOGNIZED_RESPONSE_EVENT")
        return _out(name,"RESEARCH_DECISION_PASS","PROTECTED_EVENT_BASED_STRATEGY_REACTION",
                    eventRevision=rev,
                    previousCandidateReusable=old_decision_reusable,
                    nextResearchAction=plan,
                    terminal=terminal,
                    learnedGreedyPersonality=False,
                    chatIntentProven=False,
                    finalAcceptActions=0)
    except (Blocked,ValueError,TypeError,KeyError) as e:
        return _out(name,"BLOCKED",str(e) if isinstance(e,Blocked) else "BAD_INPUT")

def learning_decision(*,episodes,minimum_unique_partners=12):
    """Actually FIT a conditional response model, then test unseen partners.

    Observed request acceptance is NOT final trade acceptance or settlement.
    Only independently attributable, unambiguous PUBLIC response episodes may
    enter this *offline* training. ALT, ambiguous UNKNOWN/timeout/cancel are
    quarantined, never converted to negative successful-trade labels.

    A Beta-Bernoulli conditional model is trained on observed response
    contexts (ordinal demand and displayed nominal offer ratio bins), NOT
    account identities or presumed greedy personalities. The model's
    TEST/HOLDOUT predictions are generated only AFTER fitting on training
    data. A global training-rate baseline must be beaten on disjoint partners.
    """
    name="OUTCOME_QUALITY_LEARNING"
    contexts={
      ("LOW","UNDER"),("LOW","FAIR"),("LOW","OVER"),
      ("MID","UNDER"),("MID","FAIR"),("MID","OVER"),
      ("HIGH","UNDER"),("HIGH","FAIR"),("HIGH","OVER"),
    }
    try:
        if type(episodes) is not list or not 20<=len(episodes)<=1000:
            raise Blocked("RESPONSE_LEARNING_DATASET_INSUFFICIENT")
        eligible=[];quarantined=Counter();identities=set()
        for e in episodes:
            if type(e) is not dict or set(e)!={"episode","partner","scope","kind",
                  "attributed","holdout","demandTier","displayedRatioBand"}:
                raise Blocked("LEARNING_EVIDENCE_FIELDS_INVALID")
            if (type(e["episode"]) is not str or not e["episode"] or
                type(e["partner"]) is not str or not e["partner"] or
                type(e["attributed"]) is not bool or type(e["holdout"]) is not bool or
                (e["demandTier"],e["displayedRatioBand"]) not in contexts):
                raise Blocked("LEARNING_EVENT_CONTEXT_INVALID")
            if e["episode"] in identities:
                raise Blocked("LEARNING_REPLAYED_EPISODE")
            identities.add(e["episode"])
            if e["scope"]!="PUBLIC_NONALT" or not e["attributed"]:
                quarantined["ALT_OR_UNATTRIBUTED"]+=1
                continue
            if e["kind"]=="EXPLICIT_PARTNER_DECLINE":
                label=0
            elif e["kind"]=="EXPLICIT_PARTNER_REQUEST_ACCEPTED":
                label=1
            elif e["kind"] in ("UNKNOWN","NO_RESPONSE_TIMEOUT","PARTNER_CANCELLED"):
                quarantined["CENSORED_OR_UNKNOWN"]+=1
                continue
            else:
                raise Blocked("UNSUPPORTED_OUTCOME_KIND")
            eligible.append((e,label))
        holdout=[(e,y) for e,y in eligible if e["holdout"]]
        train=[(e,y) for e,y in eligible if not e["holdout"]]
        participants={e["partner"] for e,_ in eligible}
        overlap={e["partner"] for e,_ in holdout}.intersection(
                 {e["partner"] for e,_ in train})
        if (len(participants)<minimum_unique_partners or
            len(holdout)<6 or len(train)<12 or overlap):
            return _out(name,"ABSTAIN","INSUFFICIENT_INDEPENDENT_PARTNER_HOLDOUT",
                        eligible=len(eligible),quarantined=dict(quarantined),
                        trainingEpisodes=len(train),holdoutEpisodes=len(holdout),
                        researchModelSelected=False)
        # Conditional response counts are the learned model. No input prediction
        # can be injected. Laplace smoothing avoids zero/one certainty.
        positives=Counter()
        totals=Counter()
        for e,y in train:
            context=(e["demandTier"],e["displayedRatioBand"])
            totals[context]+=1
            positives[context]+=y
        global_rate=(1+sum(y for _,y in train))/(2+len(train))
        def brier(kind):
            score=0.0
            for e,y in holdout:
                c=(e["demandTier"],e["displayedRatioBand"])
                prediction=((1+positives[c])/(2+totals[c])) if kind=="model" else global_rate
                score+=(prediction-y)**2
            return score/len(holdout)
        model,baseline=brier("model"),brier("baseline")
        better=model+0.001<baseline and all(
            totals[(e["demandTier"],e["displayedRatioBand"])]>=2 for e,_ in holdout)
        return _out(name,"RESEARCH_DECISION_PASS" if better else "ABSTAIN",
                    "TRAINED_MODEL_BEATS_UNSEEN_PARTNER_BASELINE" if better else
                    "NO_HELDOUT_GAIN_NO_LEARNING_UPDATE",
                    eligible=len(eligible),trainingEpisodes=len(train),
                    holdoutEpisodes=len(holdout),quarantined=dict(quarantined),
                    brierScore=round(model,5),
                    baselineBrierScore=round(baseline,5),
                    researchModelSelected=better,
                    independentPartnerHoldout=True,
                    researchConditionalBucketsFitted=len(totals),
                    productionLearningAuthorized=False,
                    verifiedTradesForProfit=0,
                    acceptedClientRequestNotGameSettlement=True)
    except (Blocked,ValueError,TypeError,KeyError,OverflowError) as e:
        return _out(name,"BLOCKED",str(e) if isinstance(e,Blocked) else "BAD_INPUT")
