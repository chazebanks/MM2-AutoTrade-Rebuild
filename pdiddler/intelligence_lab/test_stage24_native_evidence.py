"""Stage24 Python-first source/scanner evidence contract tests.

The actual Stage24 Lua adapter and Stage23 permit are executed in Lua5.4.
The native scanner is Luau and is checked by source-contract assertions;
no false claim of a real Roblox scan or trading authority is made.
"""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT=Path(__file__).resolve().parents[1]
MOD=ROOT/"new_part4"
SCANNER=ROOT/"presentation"/"pdiddler3_scanner_MODULE_v6_10_CURRENT_PRESENTATION.lua"

class NativeEvidenceTests(unittest.TestCase):
    def test_preserve_existing_scanner_with_only_publication_metadata(self):
        src=SCANNER.read_text()
        for token in ('local function scanOne(', 'stableCount>=requiredStable',
                      'scanPublicationSerial += 1',
                      'kind = "local-stable-scan-publication-v1"',
                      'jobId = game.JobId',
                      'playerUserId = p.UserId',
                      'fingerprint = inv.fingerprint',
                      'completedAtMono = os.clock()',
                      'sequence = scanPublicationSerial',
                      'scanProof = proof',
                      'function ScannerAPI.getRecord(userId)'):
            self.assertIn(token,src)
        self.assertNotIn("function ScannerAPI.newScanner",src)

    def test_old_preview_is_not_secretly_authorized(self):
        bootstrap=(MOD/"REPLACEMENT_INTEGRATION_PREVIEW.lua").read_text()
        self.assertIn("p4.run(I.scanner,I.profile)",bootstrap)
        self.assertNotIn("p4.run(I.scanner,I.profile,",bootstrap)
        self.assertNotIn('PDIDDLER_ALLOW_REPLACEMENT_PREVIEW=true',bootstrap)
        self.assertNotIn('minimumProfit=15',bootstrap)

    def test_real_market_source_fields_must_expire(self):
        context=(MOD/"p4_live_context.lua").read_text()
        for phrase in ("observedAtEpoch","expiresAtEpoch",
                       'prof.isFresh','prof.version',
                       'profile.get','price.supremeValue',
                       'price.demand','price.stability',
                       'return nil,"market-or-job-stale"'):
            self.assertIn(phrase,context)
        self.assertNotIn('isFresh=function() return true',context)
        self.assertNotIn('expiresAtEpoch=os.time()',context)

    def test_opponent_proof_is_from_existing_verified_scan(self):
        context=(MOD/"p4_live_context.lua").read_text()
        for phrase in ("getRecord","getVerificationState",
                       "v.scanning==true","v.retryScheduled==true",
                       'proof.sequence~=original.sequence',
                       'proof.jobId~=h.jobId',
                       'proof.fingerprint~=r.inv.fingerprint',
                       'mono-proof.completedAtMono>h.age',
                       'own-scan-stale-or-missing'):
            self.assertIn(phrase,context)
        self.assertNotIn('GetFullInventory',context)
        self.assertNotIn('InvokeServer',context)

    def test_context_is_optional_and_denies_default_runtime_actions(self):
        root=(MOD/"PDIDDLER_PART4_REPLACEMENT.lua").read_text()
        for phrase in ('config.nativeEvidence==true',
                       'readModule,"p4_live_context"',
                       'moduleE.refreshOwn',
                       'moduleE.build(stateE)',
                       'strategyOK=false',
                       'local placementEnabled=type(placement)=="table"',
                       'authorizesAccept=false'):
            self.assertIn(phrase,root)
        self.assertNotIn('AcceptTrade:FireServer',root)

    def test_current_opponent_decode_replaces_cached_stage23_diagnostics(self):
        bridge=(MOD/"p4_strategy_permit.lua").read_text()
        executor=(MOD/"p4_offer_executor.lua").read_text()
        replacement=(MOD/"PDIDDLER_PART4_REPLACEMENT.lua").read_text()
        self.assertIn('function M.validate(s,proposal,o,now,diagnostics)',bridge)
        self.assertIn('inspect,s,o,diagnostics,ctx,p.candidate',bridge)
        self.assertNotIn('inspect,s,o,p.diagnostics,ctx,p.candidate',bridge)
        self.assertIn('pcall(s.validatePermit,proposal,o,now,diagnostics)',executor)
        self.assertIn('offerCore.prepare(offerState,proposal,obs,now,diagnostics)',replacement)

    @unittest.skipUnless(shutil.which("lua5.4"),"CI installs Lua 5.4")
    def test_actual_lua_contracts(self):
        for filename,expected in (
            ("test_p4_live_context.lua","Stage24 existing-scanner-stamps-to-Stage17"),
            ("test_p4_strategy_permit.lua","Stage23 existing Stage17 review"),
            ("test_p4_strategy_recovery_integration.lua","Stage23 actual Stage17 approval"),
        ):
            result=subprocess.run(["lua5.4",str(MOD/"tests"/filename),str(MOD)],
               cwd=str(ROOT.parent),text=True,capture_output=True,timeout=15)
            self.assertEqual(result.returncode,0,
                filename+" failed:\n"+result.stdout+"\n"+result.stderr)
            self.assertIn(expected,result.stdout)

if __name__=="__main__":
    unittest.main()
