"""Stage59: adversarial two-client anonymous MM2 manual trade evidence tests."""
from __future__ import annotations
import copy
import importlib.util
import random
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
FILE=ROOT/"scripts/validate_manual_trade_pair.py"
SPEC=importlib.util.spec_from_file_location("stage59_pair",FILE)
assert SPEC and SPEC.loader
mod=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(mod)

def witness(role,gained,lost,nonce,when=1794101234):
    result={
        "schema":"gingerscope-stage32-readonly-result-correlation-v1",
        "status":"ELIGIBLE_DELTA_WITHOUT_RESULT_NAMED_RECEIPT",
        "reason":"own-inventory-change-cause-unverified",
        "stopReason":"TWO_POST_CLOSE_READS_FINISHED",
        "inventoryStatus":"ELIGIBLE_DELTA_UNATTRIBUTED",
        "beforeObserved":True,"windowClosureObserved":True,
        "postReadbacksObserved":2,"changedEligibleTypes":1,
        "gainedEligibleCopies":gained,"lostEligibleCopies":lost,
        "rawWeaponInventoryChanged":True,"closureStatus":"closed_unknown",
        "signalReceipts":0,"completeTradeSignalSeen":False,
        "endTradeSignalSeen":False,"declineTradeSignalSeen":False,
        "partnerDepartureObserved":False,"observedOurAccept":True,
        "observedTheirAccept":False,"bothAcceptedStableObserved":False,
        "offerMutationAfterAccept":False,
        "tradeOutcome":"UNKNOWN","readOnly":True,
        "serverAttestation":False,"serverCompletionProven":False,
        "causalAttributionProven":False,"authorizesTrade":False,
        "authorizesAccept":False,"mayRecordCompletedTrade":False,
        "mayReportProfit":False,
    }
    return {"schema":"gingerscope-stage59-two-client-aggregate-witness-v1",
        "operatorDeclaredRole":role,
        "pairId":"STAGE59-NOV08-MANUAL-A",
        "receiptNonce":nonce,
        "observedAtUnix":when,"readOnly":True,
        "collectorStatus":"CLIENT_STAGE32_TERMINAL_OBSERVATION",
        "authorizesTrade":False,"authorizesAccept":False,
        "serverCompletionProven":False,"serverAttestation":False,
        "mayRecordCompletedTrade":False,"mayReportProfit":False,
        "stage32":result}

def samples():
    return (
        witness("SENDER",0,1,"12345678-1234-1234-1234-123456789abc"),
        witness("RECEIVER",1,0,"abcdefab-1234-1234-1234-123456789abc",1794101250)
    )

def check_immutable(r):
    assert r["tradeOutcome"]=="UNKNOWN"
    for name in ("serverCompletionProven","serverAttestation",
                 "serverTransactionIdAuthenticated",
                 "exactWeaponInstanceIdentityProven",
                 "sameServerJobAuthenticated","causalTradeAttributionProven",
                 "mayReportProfit","mayRecordCompletedTrade",
                 "mayUseForStrategyLearning",
                 "authorizesAccept","authorizesTrade"):
        assert r[name] is False,(name,r[name])

class Stage59ReciprocalWitnessTests(unittest.TestCase):
    def test_two_client_aggregate_candidate_not_settlement(self):
        a,b=samples()
        x=mod.evaluate(a,b,operator_claims_same_manual_trade=True,
                       operator_reports_visible_completion=True)
        self.assertEqual(x["status"],"CLIENT_RECIPROCAL_ELIGIBLE_DELTAS_UNATTRIBUTED")
        self.assertTrue(x["clientReciprocalEligibleDeltaObserved"])
        self.assertTrue(x["manualSameTradeClaimObserved"])
        self.assertEqual(x["reason"],
                         "operator-reported-completion-plus-reciprocal-client-deltas-unattributed")
        check_immutable(x)

    def test_no_operator_corroboration_still_no_trade_claim(self):
        a,b=samples()
        x=mod.evaluate(a,b)
        self.assertEqual(x["status"],"CLIENT_RECIPROCAL_ELIGIBLE_DELTAS_UNATTRIBUTED")
        self.assertIn("not-operator-confirmed",x["reason"])
        check_immutable(x)

    def test_actual_incident_same_receiver_receipt_pasted_as_alt_and_main(self):
        original=witness("RECEIVER",1,0,"d7ea4c21-12be-4c6d-aa16-b69f679178a6",
                         1794152772)
        copied=copy.deepcopy(original)
        result=mod.evaluate(original,copied,
                            operator_claims_same_manual_trade=True,
                            operator_reports_visible_completion=True)
        self.assertEqual(result["status"],"INCOMPLETE")
        self.assertEqual(result["reason"],"IDENTICAL_REPORT_PASTED_TWICE")
        self.assertFalse(result["clientReciprocalEligibleDeltaObserved"])
        check_immutable(result)

    def test_replay_and_unbound_clocks_block(self):
        a,b=samples()
        b["receiptNonce"]=a["receiptNonce"]
        self.assertEqual(mod.evaluate(a,b)["reason"],"REPLAYED_SINGLE_CLIENT_RECEIPT")
        a,b=samples()
        b["observedAtUnix"]=a["observedAtUnix"]+91
        self.assertEqual(mod.evaluate(a,b)["reason"],
                         "CLIENT_CLOCKS_OR_TRADES_NOT_COLOCATED")
        a,b=samples()
        b["pairId"]="STAGE59-NOV08-MANUAL-B"
        self.assertEqual(mod.evaluate(a,b)["reason"],"MISMATCHED_TEST_PAIR")

    def test_no_externally_unconfirmed_weapon_identity_promoted(self):
        a,b=samples()
        x=mod.evaluate(a,b,operator_claims_same_manual_trade=True,
                       operator_reports_visible_completion=False)
        self.assertFalse(x["exactWeaponInstanceIdentityProven"])
        self.assertFalse(x["causalTradeAttributionProven"])
        check_immutable(x)

    def test_failure_mutations_must_not_record_success(self):
        cases=[
            ("nested stage32 timed out",lambda a,b:b.__setitem__(
                "collectorStatus","INCOMPLETE_STAGE32_NO_POST_CLOSE_EVIDENCE")),
            ("wrong account role",lambda a,b:b.__setitem__("operatorDeclaredRole","SENDER")),
            ("no sender",lambda a,b:a.pop("stage32")),
            ("missing own baseline",lambda a,b:a["stage32"].__setitem__("beforeObserved",False)),
            ("one post-read only",lambda a,b:b["stage32"].__setitem__("postReadbacksObserved",1)),
            ("wrong closure",lambda a,b:a["stage32"].__setitem__("closureStatus","success")),
            ("net both gain",lambda a,b:a["stage32"].__setitem__("gainedEligibleCopies",1)),
            ("no sender loss",lambda a,b:a["stage32"].__setitem__("lostEligibleCopies",0)),
            ("no receiver gain",lambda a,b:b["stage32"].__setitem__("gainedEligibleCopies",0)),
            ("two weapons transferred",lambda a,b:b["stage32"].__setitem__("gainedEligibleCopies",2)),
            ("booleans as copy counts",lambda a,b:a["stage32"].__setitem__("lostEligibleCopies",True)),
            ("sender inconsistent",lambda a,b:a["stage32"].__setitem__("inventoryStatus","POST_READS_DISAGREE")),
            ("receiver profile unchanged",lambda a,b:b["stage32"].__setitem__("rawWeaponInventoryChanged",False)),
            ("sender missing slot",lambda a,b:a["stage32"].__setitem__("changedEligibleTypes",0)),
            ("server claim",lambda a,b:a["stage32"].__setitem__("serverCompletionProven",True)),
            ("profit claim",lambda a,b:b.__setitem__("mayReportProfit",True)),
            ("complete receipt observed",lambda a,b:b["stage32"].__setitem__("completeTradeSignalSeen",True)),
            ("departed",lambda a,b:a["stage32"].__setitem__("partnerDepartureObserved",True)),
            ("wrong schema",lambda a,b:b["stage32"].__setitem__("schema","unrecognized")),
            ("bad status",lambda a,b:b["stage32"].__setitem__("status","SUCCESS")),
            ("bad pair id",lambda a,b:b.__setitem__("pairId","INVALID_CODE")),
            ("unrecognized nonce",lambda a,b:b.__setitem__("receiptNonce","1")),
            ("moved time",lambda a,b:a.__setitem__("observedAtUnix",0)),
            ("second receipt missing",lambda a,b:b.clear()),
            ("decline receipt",lambda a,b:a["stage32"].__setitem__("signalReceipts",1)),
        ]
        for name,edit in cases:
            with self.subTest(case=name):
                a,b=samples()
                edit(a,b)
                out=mod.evaluate(a,b,operator_claims_same_manual_trade=True,
                                 operator_reports_visible_completion=True)
                self.assertEqual(out["status"],"INCOMPLETE")
                self.assertFalse(out["clientReciprocalEligibleDeltaObserved"])
                check_immutable(out)

    def test_800_seeded_wrong_session_and_inventory_cases(self):
        r=random.Random(5908)
        for i in range(800):
            a,b=samples()
            choice=r.randrange(12)
            if choice==0:a["stage32"]["gainedEligibleCopies"]=r.randint(1,4)
            elif choice==1:a["stage32"]["lostEligibleCopies"]=r.choice([0,2,3,4])
            elif choice==2:b["stage32"]["lostEligibleCopies"]=r.randint(1,4)
            elif choice==3:b["stage32"]["gainedEligibleCopies"]=r.choice([0,2,3,4])
            elif choice==4:a["stage32"]["signalReceipts"]=r.randint(1,3)
            elif choice==5:b["stage32"]["postReadbacksObserved"]=r.choice([0,1,3])
            elif choice==6:a["stage32"]["status"]="NO_RESULT_NAMED_RECEIPT_OBSERVED"
            elif choice==7:b["stage32"]["tradeOutcome"]="SUCCESS"
            elif choice==8:a["stage32"]["authorizesAccept"]=True
            elif choice==9:b["pairId"]+=str(i)
            elif choice==10:b["observedAtUnix"]+=r.randint(91,3600)
            elif choice==11:b["collectorStatus"]="INCOMPLETE_STAGE32_NO_POST_CLOSE_EVIDENCE"
            x=mod.evaluate(a,b,operator_claims_same_manual_trade=True,
                           operator_reports_visible_completion=True)
            self.assertEqual(x["status"],"INCOMPLETE",(i,choice,x))
            check_immutable(x)

    def test_source_does_not_contact_game_or_promote_profit(self):
        code=FILE.read_text(encoding="utf-8")
        for snippet in (":FireServer(",":InvokeServer(","HttpGet(","setclipboard(",
                        "GetProfileData(", "loadstring(", "getgenv("):
            self.assertNotIn(snippet,code)
        self.assertIn('"tradeOutcome":"UNKNOWN"',code)
        self.assertIn('"serverCompletionProven":False',code)
        self.assertIn('"mayUseForStrategyLearning":False',code)

if __name__=="__main__":
    unittest.main()
