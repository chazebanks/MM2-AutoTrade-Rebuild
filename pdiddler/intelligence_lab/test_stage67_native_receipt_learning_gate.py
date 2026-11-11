"""Stage67: exact native Stage66 shape + adversarial learning containment."""
from __future__ import annotations

import copy
import importlib.util
import json
import random
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/"scripts/stage67_native_raw_receipt_learning_gate.py"
spec=importlib.util.spec_from_file_location("stage67_gate",SOURCE)
assert spec and spec.loader
gate=importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)

def native_report():
    return {
        "eventSessionAssociationProven":False,"recordCount":2,
        "coreTerminal":True,"readOnly":True,
        "serverTransactionIdAuthenticated":False,
        "status":"CLIENT_RAW_RECEIPT_EQUALS_OWN_GAIN_UNATTRIBUTED",
        "callbackRowFieldTypes":["string","number","string"],
        "callbackRowShape":"TRIPLET_ELEMENT_TYPES_OBSERVED",
        "serverAttestation":False,"authorizesAccept":False,
        "authorizesTrade":False,"listenerDisconnected":True,
        "clientCompatibleFlagPattern":True,
        "schema":"gingerscope-stage66-one-window-client-accept-delta-v1",
        "causalTradeAttributionProven":False,
        "serverCompletionProven":False,
        "mayRecordCompletedTrade":False,
        "reason":"private-raw-key-string-equality-is-not-server-settlement-proof",
        "tradeOutcome":"UNKNOWN","discardedReceipts":0,
        "mayRecordRejectedTrade":False,
        "privateRawKeyEqualityObserved":True,
        "privateRawEqualityStatus":"PRIVATE_RAW_PRIMITIVE_EQUALITY_CLIENT_ONLY",
        "stablePartnerLabel":True,
        "samples":[
            {"secondArg":"NIL","firstArg":"BOOLEAN_FALSE",
             "phase":"WITHIN_BOUND_GUI_CLIENT_ONLY",
             "elapsedSeconds":12,"argCount":1,
             "secondTableShape":"NOT_TABLE"},
            {"secondArg":"TABLE","firstArg":"BOOLEAN_TRUE",
             "phase":"IMMEDIATE_GUI_CLOSE_CLIENT_ONLY",
             "elapsedSeconds":14.2,"argCount":2,
             "secondTableShape":"BOUNDED_SEQUENCE_1"},
        ],
        "ownReadbacks":{
            "rawWeaponInventoryChanged":True,
            "stopReason":"TWO_POST_CLOSE_READS_FINISHED",
            "beforeObserved":True,
            "partnerCacheAtBaseline":True,
            "gainedEligibleCopies":1,
            "changedEligibleTypes":1,
            "status":"ELIGIBLE_DELTA_WITHOUT_RESULT_NAMED_RECEIPT",
            "windowClosureObserved":True,
            "lostEligibleCopies":0,"postReadbacksObserved":2,
        },
        "ignoredUnboundReceipts":0,"guiBound":True,
        "sameBoundWindowClientOnly":True,
        "exactCallbackWeaponKeyIdentityProven":False,
        "privateRawEqualityReason":"private-exact-string-equality-is-not-server-transaction-proof",
        "clientReciprocalTransferProven":False,
        "mayUseForStrategyLearning":False,
        "mayReportProfit":False,
        "exactWeaponIdentityConfirmed":False,
    }

def assert_never_learn(case,result):
    case.assertFalse(result["discordLearningEligible"])
    case.assertFalse(result["completedTradeRecorded"])
    case.assertFalse(result["rejectedTradeRecorded"])
    case.assertFalse(result["mayUseForStrategyLearning"])
    case.assertFalse(result["authorizesTrade"])
    case.assertFalse(result["authorizesAccept"])
    case.assertFalse(result["mayReportProfit"])
    case.assertFalse(result["operatorConfirmedThisSpecificTrade"])
    case.assertFalse(result["serverCompletionProven"])
    case.assertEqual(result["tradeOutcome"],"UNKNOWN")
    case.assertTrue(result["historicalTestAccountExcluded"])

class Stage67NativeReportTests(unittest.TestCase):
    def check_quarantined(self,value):
        result=gate.evaluate(value)
        self.assertEqual(result["status"],"QUARANTINED_OR_INCONCLUSIVE",result)
        self.assertFalse(result["clientKeyEqualityObserved"])
        assert_never_learn(self,result)

    def test_exact_native_input_is_local_corroboration_not_training(self):
        result=gate.evaluate(native_report())
        self.assertEqual(result["status"],"CLIENT_RAW_CALLBACK_AND_GAIN_MATCH_UNATTRIBUTED")
        self.assertEqual(result["confidenceTier"],"CLIENT_RAW_PRIMITIVE_CORROBORATION")
        self.assertTrue(result["clientKeyEqualityObserved"])
        assert_never_learn(self,result)

    def test_source_self_attestation_and_private_field_injection(self):
        for k in gate.FALSE_FIELDS:
            with self.subTest(k=k):
                item=native_report();item[k]=True
                self.check_quarantined(item)
        for k in gate.TRUE_FIELDS:
            with self.subTest(k=k):
                item=native_report();item[k]=False
                self.check_quarantined(item)
        for section in ("source","readbacks","event"):
            with self.subTest(section=section):
                item=native_report()
                if section=="source":
                    item["rawWeaponName"]="SECRET_WPN"
                elif section=="readbacks":
                    item["ownReadbacks"]["privateRawKey"]="SECRET_WPN"
                else:
                    item["samples"][1]["receivedRawRow"]=["SECRET_WPN",1,"Weapons"]
                result=gate.evaluate(item)
                self.assertEqual(result["status"],"QUARANTINED_OR_INCONCLUSIVE")
                self.assertNotIn("SECRET_WPN",json.dumps(result))
                assert_never_learn(self,result)

    def test_callback_order_freshness_and_item_type_contradictions(self):
        changes=[
            lambda x:x["samples"].reverse(),
            lambda x:x["samples"][0].__setitem__("firstArg","BOOLEAN_TRUE"),
            lambda x:x["samples"][1].__setitem__("firstArg","BOOLEAN_FALSE"),
            lambda x:x["samples"][0].__setitem__("phase","PRE_BOUND_UNATTRIBUTED"),
            lambda x:x["samples"][1].__setitem__("phase","AFTER_CLOSE_UNATTRIBUTED"),
            lambda x:x["samples"][1].__setitem__("elapsedSeconds",17.2),
            lambda x:x["samples"][1].__setitem__("elapsedSeconds",10.0),
            lambda x:x["samples"][1].__setitem__("elapsedSeconds",float("nan")),
            lambda x:x["samples"][0].__setitem__("elapsedSeconds",float("inf")),
            lambda x:x["samples"][0].__setitem__("elapsedSeconds",True),
            lambda x:x["samples"][1].__setitem__("argCount",True),
            lambda x:x["samples"][1].__setitem__("argCount",1),
            lambda x:x["samples"][1].__setitem__("secondTableShape","BOUNDED_SEQUENCE_2"),
            lambda x:x["samples"].append(copy.deepcopy(x["samples"][1])),
            lambda x:x.__setitem__("recordCount",1),
            lambda x:x.__setitem__("ignoredUnboundReceipts",1),
            lambda x:x.__setitem__("discardedReceipts",2),
            lambda x:x["callbackRowFieldTypes"].__setitem__(0,"number"),
            lambda x:x["callbackRowFieldTypes"].append("secret"),
            lambda x:x.__setitem__("callbackRowShape","NOT_TRIPLET"),
            lambda x:x.__setitem__("privateRawEqualityStatus","INCONCLUSIVE"),
            lambda x:x.__setitem__("privateRawKeyEqualityObserved",False),
            lambda x:x.__setitem__("privateRawEqualityReason","UNVERIFIED"),
        ]
        for i,change in enumerate(changes):
            with self.subTest(i=i):
                case=native_report()
                change(case)
                self.check_quarantined(case)

    def test_owned_weapon_readback_provenance_and_quantity_guards(self):
        changes=[
            lambda x:x["ownReadbacks"].__setitem__("gainedEligibleCopies",2),
            lambda x:x["ownReadbacks"].__setitem__("lostEligibleCopies",1),
            lambda x:x["ownReadbacks"].__setitem__("changedEligibleTypes",0),
            lambda x:x["ownReadbacks"].__setitem__("rawWeaponInventoryChanged",False),
            lambda x:x["ownReadbacks"].__setitem__("partnerCacheAtBaseline",False),
            lambda x:x["ownReadbacks"].__setitem__("beforeObserved",False),
            lambda x:x["ownReadbacks"].__setitem__("windowClosureObserved",False),
            lambda x:x["ownReadbacks"].__setitem__("postReadbacksObserved",1),
            lambda x:x["ownReadbacks"].__setitem__("status","COMPLETED"),
            lambda x:x["ownReadbacks"].__setitem__("stopReason","TIMEOUT"),
            lambda x:x.__setitem__("status","CONFIRMED_COMPLETE"),
            lambda x:x.__setitem__("reason","server-signed"),
            lambda x:x.__setitem__("tradeOutcome","SUCCESS"),
            lambda x:x.__setitem__("schema","gingerscope-stage59-paired-v1"),
        ]
        for i,change in enumerate(changes):
            with self.subTest(i=i):
                case=native_report()
                change(case)
                self.check_quarantined(case)

    def test_1000_seeded_hostile_field_variations(self):
        rng=random.Random(67067)
        for index in range(1000):
            item=native_report()
            n=rng.randrange(15)
            if n==0:item["status"]="UNKNOWN"
            elif n==1:item["privateRawEqualityStatus"]="INCOMPLETE"
            elif n==2:item["callbackRowFieldTypes"][rng.randrange(3)]="TABLE"
            elif n==3:item["samples"][0]["phase"]="PRE_BOUND_UNATTRIBUTED"
            elif n==4:item["samples"][1]["phase"]="BEFORE_GUI"
            elif n==5:item["samples"][1]["elapsedSeconds"]=rng.uniform(20,100)
            elif n==6:item["samples"][1]["argCount"]=rng.choice([0,1,3])
            elif n==7:item["samples"][0]["firstArg"]="OTHER"
            elif n==8:item["ignoredUnboundReceipts"]=rng.randint(1,4)
            elif n==9:item["discardedReceipts"]=rng.randint(1,20)
            elif n==10:item["ownReadbacks"]["gainedEligibleCopies"]=rng.randint(2,100)
            elif n==11:item["ownReadbacks"]["postReadbacksObserved"]=rng.randint(3,7)
            elif n==12:item["mayUseForStrategyLearning"]=True
            elif n==13:item["samples"][1]["rawIdentifier"]="SECRET"+str(index)
            else:item["stage59Pair"]={"operator":"yes"}
            result=gate.evaluate(item)
            self.assertEqual(result["status"],"QUARANTINED_OR_INCONCLUSIVE",(index,n,result))
            assert_never_learn(self,result)

    def test_no_reuse_of_other_trade_or_historical_webhook_claim(self):
        for item in ([],{},None,[native_report()],{"stage59":{}},
                     {"stage63":native_report()},"COMPLETE"):
            self.check_quarantined(item)
        src=SOURCE.read_text()
        for forbidden in ("requests.","urllib","httpx","subprocess",
                          "DiscordWebhook","getgenv","InvokeServer",
                          "FireServer","setclipboard","API_KEY"):
            self.assertNotIn(forbidden,src)

if __name__=="__main__":
    unittest.main()
