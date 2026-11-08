#!/usr/bin/env python3
"""MM2 Discord historical notification -> private, research-only JSONL evidence ledger.

No raw Discord embeds, usernames, message text, or credentials are persisted or
printed. Requires execution within a *verified private GitHub repository*.
This ledger is NOT proof of MM2 server settlement and is NEVER trade authority.

Public source code may be reviewed in MM2-AutoTrade-Rebuild. Never run the
collector with credentials on that public repository.
"""
from __future__ import annotations

from collections import Counter
from datetime import datetime, timezone
from decimal import Decimal
import argparse
import json
import os
from pathlib import Path
import re
import sys
import tempfile

# Direct module loading in offline tests/private Actions must still resolve the sibling
# audit module from this immutable reviewed source tree.
sys.path.insert(0, str(Path(__file__).resolve().parent))
import discord_history_embed_audit as audit

SCHEMA = "mm2-discord-private-evidence-ledger-v1"
PUBLIC_REPO = "chazebanks/MM2-AutoTrade-Rebuild"
APPROVED_CHANNEL = audit.APPROVED_CHANNEL
MAX_PAGES = 20
MAX_RECORDS = MAX_PAGES * audit.PER_PAGE
MAX_LEDGER_BYTES = 20 * 1024 * 1024
RELATIVE_LEDGER_PATH = Path("data/mm2_discord/history_v1.jsonl")
SNOWFLAKE = audit.SNOWFLAKE
ITEM_MAX_NAME_LENGTH = 100


class LedgerError(Exception):
    """Only fixed, non-sensitive failure codes are emitted to logs."""


def timestamp_utc(value: object) -> str | None:
    if not isinstance(value, str) or len(value) > 48:
        return None
    try:
        dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    if dt.tzinfo is None:
        return None
    return dt.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def item_rows(value: str) -> list[dict[str, str | int]]:
    if not isinstance(value, str):
        raise LedgerError("INVALID_ITEM_ROW")
    lines = [line.strip() for line in value.splitlines() if line.strip()]
    if not 1 <= len(lines) <= 4:
        raise LedgerError("INVALID_ITEM_COUNT")
    rows = []
    for line in lines:
        match = audit.ITEM_ROW.fullmatch(line)
        if not match:
            raise LedgerError("INVALID_ITEM_ROW")
        name = match.group("item").strip()
        if (not name or len(name) > ITEM_MAX_NAME_LENGTH or
                any(c in name for c in ("<", ">", "@", "\r", "\t")) or
                re.search(r"(?:\bx\s*\d+|\bqty\b|\bquantity\b|[×✕]\s*\d+)", name, re.I)):
            raise LedgerError("AMBIGUOUS_ITEM_IDENTITY")
        val = audit.decimal(match.group("value"))
        if val is None or val <= 0:
            raise LedgerError("INVALID_LISTED_VALUE")
        rows.append({
            "unverified_display_label": name,
            "listed_value_at_notification": format(val, "f"),
            "assumed_physical_copy_count": 1,
            "raw_mm2_weapon_key_verified": False,
            "checker_id_verified": False,
        })
    return rows


def build_record(message: object, *, expected_webhook_id: str | None = None) -> dict | None:
    """Create minimal private archive record; no identity or settlement promotion."""
    if not isinstance(message, dict):
        raise LedgerError("INVALID_MESSAGE")
    message_id = message.get("id")
    if not isinstance(message_id, str) or not SNOWFLAKE.fullmatch(message_id):
        raise LedgerError("INVALID_MESSAGE_ID")
    webhook_id = message.get("webhook_id")
    if not isinstance(webhook_id, str) or not SNOWFLAKE.fullmatch(webhook_id):
        return None  # Do not retain unrelated non-webhook channel content.
    if expected_webhook_id and webhook_id != expected_webhook_id:
        return None  # Do not retain other webhook messages.
    embeds = message.get("embeds")
    if not isinstance(embeds, list):
        return None
    trade_embeds = [e for e in embeds if isinstance(e, dict) and
                    e.get("title") == "MM2 Trade Completed"]
    if not trade_embeds:
        return None  # Do not collect non-trade messages or other webhooks.
    classification = audit.classify_message(message)
    record: dict = {
        "schema": SCHEMA,
        "source": "HISTORICAL_DISCORD_WEBHOOK_SELF_REPORT",
        "channel_id": APPROVED_CHANNEL,
        "message_id": message_id,
        "source_webhook_id": webhook_id,
        "webhook_source_pinned": bool(expected_webhook_id),
        "discord_message_timestamp_utc": timestamp_utc(message.get("timestamp")),
        "classification": classification,
        "server_settlement": "UNKNOWN",
        "completed_trade_verified": False,
        "learning_eligible": False,
        "authorizes_trade": False,
        "authorizes_accept": False,
        "may_report_profit": False,
    }
    if classification == "TEST_ACCOUNT_EXCLUDED":
        record["counterparty_category"] = "TEST_ACCOUNT"
        return record  # No test-account name or trade items persist.
    if classification != "PARSED_UNVERIFIED_WEBHOOK_CLAIM":
        record["counterparty_category"] = "UNKNOWN_OR_UNRECONCILED"
        record["recover_from_discord_by_message_id"] = True
        return record  # Quarantine unparseable messages, no guessed data.
    fields = audit.embed_fields(trade_embeds[0])
    if fields is None:
        raise LedgerError("PARSER_CLASSIFICATION_CONFLICT")
    trader = audit.normalized_username(fields.get("trader"))
    if not trader or trader == audit.TEST_ACCOUNT:
        raise LedgerError("PARSER_CLASSIFICATION_CONFLICT")
    try:
        given_items = item_rows(fields["you gave"])
        received_items = item_rows(fields["you received"])
    except (KeyError, LedgerError):
        raise LedgerError("PARSER_CLASSIFICATION_CONFLICT") from None
    values = audit.VALUES.fullmatch(fields["values"])
    profit = audit.PROFIT.fullmatch(fields["profit"])
    if not values or not profit:
        raise LedgerError("PARSER_CLASSIFICATION_CONFLICT")
    given_value = Decimal(values.group(1))
    received_value = Decimal(values.group(2))
    reported_gain = Decimal(profit.group(1))
    if (sum(Decimal(str(x["listed_value_at_notification"])) for x in given_items) != given_value or
            sum(Decimal(str(x["listed_value_at_notification"])) for x in received_items) != received_value or
            received_value - given_value != reported_gain):
        raise LedgerError("PARSER_CLASSIFICATION_CONFLICT")
    mode = fields["mode"]
    if not isinstance(mode, str) or not re.fullmatch(r"[A-Za-z][A-Za-z -]{0,39}", mode):
        mode = "UNKNOWN"
    record["counterparty_category"] = "NON_TEST_TRADER_UNVERIFIED"
    record["claimed_trade"] = {
        "mode": mode,
        "gave": given_items,
        "received": received_items,
        "listed_gave_at_notification": format(given_value, "f"),
        "listed_received_at_notification": format(received_value, "f"),
        "reported_listed_gain": format(reported_gain, "f"),
    }
    return record


def collect_records(page_fetch, *, max_pages: int = MAX_PAGES,
                    expected_webhook_id: str | None = None) -> tuple[list[dict], Counter]:
    """Full bounded pagination. Any ambiguous/incomplete run returns no records."""
    if type(max_pages) is not int or not 1 <= max_pages <= MAX_PAGES:
        raise LedgerError("INVALID_PAGE_LIMIT")
    if expected_webhook_id and not SNOWFLAKE.fullmatch(expected_webhook_id):
        raise LedgerError("INVALID_WEBHOOK_PIN")
    cursor: str | None = None
    visited: set[str] = set()
    out: list[dict] = []
    stats = Counter()
    finished = False
    for _ in range(max_pages):
        page = page_fetch(cursor)
        if not isinstance(page, list) or len(page) > audit.PER_PAGE:
            raise LedgerError("INVALID_DISCORD_PAGE")
        stats["pages"] += 1
        prior_id: int | None = None
        for message in page:
            if not isinstance(message, dict):
                raise LedgerError("INVALID_MESSAGE")
            msg_id = message.get("id")
            if not isinstance(msg_id, str) or not SNOWFLAKE.fullmatch(msg_id):
                raise LedgerError("INVALID_MESSAGE_ID")
            num = int(msg_id)
            if (cursor is not None and num >= int(cursor)) or (prior_id is not None and num >= prior_id):
                raise LedgerError("PAGINATION_ORDER_FAILURE")
            prior_id = num
            if msg_id in visited:
                stats["duplicates_in_response"] += 1
                continue
            visited.add(msg_id)
            stats["messages_scanned"] += 1
            rec = build_record(message, expected_webhook_id=expected_webhook_id)
            if rec is None:
                stats["unrelated_skipped"] += 1
            else:
                stats[rec["classification"]] += 1
                out.append(rec)
        if len(page) < audit.PER_PAGE:
            finished = True
            break
        cursor = str(min(int(m["id"]) for m in page))
    if not finished:
        raise LedgerError("BACKFILL_PAGE_LIMIT_REACHED")
    stats["records_prepared"] = len(out)
    stats["source_identity_pinned"] = int(bool(expected_webhook_id))
    stats["server_verified_settlements"] = 0
    stats["learning_eligible"] = 0
    return out, stats


def ledger_path(workspace: Path) -> Path:
    if not workspace.is_dir() or workspace.is_symlink():
        raise LedgerError("INVALID_PRIVATE_WORKSPACE")
    root = workspace.resolve()
    path = root
    for part in RELATIVE_LEDGER_PATH.parts[:-1]:
        path = path / part
        if path.is_symlink():
            raise LedgerError("SYMLINK_LEDGER_DIRECTORY")
    file_path = root / RELATIVE_LEDGER_PATH
    if file_path.is_symlink():
        raise LedgerError("SYMLINK_LEDGER_FILE")
    return file_path


def load_existing(path: Path) -> dict[str, dict]:
    if not path.exists():
        return {}
    if not path.is_file() or path.stat().st_size > MAX_LEDGER_BYTES:
        raise LedgerError("INVALID_EXISTING_ARCHIVE")
    existing = {}
    with path.open("r", encoding="utf-8") as f:
        for line in f:
            try:
                value = json.loads(line)
            except ValueError:
                raise LedgerError("CORRUPT_ARCHIVE_JSON") from None
            if not isinstance(value, dict) or value.get("schema") != SCHEMA or value.get("channel_id") != APPROVED_CHANNEL:
                raise LedgerError("UNTRUSTED_ARCHIVE_SCHEMA")
            msg_id = value.get("message_id")
            if not isinstance(msg_id, str) or not SNOWFLAKE.fullmatch(msg_id) or msg_id in existing:
                raise LedgerError("DUPLICATE_OR_INVALID_ARCHIVE_ID")
            if (value.get("learning_eligible") is not False or
                    value.get("completed_trade_verified") is not False or
                    value.get("server_settlement") != "UNKNOWN" or
                    value.get("authorizes_trade") is not False or
                    value.get("authorizes_accept") is not False or
                    value.get("may_report_profit") is not False):
                raise LedgerError("UNSAFE_ARCHIVE_AUTHORITY")
            existing[msg_id] = value
    return existing


def stage_records(workspace: Path, new_records: list[dict]) -> tuple[int, int]:
    """Atomic, idempotent archive write. Historical edits cause conflict, not overwrite."""
    path = ledger_path(workspace)
    old = load_existing(path)
    combined = dict(old)
    inserted = 0
    for rec in new_records:
        msg_id = rec.get("message_id")
        if not isinstance(msg_id, str) or not SNOWFLAKE.fullmatch(msg_id):
            raise LedgerError("INVALID_CANDIDATE_ID")
        if rec.get("schema") != SCHEMA or rec.get("channel_id") != APPROVED_CHANNEL:
            raise LedgerError("INVALID_CANDIDATE_SCHEMA")
        if (rec.get("learning_eligible") is not False or
                rec.get("completed_trade_verified") is not False or
                rec.get("server_settlement") != "UNKNOWN" or
                rec.get("authorizes_trade") is not False or
                rec.get("authorizes_accept") is not False or
                rec.get("may_report_profit") is not False):
            raise LedgerError("UNSAFE_CANDIDATE_AUTHORITY")
        if msg_id in combined:
            if combined[msg_id] != rec:
                raise LedgerError("EXISTING_RECEIPT_CHANGED_REVIEW_REQUIRED")
        else:
            combined[msg_id] = rec
            inserted += 1
    if inserted == 0:
        return 0, len(combined)
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    if path.parent.is_symlink():
        raise LedgerError("SYMLINK_LEDGER_DIRECTORY")
    data = "".join(json.dumps(combined[mid], sort_keys=True, ensure_ascii=False, separators=(",", ":")) + "\n"
                   for mid in sorted(combined, key=int))
    if len(data.encode("utf-8")) > MAX_LEDGER_BYTES:
        raise LedgerError("ARCHIVE_SIZE_LIMIT")
    temp: str | None = None
    try:
        fd, temp = tempfile.mkstemp(prefix=".history_v1-", dir=path.parent)
        with os.fdopen(fd, "w", encoding="utf-8") as out:
            out.write(data)
            out.flush()
            os.fsync(out.fileno())
        os.chmod(temp, 0o600)
        os.replace(temp, path)
    finally:
        if temp and os.path.exists(temp):
            os.unlink(temp)
    return inserted, len(combined)


def validated_private_workspace(env: dict[str, str]) -> Path:
    repo = env.get("GITHUB_REPOSITORY", "")
    if (env.get("MM2_PRIVATE_REPO_VERIFIED") != "true" or not repo or
            repo == PUBLIC_REPO or repo.count("/") != 1 or
            env.get("MM2_EXPECTED_ARCHIVE_REPO") != repo):
        raise LedgerError("PRIVATE_REPOSITORY_REQUIRED")
    workspace_str = env.get("GITHUB_WORKSPACE", "")
    if not workspace_str:
        raise LedgerError("INVALID_PRIVATE_WORKSPACE")
    return Path(workspace_str)


def main(argv=None, *, env=None, fetch=None) -> int:
    parser = argparse.ArgumentParser(description="Private MM2 Discord evidence ledger importer")
    parser.add_argument("--channel-id", required=True)
    parser.add_argument("--max-pages", type=int, default=MAX_PAGES)
    args = parser.parse_args(argv)
    environment = dict(os.environ if env is None else env)
    try:
        workspace = validated_private_workspace(environment)
        if args.channel_id != APPROVED_CHANNEL:
            raise LedgerError("UNAUTHORIZED_DISCORD_CHANNEL")
        token = environment.get("MM2_RESEARCH_DISCORD_BOT_TOKEN", "")
        if not token:
            raise LedgerError("MISSING_DISCORD_BOT_SECRET")
        pin = environment.get("MM2_RESEARCH_SOURCE_WEBHOOK_ID") or None
        pages = fetch if fetch is not None else lambda before: audit.fetch_page(
            args.channel_id, token, before)
        records, stats = collect_records(pages, max_pages=args.max_pages,
                                         expected_webhook_id=pin)
        inserted, total = stage_records(workspace, records)
    except (LedgerError, audit.AuditFailure) as exc:
        # Fixed codes only; no payload, credential, or request exception details.
        print("PRIVATE_HISTORY_IMPORT=FAILED:" + str(exc))
        return 1
    except Exception:
        print("PRIVATE_HISTORY_IMPORT=FAILED:INTERNAL_ERROR")
        return 1
    print("PRIVATE_HISTORY_IMPORT=OK")
    for key in ("pages", "messages_scanned", "unrelated_skipped", "TEST_ACCOUNT_EXCLUDED",
                "PARSED_UNVERIFIED_WEBHOOK_CLAIM", "UNKNOWN_TRADER_EXCLUDED",
                "UNPARSEABLE_ITEM_BUNDLE", "INCONSISTENT_VALUE_CLAIM",
                "records_prepared", "source_identity_pinned",
                "server_verified_settlements", "learning_eligible"):
        print("COUNT_" + key.upper() + "=" + str(stats[key]))
    print("COUNT_NEW_PRIVATE_RECORDS=" + str(inserted))
    print("COUNT_TOTAL_PRIVATE_RECORDS=" + str(total))
    print("TRADE_ACCEPTANCE_AND_LEARNING_DISABLED=TRUE")
    return 0


if __name__ == "__main__":
    sys.exit(main())
