"""Stage73 verifies the actual Lua scanner view and read-only boot composition.

No Roblox instance is started by these tests. The scanner has no new trade
authority, and existing expired Supreme profile stays expired.
"""
from __future__ import annotations

import random
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
VIEW=ROOT/"pdiddler/presentation/pdiddler3_scanner_view_stage73_history_v1.lua"
HISTORY=ROOT/"pdiddler/intelligence_lab/stage72_historical_reference_preview.lua"
PROFILE=ROOT/"pdiddler/snapshots/pdiddler_supreme_snapshot_2026_11_06.lua"
STRICT=ROOT/"pdiddler/new_part4/P4_REPRICE_ONLY.lua"
BOOT=ROOT/"pdiddler/new_part4/STAGE73_SCANNER_HISTORY_ONLY_BOOT.lua"
HARNESS=r"""
local mode=arg[1]
local history=assert(dofile(arg[2]))
local profile=assert(dofile(arg[3]))
local strict=assert(dofile(arg[4]))
local now=1794201000
os.time=function() return now end
local render=assert(loadfile(arg[5]))(history)
local items={
  {id="PRIVATE_RAW_KEY_1",name="Gingerscope",page="ancient",
    cat="Weapons",type="Gun",checkerId="771",qty=1},
  {id="PRIVATE_RAW_KEY_2",name="Candleflame",page="godly",
    cat="Weapons",type="Knife",checkerId="524",qty=1},
  {id="PRIVATE_RAW_KEY_3",name="Chroma Candleflame",page="chroma",
    cat="Weapons",type="Knife",checkerId="525",qty=1},
  {id="PRIVATE_RAW_KEY_4",name="Emberbow",page="ancient",
    cat="Weapons",type="Gun",checkerId="1026",qty=1},
}
if mode=="bad-chroma" then items[3].name="Candleflame"
elseif mode=="fuzzy-alias" then items[1].name="GSCOPE"
elseif mode=="fake-valued-row" then
  items[1].verified=true
  items[1].value=250000000
  items[1].source="verified-snapshot-2026-11-01"
elseif mode=="invalid-qty" then items[1].qty="1"
elseif mode=="duplicate-key" then items[2].id=items[1].id
elseif mode=="missing-profile" then profile.sources.godly=nil
elseif mode=="expired-but-claimed-current" then
  profile.liveReady=true
elseif mode=="no-inventory" then items=nil
elseif mode=="fuzz" then
  local z=(tonumber(arg[6]) or 0)%12
  if z==0 then items[1].checkerId="999999"
  elseif z==1 then items[3].name="Candleflame"
  elseif z==2 then items[1].name="Alias"
  elseif z==3 then items[1].verified=true
  elseif z==4 then items[1].value=1e30
  elseif z==5 then items[1].type="Pet"
  elseif z==6 then items[1].qty=0/0
  elseif z==7 then profile.sources.ancient.sha256="bad"
  elseif z==8 then profile.expiresAtEpoch=1800000000
  elseif z==9 then items[2].id=items[1].id
  elseif z==10 then profile.sources.godly=nil
  else items[1].qty=2 end
end
local inv=items and {items=items,unmapped=0,unpriced=0,badQty=0} or nil
if mode=="clock-rollback" then
  assert(not profile.isFresh())
  assert(render.inventory(inv,profile,strict).totalText=="UNVERIFIED")
  now=profile.observedAtEpoch+300
  assert(profile.isFresh(), "test clock must make the old profile appear fresh")
end
local result=render.inventory(inv,profile,strict)
assert(type(result)=="table")
assert(result.totalText=="UNVERIFIED", "history total became "..result.totalText)
assert(result.priceState=="expired")
assert(type(result.detail)=="string")
assert(result.detail:find("prices expired or unavailable",1,true))
assert(result.detail:find("Total value: UNVERIFIED",1,true))
assert(result.detail:find("UNVERIFIED",1,true))
assert(not result.detail:find("Outgoing: READY",1,true))
local state,row=render.row({state="whitelist",inv=inv},
  {state="ready",reason="fake-outgoing-ready"},nil,profile,strict)
assert(state=="whitelist")
assert(row:find("Outgoing: UNKNOWN | Paused: Supreme prices expired or unavailable",1,true))
assert(not row:find("Outgoing: READY",1,true))
local summary=render.summary(7,1,0,{state="ready",reachable=1000},profile)
assert(summary:find("Outgoing: paused - Supreme prices expired or unavailable",1,true))
assert(not summary:find("Outgoing (unprocessed): Reachable 1000",1,true))
if mode=="base" or mode=="fake-valued-row"
   or mode=="expired-but-claimed-current" or mode=="clock-rollback" then
 assert(result.historicalReferencesShown==3)
 assert(result.detail:find("HISTORICAL REFERENCES ONLY (UNVERIFIED; NO TRADING)",1,true))
 assert(result.detail:find("Historical Supreme ref: 16000 each",1,true))
 assert(result.detail:find("Additional historical references omitted from preview",1,true))
elseif mode=="bad-chroma" or mode=="fuzzy-alias" then
 assert(result.historicalReferencesShown<=3)
elseif mode=="missing-profile" or mode=="invalid-qty" or
   mode=="duplicate-key" or mode=="no-inventory" then
 assert(result.historicalReferencesShown==0)
end
if mode=="clock-rollback" then
  assert(not result.detail:find("Snapshot expired: false",1,true))
  local _,idleRow=render.row({state="whitelist",inv=inv},nil,nil,profile,strict)
  assert(idleRow:find("Paused: Supreme prices expired or unavailable",1,true))
end
print("STAGE73_VIEW mode="..mode..
 " shown="..result.historicalReferencesShown..
 " total="..result.totalText..
 " state="..result.priceState..
 " outgoingPaused=true")
"""

class Stage73ActualViewTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.lua=shutil.which("lua5.4")
        cls.luac=shutil.which("luac5.4")
        if not cls.lua or not cls.luac:
            raise RuntimeError("Lua5.4 is required")
        cls.temp=tempfile.TemporaryDirectory(prefix="stage73_view_")
        cls.harness=Path(cls.temp.name)/"harness.lua"
        cls.harness.write_text(HARNESS,encoding="utf-8")
    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()
    def invoke(self,mode,seed=None):
        cmd=[self.lua,str(self.harness),mode,str(HISTORY),str(PROFILE),
             str(STRICT),str(VIEW)]
        if seed is not None: cmd.append(str(seed))
        p=subprocess.run(cmd,capture_output=True,text=True,timeout=6)
        self.assertEqual(p.returncode,0,(mode,seed,p.stdout[-1500:],p.stderr[-1800:]))
        self.assertIn("STAGE73_VIEW",p.stdout)
        self.assertIn("total=UNVERIFIED state=expired outgoingPaused=true",p.stdout)
        for forbidden in ("PRIVATE_RAW_KEY_1","PRIVATE_RAW_KEY_2",
                          "verified-snapshot-2026-11-01"):
            self.assertNotIn(forbidden,p.stdout)
        return p.stdout
    def test_actual_source_compiles_and_stable_safe_bootstrap_pins(self):
        for path in (VIEW,BOOT,HISTORY,PROFILE,STRICT):
            cmd=subprocess.run([self.luac,"-p",str(path)],
                               capture_output=True,text=True)
            self.assertEqual(cmd.returncode,0,(str(path),cmd.stderr))
        boot=BOOT.read_text(encoding="utf-8")
        self.assertIn("STAGE73_SCANNER_HISTORY_ONLY_BOOT",str(BOOT))
        self.assertIn("stage72_historical_reference_preview.lua",boot)
        self.assertIn("pdiddler3_scanner_view_stage73_history_v1.lua",boot)
        self.assertIn("a10d80a086b644085a9cffd87c1f5ce0489597bc",boot)
        self.assertIn("8a5604bd2b44eb27293b134ed1a78382fe5b4048",boot)
        self.assertIn('S.status="STAGE73_SCANNER_HISTORY_ONLY_NO_TRADE_AUTHORITY"',boot)
        self.assertIn("S.rawScanner=fetchAndRun(\"scanner\",profile,reprice,view)",boot)
        for bad in (":FireServer(",":InvokeServer(", "OfferItem(", "AcceptTrade(",
                    "DeclineTrade(", "SendRequest(", "SetValue(", "DiscordWebhook("):
            self.assertNotIn(bad,boot)

    def test_expired_supreme_old_values_only_historical_annotation(self):
        self.assertIn("shown=3",self.invoke("base"))
    def test_clock_rollback_cannot_promote_history_view_to_current_prices(self):
        self.assertIn("shown=3",self.invoke("clock-rollback"))
    def test_forged_client_price_and_fake_outgoing_ready_never_promote(self):
        for mode in ("fake-valued-row","expired-but-claimed-current"):
            with self.subTest(mode=mode):
                self.assertIn("shown=3",self.invoke(mode))
    def test_chroma_and_fuzzy_aliass_remain_unverified(self):
        for mode in ("bad-chroma","fuzzy-alias"):
            with self.subTest(mode=mode):
                self.invoke(mode)
    def test_invalid_inventory_or_source_suppresses_historical_section(self):
        for mode in ("missing-profile","invalid-qty","duplicate-key",
                     "no-inventory"):
            with self.subTest(mode=mode):
                self.assertIn("shown=0",self.invoke(mode))
    def test_200_seeded_ui_states_keep_outgoing_paused(self):
        rng=random.Random(737373)
        for i in range(200):
            self.assertIn("outgoingPaused=true",
                          self.invoke("fuzz",rng.randrange(1,1000000)))

if __name__=="__main__":
    unittest.main()
