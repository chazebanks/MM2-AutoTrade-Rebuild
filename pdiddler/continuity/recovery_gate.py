"""Validate research receipts against current refs in the public Gingerscope repo."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
from pathlib import Path


REPOSITORY = "https://github.com/chazebanks/MM2-AutoTrade-Rebuild"
BASE_REF = "refs/heads/main"
SHA = re.compile(r"[0-9a-f]{40}")
PR_URL = re.compile(re.escape(REPOSITORY) + r"/pull/([1-9][0-9]*)")
REQUIRED = (
    "taskId", "baseHead", "sourceHead", "sourcePullRequest", "recoveredEntrypoint",
    "missionRead", "matrixRead", "historyCoverage", "relatedFailures", "priorEvidence",
    "falsificationTests", "scope", "authorization", "risk", "newFindings",
)
SAFE_SCOPES = {"DOCS_ONLY", "READ_ONLY_RESEARCH", "TEST_ONLY"}
MAX_RECEIPT_BYTES = 64 * 1024


def is_commit(value):
    return isinstance(value, str) and SHA.fullmatch(value) is not None and value != "0" * 40


def resolve_remote_refs(refs):
    result = subprocess.run(
        ["git", "ls-remote", "--refs", REPOSITORY + ".git", *refs],
        check=True,
        text=True,
        capture_output=True,
        timeout=25,
        env={**os.environ, "GIT_TERMINAL_PROMPT": "0"},
    )
    return {ref: sha for sha, ref in (line.split("\t", 1) for line in result.stdout.splitlines())}


def blocked(*reasons):
    return {"status": "BLOCKED", "reasons": list(reasons)}


def gate(payload, *, resolve_refs=resolve_remote_refs, expected_base=None):
    if not isinstance(payload, dict):
        return blocked("INVALID_RECEIPT")

    missing = [f"MISSING_{field}" for field in REQUIRED if field not in payload]
    if missing:
        return blocked(*missing)

    errors = []
    task_id = payload["taskId"]
    scope = payload["scope"]
    source_pr = payload["sourcePullRequest"]
    valid_source_pr = type(source_pr) is int and source_pr > 0
    if not isinstance(task_id, str) or not re.fullmatch(r"GS-[A-Z0-9-]{4,60}", task_id):
        errors.append("TASK_ID_INVALID")
    if not is_commit(payload["baseHead"]):
        errors.append("BASE_HEAD_INVALID")
    if expected_base is not None and payload["baseHead"] != expected_base:
        errors.append("TRUSTED_BASE_MISMATCH")
    if not is_commit(payload["sourceHead"]):
        errors.append("HEAD_INVALID")
    if not valid_source_pr:
        errors.append("SOURCE_PR_INVALID")
    if payload["recoveredEntrypoint"] != "00 - GINGERSCOPE RECOVERY ENTRYPOINT - READ FIRST":
        errors.append("ENTRYPOINT_UNVERIFIED")
    if payload["missionRead"] is not True or payload["matrixRead"] is not True:
        errors.append("MISSION_OR_MATRIX_NOT_READ")
    if payload["historyCoverage"] != "PARTIAL_NOT_ALL_STAGES_AUDITED":
        errors.append("FALSE_HISTORY_COVERAGE")
    if not isinstance(scope, str) or scope not in SAFE_SCOPES:
        errors.append("UNAPPROVED_SCOPE")
    if payload["authorization"] != "NO_LIVE_GAME_ACTIONS":
        errors.append("AUTHORITY_NOT_PROVEN")
    if payload["risk"] != "NO_GAME_ACTIONS_NO_PRIVATE_DATA":
        errors.append("RISK_NOT_QUARANTINED")
    for field in ("relatedFailures", "falsificationTests", "newFindings"):
        evidence = payload[field]
        if not isinstance(evidence, list) or not evidence or not all(
            isinstance(line, str) and len(line.strip()) >= 8 for line in evidence
        ):
            errors.append(f"MISSING_EVIDENCE_{field}")
    if any(payload.get(field, False) is not False for field in (
        "serverSettlementProven", "authorizesFinalAccept"
    )):
        errors.append("UNSUPPORTED_LIVE_AUTHORITY")

    links = payload["priorEvidence"]
    pr_heads = {}
    if not isinstance(links, list) or not links:
        errors.append("PR_EVIDENCE_REQUIRED")
    else:
        for link in links:
            url = link.get("url") if isinstance(link, dict) else None
            match = PR_URL.fullmatch(url) if isinstance(url, str) else None
            if match is None or not is_commit(link.get("head")):
                errors.append("PR_REFERENCE_INVALID")
                break
            number = match.group(1)
            if number in pr_heads:
                errors.append("DUPLICATE_PR_EVIDENCE")
                break
            pr_heads[number] = link["head"]
    if valid_source_pr:
        stated_source = pr_heads.get(str(source_pr))
        if stated_source is None:
            errors.append("SOURCE_PR_REQUIRED_IN_EVIDENCE")
        elif stated_source != payload["sourceHead"]:
            errors.append("CONFLICTING_SOURCE_HEAD")
    if errors:
        return blocked(*errors)

    evidence_refs = {f"refs/pull/{number}/head": pr_heads[number] for number in sorted(pr_heads)}
    try:
        current = resolve_refs([BASE_REF, *evidence_refs])
    except (OSError, ValueError, subprocess.SubprocessError):
        return blocked("GITHUB_REFS_UNAVAILABLE")

    if not is_commit(current.get(BASE_REF)):
        errors.append("GITHUB_BASE_REF_UNAVAILABLE")
    elif current[BASE_REF] != payload["baseHead"]:
        errors.append("BASE_HEAD_STALE")
    for ref, expected in evidence_refs.items():
        number = ref.split("/")[2]
        if not is_commit(current.get(ref)):
            errors.append(f"PR_EVIDENCE_UNRESOLVED_{number}")
        elif current[ref] != expected:
            errors.append("SOURCE_HEAD_STALE" if number == str(source_pr) else f"PR_EVIDENCE_STALE_{number}")
    if errors:
        return blocked(*errors)

    return {
        "status": "RESEARCH_RECEIPT_VALID",
        "reasons": [],
        "verifiedRefs": {ref: current[ref] for ref in [BASE_REF, *evidence_refs]},
        "note": "GitHub refs verified. Self-attested reading and relevance require review.",
    }


def unique_fields(pairs):
    fields = {}
    for key, value in pairs:
        if key in fields:
            raise ValueError(f"Duplicate receipt field {key}")
        fields[key] = value
    return fields


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--expected-base", help="SHA of the checked-out trusted validator")
    parser.add_argument("receipt", type=Path)
    args = parser.parse_args()

    try:
        with args.receipt.open("rb") as receipt:
            data = receipt.read(MAX_RECEIPT_BYTES + 1)
        if len(data) > MAX_RECEIPT_BYTES:
            raise ValueError("Receipt exceeds maximum size")
        result = gate(json.loads(data, object_pairs_hook=unique_fields), expected_base=args.expected_base)
    except (OSError, ValueError, RecursionError):
        result = blocked("RECEIPT_UNREADABLE_OR_INVALID")
    print(json.dumps(result, sort_keys=True))
    raise SystemExit(0 if result["status"] == "RESEARCH_RECEIPT_VALID" else 1)


if __name__ == "__main__":
    main()
