#!/usr/bin/env python3
"""Single-channel Discord bot permission smoke test; no storage or message content output.

This utility performs exactly three authorized HTTP GET requests:
  GET /users/@me
  GET /channels/<provided ID>
  GET /channels/<provided ID>/messages?limit=25
It reports only fixed status codes and aggregate counters. No message IDs,
channel names, identities, content, embeds, token, or response bodies are logged.
It does not send messages, import historical data, or authorize MM2 trades.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


API_ROOT = "https://discord.com/api/v10"
USER_AGENT = "MM2-Trade-Research-ReadOnly-Probe/1.0"
READ_LIMIT = 25
MAX_RESPONSE_BYTES = 2_000_000


class ProbeError(Exception):
    """An intentionally coarse, safe-to-log failure code."""


def fetch_json(path: str, token: str, *, opener=urlopen, sleep=time.sleep):
    if not (path == "/users/@me" or
            re.fullmatch(r"/channels/[0-9]{17,20}(?:/messages\?limit=25)?", path)):
        raise ProbeError("UNSUPPORTED_REQUEST")
    request = Request(
        API_ROOT + path,
        headers={"Authorization": "Bot " + token, "User-Agent": USER_AGENT,
                 "Accept": "application/json"},
        method="GET",
    )
    for attempt in range(3):
        try:
            with opener(request, timeout=15) as response:
                if response.status != 200:
                    raise ProbeError("UNEXPECTED_HTTP_STATUS")
                payload = response.read(MAX_RESPONSE_BYTES + 1)
                if len(payload) > MAX_RESPONSE_BYTES:
                    raise ProbeError("RESPONSE_TOO_LARGE")
                try:
                    return json.loads(payload.decode("utf-8"))
                except (UnicodeError, ValueError):
                    raise ProbeError("INVALID_JSON_RESPONSE") from None
        except HTTPError as exc:
            if exc.code == 429 and attempt < 2:
                try:
                    retry_after = float(exc.headers.get("Retry-After", "1"))
                except (TypeError, ValueError):
                    retry_after = 1.0
                if 0 <= retry_after <= 5:
                    sleep(retry_after)
                    continue
            if exc.code == 429:
                raise ProbeError("RATE_LIMIT_RETRY_EXHAUSTED") from None
            if exc.code in (401, 403, 404):
                raise ProbeError("DISCORD_HTTP_" + str(exc.code)) from None
            raise ProbeError("DISCORD_HTTP_ERROR") from None
        except (URLError, TimeoutError, OSError):
            raise ProbeError("NETWORK_FAILURE") from None
    raise ProbeError("RATE_LIMIT_RETRY_EXHAUSTED")


def describe_messages(messages: object) -> tuple[int, int, int, int]:
    if not isinstance(messages, list) or len(messages) > READ_LIMIT:
        raise ProbeError("UNEXPECTED_HISTORY_FORMAT")
    webhook_count = 0
    embed_count = 0
    content_count = 0
    for row in messages:
        if not isinstance(row, dict):
            raise ProbeError("UNEXPECTED_HISTORY_FORMAT")
        webhook_count += bool(row.get("webhook_id"))
        embed_count += bool(row.get("embeds"))
        content_count += bool(row.get("content"))
    return len(messages), webhook_count, embed_count, content_count


def probe(channel_id: str, token: str, *, fetch=fetch_json) -> tuple[str, ...]:
    if not re.fullmatch(r"[0-9]{17,20}", channel_id):
        raise ProbeError("INVALID_CHANNEL_ID")
    if not token or not token.strip():
        raise ProbeError("MISSING_DISCORD_BOT_SECRET")
    identity = fetch("/users/@me", token)
    if not isinstance(identity, dict) or identity.get("bot") is not True:
        raise ProbeError("TOKEN_NOT_A_BOT")
    channel = fetch("/channels/" + channel_id, token)
    if not isinstance(channel, dict) or str(channel.get("id")) != channel_id:
        raise ProbeError("CHANNEL_ID_MISMATCH")
    rows = fetch("/channels/" + channel_id + "/messages?limit=25", token)
    total, webhooks, embeds, content = describe_messages(rows)
    return (
        "BOT_AUTH=OK",
        "CHANNEL_ACCESS=OK",
        "HISTORY_READ=" + ("INCONCLUSIVE_NO_MESSAGES" if total == 0 else "VISIBLE_MESSAGES"),
        "HISTORY_SAMPLE_COUNT=" + str(total),
        "SAMPLE_WEBHOOK_MESSAGES=" + str(webhooks),
        "SAMPLE_MESSAGES_WITH_EMBEDS=" + str(embeds),
        "SAMPLE_MESSAGES_WITH_TEXT=" + str(content),
        "HISTORY_STATUS=" + ("NO_MESSAGES_RETURNED_CHECK_READ_HISTORY_PERMISSION_OR_EMPTY_CHANNEL"
                             if total == 0 else "SAMPLE_VISIBLE_NOT_COMPLETION_PROOF"),
    )


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Read-only Discord channel access test")
    parser.add_argument("--channel-id", required=True, help="Discord notification channel ID")
    args = parser.parse_args(argv)
    secret = os.environ.get("MM2_RESEARCH_DISCORD_BOT_TOKEN", "")
    try:
        result = probe(args.channel_id, secret)
    except ProbeError as exc:
        print("DISCORD_PROBE=FAILED:" + str(exc))
        return 1
    except Exception:
        # No exception formatting: Discord request exceptions may contain private URLs.
        print("DISCORD_PROBE=FAILED:UNEXPECTED_INTERNAL_ERROR")
        return 1
    print("DISCORD_PROBE=OK")
    for line in result:
        print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
