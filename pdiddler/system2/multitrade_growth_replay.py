"""System2 Part5: multi-step inventory growth replay, offline simulations ONLY.

Inventories after step 1 are **hypothetical**, not forged current-client
receipts. Source IDs/prices come only from original pinned 189-value research.
No simulated offer can assert actual partner interest, fulfillment, settlement,
verified liquidity, executable four-slot control or a funded target deal.
"""
from __future__ import annotations

from pdiddler.system2.market_research_reader import _index, TARGET_KEY
from pdiddler.system2.trade_scenario_lab import (
    _owned_from_shadow, _slots, _totals, SIMULATION_KIND,
)
from pdiddler.system2.operator_capture_adapter import AUTHORITY_DENIED, EXPORT_SHA256

SCHEMA = "gingerscope-system2-multitrade-growth-replay-v1"
MAX_STEPS = 8


def _out(status, reason, **fields):
    return {
        "schema": SCHEMA,
        "status": status,
        "reason": reason,
        "simulationOnly": True,
        "allLaterInventoriesHypothetical": True,
        "executionOrOfferPlan": False,
        "stage120LiveMarketAuthorized": False,
        "liveMarketExpiryProven": False,
        "partnerAcceptanceProbability": None,
        "empiricalLiquidityEvidence": "UNKNOWN",
        "serverTradeCompletionProven": False,
        "autoAcceptAuthorized": False,
        "sourceEditionAuthenticated": False,
        "currentGameItemInstanceProven": False,
        "protectedGingerscopeNeverOutgoing": True,
        **fields, **AUTHORITY_DENIED,
    }


def _identity(holdings):
    return tuple(sorted((k,qty) for k,qty in holdings.items() if qty))


def _portfolio_value(holdings, idx):
    return sum(idx[key]["decimalValue"] * qty for key,qty in holdings.items())


def simulate(mapped, shadow, steps, *, evaluated_at_utc=None):
    """Read one legitimate offline shadow, then use ONLY synthetic copy ledgers."""
    try:
        idx = _index(mapped)
        owned, starting_value = _owned_from_shadow(shadow, idx, evaluated_at_utc=evaluated_at_utc)
        if type(steps) is not list or not 2 <= len(steps) <= MAX_STEPS:
            raise ValueError("GROWTH_PATH_REQUIRES_TWO_TO_EIGHT_HYPOTHETICAL_STEPS")
        if sum(owned.values()) <= 0:
            raise ValueError("NO_CLIENT_OBSERVED_ELIGIBLE_STARTING_COPIES")
        hypothetical = dict(owned)
        seen = {_identity(hypothetical)}
        transitions = []
        prior_target = hypothetical.get(TARGET_KEY,0)
        target_witnessed_in_hypothesis = False
        current_value = starting_value
        any_stack_unvalidated = False
        for number, scenario in enumerate(steps, 1):
            if (type(scenario) is not dict
                    or set(scenario) != {"kind","outgoingSlots","incomingSlots"}
                    or scenario.get("kind") != SIMULATION_KIND):
                raise ValueError("STEP_" + str(number) + "_EXPLICIT_SYNTHETIC_SCENARIO_REQUIRED")
            out = _slots(scenario["outgoingSlots"], allow_empty=False)
            rec = _slots(scenario["incomingSlots"], allow_empty=False)
            if TARGET_KEY in out:
                raise ValueError("STEP_" + str(number) + "_PROTECTED_GINGERSCOPE_NEVER_OUTGOING")
            if any(k not in idx for k in (*out, *rec)):
                raise ValueError("STEP_" + str(number) + "_UNKNOWN_RAW_KEY")
            if any(hypothetical.get(k,0) < qty for k,qty in out.items()):
                raise ValueError("STEP_" + str(number) + "_HYPOTHETICAL_STOCK_SHORTFALL")
            outgoing = _totals(out,idx)
            incoming = _totals(rec,idx)
            delta = incoming["listed"] - outgoing["listed"]
            per_step_stack_uncertain = bool(outgoing["publisherStackPricingUncertainKeys"] or
                                            incoming["publisherStackPricingUncertainKeys"])
            any_stack_unvalidated = any_stack_unvalidated or per_step_stack_uncertain
            if delta < 0:
                return _out("BLOCKED_LOSS_POLICY",
                    "STEP_" + str(number) + "_UNAPPROVED_LISTED_LOSS",
                    blockedAtStep=number, hypotheticalCompletedSteps=number-1,
                    noLossAlternativesEvaluated=False,
                    validatedApprovedLossBudget=False,
                    sourceExportSha256=EXPORT_SHA256)
            for k,qty in out.items():
                hypothetical[k] -= qty
                if not hypothetical[k]:
                    del hypothetical[k]
            for k,qty in rec.items():
                hypothetical[k] = hypothetical.get(k,0) + qty
            new_value = _portfolio_value(hypothetical,idx)
            if new_value != current_value + delta:
                raise ValueError("STEP_" + str(number) + "_VALUE_CONSERVATION_CONFLICT")
            stamp = _identity(hypothetical)
            if stamp in seen:
                raise ValueError("STEP_" + str(number) + "_PORTFOLIO_CYCLE_DETECTED")
            seen.add(stamp)
            observed_target = hypothetical.get(TARGET_KEY,0)
            if observed_target > prior_target:
                target_witnessed_in_hypothesis = True
            prior_target = observed_target
            notes=[]
            if incoming["low"] - outgoing["high"] < 0:
                notes.append("RANGE_DOWNSIDE_POSSIBLE")
            if incoming["copies"]>4 or outgoing["copies"]>4:
                notes.append("STACKED_COPIES_ARE_NOT_PHYSICAL_SLOTS")
            if per_step_stack_uncertain:
                notes.append("PUBLISHER_NONLINEAR_5PLUS_SAME_ITEM_STACK")
            if observed_target > 0:
                notes.append("TARGET_COPIES_ONLY_HYPOTHETICAL_OR_CLIENT_OBSERVED")
            if delta==0:
                notes.append("NO_LISTED_VALUE_GROWTH_THIS_STEP")
            notes.append("COUNTERPARTY_INTEREST_AND_RETRADE_LIQUIDITY_UNKNOWN")
            transitions.append({
                "step":number,
                "scenarioKind":"UPGRADE" if len(rec)<len(out) else
                   ("DOWNGRADE" if len(rec)>len(out) else "SIDEGRADE"),
                "outgoingPhysicalSlots":len(out),
                "incomingPhysicalSlots":len(rec),
                "outgoingCopies":outgoing["copies"],
                "incomingCopies":incoming["copies"],
                "outgoingListed":outgoing["listed"],
                "incomingListed":incoming["listed"],
                "listedDelta":delta,
                "listedDeltaReliableForNegotiation":not per_step_stack_uncertain,
                "outgoingUncertainStackKeys":outgoing["publisherStackPricingUncertainKeys"],
                "incomingUncertainStackKeys":incoming["publisherStackPricingUncertainKeys"],
                "worstCaseListedRangeDelta":incoming["low"]-outgoing["high"],
                "hypotheticalPortfolioListedValueAfterStep":new_value,
                "hypotheticalOwnedTargetCopies":observed_target,
                "warnings":notes,
                "actionAuthorized":False,
            })
            current_value = new_value
        target = idx[TARGET_KEY]["decimalValue"]
        return _out(
            ("OFFLINE_GROWTH_PATH_STACK_UNCERTAIN" if any_stack_unvalidated
             else "OFFLINE_GROWTH_PATH_SIMULATED"),
            ("PUBLISHER_STACK_VALUATION_CANNOT_SUPPORT_GROWTH_COMPARISON"
             if any_stack_unvalidated else "MULTISTEP_LISTED_VALUE_PATH_NOT_EXECUTABLE_OR_LEARNED"),
            sourceExportSha256=EXPORT_SHA256,
            simulatedSteps=len(transitions),
            startingListedPortfolioValue=starting_value,
            endingHypotheticalListedPortfolioValue=current_value,
            hypotheticalListedValueGrowth=current_value-starting_value,
            growthPaperArithmeticReliableForNegotiation=not any_stack_unvalidated,
            unknownStackTradeValueNeedsIndependentEvidence=any_stack_unvalidated,
            startingGapToGingerscope=max(0,target-starting_value),
            endingHypotheticalGapToGingerscope=max(0,target-current_value),
            goalTargetHypotheticallyReceived=target_witnessed_in_hypothesis,
            hypotheticalEndingProtectedGingerscopeCopies=hypothetical.get(TARGET_KEY,0),
            marketValueSufficiencyDoesNotProveFeasibleFourSlotExchange=True,
            steps=transitions,
        )
    except (TypeError,ValueError,KeyError,AttributeError,OverflowError) as ex:
        return _out("BLOCKED",str(ex)[:200])
