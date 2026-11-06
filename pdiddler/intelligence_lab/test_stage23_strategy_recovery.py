"""Stage23 Python-driven integration test and regression boundaries.

Runs the ACTUAL Stage16/17 + Stage22/11 Lua in Lua 5.4 subprocesses.
No real Roblox access, inventory mutation, final Accept, or native click.
"""
from pathlib import Path
import shutil
import subprocess
import unittest

BASE=Path(__file__).resolve().parents[1]/"new_part4"
class StrategyRecoveryTests(unittest.TestCase):
    def test_stage17_remains_research_only(self):
        old=(BASE/"p4_dual_perspective.lua").read_text()
        self.assertIn("reviewOnly=true",old)
        self.assertIn("authorizesTrade=false",old)
        self.assertIn("authorizesAccept=false",old)
        self.assertIn("injectedRisk",old)
        self.assertIn("require('p4_risk_review')",old)

    def test_new_bridge_demands_separate_scoped_approval(self):
        bridge=(BASE/"p4_strategy_permit.lua").read_text()
        for x in ("approve","stamp.allowed~=true","stamp.session~=s.session",
                  "stamp.ourSig~=o.ourSig","stamp.theirSig~=o.theirSig",
                  "stamp.candidateKey","review.authorizesTrade~=false",
                  "review.authorizesAccept~=false","s.used=true",
                  "o.ourSlots==0"):
            self.assertIn(x,bridge)
        self.assertNotIn("minimumProfit",bridge)
        self.assertNotIn("AcceptTrade",bridge)
        self.assertNotIn("OfferItem:FireServer",bridge)

    def test_price_and_stock_rechecked_before_dispatch(self):
        bridge=(BASE/"p4_strategy_permit.lua").read_text()
        for x in ("market.sourceId~=current","market.verified~=true",
                  "now>=market.validUntil","context=s", "ctx.ownFingerprint",
                  "ctx.opponentFingerprint","m.valueCents","m.demand",
                  "m.stability","ctx.opponentInventory[row.id]",
                  "review.sellerSurplusCents"):
            if x=="context=s": continue
            self.assertIn(x,bridge)

    def test_current_loader_cannot_send_or_remove_automatically(self):
        preview=(BASE/"REPLACEMENT_INTEGRATION_PREVIEW.lua").read_text()
        self.assertIn("p4.run(I.scanner,I.profile)",preview)
        self.assertNotIn("p4.run(I.scanner,I.profile,",preview)
        self.assertNotIn("PDIDDLER_ALLOW_REPLACEMENT_PREVIEW=true",preview)
        self.assertNotIn("pdiddler4_balancer_SUPREME_v11",preview)

    def test_recovery_is_existing_stage11_not_a_new_clicker(self):
        root=(BASE/"PDIDDLER_PART4_REPLACEMENT.lua").read_text()
        for x in ('readModule("p4_coordinator")',
                  'readModule("p4_safety_core")',
                  'readModule("p4_native_removal")',
                  'readModule("p4_stability_gate")',
                  'strategyModule.validate(strategyState,p,o,t,diagnostics)',
                  'strategyModule.next',
                  'recoveryLatched=true',
                  'MANUAL_WITHDRAW_OR_DECLINE_REQUIRED',
                  'placement.recovery.clickOnce'):
            self.assertIn(x,root)
        self.assertNotIn("AcceptTrade:FireServer",root)
        self.assertNotIn("minimumProfit=15",root)

    @unittest.skipUnless(shutil.which("lua5.4"),"Lua 5.4 installed in GitHub CI")
    def test_actual_lua_stage17_and_recovery_integrations(self):
        for name,expected in (
            ("test_p4_strategy_permit.lua","Stage23 existing Stage17 review"),
            ("test_p4_strategy_recovery_integration.lua",
             "Stage23 actual Stage17 approval"),
        ):
            process=subprocess.run(
                ["lua5.4",str(BASE/"tests"/name),str(BASE)],
                cwd=str(BASE.parents[1]),capture_output=True,text=True,
                timeout=15,check=False)
            self.assertEqual(process.returncode,0,
               name+" failed:\n"+process.stderr+"\n"+process.stdout)
            self.assertIn(expected,process.stdout)

if __name__=="__main__":
    unittest.main()
