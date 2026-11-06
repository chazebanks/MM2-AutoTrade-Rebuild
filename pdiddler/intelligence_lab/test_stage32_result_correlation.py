"""Stage32: passive client receipt + independent own inventory readbacks.

No native Accept, trade request, item insert/remove, webhooks or completion.
The old Stage20 outcome auditor must still reject closed_unknown as success.
"""
from datetime import datetime, timedelta, timezone
from pathlib import Path
import shutil
import subprocess
import unittest

from stage20_outcome_audit import (
    OfferObservation, ClosureObservation, InventoryReadback, review_outcome,
)

ROOT=Path(__file__).resolve().parents[1]
P4=ROOT/"new_part4"
CORE=P4/"p4_stage32_result_correlation.lua"
PROBE=P4/"STAGE32_READONLY_RESULT_DELTA_PROBE.lua"

class Stage32Tests(unittest.TestCase):
    def test_join_never_creates_server_completion_authority(self):
        code=CORE.read_text()
        for item in (
            'serverAttestation=false,serverCompletionProven=false',
            'authorizesTrade=false,authorizesAccept=false',
            'mayRecordCompletedTrade=false,mayReportProfit=false',
            'tradeOutcome="UNKNOWN"',
            'causalAttributionProven=false',
            '"COMPLETE_NAMED_RECEIPT_AND_UNATTRIBUTED_DELTA"',
            '"CONFLICTING_RESULT_NAMED_RECEIPTS"',
            '"END_NAMED_RECEIPT_AND_UNATTRIBUTED_DELTA"',
            '"CENSUS_TRUNCATED"',
        ):
            self.assertIn(item,code)
        for forbidden in (":FireServer(",":InvokeServer(",
                "SendMouseButtonEvent(","GetProfileData(","HttpGet("):
            self.assertNotIn(forbidden,code)

    def test_one_session_and_three_independent_sources_required(self):
        code=CORE.read_text()
        for item in (
            't.session~=c.session',
            't.session~=l.session',
            'not t.terminal or not c.final or not l.terminal',
            't.phase~="CLOSED_UNKNOWN"',
            'c.closure~="CLOSED_UNKNOWN"',
            'math.abs(t.lastTime-c.closedAt)>1',
            'math.abs(t.lastTime-l.closedAt)>1',
            'l.scans~=3',
            'c.samples>#c.events',
        ):
            self.assertIn(item,code)

    def test_delta_probe_has_exact_event_scope_no_event_payloads(self):
        code=PROBE.read_text()
        for item in (
            'local eventNames={"CompleteTrade","EndTrade","DeclineTrade"}',
            'local permitted={CompleteTrade=true,EndTrade=true,DeclineTrade=true}',
            'folder:GetDescendants()',
            'return false,"DUPLICATE_CANDIDATE_REMOTE"',
            'signal.OnClientEvent:Connect(function()',
            'mods.census.received(census,name,os.clock())',
            'mods.census.closed(S.census,kind,now)',
            'S.signalCore.finish(S.census,why,os.clock())',
            'S.joinCore.evaluate(timeline.instance,S.census,ledger.instance)',
            'GINGERSCOPE STAGE32 ANONYMIZED',
            'authorizesTrade=false,authorizesAccept=false',
            'mayRecordCompletedTrade=false,mayReportProfit=false',
            'partner.Parent~=players',
            'if census.closedAt and current then return end',
        ):
            self.assertIn(item,code)
        for forbidden in (":FireServer(",":InvokeServer(",
                "SendMouseButtonEvent(", "GetProfileData:InvokeServer(",
                "TeleportToPlaceInstance(", "queue_on_teleport(",
                "AcceptTrade:FireServer", "DeclineTrade:FireServer",
                "HttpService:PostAsync(", "Instance.new(", "hookfunction("):
            self.assertNotIn(forbidden,code)
        self.assertNotIn('OnClientEvent:Connect(function(...)',code)

    def test_reuses_existing_scanner_gui_observers_and_ledger(self):
        code=PROBE.read_text()
        for item in (
            'STAGE25_SCANNER_ONLY_BOOT.lua',
            'source(STAGE26,"p4_native_observer")',
            'source(STAGE26,"p4_observer_contract")',
            'source(STAGE28,"p4_stage28_accept_timeline")',
            'source(STAGE29,"p4_stage29_postclose_ledger")',
            'source(STAGE30,"p4_stage30_client_signal_census")',
            'source(STAGE32,"p4_stage32_result_correlation")',
            'scanner.getOwnInventory',
            'mods.ledger.before(ledger.instance,own,beforeTime,sc)',
            'mods.ledger.after(ledger.instance,inventory,t,sc,i)',
            'mods.timeline.ingest(timeline.instance,o,diag,os.clock())',
            'S.connections={}',
            'if S.reportReady then return end',
        ):
            self.assertIn(item,code)

    def test_older_stage20_still_forbids_closed_unknown_completion(self):
        t=datetime(2026,11,5,tzinfo=timezone.utc)
        o=OfferObservation("own","job","session","partner",t,
                           {"godly:11:checker-id":1},{"chroma:12:checker-id":1},
                           True,True,True,True)
        c=ClosureObservation("own","job","session","partner",
                             t+timedelta(seconds=1),"closed_unknown")
        def inventory(sec,seq,d):
            return InventoryReadback("own","job",t+timedelta(seconds=sec),
                        seq,d,True,"native_claimed")
        before=inventory(-1,1,{"godly:11:checker-id":2})
        after1=inventory(2,2,{"godly:11:checker-id":1,"chroma:12:checker-id":1})
        after2=inventory(3,3,{"godly:11:checker-id":1,"chroma:12:checker-id":1})
        r=review_outcome(o,c,before,after1,after2)
        self.assertEqual(r.status,"INCOMPLETE")
        self.assertFalse(r.server_completion_proven)
        self.assertFalse(r.may_record_completed_trade)
        self.assertFalse(r.authorizes_accept)

    @unittest.skipUnless(shutil.which("lua5.4"),"Lua5.4 in CI")
    def test_pure_lua_correlation_regression(self):
        p=subprocess.run(["lua5.4",str(P4/"tests"/"test_stage32_result_correlation.lua"),
                           str(P4)],cwd=str(ROOT.parent),
                           text=True,capture_output=True,timeout=12)
        self.assertEqual(p.returncode,0,p.stdout+"\n"+p.stderr)
        self.assertIn("Stage32 client-only result-signal inventory correlation",p.stdout)

    @unittest.skipUnless(shutil.which("lua5.4"),"Lua5.4 in CI")
    def test_actual_stage29_lua_regression_through_python(self):
        """Execute the real Stage29 Lua ledger test, including excluded-weapon exchange.

        This is an offline fixture (not proof of the user's outgoing item tier
        or of MM2's successful-trade server transport).
        """
        source=(P4/"tests"/"test_stage29_postclose_ledger.lua").read_text()
        self.assertIn(
            "eligible gain plus untracked weapon loss reports zero eligible losses",
            source,
        )
        p=subprocess.run(
            ["lua5.4", str(P4/"tests"/"test_stage29_postclose_ledger.lua"),
             str(P4)],
            cwd=str(ROOT.parent), text=True, capture_output=True, timeout=12,
        )
        self.assertEqual(p.returncode, 0, p.stdout+"\\n"+p.stderr)
        self.assertRegex(
            p.stdout,
            r"PASS\\s+\\d+\\s+Stage29 pure post-close own inventory ledger evidence",
        )

    @unittest.skipUnless(shutil.which("lua5.4"),"Lua5.4 in CI")
    def test_delta_launcher_compiles_without_running(self):
        p=subprocess.run(["lua5.4","-e",
             "assert(loadfile('pdiddler/new_part4/STAGE32_READONLY_RESULT_DELTA_PROBE.lua'))"],
             cwd=str(ROOT.parent),text=True,capture_output=True,timeout=12)
        self.assertEqual(p.returncode,0,p.stdout+"\n"+p.stderr)

if __name__=="__main__":
    unittest.main()
