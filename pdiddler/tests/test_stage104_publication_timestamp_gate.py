"""Stage104 canonical Supreme source publisher chronology and alias regressions.

Uses ACTUAL three Stage84 Nov9 HTML source blobs and unchanged original Stage69
parser, all SHA-pinned in GitHub Actions. No network, real account, or trade.
"""
from __future__ import annotations
import copy
import hashlib
import importlib.util
import os
from pathlib import Path
import random
import unittest

from pdiddler.intelligence_lab.stage104_publication_timestamp_gate import (
    audit_publication, PRIOR, PAGE_COUNTS
)
BASE="https://supremevalues.com/mm2/"
PATH={"ancient":"ancients","godly":"godlies","chroma":"chromas"}
T="2026-11-10T07:00:00Z"
RAW_SHA={
    "ancient":"ce8178ab9579e8782d8f72a6dac051756a728506",
    "godly":"d3cf222a8e10cff3a9fb051b16188192389c4b2d",
    "chroma":"6c77624cac3df96168b008e9bc8eca68a2d78cf9",
}
def gitsha(raw:bytes)->str:
    return hashlib.sha1(b"blob "+str(len(raw)).encode()+b"\0"+raw).hexdigest()

class ActualStage104PublisherAudit(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if os.getenv("STAGE104_REQUIRE_PINNED")!="1":
            raise unittest.SkipTest("Stage104 needs three reviewed original raw HTML files")
        source=Path(os.environ["STAGE104_ORIGINAL_HTML_DIR"])
        parser=Path(os.environ["STAGE104_ORIGINAL_PARSER"])
        assert gitsha(parser.read_bytes())=="d5843a57f34078cbe7213aa78a4aa12a5775c016"
        spec=importlib.util.spec_from_file_location("stage104_exact_original_parser",parser)
        p=importlib.util.module_from_spec(spec)
        spec.loader.exec_module(p)
        cls.parse=staticmethod(p.parse_page)
        cls.original={}
        cls.prior={}
        for page,file in PATH.items():
            raw=(source/(file+".html")).read_bytes()
            assert gitsha(raw)==RAW_SHA[page],page
            rows,published=p.parse_page(raw.decode(),page)
            assert published==PRIOR
            assert len(rows)==PAGE_COUNTS[page]
            cls.prior[page]=rows
            cls.original[page]={
                "url":BASE+file,
                "html":raw,
                "httpStatus":200,
                "retrievedAtUtc":T,
            }
    def audit(self,captures=None,parse_page=None,**kw):
        return audit_publication(
            captures if captures is not None else self.original,
            prior_published=kw.pop("prior_published",PRIOR),
            prior_records=kw.pop("prior_records",self.prior),
            evaluation_utc=kw.pop("evaluation_utc",T),
            parse_page=parse_page or self.parse,
            **kw,
        )
    def check_authority_denied(self,r):
        for k in ("publisherRefreshApproved",
                  "publicObservationAuthenticatedAsGameTrade",
                  "rawGameWeaponKeyAuthenticated",
                  "numericSupremeCheckerIdVerified","currentPricesVerified",
                  "priceForTradeVerified","authenticatedOwnedInventory",
                  "serverAttestation","serverCompletionProven",
                  "authorizesTrade","authorizesAccept","mayRecordCompletedTrade",
                  "mayReportProfit","maySendDiscordWebhook",
                  "mayUseForStrategyLearning"):
            self.assertIs(r[k],False,k)
        self.assertIs(r["fixedPriorExpiryPreserved"],True)
        self.assertIs(r["readOnly"],True)
        self.assertEqual(r["tradeOutcome"],"UNKNOWN")
    def test_three_real_nov9_sources_are_same_publisher_not_a_nov10_refresh(self):
        r=self.audit()
        self.assertEqual(r["status"],"NO_NEW_PUBLISHER_PUBLICATION")
        self.assertEqual(r["reason"],"SOURCE_PUBLISHER_DATE_UNCHANGED_NO_REFRESH")
        self.assertEqual(r["observedPublisherUtc"],"2026-11-09T18:58:33Z")
        self.assertEqual(r["canonicalSourcePageCount"],3)
        self.assertEqual(r["rowChangeCount"],0)
        self.assertEqual(len(r["sourceHtmlSha256"]),3)
        self.assertEqual(len(set(r["rawPagePublishedDates"].values())),1)
        self.check_authority_denied(r)
    def test_alternate_chroma_php_older_url_rejected_even_if_content_looks_identical(self):
        c=copy.deepcopy(self.original)
        c["chroma"]["url"]="https://www.supremevalues.com/mm2/chromas.php"
        r=self.audit(c)
        self.assertEqual(r["status"],"INCONCLUSIVE")
        self.check_authority_denied(r)
    def test_wrong_category_alias_and_mixed_hosts_rejected(self):
        bad=(
         ("chroma","https://supremevalues.com/mm2/chromas.php"),
         ("godly","http://supremevalues.com/mm2/godlies"),
         ("ancient","https://supremevalues.com/mm2/ancients?cache=0"),
         ("chroma","https://evil.example/mm2/chromas"),
         ("ancient","https://supremevalues.com/mm2/ancients/"),
         ("godly","https://supremevalues.com/mm2/ancients")
        )
        for p,url in bad:
            with self.subTest(page=p,url=url):
                c=copy.deepcopy(self.original)
                c[p]["url"]=url
                r=self.audit(c)
                self.assertEqual(r["status"],"INCONCLUSIVE")
                self.check_authority_denied(r)
        c=copy.deepcopy(self.original)
        c["godly"]["url"]="https://www.supremevalues.com/mm2/godlies"
        self.assertEqual(self.audit(c)["status"],"INCONCLUSIVE")
        c={k:{**v,"url":v["url"].replace("https://","https://www.")}
           for k,v in self.original.items()}
        self.assertEqual(self.audit(c)["status"],"NO_NEW_PUBLISHER_PUBLICATION")
    def test_same_publisher_with_display_only_html_change_not_an_update(self):
        c=copy.deepcopy(self.original)
        page="godly"
        b=c[page]["html"]
        c[page]["html"]=b.replace(b"</body>",b"<!-- decorative change --></body>")
        self.assertNotEqual(c[page]["html"],b)
        r=self.audit(c)
        self.assertEqual(r["status"],"NO_NEW_PUBLISHER_PUBLICATION",r)
        self.assertEqual(r["rowChangeCount"],0)
        self.check_authority_denied(r)
    def test_unstamped_price_drift_requires_review_not_misrepresented_as_new_quote(self):
        def changed(html,page):
            rows,stamp=self.parse(html,page)
            if page=="ancient":
                rows[1]["supremeValue"]+=5
            return rows,stamp
        r=self.audit(parse_page=changed)
        self.assertEqual(r["status"],"NO_NEW_PUBLISHER_PUBLICATION")
        self.assertEqual(r["reason"],
                         "UNCHANGED_PUBLISHER_DATE_BUT_ROW_DRIFT_REVIEW_REQUIRED")
        self.assertGreater(r["rowChangeCount"],0)
        self.check_authority_denied(r)
    def test_mixed_updated_and_stale_publisher_timestamps_quarantined(self):
        def mixed(html,page):
            rows,pub=self.parse(html,page)
            if page=="chroma": pub="2026-11-06T15:56:00Z"
            return rows,pub
        r=self.audit(parse_page=mixed)
        self.assertEqual(r["status"],"INCONCLUSIVE")
        self.check_authority_denied(r)
    def test_newer_three_category_timestamp_still_not_authorized_price(self):
        def newer(html,page):
            rows,_=self.parse(html,page)
            if page=="ancient": rows[1]["supremeValue"]+=25
            return rows,"2026-11-10T18:58:33Z"
        c=copy.deepcopy(self.original)
        for v in c.values():v["retrievedAtUtc"]="2026-11-10T19:00:00Z"
        r=self.audit(c,parse_page=newer,evaluation_utc="2026-11-10T19:10:00Z")
        self.assertEqual(r["status"],"NEW_PUBLISHER_CANDIDATE_REVIEW_REQUIRED",r)
        self.assertGreater(r["rowChangeCount"],0)
        self.check_authority_denied(r)
    def test_newer_date_without_any_public_record_change_needs_review(self):
        def newer(html,page):
            rows,_=self.parse(html,page)
            return rows,"2026-11-10T18:58:33Z"
        c=copy.deepcopy(self.original)
        for v in c.values():v["retrievedAtUtc"]="2026-11-10T19:00:00Z"
        r=self.audit(c,parse_page=newer,evaluation_utc="2026-11-10T19:10:00Z")
        self.assertEqual(r["status"],"NEW_PUBLISHER_CANDIDATE_REVIEW_REQUIRED")
        self.assertEqual(r["rowChangeCount"],0)
        self.check_authority_denied(r)
    def test_old_publication_is_never_extended_after_new_crawl(self):
        c=copy.deepcopy(self.original)
        for v in c.values():v["retrievedAtUtc"]="2026-11-11T14:00:00Z"
        r=self.audit(c,evaluation_utc="2026-11-11T14:01:00Z")
        self.assertEqual(r["status"],"NO_NEW_PUBLISHER_PUBLICATION")
        self.assertIs(r["publisherRefreshApproved"],False)
        self.assertIs(r["fixedPriorExpiryPreserved"],True)
    def test_missing_corrupt_or_future_html_fails(self):
        for kind in ("empty","html","missing","timestamp","http"):
            c=copy.deepcopy(self.original)
            if kind=="empty":c["chroma"]["html"]=b""
            if kind=="html":c["ancient"]["html"]=b"untrusted html"*400
            if kind=="missing":del c["godly"]
            if kind=="timestamp":c["godly"]["retrievedAtUtc"]="2026-11-14T07:00:00Z"
            if kind=="http":c["godly"]["httpStatus"]=403
            r=self.audit(c)
            self.assertEqual(r["status"],"INCONCLUSIVE",kind)
            self.check_authority_denied(r)
    def test_300_seeded_url_and_clock_mutants_never_approve_trade(self):
        rng=random.Random(104)
        for i in range(300):
            c=copy.deepcopy(self.original)
            page=rng.choice(tuple(PATH))
            if i%3==0:
                c[page]["url"]+=rng.choice((".php","?v=1","/", "#fragment"))
            elif i%3==1:
                c[page]["retrievedAtUtc"]=rng.choice(
                    ("2026-11-01T00:00:00Z","2026-11-19T00:00:00Z",T))
            else:
                c[page]["httpStatus"]=rng.choice((200,301,403,404))
            result=self.audit(c)
            self.check_authority_denied(result)
            self.assertNotEqual(result.get("status"),"APPROVED_FOR_TRADING")
    def test_raw_source_digests_proven_from_exact_stage84_originals(self):
        r=self.audit()
        for page in PATH:
            self.assertEqual(r["sourceHtmlSha256"][page],
                             hashlib.sha256(self.original[page]["html"]).hexdigest())
        self.check_authority_denied(r)

if __name__=="__main__":
    unittest.main()
