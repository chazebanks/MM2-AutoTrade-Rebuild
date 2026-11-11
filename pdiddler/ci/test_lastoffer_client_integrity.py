"""Read-only LastOffer protocol audit: source, historical boundary, real Lua checks."""
from __future__ import annotations

import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
MODULE = ROOT / 'pdiddler/intelligence_lab/trade_lastoffer_client_audit.lua'
LUA_TESTS = ROOT / 'pdiddler/tests/test_trade_lastoffer_client_audit.lua'
NATIVE = ROOT / 'pdiddler/supervised/SUPERVISED_P3_STAGE101_IDENTITY_NATIVE.lua'
START = ROOT / 'pdiddler/supervised/SUPERVISED_P3_STAGE101_READONLY_START.lua'


def blob(path: Path) -> str:
    data = path.read_bytes()
    return hashlib.sha1(f'blob {len(data)}\0'.encode() + data).hexdigest()


class LastOfferIntegrity(unittest.TestCase):
    def test_original_pr221_native_bytes_not_modified(self):
        self.assertEqual(blob(NATIVE), '46cff56b9f58fa8590a275dfd26f46cea0c5c9a6')
        self.assertEqual(blob(START), 'a1430dc26fc3d85fe2268a84a5fea475812b5002')

    def test_audit_cannot_trade_or_promote_unauthenticated_token(self):
        code = MODULE.read_text(encoding='utf-8')
        for forbidden in (
            'FireServer(', 'InvokeServer(', 'HttpGet(', 'PostAsync(',
            'setclipboard(', 'getgenv(', 'game:GetService(',
            'authorizesAccept=true', 'serverTradeRevisionProven=true',
            'eventSessionAssociationProven=true', 'mayReportProfit=true',
        ):
            self.assertNotIn(forbidden, code)
        for required in (
            'lastOfferValueExposed=false',
            'serverTradeRevisionProven=false',
            'eventSessionAssociationProven=false',
            'callbackCausalityProven=false',
            'authorizesAccept=false',
            'maySendDiscordWebhook=false',
            'tradeOutcome="UNKNOWN"',
            'CLIENT_LASTOFFER_UNCHANGED_WITH_DIFFERENT_OFFER',
            'CLIENT_LASTOFFER_CHANGED_WITH_SAME_OFFER',
        ):
            self.assertIn(required, code)

    def test_real_lua_adversarial_suite(self):
        interpreter = shutil.which('lua5.4') or shutil.which('lua')
        if interpreter:
            cmd = [interpreter, str(LUA_TESTS)]
        else:
            tex = shutil.which('luatex')
            if not tex:
                self.fail('A Lua runtime is required: neither lua5.4 nor luatex found')
            cmd = [tex, '--luaonly', str(LUA_TESTS)]
        env = os.environ.copy()
        env['LASTOFFER_MODULE'] = str(MODULE)
        p = subprocess.run(cmd, env=env, text=True, capture_output=True,
                           timeout=20, check=False)
        self.assertEqual(p.returncode, 0, p.stdout + '\n' + p.stderr)
        self.assertIn('LASTOFFER_CLIENT_ONLY_PASS 11 named groups', p.stdout)
        self.assertIn('LASTOFFER_ADVERSARIAL_PASS 1000 deterministic client-only pairs', p.stdout)


if __name__ == '__main__':
    unittest.main()
