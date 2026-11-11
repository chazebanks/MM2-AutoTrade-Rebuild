"""Stage119 original-MM2 native read-only integrity audit (no trade actions)."""
from __future__ import annotations
from pathlib import Path
import hashlib
import os
import re
import subprocess
import unittest

ROOT=Path(__file__).resolve().parents[2]
RUNNER=ROOT/"pdiddler/supervised/STAGE119_LASTOFFER_NATIVE.lua"
CONTROLLER=ROOT/"pdiddler/supervised/stage119_lastoffer_native_controller.lua"
MOCK=ROOT/"pdiddler/ci/stage119_native_original_mocks.luau"
STAGE118=ROOT/"pdiddler/intelligence_lab/stage118_lastoffer_gui_correlation.lua"
AUDIT=ROOT/"pdiddler/intelligence_lab/trade_lastoffer_client_audit.lua"
PR221=ROOT/"pdiddler/supervised/SUPERVISED_P3_STAGE101_IDENTITY_NATIVE.lua"
PR221LOADER=ROOT/"pdiddler/supervised/SUPERVISED_P3_STAGE101_READONLY_START.lua"
ORIGINAL=Path(os.environ.get("STAGE119_STAGE9","/tmp/gingerscope-stage119/stage9.lua"))
NATIVE=Path(os.environ.get("STAGE119_STAGE9_NATIVE","/tmp/gingerscope-stage119/native_stage9.lua"))
GEOMETRY=Path(os.environ.get("STAGE119_GEOMETRY","/tmp/gingerscope-stage119/geometry.lua"))

def blob(p:Path)->str:
    b=p.read_bytes()
    return hashlib.sha1(f"blob {len(b)}\0".encode()+b).hexdigest()

class Stage119SourceTests(unittest.TestCase):
    def test_immutable_proven_dependencies(self):
        for path,sha in (
            (STAGE118,"bfabdae261017bac3b591f72c15ca9baa58c5e70"),
            (AUDIT,"fba6f02c7287e2afd7ad3ea9e75cc221854a17b9"),
            (PR221,"46cff56b9f58fa8590a275dfd26f46cea0c5c9a6"),
            (PR221LOADER,"a1430dc26fc3d85fe2268a84a5fea475812b5002"),
            (ORIGINAL,"7c84456006bd684dacb0217d0ae092d6d67575a4"),
            (NATIVE,"a6338e946467ad738005bc5cb13cd2d2fbc2a2d0"),
            (GEOMETRY,"e0eac8e039655999bd7bbac1f12da179db7c22ed")
        ):
            self.assertEqual(blob(path),sha,str(path))

    def test_client_only_and_no_game_side_effects(self):
        runner=RUNNER.read_text()
        control=CONTROLLER.read_text()
        for source in (runner,control):
            for token in (r":\s*FireServer\s*\(",r":\s*InvokeServer\s*\(",
                         r":\s*Teleport\s*\(",r":\s*PostAsync\s*\(",
                         r"RemoteEvent\s*:\s*Fire",r"authorizesAccept\s*=\s*true",
                         r"serverTradeRevisionProven\s*=\s*true"):
                self.assertIsNone(re.search(token,source),token)
            for field in ("serverTradeRevisionProven=false",
                          "eventSessionAssociationProven=false",
                          "callbackCausalityProven=false",
                          "authorizesAccept=false",
                          "mayReportProfit=false",
                          'tradeOutcome="UNKNOWN"'):
                self.assertIn(field,source)
        for needed in ("venossgaming90190","PlaceId~=142823291",
                       "OnClientEvent:Connect","stage100_screen_prompt_overlay.lua",
                       "ONSCREEN_GUIDE_NO_SAFE_SPACE_OUTSIDE_TRADE",
                       "STOP / COPY", "UIStroke", "safeJson"):
            self.assertIn(needed,runner)
        for required in ("WAIT_FIRST_GUI","WAIT_SECOND_GUI",
                         "UNEXPECTED_OR_DUPLICATE_CLIENT_EVENT",
                         "TRADE_ROOT_OR_PARTNER_CHANGED"):
            self.assertIn(required,control)

    def test_no_raw_token_or_item_in_native_report(self):
        txt=RUNNER.read_text()
        self.assertNotIn("LastOffer = packet.LastOffer",txt)
        self.assertNotIn("r.LastOffer",txt)
        self.assertNotIn("lastOfferValue=",txt)
        self.assertIn("lastOfferEqualityClass",txt)

if __name__=="__main__":
    unittest.main()
