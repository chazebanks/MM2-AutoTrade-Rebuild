"""Stage 6: read-only, NON-AUTHORITATIVE MM2 opponent scanner-cache observations.

Scanner records have no last-successful-read timestamp. Export time is NOT scan
age; outputs can power offline review only, never authorize a live trade.
"""
from __future__ import annotations
from dataclasses import dataclass
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from typing import Any, Mapping
import re

from evaluator import AssessmentError
from market_bridge import Market
from growth_planner import GrowthPlan, plan_growth

FORMAT = "pdiddler-opponent-cache-v1"
SOURCE = "scanner-record-cache"
MAX_TARGETS = 32
MAX_ROWS = 256
MAX_COPIES = 100000


@dataclass(frozen=True)
class OpponentReview:
    label: str
    state: str
    observed_holdings: Mapping[str, int]
    issues: tuple[str, ...]
    raw_price_drift: tuple[tuple[str, str, str], ...]
    suitable_for_offline_review: bool
    authorizes_live_trade: bool = False


@dataclass(frozen=True)
class OpponentObservation:
    exported_at: datetime
    market_version: str
    opponents: tuple[OpponentReview, ...]
    scan_age_known: bool = False
    authorizes_live_trade: bool = False


def _require_int(value: Any, label: str, *, minimum: int = 0, maximum: int = MAX_COPIES) -> int:
    if type(value) is not int or not minimum <= value <= maximum:
        raise AssessmentError(f"invalid-{label}")
    return value


def parse_opponent_cache(blob: Mapping[str, Any], market: Market, now: datetime) -> OpponentObservation:
    """Validate cached rows without treating the cache as contemporaneous native proof."""
    market.catalog.validate(now)
    if not isinstance(blob, Mapping) or blob.get("format") != FORMAT or blob.get("source") != SOURCE:
        raise AssessmentError("invalid-opponent-export-contract")
    if blob.get("marketVersion") != market.source_version or blob.get("marketFresh") is not True:
        raise AssessmentError("opponent-export-market-not-verified")
    if blob.get("cacheFreshnessProven") is not False:
        raise AssessmentError("false-scanner-cache-freshness-claim")
    epoch = _require_int(blob.get("snapshotAtEpoch"), "export-time", minimum=1, maximum=10**11)
    exported = datetime.fromtimestamp(epoch, tz=timezone.utc)
    if now.tzinfo is None or now.utcoffset() is None:
        raise AssessmentError("now-must-have-timezone")
    age = (now.astimezone(timezone.utc) - exported).total_seconds()
    if age < -30 or age > 120:
        raise AssessmentError("opponent-export-too-old-or-future")
    targets = blob.get("targets")
    if not isinstance(targets, list) or len(targets) > MAX_TARGETS:
        raise AssessmentError("invalid-opponent-target-list")
    if blob.get("totalTargets") != len(targets):
        raise AssessmentError("target-count-mismatch")
    seen_labels: set[str] = set()
    result: list[OpponentReview] = []
    for target in targets:
        if not isinstance(target, Mapping):
            raise AssessmentError("invalid-opponent-record")
        label = target.get("label")
        if not isinstance(label, str) or not re.fullmatch(r"P(?:[1-9]|[12][0-9]|3[0-2])", label):
            raise AssessmentError("invalid-opponent-label")
        if label in seen_labels:
            raise AssessmentError("duplicate-opponent-label")
        seen_labels.add(label)
        state = target.get("state")
        if state not in ("whitelist", "blacklist", "unknown", "missing"):
            raise AssessmentError("invalid-opponent-state")
        if type(target.get("present")) is not bool or type(target.get("scanning")) is not bool or type(target.get("retryScheduled")) is not bool:
            raise AssessmentError("missing-scanner-state")
        issues: list[str] = []
        if state != "whitelist":
            issues.append("not-verified-whitelist")
        if not target["present"] or target["scanning"] or target["retryScheduled"]:
            issues.append("player-absent-or-scan-in-progress")
        if not isinstance(target.get("fingerprint"), str) or not target["fingerprint"]:
            issues.append("cache-fingerprint-unavailable")
        for flag in ("unmapped", "unpriced", "badQty"):
            n = target.get(flag)
            if type(n) is not int or n < 0 or n:
                issues.append(f"scanner-{flag}-incomplete")
        raw_owned = target.get("rawOwned")
        if type(raw_owned) is not int or raw_owned < 0:
            issues.append("raw-owned-count-unavailable")
        rows = target.get("items")
        if not isinstance(rows, list) or len(rows) > MAX_ROWS:
            raise AssessmentError("invalid-opponent-item-list")
        owned: dict[str, int] = {}
        seen_internal: set[str] = set()
        drift: list[tuple[str, str, str]] = []
        copies = 0
        for row in rows:
            if not isinstance(row, Mapping):
                raise AssessmentError("invalid-opponent-item-row")
            internal = row.get("id")
            if not isinstance(internal, str) or not internal or internal in seen_internal:
                raise AssessmentError("duplicate-or-missing-opponent-internal-id")
            seen_internal.add(internal)
            quantity = _require_int(row.get("qty"), "opponent-quantity", minimum=1)
            copies += quantity
            page, checker = row.get("page"), row.get("checkerId")
            if page not in ("ancient", "godly", "chroma") or not isinstance(checker, str) or not checker.isascii() or not checker.isdecimal():
                issues.append("unresolved-opponent-checker-id")
                continue
            key = f"{page}:{checker}:checker-id"
            item = market.catalog.items.get(key)
            display = row.get("name")
            if (item is None or not item.verified or not item.tradable
                    or not isinstance(display, str)
                    or display.replace("’", "'").strip().casefold() != market.names.get(key, "").replace("’", "'").strip().casefold()
                    or row.get("type") not in ("Knife", "Gun") or row.get("cat") != "Weapons"):
                issues.append("unverified-opponent-identity")
                continue
            if key in owned:
                raise AssessmentError("duplicate-opponent-checker-id")
            owned[key] = quantity
            if row.get("value") is not None:
                try:
                    raw_quote = Decimal(str(row["value"]))
                    if not raw_quote.is_finite():
                        raise InvalidOperation
                except (InvalidOperation, ValueError):
                    issues.append("invalid-scanner-display-price")
                else:
                    if raw_quote != item.value:
                        drift.append((key, str(raw_quote), str(item.value)))
        if type(raw_owned) is int and copies > raw_owned:
            issues.append("priced-copies-exceed-raw-owned-count")
        if not owned:
            issues.append("no-verified-priced-items")
        result.append(OpponentReview(label, state, owned, tuple(sorted(set(issues))),
                                     tuple(drift), not issues))
    return OpponentObservation(exported, market.source_version, tuple(result))


def compare_observed_opponent(own: Mapping[str, int], observation: OpponentReview,
                              market: Market, now: datetime, *, limit: int = 5) -> GrowthPlan:
    """Hypothetical human review. No user identity or live authorization needed."""
    if not observation.suitable_for_offline_review:
        raise AssessmentError("opponent-cache-not-usable-for-offline-review")
    return plan_growth(own, observation.observed_holdings, market.catalog, now,
                       limit=limit, max_targets=20, search_budget_each=50000)
