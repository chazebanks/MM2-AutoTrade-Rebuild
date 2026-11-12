"""Offline original source tests for isolated persistent backend. No real APIs."""
from __future__ import annotations

from contextlib import redirect_stdout
from datetime import datetime, timezone, timedelta
from http.server import ThreadingHTTPServer
from io import StringIO
import http.client
import json
import os
from pathlib import Path
import random
import sqlite3
import tempfile
import threading
import unittest

from pdiddler.backend.persistent_store import (
    Store, DENIALS, InvalidEvidence, ConflictingReplay, digest, clock,
)
from pdiddler.backend import runtime

NOW="2026-11-12T17:00:00Z"
EARLIER="2026-11-12T16:00:00Z"
LATER="2026-11-12T18:00:00Z"
SECRET="TEST_BACKEND_PRIVATE_STATUS_TOKEN_0123456789"

def market(**kw):
    return {
        "receiptId":"TEST_receipt_1",
        "sourceId":"TEST_market",
        "mode":"EXTERNAL_UNTRUSTED",
        "sourcePublishedAt":EARLIER,
        "retrievedAt":"2026-11-12T16:30:00Z",
        "expiresAt":LATER,
        "itemCount":1200,
        "observationSha256":"a"*64,
        **kw,
    }

def inventory(**kw):
    return {
        "checkpointId":"TEST_checkpoint_1",
        "epochId":"TEST_client_epoch",
        "observedAt":EARLIER,
        "items":[{"rawKey":"TEST_W1","copies":2},
                 {"rawKey":"TEST_Gingerscope","copies":1}],
        **kw,
    }

def event(**kw):
    return {
        "eventId":"TEST_event_1",
        "epochId":"TEST_client_epoch",
        "revision":1,
        "kind":"OFFER_OBSERVED",
        "observedAt":EARLIER,
        **kw,
    }

class DurableStoreTests(unittest.TestCase):
    def setUp(self):
        self.folder=tempfile.TemporaryDirectory()
        self.path=Path(self.folder.name)/"durable.sqlite"
        self.store=Store(self.path)

    def tearDown(self):
        self.store.close()
        self.folder.cleanup()

    def assert_blocked(self,status):
        self.assertEqual(status["schema"],"gingerscope-private-state-v1")
        for k,v in DENIALS.items():
            self.assertEqual(status[k],v,k)
        self.assertEqual(status["plannerMode"],"BLOCKED_READ_ONLY")
        self.assertEqual(status["serverSettlementStatus"],"UNKNOWN")
        self.assertEqual(status["confirmedSettledTrades"],0)
        self.assertFalse(status["marketPriceDataExposed"])
        self.assertEqual(status["protectedOutboundItem"],"Gingerscope")
        self.assertNotIn("items",status)
        self.assertNotIn("prices",status)
        return status

    def test_initial_db_is_safely_blocked(self):
        s=self.assert_blocked(self.store.safe_status(now=NOW))
        self.assertEqual(s["marketStatus"],"UNAVAILABLE")
        self.assertEqual(s["inventoryCheckpointStatus"],"NONE")
        self.assertEqual(s["observedTradeEventsClientOnly"],0)

    def test_receipt_is_provenance_only_never_authorized(self):
        self.assertEqual(self.store.record_market_receipt(market(),now=NOW),
                         "STORED_RESEARCH_ONLY")
        s=self.assert_blocked(self.store.safe_status(now=NOW))
        self.assertEqual(s["marketStatus"],"RESEARCH_ONLY_UNEXPIRED")
        self.assertEqual(self.store.record_market_receipt(market(),now=NOW),"DUPLICATE")

    def test_receipt_expiry_does_not_get_refreshed_by_new_read(self):
        self.store.record_market_receipt(market(),now=NOW)
        s=self.assert_blocked(self.store.safe_status(now="2026-11-13T01:00:00Z"))
        self.assertEqual(s["marketStatus"],"STALE_RESEARCH")

    def test_receipt_survives_database_restart(self):
        self.store.record_market_receipt(market(),now=NOW)
        self.store.close()
        self.store=Store(self.path)
        self.assertEqual(self.assert_blocked(self.store.safe_status(now=NOW))["marketStatus"],
                         "RESEARCH_ONLY_UNEXPIRED")

    def test_market_replay_conflict_rejected(self):
        self.store.record_market_receipt(market(),now=NOW)
        with self.assertRaises(ConflictingReplay):
            self.store.record_market_receipt(market(itemCount=1199),now=NOW)
        self.assertEqual(self.store.db.execute(
            "select count(*) from market_receipts").fetchone()[0],1)

    def test_market_rejects_unauthorized_status_escalation(self):
        bad=market()
        bad["authorizesTrade"]=True
        with self.assertRaises(InvalidEvidence):
            self.store.record_market_receipt(bad,now=NOW)

    def test_market_rejects_invalid_source_times_and_fake_hash(self):
        for bad in (market(sourcePublishedAt=LATER),
                    market(retrievedAt=LATER),
                    market(expiresAt=EARLIER),
                    market(observationSha256="notahash"),
                    market(itemCount=True), market(itemCount=-4),
                    market(mode="VERIFIED_SETTLED")):
            with self.subTest(bad=bad):
                with self.assertRaises(InvalidEvidence):
                    self.store.record_market_receipt(bad,now=NOW)

    def test_market_counts_are_not_derived_pricing(self):
        self.store.record_market_receipt(market(itemCount=4999),now=NOW)
        self.assertFalse(self.store.safe_status(now=NOW)["verifiedRealMarketValue"])

    def test_realistic_120_weapon_types_and_stacks(self):
        payload=inventory(items=[
            {"rawKey":f"TEST_W_{i}","copies":(i%9)+1} for i in range(120)
        ])
        self.assertEqual(self.store.record_inventory(payload,now=NOW),"STORED_CLIENT_ONLY")
        self.assertEqual(self.store.record_inventory(payload,now=NOW),"DUPLICATE")
        self.assertEqual(self.assert_blocked(self.store.safe_status(now=NOW))[
            "inventoryCheckpointStatus"],"CLIENT_ONLY")
        self.assertEqual(self.store.db.execute(
            "SELECT COUNT(*) FROM inventory_checkpoints").fetchone()[0],1)

    def test_inventory_gingerscope_may_be_owned_but_never_outgoing(self):
        self.store.record_inventory(inventory(),now=NOW)
        self.assertEqual(self.assert_blocked(self.store.safe_status(now=NOW))[
            "protectedOutboundItem"],"Gingerscope")
        self.assertFalse(self.store.safe_status(now=NOW)["authorizesOffer"])

    def test_duplicate_inventory_copy_and_boolean_rejected(self):
        for items in (
            [{"rawKey":"TEST_A","copies":2},{"rawKey":"TEST_A","copies":3}],
            [{"rawKey":"TEST_A","copies":True}],
            [{"rawKey":"TEST_A","copies":-1}],
            [{"rawKey":"TEST_A","copies":10001}],
            [{"rawKey":"TEST A","copies":3}],
        ):
            with self.subTest(items=items):
                with self.assertRaises(InvalidEvidence):
                    self.store.record_inventory(inventory(items=items),now=NOW)

    def test_inventory_conflict_and_stale_restart_replay(self):
        self.store.record_inventory(inventory(),now=NOW)
        with self.assertRaises(ConflictingReplay):
            self.store.record_inventory(inventory(items=[]),now=NOW)
        self.store.record_inventory(inventory(
            checkpointId="TEST_checkpoint_2",observedAt=NOW),now=NOW)
        with self.assertRaises(InvalidEvidence):
            self.store.record_inventory(inventory(
                checkpointId="TEST_checkpoint_3",observedAt=EARLIER),now=NOW)
        self.store.close()
        self.store=Store(self.path)
        self.assertEqual(self.store.db.execute(
            "SELECT COUNT(*) FROM inventory_checkpoints").fetchone()[0],2)

    def test_inventory_unknown_identity_is_not_authenticated(self):
        self.store.record_inventory(inventory(),now=NOW)
        self.assertFalse(self.assert_blocked(self.store.safe_status(now=NOW))[
            "rawWeaponIdentityVerified"])

    def test_client_event_is_not_settlement(self):
        self.assertEqual(self.store.record_trade_event(event(),now=NOW),
                         "STORED_CLIENT_ONLY")
        self.assertEqual(self.store.record_trade_event(event(),now=NOW),"DUPLICATE")
        s=self.assert_blocked(self.store.safe_status(now=NOW))
        self.assertEqual(s["observedTradeEventsClientOnly"],1)
        self.assertFalse(s["maySendDiscordWebhook"])
        self.assertFalse(s["mayUseForStrategyLearning"])

    def test_explicit_server_settlement_or_profit_never_enters_client_stream(self):
        for kind in ("VERIFIED_SETTLED","PROFIT","COMPLETED","ACCEPTED","UNKNOWN"):
            with self.subTest(kind=kind):
                with self.assertRaises(InvalidEvidence):
                    self.store.record_trade_event(event(kind=kind),now=NOW)
        self.assertEqual(self.store.db.execute(
            "SELECT COUNT(*) FROM client_trade_events").fetchone()[0],0)

    def test_accepted_side_effect_or_player_name_not_allowed(self):
        for changes in ({"serverSettlementProven":True},
                        {"offerItem":"Gingerscope"},
                        {"username":"TEST_PERSON"},
                        {"maySendDiscordWebhook":True}):
            x=event(**changes)
            with self.assertRaises(InvalidEvidence):
                self.store.record_trade_event(x,now=NOW)

    def test_event_revision_regression_and_duplicate_slot(self):
        self.store.record_trade_event(event(),now=NOW)
        self.store.record_trade_event(event(eventId="TEST_event_2",revision=2),now=NOW)
        with self.assertRaises(InvalidEvidence):
            self.store.record_trade_event(event(eventId="TEST_event_3",revision=1,
                                               kind="OUR_DECLINE"),now=NOW)
        with self.assertRaises(ConflictingReplay):
            self.store.record_trade_event(event(eventId="TEST_event_3",revision=2),now=NOW)
        self.assertEqual(self.store.db.execute(
            "SELECT COUNT(*) FROM client_trade_events").fetchone()[0],2)

    def test_conflicting_event_idempotency(self):
        self.store.record_trade_event(event(),now=NOW)
        with self.assertRaises(ConflictingReplay):
            self.store.record_trade_event(event(kind="OUR_DECLINE"),now=NOW)
        self.assertEqual(self.store.record_trade_event(event(),now=NOW),"DUPLICATE")

    def test_out_of_order_epoch_does_not_invalidate_newer_epoch(self):
        self.store.record_trade_event(event(epochId="TEST_epoch_A",revision=20),now=NOW)
        self.assertEqual(self.store.record_trade_event(event(
            eventId="TEST_event_B",epochId="TEST_epoch_B",revision=0),now=NOW),
            "STORED_CLIENT_ONLY")

    def test_health_job_lease_single_owner_and_persists(self):
        self.store.prepare_health_job(now=NOW)
        with Store(self.path) as second:
            self.assertTrue(self.store.claim_health_job(token="TEST_lease_A",now=NOW))
            self.assertFalse(second.claim_health_job(token="TEST_lease_B",now=NOW))
            self.assertFalse(second.finish_health_job(token="TEST_lease_B",now=NOW))
            self.assertTrue(self.store.finish_health_job(token="TEST_lease_A",now=NOW))
            self.assertFalse(second.claim_health_job(token="TEST_lease_B",now=NOW))
        self.assertEqual(self.store.safe_status(now=NOW)["healthJobStatus"],
                         "OK_PRIVATE_LOCAL")

    def test_stale_job_lease_recovered_after_crash(self):
        self.store.prepare_health_job(now=EARLIER)
        self.assertTrue(self.store.claim_health_job(
            token="TEST_stale_owner",now=EARLIER,lease_seconds=30))
        self.store.close()
        self.store=Store(self.path)
        self.assertTrue(self.store.claim_health_job(token="TEST_new_owner",now=NOW))
        self.assertFalse(self.store.finish_health_job(token="TEST_stale_owner",now=NOW))
        self.assertTrue(self.store.finish_health_job(token="TEST_new_owner",now=NOW))

    def test_job_invalid_limits_and_no_market_job(self):
        with self.assertRaises(InvalidEvidence):
            self.store.prepare_health_job(now=NOW,interval_seconds=0)
        self.store.prepare_health_job(now=NOW)
        with self.assertRaises(InvalidEvidence):
            self.store.claim_health_job(token="TEST_t",now=NOW,lease_seconds=0)
        self.assertEqual(self.store.db.execute(
            "SELECT COUNT(*) FROM job_state WHERE job_name='market_refresh'").fetchone()[0],0)

    def test_no_leaked_values_in_status_after_many_events(self):
        self.store.record_market_receipt(market(),now=NOW)
        self.store.record_inventory(inventory(),now=NOW)
        self.store.record_trade_event(event(),now=NOW)
        raw=json.dumps(self.assert_blocked(self.store.safe_status(now=NOW)))
        for banned in ("TEST_W1", "TEST_Gingerscope", "TEST_market", "TEST_client_epoch",
                       "TEST_event_1","observationSha256","rawKey","sourcePublishedAt"):
            self.assertNotIn(banned,raw)

    def test_suspicious_250_invalid_proposals_never_escalate(self):
        rnd=random.Random(20261112)
        fields=("authorizesAccept","DiscordWebhook","eventId","kind","revision")
        for _ in range(250):
            x=event(eventId=f"TEST_random_{_}")
            f=rnd.choice(fields)
            x[f]=rnd.choice((True,None,-1,"VERIFIED_SETTLED","../private"))
            try:
                self.store.record_trade_event(x,now=NOW)
            except InvalidEvidence:
                pass
            self.assert_blocked(self.store.safe_status(now=NOW))

    def test_backup_is_consistent_with_live_wal_and_can_reopen_as_restored_db(self):
        self.store.record_market_receipt(market(),now=NOW)
        self.store.record_inventory(inventory(),now=NOW)
        self.store.record_trade_event(event(),now=NOW)
        # Deliberately leave WAL checkpoint timing to SQLite; online backup
        # must carry committed records, not merely copy the main .sqlite file.
        backup=Path(self.folder.name)/"private-backup-1.sqlite"
        self.assertEqual(self.store.backup_to(backup),
                         "PRIVATE_BACKUP_CREATED_AND_INTEGRITY_CHECKED")
        self.assertTrue(backup.exists())
        with sqlite3.connect(backup) as raw:
            self.assertEqual(raw.execute("PRAGMA integrity_check").fetchone()[0],"ok")
            self.assertEqual(raw.execute("SELECT COUNT(*) FROM market_receipts").fetchone()[0],1)
            self.assertEqual(raw.execute("SELECT COUNT(*) FROM inventory_checkpoints").fetchone()[0],1)
            self.assertEqual(raw.execute("SELECT COUNT(*) FROM client_trade_events").fetchone()[0],1)
        with Store(backup) as restored:
            result=self.assert_blocked(restored.safe_status(now=NOW))
            self.assertEqual(result["observedTradeEventsClientOnly"],1)
            self.assertEqual(result["inventoryCheckpointStatus"],"CLIENT_ONLY")
            self.assertEqual(result["marketStatus"],"RESEARCH_ONLY_UNEXPIRED")
        self.assertFalse(list(Path(self.folder.name).glob(".gingerscope-backup-*.part")))
        if os.name == "posix":
            self.assertEqual(backup.stat().st_mode & 0o777,0o600)

    def test_backup_never_overwrites_original_or_existing_destination(self):
        self.store.record_inventory(inventory(),now=NOW)
        before=self.path.read_bytes()
        with self.assertRaises(InvalidEvidence):
            self.store.backup_to(self.path)
        self.assertEqual(self.path.read_bytes(),before)
        target=Path(self.folder.name)/"existing.sqlite"
        target.write_bytes(b"DO_NOT_REPLACE_THIS_FILE")
        with self.assertRaises(InvalidEvidence):
            self.store.backup_to(target)
        self.assertEqual(target.read_bytes(),b"DO_NOT_REPLACE_THIS_FILE")

    def test_backup_rejects_missing_parent_and_symlink_destination(self):
        parent=Path(self.folder.name)
        with self.assertRaises(InvalidEvidence):
            self.store.backup_to(parent/"no-such-dir"/"copy.sqlite")
        target=parent/"real-existing.sqlite"
        target.write_bytes(b"PROTECT_EXISTING")
        link=parent/"linked.sqlite"
        try:
            link.symlink_to(target)
        except (NotImplementedError, OSError):
            self.skipTest("symlink creation not supported")
        with self.assertRaises(InvalidEvidence):
            self.store.backup_to(link)
        self.assertEqual(target.read_bytes(),b"PROTECT_EXISTING")

    def test_backup_after_new_events_uses_new_destination_and_does_not_change_old(self):
        first=Path(self.folder.name)/"first.sqlite"
        second=Path(self.folder.name)/"second.sqlite"
        self.store.record_trade_event(event(),now=NOW)
        self.store.backup_to(first)
        self.store.record_trade_event(event(
            eventId="TEST_event_2",revision=2,kind="COUNTEROFFER_OBSERVED"),now=NOW)
        self.store.backup_to(second)
        for dbfile,expected in ((first,1),(second,2)):
            with sqlite3.connect(dbfile) as db:
                self.assertEqual(db.execute(
                    "SELECT COUNT(*) FROM client_trade_events").fetchone()[0],expected)
        with self.assertRaises(InvalidEvidence):
            self.store.backup_to(first)

    def test_backup_cli_creates_file_without_dumping_private_records(self):
        self.store.record_inventory(inventory(),now=NOW)
        destination=Path(self.folder.name)/"cli-backup.sqlite"
        out=StringIO()
        with redirect_stdout(out):
            self.assertEqual(runtime.main([
                "backup","--db",str(self.path),"--to",str(destination)]),0)
        result=json.loads(out.getvalue())
        self.assertEqual(result["backup"],"PRIVATE_BACKUP_CREATED_AND_INTEGRITY_CHECKED")
        self.assertFalse(result["contentsExposed"])
        self.assertNotIn("TEST_Gingerscope",out.getvalue())
        with Store(destination) as restored:
            self.assertEqual(restored.safe_status(now=NOW)["inventoryCheckpointStatus"],
                             "CLIENT_ONLY")

    def test_invalid_schema_version_is_rejected_at_database_boundary(self):
        # CHECK(version=1) prevents silent migration/overwrite by default.
        with self.assertRaises(sqlite3.IntegrityError):
            self.store.db.execute("UPDATE schema_metadata SET version=99")
        self.store.close()
        self.store=Store(self.path)
        self.assertEqual(self.store.db.execute(
            "SELECT version FROM schema_metadata").fetchone()[0],1)

class PrivateRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.folder=tempfile.TemporaryDirectory()
        self.path=Path(self.folder.name)/"runtime.sqlite"

    def tearDown(self):
        self.folder.cleanup()

    def test_once_persists_and_does_not_request_market_data(self):
        out=runtime.run_once(self.path,now=NOW,token="TEST_health")
        self.assertEqual(out["healthJobStatus"],"OK_PRIVATE_LOCAL")
        self.assertFalse(out["authorizesOffer"])
        out2=runtime.run_once(self.path,now=NOW,token="TEST_next")
        self.assertEqual(out2["healthJobStatus"],"OK_PRIVATE_LOCAL")
        self.assertFalse(out2["maySendDiscordWebhook"])

    def test_cli_init_and_once_emit_safe_status_only(self):
        f=StringIO()
        with redirect_stdout(f):
            self.assertEqual(runtime.main(["init","--db",str(self.path)]),0)
        initial=json.loads(f.getvalue())
        self.assertEqual(initial["plannerMode"],"BLOCKED_READ_ONLY")
        f=StringIO()
        with redirect_stdout(f):
            self.assertEqual(runtime.main(["once","--db",str(self.path)]),0)
        self.assertEqual(json.loads(f.getvalue())["healthJobStatus"],"OK_PRIVATE_LOCAL")

    def test_read_only_http_api_requires_private_token(self):
        with Store(self.path) as _:
            pass
        handler=runtime.make_handler(self.path,SECRET)
        server=ThreadingHTTPServer(("127.0.0.1",0),handler)
        server.daemon_threads=True
        thread=threading.Thread(target=server.serve_forever,daemon=True)
        thread.start()
        try:
            port=server.server_address[1]
            def get(path,method="GET",header=None):
                conn=http.client.HTTPConnection("127.0.0.1",port,timeout=2)
                conn.request(method,path,headers=header or {})
                resp=conn.getresponse()
                text=resp.read().decode("utf-8")
                conn.close()
                return resp.status,json.loads(text)
            self.assertEqual(get("/healthz"),(200,{"status":"ALIVE_NOT_MARKET_READY"}))
            self.assertEqual(get("/v1/status")[0],401)
            self.assertEqual(get("/v1/status",header={"Authorization":"Bearer WRONG"})[0],401)
            code,body=get("/v1/status",header={"Authorization":"Bearer "+SECRET})
            self.assertEqual(code,200)
            self.assertFalse(body["authorizesTrade"])
            self.assertEqual(body["marketStatus"],"UNAVAILABLE")
            self.assertNotIn(SECRET,str(body))
            self.assertEqual(get("/v1/status",method="POST")[0],405)
            self.assertEqual(get("/v1/prices",header={
                "Authorization":"Bearer "+SECRET})[0],404)
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=3)

    def test_headless_worker_initializes_without_an_http_server_or_token(self):
        class StopAtFirstWait:
            waits=[]
            def wait(self, duration):
                self.waits.append(duration)
                return True
        stop=StopAtFirstWait()
        runtime.run_private_worker(self.path,stop_event=stop)
        self.assertEqual(stop.waits,[300])
        with Store(self.path) as store:
            result=store.safe_status(now=runtime.current_time())
            self.assertEqual(result["healthJobStatus"],"OK_PRIVATE_LOCAL")
            self.assertFalse(result["authorizesTrade"])
            self.assertFalse(result["maySendDiscordWebhook"])

    def test_headless_worker_retries_local_health_on_tick_only(self):
        from unittest.mock import patch
        class TwoTicks:
            def __init__(self):
                self.calls=0
            def wait(self,duration):
                self.calls+=1
                self.last_duration=duration
                return self.calls==2
        stop=TwoTicks()
        with patch.object(runtime,"run_once",return_value={}) as called:
            runtime.run_private_worker(self.path,stop_event=stop,
                                       interval_seconds=45)
        self.assertEqual(called.call_count,2)
        self.assertEqual(stop.calls,2)
        self.assertEqual(stop.last_duration,45)

    def test_production_worker_refuses_undurable_data_path(self):
        from unittest.mock import patch
        class Stop:
            def wait(self,_):
                return True
        with patch.object(runtime.os.path,"ismount",return_value=False):
            with patch.object(runtime,"run_once") as called:
                with self.assertRaisesRegex(RuntimeError,
                                            "PRODUCTION_SQLITE_VOLUME_NOT_MOUNTED"):
                    runtime.run_private_worker("/data/gingerscope.sqlite",stop_event=Stop())
                called.assert_not_called()

    def test_production_worker_accepts_mounted_data_path_without_network(self):
        from unittest.mock import patch
        class Stop:
            def wait(self,_):
                return True
        with patch.object(runtime.os.path,"ismount",return_value=True):
            with patch.object(runtime,"run_once",return_value={}) as run:
                runtime.run_private_worker("/data/gingerscope.sqlite",stop_event=Stop())
                run.assert_called_once_with("/data/gingerscope.sqlite")

    def test_worker_rejects_data_path_symlink_escape(self):
        from unittest.mock import patch
        with patch.object(runtime.Path,"resolve",return_value=Path("/tmp/ephemeral.sqlite")):
            with patch.object(runtime.os.path,"ismount",return_value=True):
                with self.assertRaisesRegex(RuntimeError,"PRODUCTION_DB_PATH_ESCAPE_BLOCKED"):
                    runtime._require_railway_persistent_volume("/data/gingerscope.sqlite")

    def test_worker_fails_closed_on_invalid_interval(self):
        from unittest.mock import patch
        with patch.object(runtime,"run_once",side_effect=AssertionError("NO_IO")):
            for value in (0,29,3601,True,"300"):
                with self.subTest(interval=value):
                    with self.assertRaises(ValueError):
                        runtime.run_private_worker(self.path,interval_seconds=value)

    def test_worker_cli_runs_headless_without_http_or_provider_key(self):
        from unittest.mock import patch
        with patch.object(runtime,"run_private_worker") as worker:
            self.assertEqual(runtime.main(["worker","--db",str(self.path)]),0)
            worker.assert_called_once_with(self.path)

    def test_server_token_policy_fail_closed(self):
        for token in (None,"", "weak", "é"*64):
            with self.subTest(token=repr(token)):
                with self.assertRaises(ValueError):
                    runtime.make_handler(self.path,token)

if __name__=="__main__":
    unittest.main()
