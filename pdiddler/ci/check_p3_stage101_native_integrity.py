#!/usr/bin/env python3
"""Static gate for standalone native observer, not a true device test."""
from pathlib import Path
import subprocess
import unittest

ROOT=Path(__file__).resolve().parents[2]
AUTO=ROOT/"pdiddler/supervised/SUPERVISED_P3_ONE_ITEM_AUTO_OFFER_NATIVE.lua"
OLD=ROOT/"pdiddler/supervised/SUPERVISED_P3_NATIVE_STARTUP.lua"
CURRENT=ROOT/"pdiddler/supervised/SUPERVISED_P3_STAGE101_IDENTITY_NATIVE.lua"
WITNESS=ROOT/"pdiddler/supervised/supervised_p3_p4_stage101_identity_witness.lua"
HANDOFF=ROOT/"pdiddler/supervised/supervised_p3_p4_handoff.lua"
START=ROOT/"pdiddler/supervised/SUPERVISED_P3_STAGE101_READONLY_START.lua"
def blob(path):
    return subprocess.check_output(["git","hash-object",str(path)],text=True).strip()

class NativeReadOnly(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.code=CURRENT.read_text()
        cls.witness=WITNESS.read_text()

    def test_old_live_p3_and_auto_offer_remain_byte_identical(self):
        self.assertEqual(blob(OLD),"51abddeb7819110c16a4e77480232dca36402ad4")
        self.assertEqual(blob(AUTO),"72f59f77e83fd353d184daf79b7d6a34088170b3")
        self.assertEqual(blob(HANDOFF),"d496d6311dc6c5e24e059fcd71014e274a4be76b")

    def test_new_runner_uses_exact_frozen_history_and_identity_module(self):
        for token in (
          "15f762a27a968373ed82809345f1869e1f688b26",
          "1971b93d324f0275e6a9affb472ac3e804439ed8",
          "25b48b60fdb2f971bbb6b2a2020f3c7c4432f7ae",
          "fd00161e4a309935d66b7a32ec057ac17a20d855",
          'identityModule.new(boundScope',
          'supervisor.currentBoundReadOnly()',
          'stage9Native.capture',
          'io.readSide,root,"TheirOffer"',
          'remote.OnClientEvent:Connect(function(...)',
          'table.pack(...)',
          'baselineAt',
          'math.clamp(report.matchedOwnSlots,0,4)',
          'clientBothSidesCandidateConsistent',
          'stage101IdentityReadOnly~=true',
          'if eventConnection then',
          'Never final Accept',
        ):
            if token!='Never final Accept':
                self.assertIn(token,self.code,token)

    def test_one_line_entrypoint_exact_alt_and_exact_reviewed_frozen_native(self):
        loader=START.read_text(encoding="utf-8")
        self.assertEqual(blob(CURRENT),"4ad3ca58c302889c4b73c2ccc688ee32639e1965")
        for token in (
          'targetName="venossgaming90190"',
          '"bb065d00a62b904c298cfd08ff1d2a75a4b509b7/"',
          'stage101IdentityReadOnly=true',
          'altOnlyTest=true',
          'finalAcceptMustRemainManual=true',
          'game.PlaceId~=142823291',
          'PDIDDLER_SUPERVISED_P3_NATIVE_OWNER~=nil',
          'loadstring(source)',
        ):
            self.assertIn(token,loader)
        for forbidden in ('OfferItem:FireServer(','AcceptTrade:FireServer(',
                          'DeclineTrade:FireServer('):
            self.assertNotIn(forbidden,loader)

    def test_no_scripted_weapon_offer_or_final_accept_or_decline(self):
        for source in (self.code,self.witness):
            for forbidden in (
              'OfferItem:FireServer(', 'AcceptTrade:FireServer(',
              'DeclineTrade:FireServer(', ':InvokeServer(',
              'SendMouseButtonEvent(', 'VirtualInputManager:Send',
              'TeleportService:Teleport(', 'PostAsync(',
              'authorizesTrade=true','authorizesAccept=true',
              'serverCompletionProven=true','maySendDiscordWebhook=true',
            ):
                self.assertNotIn(forbidden,source,forbidden)
        for token in (
          'actualOffers=0,actualAccepts=0,actualDeclines=0',
          'rawItemIdConfirmed=false',
          'eventSessionAssociationProven=false',
          'serverCompletionProven=false',
          'tradeOutcome="UNKNOWN"',
          'READ ONLY | NEVER FINAL ACCEPT',
          'ALT — ADD ONE WEAPON',
          'MAIN — ADD ONE WEAPON',
          'manually DECLINE',
        ):
            self.assertIn(token,self.code,token)

    def test_witness_manual_45s_baseline_without_event_expanding_3s_causality(self):
        self.assertIn('HUMAN_MAIN_ADD_WINDOW_EXPIRED',self.witness)
        self.assertIn('v.at-begunAt>45',self.witness)
        self.assertIn('before=v',self.witness)
        self.assertIn('at-before.at>3',self.witness)
        self.assertIn('GUI_CHANGED_BEFORE_CURRENT_EVENT_WITNESS',self.witness)
        self.assertIn('ONE_CLIENT_EVENT_WAIT_STABLE_BOTH_SIDES_GUI',self.witness)

if __name__=="__main__":
    unittest.main()
