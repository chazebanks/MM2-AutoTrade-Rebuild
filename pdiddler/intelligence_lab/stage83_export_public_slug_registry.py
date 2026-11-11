"""Stage83 deterministic PUBLIC Lua registry compiler from seven SHA-pinned archives.

No user inventory. No prices, numeric checker IDs, webhooks, or live Roblox API.
Checks original Stage82 source digest before using its reviewed source join.
"""
from __future__ import annotations
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile

PIN_STAGE82_GIT_BLOB = "91362b647a8cc630e4fabcf7aa5d65eb44adb399"
SCHEMA = "gingerscope-stage83-public-slug-registry-v1"
PUBLICATION = "2026-11-06T15:56:07Z"
EXPIRY = "2026-11-09T15:56:07Z"

def git_blob(data: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(data)).encode("ascii") + b"\x00" + data).hexdigest()

def checked_source_module(blob: bytes):
    if git_blob(blob) != PIN_STAGE82_GIT_BLOB:
        raise ValueError("STAGE82_REVIEWED_SOURCE_BLOB_MISMATCH")
    # Only our own reviewed byte-exact Python source is imported, never
    # third-party Lua and never a webpage or caller-supplied source.
    with tempfile.TemporaryDirectory() as tmp:
        fn=Path(tmp)/"stage82_checked.py"
        fn.write_bytes(blob)
        spec=importlib.util.spec_from_file_location("stage82_registry_compiler",fn)
        assert spec and spec.loader
        mod=importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        return mod

def _lua_str(value: str) -> str:
    if not isinstance(value,str) or not value or any(ord(x)>126 or ord(x)<32 for x in value):
        raise ValueError("non-ASCII or invalid public literal")
    return json.dumps(value,ensure_ascii=True)

def compile_registry(game: bytes, roster: bytes, sites: dict[str,bytes],
                     stage77: bytes, stage81: bytes, stage82: bytes) -> str:
    builder=checked_source_module(stage82)
    result=builder.build(game,roster,sites,stage77,stage81)
    if result.get("status")!="PUBLIC_GAME_KEY_TO_WEBSITE_SLUG_CANDIDATES_ONLY":
        raise ValueError("STAGE82_PINNED_CANDIDATE_PREFLIGHT_FAILED")
    if result.get("matchingPublicGameWeaponKeys")!=189 or result.get("historicalWebsiteAgeExpired") is not True:
        raise ValueError("UNEXPECTED_PUBLIC_REGISTRY_COVERAGE_OR_FRESHNESS")
    if result.get("sourcePublisherExpiryUtc")!=EXPIRY:
        raise ValueError("UNEXPECTED_PUBLICATION_EXPIRY")
    # independently checked Oct18 game metadata via reviewed Stage77 parser,
    # preserving original game ItemName vs website's display capitalization.
    parser=builder._pinned_module(stage77,builder.STAGE77_BLOB,"stage77_for_83.py")
    source=parser.game_rows(game)
    rows=result["candidates"]
    if len(rows)!=189:
        raise ValueError("PUBLIC_REGISTRY_SIZE_CHANGED")
    out=[
        "-- Stage83 PUBLIC reference candidates only; source publisher expired.",
        "-- Auto-generated from EIGHT verified historical source blobs.",
        "-- Never prices, trading auth, live owned inventory or numeric site checker IDs.",
        "return {",
        '  schema = "'+SCHEMA+'",',
        '  publisherUtc = "'+PUBLICATION+'",',
        '  publisherExpiryUtc = "'+EXPIRY+'",',
        "  currentPricesVerified = false,",
        "  authenticatedOwnedInventory = false,",
        "  authorizesTrade = false,",
        "  authorizesAccept = false,",
        "  mayUseForStrategyLearning = false,",
        "  entries = {",
    ]
    for raw in sorted(rows):
        if raw not in source:
            raise ValueError("SOURCE_RAW_KEY_NOT_IN_ARCHIVE")
        item=source[raw]
        candidate=rows[raw]
        raw_name,kind,rarity=item.get("ItemName"),item.get("ItemType"),item.get("Rarity")
        chroma=item.get("Chroma",False)
        if (not isinstance(chroma,bool) or not isinstance(raw_name,str) or
            candidate["gameItemType"]!=kind or candidate["gameRarity"]!=rarity or
            candidate["gameChroma"] is not chroma):
            raise ValueError("PUBLIC_VARIANT_MISMATCH")
        page,slug=candidate["page"],candidate["slug"]
        if page not in ("ancient","godly","chroma"):
            raise ValueError("INVALID_SOURCE_CATEGORY")
        parts=[_lua_str(raw_name),_lua_str(kind),_lua_str(rarity),
               "true" if chroma else "false",_lua_str(page),_lua_str(slug)]
        out.append("    ["+_lua_str(raw)+"] = {"+", ".join(parts)+"},")
    out.extend(["  },","}",""])
    return "\n".join(out)

def main():
    parser=argparse.ArgumentParser()
    for name in ("game","roster","ancients","godlies","chromas","stage77","stage81","stage82","output"):
        parser.add_argument("--"+name,required=True,type=Path)
    args=parser.parse_args()
    lua=compile_registry(args.game.read_bytes(),args.roster.read_bytes(),
        {"ancient":args.ancients.read_bytes(),"godly":args.godlies.read_bytes(),
         "chroma":args.chromas.read_bytes()},
        args.stage77.read_bytes(),args.stage81.read_bytes(),args.stage82.read_bytes())
    args.output.write_text(lua,encoding="utf-8")
    print("STAGE83_PUBLIC_REGISTRY_COMPILED entries=189 bytes="+str(len(lua.encode("utf-8"))))

if __name__=="__main__":
    main()
