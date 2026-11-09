"""Stage82: archived *PUBLIC* MM2 raw catalogue key -> Supreme URL slug candidates.

This is not a source of truth for a player's Weapons.Owned, a current game
catalogue, a numeric Supreme checker ID, valuation, completed trades or
automatic trading. Nothing here invokes Roblox, network access, or live scripts.

The five Stage81 source files plus the October18 game db are SHA-pinned.
"""
from __future__ import annotations

from collections import Counter
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import tempfile

SCHEMA = "gingerscope-stage82-pinned-public-game-to-website-slug-candidates-v1"
GAME_BLOB = "2be54c3f5c6b715844728c01a65cc2f24a55c02d"
STAGE77_BLOB = "754fbe3189d5108272c32a27fc52bf3834011d38"
STAGE81_BLOB = "bff17e1c164d7075a975b0a5e1da27ac2d20a2ba"
ROSTER_BLOB = "a85af4f6137278540e1fed0c27e7e801553e4111"
PAGE_BLOBS = {
    "ancient": "7e11a2d835eadbb522d351bdabe393a7c9688f4b",
    "godly": "2e4a0c1b8df894f9037e737ba80919b9b2d0c9ae",
    "chroma": "0d2d156d9d9c499ef0e1213376796c1a916e6ce1",
}
SOURCE_PAGE = {"ancient":"ancients", "godly":"godlies", "chroma":"chromas"}
EXPECTED_ROSTER = {"ancient":16, "godly":128, "chroma":46}
EXPECTED_SITE_SLUGS = {"ancient":15, "godly":128, "chroma":46}
FLAGS = {
    "readOnly": True, "researchOnly": True,
    "sourceScope": "PINNED_HISTORICAL_THIRD_PARTY_GAME_AND_WEBSITE_CAPTURE",
    "actualOwnedInventoryRead": False, "serverAttestation": False,
    "authenticatedOwnedInventory": False,
    "currentGameCatalogueAuthenticated": False,
    "websiteOriginServerAttested": False, "currentPricesVerified": False,
    "sourcePublisherFresh": False, "numericSupremeCheckerIdVerified": False,
    "currentOwnedRawToMarketSlugVerified": False,
    "rawGameToNumericCheckerVerified": False,
    "authorizesTrade": False, "authorizesAccept": False,
    "mayRecordCompletedTrade": False, "mayRecordRejectedTrade": False,
    "mayReportProfit": False, "maySendDiscordWebhook": False,
    "mayUseForStrategyLearning": False, "serverCompletionProven": False,
    "tradeOutcome": "UNKNOWN",
}

def _hash(raw: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(raw)).encode("ascii") + b"\0" + raw).hexdigest()

def report(status: str, reason: str, **fields) -> dict:
    return {"schema": SCHEMA, "status": status, "reason": reason, **FLAGS, **fields}

def _pinned_module(raw: bytes, sha: str, filename: str):
    if type(raw) is not bytes or _hash(raw) != sha:
        raise ValueError("reviewed parser source hash mismatch")
    # Load only OWN, exact hash pinned and previously CI-reviewed Python source,
    # never HTML, a third-party Lua file or a URL as executable code.
    with tempfile.TemporaryDirectory() as folder:
        path = Path(folder) / filename
        path.write_bytes(raw)
        spec = importlib.util.spec_from_file_location("_pinned_" + filename.replace(".", "_"),path)
        if spec is None or spec.loader is None:
            raise ValueError("pinned module unreadable")
        obj = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(obj)
        return obj

def _game_public_category(meta: dict):
    if not isinstance(meta, dict):
        raise ValueError("public game metadata entry malformed")
    rarity, kind, name = meta.get("Rarity"), meta.get("ItemType"),meta.get("ItemName")
    if rarity not in ("Ancient","Godly") or kind not in ("Knife","Gun"):
        return None
    if not isinstance(name, str) or not name or len(name)>128 or re.search(r"[\x00-\x1f]",name):
        raise ValueError("public game eligible weapon name malformed")
    chroma = meta.get("Chroma",False)
    if type(chroma) is not bool:
        raise ValueError("Chroma marker not boolean")
    if chroma and name.casefold().startswith("chroma "):
        raise ValueError("ambiguous double Chroma prefix")
    page = "chroma" if chroma else rarity.lower()
    label = "Chroma " + name if chroma else name
    return page, label, rarity, kind, chroma

def build(game:bytes, roster:bytes, pages:dict[str,bytes],
          stage77:bytes, stage81:bytes) -> dict:
    """Produce only archival public candidate URLs with explicit DENIED authority."""
    if type(game) is not bytes or type(roster) is not bytes or type(pages) is not dict:
        return report("INCONCLUSIVE","SOURCE_INPUT_INVALID",candidates={})
    if _hash(game)!=GAME_BLOB or _hash(roster)!=ROSTER_BLOB:
        return report("INCONCLUSIVE","GAME_OR_ROSTER_BLOB_CHANGED",candidates={})
    if set(pages)!=set(PAGE_BLOBS) or any(
        type(pages[k]) is not bytes or _hash(pages[k])!=v for k,v in PAGE_BLOBS.items()
    ):
        return report("INCONCLUSIVE","FIRST_PARTY_HTML_BLOB_CHANGED",candidates={})
    if type(stage77) is not bytes or _hash(stage77)!=STAGE77_BLOB:
        return report("INCONCLUSIVE","REVIEWED_HTML_PARSER_BLOB_CHANGED",candidates={})
    if type(stage81) is not bytes or _hash(stage81)!=STAGE81_BLOB:
        return report("INCONCLUSIVE","REVIEWED_SOURCE_AUDIT_BLOB_CHANGED",candidates={})
    try:
        old = _pinned_module(stage77, STAGE77_BLOB, "stage77.py")
        preflight = _pinned_module(stage81, STAGE81_BLOB, "stage81.py")
        stage81_result = preflight.run(roster,pages,stage77)
        if stage81_result.get("status") != "PUBLIC_WEBSITE_SLUG_COVERAGE_CONFIRMED_RESEARCH_ONLY":
            raise ValueError("original Stage81 first-party source preflight failed")
        game_rows = old.game_rows(game)
        if len(game_rows)!=1040:
            raise ValueError("public game catalogue count changed")
        catalog = {}
        eligible_count = 0
        for raw,meta in game_rows.items():
            if not isinstance(raw,str) or not raw or len(raw)>128:
                raise ValueError("game raw key malformed")
            candidate = _game_public_category(meta)
            if candidate is None:
                continue
            eligible_count += 1
            page,label,rarity,kind,chroma = candidate
            compound=(page,label.casefold())
            catalog.setdefault(compound,[]).append(
                {"rawKey":raw,"page":page,"name":label,"rarity":rarity,"kind":kind,"chroma":chroma}
            )
        if eligible_count != 200:
            raise ValueError("public game eligible count changed")
        # Duplicated public labels may be a different item or a source bug.
        # Do not choose a winner by fuzzy score or item art ID.
        if any(len(choices)>1 for choices in catalog.values()):
            raise ValueError("ambiguous public game page/name compound key")
        originals=json.loads(roster)
        roster_rows=originals.get("rows")
        if type(roster_rows) is not list or len(roster_rows)!=190:
            raise ValueError("historical market roster invalid")
        website={}
        for page,html in pages.items():
            records=old.website_records(html,SOURCE_PAGE[page])
            if len(records)!=EXPECTED_SITE_SLUGS[page]:
                raise ValueError("first-party page count changed")
            for slug,(name,base_rarity) in records.items():
                key=(page,name.casefold())
                if key in website:
                    raise ValueError("ambiguous website name within page")
                website[key]={"slug":slug,"name":name,"baseRarity":base_rarity}
        candidates={}
        target_urls=set()
        used_game_keys=set()
        priceless=0
        roster_count=Counter()
        for row in roster_rows:
            if type(row) is not dict:
                raise ValueError("malformed original roster row")
            page,name=row.get("page"),row.get("name")
            if page not in EXPECTED_ROSTER or not isinstance(name,str) or not name:
                raise ValueError("original market name/category invalid")
            roster_count[page]+=1
            key=(page,name.casefold())
            possible=catalog.get(key,[])
            if len(possible)!=1:
                raise ValueError("game-to-roster public name ambiguous or absent")
            weapon=possible[0]
            raw=weapon["rawKey"]
            if raw in used_game_keys:
                raise ValueError("one game item maps to duplicate market identities")
            used_game_keys.add(raw)
            if page=="ancient" and name=="Nik's Scythe":
                if row.get("supremeValue") is not None or key in website:
                    raise ValueError("priceless Nik no-URL exception changed")
                priceless+=1
                continue
            site=website.get(key)
            if site is None:
                raise ValueError("unique official website page/slug absent")
            # Chroma Ancient vs Godly is part of identity, not an alias.
            if site["baseRarity"]!=weapon["rarity"]:
                raise ValueError("Chroma/base rarity disagrees between original public sources")
            url=f"https://supremevalues.com/mm2/{SOURCE_PAGE[page]}?item={site['slug']}"
            if url in target_urls or raw in candidates:
                raise ValueError("duplicate public URL or game key")
            target_urls.add(url)
            candidates[raw]={
                "page":page,"displayName":site["name"],"slug":site["slug"],
                "url":url, "gameItemType":weapon["kind"],
                "gameRarity":weapon["rarity"],"gameChroma":weapon["chroma"],
                "identityEvidence":"HISTORICAL_PUBLIC_NAME_CATEGORY_VARIANT_CORRESPONDENCE_ONLY",
                "priceForTradeVerified":False,
                "currentOwnedRawKeyVerified":False,
            }
        if dict(roster_count)!=EXPECTED_ROSTER or len(candidates)!=189 or priceless!=1:
            raise ValueError("original canonical 190-to-189 source partition invalid")
        game_only_keys=set(raw for group in catalog.values() for raw in
                           (entry["rawKey"] for entry in group)) - used_game_keys
        if len(game_only_keys)!=10 or len(catalog)!=200 or len(target_urls)!=189:
            raise ValueError("game public eligible-only remainder not exactly ten")
    except (ValueError,TypeError,KeyError,UnicodeError,ImportError,
            json.JSONDecodeError,OverflowError,RecursionError,AttributeError):
        return report("INCONCLUSIVE","ARCHIVED_PUBLIC_IDENTITY_JOIN_UNREVIEWED",candidates={})
    return report(
        "PUBLIC_GAME_KEY_TO_WEBSITE_SLUG_CANDIDATES_ONLY",
        "NO_AUTHENTICATED_OWNED_KEY_NUMERIC_CHECKER_OR_FRESH_PRICE",
        candidates=candidates,
        matchingPublicGameWeaponKeys=len(candidates),
        eligiblePublicGameKeys=eligible_count,
        publicGameKeysAbsentFromOldSupremeRoster=len(game_only_keys),
        pricelessNoOfficialSlug=priceless,
        pageCounts={p:sum(x["page"]==p for x in candidates.values())
                    for p in ("ancient","godly","chroma")},
        sourcePublisherExpiryUtc=stage81_result["hardPublisherExpiryUtc"],
        historicalWebsiteAgeExpired=stage81_result["publisherOlderThan72Hours"],
    )

def lookup_public_candidate(report_object:object, raw_key:object)->dict:
    """No caller metadata, checker ID, alias, fuzzy match, or price can promote proof."""
    if type(raw_key) is not str or not raw_key or len(raw_key)>128:
        return report("INCONCLUSIVE","RAW_PUBLIC_KEY_MUST_BE_EXACT_STRING")
    if type(report_object) is not dict or report_object.get("status")!=(
        "PUBLIC_GAME_KEY_TO_WEBSITE_SLUG_CANDIDATES_ONLY"
    ) or report_object.get("readOnly") is not True or report_object.get("researchOnly") is not True:
        return report("INCONCLUSIVE","UNREVIEWED_REGISTRY")
    # Supplied registry is not an authenticated proof. Lookup is a display-only
    # public correspondence, even if caller falsely inserts verified=true.
    candidates=report_object.get("candidates")
    if type(candidates) is not dict or len(candidates)!=189:
        return report("INCONCLUSIVE","INCOMPLETE_REGISTRY")
    matched=candidates.get(raw_key)
    if type(matched) is not dict or matched.get("currentOwnedRawKeyVerified") is not False or (
        matched.get("priceForTradeVerified") is not False
    ):
        return report("UNMAPPED_PUBLIC_KEY","NO_REVIEWED_SOURCE_CORRESPONDENCE")
    # Validate exact first-party URL form even against forged caller objects.
    # A forged caller can still invent a public reference; this is NEVER
    # authorization or authentication, including when this check succeeds.
    page,slug,url=matched.get("page"),matched.get("slug"),matched.get("url")
    name,kind,rarity,chroma=(matched.get("displayName"),
                            matched.get("gameItemType"),
                            matched.get("gameRarity"),
                            matched.get("gameChroma"))
    if (page not in SOURCE_PAGE or type(slug) is not str or
        re.fullmatch(r"[A-Za-z0-9_'-]+",slug) is None or
        url!=f"https://supremevalues.com/mm2/{SOURCE_PAGE[page]}?item={slug}" or
        type(name) is not str or not name or len(name)>128 or
        kind not in ("Knife","Gun") or rarity not in ("Ancient","Godly") or
        type(chroma) is not bool or
        page!=("chroma" if chroma else rarity.lower()) or
        (chroma and not name.startswith("Chroma "))):
        return report("INCONCLUSIVE","PUBLIC_REFERENCE_FIELDS_MALFORMED")
    # Rebuild only canonical recognized public-reference fields.
    # Historical numeric checkerId, supplied price or verified flags discarded.
    allowed=("page","displayName","slug","url","gameItemType","gameRarity","gameChroma")
    return report("PUBLIC_REFERENCE_LINK_ONLY",
                  "HISTORICAL_WEBSITE_REFERENCE_NOT_CURRENT_TRADE_VALUE",
                  publicReference={key:matched[key] for key in allowed})

