"""Contract tests for the offline Luau-to-Python observation boundary."""

from copy import deepcopy
from hashlib import sha256
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

from pdiddler.system2.controlled_host import ControlledHostError, load_controlled_host
from pdiddler.system2.manual_portfolio_review import DEFAULT_CATALOG


REPLAY = "2026-11-25T07:52:05Z"
CATALOG = DEFAULT_CATALOG.read_bytes()
ROOT = Path(__file__).resolve().parents[2]


def receipt():
    session_id = "controlled-host-trade"
    events = [
        {
            "event_id": f"controlled-host-{sequence}",
            "session_id": session_id,
            "sequence": sequence,
            "revision": revision,
            "kind": kind,
            **terms,
        }
        for sequence, revision, kind, terms in (
            (1, 0, "PARTNER_REQUEST_ACCEPTED", {}),
            (2, 1, "OFFER_OBSERVED", {"give": {"godly:Fang": 1}, "receive": {"godly:Gemstone": 1}}),
            (3, 2, "PARTNER_OFFER_REVISION", {"give": {"godly:Fang": 1}, "receive": {"godly:Plasmabeam": 1}}),
        )
    ]
    return {
        "schema": "gingerscope-controlled-host-v1",
        "evidence_class": "SYNTHETIC_LUNE_OBSERVATION",
        "catalog_sha256": sha256(CATALOG).hexdigest(),
        "replay_at": REPLAY,
        "live_authority": False,
        "readiness": [
            "HEALTH_READY", "PART2_READY", "P3_OBSERVER_READY", "P4_BOUND",
            "P3_RESUMED", "LEASE_REVOKED", "STOPPED",
        ],
        "session": {
            "sessionId": session_id,
            "accounts": {
                "main": {"godly:Fang": 2, "chroma:CFang": 1, "ancient:Gingerscope": 1},
                "alt": {"godly:Orange_Seer": 1},
            },
            "counterpartyStock": {"godly:Gemstone": 1, "godly:Plasmabeam": 1},
            "events": events,
        },
        "offer_evidence": [
            {"revision": rev, "physical_give_slots": 1, "physical_receive_slots": 1,
             "outgoing_listed": 10, "incoming_listed": incoming, "listed_delta": incoming - 10}
            for rev, incoming in ((1, 15), (2, 18))
        ],
    }


def load(document, *, catalog=CATALOG, clock=REPLAY):
    return load_controlled_host(json.dumps(document).encode(), catalog=catalog, clock=clock)


class ControlledHostContractTests(unittest.TestCase):
    def test_fixture_sequence_and_exact_market_value(self):
        document = load(receipt())
        self.assertEqual(document["session"]["events"][-1]["receive"], {"godly:Plasmabeam": 1})
        self.assertEqual(document["offer_evidence"][-1]["listed_delta"], 8)
        self.assertEqual(document["session"]["accounts"]["alt"], {"godly:Orange_Seer": 1})

    def test_market_tampering_expiry_and_clock_mismatch_are_rejected(self):
        for catalog, clock in (
            (CATALOG + b" ", REPLAY),
            (CATALOG, "2026-11-25T12:10:00Z"),
            (CATALOG, "2026-11-25T07:52:06Z"),
        ):
            with self.subTest(clock=clock), self.assertRaises(ControlledHostError):
                load(receipt(), catalog=catalog, clock=clock)

    def test_source_cannot_claim_authority_identity_or_settlement(self):
        for target, key, value in (
            ("envelope", "live_authority", True),
            ("envelope", "evidence_class", "LIVE_MM2"),
            ("session", "lease_id", "DO_NOT_REPORT"),
            ("session", "settlement", {}),
            ("event", "partner_name", "DO_NOT_REPORT"),
        ):
            document = receipt()
            fields = {"envelope": document, "session": document["session"],
                      "event": document["session"]["events"][-1]}
            fields[target][key] = value
            with self.subTest(key=key), self.assertRaises(ControlledHostError) as caught:
                load(document)
            self.assertNotIn("DO_NOT_REPORT", str(caught.exception))

    def test_rejects_bad_sequence_protected_items_and_mismatched_terms(self):
        for update in (
            {"sequence": 4}, {"revision": 1}, {"give": {"ancient:Gingerscope": 1}},
            {"give": {"godly:Fang": True}}, {"give": {"godly:Fang": 2}},
            {"receive": {"godly:Unmapped": 1}}, {"receive": {"godly:Gemstone": 1}},
            {"receive": {"godly:Plasmabeam": 2}},
        ):
            document = receipt()
            document["session"]["events"][-1].update(update)
            with self.subTest(update=update), self.assertRaises(ControlledHostError):
                load(document)

    def test_rejects_wrong_price_and_duplicate_or_nonfinite_json(self):
        document = deepcopy(receipt())
        document["offer_evidence"][1]["listed_delta"] += 1
        with self.assertRaises(ControlledHostError):
            load(document)
        for raw in (b'{"schema":"x","schema":"y"}', b'{"x":NaN}', b"{}{}"):
            with self.subTest(raw=raw), self.assertRaises(ControlledHostError):
                load_controlled_host(raw, catalog=CATALOG, clock=REPLAY)

    def test_actual_lune_observer_receipt_reaches_the_python_session_store(self):
        runner_temp = os.environ.get("RUNNER_TEMP")
        hosted_lune = Path(runner_temp) / "lune" if runner_temp else None
        lune = shutil.which("lune") or hosted_lune
        if lune is None or not Path(lune).is_file():
            self.skipTest("Lune 0.11.1 is needed for the executed host observation test.")
        observed = subprocess.run(
            [lune, "run", "pdiddler/ci/gingerscope_controlled_host.luau"],
            cwd=ROOT, capture_output=True, check=True, timeout=20,
        ).stdout
        for private in (b"FixtureMainOnly", b"FixturePartnerOnly", b"CONTROLLED_FIXTURE_JOB"):
            self.assertNotIn(private, observed)
        document = load_controlled_host(observed, catalog=CATALOG, clock=REPLAY)
        trace = document["session"]
        trace["events"].append({
            "sequence": 4, "revision": 2, "kind": "CLIENT_WINDOW_CLOSED_UNKNOWN",
            "event_id": "finish-controlled-host", "session_id": trace["sessionId"],
        })
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            input_file = folder / "trace.json"
            input_file.write_text(json.dumps(trace), encoding="utf-8")
            args = [
                sys.executable, "-m", "pdiddler.gingerscope", "--database", str(folder / "state.sqlite"),
                "--synthetic", "--replay-at", REPLAY,
            ]
            result = subprocess.run(
                [*args, "simulate-session", str(input_file)],
                cwd=ROOT, capture_output=True, check=True, timeout=20,
            )
            report = json.loads(result.stdout)
            self.assertEqual(report["status"]["outcomeCounts"], {"CLIENT_WINDOW_CLOSED_UNKNOWN": 1})
            self.assertEqual(report["status"]["activeSessions"], 0)
            self.assertIsNone(report["status"]["realizedGrowth"])
            self.assertEqual(report["status"]["syntheticSettlements"], 0)
            offers = report["offerEvaluations"]
            self.assertEqual([offer["offerRevision"] for offer in offers], [1, 2])
            self.assertEqual([offer["offer"]["main_listed_delta"] for offer in offers],
                             [row["listed_delta"] for row in document["offer_evidence"]])
            for offer in offers:
                current = subprocess.run(
                    [*args, "current", offer["evaluationId"]],
                    cwd=ROOT, capture_output=True, check=True, timeout=20,
                )
                self.assertIsNone(json.loads(current.stdout)["evaluation"])
