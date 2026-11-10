"""Stage102: deterministically export 189 original Stage94 public records as
a minimal Lua-readable archival catalogue (JSON).

Input: exact original 15 pinned game/Supreme source files plus unchanged
Stage94 join and Stage101 source/digest validation in CI. No current prices,
server identity, ownership, real trade authorizations, or API calls.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from pdiddler.intelligence_lab.stage94_public_source_join import join_public_sources
from pdiddler.intelligence_lab.stage101_offer_public_value_preview import (
    _source as verify_original_stage94, ORIGINAL_STAGE94_ROWS_SHA256
)

SCHEMA="gingerscope-stage102-pinned-public-name-value-archive-v1"
PUBLISHED="2026-11-09T18:58:33Z"
EXPIRES="2026-11-10T22:26:48Z"
OUTPUT=Path("pdiddler/intelligence_lab/stage102_pinned_public_reference_2026_11_09.json")
EVAL_EPOCH=1794280000

def build() -> dict:
    # Existing Stage94 test loader checks all 15 exact original Git blobs,
    # reconstructs Stage82 historic website and Stage84 new publication.
    from pdiddler.tests.test_stage94_public_source_join import ActualOriginalPublicSourceJoin
    ActualOriginalPublicSourceJoin.setUpClass()
    fixture=ActualOriginalPublicSourceJoin
    source=join_public_sources(fixture.old,fixture.new,
                               fixture.newSiteSlugs,at_epoch=EVAL_EPOCH)
    assert source["status"]=="PUBLIC_RESEARCH_JOIN_READY",source.get("reason")
    rows,status=verify_original_stage94(source,EVAL_EPOCH)
    assert status=="HISTORICAL_RESEARCH_WITHIN_CAPTURE_WINDOW"
    assert len(rows)==189
    archival_rows=[
        {
            "label":row["publicItemName"],
            "category":row["page"],
            "chroma":row["page"]=="chroma",
            "value":row["researchSourceValue"],
            "demand":row["researchDemand"],
            "stability":row["researchStability"],
        } for row in rows
    ]
    assert len(archival_rows)==189
    assert all("raw" not in str(k).lower() and "checker" not in str(k).lower()
               for row in archival_rows for k in row)
    archive={
      "schema":SCHEMA,
      "publishedAt":PUBLISHED,
      "expiresAt":EXPIRES,
      "origin":"ORIGINAL_STAGE94_PUBLIC_RESEARCH_ONLY",
      "originalJoinedRowsSha256":ORIGINAL_STAGE94_ROWS_SHA256,
      "entryCount":189,
      "categoryCounts":{"ancient":15,"godly":128,"chroma":46},
      "currentPricesVerified":False,
      "priceForTradeVerified":False,
      "rawOfferKeyBoundToPhysicalSlot":False,
      "numericSupremeCheckerIdVerified":False,
      "mayReportProfit":False,
      "authorizesTrade":False,
      "authorizesAccept":False,
      "serverCompletionProven":False,
      "rows":archival_rows,
    }
    return archive

def encode(archive:dict)->bytes:
    return (json.dumps(archive,sort_keys=True,ensure_ascii=True,
                       separators=(",",":"))+"\n").encode("utf-8")

def main()->None:
    parser=argparse.ArgumentParser()
    parser.add_argument("--emit",action="store_true",
                        help="Emit a bounded single-line JSON in GitHub Actions logs")
    parser.add_argument("--verify-existing",action="store_true")
    args=parser.parse_args()
    original=build()
    raw=encode(original)
    sha=hashlib.sha256(raw).hexdigest()
    print("STAGE102_ORIGINAL_PUBLIC_ARCHIVE_SHA256="+sha)
    print("STAGE102_ARCHIVE_BYTES="+str(len(raw)))
    assert len(raw)<52000
    if args.verify_existing and OUTPUT.exists():
        assert OUTPUT.read_bytes()==raw,"Committed archive diverges from pinned original sources"
        print("STAGE102_COMMITTED_ARCHIVE_EQUALS_ORIGINAL_189_SOURCE_ROWS")
    if args.emit:
        print("STAGE102_EXPORT_JSON_START")
        print(raw.decode("utf-8").rstrip("\n"))
        print("STAGE102_EXPORT_JSON_END")
    print("STAGE102_REPRODUCIBLE_RESEARCH_ARCHIVE_VALID_189")

if __name__=="__main__":
    main()
