"""Stage102 tests: 189 real Stage94 source rows + original Stage9/Stage98 Lua.

CI downloads all 15 original files, reconstructs exact Stage94/101 bytes,
then executes the production-pure Lua preview on those genuine 189 values.
No Roblox client or current quotes involved.
"""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

from pdiddler.intelligence_lab.stage102_export_public_reference import (
    build,encode,OUTPUT
)

LUA=Path("pdiddler/tests/test_stage102_lua_public_reference_preview.lua")
ENGINE=Path("pdiddler/intelligence_lab/stage102_lua_public_reference_preview.lua")
EXPECTED_SOURCE_SHA="6eafa73001f59f41d07e6fee6959be38dabd8b2d43e690ede30852f9b0ee532a"
FLAGS=("currentPricesVerified","priceForTradeVerified","authorizesTrade",
       "authorizesAccept","mayReportProfit","serverCompletionProven")

def lua_str(s:str)->str:
    # UTF-8 string literal; JSON "\\u" sequences are not supported in Lua.
    return json.dumps(s,ensure_ascii=False).replace("\u2028","\\226\\128\\168").replace("\u2029","\\226\\128\\169")

def as_lua(obj:object)->str:
    if obj is None: return "nil"
    if type(obj) is bool: return "true" if obj else "false"
    if type(obj) is int: return str(obj)
    if type(obj) is str: return lua_str(obj)
    if type(obj) is list:
        return "{"+",".join(as_lua(x) for x in obj)+"}"
    if type(obj) is dict:
        return "{"+",".join("["+lua_str(str(k))+"]="+as_lua(v)
                            for k,v in sorted(obj.items()))+"}"
    raise TypeError(type(obj))

class OriginalStage102Lua(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if os.getenv("STAGE102_REQUIRE_PINNED")!="1":
            raise unittest.SkipTest("Original Stage94 source pins required by Stage102 workflow")
        for k in ("STAGE102_ORIGINAL_STAGE9","STAGE102_ORIGINAL_STAGE98"):
            assert Path(os.environ[k]).is_file()
        cls.archive=build()
        cls.encoded=encode(cls.archive)

    def test_original_189_archive_export_is_deterministic_no_raw_keys(self):
        x=self.archive
        self.assertEqual(x["entryCount"],189)
        self.assertEqual(x["originalJoinedRowsSha256"],EXPECTED_SOURCE_SHA)
        self.assertEqual(len(x["rows"]),189)
        self.assertEqual(
            {k:sum(row["category"]==k for row in x["rows"])
             for k in ("ancient","godly","chroma")},
            {"ancient":15,"godly":128,"chroma":46})
        for k in FLAGS:
            self.assertIs(x[k],False)
        for r in x["rows"]:
            self.assertEqual(set(r),{"label","category","chroma",
                                     "value","demand","stability"})
            self.assertIs(type(r["value"]),int)
        self.assertEqual(self.encoded,encode(build()))
        self.assertLess(len(self.encoded),52000)
        if OUTPUT.exists():
            self.assertEqual(OUTPUT.read_bytes(),self.encoded)

    def test_actual_original_lua_and_full_archive_15_groups(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/"original189.lua"
            p.write_text("return "+as_lua(self.archive)+"\n",encoding="utf-8")
            env=os.environ.copy()
            env["STAGE102_ARCHIVE_LUA"]=str(p)
            for q in (p,ENGINE,LUA):
                t=subprocess.run(["luac5.4","-p",str(q)],
                    capture_output=True,text=True,timeout=10)
                self.assertEqual(t.returncode,0,t.stderr+t.stdout)
            t=subprocess.run(["lua5.4",str(LUA)],
                capture_output=True,text=True,env=env,timeout=45)
            self.assertEqual(t.returncode,0,t.stdout+"\n"+t.stderr)
            lines=[z for z in t.stdout.splitlines() if z.startswith("PASS Stage102 ")]
            self.assertEqual(len(lines),15,t.stdout)
            self.assertIn("STAGE102_FULL_ARCHIVE_LUA_TEST_PASS groups=15",t.stdout)

    def test_no_remote_or_accept_path_in_pure_lua_engine(self):
        s=ENGINE.read_text()
        for required in ("currentPricesVerified=false","authorizesAccept=false",
                         "protectedGingerscopeCandidateVisible",
                         "ARCHIVED_RESEARCH_CAPTURE_EXPIRED",
                         "ORIGINAL_STAGE94_PUBLIC_RESEARCH_ONLY",
                         "NAME_ONLY_NOT_RAW_KEY_BOUND",
                         "UNIQUE_PUBLIC_NAME_VARIANT_CANDIDATE",
                         "liquidity=\"UNVERIFIED\""):
            self.assertIn(required,s)
        for forbidden in ("FireServer(","InvokeServer(","HttpGet(",
                          "game:GetService(","VirtualInputManager",
                          "AcceptTrade(","DeclineTrade(","PostAsync(",
                          "TeleportService","getconnections("):
            self.assertNotIn(forbidden,s)

if __name__=="__main__":
    unittest.main()
