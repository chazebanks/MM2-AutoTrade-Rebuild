"""Stage34 pure offer-to-inventory reconciliation, invoked through real Lua.
No request sending, final Accept, completed trade authority, or Claim-click gate.
"""
from pathlib import Path
import subprocess
import shutil
import unittest

LAB=Path(__file__).resolve().parent
ROOT=LAB.parent.parent
P4=ROOT/"pdiddler"/"new_part4"
CORE=P4/"p4_stage34_offer_delta_reconcile.lua"
TEST=P4/"tests"/"test_stage34_offer_delta_reconcile.lua"

class Stage34OfferDeltaTest(unittest.TestCase):
    def test_reuses_stage9_canonical_offer_and_stage29_inventory_shape(self):
        src=CORE.read_text()
        for required in (
            'offerMap(diag.ourItems,o.ourSlots)',
            'offerMap(diag.theirItems,o.theirSlots)',
            'l.pre.items',
            'l.post2.items',
            'l.post1.items',
            'l.status~="ELIGIBLE_DELTA_UNATTRIBUTED"',
            'l.post1.fp~=l.post2.fp',
            'l.post1.rawOwned~=l.post2.rawOwned',
            'l.after1At<=s.closedAt',
            'l.after2At<=l.after1At',
            'sameScope(s,scope)',
            's.lastSig~=sample.signature and s.seenAnyAccept',
            'same-item-in-both-offers-net-delta-ambiguous',
        ):
            self.assertIn(required,src)
        self.assertNotIn("Claim:FireServer",src)
        self.assertNotIn('ClaimWeapon:FireServer',src)
        for forbidden in (':FireServer(',':InvokeServer(','HttpGet(',
                          'SendMouseButtonEvent(','setclipboard(',
                          'HttpService:PostAsync(','getconnections('):
            self.assertNotIn(forbidden,src)

    def test_fail_closed_report_is_anonymized_and_no_settlement_authority(self):
        src=CORE.read_text()
        for marker in (
            'tradeOutcome="UNKNOWN"',
            'serverCompletionProven=false',
            'causalAttributionProven=false',
            'authorizesTrade=false,authorizesAccept=false',
            'mayRecordCompletedTrade=false,mayReportProfit=false',
            'readbacksAreClientClaims=true',
            'offerCaptureIsClientClaim=true',
            'claimButtonIsNotCreditPrerequisite=true',
        ):
            self.assertIn(marker,src)
        tests=TEST.read_text()
        for name in (
            'one-sided gift exact eligible identity and quantity agree client only',
            'two-sided exact distinct eligible exchange agrees client only',
            'claim popup not required for own inventory already credited after close',
            'wrong item gained is mismatch despite equal net count',
            'gross same-item both directions cannot be proven from net inventory',
            'mutation after any observed Accept permanently poisons reconciliation',
            'ledger for other session cannot match identical quantity maps',
        ):
            self.assertIn(name,tests)

    @unittest.skipUnless(shutil.which("lua5.4"),"Lua5.4 in GitHub CI")
    def test_python_runs_actual_lua_stage34_suite(self):
        p=subprocess.run(
            ["lua5.4",str(TEST),"pdiddler/new_part4"],
            cwd=str(ROOT),capture_output=True,text=True,timeout=14
        )
        self.assertEqual(p.returncode,0,p.stdout+"\n"+p.stderr)
        self.assertIn("Stage34 pure client offer to inventory identity reconciliation",p.stdout)

    @unittest.skipUnless(shutil.which("lua5.4"),"Lua5.4 in GitHub CI")
    def test_stage34_source_compiles(self):
        p=subprocess.run(["lua5.4","-e",
               "assert(loadfile('pdiddler/new_part4/p4_stage34_offer_delta_reconcile.lua'))"],
               cwd=str(ROOT),capture_output=True,text=True,timeout=10)
        self.assertEqual(p.returncode,0,p.stdout+"\n"+p.stderr)

if __name__=="__main__":
    unittest.main()
