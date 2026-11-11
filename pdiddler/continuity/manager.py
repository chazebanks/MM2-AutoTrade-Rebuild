"""Gingerscope continuity control plane. Offline only; no Roblox/trade authority.

Only source-controlled, sanitized development metadata belongs in the public repo.
Do NOT put private client/event/Discord logs in this repository.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
from pathlib import Path

BASE = Path(__file__).resolve().parents[2]
RECORD_DIR = Path("pdiddler/continuity/records")
EVIDENCE_URL = re.compile(r"https://github[.]com/chazebanks/MM2-AutoTrade-Rebuild/(?:pull|commit|actions/runs)/[A-Za-z0-9_./#-]+\Z")
REQUIRED = frozenset({
    "GOAL_ACQUIRE_HOLD_GINGERSCOPE", "PROTECT_OUTGOING_GINGERSCOPE",
    "NO_LEGACY_MIN_PLUS15", "NO_FORCED_HIGHEST_OPENER",
    "NO_CHAT_AUTONEGOTIATION", "FULL_AUTO_IS_FUTURE_GOAL_NOT_APPROVAL",
    "NO_CLIENT_AS_SERVER_SETTLEMENT", "NO_AUTO_ACCEPT_UNPROVEN",
    "ONSCREEN_MANUAL_TEST_INSTRUCTIONS", "PRESERVE_WORKING_P3_P4",
    "NO_REPEAT_CLOSED_DEVICE_TEST", "SOURCE_FRESHNESS_REQUIRED",
    "ONE_DISTINCT_ISSUE_TESTED", "PRIVATE_EVIDENCE_NOT_PUBLIC",
})
DENIED_AUTHORITY = frozenset({
    "authorizesTrade", "authorizesOffer", "authorizesAccept",
    "serverCompletionProven", "mayReportProfit", "maySendDiscordWebhook",
    "mayUseForStrategyLearning", "verifiedMarketQuote",
})
JOB_ID = re.compile(r"job-[a-z0-9][a-z0-9_-]{2,60}\Z")
COMMIT = re.compile(r"[a-f0-9]{40}\Z")
STATES = {"PLANNED", "RUNNING", "BLOCKED", "FAILED", "COMPLETE", "INTERRUPTED"}
SAFE_EVENT_KEYS = frozenset({"stage", "status", "reason", "clientCallbacks", "guiTransitions", "scriptOffers", "scriptAccepts", "scriptDeclines", "tradeOutcome"})
SAFE_STATUSES = {"PASS", "STOPPED", "INCONCLUSIVE", "FAILED", "BLOCKED"}


class GateError(ValueError):
    pass


def require(condition: bool, reason: str) -> None:
    if not condition:
        raise GateError(reason)


def _read(root: Path, name: str) -> dict:
    path = root / "pdiddler" / "continuity" / name
    require(path.is_file() and not path.is_symlink(), "MISSING_OR_SYMLINK_" + name)
    data = json.loads(path.read_text(encoding="utf-8"))
    require(type(data) is dict, "INVALID_OBJECT_" + name)
    return data


def blob_sha(data: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def verify(root: Path = BASE) -> dict:
    root = root.resolve()
    manifest, policy, state, index = (_read(root, n) for n in (
        "manifest.json", "policy.json", "current_state.json", "history_index.json"))
    require(manifest.get("schema") == "gingerscope-continuity-manifest-v1", "MANIFEST_SCHEMA")
    require(manifest.get("repository") == "chazebanks/MM2-AutoTrade-Rebuild", "REPOSITORY_MISMATCH")
    controlled = manifest.get("controlledBlobs")
    tracked = {
        "pdiddler/continuity/policy.json", "pdiddler/continuity/current_state.json",
        "pdiddler/continuity/history_index.json", "pdiddler/continuity/public_pr_catalog.json",
    }
    require(type(controlled) is dict and set(controlled) == tracked, "CONTROLLED_BLOB_LIST_INVALID")
    for relative, expected in controlled.items():
        require(type(expected) is str and COMMIT.fullmatch(expected) is not None, "CONTROLLED_SHA_INVALID")
        target = root / relative
        require(target.is_file() and not target.is_symlink(), "CONTROLLED_FILE_MISSING")
        require(blob_sha(target.read_bytes()) == expected, "CONTROLLED_FILE_CHANGED_REVIEW_REQUIRED_" + relative)
    sources = manifest.get("sourceBlobs")
    require(type(sources) is dict and len(sources) >= 5, "MISSING_SOURCE_ANCHORS")
    for relative, expected in sources.items():
        require(type(relative) is str and relative.startswith("pdiddler/") and ".." not in Path(relative).parts, "SOURCE_PATH_INVALID")
        require(type(expected) is str and COMMIT.fullmatch(expected) is not None, "SOURCE_SHA_INVALID")
        target = root / relative
        require(target.is_file() and not target.is_symlink(), "SOURCE_MISSING_" + relative)
        require(blob_sha(target.read_bytes()) == expected, "SOURCE_CHANGED_REINDEX_REQUIRED_" + relative)
    require(policy.get("schema") == "gingerscope-critical-policy-v1", "POLICY_SCHEMA")
    rules = policy.get("rules")
    require(type(rules) is list and len(rules) >= len(REQUIRED), "CRITICAL_RULES_MISSING")
    ids = [item.get("id") for item in rules if type(item) is dict]
    require(len(ids) == len(rules) and len(set(ids)) == len(ids), "CRITICAL_RULE_IDS_DUPLICATE_OR_INVALID")
    require(REQUIRED.issubset(ids), "REQUIRED_CRITICAL_RULE_ABSENT")
    for item in rules:
        require(type(item.get("statement")) is str and len(item["statement"]) >= 20, "CRITICAL_RULE_TEXT_MISSING")
        require(item.get("locked") is True and item.get("source") in sources, "CRITICAL_RULE_NOT_SOURCE_BOUND")
    require(state.get("schema") == "gingerscope-current-state-v1", "STATE_SCHEMA")
    require(state.get("sourceCommit") == manifest.get("baselineCommit") and COMMIT.fullmatch(state.get("sourceCommit", "")), "STATE_SOURCE_MISMATCH")
    require(type(state.get("latestStage")) is int and state["latestStage"] >= 121, "STAGE_STALE_OR_INVALID")
    require(type(state.get("latestMergedPR")) is int and state["latestMergedPR"] >= 228, "PR_BASELINE_UNRECONCILED")
    require(state.get("tradeOutcome") == "UNKNOWN", "UNVERIFIED_TRADE_OUTCOME_PROMOTED")
    require(type(state.get("blockers")) is list and len(state["blockers"]) >= 2, "BLOCKERS_MISSING")
    require(type(state.get("nextAction")) is str and len(state["nextAction"]) > 30, "NEXT_ACTION_MISSING")
    authority = state.get("authority")
    require(type(authority) is dict and DENIED_AUTHORITY.issubset(authority), "AUTHORITY_FIELDS_MISSING")
    require(all(authority[k] is False for k in DENIED_AUTHORITY), "UNVERIFIED_AUTHORITY_PROMOTED")
    require(index.get("schema") == "gingerscope-history-index-v1", "INDEX_SCHEMA")
    require(index.get("coverage") == "PARTIAL_NOT_ALL_STAGES_AUDITED", "FALSE_HISTORY_COMPLETENESS")
    entries = index.get("entries")
    require(type(entries) is list and len(entries) >= 3, "HISTORY_INDEX_EMPTY")
    stages = [x.get("stage") for x in entries if type(x) is dict]
    require(len(stages) == len(entries) and len(set(stages)) == len(stages), "DUPLICATE_STAGE_RECORD")
    require({119, 120, 121}.issubset(stages), "LATEST_STAGE_ENTRIES_MISSING")
    for entry in entries:
        require(type(entry.get("references")) is list and bool(entry["references"]), "STAGE_EVIDENCE_REF_MISSING")
        require(entry.get("evidenceTier") in {"CLIENT_ONLY", "SYNTHETIC_OFFLINE", "RESEARCH_ONLY"}, "STAGE_EVIDENCE_TIER_INVALID")
    catalog = _read(root, "public_pr_catalog.json")
    require(catalog.get("schema") == "gingerscope-public-pr-catalog-v1", "PR_CATALOG_SCHEMA")
    prs, ci = catalog.get("prs"), catalog.get("stageIndex")
    require(type(prs) is list and len(prs) >= 200 and len(prs) == catalog.get("totalPRs"), "PR_CATALOG_INCOMPLETE")
    require(type(ci) is list and len(ci) == 121, "STAGE_TITLE_INDEX_INCOMPLETE")
    numbers = [p.get("pr") for p in prs if type(p) is dict]
    require(len(numbers) == len(prs) and len(set(numbers)) == len(prs), "PR_CATALOG_DUPLICATE")
    for i, item in enumerate(ci, 1):
        require(type(item) is dict and item.get("stage") == i and
                item.get("indexStatus") == "TITLE_REFERENCE_ONLY_NOT_SOURCE_AUDIT", "STAGE_TITLE_INDEX_FALSE_CLAIM")
        refs = item.get("prsByTitle")
        require(type(refs) is list and all(n in numbers for n in refs), "STAGE_INDEX_PR_REFERENCE_INVALID")
    return {"status": "PASS", "criticalRuleCount": len(rules), "verifiedSourceBlobs": len(sources),
            "controlledFiles": len(controlled), "publicPRRecords": len(prs),
            "stageTitleIndexCount": sum(bool(x["prsByTitle"]) for x in ci),
            "indexedStageCount": len(entries), "coverage": index["coverage"],
            "latestStage": state["latestStage"], "latestMergedPR": state["latestMergedPR"]}


def recover(root: Path = BASE) -> dict:
    gate = verify(root)
    state = _read(root, "current_state.json")
    policy = _read(root, "policy.json")
    index = _read(root, "history_index.json")
    return {"gate": gate, "scope": "INDEX_AND_PINNED_ANCHORS_NOT_FULL_HISTORY_AUDIT",
            "sourceCommit": state["sourceCommit"], "nextAction": state["nextAction"],
            "blockers": state["blockers"],
            "mandatoryRules": [x["id"] for x in policy["rules"]],
            "evidence": index["entries"],
            "readBeforeCodeChange": state["readBeforeCodeChange"],
            "missingHistoricalAudit": index["missingHistoricalAudit"],
            "publicPRCatalog": "pdiddler/continuity/public_pr_catalog.json"}


def _atomic_new(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = (json.dumps(data, indent=2, sort_keys=True, ensure_ascii=True) + "\n").encode()
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(fd, "wb") as fh:
            fh.write(payload)
            fh.flush()
            os.fsync(fh.fileno())
    except BaseException:
        path.unlink(missing_ok=True)
        raise


def begin_job(root: Path, job_id: str, task: str, source_commit: str) -> dict:
    verify(root)
    require(JOB_ID.fullmatch(job_id) is not None, "JOB_ID_INVALID")
    require(type(task) is str and 12 <= len(task) <= 160 and "\n" not in task, "TASK_INVALID")
    require(type(source_commit) is str and COMMIT.fullmatch(source_commit), "SOURCE_COMMIT_INVALID")
    path = root / RECORD_DIR / (job_id + ".json")
    data = {"schema": "gingerscope-execution-job-v1", "jobId": job_id, "task": task,
            "sourceCommit": source_commit, "status": "PLANNED", "evidence": [],
            "executionAuthorized": False, "liveGameActionAuthorized": False,
            "retryPolicy": "INSPECT_BEFORE_RETRY_NEVER_AUTO_REPLAY_SIDE_EFFECTS"}
    if path.exists():
        old = json.loads(path.read_text())
        require(old.get("schema") == data["schema"] and old.get("jobId") == job_id and
                old.get("task") == task and old.get("sourceCommit") == source_commit,
                "JOB_ID_COLLISION_MISMATCH")
        return {"status": "EXISTS_NO_REPLAY", "job": old}
    _atomic_new(path, data)
    return {"status": "CREATED_NOT_EXECUTED", "job": data}


def job_status(root: Path, job_id: str) -> dict:
    require(JOB_ID.fullmatch(job_id) is not None, "JOB_ID_INVALID")
    path = root / RECORD_DIR / (job_id + ".json")
    require(path.is_file() and not path.is_symlink(), "UNKNOWN_JOB_NO_AUTO_REPLAY")
    job = json.loads(path.read_text())
    require(job.get("jobId") == job_id and job.get("status") in STATES, "CORRUPT_JOB")
    events = sorted((root / RECORD_DIR).glob(job_id + ".step*.json"))
    previous = job
    for seq, item in enumerate(events, 1):
        require(item.name == f"{job_id}.step{seq:04d}.json" and not item.is_symlink(), "JOB_EVENT_SEQUENCE_GAP")
        step = json.loads(item.read_text())
        require(step.get("schema") == "gingerscope-job-transition-v1" and step.get("jobId") == job_id, "JOB_EVENT_SCHEMA")
        require(step.get("priorDigest") == hashlib.sha256(json.dumps(previous, sort_keys=True).encode()).hexdigest(), "JOB_EVENT_CHAIN_BROKEN")
        prior, now = previous["status"], step.get("status")
        allowed = {"PLANNED": {"RUNNING", "BLOCKED", "INTERRUPTED"},
                   "RUNNING": {"COMPLETE", "FAILED", "BLOCKED", "INTERRUPTED"},
                   "INTERRUPTED": {"RUNNING", "BLOCKED"}}
        require(now in allowed.get(prior, set()), "ILLEGAL_JOB_STATE_TRANSITION")
        require(type(step.get("evidence")) is str and EVIDENCE_URL.fullmatch(step["evidence"]), "UNVERIFIABLE_JOB_EVIDENCE_URL")
        previous = {**previous, "status": now, "lastEvidence": step["evidence"], "stepsRecorded": seq}
    return previous


def transition_job(root: Path, job_id: str, status: str, evidence: str) -> dict:
    verify(root)
    require(type(status) is str and status in STATES and status != "PLANNED", "JOB_STATUS_INVALID")
    require(type(evidence) is str and EVIDENCE_URL.fullmatch(evidence) is not None, "EVIDENCE_URL_INVALID")
    old = job_status(root, job_id)
    prior = old["status"]
    allowed = {"PLANNED": {"RUNNING", "BLOCKED", "INTERRUPTED"},
               "RUNNING": {"COMPLETE", "FAILED", "BLOCKED", "INTERRUPTED"},
               "INTERRUPTED": {"RUNNING", "BLOCKED"}}
    require(status in allowed.get(prior, set()), "NO_UNSAFE_JOB_REPLAY_OR_TERMINAL_REOPEN")
    base = root / RECORD_DIR
    seq = old.get("stepsRecorded", 0) + 1
    previous = job_status(root, job_id)
    step = {"schema": "gingerscope-job-transition-v1", "jobId": job_id, "status": status,
            "evidence": evidence, "priorDigest": hashlib.sha256(json.dumps(previous, sort_keys=True).encode()).hexdigest()}
    _atomic_new(base / f"{job_id}.step{seq:04d}.json", step)
    return job_status(root, job_id)


def _private_dir(root: Path, destination: Path) -> Path:
    """Explicit private directory, outside repo and its symlinks; no implicit uploads."""
    require(destination.exists() and destination.is_dir() and not destination.is_symlink(), "PRIVATE_DIR_REQUIRED")
    target = destination.resolve()
    require(not (target == root.resolve() or root.resolve() in target.parents), "PUBLIC_REPOSITORY_LOG_FORBIDDEN")
    require((target / ".gingerscope_private").is_file(), "PRIVATE_STORAGE_MARKER_MISSING")
    return target


def save_client_event(root: Path, private_dir: Path, event_id: str, event: dict) -> dict:
    verify(root)
    target = _private_dir(root, private_dir)
    require(re.fullmatch(r"evt-[a-z0-9_-]{4,60}", event_id) is not None, "EVENT_ID_INVALID")
    require(type(event) is dict and set(event) == SAFE_EVENT_KEYS, "UNTRUSTED_OR_PRIVATE_CLIENT_FIELDS")
    require(type(event["stage"]) is int and 1 <= event["stage"] <= 2000, "STAGE_INVALID")
    require(event["status"] in SAFE_STATUSES and type(event["reason"]) is str and
            re.fullmatch(r"[A-Z0-9_]{3,70}", event["reason"]) is not None, "EVENT_STATUS_INVALID")
    for k in ("clientCallbacks", "guiTransitions", "scriptOffers", "scriptAccepts", "scriptDeclines"):
        require(type(event[k]) is int and 0 <= event[k] <= 10000, "COUNTER_INVALID")
    require(event["tradeOutcome"] == "UNKNOWN", "UNVERIFIED_COMPLETION_CLAIM")
    data = {"schema": "gingerscope-private-client-evidence-v1", "eventId": event_id, **event,
            "source": "SANITIZED_CLIENT_OBSERVATION", "serverCompletionProven": False,
            "mayReportProfit": False, "authorizesAccept": False, "mayUseForStrategyLearning": False}
    path = target / (event_id + ".json")
    if path.exists():
        require(path.is_file() and not path.is_symlink(), "EVENT_PATH_INVALID")
        prior = json.loads(path.read_text())
        require(prior == data, "EVENT_ID_COLLISION_NO_OVERWRITE")
        return {"status": "DUPLICATE_NOT_RECORDED", "eventId": event_id}
    _atomic_new(path, data)
    return {"status": "PRIVATE_RECEIPT_SAVED", "eventId": event_id, "tradeOutcome": "UNKNOWN"}


def main() -> None:
    parser = argparse.ArgumentParser(description="Gingerscope continuity; metadata only, no trading")
    parser.add_argument("command", choices=["verify", "recover", "job-start", "job-status", "job-progress", "event-save"])
    parser.add_argument("--root", type=Path, default=BASE)
    parser.add_argument("--id")
    parser.add_argument("--task")
    parser.add_argument("--source-commit")
    parser.add_argument("--status")
    parser.add_argument("--evidence")
    parser.add_argument("--private-dir", type=Path)
    parser.add_argument("--event-file", type=Path)
    args = parser.parse_args()
    try:
        if args.command == "verify": result = verify(args.root)
        elif args.command == "recover": result = recover(args.root)
        elif args.command == "job-start": result = begin_job(args.root, args.id or "", args.task or "", args.source_commit or "")
        elif args.command == "job-status": result = job_status(args.root, args.id or "")
        elif args.command == "job-progress": result = transition_job(args.root, args.id or "", args.status or "", args.evidence or "")
        else:
            require(args.private_dir is not None and args.event_file is not None, "PRIVATE_DIR_AND_EVENT_FILE_REQUIRED")
            result = save_client_event(args.root, args.private_dir, args.id or "", json.loads(args.event_file.read_text()))
        print(json.dumps(result, indent=2, sort_keys=True))
    except (GateError, OSError, ValueError, TypeError, KeyError) as exc:
        print(json.dumps({"status": "BLOCKED", "reason": str(exc)}))
        raise SystemExit(2) from exc


if __name__ == "__main__":
    main()
