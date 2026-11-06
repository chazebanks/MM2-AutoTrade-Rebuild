"""Stage33: real Lua full-Trade client signal census tested through Python.
No client event payload, personal data, Accept, remote sends, inventory changes
or authority to record a completed trade/profit.
"""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT=Path(__file__).resolve().parents[1]
P4=ROOT/"new_part4"
WINDOW=P4/"p4_stage33_transport_window.lua"
PROBE=P4/"STAGE33_READONLY_TRANSPORT_DELTA_PROBE.lua"
TEST=P4/"tests"/"test_stage33_transport_window.lua"

class Stage33TransportTests(unittest.TestCase):
    def test_inherits_stage30_pure_census_and_carries_known_16_names(self):
        core=WINDOW.read_text()
        self.assertIn('local NAMES={',core)
        for name in (
            'AcceptRequest','AcceptTrade','CancelAccept','CancelRequest',
            'CompleteTrade','DeclineRequest','DeclineTrade','EndTrade',
            'GetRequest','OfferItem','RemoveOffer','RequestSent',
            'SetRequestsEnabled','StartTrade','UpdateOffers','UpdateTrade'
        ):
            self.assertIn('"'+name+'"',core)
        for marker in (
            's.core.new(', 's.core.catalog(', 's.core.received(',
            's.core.closed(', 's.core.finish(', 's.core.summary(',
            's.preOpenCount=s.preOpenCount+1',
            's.tail[#s.tail+1]=v',
            'if #s.tail>16 then table.remove(s.tail,1) end',
            'earlierReceiptsTruncated=s.scopedCount>24',
            'postCloseReceipts=',
        ):
            self.assertIn(marker,core)

    def test_native_probe_is_passive_and_binds_before_gui(self):
        code=PROBE.read_text()
        for marker in (
            'p4_stage30_client_signal_census',
            'p4_stage33_transport_window',
            'folder:GetDescendants()',
            'node:IsA("RemoteEvent")',
            'return node.OnClientEvent:Connect(function()',
            'mods.window.received(S.window,name,os.clock())',
            'S.phase="WAIT_MANUAL_WINDOW"',
            'S.phase="POST_CLOSE_GRACE"',
            'mods.window.close(S.window,os.clock())',
            'mods.window.finish(S.window,os.clock(),normal)',
            'POST_CLOSE_GRACE_FINISHED',
            '[GINGERSCOPE STAGE33 ANONYMIZED]',
            'authorizesAccept=false',
            'mayRecordCompletedTrade=false',
            'mayReportProfit=false',
            'S.connections={}',
            'PDIDDLER_GINGERSCOPE_REPLACEMENT_PREVIEW',
            'PDIDDLER_STAGE32_RESULT_CORRELATION_PROBE',
        ):
            self.assertIn(marker,code)
        self.assertLess(code.index('node.OnClientEvent:Connect(function()'),
                        code.index('S.phase="WAIT_MANUAL_WINDOW"'))
        forbidden=(
            ':FireServer(',':InvokeServer(',':FireAllClients(',':FireClient(',
            'SendMouseButtonEvent(','TeleportToPlaceInstance(',
            'queue_on_teleport(', 'GetProfileData(',
            'OfferItem:FireServer','AcceptTrade:FireServer',
            'DeclineTrade:FireServer','HttpService:PostAsync(',
            'hookfunction(', 'getconnections(', 'getupvalue(',
            'SetCore(', 'setclipboard(token', 'OnClientEvent:Connect(function(...)',
        )
        for item in forbidden:
            self.assertNotIn(item,code)
        self.assertNotIn("STAGE25_SCANNER_ONLY_BOOT.lua",code)

    def test_pure_window_refuses_to_authorize_completion(self):
        code=WINDOW.read_text()
        for phrase in (
            'tradeOutcome="UNKNOWN"',
            'serverCompletionProven=false',
            'causalAttributionProven=false',
            'authorizesTrade=false,authorizesAccept=false',
            'mayRecordCompletedTrade=false,mayReportProfit=false',
        ):
            self.assertIn(phrase,code)
        for forbidden in (':FireServer(',':InvokeServer(',
                          'HttpGet(','SendMouseButtonEvent('):
            self.assertNotIn(forbidden,code)

    @unittest.skipUnless(shutil.which("lua5.4"),"Lua5.4 required")
    def test_python_executes_actual_pure_stage33_lua(self):
        # Ensure the native first-result regression is actually exercised by
        # the exact Lua suite Python executes; do not simulate success in Python.
        self.assertIn(
            "first native Stage33 StartTrade then UpdateTrade and two AcceptTrade stays unknown",
            TEST.read_text(),
        )
        p=subprocess.run(
            ["lua5.4",str(TEST),str(P4)],
            cwd=str(ROOT.parent),text=True,capture_output=True,timeout=12
        )
        self.assertEqual(p.returncode,0,p.stdout+"\n"+p.stderr)
        self.assertIn("Stage33 bounded read-only full Trade transport window",p.stdout)

    @unittest.skipUnless(shutil.which("lua5.4"),"Lua5.4 required")
    def test_actual_native_launcher_compiles_without_execution(self):
        p=subprocess.run(
            ["lua5.4","-e",
             "assert(loadfile('pdiddler/new_part4/STAGE33_READONLY_TRANSPORT_DELTA_PROBE.lua'))"],
            cwd=str(ROOT.parent),text=True,capture_output=True,timeout=12
        )
        self.assertEqual(p.returncode,0,p.stdout+"\n"+p.stderr)

if __name__=="__main__":
    unittest.main()
