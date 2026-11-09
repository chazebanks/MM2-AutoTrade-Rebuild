"""Stage67: validate one Stage66 client raw receipt report, never grant learning.

Current observed source is an isolated client-side callback plus readbacks.
This program never joins another trade, imports private Discord archives,
or authenticates a server transaction. Outputs are privacy-minimized.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

SCHEMA="gingerscope-stage66-one-window-client-accept-delta-v1"
OUTPUT="gingerscope-stage67-client-receipt-learning-gate-v1"
FIELDS=frozenset((
 "eventSessionAssociationProven","recordCount","coreTerminal","readOnly",
 "serverTransactionIdAuthenticated","status","callbackRowFieldTypes",
 "callbackRowShape","serverAttestation","authorizesAccept","authorizesTrade",
 "listenerDisconnected","clientCompatibleFlagPattern","schema",
 "causalTradeAttributionProven","serverCompletionProven",
 "mayRecordCompletedTrade","reason","tradeOutcome","discardedReceipts",
 "mayRecordRejectedTrade","privateRawKeyEqualityObserved",
 "privateRawEqualityStatus","stablePartnerLabel","samples","ownReadbacks",
 "ignoredUnboundReceipts","guiBound","sameBoundWindowClientOnly",
 "exactCallbackWeaponKeyIdentityProven","privateRawEqualityReason",
 "clientReciprocalTransferProven","mayUseForStrategyLearning",
 "mayReportProfit","exactWeaponIdentityConfirmed",
))
EVENT_FIELDS=frozenset((
 "secondArg","firstArg","phase","elapsedSeconds","argCount",
 "secondTableShape",
))
OWN_FIELDS=frozenset((
 "rawWeaponInventoryChanged","stopReason","beforeObserved",
 "partnerCacheAtBaseline","gainedEligibleCopies","changedEligibleTypes",
 "status","windowClosureObserved","lostEligibleCopies",
 "postReadbacksObserved",
))
FALSE_FIELDS=(
 "eventSessionAssociationProven","serverTransactionIdAuthenticated",
 "serverAttestation","authorizesAccept","authorizesTrade",
 "causalTradeAttributionProven","serverCompletionProven",
 "mayRecordCompletedTrade","mayRecordRejectedTrade",
 "exactCallbackWeaponKeyIdentityProven",
 "clientReciprocalTransferProven","mayUseForStrategyLearning",
 "mayReportProfit","exactWeaponIdentityConfirmed",
)
TRUE_FIELDS=(
 "coreTerminal","readOnly","listenerDisconnected","clientCompatibleFlagPattern",
 "privateRawKeyEqualityObserved","stablePartnerLabel","guiBound",
 "sameBoundWindowClientOnly",
)

def output(ok:bool, reason:str)->dict:
    return {
        "schema":OUTPUT,
        "status":("CLIENT_RAW_CALLBACK_AND_GAIN_MATCH_UNATTRIBUTED" if ok
                  else "QUARANTINED_OR_INCONCLUSIVE"),
        "reason":reason,
        "confidenceTier":("CLIENT_RAW_PRIMITIVE_CORROBORATION" if ok
                          else "UNUSABLE_UNTRUSTED_OR_INCOMPLETE"),
        "clientKeyEqualityObserved":ok,
        "distinctStage66ReportValidated":ok,
        "operatorConfirmedThisSpecificTrade":False,
        "exactItemInstanceProven":False,
        "authenticatedTransactionIdPresent":False,
        "serverCompletionProven":False,
        "serverAttestation":False,
        "partnerIdentityAuthenticated":False,
        "opponentDeclineAttributionProven":False,
        "tradeOutcome":"UNKNOWN",
        "completedTradeRecorded":False,
        "rejectedTradeRecorded":False,
        "mayReportProfit":False,
        "historicalTestAccountExcluded":True,
        "discordLearningEligible":False,
        "mayUseForStrategyLearning":False,
        "authorizesAccept":False,
        "authorizesTrade":False,
    }

def fail(reason:str)->dict:
    return output(False,reason)

def time_ok(x:object)->bool:
    return (type(x) in (int,float) and math.isfinite(x)
            and 0<=x<=150 and abs(x*10-round(x*10))<1e-7)

def evaluate(report:object)->dict:
    if not isinstance(report,dict) or set(report)!=FIELDS:
        return fail("SCHEMA_MISSING_EXTRA_FIELDS_OR_ATTEMPTED_JOIN")
    if report["schema"]!=SCHEMA or report["status"]!=(
        "CLIENT_RAW_RECEIPT_EQUALS_OWN_GAIN_UNATTRIBUTED"
    ):
        return fail("WRONG_OR_NONTERMINAL_SOURCE")
    if report["reason"]!=(
        "private-raw-key-string-equality-is-not-server-settlement-proof"
    ) or report["tradeOutcome"]!="UNKNOWN":
        return fail("INCONSISTENT_CLIENT_OUTCOME")
    if any(report[name] is not False for name in FALSE_FIELDS):
        return fail("SELF_ATTESTED_OR_UNTRUSTED_AUTHORITY")
    if any(report[name] is not True for name in TRUE_FIELDS):
        return fail("UNPROVEN_LOCAL_COHERENCE")
    if (type(report["recordCount"]) is not int or report["recordCount"]!=2
        or type(report["discardedReceipts"]) is not int
        or report["discardedReceipts"]!=0
        or type(report["ignoredUnboundReceipts"]) is not int
        or report["ignoredUnboundReceipts"]!=0):
        return fail("SAMPLES_DROPPED_OR_UNBOUND")
    if (report["privateRawEqualityStatus"]!=
            "PRIVATE_RAW_PRIMITIVE_EQUALITY_CLIENT_ONLY" or
        report["privateRawEqualityReason"]!=
            "private-exact-string-equality-is-not-server-transaction-proof" or
        report["callbackRowShape"]!="TRIPLET_ELEMENT_TYPES_OBSERVED" or
        report["callbackRowFieldTypes"]!=["string","number","string"]):
        return fail("RECEIPT_RAW_EQUALITY_OR_TYPES_UNPROVEN")
    own=report["ownReadbacks"]
    if not isinstance(own,dict) or set(own)!=OWN_FIELDS:
        return fail("OWNED_WEAPON_READBACK_SCHEMA_INVALID")
    expected={
        "rawWeaponInventoryChanged":True,
        "stopReason":"TWO_POST_CLOSE_READS_FINISHED",
        "beforeObserved":True,
        "partnerCacheAtBaseline":True,
        "gainedEligibleCopies":1,
        "changedEligibleTypes":1,
        "status":"ELIGIBLE_DELTA_WITHOUT_RESULT_NAMED_RECEIPT",
        "windowClosureObserved":True,
        "lostEligibleCopies":0,
        "postReadbacksObserved":2,
    }
    if any(type(own.get(k)) is not type(v) or own[k]!=v
           for k,v in expected.items()):
        return fail("RAW_GAIN_OR_TWO_POST_CLOSE_READBACKS_UNPROVEN")
    events=report["samples"]
    if not isinstance(events,list) or len(events)!=2:
        return fail("CALLBACK_SEQUENCE_COUNT_INVALID")
    for e in events:
        if not isinstance(e,dict) or set(e)!=EVENT_FIELDS:
            return fail("UNTRUSTED_CALLBACK_FIELDS_OR_PAYLOAD")
        if not time_ok(e["elapsedSeconds"]):
            return fail("INVALID_CALLBACK_CLOCK")
    first,second=events
    if not (
        first["firstArg"]=="BOOLEAN_FALSE"
        and first["argCount"]==1 and type(first["argCount"]) is int
        and first["secondArg"]=="NIL"
        and first["secondTableShape"]=="NOT_TABLE"
        and first["phase"]=="WITHIN_BOUND_GUI_CLIENT_ONLY"
        and second["firstArg"]=="BOOLEAN_TRUE"
        and second["argCount"]==2 and type(second["argCount"]) is int
        and second["secondArg"]=="TABLE"
        and second["secondTableShape"]=="BOUNDED_SEQUENCE_1"
        and second["phase"] in (
             "WITHIN_BOUND_GUI_CLIENT_ONLY",
             "IMMEDIATE_GUI_CLOSE_CLIENT_ONLY"
        )
    ):
        return fail("CALLBACK_PHASE_OR_STRUCTURE_CONTRADICTED")
    gap=second["elapsedSeconds"]-first["elapsedSeconds"]
    if not 0<=gap<=5:
        return fail("CALLBACK_ORDER_OR_FRESHNESS_INVALID")
    return output(True,"raw-string-equality-confirmed-as-local-client-observation-only")


def main()->None:
    import sys
    if len(sys.argv)!=2:
        raise SystemExit("Usage: stage67_native_raw_receipt_learning_gate.py report.json")
    source=json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    print(json.dumps(evaluate(source),sort_keys=True))


if __name__=="__main__":
    main()
