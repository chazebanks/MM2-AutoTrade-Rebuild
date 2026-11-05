"""Stage 19: Python-only Gingerscope portfolio and completed-trade accounting.

Reuses Stage 1 portfolio_metrics; does not replace any strategy, scanner,
native trade controller, or Stage 18 adapter.

The ledger validates *caller-supplied* evidence structure. Marking records
'native' and supplying a proof reference NEVER independently proves a real
server-side completed transaction. No live trading permission is produced.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal
from typing import Mapping, Sequence

from evaluator import AssessmentError, Catalog, portfolio_metrics

GOAL = "ancient:771:checker-id"


@dataclass(frozen=True)
class AccountSnapshot:
    label: str  # local pseudonym, NOT a Roblox user ID
    items: Mapping[str, int]
    captured_at: datetime
    evidence: str = "provisional"  # provisional|native_claimed
    complete_eligible: bool = False


@dataclass(frozen=True)
class AccountReadiness:
    label: str
    priced_value_lower_bound: Decimal
    four_copy_ceiling: Decimal
    theoretical_four_type_stack_ceiling: Decimal
    four_copy_gap: Decimal
    goal_owned: bool
    unknown_copies: int
    evidence: str
    evidence_fresh: bool
    complete_eligible: bool


@dataclass(frozen=True)
class PortfolioReadiness:
    accounts: tuple[AccountReadiness, ...]
    combined_listed_lower_bound: Decimal
    best_current_account_four_copy: Decimal
    best_current_account_gap: Decimal
    theoretical_consolidated_four_copy: Decimal
    theoretical_consolidation_uplift: Decimal
    goal_value: Decimal
    goal_owned: bool
    completeness_proven: bool
    evidence_fresh: bool
    source: str
    review_only: bool = True
    authorizes_trade: bool = False
    authorizes_accept: bool = False


@dataclass(frozen=True)
class CompletedEvent:
    event_ref: str  # anonymized external completion-proof reference supplied by caller
    kind: str  # external_trade | owned_transfer
    # Account -> canonical item ID -> SIGNED quantity change (receive +, give -).
    changes: Mapping[str, Mapping[str, int]]
    completion_claimed: bool = True


@dataclass(frozen=True)
class ValueAttribution:
    before_value: Decimal
    after_value: Decimal
    completed_external_trades_at_old_prices: Decimal
    market_repricing_on_after_holdings: Decimal
    portfolio_change: Decimal
    internal_transfer_value: Decimal
    included_events: int
    evidence_status: str
    review_only: bool = True
    authorizes_trade: bool = False
    authorizes_accept: bool = False


def _stamp(value: datetime, name: str) -> None:
    if not isinstance(value, datetime) or value.tzinfo is None or value.utcoffset() is None:
        raise AssessmentError(name + "-timezone-required")


def _copies(snapshot: AccountSnapshot) -> dict[str, int]:
    if not isinstance(snapshot, AccountSnapshot) or not isinstance(snapshot.label, str) or not snapshot.label.strip() or len(snapshot.label) > 40:
        raise AssessmentError("account-label-invalid")
    if snapshot.evidence not in ("provisional", "native_claimed") or type(snapshot.complete_eligible) is not bool:
        raise AssessmentError("account-evidence-invalid")
    _stamp(snapshot.captured_at, "account-capture")
    if not isinstance(snapshot.items, Mapping):
        raise AssessmentError("account-items-invalid")
    out: dict[str, int] = {}
    for key, count in snapshot.items.items():
        if not isinstance(key, str) or key.count(":") < 2:
            raise AssessmentError("account-item-identity-invalid")
        if type(count) is not int or not 1 <= count <= 1_000_000:
            raise AssessmentError("account-item-count-invalid")
        out[key] = count
    return out


def _accounts(snapshots: Sequence[AccountSnapshot]) -> dict[str, AccountSnapshot]:
    if not isinstance(snapshots, (tuple, list)) or not 1 <= len(snapshots) <= 16:
        raise AssessmentError("account-snapshot-list-invalid")
    out: dict[str, AccountSnapshot] = {}
    for snap in snapshots:
        _copies(snap)
        if snap.label in out:
            raise AssessmentError("duplicate-account-label")
        out[snap.label] = snap
    return out


def _priced(catalog: Catalog, key: str) -> Decimal:
    item = catalog.items.get(key)
    if item is None or not item.verified or not item.tradable or item.value <= 0:
        raise AssessmentError("accounting-price-or-identity-unverified")
    return item.value


def portfolio_readiness(
    snapshots: Sequence[AccountSnapshot], catalog: Catalog, now: datetime,
    *, goal_id: str = GOAL, max_age_seconds: int = 120,
) -> PortfolioReadiness:
    """Calculate ACTUAL per-account copy limits and a separate consolidation bound.

    An asset on the alt account cannot be combined with the main account in
    one MM2 trade unless a separately verified in-game transfer occurs.
    """
    _stamp(now, "portfolio-now")
    catalog.validate(now)
    if type(max_age_seconds) is not int or max_age_seconds < 0:
        raise AssessmentError("portfolio-freshness-config-invalid")
    goal_value = _priced(catalog, goal_id)
    accounts = _accounts(snapshots)
    total = Decimal(0)
    combined: dict[str, int] = {}
    best = Decimal(0)
    rows: list[AccountReadiness] = []
    all_complete = True
    all_fresh = True
    has_goal = False
    for label in sorted(accounts):
        snap = accounts[label]
        quantities = _copies(snap)
        age = (now - snap.captured_at).total_seconds()
        if age < 0:
            raise AssessmentError("future-account-capture")
        fresh = age <= max_age_seconds
        metrics = portfolio_metrics(quantities, catalog)
        owns = quantities.get(goal_id, 0) > 0
        row = AccountReadiness(
            label=label,
            priced_value_lower_bound=metrics.priced_value_lower_bound,
            four_copy_ceiling=metrics.four_copy_ceiling,
            theoretical_four_type_stack_ceiling=metrics.four_type_stack_ceiling,
            four_copy_gap=max(Decimal(0), goal_value - metrics.four_copy_ceiling),
            goal_owned=owns, unknown_copies=metrics.unpriced_units,
            evidence=snap.evidence, evidence_fresh=fresh,
            complete_eligible=snap.complete_eligible)
        rows.append(row)
        has_goal = has_goal or owns
        total += metrics.priced_value_lower_bound
        best = max(best, metrics.four_copy_ceiling)
        all_complete = all_complete and (snap.evidence == "native_claimed"
                                          and snap.complete_eligible
                                          and metrics.unpriced_units == 0
                                          and metrics.nontradable_units == 0)
        all_fresh = all_fresh and fresh
        for key, qty in quantities.items():
            combined[key] = combined.get(key, 0) + qty
    hypothetical = portfolio_metrics(combined, catalog).four_copy_ceiling
    return PortfolioReadiness(
        accounts=tuple(rows), combined_listed_lower_bound=total,
        best_current_account_four_copy=best,
        best_current_account_gap=max(Decimal(0), goal_value - best),
        theoretical_consolidated_four_copy=hypothetical,
        theoretical_consolidation_uplift=hypothetical-best,
        goal_value=goal_value, goal_owned=has_goal,
        completeness_proven=all_complete, evidence_fresh=all_fresh,
        source=catalog.source)


def _position_value(snapshots: Mapping[str, AccountSnapshot], catalog: Catalog) -> Decimal:
    total = Decimal(0)
    for snap in snapshots.values():
        for key, qty in _copies(snap).items():
            total += _priced(catalog, key) * qty
    return total


def reconcile_value_change(
    before: Sequence[AccountSnapshot], after: Sequence[AccountSnapshot],
    old_catalog: Catalog, new_catalog: Catalog,
    before_at: datetime, after_at: datetime,
    events: Sequence[CompletedEvent] = (),
) -> ValueAttribution:
    """Split observed value change into confirmed-event vs repricing buckets.

    Trade first, reprice after: (after holdings valued at old prices - before
    holdings valued at old prices) + (after holdings at new vs old prices).

    Requires exact event-ledger reconciliation. Without trustworthy complete
    event evidence, do NOT claim that an inventory delta was trading profit.
    Native-claimed data is caller-provided and still not proof by itself.
    """
    _stamp(before_at, "ledger-before")
    _stamp(after_at, "ledger-after")
    if after_at < before_at:
        raise AssessmentError("ledger-time-reversed")
    old_catalog.validate(before_at)
    new_catalog.validate(after_at)
    b = _accounts(before)
    a = _accounts(after)
    if set(a) != set(b):
        raise AssessmentError("account-set-changed-without-evidence")
    for label in a:
        if a[label].captured_at != after_at or b[label].captured_at != before_at:
            raise AssessmentError("ledger-account-snapshot-time-mismatch")
    if not isinstance(events, (tuple, list)) or len(events) > 100:
        raise AssessmentError("ledger-event-budget-invalid")

    original: dict[str, dict[str, int]] = {label: _copies(snap) for label, snap in b.items()}
    observed: dict[str, dict[str, int]] = {label: _copies(snap) for label, snap in a.items()}
    expected: dict[str, dict[str, int]] = {label: {} for label in b}
    seen_refs: set[str] = set()
    external = Decimal(0)
    transfer = Decimal(0)
    for event in events:
        if not isinstance(event, CompletedEvent) or not isinstance(event.event_ref, str) or not event.event_ref.strip() or event.event_ref in seen_refs:
            raise AssessmentError("ledger-duplicate-or-invalid-event-proof")
        seen_refs.add(event.event_ref)
        if type(event.completion_claimed) is not bool or not event.completion_claimed:
            raise AssessmentError("ledger-event-completion-unproven")
        if event.kind not in ("external_trade", "owned_transfer") or not isinstance(event.changes, Mapping):
            raise AssessmentError("ledger-event-type-invalid")
        if event.kind == "external_trade" and len(event.changes) != 1:
            raise AssessmentError("ledger-external-trade-account-count-invalid")
        if event.kind == "owned_transfer" and len(event.changes) != 2:
            raise AssessmentError("ledger-transfer-account-count-invalid")
        event_total: dict[str, int] = {}
        outgoing = False
        incoming = False
        event_value = Decimal(0)
        for label, changes in event.changes.items():
            if label not in b or not isinstance(changes, Mapping) or not changes:
                raise AssessmentError("ledger-event-account-invalid")
            for key, quantity in changes.items():
                if not isinstance(key, str) or type(quantity) is not int or quantity == 0 or abs(quantity) > 1_000_000:
                    raise AssessmentError("ledger-event-item-or-quantity-invalid")
                _priced(old_catalog, key)
                _priced(new_catalog, key)
                outgoing = outgoing or quantity < 0
                incoming = incoming or quantity > 0
                expected[label][key] = expected[label].get(key, 0) + quantity
                event_total[key] = event_total.get(key, 0) + quantity
                event_value += _priced(old_catalog, key) * quantity
        if not outgoing or not incoming:
            raise AssessmentError("ledger-event-not-two-sided")
        if event.kind == "owned_transfer":
            if any(qty != 0 for qty in event_total.values()) or event_value != 0:
                raise AssessmentError("ledger-transfer-must-conserve-assets")
            transfer += event_value
        else:
            external += event_value

    for label in b:
        for key in set(original[label]) | set(observed[label]) | set(expected[label]):
            actual_delta = observed[label].get(key, 0) - original[label].get(key, 0)
            if actual_delta != expected[label].get(key, 0):
                raise AssessmentError("unexplained-inventory-change")
    if events and not all(
        s.evidence == "native_claimed" and s.complete_eligible
        for s in list(b.values()) + list(a.values())
    ):
        raise AssessmentError("ledger-event-evidence-not-authoritative")

    before_old = _position_value(b, old_catalog)
    after_old = _position_value(a, old_catalog)
    after_new = _position_value(a, new_catalog)
    trade_delta = after_old-before_old
    price_delta = after_new-after_old
    if trade_delta != external:
        raise AssessmentError("ledger-event-valuation-not-reconciled")
    return ValueAttribution(
        before_value=before_old, after_value=after_new,
        completed_external_trades_at_old_prices=external,
        market_repricing_on_after_holdings=price_delta,
        portfolio_change=after_new-before_old,
        internal_transfer_value=transfer,
        included_events=len(events),
        evidence_status=(
            "caller-native-evidence-structurally-reconciled"
            if all(s.evidence == "native_claimed" and s.complete_eligible
                   for s in list(b.values())+list(a.values()))
            else "provisional-price-only"
        ))
