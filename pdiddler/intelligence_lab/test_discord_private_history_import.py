"""Private-only historical MM2 Discord evidence ledger regressions.

Synthetic fixtures and tempdirs only. Never uses Discord credentials or real data.
"""
from __future__ import annotations

import contextlib
from decimal import Decimal
import importlib.util
import io
import json
from pathlib import Path
import random
import tempfile
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[2] / "scripts" / "discord_private_history_import.py"
SPEC = importlib.util.spec_from_file_location("mm2_private_history_import", SOURCE)
ledger = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ledger)
CID = ledger.APPROVED_CHANNEL
WEBHOOK = "1565287412106797999"
OTHER_WEBHOOK = "1565287412106797888"
BASE_ID = 1565287412106700000
FAKE_TOKEN = "NEVER_SHOW_THIS_FAKE_SECRET"
PUBLIC_REPO = ledger.PUBLIC_REPO


def message(offset=900, trader="player_42", give="Eternal IV - 10\nNightblade - 20",
            receive="Iceblaster - 35", values="You: 30 | Them: 35",
            profit="+5 (16.7%)", webhook=WEBHOOK):
    return {
        "id": str(BASE_ID + offset),
        "webhook_id": webhook,
        "timestamp": "2026-10-31T12:34:00+00:00",
        "content": "",
        "embeds": [{
            "title": "MM2 Trade Completed",
            "description": "Do not archive this private text.",
            "fields": [
                {"name": "Trader", "value": trader},
                {"name": "Profit", "value": profit},
                {"name": "Mode", "value": "Auto-managed"},
                {"name": "You gave", "value": give},
                {"name": "You received", "value": receive},
                {"name": "Values", "value": values},
            ],
        }],
    }


def env(workspace, repo="chazebanks/MM2-Trade-Research-PRIVATE", secret=FAKE_TOKEN):
    return {
        "GITHUB_REPOSITORY": repo,
        "MM2_EXPECTED_ARCHIVE_REPO": repo,
        "MM2_PRIVATE_REPO_VERIFIED": "true",
        "GITHUB_WORKSPACE": str(workspace),
        "MM2_RESEARCH_DISCORD_BOT_TOKEN": secret,
    }


class PrivateHistoryImportTests(unittest.TestCase):
    def test_parsed_historical_trade_is_not_completion(self):
        rec = ledger.build_record(message())
        self.assertEqual(rec["classification"], "PARSED_UNVERIFIED_WEBHOOK_CLAIM")
        self.assertEqual(rec["counterparty_category"], "NON_TEST_TRADER_UNVERIFIED")
        self.assertEqual(rec["server_settlement"], "UNKNOWN")
        self.assertFalse(rec["completed_trade_verified"])
        self.assertFalse(rec["webhook_source_pinned"])
        self.assertFalse(rec["learning_eligible"])
        self.assertFalse(rec["authorizes_trade"])
        self.assertFalse(rec["authorizes_accept"])
        self.assertFalse(rec["may_report_profit"])
        self.assertEqual(rec["claimed_trade"]["listed_gave_at_notification"], "30")
        self.assertEqual(rec["claimed_trade"]["listed_received_at_notification"], "35")
        self.assertEqual(rec["claimed_trade"]["reported_listed_gain"], "5")
        self.assertEqual([x["unverified_display_label"] for x in rec["claimed_trade"]["gave"]],
                         ["Eternal IV", "Nightblade"])
        self.assertEqual(rec["discord_message_timestamp_utc"], "2026-10-31T12:34:00Z")
        self.assertNotIn("player_42", json.dumps(rec))
        self.assertNotIn("Do not archive", json.dumps(rec))

    def test_user_test_alt_excluded_completely_before_trade_details(self):
        for trader in ("venossgaming90190", " VenossGaming90190 ", "VENOSSGAMING90190",
                       "ｖｅｎｏｓｓｇａｍｉｎｇ９０１９０"):
            with self.subTest(trader=trader):
                rec = ledger.build_record(message(trader=trader))
                self.assertEqual(rec["classification"], "TEST_ACCOUNT_EXCLUDED")
                self.assertEqual(rec["counterparty_category"], "TEST_ACCOUNT")
                self.assertNotIn("claimed_trade", rec)
                self.assertNotIn("venoss", json.dumps(rec).lower())
                self.assertNotIn("Iceblaster", json.dumps(rec))

    def test_similar_names_not_false_matches(self):
        for trader in ("venossgaming9019", "venossgaming901901", "myvenossgaming90190"):
            self.assertEqual(ledger.build_record(message(trader=trader))["classification"],
                             "PARSED_UNVERIFIED_WEBHOOK_CLAIM")

    def test_unparseable_bundles_get_private_reference_not_raw_data(self):
        m = message(give="Iceblaster x2 - 70", values="You: 70 | Them: 35", profit="-35")
        rec = ledger.build_record(m)
        self.assertEqual(rec["classification"], "UNPARSEABLE_ITEM_BUNDLE")
        self.assertTrue(rec["recover_from_discord_by_message_id"])
        self.assertNotIn("claimed_trade", rec)
        self.assertNotIn("Iceblaster", json.dumps(rec))
        self.assertNotIn("player_42", json.dumps(rec))

    def test_unknown_trader_quarantined(self):
        rec = ledger.build_record(message(trader="my display name"))
        self.assertEqual(rec["classification"], "UNKNOWN_TRADER_EXCLUDED")
        self.assertEqual(rec["counterparty_category"], "UNKNOWN_OR_UNRECONCILED")
        self.assertFalse(rec["learning_eligible"])

    def test_unrelated_and_nonwebhook_not_collected(self):
        m = message()
        m["webhook_id"] = None
        self.assertIsNone(ledger.build_record(m))
        m = message()
        m["embeds"][0]["title"] = "Unrelated server update"
        self.assertIsNone(ledger.build_record(m))
        m = message()
        m["embeds"] = []
        self.assertIsNone(ledger.build_record(m))

    def test_source_pin_does_not_turn_historical_claim_into_proof(self):
        good = ledger.build_record(message(), expected_webhook_id=WEBHOOK)
        self.assertTrue(good["webhook_source_pinned"])
        self.assertFalse(good["completed_trade_verified"])
        self.assertFalse(good["learning_eligible"])
        self.assertIsNone(ledger.build_record(message(webhook=OTHER_WEBHOOK),
                                              expected_webhook_id=WEBHOOK))

    def test_unknown_timestamp_and_utc_timezone(self):
        self.assertIsNone(ledger.timestamp_utc("2026-11-01 10:00:00"))
        self.assertIsNone(ledger.timestamp_utc("not-a-date"))
        self.assertIsNone(ledger.timestamp_utc(None))
        self.assertEqual(ledger.timestamp_utc("2026-11-01T10:00:00-05:00"),
                         "2026-11-01T15:00:00Z")

    def test_item_quantity_and_raw_ids_never_pretend_verified(self):
        rows = ledger.item_rows("Boneblade - 7\nBoneblade - 7")
        self.assertEqual(len(rows), 2)
        self.assertEqual(rows[0]["assumed_physical_copy_count"], 1)
        self.assertFalse(rows[0]["raw_mm2_weapon_key_verified"])
        self.assertFalse(rows[0]["checker_id_verified"])
        for raw in ("Knife x2 - 20", "Knife ×2 - 20", "Knife qty 2 - 20",
                    "name - 10\n" * 5, "@everyone - 10", "<@123> - 10"):
            with self.subTest(raw=raw), self.assertRaises(ledger.LedgerError):
                ledger.item_rows(raw)

    def test_full_pagination_before_commit(self):
        seen_cursors = []
        def fetch(cursor):
            seen_cursors.append(cursor)
            if cursor is None:
                return [message(offset=i + 500) for i in reversed(range(50))]
            self.assertEqual(cursor, str(BASE_ID + 500))
            return [message(offset=i + 400) for i in reversed(range(7))]
        results, stats = ledger.collect_records(fetch)
        self.assertEqual(len(results), 57)
        self.assertEqual(stats["pages"], 2)
        self.assertEqual(stats["messages_scanned"], 57)
        self.assertEqual(seen_cursors, [None, str(BASE_ID + 500)])

    def test_page_limit_prevents_partial_archive(self):
        def fetch(cursor):
            if cursor is None:
                return [message(offset=i + 500) for i in reversed(range(50))]
            self.fail("unexpected additional fetch")
        with self.assertRaisesRegex(ledger.LedgerError, "BACKFILL_PAGE_LIMIT_REACHED"):
            ledger.collect_records(fetch, max_pages=1)

    def test_page_unsorted_detected(self):
        with self.assertRaisesRegex(ledger.LedgerError, "PAGINATION_ORDER_FAILURE"):
            ledger.collect_records(lambda _:[message(100), message(200)])

    def test_cursor_not_decreasing_fails(self):
        def fetch(cursor):
            if cursor is None:
                return [message(offset=i + 500) for i in reversed(range(50))]
            return [message(700)]
        with self.assertRaisesRegex(ledger.LedgerError, "PAGINATION_ORDER_FAILURE"):
            ledger.collect_records(fetch)

    def test_malformed_ids_fail_before_write(self):
        for bad in ("x", "0", "-12", None):
            data = message()
            data["id"] = bad
            with self.subTest(bad=bad), self.assertRaises(ledger.LedgerError):
                ledger.collect_records(lambda _:[data])

    def test_invalid_source_pin_fails(self):
        with self.assertRaisesRegex(ledger.LedgerError, "INVALID_WEBHOOK_PIN"):
            ledger.collect_records(lambda _:[], expected_webhook_id="garbage")

    def test_atomic_archive_and_rerun_idempotent(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            records = [ledger.build_record(message(800)), ledger.build_record(message(700))]
            n, total = ledger.stage_records(root, records)
            self.assertEqual((n, total), (2, 2))
            dest = root / ledger.RELATIVE_LEDGER_PATH
            self.assertTrue(dest.exists())
            self.assertEqual([json.loads(line)["message_id"] for line in dest.read_text().splitlines()],
                             [str(BASE_ID + 700), str(BASE_ID + 800)])
            old_bytes = dest.read_bytes()
            self.assertEqual(ledger.stage_records(root, list(reversed(records))), (0, 2))
            self.assertEqual(old_bytes, dest.read_bytes())

    def test_changed_historical_receipt_requires_review_no_overwrite(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            record = ledger.build_record(message(800))
            ledger.stage_records(root, [record])
            dest = root / ledger.RELATIVE_LEDGER_PATH
            before = dest.read_bytes()
            changed = ledger.build_record(message(800, profit="+999"))
            with self.assertRaisesRegex(ledger.LedgerError, "EXISTING_RECEIPT_CHANGED_REVIEW_REQUIRED"):
                ledger.stage_records(root, [changed])
            self.assertEqual(before, dest.read_bytes())

    def test_rejects_tampered_archive_authority(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            dest = root / ledger.RELATIVE_LEDGER_PATH
            dest.parent.mkdir(parents=True)
            record = ledger.build_record(message())
            record["learning_eligible"] = True
            dest.write_text(json.dumps(record)+"\n")
            with self.assertRaisesRegex(ledger.LedgerError, "UNSAFE_ARCHIVE_AUTHORITY"):
                ledger.load_existing(dest)


    def test_rejects_profit_authority_on_old_or_new_receipts(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            original = ledger.build_record(message())
            for elevated in ({"may_report_profit": True},
                             {"authorizes_trade": True},
                             {"authorizes_accept": True},
                             {"completed_trade_verified": True},
                             {"learning_eligible": True},
                             {"server_settlement": "CONFIRMED"}):
                with self.subTest(elevated=elevated):
                    rec = dict(original)
                    rec.update(elevated)
                    with self.assertRaisesRegex(ledger.LedgerError, "UNSAFE_CANDIDATE_AUTHORITY"):
                        ledger.stage_records(root, [rec])
            self.assertFalse((root / ledger.RELATIVE_LEDGER_PATH).exists())

    def test_rejects_corrupt_json_and_duplicate_archive_receipts(self):
        with tempfile.TemporaryDirectory() as td:
            dest = Path(td) / ledger.RELATIVE_LEDGER_PATH
            dest.parent.mkdir(parents=True)
            dest.write_text("{broken\n")
            with self.assertRaisesRegex(ledger.LedgerError, "CORRUPT_ARCHIVE_JSON"):
                ledger.load_existing(dest)
            record = json.dumps(ledger.build_record(message()))
            dest.write_text(record+"\n"+record+"\n")
            with self.assertRaisesRegex(ledger.LedgerError, "DUPLICATE_OR_INVALID_ARCHIVE_ID"):
                ledger.load_existing(dest)

    def test_symlinked_archive_folder_rejected(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            (root / "data").symlink_to(Path(td) / "another", target_is_directory=True)
            with self.assertRaisesRegex(ledger.LedgerError, "SYMLINK_LEDGER_DIRECTORY"):
                ledger.ledger_path(root)

    def test_private_repo_guard_refuses_public_or_missing_attestation(self):
        with tempfile.TemporaryDirectory() as td:
            for vals in (
                env(td, repo=PUBLIC_REPO),
                {**env(td), "MM2_PRIVATE_REPO_VERIFIED": "false"},
                {**env(td), "MM2_EXPECTED_ARCHIVE_REPO": "different/repo"},
                {**env(td), "GITHUB_REPOSITORY": ""},
            ):
                with self.subTest(vals=vals), self.assertRaisesRegex(
                    ledger.LedgerError, "PRIVATE_REPOSITORY_REQUIRED"
                ):
                    ledger.validated_private_workspace(vals)

    def test_cli_offline_does_not_print_message_data(self):
        with tempfile.TemporaryDirectory() as td:
            buf = io.StringIO()
            fake_page = [message(901), message(900, trader="venossgaming90190"),
                         message(899, give="Weapon x2 - 40")]
            with contextlib.redirect_stdout(buf):
                status = ledger.main(["--channel-id", CID], env=env(td),
                                     fetch=lambda _cursor:fake_page)
            self.assertEqual(status, 0)
            s = buf.getvalue()
            self.assertIn("PRIVATE_HISTORY_IMPORT=OK", s)
            self.assertIn("COUNT_TEST_ACCOUNT_EXCLUDED=1", s)
            self.assertIn("COUNT_NEW_PRIVATE_RECORDS=3", s)
            self.assertIn("COUNT_LEARNING_ELIGIBLE=0", s)
            for forbidden in (FAKE_TOKEN, "player_42", "venossgaming90190",
                              "Iceblaster", "Eternal", WEBHOOK, CID):
                self.assertNotIn(forbidden, s)
            dest = Path(td) / ledger.RELATIVE_LEDGER_PATH
            results = [json.loads(line) for line in dest.read_text().splitlines()]
            self.assertEqual({x["classification"] for x in results},
                             {"PARSED_UNVERIFIED_WEBHOOK_CLAIM", "TEST_ACCOUNT_EXCLUDED",
                              "UNPARSEABLE_ITEM_BUNDLE"})

    def test_main_rejects_public_before_network(self):
        with tempfile.TemporaryDirectory() as td:
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                status = ledger.main(["--channel-id", CID], env=env(td, repo=PUBLIC_REPO),
                                     fetch=lambda _cursor:self.fail("network called"))
            self.assertEqual(status, 1)
            self.assertIn("PRIVATE_REPOSITORY_REQUIRED", buf.getvalue())

    def test_main_rejects_missing_secret_before_network(self):
        with tempfile.TemporaryDirectory() as td:
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                status = ledger.main(["--channel-id", CID], env=env(td, secret=""),
                                     fetch=lambda _cursor:self.fail("network called"))
            self.assertEqual(status, 1)
            self.assertIn("MISSING_DISCORD_BOT_SECRET", buf.getvalue())

    def test_zero_or_unrecognized_discord_messages_do_not_create_file(self):
        with tempfile.TemporaryDirectory() as td:
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                status = ledger.main(["--channel-id", CID], env=env(td),
                                     fetch=lambda _:[])
            self.assertEqual(status, 0)
            self.assertFalse((Path(td) / ledger.RELATIVE_LEDGER_PATH).exists())

    def test_randomized_reconciled_claims_remain_unverified(self):
        rng = random.Random(995003)
        for _ in range(500):
            given, received = rng.randint(1, 15000), rng.randint(1, 15000)
            gain = received - given
            source = message(give=f"Weapon A - {given}", receive=f"Weapon B - {received}",
                             values=f"You: {given} | Them: {received}", profit=f"{gain:+d}")
            parsed = ledger.build_record(source)
            self.assertEqual(parsed["classification"], "PARSED_UNVERIFIED_WEBHOOK_CLAIM")
            self.assertFalse(parsed["learning_eligible"])
            source["embeds"][0]["fields"][1]["value"] = f"{gain + 1:+d}"
            invalid = ledger.build_record(source)
            self.assertEqual(invalid["classification"], "INCONSISTENT_VALUE_CLAIM")
            self.assertNotIn("claimed_trade", invalid)


if __name__ == "__main__":
    unittest.main()
