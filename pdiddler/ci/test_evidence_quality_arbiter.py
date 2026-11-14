"""Adversarial research-evidence arbitration. Every positive is STILL offline only."""
from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path
import unittest

from pdiddler.system2 import evidence_quality_arbiter as m

UTC="2026-11-14T05:15:40.000Z"
def source():
 return {
  "schema":m.S121,"status":"RESEARCH_ONLY",
  "reason":"NEW_PUBLISHER_REQUIRES_INDEPENDENT_REVIEW",
  "tradeOutcome":"UNKNOWN",
  "authorizesOffer":False,"authorizesTrade":False,"authorizesAccept":False,
  "verifiedMarketQuote":False,"publishedCurrentPriceAuthenticated":False,
  "mayFeedStage120AsVerifiedMarket":False,"mayUseForStrategyLearning":False,
 }
def parity():
 return {
  "schema":m.PARITY,"status":"RESEARCH_PARITY_CORROBORATED",
  "sourcePageParity":True,"websiteMatchedRows":189,
  "confirmedPublisherUtc":"2026-11-13T18:20:00Z",
  "operatorExportSha256":m.EXPECTED_ORIGINAL_SHA,
  "authorizesOffer":False,"authorizesTrade":False,"authorizesAccept":False,
  "mayFeedStage120AsVerifiedMarket":False,"mayUseForStrategyLearning":False,
  "publishedCurrentPriceAuthenticated":False,
  "pages":[{"category":p,"url":f"https://supremevalues.com/mm2/{p}",
           "httpStatus":200,"publishedItemMatches":c,
           "sourceHtmlSha256":"a"*64}
          for p,c in [("ancients",15),("godlies",128),("chromas",46)]],
 }
def key():
 return {
  "schema":m.KEY_AUDIT,"status":"CLIENT_KEY_RECONCILIATION_BATCH",
  "clientOnly":True,"authorizesOffer":False,"authorizesTrade":False,
  "authorizesAccept":False,"currentMarketPriceAuthenticated":False,
  "publisherEditionBound":False,"serverCompletionProven":False,
  "features":{
   "ownedKeyMapping":{
    "status":"HISTORICAL_KEY_CANDIDATES_MATCH_CLIENT_META",
    "keysOutsideHistoricalRegistry":0,"gameLabelDriftKeys":0,
    "structuralMismatchKeys":0,"ownedUnresolvedMetaKeys":0,
    "rawPrivateItemNeverCopied":"PRIVATE_SECRET_CENSUS",
   },
   "currentGameCatalog":{"status":"HISTORICAL_REGISTRY_CLIENT_META_PARITY"}
  }
 }
def shadow():
 return {
  "schema":m.SHADOW,"status":"CLIENT_STRUCTURAL_SHADOW_REPORT",
  "clientOnly":True,"authorizesOffer":False,"authorizesTrade":False,
  "authorizesAccept":False,"verifiedCurrentMarketPrice":False,
  "publisherEditionAuthenticated":False,"serverCompletionProven":False,
  "features":{
   "syntheticBilateralModels":{"status":"PURE_SYNTHETIC_SCENARIOS_PASSED","cases":10},
   "protectedTarget":{"mayOfferTarget":False,"targetOwnershipRevealed":False}
  }
 }
def decision():
 return {
  "schema":m.SEALED,"status":"SEALED_SOURCE_RESEARCH_ONLY",
  "sourceRowsPinnedToOriginalOperatorExport":True,
  "operatorExportSha256":m.EXPECTED_ORIGINAL_SHA,
  "mappedRowsSha256":m.EXPECTED_ROWS_SHA,
  "clientSessionAuthenticated":False,"currentGameItemIdentityAuthenticated":False,
  "researchMode":"ATTRACTIVENESS",
  "authorizesOffer":False,"authorizesTrade":False,"authorizesAccept":False,
  "mayUseForStrategyLearning":False,"mayReportProfit":False,
  "researchResult":{
   "authorizesOffer":False,"authorizesTrade":False,
   "authorizesAccept":False,"mayUseForStrategyLearning":False,
   "sourceWeaponName":"PRIVATE_SHADOW_WEAPON"
  }
 }
def revision():
 return {
  "schema":m.REVISION,"status":"RESEARCH_SNAPSHOT_ONLY",
  "authorizesOffer":False,"authorizesTrade":False,"authorizesAccept":False,
  "publisherEditionAuthenticated":False,"currentGameInventoryProven":False,
  "activeTradeSessionProven":False,"currentOfferRevisionProven":False,
 }
def policy():
 return {
  "schema":m.POLICY,"developmentPermitted":True,
  "deploymentAuthorized":False,"autonomousLossTradesAuthorized":False,
  "separateExplicitDeploymentAuthorizationRequired":True,
  "riskBudget":{"approvalStatus":"NOT_SPECIFIED_NOT_APPROVED",
    "maxLossPerTrade":None,"maxCumulativeLoss":None,
    "maxLossFractionPerTrade":None,"maximumFrequency":None},
 }
def good():
 return {"evaluated_at_utc":UTC,"source_admission":source(),
 "page_parity":parity(),"native_key_audit":key(),
 "structural_shadow":shadow(),"sealed_decision":decision(),
 "revision":revision(),"growth_policy":policy(),"observed_outcomes":[]}

class EvidenceQualityArbiterTests(unittest.TestCase):
 def check(self,k=None):
  q=good() if k is None else k
  r=m.assess(**q)
  self.assertFalse(r["authorizesOffer"],r)
  self.assertFalse(r["authorizesTrade"],r)
  self.assertFalse(r["authorizesAccept"],r)
  self.assertFalse(r["publishedCurrentPriceAuthenticated"],r)
  self.assertFalse(r["mayUseForStrategyLearning"],r)
  self.assertFalse(r["mayFeedStage120AsVerifiedMarket"],r)
  self.assertFalse(r["marketSourceUsableForLiveOffer"],r)
  self.assertFalse(r["liveOfferRankingAuthorized"],r)
  self.assertEqual(r["trustedCompletedTradeLabels"],0)
  return r
 def test_positive_complete_coherent_still_research_only(self):
  x=self.check()
  self.assertEqual(x["status"],"OFFLINE_COHERENCE_RESEARCH_ONLY",x)
  self.assertTrue(x["syntheticStrategyReplaysAllowed"])
  self.assertEqual(x["features"]["sealedResearchDecision"],
                   "SEALED_ATTRACTIVENESS_HYPOTHETICAL_ONLY")
  self.assertFalse(x["realTradeCandidateGenerated"])
  self.assertEqual(x["tradeOutcome"],"UNKNOWN")
  self.assertNotIn("PRIVATE",json.dumps(x))
 def test_missing_stage111_capture_is_not_faked(self):
  x=good();x["source_admission"]=None
  r=self.check(x)
  self.assertEqual(r["status"],"INCOMPLETE_EVIDENCE_RESEARCH_ONLY")
  self.assertEqual(r["features"]["sourceAdmission"],
                   "UNAVAILABLE_ORIGINAL_ARCHIVE_NOT_CAPTURED")
 def test_missing_original_full_parity_receipt_not_admitted(self):
  x=good();x["page_parity"]=None
  r=self.check(x)
  self.assertFalse(r["syntheticStrategyReplaysAllowed"])
 def test_website_parity_188_items_research_incomplete(self):
  x=good();x["page_parity"]["websiteMatchedRows"]=188
  self.assertEqual(self.check(x)["status"],"INCOMPLETE_EVIDENCE_RESEARCH_ONLY")
 def test_site_change_timestamp_old_not_current(self):
  x=good();x["page_parity"]["confirmedPublisherUtc"]="2026-11-08T18:20:00Z"
  self.assertEqual(self.check(x)["features"]["independentWebsiteParity"],
                   "SOURCE_PUBLICATION_NOT_NEWER_THAN_OLD_REGISTRY")
 def test_future_unvalid_timestamp_rejected(self):
  x=good();x["page_parity"]["confirmedPublisherUtc"]="2026-11-31T18:20:00Z"
  self.assertEqual(self.check(x)["features"]["independentWebsiteParity"],
                   "PARITY_PUBLICATION_TIMESTAMP_INVALID")
 def test_duplicate_page_does_not_pass(self):
  x=good();x["page_parity"]["pages"][2]["category"]="godlies"
  self.assertEqual(self.check(x)["status"],"INCOMPLETE_EVIDENCE_RESEARCH_ONLY")
 def test_page_digest_malformed(self):
  x=good();x["page_parity"]["pages"][0]["sourceHtmlSha256"]="not-sha"
  self.assertFalse(self.check(x)["syntheticStrategyReplaysAllowed"])
 def test_modified_page_value_count_detected(self):
  x=good();x["page_parity"]["pages"][0]["publishedItemMatches"]=14
  self.assertEqual(self.check(x)["features"]["independentWebsiteParity"],
                   "PARITY_CATEGORY_COUNTS_CONFLICT")
 def test_forged_source_trade_permission_blocks(self):
  x=good();x["source_admission"]["authorizesAccept"]=True
  self.assertEqual(self.check(x)["status"],"BLOCKED")
 def test_forged_parity_permission_blocks(self):
  x=good();x["page_parity"]["publishedCurrentPriceAuthenticated"]=True
  self.assertEqual(self.check(x)["status"],"BLOCKED")
 def test_changed_historical_game_key_status_not_current(self):
  x=good();x["native_key_audit"]["features"]["ownedKeyMapping"]["keysOutsideHistoricalRegistry"]=1
  self.assertFalse(self.check(x)["syntheticStrategyReplaysAllowed"])
 def test_forged_client_inventory_ownership_blocks(self):
  x=good();x["native_key_audit"]["authorizesTrade"]=True
  self.assertEqual(self.check(x)["status"],"BLOCKED")
 def test_missing_tenth_synthetic_case(self):
  x=good();x["structural_shadow"]["features"]["syntheticBilateralModels"]["cases"]=9
  self.assertEqual(self.check(x)["status"],"INCOMPLETE_EVIDENCE_RESEARCH_ONLY")
 def test_forged_shadow_accept_blocks(self):
  x=good();x["structural_shadow"]["authorizesAccept"]=True
  self.assertEqual(self.check(x)["status"],"BLOCKED")
 def test_forged_sealed_source_sha_blocks(self):
  x=good();x["sealed_decision"]["mappedRowsSha256"]="f"*64
  self.assertEqual(self.check(x)["status"],"INCOMPLETE_EVIDENCE_RESEARCH_ONLY")
 def test_sealed_research_outcome_changed_blocks(self):
  x=good();x["sealed_decision"]["researchResult"]["mayUseForStrategyLearning"]=True
  self.assertEqual(self.check(x)["status"],"BLOCKED")
 def test_revision_changed_not_reusable_even_with_perfect_parity(self):
  x=good();x["revision"]["status"]="INVALIDATED"
  r=self.check(x)
  self.assertEqual(r["status"],"INVALIDATED")
  self.assertFalse(r["syntheticStrategyReplaysAllowed"])
 def test_revision_claims_live_offer_blocked(self):
  x=good();x["revision"]["currentOfferRevisionProven"]=True
  self.assertEqual(self.check(x)["status"],"BLOCKED")
 def test_loss_budget_null_permanent_no_auto_loss(self):
  x=good();x["growth_policy"]["deploymentAuthorized"]=True
  self.assertEqual(self.check(x)["status"],"BLOCKED")
 def test_unapproved_numeric_loss_budget_does_not_open_gate(self):
  x=good();x["growth_policy"]["riskBudget"]["maxLossPerTrade"]=25
  self.assertEqual(self.check(x)["status"],"BLOCKED")
 def test_completed_claim_from_chat_must_not_train_strategy(self):
  x=good();x["observed_outcomes"]=[{"kind":"COMPLETED","source":"CHAT_MSG"}]
  self.assertEqual(self.check(x)["status"],"BLOCKED")
 def test_unknown_or_declined_trades_never_count_success(self):
  x=good();x["observed_outcomes"]=[{"kind":"UNKNOWN"},{"kind":"DECLINED"},{"kind":"CANCELED"}]
  r=self.check(x)
  self.assertEqual(r["trustedCompletedTradeLabels"],0)
  self.assertNotIn("observed_outcomes",r)
 def test_invalid_evaluation_time_blocks(self):
  x=good();x["evaluated_at_utc"]="2026-11-99T05:15:40.000Z"
  self.assertEqual(self.check(x)["status"],"BLOCKED")
 def test_weapons_partner_ids_and_private_values_never_returned(self):
  x=good()
  x["native_key_audit"]["features"]["raw_private_id"]="PRIVATE_OWNER_IDENT"
  x["sealed_decision"]["researchResult"]["secret"]="PRIVATE_META_SECRET"
  x["revision"]["partnerUserId"]=123456789
  r=self.check(x)
  raw=json.dumps(r)
  for forbidden in ("PRIVATE_OWNER_IDENT","PRIVATE_META_SECRET","123456789"):
   self.assertNotIn(forbidden,raw)
 def test_all_modes_stay_research(self):
  for mode in ("SCENARIO","ATTRACTIVENESS","MULTITRADE_GROWTH","COUNTERPARTY_OPTIONS"):
   x=good();x["sealed_decision"]["researchMode"]=mode
   self.assertEqual(self.check(x)["status"],"OFFLINE_COHERENCE_RESEARCH_ONLY")
 def test_unverified_outcome_list_limit(self):
  x=good();x["observed_outcomes"]=[{"kind":"UNKNOWN"}]*5001
  self.assertEqual(self.check(x)["status"],"BLOCKED")
 def test_source_reporting_requires_old_stage121_status(self):
  x=good();x["source_admission"]["status"]="LIVE_SOURCE_APPROVED"
  self.assertEqual(self.check(x)["status"],"INCOMPLETE_EVIDENCE_RESEARCH_ONLY")

if __name__=="__main__":
 unittest.main()
