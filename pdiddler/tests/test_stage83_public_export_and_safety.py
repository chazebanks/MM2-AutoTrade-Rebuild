"""Stage83 reproducible public registry source + privacy boundary tests.

Focused CI must provide all SEVEN original source files and exact reviewed
Stage82 module. No Roblox game calls, no owned profile reads, no current prices.
"""
from __future__ import annotations
import hashlib
import importlib.util
import os
from pathlib import Path
import random
import unittest

ROOT=Path(__file__).resolve().parents[2]
SCRIPT=ROOT/"pdiddler/intelligence_lab/stage83_export_public_slug_registry.py"
REGISTRY=ROOT/"pdiddler/intelligence_lab/stage83_public_slug_registry.lua"
NATIVE=ROOT/"pdiddler/new_part4/STAGE83_READONLY_PUBLIC_SLUG_COVERAGE.lua"
HELPER=ROOT/"pdiddler/intelligence_lab/stage83_private_aggregate_coverage.lua"
spec=importlib.util.spec_from_file_location("stage83_public_export",SCRIPT)
m=importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

PINS={
 "STAGE83_GAME": "2be54c3f5c6b715844728c01a65cc2f24a55c02d",
 "STAGE83_ROSTER": "a85af4f6137278540e1fed0c27e7e801553e4111",
 "STAGE83_ANCIENTS": "7e11a2d835eadbb522d351bdabe393a7c9688f4b",
 "STAGE83_GODLIES": "2e4a0c1b8df894f9037e737ba80919b9b2d0c9ae",
 "STAGE83_CHROMAS": "0d2d156d9d9c499ef0e1213376796c1a916e6ce1",
 "STAGE83_STAGE77": "754fbe3189d5108272c32a27fc52bf3834011d38",
 "STAGE83_STAGE81": "bff17e1c164d7075a975b0a5e1da27ac2d20a2ba",
 "STAGE83_STAGE82": "91362b647a8cc630e4fabcf7aa5d65eb44adb399",
}

class Stage83(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if any(not os.environ.get(k) for k in PINS):
            if os.environ.get("STAGE83_REQUIRE_PINNED")=="1":
                raise AssertionError("Stage83 must receive EIGHT immutable source files")
            cls.src=None
            return
        cls.src={k:Path(os.environ[k]).read_bytes() for k in PINS}
        for key,want in PINS.items():
            actual=m.git_blob(cls.src[key])
            if actual!=want:
                raise AssertionError(f"{key}: immutable historical input changed")
        cls.sources=(
          cls.src["STAGE83_GAME"],
          cls.src["STAGE83_ROSTER"],
          {"ancient":cls.src["STAGE83_ANCIENTS"],
           "godly":cls.src["STAGE83_GODLIES"],
           "chroma":cls.src["STAGE83_CHROMAS"]},
          cls.src["STAGE83_STAGE77"],
          cls.src["STAGE83_STAGE81"],
          cls.src["STAGE83_STAGE82"],
        )
        cls.actual=m.compile_registry(*cls.sources)

    def sources_or_skip(self):
        if self.src is None: self.skipTest("requires dedicated immutable-source CI")
        return self.sources

    def test_rebuild_lua_registry_exactly_from_all_eight_files(self):
        self.sources_or_skip()
        self.assertEqual(self.actual,REGISTRY.read_text(encoding="utf-8"))
        self.assertEqual(self.actual.count('    ["'),189)
        self.assertIn('["Gingerscope"] = {"Gingerscope", "Gun", "Ancient", false, "ancient", "Gingerscope"}',self.actual)
        self.assertIn('["EmberscytheChroma"] = {"Emberscythe", "Knife", "Ancient", true, "chroma", "CEmberscythe"}',self.actual)
        self.assertIn('["BattleAxe2"] = {"BattleAxe II", "Knife", "Godly", false, "godly", "BA2"}',self.actual)
        self.assertIn('"2026-11-09T15:56:07Z"',self.actual)

    def test_archived_public_lua_exports_no_prices_market_ids_or_authorities(self):
        self.sources_or_skip()
        s=self.actual
        for forbidden in ("supremeValue","checkerId","serverAttestation = true",
                          "authorizesTrade = true","price =","GetProfileData",
                          "FireServer","InvokeServer","setclipboard","userdata"):
            self.assertNotIn(forbidden,s)
        self.assertIn("currentPricesVerified = false",s)
        self.assertIn("authenticatedOwnedInventory = false",s)
        self.assertIn("mayUseForStrategyLearning = false",s)
        self.assertEqual(len(s.encode("utf-8")),len(REGISTRY.read_bytes()))

    def test_400_byte_mutations_never_produce_public_approved_registry(self):
        source=self.sources_or_skip()
        rng=random.Random(8307)
        for i in range(400):
            game,roster,sites,stage77,stage81,stage82=source
            sites=dict(sites)
            choice=i%8
            bad=bytes([rng.randint(0,255)])
            if choice==0:game+=bad
            elif choice==1:roster+=bad
            elif choice==2:sites["ancient"]+=bad
            elif choice==3:sites["godly"]+=bad
            elif choice==4:sites["chroma"]+=bad
            elif choice==5:stage77+=bad
            elif choice==6:stage81+=bad
            else:stage82+=bad
            with self.subTest(i=i):
                with self.assertRaises(ValueError):
                    m.compile_registry(game,roster,sites,stage77,stage81,stage82)

    def test_public_key_round_trip_does_not_promote_price_authority(self):
        self.sources_or_skip()
        self.assertNotIn("Nik's Scythe",self.actual.split("  entries = {",1)[1])
        self.assertEqual(self.actual.count("    ["),189)
        # The 10 eligible public-only entries plus priceless item remain
        # unlinked, not guessed from wiki names or art IDs.
        self.assertNotIn("Old numeric checker",self.actual)

    def test_native_wrap_cannot_mutate_trades_and_reads_only_own_once(self):
        native=NATIVE.read_text(encoding="utf-8")
        helper=HELPER.read_text(encoding="utf-8")
        self.assertEqual(native.count("ownRemote:InvokeServer()"),1)
        self.assertIn("deadline=os.clock()+4.5",native)
        self.assertIn('profile.Weapons.Owned,sync.Weapons,registry',native)
        self.assertIn("rawget(registry.entries,raw)",helper)
        self.assertIn("sourcePublisherFresh=false",helper)
        for forbidden in ("FireServer(","GetFullInventory","AcceptTrade",
                          "OfferItem","TeleportService","getconnections(",
                          "hookfunction(","HttpPost(","RequestAsync("):
            self.assertNotIn(forbidden,native)
            self.assertNotIn(forbidden,helper)
        self.assertIn("GINGERSCOPE_STAGE80_ONE_METADATA_REASON_PROBE",native)

if __name__=="__main__":
    unittest.main()
