"""Bounded, deterministic OFFLINE MM2 portfolio trade-candidate planner.

Builds research-only upgrade/downgrade ideas from a *preselected* small shortlist.
Not integrated into MM2/Delta; no offer placement, automatic Accept or settlement.
All caller-supplied identity/market evidence is untrusted and unverified here.
"""
from __future__ import annotations

import itertools
from typing import Any

SCHEMA = "gingerscope-offline-portfolio-candidate-v1"
MAX_TYPES_PER_SIDE = 5
MAX_COPIES_PER_TYPE = 2
MAX_COPIES_PER_SIDE = 4
MAX_VALUE = 1_000_000
MAX_TOTAL_VALUE = 100_000_000


def _result(status: str, reason: str, candidates: list | None = None) -> dict[str, Any]:
    return {
        "schema": SCHEMA,
        "status": status,
        "reason": reason,
        "candidates": [] if candidates is None else candidates,
        "enumerationCompleteForProvidedShortlists": status in {"CANDIDATES_PREPARED", "NO_CANDIDATES"},
        "globalInventoryOptimalityProven": False,
        "counterpartyConsentProven": False,
        "weaponIdentityAuthenticated": False,
        "serverCompletionProven": False,
        "mayRecordCompletedTrade": False,
        "mayUseForStrategyLearning": False,
        "mayReportProfit": False,
        "authorizesTrade": False,
        "authorizesAccept": False,
        "tradeOutcome": "UNKNOWN",
    }


def _inventory(rows: object) -> dict[str, int] | None:
    if not isinstance(rows, list) or not 1 <= len(rows) <= MAX_TYPES_PER_SIDE:
        return None
    out = {}
    for row in rows:
        if not isinstance(row, dict):
            return None
        key, count = row.get("key"), row.get("quantity")
        if (not isinstance(key, str) or not 1 <= len(key) <= 80 or key in out
                or type(count) is not int or not 1 <= count <= MAX_COPIES_PER_TYPE):
            return None
        out[key] = count
    return dict(sorted(out.items()))


def _offers(inv: dict[str, int]):
    keys = list(inv)
    for quantities in itertools.product(*(range(inv[key] + 1) for key in keys)):
        if 1 <= sum(quantities) <= MAX_COPIES_PER_SIDE:
            yield [(key, qty) for key, qty in zip(keys, quantities) if qty]


def _metric_sum(offer, items, name):
    return sum(items[key][name] * qty for key, qty in offer)


def _hhi(holdings: dict[str, int], items: dict) -> float:
    terms = [qty * items[key]["value"] for key, qty in holdings.items() if qty]
    total = sum(terms)
    if not total:
        return 0
    return sum(x * x for x in terms) / (total * total)


def plan(
    our_shortlist: object,
    their_shortlist: object,
    market: object,
    *,
    now: int,
    min_gain: int = 0,
    min_received_demand: int = 4,
    min_received_liquidity: int = 4,
    max_counterparty_overpay_pct: int = 50,
    max_results: int = 5,
) -> dict[str, Any]:
    """Compute hypothetical proposals; never a real-trading authorization.

    The five-types-per-side cap is deliberate: passing an entire inventory must
    fail visibly instead of silently truncating it. Publisher timestamp and
    exact identity fields are mandatory but are NOT authenticated by this code.
    """
    a, b = _inventory(our_shortlist), _inventory(their_shortlist)
    if a is None or b is None:
        return _result("BLOCKED", "INVALID_OR_TOO_LARGE_INPUT_SHORTLIST")
    if (type(now) is not int or not 1_700_000_000 <= now <= 2_100_000_000
            or type(min_gain) is not int or not 0 <= min_gain <= MAX_VALUE
            or type(min_received_demand) is not int or not 1 <= min_received_demand <= 10
            or type(min_received_liquidity) is not int or not 1 <= min_received_liquidity <= 10
            or type(max_counterparty_overpay_pct) is not int or
            not 0 <= max_counterparty_overpay_pct <= 100
            or type(max_results) is not int or not 1 <= max_results <= 10):
        return _result("BLOCKED", "INVALID_POLICY_OR_CLOCK")

    if not isinstance(market, dict) or market.get("source") != "SUPREME_DISPLAY_RESEARCH_ONLY":
        return _result("BLOCKED", "MARKET_SOURCE_UNKNOWN")
    if not isinstance(market.get("version"), str) or not market["version"]:
        return _result("BLOCKED", "MARKET_VERSION_MISSING")
    updated = market.get("publisherUpdatedAtUnix")
    retrieved = market.get("retrievedAtUnix")
    if (type(updated) is not int or type(retrieved) is not int
            or not 1_700_000_000 <= updated <= retrieved <= now
            or now - updated > 48 * 3600):
        return _result("BLOCKED", "PUBLISHER_EVIDENCE_MISSING_OR_EXPIRED")
    items = market.get("items")
    if not isinstance(items, dict):
        return _result("BLOCKED", "MARKET_ITEMS_MISSING")
    relevant = set(a) | set(b)
    for key in relevant:
        r = items.get(key)
        if not isinstance(r, dict) or r.get("identityLinkEvidence") != "INDEPENDENT_EXACT":
            return _result("BLOCKED", "UNKNOWN_OR_UNPROVEN_ITEM_IDENTITY")
        if (type(r.get("value")) is not int or not 1 <= r["value"] <= MAX_VALUE
                or type(r.get("demand")) is not int or not 1 <= r["demand"] <= 10
                or type(r.get("liquidity")) is not int or not 1 <= r["liquidity"] <= 10
                or not isinstance(r.get("stability"), str)):
            return _result("BLOCKED", "UNKNOWN_MARKET_VALUE_OR_DESIRABILITY")

    baseline_hhi = _hhi(a, items)
    prepared = []
    own = list(_offers(a))
    theirs = [
        offer for offer in _offers(b)
        if all(items[key]["demand"] >= min_received_demand
               and items[key]["liquidity"] >= min_received_liquidity
               and items[key]["stability"] in {"Stable", "Overpaid For"}
               for key, _ in offer)
    ]
    # Five types with at most two of each yield at most 95 nonempty
    # four-copy bundles per side, or 9,025 candidate pair comparisons.
    for giving in own:
        our_value = _metric_sum(giving, items, "value")
        our_keys = {key for key, _ in giving}
        for getting in theirs:
            if any(key in our_keys for key, _ in getting):
                continue  # swapping same item to itself obscures inventory risk.
            their_value = _metric_sum(getting, items, "value")
            delta = their_value - our_value
            if delta < min_gain or 100 * delta > max_counterparty_overpay_pct * our_value:
                continue
            after = dict(a)
            for key, qty in giving:
                after[key] -= qty
            for key, qty in getting:
                after[key] = after.get(key, 0) + qty
            # Market profile for all keys in our shortlist and incoming offer.
            after_hhi = _hhi(after, items)
            count_out = sum(qty for _, qty in giving)
            count_in = sum(qty for _, qty in getting)
            kind = "UPGRADE" if count_out > count_in else (
                "DOWNGRADE" if count_out < count_in else "SIDEGRADE"
            )
            # Score is only a declared research ordering, NOT execution odds.
            base = (4 * delta
                    + _metric_sum(getting, items, "demand")
                    + _metric_sum(getting, items, "liquidity")
                    - _metric_sum(giving, items, "demand")
                    - _metric_sum(giving, items, "liquidity"))
            concentration_penalty = round(100 * max(0.0, after_hhi - baseline_hhi))
            score = base - concentration_penalty
            prepared.append({
                "type": kind,
                "offer": [{"key": k, "quantity": q} for k, q in giving],
                "receive": [{"key": k, "quantity": q} for k, q in getting],
                "offeredListedValue": our_value,
                "receivedListedValue": their_value,
                "projectedListedGain": delta,
                "scoreResearchOnly": score,
                "concentrationIncreasePenalty": concentration_penalty,
            })
    prepared.sort(key=lambda x: (
        -x["scoreResearchOnly"], -x["projectedListedGain"],
        x["type"],
        tuple((r["key"], r["quantity"]) for r in x["offer"]),
        tuple((r["key"], r["quantity"]) for r in x["receive"]),
    ))
    if not prepared:
        return _result("NO_CANDIDATES", "NO_NONNEGATIVE_SAFE_RESEARCH_PROPOSAL")
    result = _result("CANDIDATES_PREPARED", "SYNTHETIC_ONLY_NOT_LIVE_TRADING",
                     prepared[:max_results])
    result["candidatePairsConsidered"] = len(prepared)
    result["searchCap"] = {"maxDistinctTypesPerSide": MAX_TYPES_PER_SIDE,
                           "maxCopiesPerType": MAX_COPIES_PER_TYPE,
                           "maxSlotsPerSide": MAX_COPIES_PER_SIDE,
                           "maxCopiesPerSide": MAX_COPIES_PER_SIDE}
    return result
