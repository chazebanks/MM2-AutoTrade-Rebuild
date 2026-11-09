"""Stage84 strict RESEARCH-ONLY refresh of Nov9 Supreme publisher records.

Never checks a game profile, trades, requests, price-authorizes, or sends Discord.
Consumes Firecrawl HTML (not origin-signed) bound to exact Git blobs and observed
timestamps, using byte-verified OWN Stage69 parser and provenance reader.
"""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import time

SCHEMA="gingerscope-stage84-new-first-party-publication-research-only-v1"
PUBLISHER="2026-11-09T18:58:33Z"
PAGE_COUNTS={"ancient":16,"chroma":46,"godly":128}
ORIGINAL_BLOBS={
 "parser":"d5843a57f34078cbe7213aa78a4aa12a5775c016",
 "manifestReader":"9b6faa9f7a9890d69635542529703fedc8e4d55f",
 "oldRoster":"a85af4f6137278540e1fed0c27e7e801553e4111",
}
NEW_BLOBS={
 "ancient":"ce8178ab9579e8782d8f72a6dac051756a728506",
 "godly":"d3cf222a8e10cff3a9fb051b16188192389c4b2d",
 "chroma":"6c77624cac3df96168b008e9bc8eca68a2d78cf9",
}

def blobsha(b:bytes)->str:
 return hashlib.sha1(b"blob "+str(len(b)).encode("ascii")+b"\0"+b).hexdigest()

def checked_module(path:Path, expected_sha:str, name:str):
 b=path.read_bytes()
 if blobsha(b)!=expected_sha:
  raise ValueError("REVIEWED_OWN_MODULE_BLOB_CHANGED:"+name)
 spec=importlib.util.spec_from_file_location(name,path)
 if spec is None or spec.loader is None:
  raise ValueError("OWN_MODULE_UNAVAILABLE:"+name)
 obj=importlib.util.module_from_spec(spec)
 spec.loader.exec_module(obj)
 return obj

def load_inputs(source_dir:Path, manifest_path:Path, parser_path:Path,
                manifest_reader_path:Path, roster_path:Path, *,
                now_epoch:int|None=None):
 parser=checked_module(parser_path,ORIGINAL_BLOBS["parser"],"checked_stage69_parser")
 reader=checked_module(manifest_reader_path,ORIGINAL_BLOBS["manifestReader"],"checked_stage69_receipt")
 if blobsha(roster_path.read_bytes())!=ORIGINAL_BLOBS["oldRoster"]:
  raise ValueError("OLD_ROSTER_CHANGED")
 now=int(time.time()) if now_epoch is None else now_epoch
 imported=reader.read_manifest(manifest_path,source_dir,now_epoch=now)
 pages={};sources={}
 for page,slug in parser.PAGES.items():
  original=imported[page]
  raw=original["content"]
  if blobsha(raw)!=NEW_BLOBS[page]:
   raise ValueError("NEW_ORIGINAL_HTML_BLOB_CHANGED:"+page)
  if original["publisher"]!="2026-11-09T13:58:33-05:00":
   raise ValueError("PUBLISHER_DATE_DRIFT:"+page)
  parsed,published=parser.parse_page(raw.decode("utf-8"),page)
  if published!=PUBLISHER or len(parsed)!=PAGE_COUNTS[page]:
   raise ValueError("NEW_SOURCE_PUBLICATION_OR_COUNT_MISMATCH:"+page)
  observed=original["observedAtEpoch"]
  if observed<parser.epoch(PUBLISHER) or observed>now:
   raise ValueError("SOURCE_OBSERVATION_DATE_INVALID")
  pages[page]=parsed
  sources[page]={
   "url":"https://supremevalues.com/mm2/"+slug,
   "observedAt":parser.iso(observed),
   "publishedAt":published,
   "sourceGitBlobSha":NEW_BLOBS[page],
   "sha256":hashlib.sha256(raw).hexdigest()
  }
 if len({s["publishedAt"] for s in sources.values()})!=1:
  raise ValueError("INCONSISTENT_SITE_PUBLICATION")
 mapping=parser.load_mapping(roster_path)
 if dict(Counter(x["page"] for x in mapping))!=PAGE_COUNTS:
  raise ValueError("CANONICAL_ROSTER_CATEGORY_MISMATCH")
 rows=parser.map_rows(mapping,pages)
 if len(rows)!=190 or any(x["sourceRecordMatched"] is not True for x in rows):
  raise ValueError("NEW_SOURCE_CANONICAL_ITEM_MISMATCH")
 original=json.loads(roster_path.read_text(encoding="utf-8"))
 old={(x["page"],x["name"].casefold()):x for x in original["rows"]}
 if len(old)!=190:
  raise ValueError("HISTORICAL_BASELINE_DUPLICATE")
 diff={"valueChanged":0,"demandChanged":0,"stabilityChanged":0,"priceIncreased":0,"priceDecreased":0}
 for row in rows:
  base=old[(row["page"],row["name"].casefold())]
  before,after=base.get("supremeValue"),row.get("supremeValue")
  if before!=after:
   diff["valueChanged"]+=1
   if before is not None and after is not None:
    diff["priceIncreased"]+=int(after>before)
    diff["priceDecreased"]+=int(after<before)
  diff["demandChanged"]+=int(base.get("demand")!=row.get("demand"))
  diff["stabilityChanged"]+=int(base.get("stability")!=row.get("stability"))
 expires=parser.expiry(sources)
 if now>=expires or expires<=parser.epoch(PUBLISHER):
  raise ValueError("NEW_SOURCE_ALREADY_EXPIRED")
 if diff["valueChanged"]==0:
  raise ValueError("NEW_PUBLISHER_DATE_WITHOUT_ANY_VALUE_CHANGE_REQUIRES_REVIEW")
 for row in rows:
  row.update({"verified":False,"rawGameMappingVerified":False,
              "priceForTradeVerified":False,"sourceRecordMatched":True})
 valid=next(x for x in rows if x["page"]=="ancient" and x["name"]=="Gingerscope")
 if valid["supremeValue"]!=16000:
  raise ValueError("NEW_GINGERSCOPE_SENTINEL_CHANGED")
 finite=sum(x["supremeValue"] is not None for x in rows)
 if finite!=189:
  raise ValueError("PRICLESS_FINITE_COUNT_CHANGED")
 snapshot={
  "schemaVersion":1,"stage84Schema":SCHEMA,
  "snapshotDate":"2026-11-09","publisherWithin72HoursAtAcquisition":True,
  "observedAt":min(s["observedAt"] for s in sources.values()),
  "publishedAt":PUBLISHER,"expiresAt":parser.iso(expires),
  "sources":sources,
  "coverage":{**PAGE_COUNTS,"total":190,"finite":finite,"unpriced":1},
  "publishedSourceChangeCounts":diff,
  "rows":rows,
  "researchOnly":True,"authorizesTrade":False,"authorizesAccept":False,
  "autoDeploy":False,"liveReady":False,
  "currentPricesVerified":False,"numericSupremeCheckerIdVerified":False,
  "authenticatedOwnedInventory":False,"serverAttestation":False,
  "serverCompletionProven":False,"mayRecordCompletedTrade":False,
  "mayReportProfit":False,"maySendDiscordWebhook":False,
  "mayUseForStrategyLearning":False,"tradeOutcome":"UNKNOWN",
  "sourceAcquisition":"Firecrawl rawHtml maxAge=0; original source not cryptographically origin-signed",
  "rawGameMappingsVerified":False
 }
 return snapshot

def main():
 ap=argparse.ArgumentParser()
 for field in ("source-dir","manifest","parser","manifest-reader","roster","output"):
  ap.add_argument("--"+field,required=True,type=Path)
 a=ap.parse_args()
 out=load_inputs(a.source_dir,a.manifest,a.parser,a.manifest_reader,a.roster)
 a.output.write_text(json.dumps(out,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
 print(json.dumps({"stage":"84","status":"NEW_PUBLISHED_SOURCE_RESEARCH_ONLY",
  "publishedAt":out["publishedAt"],"expiresAt":out["expiresAt"],
  "coverage":out["coverage"],"changed":out["publishedSourceChangeCounts"],
  "currentPricesVerified":False,"authorizesTrade":False},sort_keys=True))

if __name__=="__main__":
 main()
