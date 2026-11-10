"""Gingerscope offer snapshot guard: offline research only.

A *candidate* here is only an internally coherent, projected list-value
comparison. It cannot prove item identity, server settlement, executable
trade feasibility, or any right to press MM2 Accept. No network/game I/O.
"""
from __future__ import annotations

from typing import Any

SCHEMA = "gingerscope-offer-snapshot-guard-v1"
MAX_SLOTS = 4
MAX_QUANTITY = 1_000_000
MAX_VALUE = 1_000_000
MAX_OBSERVATION_AGE = 2  # seconds, synthetic / clock assertion only
MAX_CATALOG_AGE = 48 * 3600
ALLOWED_STABILITY = {"Stable", "Overpaid For"}


def _reject(reason: str) -> dict[str, Any]:
    return {
        "schema": SCHEMA,
        "status": "REJECTED",
        "reason": reason,
        "projectedListedGain": None,
        "valueOffered": None,
        "valueRequested": None,
        "exactItemIdentityAuthenticatedByGuard": False,
        "serverCompletionProven": False,
        "mayRecordCompletedTrade": False,
        "mayReportProfit": False,
        "mayUseForStrategyLearning": False,
        "authorizesTrade": False,
        "authorizesAccept": False,
        "tradeOutcome": "UNKNOWN",
    }


def _slots(value: object) -> list[tuple[int, str, int]] | None:
    if not isinstance(value, list) or not (1 <= len(value) <= MAX_SLOTS):
        return None
    out: list[tuple[int, str, int]] = []
    used: set[int] = set()
    for slot in value:
        if not isinstance(slot, dict):
            return None
        n = slot.get("index")
        item = slot.get("key")
        copies = slot.get("quantity")
        if (type(n) is not int or n < 1 or n > MAX_SLOTS or n in used
                or not isinstance(item, str) or not item or len(item) > 90
                or type(copies) is not int or not 1 <= copies <= MAX_QUANTITY):
            return None
        used.add(n)
        out.append((n, item, copies))
    return sorted(out)


def evaluate(proposal: object, observation: object, catalog: object, *, now: int,
             minimum_gain: int = 0, minimum_received_demand: int = 4) -> dict[str, Any]:
    """Research candidate gate. All fields are untrusted, including proof booleans.

    The caller must supply independently established evidence. This module
    CANNOT authenticate those claims and NEVER authorizes a real trade.
    """
    if not all(isinstance(x, dict) for x in (proposal, observation, catalog)):
        return _reject("INPUT_SHAPE_INVALID")
    if (type(now) is not int or now < 1_700_000_000 or now > 2_100_000_000
            or type(minimum_gain) is not int or minimum_gain < 0 or minimum_gain > MAX_VALUE
            or type(minimum_received_demand) is not int or
            minimum_received_demand < 1 or minimum_received_demand > 10):
        return _reject("POLICY_OR_CLOCK_INVALID")
    required_text = ("sessionId", "jobId", "partnerKey", "catalogVersion")
    if any(not isinstance(proposal.get(k), str) or not proposal[k] or len(proposal[k]) > 160
           for k in required_text):
        return _reject("PROPOSAL_BINDING_MISSING")
    if any(observation.get(k) != proposal.get(k) for k in required_text):
        return _reject("SESSION_PARTNER_OR_CATALOG_CHANGED")
    if observation.get("tradeOpen") is not True or observation.get("exactPartnerBound") is not True:
        return _reject("TRADE_OR_PARTNER_UNVERIFIED")
    if observation.get("ourAccepted") is not False or observation.get("theirAccepted") is not False:
        return _reject("ACCEPT_STATE_CHANGED_OR_UNKNOWN")
    if observation.get("offerMutationPending") is not False:
        return _reject("OFFER_MUTATION_PENDING_OR_UNKNOWN")
    pversion = proposal.get("offerRevision")
    if type(pversion) is not int or pversion < 0 or pversion > 2_147_483_647:
        return _reject("OFFER_REVISION_INVALID")
    if type(observation.get("offerRevision")) is not int or observation["offerRevision"] != pversion:
        return _reject("OFFER_REVISION_CHANGED")
    observed_at = observation.get("observedAtUnix")
    proposed_at = proposal.get("observedAtUnix")
    if any(type(x) is not int for x in (observed_at, proposed_at)) or (
        proposed_at > observed_at or observed_at > now or now - observed_at > MAX_OBSERVATION_AGE
        or proposed_at < observed_at - MAX_OBSERVATION_AGE
    ):
        return _reject("OBSERVATION_STALE_OR_CLOCK_INVALID")
    if (catalog.get("version") != proposal.get("catalogVersion")
            or catalog.get("source") != "SUPREME_DISPLAY_RESEARCH_ONLY"):
        return _reject("MARKET_SOURCE_OR_VERSION_UNMATCHED")
    publish_at = catalog.get("publisherUpdatedAtUnix")
    fetched_at = catalog.get("retrievedAtUnix")
    if (type(publish_at) is not int or type(fetched_at) is not int
            or publish_at > fetched_at or fetched_at > now
            or now - publish_at > MAX_CATALOG_AGE or publish_at < 1_700_000_000):
        return _reject("PUBLISHER_TIMESTAMP_MISSING_OR_EXPIRED")
    ours = _slots(proposal.get("ours"))
    theirs = _slots(proposal.get("theirs"))
    current_ours = _slots(observation.get("ours"))
    current_theirs = _slots(observation.get("theirs"))
    if any(x is None for x in (ours, theirs, current_ours, current_theirs)):
        return _reject("OFFER_SLOTS_UNREADABLE_OR_EMPTY")
    if ours != current_ours or theirs != current_theirs:
        return _reject("OFFER_SLOTS_CHANGED")
    items = catalog.get("items")
    if not isinstance(items, dict):
        return _reject("MARKET_ITEMS_MISSING")
    total_ours = total_theirs = 0
    for side, rows in (("ours", ours), ("theirs", theirs)):
        for _, key, qty in rows:
            entry = items.get(key)
            if not isinstance(entry, dict):
                return _reject("UNKNOWN_CATALOG_ITEM")
            if entry.get("identityLinkEvidence") != "INDEPENDENT_EXACT":
                return _reject("RAW_KEY_TO_DISPLAY_ID_UNVERIFIED")
            val = entry.get("value")
            if type(val) is not int or not 1 <= val <= MAX_VALUE:
                return _reject("CATALOG_PRICE_INVALID")
            demand = entry.get("demand")
            if type(demand) is not int or not 1 <= demand <= 10:
                return _reject("DEMAND_UNKNOWN_OR_INVALID")
            if not isinstance(entry.get("stability"), str):
                return _reject("STABILITY_UNKNOWN")
            if side == "theirs":
                if demand < minimum_received_demand:
                    return _reject("RECEIVED_ITEM_LOW_DEMAND")
                if entry["stability"] not in ALLOWED_STABILITY:
                    return _reject("RECEIVED_ITEM_UNSTABLE")
            if side == "ours":
                total_ours += val * qty
            else:
                total_theirs += val * qty
    gain = total_theirs - total_ours
    if gain < minimum_gain:
        return _reject("PROJECTED_LISTED_GAIN_BELOW_POLICY")
    return {
        **_reject("research-display-only"),
        "status": "RESEARCH_CANDIDATE_ONLY",
        "reason": "INTERNAL_SNAPSHOT_MATCH_NOT_SERVER_PROOF",
        "valueOffered": total_ours,
        "valueRequested": total_theirs,
        "projectedListedGain": gain,
    }
