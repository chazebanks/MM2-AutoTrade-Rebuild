"""Stage76: strict PUBLIC market slug ↔ PUBLIC game-catalogue names.

Research only. A fan-made market's URL slug is not a Roblox raw weapon key,
item-art ID, or its internal numeric checker index. This module never reads
Roblox inventory, uses prices, opens trades or grants execution authority.
"""
from __future__ import annotations

from urllib.parse import urlsplit, parse_qsl

SCHEMA = "gingerscope-stage76-first-party-slug-crosswalk-v1"
# Four deliberately DIFFERENT website identity cases verified against
# first-party Supreme item pages on 2026-11-09. PUBLIC ONLY; NOT live quotes.
# Client attributes are expected metadata in the pinned Stage75 probe,
# NOT an attested capture of the user's complete owned inventory.
CASES = {
    "Gingerscope": ("Gingerscope", "Gun", "Ancient", False,
                    "ancients", "Gingerscope", "Gingerscope"),
    "EmberscytheChroma": ("Emberscythe", "Knife", "Ancient", True,
                          "chromas", "CEmberscythe", "Chroma Emberscythe"),
    "BattleAxe": ("BattleAxe", "Knife", "Godly", False,
                  "godlies", "Battleaxe", "Battleaxe"),
    "BattleAxe2": ("BattleAxe II", "Knife", "Godly", False,
                   "godlies", "BA2", "Battleaxe II"),
}
FALSE_FLAGS = {
    "readOnly": True,
    "currentGameCatalogueAuthenticated": False,
    "authenticatedOwnedInventory": False,
    "serverAttestation": False,
    "numericSupremeCheckerIdVerified": False,
    "sourcePublisherFresh": False,
    "currentPricesVerified": False,
    "authorizesTrade": False,
    "authorizesAccept": False,
    "mayReportProfit": False,
    "mayRecordCompletedTrade": False,
    "mayRecordRejectedTrade": False,
    "maySendDiscordWebhook": False,
    "mayUseForStrategyLearning": False,
    "tradeOutcome": "UNKNOWN",
}

def _result(status: str, reason: str, matched: int = 0, **stats) -> dict:
    return {"schema": SCHEMA, "status": status, "reason": reason,
            "expected": len(CASES), "matched": matched, **FALSE_FLAGS, **stats}

def _site_url(page: str, slug: str) -> str:
    return f"https://supremevalues.com/mm2/{page}?item={slug}"

def _valid_first_party_url(url: object, page: str, slug: str) -> bool:
    if not isinstance(url, str):
        return False
    try:
        parts = urlsplit(url)
    except ValueError:
        return False
    # Exact canonical hostname/path/query, never www, redirects, fragments,
    # duplicate item parameters, userinfo, additional query keys or HTTP.
    if (parts.scheme != "https" or parts.netloc != "supremevalues.com"
            or parts.path != f"/mm2/{page}" or parts.fragment):
        return False
    pairs = parse_qsl(parts.query, keep_blank_values=True)
    return len(pairs) == 1 and pairs[0] == ("item", slug) and url == _site_url(page, slug)

def audit(client: list[dict], first_party: list[dict]) -> dict:
    """Validate provided public observations against separately reviewed facts.

    Every input can still be caller-supplied; success proves only that it is
    consistent with the frozen research contract, NOT that the data is genuine.
    """
    if not isinstance(client, list) or not isinstance(first_party, list):
        return _result("INCONCLUSIVE", "OBSERVATIONS_UNAVAILABLE")
    if len(client) != len(CASES) or len(first_party) != len(CASES):
        return _result("INCONCLUSIVE", "INCOMPLETE_OR_EXTRA_OBSERVATIONS")
    client_by_key, official_by_key = {}, {}
    for group, by_key in ((client, client_by_key), (first_party, official_by_key)):
        for row in group:
            if not isinstance(row, dict):
                return _result("INCONCLUSIVE", "MALFORMED_OBSERVATION")
            key = row.get("rawKey")
            if not isinstance(key, str) or key not in CASES or key in by_key:
                return _result("INCONCLUSIVE", "DUPLICATE_OR_UNKNOWN_RAW_KEY")
            by_key[key] = row
    used_urls, used_market_names = set(), set()
    matched = 0
    distinct_slugs = 0
    case_exceptions = 0
    for raw, (name, kind, rarity, chroma, page, slug, market_name) in CASES.items():
        observed = client_by_key[raw]
        if (observed.get("ItemName") != name or observed.get("ItemType") != kind
                or observed.get("Rarity") != rarity or type(observed.get("Chroma")) is not bool
                or observed["Chroma"] is not chroma):
            return _result("INCONCLUSIVE", "GAME_CATALOGUE_METADATA_MISMATCH", matched)
        official = official_by_key[raw]
        url = official.get("url")
        if not _valid_first_party_url(url, page, slug):
            return _result("INCONCLUSIVE", "UNREVIEWED_FIRST_PARTY_URL", matched)
        if (official.get("headline") != f"MM2 {market_name} Value & More"
                or official.get("sourceName") != market_name
                or official.get("pageCategory") != page):
            return _result("INCONCLUSIVE", "MARKET_NAME_OR_CATEGORY_MISMATCH", matched)
        # Chroma market category is distinct from the item rarity. Explicitly
        # preserve Ancient Chroma vs Godly Chroma instead of assuming Godly.
        if page == "chromas" and official.get("baseClass") != rarity:
            return _result("INCONCLUSIVE", "CHROMA_BASE_CLASS_MISMATCH", matched)
        if page != "chromas" and official.get("baseClass") not in (None, rarity):
            return _result("INCONCLUSIVE", "MARKET_BASE_CLASS_MISMATCH", matched)
        if url in used_urls or (page, market_name) in used_market_names:
            return _result("INCONCLUSIVE", "NONUNIQUE_MARKET_TARGET", matched)
        used_urls.add(url)
        used_market_names.add((page, market_name))
        if slug != raw:
            distinct_slugs += 1
        if market_name.casefold() == name.casefold() and market_name != name:
            case_exceptions += 1
        matched += 1
    return _result("PUBLIC_NAME_AND_SLUG_CORRESPONDENCE_ONLY",
                   "WEBSITE_SLUG_NOT_GAME_RAW_KEY_OR_NUMERIC_CHECKER_ID",
                   matched, websiteSlugDiffersFromGameRawKey=distinct_slugs,
                   marketNameCaseDiffersFromClient=case_exceptions,
                   provenance="FOUR_FIRST_PARTY_WEB_PAGES_2026_11_09_RESEARCH_ONLY")
