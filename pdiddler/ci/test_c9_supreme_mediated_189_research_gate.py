"""Adversarial regression on actual archived official-origin mediated 189 data.

These tests verify the public-source receipt and fail closed on tampering;
they do NOT make the original direct GitHub HTTP 403 go away or prove trades.
"""
from __future__ import annotations
import copy
import json
from datetime import datetime, timedelta, timezone
from pathlib import Path
import unittest
from pdiddler.system2.c9_supreme_mediated_189_research_gate import (
    validate, SupremeEvidenceBlocked,
)

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "pdiddler/system2"
SNAP = json.loads((SRC/"c9_supreme_official_origin_mediated_189_2026_11_15.json").read_text())
BASE = json.loads((SRC/"c9_research_public_189_crosswalk.json").read_text())
CAP = datetime.fromisoformat(SNAP["sourceCapturedUtc"].replace("Z", "+00:00"))


def clock(offset=30):
    return (CAP + timedelta(seconds=offset)).astimezone(
        timezone.utc).isoformat().replace("+00:00", "Z")


class SupremeActualOrigin189(unittest.TestCase):
    def check(self, snapshot=None, baseline=None, at=None):
        return validate(SNAP if snapshot is None else snapshot,
                        BASE if baseline is None else baseline,
                        clock() if at is None else at)

    def test_public_source_189_and_34_conflicts_are_not_livetrade(self):
        receipt = self.check()
        self.assertEqual(receipt["matchedHistoricalGameKeys"], 189)
        self.assertEqual(receipt["marketSupremePriceConflictCount"], 34)
        self.assertEqual(receipt["status"],
                         "BLOCKED_UNTIL_DUAL_SOURCE_RESEARCH_RECONCILIATION")
        self.assertFalse(receipt["safeForAutonomousTrade"])
        self.assertFalse(receipt["safeToClaimOfficialPublisherSignature"])
        self.assertFalse(receipt["safeToUseUnmodifiedAggregateSupremeColumnForGrowthRanking"])
        self.assertFalse(receipt["authorizesOffer"])
        self.assertFalse(receipt["authorizesAccept"])
        self.assertEqual(len(SNAP["rows"]), 189)
        self.assertTrue(SNAP["all189OfficialPricesAndDemandParsed"])

    def test_known_official_changed_prices_are_correct(self):
        data = {x["rawGameKeyCandidate"]: x for x in SNAP["rows"]}
        expected = {"Gingerscope": 16000, "Harvester": 275,
                    "Icepiercer": 185, "EmberscytheChroma": 12000,
                    "Immortal": 120, "Mortal": 120,
                    "Snowcannon": 850, "TravelerAxe": 6700,
                    "VampireAxe": 1300, "UFOKnifeChroma": 18000}
        for k, v in expected.items():
            with self.subTest(key=k):
                self.assertEqual(data[k]["officialSupremeListed"], v)

    def test_exact_6_hour_ttl_and_one_second_late(self):
        self.assertEqual(self.check(at=clock(21600))["matchedHistoricalGameKeys"], 189)
        with self.assertRaisesRegex(SupremeEvidenceBlocked, "CAPTURE_EXPIRED"):
            self.check(at=clock(21601))
        with self.assertRaisesRegex(SupremeEvidenceBlocked, "CAPTURE_EXPIRED"):
            self.check(at=clock(-1))

    def test_cannot_call_firecrawl_a_direct_github_source(self):
        x=copy.deepcopy(SNAP)
        x["directGitHubRunnerFirstPartyFetchSucceeded"]=True
        with self.assertRaisesRegex(SupremeEvidenceBlocked, "UNSAFE_PROVENANCE"):
            self.check(snapshot=x)

    def test_expired_official_publication_not_falsely_current(self):
        x=copy.deepcopy(SNAP)
        x["sourceOfficialPublicationISO"]="2026-09-01T11:59:41-04:00"
        with self.assertRaisesRegex(SupremeEvidenceBlocked, "PUBLICATION_FUTURE_OR_STALE"):
            self.check(snapshot=x)

    def test_changed_price_cannot_keep_old_match_flag(self):
        x=copy.deepcopy(SNAP)
        row=next(y for y in x["rows"] if y["rawGameKeyCandidate"]=="Harvester")
        row["officialSupremeListed"]=row["aggregatorSupremeListedAtCapture"]
        with self.assertRaisesRegex(SupremeEvidenceBlocked, "FORGED_PRICE_MATCH"):
            self.check(snapshot=x)

    def test_forged_aggregate_supreme_column_rejected(self):
        x=copy.deepcopy(SNAP)
        x["rows"][0]["aggregatorSupremeListedAtCapture"]=1
        with self.assertRaisesRegex(SupremeEvidenceBlocked, "AGGREGATOR_SNAPSHOT_MUTATED"):
            self.check(snapshot=x)

    def test_price_conflict_count_cannot_be_erased(self):
        x=copy.deepcopy(SNAP)
        x["officialPriceDisagreementCount"]=0
        with self.assertRaisesRegex(SupremeEvidenceBlocked, "DIFF_COUNTS_FORGED"):
            self.check(snapshot=x)

    def test_missing_item_cannot_pass(self):
        x=copy.deepcopy(SNAP)
        x["rows"]=x["rows"][:-1]
        with self.assertRaisesRegex(SupremeEvidenceBlocked, "CENSUS_INVALID"):
            self.check(snapshot=x)

    def test_duplicate_item_cannot_pass(self):
        x=copy.deepcopy(SNAP)
        x["rows"][1]=copy.deepcopy(x["rows"][0])
        with self.assertRaisesRegex(SupremeEvidenceBlocked, "DUPLICATED"):
            self.check(snapshot=x)

    def test_flowerwood_alias_cannot_be_hidden(self):
        x=copy.deepcopy(SNAP)
        row=next(y for y in x["rows"] if y["rawGameKeyCandidate"]=="FlowerwoodKnife")
        row["explicitReviewedNameAlias"]=False
        with self.assertRaisesRegex(SupremeEvidenceBlocked, "NAME_ALIAS"):
            self.check(snapshot=x)

    def test_gingerscope_never_offered_out(self):
        x=copy.deepcopy(SNAP)
        row=next(y for y in x["rows"] if y["rawGameKeyCandidate"]=="Gingerscope")
        row["outgoingGingerscopeProtected"]=False
        with self.assertRaisesRegex(SupremeEvidenceBlocked, "PROTECTION_FAILED"):
            self.check(snapshot=x)

    def test_renaming_raw_game_key_rejected(self):
        x=copy.deepcopy(SNAP)
        x["rows"][0]["rawGameKeyCandidate"]="PrivateFakeIdentityKey"
        with self.assertRaisesRegex(SupremeEvidenceBlocked, "UNREVIEWED"):
            self.check(snapshot=x)

    def test_wrong_category_or_demand_rejected(self):
        x=copy.deepcopy(SNAP)
        x["rows"][0]["category"]="ancient" if x["rows"][0]["category"]!="ancient" else "godly"
        with self.assertRaisesRegex(SupremeEvidenceBlocked, "CATEGORY_CHANGED"):
            self.check(snapshot=x)
        x=copy.deepcopy(SNAP)
        x["rows"][0]["officialDemand"]="NaN"
        with self.assertRaisesRegex(SupremeEvidenceBlocked, "DEMAND_OR_STABILITY_INVALID"):
            self.check(snapshot=x)

    def test_page_provider_identity_cannot_be_spoofed(self):
        x=copy.deepcopy(SNAP)
        x["pageEvidence"]["chroma"]["url"]="https://evil.invalid/mm2/chromas"
        with self.assertRaisesRegex(SupremeEvidenceBlocked, "PAGE_ORIGIN"):
            self.check(snapshot=x)
        x=copy.deepcopy(SNAP)
        x["pageEvidence"]["home"]["statusCode"]=403
        with self.assertRaisesRegex(SupremeEvidenceBlocked, "PAGE_ORIGIN"):
            self.check(snapshot=x)

    def test_private_account_data_absent_from_published_public_only(self):
        text=json.dumps(SNAP,sort_keys=True)
        for phrase in ("ownedInventory","partnerUserId","jobId","leaseId",
                       "discordWebhook","getgenv","operatorAltUsername"):
            self.assertNotIn(phrase, text)


if __name__ == "__main__":
    unittest.main()
