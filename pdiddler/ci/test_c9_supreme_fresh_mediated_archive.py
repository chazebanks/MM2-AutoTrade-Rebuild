"""Immutable revised official Supreme 189-item capture and fail-closed archive tests."""
from __future__ import annotations

import copy
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import unittest

from pdiddler.system2.c9_supreme_fresh_mediated_archive_gate import (
    C9SupremeRenewalBlocked, audit, git_blob_sha,
    RENEWED_RECEIPT_BLOB, PRIOR_RECEIPT_BLOB, ORIGINAL_CROSSWALK_BLOB,
    REVIEWED_PUBLICATION_ISO, RENEWED_CAPTURE_ISO, PRIOR_CAPTURE_ISO,
)
from pdiddler.system2.c9_supreme_mediated_189_research_gate import (
    validate, SupremeEvidenceBlocked,
)

ROOT = Path(__file__).resolve().parents[2]/"pdiddler/system2"
NEW = (ROOT/"c9_supreme_official_origin_mediated_189_2026_11_16.json").read_bytes()
OLD = (ROOT/"c9_supreme_official_origin_mediated_189_2026_11_15.json").read_bytes()
REG = (ROOT/"c9_research_public_189_crosswalk.json").read_bytes()
AT = "2026-11-16T04:37:05Z"


def new_json():
    return json.loads(NEW)


def old_json():
    return json.loads(OLD)


def reg_json():
    return json.loads(REG)


def clock(base, seconds):
    t = datetime.fromisoformat(base.replace("Z", "+00:00"))
    return (t+timedelta(seconds=seconds)).astimezone(timezone.utc).isoformat().replace("+00:00","Z")


class RevisedOfficialSupreme189(unittest.TestCase):
    def audit(self, renewed=NEW, older=OLD, registry=REG, at=AT):
        return audit(renewed, older, registry, at_utc=at)

    def test_exact_source_git_blobs_are_immutable(self):
        self.assertEqual(git_blob_sha(NEW), RENEWED_RECEIPT_BLOB)
        self.assertEqual(git_blob_sha(OLD), PRIOR_RECEIPT_BLOB)
        self.assertEqual(git_blob_sha(REG), ORIGINAL_CROSSWALK_BLOB)

    def test_new_real_mediate_capture_has_distinct_source_proofs(self):
        new = new_json()
        ids = [x["scrapeId"] for x in new["pageEvidence"].values()]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertEqual(len(ids),4)
        for k in ("home","ancient","godly","chroma"):
            with self.subTest(page=k):
                p=new["pageEvidence"][k]
                self.assertEqual(p["transport"],"Firecrawl rawHtml")
                self.assertEqual(p["statusCode"],200)
                self.assertGreater(p["rawHtmlBytes"],500)
                self.assertTrue(p["url"].startswith("https://supremevalues.com/"))
        self.assertFalse(new["directGitHubRunnerFirstPartyFetchSucceeded"])
        self.assertFalse(new["officialPublisherSignatureVerified"])

    def test_audit_fresh_at_recheck_capture_and_preserves_publisher_edition(self):
        r=self.audit()
        self.assertEqual(r["status"],"FRESH_CAPTURE_RESEARCH_AUDITED_NO_MARKET_OR_TRADE_AUTHORITY")
        self.assertEqual(r["historicalGameKeys"],189)
        self.assertEqual(r["capturedUtc"],RENEWED_CAPTURE_ISO)
        self.assertEqual(r["officialPublisherEdition"],REVIEWED_PUBLICATION_ISO)
        self.assertTrue(r["officialRowsUnchangedSincePreviousSameEdition"])
        self.assertEqual(r["supremeColumnPriorAggregatorConflicts"],34)
        self.assertTrue(r["officialOriginThroughFirecrawl"])
        self.assertFalse(r["directGithubFirstPartyFetchVerified"])
        self.assertFalse(r["currentMm2valuesIndependentSnapshotBound"])

    def test_exact_189_raw_keys_and_retained_census(self):
        a=new_json()
        self.assertEqual(a["matchedHistoricalGameKeys"],189)
        self.assertEqual(a["categoryMatchedCounts"],{"ancient":15,"godly":128,"chroma":46})
        self.assertEqual(len(a["rows"]),189)
        self.assertEqual(len({r["rawGameKeyCandidate"] for r in a["rows"]}),189)
        self.assertEqual(sum(r["outgoingGingerscopeProtected"] for r in a["rows"]),1)
        self.assertEqual(next(r["officialSupremeListed"] for r in a["rows"]
                              if r["rawGameKeyCandidate"]=="Gingerscope"),16000)

    def test_edition_unchanged_does_not_restamp_publisher_clock(self):
        new=new_json()
        old=old_json()
        self.assertEqual(new["sourceOfficialPublicationISO"],old["sourceOfficialPublicationISO"])
        self.assertEqual(new["sourceOfficialPublicationISO"],REVIEWED_PUBLICATION_ISO)
        self.assertNotEqual(new["sourceCapturedUtc"],old["sourceCapturedUtc"])
        self.assertGreater(
            datetime.fromisoformat(new["sourceCapturedUtc"].replace("Z","+00:00")),
            datetime.fromisoformat(old["sourceCapturedUtc"].replace("Z","+00:00"))
        )

    def test_all_189_public_values_demand_stability_ids_match_same_edition(self):
        a={r["rawGameKeyCandidate"]:r for r in new_json()["rows"]}
        b={r["rawGameKeyCandidate"]:r for r in old_json()["rows"]}
        self.assertEqual(set(a),set(b))
        for key in a:
            with self.subTest(key=key):
                for f in ("officialName","officialItemId","officialSupremeListed",
                          "officialDemand","officialStability","category",
                          "outgoingGingerscopeProtected"):
                    self.assertEqual(a[key][f],b[key][f])

    def test_earlier_capture_was_expired_at_new_capture(self):
        evaluated=clock(RENEWED_CAPTURE_ISO,30)
        with self.assertRaisesRegex(SupremeEvidenceBlocked,"CAPTURE_EXPIRED"):
            validate(old_json(),reg_json(),evaluated)
        self.assertEqual(validate(new_json(),reg_json(),evaluated)["matchedHistoricalGameKeys"],189)

    def test_renewed_capture_expires_exactly_after_six_hours(self):
        cap=RENEWED_CAPTURE_ISO
        self.assertEqual(self.audit(at=clock(cap,21600))["sourceAgeSeconds"],21600)
        for offset in (-1,21601):
            with self.subTest(offset=offset),self.assertRaisesRegex(
                C9SupremeRenewalBlocked,"CAPTURE_EXPIRED"
            ):
                self.audit(at=clock(cap,offset))

    def test_new_source_tamper_price_denied_by_blob(self):
        changed=new_json()
        changed["rows"][0]["officialSupremeListed"] += 1
        raw=json.dumps(changed).encode()
        with self.assertRaisesRegex(C9SupremeRenewalBlocked,"GIT_BLOB_MISMATCH_NEW"):
            self.audit(renewed=raw)

    def test_new_source_forged_clock_denied_by_blob(self):
        changed=new_json()
        changed["sourceCapturedUtc"]="2026-11-16T10:00:00Z"
        with self.assertRaisesRegex(C9SupremeRenewalBlocked,"GIT_BLOB_MISMATCH_NEW"):
            self.audit(renewed=json.dumps(changed).encode())

    def test_new_source_forged_capture_id_denied_by_blob(self):
        changed=new_json()
        changed["pageEvidence"]["ancient"]["scrapeId"]=changed["pageEvidence"]["home"]["scrapeId"]
        with self.assertRaisesRegex(C9SupremeRenewalBlocked,"GIT_BLOB_MISMATCH_NEW"):
            self.audit(renewed=json.dumps(changed).encode())

    def test_prior_source_forgery_denied(self):
        changed=old_json()
        changed["sourceCapturedUtc"]="2026-11-16T04:30:00Z"
        with self.assertRaisesRegex(C9SupremeRenewalBlocked,"GIT_BLOB_MISMATCH_OLD"):
            self.audit(older=json.dumps(changed).encode())

    def test_historical_crosswalk_forgery_denied(self):
        changed=reg_json()
        changed["items"][0]["supremeListed"]=500
        with self.assertRaisesRegex(C9SupremeRenewalBlocked,"GIT_BLOB_MISMATCH_REGISTRY"):
            self.audit(registry=json.dumps(changed).encode())

    def test_no_authority_or_sensitive_data_in_public_receipt(self):
        r=self.audit()
        for name in ("researchOnly",):
            self.assertIs(r[name],True)
        for name in ("authorizesTrade","authorizesOffer","authorizesAccept",
                     "safeForLivePricing","mayReportProfit","mayUseForStrategyLearning",
                     "liveRobloxWeaponIdentityVerified","serverTradeSettlementProven",
                     "publisherCryptographicSignatureVerified"):
            self.assertIs(r[name],False)
        text=json.dumps(new_json(),sort_keys=True)
        for word in ("ownedInventory","userId","operatorAltUsername","jobId","leaseId",
                     "webhookUrl","privateKey","getgenv"):
            self.assertNotIn(word,text)


if __name__ == "__main__":
    unittest.main()
