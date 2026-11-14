"""System2 Part 3: deterministic MULTI-PART offline trade scenario laboratory.

The lab consumes the already read-only inventory shadow and immutable-source
market research record. It does not propose an MM2 offer, place/accept trades,
estimate completion probabilities, or treat Supreme demand as measured liquidity.

Physical offer slots and stacked quantities are separately accounted for. The
Gingerscope acquisition target is never allowed outgoing, even in simulations.
"""
from __future__ import annotations

from collections import Counter
from pdiddler.system2.market_research_reader import _index, TARGET_KEY
from pdiddler.system2.operator_capture_adapter import AUTHORITY_DENIED, EXPORT_SHA256

SCHEMA = "gingerscope-system2-offline-trade-scenario-v1"
SHADOW_SCHEMA = "gingerscope-system2-client-inventory-shadow-v1"
SIMULATION_KIND = "SYNTHETIC_OFFLINE_TEST"
MAX_OFFER_SLOTS = 4


def _out(status, reason, **data):
    return {
        "schema": SCHEMA,
        "status": status,
        "reason": reason,
        "simulationOnly": True,
        "livePriceAuthority": False,
        "clientOwnedItemAuthenticityProven": False,
        "partnerInventoryAuthenticityProven": False,
        "offerSessionRevisionProven": False,
        "partnerAppeal": "UNMEASURED",
        "executedTradeLiquidity": "UNKNOWN",
        "acceptanceProbability": None,
        "fourPhysicalSlotLayoutSimulated": True,
        "fourPhysicalSlotExecutionProven": False,
        "approvedRiskBudget": False,
        "controlledLossTradeAuthorized": False,
        "gingerscopeOutgoingProtected": True,
        **data, **AUTHORITY_DENIED,
    }


def _positive_integer(x):
    return type(x) is int and 1 <= x <= 10_000


def _slots(rows, *, allow_empty):
    if type(rows) is not list or not (0 if allow_empty else 1) <= len(rows) <= MAX_OFFER_SLOTS:
        raise ValueError("PHYSICAL_OFFER_SLOT_COUNT_INVALID")
    seen = set()
    parsed = {}
    for row in rows:
        if type(row) is not dict or set(row) != {"rawGameKey", "quantity"}:
            raise ValueError("INVALID_PHYSICAL_SLOT_FIELDS")
        key, count = row["rawGameKey"], row["quantity"]
        if type(key) is not str or not key or key in seen or not _positive_integer(count):
            raise ValueError("UNKNOWN_DUPLICATE_OR_INVALID_SLOT")
        seen.add(key)
        parsed[key] = count
    return parsed


def _owned_from_shadow(shadow, idx):
    if (type(shadow) is not dict
            or shadow.get("schema") != SHADOW_SCHEMA
            or shadow.get("status") != "RESEARCH_CLIENT_INVENTORY_SHADOW_READY"
            or shadow.get("sourceExportSha256") != EXPORT_SHA256
            or shadow.get("legacyScannerPricingUsed") is not False
            or shadow.get("clientInventoryAuthenticity") != "UNVERIFIED_CALLER_SUPPLIED_CLIENT_SNAPSHOT"
            or shadow.get("portfolioCompletenessProven") is not False
            or shadow.get("currentGameItemInstanceProven") is not False
            or shadow.get("targetOutgoingProtected") is not True
            or any(shadow.get(key) != value for key, value in AUTHORITY_DENIED.items())):
        raise ValueError("UNVERIFIED_OR_MUTATED_INVENTORY_SHADOW")
    rows = shadow.get("records")
    if type(rows) is not list or len(rows) > 189:
        raise ValueError("INVALID_SHADOW_ROWS")
    owned = {}
    total = 0
    copies = 0
    for row in rows:
        if type(row) is not dict:
            raise ValueError("INVALID_SHADOW_ITEM")
        key = row.get("rawGameKeyCandidate")
        qty = row.get("quantityClientCandidate")
        if type(key) is not str or key in owned or key not in idx or not _positive_integer(qty):
            raise ValueError("INVALID_SHADOW_ITEM")
        source = idx[key]
        if (row.get("category") != source["category"]
                or row.get("chromaCandidate") is not (source["category"] == "chromas")
                or row.get("listedValue") != source["decimalValue"]
                or row.get("listedSubtotal") != qty * source["decimalValue"]
                or row.get("outgoingProtected") is not (key == TARGET_KEY)):
            raise ValueError("SHADOW_MARKET_IDENTITY_OR_PRICE_MISMATCH")
        owned[key] = qty
        total += qty * source["decimalValue"]
        copies += qty
    if (shadow.get("eligibleDistinctKeys") != len(owned)
            or shadow.get("eligibleCopies") != copies
            or shadow.get("listedEligibleTotal") != total):
        raise ValueError("SHADOW_CENSUS_OR_TOTAL_MISMATCH")
    return owned, total


def _totals(slots, idx):
    value = low = high = copies = 0
    weighted_demand = 0
    labels = Counter()
    for key, qty in slots.items():
        source = idx[key]
        value += source["decimalValue"] * qty
        low += source["rangeLow"] * qty
        high += source["rangeHigh"] * qty
        copies += qty
        weighted_demand += source["demand"] * qty
        labels[source["stability"]] += qty
    return {
        "listed": value, "low": low, "high": high, "copies": copies,
        "demandArithmeticMean": (weighted_demand / copies) if copies else None,
        "stabilityCopyCounts": dict(sorted(labels.items())),
    }


def inspect(mapped, shadow, scenario):
    """Review one hypothetical bilateral exchange; NEVER selects execution."""
    try:
        idx = _index(mapped)
        if (type(scenario) is not dict or set(scenario) != {
            "kind", "outgoingSlots", "incomingSlots"
        } or scenario["kind"] != SIMULATION_KIND):
            raise ValueError("EXPLICIT_SYNTHETIC_SCENARIO_REQUIRED")
        owned, before = _owned_from_shadow(shadow, idx)
        outgoing = _slots(scenario["outgoingSlots"], allow_empty=True)
        incoming = _slots(scenario["incomingSlots"], allow_empty=False)
        if TARGET_KEY in outgoing:
            raise ValueError("GINGERSCOPE_NEVER_OUTGOING")
        if any(key not in idx for key in (*outgoing, *incoming)):
            raise ValueError("UNKNOWN_EXACT_HISTORICAL_WEAPON_KEY")
        if any(owned.get(key, 0) < qty for key, qty in outgoing.items()):
            raise ValueError("OUTGOING_EXCEEDS_CLIENT_OBSERVED_OWNED_COPIES")
        if not outgoing and not incoming:
            raise ValueError("EMPTY_EXCHANGE")
        sold, bought = _totals(outgoing, idx), _totals(incoming, idx)
        gain = bought["listed"] - sold["listed"]
        after = before + gain
        physical_out, physical_in = len(outgoing), len(incoming)
        kind = ("UPGRADE" if physical_in < physical_out else
                "DOWNGRADE" if physical_in > physical_out else "SIDEGRADE")
        # Descriptive only: no inference that item demand equals fill rate.
        risk = []
        if gain < 0:
            risk.append("UNAPPROVED_LISTED_VALUE_LOSS")
        if bought["low"] - sold["high"] < 0:
            risk.append("WORST_CASE_RANGE_LOSS_POSSIBLE")
        if sold["copies"] > MAX_OFFER_SLOTS or bought["copies"] > MAX_OFFER_SLOTS:
            risk.append("STACKED_COPIES_DISTINCT_FROM_PHYSICAL_SLOTS")
        if TARGET_KEY in incoming:
            risk.append("TARGET_INCOMING_HYPOTHETICAL_NOT_ACQUIRED")
        if not outgoing:
            risk.append("EMPTY_OUTGOING_HYPOTHETICAL_GIFT")
        risk.append("NO_VERIFIED_COUNTERPARTY_LIQUIDITY_OR_ACCEPTANCE_DATA")
        # Do not invent liquidity or a risk budget, or silently approve loss.
        return _out(
            "OFFLINE_LOSS_SCENARIO_BLOCKED_POLICY" if gain < 0 else "OFFLINE_SCENARIO_REVIEWED",
            "NO_APPROVED_LOSS_BUDGET" if gain < 0 else "LISTED_VALUE_RESEARCH_NOT_TRADE_PROPOSAL",
            sourceExportSha256=EXPORT_SHA256,
            scenarioKind=kind,
            outgoingPhysicalSlots=physical_out,
            incomingPhysicalSlots=physical_in,
            outgoingCopies=sold["copies"],
            incomingCopies=bought["copies"],
            offeredListedValue=sold["listed"],
            receivedListedValue=bought["listed"],
            listedDelta=gain,
            worstCaseRangeDelta=bought["low"] - sold["high"],
            bestCaseRangeDelta=bought["high"] - sold["low"],
            beforeListedPortfolioValue=before,
            afterHypotheticalListedPortfolioValue=after,
            hypotheticalTargetReceived=TARGET_KEY in incoming,
            gingerscopeTargetListedValue=idx[TARGET_KEY]["decimalValue"],
            postHypotheticalListedGapToTarget=max(0,idx[TARGET_KEY]["decimalValue"]-after),
            outgoingDemandScoreMean=sold["demandArithmeticMean"],
            incomingDemandScoreMean=bought["demandArithmeticMean"],
            incomingStabilityCounts=bought["stabilityCopyCounts"],
            outgoingStabilityCounts=sold["stabilityCopyCounts"],
            warnings=risk,
        )
    except (ValueError, KeyError, TypeError, AttributeError) as error:
        return _out("BLOCKED", str(error)[:180])
