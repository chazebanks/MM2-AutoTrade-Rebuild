"""Security/immutable source audit of C9 market-bound Stage119 research fork.
This is NOT actual-device attestation or real trade permission.
"""
from pathlib import Path
import hashlib
import unittest

ROOT=Path(__file__).resolve().parents[2]
STAGE119=ROOT/"pdiddler/supervised/STAGE119_P3_BOUND_READONLY_NATIVE.lua"
LEASE_ONLY=ROOT/"pdiddler/supervised/STAGE119_C9_READONLY_RESEARCH_NATIVE.lua"
MARKET=ROOT/"pdiddler/supervised/STAGE119_C9_MARKET_READONLY_NATIVE.lua"
START=ROOT/"pdiddler/supervised/STAGE119_C9_MARKET_READONLY_START.lua"
COMPOSER=ROOT/"pdiddler/system2/native_c9_original_host_market_composer.lua"

def git_blob(p):
    b=p.read_bytes()
    return hashlib.sha1(b"blob "+str(len(b)).encode()+b"\0"+b).hexdigest()

class C9MarketNativeIntegrity(unittest.TestCase):
    def test_immutable_original_and_prior_stage119_sources(self):
        self.assertEqual(git_blob(STAGE119),"fc25514564e78d390b089742eb4e7da7508c12fa")
        self.assertEqual(git_blob(LEASE_ONLY),"89b1c1cb813cae20e0c52c2858359a2749267f1f")
        self.assertEqual(git_blob(MARKET),"8ad6b63989c6821e31a589c282d6c118c2fc8604")
        self.assertEqual(git_blob(COMPOSER),"50943c08bdb6617b9630159ce329211d11c4caa5")
    def test_loader_matches_executable_pinned_git_revision(self):
        script=START.read_text()
        for token in (
            "82e79811b8247b05e4dd2a49a3a7dce2ba5e76d2",
            "STAGE119_C9_MARKET_READONLY_NATIVE.lua",
            "plan.operatorConfirmedReadOnlyInventoryRpc~=true",
            "plan.understandsCurrentSourceMayExpire~=true",
            "plan.explicitOperatorWantsC9Research~=true",
            "plan.understandsArmSendsP3TradeRequest~=true",
            "plan.consentVerifiedForNamedAlt~=true",
            "plan.noWeaponAddOrRemoveTests~=true",
            "type(runtime.c9ReadOnlyMarketPreflight)~=\"function\"",
            "runtime.arm~=nil", "runtime.accept~=nil",
        ):
            self.assertIn(token,script)
        self.assertNotIn("venossgaming90190",script)
        self.assertNotIn("/main/",script)
    def test_fork_executes_only_pinned_reviewed_c3_c4_c9_modules(self):
        runner=MARKET.read_text()
        for v in (
           "cfg.c9MarketReadOnly~=true",
           "cfg.operatorConfirmedReadOnlyInventoryRpc~=true",
           "364f3d17e8ff09919096f5eff6b4d32a340b380d",
           "native_c9_original_host_market_composer.lua",
           "native_c9_immutable_market_research_gate.lua",
           "native_c9_device_readonly_preflight.lua",
           "rawScanner.getOwnInventory",
           "native_bilateral_attractiveness_shadow.lua",
           "c9ReadOnlyMarketPreflight=c9ReadOnlyMarketPreflight",
           "C9_REAL_PUBLIC_SOURCE_EXPIRED_OR_CLOCK_CHANGED",
        ):
            if v=="C9_REAL_PUBLIC_SOURCE_EXPIRED_OR_CLOCK_CHANGED":
                self.assertIn(v,(ROOT/"pdiddler/system2/native_c9_immutable_market_research_gate.lua").read_text())
            else: self.assertIn(v,runner)
        self.assertNotIn("ALT manually ADD then REMOVE ONE",runner)
        self.assertNotIn("MAIN offers NOTHING",runner)
        self.assertIn("NO ADD/REMOVE, NO FINAL ACCEPT",runner)
    def test_research_only_modifications_do_not_grant_trade_control(self):
        runner=MARKET.read_text()
        start=START.read_text()
        for source in (runner,start,COMPOSER.read_text()):
            for forbidden in (
               "OfferItem:FireServer(", "AcceptTrade:FireServer(",
               "DeclineTrade:FireServer(", "TeleportService:Teleport(",
               "maySendDiscordWebhook=true", "authorizesTrade=true",
               "authorizesAccept=true", "liveLossBudgetApproved=true",
            ):
                self.assertNotIn(forbidden,source)
        self.assertNotIn("supervisor.arm(",start)
        self.assertNotIn("c9ReadOnlyMarketPreflight=c9HostHandle",runner)
        self.assertNotIn("return c9HostHandle",runner)
        self.assertIn("consentedToReadOnlyInventoryRpc=true",runner)
        self.assertIn("type(rawScanner.getOwnInventory)~=\"function\"",runner)

if __name__=="__main__":unittest.main()
