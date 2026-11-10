"""Stage103: execute actual read-only original Part4 native GUI with archived
189 real Supreme public-reference rows and collision-safe in-game value panel.
Mock controls only; no actual game server or current-price attestation.
"""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import tempfile
import unittest

from pdiddler.tests.test_stage102_public_lua_bridge import as_lua

SCRIPT=Path("pdiddler/new_part4/STAGE103_READONLY_ARCHIVED_VALUE_OVERLAY.lua")
TEST=Path("pdiddler/tests/test_stage103_native_archived_value_overlay.lua")
PUBLIC=Path("pdiddler/intelligence_lab/stage102_pinned_public_reference_2026_11_09.json")
SHA="47a025018f8bd24acbe4b193f7ec2a4aa158e88deced381d0f787406afa3339b"

class Stage103NativePublicReference(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if os.getenv("STAGE103_REQUIRE_PINNED")!="1":
            raise unittest.SkipTest("Stage103 exact original source blobs required")
        for name in ("STAGE103_ORIGINAL_STAGE9","STAGE103_ORIGINAL_NATIVE",
                     "STAGE103_ORIGINAL_STAGE98","STAGE103_ORIGINAL_STAGE102"):
            assert Path(os.environ[name]).is_file(),name
        raw=PUBLIC.read_bytes()
        assert hashlib.sha256(raw).hexdigest()==SHA,"Original 189-record archive changed"
        cls.archive=json.loads(raw)
        assert cls.archive["entryCount"]==189

    def test_real_gui_adapter_and_archival_value_display_under_lua(self):
        with tempfile.TemporaryDirectory() as temp:
            p=Path(temp)/"pinned_archive.lua"
            p.write_text("return "+as_lua(self.archive)+"\n",encoding="utf-8")
            env=os.environ.copy()
            env["STAGE103_ARCHIVE_LUA"]=str(p)
            for path in (p,SCRIPT,TEST):
                r=subprocess.run(["luac5.4","-p",str(path)],capture_output=True,
                    text=True,timeout=10)
                self.assertEqual(r.returncode,0,r.stdout+r.stderr)
            r=subprocess.run(["lua5.4",str(TEST)],env=env,text=True,
                capture_output=True,timeout=55)
            self.assertEqual(r.returncode,0,r.stdout+"\n"+r.stderr)
            lines=[x for x in r.stdout.splitlines() if x.startswith("PASS Stage103 ")]
            self.assertEqual(len(lines),12,r.stdout)
            self.assertIn("STAGE103_REAL_ARCHIVE_NATIVE_GUI_MOCK_PASS groups=12",r.stdout)

    def test_no_auto_offer_accept_decline_or_current_price_from_archival_script(self):
        s=SCRIPT.read_text()
        for required in (
            "PDIDDLER_STAGE103_READONLY_ARMED","source(\"stage102\")",
            "pinnedArchive()", "values.preview(archive,state,os.time(),os.clock())",
            "source(\"promptLayout\")", "placeGuide(",
            "ARCHIVED NOV 9 • NOT CURRENT",
            "PROTECTED_GINGERSCOPE_IN_OUR_OFFER",
            "offerPreviewInvalidatedDuringHold=true",
            "onScreenGuideNonOverlappingTrade=false",
            "actualRequestTaps=0,actualOffers=0,actualAccepts=0",
            "authorizesTrade=false","authorizesAccept=false",
            "marketPriceNotVerified=true",
            "[GINGERSCOPE STAGE103 ARCHIVED VALUES]"
        ):
            self.assertIn(required,s,required)
        for forbidden in (
            ":FireServer(",":InvokeServer(", "VirtualInputManager",
            "SendMouseButtonEvent(", "OnClientEvent:Connect(",
            "TeleportService", "PostAsync(", "HttpPost(",
            "AcceptTrade(", "DeclineTrade(", "getconnections("
        ):
            self.assertNotIn(forbidden,s,forbidden)
        self.assertNotIn("authorizesTrade=true",s)
        self.assertNotIn("authorizesAccept=true",s)

    def test_archived_data_is_exactly_189_and_protected_gingerscope(self):
        self.assertEqual(len(self.archive["rows"]),189)
        self.assertEqual(self.archive["expiresAt"],"2026-11-10T22:26:48Z")
        self.assertFalse(self.archive["currentPricesVerified"])
        self.assertFalse(self.archive["authorizesAccept"])
        self.assertEqual(
            [r["value"] for r in self.archive["rows"] if r["label"]=="Gingerscope"],
            [16000])
        self.assertEqual(
            [r["value"] for r in self.archive["rows"] if r["label"]=="Emberbow"],
            [650])

if __name__=="__main__":
    unittest.main()
