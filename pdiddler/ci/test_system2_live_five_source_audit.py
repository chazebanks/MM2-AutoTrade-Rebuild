"""Static fail-closed contract for the NEW System2 live-five controller/native harness.
Do not misstate a passing source audit as original-MM2 device proof.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
CTRL = ROOT / "pdiddler/system2/system2_live_five_controller.lua"
NATIVE = ROOT / "pdiddler/system2/SYSTEM2_LIVE_FIVE_MAIN_NATIVE.lua"
LUA_TEST = ROOT / "pdiddler/ci/test_system2_live_five_controller.lua"
HISTORIC_ARM8_CTRL = "064d37b881bcf08d02f6c5c902bb623c9e367507"
HISTORIC_ARM8_NATIVE_BLOB = "f39de9264d4fd45ff2526815e69db516d8fd1d68"

class SourceContract(unittest.TestCase):
    def setUp(self):
        self.c=CTRL.read_text()
        self.n=NATIVE.read_text()
        self.t=LUA_TEST.read_text()

    def test_five_different_strategy_scenarios(self):
        for name in ("DISCORD_EVENT_PROVENANCE",
            "PARTNER_RESPONSE_REVISIONS",
            "BILATERAL_ALTERNATIVE_COMPARISON",
            "GINGERSCOPE_GROWTH_STRUCTURAL_GATES",
            "RESEARCH_REVISION_TERMINAL_STOP"):
            self.assertIn(name,self.c)
        self.assertIn("maxRounds=5",self.c)
        self.assertIn("explicitFiveLiveConsent",self.c)
        self.assertNotIn("ALL_EIGHT_CLIENT_SCENARIOS_VERIFIED",self.c)

    def test_market_and_discord_are_not_false_live_successes(self):
        self.assertIn('"BLOCKED_PREREQUISITE","LIVE_V2_DISCORD_INGRESS_NOT_VERIFIED"',self.c)
        self.assertIn('"BLOCKED_PREREQUISITE","PUBLISHER_AND_LIQUIDITY_AUTHORITY_UNPROVEN"',self.c)
        self.assertIn('"BLOCKED_PREREQUISITE","GROWTH_VALUE_AND_SELLER_WILLINGNESS_UNPROVEN"',self.c)
        for text in ("discordV2DeliveryVerified=false",
                "realMarketSourceAuthenticated=false",
                "serverCompletionProven=false",
                "mayUseForStrategyLearning=false"):
            self.assertIn(text,self.c)

    def test_controller_never_directly_acts_on_game_or_discord(self):
        for dangerous in (":FireServer(", ":InvokeServer(",
            "HttpGet(", "PostAsync(", "AcceptTrade(", "TeleportService",
            "DiscordWebhook", "setclipboard(", "loadstring("):
            self.assertNotIn(dangerous,self.c)
        self.assertIn("api.startEpoch",self.c)
        self.assertIn("api.offerApproved",self.c)
        self.assertIn("api.removeOwnOne",self.c)
        self.assertIn("api.decline",self.c)
        self.assertIn("api.stopAll",self.c)

    def test_native_separate_owner_local_alt_and_one_arm(self):
        self.assertIn('PDIDDLER_SYSTEM2_LIVE_FIVE_OWNER',self.n)
        self.assertIn('PDIDDLER_SYSTEM1_MAIN_AUTO_OWNER',self.n)
        self.assertIn('E.PDIDDLER_SYSTEM2_ALT_NAME',self.n)
        self.assertIn('armRounds(5)',self.n)
        self.assertNotIn('armRounds(8)end',self.n)
        self.assertNotIn('ALT_NAME="venossgaming90190"',self.n)
        self.assertIn('if requestedRounds~=5',self.n)
        self.assertIn("controller.status().phase~=\"EXPECTED_TERMINAL_STOP\"",self.n)

    def test_native_source_pin_and_original_protected_io(self):
        self.assertRegex(self.n, r'local CTRL="[0-9a-f]{40}"')
        self.assertIn('loadPinned(CTRL,"system2/system2_live_five_controller.lua"',self.n)
        for item in ('pdiddler4_tradeio_supervised_v2.lua',
                     'supervised_p3_startup_supervisor.lua',
                     'supervised_p3_continuous_watchdog.lua',
                     'pdiddler3_outgoing_single_send_epoch.lua'):
            self.assertIn(item,self.n)
        self.assertIn('finalAcceptDisabled=true',self.n)
        self.assertIn('noAutomaticAcceptAcknowledged=true',self.n)
        self.assertIn('io.decline(',self.n)
        self.assertNotIn('io.accept(',self.n)

    def test_original_exact_slot_vs_copy_boundary(self):
        self.assertIn("#rows>4",self.c)
        self.assertIn("integer(v.quantity,1,1000000)",self.c)
        self.assertIn('target(v.name) or target(v.id)',self.c)
        self.assertIn("survivor(baseline,ob.ours)",self.c)

    def test_one_terminal_stop_after_fifth_revision(self):
        self.assertIn('phase="EXPECTED_TERMINAL_STOP"',self.c)
        self.assertIn('note="EXPECTED_REVISION_FAILSTOP_NO_FURTHER_ACTION"',self.c)
        self.assertIn("if terminal then return receipt()",self.c)
        self.assertIn("pcall(api.stopAll);publish()",self.c)

    def test_reports_never_export_item_names_or_identity(self):
        for token in ("discordV2Delivered=false", "clientOutcomeOnly=true",
                      "offerRevisionsObserved=", "candidateOffersClientObserved=",
                      "firstFailureScenario=firstFailure"):
            self.assertIn(token,self.c)
        body=self.c.split("local function receipt()",1)[1].split("local function publish()",1)[0]
        for secret in ("name=first", "id=first", "jobId=", "username=",
                       "partnerUserId=", "ownedWeapons=", "remotePayload="):
            self.assertNotIn(secret,body)

    def test_actual_lua_source_bound_harness_exists(self):
        self.assertIn('dofile("pdiddler/system2/system2_live_five_controller.lua")',self.t)
        self.assertIn("poisonPartner=2",self.t)
        self.assertIn("poisonAccepted=1",self.t)
        self.assertIn("poisonFiveSlots=2",self.t)
        self.assertIn("clientClosedWindows",self.t)

if __name__=="__main__":
    unittest.main()
