"""Stage35: purely structural trade-slot metadata census, zero trading.
The test runs ACTUAL Lua and compiles the native one-shot Delta launcher.
"""
from pathlib import Path
import shutil
import re
import subprocess
import unittest

ROOT=Path(__file__).resolve().parents[2]
P4=ROOT/"pdiddler"/"new_part4"
CORE=P4/"p4_stage35_slot_identity_metadata.lua"
NATIVE=P4/"STAGE35_READONLY_SLOT_METADATA_DELTA_PROBE.lua"
TEST=P4/"tests"/"test_stage35_slot_identity_metadata.lua"

class Stage35MetadataTests(unittest.TestCase):
    def test_pure_module_strips_values_and_has_no_trade_authority(self):
        code=CORE.read_text()
        for snippet in (
            'schema="gingerscope-stage35-slot-identity-metadata-shape-v1"',
            'base.candidateIdFieldPresent=true',
            'base.filledImageNodePresent=true',
            'rawIdAuthenticated=false,exactItemIdentityConfirmed=false',
            'serverCompletionProven=false',
            'mayRecordCompletedTrade=false,mayReportProfit=false',
            'r.valueType',
            'nonempty=r.nonempty',
            'native-slot-metadata-truncated',
            'status="INCOMPLETE"',
        ):
            self.assertIn(snippet,code)
        for forbidden in (
            ':FireServer(',':InvokeServer(', 'game:HttpGet(', 'getconnections(',
            'setclipboard(','Image=','image=r.image','value=r.value',
        ):
            self.assertNotIn(forbidden,code)

    def test_native_probe_captures_shape_without_payload_or_trade_action(self):
        code=NATIVE.read_text()
        for marker in (
            'PDIDDLER_STAGE35_SLOT_METADATA_CENSUS',
            'p4_stage35_slot_identity_metadata.lua',
            'local PIN35="cee7b0605a6822d1dbb0b1592fc2d84b53f0e238"',
            'slot:GetDescendants()',
            'node:GetAttributes()',
            'node:IsA("ImageLabel")',
            'node:IsA("StringValue")',
            'itemNameLabelPresent=true',
            'raw.metadataTruncated=true',
            'S.state="WAIT_FOR_POPULATED_MANUAL_SLOT"',
            'rawIdAuthenticated=false',
            'r.exactItemIdentityConfirmed=false',
            'r.authorizesAccept=false',
            'r.mayRecordCompletedTrade=false',
            '[GINGERSCOPE STAGE35 ANONYMIZED]',
        ):
            self.assertIn(marker,code)
        for forbidden in (
            ':FireServer(',':InvokeServer(', 'SendMouseButtonEvent(',
            'TeleportToPlaceInstance(', 'queue_on_teleport(',
            'GetFullInventory(', 'getOwnInventory(',
            'AcceptTrade:FireServer(', 'HttpService:PostAsync(',
            'getconnections(','getupvalue(','hookfunction(',
        ):
            self.assertNotIn(forbidden,code)
        self.assertIn('S.state="WAIT_FOR_POPULATED_MANUAL_SLOT"',code)
        self.assertNotIn('RemoteEvent:FireServer(',code)

    def test_slot_bind_preserves_all_three_filled_slot_returns(self):
        # Native screenshot showed a populated TheirOffer slot but only the
        # startup console line. The old "root and filledSlot(root)" expression
        # collapses a multires return to one value in Lua, leaving side/index nil.
        source=NATIVE.read_text()
        self.assertNotIn("root and filledSlot(root)",source)
        pattern=(r"(  local slot,side,index\\n"
                 r"  if root then slot,side,index=filledSlot\\(root\\) end)")
        match=re.search(pattern,source)
        self.assertIsNotNone(match,"Actual native slot binding no longer matches")
        snippet=match.group(1)
        if shutil.which("lua5.4"):
            test_case=(
                'local root={}\\n'
                'local function filledSlot(r) '
                'assert(r==root); return {}, "TheirOffer", 1 end\\n'
                +snippet+'\\n'
                'assert(slot~=nil and side=="TheirOffer" and index==1)\\n'
                'root=nil\\n'
                +snippet+'\\n'
                'assert(slot==nil and side==nil and index==nil)\\n'
                'print("STAGE35_NATIVE_THREE_RESULTS_PRESERVED")'
            )
            run=subprocess.run(["lua5.4","-e",test_case],
                               cwd=str(ROOT),capture_output=True,
                               text=True,timeout=10)
            self.assertEqual(run.returncode,0,run.stdout+"\\n"+run.stderr)
            self.assertIn("STAGE35_NATIVE_THREE_RESULTS_PRESERVED",
                          run.stdout)

    @unittest.skipUnless(shutil.which("lua5.4"),"Lua 5.4 in GitHub CI")
    def test_python_runs_actual_pure_stage35_lua_tests(self):
        run=subprocess.run(
            ["lua5.4",str(TEST),"pdiddler/new_part4"],
            cwd=str(ROOT),capture_output=True,text=True,timeout=10,
        )
        self.assertEqual(run.returncode,0,run.stdout+"\n"+run.stderr)
        self.assertIn("Stage35 pure trade slot metadata shape census",run.stdout)

    @unittest.skipUnless(shutil.which("lua5.4"),"Lua 5.4 in GitHub CI")
    def test_pure_and_delta_files_compile_without_execution(self):
        for path in [CORE,NATIVE]:
            run=subprocess.run(["lua5.4","-e",
                    "assert(loadfile("+repr(str(path))+"))"],
                    cwd=str(ROOT),capture_output=True,text=True,timeout=10)
            self.assertEqual(run.returncode,0,run.stdout+"\n"+run.stderr)

if __name__=="__main__":
    unittest.main()
