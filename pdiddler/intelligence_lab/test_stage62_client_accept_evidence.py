"""Stage62: native-shaped one-client evidence + 1000 adversarial safety cases."""
from __future__ import annotations

import copy
import importlib.util
import json
import math
import random
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
PATH=ROOT/"scripts/stage62_client_accept_evidence.py"
spec=importlib.util.spec_from_file_location("stage62_gate",PATH)
assert spec and spec.loader
gate=importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)

def real_shaped_stage61():
    """Field-for-field shape from real Nov 8 device report, no secret content."""
    return {
        "schema":"gingerscope-stage61-accept-client-args-v1",
        "status":"CLIENT_CALLBACK_SHAPES_CAPTURED_UNATTRIBUTED",
        "reason":"CLIENT_EVENT_NAMES_AND_ARGUMENT_TYPES_ONLY",
        "readOnly":True,"tradeOutcome":"UNKNOWN",
        "serverAttestation":False,"serverCompletionProven":False,
        "serverTransactionIdAuthenticated":False,
        "eventSessionAssociationProven":False,
        "causalTradeAttributionProven":False,
        "exactWeaponIdentityConfirmed":False,
        "authorizesAccept":False,"authorizesTrade":False,
        "mayRecordCompletedTrade":False,"mayRecordRejectedTrade":False,
        "mayReportProfit":False,"mayUseForStrategyLearning":False,
        "observedSingleGui":True,"guiStableBound":True,
        "guiClosedObserved":True,"scopedEventCount":2,
        "unboundEventCount":0,"totalReceipts":2,"discardedReceipts":0,
        "listenersDisconnected":1,"hadTypeTrue":True,"hadTypeFalse":True,
        "historicalClientFlagHypothesisCompatible":True,
        "events":[
            {"phase":"DURING_GUI_CLIENT_ONLY",
             "firstArg":"BOOLEAN_FALSE","secondArg":"NIL",
             "secondTableShape":"NOT_TABLE","argCount":1,"elapsedSeconds":21.1},
            {"phase":"DURING_GUI_CLIENT_ONLY",
             "firstArg":"BOOLEAN_TRUE","secondArg":"TABLE",
             "secondTableShape":"BOUNDED_SEQUENCE_1","argCount":2,
             "elapsedSeconds":21.4},
        ],
    }

def assert_no_authority(self, out):
    self.assertEqual(out["tradeOutcome"],"UNKNOWN")
    self.assertTrue(out["readOnly"])
    for name in (
        "serverAttestation","serverCompletionProven",
        "serverTransactionIdAuthenticated","sameServerJobAuthenticated",
        "eventSessionAssociationProven","causalTradeAttributionProven",
        "exactWeaponIdentityConfirmed","operatorConfirmedThisTrade",
        "stage59SameTransactionBound","mayRecordCompletedTrade",
        "mayRecordRejectedTrade","mayReportProfit","mayUseForStrategyLearning",
        "authorizesAccept","authorizesTrade","discordLearningEligible",
    ):
        self.assertIs(out[name],False,name)
    self.assertEqual(out["sourceKind"],"ONE_STAGE61_CLIENT_REPORT_ONLY")


class Stage62GateTests(unittest.TestCase):
    def test_real_native_shaped_false_true_second_one_item_table(self):
        out=gate.evaluate(real_shaped_stage61())
        self.assertEqual(out["status"],
                         "CLIENT_FALSE_TRUE_CALLBACK_WITH_TABLE_UNATTRIBUTED")
        self.assertEqual(out["reason"],
                         "current-client-accept-callback-shape-matches-historical-ui-branch-only")
        self.assertTrue(out["clientSuccessLikeSignalObserved"])
        assert_no_authority(self,out)

    def test_malformed_cross_session_and_authority_injection_rejected(self):
        cases=[]
        x=real_shaped_stage61();x["stage59"]={"received":True};cases.append(x)
        x=real_shaped_stage61();x["playerId"]="PRIVATE-123";cases.append(x)
        x=real_shaped_stage61();x["events"][1]["rawItemName"]="PRIVATE_GODLY";cases.append(x)
        x=real_shaped_stage61();x["events"][1]["payload"]={"item":"PRIVATE"};cases.append(x)
        x=real_shaped_stage61();x.pop("events");cases.append(x)
        x=real_shaped_stage61();x["serverCompletionProven"]=True;cases.append(x)
        x=real_shaped_stage61();x["mayUseForStrategyLearning"]=True;cases.append(x)
        x=real_shaped_stage61();x["authorizesAccept"]="false";cases.append(x)
        x=real_shaped_stage61();x["tradeOutcome"]="SUCCESS";cases.append(x)
        x=real_shaped_stage61();x["eventSessionAssociationProven"]=True;cases.append(x)
        x=real_shaped_stage61();x["status"]="CONFIRMED_COMPLETE";cases.append(x)
        x=real_shaped_stage61();x["readOnly"]=False;cases.append(x)
        for i,x in enumerate(cases):
            with self.subTest(i=i):
                out=gate.evaluate(x)
                self.assertEqual(out["status"],"INCONCLUSIVE")
                self.assertFalse(out["clientSuccessLikeSignalObserved"])
                assert_no_authority(self,out)
                leak=json.dumps(out)
                for secret in ("PRIVATE-123","PRIVATE_GODLY","PRIVATE"):
                    self.assertNotIn(secret,leak)

    def test_visibility_timeline_and_listener_boundaries(self):
        mutations=[
            lambda x:x.__setitem__("guiStableBound",False),
            lambda x:x.__setitem__("guiClosedObserved",False),
            lambda x:x.__setitem__("observedSingleGui",False),
            lambda x:x.__setitem__("listenersDisconnected",0),
            lambda x:x.__setitem__("listenersDisconnected",2),
            lambda x:x.__setitem__("discardedReceipts",1),
            lambda x:x.__setitem__("unboundEventCount",1),
            lambda x:x.__setitem__("scopedEventCount",1),
            lambda x:x.__setitem__("totalReceipts",3),
            lambda x:x["events"][0].__setitem__("phase","PRE_BOUND_UNATTRIBUTED"),
            lambda x:x["events"][1].__setitem__("phase","AFTER_CLOSE_UNATTRIBUTED"),
            lambda x:x["events"][1].__setitem__("phase","OUT_OF_WINDOW"),
            lambda x:x["events"][0].__setitem__("elapsedSeconds",22.0),
            lambda x:x["events"][1].__setitem__("elapsedSeconds",27.0),
            lambda x:x["events"][1].__setitem__("elapsedSeconds",float("nan")),
            lambda x:x["events"][1].__setitem__("elapsedSeconds",float("inf")),
            lambda x:x["events"][0].__setitem__("elapsedSeconds",-1),
            lambda x:x["events"][0].__setitem__("elapsedSeconds",True),
            lambda x:x["events"][1].__setitem__("elapsedSeconds","21.4"),
        ]
        for i,change in enumerate(mutations):
            with self.subTest(i=i):
                x=real_shaped_stage61()
                change(x)
                out=gate.evaluate(x)
                self.assertEqual(out["status"],"INCONCLUSIVE",out)
                assert_no_authority(self,out)

    def test_event_shape_and_copy_replay_conflicts(self):
        mutations=[
            lambda x:x["events"].reverse(),
            lambda x:x["events"][0].__setitem__("firstArg","BOOLEAN_TRUE"),
            lambda x:x["events"][1].__setitem__("firstArg","BOOLEAN_FALSE"),
            lambda x:x["events"][0].__setitem__("argCount",2),
            lambda x:x["events"][1].__setitem__("argCount",1),
            lambda x:x["events"][1].__setitem__("secondArg","NIL"),
            lambda x:x["events"][1].__setitem__("secondArg","OTHER"),
            lambda x:x["events"][1].__setitem__("secondTableShape","PRIVATE-ITEM"),
            lambda x:x["events"][1].__setitem__("secondTableShape","BOUNDED_SEQUENCE_17"),
            lambda x:x["events"][1].__setitem__("secondTableShape","EMPTY_OR_DICTIONARY"),
            lambda x:x["events"][0].__setitem__("firstArg","NO_ARGS"),
            lambda x:x["events"][1].__setitem__("argCount",True),
            lambda x:x.__setitem__("hadTypeTrue",False),
            lambda x:x.__setitem__("hadTypeFalse",False),
            lambda x:x.__setitem__("historicalClientFlagHypothesisCompatible",False),
            lambda x:x["events"].append(copy.deepcopy(x["events"][1])),
            lambda x:x.__setitem__("events",[]),
        ]
        for i,fn in enumerate(mutations):
            with self.subTest(i=i):
                x=real_shaped_stage61()
                fn(x)
                out=gate.evaluate(x)
                self.assertEqual(out["status"],"INCONCLUSIVE",out)
                assert_no_authority(self,out)

    def test_1000_seeded_invalid_report_mutations(self):
        rng=random.Random(62062)
        for i in range(1000):
            x=real_shaped_stage61()
            choice=rng.randrange(17)
            if choice==0:
                x["events"][1]["secondTableShape"]="BOUNDED_SEQUENCE_999"
            elif choice==1:
                x["events"][0]["phase"]="PRE_BOUND_UNATTRIBUTED"
            elif choice==2:
                x["events"][1]["firstArg"]="OTHER"
            elif choice==3:
                x["status"]="INCOMPLETE"
            elif choice==4:
                x["discardedReceipts"]=rng.randint(1,99)
            elif choice==5:
                x["events"][0]["elapsedSeconds"]=rng.randint(26,130)
            elif choice==6:
                x["events"][1]["elapsedSeconds"]=-rng.randint(1,99)
            elif choice==7:
                x["events"][1]["argCount"]=rng.choice([0,1,3,17])
            elif choice==8:
                x["totalReceipts"]=rng.randint(3,100)
            elif choice==9:
                x["unboundEventCount"]=rng.randint(1,5)
            elif choice==10:
                x["listenersDisconnected"]=rng.choice([0,2,-1])
            elif choice==11:
                x["mayRecordCompletedTrade"]=True
            elif choice==12:
                x["events"][0]["secondArg"]="TABLE"
            elif choice==13:
                x["events"][0]["firstArg"]="BOOLEAN_TRUE"
            elif choice==14:
                x["historicalClientFlagHypothesisCompatible"]=False
            elif choice==15:
                x["events"][1]["payload"]=str(rng.getrandbits(64))
            elif choice==16:
                x["events"][1]["elapsedSeconds"]=21.1111
            out=gate.evaluate(x)
            self.assertEqual(out["status"],"INCONCLUSIVE",(i,choice,out))
            assert_no_authority(self,out)

    def test_no_stage59_cross_session_join_api_or_network_execution(self):
        txt=PATH.read_text(encoding="utf-8")
        for forbidden in ("requests.", "urllib", "httpx", "subprocess",
                          "InvokeServer", "FireServer", "mcp__", "getgenv",
                          "GenUI", "DiscordWebhook", "webhook_url", "API_KEY"):
            self.assertNotIn(forbidden,txt)
        report=real_shaped_stage61()
        self.assertEqual(gate.evaluate([report,report])["status"],"INCONCLUSIVE")
        self.assertEqual(gate.evaluate({"stage59":{},"stage61":report})["status"],
                         "INCONCLUSIVE")
        self.assertEqual(gate.evaluate(None)["status"],"INCONCLUSIVE")
        self.assertEqual(gate.evaluate("TRUE")["status"],"INCONCLUSIVE")


if __name__=="__main__":
    unittest.main()
