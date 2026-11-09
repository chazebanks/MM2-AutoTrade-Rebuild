"""Static current-source research observation self-consistency.

This tests provenance and quarantining, NOT the original HTML bytes (not
archived in the repo) and NOT live authorizable Supreme quotes.
"""
import json
import unittest
from collections import Counter
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
PATH=ROOT/"pdiddler/intelligence_lab/STAGE69_SUPREME_PUBLIC_HTML_OBSERVATION_RESEARCH_ONLY.json"

class Stage69CurrentSourceResearchArtifactTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.d=json.loads(PATH.read_text(encoding="utf-8"))

    def test_exact_190_items_and_unique_unverified_old_checker_keys(self):
        d=self.d
        self.assertEqual(d["schema"],
              "gingerscope-stage69-research-only-site-html-reconciliation-v1")
        self.assertEqual(d["status"],
              "SOURCE_OBSERVED_REVIEW_REQUIRED_NOT_LIVE_PRICING")
        self.assertEqual(d["itemCoverage"],
              {"ancient":16,"chroma":46,"godly":128,"total":190})
        rows=d["observedItemsFromSite"]
        self.assertEqual(len(rows),190)
        self.assertEqual(dict(Counter(x["page"] for x in rows)),
                         {"ancient":16,"chroma":46,"godly":128})
        self.assertEqual(len({
            (x["page"],x["name"].casefold()) for x in rows}),190)
        self.assertEqual(len({
            (x["page"],x["oldCheckerIdNotIndependentlyVerified"]) for x in rows}),190)
        self.assertNotIn("verified",rows[0])
        self.assertTrue(d["exactOldNameAndPageSetMatched"])
        self.assertEqual(d["displayVsAttributeDisagreementCount"],0)

    def test_all_23_changes_match_items_by_exact_page_name(self):
        d=self.d
        self.assertEqual(len(d["changes"]),23)
        lookup={(r["page"],r["name"]):r for r in d["observedItemsFromSite"]}
        seen=set()
        fields={
            "supremeValue":"observedSupremeValue",
            "demand":"observedDemand",
            "stability":"observedStability",
        }
        for row in d["changes"]:
            key=(row["page"],row["name"],row["field"])
            self.assertNotIn(key,seen)
            seen.add(key)
            self.assertEqual(
                lookup[(row["page"],row["name"])][fields[row["field"]]],
                row["observed"])
            self.assertEqual(row["oldCheckerIdNotIndependentlyVerified"],
                lookup[(row["page"],row["name"])]["oldCheckerIdNotIndependentlyVerified"])
            self.assertNotEqual(row["old"],row["observed"])
        known={(r["page"],r["name"],r["field"]):(r["old"],r["observed"]) for r in d["changes"]}
        self.assertEqual(known[("ancient","Emberbow","supremeValue")],(400,525))
        self.assertEqual(known[("chroma","Chroma Emberscythe","supremeValue")],(11000,16000))
        self.assertEqual(known[("godly","Embersickle","demand")],(2,3))

    def test_all_sources_claim_same_date_exact_known_exclusions(self):
        d=self.d
        self.assertEqual(d["sitePublisherTimestampClaimUtc"],
                         "2026-11-06T15:56:07.000Z")
        src=d["sourcePages"]
        self.assertEqual(len(src),3)
        self.assertEqual(len({r["source"] for r in src}),3)
        self.assertEqual(sum(r["eligibleItems"] for r in src),190)
        self.assertEqual(sum(r["structuredItemColumns"] for r in src),199)
        self.assertEqual(sum(len(r["knownExcludedNonWeaponOrHidden"]) for r in src),9)
        self.assertEqual(len({
            r["sitePublisherClaimUtc"] for r in src
        }),1)
        self.assertTrue(d["githubActionsDirectSourceFetchBlockedHttp403"])
        self.assertFalse(d["sourceByteHashAvailable"])
        for r in src:
            self.assertIsNone(r["rawHtmlSha256"])
            self.assertEqual(r["rawHtmlHashStatus"],
                             "NOT_OBTAINED_FROM_CONNECTOR")
            self.assertGreater(r["httpContentLengthObserved"],10000)

    def test_no_trading_or_learning_authority_in_any_observation(self):
        d=self.d
        for key in ("sitePublisherTimestampIndependentlyAuthenticated",
                    "oldCheckerIdsIndependentlyMappedToMm2RawWeaponKeys",
                    "fullLiveParserExecuted","sourceByteShaVerified",
                    "canPublishSnapshot","livePriceReady","canSendTrades",
                    "canAcceptTrades","canReportProfit","canTrainDiscordLearner"):
            self.assertIs(d["approval"][key],False,key)
        self.assertNotIn("authorizesTrade",d)
        self.assertNotIn("publishedPriceProfile",d)
        self.assertNotIn("serverTransactionId",d)

    def test_source_parser_no_longer_has_a_publisher_entrypoint(self):
        source=(ROOT/"pdiddler/intelligence_lab/stage69_supreme_parser_reference.py").read_text()
        self.assertIn("def parse_page(text, page):",source)
        self.assertNotIn("def lua_snapshot(",source)
        self.assertNotIn("def main():",source)
        self.assertNotIn("liveReady=true",source)
        self.assertNotIn("def fetch_live",source)

if __name__=="__main__":
    unittest.main()
