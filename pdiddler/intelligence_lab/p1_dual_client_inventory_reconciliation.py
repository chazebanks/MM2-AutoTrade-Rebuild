"""P1 offline cross-client inventory reconciliation, not MM2 settlement proof.

Strictly synthetic TEST_ item IDs and CLIENT snapshots. This explores whether
two *untrusted* inventory readbacks would be conservation-consistent with a
hypothetical offer; it NEVER validates an actual transaction, server-origin
identity, account independence, final Accept, profit, or strategy learning.

Distinct from existing Stage115 single-client post-close replay and Stage119
P3/P4 client GUI/LastOffer observations. All evidence stays synthetic.
"""
from __future__ import annotations

from collections import Counter
import re

SCHEMA = "gingerscope-p1-dual-client-synthetic-reconciliation-v1"
SIDES = ("OURS", "THEIRS")
KEY = re.compile(r"TEST_[A-Z0-9_]{1,48}\Z")
TOKEN = re.compile(r"TEST_SESSION_[A-Z0-9_]{1,48}\Z")
MAX_INVENTORY_TYPES = 128
MAX_PHYSICAL_OFFER_SLOTS = 4
MAX_QUANTITY = 100_000
FALSE_AUTHORITY = {
    "serverCompletionProven": False,
    "serverTransactionIdAuthenticated": False,
    "eventSessionAssociationProven": False,
    "uniqueWeaponInstanceProven": False,
    "rawItemIdConfirmed": False,
    "clientWitnessIndependenceProven": False,
    "observedTransferAttributedToTrade": False,
    "mayRecordCompletedTrade": False,
    "mayUseForStrategyLearning": False,
    "mayReportProfit": False,
    "maySendDiscordWebhook": False,
    "authorizesOffer": False,
    "authorizesTrade": False,
    "authorizesAccept": False,
    "verifiedMarketQuote": False,
    "mayUpdatePriceFiles": False,
    "mayUpdateProduction": False,
}


class ReconcileInputError(ValueError):
    pass


def _require(condition, reason):
    if not condition:
        raise ReconcileInputError(reason)


def _items(rows, *, limit):
    _require(type(rows) is list and len(rows) <= limit, "ITEM_LIST_INVALID")
    out = Counter()
    for entry in rows:
        _require(type(entry) is dict and set(entry) == {"key", "quantity"},
                 "ITEM_ROW_SCHEMA_INVALID")
        key, qty = entry["key"], entry["quantity"]
        _require(type(key) is str and KEY.fullmatch(key) is not None,
                 "REAL_OR_INVALID_ITEM_KEY")
        _require(type(qty) is int and 1 <= qty <= MAX_QUANTITY,
                 "ITEM_QUANTITY_INVALID")
        _require(key not in out, "DUPLICATE_ITEM_KEY")
        out[key] = qty
    return out


def _result(status, reason, **details):
    return {
        "schema": SCHEMA,
        "status": status,
        "reason": reason,
        "syntheticOnly": True,
        "readOnly": True,
        "realVerifiedCompletedTrades": 0,
        "serverSettlementsInferred": 0,
        "tradeOutcome": "UNKNOWN",
        "marketPrices": None,
        "cannotDistinguishTradeFromOtherInventoryMovements": True,
        "mayAdvanceP2": False,
        "mayUseForLivePriceCalibration": False,
        **FALSE_AUTHORITY,
        **details,
    }


def audit(report):
    """Check hypothetical offer vs two CLIENT before/after inventory readbacks.

    Caller cannot supply any receipt, settlement, authorization, raw weapon
    proof, private account IDs, real item IDs or player data. Passing means
    ONLY that the submitted synthetic numbers are conservation-consistent.
    """
    _require(type(report) is dict and set(report) == {
        "schema", "mode", "sessionToken", "offerRevision", "offered", "witnesses"
    }, "SOURCE_FIELDS_UNTRUSTED")
    _require(report["schema"] == SCHEMA and report["mode"] == "HYPOTHETICAL_ONLY",
             "REAL_EVIDENCE_NOT_AUTHORIZED")
    token = report["sessionToken"]
    revision = report["offerRevision"]
    _require(type(token) is str and TOKEN.fullmatch(token) is not None,
             "UNSAFE_SESSION_TOKEN")
    _require(type(revision) is int and 1 <= revision <= 1_000_000,
             "OFFER_REVISION_INVALID")
    offered, witnesses = report["offered"], report["witnesses"]
    _require(type(offered) is dict and set(offered) == set(SIDES),
             "OFFER_SIDES_INVALID")
    _require(type(witnesses) is list and len(witnesses) == 2, "WITNESS_COUNT_INVALID")
    offers = {side: _items(offered[side], limit=MAX_PHYSICAL_OFFER_SLOTS)
              for side in SIDES}
    _require(bool(offers["OURS"] or offers["THEIRS"]), "EMPTY_OFFER")
    _require(not any("GINGERSCOPE" in k for k in offers["OURS"]),
             "PROTECTED_GINGERSCOPE_OUTBOUND")
    wmap = {}
    for witness in witnesses:
        _require(type(witness) is dict and set(witness) == {
            "side", "source", "sessionToken", "offerRevision",
            "beforeMs", "closeMs", "afterMs", "before", "after"
        }, "WITNESS_FIELDS_UNTRUSTED")
        side = witness["side"]
        _require(type(side) is str and side in SIDES and side not in wmap,
                 "WITNESS_SIDE_DUPLICATE_OR_INVALID")
        _require(witness["source"] == "CLIENT_SNAPSHOT",
                 "UNSUPPORTED_OR_FAKE_SERVER_WITNESS")
        _require(witness["sessionToken"] == token,
                 "CROSS_SESSION_CLIENT_READBACK")
        _require(type(witness["offerRevision"]) is int
                 and witness["offerRevision"] == revision,
                 "STALE_OR_WRONG_OFFER_REVISION")
        times = [witness[f] for f in ("beforeMs", "closeMs", "afterMs")]
        _require(all(type(v) is int and 0 <= v <= 3_600_000 for v in times)
                 and times[0] < times[1] < times[2],
                 "PRE_CLOSE_POST_ORDER_INVALID")
        before = _items(witness["before"], limit=MAX_INVENTORY_TYPES)
        after = _items(witness["after"], limit=MAX_INVENTORY_TYPES)
        _require(all(before[k] >= qty for k, qty in offers[side].items()),
                 "OFFER_EXCEEDS_BEFORE_SNAPSHOT")
        wmap[side] = (before, after)
    _require(set(wmap) == set(SIDES), "WITNESS_SIDE_MISSING")
    expected = {}
    observed = {}
    for side, other in (("OURS", "THEIRS"), ("THEIRS", "OURS")):
        lost = offers[side]
        gained = offers[other]
        expected[side] = {k: gained[k] - lost[k]
                          for k in set(gained) | set(lost)
                          if gained[k] != lost[k]}
        before, after = wmap[side]
        observed[side] = {k: after[k] - before[k]
                          for k in set(before) | set(after)
                          if after[k] != before[k]}
    if not any(expected.values()):
        return _result("INCONCLUSIVE_NO_NET_EFFECT", "SAME_KEY_EXCHANGE_NO_OBSERVABLE_NET",
                       offerRevision=revision, syntheticWitnessCount=2,
                       clientDeltaMatchesExpected=False,
                       unexpectedOrMissingDeltaCount=0)
    errors = {}
    for side in SIDES:
        keys = set(expected[side]) | set(observed[side])
        errors[side] = sorted(k for k in keys
                              if observed[side].get(k, 0) != expected[side].get(k, 0))
    if any(errors.values()):
        return _result("QUARANTINED", "BILATERAL_CLIENT_DELTA_CONFLICT",
                       offerRevision=revision, syntheticWitnessCount=2,
                       clientDeltaMatchesExpected=False,
                       unexpectedOrMissingDeltaCount=sum(map(len, errors.values())),
                       unmatchedSyntheticKeysBySide=errors)
    return _result("CLIENT_BILATERAL_DELTAS_MATCH_SYNTHETIC",
                   "NUMERIC_CONSERVATION_ONLY_NO_SERVER_CAUSALITY",
                   offerRevision=revision, syntheticWitnessCount=2,
                   clientDeltaMatchesExpected=True,
                   unexpectedOrMissingDeltaCount=0,
                   matchedChangedSyntheticKeyCounts={
                       side: len(expected[side]) for side in SIDES},
                   noServerSettlementOrItemInstanceProof=True)
