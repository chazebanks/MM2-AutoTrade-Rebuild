"""Frozen original P3 host + real SHA256 Supreme-only branch integrity.

Historical captured publisher edition remains unsigned/mediated. These tests
do NOT prove iPad game execution, real item instances, or trade permissions.
"""
from __future__ import annotations

from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import unittest

ROOT=Path(__file__).resolve().parents[2]/"pdiddler"
SUPREME=ROOT/"system2/supreme_only_189_research_catalog_2026_11_16_refresh.json"
OLDER=ROOT/"system2/supreme_only_189_research_catalog.json"
CRYPTO=ROOT/"system2/native_sha256_rfc6234_readonly.lua"
ENGINE=ROOT/"system2/native_supreme_only_bilateral_research_refresh.lua"
BRIDGE=ROOT/"system2/native_supreme_only_protected_c3p4_adapter_refresh.lua"
HOST=ROOT/"supervised/STAGE119_C9_SUPREME_ONLY_READONLY_NATIVE.lua"
START=ROOT/"supervised/STAGE119_C9_SUPREME_ONLY_READONLY_START.lua"
ORIGINAL=ROOT/"supervised/STAGE119_P3_BOUND_READONLY_NATIVE.lua"
CATALOG_SHA="33d7b4ac5e5314a27e6ba540e579efad2bec8eb267635beda01165d5017c84a2"
CATALOG_GIT_BLOB="5f208d43e99f71231131a6aa83b51db42f5a997d"
CATALOG_CAPTURE="2026-11-16T15:36:17Z"
NATIVE_PIN="392afac77c00fb33b41c0d5d090bdbb05cfd5a8e"
SOURCE_PIN="6ba1e0eed8ff8953217d3bc31c081ef8ab4dc3bf"

def blob(path):
    b=path.read_bytes()
    return hashlib.sha1(b"blob "+str(len(b)).encode()+b"\0"+b).hexdigest()


class TrueOriginalSupremeOnlyBootIntegrity(unittest.TestCase):
    def test_fresh_real_four_page_supreme_only_catalog_bytes(self):
        b=SUPREME.read_bytes()
        self.assertEqual(hashlib.sha256(b).hexdigest(), CATALOG_SHA)
        self.assertEqual(blob(SUPREME),CATALOG_GIT_BLOB)
        c=json.loads(b)
        self.assertEqual(c["schema"],"gingerscope-system2-supreme-only-189-publisher-catalog-v2")
        self.assertEqual(c["valueSource"],"SUPREME_ONLY")
        self.assertEqual(c["sourceTransport"],"FIRECRAWL_MEDIATED_HTTPS_RESEARCH")
        self.assertEqual(c["sourceCapturedUtc"], CATALOG_CAPTURE)
        self.assertEqual(c["publisherUpdatedAt"],"2026-11-15T11:59:41-05:00")
        self.assertEqual(len(c["rows"]),189)
        self.assertEqual(c["categories"],{"ancient":15,"godly":128,"chroma":46})
        self.assertTrue(c["originalPublisherEditionUnchanged"])
        self.assertFalse(c["publisherSigned"])
        self.assertFalse(c["liveTradePricingAuthorized"])
        self.assertFalse(c["authorizesOffer"])
        pages=c["pageEvidence"]
        self.assertEqual(set(pages),{"home","ancient","godly","chroma"})
        for category,url in (
            ("home","https://supremevalues.com/"),
            ("ancient","https://supremevalues.com/mm2/ancients"),
            ("godly","https://supremevalues.com/mm2/godlies"),
            ("chroma","https://supremevalues.com/mm2/chromas")
        ):
            self.assertEqual(pages[category]["url"],url)
            self.assertEqual(pages[category]["sourceStatus"],200)
            self.assertRegex(pages[category]["scrapeId"],r"^[0-9a-f-]{36}$")
        self.assertEqual([pages[k]["publisherItemcolumnCards"]
                          for k in ("ancient","godly","chroma")],[16,130,53])
        dt=datetime.fromisoformat(CATALOG_CAPTURE.replace("Z","+00:00"))
        self.assertEqual(dt.tzinfo, timezone.utc)
        self.assertEqual((dt.timestamp()+21600),1794864977)

    def test_exact_189_single_edition_prices_not_silent_hybrid(self):
        current=json.loads(SUPREME.read_bytes())
        former=json.loads(OLDER.read_bytes())
        a={r["rawGameKeyCandidate"]:r for r in current["rows"]}
        b={r["rawGameKeyCandidate"]:r for r in former["rows"]}
        self.assertEqual(set(a),set(b))
        for key, row in a.items():
            with self.subTest(key=key):
                self.assertEqual(row,b[key])
                self.assertEqual(set(row),{
                    "rawGameKeyCandidate","category","officialName","officialItemId",
                    "supremeListed","supremeDemand","supremeStability",
                    "outgoingGingerscopeProtected"
                })
        self.assertEqual(sum(r["outgoingGingerscopeProtected"] for r in a.values()),1)
        self.assertEqual(a["Gingerscope"]["supremeListed"],16000)
        self.assertEqual(a["Harvester"]["supremeListed"],275)
        text=SUPREME.read_text().lower()
        for field in ("mm2values","mm2listed","blended","hybridprice","secondarymarketprice"):
            self.assertNotIn(field,text)

    def test_pure_sha256_module_and_native_pins_not_fake_client_hash(self):
        crypto=CRYPTO.read_text()
        self.assertIn("bit32",crypto)
        self.assertIn("0x428a2f98",crypto)
        self.assertIn("M.hex(bytes)",crypto)
        self.assertNotIn("syn.crypt",crypto)
        self.assertNotIn("getgenv",crypto)
        code=BRIDGE.read_text()
        self.assertIn(CATALOG_SHA,code)
        self.assertIn(CATALOG_GIT_BLOB,code)
        self.assertIn("c.sha256,c.sourceBytes",code)
        self.assertIn("sourceBytes",code)
        self.assertNotIn("catalogPin",code)
        self.assertNotIn("MM2VALUES",code)
        engine=ENGINE.read_text()
        self.assertIn(CATALOG_GIT_BLOB,engine)
        self.assertIn("SUPREME_ONLY_MEDIATED_PUBLIC_RESEARCH_NOT_LIVE",engine)
        self.assertNotIn("mm2Listed",engine)
        self.assertNotIn("native_bilateral_attractiveness_shadow",engine)

    def test_original_stage119_byte_frozen_and_no_legacy_price_modules_loaded(self):
        self.assertEqual(blob(ORIGINAL),"fc25514564e78d390b089742eb4e7da7508c12fa")
        host=HOST.read_text()
        self.assertIn("cfg.c9SupremeOnlyReadOnly~=true",host)
        self.assertIn("c9SupremeOnlyReadOnlyPreview=c9SupremeOnlyReadOnlyPreview",host)
        self.assertIn("operatorConfirmedReadOnlyInventoryRpc",host)
        self.assertIn("c9ReadOnlyLeaseStatus()",host)
        self.assertIn(SOURCE_PIN,host)
        self.assertIn("native_sha256_rfc6234_readonly.lua",host)
        self.assertIn("native_supreme_only_bilateral_research_refresh.lua",host)
        self.assertIn("native_market_offer_client_capture.lua",host)
        self.assertIn("supreme_only_189_research_catalog_2026_11_16_refresh.json",host)
        for forbidden in ("native_c9_growth_first_preview.lua",
                          "native_bilateral_attractiveness_shadow.lua",
                          "native_market_inventory_offer_core.lua",
                          "c9ReadOnlyMarketPreflight=c9ReadOnlyMarketPreflight"):
            self.assertNotIn(forbidden,host)
        self.assertNotIn("publicArm",host)
        self.assertNotIn("venossgaming90190",host)

    def test_new_start_pins_new_host_and_manual_only_plan(self):
        start=START.read_text()
        self.assertIn(NATIVE_PIN,start)
        self.assertIn("STAGE119_C9_SUPREME_ONLY_READONLY_NATIVE.lua",start)
        for field in ("supremeOnlyResearchRequested",
                      "explicitOwnInventoryReadRpcConsent",
                      "operatorConfirmedReadOnlyInventoryRpc",
                      "understandsArmSendsP3TradeRequest",
                      "automaticP3ArmForbidden",
                      "noWeaponAddOrRemoveTests",
                      "finalAcceptMustRemainManual",
                      "consentVerifiedForNamedAlt"):
            self.assertIn(field,start)
        for method in ("runtime.arm~=nil","runtime.offer~=nil",
                       "runtime.accept~=nil","runtime.decline~=nil",
                       "runtime.c9ReadOnlyMarketPreflight~=nil"):
            self.assertIn(method,start)
        self.assertNotIn("supervisor.arm(",start)
        self.assertNotIn("venossgaming90190",start)

if __name__=="__main__":
    unittest.main()
