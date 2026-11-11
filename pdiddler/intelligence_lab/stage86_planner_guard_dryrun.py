"""Stage86: integrate EXISTING pinned portfolio planner and offer snapshot guard.

A test-only adapter: synthetic items, synthetic market, one frozen session
and offer revision. No Roblox, no actual order/offer placement or trading.
Neither 'independent exact' from a fixture nor a passed guard authenticates
MM2 items, price sources, counterparty consent, server outcome or profit.
"""
from __future__ import annotations

from copy import deepcopy
import hashlib
import importlib.util
from pathlib import Path
import re
from typing import Any

SCHEMA="gingerscope-stage86-manual-final-accept-dryrun-v1"
GUARD_BLOB="c5b87f159de5224d231b111da2541b8b23ac6284"
PLANNER_BLOB="78948cdacd2a760db5b888fce242d598fc6f14b6"
MARKET_VERSION="SYNTHETIC-STAGE86-V1"
TEST_KEY=re.compile(r"test_[a-z0-9_]{1,30}\Z")
TEST_BINDING=re.compile(r"test_[a-z0-9_]{1,40}\Z")
FALSE={
    "readOnly":True,
    "simulationOnly":True,
    "manualFinalAcceptRequired":True,
    "actualGameOfferExecuted":False,
    "actualTradingPolicyApproved":False,
    "verifiedMarketQuote":False,
    "verifiedGameItemIdentity":False,
    "serverAttestation":False,
    "serverCompletionProven":False,
    "mayRecordCompletedTrade":False,
    "mayReportProfit":False,
    "maySendDiscordWebhook":False,
    "mayUseForStrategyLearning":False,
    "authorizesTrade":False,
    "authorizesAccept":False,
    "tradeOutcome":"UNKNOWN",
}

def git_blob(data:bytes)->str:
    return hashlib.sha1(b"blob "+str(len(data)).encode()+b"\0"+data).hexdigest()

def _read_reviewed(path:Path,expected:str,name:str):
    if git_blob(path.read_bytes())!=expected:
        raise ValueError(f"ORIGINAL_{name.upper()}_GIT_BLOB_CHANGED")
    spec=importlib.util.spec_from_file_location(f"stage86_reviewed_{name}",path)
    if spec is None or spec.loader is None:
        raise ValueError("ORIGINAL_MODULE_UNAVAILABLE")
    mod=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

def _output(status:str,reason:str,**kwargs:Any)->dict[str,Any]:
    return {"schema":SCHEMA,"status":status,"reason":reason,**FALSE,**kwargs}

def _safe_fixture(ours:object,theirs:object,market:object,binding:object,now:object)->bool:
    if type(now) is not int or not 1_700_000_000<=now<=2_100_000_000:
        return False
    if type(ours) is not list or type(theirs) is not list or type(market) is not dict:
        return False
    if type(binding) is not dict or set(binding)!={
        "sessionId","jobId","partnerKey","offerRevision","fixtureKind"
    }:
        return False
    if binding["fixtureKind"]!="SYNTHETIC_OFFLINE_TEST":
        return False
    if any(type(binding.get(k)) is not str or TEST_BINDING.fullmatch(binding[k]) is None
           for k in ("sessionId","jobId","partnerKey")):
        return False
    if type(binding["offerRevision"]) is not int or not 1<=binding["offerRevision"]<=100000:
        return False
    if market.get("source")!="SUPREME_DISPLAY_RESEARCH_ONLY" or market.get("version")!=MARKET_VERSION:
        return False
    items=market.get("items")
    if type(items) is not dict or not 1<=len(items)<=10:
        return False
    if any(type(k) is not str or TEST_KEY.fullmatch(k) is None
           for k in items):
        return False
    for rows in (ours,theirs):
        if len(rows)<1 or len(rows)>5:
            return False
        for row in rows:
            if type(row) is not dict or set(row)!={"key","quantity"}:
                return False
            if type(row["key"]) is not str or TEST_KEY.fullmatch(row["key"]) is None:
                return False
            if type(row["quantity"]) is not int or not 1<=row["quantity"]<=2:
                return False
    return True

def _slots(items:list[dict[str,Any]])->list[dict[str,Any]]:
    return [{"index":i,"key":d["key"],"quantity":d["quantity"]}
            for i,d in enumerate(items,1)]

def propose(ours:object,theirs:object,market:object,binding:object, *,
            now:int,planner_path:Path,guard_path:Path)->dict[str,Any]:
    """One deterministic candidate. Result includes only synthetic test keys."""
    if not _safe_fixture(ours,theirs,market,binding,now):
        return _output("BLOCKED","NON_SYNTHETIC_OR_INVALID_INPUT")
    try:
        planner=_read_reviewed(planner_path,PLANNER_BLOB,"planner")
        _read_reviewed(guard_path,GUARD_BLOB,"guard")
    except (ValueError,OSError,ImportError):
        return _output("BLOCKED","ORIGINAL_COMPONENT_PROVENANCE_FAILED")
    result=planner.plan(deepcopy(ours),deepcopy(theirs),deepcopy(market),
                        now=now,min_gain=5,
                        min_received_demand=4,min_received_liquidity=4,
                        max_counterparty_overpay_pct=50,max_results=5)
    if result.get("status")!="CANDIDATES_PREPARED":
        return _output("NO_PROPOSAL",result.get("reason","UNREVIEWED_PLANNER_RESULT"))
    if (result.get("authorizesTrade") is not False or
        result.get("authorizesAccept") is not False or
        result.get("serverCompletionProven") is not False or
        not result.get("candidates")):
        return _output("BLOCKED","PLANNER_AUTHORITY_OR_RESULT_UNTRUSTED")
    candidate=result["candidates"][0]
    give,receive=candidate["offer"],candidate["receive"]
    if (not 1<=sum(q["quantity"] for q in give)<=4 or
        not 1<=sum(q["quantity"] for q in receive)<=4 or
        candidate["projectedListedGain"]<5):
        return _output("BLOCKED","PLANNER_FOUR_SLOT_OR_GAIN_POLICY_FAILED")
    prepared={
       "sessionId":binding["sessionId"],"jobId":binding["jobId"],
       "partnerKey":binding["partnerKey"],"catalogVersion":MARKET_VERSION,
       "offerRevision":binding["offerRevision"],"observedAtUnix":now,
       "ours":_slots(give),"theirs":_slots(receive),
    }
    # Contract is TEST ONLY. This is never an actual MM2 offer or authorization.
    return _output("SYNTHETIC_PROPOSAL_READY","MANUAL_FINAL_ACCEPT_ONLY",
                   proposal=prepared,candidateKind=candidate["type"],
                   listedGainResearchOnly=candidate["projectedListedGain"],
                   plannerCandidatesConsidered=result["candidatePairsConsidered"])

def synthetic_observation(proposal:dict[str,Any],now:int)->dict[str,Any]:
    """Build an idealized observation for OFFLINE tests, never a game read."""
    observed=deepcopy(proposal)
    observed.update({
        "tradeOpen":True,"exactPartnerBound":True,
        "ourAccepted":False,"theirAccepted":False,
        "offerMutationPending":False,"observedAtUnix":now,
    })
    return observed

def verify(prepared:object,observation:object,market:object, *,
           now:int,guard_path:Path)->dict[str,Any]:
    """Execute the REAL pinned guard against frozen offered/current snapshots."""
    if (type(prepared) is not dict or prepared.get("status")!="SYNTHETIC_PROPOSAL_READY"
        or prepared.get("authorizesTrade") is not False
        or prepared.get("authorizesAccept") is not False
        or type(market) is not dict or market.get("version")!=MARKET_VERSION):
        return _output("BLOCKED","PROPOSAL_OR_MARKET_UNREVIEWED")
    try:
        guard=_read_reviewed(guard_path,GUARD_BLOB,"guard")
    except (ValueError,OSError,ImportError):
        return _output("BLOCKED","ORIGINAL_GUARD_PROVENANCE_FAILED")
    evidence=guard.evaluate(deepcopy(prepared["proposal"]),deepcopy(observation),
                            deepcopy(market),now=now,
                            minimum_gain=5,minimum_received_demand=4)
    if (evidence.get("authorizesTrade") is not False
        or evidence.get("authorizesAccept") is not False
        or evidence.get("serverCompletionProven") is not False):
        return _output("BLOCKED","GUARD_AUTHORITY_UNTRUSTED")
    if evidence.get("status")!="RESEARCH_CANDIDATE_ONLY":
        return _output("REJECTED_REPLAN_REQUIRED",
                       evidence.get("reason","GUARD_REFUSED"),
                       guardStatus=evidence.get("status"))
    if evidence.get("projectedListedGain")!=prepared["listedGainResearchOnly"]:
        return _output("REJECTED_REPLAN_REQUIRED","PLANNER_GUARD_GAIN_DISAGREEMENT")
    return _output("IDEAL_SYNTHETIC_SNAPSHOT_MATCH_ONLY",
                   "NO_TRADE_OR_ACCEPT_AUTHORITY",
                   listedGainResearchOnly=evidence["projectedListedGain"],
                   candidateKind=prepared["candidateKind"])
