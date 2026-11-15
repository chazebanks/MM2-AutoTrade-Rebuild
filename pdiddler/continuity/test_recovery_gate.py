import copy, unittest
try:
    from pdiddler.continuity.recovery_gate import gate
except ModuleNotFoundError:
    from recovery_gate import gate

GOOD={"taskId":"GS-RECOVERY-20261114","sourceHead":"5925c6a4cb4b7eb7491d6bd00592039e1c83154b",
"recoveredEntrypoint":"00 - GINGERSCOPE RECOVERY ENTRYPOINT - READ FIRST",
"missionRead":True,"matrixRead":True,"historyCoverage":"PARTIAL_NOT_ALL_STAGES_AUDITED",
"relatedFailures":["F13 stale history index"],
"priorEvidence":["https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/289"],
"falsificationTests":["missing evidence must block"],"scope":"TEST_ONLY",
"authorization":"NO_LIVE_GAME_ACTIONS","risk":"NO_GAME_ACTIONS_NO_PRIVATE_DATA",
"newFindings":["original history remains partial"]}

class GateTests(unittest.TestCase):
    def test_valid_receipt_is_only_research_valid(self):
        self.assertEqual(gate(GOOD)["status"],"RESEARCH_RECEIPT_VALID")
    def test_missing_each_required(self):
        for k in list(GOOD):
            with self.subTest(k=k):
                d=copy.deepcopy(GOOD);del d[k]
                self.assertEqual(gate(d)["status"],"BLOCKED")
    def test_invalid_values(self):
        cases=[("taskId","x"),("sourceHead","0"*39),("recoveredEntrypoint","wrong"),
               ("missionRead",False),("matrixRead",False),("historyCoverage","COMPLETE"),
               ("scope","LIVE_TRADE"),("authorization","AUTHORIZED"),("risk","PRIVATE_DATA"),
               ("relatedFailures",[]),("priorEvidence",["https://evil.com/pr/289"]),
               ("falsificationTests",["short"]),("newFindings",[])]
        for k,v in cases:
            with self.subTest(k=k):
                d=copy.deepcopy(GOOD);d[k]=v
                self.assertEqual(gate(d)["status"],"BLOCKED")
    def test_false_trade_authority(self):
        for k in ("serverSettlementProven","authorizesFinalAccept"):
            d=copy.deepcopy(GOOD);d[k]=True
            self.assertEqual(gate(d)["status"],"BLOCKED")
    def test_not_automatic_history_proof(self):
        self.assertIn("Self-attested",gate(GOOD)["note"])

if __name__=="__main__":unittest.main()
