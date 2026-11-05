"""Stage 7: bounded counter-offer / buyer-seller tradeoff research, NOT automation.

The seller's base listed value, source ordinal demand and price stability are
independent evidence. They are NOT a probability that a human will accept.
No remotes, network, polling, auto-accept, trade execution, or bot interactions.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal
from typing import Mapping

from evaluator import (
    AssessmentError, Catalog, check_counts, demand_comparison,
    evaluate, money, portfolio_metrics,
)
from offer_ranker import GOAL

MAX_COPIES = 4  # conservative: one physical copy occupies one trade slot


@dataclass(frozen=True)
class SellerQuote:
    give: tuple[tuple[str, int], ...]
    receive: tuple[tuple[str, int], ...]
    give_value: Decimal
    receive_value: Decimal
    # Positive = listed-value concession in favor of the counterparty.
    seller_surplus: Decimal
    our_listed_gain: Decimal
    coverage: Decimal
    our_four_copy_delta: Decimal
    our_goal_gap_after: Decimal | None
    offered_copy_count: int
    seller_demand_relation: str  # our offer's ordinal demand distribution vs wanted goods
    seller_stable_share_delta: Decimal | None
    source_flags: tuple[str, ...]
    decision: str = "offline-human-review-only"


@dataclass(frozen=True)
class NegotiationResearch:
    value_matched: tuple[SellerQuote, ...]
    bounded_concessions: tuple[SellerQuote, ...]
    four_copy_growth: tuple[SellerQuote, ...]
    accumulating: tuple[SellerQuote, ...]
    candidate_count: int
    combinations_seen: int
    rejected_value_gate: int
    rejected_overpay_policy: int
    target_listed_value: Decimal
    max_study_concession: Decimal
    source_valid_until: datetime
    no_candidate_reason: str | None
    native_ready: bool = False
    note: str = (
        "Research-only; no evidence the counterparty would accept, "
        "and cached opponent scan age is unverified."
    )


def _verify_side(bundle: Mapping[str, int], owned: Mapping[str, int], cat: Catalog, name: str) -> None:
    check_counts(bundle)
    if sum(bundle.values()) > MAX_COPIES or len(bundle) > MAX_COPIES:
        raise AssessmentError(f"{name}-physical-copies-exceed-four")
    for key, qty in bundle.items():
        item = cat.items.get(key)
        if owned.get(key, 0) < qty:
            raise AssessmentError(f"{name}-quantity-unproven")
        if item is None or not item.verified or not item.tradable or item.value <= 0 or item.stability == "unknown":
            raise AssessmentError(f"{name}-identity-unverified")


def _value(bundle: Mapping[str, int], cat: Catalog) -> Decimal:
    return sum((cat.items[k].value * q for k, q in bundle.items()), Decimal(0))


def _seller_quality(give: Mapping[str, int], recv: Mapping[str, int], cat: Catalog) -> tuple[str, Decimal | None]:
    # We are giving 'give', seller is giving 'recv'. Compare the seller's new
    # acquired bundle to what the seller surrenders (not their unobserved whole portfolio).
    acquired = portfolio_metrics(give, cat)
    surrendered = portfolio_metrics(recv, cat)
    stable_delta = None
    if acquired.stable_share is not None and surrendered.stable_share is not None:
        stable_delta = acquired.stable_share - surrendered.stable_share
    return demand_comparison(surrendered, acquired), stable_delta


def _flag(quote: SellerQuote) -> bool:
    return "seller-offer-has-weaker-source-demand-distribution" in quote.source_flags or (
        "seller-offer-has-less-stable-value-share" in quote.source_flags
    )


def study_counteroffers(
    own: Mapping[str, int], opponent: Mapping[str, int], receive: Mapping[str, int],
    catalog: Catalog, now: datetime, *, goal_id: str = GOAL,
    min_coverage: Decimal = Decimal("0.90"),
    max_concession_ratio: Decimal = Decimal("0.05"),
    max_concession_abs: Decimal = Decimal("20"),
    search_budget: int = 50000, limit: int = 10,
) -> NegotiationResearch:
    """Exhaustive 1-4 copy review. Fail closed on budget; never suppress search errors.

    A *nominal loss* is studied only for a verified, stable, at-least-demand-2
    target, a positive four-copy gain, and a bounded concession. This is a
    conservative research filter, NOT an automated permission to overpay.

    We don't apply a fabricated score to source demand and stability, or infer
    counterparty preferences from cache. No capture timestamp => no live use.
    """
    catalog.validate(now)
    check_counts(own)
    check_counts(opponent)
    _verify_side(receive, opponent, catalog, "receive")
    if not isinstance(search_budget, int) or isinstance(search_budget, bool) or search_budget < 1:
        raise AssessmentError("invalid-search-budget")
    if type(limit) is not int or not 1 <= limit <= 100:
        raise AssessmentError("invalid-review-limit")
    gate = money(min_coverage)
    ratio = money(max_concession_ratio)
    abs_cap = money(max_concession_abs)
    if gate > 1 or ratio > 1:
        raise AssessmentError("invalid-concession-or-coverage-fraction")
    goal = catalog.items.get(goal_id)
    if goal is None or not goal.verified or not goal.tradable or goal.value <= 0:
        raise AssessmentError("unverified-goal-price")
    target_value = _value(receive, catalog)
    loss_cap = min(abs_cap, target_value * ratio)
    # A requested bundle with any low source-demand or volatile item cannot
    # justify an overpay with this conservative model.
    upgrade_loss_eligible = all(
        catalog.items[key].demand >= 2
        and catalog.items[key].stability in ("stable", "doing_well", "overpaid")
        for key in receive
    )

    offerable = sorted(
        (k, min(q, MAX_COPIES), catalog.items[k].value)
        for k, q in own.items()
        if k not in receive and k in catalog.items and catalog.items[k].verified
        and catalog.items[k].tradable and catalog.items[k].value > 0
        and catalog.items[k].stability != "unknown"
    )
    choices: dict[str, int] = {}
    quotes: list[SellerQuote] = []
    visited = 0
    rejected_gate = 0
    rejected_loss = 0

    def visit(start: int, count: int, total: Decimal) -> None:
        nonlocal visited, rejected_gate, rejected_loss
        if count:
            visited += 1
            if visited > search_budget:
                raise AssessmentError("negotiation-search-budget-exceeded")
            if total < target_value * gate:
                rejected_gate += 1
            elif total > target_value + loss_cap:
                rejected_loss += 1
            else:
                is_loss = total > target_value
                if is_loss and not upgrade_loss_eligible:
                    rejected_loss += 1
                else:
                    trade = evaluate(own, opponent, choices, receive, catalog, now, goal_identity=goal_id)
                    if is_loss and trade.four_copy_delta <= 0:
                        rejected_loss += 1
                    else:
                        seller_demand, seller_stability = _seller_quality(choices, receive, catalog)
                        flags: list[str] = ["counterparty-preferences-unknown", "opponent-cache-scan-age-unknown"]
                        if is_loss:
                            flags.append("bounded-nominal-overpay-experimental")
                        elif total < target_value:
                            flags.append("seller-receives-less-listed-value")
                        if seller_demand in ("mixed", "worse"):
                            flags.append("seller-offer-has-weaker-source-demand-distribution")
                        if seller_stability is not None and seller_stability < 0:
                            flags.append("seller-offer-has-less-stable-value-share")
                        if count > 1:
                            flags.append("seller-must-accept-multiple-copies")
                        if any(catalog.items[k].stability in ("fluctuating", "underpaid") for k in choices):
                            flags.append("offer-includes-fluctuating-or-underpaid-items")
                        if any(catalog.items[k].demand <= 1 for k in choices):
                            flags.append("offer-includes-low-source-demand-item")
                        if trade.four_copy_delta < 0:
                            flags.append("four-copy-progression-regresses")
                        if trade.demand_profile in ("mixed", "worse"):
                            flags.append("our-portfolio-demand-not-unambiguously-better")
                        if trade.stable_share_delta is not None and trade.stable_share_delta < 0:
                            flags.append("our-stable-share-declines")
                        quotes.append(SellerQuote(
                            give=tuple(sorted(choices.items())), receive=tuple(sorted(receive.items())),
                            give_value=total, receive_value=target_value,
                            seller_surplus=total - target_value,
                            our_listed_gain=trade.net_listed_value,
                            coverage=total / target_value,
                            our_four_copy_delta=trade.four_copy_delta,
                            our_goal_gap_after=trade.goal_four_copy_gap_after,
                            offered_copy_count=count,
                            seller_demand_relation=seller_demand,
                            seller_stable_share_delta=seller_stability,
                            source_flags=tuple(flags),
                        ))
        if count == MAX_COPIES:
            return
        for i in range(start, len(offerable)):
            key, available, value = offerable[i]
            for q in range(1, min(available, MAX_COPIES - count) + 1):
                new_total = total + value * q
                # Values are strictly positive. Adding more can never repair an over-cap loss.
                if new_total > target_value + loss_cap:
                    break
                choices[key] = q
                visit(i + 1, count + q, new_total)
            choices.pop(key, None)

    visit(0, 0, Decimal(0))
    # Independent review lanes, NOT an acceptance score or a single "best" trade.
    close = sorted(quotes, key=lambda x: (
        abs(x.seller_surplus), _flag(x), x.offered_copy_count,
        -x.our_four_copy_delta, x.give,
    ))
    concessions = sorted((x for x in quotes if x.seller_surplus > 0), key=lambda x: (
        _flag(x), x.seller_surplus, x.offered_copy_count,
        -x.our_four_copy_delta, x.give,
    ))
    growth = sorted((x for x in quotes if x.our_four_copy_delta > 0), key=lambda x: (
        -x.our_four_copy_delta, x.our_listed_gain < 0, _flag(x),
        -x.our_listed_gain, x.offered_copy_count, x.give,
    ))
    accumulation = sorted((x for x in quotes if x.our_listed_gain > 0), key=lambda x: (
        -x.our_listed_gain, x.our_four_copy_delta < 0, _flag(x),
        x.offered_copy_count, x.give,
    ))
    return NegotiationResearch(
        value_matched=tuple(close[:limit]), bounded_concessions=tuple(concessions[:limit]),
        four_copy_growth=tuple(growth[:limit]), accumulating=tuple(accumulation[:limit]),
        candidate_count=len(quotes), combinations_seen=visited,
        rejected_value_gate=rejected_gate, rejected_overpay_policy=rejected_loss,
        target_listed_value=target_value, max_study_concession=loss_cap,
        source_valid_until=catalog.valid_until,
        no_candidate_reason=None if quotes else "no-within-verified-value-and-risk-bounds",
    )