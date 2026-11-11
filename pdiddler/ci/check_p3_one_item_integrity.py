#!/usr/bin/env python3
"""Fail-closed offline audit of the dedicated P3 one-item native pilot.

This is only a source/CI boundary; passing does not establish Roblox/iPad
runtime, authenticated ownership, settlement, or acceptable market prices.
"""
from __future__ import annotations

import pathlib
import re
import subprocess
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
D = ROOT / "pdiddler"
NATIVE = D / "supervised/SUPERVISED_P3_ONE_ITEM_OFFER_NATIVE.lua"
OP = D / "supervised/supervised_p3_one_item_operator.lua"
BOOT = D / "supervised/supervised_p3_startup_supervisor.lua"
COORD = D / "supervised/supervised_real_p3_rotation_handoff.lua"
ORIGINAL = D / "supervised/SUPERVISED_P3_NATIVE_STARTUP.lua"
IO = D / "supervised/pdiddler4_tradeio_supervised_v2.lua"
PLAN = D / "supervised/supervised_four_slot_operator_plan.lua"


def blob(path: pathlib.Path) -> str:
    return subprocess.check_output(["git", "hash-object", str(path)], text=True).strip()


class Contract(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.native = NATIVE.read_text(encoding="utf-8")
        cls.op = OP.read_text(encoding="utf-8")
        cls.boot = BOOT.read_text(encoding="utf-8")
        cls.coordinator = COORD.read_text(encoding="utf-8")
        cls.original = ORIGINAL.read_text(encoding="utf-8")
        cls.io = IO.read_text(encoding="utf-8")
        cls.plan = PLAN.read_text(encoding="utf-8")

    def test_original_successful_runner_and_tradeio_are_unchanged(self) -> None:
        self.assertEqual(blob(ORIGINAL), "51abddeb7819110c16a4e77480232dca36402ad4")
        self.assertEqual(blob(IO), "eb4dc6342d1d6dda6292490cd8fa00314199d589")
        self.assertEqual(blob(PLAN), "2d5212d5da84e6eabfb137b619128bc375a7ca05")

    def test_original_fail_closed_p3_gate_stays_intact(self) -> None:
        for token in ('requiresExplicitStart=true', 'state="ARM_PENDING"',
                      'watchdogReady', 'noOtherTransactionOwner',
                      'finalAcceptMustRemainManual~=true'):
            self.assertIn(token, self.boot)
        self.assertIn('function supervisor.currentBoundReadOnly()', self.boot)
        self.assertIn('coordinator.currentBoundReadOnly', self.boot)
        self.assertIn('function controller.currentBoundReadOnly()', self.coordinator)
        self.assertIn('local revoked=false', self.coordinator)

    def test_offers_require_separate_physical_button(self) -> None:
        self.assertIn('ui.arm.Activated:Connect(function()', self.native)
        self.assertIn('ui.offer.Activated:Connect(function()', self.native)
        self.assertIn('oneItemTapObservedClient=true', self.native)
        self.assertIn('pilot.execute,true', self.native)
        self.assertIn('if physicalTap~=true', self.op)
        self.assertIn('spent=true', self.op)
        self.assertIn('local ownOK,owned=pcall(scanner.getOwnInventory)', self.op)
        self.assertIn('local okSnap,snap=pcall(bound.capture)', self.op)
        self.assertIn('plan.run,bound,io,gate', self.op)
        self.assertEqual(self.op.count('pcall(plan.run,'), 1)
        self.assertIn('approvedRawKey', self.native)
        self.assertIn('approvedDisplayName', self.native)
        self.assertIn('approvedChromaFlag', self.native)

    def test_only_one_candidate_is_ever_supplied_to_plan(self) -> None:
        self.assertIn('weaponKeys={cfg.approvedRawKey}', self.op)
        self.assertIn('expectedDisplayNames={cfg.approvedDisplayName}', self.op)
        self.assertIn('expectedChromaFlags={cfg.approvedChromaFlag}', self.op)
        self.assertIn('index~=1 or total~=1 or previous~=0', self.op)
        self.assertIn('gate.checkOutbound=nil', self.op)
        self.assertIn('ONE_ITEM_APPROVAL_ALREADY_SPENT', self.op)
        self.assertIn('CURRENT_OWN_WEAPON_IDENTITY_NOT_PROVEN', self.op)
        self.assertIn('NO_SAFE_EXACT_P3_P4_CLIENT_TRADE', self.op)

    def test_no_legacy_strategy_or_direct_mutation_added(self) -> None:
        forbidden = (
            'AcceptTrade:FireServer(', 'OfferItem:FireServer(',
            'DeclineTrade:FireServer(', 'SendRequest:FireServer(',
            'PostAsync(', 'TeleportService', 'pdiddler4_balancer_',
            'pdiddler_PART4_BALANCER_', 'highestOwn(', 'minProfit = 15',
        )
        for filename, source in ((str(NATIVE), self.native),
                                 (str(OP), self.op),
                                 (str(BOOT), self.boot)):
            for token in forbidden:
                with self.subTest(file=filename, forbidden=token):
                    self.assertNotIn(token, source)
        self.assertIn('OfferItem:FireServer(rawId,"Weapons")', self.io)
        self.assertIn('PROTECTED_GINGERSCOPE_OUTGOING', self.io)
        self.assertIn('supervisedGate.checkOutbound', self.io)

    def test_exact_pins_and_no_external_trading_modules(self) -> None:
        self.assertEqual(self.native.count('loadFrozen("'), 10)
        for marker in (
            "9138751b5a57415939ffa1618ac57811d7c8ec7b",
            "af84b23173620b03e919187b08cd352c101ba4ea",
            "27e061555321c6a87bdd835ce3d1ff557443a909",
        ):
            self.assertIn(marker, self.native)
        self.assertEqual(self.native.count('game:HttpGet('), 1)
        self.assertNotIn('PDIDDLER_SUPERVISED_FOUR_SLOT_PILOT', self.native)
        self.assertIn('PDIDDLER_SUPERVISED_P3_ONE_ITEM_NATIVE', self.native)
        self.assertIn('targetStillExact()', self.native)

    def test_no_false_server_profit_or_completion_claim(self) -> None:
        for source in (self.native, self.op):
            for token in ('authorizesAccept=false', 'serverCompletionProven=false',
                          'mayReportProfit=false', 'maySendDiscordWebhook=false',
                          'tradeOutcome="UNKNOWN"'):
                self.assertIn(token, source)

    def test_live_test_is_distinct_from_completed_p3_proof(self) -> None:
        self.assertNotIn('function guide:showItem', self.original)
        self.assertIn('ui.offer=action("ApproveOneItem"', self.native)
        self.assertIn('ui.offer.Visible=canOffer', self.native)


if __name__ == "__main__":
    unittest.main()
