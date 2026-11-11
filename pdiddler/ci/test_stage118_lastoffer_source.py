"""Source-bound validation for Stage118 read-only LastOffer + GUI bridge."""
from pathlib import Path
import hashlib
import os
import subprocess
import unittest

ROOT=Path(__file__).resolve().parents[2]
BRIDGE=ROOT/'pdiddler/intelligence_lab/stage118_lastoffer_gui_correlation.lua'
AUDIT=ROOT/'pdiddler/intelligence_lab/trade_lastoffer_client_audit.lua'
STAGE9=Path(os.environ.get('STAGE118_STAGE9') or ROOT/'pdiddler/new_part4/p4_observer_contract.lua')
TEST=ROOT/'pdiddler/tests/test_stage118_lastoffer_gui_correlation.lua'
NATIVE=ROOT/'pdiddler/supervised/SUPERVISED_P3_STAGE101_IDENTITY_NATIVE.lua'
LOADER=ROOT/'pdiddler/supervised/SUPERVISED_P3_STAGE101_READONLY_START.lua'

def blob(path):
    b=path.read_bytes()
    return hashlib.sha1(f'blob {len(b)}\0'.encode()+b).hexdigest()

class Stage118Audit(unittest.TestCase):
    def test_exact_prior_modules_not_mutated(self):
        self.assertEqual(blob(AUDIT),'fba6f02c7287e2afd7ad3ea9e75cc221854a17b9')
        self.assertEqual(blob(STAGE9),'7c84456006bd684dacb0217d0ae092d6d67575a4')
        self.assertEqual(blob(NATIVE),'46cff56b9f58fa8590a275dfd26f46cea0c5c9a6')
        self.assertEqual(blob(LOADER),'a1430dc26fc3d85fe2268a84a5fea475812b5002')

    def test_new_bridge_never_sends_or_autonomously_accepts(self):
        s=BRIDGE.read_text()
        for forbidden in ('FireServer(', 'InvokeServer(', 'HttpGet(',
                          'PostAsync(', 'game:GetService(', 'setclipboard(',
                          'loadstring(', 'Teleport(', 'authorizesAccept=true',
                          'serverTradeRevisionProven=true'):
            self.assertNotIn(forbidden,s)
        for required in ('lastOfferEqualityClass=', 'clientGuiCrossChecked=',
                         'eventSessionAssociationProven=false',
                         'serverTradeRevisionProven=false',
                         'callbackCausalityProven=false',
                         'authorizesTrade=false', 'authorizesAccept=false',
                         'mayReportProfit=false', 'tradeOutcome="UNKNOWN"',
                         'freezePacketQuantities', 'GUI_CHANGED_BEFORE_CURRENT_CALLBACK'):
            self.assertIn(required,s)

    def test_real_lua_module_with_real_stage9_and_existing_audit(self):
        env=os.environ.copy()
        env.update(STAGE118_BRIDGE=str(BRIDGE), STAGE118_AUDIT=str(AUDIT), STAGE118_STAGE9=str(STAGE9))
        p=subprocess.run(['lua5.4',str(TEST)],text=True,capture_output=True,env=env,timeout=30)
        self.assertEqual(p.returncode,0,p.stdout+'\n'+p.stderr)
        self.assertIn('STAGE118_LASTOFFER_STAGE9_SOURCE_BOUND_PASS 10 groups, 200 two-event cases',p.stdout)

if __name__=='__main__':
    unittest.main()
