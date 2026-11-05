"""Gingerscope trading intelligence laboratory — offline, side-effect-free.

No Roblox services, HTTP requests, trade execution, automated acceptance, or
assumed acceptance probabilities.  The active Delta/Luau code is unaffected.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from typing import Mapping


class AssessmentError(ValueError):
    """A quote cannot be assessed using verified evidence."""


VALID_STABILITY = frozenset({"stable", "fluctuating", "underpaid", "doing_well", "overpaid", "unknown"})


def money(value: object) -> Decimal:
    """Require exact, nonnegative, cent-precision value units."""
    if isinstance(value, bool):
        raise AssessmentError("boolean-is-not-value")
    try:
        d = Decimal(str(value))
    except (InvalidOperation, ValueError):
        raise AssessmentError("invalid-value") from None
    if not d.is_finite() or d < 0 or d.as_tuple().exponent < -2:
        raise AssessmentError("invalid-value-or-precision")
    return d


@dataclass(frozen=True)
class Item:
    # Full variant key, not display name. Example: 'chroma:watergun:2020'.
    identity: str
    value: Decimal
    demand: int  # source ordinal descriptor, NOT acceptance probability
    stability: str
    tradable: bool = True
    verified: bool = True

    def __post_init__(self) -> None:
        if not isinstance(self.identity, str) or self.identity.count(":") < 2:
            raise AssessmentError("item-identity-missing-variant")
        object.__setattr__(self, "value", money(self.value))
        if isinstance(self.demand, bool) or not isinstance(self.demand, int) or not 0 <= self.demand <= 11:
            raise AssessmentError("invalid-demand-ordinal")
        if self.stability not in VALID_STABILITY:
            raise AssessmentError("invalid-stability")
        if not isinstance(self.verified, bool) or not isinstance(self.tradable, bool):
            raise AssessmentError("invalid-item-evidence")


@dataclass(frozen=True)
class Catalog:
    items: Mapping[str, Item]
    observed_at: datetime
    valid_until: datetime
    source: str

    def validate(self, now: datetime) -> None:
        for stamp in (now, self.observed_at, self.valid_until):
            if stamp.tzinfo is None or stamp.utcoffset() is None:
                raise AssessmentError("timezone-aware-datetime-required")
        if not self.source or not self.items:
            raise AssessmentError("missing-market-source")
        if now < self.observed_at or now > self.valid_until or self.valid_until <= self.observed_at:
            raise AssessmentError("price-snapshot-not-valid")
        for identity, item in self.items.items():
            if identity != item.identity:
                raise AssessmentError("identity-metadata-mismatch")


@dataclass(frozen=True)
class Metrics:
    priced_value_lower_bound: Decimal
    unpriced_units: int
    nontradable_units: int
    stable_share: Decimal | None
    four_copy_ceiling: Decimal
    four_type_stack_ceiling: Decimal
    # Price-weighted *ordinal distribution*, never an acceptance probability.
    demand_at_least_share: tuple[Decimal, ...]


@dataclass(frozen=True)
class TradeAssessment:
    net_listed_value: Decimal
    four_copy_delta: Decimal
    four_type_stack_delta: Decimal
    stable_share_delta: Decimal | None
    demand_profile: str
    before: Metrics
    after: Metrics
    warnings: tuple[str, ...]
    diagnostics: tuple[str, ...]
    goal_identity: str | None
    goal_value: Decimal | None
    goal_four_copy_gap_before: Decimal | None
    goal_four_copy_gap_after: Decimal | None
    goal_four_stack_gap_before: Decimal | None
    goal_four_stack_gap_after: Decimal | None
    # Deliberately NOT an automated accept/decline instruction.
    decision: str = "human-review-only"


def check_counts(counts: Mapping[str, int], *, allow_empty: bool = False) -> None:
    if not isinstance(counts, Mapping) or (not counts and not allow_empty):
        raise AssessmentError("invalid-or-empty-bundle")
    for key, qty in counts.items():
        if not isinstance(key, str) or not key:
            raise AssessmentError("invalid-asset-identity")
        if isinstance(qty, bool) or not isinstance(qty, int) or qty <= 0:
            raise AssessmentError("invalid-asset-quantity")


def portfolio_metrics(holdings: Mapping[str, int], catalog: Catalog) -> Metrics:
    check_counts(holdings, allow_empty=True)
    total = Decimal(0)
    stable_value = Decimal(0)
    demand_values = [Decimal(0) for _ in range(12)]
    four_copy_values: list[Decimal] = []
    four_type_values: list[Decimal] = []
    unknown = 0
    nontradable = 0
    for key, qty in holdings.items():
        item = catalog.items.get(key)
        if item is None or not item.verified or item.stability == "unknown":
            unknown += qty
            continue
        if not item.tradable:
            nontradable += qty
            continue
        amount = item.value * qty
        total += amount
        if item.stability == "stable":
            stable_value += amount
        for minimum in range(item.demand + 1):
            demand_values[minimum] += amount
        # At most 4 copies can contribute to the conservative copy ceiling.
        four_copy_values.extend([item.value] * min(qty, 4))
        # A separate theoretical upper bound IF stacks use one native slot.
        four_type_values.append(amount)
    four_copy_values.sort(reverse=True)
    four_type_values.sort(reverse=True)
    return Metrics(
        priced_value_lower_bound=total,
        unpriced_units=unknown,
        nontradable_units=nontradable,
        stable_share=(stable_value / total if total else None),
        four_copy_ceiling=sum(four_copy_values[:4], Decimal(0)),
        four_type_stack_ceiling=sum(four_type_values[:4], Decimal(0)),
        demand_at_least_share=tuple(v / total for v in demand_values) if total else tuple(Decimal(0) for _ in range(12)),
    )


def demand_comparison(a: Metrics, b: Metrics) -> str:
    """First-order dominance in ordinal-demand holdings, not a cardinal score."""
    if a.priced_value_lower_bound == 0 or b.priced_value_lower_bound == 0:
        return "unknown"
    # index 0 is always 1; compare meaningful demand thresholds 1..10.
    improved = [y > x for x, y in zip(a.demand_at_least_share[1:], b.demand_at_least_share[1:])]
    worsened = [y < x for x, y in zip(a.demand_at_least_share[1:], b.demand_at_least_share[1:])]
    if any(improved) and any(worsened):
        return "mixed"
    if any(improved):
        return "better"
    if any(worsened):
        return "worse"
    return "unchanged"


def evaluate(
    our_holdings: Mapping[str, int],
    opponent_holdings: Mapping[str, int],
    give: Mapping[str, int],
    receive: Mapping[str, int],
    catalog: Catalog,
    now: datetime,
    *,
    max_slots: int = 4,
    goal_identity: str | None = None,
) -> TradeAssessment:
    """Evaluate one hypothetical offer; never mutate input inventory or recommend execution."""
    catalog.validate(now)
    for holdings in (our_holdings, opponent_holdings, give, receive):
        check_counts(holdings)
    if not isinstance(max_slots, int) or isinstance(max_slots, bool) or max_slots <= 0:
        raise AssessmentError("invalid-slot-cap")
    if len(give) > max_slots or len(receive) > max_slots:
        raise AssessmentError("too-many-distinct-slots")
    if set(give).intersection(receive):
        raise AssessmentError("same-item-on-both-sides")
    for key, count in give.items():
        if our_holdings.get(key, 0) < count:
            raise AssessmentError("not-owned-give-quantity")
    for key, count in receive.items():
        if opponent_holdings.get(key, 0) < count:
            raise AssessmentError("not-owned-receive-quantity")
    for key in set(give).union(receive):
        item = catalog.items.get(key)
        if item is None:
            raise AssessmentError("unknown-traded-item")
        if not item.verified or not item.tradable or item.stability == "unknown":
            raise AssessmentError("unverified-or-nontradable-item")
        if item.value == 0:
            raise AssessmentError("unvalued-traded-item")
    goal_value: Decimal | None = None
    if goal_identity is not None:
        goal_item = catalog.items.get(goal_identity)
        if goal_item is None or not goal_item.verified or not goal_item.tradable or goal_item.value <= 0:
            raise AssessmentError("unverified-goal-price")
        goal_value = goal_item.value
    before = portfolio_metrics(our_holdings, catalog)
    after_counts = dict(our_holdings)
    for key, qty in give.items():
        updated = after_counts[key] - qty
        if updated:
            after_counts[key] = updated
        else:
            del after_counts[key]
    for key, qty in receive.items():
        after_counts[key] = after_counts.get(key, 0) + qty
    after = portfolio_metrics(after_counts, catalog)
    delta = after.priced_value_lower_bound - before.priced_value_lower_bound
    s_delta = None if before.stable_share is None or after.stable_share is None else after.stable_share - before.stable_share
    demand = demand_comparison(before, after)
    warnings: list[str] = []
    if delta < 0:
        warnings.append("nominal-list-value-decreases")
    if after.four_copy_ceiling < before.four_copy_ceiling:
        warnings.append("four-copy-purchasing-power-decreases")
    if after.four_type_stack_ceiling < before.four_type_stack_ceiling:
        warnings.append("theoretical-four-stack-power-decreases")
    if s_delta is not None and s_delta < 0:
        warnings.append("stable-value-share-decreases")
    if demand in ("worse", "mixed"):
        warnings.append("demand-profile-not-unambiguously-better")
    if before.unpriced_units or after.unpriced_units:
        warnings.append("portfolio-totals-are-lower-bounds")
    if before.nontradable_units or after.nontradable_units:
        warnings.append("nontradable-items-excluded-from-purchasing-power")
    diagnostics = [
        "market-demand-is-ordinal-not-an-acceptance-probability",
        "four-type-stack-ceiling-requires-native-quantity-slot-verification",
        "listed-value-does-not-prove-a-fillable-gingerscope-offer",
    ]
    return TradeAssessment(
        net_listed_value=delta,
        four_copy_delta=after.four_copy_ceiling - before.four_copy_ceiling,
        four_type_stack_delta=after.four_type_stack_ceiling - before.four_type_stack_ceiling,
        stable_share_delta=s_delta,
        demand_profile=demand,
        before=before,
        after=after,
        warnings=tuple(warnings),
        diagnostics=tuple(diagnostics),
        goal_identity=goal_identity,
        goal_value=goal_value,
        goal_four_copy_gap_before=(max(Decimal(0), goal_value - before.four_copy_ceiling) if goal_value is not None else None),
        goal_four_copy_gap_after=(max(Decimal(0), goal_value - after.four_copy_ceiling) if goal_value is not None else None),
        goal_four_stack_gap_before=(max(Decimal(0), goal_value - before.four_type_stack_ceiling) if goal_value is not None else None),
        goal_four_stack_gap_after=(max(Decimal(0), goal_value - after.four_type_stack_ceiling) if goal_value is not None else None),
    )


def compare(a: TradeAssessment, b: TradeAssessment) -> str:
    """Pareto compare two alternatives with the same baseline; else avoid a verdict.

    Only comparable facts: listed value, conservative four-copy purchasing power,
    stable share, and first-order demand-profile dominance. Theoretical stacks
    are excluded because native one-stack-per-slot behavior has not been proven.
    """
    if a.before != b.before or a.stable_share_delta is None or b.stable_share_delta is None:
        return "incomparable"
    if a.before.unpriced_units or b.before.unpriced_units or a.before.nontradable_units or b.before.nontradable_units:
        return "incomparable"
    if a.demand_profile == "mixed" or b.demand_profile == "mixed":
        return "incomparable"
    # Compare absolute after-portfolio demand profiles, NOT relative labels.
    ab = demand_comparison(b.after, a.after)
    if ab in ("mixed", "unknown"):
        return "incomparable"
    av = (a.net_listed_value, a.four_copy_delta, a.stable_share_delta)
    bv = (b.net_listed_value, b.four_copy_delta, b.stable_share_delta)
    age = all(x >= y for x, y in zip(av, bv)) and ab in ("better", "unchanged")
    bge = all(y >= x for x, y in zip(av, bv)) and ab in ("worse", "unchanged")
    if age and bge:
        return "equal"
    if age:
        return "a-dominates-b"
    if bge:
        return "b-dominates-a"
    return "incomparable"

