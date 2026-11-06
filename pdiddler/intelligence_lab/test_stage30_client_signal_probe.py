"""Stage30 first read-only client trade outcome-signal discovery.

Names/receipts from a Roblox RemoteEvent are not authoritative trade outcomes.
No payloads, remote sends, invented CompletedEvents, Accept or Discord.
"""
from pathlib import Path
import re
import shutil
import subprocess
import unittest

ROOT=Path(__file__).resolve().parents[1]
P4=ROOT/"new_part4"
CORE=P4/"p4_stage30_client_signal_census.lua"
PROBE=P4/"STAGE30_READONLY_CLIENT_SIGNALS_DELTA.lua"

class Stage30Tests(unittest.TestCase):
    def test_no_completion_or_accept_authority_in_signal_census(self):
        src=CORE.read_text()
        for required in (
            'tradeOutcome="UNKNOWN"',
            'serverAttestation=false',
            'serverCompletionProven=false',
            'authorizesTrade=false',
            'authorizesAccept=false',
            'mayRecordCompletedTrade=false',
            'mayReportProfit=false',
            'clientSignalsDoNotEstablishTradeOutcome=true',
        ):
            self.assertIn(required,src)
        for forbidden in ("FireServer(","InvokeServer(","GetProfileData(",
                         "SendMouseButtonEvent(","CompletedEvent:Connect("):
            self.assertNotIn(forbidden,src)

    def test_no_remote_payload_captured_and_event_log_bounded(self):
        src=CORE.read_text()
        self.assertIn('#remoteNames>32',src)
        self.assertIn('if #s.events<24 then',src)
        self.assertIn('not s.names[n]',src)
        self.assertIn('name=n,phase=phase,elapsed=',src)
        self.assertNotIn('eventArgs=',src)
        self.assertNotIn('partnerId=s.',src)
        self.assertNotIn('jobId=s.',src)

    def test_probe_only_observes_trading_remotes_and_partner_departure(self):
        src=PROBE.read_text()
        for required in (
            'local folder=rs:FindFirstChild("Trade")',
            'local all=folder:GetDescendants()',
            'node:IsA("RemoteEvent")',
            'remote.OnClientEvent:Connect(function()',
            'players.PlayerRemoving:Connect(function(p)',
            'if not S.done and p==partner then',
            'mods.census.received(census,name,os.clock())',
            'mods.census.partnerDeparture(census,os.clock())',
            'mods.census.closed(S.signals,kind,os.clock())',
            'mods.census.finish(S.signals,"OBSERVATION_FINISHED",os.clock())',
            'local liveRoot=tradeRoot()',
            'if census.closedAt and liveRoot then return end',
            'GINGERSCOPE STAGE30 ANONYMIZED',
        ):
            self.assertIn(required,src)
        for forbidden in (
            ':FireServer(',':InvokeServer(',
            'SendMouseButtonEvent(',':Fire(',':Activate(',
            'TeleportToPlaceInstance(','queue_on_teleport(',
            'RequestAsync(', 'HttpService:PostAsync(',
            'Instance.new(', 'getconnections(', 'hookfunction(',
        ):
            self.assertNotIn(forbidden,src)

    def test_one_read_only_scanner_and_stage9_staged_source(self):
        src=PROBE.read_text()
        for required in (
            'STAGE25_SCANNER_ONLY_BOOT.lua',
            'scanner.getRecord',
            'scanner.getOwnInventory',
            'source' if False else 'import(S26,"p4_native_observer")',
            'import(S28,"p4_stage28_accept_timeline")',
            'import(S30,"p4_stage30_client_signal_census")',
            'local S30="3ccf9219580726e2b122e1b9d4bdb6039eff96b0"',
            'scope' if False else 'partnerUserId=partner.UserId',
            'mods.timeline.ingest(S.timeline,o,d,os.clock())',
        ):
            self.assertIn(required,src)
        self.assertNotIn('P4_REPRICE_ONLY.lua',src)
        self.assertNotIn('pdiddler4_balancer',src)

    def test_probed_remote_catalog_has_no_data_from_arguments(self):
        src=PROBE.read_text()
        self.assertRegex(src,r'OnClientEvent:Connect\(function\(\)')
        self.assertNotRegex(src,r'OnClientEvent:Connect\(function\(\.\.\.\)')
        self.assertNotIn('table.pack(...)',src)
        self.assertNotIn('select("#",...)',src)
        self.assertIn('disconnect()',src)
        self.assertIn('if S.done then return end',src)

    @unittest.skipUnless(shutil.which("lua5.4"),"Lua5.4 available in CI")
    def test_actual_stage30_pure_lua(self):
        proc=subprocess.run(["lua5.4",
          str(P4/"tests"/"test_stage30_client_signal_census.lua"),str(P4)],
          capture_output=True,text=True,cwd=str(ROOT.parent),check=False,timeout=15)
        self.assertEqual(proc.returncode,0,proc.stdout+"\n"+proc.stderr)
        self.assertIn('Stage30 read-only client native signal census',proc.stdout)

    @unittest.skipUnless(shutil.which("lua5.4"),"Lua5.4 available in CI")
    def test_full_delta_launcher_compiles_without_execution(self):
        proc=subprocess.run(["lua5.4","-e",
          "assert(loadfile('pdiddler/new_part4/STAGE30_READONLY_CLIENT_SIGNALS_DELTA.lua'))"],
          capture_output=True,text=True,cwd=str(ROOT.parent),check=False,timeout=15)
        self.assertEqual(proc.returncode,0,proc.stdout+"\n"+proc.stderr)

if __name__=="__main__":
    unittest.main()
