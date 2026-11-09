"""Stage71: evidence-only name bridge, never a verified live pricing crosswalk.

Cross-check a pinned *historical* MM2 Sync.Item.lua raw catalog entry with a
pinned Supreme snapshot's canonical sourceName, page and variant. The numeric
Supreme checker ID is SITE-SPECIFIC and is NOT a game raw weapon ID.

Neither archival client metadata nor a matched public name authenticates the
current Roblox server inventory. No calls to MM2, Discord, market/trading or
connected services. Do not export any player's inventory raw keys.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re

SCHEMA="gingerscope-stage71-archival-game-public-name-evidence-v1"
CATALOG_BLOB="b0661d54893f681777ebd3eae50d0a4ebe9a46e3"
SUPREME_BLOB="955e3fb7cd25999fc4f0aad4a77378b9a7bb9ba3"
GAME_SOURCE="tlredz/decompiledGames v1456 ReplicatedStorage/Database/Sync/Item.lua"
# These are public archived game-CATALOG keys, not user inventory data.
# Every item is independently checked in the real source, not manufactured.
RESEARCH_TARGETS=(
    "Gingerscope", "Candleflame", "CandleflameChroma",
    "TreeGun2023", "TreeGun2023Chroma", "Darkshot",
)
# Deliberately do NOT add fresh 2026 releases to this archived evidence.
UNAVAILABLE_IN_ARCHIVE=("Emberbow", "Emberscythe", "Mortal", "Immortal")

def blob_sha(content: bytes) -> str:
    return hashlib.sha1(b"blob "+str(len(content)).encode()+b"\0"+content).hexdigest()

def _result(status: str, reason: str, *, checked=0, corroborated=0, skipped=0):
    return {
        "schema": SCHEMA,
        "status": status,
        "reason": reason,
        "archiveMetadataProvenance": GAME_SOURCE,
        "archiveBlobPinned": status=="ARCHIVED_CATALOG_SOURCE_NAME_MATCH_ONLY",
        "supremeSnapshotBlobPinned": status=="ARCHIVED_CATALOG_SOURCE_NAME_MATCH_ONLY",
        "archivedPublicCatalogEntriesChecked": checked,
        "historicalPublicNameMatches": corroborated,
        "unsupportedModernItems": skipped,
        "sourceStatus": "HISTORICAL_ARCHIVE_NOT_CURRENT_GAME_SERVER",
        "supremePriceStatus": "HISTORICAL_RESEARCH_SNAPSHOT_NOT_LIVE",
        "sourceNameMatchIsRawCheckerIdAuthentication": False,
        "numericSupremeCheckerIdProvenByGame": False,
        "currentGameCatalogAuthenticated": False,
        "currentUserInventoryRead": False,
        "mayProvideIndicativeResearchOnly": False,
        "mayMarkWeaponValueVerified": False,
        "mayRecordCompletedTrade": False,
        "mayRecordRejectedTrade": False,
        "mayUseForStrategyLearning": False,
        "mayReportProfit": False,
        "authorizesAccept": False,
        "authorizesTrade": False,
    }

def _extract_entry(catalog: str, raw: str) -> dict:
    # Catalog is verified against an exact pinned Git blob before parsing.
    escaped=re.escape(raw)
    pattern=(r"(?m)^\t"+escaped+r"\s*=\s*\{"
             r"([\s\S]*?)^\t\},?")
    found=list(re.finditer(pattern,catalog))
    if len(found)!=1:
        raise ValueError("missing or ambiguous archived catalog key")
    body=found[0].group(1)
    properties={}
    for field in ("ItemName","ItemType","Rarity","Chroma","ItemID"):
        a=list(re.finditer(
            r"(?m)^\t\t"+field+r"\s*=\s*"
            r"(\"[^\"\n]*\"|\d+|true|false)\s*,?\s*$",body))
        if len(a)>1:
            raise ValueError("duplicate direct archived field")
        if a:
            v=a[0].group(1)
            properties[field]=(v[1:-1] if v.startswith('"') else
                               v=="true" if v in ("true","false") else
                               int(v))
    for key in ("ItemName","ItemType","Rarity","ItemID"):
        if key not in properties:
            raise ValueError("archived item missing expected direct properties")
    if properties["Chroma"] if "Chroma" in properties else False:
        if properties["Rarity"]!="Godly":
            raise ValueError("unusual chroma rarity")
    if not isinstance(properties["ItemID"],int) or properties["ItemID"]<=0:
        raise ValueError("archived item asset ID invalid")
    return properties

def _expected_page(item:dict) -> tuple[str,str]:
    chroma=item.get("Chroma") is True
    rarity=item["Rarity"]
    name=item["ItemName"]
    if not isinstance(name,str) or not name.strip() or not isinstance(rarity,str):
        raise ValueError("archived catalogue label invalid")
    if item["ItemType"] not in ("Gun","Knife"):
        raise ValueError("nontradeable archived item type")
    if chroma:
        page="chroma"
        name="Chroma "+name
    elif rarity=="Ancient":
        page="ancient"
    elif rarity=="Godly":
        page="godly"
    else:
        raise ValueError("archived rarity outside eligible classes")
    return page,name

def evaluate(catalog_bytes: bytes, snapshot_bytes: bytes) -> dict:
    if not isinstance(catalog_bytes,bytes) or not isinstance(snapshot_bytes,bytes):
        return _result("INCONCLUSIVE","MISSING_BYTES")
    if blob_sha(catalog_bytes)!=CATALOG_BLOB:
        return _result("INCONCLUSIVE","ARCHIVED_GAME_CATALOG_BLOB_MISMATCH")
    if blob_sha(snapshot_bytes)!=SUPREME_BLOB:
        return _result("INCONCLUSIVE","SUPREME_CANONICAL_BLOB_MISMATCH")
    try:
        archive=catalog_bytes.decode("utf-8")
        snapshot=json.loads(snapshot_bytes)
        if (snapshot.get("schemaVersion") != 1 or
            len(snapshot.get("rows",[]))!=190):
            raise ValueError("snapshot coverage mismatch")
        rows=snapshot["rows"]
        canonical={}
        numeric_ids=set()
        for x in rows:
            name=x["sourceName"]
            page=x["page"]
            key=(page,name)
            if (not isinstance(name,str) or not name or
                page not in ("ancient","godly","chroma") or
                key in canonical or
                (page,x["id"]) in numeric_ids):
                raise ValueError("duplicate or invalid supreme canonical rows")
            canonical[key]=x
            numeric_ids.add((page,x["id"]))
        count=0
        for raw in RESEARCH_TARGETS:
            item=_extract_entry(archive,raw)
            target=_expected_page(item)
            if target not in canonical:
                raise ValueError("catalog name/category/variant does not match source")
            candidate=canonical[target]
            # This is a site checker index, NOT an MM2 ItemID. Deliberately
            # do not compare any two ID fields or report an ID conversion.
            if candidate["verified"] is not True:
                raise ValueError("supreme item row shape not source-verified")
            count+=1
        for missing in UNAVAILABLE_IN_ARCHIVE:
            if re.search(r"(?m)^\t"+re.escape(missing)+r"\s*=",archive):
                raise ValueError("archive unexpectedly includes 2026 item")
    except (UnicodeDecodeError,ValueError,TypeError,KeyError,AttributeError,
            json.JSONDecodeError):
        return _result("INCONCLUSIVE","CROSS_SOURCE_IDENTITY_NOT_UNAMBIGUOUS")
    return _result("ARCHIVED_CATALOG_SOURCE_NAME_MATCH_ONLY",
                   "public-name-variant-correspondence-is-not-numeric-id-attestation",
                   checked=count,corroborated=count,skipped=len(UNAVAILABLE_IN_ARCHIVE))

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--archived-catalog",type=Path,required=True)
    ap.add_argument("--supreme-snapshot",type=Path,required=True)
    args=ap.parse_args()
    result=evaluate(args.archived_catalog.read_bytes(),
                    args.supreme_snapshot.read_bytes())
    print(json.dumps(result,sort_keys=True))
    if result["status"]!="ARCHIVED_CATALOG_SOURCE_NAME_MATCH_ONLY":
        raise SystemExit(2)

if __name__=="__main__":
    main()
