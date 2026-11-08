"""Offline worst-case listed-value sensitivity across two untrusted public sources.

For each visible/display-name item, evaluate receipt at the LOWEST source
listing and relinquishment at the HIGHEST listing. This is deliberately
conservative *source-disagreement arithmetic*, not market liquidity, actual
execution price, verified MM2 game identity, or trading authority.
"""
from __future__ import annotations

from pathlib import Path
import json
from typing import Any

SNAPSHOT = Path(__file__).with_name("PUBLIC_MARKET_DISAGREEMENT_2026_11_08.json")
SOURCE_FIELDS = ("supremeListedValue", "mm2valuesListedValue")
SCHEMA = "gingerscope-dual-source-sensitivity-research-v1"


def _empty(reason: str) -> dict[str, Any]:
    return {
        "schema": SCHEMA,
        "status": "REJECTED",
        "reason": reason,
        "minListedGain": None,
        "maxListedGain": None,
        "perSourceListedGain": None,
        "quotedGainRobustlyPositive": False,
        "exactGameItemIdentityProven": False,
        "publisherCurrencyAndTimeVerified": False,
        "sourceDisplayAliasesAuthenticated": False,
        "actualTradeProfitProven": False,
        "authorizesTrade": False,
        "authorizesAccept": False,
        "mayReportProfit": False,
        "mayRecordCompletedTrade": False,
        "mayUseForStrategyLearning": False,
        "serverCompletionProven": False,
        "tradeOutcome": "UNKNOWN",
    }


def _offer(slots: object) -> list[tuple[str, int]] | None:
    if not isinstance(slots, list) or not (1 <= len(slots) <= 4):
        return None
    result = []
    for slot in slots:
        if not isinstance(slot, dict) or set(slot) != {"displayName", "quantity"}:
            return None
        name, qty = slot["displayName"], slot["quantity"]
        if not isinstance(name, str) or not name or len(name) > 90:
            return None
        if type(qty) is not int or not 1 <= qty <= 20:
            return None
        result.append((name, qty))
    return result


def calculate(our_offer: object, their_offer: object, *,
              snapshot: object, positive_threshold: int = 1) -> dict[str, Any]:
    """Pure research function: positive result grants NO actual-trade authority."""
    out = _empty("INPUT_INVALID")
    if (type(positive_threshold) is not int
        or not 1 <= positive_threshold <= 1000000):
        return _empty("THRESHOLD_INVALID")
    ours = _offer(our_offer)
    theirs = _offer(their_offer)
    if ours is None or theirs is None:
        return _empty("UNREADABLE_OR_EMPTY_OFFER")
    if not isinstance(snapshot, dict) or snapshot.get("schema") != (
        "gingerscope-offline-public-market-disagreement-v1"
    ) or snapshot.get("status") != "RESEARCH_SOURCE_DISPLAY_ONLY_NOT_EXECUTABLE":
        return _empty("SOURCE_SNAPSHOT_UNREVIEWED")
    safe = snapshot.get("safety")
    if not isinstance(safe, dict) or any(safe.get(flag) is not False for flag in (
        "exactRawWeaponIdAuthenticated", "sourceNamesMappedToGameKeys",
        "canPublishTradingPrices", "liveReady", "authorizesTrade",
        "authorizesAccept", "mayRecordCompletedTrade", "mayReportProfit",
        "mayUseForStrategyLearning", "serverCompletionProven",
    )) or safe.get("tradeOutcome") != "UNKNOWN":
        return _empty("SOURCE_UNTRUSTED_AUTHORITY")
    if snapshot.get("observedDateUtc") != "2026-11-08":
        return _empty("UNREVIEWED_SOURCE_DATE")
    records = snapshot.get("records")
    if not isinstance(records, list) or len(records) != 10:
        return _empty("REVIEWED_SOURCE_ROWS_INCOMPLETE")
    by_name = {}
    for record in records:
        if not isinstance(record, dict) or not isinstance(record.get("displayName"), str):
            return _empty("SOURCE_RECORD_SHAPE_INVALID")
        name = record["displayName"]
        a, b = (record.get(k) for k in SOURCE_FIELDS)
        if (name in by_name or type(a) is not int or type(b) is not int
            or not 1 <= a <= 1000000 or not 1 <= b <= 1000000
            or record.get("rawKeyCheckerIdentityAttested") is not False
            or record.get("tradeAuthority") is not False):
            return _empty("SOURCE_RECORD_UNTRUSTED")
        by_name[name] = (a,b)
    low_received=high_received=low_given=high_given=0
    per_source_received=[0,0]
    per_source_given=[0,0]
    for side, offer in (("ours",ours),("theirs",theirs)):
        for name, quantity in offer:
            if name not in by_name:
                return _empty("ITEM_MISSING_FROM_BOTH_SOURCES")
            a,b=by_name[name]
            if side=="ours":
                low_given+=min(a,b)*quantity
                high_given+=max(a,b)*quantity
                per_source_given[0]+=a*quantity
                per_source_given[1]+=b*quantity
            else:
                low_received+=min(a,b)*quantity
                high_received+=max(a,b)*quantity
                per_source_received[0]+=a*quantity
                per_source_received[1]+=b*quantity
    worst=low_received-high_given
    best=high_received-low_given
    gains=[a-b for a,b in zip(per_source_received,per_source_given)]
    out["minListedGain"]=worst
    out["maxListedGain"]=best
    out["perSourceListedGain"]={
        "supreme":gains[0],
        "mm2values":gains[1],
    }
    out["quotedGainRobustlyPositive"]=worst>=positive_threshold
    out["status"]=(
        "CROSS_SOURCE_DISPLAY_MARGIN_POSITIVE_ONLY"
        if out["quotedGainRobustlyPositive"]
        else "SOURCE_DISAGREEMENT_EXPOSES_DOWNSIDE"
    )
    out["reason"]=(
        "DISPLAY_VALUES_ONLY_NO_AUTHENTICATED_TRANSACTION_OR_ITEM"
    )
    return out


def load_snapshot() -> dict[str, Any]:
    """Local static data; never fetch or trust a live market publisher timestamp."""
    return json.loads(SNAPSHOT.read_text(encoding="utf-8"))
