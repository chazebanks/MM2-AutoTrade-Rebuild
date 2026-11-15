"""Fail-closed Gingerscope research receipt gate. Metadata only; no game actions."""
from __future__ import annotations
import json, re, sys
from pathlib import Path

SHA = re.compile(r"^[0-9a-f]{40}$")
PR_URL = re.compile(r"^https://github[.]com/chazebanks/MM2-AutoTrade-Rebuild/pull/[1-9][0-9]*$")
REQUIRED = ("taskId", "sourceHead", "recoveredEntrypoint", "missionRead",
            "matrixRead", "historyCoverage", "relatedFailures", "priorEvidence",
            "falsificationTests", "scope", "authorization", "risk", "newFindings")
SAFE_SCOPE = {"DOCS_ONLY", "READ_ONLY_RESEARCH", "TEST_ONLY"}

def gate(payload: dict) -> dict:
    errors = []
    def fail(reason): errors.append(reason)
    if type(payload) is not dict:
        return {"status":"BLOCKED", "reasons":["INVALID_RECEIPT"]}
    for k in REQUIRED:
        if k not in payload: fail("MISSING_"+k)
    if errors: return {"status":"BLOCKED","reasons":errors}
    if not isinstance(payload["taskId"], str) or not re.fullmatch(r"GS-[A-Z0-9-]{4,60}",payload["taskId"]): fail("TASK_ID_INVALID")
    if not isinstance(payload["sourceHead"],str) or not SHA.fullmatch(payload["sourceHead"]): fail("HEAD_INVALID")
    if payload["recoveredEntrypoint"] != "00 - GINGERSCOPE RECOVERY ENTRYPOINT - READ FIRST": fail("ENTRYPOINT_UNVERIFIED")
    if payload["missionRead"] is not True or payload["matrixRead"] is not True: fail("MISSION_OR_MATRIX_NOT_READ")
    if payload["historyCoverage"] != "PARTIAL_NOT_ALL_STAGES_AUDITED": fail("FALSE_HISTORY_COVERAGE")
    if payload["scope"] not in SAFE_SCOPE: fail("UNAPPROVED_SCOPE")
    if payload["authorization"] != "NO_LIVE_GAME_ACTIONS": fail("AUTHORITY_NOT_PROVEN")
    if payload["risk"] != "NO_GAME_ACTIONS_NO_PRIVATE_DATA": fail("RISK_NOT_QUARANTINED")
    for key in ("relatedFailures","priorEvidence","falsificationTests","newFindings"):
        v=payload[key]
        if not isinstance(v,list) or not v or not all(isinstance(s,str) and len(s.strip()) >= 8 for s in v): fail("MISSING_EVIDENCE_"+key)
    if isinstance(payload["priorEvidence"],list) and not any(PR_URL.fullmatch(s) for s in payload["priorEvidence"]): fail("PR_EVIDENCE_REQUIRED")
    if payload.get("serverSettlementProven") is True or payload.get("authorizesFinalAccept") is True: fail("UNSUPPORTED_LIVE_AUTHORITY")
    return {"status":"BLOCKED" if errors else "RESEARCH_RECEIPT_VALID", "reasons":errors,
            "note":"Self-attested receipt; NOT proof sources were read. Independent review and branch protection required."}

def main():
    if len(sys.argv)!=2: raise SystemExit("usage: recovery_gate.py receipt.json")
    try:
        result=gate(json.loads(Path(sys.argv[1]).read_text(encoding="utf8")))
    except (OSError,ValueError,UnicodeError):
        result={"status":"BLOCKED","reasons":["RECEIPT_UNREADABLE_OR_INVALID"]}
    print(json.dumps(result,sort_keys=True))
    raise SystemExit(0 if result["status"]=="RESEARCH_RECEIPT_VALID" else 1)

if __name__=="__main__": main()
