"""Static release-critical boundaries, in addition to real native Lune tests."""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1] / "system1"
NATIVE = (ROOT / "SYSTEM1_STEP2_PUBLIC_P3P4_NATIVE.lua").read_text()
P3 = (ROOT / "system1_step2_public_p3_single_send.lua").read_text()
GATE = (ROOT / "system1_step2_public_target_gate.lua").read_text()
CTRL = (ROOT / "system1_step2_public_handoff_controller.lua").read_text()


class Step2PublicBoundaries(unittest.TestCase):
    def test_no_accept_or_teleport_or_item_offer_actions_in_native(self):
        for forbidden in (
            "AcceptTrade:FireServer", "OfferItem:FireServer",
            "TeleportService", "TeleportToPlaceInstance",
            "PromptPurchase", "DiscordWebhook",
            "io.offerItem(", "io.accept(",
        ):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, NATIVE)

    def test_public_session_caps_and_strict_p3_authorization(self):
        for required in (
            'maxTargets=3',
            'allowRealP3RequestRotation=true',
            'finalAcceptMustRemainManual=true',
            'noItemOffers=true',
            'noServerHop=true',
            'explicitArm=true',
            'testDurationSeconds=220',
            'P3_AMBIGUOUS_SEND_STOP',
        ):
            with self.subTest(required=required):
                self.assertIn(required, NATIVE + CTRL)

    def test_no_unbounded_retry_in_step2_p3(self):
        self.assertIn('MaxUnavailableChecks=1', P3)
        self.assertIn('S.failStop=true', P3)
        self.assertIn('S.startGateOpen=false', P3)
        self.assertIn('cancel-unverified', P3)
        self.assertIn('pendingVisible=function()', P3)

    def test_real_roblox_players_type_accepted(self):
        self.assertIn('(type(players)~="table" and type(players)~="userdata")', GATE)
        self.assertIn('Players', NATIVE)
        self.assertIn('GetPlayerByUserId', GATE)
        self.assertIn('DUPLICATE_SCANNER_USER_ID', GATE)

    def test_immutable_revision_hashes_pinned(self):
        pins = re.findall(r'^local (MAIN|GATE|P3|CTRL)="([a-f0-9]{40})"$',
                          NATIVE, re.MULTILINE)
        self.assertEqual({k for k, _ in pins}, {"MAIN", "GATE", "P3", "CTRL"})
        self.assertEqual(len(set(value for _, value in pins)), 4)
        self.assertIn('https://raw.githubusercontent.com/chazebanks/', NATIVE)

    def test_controller_has_no_fabricated_settlement(self):
        for required in (
            'serverCompletionProven=false',
            'verifiedCompletedTrades=0',
            'finalAcceptEverAttempted=false',
            'authorizesOffer=false',
            'actualOffers=0',
            'actualTeleports=0',
            'mayReportProfit=false',
            'maySendDiscordWebhook=false',
        ):
            self.assertIn(required, CTRL)

    def test_client_only_success_requires_multiple_contacts_and_bound_close(self):
        self.assertIn('observed.distinctContacts>=2 and closedCount>=1', CTRL)
        self.assertIn('CLIENT_ROTATION_ONLY_HANDOFF_NOT_PROVEN', CTRL)
        self.assertIn('P4_DECLINE_FAILED_OR_UNCONFIRMED', CTRL)

if __name__ == "__main__":
    unittest.main()
