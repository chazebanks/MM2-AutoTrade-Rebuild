"""Offline-only fail-closed auditor for exact C9 Supreme five-stage source pins.

No game interactions or mutable GitHub "latest" retrieval. The runtime keeps
its existing immutable fetches; this registry is for reviews and CI only.
Run: python3 -m pdiddler.ci.supreme_c9_pin_audit
For a live device-readiness gate (will currently fail due to expired data):
     python3 -m pdiddler.ci.supreme_c9_pin_audit --require-fresh
"""
from __future__ import annotations

import argparse
from collections import Counter
from copy import deepcopy
from datetime import datetime, timezone, timedelta
import hashlib
import json
from pathlib import Path
import re
import sys

PDIDDLER = Path(__file__).resolve().parents[1]
REGISTRY = PDIDDLER / "system2/SUPREME_ONLY_C9_SOURCE_PIN_REGISTRY_2026_11_17.json"
HEX40 = re.compile(r"[0-9a-f]{40}\Z")
HEX64 = re.compile(r"[0-9a-f]{64}\Z")
DIRECT = re.compile(
    r'local\s+(\w+)\s*=\s*loadFrozen\(\s*"([0-9a-f]+)"\s*,\s*"([^"]+)"'
)
HOST_PATH = "pdiddler/supervised/STAGE119_C9_SUPREME_ONLY_FIVE_SCENARIO_CLEAN_NATIVE.lua"
START_PATH = "pdiddler/supervised/STAGE119_C9_SUPREME_ONLY_FIVE_SCENARIO_CLEAN_START.lua"
CATALOG_PATH = "pdiddler/system2/supreme_only_189_research_catalog_2026_11_17_214118z_refresh.json"

class PinAuditError(ValueError):
    """Fail-closed mismatched/ambiguous/bad source version."""

def check(condition: bool, reason: str) -> None:
    if not condition:
        raise PinAuditError(reason)

def load_manifest(path: Path=REGISTRY) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))

def git_blob(data: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(data)).encode("ascii") + b"\0" + data).hexdigest()

def sha40(value, reason: str) -> None:
    check(isinstance(value, str) and HEX40.fullmatch(value) is not None, reason)

def source_path(path: str) -> Path:
    check(isinstance(path, str) and path.startswith("pdiddler/") and
          ".." not in Path(path).parts and "\\" not in path and
          "//" not in path and "?" not in path and "#" not in path and
          re.fullmatch(r"pdiddler/[a-zA-Z0-9_./-]+", path) is not None,
          "SOURCE_PATH_INVALID")
    return PDIDDLER.parent / path

def checked_bytes(path: str) -> bytes:
    p=source_path(path)
    check(p.is_file(), "SOURCE_FILE_MISSING:" + path)
    return p.read_bytes()

def verify(manifest: dict, files: dict[str, str]|None=None) -> dict:
    """Verify *all* discovered pins, source evidence, time metadata, policy.

    files optional: injected source for adversarial Python tests only.
    No side effects or live Roblox APIs.
    """
    check(isinstance(manifest, dict), "MANIFEST_MISSING")
    check(manifest.get("schema")=="gingerscope-system2-c9-immutable-source-pin-audit-v1",
          "MANIFEST_SCHEMA_INVALID")
    check(manifest.get("repository")=="chazebanks/MM2-AutoTrade-Rebuild",
          "WRONG_IMMUTABLE_REPOSITORY")
    check(manifest.get("purpose")=="OFFLINE_AUDIT_ONLY_NO_RUNTIME_IMPORT_OR_NEW_FETCH",
          "REGISTRY_MUST_NEVER_BE_RUNTIME_AUTHORITY")
    policy=manifest.get("policy")
    check(isinstance(policy,dict) and policy.get("source")=="SUPREME_ONLY" and
          policy.get("researchOnly") is True and
          policy.get("automaticOffers") is False and
          policy.get("finalAccept") is False and
          policy.get("neverOutgoing")=="Gingerscope",
          "STRATEGY_PERMISSION_OR_PUBLISHER_DRIFT")

    launcher=manifest.get("launcher")
    host=manifest.get("protectedHost")
    check(isinstance(launcher,dict) and isinstance(host,dict), "HOST_OR_LOADER_MISSING")
    check(launcher.get("path")==START_PATH and host.get("path")==HOST_PATH,
          "HOST_OR_LOADER_REPOINTED")
    for role,entry in (("LOADER",launcher),("HOST",host)):
        sha40(entry.get("revision"),role+"_REVISION_NOT_EXACT_40")
        sha40(entry.get("blob"),role+"_BLOB_NOT_EXACT_40")
        check(git_blob(checked_bytes(entry["path"]))==entry["blob"],
              role+"_LOCAL_SOURCE_BLOB_DRIFT")

    def read_source(path: str) -> str:
        if files is not None and path in files:
            return files[path]
        return checked_bytes(path).decode("utf-8")

    # Only the *explicit* injected fixture may override source bytes, not the
    # original manifest blob check above. CI mutation tests may rewrite
    # manifest blob fields to match a fake file; production never does this.
    starter=read_source(START_PATH)
    code=read_source(HOST_PATH)
    check(starter.count('local pinned="')==1 and
          starter.count('local path="pdiddler/')==1,
          "STARTUP_PIN_LAYOUT_AMBIGUOUS")
    launch_pin=re.search(r'local pinned="([^"]+)"',starter)
    launch_path=re.search(r'local path="([^"]+)"',starter)
    check(launch_pin is not None and launch_path is not None and
          launch_pin.group(1)==host["revision"] and
          launch_path.group(1)==HOST_PATH,
          "LAUNCHER_HOST_SOURCE_PIN_MISMATCH")
    check(starter.count("raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/")==1 and
          code.count("raw.githubusercontent.com/chazebanks/MM2-AutoTrade-Rebuild/")==2,
          "PUBLIC_SOURCE_ORIGIN_DRIFT")
    check("main/" not in starter and "/latest/" not in starter,
          "MUTABLE_SOURCE_VERSION_NOT_ALLOWED")

    # Validate ALL literal loadFrozen(...) references, including attempts
    # to sneak in a mutable branch name that HEX-only extraction would miss.
    literals=re.findall(
        r'local\s+(\w+)\s*=\s*loadFrozen\(\s*"([^"]+)"\s*,\s*"([^"]+)"',
        code,
    )
    check(len(literals)==14,"DIRECT_FROZEN_DEPENDENCY_COUNT_DRIFT")
    actual=[{"symbol":a,"commit":b,"path":"pdiddler/"+c}
            for a,b,c in DIRECT.findall(code)]
    expected=manifest.get("directFrozenModules")
    check(isinstance(expected,list) and len(expected)==14 and len(actual)==14,
          "DIRECT_FROZEN_DEPENDENCY_COUNT_DRIFT")
    check(len({x["symbol"] for x in actual})==len(actual),
          "DUPLICATE_MODULE_SYMBOL")
    check(len({x["symbol"] for x in expected if isinstance(x,dict)})==len(expected),
          "DUPLICATE_MANIFEST_MODULE_SYMBOL")
    for item in expected:
        check(isinstance(item,dict) and set(item)=={"symbol","commit","path"},
              "DIRECT_MANIFEST_ENTRY_MALFORMED")
        check(isinstance(item["symbol"],str) and
              re.fullmatch("[A-Za-z_][A-Za-z_0-9]*",item["symbol"]) is not None,
              "DIRECT_MANIFEST_SYMBOL_INVALID")
        sha40(item["commit"],"DIRECT_MODULE_COMMIT_ABBREVIATED_OR_INVALID")
        source_path(item["path"])
    for item in actual:
        sha40(item["commit"],"RUNTIME_DIRECT_COMMIT_ABBREVIATED_OR_INVALID")
        source_path(item["path"])
    check(actual==expected,"RUNTIME_DIRECT_SOURCE_PIN_MISMATCH")
    check(len(set((x["commit"],x["path"]) for x in actual))==14,
          "DUPLICATE_DIRECT_SOURCE_ENTRY")

    groups=manifest.get("dynamicFrozenGroups")
    check(isinstance(groups,list) and len(groups)==2 and
          [x.get("group") for x in groups]==["supremeResearch","fiveScenario"],
          "DYNAMIC_GROUP_SET_DRIFT")
    all_dyn=[]
    for group in groups:
        commit=group.get("commit")
        symbol=group.get("hostLocal")
        count=group.get("occurrences")
        sha40(commit,"DYNAMIC_COMMIT_ABBREVIATED_OR_INVALID")
        check(symbol in ("pin","recorderPin") and
              count==(2 if symbol=="pin" else 1), "DYNAMIC_PIN_GROUP_SHAPE_INVALID")
        hits=re.findall(r'local '+symbol+r'="([^"]+)"',code)
        check(len(hits)==count and all(x==commit for x in hits),
              "DYNAMIC_RUNTIME_PIN_MISMATCH")
        refs=group.get("files")
        check(isinstance(refs,list) and
              len(refs)==(7 if symbol=="pin" else 1),
              "DYNAMIC_GROUP_FILE_COUNT_DRIFT")
        for item in refs:
            check(isinstance(item,dict) and set(item)=={"role","path"} and
                  isinstance(item["role"],str) and item["role"] and
                  isinstance(item["path"],str),
                  "DYNAMIC_MODULE_DESCRIPTOR_INVALID")
            source_path(item["path"])
            all_dyn.append((group["group"],item["role"],item["path"]))
    check(len(all_dyn)==len(set((g,role) for g,role,_ in all_dyn)),
          "DUPLICATE_DYNAMIC_ROLE")
    by_role={role:path for _,role,path in all_dyn}
    expected_roles={
       "sha256":"pdiddler/system2/native_sha256_rfc6234_readonly.lua",
       "supremeCore":"pdiddler/system2/native_supreme_only_bilateral_research_nov17.lua",
       "protectedBridge":"pdiddler/system2/native_supreme_only_protected_c3p4_adapter_nov17.lua",
       "captureAdapter":"pdiddler/system2/native_market_offer_client_capture.lua",
       "previewButton":"pdiddler/system2/native_supreme_only_current_offer_button.lua",
       "previewCapture":"pdiddler/system2/native_market_offer_client_capture.lua",
       "publisherCatalog":CATALOG_PATH,
       "recorder":"pdiddler/system2/native_supreme_only_five_scenario_recorder.lua",
    }
    check(by_role==expected_roles,"DYNAMIC_SUPREME_ROLE_REPOINTED")
    for role in ("sha256","supremeCore","protectedBridge","captureAdapter"):
        needle=role+'="'+Path(expected_roles[role]).name+'"'
        check(code.count(needle)==1,"DYNAMIC_MODULE_TABLE_CHANGED:"+role)
    for needle in (
        '"system2/native_supreme_only_current_offer_button.lua"',
        '"system2/native_market_offer_client_capture.lua"',
        '"system2/native_supreme_only_five_scenario_recorder.lua"',
        "pin..\"/pdiddler/system2/supreme_only_189_research_catalog_2026_11_17_214118z_refresh.json\"",
    ):
        check(needle in code,"RUNTIME_DYNAMIC_MODULE_PATH_CHANGED:"+needle)
    check("local captureUtc=" in starter and
          "SUPREME_FIVE_TEST_SOURCE_EXPIRED_BEFORE_MANUAL_ARM" in starter and
          "cfg.noAutomaticWeaponOffers~=true" in code and
          "cfg.neverFinalAcceptDuringTest~=true" in code and
          "operatorApprovedManualItemChanges" in starter and
          "SUPREME_ONLY" in code and
          "supervisor.arm({" in code,
          "MANUAL_ONLY_TRADE_GUARD_NOT_FOUND")
    check("OfferItem:FireServer" not in code and
          "AcceptTrade:FireServer" not in code and
          "native_market_inventory_offer_core.lua" not in code,
          "AUTOMATED_TRADE_CONTROL_INTRODUCED")
    for dangerous in ("MM2VALUES","MM2Values","mm2values.com"):
        # Search executable identifiers only; historical comment references
        # aren't trade authority but this C9 path should have none.
        check(dangerous not in starter and dangerous not in code,
              "SECOND_PUBLISHER_IMPORTED")

    blobs=manifest.get("immutableBlobs")
    check(isinstance(blobs,dict) and len(blobs)==4,"SOURCE_BLOB_SET_DRIFT")
    for path,sha in blobs.items():
        sha40(sha,"IMMUTABLE_BLOB_INVALID")
        check(git_blob(checked_bytes(path))==sha,"IMMUTABLE_BLOB_DRIFT:"+path)

    meta=manifest.get("supremeCatalog")
    check(isinstance(meta,dict) and meta.get("file")==CATALOG_PATH and
          meta.get("maxAgeSeconds")==21600 and
          meta.get("eligibleCounts")=={"ancient":15,"godly":128,"chroma":46} and
          meta.get("rawInstanceIdentityVerified") is False and
          meta.get("publisherSigned") is False and
          meta.get("liveTradePricingAuthorized") is False,
          "SUPREME_SOURCE_METADATA_OR_AUTHORITY_DRIFT")
    check(isinstance(meta.get("sha256"),str) and HEX64.fullmatch(meta["sha256"]),
          "SUPREME_SHA256_INVALID")
    catalog_bytes=checked_bytes(CATALOG_PATH)
    check(hashlib.sha256(catalog_bytes).hexdigest()==meta["sha256"],
          "SUPREME_CATALOG_CONTENT_SHA256_DRIFT")
    catalog=json.loads(catalog_bytes)
    check(catalog.get("valueSource")=="SUPREME_ONLY" and
          catalog.get("sourceCapturedUtc")==meta.get("capturedUtc") and
          catalog.get("publisherUpdatedAt")==meta.get("publisherEdition") and
          catalog.get("categories")==meta.get("eligibleCounts") and
          catalog.get("reviewedHistoricalRawGameKeyCandidates")==189 and
          catalog.get("publisherSigned") is False and
          catalog.get("liveTradePricingAuthorized") is False and
          catalog.get("authorizesTrade") is False and
          catalog.get("authorizesOffer") is False and
          catalog.get("authorizesAccept") is False and
          catalog.get("mayUseForStrategyLearning") is False,
          "CATALOG_SOURCE_OR_PERMISSION_MISMATCH")
    rows=catalog.get("rows")
    check(isinstance(rows,list) and len(rows)==189 and
          len({r["rawGameKeyCandidate"] for r in rows})==189,
          "SUPREME_CATALOG_COUNT_OR_RAW_KEY_COLLISION")
    counts=Counter(r["category"] for r in rows)
    check(dict(counts)==meta["eligibleCounts"],
          "SUPREME_CATALOG_CATEGORY_MISMATCH")
    bridge_text=checked_bytes(
        "pdiddler/system2/native_supreme_only_protected_c3p4_adapter_nov17.lua"
    ).decode("utf-8")
    check('local CATALOG_SHA256="'+meta["sha256"]+'"' in bridge_text,
          "SUPREME_BRIDGE_SHA256_SOURCE_MISMATCH")
    check('local captureUtc='+str(int(
         datetime.fromisoformat(meta["capturedUtc"].replace("Z","+00:00")).timestamp()
    )) in starter,
          "LAUNCHER_CLOCK_NOT_LINKED_TO_CATALOG")
    try:
        captured=datetime.fromisoformat(meta["capturedUtc"].replace("Z","+00:00"))
        expires=datetime.fromisoformat(meta["absoluteExpiresUtc"].replace("Z","+00:00"))
        published=datetime.fromisoformat(meta["publisherEdition"])
    except (TypeError,ValueError) as exc:
        raise PinAuditError("SOURCE_DATE_INVALID") from exc
    check(captured.utcoffset()==timedelta(0) and
          expires.utcoffset()==timedelta(0) and
          expires==captured+timedelta(seconds=21600) and
          published<=captured and
          captured.year==2026,
          "SUPREME_SOURCE_CAPTURE_EXPIRY_INVALID")
    return {
        "status":"PIN_REGISTRY_STRUCTURAL_PASS",
        "source":"SUPREME_ONLY",
        "directModules":len(actual),
        "dynamicRoles":len(all_dyn),
        "uniqueDynamicFiles":len(set(x[2] for x in all_dyn)),
        "marketSnapshotExpiresUtc":meta["absoluteExpiresUtc"],
        "mayTrade":False,
        "deviceTestVerified":False
    }

def main(argv: list[str]|None=None) -> int:
    parser=argparse.ArgumentParser()
    parser.add_argument("--require-fresh",action="store_true",
                        help="Fail if genuine Supreme capture 6-hour TTL expired.")
    args=parser.parse_args(argv)
    try:
        manifest=load_manifest()
        receipt=verify(manifest)
        end=datetime.fromisoformat(
            receipt["marketSnapshotExpiresUtc"].replace("Z","+00:00"))
        now=datetime.now(timezone.utc)
        freshness="EXPIRED" if now>end else "WITHIN_CAPTURE_TTL"
        print(json.dumps({**receipt,"marketFreshness":freshness},sort_keys=True))
        if args.require_fresh and freshness!="WITHIN_CAPTURE_TTL":
            print("SOURCE_EXPIRED_RECAPTURE_AND_REPIN_REQUIRED",file=sys.stderr)
            return 3
        return 0
    except (PinAuditError,ValueError,KeyError,TypeError) as exc:
        print("PIN_REGISTRY_BLOCKED: "+str(exc),file=sys.stderr)
        return 2

if __name__=="__main__":
    raise SystemExit(main())
