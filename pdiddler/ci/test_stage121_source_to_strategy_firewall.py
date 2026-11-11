"""Source-bound Stage121 tests: real original Stage111 -> Stage110 -> Stage104 -> Stage69.

Fetch exact historical source files in CI, mock only HTTPS transport to
exercise ACTUAL original frozen source-admission code, then test new firewall.
No fake publisher promotion and no MM2 trade authority.
"""
from __future__ import annotations
import copy
from datetime import datetime, timezone
import hashlib
import importlib
import os
from pathlib import Path
import unittest

from pdiddler.intelligence_lab import stage121_source_to_strategy_firewall as M

ROOT=Path(os.getenv("STAGE121_ORIGINAL_ROOT","/not/present"))
DATA={
 "ancient":("ancients.html","https://supremevalues.com/mm2/ancients",
            "ce8178ab9579e8782d8f72a6dac051756a728506"),
 "godly":("godlies.html","https://supremevalues.com/mm2/godlies",
          "d3cf222a8e10cff3a9fb051b16188192389c4b2d"),
 "chroma":("chromas.html","https://supremevalues.com/mm2/chromas",
           "6c77624cac3df96168b008e9bc8eca68a2d78cf9"),
}
OLD="2026-11-09T13:58:33-05:00"
NEW="2026-11-10T13:58:33-05:00"
NOV11="2026-11-11T17:30:00Z"
NOV10="2026-11-10T14:30:00Z"

def blob(data):
    return hashlib.sha1(b"blob "+str(len(data)).encode()+b"\0"+data).hexdigest()

class Resp:
    def __init__(self,url,data):
        self.url=url;self.status_code=200
        self.headers={"Content-Type":"text/html","Content-Length":str(len(data))}
        self.data=data
    def iter_content(self,chunk_size=32768):
        for i in range(0,len(self.data),chunk_size):
            yield self.data[i:i+chunk_size]
    def close(self):
        pass

class Session:
    def __init__(self,sources):
        self.sources=sources
    def get(self,url,**kwargs):
        assert kwargs.get("verify") is True
        assert kwargs.get("allow_redirects") is False
        assert kwargs.get("stream") is True
        if url not in self.sources:raise OSError("missing")
        return Resp(url,self.sources[url])

class OriginalStage121(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if os.getenv("STAGE121_REQUIRE_ORIGINAL")!="1":
            raise unittest.SkipTest("original source pin job required")
        parser=(ROOT/"stage69_parser.py").read_bytes()
        assert blob(parser)=="d5843a57f34078cbe7213aa78a4aa12a5775c016"
        cls.parser=parser
        cls.prior={}
        for name,(filename,url,sha) in DATA.items():
            c=(ROOT/filename).read_bytes()
            assert blob(c)==sha
            cls.prior[name]=c
        cls.stage111=importlib.import_module(
          "pdiddler.intelligence_lab.stage111_supreme_readonly_capture")

    def manifest(self,*,at=NOV11,changed=False):
        data={}
        for k,(_,url,_) in DATA.items():
            b=self.prior[k]
            if changed:b=b.replace(OLD.encode(),NEW.encode())
            data[url]=b
        return self.stage111.collect_and_admit(
            Session(data),parser_bytes=self.parser,prior_html=self.prior,
            clock=lambda:at)

    def eval(self,manifest=None,now=NOV11,**extra):
        r=M.assess(self.manifest() if manifest is None else manifest,
                   evaluated_utc=now,**extra)
        for field,value in M.FALSE.items():
            self.assertEqual(r.get(field),value,(field,r))
        self.assertEqual(r["tradeOutcome"],"UNKNOWN")
        self.assertNotIn("currentPrice",r)
        self.assertNotIn("weaponKey",r)
        return r

    def test_original_frozen_source_is_not_homegrown_stub(self):
        self.assertEqual(self.stage111.PARSER_GIT_BLOB,
                         "d5843a57f34078cbe7213aa78a4aa12a5775c016")
        self.assertEqual(self.stage111.PINNED_PRIOR_GIT_BLOBS,
             {k:sha for k,(_,_,sha) in DATA.items()})

    def test_real_original_nov9_capture_stale_on_nov11(self):
        m=self.manifest()
        self.assertEqual(m["status"],"NO_NEW_PUBLISHER_PUBLICATION",m)
        self.assertTrue(m["admission"]["exactOriginalParserBlobVerified"])
        self.assertTrue(m["admission"]["exactPinnedPriorHtmlVerified"])
        r=self.eval(m)
        self.assertEqual(r["status"],"BLOCKED")
        self.assertEqual(r["reason"],"OLD_PUBLICATION_FIXED_EXPIRY_PASSED")
        self.assertEqual(r["sourcePublisherUtc"],"2026-11-09T18:58:33Z")

    def test_previously_current_archival_reference_still_no_offer_authority(self):
        m=self.manifest(at=NOV10)
        r=self.eval(m,now=NOV10)
        self.assertEqual(r["status"],"RESEARCH_ONLY",r)
        self.assertEqual(r["reason"],"NO_NEW_PUBLICATION_KEEP_EXISTING_EXPIRY")
        self.assertFalse(r["mayFeedStage120AsVerifiedMarket"])

    def test_fake_updated_publisher_still_research_only(self):
        m=self.manifest(at="2026-11-10T20:00:00Z",changed=True)
        self.assertEqual(m["status"],"NEW_PUBLISHER_CANDIDATE_REVIEW_REQUIRED",m)
        r=self.eval(m,now=NOV11)
        self.assertEqual(r["status"],"RESEARCH_ONLY")
        self.assertEqual(r["reason"],"NEW_PUBLISHER_REQUIRES_INDEPENDENT_REVIEW")
        self.assertFalse(r["publishedCurrentPriceAuthenticated"])

    def test_new_aggregator_import_timestamp_never_revalidates_source(self):
        aggregator={"source":"mm2values.app","sourceListRebuiltAtUtc":NOV11,
                    "claimsSource":"Supreme Values","fakePrices":{"Harvester":250}}
        r=self.eval(candidate_market=aggregator)
        self.assertEqual(r["reason"],"UNVERIFIED_PRICE_INPUT_CANNOT_PROMOTE_RESEARCH")
        self.assertFalse(r["marketSourceUsableForLiveOffer"])

    def test_posted_trades_not_confirmed_completed_fills(self):
        r=self.eval(trade_activity={"postedOffers":4000,"tradesAccepted":None})
        self.assertEqual(r["reason"],"TRADE_POSTINGS_ARE_NOT_VERIFIED_COMPLETED_FILLS")
        self.assertFalse(r["observedCompletedTradeLiquidityVerified"])

    def test_source_manifest_cannot_self_claim_market_authority(self):
        m=self.manifest()
        m["admission"]["currentPricesVerified"]=True
        self.assertEqual(self.eval(m)["reason"],"STAGE110_DENIED_AUTHORITY_CONTRACT_CHANGED")
        m=self.manifest()
        m["admission"]["authorizesAccept"]=True
        self.assertEqual(self.eval(m)["reason"],"STAGE110_DENIED_AUTHORITY_CONTRACT_CHANGED")
        m=self.manifest()
        m["mayUpdateProduction"]=True
        self.assertEqual(self.eval(m)["reason"],"STAGE111_DENIED_AUTHORITY_CONTRACT_CHANGED")
        m=self.manifest()
        m["admission"]["newCaptureExpiryUtc"]=NOV11
        self.assertEqual(self.eval(m)["reason"],"ORIGINAL_EXPIRY_ILLEGITIMATELY_EXTENDED")

    def test_digest_or_url_or_category_integrity(self):
        for change in ("url","sha","bytecount","missing"):
            with self.subTest(change=change):
                m=self.manifest()
                if change=="url":m["capturedSources"]["chroma"]["url"]="https://supremevalues.com/mm2/chromas.php"
                if change=="sha":m["capturedSources"]["godly"]["sha256"]="0"*22
                if change=="bytecount":m["capturedSources"]["ancient"]["rawHtmlByteCount"]=0
                if change=="missing":del m["capturedSources"]["chroma"]
                r=self.eval(m)
                self.assertEqual(r["status"],"BLOCKED")

    def test_publisher_source_consistency(self):
        m=self.manifest()
        m["admission"]["rawPagePublishedDates"]["ancient"]="2030-01-01T00:00:00Z"
        self.assertEqual(self.eval(m)["reason"],"MIXED_OR_MISSING_PUBLISHER_DATES")
        m=self.manifest()
        m["admission"]["observedPublisherUtc"]="2026-11-10T18:58:33Z"
        self.assertEqual(self.eval(m)["reason"],"PUBLISHER_DATE_NOT_SOURCE_BOUND")

    def test_forged_source_status_mismatch(self):
        m=self.manifest()
        m["status"]="NEW_PUBLISHER_CANDIDATE_REVIEW_REQUIRED"
        self.assertEqual(self.eval(m)["reason"],"SOURCE_ADMISSION_STATUS_MISMATCH")
        m=self.manifest()
        m["admission"]["status"]="NEW_PUBLISHER_CANDIDATE_REVIEW_REQUIRED"
        m["status"]="NEW_PUBLISHER_CANDIDATE_REVIEW_REQUIRED"
        self.assertEqual(self.eval(m)["reason"],"UNCHANGED_PUBLISHER_STATUS_CONTRADICTION")

    def test_bad_clock_and_future_capture(self):
        self.assertEqual(self.eval(now="Nov 11 2026")["reason"],
                         "EVALUATION_CLOCK_INVALID")
        m=self.manifest()
        m["capturedSources"]["godly"]["retrievedAtUtc"]="2034-01-01T00:00:00Z"
        self.assertEqual(self.eval(m)["reason"],
                         "CANONICAL_CAPTURE_CLOCK_OUT_OF_RANGE")

    def test_incomplete_capture_not_pretend_ready(self):
        m=self.manifest()
        m["captureCompleteness"]="INCOMPLETE_CAPTURE"
        self.assertEqual(self.eval(m)["reason"],"THREE_CANONICAL_CAPTURE_REQUIRED")
        self.assertEqual(self.eval({})["reason"],"STAGE111_SOURCE_CAPTURE_MISSING")

    def test_actual_stage111_declines_php_redirect_already(self):
        s=Session({url:self.prior[k] for k,(_,url,_) in DATA.items()})
        data=s.sources.pop(DATA["chroma"][1])
        s.sources["https://supremevalues.com/mm2/chromas.php"]=data
        m=self.stage111.collect_and_admit(
            s,parser_bytes=self.parser,prior_html=self.prior,
            clock=lambda:NOV11)
        self.assertEqual(m["status"],"INCONCLUSIVE")
        self.assertEqual(self.eval(m)["status"],"BLOCKED")

    def test_400_mutated_original_receipts_never_enable_strategy(self):
        base=self.manifest()
        for i in range(400):
            m=copy.deepcopy(base)
            if i%7==0:m["capturedSources"]["ancient"]["sha256"]="f"*64
            elif i%7==1:m["capturedSources"]["godly"]["httpStatus"]=302
            elif i%7==2:m["admission"]["externalCaptureAuthenticated"]=True
            elif i%7==3:m["admission"]["newResearchDatasetPublished"]=True
            elif i%7==4:m["admission"]["observedPublisherUtc"]="2026-11-10T18:58:33Z"
            elif i%7==5:m["capturedSources"]["chroma"]["url"]="http://supremevalues.com/mm2/chromas"
            else:m["admission"]["rawPagePublishedDates"]["chroma"]="2026-11-08T18:58:33Z"
            r=self.eval(m)
            self.assertFalse(r["authorizesAccept"])
            self.assertFalse(r["mayFeedStage120AsVerifiedMarket"])

    def test_stage120_gate_remains_synthetic_only(self):
        from pdiddler.intelligence_lab import stage120_corrected_guard_preview as s
        self.assertEqual(s.MARKET_VERSION,"SYNTHETIC-STAGE120-V1")
        self.assertFalse(s.FLAGS["verifiedMarketQuote"])
        self.assertFalse(s.FLAGS["authorizesTrade"])
        self.assertFalse(s.FLAGS["authorizesAccept"])

if __name__=="__main__":unittest.main()
