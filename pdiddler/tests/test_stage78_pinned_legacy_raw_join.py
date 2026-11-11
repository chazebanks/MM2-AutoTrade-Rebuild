"""Stage78 source-provenance + actual legacy Lua inventory function reproduction.

Read-only, synthetic profiles only. Prove where the old function erases
numeric/string key types; do NOT confuse this source-level reproduction with
native Roblox data, user identity, market prices, or completed trades.
"""
from __future__ import annotations

import hashlib
import os
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
LEGACY_BLOB = "65137e7e6966784cdb3c6bb3f6cd5adf885a68ba"
REQUIRED = os.environ.get("STAGE78_REQUIRE_PINNED") == "1"
LEGACY_PATH = os.environ.get("STAGE78_LEGACY_SCANNER")

def blob_sha(source: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(source)).encode() + b"\0" + source).hexdigest()

def original_legacy_function(raw: bytes) -> str:
    if blob_sha(raw) != LEGACY_BLOB:
        raise ValueError("ORIGINAL_SCANNER_BLOB_CHANGED")
    text = raw.decode("utf-8")
    required = (
        'indexItems(Sync.Weapons)',
        'indexItems(Sync.Item)',
        'local id=tostring(rawId)',
        'local owned=type(weapons)=="table" and weapons.Owned',
        'local meta=Meta["Weapons|"..id]',
        'out.unmapped+=qty',
    )
    if not all(x in text for x in required):
        raise ValueError("EXPECTED_ORIGINAL_JOIN_STRUCTURE_NOT_FOUND")
    match = re.search(
        r'(local function inventoryFromProfile\(prof\)[\s\S]*?\nend)\n\nlocal function unwrapProfile',
        text,
    )
    if match is None:
        raise ValueError("EXACT_ORIGINAL_FUNCTION_NOT_FOUND")
    fn = match.group(1)
    # Translate ONLY standard Luau augmented assignments to equivalent Lua5.4
    # plain assignments. The SOURCE is Git SHA pinned and never edited in place.
    fn, changed = re.subn(
        r'(?m)^(\s*)(out\.[A-Za-z_][A-Za-z_0-9]*)\s*\+=\s*([^\n]+)$',
        lambda m: f'{m[1]}{m[2]}={m[2]}+({m[3].strip()})',
        fn,
    )
    if changed != 5:
        raise ValueError("UNREVIEWED_LUAU_TO_LUA54_TRANSLATION_COUNT")
    if "+=" in fn:
        raise ValueError("UNSUPPORTED_LUAU_SYNTAX")
    return fn

MOCK_BEGIN = r"""
local Meta={
 ["Weapons|42"]={id="42",name="Synthetic",type="Knife",rarity="Godly",data={}},
 ["Weapons|Gingerscope"]={id="Gingerscope",name="Gingerscope",
    type="Gun",rarity="Ancient",data={}},
}
local function checkerPage(meta) return "godly" end
local function qualifyingMeta(meta) return true end
local function checkerMarket(meta) return nil,"UNVERIFIED" end
local function identityName(meta) return meta.name end
local function metaIdentity(meta) return "UNVERIFIED" end
"""

MOCK_END = r"""
local valid=inventoryFromProfile({Weapons={Owned={Gingerscope=1}}})
assert(valid.rawOwned==1 and valid.unmapped==0 and #valid.items==1)
assert(valid.items[1].id=="Gingerscope" and valid.items[1].name=="Gingerscope")
-- Two DIFFERENT native Lua table keys collapse onto one text ID in legacy code.
local typed=inventoryFromProfile({Weapons={Owned={[42]=1, ["42"]=1}}})
assert(typed.rawOwned==2 and typed.unmapped==0 and #typed.items==2)
assert(typed.items[1].id=="42" and typed.items[2].id=="42")
assert(typed.seen[1]=="42x1" and typed.seen[2]=="42x1")
print("STAGE78_PINNED_LEGACY_TYPED_KEY_COERCION_REPRODUCED")
"""

class Stage78(unittest.TestCase):
    def test_real_pinned_scanner_exact_source_and_extracted_function(self):
        if not LEGACY_PATH:
            if REQUIRED:
                self.fail("Dedicated CI requires original, Git-blob-pinned scanner")
            self.skipTest("Source fixture is required only in dedicated Stage78 CI")
        payload = Path(LEGACY_PATH).read_bytes()
        fn = original_legacy_function(payload)
        self.assertIn('local id=tostring(rawId)', fn)
        self.assertIn('local meta=Meta["Weapons|"..id]', fn)
        self.assertIn("function inventoryFromProfile", fn)

        lua = ROOT / "pdiddler" / "intelligence_lab" / "stage78_strict_owned_raw_catalogue_join.lua"
        self.assertTrue(lua.is_file())
        # Real Lua5.4: compile/run a TRANSLATION of the exact pinned source
        # function (not a manually rewritten duplicate or a web query).
        compiled = subprocess.run(
            ["lua5.4", "-"], input=MOCK_BEGIN + fn + MOCK_END,
            text=True, capture_output=True, cwd=ROOT, check=False, timeout=15,
        )
        self.assertEqual(compiled.returncode, 0, compiled.stderr)
        self.assertIn("COERCION_REPRODUCED", compiled.stdout)

    def test_research_guard_runs_on_real_lua54(self):
        proc = subprocess.run(
            ["lua5.4", "pdiddler/tests/test_stage78_owned_raw_catalogue_join.lua"],
            capture_output=True, text=True, cwd=ROOT, check=False, timeout=15,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("STAGE78_LUA5_4_PASS", proc.stdout)
        self.assertIn("corrupted_inputs=400", proc.stdout)
        self.assertIn("numeric and string raw keys are never collapsed", proc.stdout)

    def test_no_live_apis_or_source_prices(self):
        source = (ROOT / "pdiddler/intelligence_lab/stage78_strict_owned_raw_catalogue_join.lua").read_text()
        executable = "\n".join(line for line in source.splitlines() if not line.lstrip().startswith("--"))
        self.assertNotIn("FireServer(", executable)
        self.assertNotIn("InvokeServer(", executable)
        self.assertNotIn("HttpGet(", executable)
        self.assertNotIn("GetProfileData", executable)
        self.assertNotIn("supremeValue", executable)
        self.assertIn("rawget(catalogue,rawKey)", executable)
        self.assertNotIn("tostring(rawKey)", executable)

if __name__ == "__main__":
    unittest.main()
