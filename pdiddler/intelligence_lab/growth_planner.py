"""Stage 5 Gingerscope inventory growth planner -- offline HUMAN REVIEW ONLY.

Consumes verified checker-ID priced items and Stage 4's three separate review
lanes. It ranks hypothetical wealth, four-copy purchasing power and source-backed
quality changes WITHOUT predicting which offers real people accept. It is not
wired into Roblox, Delta, outgoing/acceptance, bot avoidance, or server hopping.

Strict inferences:
- Supreme demand is ORDINAL (not a liquidity or acceptance probability).
- A stack's possible four-type capacity is NOT confirmed physical slot capacity.
- A price/listing and an owned item do not establish willingness to trade.
- Partial catalogue value is a lower bound, not complete inventory net worth.
"""
from __future__ import annotations
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal
from itertools import combinations
from typing import Mapping, Sequence

from evaluator import AssessmentError, Catalog, check_counts, evaluate, portfolio_metrics, money
from offer_ranker import GOAL, RankedOffer, rank_offers


@dataclass(frozen=True)
class GrowthOpportunity:
    # Exact checker-ID quantities. Display is for human review only.
    give: tuple[tuple[str, int], ...]
    receive: tuple[tuple[str, int], ...]
    category: str
    offered_value: Decimal
    received_value: Decimal
    listed_gain: Decimal
    four_copy_delta: Decimal
    four_copy_after: Decimal
    gingerscope_gap_after: Decimal
    demand_direction: str
    stable_share_delta: Decimal | None
    offered_copies: int
    received_copies: int
    source_coverage: Decimal
    flags: tuple[str, ...]
    # No estimate of likelihood of accepting or executing a trade.
    decision: str = "offline-human-review-only"


@dataclass(frozen=True)
class GrowthPlan:
    wealth_candidates: tuple[GrowthOpportunity, ...]
    four_copy_candidates: tuple[GrowthOpportunity, ...]
    quality_candidates: tuple[GrowthOpportunity, ...]
    caution_candidates: tuple[GrowthOpportunity, ...]
    observed_targets: int
    reviewable_quotes: int
    own_listed_lower_bound: Decimal
    own_four_copy_ceiling: Decimal
    gingerscope_listed_value: Decimal
    gingerscope_four_copy_gap: Decimal
    source_valid_until: datetime
    own_unpriced_copies: int
    opponent_unpriced_copies: int
    no_candidate_reason: str | None
    policy: str = "offline-human-review-only"
    note: str = "Hypothetical requests; no observed player acceptance or supported live-action advice."


def _admissible(item) -> bool:
    return (item is not None and item.verified and item.tradable
            and item.value > 0 and item.stability != "unknown")


def _incoming_targets(
    opponent: Mapping[str, int], catalog: Catalog,
    explicit: Sequence[Mapping[str, int]] | None,
    *, include_pairs: bool, max_targets: int,
) -> tuple[tuple[tuple[str, int], ...], ...]:
    if explicit is not None:
        if isinstance(explicit, (str, bytes)) or not isinstance(explicit, Sequence):
            raise AssessmentError("invalid-target-list")
        raw_targets = explicit
    else:
        keys = sorted(key for key in opponent if _admissible(catalog.items.get(key)))
        raw_targets = [{key: 1} for key in keys]
        if include_pairs:
            raw_targets += [{a: 1, b: 1} for a, b in combinations(keys, 2)]
    targets: set[tuple[tuple[str, int], ...]] = set()
    for target in raw_targets:
        check_counts(target)
        if len(target) > 4 or sum(target.values()) > 4:
            raise AssessmentError("target-exceeds-conservative-four-copy-limit")
        for key, qty in target.items():
            if opponent.get(key, 0) < qty:
                raise AssessmentError("requested-quantity-not-owned")
            if not _admissible(catalog.items.get(key)):
                raise AssessmentError("requested-item-not-verified")
        targets.add(tuple(sorted(target.items())))
        if len(targets) > max_targets:
            raise AssessmentError("growth-target-budget-exceeded")
    return tuple(sorted(targets))


def _categorize(offer: RankedOffer, demand: str) -> str:
    given = sum(q for _, q in offer.give)
    received = sum(q for _, q in offer.receive)
    if offer.gain < 0 or offer.four_copy_delta < 0:
        return "tradeoff"
    if given > received and offer.four_copy_delta > 0:
        return "upgrade"
    if received > given:
        return "downgrade"
    if offer.gain > 0:
        return "accumulate"
    if demand == "better":
        return "quality-rotation"
    return "neutral"


def _decorate(offer: RankedOffer, own: Mapping[str, int], opponent: Mapping[str, int],
              market: Catalog, now: datetime, goal_id: str) -> GrowthOpportunity:
    assessment = evaluate(own, opponent, dict(offer.give), dict(offer.receive), market, now,
                          goal_identity=goal_id)
    flags = list(offer.notes)
    if assessment.demand_profile in ("worse", "mixed"):
        flags.append("portfolio-demand-ordinal-not-unambiguously-better")
    if assessment.stable_share_delta is not None and assessment.stable_share_delta < 0:
        flags.append("portfolio-stability-share-decreases")
    if offer.four_copy_delta < 0:
        flags.append("four-copy-power-lost-even-if-nominal-profit-positive")
    if sum(q for _, q in offer.receive) > sum(q for _, q in offer.give):
        flags.append("downgrade-increases-copy-count")
    if any(market.items[k].demand <= 1 for k, _ in offer.receive):
        flags.append("received-includes-low-source-demand")
    if any(market.items[k].stability in ("fluctuating", "underpaid") for k, _ in offer.receive):
        flags.append("received-includes-fluctuating-or-underpaid-status")
    if assessment.before.unpriced_units or assessment.after.unpriced_units:
        flags.append("portfolio-metrics-exclude-unknown-items")
    if offer.coverage < 1:
        flags.append("counterparty-receives-less-listed-value")
    return GrowthOpportunity(
        give=offer.give, receive=offer.receive, category=_categorize(offer,assessment.demand_profile),
        offered_value=offer.give_value, received_value=offer.receive_value,
        listed_gain=assessment.net_listed_value, four_copy_delta=assessment.four_copy_delta,
        four_copy_after=assessment.after.four_copy_ceiling,
        gingerscope_gap_after=assessment.goal_four_copy_gap_after,
        demand_direction=assessment.demand_profile,
        stable_share_delta=assessment.stable_share_delta,
        offered_copies=sum(q for _, q in offer.give), received_copies=sum(q for _, q in offer.receive),
        source_coverage=offer.coverage, flags=tuple(dict.fromkeys(flags)),
    )


def _quote_key(x: GrowthOpportunity):
    return (x.give, x.receive)


def _caution(x: GrowthOpportunity) -> bool:
    return (x.four_copy_delta < 0 or x.demand_direction in ("mixed", "worse")
            or (x.stable_share_delta is not None and x.stable_share_delta < 0)
            or "received-includes-low-source-demand" in x.flags
            or "received-includes-fluctuating-or-underpaid-status" in x.flags)


def plan_growth(
    own: Mapping[str, int], opponent: Mapping[str, int], catalog: Catalog,
    now: datetime, *, goals: Sequence[Mapping[str, int]] | None = None,
    goal_id: str = GOAL, include_pairs: bool = False,
    max_targets: int = 20, search_budget_each: int = 50000,
    quote_limit_each: int = 30, limit: int = 10,
    min_review_coverage: Decimal = Decimal("0.90"),
) -> GrowthPlan:
    """Compare verified hypothetical target bundles, with multiple review lanes.

    Default discovery: one copy of each *catalogue-verified* opponent weapon.
    Explicit `goals` can include arbitrary 1--4-copy receive bundles. The
    optional pair discovery is bounded. All budgets fail closed; they do NOT
    silently truncate the search. No simulated opponent acceptance is implied.

    Nominal losses remain disallowed at Stage 4. A quality-beneficial nominal
    loss can be studied separately, but never silently authorized here.
    """
    catalog.validate(now)
    check_counts(own)
    check_counts(opponent)
    if not isinstance(include_pairs, bool):
        raise AssessmentError("invalid-pair-discovery")
    for label, n, upper in (("target", max_targets, 100), ("quote", quote_limit_each, 100),
                            ("result", limit, 100), ("search", search_budget_each, 1_000_000)):
        if type(n) is not int or not 1 <= n <= upper:
            raise AssessmentError(f"invalid-{label}-budget")
    gate = money(min_review_coverage)
    if gate > 1:
        raise AssessmentError("invalid-quote-coverage-gate")
    goal = catalog.items.get(goal_id)
    if not _admissible(goal):
        raise AssessmentError("unverified-goal-price")
    before = portfolio_metrics(own, catalog)
    targets = _incoming_targets(opponent, catalog, goals, include_pairs=include_pairs, max_targets=max_targets)
    all_quotes: dict[tuple[tuple[tuple[str, int], ...], tuple[tuple[str, int], ...]], GrowthOpportunity] = {}
    for target in targets:
        ranked = rank_offers(own, opponent, dict(target), catalog, now,
                             goal_id=goal_id, max_combinations=search_budget_each,
                             limit=quote_limit_each, min_review_coverage=gate,
                             allow_overpay=False)
        for offer in ranked.offers + ranked.progression_offers + ranked.accumulation_offers:
            key = (offer.give, offer.receive)
            if key not in all_quotes:
                all_quotes[key] = _decorate(offer, own, opponent, catalog, now, goal_id)
    pool = list(all_quotes.values())
    positive = [c for c in pool if c.listed_gain >= 0]
    # These lanes are comparative evidence, not permissions or a scalar claim
    # that a quote can be filled. Large nominal gains remain flagged where
    # source demand/stability and slot power disagree.
    wealth = sorted((x for x in positive if x.listed_gain > 0), key=lambda x: (
        -x.listed_gain, x.four_copy_delta < 0, _caution(x), -x.source_coverage,
        x.give, x.receive,
    ))
    power = sorted((x for x in positive if x.four_copy_delta > 0), key=lambda x: (
        -x.four_copy_delta, _caution(x), -x.listed_gain, -x.source_coverage,
        x.give, x.receive,
    ))
    quality = sorted((x for x in positive if x.demand_direction == "better" or
                      (x.stable_share_delta is not None and x.stable_share_delta > 0)), key=lambda x: (
        _caution(x), -x.four_copy_delta, -x.listed_gain, -x.source_coverage, x.give, x.receive,
    ))
    cautions = sorted((x for x in positive if _caution(x)), key=lambda x: (
        x.four_copy_delta < 0, -x.listed_gain, -x.source_coverage, x.give, x.receive,
    ))
    return GrowthPlan(
        wealth_candidates=tuple(wealth[:limit]), four_copy_candidates=tuple(power[:limit]),
        quality_candidates=tuple(quality[:limit]), caution_candidates=tuple(cautions[:limit]),
        observed_targets=len(targets), reviewable_quotes=len(pool),
        own_listed_lower_bound=before.priced_value_lower_bound,
        own_four_copy_ceiling=before.four_copy_ceiling,
        gingerscope_listed_value=goal.value,
        gingerscope_four_copy_gap=max(Decimal(0), goal.value-before.four_copy_ceiling),
        source_valid_until=catalog.valid_until,
        own_unpriced_copies=before.unpriced_units,
        opponent_unpriced_copies=portfolio_metrics(opponent,catalog).unpriced_units,
        no_candidate_reason=None if pool else "no-verified-quote-within-display-gate",
    )
