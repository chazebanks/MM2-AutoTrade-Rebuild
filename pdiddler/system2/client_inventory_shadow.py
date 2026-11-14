"""System 2: read-only historical-key/quantity shadow on original P3 scanner output.

Consumes the original scanner's getOwnInventory() *client* result, NOT its stale
embedded prices. A caller-created envelope cannot certify its own provenance.
No Roblox calls, no trade plan, no live quote authorization, no account data writes.
"""
from __future__ import annotations

from datetime import datetime, timezone
import hashlib
import re

from pdiddler.system2.market_research_reader import _index
from pdiddler.system2.operator_capture_adapter import AUTHORITY_DENIED

SCHEMA = "gingerscope-system2-client-inventory-shadow-v1"
INPUT_SCHEMA = "gingerscope-system2-scanner-snapshot-envelope-v1"
SOURCE = "PDIDDLER3_SCANNER_GET_OWN_INVENTORY"
_MAX_AGE_SECONDS = 60
_CAT = {"ancient": "ancients", "godly": "godlies", "chroma": "chromas"}
_RAW = re.compile(r"[A-Za-z0-9_]{1,90}\Z")
# Actual original scanner returns exactly these fields in each eligible row.
_ITEM_FIELDS = {"id", "cat", "name", "qty", "value", "type", "page",
                "checkerId", "identity", "year", "event", "valueSource"}
_INV_FIELDS = {"items", "total", "rawOwned", "unmapped", "unpriced",
               "badQty", "seen", "fingerprint"}


def _out(status, reason, **data):
    return {
        "schema": SCHEMA, "status": status, "reason": reason,
        "clientInventoryAuthenticity": "UNVERIFIED_CALLER_SUPPLIED_CLIENT_SNAPSHOT",
        "sourceEditionAuthenticated": False,
        "currentGameItemInstanceProven": False,
        "actualTradeSessionProven": False,
        "portfolioCompletenessProven": False,
        "sellerAppealVerified": False,
        "fourPhysicalSlotTradeFeasible": False,
        "targetOutgoingProtected": True,
        **data, **AUTHORITY_DENIED,
    }


def _utc(s):
    if not isinstance(s, str) or not re.fullmatch(
        r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?Z", s
    ):
        raise ValueError("INVALID_UTC")
    return datetime.fromisoformat(s[:-1] + "+00:00").astimezone(timezone.utc)


def _natural(n, *, zero=True, maximum=1_000_000):
    return type(n) is int and (0 if zero else 1) <= n <= maximum


def _nonnegative_num(n):
    return type(n) in (int, float) and n >= 0 and n < float("inf")


def _parse_seen(values, fingerprint):
    if not isinstance(values, list) or not 0 <= len(values) <= 4000:
        raise ValueError("INVALID_OWNED_CENSUS")
    if not isinstance(fingerprint, str) or fingerprint != "|".join(sorted(values)):
        raise ValueError("OWNED_FINGERPRINT_CONFLICT")
    found = {}
    for s in values:
        if type(s) is not str:
            raise ValueError("OWNED_CENSUS_ENTRY_INVALID")
        m = re.fullmatch(r"([A-Za-z0-9_]{1,90})x([0-9]{1,7})", s)
        if not m or m.group(1) in found:
            raise ValueError("OWNED_CENSUS_ENTRY_INVALID")
        qty = int(m.group(2))
        if qty <= 0 or qty > 1_000_000:
            raise ValueError("OWNED_CENSUS_QUANTITY_INVALID")
        found[m.group(1)] = qty
    return found


def evaluate(mapped, envelope, *, evaluated_at_utc):
    """Accept scanner output contract, derive value only from pinned market data.

    This is an *offline* shadow, not proof envelope was produced in MM2 or from a
    current client. Future native adapter must independently pin its job/lease.
    """
    try:
        idx = _index(mapped)
        if (type(envelope) is not dict or set(envelope) != {
            "schema", "source", "capturedAt", "jobId", "readOnly", "inventory"
        } or envelope["schema"] != INPUT_SCHEMA
            or envelope["source"] != SOURCE
            or envelope["readOnly"] is not True):
            raise ValueError("INVALID_UNTRUSTED_ENVELOPE")
        job = envelope["jobId"]
        if type(job) is not str or not re.fullmatch(r"[A-Za-z0-9_-]{8,100}", job):
            raise ValueError("CLIENT_JOB_REFERENCE_INVALID")
        observed = _utc(envelope["capturedAt"])
        now = _utc(evaluated_at_utc)
        delta = (now - observed).total_seconds()
        if not 0 <= delta <= _MAX_AGE_SECONDS:
            raise ValueError("CLIENT_OBSERVATION_OUTSIDE_60S_RESEARCH_WINDOW")
        market_finish = _utc(mapped["captureWindowUTC"]["exportedAt"])
        if observed < market_finish:
            raise ValueError("CLIENT_OBSERVATION_PRECEDES_MARKET_EXPORT")
        inv = envelope["inventory"]
        if type(inv) is not dict or set(inv) != _INV_FIELDS:
            raise ValueError("SCANNER_INVENTORY_CONTRACT_INVALID")
        if any(not _natural(inv[k]) for k in ("rawOwned", "unmapped", "unpriced", "badQty")):
            raise ValueError("SCANNER_CENSUS_COUNTS_INVALID")
        if inv["unmapped"] != 0 or inv["badQty"] != 0:
            raise ValueError("SCANNER_CENSUS_INCOMPLETE")
        if not _nonnegative_num(inv["total"]):
            raise ValueError("LEGACY_TOTAL_SHAPE_INVALID")
        census = _parse_seen(inv["seen"], inv["fingerprint"])
        if sum(census.values()) != inv["rawOwned"]:
            raise ValueError("SCANNER_CENSUS_TOTAL_CONFLICT")
        rows = inv["items"]
        if type(rows) is not list or len(rows) > 189:
            raise ValueError("SCANNER_ITEMS_SHAPE_INVALID")
        matched = {}
        totals = {"ancients": 0, "godlies": 0, "chromas": 0}
        total = low = high = 0
        results = []
        for rec in rows:
            if type(rec) is not dict or set(rec) != _ITEM_FIELDS:
                raise ValueError("SCANNER_ITEM_FIELDS_INVALID")
            key = rec["id"]
            if (type(key) is not str or not _RAW.fullmatch(key)
                or key in matched or key not in idx):
                raise ValueError("UNKNOWN_OR_DUPLICATE_RAW_GAME_KEY")
            qty = rec["qty"]
            if not _natural(qty, zero=False) or census.get(key) != qty:
                raise ValueError("SCANNER_OWNED_QUANTITY_INCONSISTENT")
            if rec["cat"] != "Weapons" or rec["page"] not in _CAT:
                raise ValueError("SCANNER_ITEM_CATEGORY_INVALID")
            ref = idx[key]
            if _CAT[rec["page"]] != ref["category"]:
                raise ValueError("CATEGORY_OR_CHROMA_MISMATCH")
            if type(rec["type"]) is not str or rec["type"].lower() != ref["gameItemTypeCandidate"].lower():
                raise ValueError("GAME_WEAPON_TYPE_MISMATCH")
            if (type(rec["name"]) is not str or
                rec["name"].casefold() != ref["name"].casefold()):
                raise ValueError("CURRENT_GAME_LABEL_NOT_HISTORICAL_CANDIDATE")
            # Format is from original scanner's metaIdentity:
            # raw|page|normalizedItemType|chroma/normal|year|event|id|asset
            sig = rec["identity"]
            if type(sig) is not str or len(sig) > 450:
                raise ValueError("SCANNER_META_IDENTITY_MISSING")
            parts = sig.split("|")
            if (len(parts) != 8 or parts[0] != key or
                parts[1] != rec["page"] or
                parts[2] != ref["gameItemTypeCandidate"].lower() or
                parts[3] != ("chroma" if rec["page"]=="chroma" else "normal")):
                raise ValueError("SCANNER_META_IDENTITY_CONFLICT")
            if any(type(rec[k]) is not str or len(rec[k]) > 160
                   for k in ("checkerId", "year", "event", "valueSource")):
                raise ValueError("SCANNER_DIAGNOSTIC_FIELDS_INVALID")
            # The scanner's October 31 checker and total are UNTRUSTED
            # historical prices. Never copy or reconcile them as source values.
            if rec["value"] is not None and not _nonnegative_num(rec["value"]):
                raise ValueError("LEGACY_VALUE_SHAPE_INVALID")
            matched[key] = qty
            cat = ref["category"]
            subtotal = qty * ref["decimalValue"]
            totals[cat] += qty
            total += subtotal
            low += qty * ref["rangeLow"]
            high += qty * ref["rangeHigh"]
            results.append({
                "rawGameKeyCandidate": key,
                "name": ref["name"], "category": cat,
                "gameItemTypeCandidate": ref["gameItemTypeCandidate"],
                "chromaCandidate": cat == "chromas",
                "quantityClientCandidate": qty,
                "listedValue": ref["decimalValue"],
                "listedRangeLow": ref["rangeLow"],
                "listedRangeHigh": ref["rangeHigh"],
                "listedSubtotal": subtotal,
                "demand": ref["demand"], "stability": ref["stability"],
                "outgoingProtected": key == "Gingerscope",
            })
        # This checks consistency only: excluded common/evolution weapons in
        # the census cannot be independently classified from scanner.items.
        if sum(matched.values()) > inv["rawOwned"]:
            raise ValueError("MATCHED_COUNTS_EXCEED_CENSUS")
        results.sort(key=lambda x:x["rawGameKeyCandidate"])
        return _out(
            "RESEARCH_CLIENT_INVENTORY_SHADOW_READY",
            "HISTORICAL_MATCH_UNVERIFIED_CLIENT_ORIGIN_NOT_LIVE_TRADE",
            jobReferenceSha256=hashlib.sha256(job.encode()).hexdigest(),
            snapshotCapturedAt=envelope["capturedAt"],
            snapshotAgeSeconds=delta,
            sourceExportSha256=mapped["sourceExportSha256"],
            eligibleDistinctKeys=len(results),
            eligibleCopies=sum(matched.values()),
            scannerRawOwnedCopies=inv["rawOwned"],
            excludedOrUnclassifiedCopies=inv["rawOwned"]-sum(matched.values()),
            legacyScannerPricingUsed=False,
            listedEligibleTotal=total,
            listedEligibleRangeLow=low,
            listedEligibleRangeHigh=high,
            gingerscopeListedValue=idx["Gingerscope"]["decimalValue"],
            listedGapToGingerscope=max(0,idx["Gingerscope"]["decimalValue"]-total),
            listedSumDoesNotProveFourSlotOffer=True,
            byCategoryCopies=totals,
            records=results,
        )
    except (ValueError,TypeError,KeyError,AttributeError) as ex:
        return _out("BLOCKED", str(ex)[:160])
