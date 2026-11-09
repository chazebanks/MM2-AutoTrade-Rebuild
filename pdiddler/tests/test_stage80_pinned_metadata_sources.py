"""Stage80 real public archive audit and original Stage79 predicate provenance.

The archived game database is THIRD-PARTY / HISTORICAL, not the user's
private Owned table or a server-authenticated source. Network only in CI.
"""
import hashlib
import os
from pathlib import Path
import re
import unittest

ROOT=Path(__file__).resolve().parents[2]
GAME_BLOB="2be54c3f5c6b715844728c01a65cc2f24a55c02d"
STAGE79_BLOB="7431604ed060bbaf815d359c38c64b0fe82c8fa8"
GAME_ROW=re.compile(r'(?m)^  \["([^"\n]+)"\]\s*=\s*\{\s*\n([\s\S]*?)^  \},?')
GAME_FIELD=re.compile(r'(?m)^    \["(ItemName|ItemType|Rarity|Chroma)"\]\s*=\s*("[^"\n]*"|true|false)\s*,?\s*$')

def hash_blob(payload):
    return hashlib.sha1(b"blob "+str(len(payload)).encode()+b"\0"+payload).hexdigest()

class Stage80(unittest.TestCase):
    def sources(self):
        p=os.getenv("STAGE80_PINNED_GAME")
        s=os.getenv("STAGE80_PINNED_STAGE79")
        if not p or not s:
            if os.getenv("STAGE80_REQUIRE_PINNED")=="1":
                self.fail("Dedicated CI requires BOTH immutable original input files")
            self.skipTest("Actual archived public sources required by dedicated CI only")
        game=Path(p).read_bytes()
        prior=Path(s).read_bytes()
        self.assertEqual(hash_blob(game),GAME_BLOB)
        self.assertEqual(hash_blob(prior),STAGE79_BLOB)
        return game,prior

    def test_original_stage79_acceptance_rule_is_weapon_only(self):
        _,old=self.sources()
        src=old.decode("utf-8")
        self.assertIn('(meta.ItemType~="Knife" and meta.ItemType~="Gun")',src)
        self.assertIn('out.malformedCatalogueEntryCount=out.malformedCatalogueEntryCount+1',src)
        self.assertIn('local meta=rawget(cat,k)',src)
        self.assertNotIn('meta.ItemType=="Misc"',src)

    def test_actual_oct18_catalogue_contains_13_misc_and_3_incomplete(self):
        raw,_=self.sources()
        rows=[]
        for key,body in GAME_ROW.findall(raw.decode("utf-8")):
            fields={}
            for name,value in GAME_FIELD.findall(body):
                self.assertNotIn(name,fields)
                fields[name]=value.strip('"')
            rows.append((key,fields))
        self.assertEqual(len(rows),1040)
        misc=[(k,d) for k,d in rows if d.get("ItemType")=="Misc"]
        incomplete=[(k,d) for k,d in rows if not d.get("ItemName") or not d.get("ItemType")]
        unexpected=[(k,d) for k,d in rows if (
            not d.get("ItemName") or not d.get("Rarity")
            or d.get("ItemType") not in ("Knife","Gun"))]
        self.assertEqual(len(misc),13)
        self.assertEqual(len(incomplete),3)
        self.assertEqual(len(unexpected),16)
        self.assertTrue(all(d["ItemName"] and d["Rarity"] for _,d in misc))
        self.assertEqual({k for k,_ in incomplete},{
            "RandomLegendaryWeapon","RandomRareWeapon","RandomUncommonWeapon"})

    def test_native_stage80_is_one_call_and_no_trade_methods(self):
        script=(ROOT/"pdiddler/new_part4/STAGE80_READONLY_OWNED_METADATA_REASON.lua").read_text()
        mod=(ROOT/"pdiddler/intelligence_lab/stage80_owned_metadata_reason.lua").read_text()
        self.assertEqual(script.count("rf:InvokeServer()"),1)
        self.assertIn('local deadline=os.clock()+4.5',script)
        self.assertIn("profile.Weapons.Owned,sync.Weapons",script)
        self.assertIn('GINGERSCOPE_STAGE79_SINGLE_OWNED_TYPE_PROBE',script)
        self.assertIn("rawget(catalogue,key)",mod)
        self.assertNotIn("tostring(key)",mod)
        for forbidden in ("FireServer(","TeleportService","AcceptTrade","OfferItem"):
            self.assertNotIn(forbidden,script)
            self.assertNotIn(forbidden,mod)
        self.assertIn("mayUseForStrategyLearning=false",mod)
        self.assertIn("authorizesTrade=false",mod)

if __name__=="__main__":
    unittest.main()
