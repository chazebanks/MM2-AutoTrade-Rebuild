"""Stage 4: deterministic, read-only MM2 trade quote discovery and ranking.

Generates *candidate* 1-4 copy offers for an explicitly verified requested
opponent bundle. It never predicts a person's acceptance, places trades, or
translates Supreme demand into a probability. No guessed stack mechanics.

Each row is human review only. A source demand score is an ordinal descriptor.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal
from typing import Mapping

from evaluator import (
    AssessmentError, Catalog, TradeAssessment, check_counts,
    evaluate, money, portfolio_metrics,
)

GOAL = "ancient:771:checker-id"  # identity only; price comes from the source catalogue


@dataclass(frozen=True)
class RankedOffer:
    give: tuple[tuple[str, int], ...]
    receive: tuple[tuple[str, int], ...]
    give_value: Decimal
    receive_value: Decimal
    gain: Decimal
    coverage: Decimal  # ratio of offered list value to requested list value
    four_copy_delta: Decimal
    goal_four_copy_gap_after: Decimal | None
    opening_item: str
    opening_demand_ordinal: int
    notes: tuple[str, ...]
    # Purely review priority; explicitly not an acceptance likelihood.
    review_label: str = "offline-human-review-only"


@dataclass(frozen=True)
class RankedQuotes:
    offers: tuple[RankedOffer, ...]  # value-competitive review lane
    progression_offers: tuple[RankedOffer, ...]  # four-copy improvement review lane
    accumulation_offers: tuple[RankedOffer, ...]  # listed value gain within displayed coverage gate
    evaluated_combinations: int
    valid_non_overpay_combinations: int
    wide_gap_combinations: int
    best_listed_coverage: Decimal
    min_review_coverage: Decimal
    suggested_receive: tuple[tuple[str, int], ...]
    source: str
    source_valid_until: datetime
    conservative_four_copy_own: Decimal
    target_value: Decimal
    note: str = "No live counterparty consent or market acceptance inferred."


def _sum_value(bundle: Mapping[str, int], cat: Catalog) -> Decimal:
    return sum((cat.items[key].value * qty for key, qty in bundle.items()), Decimal(0))


def _validated_bundle(bundle: Mapping[str, int], holdings: Mapping[str, int], cat: Catalog, *, label: str) -> None:
    check_counts(bundle)
    for key, qty in bundle.items():
        if holdings.get(key, 0) < qty:
            raise AssessmentError(f"{label}-quantity-not-owned")
        item = cat.items.get(key)
        if item is None or not item.verified or not item.tradable or item.stability == "unknown" or item.value <= 0:
            raise AssessmentError(f"{label}-item-unverified")


def _leader(bundle: Mapping[str, int], cat: Catalog) -> tuple[str, int]:
    # Opening *descriptor*, not an actual first placement recommendation.
    key = min(bundle, key=lambda k: (-cat.items[k].value * bundle[k], -cat.items[k].demand, k))
    return key, cat.items[key].demand


def _reasons(bundle: Mapping[str, int], assessment: TradeAssessment, cat: Catalog, gap: Decimal) -> tuple[str, ...]:
    signals = list(assessment.warnings)
    if all(cat.items[key].demand <= 1 for key in bundle):
        signals.append("all-offered-items-have-low-source-demand")
    if any(cat.items[key].stability in ("fluctuating", "underpaid") for key in bundle):
        signals.append("outgoing-includes-unstable-or-underpaid-source-status")
    if gap > 0:
        signals.append("counterparty-would-be-giving-more-listed-value")
    return tuple(dict.fromkeys(signals))


def rank_offers(
    own: Mapping[str, int],
    opponent: Mapping[str, int],
    receive: Mapping[str, int],
    catalog: Catalog,
    now: datetime,
    *,
    goal_id: str = GOAL,
    max_copies: int = 4,
    max_combinations: int = 50_000,
    limit: int = 10,
    allow_overpay: bool = False,
    min_review_coverage: Decimal = Decimal("0.90"),
) -> RankedQuotes:
    """Find the most nearly value-matched 1..4 *copy* offers for a known target.

    Ranking presents TWO explanation-friendly review orders, NOT an Accept policy.
    Only quotes meeting an adjustable *review* coverage heuristic appear; the
    default 90% is NOT a measured acceptance threshold or mandatory profit.
    For the same requested bundle, higher coverage is a stronger listed-value
    quote to the opponent, but lower net benefit for us. The report includes
    retention, quality and four-slot effects for human judgement. Optional
    overpay is explicitly opt-in and comes with a loss warning.

    Limited, deterministic exhaustive search; fail closed on search-budget
    exhaustion instead of quietly omitting potentially better alternatives.
    """
    catalog.validate(now)
    check_counts(own)
    check_counts(opponent)
    _validated_bundle(receive, opponent, catalog, label="receive")
    if not isinstance(max_copies, int) or isinstance(max_copies, bool) or max_copies < 1 or max_copies > 4:
        raise AssessmentError("unsupported-conservative-copy-cap")
    if sum(receive.values()) > max_copies:
        raise AssessmentError("receive-exceeds-conservative-four-copy-limit")
    if len(receive) > max_copies:
        raise AssessmentError("receive-exceeds-slot-limit")
    if not isinstance(max_combinations, int) or isinstance(max_combinations, bool) or max_combinations < 1:
        raise AssessmentError("invalid-search-budget")
    if not isinstance(limit, int) or isinstance(limit, bool) or limit < 1 or limit > 100:
        raise AssessmentError("invalid-result-limit")
    if not isinstance(allow_overpay, bool):
        raise AssessmentError("invalid-loss-policy")
    min_review_coverage = money(min_review_coverage)
    if min_review_coverage > 1:
        raise AssessmentError("invalid-quote-coverage-gate")
    goal = catalog.items.get(goal_id)
    if goal is None or not goal.verified or not goal.tradable or goal.value <= 0:
        raise AssessmentError("unverified-goal-price")

    recv_value = _sum_value(receive, catalog)
    if recv_value <= 0:
        raise AssessmentError("unpriced-target")
    own_copy_ceiling = portfolio_metrics(own, catalog).four_copy_ceiling
    rows = []
    for key in sorted(own):
        item = catalog.items.get(key)
        if key in receive or item is None or not item.verified or not item.tradable or item.value <= 0 or item.stability == "unknown":
            continue
        rows.append((key, min(own[key], max_copies), item.value))
    offers: list[RankedOffer] = []
    evaluated = 0
    valid = 0
    wide_gap = 0
    best_coverage = Decimal(0)
    picks: dict[str, int] = {}

    def visit(index: int, copies: int, value: Decimal) -> None:
        nonlocal evaluated, valid, wide_gap, best_coverage
        if copies:
            evaluated += 1
            if evaluated > max_combinations:
                raise AssessmentError("quote-search-budget-exceeded")
            if allow_overpay or value <= recv_value:
                coverage = value / recv_value
                if coverage > best_coverage:
                    best_coverage = coverage
                if coverage < min_review_coverage:
                    wide_gap += 1
                else:
                    assessment = evaluate(own, opponent, picks, receive, catalog, now,
                                          max_slots=max_copies, goal_identity=goal_id)
                    valid += 1
                    lead, demand = _leader(picks, catalog)
                    gap = recv_value - value
                    offers.append(RankedOffer(
                        give=tuple(sorted(picks.items())), receive=tuple(sorted(receive.items())),
                        give_value=value, receive_value=recv_value,
                        gain=gap, coverage=value / recv_value,
                        four_copy_delta=assessment.four_copy_delta,
                        goal_four_copy_gap_after=assessment.goal_four_copy_gap_after,
                        opening_item=lead, opening_demand_ordinal=demand,
                        notes=_reasons(picks, assessment, catalog, gap),
                    ))
        if copies == max_copies:
            return
        for j in range(index, len(rows)):
            key, available, unit = rows[j]
            for qty in range(1, min(available, max_copies - copies) + 1):
                total = value + unit * qty
                if not allow_overpay and total > recv_value:
                    break
                picks[key] = qty
                visit(j + 1, copies + qty, total)
            picks.pop(key, None)

    visit(0, 0, Decimal(0))
    # No scalar demand/stability "acceptance score". Quote competitiveness is
    # value coverage; qualitative warning count and preservation of four-copy
    # power break close ties, not an invented chance to close a trade.
    accumulation = sorted(offers, key=lambda x: (
        x.gain < 0, -x.gain if x.gain >= 0 else x.gain,
        x.four_copy_delta < 0, len(x.notes), -x.coverage,
        -x.opening_demand_ordinal, x.give,
    ))
    progression = sorted(offers, key=lambda x: (
        -x.four_copy_delta, len(x.notes), x.gain < 0,
        -x.coverage if x.gain >= 0 else x.coverage,
        -x.opening_demand_ordinal, x.give,
    ))
    offers.sort(key=lambda x: (
        x.gain < 0, -x.coverage if x.gain >= 0 else x.coverage, len(x.notes), -x.four_copy_delta,
        -x.opening_demand_ordinal, len(x.give), x.give,
    ))
    return RankedQuotes(
        offers=tuple(offers[:limit]), progression_offers=tuple(progression[:limit]),
        accumulation_offers=tuple(accumulation[:limit]),
        evaluated_combinations=evaluated,
        valid_non_overpay_combinations=valid,
        wide_gap_combinations=wide_gap, best_listed_coverage=best_coverage,
        min_review_coverage=min_review_coverage,
        suggested_receive=tuple(sorted(receive.items())),
        source=catalog.source, source_valid_until=catalog.valid_until,
        conservative_four_copy_own=own_copy_ceiling,
        target_value=goal.value,
    )
