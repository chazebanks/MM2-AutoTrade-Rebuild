"""Discord embed historical audit — synthetic fixtures only, no secrets or requests."""
from __future__ import annotations

from collections import Counter
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import random
import unittest
from unittest.mock import patch
from urllib.error import HTTPError

PATH = Path(__file__).resolve().parents[2] / "scripts" / "discord_history_embed_audit.py"
SPEC = importlib.util.spec_from_file_location("mm2_discord_history_audit", PATH)
audit = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(audit)

CHANNEL = audit.APPROVED_CHANNEL
WEBHOOK = "1565287412106797999"
ID_BASE = 1565287412106797000
TOKEN = "NEVER_PRINT_SECRET_IN_LOGS"


def embed(trader="real_player77", give="Eternal IV - 10\nNightblade - 20",
          receive="Iceblaster - 35", values="You: 30 | Them: 35",
          profit="+5 (16.7%)", mode="Auto-managed"):
    return {
        "title": "MM2 Trade Completed",
        "fields": [
            {"name": "Trader", "value": trader},
            {"name": "Profit", "value": profit},
            {"name": "Mode", "value": mode},
            {"name": "You gave", "value": give},
            {"name": "You received", "value": receive},
            {"name": "Values", "value": values},
        ],
    }


def msg(offset=10, trader="real_player77", embed_override=None):
    return {
        "id": str(ID_BASE + offset),
        "webhook_id": WEBHOOK,
        "content": "",
        "embeds": [embed(trader=trader) if embed_override is None else embed_override],
    }


class FakeResponse:
    status = 200
    def __init__(self, payload):
        self.payload = payload
    def __enter__(self):
        return self
    def __exit__(self, *_args):
        return False
    def read(self, _n):
        return self.payload


class HistoryEmbedAuditTests(unittest.TestCase):
    def test_actual_screenshot_style_not_treated_as_completed_trade(self):
        self.assertEqual(audit.classify_message(msg()), "PARSED_UNVERIFIED_WEBHOOK_CLAIM")
        counters = audit.audit_pages(lambda _cursor: [msg()])
        self.assertEqual(counters["PARSED_UNVERIFIED_WEBHOOK_CLAIM"], 1)
        for key in ("learning_eligible", "source_identity_pinned",
                    "server_verified_settlements", "records_stored"):
            self.assertEqual(counters[key], 0)

    def test_exclusion_exact_and_case_insensitive(self):
        for trader in ("venossgaming90190", "VENOSSGAMING90190", " venossgaming90190 ",
                       "ｖｅｎｏｓｓｇａｍｉｎｇ９０１９０"):
            with self.subTest(trader=trader):
                self.assertEqual(audit.classify_message(msg(trader=trader)),
                                 "TEST_ACCOUNT_EXCLUDED")

    def test_similar_username_and_mention_only_not_excluded(self):
        for trader in ("venossgaming9019", "venossgaming901901", "xvenossgaming90190",
                       "other_user42"):
            with self.subTest(trader=trader):
                self.assertNotEqual(audit.classify_message(msg(trader=trader)),
                                    "TEST_ACCOUNT_EXCLUDED")
        other = msg(trader="real_player77")
        other["embeds"][0]["description"] = "test account venossgaming90190 appears in narrative"
        self.assertEqual(audit.classify_message(other), "PARSED_UNVERIFIED_WEBHOOK_CLAIM")

    def test_unknown_or_ambiguous_trader_is_not_learning_eligible(self):
        for trader in ("", "Player Name", "user@withmention", "<@12345>", "?", "A" * 21):
            with self.subTest(trader=trader):
                self.assertEqual(audit.classify_message(msg(trader=trader)),
                                 "UNKNOWN_TRADER_EXCLUDED")

    def test_empty_trader_field_and_duplicate_heading(self):
        e = embed()
        e["fields"] = [row for row in e["fields"] if row["name"] != "Trader"]
        self.assertEqual(audit.classify_message(msg(embed_override=e)), "UNKNOWN_TRADER_EXCLUDED")
        e = embed()
        e["fields"].append({"name": "Trader", "value": "venossgaming90190"})
        self.assertEqual(audit.classify_message(msg(embed_override=e)), "UNKNOWN_EMBED_STRUCTURE")

    def test_trader_with_hidden_markdown_heading_is_excluded(self):
        e = embed(trader=" VenossGaming90190 ")
        e["fields"][0]["name"] = "**Trader**"
        self.assertEqual(audit.classify_message(msg(embed_override=e)), "TEST_ACCOUNT_EXCLUDED")

    def test_malformed_or_nonwebhook_message(self):
        self.assertEqual(audit.classify_message(None), "MALFORMED_MESSAGE")
        self.assertEqual(audit.classify_message({"embeds": [embed()]}), "NOT_WEBHOOK")
        self.assertEqual(audit.classify_message({"webhook_id": WEBHOOK, "embeds": "secret"}),
                         "MALFORMED_MESSAGE")
        self.assertEqual(audit.classify_message({"webhook_id": WEBHOOK, "embeds": []}),
                         "NOT_TRADE_EMBED")

    def test_nontrade_embed_never_parsed(self):
        e = embed()
        e["title"] = "MM2 Offer Requested"
        self.assertEqual(audit.classify_message(msg(embed_override=e)), "NOT_TRADE_EMBED")

    def test_multiple_matching_embeds_fail_closed(self):
        m = msg()
        m["embeds"].append(embed(trader="venossgaming90190"))
        self.assertEqual(audit.classify_message(m), "AMBIGUOUS_TRADE_EMBEDS")

    def test_description_only_embed_does_not_guess_fields(self):
        m = msg(embed_override={
            "title": "MM2 Trade Completed",
            "description": "**Trader**\nvenossgaming90190\n**Profit**\n+5",
        })
        self.assertEqual(audit.classify_message(m), "UNKNOWN_EMBED_STRUCTURE")

    def test_known_fields_with_missing_value(self):
        e = embed()
        e["fields"] = [field for field in e["fields"] if field["name"] != "Profit"]
        self.assertEqual(audit.classify_message(msg(embed_override=e)), "INCOMPLETE_TRADE_CLAIM")

    def test_inconsistent_values_and_profit(self):
        for overrides in ({"values": "You: 31 | Them: 35"}, {"profit": "+8 (40%)"},
                          {"values": "You: 30 | Them: 34"}):
            with self.subTest(overrides=overrides):
                self.assertEqual(audit.classify_message(msg(embed_override=embed(**overrides))),
                                 "INCONSISTENT_VALUE_CLAIM")

    def test_missing_or_bad_values(self):
        for values in ("You: 30 / Them: 35", "You: unknown | Them: 35",
                       "You: 30 | Them: 999999.999"):
            with self.subTest(values=values):
                self.assertEqual(audit.classify_message(msg(embed_override=embed(values=values))),
                                 "UNPARSEABLE_VALUE_CLAIM")

    def test_stacked_items_are_quarantined(self):
        for give in ("Iceblaster x2 - 70", "Iceblaster ×2 - 70",
                     "Iceblaster qty 2 - 70", "Iceblaster - ?", "Iceblaster - 35\n" * 5):
            with self.subTest(give=give):
                self.assertEqual(audit.classify_message(msg(embed_override=embed(give=give))),
                                 "UNPARSEABLE_ITEM_BUNDLE")

    def test_loss_report_must_reconcile(self):
        e = embed(give="Strong - 45", receive="Lesser - 40",
                  values="You: 45 | Them: 40", profit="-5 (11.1%)")
        self.assertEqual(audit.classify_message(msg(embed_override=e)),
                         "PARSED_UNVERIFIED_WEBHOOK_CLAIM")
        e["fields"][1]["value"] = "-4"
        self.assertEqual(audit.classify_message(msg(embed_override=e)),
                         "INCONSISTENT_VALUE_CLAIM")

    def test_repeated_items_and_duplicate_values_are_not_completion_proof(self):
        e = embed(give="Item A - 15\nItem A - 15")
        self.assertEqual(audit.classify_message(msg(embed_override=e)),
                         "PARSED_UNVERIFIED_WEBHOOK_CLAIM")
        # Historic ambiguous repeat quantities remain unverified regardless of arithmetic.

    def test_counts_distinguish_test_and_real_without_identifiers(self):
        messages = [
            msg(10, trader="venossgaming90190"),
            msg(9),
            msg(8, trader="Unknown Player"),
            {"id": str(ID_BASE + 7), "embeds": []},
        ]
        result = audit.audit_pages(lambda _cursor: messages)
        self.assertEqual(result["TEST_ACCOUNT_EXCLUDED"], 1)
        self.assertEqual(result["PARSED_UNVERIFIED_WEBHOOK_CLAIM"], 1)
        self.assertEqual(result["UNKNOWN_TRADER_EXCLUDED"], 1)
        self.assertEqual(result["NOT_WEBHOOK"], 1)
        self.assertEqual(result["distinct_webhook_ids"], 1)
        self.assertEqual(result["messages_seen"], 4)

    def test_duplicate_messages_not_double_counted(self):
        data = [msg(10), msg(10)]
        result = audit.audit_pages(lambda _cursor: data)
        self.assertEqual(result["duplicate_messages"], 1)
        self.assertEqual(result["PARSED_UNVERIFIED_WEBHOOK_CLAIM"], 1)

    def test_bad_pages_and_cursor_fail_closed(self):
        for invalid in (None, {}, [None], [msg()] * 51):
            with self.subTest(invalid_type=type(invalid)):
                with self.assertRaises(audit.AuditFailure):
                    audit.audit_pages(lambda _cursor: invalid)
        for pages in (0, 4, True, -1):
            with self.subTest(pages=pages), self.assertRaises(audit.AuditFailure):
                audit.audit_pages(lambda _cursor: [], max_pages=pages)

    def test_strict_cursor_pagination_and_bounds(self):
        called = []
        def pages(cursor):
            called.append(cursor)
            if cursor is None:
                return [msg(i + 100) for i in range(50)]
            self.assertEqual(cursor, str(ID_BASE + 100))
            return [msg(i + 30) for i in range(8)]
        counters = audit.audit_pages(pages)
        self.assertEqual(called, [None, str(ID_BASE + 100)])
        self.assertEqual(counters["messages_seen"], 58)
        self.assertEqual(counters["pages_read"], 2)

    def test_future_message_violates_cursor(self):
        def pages(cursor):
            if cursor is None:
                return [msg(i + 100) for i in range(50)]
            return [msg(199)]
        with self.assertRaisesRegex(audit.AuditFailure, "PAGINATION_ORDER_VIOLATION"):
            audit.audit_pages(pages)

    def test_http_get_exact_channel_and_safe_query(self):
        seen = []
        def opener(req, timeout):
            seen.append((req.get_method(), req.full_url))
            return FakeResponse(b"[]")
        result = audit.fetch_page(CHANNEL, TOKEN, None, opener=opener)
        self.assertEqual(result, [])
        self.assertEqual(seen, [("GET", "https://discord.com/api/v10/channels/" +
                                 CHANNEL + "/messages?limit=50")])
        seen.clear()
        audit.fetch_page(CHANNEL, TOKEN, str(ID_BASE + 10), opener=opener)
        self.assertEqual(seen[0][0], "GET")
        self.assertTrue(seen[0][1].endswith("&before=" + str(ID_BASE + 10)))

    def test_wrong_channel_or_cursor_rejected_before_http(self):
        for channel, cursor in (("wrong", None), (CHANNEL, "abc"), (CHANNEL, "-5")):
            with self.subTest(channel=channel, cursor=cursor):
                with self.assertRaises(audit.AuditFailure):
                    audit.fetch_page(channel, TOKEN, cursor,
                                     opener=lambda *_a, **_kw: self.fail("network called"))
        with self.assertRaises(audit.AuditFailure):
            audit.fetch_page(CHANNEL, "", None, opener=lambda *_a, **_kw: self.fail("network called"))

    def test_http_401_403_404_cannot_log_exception_url(self):
        for code in (401, 403, 404):
            def opener(req, timeout):
                raise HTTPError(req.full_url, code, "private sensitive error", {}, None)
            with self.subTest(code=code), self.assertRaises(audit.AuditFailure) as cm:
                audit.fetch_page(CHANNEL, TOKEN, None, opener=opener)
            self.assertEqual(str(cm.exception), "DISCORD_HTTP_" + str(code))
            self.assertNotIn("private sensitive", str(cm.exception))
            self.assertNotIn(TOKEN, str(cm.exception))

    def test_rate_limit_bounded(self):
        calls, waits = [], []
        def opener(req, timeout):
            calls.append(1)
            if len(calls) < 3:
                raise HTTPError(req.full_url, 429, "rate limit", {"Retry-After": "0"}, None)
            return FakeResponse(b"[]")
        self.assertEqual(audit.fetch_page(CHANNEL, TOKEN, None,
                                         opener=opener, sleep=waits.append), [])
        self.assertEqual(len(calls), 3)
        self.assertEqual(waits, [0, 0])

    def test_no_content_printed_by_cli(self):
        messages = [msg(11, trader="venossgaming90190"),
                    msg(10, trader="private_user_42")]
        # Replace HTTP function only; the real CLI still uses its exact aggregation/output.
        buf = io.StringIO()
        with patch.object(audit, "fetch_page", side_effect=lambda *_args: messages), \
             patch.dict("os.environ", {"MM2_RESEARCH_DISCORD_BOT_TOKEN": TOKEN}), \
             contextlib.redirect_stdout(buf):
            result = audit.main(["--channel-id", CHANNEL])
        output = buf.getvalue()
        self.assertEqual(result, 0)
        self.assertIn("COUNT_TEST_ACCOUNT_EXCLUDED=1", output)
        self.assertIn("COUNT_PARSED_UNVERIFIED_WEBHOOK_CLAIM=1", output)
        self.assertIn("COUNT_LEARNING_ELIGIBLE=0", output)
        for forbidden in ("venossgaming90190", "private_user_42", "Eternal IV", "Iceblaster",
                          TOKEN, WEBHOOK, CHANNEL):
            self.assertNotIn(forbidden, output)

    def test_unauthorized_channel_fails_and_no_http(self):
        buf = io.StringIO()
        with patch.dict("os.environ", {"MM2_RESEARCH_DISCORD_BOT_TOKEN": TOKEN}), \
             patch.object(audit, "fetch_page", side_effect=AssertionError("network contacted")), \
             contextlib.redirect_stdout(buf):
            self.assertEqual(audit.main(["--channel-id", "1565287412106797001"]), 1)
        self.assertIn("FAILED:UNAUTHORIZED_CHANNEL", buf.getvalue())

    def test_seeded_randomized_reconciliation_does_not_accept_mismatches(self):
        rng = random.Random(97022)
        for _ in range(400):
            a, b = rng.randint(1, 9999), rng.randint(1, 9999)
            d = b - a
            e = embed(give=f"Weapon A - {a}", receive=f"Weapon B - {b}",
                      values=f"You: {a} | Them: {b}", profit=f"{d:+d}")
            self.assertEqual(audit.classify_message(msg(embed_override=e)),
                             "PARSED_UNVERIFIED_WEBHOOK_CLAIM")
            e["fields"][1]["value"] = f"{d + 1:+d}"
            self.assertEqual(audit.classify_message(msg(embed_override=e)),
                             "INCONSISTENT_VALUE_CLAIM")


if __name__ == "__main__":
    unittest.main()
