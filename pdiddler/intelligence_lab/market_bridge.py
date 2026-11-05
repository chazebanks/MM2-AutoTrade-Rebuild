"""Stage 2: read-only Supreme checker-ID to Python intelligence bridge.

No network, Roblox API, trade automation, webhook or mutable state.
Real catalogue snapshots are immutable/expiring evidence, not real-time quotes.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from decimal import Decimal
import json
import re
from pathlib import Path
from typing import Mapping, Any

from evaluator import AssessmentError, Catalog, Item, TradeAssessment, evaluate, portfolio_metrics

PLACE_ID = 142823291
VALID_PAGES = frozenset(("ancient", "chroma", "godly"))
STABILITY_MAP = {
    "Stable": "stable", "Fluctuating": "fluctuating",
    "Underpaid For": "underpaid", "Doing Well": "doing_well",
    "Overpaid For": "overpaid",
}
MAX_SAFE_QUANTITY = 9_007_199_254_740_991
CANONICAL_SOURCE_COMMIT = "11537dfd47f8df72aec7aeba9ecaffdfc5c879d4"


def utc_time(value: object) -> datetime:
    if not isinstance(value, str):
        raise AssessmentError("timestamp-required")
    try:
        stamp = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        raise AssessmentError("timestamp-invalid") from None
    if stamp.tzinfo is None or stamp.utcoffset() is None:
        raise AssessmentError("timestamp-missing-zone")
    return stamp.astimezone(timezone.utc)


def canonical_key(page: str, checker_id: str) -> str:
    """Checker ID is the disambiguator; *never* identify by display name alone."""
    if page not in VALID_PAGES or not isinstance(checker_id, str) or not checker_id.isascii() or not checker_id.isdigit() or not checker_id:
        raise AssessmentError("invalid-checker-identity")
    return f"{page}:{checker_id}:checker-id"


@dataclass(frozen=True)
class Market:
    catalog: Catalog
    # Exact name must match the raw item together with (page, checkerId).
    names: Mapping[str, str]
    source_commit: str
    source_version: str
    source_observed_at: datetime
    source_valid_until: datetime


def load_market(blob: Mapping[str, Any], now: datetime) -> Market:
    """Decode a normalized, pinned snapshot. No freshness extension or name-only lookup."""
    if not isinstance(blob, Mapping) or blob.get("format") != "pdiddler-supreme-checker-snapshot-v1":
        raise AssessmentError("unsupported-market-format")
    if blob.get("original_commit") != CANONICAL_SOURCE_COMMIT:
        raise AssessmentError("unexpected-source-commit")
    source_version = blob.get("version")
    if not isinstance(source_version, str) or not source_version.startswith("supreme-"):
        raise AssessmentError("missing-supreme-version")
    observed = utc_time(blob.get("observed_at"))
    expires = utc_time(blob.get("valid_until"))
    published = utc_time(blob.get("published_at"))
    if published > observed or not isinstance(blob.get("sources"), Mapping):
        raise AssessmentError("market-source-provenance-invalid")
    for page in VALID_PAGES:
        src = blob["sources"].get(page)
        if not isinstance(src, Mapping) or not isinstance(src.get("sha256"), str) or not re.fullmatch(r"[0-9a-f]{64}", src["sha256"]):
            raise AssessmentError("market-source-provenance-invalid")
        if src.get("url") != "https://supremevalues.com/mm2/" + {"ancient": "ancients", "chroma": "chromas", "godly": "godlies"}[page]:
            raise AssessmentError("market-source-url-invalid")
    rows = blob.get("items")
    if not isinstance(rows, list) or len(rows) != blob.get("profile_count") or len(rows) < 1:
        raise AssessmentError("catalogue-coverage-unproven")
    items: dict[str, Item] = {}
    names: dict[str, str] = {}
    for row in rows:
        if not isinstance(row, Mapping):
            raise AssessmentError("market-row-invalid")
        key = canonical_key(row.get("page"), row.get("id"))
        if key in items:
            raise AssessmentError("duplicate-market-identity")
        if not isinstance(row.get("name"), str) or not row["name"].strip():
            raise AssessmentError("market-item-name-invalid")
        status = STABILITY_MAP.get(row.get("stability"))
        if status is None:
            raise AssessmentError("unknown-market-status")
        value = row.get("value")
        verified = value is not None and value > 0 and row.get("verified") is True
        item = Item(identity=key, value=Decimal(str(value)) if verified else Decimal(0),
                    demand=row.get("demand"), stability=status, verified=verified)
        names[key] = row["name"]
        items[key] = item
    market = Market(Catalog(items=items, observed_at=observed,
                            valid_until=expires, source=f"Supreme {source_version} @ {CANONICAL_SOURCE_COMMIT}"),
                    names, CANONICAL_SOURCE_COMMIT, source_version, observed, expires)
    market.catalog.validate(now)
    return market


def load_market_file(filename: str | Path, now: datetime) -> Market:
    with Path(filename).open(encoding="utf-8") as fp:
        return load_market(json.load(fp), now)


def normalize_display(value: str) -> str:
    return value.replace("’", "'").strip().casefold()


@dataclass(frozen=True)
class InventoryAudit:
    inventory: Mapping[str, int]
    source: str
    job_id: str | None
    user_id: str | None
    captured_at: datetime
    exact_id_verified: int
    unresolved_units: int
    issues: tuple[str, ...]
    native_authoritative: bool


def audit_inventory(raw: Mapping[str, Any], market: Market, now: datetime, *, max_age_seconds: int = 30) -> InventoryAudit:
    """Validate real scanner shape. Screenshots may be audited but never authorize trades."""
    market.catalog.validate(now)
    if not isinstance(raw, Mapping):
        raise AssessmentError("inventory-not-an-object")
    source = raw.get("source")
    if source not in ("native_scanner", "screenshot_transcription"):
        raise AssessmentError("inventory-source-unknown")
    captured = utc_time(raw.get("captured_at"))
    if captured > now or (now - captured).total_seconds() > max_age_seconds:
        raise AssessmentError("inventory-capture-stale")
    rows = raw.get("items")
    if not isinstance(rows, list):
        raise AssessmentError("inventory-items-missing")
    issues: list[str] = []
    if not rows:
        issues.append("no-items-observed")
    if source == "screenshot_transcription":
        issues.append("screenshot-cannot-prove-native-checker-ids")
        issues.append("screenshot-cannot-prove-completeness")
    else:
        for flag in ("unmapped", "unpriced", "badQty"):
            value = raw.get(flag)
            if type(value) is not int or value < 0:
                issues.append("scanner-coverage-field-invalid")
            elif value:
                issues.append(f"scanner-{flag}-nonzero")
        if not isinstance(raw.get("fingerprint"), str) or not raw["fingerprint"]:
            issues.append("scanner-fingerprint-missing")
        if raw.get("placeId") != PLACE_ID:
            issues.append("wrong-roblox-place")
        if not isinstance(raw.get("jobId"), str) or not raw["jobId"]:
            issues.append("job-id-missing")
        if not isinstance(raw.get("playerUserId"), (int, str)) or str(raw["playerUserId"]) == "":
            issues.append("player-user-id-missing")
    out: dict[str, int] = {}
    unresolved = 0
    verified_rows = 0
    seen: set[str] = set()
    for row in rows:
        if not isinstance(row, Mapping):
            raise AssessmentError("raw-inventory-row-invalid")
        count = row.get("qty")
        if type(count) is not int or not 0 < count <= MAX_SAFE_QUANTITY:
            raise AssessmentError("raw-inventory-quantity-invalid")
        page = row.get("page")
        checker = row.get("checkerId")
        if checker is None:
            checker = row.get("id")
        try:
            key = canonical_key(page, checker)
        except AssessmentError:
            issues.append("row-unknown-or-out-of-scope-identity")
            unresolved += count
            continue
        if key in seen:
            raise AssessmentError("duplicate-inventory-identity")
        seen.add(key)
        item = market.catalog.items.get(key)
        if item is None or not item.verified:
            issues.append("row-unknown-or-unpriced")
            unresolved += count
            continue
        if not isinstance(row.get("name"), str) or normalize_display(row["name"]) != normalize_display(market.names[key]):
            issues.append("row-name-id-mismatch")
            unresolved += count
            continue
        if row.get("cat") != "Weapons" or row.get("type") not in ("Knife", "Gun"):
            issues.append("row-non-weapon-or-invalid-type")
            unresolved += count
            continue
        if source == "native_scanner" and (not isinstance(row.get("id"), str) or not row["id"]):
            issues.append("native-raw-id-missing")
            unresolved += count
            continue
        out[key] = count
        verified_rows += 1
    native_ok = source == "native_scanner" and not issues and verified_rows > 0
    return InventoryAudit(inventory=out, source=source,
                          job_id=raw.get("jobId") if source == "native_scanner" else None,
                          user_id=str(raw.get("playerUserId")) if source == "native_scanner" else None,
                          captured_at=captured, exact_id_verified=verified_rows,
                          unresolved_units=unresolved, issues=tuple(sorted(set(issues))),
                          native_authoritative=native_ok)


def analyze_observed_pair(
    own: InventoryAudit, opponent: InventoryAudit,
    give: Mapping[str, int], receive: Mapping[str, int],
    market: Market, now: datetime, *, goal_id: str = "ancient:771:checker-id",
) -> TradeAssessment:
    """Offline evaluation only. Refuse screenshots/ambiguous/stale/cross-job evidence."""
    market.catalog.validate(now)
    if not own.native_authoritative or not opponent.native_authoritative:
        raise AssessmentError("trade-evidence-not-native-authoritative")
    if not own.job_id or own.job_id != opponent.job_id:
        raise AssessmentError("scanner-reads-from-different-jobs")
    if own.user_id == opponent.user_id:
        raise AssessmentError("trade-counterparty-not-distinct")
    if max((now - own.captured_at).total_seconds(), (now - opponent.captured_at).total_seconds()) > 30:
        raise AssessmentError("trade-input-too-old")
    return evaluate(own.inventory, opponent.inventory, give, receive, market.catalog, now, goal_identity=goal_id)


def market_snapshot_summary(market: Market, audit: InventoryAudit) -> dict[str, object]:
    """Read-only safe progress summary, no acceptance or execution instruction."""
    metrics = portfolio_metrics(audit.inventory, market.catalog)
    return {
        "catalog_source": market.catalog.source,
        "valid_until_utc": market.source_valid_until.isoformat(),
        "inventory_source": audit.source,
        "native_authoritative": audit.native_authoritative,
        "verified_rows": audit.exact_id_verified,
        "unresolved_units": audit.unresolved_units,
        "known_listed_value_lower_bound": str(metrics.priced_value_lower_bound),
        "four_copy_theoretical_ceiling": str(metrics.four_copy_ceiling),
        "four_type_stack_theoretical_ceiling": str(metrics.four_type_stack_ceiling),
        "issues": list(audit.issues),
    }
