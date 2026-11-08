"""Stage 20: OFFLINE Python audit of client-reported MM2 trade outcomes.

Even CLIENT_CORROBORATED is NOT authenticated server-side completion.
No CompletedEvent, webhook, profit, or live authority is minted.
"""
from __future__ import annotations
from dataclasses import dataclass
from datetime import datetime
from typing import Mapping

class EvidenceError(ValueError):
    pass

@dataclass(frozen=True)
class OfferObservation:
    account: str
    job: str
    session: str
    partner: str
    captured_at: datetime
    our_offer: Mapping[str, int]
    their_offer: Mapping[str, int]
    our_accepted: bool | None
    their_accepted: bool | None
    trade_open: bool
    resolved: bool = False

@dataclass(frozen=True)
class ClosureObservation:
    account: str
    job: str
    session: str
    partner: str
    captured_at: datetime
    status: str  # closed_unknown | declined | success_ui_claimed

@dataclass(frozen=True)
class InventoryReadback:
    account: str
    job: str
    captured_at: datetime
    read_sequence: int
    items: Mapping[str, int]
    complete_eligible: bool = False
    source: str = 'provisional'  # native_claimed | provisional

@dataclass(frozen=True)
class OutcomeAudit:
    status: str
    reason: str
    expected_delta: tuple[tuple[str, int], ...]
    observed_delta: tuple[tuple[str, int], ...]
    client_evidence_consistent: bool = False
    server_completion_proven: bool = False
    may_record_completed_trade: bool = False
    may_report_profit: bool = False
    authorizes_trade: bool = False
    authorizes_accept: bool = False
    review_only: bool = True

def _time(t):
    if not isinstance(t, datetime) or t.tzinfo is None or t.utcoffset() is None:
        raise EvidenceError('outcome-timestamp-invalid')

def _identity(x):
    if not isinstance(x, str):
        raise EvidenceError('outcome-identity-malformed')
    parts = x.split(':')
    if (len(parts) != 3 or parts[0] not in ('godly', 'ancient', 'chroma')
        or not parts[1].isascii() or not parts[1].isdigit()
        or not 1 <= len(parts[1]) <= 8 or parts[2] != 'checker-id'):
        raise EvidenceError('outcome-identity-malformed')

def _items(items):
    if not isinstance(items, Mapping) or len(items) > 256:
        raise EvidenceError('outcome-items-malformed')
    out = {}
    for key, qty in items.items():
        _identity(key)
        if type(qty) is not int or not 1 <= qty <= 1_000_000:
            raise EvidenceError('outcome-quantity-malformed')
        out[key] = qty
    return out

def _delta(a, b):
    return {k: b.get(k, 0) - a.get(k, 0) for k in set(a)|set(b)
            if a.get(k, 0) != b.get(k, 0)}

def _result(status, reason, expected, observed):
    return OutcomeAudit(status, reason, tuple(sorted(expected.items())),
                        tuple(sorted(observed.items())),
                        client_evidence_consistent=(status == 'CLIENT_CORROBORATED'))

def review_outcome(offer: OfferObservation, close: ClosureObservation,
                   before: InventoryReadback, after1: InventoryReadback,
                   after2: InventoryReadback, *,
                   max_before_age: float = 30, max_after_age: float = 30,
                   min_scan_gap: float = 0.2) -> OutcomeAudit:
    """Cross-check offer/accept evidence, closure and repeated inventory reads.

    A client-reported success indicator and two matching post-readbacks still
    cannot independently prove a real, server-confirmed trade.
    """
    if not isinstance(offer, OfferObservation) or not isinstance(close, ClosureObservation):
        raise EvidenceError('outcome-offer-or-close-invalid')
    scans = (before, after1, after2)
    if any(not isinstance(x, InventoryReadback) for x in scans):
        raise EvidenceError('outcome-readback-invalid')
    for x in (offer, close, *scans):
        _time(x.captured_at)
    for x in (offer, close):
        for field in ('account', 'job', 'session', 'partner'):
            val = getattr(x, field)
            if not isinstance(val, str) or not val.strip() or len(val) > 120:
                raise EvidenceError('outcome-scope-invalid')
    for x in scans:
        if (not isinstance(x.account, str) or not x.account.strip()
            or not isinstance(x.job, str) or not x.job.strip()):
            raise EvidenceError('outcome-scope-invalid')
        if (type(x.read_sequence) is not int or x.read_sequence < 1
            or type(x.complete_eligible) is not bool
            or x.source not in ('native_claimed', 'provisional')):
            raise EvidenceError('outcome-scan-metadata-invalid')
    for val in (max_before_age, max_after_age, min_scan_gap):
        if type(val) not in (int, float) or not 0 < val <= 300:
            raise EvidenceError('outcome-window-invalid')
    ours, theirs = _items(offer.our_offer), _items(offer.their_offer)
    initial, post1, post2 = (_items(x.items) for x in scans)
    expected = {}
    for k, q in ours.items():
        expected[k] = expected.get(k, 0) - q
    for k, q in theirs.items():
        expected[k] = expected.get(k, 0) + q
    expected = {k: v for k, v in expected.items() if v}
    observed = _delta(initial, post2)
    scope = (offer.account, offer.job, offer.session, offer.partner)
    if (scope != (close.account, close.job, close.session, close.partner)
        or any((x.account, x.job) != scope[:2] for x in scans)):
        return _result('INCONSISTENT', 'session-or-account-mismatch', expected, observed)
    if (type(offer.trade_open) is not bool or type(offer.resolved) is not bool
        or type(offer.our_accepted) not in (bool, type(None))
        or type(offer.their_accepted) not in (bool, type(None))):
        raise EvidenceError('outcome-offer-indicator-malformed')
    if close.status not in ('closed_unknown', 'declined', 'success_ui_claimed'):
        raise EvidenceError('outcome-close-status-invalid')
    # A native trade can legitimately be one-sided (e.g. receiving one weapon
    # with nothing offered in return). Shared item types on both sides are
    # also allowed: compare the NET copy delta, not disjoint name sets.
    # However, an empty/zero-net exchange has no independently detectable
    # owned-inventory change; never corroborate it from unchanged counts.
    if not offer.trade_open or not offer.resolved or (not ours and not theirs):
        return _result('INCOMPLETE', 'offer-unresolved-or-empty', expected, observed)
    if not expected:
        return _result('INCOMPLETE', 'zero-net-offer-not-inventory-verifiable', expected, observed)
    if offer.our_accepted is not True or offer.their_accepted is not True:
        return _result('INCOMPLETE', 'both-accepted-not-observed', expected, observed)
    if close.status != 'success_ui_claimed':
        return _result('INCOMPLETE', 'closure-not-proof-of-completion', expected, observed)
    if not (before.captured_at <= offer.captured_at <= close.captured_at
            < after1.captured_at < after2.captured_at):
        return _result('INCONSISTENT', 'capture-order-invalid', expected, observed)
    if ((offer.captured_at - before.captured_at).total_seconds() > max_before_age
        or (after2.captured_at - close.captured_at).total_seconds() > max_after_age
        or (after2.captured_at - after1.captured_at).total_seconds() < min_scan_gap):
        return _result('INCOMPLETE', 'scan-timing-unverified', expected, observed)
    if not (before.read_sequence < after1.read_sequence < after2.read_sequence):
        return _result('INCOMPLETE', 'distinct-scan-sequences-unverified', expected, observed)
    if any(x.source != 'native_claimed' or not x.complete_eligible for x in scans):
        return _result('INCOMPLETE', 'complete-native-readback-unverified', expected, observed)
    if post1 != post2:
        return _result('INCONSISTENT', 'two-post-readbacks-disagree', expected, observed)
    # NET inventory reconciliation alone can hide impossible outgoing offers.
    # Example: owned A x1, offered A x3, received A x4 -> observed A +1;
    # matching net totals do not establish physical ownership of 3 copies.
    # Check each outgoing type against the independently captured PRE inventory,
    # not the post-trade count and not any incoming copies from the partner.
    if any(qty > initial.get(item, 0) for item, qty in ours.items()):
        return _result('INCONSISTENT', 'outgoing-copies-exceed-pretrade-ownership',
                       expected, observed)
    if expected != observed:
        return _result('INCONSISTENT', 'offer-does-not-match-inventory-delta', expected, observed)
    return _result('CLIENT_CORROBORATED', 'server-completion-still-unverified',
                   expected, observed)
