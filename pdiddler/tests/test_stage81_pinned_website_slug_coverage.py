"""Stage81 189/190 immutable first-party slug coverage, never live market authority."""
from __future__ import annotations
import importlib.util
import json
import os
from pathlib import Path
import random
import unittest

ROOT=Path(__file__).resolve().parents[2]
FILE=ROOT/"pdiddler/intelligence_lab/stage81_pinned_website_slug_coverage.py"
spec=importlib.util.spec_from_file_location("stage81",FILE)
m=importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

class Stage81(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        env=os.environ
        keys=["STAGE81_HISTORICAL_ROSTER","STAGE81_REVIEWED_STAGE77",
              "STAGE81_ANCIENTS","STAGE81_GODLIES","STAGE81_CHROMAS"]
        if not all(env.get(k) for k in keys):
            if env.get("STAGE81_REQUIRE_PINNED")=="1":
                raise AssertionError("dedicated CI must supply all five hash-pinned source originals")
            cls.fixture=None
            return
        cls.fixture=(
            Path(env["STAGE81_HISTORICAL_ROSTER"]).read_bytes(),
            {"ancient":Path(env["STAGE81_ANCIENTS"]).read_bytes(),
             "godly":Path(env["STAGE81_GODLIES"]).read_bytes(),
             "chroma":Path(env["STAGE81_CHROMAS"]).read_bytes()},
            Path(env["STAGE81_REVIEWED_STAGE77"]).read_bytes(),
        )

    def source(self):
        if self.fixture is None: self.skipTest("actual inputs provided to focused CI only")
        return self.fixture

    def reject_authority(self,r):
        self.assertIs(r["readOnly"],True)
        self.assertIs(r["researchOnly"],True)
        for k in ("authenticatedOwnedInventory","currentGameCatalogueAuthenticated",
                  "websiteOriginServerAttested","numericSupremeCheckerIdVerified",
                  "rawGameToWebsiteSlugVerified","rawGameToNumericCheckerVerified",
                  "sourcePublisherFresh","currentPricesVerified","authorizesTrade",
                  "authorizesAccept","mayRecordCompletedTrade","mayRecordRejectedTrade",
                  "mayReportProfit","maySendDiscordWebhook","mayUseForStrategyLearning",
                  "serverCompletionProven"):
            self.assertIs(r[k],False,k)
        self.assertEqual(r["tradeOutcome"],"UNKNOWN")

    def test_real_189_public_slugs_and_one_priceless_exception(self):
        archived,html,parser=self.source()
        r=m.run(archived,html,parser)
        self.assertEqual(r["status"],"PUBLIC_WEBSITE_SLUG_COVERAGE_CONFIRMED_RESEARCH_ONLY",r)
        self.assertEqual(r["archivedRosterRows"],190)
        self.assertEqual(r["firstPartyPublicSlugs"],189)
        self.assertEqual(r["pricelessNoSlugRows"],1)
        self.assertEqual(r["byCategory"]["ancient"],{"roster":16,"websiteSlugs":15})
        self.assertEqual(r["byCategory"]["godly"],{"roster":128,"websiteSlugs":128})
        self.assertEqual(r["byCategory"]["chroma"],{"roster":46,"websiteSlugs":46})
        self.assertEqual(r["currentAuthoritativeValueCount"],0)
        self.assertTrue(r["publisherOlderThan72Hours"])
        self.reject_authority(r)

    def test_publisher_age_boundary_is_real_publication_not_refetch(self):
        a,h,p=self.source()
        before=m.run(a,h,p,asof="2026-11-09T15:56:06Z")
        at=m.run(a,h,p,asof="2026-11-09T15:56:07Z")
        later=m.run(a,h,p,asof="2026-11-10T10:00:00Z")
        for r in (before,at,later):
            self.assertEqual(r["status"],"PUBLIC_WEBSITE_SLUG_COVERAGE_CONFIRMED_RESEARCH_ONLY",r)
            self.assertEqual(r["hardPublisherExpiryUtc"],"2026-11-09T15:56:07Z")
            self.reject_authority(r)
        self.assertFalse(before["publisherOlderThan72Hours"])
        self.assertTrue(at["publisherOlderThan72Hours"])
        self.assertTrue(later["publisherOlderThan72Hours"])

    def test_snapshot_rewrites_and_page_mutations_fail_closed(self):
        a,html,p=self.source()
        mutations=[
            ("archive",a+b"\n",html,p),
            ("parser",a,html,p+b"\n"),
        ]
        for page in html:
            h=dict(html)
            h[page]=h[page]+b"\n"
            mutations.append((page,a,h,p))
        for label,archive,sites,parser in mutations:
            with self.subTest(label=label):
                r=m.run(archive,sites,parser)
                self.assertEqual(r["status"],"INCONCLUSIVE")
                self.reject_authority(r)

    def test_missing_or_extra_category_and_invalid_types(self):
        a,h,p=self.source()
        examples=[
            (a,{k:v for k,v in h.items() if k!="chroma"},p),
            (a,{**h,"other":b"source"},p),
            (a,{**h,"ancient":"HTML IS NOT BYTES"},p),
            (a,h,b"forged reviewed parser"),
            (None,h,p),
        ]
        for archive,sites,parser in examples:
            r=m.run(archive,sites,parser)
            self.assertEqual(r["status"],"INCONCLUSIVE")
            self.reject_authority(r)

    def test_400_seeded_corrupted_pinned_inputs(self):
        a,h,p=self.source()
        rng=random.Random(81001)
        for i in range(400):
            aa=a; hh=dict(h);pp=p
            k=i%5
            if k==0:
                aa+=bytes([rng.randrange(0,256)])
            elif k==1:
                pp+=bytes([rng.randrange(0,256)])
            else:
                page=("ancient","godly","chroma")[k-2]
                hh[page]+=bytes([rng.randrange(0,256)])
            r=m.run(aa,hh,pp)
            self.assertEqual(r["status"],"INCONCLUSIVE",i)
            self.reject_authority(r)

    def test_no_caller_clock_spoofing_or_raw_id_export(self):
        a,h,p=self.source()
        for t in ("2026-11-09T12:00:00", "invalid","2026-11-05T00:00:00Z"):
            r=m.run(a,h,p,asof=t)
            self.assertEqual(r["status"],"INCONCLUSIVE",t)
            self.reject_authority(r)
        r=m.run(a,h,p)
        data=json.dumps(r)
        self.assertNotIn('"rawKey"',data)
        self.assertNotIn('"checkerId"',data)
        self.assertNotIn('"username"',data)
        self.reject_authority(r)

    def test_archived_parser_is_strictly_pinned_not_external_code(self):
        src=FILE.read_text()
        self.assertIn('git_blob(src)!=PARSER_SHA',src)
        self.assertNotIn('eval(',src)
        self.assertNotIn('os.system(',src)
        self.assertNotIn('subprocess.run(',src)
        self.assertNotIn("FireServer(",src)
        self.assertNotIn('GetProfileData(',src)
        self.assertIn('"researchOnly":True',src)

if __name__=="__main__":
    unittest.main()
