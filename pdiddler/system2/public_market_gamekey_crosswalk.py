"""System2 S2.2: exact pinned raw-game-key ↔ current public market item crosswalk.

Does not obtain private player inventory, invoke game remotes, or authorize trades.
Site names/URLs are *not* Roblox game IDs. Only the original immutable Stage83
raw-key registry plus strict category/variant/name binding supplies key candidates.
"""
from __future__ import annotations

import hashlib
import json
import re
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation

from pdiddler.system2.catalog_discovery_diff import (
    SOURCE_BLOB_SHA, SOURCE_COMMIT, load_historical_registry,
)

SCHEMA = "gingerscope-system2-exact-market-gamekey-crosswalk-v1"
SOURCE_SCHEMA = "gingerscope-system2-mm2tradehub-public-html-candidate-v1"
CATEGORIES = {"ancient": 15, "godly": 128, "chroma": 46}
SITE_COUNTS = {"ancient": 16, "godly": 128, "chroma": 46}
DISPLAY_COUNTS = {"ancient": 16, "godly": 128, "chroma": 65}
CATEGORY_MAP = {"ancients": "ancient", "godlies": "godly", "chromas": "chroma"}
# Explicit collision-checked alias, *not* a general suffix/substring rule.
# Original game raw key: FlowerwoodKnife, visible client base name: Flowerwood.
# Public list: "Flowerwood Knife", distinct from the Godly "Flowerwood Gun".
ALIASES = {"FlowerwoodKnife": ("godly", "flowerwood-knife", "Flowerwood Knife")}
# Niks Scythe is an Ancient display record not among eligible Stage83 189 keys.
EXCLUDED = {("ancient", "niks-scythe"): "Niks Scythe"}
KEY = re.compile(r"^[A-Za-z0-9_]{1,90}$")
SLUG = re.compile(r"^[a-z0-9][a-z0-9-]{1,149}$")
HEX = re.compile(r"^[a-f0-9]{64}$")
PROVENANCE = {
    "researchOnly": True,
    "actualGameIdentityRevalidatedNow": False,
    "priorClientCatalogParityObserved": True,  # user-provided, prior session
    "marketDatasetNotSignedByPublisher": True,
    "actualCurrentOwnedInventoryVerified": False,
    "currentOpponentInventoryVerified": False,
    "fourPhysicalTradeSlotsValidated": False,
    "mayUseForLiveOffer": False,
    "authorizesTrade": False,
    "authorizesAccept": False,
    "mayReportProfit": False,
    "mayUseForLearning": False,
}


class MappingBlocked(Exception):
    pass


def reject(code):
    raise MappingBlocked(code)


def _utc(value):
    if type(value) is not str or not value.endswith("Z") or len(value) > 40:
        reject("UTC_TIMESTAMP_REQUIRED")
    try:
        x = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except (ValueError, OverflowError):
        reject("UTC_TIMESTAMP_MALFORMED")
    if x.utcoffset().total_seconds() != 0:
        reject("UTC_TIMEZONE_INVALID")
    return x


def _label(value):
    if type(value) is not str or not 1 <= len(value) <= 130:
        reject("INVALID_NAME")
    # Exact normalized display key, no fuzzy edit distance or partial matching.
    return "".join(c for c in value.casefold() if c.isalnum())


def _source(snapshot, evaluated_utc):
    if type(snapshot) is not dict or snapshot.get("schema") != SOURCE_SCHEMA:
        reject("WRONG_SOURCE_SCHEMA")
    if snapshot.get("status") != "CURRENT_PUBLIC_SOURCE_CANDIDATE":
        reject("SOURCE_NOT_ADMITTED")
    if snapshot.get("website") != "https://mm2tradehub.com":
        reject("SOURCE_HOST_CHANGED")
    for field in ("canFeedLiveTrade", "authorizesOffer", "authorizesAccept",
                  "verifiedServerSettlement", "exactGameWeaponIdentityProven"):
        if snapshot.get(field) is not False:
            reject("FORGED_SOURCE_AUTHORITY")
    if snapshot.get("providerTimestampPrecision") != "date-only":
        reject("SOURCE_PRECISION_CHANGED")
    now, fetched = _utc(evaluated_utc), _utc(snapshot.get("retrievedUtc"))
    if fetched > now or (now - fetched).total_seconds() > 6 * 3600:
        reject("SOURCE_RETRIEVAL_STALE_OR_FUTURE")
    try:
        pub = datetime.strptime(snapshot.get("siteEditionDate", ""), "%Y-%m-%d").replace(tzinfo=timezone.utc)
    except (ValueError, TypeError):
        reject("SOURCE_EDITION_DATE_INVALID")
    if pub > fetched or (now - pub).total_seconds() > 4 * 86400:
        reject("SOURCE_EDITION_STALE_OR_FUTURE")
    if snapshot.get("categoryCounts") != SITE_COUNTS or snapshot.get("displayCardCounts") != DISPLAY_COUNTS:
        reject("SOURCE_CARD_COVERAGE_CHANGED")
    if (snapshot.get("itemCount") != 190 or snapshot.get("deduplicatedCardCount") != 19 or
            type(snapshot.get("items")) is not list or len(snapshot["items"]) != 190):
        reject("SOURCE_UNIQUE_ROW_COUNT_CHANGED")
    pages = snapshot.get("sourceTierPageSha256")
    if type(pages) is not dict or set(pages) != set(CATEGORIES) or any(
            type(x) is not str or not HEX.fullmatch(x) for x in pages.values()):
        reject("SOURCE_PAGE_FINGERPRINT_INVALID")
    seen = set()
    catalog = {}
    counts = {cat: 0 for cat in CATEGORIES}
    for row in snapshot["items"]:
        required = {"providerName", "providerSlug", "providerCategory",
                    "mm2SourceLabel", "mm2Listed", "supremeSourceLabel",
                    "supremeListed", "demandOrdinal", "stabilityLabel",
                    "rawGameWeaponKey", "chromaSubtypeVerified",
                    "completedTradeLiquidityMeasured"}
        if type(row) is not dict or set(row) != required:
            reject("MARKET_ROW_SCHEMA_CHANGED")
        cat, slug, name = (row[x] for x in ("providerCategory", "providerSlug", "providerName"))
        if (cat not in counts or type(slug) is not str or not SLUG.fullmatch(slug)
                or type(name) is not str or len(name) > 110 or len(name) < 2
                or row["rawGameWeaponKey"] is not None or row["chromaSubtypeVerified"] is not False
                or row["completedTradeLiquidityMeasured"] is not False):
            reject("MARKET_ROW_IDENTITY_UNVERIFIED")
        for price in ("mm2Listed", "supremeListed"):
            value = row[price]
            if value is not None and (type(value) is not int or value <= 0 or value >= 10**10):
                reject("MARKET_PRICE_INVALID")
        for label in ("mm2SourceLabel", "supremeSourceLabel"):
            if type(row[label]) is not str or not 1 <= len(row[label]) <= 90:
                reject("MARKET_PRICE_LABEL_INVALID")
        if row["mm2Listed"] is None and row["supremeListed"] is None:
            reject("MARKET_NO_NUMERIC_QUOTE")
        try:
            demand = Decimal(row["demandOrdinal"])
        except (InvalidOperation, TypeError, ValueError):
            reject("MARKET_DEMAND_INVALID")
        if not demand.is_finite() or not 0 <= demand <= 11:
            reject("MARKET_DEMAND_INVALID")
        if row["stabilityLabel"] is not None and (
                type(row["stabilityLabel"]) is not str or len(row["stabilityLabel"]) > 80):
            reject("MARKET_STABILITY_INVALID")
        identity = (cat, _label(name))
        if identity in seen:
            reject("AMBIGUOUS_MARKET_NAME_VARIANT")
        seen.add(identity)
        catalog[identity] = row
        counts[cat] += 1
    if counts != SITE_COUNTS:
        reject("MARKET_CATEGORY_COUNTS_CHANGED")
    return catalog


def crosswalk(snapshot, registry_bytes, *, evaluated_utc):
    """Build one-to-one candidate keys; never silently map an uncertain name."""
    market = _source(snapshot, evaluated_utc)
    try:
        registry = load_historical_registry(registry_bytes, require_original_pin=True)
    except (TypeError, ValueError, UnicodeError):
        reject("HISTORICAL_REGISTRY_PIN_OR_SHAPE_INVALID")
    if len(registry) != 189:
        reject("HISTORICAL_189_KEY_COVERAGE_REQUIRED")
    reconciled, matched = {}, set()
    bycat = {x: 0 for x in CATEGORIES}
    for (plural, _image), item in sorted(registry.items()):
        cat = CATEGORY_MAP[plural]
        raw = item["rawGameKeyCandidate"]
        if type(raw) is not str or not KEY.fullmatch(raw) or raw in reconciled:
            reject("HISTORICAL_RAW_KEY_DUPLICATE_OR_INVALID")
        alias = ALIASES.get(raw)
        if alias:
            if alias[0] != cat:
                reject("EXPLICIT_ALIAS_CATEGORY_MISMATCH")
            name = alias[2]
            target = (cat, _label(name))
            row = market.get(target)
            if row is None or row["providerSlug"] != alias[1] or row["providerName"] != name:
                reject("EXPLICIT_ALIAS_TARGET_MISSING_OR_CHANGED")
        else:
            target = (cat, _label(item["expectedName"]))
            row = market.get(target)
            if row is None:
                reject("EXACT_HISTORICAL_MARKET_NAME_NOT_FOUND")
        if target in matched:
            reject("MARKET_ENTRY_MATCHED_BY_MULTIPLE_GAME_KEYS")
        # A game variant is anchored to the original raw-key registry, not to the
        # website's generic Chroma category (which mixes Ancient and Godly).
        chroma = cat == "chroma"
        rarity = item["rarityCandidate"]
        weapon_type = item["weaponTypeCandidate"]
        if cat == "ancient" and rarity != "Ancient" or cat == "godly" and rarity != "Godly":
            reject("HISTORICAL_GAME_TIER_CONFLICT")
        if weapon_type not in ("Knife", "Gun") or rarity not in ("Ancient", "Godly"):
            reject("HISTORICAL_GAME_WEAPON_TYPE_INVALID")
        matched.add(target)
        bycat[cat] += 1
        base_name = item["expectedName"][7:] if chroma else item["expectedName"]
        reconciled[raw] = {
            "rawGameKeyCandidate": raw, "expectedGameName": base_name,
            "gameItemType": weapon_type, "gameRarity": rarity,
            "gameChroma": chroma, "marketName": row["providerName"],
            "marketSlug": row["providerSlug"], "marketCategory": cat,
            "mm2Listed": row["mm2Listed"], "supremeListed": row["supremeListed"],
            "demandOrdinal": row["demandOrdinal"], "stabilityLabel": row["stabilityLabel"],
            "outgoingGingerscopeProtected": raw == "Gingerscope",
            "exactGameInstanceProven": False,
        }
    if bycat != CATEGORIES or len(reconciled) != 189:
        reject("CROSSWALK_189_KEY_COVERAGE_CHANGED")
    surplus = set(market) - matched
    if len(surplus) != len(EXCLUDED) or any(
            (cat, market[(cat, name)]["providerSlug"]) not in EXCLUDED or
            market[(cat, name)]["providerName"] != EXCLUDED[(cat, market[(cat, name)]["providerSlug"])]
            for cat, name in surplus):
        reject("UNREVIEWED_MARKET_ITEM_NOT_IN_GAME_REGISTRY")
    # Gingerscope is protected, even though it has a valid market quote.
    if ("Gingerscope" not in reconciled or
            reconciled["Gingerscope"]["marketSlug"] != "gingerscope" or
            not reconciled["Gingerscope"]["outgoingGingerscopeProtected"]):
        reject("PROTECTED_TARGET_INVALID")
    rows = [reconciled[k] for k in sorted(reconciled)]
    sha = hashlib.sha256(json.dumps(rows, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    return {
        "schema": SCHEMA, "status": "EXACT_HISTORICAL_GAMEKEY_MARKET_CROSSWALK",
        "marketEdition": snapshot["siteEditionDate"],
        "sourceRetrievedUtc": snapshot["retrievedUtc"],
        "sourcePageSha256": snapshot["sourceTierPageSha256"],
        "historicalRegistryCommit": SOURCE_COMMIT,
        "historicalRegistryBlob": SOURCE_BLOB_SHA,
        "matchedHistoricalGameKeys": 189,
        "categoryGameKeys": bycat,
        "excludedAdditionalMarketCards": len(EXCLUDED),
        "explicitAliasMatches": len(ALIASES),
        "crosswalkRowsSha256": sha,
        "items": rows,
        **PROVENANCE,
    }


def reconcile_one_client_metadata(mapping, raw_key, game_meta):
    """Validate a *supplied* game metadata record. Never trust names alone."""
    fail = lambda code: {"status": "BLOCKED", "reason": code, **PROVENANCE}
    if type(mapping) is not dict or mapping.get("schema") != SCHEMA or (
            mapping.get("status") != "EXACT_HISTORICAL_GAMEKEY_MARKET_CROSSWALK"):
        return fail("CROSSWALK_MISSING")
    rows = mapping.get("items")
    if type(rows) is not list or len(rows) != 189 or type(raw_key) is not str:
        return fail("RAW_KEY_NOT_EXACTLY_MAPPED")
    matches = [row for row in rows if row["rawGameKeyCandidate"] == raw_key]
    if len(matches) != 1:
        return fail("RAW_KEY_NOT_EXACTLY_MAPPED")
    if type(game_meta) is not dict:
        return fail("GAME_CATALOG_METADATA_MISSING")
    row = matches[0]
    name = game_meta.get("ItemName", game_meta.get("Name"))
    if type(name) is not str or _label(name) != _label(row["expectedGameName"]):
        return fail("LIVE_GAME_NAME_DIFFERENT_FROM_HISTORICAL_KEY")
    if (game_meta.get("ItemType") != row["gameItemType"] or
            game_meta.get("Rarity") != row["gameRarity"] or
            game_meta.get("Chroma", False) is not row["gameChroma"]):
        return fail("LIVE_GAME_TYPE_RARITY_OR_VARIANT_CONFLICT")
    if (game_meta.get("Tradable") is False or game_meta.get("CanTrade") is False or
            game_meta.get("Untradable") is True or game_meta.get("NonTradable") is True or
            game_meta.get("EvoBaseID") is not None or game_meta.get("EvoIndex") is not None):
        return fail("GAME_ITEM_EXPLICITLY_INELIGIBLE")
    return {"status": "LOCAL_METADATA_MATCH_RESEARCH_ONLY",
            "rawGameKeyCandidate": raw_key,
            "marketSlug": row["marketSlug"], "gameChroma": row["gameChroma"],
            "gameRarity": row["gameRarity"], "marketEdition": mapping["marketEdition"],
            **PROVENANCE}
