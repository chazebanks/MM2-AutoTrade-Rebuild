"""Read-only actual two-publisher source join, diverse adversarial evidence tests."""
from __future__ import annotations

from copy import deepcopy
from datetime import datetime, timedelta, timezone
import hashlib
import json
import os
from pathlib import Path
import unittest

from pdiddler.system2.c9_two_publisher_189_research_join import (
    TwoPublisherBlocked, MM2_SHA256, MM2_ROWS_SHA256, SCHEMA,
    join, strictly_compare, strict_age, negative_licenses, map_exact, read_pinned,
)
from pdiddler.system2.c9_mm2values_firstparty_189 import validate_freshness
from pdiddler.system2.c9_supreme_fresh_mediated_archive_gate import audit as supreme_gate

ROOT = Path(__file__).resolve().parents[2] / "pdiddler/system2"
PRIOR = (ROOT / "c9_supreme_official_origin_mediated_189_2026_11_15.json").read_bytes()
SUPREME = (ROOT / "c9_supreme_official_origin_mediated_189_2026_11_16.json").read_bytes()
REGISTRY = (ROOT / "c9_research_public_189_crosswalk.json").read_bytes()
# Permanent, exact-byte public-only fixture; same Git blob and SHA-256 as
# direct publisher GitHub Actions capture in PR308. Broad inherited discovery
# and dedicated two-source runs now execute all cases without external expiry.
MM2 = (ROOT / "c9_mm2values_direct_189_2026_11_16.json").read_bytes()
AT = "2026-11-16T06:44:54Z"
M = json.loads(MM2)
S = json.loads(SUPREME)
R = json.loads(REGISTRY)


def date_delta(iso, amount):
    t = datetime.fromisoformat(iso.replace("Z", "+00:00"))
    return (t + timedelta(seconds=amount)).astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


class TwoPublisher189Contract(unittest.TestCase):
    def task(self, mm2=MM2, supreme=SUPREME, prior=PRIOR, reg=REGISTRY, at=AT):
        return join(mm2, supreme, prior, reg, evaluated_utc=at)

    def test_verified_real_public_mm2_artifact_sha256(self):
        self.assertEqual(hashlib.sha256(MM2).hexdigest(), MM2_SHA256)
        self.assertEqual(M["rowsSha256"], MM2_ROWS_SHA256)
        self.assertEqual(M["matchedHistoricalGameKeys"], 189)

    def test_exact_189_independently_named_keys_and_category_counts(self):
        output = self.task()
        self.assertEqual(output["status"], "TWO_PUBLISHER_189_READONLY_RESEARCH_JOINED_NOT_TRADE_READY")
        self.assertEqual(output["rawGameKeyCandidateCount"], 189)
        self.assertEqual(output["categoryCounts"], {"ancient":15,"godly":128,"chroma":46})
        self.assertEqual(set(row["rawGameKeyCandidate"] for row in output["rows"]),
                         set(row["rawGameKeyCandidate"] for row in R["items"]))
        self.assertEqual(output["mm2ComparedWithOldAggregatorConflictCount"], 22)
        self.assertEqual(output["supremeComparedWithOldAggregatorConflictCount"], 34)
        both=output["bothOldAggregatorColumnsChangedForSameKeys"]
        distinct=output["distinctOldAggregatorConflictKeys"]
        self.assertEqual(distinct, 22+34-both)
        self.assertGreaterEqual(both,0)
        self.assertLessEqual(both,22)

    def test_gingerscope_outbound_protected_and_public_values_different_providers(self):
        output=self.task()
        row=next(r for r in output["rows"] if r["rawGameKeyCandidate"]=="Gingerscope")
        self.assertTrue(row["outgoingGingerscopeProtected"])
        self.assertEqual(row["mm2Values"]["listed"],16000)
        self.assertEqual(row["supremeValues"]["listed"],16000)
        self.assertEqual(sum(r["outgoingGingerscopeProtected"] for r in output["rows"]),1)
        self.assertEqual(output["mm2Publisher"]["transport"],"DIRECT_GITHUB_HTTPS")
        self.assertEqual(output["supremePublisher"]["transport"],"FIRECRAWL_MEDIATED_HTTPS")
        self.assertFalse(output["publisherCryptographicSignaturesVerified"])

    def test_named_descriptive_nonpricing_differences_kept_distinct(self):
        x=self.task()
        r={y["rawGameKeyCandidate"]:y for y in x["rows"]}
        self.assertEqual(r["EmberscytheChroma"]["mm2Values"]["listed"],12250)
        self.assertEqual(r["EmberscytheChroma"]["supremeValues"]["listed"],12000)
        self.assertEqual(r["FlowerwoodKnife"]["mm2Values"]["publicName"],"Flowerwood Knife")
        self.assertEqual(r["FlowerwoodKnife"]["supremeValues"]["publicName"],"Flowerwood")
        self.assertEqual(r["TravelerAxe"]["mm2Values"]["listed"],6750)
        self.assertEqual(r["TravelerAxe"]["supremeValues"]["listed"],6700)
        self.assertTrue(x["samePublisherValuesAcrossTwoSitesNotRequired"])
        self.assertTrue(x["sourceDemandIsNotEmpiricalLiquidity"])

    def test_no_learner_or_live_quote_or_offer_authority(self):
        x=self.task()
        for k in ("researchOnly",): self.assertIs(x[k],True)
        for k in ("realTradeCompletionProven","accountInventoryVerified",
                  "actualRobloxItemIdentityVerified","fourPhysicalTradeSlotsValidated",
                  "autonomousStrategyRankingAuthorized","safeForLiveMarketQuotes",
                  "authorizesTrade","authorizesOffer","authorizesAccept",
                  "mayUseForStrategyLearning","mayReportProfit"):
            self.assertIs(x[k],False)
        for r in x["rows"]:
            self.assertIsNone(r["empiricalCounterpartyAcceptanceProbability"])
            self.assertEqual(r["empiricalRetradeLiquidity"],"UNKNOWN")
            self.assertFalse(r["rawRobloxItemIdentityProven"])

    def test_own_mm2_capture_exact_six_hour_boundary_and_one_second_late(self):
        self.assertEqual(validate_freshness(M,now_utc=date_delta(M["sourceCapturedUtc"],21600))
                         ["sourceAgeSeconds"],21600)
        self.assertGreaterEqual(self.task(at=date_delta(M["sourceCapturedUtc"],21600))
                                ["rawGameKeyCandidateCount"],189)
        with self.assertRaisesRegex(TwoPublisherBlocked,"CAPTURE_EXPIRED"):
            self.task(at=date_delta(M["sourceCapturedUtc"],21601))

    def test_supreme_capture_independently_expires_at_six_hours(self):
        self.assertEqual(supreme_gate(SUPREME,PRIOR,REGISTRY,
                         at_utc=date_delta(S["sourceCapturedUtc"],21600))
                         ["sourceAgeSeconds"],21600)
        with self.assertRaisesRegex(TwoPublisherBlocked,"SUPREME_CAPTURE_EXPIRED"):
            strict_age(date_delta(S["sourceCapturedUtc"],21601),
                       S["sourceCapturedUtc"],S["sourceOfficialPublicationISO"],"SUPREME")

    def test_mutated_mm2_listed_price_sha_is_rejected(self):
        mm2=deepcopy(M)
        mm2["rows"][0]["mm2FirstPartyListed"]+=1
        with self.assertRaisesRegex(TwoPublisherBlocked,"MM2_GIT_BLOB_PIN_FAILED"):
            self.task(mm2=json.dumps(mm2).encode())

    def test_forged_mm2_fresh_capture_sha_is_rejected(self):
        mm2=deepcopy(M)
        mm2["sourceCapturedUtc"]="2026-11-16T10:20:00Z"
        with self.assertRaisesRegex(TwoPublisherBlocked,"MM2_GIT_BLOB_PIN_FAILED"):
            self.task(mm2=json.dumps(mm2).encode())

    def test_independent_sha256_pin_catches_modified_source_without_git_gate(self):
        altered=deepcopy(M)
        altered["rows"][0]["mm2FirstPartyListed"] += 1
        with self.assertRaisesRegex(TwoPublisherBlocked,"SHA256_PIN_FAILED_MM2"):
            read_pinned(json.dumps(altered).encode(),MM2_SHA256,"MM2")

    def test_supreme_modified_listed_price_git_blob_rejected(self):
        supreme=deepcopy(S)
        supreme["rows"][0]["officialSupremeListed"]+=1
        with self.assertRaisesRegex(TwoPublisherBlocked,"GIT_BLOB_PIN_FAILED"):
            self.task(supreme=json.dumps(supreme).encode())

    def test_prior_supreme_source_and_immutable_raw_registry_rejected_when_modified(self):
        prior=deepcopy(json.loads(PRIOR))
        prior["sourceCapturedUtc"]="2026-11-16T04:30:00Z"
        with self.assertRaisesRegex(TwoPublisherBlocked,"GIT_BLOB_PIN_FAILED"):
            self.task(prior=json.dumps(prior).encode())
        reg=deepcopy(R)
        reg["items"][0]["supremeListed"]=111
        with self.assertRaisesRegex(TwoPublisherBlocked,"GIT_BLOB_PIN_FAILED"):
            self.task(reg=json.dumps(reg).encode())

    def test_missing_raw_key_denied_even_if_price_sum_positive(self):
        mm2=deepcopy(M)
        mm2["rows"][-1]["rawGameKeyCandidate"]="UnknownNewWeapon"
        with self.assertRaisesRegex(TwoPublisherBlocked,"RAW_KEY_COVERAGE_OR_CATEGORY_CHANGED"):
            strictly_compare(mm2,S,R)

    def test_duplicate_raw_key_and_cross_category_denied(self):
        mm2=deepcopy(M)
        mm2["rows"][1]["rawGameKeyCandidate"]=mm2["rows"][0]["rawGameKeyCandidate"]
        with self.assertRaisesRegex(TwoPublisherBlocked,"DUPLICATE_KEY_OR_CATEGORY"):
            strictly_compare(mm2,S,R)
        mm2=deepcopy(M)
        mm2["rows"][0]["category"]="chroma" if mm2["rows"][0]["category"]!="chroma" else "godly"
        with self.assertRaises(TwoPublisherBlocked):
            strictly_compare(mm2,S,R)

    def test_unreviewed_alias_or_accidental_source_swap_denied(self):
        mm2=deepcopy(M)
        row=next(x for x in mm2["rows"] if x["rawGameKeyCandidate"]=="FlowerwoodKnife")
        row["firstPartyName"]="Flowerwood"
        with self.assertRaisesRegex(TwoPublisherBlocked,"MM2_PUBLIC_LABEL_MISMATCH"):
            strictly_compare(mm2,S,R)
        supreme=deepcopy(S)
        row=next(x for x in supreme["rows"] if x["rawGameKeyCandidate"]=="FlowerwoodKnife")
        row["officialName"]="Flowerwood Knife"
        with self.assertRaisesRegex(TwoPublisherBlocked,"SUPREME_PUBLIC_LABEL_MISMATCH"):
            strictly_compare(M,supreme,R)

    def test_client_item_identity_fake_and_protected_outbound_forgery_blocked(self):
        mm2=deepcopy(M)
        mm2["rows"][0]["authenticatedRobloxItemInstance"]=True
        with self.assertRaisesRegex(TwoPublisherBlocked,"UNVERIFIED_CLIENT_INSTANCE_PROMOTED"):
            strictly_compare(mm2,S,R)
        sup=deepcopy(S)
        next(x for x in sup["rows"] if x["rawGameKeyCandidate"]=="Gingerscope")["outgoingGingerscopeProtected"]=False
        with self.assertRaisesRegex(TwoPublisherBlocked,"GINGERSCOPE_GUARD_FAILED"):
            strictly_compare(M,sup,R)

    def test_demand_ordinal_must_not_be_empirical_probability(self):
        mm2=deepcopy(M)
        mm2["rows"][0]["mm2DemandOrdinal"]="NaN"
        with self.assertRaisesRegex(TwoPublisherBlocked,"ORDINAL"):
            strictly_compare(mm2,S,R)
        mm2=deepcopy(M)
        mm2["rows"][0]["mm2DemandOrdinal"]="101"
        with self.assertRaisesRegex(TwoPublisherBlocked,"ORDINAL_OUT_OF_BOUNDS"):
            strictly_compare(mm2,S,R)

    def test_old_aggregator_conflict_false_flaging_blocked(self):
        mm2=deepcopy(M)
        mm2["aggregatorMM2PriceDisagreementKeys"]=[]
        with self.assertRaisesRegex(TwoPublisherBlocked,"MM2_CONFLICT_LIST_FORGED"):
            strictly_compare(mm2,S,R)
        supreme=deepcopy(S)
        supreme["rows"][0]["aggregatorSupremeColumnMismatch"]=(
            not supreme["rows"][0]["aggregatorSupremeColumnMismatch"])
        with self.assertRaisesRegex(TwoPublisherBlocked,"SUPREME_CONFLICT_FLAG_FORGED"):
            strictly_compare(M,supreme,R)

    def test_separate_publisher_ages_never_inferred_from_capture_only(self):
        with self.assertRaisesRegex(TwoPublisherBlocked,"PUBLISHER_EDITION_NOT_CURRENT"):
            strict_age("2026-11-16T04:30:00Z","2026-11-16T04:20:00Z",
                       "2026-10-01T00:00:00Z","MM2")
        with self.assertRaisesRegex(TwoPublisherBlocked,"CAPTURE_FROM_FUTURE"):
            strict_age("2026-11-16T04:00:00Z","2026-11-16T04:20:00Z",
                       "2026-11-15T11:59:41-05:00","SUPREME")

    def test_no_private_data_in_combined_public_receipt(self):
        text=json.dumps(self.task(),sort_keys=True)
        for word in ("ownedInventory","playerUserId","partnerUserId","jobId",
                     "sessionLeaseId","webhookUrl","getgenv","privateKey"):
            with self.subTest(word=word):
                self.assertNotIn(word,text)


if __name__=="__main__":
    unittest.main()
