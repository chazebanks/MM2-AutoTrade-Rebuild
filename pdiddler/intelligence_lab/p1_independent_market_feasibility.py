"""P1 source-free MM2 barter-data identifiability feasibility (OFFLINE SYNTHETIC).

Examines whether *hypothetical* barter equations could constrain relative item
values if future settlement evidence became independently verifiable.
It DOES NOT estimate market prices, certify settlement, infer attractiveness,
collect player data, or authorize trading. Real event input is forbidden.
"""
from __future__ import annotations

from fractions import Fraction
from collections import Counter

SCHEMA = "gingerscope-p1-self-observed-market-feasibility-v1"
DENIED = {
    "authorizesOffer": False, "authorizesTrade": False,
    "authorizesAccept": False, "verifiedMarketQuote": False,
    "serverCompletionProven": False, "mayReportProfit": False,
    "maySendDiscordWebhook": False, "mayUseForStrategyLearning": False,
    "mayUpdateProduction": False, "mayUpdatePriceFiles": False,
}
MAX_PHYSICAL_SLOTS = 4
MAX_SYNTHETIC_EVENTS = 250
MAX_KEYS = 128


class FeasibilityInputError(ValueError):
    pass


def _ensure(condition, code):
    if not condition:
        raise FeasibilityInputError(code)


def _rank(rows, width):
    """Exact Gaussian elimination over rationals, for modest research fixtures."""
    a = [[Fraction(x) for x in row] for row in rows]
    rank = 0
    for col in range(width):
        pivot = next((i for i in range(rank, len(a)) if a[i][col] != 0), None)
        if pivot is None:
            continue
        a[rank], a[pivot] = a[pivot], a[rank]
        v = a[rank][col]
        a[rank] = [x / v for x in a[rank]]
        for i in range(rank + 1, len(a)):
            v = a[i][col]
            if v:
                a[i] = [left - v * right for left, right in zip(a[i], a[rank])]
        rank += 1
        if rank == len(a):
            break
    return rank


def _side(data):
    _ensure(type(data) is list and 1 <= len(data) <= MAX_PHYSICAL_SLOTS,
            "INVALID_PHYSICAL_SLOT_COUNT")
    result = Counter()
    for slot in data:
        _ensure(type(slot) is dict and set(slot) == {"key", "quantity"},
                "INVALID_SLOT_SCHEMA")
        key, count = slot["key"], slot["quantity"]
        _ensure(type(key) is str and key.startswith("TEST_") and len(key) <= 80,
                "REAL_OR_INVALID_ITEM_ID_FORBIDDEN")
        _ensure(type(count) is int and 1 <= count <= 1_000_000,
                "INVALID_STACK_QUANTITY")
        _ensure(key not in result, "DUPLICATE_PHYSICAL_SLOT_KEY")
        result[key] = count
    return result


def analyze(events, *, reference_key="TEST_A"):
    """Diagnose hypothetical linear constraints; no real input or market output.

    Each TEST event represents equality of item *sums* for structural testing.
    Real completed swaps need not have equal market value, and neither barter
    prices nor value scale can be established merely from this model.
    """
    _ensure(type(events) is list and len(events) <= MAX_SYNTHETIC_EVENTS,
            "INVALID_SYNTHETIC_EVENT_LIST")
    _ensure(type(reference_key) is str and reference_key.startswith("TEST_"),
            "REAL_OR_INVALID_REFERENCE_KEY")
    ids = set()
    equations = []
    all_keys = set()
    for event in events:
        _ensure(type(event) is dict and set(event) ==
                {"eventId", "mode", "given", "received"}, "INVALID_EVENT_SCHEMA")
        event_id = event["eventId"]
        _ensure(type(event_id) is str and 0 < len(event_id) <= 80
                and event_id not in ids, "DUPLICATE_OR_INVALID_EVENT")
        ids.add(event_id)
        _ensure(event["mode"] == "HYPOTHETICAL_ONLY",
                "UNVERIFIED_OR_REAL_SETTLEMENT_INPUT_FORBIDDEN")
        given, received = _side(event["given"]), _side(event["received"])
        equation = Counter(received)
        equation.subtract(given)
        all_keys.update(equation.keys())
        equations.append(equation)
    _ensure(len(all_keys) <= MAX_KEYS, "TOO_MANY_SYNTHETIC_KEYS")

    keys = sorted(all_keys)
    width = len(keys)
    matrix = [[eq.get(k, 0) for k in keys] for eq in equations]
    constraint_rank = _rank(matrix, width)
    anchored = reference_key in all_keys
    with_anchor = matrix + [[int(k == reference_key) for k in keys]] if anchored else matrix
    anchored_rank = _rank(with_anchor, width)
    identifiable = []
    for idx, key in enumerate(keys):
        basis = [int(i == idx) for i in range(width)]
        if _rank(with_anchor + [basis], width) == anchored_rank:
            identifiable.append(key)
    return {
        "schema": SCHEMA,
        "status": "SYNTHETIC_RESEARCH_ONLY",
        "reason": "NO_REAL_VERIFIED_SETTLEMENT_OR_PRICE_ANCHOR",
        "hypotheticalEventCount": len(events),
        "realVerifiedSettlementCount": 0,
        "syntheticItemKeys": width,
        "equalityConstraintRank": constraint_rank,
        "arbitraryReferenceKey": reference_key,
        "referenceIncludedInSyntheticGraph": anchored,
        "rankWithArbitraryUnitReference": anchored_rank,
        "unresolvedDegreesOfFreedomWithReference": width - anchored_rank,
        "structurallyIdentifiableSyntheticRelativeKeys": identifiable,
        "underdeterminedSyntheticRelativeKeys":
            [key for key in keys if key not in identifiable],
        "barterEqualityAssumptionUnproven": True,
        "absoluteMarketScaleIdentifiable": False,
        "priceEstimates": None,
        "mayUseForLivePriceCalibration": False,
        "realItemIdentityVerified": False,
        "mayAdvanceP2": False,
        "tradeOutcome": "UNKNOWN",
        **DENIED,
    }


def empty_checkpoint():
    """Current repo-known validated trade count = 0; no fabricated events."""
    return analyze([])
