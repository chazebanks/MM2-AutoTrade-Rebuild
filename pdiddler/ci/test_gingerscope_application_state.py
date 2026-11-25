"""Exercise the actual offline state store and its recovery boundaries."""
from __future__ import annotations

import json
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import unittest

from pdiddler.system2.application_state import StateError, StateStore


CAPTURED = "2026-11-25T07:00:00Z"
PUBLISHED = "2026-11-23T23:00:00Z"
NEW_PUBLISHED = "2026-11-24T23:00:00Z"
NOW = "2026-11-25T08:00:00Z"
LATER = "2026-11-25T08:05:00Z"
LEASE_END = "2026-11-25T08:10:00Z"
EXPIRES = "2026-11-25T12:00:00Z"
GIVE = {"godly:Fang": 1}
RECEIVE = {"godly:Boneblade": 1}
ACCOUNTS = {"main": GIVE, "alt": {"unknown:Unmapped": 1}}
MARKET_HASH = "a" * 64


def sync(store, *, accounts=ACCOUNTS, digest=MARKET_HASH, published=PUBLISHED, listed_values=None):
    return store.sync_inputs(
        market_sha256=digest, publisher_updated_at=published, captured_at=CAPTURED,
        expires_at=EXPIRES, accounts=accounts, listed_values=listed_values,
    )


def event(event_id, sequence, revision, kind, **payload):
    return dict(event_id=event_id, session_id="episode", sequence=sequence,
                revision=revision, kind=kind, **payload)


def offer(store, token, **payload):
    store.observe(event("accepted", 1, 0, "PARTNER_REQUEST_ACCEPTED"), owner=token, now=NOW)
    return store.observe(
        event("offered", 2, 1, "OFFER_OBSERVED", **(payload or {"give": GIVE, "receive": RECEIVE})),
        owner=token, now=NOW,
    )


def witnesses():
    return [
        {"side": "account", "source_id": "synthetic-1", "before": GIVE, "after": RECEIVE},
        {"side": "counterparty", "source_id": "synthetic-2", "before": RECEIVE, "after": GIVE},
    ]


class ApplicationStateTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.path = Path(directory.name) / "state.sqlite3"

    def test_persistent_market_and_separate_account_revisions(self):
        with StateStore(self.path) as state:
            self.assertEqual(sync(state), 1)
            self.assertEqual(sync(state), 1)
            transferred = {"main": {}, "alt": {**ACCOUNTS["alt"], **GIVE}}
            self.assertEqual(sync(state, accounts=transferred), 2)
            self.assertEqual(sync(state, accounts=transferred, digest="b" * 64,
                                  published=NEW_PUBLISHED), 3)
        with StateStore(self.path) as state:
            self.assertEqual(state.inputs(1)["accounts"], ACCOUNTS)
            self.assertEqual(state.inputs(2)["accounts"], transferred)
            self.assertEqual(state.inputs()["marketSha256"], "b" * 64)
            self.assertIsNone(state.summary()["realizedGrowth"])

    def test_edition_conflict_does_not_change_current_revision(self):
        with StateStore(self.path) as state:
            sync(state)
            with self.assertRaises(StateError):
                state.sync_inputs(
                    market_sha256=MARKET_HASH, publisher_updated_at=PUBLISHED,
                    captured_at=CAPTURED, expires_at="2026-11-25T13:00:00Z",
                    accounts={"main": {}, "alt": {}},
                )
            self.assertEqual(state.inputs()["accounts"], ACCOUNTS)

    def test_older_edition_and_stale_inventory_writer_are_rejected(self):
        with StateStore(self.path) as state:
            sync(state)
            with StateStore(self.path) as concurrent:
                sync(concurrent, accounts={"main": {}, "alt": {}})
            for changes in [
                {"expected_input_revision": 1},
                {"market_sha256": "b" * 64, "publisher_updated_at": "2026-11-22T23:00:00Z"},
                {"market_sha256": "b" * 64, "captured_at": NOW},
            ]:
                fields = dict(market_sha256=MARKET_HASH, publisher_updated_at=PUBLISHED,
                              captured_at=CAPTURED, expires_at=EXPIRES, accounts=ACCOUNTS)
                with self.subTest(changes=changes), self.assertRaises(StateError):
                    state.sync_inputs(**{**fields, **changes})
            self.assertEqual(state.inputs()["inputRevision"], 2)
            self.assertEqual(state.inputs()["accounts"], {"main": {}, "alt": {}})

    def test_evaluations_follow_input_and_expiry(self):
        with StateStore(self.path) as state:
            revision = sync(state)
            fields = dict(input_revision=revision, report={"mode": "HYPOTHETICAL"}, evaluated_at=NOW)
            self.assertTrue(state.record_evaluation("eval", **fields))
            self.assertFalse(state.record_evaluation("eval", **fields))
            with self.assertRaises(StateError):
                state.record_evaluation("eval", **{**fields, "report": {"mode": "CONFLICT"}})
            self.assertIsNotNone(state.current_evaluation("eval", now=EXPIRES))
            self.assertIsNone(state.current_evaluation("eval", now="2026-11-25T12:00:01Z"))
            self.assertIsNone(state.current_evaluation("eval", now=CAPTURED))
            sync(state, digest="b" * 64, published=NEW_PUBLISHED)
            self.assertIsNone(state.current_evaluation("eval", now=NOW))
            self.assertEqual(state.evaluation_history("eval")["inputRevision"], 1)
            with self.assertRaises(StateError):
                state.record_evaluation("stale", **fields)

    def test_exact_offer_and_evidence_revisions_invalidate_advice(self):
        with StateStore(self.path) as state:
            revision = sync(state)
            token = state.start_session("episode", account="main", now=NOW, lease_until=LEASE_END)
            offer(state, token)
            fields = dict(input_revision=revision, report={"mode": "HYPOTHETICAL"},
                          evaluated_at=NOW, session_id="episode")
            state.record_evaluation("first", offer_revision=1, **fields)
            self.assertIsNotNone(state.current_evaluation("first", now=NOW))
            revised = event("revised", 3, 2, "MAIN_OFFER_REVISION", give={}, receive=RECEIVE)
            self.assertTrue(state.observe(revised, owner=token, now=LATER))
            self.assertIsNone(state.current_evaluation("first", now=LATER))
            state.record_evaluation("second", offer_revision=2, **{**fields, "evaluated_at": LATER})
            indicator = event("indicator", 4, 2, "PARTNER_ACCEPT_INDICATOR")
            state.observe(indicator, owner=token, now=LATER)
            self.assertIsNone(state.current_evaluation("second", now=LATER))
            self.assertIsNone(state.summary()["realizedGrowth"])

    def test_wrong_owner_stale_sequence_and_mutated_duplicate_rejected(self):
        with StateStore(self.path) as state:
            sync(state)
            token = state.start_session("episode", account="alt", now=NOW, lease_until=LEASE_END)
            exact = event("accepted", 1, 0, "PARTNER_REQUEST_ACCEPTED")
            with self.assertRaises(StateError):
                state.observe(exact, owner="different-owner", now=NOW)
            self.assertTrue(state.observe(exact, owner=token, now=NOW))
            self.assertFalse(state.observe(exact, owner=token, now=LATER))
            for bad in [
                {**exact, "kind": "PARTNER_DECLINED"},
                event("different", 1, 0, "PARTNER_REQUEST_ACCEPTED"),
                event("future", 4, 2, "MAIN_OFFER_REVISION", give=GIVE, receive=RECEIVE),
                event("false-complete", 2, 0, "COMPLETED"),
                event("bad-quantity", 2, 1, "OFFER_OBSERVED", give={"godly:Fang": True}, receive=RECEIVE),
            ]:
                with self.subTest(kind=bad["kind"]), self.assertRaises(StateError):
                    state.observe(bad, owner=token, now=NOW)

    def test_interruption_is_replayable_and_does_not_change_balances(self):
        with StateStore(self.path) as state:
            sync(state)
            token = state.start_session("episode", account="main", now=NOW, lease_until=LEASE_END)
            offer(state, token)
            ended = event("interrupt", 3, 1, "SESSION_INTERRUPTED")
            self.assertTrue(state.observe(ended, owner=token, now=LATER))
        with StateStore(self.path) as state:
            self.assertFalse(state.observe(ended, owner=token, now=LEASE_END))
            summary = state.summary()
            self.assertEqual(summary["outcomeCounts"]["SESSION_INTERRUPTED"], 1)
            self.assertEqual(summary["unresolvedSessions"], 1)
            self.assertEqual(summary["syntheticSettlements"], 0)
            self.assertIsNone(summary["realizedGrowth"])
            self.assertNotIn("Fang", json.dumps(summary))
            self.assertNotIn("episode", json.dumps(summary))
            self.assertEqual(state.inputs()["accounts"], ACCOUNTS)

    def test_restart_preserves_active_owner_then_releases_expired_lease_once(self):
        with StateStore(self.path) as before:
            sync(before)
            token = before.start_session("episode", account="main", now=NOW, lease_until=LEASE_END)
            offer(before, token)
            with StateStore(self.path) as concurrent:
                self.assertEqual(concurrent.recover(now=LATER), 0)
                with self.assertRaises(StateError):
                    concurrent.start_session("overlap", account="alt", now=LATER, lease_until=LEASE_END)
        with StateStore(self.path) as state:
            self.assertEqual(state.recover(now=LEASE_END), 1)
            self.assertEqual(state.recover(now=LEASE_END), 0)
            self.assertEqual(state.summary()["unresolvedSessions"], 1)
            state.start_session("fresh", account="main", now=LEASE_END, lease_until=EXPIRES)
            with self.assertRaises(StateError):
                state.observe(event("late", 3, 1, "MAIN_ACCEPT_INDICATOR"), owner=token, now=LEASE_END)
            self.assertEqual(state.summary()["activeSessions"], 1)

    def test_session_open_and_input_revision_commit_together(self):
        fields = dict(market_sha256=MARKET_HASH, publisher_updated_at=PUBLISHED,
                      captured_at=CAPTURED, expires_at=EXPIRES, accounts=ACCOUNTS)
        with StateStore(self.path) as state:
            token = state.start_session("episode", account="main", now=NOW, lease_until=LEASE_END,
                                        inputs=fields)
            self.assertEqual(state.inputs()["inputRevision"], 1)
            self.assertEqual(state.summary()["activeSessions"], 1)
            changed = {**fields, "accounts": {"main": {}, "alt": {}}}
            with self.assertRaisesRegex(StateError, "current portfolio revision"):
                state.sync_inputs(**changed)
            self.assertEqual(state.inputs()["accounts"], ACCOUNTS)
            state.stop_session("episode", owner=token, now=LATER)
            with self.assertRaisesRegex(StateError, "cannot be reopened"):
                state.start_session("episode", account="main", now=LATER, lease_until=LEASE_END,
                                    inputs=changed)
            self.assertEqual(state.inputs()["inputRevision"], 1)
            self.assertEqual(state.inputs()["accounts"], ACCOUNTS)

    def test_explicit_market_change_during_session_invalidates_evaluation(self):
        with StateStore(self.path) as state:
            revision = sync(state)
            token = state.start_session("episode", account="main", now=NOW, lease_until=LEASE_END)
            offer(state, token)
            state.record_evaluation("eval", input_revision=revision, report={}, evaluated_at=NOW,
                                    session_id="episode", offer_revision=1)
            self.assertIsNotNone(state.current_evaluation("eval", now=NOW))
            state.sync_inputs(market_sha256="b" * 64, publisher_updated_at=NEW_PUBLISHED,
                              captured_at=CAPTURED, expires_at=EXPIRES, accounts=ACCOUNTS,
                              expected_input_revision=revision)
            self.assertIsNone(state.current_evaluation("eval", now=NOW))
            self.assertEqual(state.summary()["activeSessions"], 1)
            with self.assertRaisesRegex(StateError, "session's starting inputs"):
                state.record_evaluation("wrong", input_revision=2, report={}, evaluated_at=NOW,
                                        session_id="episode", offer_revision=1)

    def test_safe_stop_is_idempotent_and_invalidates_session_evaluation(self):
        with StateStore(self.path) as state:
            revision = sync(state)
            token = state.start_session("episode", account="main", now=NOW, lease_until=LEASE_END)
            offer(state, token)
            state.record_evaluation("eval", input_revision=revision, report={}, evaluated_at=NOW,
                                    session_id="episode", offer_revision=1)
            self.assertTrue(state.stop_session("episode", owner=token, now=LATER))
            self.assertFalse(state.stop_session("episode", owner=token, now=LATER))
            self.assertIsNone(state.current_evaluation("eval", now=LATER))
            self.assertEqual(state.summary()["outcomeCounts"], {"SESSION_INTERRUPTED": 1})

    def test_corroborated_synthetic_settlement_is_atomic_and_deduplicated(self):
        with StateStore(self.path, scope="synthetic") as state:
            sync(state, accounts={"main": GIVE, "alt": {}},
                 listed_values={"godly:Fang": 10, "godly:Boneblade": 15})
            token = state.start_session("episode", account="main", now=NOW,
                                        lease_until=LEASE_END, counterparty=RECEIVE)
            offer(state, token)
            args = dict(owner=token, now=LATER, transaction_id="simulation", revision=1)
            conflict = witnesses()
            conflict[1]["after"] = {}
            with self.assertRaises(StateError):
                state.settle_synthetic("episode", witnesses=conflict, **args)
            self.assertEqual(state.inputs()["accounts"]["main"], GIVE)
            self.assertEqual(state.summary()["syntheticSettlements"], 0)
            self.assertTrue(state.settle_synthetic("episode", witnesses=witnesses(), **args))
        with StateStore(self.path, scope="synthetic") as state:
            self.assertFalse(state.settle_synthetic("episode", witnesses=witnesses(), **args))
            with self.assertRaises(StateError):
                state.settle_synthetic("episode", witnesses=conflict, **args)
            self.assertEqual(state.inputs()["accounts"]["main"], RECEIVE)
            self.assertEqual(state.inputs(1)["accounts"]["main"], GIVE)
            self.assertEqual(state.summary()["syntheticListedDelta"], 5)
            self.assertIsNone(state.summary()["realizedGrowth"])
            rows = state.synthetic_settlement_rows()
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0]["listed_delta"], 5)
            self.assertEqual(rows[0]["distinct_source_count"], 2)
            self.assertEqual(rows[0]["market_edition"], MARKET_HASH)
            self.assertNotIn("Fang", json.dumps(rows))
        with self.assertRaises(StateError):
            StateStore(self.path)

    def test_manual_state_has_no_synthetic_settlement_ingress(self):
        with StateStore(self.path) as state:
            sync(state)
            token = state.start_session("episode", account="main", now=NOW, lease_until=LEASE_END)
            offer(state, token)
            with self.assertRaises(StateError):
                state.settle_synthetic("episode", owner=token, now=LATER,
                                       transaction_id="x", revision=1, witnesses=witnesses())
            self.assertEqual(state.synthetic_settlement_rows(), [])
            self.assertEqual(state.inputs()["accounts"], ACCOUNTS)

    def test_unsafe_synthetic_offers_do_not_change_holdings(self):
        protected = {"ancient:Gingerscope": 1}
        prices = {"ancient:Gingerscope": 4, "godly:Fang": 10, "godly:Boneblade": 15}
        scenarios = [
            (protected, GIVE, "inventory protections"),
            ({"godly:Fang": 2}, {"godly:Boneblade": 2}, "exceed the starting holdings"),
            (RECEIVE, GIVE, "Unapproved listed loss"),
            ({"unknown:Unmapped": 1}, GIVE, "Unknown item values"),
        ]
        for i, (give, receive, reason) in enumerate(scenarios):
            with self.subTest(give=give), StateStore(
                self.path.with_suffix(f".{i}.sqlite3"), scope="synthetic"
            ) as state:
                initial = {"main": {**protected, **GIVE, **RECEIVE, "unknown:Unmapped": 1}, "alt": {}}
                sync(state, accounts=initial, listed_values=prices)
                token = state.start_session("episode", account="main", counterparty=receive,
                                            now=NOW, lease_until=LEASE_END)
                offer(state, token, give=give, receive=receive)
                claim = [
                    {"side": "account", "source_id": "a", "before": initial["main"], "after": {}},
                    {"side": "counterparty", "source_id": "b", "before": GIVE, "after": GIVE},
                ]
                with self.assertRaisesRegex(StateError, reason):
                    state.settle_synthetic("episode", owner=token, now=LATER,
                                           transaction_id="unsafe", revision=1, witnesses=claim)
                self.assertEqual(state.inputs()["accounts"], initial)
                self.assertEqual(state.synthetic_settlement_rows(), [])

    def test_crash_during_actual_database_write_rolls_back(self):
        with StateStore(self.path) as state:
            sync(state)
        crash = """
import os, sys
from pdiddler.system2.application_state import StateStore
with StateStore(sys.argv[1]) as state:
    def trace(sql):
        if sql == 'COMMIT':
            os._exit(92)
    state._db.set_trace_callback(trace)
    state.sync_inputs(market_sha256='b'*64, publisher_updated_at='2026-11-24T23:00:00Z',
                      captured_at='2026-11-25T07:00:00Z', expires_at='2026-11-25T12:00:00Z',
                      accounts={'main': {}, 'alt': {}})
"""
        result = subprocess.run([sys.executable, "-c", crash, str(self.path)], check=False)
        self.assertEqual(result.returncode, 92)
        with StateStore(self.path) as state:
            self.assertEqual(state.inputs()["marketSha256"], MARKET_HASH)
            self.assertEqual(state.inputs()["accounts"], ACCOUNTS)

    def test_incompatible_versions_and_non_database_bytes_rejected(self):
        with StateStore(self.path):
            pass
        with sqlite3.connect(self.path) as db:
            db.execute("PRAGMA user_version=31337")
        with self.assertRaises(StateError):
            StateStore(self.path)
        self.path.write_bytes(b"incomplete and corrupt")
        with self.assertRaises(StateError):
            StateStore(self.path)

    def test_damaged_json_records_and_missing_dependencies_are_rejected(self):
        for name, statement in [
            ("bad-json", "UPDATE inputs SET accounts='broken-json'"),
            ("bad-ref", "DELETE FROM markets"),
            ("bad-index", "DROP INDEX one_active_session"),
        ]:
            with self.subTest(name=name):
                path = self.path.with_suffix(f".{name}.sqlite3")
                with StateStore(path) as state:
                    sync(state)
                with sqlite3.connect(path) as db:
                    db.execute("PRAGMA ignore_check_constraints=ON")
                    db.execute(statement)
                with self.assertRaises(StateError):
                    StateStore(path)


if __name__ == "__main__":
    unittest.main()
