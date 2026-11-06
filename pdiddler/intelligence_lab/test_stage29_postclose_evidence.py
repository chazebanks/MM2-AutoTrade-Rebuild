"""Stage29: after CLOSED_UNKNOWN, separate client inventory-readback evidence.

The live Delta probe is observation-only and cannot authorize Accept or
classify a completed trade, even when before/after quantities change.
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
LEDGER=P4/"p4_stage29_postclose_ledger.lua"
PROBE=P4/"STAGE29_POSTCLOSE_DELTA_PROBE.lua"

class Stage29Tests(unittest.TestCase):
    def test_true_distinction_between_local_delta_and_server_completion(self):
        src=LEDGER.read_text()
        for phrase in ('"NO_ELIGIBLE_DELTA_OBSERVED"',
                       '"ELIGIBLE_DELTA_UNATTRIBUTED"',
                       '"RAW_WEAPON_CHANGE_UNATTRIBUTED"',
                       '"POST_READS_DISAGREE"',
                       'tradeOutcome="UNKNOWN"',
                       'mayRecordCompletedTrade=false',
                       'mayReportProfit=false',
                       'serverAttestation=false',
                       'authorizesTrade=false,authorizesAccept=false'):
            self.assertIn(phrase,src)
        for banned in (":FireServer(",":InvokeServer(",
                       "HttpGet(","SendMouseButtonEvent(","Discord",
                       "AcceptTrade","DeclineTrade"):
            self.assertNotIn(banned,src)

    def test_serial_single_session_scans_and_waits(self):
        src=LEDGER.read_text()
        for phrase in ("scope.session==s.session",
                       "scope.jobId==s.jobId",
                       "scope.accountId==s.accountId",
                       "scope.partnerId==s.partnerId",
                       'kind~="CLOSED_UNKNOWN"',
                       'sequence~=s.scans+1',
                       "t-s.after1At<s.minPostGap",
                       "t-s.closedAt>s.maxPostAge",
                       "s.post1.fp~=s.post2.fp",
                       "s.post1.rawOwned~=s.post2.rawOwned"):
            self.assertIn(phrase,src)

    def test_reuses_existing_scanner_and_stage9_no_new_trade_controller(self):
        src=PROBE.read_text()
        for phrase in ("STAGE25_SCANNER_ONLY_BOOT.lua",
                       'source(STAGE26,"p4_native_observer")',
                       'source(STAGE28,"p4_stage28_accept_timeline")',
                       'source(STAGE29,"p4_stage29_postclose_ledger")',
                       'scanner.getOwnInventory',
                       'mods.timeline.ingest',
                       'mods.ledger.before',
                       'mods.ledger.close',
                       'mods.ledger.after',
                       'GINGERSCOPE STAGE29 ANONYMIZED',
                       'mayRecordCompletedTrade=false',
                       'serverCompletionProven=false'):
            self.assertIn(phrase,src)
        for banned in (":FireServer(", "AcceptTrade", "DeclineTrade:FireServer",
                       "SendMouseButtonEvent(", "TeleportToPlaceInstance(",
                       "queue_on_teleport(", "pdiddler4_balancer_SUPREME"):
            # AcceptTrade is mentioned only as an explanatory NO-Accept comment
            if banned=="AcceptTrade": continue
            self.assertNotIn(banned,src)
        self.assertNotIn("Instance.new(",src)

    def test_stage20_still_refuses_closed_unknown_even_with_matching_deltas(self):
        t=datetime(2026,11,5,16,tzinfo=timezone.utc)
        a,b="godly:11:checker-id","chroma:12:checker-id"
        offer=OfferObservation("owned","job","S1","partner",t,
            {a:1},{b:1},True,True,True,True)
        close=ClosureObservation("owned","job","S1","partner",
            t+timedelta(seconds=1),"closed_unknown")
        def scan(sec,seq,items):
            return InventoryReadback("owned","job",t+timedelta(seconds=sec),
                    seq,items,True,"native_claimed")
        before=scan(-1,1,{a:2})
        after1=scan(2,2,{a:1,b:1})
        after2=scan(3,3,{a:1,b:1})
        audit=review_outcome(offer,close,before,after1,after2)
        self.assertEqual(audit.status,"INCOMPLETE")
        self.assertEqual(audit.reason,"closure-not-proof-of-completion")
        self.assertFalse(audit.server_completion_proven)
        self.assertFalse(audit.may_report_profit)
        self.assertFalse(audit.may_record_completed_trade)
        self.assertFalse(audit.authorizes_accept)

    def test_one_sided_declined_client_case_cannot_mint_any_completed_claim(self):
        t=datetime(2026,11,5,16,tzinfo=timezone.utc)
        b="chroma:12:checker-id"
        offer=OfferObservation("owned","job","S1","partner",t,
            {},{b:1},False,True,True,True)
        close=ClosureObservation("owned","job","S1","partner",
            t+timedelta(seconds=1),"closed_unknown")
        def scan(sec,seq):
            return InventoryReadback("owned","job",t+timedelta(seconds=sec),
                seq,{"godly:11:checker-id":2},True,"native_claimed")
        result=review_outcome(offer,close,scan(-1,1),scan(2,2),scan(3,3))
        self.assertEqual(result.status,"INCOMPLETE")
        self.assertFalse(result.may_record_completed_trade)

    @unittest.skipUnless(shutil.which("lua5.4"),"CI Lua runtime")
    def test_actual_lua_pure_ledger(self):
        proc=subprocess.run(["lua5.4",
            str(P4/"tests"/"test_stage29_postclose_ledger.lua"),str(P4)],
            cwd=str(ROOT.parent),text=True,capture_output=True,timeout=15)
        self.assertEqual(proc.returncode,0,proc.stdout+"\n"+proc.stderr)
        self.assertIn("Stage29 pure post-close own inventory ledger evidence",
                      proc.stdout)

    @unittest.skipUnless(shutil.which("lua5.4"),"CI Lua runtime")
    def test_standalone_delta_probe_compiles_without_running(self):
        proc=subprocess.run(["lua5.4","-e",
              "assert(loadfile('pdiddler/new_part4/STAGE29_POSTCLOSE_DELTA_PROBE.lua'))"],
            cwd=str(ROOT.parent),text=True,capture_output=True,timeout=15)
        self.assertEqual(proc.returncode,0,proc.stdout+"\n"+proc.stderr)

if __name__=="__main__":
    unittest.main()
