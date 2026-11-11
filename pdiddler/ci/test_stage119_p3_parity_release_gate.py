"""Stage119 V2 strict *release gate*, derived from REAL MAIN iPad PR221 flow.

This file intentionally starts RED against the superseded PR225 manual-open
runner. It must pass only after a new P3->P4 source-bound native adaptation
exists and its LIVE FROZEN dependency behavior has its own Lune integration
tests. Static text checks here are NECESSARY, NEVER sufficient.
"""
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]
OLD=ROOT/"pdiddler/supervised/SUPERVISED_P3_STAGE101_IDENTITY_NATIVE.lua"
INVALID=ROOT/"pdiddler/supervised/STAGE119_LASTOFFER_NATIVE.lua"
INVALID_CONTROLLER=ROOT/"pdiddler/supervised/stage119_lastoffer_native_controller.lua"
NEW=ROOT/"pdiddler/supervised/STAGE119_P3_BOUND_READONLY_NATIVE.lua"
NEW_LOADER=ROOT/"pdiddler/supervised/STAGE119_P3_BOUND_READONLY_START.lua"
NEW_MOCK=ROOT/"pdiddler/ci/stage119_p3_bound_original_mocks.luau"
KNOWN_GOOD=(
    "supervisor.arm({",
    "explicitUserAuthorization=true",
    "allowRealP3RequestRotation=true",
    "finalAcceptMustRemainManual=true",
    "supervisor.currentBoundReadOnly",
    "supervisor.isP3Paused()",
    "E.PDIDDLER_OUTGOING_SESSION",
    "P4_TWO_SIDED_CLIENT_SNAPSHOT",
    "io.trade()",
    "watcher.isReady()",
    'ui.arm=action("ArmP3","ARM P3"',
    'ui.stop=action("StopP3","STOP / COPY"',
    "suppressLegacyScannerGUI()",
)
OWNER_DENIAL=(
    "E.PDIDDLER_SUPERVISED_P3_NATIVE_OWNER",
    "E.PDIDDLER_OUTGOING_SESSION",
    "E.PDIDDLER_PART4_SESSION",
    "E.PDIDDLER_PART4_CONTROLLER_ACTIVE",
    "E.PDIDDLER_OUTGOING_CONTROLLER_ACTIVE",
    "E.PDIDDLER_AUTOTRADE_ACTIVE",
)
NATIVE_TOKENS=(
    "stage118_lastoffer_gui_correlation.lua",
    "trade_lastoffer_client_audit.lua",
    "CLIENT_LASTOFFER_CHANGED_WITH_DIFFERENT_OFFER",
    "CLIENT_LASTOFFER_UNCHANGED_WITH_DIFFERENT_OFFER",
)
NEW_OWNER_DENIAL=(
    "E.PDIDDLER_STAGE119_LASTOFFER_OWNER",
    "E.PDIDDLER_STAGE119_LASTOFFER_USED_JOB",
)
UNSAFE_V1_TOKENS=(
    "MAIN manually opens trade with consenting ALT",
    "p3ArmObservedClient=false, -- this test is MANUAL ONLY",
)

class ProtectedStage119Parity(unittest.TestCase):
    def test_original_proved_contract_still_in_repository(self):
        text=OLD.read_text()
        for token in KNOWN_GOOD:
            self.assertIn(token,text,token)
        for token in OWNER_DENIAL:
            self.assertIn(token,text,token)

    def test_old_stage119_is_not_equivalent(self):
        old=INVALID.read_text()
        old_controller=INVALID_CONTROLLER.read_text()
        # Affirm the precise design defect this correction is for.
        self.assertIn("MAIN manually opens trade with consenting ALT",old_controller)
        self.assertIn("p3ArmObservedClient=false",old_controller)
        self.assertNotIn("supervisor.currentBoundReadOnly()",old)
        self.assertNotIn("supervisor.arm({",old)

    def test_new_runner_exists_and_preserves_p3_bound_contract(self):
        self.assertTrue(NEW.is_file(),
                        "RED: PR225 manual-open witness has no protected P3 replacement")
        text=NEW.read_text()
        for token in KNOWN_GOOD+OWNER_DENIAL+NEW_OWNER_DENIAL+NATIVE_TOKENS:
            self.assertIn(token,text,token)
        for token in (
            "pcall(supervisor.currentBoundReadOnly)",
            'snap.status~="CLIENT_UNPRICED_TWO_SIDED_SNAPSHOT"',
            "snap.partnerExactClientBound~=true",
            "snap.part3Paused~=true",
            "snap.part4TradeVisible~=true",
            "verifyPhysical(currentStage9Raw.our,snap.ours",
            "verifyPhysical(currentStage9Raw.their,snap.theirs",
            "UNEXPECTED_OR_DUPLICATE_CLIENT_EVENT",
        ):
            self.assertIn(token,text,token)
        for token in UNSAFE_V1_TOKENS:
            self.assertNotIn(token,text,token)

    def test_new_loader_and_real_native_p3_mock_exist(self):
        self.assertTrue(NEW_LOADER.is_file(), "RED: no frozen P3 ARM Stage119 loader")
        self.assertTrue(NEW_MOCK.is_file(), "RED: no actual P3/P4 Stage119 native Lune suite")
        loader=NEW_LOADER.read_text()
        self.assertIn("stage119LastOfferReadOnly=true",loader)
        self.assertIn("finalAcceptMustRemainManual=true",loader)
        native=NEW_MOCK.read_text()
        for token in (
            "currentBoundReadOnly", "P3_BOUND_LEASE",
            "ARM P3", "P4_TWO_SIDED_CLIENT_SNAPSHOT",
            "OnClientEvent", "stage118",
            "no safe", "UNKNOWN",
        ):
            self.assertIn(token,native,token)

if __name__=="__main__":
    unittest.main()
