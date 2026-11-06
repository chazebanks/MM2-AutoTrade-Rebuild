"""Python-primary Stage22 test runner and runtime boundary audit.

The actual Lua/Luau placement logic is exercised via Lua 5.4 subprocess,
not reimplemented as a second, divergent Python strategy.
"""
from pathlib import Path
import shutil
import subprocess
import unittest

BASE = Path(__file__).resolve().parents[1] / "new_part4"

class PlacementContractTests(unittest.TestCase):
    def test_new_offer_executor_has_no_native_side_effects(self):
        text=(BASE / "p4_offer_executor.lua").read_text()
        for invalid in ("game:GetService",":FireServer(","AcceptTrade",
                        "VirtualInputManager","request(","http_request","loadstring("):
            self.assertNotIn(invalid,text)
        self.assertIn('validatePermit',text)
        self.assertIn('s.mode="SENT"',text)
        self.assertIn('return "VERIFIED"',text)

    def test_native_adapter_does_not_accept_or_report_completion(self):
        text=(BASE / "p4_native_offer.lua").read_text()
        for invalid in ("AcceptTrade", "DeclineTrade:FireServer",
                        "quoteSafe=true", "authorizesAccept=true", "webhookUrl"):
            self.assertNotIn(invalid,text)
        self.assertIn("insertion-token-consumed",text)
        self.assertIn("ATTEMPT_UNCERTAIN",text)
        self.assertIn("ownInventory",text)

    def test_live_preview_still_does_not_enable_placement(self):
        entry=(BASE / "REPLACEMENT_INTEGRATION_PREVIEW.lua").read_text()
        self.assertIn('p4.run(I.scanner,I.profile)',entry)
        self.assertNotIn('p4.run(I.scanner,I.profile,',entry)
        self.assertNotIn('PDIDDLER_ALLOW_REPLACEMENT_PREVIEW=true',entry)
        self.assertNotIn('OfferItem:FireServer',entry)

    def test_no_reintroduction_of_old_profit_balancer(self):
        root=(BASE / "PDIDDLER_PART4_REPLACEMENT.lua").read_text()
        self.assertNotIn('pdiddler4_balancer_SUPREME_v11',root)
        self.assertNotIn('minimumProfit=15',root)
        self.assertIn('readModule("p4_offer_executor")',root)
        self.assertIn('readModule("p4_native_offer")',root)

    def test_protected_default_requires_external_permit_and_sender(self):
        root=(BASE / "PDIDDLER_PART4_REPLACEMENT.lua").read_text()
        self.assertIn('placement.enabled==true',root)
        self.assertIn('type(placement.validatePermit)=="function"',root)
        self.assertIn('type(placement.nextProposal)=="function"',root)
        self.assertIn('type(placement.sendOnce)=="function"',root)
        self.assertIn('S.placementStatus="NOT_ENABLED"',root)

    def test_owns_and_matches_before_sending(self):
        adapter=(BASE / "p4_native_offer.lua").read_text()
        for exact in ('intent.checkerId','intent.page','intent.theirSig',
                      'intent.ourSig','intent.session','found.qty',
                      'obs.ourAccepted~=false','obs.theirAccepted~=false',
                      'sendOnce'):
            self.assertIn(exact,adapter)

    def test_post_offer_delta_is_required(self):
        core=(BASE / "p4_offer_executor.lua").read_text()
        self.assertIn('same(actual,p.expected)',core)
        self.assertIn('o.ourSig~=p.intent.ourSig',core)
        self.assertIn('if not same(actual,p.before)',core)
        self.assertIn('no-visible-add-confirmation',core)

    @unittest.skipUnless(shutil.which("lua5.4"),"Lua 5.4 available in CI")
    def test_real_lua_native_mock_contracts(self):
        for name,expect in (
            ("test_p4_offer_placement.lua","Stage22 single-item placement"),
            ("test_p4_replacement_offer_integration.lua",
             "Stage22 native-mock replacement integration"),
        ):
            completed=subprocess.run(
                ["lua5.4",str(BASE/"tests"/name),str(BASE)],
                cwd=str(BASE.parents[1]),capture_output=True,text=True,
                timeout=10,check=False)
            self.assertEqual(completed.returncode,0,
                name+" failed:\n"+completed.stderr+"\n"+completed.stdout)
            self.assertIn(expect,completed.stdout)

if __name__=="__main__":
    unittest.main()
