#!/usr/bin/env python3
"""Offline integrity checks; NOT evidence of server-side settlement.

This gate protects the previously proven original-MM2 manual PR214/PR216
runners and human-owned picker from modifications in the auto-offer branch.
"""
from pathlib import Path
import subprocess
import unittest

ROOT=Path(__file__).resolve().parents[2]
D=ROOT/"pdiddler/supervised"
MANUAL=D/"SUPERVISED_P3_ONE_ITEM_OFFER_NATIVE.lua"
P3=D/"SUPERVISED_P3_NATIVE_STARTUP.lua"
PICKER=D/"SUPERVISED_P3_ONE_ITEM_OWNED_PICKER.lua"
OP=D/"supervised_p3_one_item_operator.lua"
GATE=D/"supervised_p3_one_item_auto_gate.lua"
AUTO=D/"SUPERVISED_P3_ONE_ITEM_AUTO_OFFER_NATIVE.lua"
AUTOPICKER=D/"SUPERVISED_P3_ONE_ITEM_AUTO_OWNED_PICKER.lua"
IO=D/"pdiddler4_tradeio_supervised_v2.lua"

def blob(p:Path)->str:
    return subprocess.check_output(["git","hash-object",str(p)],text=True).strip()

class SourceAudit(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manual=MANUAL.read_text(encoding="utf-8")
        cls.p3=P3.read_text(encoding="utf-8")
        cls.picker=PICKER.read_text(encoding="utf-8")
        cls.op=OP.read_text(encoding="utf-8")
        cls.gate=GATE.read_text(encoding="utf-8")
        cls.auto=AUTO.read_text(encoding="utf-8")
        cls.autopicker=AUTOPICKER.read_text(encoding="utf-8")

    def test_previous_native_proofs_byte_for_byte_unchanged(self):
        self.assertEqual(blob(MANUAL),"9ed64d2aeecef8ad742917e29c0f093320fac7dd")
        self.assertEqual(blob(P3),"51abddeb7819110c16a4e77480232dca36402ad4")
        self.assertEqual(blob(PICKER),"7ec246113b37c202970517a10a052ef86708c031")
        self.assertEqual(blob(OP),"d295fbb7eb4bc366e553b0750bdb0dd40792376d")
        self.assertEqual(blob(IO),"eb4dc6342d1d6dda6292490cd8fa00314199d589")

    def test_new_gate_exact_sha_frozen_and_loaded(self):
        self.assertEqual(blob(GATE),"b5a2451487f2e7f5ceb2fe815bfa06f516ea8175")
        self.assertIn('loadFrozen("b23419685fb8d91c1845143804aed636cbc64dd9"',self.auto)
        self.assertIn('"supervised/supervised_p3_one_item_auto_gate.lua"',self.auto)
        self.assertIn('autoModule.new(pilot,cfg.autoConsent',self.auto)
        self.assertIn('autoGate.observe,r.status',self.auto)

    def test_only_explicit_prior_item_authorization_may_start(self):
        for token in (
            'origin="PICKER_HUMAN_APPROVED_AUTO_ONE"',
            'explicitOneAutomaticPlacement=true',
            'singleConsentingAltOnly=true',
            'finalAcceptMustRemainManual=true',
            'altUserId=uid',
            'issuedAt=os.clock()',
            'rawKey=item.raw',
            'display=item.display',
            'chroma=item.chroma',
        ):
            self.assertIn(token,self.autopicker)
        self.assertIn('ui.confirm=btn("ConfirmOwnedOne","AUTHORIZE 1 AUTO OFFER"',self.autopicker)
        self.assertIn('ui.arm.Activated:Connect(function()',self.auto)
        self.assertNotIn('ui.offer.Activated:Connect',self.auto)
        self.assertIn('cfg.autoConsent.job~=game.JobId',self.auto)
        self.assertIn('cfg.autoConsent.rawKey~=cfg.approvedRawKey',self.auto)
        self.assertIn('targetStillExact()',self.auto)
        self.assertIn('E.PDIDDLER_SUPERVISED_P3_AUTO_USED_JOB=game.JobId',self.auto)

    def test_gate_one_physical_attempt_without_implicit_retry(self):
        for token in (
            'firstRoot~=root', 'now-firstTime<0.15', 'spent=true',
            'pilot.preview', 'env.onTrigger',
            'P3_BOUND', 'AUTO_ONE_SHOT_ALREADY_SPENT',
        ):
            if token!='P3_BOUND':
                self.assertIn(token,self.gate)
        self.assertIn('offerSpent=true',self.auto)
        self.assertIn('local good,receipt=pcall(pilot.execute,true)',self.auto)
        self.assertIn('oneItemOfferAttempts=0',self.auto)
        self.assertIn('autoOfferTriggeredClient=true',self.auto)
        self.assertIn('autoOfferPreauthorizedClient=true',self.auto)
        self.assertIn('oneItemTapObservedClient=false',self.auto)

    def test_no_direct_unauthorized_game_mutations(self):
        forbidden=(
            'OfferItem:FireServer(', 'AcceptTrade:FireServer(',
            'DeclineTrade:FireServer(', 'SendRequest:FireServer(',
            'TeleportService', 'PostAsync(', 'minProfit = 15',
            'pdiddler4_balancer_',
        )
        for source in (self.autopicker,self.auto,self.gate):
            for x in forbidden:
                with self.subTest(command=x):
                    self.assertNotIn(x,source)
        self.assertIn('authorizesAccept=false',self.auto)
        self.assertIn('serverCompletionProven=false',self.auto)
        self.assertIn('mayReportProfit=false',self.auto)
        self.assertIn('maySendDiscordWebhook=false',self.auto)
        self.assertIn('tradeOutcome="UNKNOWN"',self.auto)

    def test_does_not_use_untested_price_or_economic_rules(self):
        self.assertIn('approvedRawKey=item.raw',self.autopicker)
        self.assertIn('approvedDisplayName=item.display',self.autopicker)
        self.assertIn('approvedChromaFlag=item.chroma',self.autopicker)
        self.assertNotIn('highest',self.auto.lower())
        self.assertNotIn('minProfit',self.auto)
        self.assertNotIn('checkerPrice',self.auto)
        self.assertNotIn('tradeValue',self.auto)

if __name__=="__main__":
    unittest.main()
