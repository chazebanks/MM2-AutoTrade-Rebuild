"""Ensure one-server harness composes exact approved parts, never bypasses safety."""
import pathlib
import re
import unittest

BASE = pathlib.Path(__file__).resolve().parents[1] / "system1"
NATIVE = (BASE / "SYSTEM1_ONE_SERVER_COMBINED_NATIVE.lua").read_text()
STAGE2 = (BASE / "SYSTEM1_COMBINED_STEP2_BOUND_EPOCH_NATIVE.lua").read_text()
ORIGINAL_STAGE2 = (BASE / "SYSTEM1_STEP2_PUBLIC_P3P4_NATIVE.lua").read_text()
CTRL = (BASE / "system1_one_server_transition_controller.lua").read_text()


class OneServerComposedSafety(unittest.TestCase):
    def test_only_pinned_independent_test_scripts_and_transition(self):
        pins = dict(re.findall(r'^local (FIRST|SECOND|CONTROL)="([a-f0-9]{40})"$',
                               NATIVE, re.MULTILINE))
        self.assertEqual(set(pins), {"FIRST", "SECOND", "CONTROL"})
        self.assertEqual(
            pins["FIRST"], "b24661781e72e3dec759960d2f4b423841961c8b")
        self.assertEqual(
            pins["SECOND"], "b7d98b9b0815f72bff63fe7b58b8c92c59c3e0d7")
        self.assertEqual(
            pins["CONTROL"], "8f6b736ca05bb529bf6dc78864ad080fca65d0b8")

    def test_stage2_original_io_code_is_byte_identical_after_preflight(self):
        anchor = 'local Players=game:GetService("Players")'
        self.assertIn(anchor, ORIGINAL_STAGE2)
        self.assertIn(anchor, STAGE2)
        self.assertEqual(
            ORIGINAL_STAGE2.split(anchor, 1)[1],
            STAGE2.split(anchor, 1)[1],
            "Combined Step2 must not modify original public trading logic",
        )

    def test_retired_epoch_transition_is_not_reset_or_unsafe_bypass(self):
        for required in (
            'transition.retiredP3Epoch==E.PDIDDLER_OUTGOING_SESSION',
            'transition.status=="STEP1_VERIFIED_CLOSED"',
            'transition.used==false',
            'E.PDIDDLER_SYSTEM1_STEP1_RECOVERY_OWNER==nil',
            'E.PDIDDLER_PART4_SESSION==nil',
            'transition.used=true',
            'E.PDIDDLER_SYSTEM1_COMBINED_TRANSITION_TOKEN=nil',
        ):
            with self.subTest(required=required):
                self.assertIn(required, STAGE2)
        self.assertNotRegex(
            NATIVE + "\n" + STAGE2,
            r"PDIDDLER_OUTGOING_SESSION\s*=\s*(?:nil|0|1)\b",
        )

    def test_one_game_job_one_live_controller_client_test_only(self):
        for required in (
            'game.JobId==THIS_JOB',
            'E.PDIDDLER_SYSTEM1_STEP1_RECOVERY_USED_JOB~=THIS_JOB',
            'E.PDIDDLER_PART4_SESSION~=nil',
            'not noTradeOrPending()',
            'quiescenceChecks=quiescenceProof',
            'originalP3EpochNeverReset=true',
            'recoveryBatchAuthorized~=true',
            'CLIENT_TEST_SEQUENCE_COMPLETE',
            'PUBLIC_CLIENT_ROTATION_HANDOFF_PASS',
            'type(r.publicRequestDiagnostic)=="table"',
        ):
            with self.subTest(required=required):
                self.assertIn(required, NATIVE + CTRL)

    def test_no_final_accept_trades_teleport_integration(self):
        for forbidden in (
            'AcceptTrade:FireServer', 'OfferItem:FireServer',
            'TeleportService', 'TeleportToPlaceInstance',
            'io.accept(', 'io.offerItem(',
        ):
            self.assertNotIn(forbidden, NATIVE + CTRL)
        for required in (
            'finalAcceptEverAttempted=false',
            'serverCompletionProven=false',
            'verifiedCompletedTrades=0',
            'clientOnly=true',
        ):
            self.assertIn(required, CTRL)

    def test_source_names_and_original_test_integrity(self):
        for part in (
            "SYSTEM1_STEP1_ALT_DYNAMIC_RECOVERY_NATIVE.lua",
            "SYSTEM1_COMBINED_STEP2_BOUND_EPOCH_NATIVE.lua",
            "system1_one_server_transition_controller.lua",
        ):
            self.assertIn(part, NATIVE)
        self.assertTrue((BASE / "SYSTEM1_STEP1_ALT_DYNAMIC_RECOVERY_NATIVE.lua").exists())
        self.assertTrue((BASE / "SYSTEM1_STEP2_PUBLIC_P3P4_NATIVE.lua").exists())


if __name__ == "__main__":
    unittest.main()
