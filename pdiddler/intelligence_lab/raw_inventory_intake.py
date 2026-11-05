"""Read-only intake of the real standalone GetProfileData export.

An internal MM2 item ID is NOT a Supreme checker ID. No inferred identity
is authorized for execution. All outputs are offline observations only.
"""
from __future__ import annotations
from dataclasses import dataclass
from decimal import Decimal, InvalidOperation
from typing import Any, Mapping

FORMAT = "pdiddler-raw-inventory-v1"
SOURCE = "GetProfileData"
MAX_SAFE_INTEGER = 9007199254740991

class RawInventoryError(ValueError):
    pass

@dataclass(frozen=True)
class RawInventory:
    owned: dict[str, int]
    distinct_count: int
    total_copies: int
    provenance: str = "live-game-GetProfileData-raw-ids"
    checker_ids_verified: bool = False


def parse_raw_export(export: Mapping[str, Any]) -> RawInventory:
    """Validates all rows, not just the high-value part, and fails closed."""
    if not isinstance(export, Mapping) or export.get("format") != FORMAT or export.get("source") != SOURCE:
        raise RawInventoryError("unknown-export-format-or-source")
    rows = export.get("items")
    if not isinstance(rows, list) or not rows:
        raise RawInventoryError("empty-or-missing-items")
    owned: dict[str, int] = {}
    total = 0
    for idx, row in enumerate(rows):
        if not isinstance(row, Mapping):
            raise RawInventoryError(f"invalid-row:{idx}")
        key, qty = row.get("id"), row.get("qty")
        if not isinstance(key, str) or not key or key != key.strip() or len(key) > 200:
            raise RawInventoryError(f"invalid-internal-id:{idx}")
        if type(qty) is not int or not 0 < qty <= MAX_SAFE_INTEGER:
            raise RawInventoryError(f"invalid-quantity:{key}")
        if key in owned:
            raise RawInventoryError(f"duplicate-internal-id:{key}")
        if total > MAX_SAFE_INTEGER-qty:
            raise RawInventoryError("total-quantity-overflow")
        owned[key] = qty
        total += qty
    return RawInventory(owned=owned,distinct_count=len(owned),total_copies=total)


@dataclass(frozen=True)
class ScannedMatch:
    internal_id: str
    checker_key: str | None
    qty: int
    reason: str
    pinned_unit_value: Decimal | None = None
    scanner_unit_value: Decimal | None = None


def reconcile_scanner_output(raw: RawInventory, scanner: Mapping[str,Any], market) -> tuple[ScannedMatch, ...]:
    """Offline verification of scanner-enriched rows against raw inventory.

    Scanner must originate from the same person's same inventory episode; this
    function tests only internal item/quantity/catalogue consistency and does
    NOT grant authoritative live-trading permission. Stage 2's time/job/flag
    gates remain separately mandatory.
    """
    if not isinstance(scanner,Mapping) or not isinstance(scanner.get("items"), list):
        raise RawInventoryError("scanner-items-missing")
    if scanner.get("format") not in ("pdiddler-scanner-observation-v1",):
        raise RawInventoryError("scanner-contract-unverified")
    claimed = set()
    checker_claims: set[str] = set()
    results: list[ScannedMatch] = []
    for row in scanner["items"]:
        if not isinstance(row,Mapping):
            raise RawInventoryError("scanner-row-invalid")
        key = row.get("id")
        if not isinstance(key,str) or not key or key in claimed:
            raise RawInventoryError("scanner-internal-id-missing-or-duplicate")
        claimed.add(key)
        qty = row.get("qty")
        if type(qty) is not int or qty <= 0:
            raise RawInventoryError(f"scanner-quantity-invalid:{key}")
        if raw.owned.get(key) != qty:
            results.append(ScannedMatch(key,None,qty,"scanner-raw-quantity-mismatch"))
            continue
        page, checker, name = row.get("page"),row.get("checkerId"),row.get("name")
        if page not in ("chroma","godly","ancient") or not isinstance(checker,str) or not checker.isascii() or not checker.isdigit():
            results.append(ScannedMatch(key,None,qty,"unknown-checker-identity"))
            continue
        canonical = f"{page}:{checker}:checker-id"
        match = market.catalog.items.get(canonical)
        if not match or not match.verified:
            results.append(ScannedMatch(key,None,qty,"checker-not-in-priced-catalogue"))
            continue
        if not isinstance(name,str) or name.replace("’","'").casefold().strip() != market.names[canonical].replace("’","'").casefold().strip():
            results.append(ScannedMatch(key,None,qty,"checker-name-mismatch"))
            continue
        if canonical in checker_claims:
            raise RawInventoryError("duplicate-mapped-checker-identity")
        checker_claims.add(canonical)
        if row.get("cat") != "Weapons" or row.get("type") not in ("Knife","Gun"):
            results.append(ScannedMatch(key,None,qty,"item-not-tradable-weapon-type"))
            continue
        # A legacy scanner display quote is not the current source price.
        # Keep exact checker identity, but report the discrepancy explicitly.
        scanner_value = None
        if "value" in row and row["value"] is not None:
            try:
                scanner_value = Decimal(str(row["value"]))
            except (InvalidOperation, TypeError, ValueError):
                results.append(ScannedMatch(key,canonical,qty,
                    "matched-identity-scanner-price-invalid",match.value,None))
                continue
        if scanner_value is not None and scanner_value != match.value:
            results.append(ScannedMatch(key,canonical,qty,
                "matched-identity-scanner-price-drift",match.value,scanner_value))
            continue
        results.append(ScannedMatch(key,canonical,qty,
            "consistent-scanner-catalogue-match",match.value,scanner_value))
    return tuple(results)


@dataclass(frozen=True)
class ObservationReport:
    matches: tuple[ScannedMatch, ...]
    identity_matched_rows: int
    identity_matched_copies: int
    price_drift_rows: int
    raw_scanner_priced_total: Decimal
    pinned_market_priced_total: Decimal
    issues: tuple[str, ...]
    # Offline validation is NOT authorization to place or accept trades.
    offline_evidence_consistent: bool
    live_trading_authorized: bool = False


def audit_scanner_observation(raw: RawInventory, scanner: Mapping[str, Any], market) -> ObservationReport:
    """Compare native raw inventory and scanner export, without trade actions."""
    if not isinstance(scanner, Mapping):
        raise RawInventoryError("scanner-not-an-object")
    issues: list[str] = []
    if scanner.get("source") != "native_scanner_readonly":
        issues.append("scanner-source-not-confirmed")
    if scanner.get("marketVersion") != market.source_version:
        issues.append("scanner-market-version-mismatch")
    if scanner.get("marketFresh") is not True:
        issues.append("scanner-market-not-fresh")
    if type(scanner.get("rawOwned")) is not int or scanner["rawOwned"] != raw.total_copies:
        issues.append("scanner-raw-owned-mismatch")
    expected_fp = "|".join(f"{item_id}x{qty}" for item_id,qty in sorted(raw.owned.items()))
    if scanner.get("fingerprint") != expected_fp:
        issues.append("scanner-fingerprint-mismatch")
    for flag in ("unmapped", "unpriced", "badQty"):
        if type(scanner.get(flag)) is not int or scanner[flag] != 0:
            issues.append(f"scanner-{flag}-nonzero-or-missing")
    matches = reconcile_scanner_output(raw, scanner, market)
    matched = [m for m in matches if m.checker_key is not None]
    if any(m.checker_key is None for m in matches):
        issues.append("scanner-unresolved-identity-or-quantity")
    raw_total = sum((m.scanner_unit_value or Decimal(0))*m.qty for m in matched)
    pinned_total = sum((m.pinned_unit_value or Decimal(0))*m.qty for m in matched)
    return ObservationReport(
        matches=matches,
        identity_matched_rows=len(matched),
        identity_matched_copies=sum(m.qty for m in matched),
        price_drift_rows=sum(m.reason=="matched-identity-scanner-price-drift" for m in matched),
        raw_scanner_priced_total=raw_total,
        pinned_market_priced_total=pinned_total,
        issues=tuple(sorted(set(issues))),
        offline_evidence_consistent=not issues and bool(matched),
    )
