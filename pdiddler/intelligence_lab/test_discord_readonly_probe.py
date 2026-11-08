"""Read-only Discord probe contract and privacy regression tests."""
from __future__ import annotations

import contextlib
import importlib.util
import io
from pathlib import Path
import unittest
from unittest.mock import patch
from urllib.error import HTTPError

SCRIPT = Path(__file__).resolve().parents[2] / "scripts" / "discord_readonly_probe.py"
SPEC = importlib.util.spec_from_file_location("mm2_discord_probe", SCRIPT)
assert SPEC and SPEC.loader
probe = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(probe)

CID = "1565287412106797098"
TOKEN = "FAKE_SECRET_FOR_OFFLINE_TESTS_ONLY"


def fake_fetch(path, token):
    if path == "/users/@me":
        return {"id": "redacted", "bot": True}
    if path == "/channels/" + CID:
        return {"id": CID, "name": "private-do-not-log"}
    if path == "/channels/" + CID + "/messages?limit=25":
        return [
            {"webhook_id": "confidential-webhook", "embeds": [{"secret": "NEVER_PRINT_ME"}],
             "content": "PRIVATE TRADE CONTENT NEVER PRINT"},
            {"webhook_id": None, "embeds": [], "content": ""},
        ]
    raise AssertionError("unexpected HTTP path: " + path)


class DummyResponse:
    def __init__(self, payload):
        self.payload = payload
        self.status = 200

    def __enter__(self):
        return self

    def __exit__(self, *_):
        return False

    def read(self, _limit):
        return self.payload


class DiscordReadOnlyProbeTests(unittest.TestCase):
    def test_valid_channel_response_outputs_counters_not_secrets(self):
        result = probe.probe(CID, TOKEN, fetch=fake_fetch)
        text = "\n".join(result)
        self.assertIn("BOT_AUTH=OK", text)
        self.assertIn("HISTORY_SAMPLE_COUNT=2", text)
        self.assertIn("HISTORY_READ=VISIBLE_MESSAGES", text)
        self.assertIn("SAMPLE_WEBHOOK_MESSAGES=1", text)
        self.assertIn("SAMPLE_MESSAGES_WITH_EMBEDS=1", text)
        self.assertIn("SAMPLE_MESSAGES_WITH_TEXT=1", text)
        for sensitive in ("NEVER_PRINT_ME", "PRIVATE TRADE CONTENT", "confidential-webhook", "private-do-not-log", TOKEN):
            self.assertNotIn(sensitive, text)

    def test_only_allowed_channel_is_queried(self):
        seen = []
        def capture(path, token):
            seen.append(path)
            return fake_fetch(path, token)
        probe.probe(CID, TOKEN, fetch=capture)
        self.assertEqual(seen, [
            "/users/@me",
            "/channels/" + CID,
            "/channels/" + CID + "/messages?limit=25",
        ])

    def test_invalid_channel_fails_before_http(self):
        for cid in ("", "not-id", "../wrong", "https://discord.com", "1234"):
            with self.subTest(cid=cid), self.assertRaises(probe.ProbeError):
                probe.probe(cid, TOKEN, fetch=lambda *_: self.fail("HTTP used"))

    def test_missing_secret_fails_before_http(self):
        with self.assertRaisesRegex(probe.ProbeError, "MISSING_DISCORD_BOT_SECRET"):
            probe.probe(CID, " ", fetch=lambda *_: self.fail("HTTP used"))

    def test_user_token_cannot_impersonate_bot(self):
        def wrong_bot(path, token):
            if path == "/users/@me":
                return {"bot": False}
            self.fail("called channel with non-bot token")
        with self.assertRaisesRegex(probe.ProbeError, "TOKEN_NOT_A_BOT"):
            probe.probe(CID, TOKEN, fetch=wrong_bot)

    def test_wrong_channel_identity_fails_closed(self):
        def wrong_channel(path, token):
            if path == "/channels/" + CID:
                return {"id": "1565287412106797999"}
            return fake_fetch(path, token)
        with self.assertRaisesRegex(probe.ProbeError, "CHANNEL_ID_MISMATCH"):
            probe.probe(CID, TOKEN, fetch=wrong_channel)

    def test_empty_history_is_not_reported_as_verified_read(self):
        def no_history(path, token):
            if "/messages?" in path:
                return []
            return fake_fetch(path, token)
        result = "\n".join(probe.probe(CID, TOKEN, fetch=no_history))
        self.assertIn("NO_MESSAGES_RETURNED_CHECK_READ_HISTORY_PERMISSION_OR_EMPTY_CHANNEL", result)
        self.assertIn("HISTORY_READ=INCONCLUSIVE_NO_MESSAGES", result)
        self.assertNotIn("SAMPLE_VISIBLE_NOT_COMPLETION_PROOF", result)

    def test_history_shape_rejection(self):
        for bad in (None, {}, [None], [{"content": ""}] * 26):
            with self.subTest(bad_type=type(bad)), self.assertRaisesRegex(probe.ProbeError, "UNEXPECTED_HISTORY_FORMAT"):
                probe.describe_messages(bad)

    def test_no_http_post_and_no_unapproved_endpoints(self):
        seen = []
        def opener(req, timeout):
            seen.append((req.get_method(), req.full_url))
            return DummyResponse(b'{"bot": true}')
        result = probe.fetch_json("/users/@me", TOKEN, opener=opener)
        self.assertTrue(result["bot"])
        self.assertEqual(seen, [("GET", "https://discord.com/api/v10/users/@me")])
        for path in ("/guilds/123/messages", "/channels/123/messages", "/users/@me?hack=1",
                     "/channels/" + CID + "/messages?limit=100"):
            with self.subTest(path=path), self.assertRaisesRegex(probe.ProbeError, "UNSUPPORTED_REQUEST"):
                probe.fetch_json(path, TOKEN, opener=lambda *_a, **_k: self.fail("Unapproved API call"))

    def test_get_history_path_allowlist_matches_exact_query(self):
        def opener(req, timeout):
            self.assertEqual(req.get_method(), "GET")
            return DummyResponse(b"[]")
        self.assertEqual(probe.fetch_json("/channels/" + CID + "/messages?limit=25",
                                          TOKEN, opener=opener), [])

    def test_http_auth_error_is_redacted(self):
        def opener(req, timeout):
            raise HTTPError(req.full_url, 401, "sensitive private body", {}, None)
        with self.assertRaises(probe.ProbeError) as cm:
            probe.fetch_json("/users/@me", TOKEN, opener=opener)
        self.assertEqual(str(cm.exception), "DISCORD_HTTP_401")
        self.assertNotIn(TOKEN, str(cm.exception))
        self.assertNotIn("private body", str(cm.exception))

    def test_rate_limit_retry_is_bounded(self):
        attempts = []
        waits = []
        def opener(req, timeout):
            attempts.append(req.full_url)
            if len(attempts) < 3:
                raise HTTPError(req.full_url, 429, "rate limited", {"Retry-After": "0"}, None)
            return DummyResponse(b'{"bot":true}')
        result = probe.fetch_json("/users/@me", TOKEN, opener=opener, sleep=waits.append)
        self.assertTrue(result["bot"])
        self.assertEqual(len(attempts), 3)
        self.assertEqual(waits, [0.0, 0.0])

    def test_oversize_and_malformed_response_fails_closed(self):
        for payload, code in ((b"nonsense", "INVALID_JSON_RESPONSE"),
                              (b"x" * (probe.MAX_RESPONSE_BYTES + 1), "RESPONSE_TOO_LARGE")):
            with self.subTest(code=code), self.assertRaisesRegex(probe.ProbeError, code):
                probe.fetch_json("/users/@me", TOKEN,
                                 opener=lambda *_args, **_kw: DummyResponse(payload))

    def test_cli_without_secret_only_logs_safe_failure(self):
        buf = io.StringIO()
        with patch.dict("os.environ", {"MM2_RESEARCH_DISCORD_BOT_TOKEN": ""}), contextlib.redirect_stdout(buf):
            exit_code = probe.main(["--channel-id", CID])
        self.assertEqual(exit_code, 1)
        self.assertEqual(buf.getvalue().strip(), "DISCORD_PROBE=FAILED:MISSING_DISCORD_BOT_SECRET")


if __name__ == "__main__":
    unittest.main()
