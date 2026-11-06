"""Stage28: native Accept/Close observation and Stage20 outcome authority fence.

All client GUI evidence is read-only and cannot authorize an Accept or a
Discord 'completed trade'. The actual Stage9 Lua UI reader is tested.
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
TIMELINE=P4/"p4_stage28_accept_timeline.lua"
NATIVE=P4/"STAGE28_PASSIVE_DELTA_PROBE.lua"

class Stage28Tests(unittest.TestCase):
    def test_timeline_never_mints_server_or_profit_authority(self):
        code=TIMELINE.read_text()
        for f in ("serverCompletionProven=false",
                  "mayRecordCompletedTrade=false",
                  "mayReportProfit=false",
                  "authorizesTrade=false,authorizesAccept=false",
                  "closureProvesCompletion=false",
                  's.closureStatus="closed_unknown"'):
            self.assertIn(f,code)
        for forbidden in ("FireServer(", "InvokeServer(", "SendMouseButtonEvent(",
                          "AcceptTrade", "DeclineTrade", "CompletedEvent",
                          "HttpGet(", "request("):
            self.assertNotIn(forbidden,code)

    def test_native_probe_is_passive_and_one_session_only(self):
        code=NATIVE.read_text()
        for forbidden in (":FireServer(", ":InvokeServer(",
                          "SendMouseButtonEvent(", "AcceptTrade:FireServer",
                          "DeclineTrade:FireServer", "queue_on_teleport(",
                          "TeleportToPlaceInstance("):
            self.assertNotIn(forbidden,code)
        for evidence in ('import(STAGE26,"p4_native_observer")',
                         'import(STAGE26,"p4_observer_contract")',
                         'import(STAGE28,"p4_stage28_accept_timeline")',
                         'scanner.getRecord',
                         'scanner.getOwnInventory',
                         'modules.native.capture',
                         'modules.timeline.ingest',
                         'modules.timeline.summary(timeline.state)',
                         'marketFresh=function()return false end',
                         'PDIDDLER_STAGE27_NATIVE_LAB',
                         'PDIDDLER_PART4_SESSION',
                         'GINGERSCOPE STAGE28 ANONYMIZED',
                         'serverCompletionProven=false',
                         'serverAttestation=false'):
            self.assertIn(evidence,code)
        self.assertNotIn("ui.DisplayOrder",code)  # no overlay to block trade
        self.assertNotIn("Instance.new(",code)

    def test_source_expiry_not_forged_into_trade_authority(self):
        code=NATIVE.read_text()
        self.assertIn('STAGE26=',code)
        self.assertIn('STAGE25_SCANNER_ONLY_BOOT.lua',code)
        self.assertIn('marketFresh=function()return false end',code)
        self.assertIn('summary.authorizesAccept=false',code)
        self.assertIn('summary.mayRecordCompletedTrade=false',code)

    def test_accept_indicators_require_consistent_resolved_offer_to_stabilize(self):
        code=TIMELINE.read_text()
        for frag in ('o.contextOK~=true',
                     'o.theirResolved~=true',
                     'o.ourSlots==0 or o.theirSlots==0',
                     's.lastSignature and signature~=s.lastSignature',
                     's.hadAnyAccept or ours or theirs',
                     't-s.pendingSince>=s.minStableGap',
                     'o.ourAccepted==true or',
                     's.tainted=true',
                     's.terminal=true'):
            self.assertIn(frag,code)

    def test_stage20_cannot_treat_stage28_closure_as_success(self):
        t=datetime(2026,11,5,tzinfo=timezone.utc)
        offer=OfferObservation("owned","job-one","session-one","partner",
            t,{"godly:11:checker-id":1},{"chroma:12:checker-id":1},
            True,True,True,True)
        close=ClosureObservation("owned","job-one","session-one","partner",
            t+timedelta(seconds=1),"closed_unknown")
        def scan(offset,seq,data):
            return InventoryReadback("owned","job-one",
                t+timedelta(seconds=offset),seq,data,True,"native_claimed")
        pre=scan(-1,1,{"godly:11:checker-id":2})
        after=scan(2,2,{"godly:11:checker-id":1,"chroma:12:checker-id":1})
        after2=scan(2.5,3,{"godly:11:checker-id":1,"chroma:12:checker-id":1})
        result=review_outcome(offer,close,pre,after,after2)
        self.assertEqual(result.status,"INCOMPLETE")
        self.assertEqual(result.reason,"closure-not-proof-of-completion")
        self.assertFalse(result.server_completion_proven)
        self.assertFalse(result.may_record_completed_trade)
        self.assertFalse(result.may_report_profit)
        self.assertFalse(result.authorizes_accept)

    def test_timeline_returns_no_identifying_values(self):
        code=TIMELINE.read_text().split("function M.summary(s)")[1]
        for forbidden in ("jobId=s.", "partnerUserId=s.", "localUserId=s.",
                          "accountId=s.", "partnerName=s.", "webhook"):
            self.assertNotIn(forbidden,code)
        self.assertIn("events=history",code)

    @unittest.skipUnless(shutil.which("lua5.4"),"Lua5.4 in CI")
    def test_actual_lua_acceptance_and_native_reader(self):
        for filename,expected in (
            ("test_stage28_accept_timeline.lua",
             "Stage28 pure acceptance/closure read-only timeline regression"),
            ("test_stage28_native_accept_integration.lua",
             "Stage28 actual Stage9 native acceptance and closure mock integration"),
        ):
            proc=subprocess.run(["lua5.4",str(P4/"tests"/filename),str(P4)],
               cwd=str(ROOT.parent),capture_output=True,text=True,
               timeout=12,check=False)
            self.assertEqual(proc.returncode,0,
                filename+" failed:\n"+proc.stdout+"\n"+proc.stderr)
            self.assertIn(expected,proc.stdout)

    @unittest.skipUnless(shutil.which("lua5.4"),"Lua5.4 in CI")
    def test_passive_delta_probe_compiles_without_running(self):
        proc=subprocess.run(["lua5.4","-e",
             "assert(loadfile('pdiddler/new_part4/STAGE28_PASSIVE_DELTA_PROBE.lua'))"],
            cwd=str(ROOT.parent),capture_output=True,text=True,
            timeout=12,check=False)
        self.assertEqual(proc.returncode,0,proc.stdout+"\n"+proc.stderr)

if __name__=="__main__":
    unittest.main()
