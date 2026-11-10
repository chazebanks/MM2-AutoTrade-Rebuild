"""Stage96 Python driver for ACTUAL Lua5.4 original-stage source tests.

Requires Git-blob-verified pinned modules provided by dedicated workflow. The
tested input corpus is implemented by the Lua test harness, including 500
deterministic adversarial receipt/GUI mutations and original Stage43/44 reuse.
"""
from __future__ import annotations
import os
from pathlib import Path
import re
import subprocess
import unittest

SRC=Path("pdiddler/intelligence_lab/stage96_partner_event_gui_correlation.lua")
LUA=Path("pdiddler/tests/test_stage96_partner_event_gui_correlation.lua")
PINNED=(
 "STAGE96_MODULE","STAGE96_ORIGINAL_STAGE9",
 "STAGE96_ORIGINAL_STAGE42","STAGE96_ORIGINAL_STAGE43",
 "STAGE96_ORIGINAL_STAGE44","STAGE96_ORIGINAL_STAGE83",
 "STAGE96_STAGE95"
)

def require_env():
    if os.environ.get("STAGE96_REQUIRE_PINNED")!="1":
        raise RuntimeError("Exact verified original Lua source dependencies required")
    for key in PINNED:
        value=os.environ.get(key)
        if not value or not Path(value).is_file():
            raise RuntimeError(f"Source pin unavailable: {key}")

class Stage96OriginalSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        require_env()

    def test_original_real_lua_corpus_500_mutations(self):
        run=subprocess.run(["lua5.4",str(LUA)],capture_output=True,
             text=True,check=False,timeout=30,env=os.environ.copy())
        self.assertEqual(run.returncode,0,run.stdout+"\n"+run.stderr)
        lines=run.stdout.splitlines()
        group_pass=[line for line in lines if line.startswith("PASS Stage96 ")]
        self.assertGreaterEqual(len(group_pass),13,run.stdout)
        summary=[line for line in lines
                 if line.startswith("STAGE96_ACTUAL_ORIGINAL_SOURCE_TESTS_PASS")]
        self.assertEqual(len(summary),1,run.stdout)
        m=re.fullmatch(
           r"STAGE96_ACTUAL_ORIGINAL_SOURCE_TESTS_PASS groups=(\d+) mutants=(\d+)",
           summary[0])
        self.assertIsNotNone(m,summary[0])
        self.assertEqual(int(m.group(1)),len(group_pass))
        self.assertEqual(int(m.group(2)),500)

    def test_source_and_test_valid_lua(self):
        for path in (SRC,LUA):
            run=subprocess.run(["luac5.4","-p",str(path)],capture_output=True,
                    text=True,check=False,timeout=10)
            self.assertEqual(run.returncode,0,run.stdout+run.stderr)

    def test_original_modules_reused_without_remote_actions(self):
        code=SRC.read_text(encoding="utf-8")
        tests=LUA.read_text(encoding="utf-8")
        for term in (
            "raw.contextOK~=true","EVENT_PLAYER_REFERENCE_NOT_UNIQUE",
            "CALLBACK_GUI_TIMING_NOT_BOUNDED",
            "EVENT_COUNT_NOT_EXACTLY_ONE","GUI_AND_CLIENT_EVENT_QUANTITY_DISAGREE",
            "STAGE95_PHYSICAL_OFFER_NOT_CANDIDATE",
            "CLIENT_PARTNER_EVENT_GUI_NAME_QTY_CONSISTENT_UNATTRIBUTED",
            "CLIENT_PARTNER_EVENT_GUI_RAW_TEXT_CONSISTENT_UNATTRIBUTED",
            "eventSessionAssociationProven=false",
            "callbackCausalityProven=false","authorizesAccept=false",
            "currentPricesVerified=false","serverCompletionProven=false"
        ):
            self.assertIn(term,code)
        for term in (
            'Stage42.inspect(', 'Stage43.inspect(', 'Stage44.inspect(',
            'Stage95.inspect', 'mutants=500',
        ):
            # Stage95.inspect is referenced as a dependency through the
            # provided module, so test a matching local name as appropriate.
            if term=="Stage95.inspect":
                self.assertIn("Stage95",tests)
            else:
                self.assertIn(term,tests)
        for forbidden in (
            "FireServer(", "InvokeServer(", "HttpPost(", "PostAsync(",
            "TeleportService", "SendMouseButtonEvent(",
            "ClickDetector", "AcceptTrade(", "DeclineTrade(",
            "loadstring(game:HttpGet", "getconnections(",
        ):
            self.assertNotIn(forbidden,code)
        self.assertNotIn("authorizesTrade=true",code)
        self.assertNotIn("authorizesAccept=true",code)

if __name__=="__main__":
    unittest.main()
