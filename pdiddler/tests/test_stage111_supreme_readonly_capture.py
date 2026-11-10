"""Stage111: actual Stage110 admission with a mocked HTTPS capture transport.

Real Stage69 parser, Stage84 original Nov9 HTML and Git SHA checks execute in
CI. NO actual Supreme HTTP calls in PR tests. Workflow never pushes a market
file, enables trade, or extends the captured 2026-11-10 source expiry.
"""
from __future__ import annotations
import copy
import hashlib
import importlib
import json
import os
from pathlib import Path
import tempfile
import unittest

URLS={
 "ancient":"https://supremevalues.com/mm2/ancients",
 "godly":"https://supremevalues.com/mm2/godlies",
 "chroma":"https://supremevalues.com/mm2/chromas",
}

def blob(raw):
    return hashlib.sha1(b"blob "+str(len(raw)).encode()+b"\0"+raw).hexdigest()


class FakeResponse:
    def __init__(self,url,data,status=200,ctype="text/html; charset=utf-8",
                 redirect=None,raise_stream=False):
        self.url=redirect or url
        self.status_code=status
        self.headers={"Content-Type":ctype,"Content-Length":str(len(data))}
        self.data=data
        self.raise_stream=raise_stream
        self.closed=False

    def iter_content(self,chunk_size):
        assert chunk_size>0
        for i in range(0,len(self.data),chunk_size):
            if self.raise_stream:
                raise IOError("simulated read disconnection")
            yield self.data[i:i+chunk_size]

    def close(self):
        self.closed=True


class FakeSession:
    def __init__(self,data):
        self.data=data
        self.queries=[]
        self.responses=[]

    def get(self,url,**kwargs):
        self.queries.append((url,kwargs))
        if url not in self.data:
            raise IOError("simulated service unavailable")
        response=self.data[url]
        self.responses.append(response)
        return response


class Stage111ArchivedSourceCaptureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if os.environ.get("STAGE111_REQUIRE_PINNED")!="1":
            raise unittest.SkipTest("pin exact Stage69 and three Stage84 originals")
        cls.m=importlib.import_module(
            "pdiddler.intelligence_lab.stage111_supreme_readonly_capture")
        cls.parser=Path(os.environ["STAGE111_ORIGINAL_PARSER"]).read_bytes()
        root=Path(os.environ["STAGE111_ORIGINAL_HTML_DIR"])
        cls.old={k:(root/(k+"s" if k!="chroma" else "chromas")).with_suffix(".html").read_bytes()
                 for k in ()}
        cls.old={k:(root/(f+".html")).read_bytes() for k,f in (
            ("ancient","ancients"),("godly","godlies"),("chroma","chromas"))}
        self_hashes={k:blob(v) for k,v in cls.old.items()}
        assert blob(cls.parser)=="d5843a57f34078cbe7213aa78a4aa12a5775c016"
        assert self_hashes=={
            "ancient":"ce8178ab9579e8782d8f72a6dac051756a728506",
            "godly":"d3cf222a8e10cff3a9fb051b16188192389c4b2d",
            "chroma":"6c77624cac3df96168b008e9bc8eca68a2d78cf9",
        }
    def session(self,old=None):
        data=self.old if old is None else old
        return FakeSession({URLS[k]:FakeResponse(URLS[k],v) for k,v in data.items()})

    def run(self,session=None,old=None,time="2026-11-10T14:00:00Z",
            parser=None,baseline=None,output=None):
        session=self.session(old) if session is None else session
        result=self.m.collect_and_admit(
            session,
            parser_bytes=self.parser if parser is None else parser,
            prior_html=self.old if baseline is None else baseline,
            clock=lambda:time,
            artifact_dir=output,
        )
        return result,session

    def denied(self,report):
        a=report["admission"]
        self.assertFalse(a["externalCaptureAuthenticated"])
        self.assertFalse(a["newResearchDatasetPublished"])
        self.assertIsNone(a["newCaptureExpiryUtc"])
        self.assertTrue(a["fixedPriorExpiryPreserved"])
        for key in ("authorizesTrade","authorizesAccept","mayReportProfit",
                    "maySendDiscordWebhook","currentPricesVerified",
                    "priceForTradeVerified","publisherRefreshApproved",
                    "rawGameWeaponKeyAuthenticated","serverCompletionProven"):
            self.assertFalse(a[key],key)
        self.assertEqual(a["tradeOutcome"],"UNKNOWN")
        self.assertFalse(report["mayUpdatePriceFiles"])
        self.assertFalse(report["mayUpdateProduction"])
        self.assertFalse(report["authenticatesExternalSource"])
        self.assertFalse(report["mayExtendOriginalCaptureExpiry"])

    def test_all_three_real_original_supreme_pages_archive_unchanged_no_market_update(self):
        with tempfile.TemporaryDirectory() as td:
            result,session=self.run(output=Path(td))
            self.assertEqual(result["status"],"NO_NEW_PUBLISHER_PUBLICATION",result)
            self.assertEqual(result["admission"]["rowChangeCount"],0)
            self.assertEqual(result["admission"]["observedPublisherUtc"],
                             "2026-11-09T18:58:33Z")
            self.assertEqual(set(result["capturedSources"]),set(URLS))
            self.denied(result)
            self.assertEqual(len(session.queries),3)
            for url,opts in session.queries:
                self.assertIn(url,URLS.values())
                self.assertIs(opts["verify"],True)
                self.assertIs(opts["allow_redirects"],False)
                self.assertIs(opts["stream"],True)
                self.assertIn("no-cache",opts["headers"]["Cache-Control"])
                self.assertEqual(opts["timeout"],(8,20))
            self.assertTrue(all(r.closed for r in session.responses))
            d=Path(td)
            self.assertEqual({p.name for p in d.iterdir()},
                             {"source_audit.json","source_ancient.html",
                              "source_godly.html","source_chroma.html"})
            saved=json.loads((d/"source_audit.json").read_text())
            self.assertEqual(saved["status"],result["status"])
            for category,raw in self.old.items():
                self.assertEqual((d/("source_"+category+".html")).read_bytes(),raw)
                self.assertEqual(result["capturedSources"][category]["sha256"],
                                 hashlib.sha256(raw).hexdigest())

    def test_retrieval_after_expiry_does_not_republish_or_redate_old_source(self):
        result,_=self.run(time="2026-11-12T14:00:00Z")
        self.assertEqual(result["status"],"NO_NEW_PUBLISHER_PUBLICATION")
        self.assertIsNone(result["admission"]["newCaptureExpiryUtc"])
        self.denied(result)

    def test_new_publisher_html_is_candidate_only_even_with_https_fetch(self):
        altered={k:v.replace(b"2026-11-09T13:58:33-05:00",
                             b"2026-11-10T13:58:33-05:00")
                 for k,v in self.old.items()}
        for k in self.old:
            self.assertNotEqual(altered[k],self.old[k],k)
        result,_=self.run(old=altered,time="2026-11-10T19:00:00Z")
        self.assertEqual(result["status"],"NEW_PUBLISHER_CANDIDATE_REVIEW_REQUIRED",result)
        self.denied(result)

    def test_redirects_aliases_wrong_mime_and_non200_rejected_before_approval(self):
        tests=[
            {"redirect":"https://supremevalues.com/mm2/ancients.php"},
            {"status":302},
            {"status":403},
            {"ctype":"application/json"},
            {"redirect":"https://untrusted.example/mm2/ancients"}
        ]
        for kw in tests:
            with self.subTest(kw=kw):
                session=self.session()
                session.data[URLS["ancient"]]=FakeResponse(
                    URLS["ancient"],self.old["ancient"],**kw)
                result,_=self.run(session=session)
                self.assertEqual(result["status"],"INCONCLUSIVE",result)
                self.denied(result)

    def test_missing_page_transport_interrupt_small_and_oversize_fail_closed(self):
        tests=("missing","interrupt","short","big")
        for case in tests:
            with self.subTest(case=case):
                s=self.session()
                if case=="missing":del s.data[URLS["godly"]]
                if case=="interrupt":
                    s.data[URLS["godly"]].raise_stream=True
                if case=="short":s.data[URLS["godly"]].data=b"<html></html>"
                if case=="big":s.data[URLS["godly"]].data=b"x"*800001
                result,_=self.run(session=s)
                self.assertEqual(result["status"],"INCONCLUSIVE",result)
                self.denied(result)
                self.assertNotEqual(result["status"],
                    "NEW_PUBLISHER_CANDIDATE_REVIEW_REQUIRED")

    def test_injected_parser_and_baseline_rejected_without_any_fetch(self):
        for parser,baseline in (
            (self.parser+b"\n# altered",self.old),
            (self.parser,{**self.old,"ancient":self.old["ancient"]+b" "}),
        ):
            with self.subTest(kind=len(parser)):
                result,session=self.run(parser=parser,baseline=baseline)
                self.assertEqual(result["status"],"INCONCLUSIVE",result)
                self.assertEqual(len(session.queries),0)
                self.denied(result)

    def test_untrusted_mocked_tls_status_never_authenticates_real_publication(self):
        result,_=self.run()
        self.assertFalse(result["authenticatesExternalSource"])
        self.assertFalse(result["admission"]["externalCaptureAuthenticated"])
        self.assertNotIn("gameRawItemId",str(result))
        self.assertNotIn("Gingerscope",str(result))
        self.assertNotIn("priceForTrade",result)
        self.denied(result)

    def test_artifact_writer_does_not_modify_any_repo_value_file(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td)
            value=root/"mm2values.lua"
            value.write_bytes(b"ORIGINAL_LIVE_RESEARCH_VALUE_BYTES")
            report,_=self.run(output=root/"capture")
            self.assertEqual(value.read_bytes(),b"ORIGINAL_LIVE_RESEARCH_VALUE_BYTES")
            self.assertTrue((root/"capture/source_audit.json").is_file())
            self.denied(report)

if __name__=="__main__":
    unittest.main()
