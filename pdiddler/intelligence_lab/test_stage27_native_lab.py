"""Stage27 Python-first audit of the actual Lua native transport/lab.

This is NOT Delta proof: requires manual in-game verification after passing.
"""
from pathlib import Path
import re
import shutil
import subprocess
import unittest

ROOT=Path(__file__).resolve().parents[1]
P4=ROOT/"new_part4"
LAB=P4/"STAGE27_CONTROLLED_DELTA_LAB.lua"
CORE=P4/"p4_stage27_lab_core.lua"
TRANSPORT=P4/"p4_stage27_native_transport.lua"

class NativeControlledLabTests(unittest.TestCase):
    def test_operator_controls_are_only_dispatch_triggers(self):
        text=LAB.read_text()
        for call in (
            'bindButton.Activated:Connect',
            'selectButton.Activated:Connect',
            'addButton.Activated:Connect(executeAdd)',
            'removeButton.Activated:Connect(executeRemove)',
            'stopButton.Activated:Connect',
        ):
            self.assertIn(call,text)
        self.assertIn('function executeAdd()',text)
        self.assertIn('function executeRemove()',text)
        self.assertIn('S.stamp=os.clock();S.addAttempted=true',text)
        self.assertIn('S.stamp=os.clock();S.removeAttempted=true',text)
        self.assertNotRegex(text,r'(?m)^\s*(executeAdd|executeRemove)\(\)')

    def test_no_active_old_trading_system_involved(self):
        text=LAB.read_text()
        for forbidden in (
            'p4.run(', 'transport.bootstrap(', 'outgoing.start(',
            'OfferItem:FireServer', 'AcceptTrade:FireServer',
            'DeclineTrade:FireServer', 'queue_on_teleport(',
            'pdiddler4_balancer_SUPREME_v11_VALUE_FIRST.lua',
        ):
            self.assertNotIn(forbidden,text)
        self.assertIn('STAGE25_SCANNER_ONLY_BOOT.lua',text)
        self.assertIn('PDIDDLER_OUTGOING_SESSION~=nil',text)
        self.assertIn('PDIDDLER_PART4_SESSION~=nil',text)
        self.assertIn('MAX_ITEM_VALUE=200',text)

    def test_current_source_and_timestamped_scanner_are_required(self):
        text=LAB.read_text()
        for required in (
            'profile.isFresh()',
            'scanProof',
            'proof.jobId~=GAME_JOB',
            'proof.playerUserId~=partner.UserId',
            'proof.fingerprint~=rec.inv.fingerprint',
            'os.clock()-proof.completedAtMono>30',
            'state.scanning==true',
            'state.retryScheduled==true',
            'scanner.getOwnInventory',
            'it.checkerId',
            'price.supremeValue<=MAX_ITEM_VALUE',
        ):
            self.assertIn(required,text)

    def test_offer_and_remove_require_verified_same_session(self):
        text=CORE.read_text()
        for required in (
            'o.ourAccepted~=false', 'o.theirAccepted~=false',
            's.addAttempted=true',
            's.removeAttempted=true',
            's.permitActive=true',
            's.permitActive=false',
            's.offerCore.prepare',
            's.offerNative.execute',
            's.offerCore.dispatched',
            's.offerCore.observe',
            's.removeCore.prepare',
            's.removeNative.execute',
            's.removeCore.dispatched',
            's.removeCore.observe',
            's.phase="READY_REMOVE"',
            's.phase="DONE"',
        ):
            self.assertIn(required,text)
        self.assertIn('serverCompletionProven=false',text)
        self.assertIn('authorizesAccept=false',text)

    def test_native_transport_is_single_mode_no_fallback(self):
        text=TRANSPORT.read_text()
        self.assertEqual(text.count('remote:FireServer('),1)
        self.assertEqual(text.count('vim:SendMouseButtonEvent('),2)
        self.assertNotIn('firesignal(',text)
        self.assertNotIn(':Activate()',text)
        self.assertNotIn('AcceptTrade',text)
        self.assertNotIn('DeclineTrade',text)
        self.assertNotIn('Teleport',text)
        self.assertIn('h.addConsumed=true',text)
        self.assertIn('h.removeConsumed=true',text)
        self.assertIn('targetObscured',text)

    def test_one_live_action_requires_both_transport_interfaces_before_add(self):
        text=LAB.read_text()
        self.assertIn('local interfacesOK=pcall(function()',text)
        self.assertIn('OfferItem missing',text)
        self.assertIn('physical remove-input API missing',text)
        self.assertIn('Native add or physical removal input unavailable',text)

    def test_anonymized_result_includes_uncertainties(self):
        text=LAB.read_text()
        self.assertIn('GINGERSCOPE STAGE27 ANONYMIZED',text)
        self.assertIn('setclipboard',text)
        core=CORE.read_text()
        self.assertIn('addAttempted=s.addAttempted',core)
        self.assertIn('removeAttempted=s.removeAttempted',core)
        self.assertNotIn('partnerUserId=',core)
        self.assertNotIn('localUserId=',core)
        self.assertNotIn('jobId=',core)

    @unittest.skipUnless(shutil.which("lua5.4"),"Lua5.4 available in GitHub CI")
    def test_complete_native_delta_ui_launcher_compiles_without_running(self):
        proc=subprocess.run(
            ["lua5.4","-e",
             "assert(loadfile('pdiddler/new_part4/STAGE27_CONTROLLED_DELTA_LAB.lua'))"],
            cwd=str(ROOT.parent),capture_output=True,text=True,
            timeout=10,check=False)
        self.assertEqual(proc.returncode,0,
                         proc.stdout+"\\n"+proc.stderr)

    @unittest.skipUnless(shutil.which("lua5.4"),"Lua5.4 available in GitHub CI")
    def test_actual_lua_state_machine_and_native_mock(self):
        for filename,expected in (
            ("test_stage27_lab_transaction.lua",
             "Stage27 real Stage22 ADD and Stage10 REMOVE manual-lab"),
            ("test_stage27_native_transport.lua",
             "Stage27 native OfferItem and physical single-click"),
        ):
            proc=subprocess.run(["lua5.4",str(P4/"tests"/filename),str(P4)],
                cwd=str(ROOT.parent),capture_output=True,text=True,
                check=False,timeout=12)
            self.assertEqual(proc.returncode,0,
                filename+" failed:\n"+proc.stdout+"\n"+proc.stderr)
            self.assertIn(expected,proc.stdout)

if __name__=="__main__":
    unittest.main()
