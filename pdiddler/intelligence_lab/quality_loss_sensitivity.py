"""Offline sensitivity checks for controlled quality-upgrade losses.

Never a live trade planner, price oracle, or authorization gate.
Inputs are hypothetical / untrusted; the value of a trade's future
retradability and the likelihood a partner accepts are NOT inferred here.
"""
from __future__ import annotations

from decimal import Decimal
from typing import Any

SCHEMA = "gingerscope-quality-loss-sensitivity-offline-v1"
CAPS_BPS = (0, 50, 100, 200, 300)
MAX_PHYSICAL_SLOTS = 4
MAX_VALUE = 10**9

FLAGS = {
    "researchOnly": True,
    "marketQuoteAuthenticated": False,
    "itemIdentityAuthenticated": False,
    "liquidityVerified": False,
    "acceptanceProbabilityVerified": False,
    "serverCompletionProven": False,
    "mayUseForStrategyLearning": False,
    "authorizesTrade": False,
    "authorizesOffer": False,
    "authorizesAccept": False,
    "mayReportProfit": False,
    "tradeOutcome": "UNKNOWN",
}


def _result(status: str, reason: str, **payload: Any) -> dict[str, Any]:
    return {"schema": SCHEMA, "status": status, "reason": reason, **payload, **FLAGS}


def _value(slots: object, market: object, *, outgoing: bool) -> int | None:
    # Physical slots, not total copies. No implicit truncation of stacks.
    if type(slots) is not list or not 1 <= len(slots) <= MAX_PHYSICAL_SLOTS:
        return None
    if type(market) is not dict:
        return None
    total = 0
    for slot in slots:
        if type(slot) is not dict or set(slot) != {"key", "quantity"}:
            return None
        key, qty = slot["key"], slot["quantity"]
        if type(key) is not str or not 1 <= len(key) <= 80:
            return None
        if outgoing and key.lower().replace(" ", "") == "gingerscope":
            return None
        if type(qty) is not int or not 1 <= qty <= 100:
            return None
        val = market.get(key)
        if type(val) is not int or not 1 <= val <= MAX_VALUE:
            return None
        total += val * qty
        if total > MAX_VALUE:
            return None
    return total


def study_candidate(offer: object, receive: object, hypothetical_values: object) -> dict[str, Any]:
    """Return exact loss math and exploratory caps; NEVER authorize a trade."""
    ours = _value(offer, hypothetical_values, outgoing=True)
    theirs = _value(receive, hypothetical_values, outgoing=False)
    if ours is None or theirs is None:
        return _result("BLOCKED", "INVALID_SLOTS_MARKET_OR_PROTECTED_GINGERSCOPE")
    loss = max(0, ours - theirs)
    delta = theirs - ours
    cap_tests = [
        {"capBasisPoints": cap, "withinHypotheticalCap": loss * 10000 <= ours * cap}
        for cap in CAPS_BPS
    ]
    # A hypothetical cap is not a configured risk budget or permission.
    return _result(
        "SIMULATED", "HYPOTHETICAL_LISTED_VALUE_ONLY",
        outgoingListedValue=ours,
        incomingListedValue=theirs,
        listedDelta=delta,
        listedLoss=loss,
        listedLossBasisPointsExact=f"{loss * 10000}/{ours}",
        capScenarios=cap_tests,
        qualityImprovementProven=False,
        approvedRiskBudget=None,
    )


def repeated_loss_retention(cap_bps: int, repeats: int = 10) -> str:
    """Exact decimal compounding in an artificial no-offsetting-gains scenario."""
    if type(cap_bps) is not int or not 0 <= cap_bps < 10000:
        raise ValueError("invalid hypothetical basis-point cap")
    if type(repeats) is not int or not 0 <= repeats <= 10000:
        raise ValueError("invalid number of hypothetical trades")
    retained = (Decimal(1) - Decimal(cap_bps) / Decimal(10000)) ** repeats
    return format(retained, "f")


def break_even_exit_probability(
    original_outgoing_value: int, low_exit_value: int, high_exit_value: int,
    opportunity_cost: int = 0,
) -> dict[str, Any]:
    """Toy two-exit model; no learned probability or real completed fills."""
    nums = (original_outgoing_value, low_exit_value, high_exit_value, opportunity_cost)
    if any(type(x) is not int or x < 0 or x > MAX_VALUE for x in nums):
        return _result("BLOCKED", "INVALID_HYPOTHETICAL_EXIT_VALUES")
    if original_outgoing_value == 0 or high_exit_value <= low_exit_value:
        return _result("BLOCKED", "EXIT_RANGE_MUST_HAVE_UPSIDE")
    required = (Decimal(original_outgoing_value) + Decimal(opportunity_cost)
                - Decimal(low_exit_value)) / Decimal(high_exit_value - low_exit_value)
    if required <= 0:
        feasibility = "BREAK_EVEN_EVEN_AT_LOW_EXIT"
    elif required > 1:
        feasibility = "IMPOSSIBLE_IN_TWO_EXIT_MODEL"
    else:
        feasibility = "CONDITIONAL_NO_REAL_PROBABILITY_ESTIMATE"
    return _result(
        "SIMULATED", "ILLUSTRATIVE_TWO_EXIT_BREAK_EVEN_ONLY",
        requiredHighExitProbability=format(max(Decimal(0), required), "f"),
        feasibility=feasibility,
        estimatedActualHighExitProbability=None,
        observedCompletedTradeSampleSize=0,
    )


def audit_learning_claim(outcome: object, claimed_verification: object = None) -> dict[str, Any]:
    """An untrusted status/boolean does not prove a verified outcome."""
    if type(outcome) is not str or outcome not in {"UNKNOWN", "DECLINED", "CANCELED", "COMPLETED"}:
        return _result("BLOCKED", "UNKNOWN_OUTCOME_CLASS")
    # This module has no independent verifiable settlement or partner telemetry.
    return _result(
        "QUARANTINED", "INDEPENDENT_EVIDENCE_VALIDATOR_UNAVAILABLE",
        assertedOutcome=outcome, claimedVerificationIgnored=True,
        approvedTrainingLabel=None,
    )
