"""Genuine publisher re-observation regression, research-only and non-executable.

This validates immutable archival research data and exact source code *pins*;
it does not authorize in-game trading or pretend a refreshed listing is a new
publisher edition. Actual Delta/Roblox native tests remain separately gated.
"""
from pathlib import Path
from datetime import datetime,timedelta,timezone
import hashlib,json,unittest

P=Path(__file__).resolve().parents[1]
ORIGINAL=P/"system2/supreme_only_189_research_catalog_2026_11_17_refresh.json"
NEW=P/"system2/supreme_only_189_research_catalog_2026_11_17_214118z_refresh.json"
CORE=P/"system2/native_supreme_only_bilateral_research_nov17.lua"
BRIDGE=P/"system2/native_supreme_only_protected_c3p4_adapter_nov17.lua"
HOST=P/"supervised/STAGE119_C9_SUPREME_ONLY_FIVE_SCENARIO_CLEAN_NATIVE.lua"
LOADER=P/"supervised/STAGE119_C9_SUPREME_ONLY_FIVE_SCENARIO_CLEAN_START.lua"
REG=P/"system2/SUPREME_ONLY_C9_SOURCE_PIN_REGISTRY_2026_11_17.json"
CAPTURE="2026-11-17T21:41:18Z"
EXPIRY="2026-11-18T03:41:18Z"
PUBLISHER="2026-11-15T11:59:41-05:00"
SHA256="fd657db48c00c996705093dadc384c1a0ddd4630398826108b5585ca76c2eca4"
BLOB="958038a6b22c43e8d0359cb15e6704bc84253430"

def blob(b):
 return hashlib.sha1(b"blob "+str(len(b)).encode()+b"\\0"+b).hexdigest()
def load(p): return json.loads(p.read_bytes())

class SupremeRefreshResearch(unittest.TestCase):
 def test_exact_new_immutable_bytes(self):
  raw=NEW.read_bytes()
  self.assertEqual(hashlib.sha256(raw).hexdigest(),SHA256)
  self.assertEqual(blob(raw),BLOB)
 def test_new_capture_is_not_falsified_new_publisher_edition(self):
  a,b=load(ORIGINAL),load(NEW)
  self.assertEqual(a["publisherUpdatedAt"],PUBLISHER)
  self.assertEqual(b["publisherUpdatedAt"],PUBLISHER)
  self.assertEqual(b["sourceCapturedUtc"],CAPTURE)
  self.assertIs(b["originalPublisherEditionUnchanged"],True)
  self.assertFalse(b["publisherSigned"])
  self.assertFalse(b["liveTradePricingAuthorized"])
  self.assertFalse(b["mayUseForStrategyLearning"])
  self.assertFalse(b["authorizesAccept"])
  self.assertEqual(b["rows"],a["rows"])
  self.assertEqual(b["categories"],{"ancient":15,"godly":128,"chroma":46})
  self.assertEqual(len(b["rows"]),189)
  self.assertEqual({r["rawGameKeyCandidate"] for r in b["rows"]},
                   {r["rawGameKeyCandidate"] for r in a["rows"]})
  protected=[r for r in b["rows"] if r["outgoingGingerscopeProtected"]]
  self.assertEqual([r["rawGameKeyCandidate"] for r in protected],["Gingerscope"])
 def test_scrape_receipts_all_four_and_16_130_53(self):
  data=load(NEW)
  pages=data["pageEvidence"]
  self.assertEqual(set(pages),{"home","ancient","godly","chroma"})
  self.assertEqual([pages[k]["publisherItemcolumnCards"] for k in
                    ("ancient","godly","chroma")],[16,130,53])
  for p in pages.values():
   self.assertEqual(p["sourceStatus"],200)
   self.assertEqual(p["transport"],"FIRECRAWL_MEDIATED_HTTPS")
   self.assertTrue(p["scrapeId"].startswith("01a1eb7"))
  self.assertEqual(data["sourceTransport"],"FIRECRAWL_MEDIATED_HTTPS_RESEARCH")
 def test_capture_window_exact_and_bounded(self):
  a=datetime.fromisoformat(CAPTURE.replace("Z","+00:00"))
  b=datetime.fromisoformat(EXPIRY.replace("Z","+00:00"))
  self.assertEqual(b-a,timedelta(hours=6))
  self.assertLess(datetime.fromisoformat(PUBLISHER),a)
  self.assertEqual(int(a.timestamp()),1794951678)
  self.assertEqual(int(b.timestamp()),1794973278)
 def test_only_single_supreme_source_in_runtime_code(self):
  h,s=HOST.read_text(),LOADER.read_text()
  c,b=CORE.read_text(),BRIDGE.read_text()
  self.assertEqual(h.count('local pin="06bddba07cad0e45fe37af47f84e0092c9bb1665"'),2)
  self.assertIn("supreme_only_189_research_catalog_2026_11_17_214118z_refresh.json",h)
  self.assertIn('local SOURCE_SHA="'+BLOB+'"',c)
  self.assertIn("local CAPTURE=1794951678",c)
  self.assertIn('catalog.sourceCapturedUtc~="'+CAPTURE+'"',c)
  self.assertIn('local CATALOG_SHA256="'+SHA256+'"',b)
  self.assertIn('local SOURCE_GIT_BLOB="'+BLOB+'"',b)
  self.assertIn("math.floor(fresh-1794951678)",b)
  self.assertIn("local captureUtc=1794951678",s)
  self.assertIn('local pinned="b87b2acb2c3228a2fa027b6a77904ce1fb38c474"',s)
  for part in (h,s,c,b):
   self.assertNotIn("MM2Values",part)
   self.assertNotIn("mm2values.com",part)
 def test_nonruntime_registry_pin_matches_frozen_source(self):
  m=load(REG)
  self.assertEqual(m["supremeCatalog"]["sha256"],SHA256)
  self.assertEqual(m["supremeCatalog"]["capturedUtc"],CAPTURE)
  self.assertEqual(m["supremeCatalog"]["absoluteExpiresUtc"],EXPIRY)
  self.assertEqual(m["supremeCatalog"]["file"],"pdiddler/"+NEW.relative_to(P).as_posix())
  self.assertEqual(m["dynamicFrozenGroups"][0]["commit"],
                   "06bddba07cad0e45fe37af47f84e0092c9bb1665")
  self.assertFalse(m["policy"]["automaticOffers"])
  self.assertFalse(m["policy"]["finalAccept"])

if __name__=="__main__":unittest.main()
