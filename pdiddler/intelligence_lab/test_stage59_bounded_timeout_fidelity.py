"""Stage59 native timeout regression: preserve ORIGINAL Stage32 + Stage29 source.

The Stage59-only 120-second fork MUST be byte-for-byte identical to the
original pinned client observer and inventory ledger after reversing exactly
the known timeout/name/source-pin deltas. The original 30s executable and the
independent 30s post-close freshness guard remain otherwise untouched.
"""
from __future__ import annotations

import hashlib
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
STAGE32=ROOT/"pdiddler/new_part4/STAGE59_RESULT_DELTA_120S_PROBE.lua"
STAGE29=ROOT/"pdiddler/new_part4/STAGE59_POSTCLOSE_LEDGER_120S.lua"
OLD32_GIT_BLOB="3cbe1aedaa9c8601a6e1727331aabf3a206ed1e0"
OLD29_GIT_BLOB="bbb40941ab6fe6ed40c6ce999a0eb40fc7b7576e"
ORIGINAL_STAGE29_SHA="06374ead14ce0b18fb05e55c80c2df6a143bf0ce"
STAGE59_LEDGER_COMMIT="562fb0c453c1711a3fbd6ca294a44797ac359c42"

def blob_sha(s:str)->str:
    raw=s.encode("utf-8")
    return hashlib.sha1(f"blob {len(raw)}\0".encode()+raw).hexdigest()

LUA_DRIVER=r'''
local path=arg[1]
local Ledger=assert(loadfile(path))()
local scoped={session="stage59:local",jobId="opaque",accountId=12,partnerId=21}
local function item(count)
 return {items={{page="godly",checkerId="20",id="anonymous",
  cat="Weapons",type="Knife",qty=count}},
  rawOwned=count,fingerprint="FP_"..count,unmapped=0,badQty=0,unpriced=0}
end
local count=0
local function check(desc,fn)
 local ok,err=pcall(fn)
 if not ok then error(desc..": "..tostring(err)) end
 count=count+1
end
local function simulate(beforeQty,afterQty,delay)
 local s=Ledger.new(scoped,100,{maxBeforeToClose=120,minPostGap=.75,maxPostAge=30})
 assert(s.maxBeforeToClose==120)
 assert(Ledger.before(s,item(beforeQty),110,scoped)=="OBSERVED")
 local closed=Ledger.close(s,"CLOSED_UNKNOWN",110+delay,scoped)
 if delay>120 then
  assert(closed=="INCOMPLETE")
  local result=Ledger.summary(s)
  assert(result.status=="INCOMPLETE")
  assert(result.serverCompletionProven==false)
  assert(result.tradeOutcome=="UNKNOWN")
  return result
 end
 assert(closed=="OBSERVED")
 assert(Ledger.after(s,item(afterQty),111+delay,scoped,2)=="OBSERVED")
 assert(Ledger.after(s,item(afterQty),113+delay,scoped,3)=="ELIGIBLE_DELTA_UNATTRIBUTED")
 local result=Ledger.summary(s)
 assert(result.beforeObserved==true)
 assert(result.windowClosureObserved==true)
 assert(result.postReadbacksObserved==2)
 assert(result.changedEligibleTypes==1)
 assert(result.gainedEligibleCopies==math.max(0,afterQty-beforeQty))
 assert(result.lostEligibleCopies==math.max(0,beforeQty-afterQty))
 assert(result.serverCompletionProven==false)
 assert(result.authorizesAccept==false)
 assert(result.mayRecordCompletedTrade==false)
 assert(result.mayReportProfit==false)
 assert(result.tradeOutcome=="UNKNOWN")
 return result
end
check("115-second donor trade closes normally client-only",function()
 simulate(2,1,115)
end)
check("115-second receiver trade closes normally client-only",function()
 simulate(1,2,115)
end)
check("original 30-second regression boundary no longer prematurely fails",function()
 simulate(1,2,31)
end)
check("exact 120-second boundary observed",function()
 simulate(1,2,120)
end)
check("121-second closure refuses stale attribution",function()
 simulate(1,2,121)
end)
check("no unbounded horizon enabled",function()
 local ok=pcall(Ledger.new,scoped,100,{maxBeforeToClose=121})
 assert(not ok)
end)
check("post-close freshness still capped at 30 seconds",function()
 local s=Ledger.new(scoped,100,{maxBeforeToClose=120,minPostGap=.75,maxPostAge=30})
 assert(Ledger.before(s,item(1),110,scoped)=="OBSERVED")
 assert(Ledger.close(s,"CLOSED_UNKNOWN",220,scoped)=="OBSERVED")
 assert(Ledger.after(s,item(2),251,scoped,2)=="INCOMPLETE")
end)
check("different partner blocked",function()
 local wrong={session="stage59:local",jobId="opaque",accountId=12,partnerId=22}
 local s=Ledger.new(scoped,100,{maxBeforeToClose=120,minPostGap=.75,maxPostAge=30})
 assert(Ledger.before(s,item(1),110,scoped)=="OBSERVED")
 assert(Ledger.close(s,"CLOSED_UNKNOWN",210,wrong)=="INCOMPLETE")
end)
math.randomseed(5909)
for i=1,400 do
 local delay=math.random(0,125)
 local beforeQty=math.random(1,5)
 local afterQty=math.random(1,5)
 if beforeQty==afterQty then afterQty=afterQty+1 end
 local r=simulate(beforeQty,afterQty,delay)
 if delay<=120 then assert(r.postReadbacksObserved==2)
 else assert(r.status=="INCOMPLETE") end
end
check("400 seeded timing and qty cases",function()end)
print("STAGE59_REAL_LUA_120S_LEDGER_9_CASES_400_SEEDED_PASS")
'''
class Stage59TimeoutSourceFidelityTests(unittest.TestCase):
    def test_exact_source_only_known_modifications(self):
        l29=STAGE29.read_text(encoding="utf-8")
        l32=STAGE32.read_text(encoding="utf-8")
        self.assertEqual(l29.count("age<=120"),1)
        old29=l29.replace("age<=120","age<=60")
        self.assertEqual(blob_sha(old29),OLD29_GIT_BLOB,
                         "Stage59 ledger must differ only in bounded max window")
        self.assertEqual(l32.count("maxBeforeToClose=120"),1)
        self.assertEqual(l32.count("os.clock()-beforeTime<120"),1)
        self.assertIn("maxPostAge=30",l32)
        self.assertIn("STAGE59_POSTCLOSE_LEDGER_120S",l32)
        old32=l32
        deltas=(
            (f'local STAGE29="{STAGE59_LEDGER_COMMIT}"',
             f'local STAGE29="{ORIGINAL_STAGE29_SHA}"'),
            ('ledger=source(STAGE29,"STAGE59_POSTCLOSE_LEDGER_120S")',
             'ledger=source(STAGE29,"p4_stage29_postclose_ledger")'),
            ('maxBeforeToClose=120,minPostGap=.75,maxPostAge=30',
             'maxBeforeToClose=30,minPostGap=.75,maxPostAge=30'),
            ('close within 120s.','close within 30s.'),
            ('os.clock()-beforeTime<120','os.clock()-beforeTime<30'),
            ('TRADE_WINDOW_NOT_CLOSED_WITHIN_120S',
             'TRADE_WINDOW_NOT_CLOSED_WITHIN_30S'),
        )
        for new,old in deltas:
            self.assertEqual(old32.count(new),1,new)
            old32=old32.replace(new,old)
        self.assertEqual(blob_sha(old32),OLD32_GIT_BLOB,
                         "Stage59 observer must differ ONLY in bounded timing & exact ledger pin")
        self.assertNotIn("TRADE_WINDOW_NOT_CLOSED_WITHIN_30S",l32)
        for forbidden in (":FireServer(",":PostAsync(",":InvokeServer(",":FireClient(",
                          "AcceptTrade:","OfferItem:","TeleportToPlaceInstance("):
            self.assertNotIn(forbidden,l32)
            self.assertNotIn(forbidden,l29)

    @unittest.skipUnless(shutil.which("lua5.4"),"GitHub CI installs Lua5.4")
    def test_actual_lua_stage29_cross_timeout_boundary_and_scoped_reads(self):
        with tempfile.TemporaryDirectory(prefix="stage59_age_") as td:
            fixture=Path(td)/"driver.lua"
            fixture.write_text(LUA_DRIVER,encoding="utf-8")
            p=subprocess.run(["lua5.4",str(fixture),str(STAGE29)],
                cwd=ROOT,capture_output=True,text=True,timeout=40)
        self.assertEqual(p.returncode,0,p.stdout+"\n"+p.stderr)
        self.assertIn("STAGE59_REAL_LUA_120S_LEDGER_9_CASES_400_SEEDED_PASS",p.stdout)

if __name__=="__main__":
    unittest.main()
