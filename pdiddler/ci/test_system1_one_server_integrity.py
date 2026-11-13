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
            pins["SECOND"], "f2c6b9ab11175885692027658038862da77be1cd")
        self.assertEqual(
            pins["CONTROL"], "2c822f3519739d075eab3ec0f4e76830ad0da715")

    def test_combined_step2_only_changes_supervision_diagnostics(self):
        """Protect the proven public trading flow from unrelated changes.

        The original Stage2 is byte identical after its preflight EXCEPT
        the new terminal-only watchdog diagnostics/controller pin.
        """
        anchor = 'local Players=game:GetService("Players")'
        self.assertIn(anchor, ORIGINAL_STAGE2)
        self.assertIn(anchor, STAGE2)
        combined = STAGE2.split(anchor, 1)[1]
        original = ORIGINAL_STAGE2.split(anchor, 1)[1]

        def restore_region(src, start, end):
            i = src.index(start)
            j = src.index(end, i + len(start))
            i_orig = original.index(start)
            j_orig = original.index(end, i_orig + len(start))
            return src[:i] + original[i_orig:j_orig] + src[j:]

        combined = combined.replace(
            'local CTRL="4e45ece155a9efb31bdc377a08ed91ea7e4d366a"',
            'local CTRL="77d83cb9c1abf7f5991c7408ce006701484844b8"')
        combined = combined.replace(
            '"system1/system1_combined_step2_handoff_controller.lua"',
            '"system1/system1_step2_public_handoff_controller.lua"')
        combined = restore_region(
            combined, 'local haltReason=nil', 'local function writeReceipt')
        combined = restore_region(
            combined, '  onStatus=function(result)', ' },{\n  spawn=')
        combined = restore_region(
            combined, 'local function observe()', ' local observed={')
        combined = restore_region(
            combined, ' if haltReason and observed.fault==nil then',
            ' if status.status=="STOPPED" then')
        self.assertEqual(
            combined, original,
            "Unexpected modification outside combined watchdog diagnostics")

        new_controller = (
            BASE / "system1_combined_step2_handoff_controller.lua"
        ).read_text()
        old_controller = (
            BASE / "system1_step2_public_handoff_controller.lua"
        ).read_text()
        self.assertIn('P3_WATCHDOG_HEARTBEAT_MISSING', new_controller)
        self.assertIn('P3_SESSION_EPOCH_CHANGED', new_controller)
        self.assertIn('P3_WATCHDOG_BLOCKED', new_controller)
        self.assertIn('return stop(observed.fault,observed.possibleSideEffect)',
                      new_controller)
        self.assertNotIn('return stop(observed.fault,observed.possibleSideEffect)',
                         old_controller)
        self.assertIn('firstFailureEvidence=', new_controller)

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

    def test_cold_lobby_preflight_does_not_start_original_trader_early(self):
        for token in (
            'PREFLIGHT_ALT_NOT_PRESENT',
            'PREFLIGHT_ALT_IDENTITY_UNVERIFIED',
            'PREFLIGHT_PLAYERGUI_NOT_READY',
            'PREFLIGHT_CAMERA_NOT_READY',
            'PREFLIGHT_COMPETING_CONTROLLER',
            'REQUEST_POPUP_ACTIVE',
            'TRADE_WINDOW_ACTIVE',
            'preflight.stableReadinessChecks>=4',
            'engine.preflightAbort(',
            'task.wait(0.2)',
            'pcall(readiness)',
            'PREFLIGHT_READ_EXCEPTION',
        ):
            with self.subTest(token=token):
                self.assertIn(token, NATIVE)
        self.assertIn('PREFLIGHT_"..', NATIVE)
        self.assertIn('COMBINED_STEP1_PREFLIGHT_NOT_READY', CTRL)

    def test_step1_original_startup_error_is_not_lost_or_stale(self):
        for required in (
            'startFailure=step1StartFailure',
            'priorStep1Json=E.PDIDDLER_SYSTEM1_MAIN_AUTO_LAST_JSON',
            'raw~=priorStep1Json',
            'Http:JSONDecode(raw)',
            'SOURCE_PINNED_FETCH_FAILED',
            'SCRIPT_EXECUTION_FAILED',
            'SCRIPT_RETURNED_NO_RUNNER',
        ):
            self.assertIn(required, NATIVE)
        self.assertIn('step1Failure=childFault(sourceFailure)', CTRL)

    def test_live_step1_status_vs_original_serialized_json(self):
        """The real Step1 controller adds safety fields only to copied JSON."""
        step1_controller = (
            BASE / "system1_step1_alt_recovery_controller.lua"
        ).read_text()
        step1_native = (
            BASE / "SYSTEM1_STEP1_ALT_DYNAMIC_RECOVERY_NATIVE.lua"
        ).read_text()
        self.assertIn('function controller.status()return receipt()end',
                      step1_controller)
        self.assertIn('data.finalAcceptEverAttempted=false', step1_native)
        self.assertIn('data.verifiedCompletedTrades=0', step1_native)
        self.assertNotIn('finalAcceptEverAttempted=false',
                         step1_controller.split("local function report",1)[1]
                         .split("local function integer",1)[0])
        self.assertIn('step1VerifiedReceipt=step1VerifiedReceipt', NATIVE)
        self.assertIn('raw~=priorStep1Json', NATIVE)
        self.assertIn('exported.finalAcceptEverAttempted~=false', CTRL)
        self.assertIn('exported.verifiedCompletedTrades~=0', CTRL)
        self.assertIn('exported.actions.offersClientVisible', CTRL)
        self.assertIn('published.closedBy~=v.closedBy', CTRL)

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
