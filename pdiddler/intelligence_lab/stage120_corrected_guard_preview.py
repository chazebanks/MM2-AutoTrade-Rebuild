"""Stage120: connect EXISTING PR106 planner to CORRECTED PR182 guard.

Strictly synthetic/offline bridge. This replaces neither Stage86 nor its archived
PR105 evidence: Stage86 proved the old planner/guard pairing; this checks the
corrected FOUR-PHYSICAL-SLOT, protected-Gingerscope guard plus fixed source expiry.
No MM2, game/Delta calls, current quotes, player identity proof or Accept.
"""
from __future__ import annotations

from copy import deepcopy
import hashlib
import importlib.util
from pathlib import Path
import re

SCHEMA = "gingerscope-stage120-corrected-guard-synthetic-preview-v1"
PLANNER_BLOB = "78948cdacd2a760db5b888fce242d598fc6f14b6"  # PR106
GUARD_BLOB = "11db895622d053ddced4fba9666135bf97bd615b"  # PR182
MARKET_VERSION = "SYNTHETIC-STAGE120-V1"
FAKE_KEY = re.compile(r"(?:test_[a-z0-9_]{1,30}|Gingerscope)\Z")
FAKE_BINDING = re.compile(r"test_[a-z0-9_]{1,40}\Z")
FLAGS = {
    "readOnly": True, "simulationOnly": True,
    "verifiedMarketQuote": False, "verifiedGameItemIdentity": False,
    "counterpartyConsentProven": False, "serverTradeRevisionProven": False,
    "serverCompletionProven": False, "mayRecordCompletedTrade": False,
    "mayReportProfit": False, "maySendDiscordWebhook": False,
    "mayUseForStrategyLearning": False, "authorizesTrade": False,
    "authorizesOffer": False, "authorizesAccept": False,
    "tradeOutcome": "UNKNOWN",
}


def _result(status: str, reason: str, **data):
    # Constant denied authority always wins over caller-provided fields.
    return {"schema": SCHEMA, "status": status, "reason": reason, **data, **FLAGS}


def _blob(path: Path) -> str:
    raw = path.read_bytes()
    return hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()


def _source(path: Path, expected: str, name: str):
    if _blob(path) != expected:
        raise ValueError("FROZEN_" + name + "_BLOB_MISMATCH")
    spec = importlib.util.spec_from_file_location("gingerscope_stage120_" + name, path)
    if spec is None or spec.loader is None:
        raise ValueError("FROZEN_" + name + "_MISSING")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _fixture_ok(own, other, market, binding, now):
    if type(now) is not int or not 1_700_000_000 <= now <= 2_100_000_000:
        return False
    if type(own) is not list or type(other) is not list:
        return False
    for side in (own, other):
        if not 1 <= len(side) <= 5:
            return False
        seen = set()
        for row in side:
            if type(row) is not dict or set(row) != {"key", "quantity"}:
                return False
            key, qty = row["key"], row["quantity"]
            if (type(key) is not str or FAKE_KEY.fullmatch(key) is None
                    or key in seen or type(qty) is not int or not 1 <= qty <= 2):
                return False
            seen.add(key)
    if type(binding) is not dict or set(binding) != {
        "fixtureKind", "sessionId", "jobId", "partnerKey", "offerRevision"
    } or binding["fixtureKind"] != "SYNTHETIC_OFFLINE_TEST":
        return False
    if any(type(binding[k]) is not str or FAKE_BINDING.fullmatch(binding[k]) is None
           for k in ("sessionId", "jobId", "partnerKey")):
        return False
    if type(binding["offerRevision"]) is not int or not 0 <= binding["offerRevision"] <= 2_147_483_647:
        return False
    if type(market) is not dict or market.get("source") != "SUPREME_DISPLAY_RESEARCH_ONLY" or (
        market.get("version") != MARKET_VERSION
    ):
        return False
    rows = market.get("items")
    if type(rows) is not dict or not 1 <= len(rows) <= 11:
        return False
    if any(type(k) is not str or FAKE_KEY.fullmatch(k) is None for k in rows):
        return False
    return True


def _fresh(market, now):
    # Hard source expiry is independent of retrieval time / 48-hour publisher
    # cap. Re-downloading unchanged content must not reactivate an old quote.
    pub = market.get("publisherUpdatedAtUnix")
    got = market.get("retrievedAtUnix")
    expires = market.get("sourceValidUntilUnix")
    if any(type(x) is not int for x in (pub, got, expires)):
        return False
    return (1_700_000_000 <= pub <= got <= now <= expires
            and expires <= pub + 48 * 3600)


def _slots(bundle):
    return [{"index": i, "key": item["key"], "quantity": item["quantity"]}
            for i, item in enumerate(bundle, 1)]


def _proposal(candidate, binding, now):
    return {
        "sessionId": binding["sessionId"],
        "jobId": binding["jobId"],
        "partnerKey": binding["partnerKey"],
        "catalogVersion": MARKET_VERSION,
        "offerRevision": binding["offerRevision"], "observedAtUnix": now,
        "ours": _slots(candidate["offer"]), "theirs": _slots(candidate["receive"]),
    }


def _ideal_synthetic(proposal):
    # This is NOT a captured MM2 observation; used only to filter hypothetical
    # research candidates. Actual live input is prohibited at fixture boundary.
    return {**deepcopy(proposal), "tradeOpen": True, "exactPartnerBound": True,
            "ourAccepted": False, "theirAccepted": False,
            "offerMutationPending": False}


def prepare(own, other, market, binding, *, now: int, planner_path: Path, guard_path: Path):
    """One candidate from existing planner; checked by corrected PR182 guard."""
    if not _fixture_ok(own, other, market, binding, now):
        return _result("BLOCKED", "SYNTHETIC_FIXTURE_REQUIRED")
    if not _fresh(market, now):
        return _result("BLOCKED", "SOURCE_FIXED_EXPIRY_OR_PUBLISHER_INVALID")
    try:
        planner = _source(planner_path, PLANNER_BLOB, "planner")
        guard = _source(guard_path, GUARD_BLOB, "guard")
    except (OSError, ImportError, ValueError):
        return _result("BLOCKED", "FROZEN_COMPONENT_PROVENANCE_FAILED")
    candidates = planner.plan(deepcopy(own), deepcopy(other), deepcopy(market),
                              now=now, min_gain=0, min_received_demand=4,
                              min_received_liquidity=4,
                              max_counterparty_overpay_pct=100, max_results=10)
    if candidates.get("authorizesTrade") is not False or (
        candidates.get("authorizesAccept") is not False
    ):
        return _result("BLOCKED", "PLANNER_AUTHORITY_INVALID")
    if candidates.get("status") != "CANDIDATES_PREPARED":
        return _result("NO_PROPOSAL", str(candidates.get("reason", "NO_VALID_CANDIDATE")))
    refused = {}
    for candidate in candidates.get("candidates", []):
        offered = candidate.get("offer", [])
        received = candidate.get("receive", [])
        if not (1 <= len(offered) <= 4 and 1 <= len(received) <= 4):
            refused["PHYSICAL_SLOT_LIMIT"] = refused.get("PHYSICAL_SLOT_LIMIT", 0) + 1
            continue
        prop = _proposal(candidate, binding, now)
        outcome = guard.evaluate(deepcopy(prop), _ideal_synthetic(prop),
                                 deepcopy(market), now=now, minimum_gain=0,
                                 minimum_received_demand=4)
        if outcome.get("authorizesAccept") is not False or (
            outcome.get("authorizesTrade") is not False
        ):
            return _result("BLOCKED", "CORRECTED_GUARD_AUTHORITY_INVALID")
        if outcome.get("status") == "RESEARCH_CANDIDATE_ONLY":
            if outcome.get("projectedListedGain") != candidate.get("projectedListedGain"):
                return _result("BLOCKED", "PLANNER_GUARD_VALUE_DISAGREEMENT")
            return _result(
                "SYNTHETIC_PROPOSAL_ONLY", "CORRECTED_GUARD_IDEAL_FIXTURE_MATCH",
                proposal=prop, candidateKind=candidate.get("type"),
                listedGainResearchOnly=candidate.get("projectedListedGain"),
                alternativesExamined=len(refused) + 1,
                sourceValidUntilUnix=market["sourceValidUntilUnix"],
            )
        reason = str(outcome.get("reason", "GUARD_REFUSED"))
        refused[reason] = refused.get(reason, 0) + 1
    if "PROTECTED_GINGERSCOPE_OUTGOING" in refused:
        return _result("NO_PROPOSAL", "PROTECTED_GINGERSCOPE_OUTGOING")
    return _result("NO_PROPOSAL", "NO_CANDIDATE_PASSED_CORRECTED_GUARD",
                   blockedReasonCounts=refused)


def verify(prepared, observed, market, *, now: int, guard_path: Path):
    """Guard a separately supplied *synthetic* snapshot after prepare.

    Never reconstruct the observation from prepared values here. Any changed
    offer, epoch, partner, expiry or Gingerscope outgoing invalidates it.
    """
    if (type(prepared) is not dict or prepared.get("status") != "SYNTHETIC_PROPOSAL_ONLY"
            or prepared.get("simulationOnly") is not True
            or prepared.get("authorizesTrade") is not False
            or type(market) is not dict or market.get("version") != MARKET_VERSION):
        return _result("BLOCKED", "NO_VALID_SYNTHETIC_PROPOSAL")
    if not _fresh(market, now) or market.get("sourceValidUntilUnix") != prepared.get("sourceValidUntilUnix"):
        return _result("BLOCKED", "SOURCE_EXPIRED_OR_CHANGED_SINCE_PREPARE")
    if type(observed) is not dict:
        return _result("BLOCKED", "INDEPENDENT_SYNTHETIC_OBSERVATION_MISSING")
    try:
        guard = _source(guard_path, GUARD_BLOB, "guard")
    except (OSError, ImportError, ValueError):
        return _result("BLOCKED", "FROZEN_GUARD_PROVENANCE_FAILED")
    evidence = guard.evaluate(deepcopy(prepared["proposal"]), deepcopy(observed),
                              deepcopy(market), now=now, minimum_gain=0,
                              minimum_received_demand=4)
    if evidence.get("authorizesTrade") is not False or evidence.get("authorizesAccept") is not False:
        return _result("BLOCKED", "CORRECTED_GUARD_AUTHORITY_INVALID")
    if evidence.get("status") != "RESEARCH_CANDIDATE_ONLY":
        return _result("REPLAN_REQUIRED", str(evidence.get("reason", "CORRECTED_GUARD_REJECTED")))
    if evidence.get("projectedListedGain") != prepared.get("listedGainResearchOnly"):
        return _result("REPLAN_REQUIRED", "CANDIDATE_VALUE_MISMATCH")
    return _result("IDEAL_SYNTHETIC_MATCH_ONLY",
                   "NO_MM2_EXECUTION_OR_ACCEPT_AUTHORITY",
                   candidateKind=prepared["candidateKind"],
                   listedGainResearchOnly=prepared["listedGainResearchOnly"])
