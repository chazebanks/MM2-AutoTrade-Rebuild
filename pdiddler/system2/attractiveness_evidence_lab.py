"""System2 Part4: evidence-first attractiveness comparisons across hypothetical trades.

No inferred fill rate, no autonomous desirability score, no partner approval.
Supreme demand/stability are *source labels*, not independently measured
liquidity. This module compares simultaneous alternatives, not a sequence.
"""
from __future__ import annotations

from collections import Counter
import json

from pdiddler.system2.market_research_reader import _index
from pdiddler.system2.trade_scenario_lab import (
    _owned_from_shadow, inspect as review_scenario, SIMULATION_KIND,
)
from pdiddler.system2.operator_capture_adapter import AUTHORITY_DENIED

SCHEMA = "gingerscope-system2-offline-attractiveness-evidence-v1"

# Publisher-defined categorical terms, not measured acceptance probabilities.
# Reference: https://supremevalues.com/use (Supreme stability guide).
# Do not collapse all labels other than "Stable" into an instability penalty.
STABILITY_LABELS = frozenset({
    "Rising", "Overpaid For", "Doing Well", "Improving", "Fluctuating",
    "Receding", "Stable", "Underpaid For", "Decreasing", "Unsafe",
})
STABILITY_CAUTION = {
    "Fluctuating": "PUBLISHER_FLUCTUATING_RANGE_UNCERTAINTY",
    "Underpaid For": "PUBLISHER_FREQUENT_UNDERPAYS",
    "Decreasing": "PUBLISHER_DECREASING_RISK",
    "Unsafe": "PUBLISHER_UNSAFE_WARNING",
    "Receding": "PUBLISHER_RECEDING_LABEL",
}



def _out(status, reason, **data):
    return {
        "schema": SCHEMA, "status": status, "reason": reason,
        "simulationOnly": True,
        "partnerAppealVerified": False,
        "verifiedTradeAcceptanceProbability": None,
        "actualRetradeLiquidity": "UNKNOWN",
        "tradeOutcome": "UNKNOWN",
        "empiricallyCalibratedStrategy": False,
        "liveOfferRankingAuthorized": False,
        "qualityLossBudgetApproved": False,
        "outgoingGingerscopeProtected": True,
        **data, **AUTHORITY_DENIED,
    }


def _concentration(inventory, idx):
    pieces = {key: qty * idx[key]["decimalValue"] for key, qty in inventory.items() if qty > 0}
    listed_total = sum(pieces.values())
    if not listed_total:
        return {
            "total": 0, "largestListedPosition": None,
            "largestListedPositionShare": None, "distinctOwnedKeys": len(pieces),
        }
    largest_key = min((key for key,v in pieces.items() if v==max(pieces.values())))
    return {
        "total": listed_total,
        "largestListedPosition": largest_key,
        "largestListedPositionShare": pieces[largest_key] / listed_total,
        "distinctOwnedKeys": len(pieces),
    }


def _after(owned, scenario):
    result = dict(owned)
    for row in scenario["outgoingSlots"]:
        key, qty = row["rawGameKey"], row["quantity"]
        result[key] = result.get(key,0) - qty
        if result[key] == 0:
            del result[key]
    for row in scenario["incomingSlots"]:
        key, qty = row["rawGameKey"], row["quantity"]
        result[key] = result.get(key,0) + qty
    return result


def compare(mapped, shadow, alternatives, *, evaluated_at_utc=None):
    """Audit 2–12 simultaneous, mutually exclusive alternatives.

    Returns descriptions and research attention order only: NOT an offer,
    negotiation decision, inferred liquidity probability, or trade instruction.
    """
    try:
        idx = _index(mapped)
        owned, value_before = _owned_from_shadow(shadow, idx, evaluated_at_utc=evaluated_at_utc)
        if type(alternatives) is not list or not 2 <= len(alternatives) <= 12:
            raise ValueError("TWO_TO_TWELVE_SYNTHETIC_ALTERNATIVES_REQUIRED")
        seen = set()
        audited = []
        baseline = _concentration(owned, idx)
        for i, candidate in enumerate(alternatives):
            if type(candidate) is not dict or candidate.get("kind") != SIMULATION_KIND:
                raise ValueError("INVALID_EXPLICIT_SYNTHETIC_ALTERNATIVE")
            fingerprint = json.dumps(candidate, sort_keys=True, separators=(",",":"))
            if fingerprint in seen:
                raise ValueError("DUPLICATE_HYPOTHETICAL_ALTERNATIVE")
            seen.add(fingerprint)
            review = review_scenario(mapped,shadow,candidate,evaluated_at_utc=evaluated_at_utc)
            if review["status"] == "BLOCKED":
                audited.append({
                    "candidateIndex":i,"status":"INVALID_ALTERNATIVE",
                    "reason":review["reason"],"mayUseForTrade":False,
                })
                continue
            if review["status"] not in (
                "OFFLINE_SCENARIO_REVIEWED", "OFFLINE_LOSS_SCENARIO_BLOCKED_POLICY"
            ) or review["authorizesOffer"] is not False:
                raise ValueError("UNRECOGNIZED_SCENARIO_STATUS")
            post = _after(owned, candidate)
            if any(type(qty) is not int or qty <= 0 for qty in post.values()):
                raise ValueError("NEGATIVE_HYPOTHETICAL_INVENTORY")
            concentration = _concentration(post,idx)
            if (review["beforeListedPortfolioValue"] != value_before or
                review["afterHypotheticalListedPortfolioValue"] != concentration["total"]):
                raise ValueError("INVENTORY_CONSERVATION_CHECK_FAILED")
            issues=[]
            if review["listedDelta"]<0:
                issues.append("UNAPPROVED_LISTED_LOSS")
            if review["worstCaseRangeDelta"]<0:
                issues.append("PRICE_RANGE_DOWNSIDE_EXPOSED")
            stack_uncertain = review["listedDeltaReliableForNegotiation"] is False
            if stack_uncertain:
                issues.append("PUBLISHER_NONLINEAR_STACK_PRICE_NEEDS_INDEPENDENT_EVIDENCE")
            labels = {idx[row["rawGameKey"]]["stability"]
                      for row in candidate["incomingSlots"]}
            if not labels.issubset(STABILITY_LABELS):
                raise ValueError("UNKNOWN_PUBLISHER_STABILITY_LABEL")
            for label in sorted(labels):
                caution = STABILITY_CAUTION.get(label)
                if caution:
                    issues.append(caution)
            if any(idx[row["rawGameKey"]]["demand"]<=2
                   for row in candidate["incomingSlots"]):
                issues.append("LOW_ORDINAL_PUBLISHER_DEMAND_LABEL")
            if (baseline["largestListedPositionShare"] is not None and
                concentration["largestListedPositionShare"] is not None and
                concentration["largestListedPositionShare"]>
                    baseline["largestListedPositionShare"]):
                issues.append("PORTFOLIO_LISTED_VALUE_CONCENTRATION_INCREASES")
            if review["hypotheticalTargetReceived"]:
                issues.append("GINGERSCOPE_HYPOTHETICALLY_INCOMING_NOT_ACQUIRED")
            issues.append("ACCEPTANCE_AND_EXECUTED_RESALE_LIQUIDITY_UNMEASURED")
            # No numeric accept/retrade probabilities are derived or recorded.
            audited.append({
                "candidateIndex":i,
                "status":("LOSS_NOT_AUTHORIZED" if review["listedDelta"]<0 else
                          "PAPER_STACK_VALUE_UNCERTAIN" if stack_uncertain else
                          "OFFLINE_RESEARCH_CANDIDATE_ONLY"),
                "scenarioKind":review["scenarioKind"],
                "hypotheticalTargetReceived":review["hypotheticalTargetReceived"],
                "listedDelta":review["listedDelta"],
                "worstCaseRangeDelta":review["worstCaseRangeDelta"],
                "beforeListedConcentration":baseline["largestListedPositionShare"],
                "afterListedConcentration":concentration["largestListedPositionShare"],
                "distinctKeysAfter":concentration["distinctOwnedKeys"],
                "incomingDemandValueWeightedMean":review["incomingDemandValueWeightedMean"],
                "listedDeltaReliableForNegotiation":review["listedDeltaReliableForNegotiation"],
                "incomingSourceStabilityCounts":review["incomingStabilityCounts"],
                "evidenceWarnings":issues,
                "verifiedPartnerAppeal":False,
                "empiricalLiquiditySampleSize":0,
                "mayUseForTrade":False,
            })
        # A lower warning count indicates *what to investigate first*.
        # It is NOT an offer preference, learned accept likelihood, or policy.
        # Stack-price-uncertain alternatives are EXCLUDED from the nominal
        # attention ordering until independent executable-value evidence exists.
        valid = [a for a in audited if a["status"]=="OFFLINE_RESEARCH_CANDIDATE_ONLY"]
        attention = sorted(valid, key=lambda a:(
            len(a["evidenceWarnings"]), -a["listedDelta"], a["candidateIndex"]
        ))
        has_nonloss = bool(valid)
        for a in audited:
            if a["status"]=="LOSS_NOT_AUTHORIZED":
                a["hasNoLossAlternativeInBatch"]=has_nonloss
        return _out(
            "OFFLINE_ATTRACTIVENESS_EVIDENCE_COMPARISON_ONLY",
            "NO_EMPIRICAL_ACCEPTANCE_OR_RETRADE_FILL_EVIDENCE",
            baselineListedValue=value_before,
            alternativesReviewed=len(audited),
            nonLossResearchAlternatives=len(valid),
            stackPriceUncertainAlternatives=sum(a["status"]=="PAPER_STACK_VALUE_UNCERTAIN" for a in audited),
            lossBlockedAlternatives=sum(a["status"]=="LOSS_NOT_AUTHORIZED" for a in audited),
            invalidAlternatives=sum(a["status"]=="INVALID_ALTERNATIVE" for a in audited),
            researchAttentionIndices=[a["candidateIndex"] for a in attention],
            researchAttentionOrderIsNotAnOfferRanking=True,
            alternatives=audited,
        )
    except (TypeError,ValueError,KeyError,AttributeError,OverflowError) as err:
        return _out("BLOCKED",str(err)[:200])
