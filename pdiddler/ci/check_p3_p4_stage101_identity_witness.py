#!/usr/bin/env python3
"""Stage101 original protected P3/P4 identity witness, offline-only audit."""
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT/"pdiddler/supervised/supervised_p3_p4_stage101_identity_witness.lua"
MANUAL = ROOT/"pdiddler/supervised/SUPERVISED_P3_ONE_ITEM_OFFER_NATIVE.lua"
AUTO = ROOT/"pdiddler/supervised/SUPERVISED_P3_ONE_ITEM_AUTO_OFFER_NATIVE.lua"
OLD_PICKER = ROOT/"pdiddler/supervised/SUPERVISED_P3_ONE_ITEM_OWNED_PICKER.lua"
NEW_PICKER = ROOT/"pdiddler/supervised/SUPERVISED_P3_ONE_ITEM_AUTO_OWNED_PICKER.lua"
HANDOFF = ROOT/"pdiddler/supervised/supervised_p3_p4_handoff.lua"

def gitblob(p: Path) -> str:
    return subprocess.check_output(["git","hash-object",str(p)],text=True).strip()

class WitnessSource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source=SOURCE.read_text(encoding="utf-8")

    def test_existing_live_production_is_byte_identical(self):
        self.assertEqual(gitblob(MANUAL),"9ed64d2aeecef8ad742917e29c0f093320fac7dd")
        self.assertEqual(gitblob(AUTO),"72f59f77e83fd353d184daf79b7d6a34088170b3")
        self.assertEqual(gitblob(OLD_PICKER),"7ec246113b37c202970517a10a052ef86708c031")
        self.assertEqual(gitblob(NEW_PICKER),"8824ce83a7384821a906a335c655c1ef94908c6b")
        self.assertEqual(gitblob(HANDOFF),"d496d6311dc6c5e24e059fcd71014e274a4be76b")

    def test_witness_only_passive_pure_sources(self):
        for token in (
          'CLIENT_UNPRICED_TWO_SIDED_SNAPSHOT',
          'P3_BOUND_CANDIDATE_READ_ONLY',
          'ORIGINAL_STAGE9_AND_PROTECTED_P4_GUI_DISAGREE',
          'GUI_CHANGED_BEFORE_CURRENT_EVENT_WITNESS',
          'REQUIRES_ONE_STABLE_ALT_SLOT_AND_EMPTY_MAIN_AT_START',
          'BOTH_SIDES_NOT_VISIBLE_AFTER_CLIENT_EVENT',
          'CLIENT_BOTH_SIDES_RAW_KEY_CANDIDATES_UNATTRIBUTED',
          'rawItemIdConfirmed=false',
          'authorizesAccept=false','serverCompletionProven=false',
          'eventSessionAssociationProven=false,callbackCausalityProven=false',
          'tradeOutcome="UNKNOWN"','local immutablePacket=clonePacket(packed)',
        ):
            self.assertIn(token,self.source)
        for forbidden in (
          ':FireServer(', ':InvokeServer(', 'getconnections(',
          'VirtualInputManager', 'SendMouseButtonEvent',
          'TeleportService','PostAsync(', 'HttpPost(',
          'AcceptTrade(', 'DeclineTrade(', 'getgenv(', 'game:GetService(',
          'loadstring(game:HttpGet(', 'maySendDiscordWebhook=true',
          'mayReportProfit=true', 'authorizesTrade=true',
          'authorizesAccept=true', 'serverCompletionProven=true',
        ):
            self.assertNotIn(forbidden,self.source)

    def test_private_client_keys_not_in_anonymized_report(self):
        self.assertIn('-- NEVER return/store/log the private raw-key map',self.source)
        self.assertIn('before=nil;receipt=nil;after1=nil;private=nil',self.source)
        self.assertIn('return last',self.source)
        self.assertNotIn('last.ours=',self.source)
        self.assertNotIn('last.theirs=',self.source)
        self.assertNotIn('last.rawKey=',self.source)
        self.assertNotIn('print(',self.source)

    def test_no_old_price_or_accept_strategy_used(self):
        for token in ('minProfit','highest','numericCheckerId','SupremeValue','PostAsync','AcceptTrade'):
            self.assertNotIn(token,self.source)

if __name__=="__main__":
    unittest.main()
