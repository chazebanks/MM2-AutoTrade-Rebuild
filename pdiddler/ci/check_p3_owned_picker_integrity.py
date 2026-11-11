#!/usr/bin/env python3
"""Offline source-integrity gate for the read-only native owned-item picker.

The immutable PR216 actual P3 trader has its OWN separate full Lune/CI suite.
This module validates the preflight chooser NEVER acquires trading authority.
"""
from pathlib import Path
import subprocess
import unittest

ROOT=Path(__file__).resolve().parents[2]
P=ROOT/"pdiddler/supervised/SUPERVISED_P3_ONE_ITEM_OWNED_PICKER.lua"
M=ROOT/"pdiddler/supervised/p3_one_item_owned_selection.lua"
RUNNER=ROOT/"pdiddler/supervised/SUPERVISED_P3_ONE_ITEM_OFFER_NATIVE.lua"
PR214=ROOT/"pdiddler/supervised/SUPERVISED_P3_NATIVE_STARTUP.lua"

def sha(path):
    return subprocess.check_output(["git","hash-object",str(path)],text=True).strip()

class PickerIntegrity(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.p=P.read_text()
        cls.m=M.read_text()

    def test_actual_pinned_model_bytes(self):
        # This blob was independently inspected from revision 2b030fe...
        self.assertEqual(sha(M),"bb2f3ada720ea87278a5fd997f2a4f4153b340bd")
        self.assertIn('local CHOICES_REV="2b030fe448d9fd039418aeb603e9b63d0e6b553f"',self.p)

    def test_old_native_runners_unchanged(self):
        self.assertEqual(sha(RUNNER),"9ed64d2aeecef8ad742917e29c0f093320fac7dd")
        self.assertEqual(sha(PR214),"51abddeb7819110c16a4e77480232dca36402ad4")
        self.assertIn('local PR216="73c4a72843d818d08f8212c74d9db0fdad59acea"',self.p)

    def test_selection_never_authorizes_offer(self):
        for source in (self.p,self.m):
            for forbidden in (
                'OfferItem:FireServer(', 'AcceptTrade:FireServer(',
                'DeclineTrade:FireServer(', 'SendRequest:FireServer(',
                'PostAsync(', 'TeleportService',
                'pdiddler4_balancer_', 'highestOwn(',
            ):
                with self.subTest(forbidden=forbidden):
                    self.assertNotIn(forbidden,source)
            for required in ('authorizesOffer=false','authorizesAccept=false'):
                if source is self.m:
                    self.assertIn(required,source)
        self.assertIn('serverCompletionProven=false',self.m)
        self.assertIn('mayReportProfit=false',self.m)
        self.assertIn('tradeOutcome="UNKNOWN"',self.m)

    def test_physical_choice_then_confirm_before_runner(self):
        self.assertIn('b.Activated:Connect(function()',self.p)
        self.assertIn('ui.confirm.Activated:Connect(function()',self.p)
        self.assertIn('selected={raw=item.raw,display=item.display,chroma=item.chroma}',self.p)
        self.assertNotIn('owner.choiceResult',self.p)
        self.assertNotIn('owner.selected=',self.p)
        self.assertIn('if not item or type(item.raw)',self.p)
        self.assertIn('E.PDIDDLER_SUPERVISED_P3_ONE_ITEM_NATIVE={',self.p)
        self.assertIn('approvedRawKey=item.raw',self.p)
        self.assertIn('approvedDisplayName=item.display',self.p)
        self.assertIn('approvedChromaFlag=item.chroma',self.p)
        self.assertIn('noAutomaticAcceptAcknowledged=true',self.p)
        self.assertIn('manualOfferOnly=true',self.p)

    def test_only_one_current_remote_read_and_bounded_wait(self):
        self.assertEqual(self.p.count('remote:InvokeServer()'),1)
        self.assertIn('os.clock()-started<8',self.p)
        self.assertIn('OWN_PROFILE_READ_TIMEOUT_NO_RETRY',self.p)
        self.assertIn('os.clock()-(owner.profileReadAt or 0)>180',self.p)
        self.assertIn('CURRENT_GAME_WEAPON_CATALOG_UNREADABLE',self.m)
        self.assertIn('OWN_WEAPON_METADATA_UNRESOLVED',self.m)
        self.assertIn('NO_ELIGIBLE_CURRENT_OWN_WEAPONS',self.m)
        self.assertIn('OWN_WEAPON_QUANTITY_INVALID',self.m)

    def test_live_client_rechecks_and_no_restart(self):
        for item in ('exactAlt()','noTrade()','E[JOB]==game.JobId',
                     'PDIDDLER_SUPERVISED_P3_NATIVE_OWNER'):
            self.assertIn(item,self.p)
        self.assertIn('if not active()',self.p)
        self.assertIn('stop("OPERATOR_CANCELLED")',self.p)
        self.assertIn('E[JOB]=game.JobId',self.p)

    def test_deterministic_human_choice_not_automatic_value_ranking(self):
        self.assertIn('table.sort(choices',self.m)
        self.assertIn('a.display:lower()',self.m)
        self.assertNotIn('price',self.p.lower())
        self.assertNotIn('profit',self.p.lower())
        self.assertNotIn('market',self.p.lower())
        self.assertIn('protected(raw)',self.m)
        self.assertIn('not protected(raw)',self.m)
        self.assertIn('d.EvoBaseID~=nil',self.m)
        self.assertIn('d.Tradable==false',self.m)

if __name__=="__main__":
    unittest.main()
