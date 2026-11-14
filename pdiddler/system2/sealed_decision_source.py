"""System2 sealed-source decision entry point (offline research only).

Read the original immutable 189-item operator export and immutable Stage83 Lua
afresh on EVERY call. Validate its 189-row historical mapping against a SECOND
independent pinned canonical records SHA256 before any inventory or scenario
analysis. This removes the risk of a mutable prevalidated market dictionary
quietly changing unowned / incoming weapon prices later.

Does NOT establish genuine MM2 client provenance, completed server trade,
historical source timeliness, or live-game item key truth. ALL live permissions
stay false, including when the offline calculation passes.
"""
from __future__ import annotations

import hashlib
import json

from pdiddler.system2.operator_capture_adapter import (
    AUTHORITY_DENIED, EXPORT_SHA256, ingest,
)
from pdiddler.system2.client_inventory_shadow import evaluate as validate_inventory
from pdiddler.system2.trade_scenario_lab import inspect as scenario_inspect
from pdiddler.system2.attractiveness_evidence_lab import compare as compare_alternatives
from pdiddler.system2.multitrade_growth_replay import simulate as growth_simulate

SCHEMA = "gingerscope-system2-sealed-source-decision-v1"
EXPECTED_ROWS_SHA256 = "a33d2bace80b1375bd062cb634ee0dc0dff33962bac174814ce7a490dc184c16"
MODES = ("SCENARIO", "ATTRACTIVENESS", "MULTITRADE_GROWTH")


def _result(status, reason, **data):
    return {
        "schema": SCHEMA,
        "status": status,
        "reason": reason,
        "sourceRowsPinnedToOriginalOperatorExport": False,
        "clientSessionAuthenticated": False,
        "currentGameItemIdentityAuthenticated": False,
        "publisherEditionStillRequiresIndependentArchive": True,
        "verifiedRealWorldPriceOrLiquidity": False,
        "safeForUnattendedTrading": False,
        **data,
        **AUTHORITY_DENIED,
    }


def canonical_record_hash(records):
    """Pure source seal; hash is independently pinned as EXPECTED_ROWS_SHA256."""
    if type(records) is not list or len(records) != 189:
        raise ValueError("MAPPED_189_RECORDS_REQUIRED")
    if any(type(row) is not dict for row in records):
        raise ValueError("MAPPED_ROW_STRUCTURE_INVALID")
    serialized = json.dumps(
        records, sort_keys=True, separators=(",", ":"), ensure_ascii=False,
        allow_nan=False,
    ).encode("utf-8")
    return hashlib.sha256(serialized).hexdigest()


def inspect_sealed(*, export_bytes, stage83_lua_bytes, client_envelope,
                   evaluated_at_utc, mode, payload):
    """Reverify private source bytes, read-only client observation, then one mode.

    This must NOT be used as the live strategy offer/accept interface. The
    caller controls the clock and profile envelope, so session provenance
    is explicitly UNVERIFIED even if sealed records pass.
    """
    try:
        if mode not in MODES:
            raise ValueError("UNKNOWN_RESEARCH_DECISION_MODE")
        if type(export_bytes) is not bytes or type(stage83_lua_bytes) is not bytes:
            raise ValueError("ORIGINAL_SOURCE_BYTES_REQUIRED")
        # Re-runs original first-party export SHA256 and Stage83 Git blob pin.
        mapped = ingest(export_bytes, stage83_lua_bytes)
        if mapped.get("sourceExportSha256") != EXPORT_SHA256:
            raise ValueError("ORIGINAL_EXPORT_SHA256_CONTRACT_FAILED")
        actual_rows_sha = canonical_record_hash(mapped.get("records"))
        if actual_rows_sha != EXPECTED_ROWS_SHA256:
            raise ValueError("SEALED_189_RECORD_CONTENT_MISMATCH")
        shadow = validate_inventory(mapped, client_envelope,
                                    evaluated_at_utc=evaluated_at_utc)
        if shadow.get("status") != "RESEARCH_CLIENT_INVENTORY_SHADOW_READY":
            raise ValueError(
                "CLIENT_INVENTORY_UNVERIFIED_OR_INVALID:" +
                str(shadow.get("reason", "UNKNOWN"))[:110]
            )
        if mode == "SCENARIO":
            result = scenario_inspect(mapped, shadow, payload,
                                      evaluated_at_utc=evaluated_at_utc)
        elif mode == "ATTRACTIVENESS":
            result = compare_alternatives(mapped, shadow, payload,
                                          evaluated_at_utc=evaluated_at_utc)
        else:
            result = growth_simulate(mapped, shadow, payload,
                                     evaluated_at_utc=evaluated_at_utc)
        if (result.get("status") in (None, "BLOCKED", "BLOCKED_LOSS_POLICY") or
            any(result.get(flag) != deny for flag,deny in AUTHORITY_DENIED.items())):
            return _result(
                "BLOCKED",
                "UNDERLYING_RESEARCH_DECISION_DENIED:" +
                    str(result.get("reason", "UNKNOWN"))[:100]
            )
        return _result(
            "SEALED_SOURCE_RESEARCH_ONLY",
            "ORIGINAL_OPERATOR_SOURCE_SEALED_BUT_CLIENT_AND_TRADE_UNVERIFIED",
            sourceRowsPinnedToOriginalOperatorExport=True,
            operatorExportSha256=EXPORT_SHA256,
            mappedRowsSha256=actual_rows_sha,
            researchMode=mode,
            researchResult=result,
        )
    except (ValueError, TypeError, KeyError, UnicodeError, OverflowError) as exc:
        return _result("BLOCKED", str(exc)[:220])
