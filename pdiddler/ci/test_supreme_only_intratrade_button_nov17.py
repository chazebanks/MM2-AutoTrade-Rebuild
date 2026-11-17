"""Integrity/regression: freshly captured Supreme-only exact in-game read-only UI.

Offline source assertions; not evidence of successful iPad/Delta execution.
"""
import hashlib
import json
from pathlib import Path
import unittest

P=Path(__file__).resolve().parents[1]
CAT=P/"system2/supreme_only_189_research_catalog_2026_11_17_refresh.json"
OLD=P/"system2/supreme_only_189_research_catalog_2026_11_16_refresh.json"
CORE=P/"system2/native_supreme_only_bilateral_research_nov17.lua"
BRIDGE=P/"system2/native_supreme_only_protected_c3p4_adapter_nov17.lua"
BUTTON=P/"system2/native_supreme_only_current_offer_button.lua"
HOST=P/"supervised/STAGE119_C9_SUPREME_ONLY_BUTTON_NATIVE.lua"
START=P/"supervised/STAGE119_C9_SUPREME_ONLY_BUTTON_START.lua"
SHA="48107d3039caf620bcad2c08831c9ca7fe206780dfb0e2d96d8161e3c9210f4a"
BLOB="1497e9644ae271ff7a144aa5de43c30609f5c722"
LATEST_BLOB="958038a6b22c43e8d0359cb15e6704bc84253430"
LATEST_SHA="fd657db48c00c996705093dadc384c1a0ddd4630398826108b5585ca76c2eca4"

def git_blob(p):
    content=p.read_bytes()
    return hashlib.sha1(b"blob "+str(len(content)).encode()+b"\0"+content).hexdigest()

class SupremeOnscreenButtonNativeIntegrity(unittest.TestCase):
    def test_true_source_bytes_sha_and_unique_exact_189(self):
        data=CAT.read_bytes()
        self.assertEqual(hashlib.sha256(data).hexdigest(),SHA)
        self.assertEqual(git_blob(CAT),BLOB)
        c=json.loads(data)
        self.assertEqual(c["sourceCapturedUtc"],"2026-11-17T14:06:51Z")
        self.assertEqual(c["publisherUpdatedAt"],"2026-11-15T11:59:41-05:00")
        self.assertTrue(c["originalPublisherEditionUnchanged"])
        self.assertEqual(c["valueSource"],"SUPREME_ONLY")
        self.assertEqual(c["categories"],{"ancient":15,"godly":128,"chroma":46})
        self.assertEqual(len(c["rows"]),189)
        self.assertEqual(len({r["rawGameKeyCandidate"] for r in c["rows"]}),189)
        self.assertEqual(len({(r["category"],r["officialItemId"]) for r in c["rows"]}),189)
        self.assertFalse(c["publisherSigned"])
        self.assertFalse(c["liveTradePricingAuthorized"])
        self.assertFalse(c["authorizesOffer"])
        self.assertFalse(c["authorizesAccept"])
        self.assertEqual(c["pageEvidence"]["ancient"]["publisherItemcolumnCards"],16)
        self.assertEqual(c["pageEvidence"]["godly"]["publisherItemcolumnCards"],130)
        self.assertEqual(c["pageEvidence"]["chroma"]["publisherItemcolumnCards"],53)
        for key in ("home","ancient","godly","chroma"):
            self.assertEqual(c["pageEvidence"][key]["sourceStatus"],200)
            self.assertRegex(c["pageEvidence"][key]["scrapeId"],
                             r"^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$")
    def test_no_stealth_value_change_or_second_market_source(self):
        old=json.loads(OLD.read_bytes())
        current=json.loads(CAT.read_bytes())
        self.assertEqual(old["rows"],current["rows"])
        text=CAT.read_text().lower()
        for token in ("mm2values","mm2listed","marketprice2","hybridvalue","secondarylisted"):
            self.assertNotIn(token,text)
        keys={r["rawGameKeyCandidate"]:r for r in current["rows"]}
        self.assertEqual(keys["Gingerscope"]["supremeListed"],16000)
        self.assertEqual(keys["Harvester"]["supremeListed"],275)
        self.assertEqual(keys["FlowerwoodKnife"]["supremeListed"],235)
        self.assertEqual(sum(x["outgoingGingerscopeProtected"] for x in current["rows"]),1)
    def test_native_pins_and_exact_two_sided_current_offer(self):
        core=CORE.read_text()
        bridge=BRIDGE.read_text()
        button=BUTTON.read_text()
        self.assertIn(LATEST_BLOB,core)
        self.assertIn(LATEST_BLOB,bridge)
        self.assertIn(LATEST_SHA,bridge)
        self.assertIn("1794951678",core)
        self.assertIn("1794951678",bridge)
        self.assertIn("sameOffer(option.receive,their)",bridge)
        self.assertIn("sameOffer(option.give,ours)",bridge)
        self.assertIn("ORIGINAL_P4_OFFER_ACCEPTANCE_OR_STACK_CHANGED",bridge)
        self.assertIn("ORIGINAL_C3_OWN_CENSUS_CHANGED_DURING_STRATEGY",bridge)
        self.assertIn("ORIGINAL_P4_CHANGED_AFTER_C3_REFRESH",bridge)
        self.assertIn("BOTH_PHYSICAL_OFFERS_MUST_BE_NONEMPTY",button)
        self.assertIn("GUI_RAW_WEAPON_ID_OR_SLOT_NOT_PROVEN",button)
        self.assertIn("ORIGINAL_P4_GUI_CHANGED_DURING_PREVIEW",button)
        self.assertIn("GINGERSCOPE_NEVER_OUTGOING",button)
        for code in (core,bridge,button):
            for forbidden in ("mm2Listed","mm2Values","FireServer","InvokeServer",
                              "PostAsync","TeleportService","AcceptTrade","DeclineTrade"):
                self.assertNotIn(forbidden,code)
    def test_safe_single_button_reuses_original_arm_slot(self):
        host=HOST.read_text()
        start=START.read_text()
        self.assertIn('ui.arm=action("ArmP3","ARM P3",12)',host)
        self.assertIn('ui.preview=action("SupremePreview","SUPREME PREVIEW",12)',host)
        self.assertIn('ui.stop=action("StopP3","STOP / COPY",164)',host)
        self.assertIn('geometry.choose(',host)
        self.assertIn('{w=304,h=148}',host)
        self.assertIn('ui.preview.Activated:Connect(function()',host)
        self.assertIn('ui.preview.Visible=armed and not supremePreviewBusy',host)
        self.assertIn('c9SupremeOnlyReadOnlyPreview(options)',host)
        self.assertIn("native_supreme_only_current_offer_button.lua",host)
        self.assertIn("3d23aeb45efe6dc87840b0f4f8a89198d0d8b4e3",host)
        self.assertIn("supreme_only_189_research_catalog_2026_11_17_refresh.json",host)
        self.assertIn("7f8068ce852eba851bcd6f5fe041f9055ba9bbb6",start)
        self.assertIn("GINGERSCOPE_C9_SUPREME_ONLY_PLAN",start)
        for field in ("explicitOwnInventoryReadRpcConsent","supremeOnlyResearchRequested",
                      "automaticP3ArmForbidden","consentVerifiedForNamedAlt"):
            self.assertIn(field,start)
        self.assertNotIn("c9ReadOnlyMarketPreflight=c9ReadOnlyMarketPreflight",host)
        self.assertNotIn("venossgaming90190",start)
        self.assertNotIn("supervisor.arm(",start)
    def test_no_new_active_buttons_or_data_leaks(self):
        for p in (BUTTON,BRIDGE):
            s=p.read_text()
            for active in ("FireServer","InvokeServer","PostAsync","game:HttpGet(",
                           "setclipboard(", "getgenv("):
                self.assertNotIn(active,s)
        host=HOST.read_text()
        self.assertEqual(host.count("supervisor.arm({"),1)
        self.assertEqual(host.count("ui.preview.Activated:Connect("),1)
        self.assertNotIn("native_market_inventory_offer_core.lua",host)
        self.assertNotIn("native_bilateral_attractiveness_shadow.lua",host)
        self.assertNotIn("native_c9_growth_first_preview.lua",host)

if __name__=="__main__":
    unittest.main()
