"""Stage74: FULL pinned public MM2 archive ↔ historical Supreme name coverage.

This is a source-level research result, NOT current-game, player inventory, price
approval, numeric Supreme-ID correspondence, trade, Accept, or Discord learning.
The website-local Supreme row "id" is NOT a Roblox raw weapon ID.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

SCHEMA = "gingerscope-stage74-complete-public-archive-name-audit-v1"
CATALOG_BLOB = "b0661d54893f681777ebd3eae50d0a4ebe9a46e3"
SUPREME_BLOB = "955e3fb7cd25999fc4f0aad4a77378b9a7bb9ba3"
CATEGORIES = ("ancient", "godly", "chroma")
# The exact pinned October-2026 v1456 source contains 995 top-level game rows.
# The November-4 Supreme archive has 190 eligible canonical source rows.
EXPECTED_ARCHIVED_GAME_ROWS = 995
EXPECTED_SOURCE_ROWS = 190
ENTRY = re.compile(r"(?m)^\t([A-Za-z0-9_]+)\s*=\s*\{\s*\n([\s\S]*?)^\t\},?")
FIELD = re.compile(
    r'(?m)^\t\t(ItemName|ItemType|Rarity|Chroma|ItemID)'
    r'\s*=\s*("[^"\n]*"|\d+|true|false)\s*,?\s*$'
)
FLAGS = dict(
    archivedNameCorrespondenceOnly=True,
    currentGameCatalogAuthenticated=False,
    playerInventoryRead=False,
    sourcePublisherCurrentVerified=False,
    currentPricesVerified=False,
    numericSupremeCheckerIdProvenByGame=False,
    rawGameToSupremeCheckerApproved=False,
    authorizesTrade=False,
    authorizesAccept=False,
    mayReportProfit=False,
    mayRecordCompletedTrade=False,
    mayRecordRejectedTrade=False,
    mayUseForStrategyLearning=False,
    maySendDiscordWebhook=False,
)

def blob_sha(data: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()

def result(status: str, reason: str, **data) -> dict:
    return {
        "schema": SCHEMA, "status": status, "reason": reason,
        "gameArchive": "tlredz/decompiledGames v1456 2026-10-05",
        "supremeArchive": "2026-11-04 HISTORICAL (EXPIRED)",
        "tradeOutcome": "UNKNOWN",
        **FLAGS,
        **data,
    }

def _parse_field_value(value: str):
    if value.startswith('"'):
        return value[1:-1]
    if value in ("true", "false"):
        return value == "true"
    return int(value)

def parse_game_entries(text: str) -> dict:
    """Parse ONLY direct top-level Lua literal fields, never nested property text."""
    raw = {}
    for match in ENTRY.finditer(text):
        key = match.group(1)
        if key in raw:
            raise ValueError("duplicate top-level game catalogue key")
        attrs = {}
        for direct in FIELD.finditer(match.group(2)):
            name = direct.group(1)
            if name in attrs:
                raise ValueError("duplicate direct game field")
            attrs[name] = _parse_field_value(direct.group(2))
        raw[key] = attrs
    if len(raw) != EXPECTED_ARCHIVED_GAME_ROWS:
        raise ValueError("unreviewed archival game catalogue coverage")
    return raw

def game_page_name(attrs: dict):
    name = attrs.get("ItemName")
    rarity = attrs.get("Rarity")
    weapon_type = attrs.get("ItemType")
    if rarity not in ("Godly", "Ancient") or weapon_type not in ("Knife", "Gun"):
        return None
    if not isinstance(name, str) or not 0 < len(name) <= 128 or re.search(r"[\x00-\x1f]", name):
        raise ValueError("eligible game source name invalid")
    item_id = attrs.get("ItemID")
    if type(item_id) is not int or not (0 < item_id < 10**15):
        raise ValueError("eligible game asset id invalid")
    chroma = attrs.get("Chroma", False)
    if type(chroma) is not bool:
        raise ValueError("unexpected chroma variant flag")
    if chroma:
        if rarity != "Godly" or name.casefold().startswith("chroma "):
            raise ValueError("chroma variant/category mismatch")
        return ("chroma", "Chroma " + name)
    return ("ancient" if rarity == "Ancient" else "godly", name)

def parse_market_rows(raw: bytes) -> set:
    source = json.loads(raw)
    if not isinstance(source, dict) or source.get("schemaVersion") != 1:
        raise ValueError("invalid public source snapshot")
    rows = source.get("rows")
    if not isinstance(rows, list) or len(rows) != EXPECTED_SOURCE_ROWS:
        raise ValueError("unreviewed supreme item count")
    names, ids = set(), set()
    for row in rows:
        if not isinstance(row, dict):
            raise ValueError("source row not a record")
        page, name, identifier = row.get("page"), row.get("sourceName"), row.get("id")
        if page not in CATEGORIES or not isinstance(name, str) or not name or len(name)>128:
            raise ValueError("invalid market name/category")
        if not isinstance(identifier, str) or not identifier.isdecimal():
            raise ValueError("invalid market-local index")
        if row.get("verified") is not True:
            raise ValueError("original public market row invalid")
        if (page,name) in names or (page,identifier) in ids:
            raise ValueError("duplicate market name or index")
        names.add((page,name))
        ids.add((page,identifier))
    return names

def evaluate(catalog_bytes: bytes, supreme_bytes: bytes) -> dict:
    if not isinstance(catalog_bytes, bytes) or not isinstance(supreme_bytes, bytes):
        return result("INCONCLUSIVE", "MISSING_PINNED_SOURCE_BYTES")
    if blob_sha(catalog_bytes) != CATALOG_BLOB:
        return result("INCONCLUSIVE", "ARCHIVED_GAME_BLOB_MISMATCH")
    if blob_sha(supreme_bytes) != SUPREME_BLOB:
        return result("INCONCLUSIVE", "HISTORICAL_SUPREME_BLOB_MISMATCH")
    try:
        game = parse_game_entries(catalog_bytes.decode("utf-8"))
        canonical = parse_market_rows(supreme_bytes)
        game_counts = {}
        for props in game.values():
            page_and_name = game_page_name(props)
            if page_and_name:
                game_counts[page_and_name] = game_counts.get(page_and_name, 0) + 1
        matches = sorted(k for k in canonical if game_counts.get(k,0)==1)
        ambiguous = sorted(k for k in canonical if game_counts.get(k,0)>1)
        missing = sorted(k for k in canonical if k not in game_counts)
        if len(matches)+len(ambiguous)+len(missing) != len(canonical):
            raise ValueError("coverage partition lost entries")
    except (ValueError, KeyError, TypeError, UnicodeDecodeError, json.JSONDecodeError):
        return result("INCONCLUSIVE", "PUBLIC_ARCHIVE_CROSSWALK_SHAPE_UNREVIEWED")
    return result(
        "ARCHIVED_PUBLIC_NAME_COVERAGE_ONLY",
        "ARCHIVED_GAME_KEYS_NOT_AUTHENTICATED_CURRENT_OR_MARKET_NUMERIC_IDS",
        archiveTopLevelRows=len(game),
        archiveEligibleRows=sum(game_counts.values()),
        snapshotCanonicalRows=len(canonical),
        uniquePublicNameAndCategoryMatches=len(matches),
        ambiguousPublicNameMatches=len(ambiguous),
        sourceNamesAbsentFromArchive=len(missing),
        matchedByCategory={
            page: sum(1 for p, _ in matches if p == page)
            for page in CATEGORIES
        },
        # Public publisher labels only; do not export individual user's
        # inventory, raw keys, player identifiers or site-local checker IDs.
        absentPublicSourceNames=[
            {"page": page, "name": name} for page,name in missing
        ],
    )

def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--game-archive", type=Path, required=True)
    p.add_argument("--supreme-archive", type=Path, required=True)
    a = p.parse_args()
    out = evaluate(a.game_archive.read_bytes(), a.supreme_archive.read_bytes())
    print(json.dumps(out, sort_keys=True))
    if out["status"] != "ARCHIVED_PUBLIC_NAME_COVERAGE_ONLY":
        raise SystemExit(2)

if __name__ == "__main__":
    main()
