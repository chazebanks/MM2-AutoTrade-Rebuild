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
 return hashlib.sha1(b"blob "+str(len(b)).encode()+b"\0"+b).hexdigest()
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
  self.assertIn('catalog.sourceCapturedUtc=="'+CAPTURE+'"',c)
  self.assertIn('local CATALOG_SHA256="'+SHA256+'"',b)
  self.assertIn('local SOURCE_GIT_BLOB="'+BLOB+'"',b)
  self.assertIn("activeCapture=1794951678",b)
  self.assertIn("math.floor(fresh-activeCapture)",b)
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


 def test_protected_c3p4_native_fixture_uses_exact_renewal_and_rejects_old(self):
  # An independently verified archive must not be silently passed to the new
  # native adapter just because its 189 logical item rows did not change.
  mock=(P/"ci/system2_supreme_only_protected_c3p4_nov17_mocks.luau").read_text()
  self.assertNotEqual(hashlib.sha256(ORIGINAL.read_bytes()).hexdigest(),SHA256)
  self.assertEqual(hashlib.sha256(NEW.read_bytes()).hexdigest(),SHA256)
  self.assertIn('local sourceBytes=fs.readFile(root.."'+NEW.name+'")',mock)
  self.assertIn('local SOURCE_SHA256="'+SHA256+'"',mock)
  self.assertIn('local SOURCE_PIN="'+BLOB+'"',mock)
  self.assertIn('local CAPTURE=1794951678',mock)
  self.assertIn('local CLOCK=CAPTURE+30',mock)
  self.assertIn('clock=CAPTURE+21601',mock)
  self.assertIn('sourceStatus(catalog,SOURCE_PIN,CLOCK)',mock)
  self.assertIn('local legacySourceBytes=fs.readFile(root.."'+ORIGINAL.name+'")',mock)
  self.assertIn('sourceBytes=legacySourceBytes',mock)
  self.assertIn('eq(legacyWhy,"SUPREME_ONLY_SOURCE_SHA256_VERIFICATION_FAILED"',mock)
  self.assertIn('sourceBytes=serde.encode("json",injected)',mock)
  self.assertNotIn('local CLOCK=1794924441.0',mock)
  self.assertNotIn('local SOURCE_SHA256="48107d3039caf620bcad2c08831c9ca7fe206780dfb0e2d96d8161e3c9210f4a"',mock)

NOV25=P/"system2/supreme_only_189_research_catalog_2026_11_25_publication_nov23.json"
NOV25_BLOB="b6f5c1eec48d59b422f53baa4d83a54ce6837b72"

class SupremeNov25Archive(unittest.TestCase):
 def test_exact_new_archive_and_prior_identity(self):
  from collections import Counter
  raw=NOV25.read_bytes()
  self.assertEqual(blob(raw),NOV25_BLOB)
  current=json.loads(raw)
  prior=load(NEW)
  self.assertEqual(current["priorResearchCatalogGitBlob"],blob(NEW.read_bytes()))
  self.assertEqual(current["valueSource"],"SUPREME_ONLY")
  self.assertEqual(len(current["rows"]),189)
  self.assertEqual(len({r["rawGameKeyCandidate"] for r in current["rows"]}),189)
  self.assertEqual(Counter(r["category"] for r in current["rows"]),current["categories"])
  self.assertEqual(current["categories"],{"ancient":15,"godly":128,"chroma":46})
  self.assertEqual(len({(r["category"],r["officialItemId"]) for r in current["rows"]}),189)
  price_fields={"supremeListed","supremeDemand","supremeStability"}
  for a,b in zip(prior["rows"],current["rows"],strict=True):
   self.assertEqual({k:v for k,v in a.items() if k not in price_fields},
                    {k:v for k,v in b.items() if k not in price_fields})
   self.assertIs(type(b["supremeListed"]),int)
   self.assertGreater(b["supremeListed"],0)
   self.assertTrue(b["supremeDemand"].isdigit())
   self.assertIn(int(b["supremeDemand"]),range(12))
   self.assertTrue(b["supremeStability"])
  self.assertEqual([r["rawGameKeyCandidate"] for r in current["rows"]
                    if r["outgoingGingerscopeProtected"]],["Gingerscope"])

 def test_publication_change_counts_and_selected_market_values(self):
  prior,current=load(NEW),load(NOV25)
  fields={"supremeListed":"changedValueRows","supremeDemand":"changedDemandRows",
          "supremeStability":"changedStabilityRows"}
  pairs=list(zip(prior["rows"],current["rows"],strict=True))
  self.assertEqual(sum(a!=b for a,b in pairs),34)
  self.assertEqual(current["changedRows"],34)
  for field,count_key in fields.items():
   self.assertEqual(sum(a[field]!=b[field] for a,b in pairs),current[count_key])
  self.assertEqual([current[k] for k in fields.values()],[32,10,19])
  self.assertEqual(current["publisherUpdatedAt"],"2026-11-23T19:13:44-05:00")
  self.assertIs(current["originalPublisherEditionUnchanged"],False)
  index={r["rawGameKeyCandidate"]:r for r in current["rows"]}
  for key,value in {"Gingerscope":16000,"Harvester":310,"Icepiercer":220,
                    "Celestial":2025,"Emberbow":575,"VampireAxe":1100}.items():
   self.assertEqual(index[key]["supremeListed"],value)

 def test_capture_receipts_and_conservative_six_hour_expiry(self):
  import uuid
  data=load(NOV25)
  self.assertEqual(set(data["pageEvidence"]),{"home","ancient","godly","chroma"})
  times=[]
  for page in data["pageEvidence"].values():
   ident=uuid.UUID(page["scrapeId"])
   self.assertEqual(ident.version,7)
   stamp=datetime.fromtimestamp((ident.int>>80)/1000,timezone.utc)
   self.assertEqual(stamp,datetime.fromisoformat(page["scrapeIdUtc"]))
   self.assertEqual(page["sourceStatus"],200)
   self.assertEqual(page["transport"],"FIRECRAWL_MEDIATED_HTTPS")
   self.assertGreater(page["sourceHtmlCharacterCount"],1000)
   times.append(stamp)
  captured=datetime.fromisoformat(data["sourceCapturedUtc"])
  expiry=datetime.fromisoformat(data["sourceExpiresUtc"])
  self.assertEqual(captured,min(times).replace(microsecond=0))
  self.assertLess(max(times)-min(times),timedelta(minutes=2))
  self.assertEqual(expiry-captured,timedelta(hours=6))
  self.assertEqual(data["sourceMaxAgeSeconds"],21600)
  self.assertLess(datetime.fromisoformat(data["publisherUpdatedAt"]),captured)

 def test_precise_exclusions_and_research_authority_boundary(self):
  data=load(NOV25); pages=data["pageEvidence"]
  self.assertEqual([pages[k]["publisherItemcolumnCards"] for k in
                    ("ancient","godly","chroma")],[16,130,53])
  self.assertEqual(pages["ancient"]["unpricedCardNames"],["Nik's Scythe"])
  self.assertEqual(set(pages["godly"]["excludedCardIds"]),{"Batwing","Black_Luger"})
  self.assertEqual(set(pages["chroma"]["excludedCardIds"]),
                   {"CBat","CBear","CBunny","CCat","CDog","CFox","CPig"})
  self.assertIs(data["sourceResearchOnly"],True)
  for flag in ("publisherSigned","rawHtmlArchived","exactRobloxItemInstanceVerified",
               "currentInventoryVerified","liveTradePricingAuthorized","authorizesTrade",
               "authorizesOffer","authorizesAccept","mayUseForStrategyLearning","mayReportProfit"):
   self.assertIs(data[flag],False)
  # The native core and read-only bridge now explicitly admit both exact
  # archived editions within their own clocks. Frozen launchers remain old.
  for p in (HOST,LOADER,REG):
   self.assertNotIn(NOV25.name,p.read_text())
   self.assertNotIn(NOV25_BLOB,p.read_text())
  for p in (CORE,BRIDGE):
   self.assertIn(NOV25_BLOB,p.read_text())
  self.assertIn("1795586999",CORE.read_text())
  self.assertIn("1795586999",BRIDGE.read_text())
  self.assertEqual(hashlib.sha256(NOV25.read_bytes()).hexdigest(),
                   "3f0996b9ac20f3c4689519e1faf65e83796bce8b2d6afe6ad4d2e705ffca525e")

if __name__=="__main__":unittest.main()
