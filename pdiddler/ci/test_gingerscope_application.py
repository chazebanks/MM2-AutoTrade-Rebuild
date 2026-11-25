"""Executable offline workflow tests through the supported CLI."""

import json
from hashlib import sha256
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from datetime import datetime

from pdiddler.ci.test_supreme_market_editions import BASE_CAPTURE, NEXT_CAPTURE, archive


CLOCK = "2026-11-25T07:52:05Z"
ROOT = Path(__file__).resolve().parents[2]
ACCOUNTS = {"main": {"godly:Fang": 1, "godly:Missing": 2}, "alt": {"godly:Boneblade": 1}}
STOCK = {"godly:Boneblade": 1, "godly:Orange_Seer": 2}


class ApplicationTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.folder = Path(temporary.name)
        self.database = self.folder / "state.sqlite"
        self.request = self.folder / "request.json"

    def invoke(self, command, *, data=None, args=(), expected=0, clock=CLOCK, options=()):
        if data is not None:
            self.request.write_text(json.dumps(data))
        proc = subprocess.run(
            [sys.executable, "-m", "pdiddler.gingerscope", "--database", str(self.database),
             "--synthetic", "--replay-at", clock, *options, command, *args],
            cwd=ROOT, capture_output=True, text=True, timeout=30,
        )
        self.assertEqual(proc.returncode, expected, proc.stderr)
        return json.loads(proc.stdout) if expected == 0 else proc.stderr

    def test_review_integrates_accounting_candidate_search_and_state(self):
        result = self.invoke(
            "review", data={"accounts": ACCOUNTS, "counterparties": [STOCK]},
            args=[str(self.request)],
        )
        self.assertEqual(result["clock"], "HISTORICAL_REPLAY")
        self.assertEqual(result["report"]["portfolio"]["accounts"]["main"]["unpriced_copies"], 2)
        self.assertIsNone(result["report"]["portfolio"]["combined"]["total_listed_value"])
        self.assertIsInstance(result["report"]["planning"]["alternatives"], list)
        self.assertIsNotNone(result["inputRevision"])
        self.assertFalse(result["report"]["authority"]["authorizesTrade"])
        current = self.invoke("current", args=[result["evaluationId"]])
        self.assertEqual(current["evaluation"]["report"], result["report"])
        revised = {"main": {"godly:Fang": 2}, "alt": ACCOUNTS["alt"]}
        self.invoke("review", data={"accounts": revised}, args=[str(self.request)])
        stale = self.invoke("current", args=[result["evaluationId"]])
        self.assertIsNone(stale["evaluation"])

    def test_controlled_revision_and_interruption_invalidate_evaluations(self):
        def event(sequence, revision, kind, **offer):
            return {"session_id": "fixture-session", "event_id": f"fixture-{sequence}",
                    "sequence": sequence, "revision": revision, "kind": kind, **offer}

        result = self.invoke(
            "simulate-session",
            data={"accounts": ACCOUNTS, "sessionId": "fixture-session", "counterpartyStock": STOCK,
                  "events": [
                      event(1, 0, "PARTNER_REQUEST_ACCEPTED"),
                      event(2, 1, "OFFER_OBSERVED", give={"godly:Fang": 1},
                            receive={"godly:Boneblade": 1}),
                      event(3, 2, "PARTNER_OFFER_REVISION", give={"godly:Fang": 1},
                            receive={"godly:Orange_Seer": 1}),
                      event(4, 2, "SESSION_INTERRUPTED"),
                  ]}, args=[str(self.request)],
        )
        self.assertEqual([item["offerRevision"] for item in result["offerEvaluations"]], [1, 2])
        for item in result["offerEvaluations"]:
            self.assertIsNone(self.invoke("current", args=[item["evaluationId"]])["evaluation"])
        status = self.invoke("recover")
        self.assertIsNone(status["realizedGrowth"])
        self.assertNotIn("fixture-session", json.dumps(status))
        self.assertNotIn("Fang", json.dumps(status))

    def test_bad_inputs_and_expired_source_fail_without_showing_holdings(self):
        error = self.invoke(
            "review", data={"accounts": {"main": {"godly:SensitiveLabel": True}, "alt": {}}},
            args=[str(self.request)], expected=2,
        )
        self.assertNotIn("SensitiveLabel", error)
        expired = self.invoke("review", data={"accounts": ACCOUNTS}, args=[str(self.request)],
                              clock="2026-11-26T00:00:00Z", expected=2)
        self.assertIn("SOURCE_EXPIRED", expired)

    def test_malformed_observation_does_not_open_session(self):
        failure = self.invoke(
            "simulate-session",
            data={"accounts": ACCOUNTS, "sessionId": "broken", "counterpartyStock": STOCK,
                  "events": [{"session_id": "broken", "kind": []}]},
            args=[str(self.request)], expected=2,
        )
        self.assertIn("bounded observations", failure)
        status = self.invoke("status")
        self.assertIsNone(status["inputRevision"])
        self.assertEqual(status["activeSessions"], 0)

    def test_current_detects_changed_persisted_report(self):
        review = self.invoke("review", data={"accounts": ACCOUNTS}, args=[str(self.request)])
        forged = review["report"]
        forged["authority"]["authorizesTrade"] = True
        with sqlite3.connect(self.database) as database:
            database.execute("UPDATE evaluations SET report=?", (json.dumps(forged),))
        failure = self.invoke("current", args=[review["evaluationId"]], expected=2)
        self.assertIn("integrity verification", failure)

    def test_single_offer_cannot_dispose_of_gingerscope(self):
        accounts = {"main": {"ancient:Gingerscope": 1}, "alt": {}}
        offer = {"give": accounts["main"], "receive": {"godly:Boneblade": 1},
                 "counterpartyStock": STOCK}
        failure = self.invoke("review", data={"accounts": accounts, "offer": offer},
                              args=[str(self.request)], expected=2)
        self.assertIn("protected", failure)
        self.assertIsNone(self.invoke("status")["inputRevision"])

    def test_manual_database_uses_current_clock_and_separate_scope(self):
        from contextlib import redirect_stdout
        from io import StringIO

        from pdiddler.gingerscope import main

        self.request.write_text(json.dumps({"accounts": ACCOUNTS}))
        output = StringIO()
        with patch("pdiddler.gingerscope.datetime") as clock, redirect_stdout(output):
            clock.now.return_value = datetime.fromisoformat(CLOCK)
            self.assertEqual(main(["--database", str(self.database), "review", str(self.request)]), 0)
        report = json.loads(output.getvalue())
        self.assertEqual(report["clock"], "CURRENT_UTC")
        self.assertEqual(report["inputRevision"], 1)
        self.assertIn("scope", self.invoke("status", expected=2).lower())

    def test_market_change_revalues_exact_same_holdings_and_invalidates_prior_report(self):
        accounts = {"main": {"godly:Bioblade": 1, "godly:RemovedWeapon": 1}, "alt": {}}
        old_path = self.folder / "old.json"
        new_path = self.folder / "new.json"
        previous, current = archive(), archive(changed=True)
        old_path.write_bytes(previous)
        new_path.write_bytes(current)
        old_options = ("--catalog", str(old_path), "--expected-market-sha256", sha256(previous).hexdigest())
        new_options = ("--catalog", str(new_path), "--expected-market-sha256", sha256(current).hexdigest())
        old = self.invoke("review", data={"accounts": accounts}, args=[str(self.request)],
                          clock=BASE_CAPTURE, options=old_options)
        new = self.invoke("review", data={"accounts": accounts}, args=[str(self.request)],
                          clock=NEXT_CAPTURE, options=new_options)
        self.assertEqual(old["report"]["portfolio"]["accounts"]["main"]["known_listed_value"], 23)
        new_balance = new["report"]["portfolio"]["accounts"]["main"]
        self.assertEqual(new_balance["known_listed_value"], 21)
        self.assertEqual(new_balance["unpriced_copies"], 1)
        self.assertIsNone(new["report"]["portfolio"]["realized_growth"])
        self.assertNotEqual(old["inputRevision"], new["inputRevision"])
        # The old evaluation is still invalid within its own source time window.
        stale = self.invoke("current", args=[old["evaluationId"]], clock=BASE_CAPTURE)
        self.assertIsNone(stale["evaluation"])

    def test_synthetic_settlement_is_counted_once_and_preserves_reconciliation_after_replay(self):
        fixture = "fixture-settlement"
        catalog = archive()
        path = self.folder / "market.json"
        path.write_bytes(catalog)
        options = ("--catalog", str(path), "--expected-market-sha256", sha256(catalog).hexdigest())
        own = {"godly:Bioblade": 1}
        other = {"godly:RemovedWeapon": 1}
        request = {
            "accounts": {"main": own, "alt": {}}, "sessionId": fixture, "counterpartyStock": other,
            "events": [
                {"event_id": "request", "session_id": fixture, "sequence": 1, "revision": 0,
                 "kind": "PARTNER_REQUEST_ACCEPTED"},
                {"event_id": "offer", "session_id": fixture, "sequence": 2, "revision": 1,
                 "kind": "OFFER_OBSERVED", "give": own, "receive": other},
            ],
            "settlement": {
                "transaction_id": "transaction-fixture", "revision": 1, "at": "2026-11-26T07:00:01Z",
                "witnesses": [
                    {"side": "account", "source_id": "source-a", "before": own, "after": other},
                    {"side": "counterparty", "source_id": "source-b", "before": other, "after": own},
                ],
            },
        }
        settled = self.invoke("simulate-session", data=request, args=[str(self.request)],
                              clock=BASE_CAPTURE, options=options)["status"]
        self.assertEqual(settled["syntheticSettlements"], 1)
        self.assertEqual(settled["syntheticListedDelta"], 3)
        self.assertIsNone(settled["realizedGrowth"])
        self.invoke("simulate-session", data=request, args=[str(self.request)],
                    clock=BASE_CAPTURE, options=options, expected=2)
        self.assertEqual(self.invoke("status", clock=BASE_CAPTURE), settled)
