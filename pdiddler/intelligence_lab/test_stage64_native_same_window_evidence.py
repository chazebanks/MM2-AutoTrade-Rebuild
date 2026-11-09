"""Stage64 exact real Stage63-shaped report and adversarial trust-boundary tests."""
from __future__ import annotations

import copy
import importlib.util
import json
import random
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT/"scripts/stage64_same_window_client_evidence.py"
spec = importlib.util.spec_from_file_location("gingerscope_stage64", PATH)
assert spec and spec.loader
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

def native63():
    return {
        "eventSessionAssociationProven":False,
        "causalTradeAttributionProven":False,
        "serverCompletionProven":False,
        "coreTerminal":True,"readOnly":True,
        "reason":"client-accept-flag-and-own-inventory-delta-do-not-authenticate-settlement",
        "tradeOutcome":"UNKNOWN","serverTransactionIdAuthenticated":False,
        "ownReadbacks":{
            "rawWeaponInventoryChanged":True,
            "stopReason":"TWO_POST_CLOSE_READS_FINISHED",
            "beforeObserved":True,"partnerCacheAtBaseline":True,
            "gainedEligibleCopies":1,"changedEligibleTypes":1,
            "status":"ELIGIBLE_DELTA_WITHOUT_RESULT_NAMED_RECEIPT",
            "windowClosureObserved":True,"lostEligibleCopies":0,
            "postReadbacksObserved":2
        },
        "status":"CLIENT_ACCEPT_FLAG_PLUS_OWN_GAIN_SAME_WINDOW_UNATTRIBUTED",
        "mayRecordRejectedTrade":False,
        "sameBoundWindowClientOnly":True,
        "ignoredUnboundReceipts":0,
        "serverAttestation":False,
        "recordCount":2,
        "authorizesAccept":False,
        "authorizesTrade":False,
        "discardedReceipts":0,
        "samples":[
            {"secondArg":"NIL","firstArg":"BOOLEAN_FALSE",
             "phase":"WITHIN_BOUND_GUI_CLIENT_ONLY",
             "elapsedSeconds":14.3,"argCount":1,
             "secondTableShape":"NOT_TABLE"},
            {"secondArg":"TABLE","firstArg":"BOOLEAN_TRUE",
             "phase":"WITHIN_BOUND_GUI_CLIENT_ONLY",
             "elapsedSeconds":15.9,"argCount":2,
             "secondTableShape":"BOUNDED_SEQUENCE_1"},
        ],
        "listenerDisconnected":True,
        "clientCompatibleFlagPattern":True,
        "stablePartnerLabel":True,
        "guiBound":True,
        "clientReciprocalTransferProven":False,
        "mayRecordCompletedTrade":False,
        "mayReportProfit":False,
        "mayUseForStrategyLearning":False,
        "schema":"gingerscope-stage63-one-window-client-accept-delta-v1",
        "exactWeaponIdentityConfirmed":False,
    }

def check_no_authority(t, result):
    for key in (
        "operatorConfirmationForThisRunProven", "serverCompletionProven",
        "serverAttestation","serverTransactionIdAuthenticated",
        "eventSessionAssociationProven","causalTradeAttributionProven",
        "sameTradeCounterpartyAuthenticated","exactWeaponIdentityConfirmed",
        "authorizesAccept","authorizesTrade","mayRecordCompletedTrade",
        "mayRecordRejectedTrade","mayReportProfit",
        "mayUseForStrategyLearning","discordLearningEligible"
    ):
        t.assertIs(result[key],False,key)
    t.assertEqual(result["tradeOutcome"],"UNKNOWN")
    t.assertEqual(result["schema"],
                  "gingerscope-stage64-client-corroboration-audit-v1")

class Stage64NativeEvidence(unittest.TestCase):
    def test_real_stage63_native_report_exact_correlation_but_no_authority(self):
        result=m.evaluate(native63())
        self.assertEqual(result["status"],
                         "CLIENT_SAME_WINDOW_ACCEPT_PLUS_OWN_GAIN_UNATTRIBUTED")
        self.assertTrue(result["clientTemporalCorrelationObserved"])
        check_no_authority(self,result)
        self.assertNotIn("ownReadbacks",result)
        self.assertNotIn("samples",result)

    def test_unsafe_source_authority_and_private_payloads_rejected(self):
        for key in m.FLAG_FALSE:
            with self.subTest(key=key):
                x=native63();x[key]=True
                result=m.evaluate(x)
                self.assertEqual(result["status"],"INCONCLUSIVE")
                check_no_authority(self,result)
        for key in m.FLAG_TRUE:
            with self.subTest(key=key):
                x=native63();x[key]=False
                result=m.evaluate(x)
                self.assertEqual(result["status"],"INCONCLUSIVE")
                check_no_authority(self,result)
        for path in ["top","own","sample"]:
            with self.subTest(path=path):
                x=native63()
                if path=="top":x["userId"]="PRIVATE_USER"
                elif path=="own":x["ownReadbacks"]["weapon"]="PRIVATE_WEAPON"
                else:x["samples"][1]["rawItems"]={"key":"PRIVATE_ITEM"}
                result=m.evaluate(x)
                self.assertEqual(result["status"],"INCONCLUSIVE")
                self.assertNotIn("PRIVATE",json.dumps(result))
                check_no_authority(self,result)

    def test_reversed_or_delayed_callbacks_wrong_phase_and_counts(self):
        mutations=[
            lambda x:x["samples"].reverse(),
            lambda x:x["samples"][1].__setitem__("firstArg","BOOLEAN_FALSE"),
            lambda x:x["samples"][0].__setitem__("firstArg","BOOLEAN_TRUE"),
            lambda x:x["samples"][1].__setitem__("secondArg","NIL"),
            lambda x:x["samples"][1].__setitem__("secondTableShape","BOUNDED_SEQUENCE_0"),
            lambda x:x["samples"][1].__setitem__("secondTableShape","BOUNDED_SEQUENCE_2"),
            lambda x:x["samples"][1].__setitem__("argCount",1),
            lambda x:x["samples"][1].__setitem__("argCount",True),
            lambda x:x["samples"][0].__setitem__("phase","PRE_BOUND_UNATTRIBUTED"),
            lambda x:x["samples"][1].__setitem__("phase","IMMEDIATE_GUI_CLOSE_CLIENT_ONLY"),
            lambda x:x["samples"][1].__setitem__("elapsedSeconds",20.0),
            lambda x:x["samples"][0].__setitem__("elapsedSeconds",16.0),
            lambda x:x["samples"][1].__setitem__("elapsedSeconds","15.9"),
            lambda x:x["samples"][1].__setitem__("elapsedSeconds",float("nan")),
            lambda x:x["samples"][0].__setitem__("elapsedSeconds",float("inf")),
            lambda x:x["samples"].append(copy.deepcopy(x["samples"][1])),
            lambda x:x.__setitem__("recordCount",3),
            lambda x:x.__setitem__("recordCount",False),
            lambda x:x.__setitem__("ignoredUnboundReceipts",1),
            lambda x:x.__setitem__("discardedReceipts",1),
            lambda x:x["ownReadbacks"].__setitem__("postReadbacksObserved",1),
            lambda x:x["ownReadbacks"].__setitem__("gainedEligibleCopies",0),
            lambda x:x["ownReadbacks"].__setitem__("lostEligibleCopies",1),
            lambda x:x["ownReadbacks"].__setitem__("changedEligibleTypes",2),
            lambda x:x["ownReadbacks"].__setitem__("partnerCacheAtBaseline",False),
            lambda x:x["ownReadbacks"].__setitem__("stopReason","TIMEOUT"),
            lambda x:x["ownReadbacks"].__setitem__("status","INCOMPLETE"),
            lambda x:x.__setitem__("status","CONFIRMED_COMPLETE"),
            lambda x:x.__setitem__("schema","gingerscope-stage59-two-client-aggregate-witness-v1"),
            lambda x:x.__setitem__("tradeOutcome","COMPLETE"),
        ]
        for i,modify in enumerate(mutations):
            with self.subTest(i=i):
                x=native63()
                modify(x)
                result=m.evaluate(x)
                self.assertEqual(result["status"],"INCONCLUSIVE",(i,result))
                self.assertFalse(result["clientTemporalCorrelationObserved"])
                check_no_authority(self,result)

    def test_1000_seeded_conflicting_native_shapes_fail_closed(self):
        rng=random.Random(64064)
        for i in range(1000):
            x=native63()
            selector=rng.randrange(15)
            if selector==0:x["status"]="INCONCLUSIVE"
            elif selector==1:x["schema"]="UNKNOWN"
            elif selector==2:x["reason"]="server-verified"
            elif selector==3:x["mayRecordCompletedTrade"]=True
            elif selector==4:x["eventSessionAssociationProven"]=True
            elif selector==5:x["samples"][0]["firstArg"]="OTHER"
            elif selector==6:x["samples"][1]["secondArg"]="NIL"
            elif selector==7:x["samples"][1]["elapsedSeconds"]=rng.randint(21,100)
            elif selector==8:x["samples"][0]["elapsedSeconds"]=rng.randint(16,100)
            elif selector==9:x["samples"][1]["phase"]="AFTER_CLOSE"
            elif selector==10:x["ownReadbacks"]["gainedEligibleCopies"]=rng.randint(2,50)
            elif selector==11:x["ownReadbacks"]["lostEligibleCopies"]=rng.randint(1,50)
            elif selector==12:x["ownReadbacks"]["postReadbacksObserved"]=rng.randint(3,50)
            elif selector==13:x["ownReadbacks"]["rawWeaponInventoryChanged"]=False
            else:x["samples"][0]["extraPayload"]=str(rng.getrandbits(64))
            result=m.evaluate(x)
            self.assertEqual(result["status"],"INCONCLUSIVE",(i,selector))
            check_no_authority(self,result)

    def test_stage59_and_stage61_cannot_be_merged_into_one_run(self):
        x=native63()
        x["stage59"]={"lost":1}
        self.assertEqual(m.evaluate(x)["status"],"INCONCLUSIVE")
        x=native63()
        x["stage61"]={"flag":True}
        self.assertEqual(m.evaluate(x)["status"],"INCONCLUSIVE")
        for invalid in (None,"",[],[native63(),native63()],{}):
            self.assertEqual(m.evaluate(invalid)["status"],"INCONCLUSIVE")
        source=PATH.read_text(encoding="utf-8")
        for verboten in ("urllib.request","requests.","httpx","subprocess",
                        "FireServer","InvokeServer","mcp__", "setclipboard",
                        "DiscordWebhook","Authorization:"):
            self.assertNotIn(verboten,source)

if __name__=="__main__":
    unittest.main()
