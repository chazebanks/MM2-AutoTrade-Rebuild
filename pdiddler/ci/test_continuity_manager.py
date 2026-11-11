"""Metadata-only continuity gate: corruption, replay, evidence and privacy tests."""
from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from pdiddler.continuity import manager as c


class ContinuityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "public_repo"
        self.config = self.root / "pdiddler" / "continuity"
        self.config.mkdir(parents=True)
        source = Path(__file__).resolve().parents[1] / "continuity"
        for name in ("manifest.json", "policy.json", "current_state.json", "history_index.json"):
            (self.config / name).write_bytes((source / name).read_bytes())
        manifest = self.data("manifest.json")
        for i, relative in enumerate(manifest["sourceBlobs"]):
            file = self.root / relative
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_text(f"verified fixture anchor {i}\n", encoding="utf-8")
            manifest["sourceBlobs"][relative] = c.blob_sha(file.read_bytes())
        self.write("manifest.json", manifest)
        self.private = Path(self.temp.name) / "private"
        self.private.mkdir()
        (self.private / ".gingerscope_private").write_text("")

    def data(self, name):
        return json.loads((self.config / name).read_text())

    def write(self, name, data):
        (self.config / name).write_text(json.dumps(data), encoding="utf-8")

    def event(self):
        return dict(stage=119, status="STOPPED", reason="OPERATOR_STOPPED",
                    clientCallbacks=2, guiTransitions=2, scriptOffers=0,
                    scriptAccepts=0, scriptDeclines=0, tradeOutcome="UNKNOWN")

    def test_clean_gate_and_bounded_recovery(self):
        result = c.verify(self.root)
        self.assertEqual(result["status"], "PASS")
        self.assertEqual(result["coverage"], "PARTIAL_NOT_ALL_STAGES_AUDITED")
        brief = c.recover(self.root)
        self.assertEqual(brief["gate"]["latestStage"], 121)
        self.assertIn("NOT_FULL_HISTORY", brief["scope"])
        self.assertGreaterEqual(len(brief["mandatoryRules"]), 14)

    def test_mutated_source_fails_closed(self):
        anchor = next(iter(self.data("manifest.json")["sourceBlobs"]))
        (self.root / anchor).write_text("tampered")
        with self.assertRaisesRegex(c.GateError, "SOURCE_CHANGED_REINDEX_REQUIRED"):
            c.verify(self.root)

    def test_missing_rule_fails_closed(self):
        policy = self.data("policy.json")
        policy["rules"].pop()
        self.write("policy.json", policy)
        with self.assertRaises(c.GateError):
            c.verify(self.root)

    def test_rule_duplicate_and_unbound_rejected(self):
        policy = self.data("policy.json")
        policy["rules"][1]["id"] = policy["rules"][0]["id"]
        self.write("policy.json", policy)
        with self.assertRaises(c.GateError): c.verify(self.root)
        policy = self.data("policy.json")
        policy["rules"][1]["id"] = "PROTECT_OUTGOING_GINGERSCOPE"
        policy["rules"][1]["source"] = "untrusted.md"
        self.write("policy.json", policy)
        with self.assertRaises(c.GateError): c.verify(self.root)

    def test_fake_trade_and_price_authority_rejected(self):
        state = self.data("current_state.json")
        state["authority"]["authorizesAccept"] = True
        self.write("current_state.json", state)
        with self.assertRaisesRegex(c.GateError, "UNVERIFIED_AUTHORITY_PROMOTED"):
            c.verify(self.root)
        state["authority"]["authorizesAccept"] = False
        state["tradeOutcome"] = "COMPLETED"
        self.write("current_state.json", state)
        with self.assertRaises(c.GateError): c.verify(self.root)

    def test_missing_stage_history_cannot_claim_full_audit(self):
        index = self.data("history_index.json")
        index["coverage"] = "FULLY_AUDITED"
        self.write("history_index.json", index)
        with self.assertRaisesRegex(c.GateError, "FALSE_HISTORY_COMPLETENESS"):
            c.verify(self.root)

    def test_unique_job_id_prevents_replaying_operations(self):
        sha = self.data("current_state.json")["sourceCommit"]
        job_id = "job-test-run-001"
        result = c.begin_job(self.root, job_id, "One safe offline test", sha)
        self.assertEqual(result["status"], "CREATED_NOT_EXECUTED")
        again = c.begin_job(self.root, job_id, "One safe offline test", sha)
        self.assertEqual(again["status"], "EXISTS_NO_REPLAY")
        self.assertEqual(c.job_status(self.root, job_id)["status"], "PLANNED")
        with self.assertRaises(c.GateError):
            c.job_status(self.root, "job-unknown")

    def test_append_only_job_chain_and_terminal_reopen_denial(self):
        sha = self.data("current_state.json")["sourceCommit"]
        name = "job-chain-1234"
        link = "https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/228"
        c.begin_job(self.root, name, "Audit one original test", sha)
        running = c.transition_job(self.root, name, "RUNNING", link)
        self.assertEqual(running["status"], "RUNNING")
        done = c.transition_job(self.root, name, "COMPLETE", link)
        self.assertEqual(done["status"], "COMPLETE")
        self.assertEqual(done["stepsRecorded"], 2)
        with self.assertRaises(c.GateError): c.transition_job(self.root, name, "RUNNING", link)
        with self.assertRaises(c.GateError): c.transition_job(self.root, name, "COMPLETE", link)
        step = self.root / c.RECORD_DIR / f"{name}.step0001.json"
        data = json.loads(step.read_text()); data["evidence"] = "https://example.com/injected"
        step.write_text(json.dumps(data))
        with self.assertRaises(c.GateError): c.job_status(self.root, name)

    def test_interrupted_is_not_automatically_replayed(self):
        sha = self.data("current_state.json")["sourceCommit"]
        name = "job-interrupt-7"
        link = "https://github.com/chazebanks/MM2-AutoTrade-Rebuild/commit/7216c4db84a5a7c95227ff09fb97b27106f44406"
        c.begin_job(self.root, name, "One staged code review", sha)
        c.transition_job(self.root, name, "INTERRUPTED", link)
        self.assertEqual(c.begin_job(self.root, name, "One staged code review", sha)["status"], "EXISTS_NO_REPLAY")
        self.assertEqual(c.job_status(self.root, name)["status"], "INTERRUPTED")

    def test_private_receipts_idempotent_and_strict(self):
        obj = self.event()
        saved = c.save_client_event(self.root, self.private, "evt-demo0001", obj)
        self.assertEqual(saved["status"], "PRIVATE_RECEIPT_SAVED")
        repeated = c.save_client_event(self.root, self.private, "evt-demo0001", obj)
        self.assertEqual(repeated["status"], "DUPLICATE_NOT_RECORDED")
        obj["clientCallbacks"] = 3
        with self.assertRaisesRegex(c.GateError, "EVENT_ID_COLLISION"):
            c.save_client_event(self.root, self.private, "evt-demo0001", obj)

    def test_reject_private_identifiers_false_outcomes_and_public_dir(self):
        obj = self.event()
        obj["username"] = "sensitive"
        with self.assertRaisesRegex(c.GateError, "UNTRUSTED_OR_PRIVATE_CLIENT_FIELDS"):
            c.save_client_event(self.root, self.private, "evt-other0001", obj)
        obj.pop("username")
        obj["tradeOutcome"] = "COMPLETED"
        with self.assertRaises(c.GateError): c.save_client_event(self.root, self.private, "evt-other0001", obj)
        obj["tradeOutcome"] = "UNKNOWN"
        public = self.root / "logs"; public.mkdir(); (public / ".gingerscope_private").write_text("")
        with self.assertRaisesRegex(c.GateError, "PUBLIC_REPOSITORY_LOG_FORBIDDEN"):
            c.save_client_event(self.root, public, "evt-other0001", obj)

    def test_type_confusion_and_invalid_ids(self):
        obj = self.event(); obj["clientCallbacks"] = True
        with self.assertRaises(c.GateError): c.save_client_event(self.root, self.private, "evt-valid0001", obj)
        with self.assertRaises(c.GateError): c.save_client_event(self.root, self.private, "../escape", self.event())
        with self.assertRaises(c.GateError): c.begin_job(self.root, "../escape", "One safe offline test", "0" * 40)


if __name__ == "__main__":
    unittest.main()
