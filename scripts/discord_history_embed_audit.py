#!/usr/bin/env python3
"""Research-only Discord webhook embed history audit.

Explicitly limited to the owner's one authorized MM2 channel.
Reads at most 3 x 50 messages, keeps all payloads in transient process memory,
writes no files/artifacts/DB, and prints fixed aggregate counters only.
A webhook saying "Trade Completed" is NOT verified settlement.
"""
from __future__ import annotations

from collections import Counter
from decimal import Decimal, InvalidOperation
import argparse
import json
import os
import re
import sys
import time
import unicodedata
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

API = "https://discord.com/api/v10"
APPROVED_CHANNEL = "1565287412106797098"
TEST_ACCOUNT = "venossgaming90190"
PER_PAGE = 50
MAX_PAGES = 3
MAX_BYTES = 2_000_000
SNOWFLAKE = re.compile(r"[0-9]{17,20}\Z")
USERNAME = re.compile(r"[A-Za-z0-9_]{3,20}\Z")
ITEM_ROW = re.compile(r"(?P<item>[^\n]+?)\s+-\s+(?P<value>\d+(?:\.\d{1,2})?)\Z")
VALUES = re.compile(r"You:\s*(\d+(?:\.\d{1,2})?)\s*\|\s*Them:\s*(\d+(?:\.\d{1,2})?)\Z", re.I)
PROFIT = re.compile(r"([+-]?\d+(?:\.\d{1,2})?)(?:\s*\(\s*\d+(?:\.\d+)?%\s*\))?\Z")
EXPECTED_FIELDS = ("trader", "profit", "mode", "you gave", "you received", "values")


class AuditFailure(Exception):
    """Only fixed, non-sensitive failure codes may be printed."""


def normalized_username(raw: object) -> str | None:
    if not isinstance(raw, str):
        return None
    cleaned = unicodedata.normalize("NFKC", raw).strip()
    return cleaned.casefold() if USERNAME.fullmatch(cleaned) else None


def decimal(raw: str) -> Decimal | None:
    try:
        out = Decimal(raw)
    except (InvalidOperation, TypeError, ValueError):
        return None
    if not out.is_finite() or out < 0 or out.as_tuple().exponent < -2:
        return None
    return out


def embed_fields(embed: dict) -> dict[str, str] | None:
    """Accept only exact Discord embed field name/value pairs; no guesses."""
    fields = embed.get("fields")
    if not isinstance(fields, list) or len(fields) > 25:
        return None
    found: dict[str, str] = {}
    for row in fields:
        if not isinstance(row, dict) or not isinstance(row.get("name"), str) or not isinstance(row.get("value"), str):
            return None
        key = " ".join(row["name"].replace("*", "").casefold().split())
        if not key or key in found or len(row["value"]) > 1024:
            return None
        found[key] = row["value"].strip().replace("**", "")
    return found


def bundle_value(raw: str) -> Decimal | None:
    lines = [line.strip() for line in raw.splitlines() if line.strip()]
    if not 1 <= len(lines) <= 4:
        return None
    total = Decimal(0)
    for line in lines:
        match = ITEM_ROW.fullmatch(line)
        if not match:
            return None
        name = match.group("item").strip()
        # Older reports don't encode unit/copy quantity. Reject ambiguous stacks.
        if not name or re.search(r"(?:\bx\s*\d+|\bqty\b|\bquantity\b|[×✕]\s*\d+)", name, re.I):
            return None
        value = decimal(match.group("value"))
        if value is None or value <= 0:
            return None
        total += value
    return total


def classify_message(message: object) -> str:
    if not isinstance(message, dict):
        return "MALFORMED_MESSAGE"
    if not isinstance(message.get("webhook_id"), str) or not SNOWFLAKE.fullmatch(message["webhook_id"]):
        return "NOT_WEBHOOK"
    embeds = message.get("embeds")
    if not isinstance(embeds, list):
        return "MALFORMED_MESSAGE"
    matches = [e for e in embeds if isinstance(e, dict) and
               isinstance(e.get("title"), str) and e["title"].strip() == "MM2 Trade Completed"]
    if not matches:
        return "NOT_TRADE_EMBED"
    if len(matches) != 1:
        return "AMBIGUOUS_TRADE_EMBEDS"
    fields = embed_fields(matches[0])
    if fields is None:
        return "UNKNOWN_EMBED_STRUCTURE"
    # Test-account exclusion must happen BEFORE assuming the reported exchange is valid.
    trader = normalized_username(fields.get("trader"))
    if trader == TEST_ACCOUNT:
        return "TEST_ACCOUNT_EXCLUDED"
    if trader is None:
        return "UNKNOWN_TRADER_EXCLUDED"
    if not all(k in fields for k in EXPECTED_FIELDS):
        return "INCOMPLETE_TRADE_CLAIM"
    if not fields["mode"].strip():
        return "INCOMPLETE_TRADE_CLAIM"
    given, received = bundle_value(fields["you gave"]), bundle_value(fields["you received"])
    if given is None or received is None:
        return "UNPARSEABLE_ITEM_BUNDLE"
    listed = VALUES.fullmatch(fields["values"].strip())
    profit = PROFIT.fullmatch(fields["profit"].strip())
    if listed is None or profit is None:
        return "UNPARSEABLE_VALUE_CLAIM"
    give_total, receive_total = decimal(listed.group(1)), decimal(listed.group(2))
    if give_total is None or receive_total is None:
        return "UNPARSEABLE_VALUE_CLAIM"
    gain_text = profit.group(1)
    try:
        signed_gain = Decimal(gain_text)
    except InvalidOperation:
        return "UNPARSEABLE_VALUE_CLAIM"
    if give_total != given or receive_total != received or signed_gain != received - given:
        return "INCONSISTENT_VALUE_CLAIM"
    # Parsed != verified. Source webhook identity not pinned; self-reported completion only.
    return "PARSED_UNVERIFIED_WEBHOOK_CLAIM"


def audit_pages(page_fetch, *, max_pages: int = MAX_PAGES) -> Counter:
    if type(max_pages) is not int or not 1 <= max_pages <= MAX_PAGES:
        raise AuditFailure("INVALID_PAGE_LIMIT")
    counts = Counter()
    seen: set[str] = set()
    webhook_ids: set[str] = set()
    cursor = None
    for _ in range(max_pages):
        page = page_fetch(cursor)
        if not isinstance(page, list) or len(page) > PER_PAGE:
            raise AuditFailure("INVALID_DISCORD_PAGE")
        counts["pages_read"] += 1
        current_ids: list[int] = []
        for message in page:
            if not isinstance(message, dict) or not isinstance(message.get("id"), str) or not SNOWFLAKE.fullmatch(message["id"]):
                raise AuditFailure("INVALID_MESSAGE_ID")
            msg_id = message["id"]
            current_ids.append(int(msg_id))
            if cursor is not None and int(msg_id) >= int(cursor):
                raise AuditFailure("PAGINATION_ORDER_VIOLATION")
            if msg_id in seen:
                counts["duplicate_messages"] += 1
                continue
            seen.add(msg_id)
            counts["messages_seen"] += 1
            if isinstance(message.get("webhook_id"), str) and SNOWFLAKE.fullmatch(message["webhook_id"]):
                webhook_ids.add(message["webhook_id"])
            if isinstance(message.get("embeds"), list):
                for e in message["embeds"]:
                    if isinstance(e, dict) and e.get("title") == "MM2 Trade Completed":
                        counts["trade_embeds_with_fields"] += bool(isinstance(e.get("fields"), list) and e["fields"])
                        counts["trade_embeds_with_description"] += bool(isinstance(e.get("description"), str) and e["description"])
            result = classify_message(message)
            counts[result] += 1
            # Discard in-memory response reference at page end. Never print source data.
        if len(page) < PER_PAGE:
            break
        next_cursor = str(min(current_ids))
        if cursor is not None and int(next_cursor) >= int(cursor):
            raise AuditFailure("PAGINATION_STALLED")
        cursor = next_cursor
    counts["distinct_webhook_ids"] = len(webhook_ids)
    counts["source_identity_pinned"] = 0
    counts["server_verified_settlements"] = 0
    counts["learning_eligible"] = 0
    counts["records_stored"] = 0
    return counts


def fetch_page(channel_id: str, token: str, before: str | None, *,
               opener=urlopen, sleep=time.sleep) -> list:
    if channel_id != APPROVED_CHANNEL or not token or not token.strip():
        raise AuditFailure("UNAUTHORIZED_CHANNEL_OR_SECRET")
    if before is not None and not SNOWFLAKE.fullmatch(before):
        raise AuditFailure("INVALID_CURSOR")
    path = f"/channels/{channel_id}/messages?limit={PER_PAGE}"
    if before:
        path += "&before=" + before
    req = Request(API + path, headers={
        "Authorization": "Bot " + token,
        "User-Agent": "MM2-Trade-Research-History-Audit/1.0",
        "Accept": "application/json",
    }, method="GET")
    for attempt in range(3):
        try:
            with opener(req, timeout=15) as resp:
                if resp.status != 200:
                    raise AuditFailure("HTTP_UNEXPECTED_STATUS")
                raw = resp.read(MAX_BYTES + 1)
                if len(raw) > MAX_BYTES:
                    raise AuditFailure("RESPONSE_TOO_LARGE")
                try:
                    result = json.loads(raw.decode("utf-8"))
                except (ValueError, UnicodeError):
                    raise AuditFailure("INVALID_RESPONSE_JSON") from None
                if not isinstance(result, list):
                    raise AuditFailure("INVALID_RESPONSE_SHAPE")
                return result
        except HTTPError as exc:
            if exc.code == 429 and attempt < 2:
                try:
                    pause = float(exc.headers.get("Retry-After", "1"))
                except (TypeError, ValueError):
                    pause = 1.0
                if 0 <= pause <= 5:
                    sleep(pause)
                    continue
            if exc.code in (401, 403, 404):
                raise AuditFailure("DISCORD_HTTP_" + str(exc.code)) from None
            raise AuditFailure("DISCORD_HTTP_ERROR") from None
        except (URLError, TimeoutError, OSError):
            raise AuditFailure("NETWORK_FAILURE") from None
    raise AuditFailure("RATE_LIMIT_RETRY_EXHAUSTED")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="No-storage Discord embed claims audit")
    parser.add_argument("--channel-id", required=True)
    parser.add_argument("--max-pages", type=int, default=MAX_PAGES)
    args = parser.parse_args(argv)
    token = os.environ.get("MM2_RESEARCH_DISCORD_BOT_TOKEN", "")
    if not token:
        print("HISTORY_AUDIT=FAILED:MISSING_BOT_TOKEN")
        return 1
    if args.channel_id != APPROVED_CHANNEL:
        print("HISTORY_AUDIT=FAILED:UNAUTHORIZED_CHANNEL")
        return 1
    try:
        counts = audit_pages(
            lambda before: fetch_page(args.channel_id, token, before),
            max_pages=args.max_pages,
        )
    except AuditFailure as exc:
        print("HISTORY_AUDIT=FAILED:" + str(exc))
        return 1
    except Exception:
        # No traceback or exception string: may include Discord payloads.
        print("HISTORY_AUDIT=FAILED:INTERNAL_ERROR")
        return 1
    print("HISTORY_AUDIT=OK")
    for key in ("pages_read", "messages_seen", "duplicate_messages", "distinct_webhook_ids",
                "trade_embeds_with_fields", "trade_embeds_with_description",
                "NOT_WEBHOOK", "NOT_TRADE_EMBED", "MALFORMED_MESSAGE",
                "AMBIGUOUS_TRADE_EMBEDS", "UNKNOWN_EMBED_STRUCTURE",
                "TEST_ACCOUNT_EXCLUDED", "UNKNOWN_TRADER_EXCLUDED",
                "INCOMPLETE_TRADE_CLAIM", "UNPARSEABLE_ITEM_BUNDLE",
                "UNPARSEABLE_VALUE_CLAIM", "INCONSISTENT_VALUE_CLAIM",
                "PARSED_UNVERIFIED_WEBHOOK_CLAIM", "source_identity_pinned",
                "server_verified_settlements", "learning_eligible", "records_stored"):
        print("COUNT_" + key.upper() + "=" + str(counts[key]))
    print("HISTORICAL_NOTIFICATIONS_ARE_NOT_SERVER_SETTLEMENT_EVIDENCE=TRUE")
    return 0


if __name__ == "__main__":
    sys.exit(main())
