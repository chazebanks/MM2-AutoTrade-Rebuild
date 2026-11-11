"""Stage84 original Nov9 first-party publisher and fresh research-only source tests.

All real inputs are downloaded from immutable Git objects and SHA checked.
No live MM2 client access or price/trading permissions.
"""
from __future__ import annotations
import importlib.util
import json
import os
from pathlib import Path
import random
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
MOD=ROOT/"pdiddler/intelligence_lab/stage84_nov9_publisher_refresh.py"
SPEC=importlib.util.spec_from_file_location("stage84_refresh",MOD)
m=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(m)

class Stage84(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  # Stage69 receipt binds the *relative checkout path*, not a resolved absolute.
  cls.sources=Path("pdiddler/research_source_html/stage84_2026_11_09")
  cls.manifest=cls.sources/"source_manifest.json"
  must=("STAGE84_REVIEWED_PARSER","STAGE84_MANIFEST_READER","STAGE84_ROSTER")
  if any(not os.environ.get(k) for k in must):
   if os.environ.get("STAGE84_REQUIRE_PINNED")=="1":
    raise AssertionError("CI must bind original Stage69 parser/reader and old roster")
   cls.filenames=None
   return
  cls.filenames=tuple(Path(os.environ[k]) for k in must)
  cls.receipt=json.loads(cls.manifest.read_text())
  cls.observed_epoch=max(int(__import__("datetime").datetime.fromisoformat(
        row["observedAt"].replace("Z","+00:00")).timestamp()) for row in cls.receipt["items"])

 def data(self):
  if self.filenames is None:
   self.skipTest("only dedicated workflow has original three source files")
  return self.filenames

 def load(self,when=None):
  parser,reader,roster=self.data()
  return m.load_inputs(self.sources,self.manifest,parser,reader,roster,
                       now_epoch=self.observed_epoch+30 if when is None else when)

 def no_authority(self,out):
  self.assertIs(out["researchOnly"],True)
  self.assertEqual(out["tradeOutcome"],"UNKNOWN")
  for name in (
    "authorizesTrade","authorizesAccept","autoDeploy","liveReady",
    "currentPricesVerified","numericSupremeCheckerIdVerified",
    "authenticatedOwnedInventory","serverAttestation","serverCompletionProven",
    "mayRecordCompletedTrade","mayReportProfit","maySendDiscordWebhook",
    "mayUseForStrategyLearning","rawGameMappingsVerified",
  ):
   self.assertIs(out[name],False,name)
  for row in out["rows"]:
   self.assertIs(row["verified"],False)
   self.assertIs(row["rawGameMappingVerified"],False)
   self.assertIs(row["priceForTradeVerified"],False)
   self.assertIs(row["sourceRecordMatched"],True)

 def test_real_three_newly_published_sources_reconcile_190_records(self):
  out=self.load()
  self.assertEqual(out["publishedAt"],"2026-11-09T18:58:33Z")
  self.assertEqual(out["coverage"],{
   "ancient":16,"godly":128,"chroma":46,"total":190,"finite":189,"unpriced":1})
  self.assertEqual(out["expiresAt"],"2026-11-10T22:26:48Z")
  self.assertEqual(out["stage84Schema"],m.SCHEMA)
  self.assertEqual(len(out["sources"]),3)
  self.assertTrue(out["publisherWithin72HoursAtAcquisition"])
  self.no_authority(out)

 def test_values_have_genuine_new_published_changes(self):
  out=self.load()
  diff=out["publishedSourceChangeCounts"]
  self.assertGreater(diff["valueChanged"],0)
  self.assertGreater(diff["priceIncreased"]+diff["priceDecreased"],0)
  self.assertLessEqual(diff["priceIncreased"]+diff["priceDecreased"],diff["valueChanged"])
  ancient={x["name"]:x for x in out["rows"] if x["page"]=="ancient"}
  self.assertEqual(ancient["Gingerscope"]["supremeValue"],16000)
  self.assertEqual(ancient["Emberbow"]["supremeValue"],650)
  self.assertEqual(ancient["Harvester"]["supremeValue"],260)
  self.no_authority(out)

 def test_all_three_source_publisher_dates_and_receipts_identical(self):
  p=sorted(x["page"] for x in self.receipt["items"])
  self.assertEqual(p,["ancient","chroma","godly"])
  for item in self.receipt["items"]:
   self.assertEqual(item["sourcePublisherIso"],"2026-11-09T13:58:33-05:00")
   self.assertEqual(item["sourceGitBlobSha"],m.NEW_BLOBS[item["page"]])
   self.assertGreater(item["bytesUtf8"],25000)
   self.assertTrue(item["scrapeId"])
  out=self.load()
  pubs={x["publishedAt"] for x in out["sources"].values()}
  self.assertEqual(pubs,{"2026-11-09T18:58:33Z"})

 def test_first_expiry_boundary_is_retrieval_24h_not_publisher_72h(self):
  good=self.load(when=self.observed_epoch+86399)
  self.assertEqual(good["publishedAt"],"2026-11-09T18:58:33Z")
  self.no_authority(good)
  with self.assertRaises(ValueError):
   self.load(when=self.observed_epoch+86400)
  with self.assertRaises(ValueError):
   self.load(when=self.observed_epoch+72*3600)

 def test_old_roster_and_reviewed_parser_sources_are_immutable(self):
  parser,reader,roster=self.data()
  self.assertEqual(m.blobsha(parser.read_bytes()),m.ORIGINAL_BLOBS["parser"])
  self.assertEqual(m.blobsha(reader.read_bytes()),m.ORIGINAL_BLOBS["manifestReader"])
  self.assertEqual(m.blobsha(roster.read_bytes()),m.ORIGINAL_BLOBS["oldRoster"])
  self.no_authority(self.load())

 def test_source_receipt_tamper_rejected_even_with_current_timestamp(self):
  parser,reader,roster=self.data()
  with tempfile.TemporaryDirectory() as directory:
   source=Path(directory)
   for item in self.receipt["items"]:
    origin=self.sources/Path(item["path"]).name
    (source/origin.name).write_bytes(origin.read_bytes())
   dest=source/"source_manifest.json"
   forged=json.loads(self.manifest.read_text())
   # The strict reader binds page receipt paths to this intentional test folder.
   for item in forged["items"]:
    item["path"]=str(source/Path(item["path"]).name)
   forged["items"][0]["sourcePublisherIso"]="2026-11-10T13:58:33-05:00"
   dest.write_text(json.dumps(forged))
   with self.assertRaises(ValueError):
    m.load_inputs(source,dest,parser,reader,roster,now_epoch=self.observed_epoch+60)
   forged=json.loads(self.manifest.read_text())
   for item in forged["items"]:
    item["path"]=str(source/Path(item["path"]).name)
   forged["items"][0]["bytesUtf8"]+=1
   dest.write_text(json.dumps(forged))
   with self.assertRaises(ValueError):
    m.load_inputs(source,dest,parser,reader,roster,now_epoch=self.observed_epoch+60)

 def test_400_mutated_real_original_source_bytes_never_match_pins(self):
  self.data()
  rng=random.Random(8405)
  pages={
   "ancient":(self.sources/"ancients.html").read_bytes(),
   "godly":(self.sources/"godlies.html").read_bytes(),
   "chroma":(self.sources/"chromas.html").read_bytes(),
  }
  counts={"ancient":0,"godly":0,"chroma":0}
  for i in range(400):
   page=("ancient","godly","chroma")[i%3]
   data=pages[page]
   offset=rng.randrange(len(data))
   change=bytes([data[offset]^1])
   corrupted=data[:offset]+change+data[offset+1:]
   self.assertNotEqual(m.blobsha(corrupted),m.NEW_BLOBS[page])
   counts[page]+=1
  self.assertEqual(sum(counts.values()),400)

 def test_no_client_remote_no_runtime_authority_no_mutable_page_scrape(self):
  s=MOD.read_text()
  for needle in ("FireServer(","InvokeServer(","GetProfileData(","setclipboard(",
                 "TeleportService","requests.get(","urlopen("):
   self.assertNotIn(needle,s)
  self.assertIn("priceForTradeVerified",s)
  self.assertIn("authorizesTrade",s)
  self.assertIn("sourceGitBlobSha",s)

if __name__=="__main__":
 unittest.main()
