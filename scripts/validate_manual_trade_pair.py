"""Stage59 — deliberately non-authoritative cross-client manual-trade receipt join.

Correlates two anonymized Stage32 *client* measurements, not an official MM2
transaction ID or server signature. Even matching two sides NEVER authorizes
automatic Accept, realized profit, a completed-trade webhook, or Gingerscope
strategy learning. The game is not called. Read-only offline evaluator.
"""
from __future__ import annotations

import json
import re
from pathlib import Path

SOURCE_SCHEMA = "gingerscope-stage32-readonly-result-correlation-v1"
PAIR_SCHEMA = "gingerscope-stage59-two-client-aggregate-witness-v1"
RESULT_SCHEMA = "gingerscope-stage59-reciprocal-client-evidence-v1"
PAIR_ID_PATTERN = re.compile(r"^STAGE59-[A-Z0-9-]{4,48}$")
NONCE_PATTERN = re.compile(r"^[0-9a-fA-F-]{16,64}$")

def _unsafe(reason: str, sender=None, receiver=None) -> dict:
    return {
        "schema":RESULT_SCHEMA, "status":"INCOMPLETE",
        "reason":reason, "clientReciprocalEligibleDeltaObserved":False,
        "manualSameTradeClaimObserved":False,
        "serverTransactionIdAuthenticated":False,
        "exactWeaponInstanceIdentityProven":False,
        "sameServerJobAuthenticated":False,
        "causalTradeAttributionProven":False,
        "serverAttestation":False,
        "serverCompletionProven":False,
        "authorizesTrade":False,
        "authorizesAccept":False,
        "mayRecordCompletedTrade":False,
        "mayReportProfit":False,
        "mayUseForStrategyLearning":False,
        "tradeOutcome":"UNKNOWN", "readOnly":True,
        "senderObserved":sender is not None,
        "receiverObserved":receiver is not None,
    }

def _receipt_check(r: object, expected_role: str) -> str | None:
    if not isinstance(r,dict):
        return "RECEIPT_MISSING"
    if r.get("schema") != PAIR_SCHEMA or r.get("operatorDeclaredRole") != expected_role:
        return "WRONG_ROLE_OR_PAIR_SCHEMA"
    if r.get("readOnly") is not True or r.get("authorizesAccept") is not False:
        return "UNSAFE_PAIR_WRAPPER"
    for flag in ("serverCompletionProven","serverAttestation",
                 "mayRecordCompletedTrade","mayReportProfit","authorizesTrade"):
        if r.get(flag) is not False:
            return "UNSAFE_PAIR_WRAPPER"
    receipt_id=r.get("receiptNonce")
    if not isinstance(receipt_id,str) or not NONCE_PATTERN.fullmatch(receipt_id):
        return "INVALID_LOCAL_RECEIPT_NONCE"
    timestamp=r.get("observedAtUnix")
    if type(timestamp) is not int or not 1700000000<=timestamp<=2100000000:
        return "INVALID_LOCAL_CLOCK"
    if not isinstance(r.get("stage32"),dict):
        return "MISSING_STAGE32_RECORD"
    d=r["stage32"]
    if d.get("schema") != SOURCE_SCHEMA:
        return "WRONG_STAGE32_SCHEMA"
    if d.get("readOnly") is not True or d.get("tradeOutcome")!="UNKNOWN":
        return "UNSAFE_OR_MUTATED_SOURCE_RECEIPT"
    for flag in ("serverCompletionProven","serverAttestation",
                 "causalAttributionProven","mayRecordCompletedTrade",
                 "mayReportProfit","authorizesTrade","authorizesAccept"):
        if d.get(flag) is not False:
            return "UNSAFE_OR_MUTATED_SOURCE_RECEIPT"
    if d.get("status")!="ELIGIBLE_DELTA_WITHOUT_RESULT_NAMED_RECEIPT":
        return "SOURCE_RESULT_REQUIRES_SEPARATE_REVIEW"
    if (d.get("beforeObserved") is not True or
        d.get("windowClosureObserved") is not True or
        d.get("postReadbacksObserved")!=2 or
        d.get("stopReason")!="TWO_POST_CLOSE_READS_FINISHED" or
        d.get("closureStatus")!="closed_unknown" or
        d.get("rawWeaponInventoryChanged") is not True or
        d.get("inventoryStatus")!="ELIGIBLE_DELTA_UNATTRIBUTED" or
        d.get("changedEligibleTypes")!=1):
        return "INCOMPLETE_OR_UNSTABLE_READBACKS"
    for key in ("gainedEligibleCopies","lostEligibleCopies"):
        v=d.get(key)
        if type(v) is not int or v<0 or v>4:
            return "INVALID_BOUNDED_ELIGIBLE_COUNTS"
    if (d.get("signalReceipts")!=0 or d.get("completeTradeSignalSeen") is not False
        or d.get("endTradeSignalSeen") is not False
        or d.get("declineTradeSignalSeen") is not False
        or d.get("partnerDepartureObserved") is not False):
        return "UNEXPECTED_RESULT_SIGNAL_REQUIRES_REVIEW"
    return None

def evaluate(sender: object, receiver: object, *,
             operator_claims_same_manual_trade: bool = False,
             operator_reports_visible_completion: bool = False) -> dict:
    """Join client aggregates only; no success or server attestation is possible."""
    answer=_unsafe("INSUFFICIENT_TWO_SIDED_EVIDENCE",sender,receiver)
    first=_receipt_check(sender,"SENDER")
    second=_receipt_check(receiver,"RECEIVER")
    if first or second:
        answer["reason"]="SENDER:"+str(first) if first else "RECEIVER:"+str(second)
        return answer
    if (sender["pairId"]!=receiver["pairId"] or
        not isinstance(sender["pairId"],str) or
        not PAIR_ID_PATTERN.fullmatch(sender["pairId"])):
        answer["reason"]="MISMATCHED_TEST_PAIR"
        return answer
    if sender["receiptNonce"]==receiver["receiptNonce"]:
        answer["reason"]="REPLAYED_SINGLE_CLIENT_RECEIPT"
        return answer
    gap=abs(sender["observedAtUnix"]-receiver["observedAtUnix"])
    if gap>90:
        answer["reason"]="CLIENT_CLOCKS_OR_TRADES_NOT_COLOCATED"
        return answer
    a=sender["stage32"];b=receiver["stage32"]
    if not (a["gainedEligibleCopies"]==0 and a["lostEligibleCopies"]==1 and
            b["gainedEligibleCopies"]==1 and b["lostEligibleCopies"]==0):
        answer["reason"]="ELIGIBLE_INVENTORY_DELTAS_NOT_RECIPROCAL"
        return answer
    if type(operator_claims_same_manual_trade) is not bool or type(
        operator_reports_visible_completion
    ) is not bool:
        answer["reason"]="INVALID_OPERATOR_CONFIRMATION_TYPE"
        return answer
    answer["status"]="CLIENT_RECIPROCAL_ELIGIBLE_DELTAS_UNATTRIBUTED"
    answer["reason"]="distinct-client-aggregate-deltas-do-not-bind-item-or-server-transaction"
    answer["clientReciprocalEligibleDeltaObserved"]=True
    answer["manualSameTradeClaimObserved"]=operator_claims_same_manual_trade
    if not operator_claims_same_manual_trade:
        answer["reason"]="independent-deltas-observed-but-one-shared-transaction-not-operator-confirmed"
    elif not operator_reports_visible_completion:
        answer["reason"]="operator-has-not-verified-visible-manual-completion"
    else:
        answer["reason"]="operator-reported-completion-plus-reciprocal-client-deltas-unattributed"
    return answer

def main() -> None:
    # Offline analysis of two manually supplied, already anonymized evidence files.
    # No automatic game interaction or own/partner account data are requested.
    import sys
    if len(sys.argv)!=3:
        raise SystemExit("Usage: validate_manual_trade_pair.py <sender.json> <receiver.json>")
    src1=json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    src2=json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
    print(json.dumps(evaluate(src1,src2),sort_keys=True))

if __name__=="__main__":
    main()
