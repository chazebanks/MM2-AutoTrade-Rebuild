"""Stage110: verified Supreme publisher admission cannot accept arbitrary parser/baseline.

Exercise unchanged Stage69 raw HTML parser and Stage107 corrected Stage104
gate on four exact pinned original Git blobs. New public capture is only a
candidate for human review, never a price authority.
"""
import copy
import hashlib
import importlib
import os
from pathlib import Path
import unittest


def gitsha(data):
    return hashlib.sha1(b"blob "+str(len(data)).encode()+b"\0"+data).hexdigest()


class Stage110SourceAdmission(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if os.getenv("STAGE110_REQUIRE_PINNED") != "1":
            raise unittest.SkipTest("original full Supreme source fixture required")
        p=Path(os.environ["STAGE110_ORIGINAL_PARSER"])
        root=Path(os.environ["STAGE110_ORIGINAL_HTML_DIR"])
        cls.parser_bytes=p.read_bytes()
        cls.old_html={key:(root/(filename+".html")).read_bytes() for key,filename in
                      (("ancient","ancients"),("godly","godlies"),("chroma","chromas"))}
        cls.mod=importlib.import_module(
            "pdiddler.intelligence_lab.stage110_trusted_source_admission")
        assert gitsha(cls.parser_bytes)=="d5843a57f34078cbe7213aa78a4aa12a5775c016"
        assert {
            k:gitsha(v) for k,v in cls.old_html.items()
        }=={
            "ancient":"ce8178ab9579e8782d8f72a6dac051756a728506",
            "godly":"d3cf222a8e10cff3a9fb051b16188192389c4b2d",
            "chroma":"6c77624cac3df96168b008e9bc8eca68a2d78cf9",
        }

    def capture(self):
        return {k:{"url":"https://supremevalues.com/mm2/"+p,
                   "html":v,"httpStatus":200,
                   "retrievedAtUtc":"2026-11-10T07:00:00Z"}
                for k,p,v in (
                    ("ancient","ancients",self.old_html["ancient"]),
                    ("godly","godlies",self.old_html["godly"]),
                    ("chroma","chromas",self.old_html["chroma"]),
                )}

    def audit(self,captures=None,parser_bytes=None,prior_bytes=None,
              evaluated="2026-11-10T07:05:00Z"):
        return self.mod.admit(
            self.capture() if captures is None else captures,
            original_parser_bytes=(self.parser_bytes if parser_bytes is None
                                   else parser_bytes),
            pinned_prior_html=(self.old_html if prior_bytes is None else prior_bytes),
            evaluation_utc=evaluated,
        )

    def denied(self,r):
        for flag in ("publisherRefreshApproved","currentPricesVerified",
                     "priceForTradeVerified","rawGameWeaponKeyAuthenticated",
                     "numericSupremeCheckerIdVerified","serverCompletionProven",
                     "authorizesTrade","authorizesAccept","mayRecordCompletedTrade",
                     "mayReportProfit","maySendDiscordWebhook",
                     "mayUseForStrategyLearning","externalCaptureAuthenticated"):
            self.assertIs(r[flag],False,flag)
        self.assertEqual(r["tradeOutcome"],"UNKNOWN")
        self.assertTrue(r["readOnly"])

    def test_real_nov9_official_sources_are_not_new_publication(self):
        r=self.audit()
        self.assertEqual(r["status"],"NO_NEW_PUBLISHER_PUBLICATION",r)
        self.assertEqual(r["reason"],"SOURCE_PUBLISHER_DATE_UNCHANGED_NO_REFRESH")
        self.assertEqual(r["observedPublisherUtc"],"2026-11-09T18:58:33Z")
        self.assertTrue(r["exactOriginalParserBlobVerified"])
        self.assertTrue(r["exactPinnedPriorHtmlVerified"])
        self.assertFalse(r["newResearchDatasetPublished"])
        self.denied(r)

    def test_caller_supplied_fake_parser_cannot_forge_publication(self):
        tampered=self.parser_bytes+b"\n# fake parser monkey-patch or new code"
        r=self.audit(parser_bytes=tampered)
        self.assertEqual(r["status"],"INCONCLUSIVE",r)
        self.assertEqual(r["reason"],"PINNED_ORIGINAL_PARSER_MISMATCH")
        self.denied(r)

    def test_caller_prior_html_cannot_hide_replaced_site_names(self):
        old=copy.deepcopy(self.old_html)
        old["ancient"]=old["ancient"]+b"<!--fake prior baseline-->"
        r=self.audit(prior_bytes=old)
        self.assertEqual(r["status"],"INCONCLUSIVE")
        self.assertEqual(r["reason"],"PINNED_ORIGINAL_PRIOR_HTML_MISMATCH")
        self.denied(r)

    def test_source_html_same_publication_after_expiry_cannot_extend_source(self):
        c=self.capture()
        for x in c.values(): x["retrievedAtUtc"]="2026-11-11T07:00:00Z"
        r=self.audit(c,evaluated="2026-11-11T07:05:00Z")
        self.assertEqual(r["status"],"NO_NEW_PUBLISHER_PUBLICATION")
        self.assertTrue(r["fixedPriorExpiryPreserved"])
        self.assertFalse(r["newResearchDatasetPublished"])
        self.denied(r)

    def test_forged_future_publisher_html_may_only_trigger_manual_candidate(self):
        c=self.capture()
        for item in c.values():
            item["html"]=item["html"].replace(
                b"2026-11-09T13:58:33-05:00",
                b"2026-11-10T13:58:33-05:00")
            item["retrievedAtUtc"]="2026-11-10T19:00:00Z"
        r=self.audit(c,evaluated="2026-11-10T19:01:00Z")
        self.assertEqual(r["status"],"NEW_PUBLISHER_CANDIDATE_REVIEW_REQUIRED",r)
        self.assertFalse(r["externalCaptureAuthenticated"])
        self.assertFalse(r["publisherRefreshApproved"])
        self.assertFalse(r["newResearchDatasetPublished"])
        self.denied(r)

    def test_stale_php_alias_and_partial_three_pages_fail_closed(self):
        c=self.capture()
        c["chroma"]["url"]="https://supremevalues.com/mm2/chromas.php"
        r=self.audit(c)
        self.assertEqual(r["status"],"INCONCLUSIVE")
        self.denied(r)
        c=self.capture();del c["godly"]
        r=self.audit(c)
        self.assertEqual(r["status"],"INCONCLUSIVE")
        self.denied(r)

    def test_mocked_status_code_alone_is_not_first_party_authentication(self):
        c=self.capture()
        c["godly"]["httpStatus"]=304
        r=self.audit(c)
        self.assertEqual(r["status"],"INCONCLUSIVE")
        self.denied(r)

    def test_source_status_cannot_grant_trade_or_backdate_market_prices(self):
        r=self.audit()
        self.denied(r)
        self.assertNotIn("currentValue",r)
        self.assertNotIn("price",r)
        self.assertNotIn("rawKey",r)
        self.assertNotIn("newCaptureExpiryUtc",r)

if __name__=="__main__":
    unittest.main()
