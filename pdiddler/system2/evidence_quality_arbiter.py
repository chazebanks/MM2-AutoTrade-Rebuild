"""System2: independent research evidence matrix for strategy-arbitration gates.

This is not a strategy planner, market ingestion endpoint, trading interface,
or new source parser. It composes existing Stage121, publisher parity, sealed
source decision, revision and long-term risk-policy status receipts by strict
schema. All receipts are caller-supplied (not cryptographic attestations).
No live authority can be promoted, even with all green statuses.

Never store or return a player's weapon keys, inventory, partner IDs, offer
candidates, price rows, outcome claims, or claim a trade was completed.
"""
from __future__ import annotations

from datetime import datetime, timezone
import re

SCHEMA = "gingerscope-system2-evidence-quality-arbiter-v1"
S121 = "gingerscope-stage121-market-evidence-firewall-v1"
PARITY = "gingerscope-system2-three-page-publisher-parity-v1"
SEALED = "gingerscope-system2-sealed-source-decision-v1"
REVISION = "gingerscope-system2-market-inventory-sync-research-v1"
POLICY = "gingerscope-controlled-quality-loss-policy-v1"
KEY_AUDIT = "gingerscope-system2-native-key-reconciliation-batch-v1"
SHADOW = "gingerscope-system2-structural-shadow-batch-v1"
SHA = re.compile(r"^[a-f0-9]{64}$")
UTC = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?Z$")
DENIED = {
    "researchOnly": True,
    "marketSourceUsableForLiveOffer": False,
    "publishedCurrentPriceAuthenticated": False,
    "independentLiveGameKeyIdentityVerified": False,
    "observedCompletedTradeLiquidityVerified": False,
    "verifiedPartnerAppeal": False,
    "verifiedMarketQuote": False,
    "mayFeedStage120AsVerifiedMarket": False,
    "authorizesOffer": False,
    "authorizesTrade": False,
    "authorizesAccept": False,
    "lossTradeAuthorized": False,
    "approvedRiskBudget": False,
    "mayRecordCompletedTrade": False,
    "mayReportProfit": False,
    "maySendDiscordWebhook": False,
    "mayUseForStrategyLearning": False,
    "serverCompletionProven": False,
    "tradeOutcome": "UNKNOWN",
    "liveOfferRankingAuthorized": False,
    "realPlayerInventoryExported": False,
}
EXPECTED_ORIGINAL_SHA = "bb91b545637a0fe8d7dcceebef9070ee9a76210015bdc1737fd78f068acaeb4f"
EXPECTED_ROWS_SHA = "a33d2bace80b1375bd062cb634ee0dc0dff33962bac174814ce7a490dc184c16"
HISTORICAL_STAGE83_PUBLISHER_EXPIRED = "2026-11-09T15:56:07Z"

def _out(status, reason, features=None):
    result = {"schema":SCHEMA, "status":status, "reason":reason,
              "publicOnlyAggregateReceipt":True,
              "trustedCompletedTradeLabels":0,
              "syntheticStrategyReplaysAllowed":False,
              "realTradeCandidateGenerated":False}
    if features is not None:
        result["features"] = features
    return {**result, **DENIED}

def _time(text):
    if type(text) is not str or UTC.fullmatch(text) is None:
        raise ValueError("EVALUATION_UTC_INVALID")
    date = datetime.fromisoformat(text.replace("Z", "+00:00"))
    return date.astimezone(timezone.utc)

def _false_flags(item, keys):
    return all(item.get(k) is False for k in keys)

def _source_stage121(item):
    if item is None:
        return "UNAVAILABLE_ORIGINAL_ARCHIVE_NOT_CAPTURED"
    if type(item) is not dict or item.get("schema") != S121:
        return "INVALID_RESEARCH_SOURCE_RECEIPT"
    if not _false_flags(item, ("authorizesOffer","authorizesTrade",
                              "authorizesAccept","verifiedMarketQuote",
                              "publishedCurrentPriceAuthenticated",
                              "mayFeedStage120AsVerifiedMarket",
                              "mayUseForStrategyLearning")):
        return "REJECT_SOURCE_AUTHORITY_FORGERY"
    if item.get("tradeOutcome")!="UNKNOWN":
        return "REJECT_FALSE_SOURCE_TRADE_OUTCOME"
    if item.get("status")=="RESEARCH_ONLY" and item.get("reason")=="NEW_PUBLISHER_REQUIRES_INDEPENDENT_REVIEW":
        return "NEW_PUBLISHER_CANDIDATE_RESEARCH_ONLY"
    if item.get("status")=="BLOCKED":
        return "STAGE121_SOURCE_BLOCKED"
    return "SOURCE_RESEARCH_STATUS_NOT_ADMITTED"

def _parity(item):
    if item is None:
        return "UNAVAILABLE_FULL_PARITY_RECEIPT_NOT_ADMITTED"
    if type(item) is not dict or item.get("schema") != PARITY:
        return "INVALID_WEBSITE_PARITY_RECEIPT"
    if not _false_flags(item,("publishedCurrentPriceAuthenticated",
                              "authorizesOffer","authorizesTrade",
                              "authorizesAccept","mayFeedStage120AsVerifiedMarket",
                              "mayUseForStrategyLearning")):
        return "REJECT_PARITY_AUTHORITY_FORGERY"
    if (item.get("status")!="RESEARCH_PARITY_CORROBORATED" or
        item.get("sourcePageParity") is not True or
        item.get("websiteMatchedRows")!=189 or
        item.get("operatorExportSha256")!=EXPECTED_ORIGINAL_SHA):
        return "INCOMPLETE_OR_CHANGED_WEBSITE_PARITY"
    try:
        stamp = _time(item.get("confirmedPublisherUtc"))
    except (TypeError,ValueError,OverflowError):
        return "PARITY_PUBLICATION_TIMESTAMP_INVALID"
    pages = item.get("pages")
    if type(pages) is not list or len(pages)!=3:
        return "THREE_CANONICAL_PARITY_PAGES_REQUIRED"
    cats={"ancients","godlies","chromas"}
    names=set()
    for page in pages:
        if type(page) is not dict:
            return "CANONICAL_PAGE_RECEIPT_INVALID"
        name=page.get("category")
        if name not in cats or name in names or page.get("url")!=f"https://supremevalues.com/mm2/{name}":
            return "DUPLICATE_OR_NONCANONICAL_SOURCE_URL"
        names.add(name)
        if page.get("httpStatus")!=200 or
            type(page.get("publishedItemMatches")) is not int or
            type(page.get("sourceHtmlSha256")) is not str or
            SHA.fullmatch(page["sourceHtmlSha256"]) is None:
            return "HTML_CAPTURE_METADATA_UNVERIFIED"
    if names!=cats:
        return "MISSING_PARITY_CATEGORY"
    match={p["category"]:p["publishedItemMatches"] for p in pages}
    if match!={"ancients":15,"godlies":128,"chromas":46}:
        return "PARITY_CATEGORY_COUNTS_CONFLICT"
    if stamp <= _time(HISTORICAL_STAGE83_PUBLISHER_EXPIRED):
        return "SOURCE_PUBLICATION_NOT_NEWER_THAN_OLD_REGISTRY"
    return "RESEARCH_189_PARITY_NOT_AUTHENTICATED_HTTPS"

def _game(item):
    if item is None:
        return "NATIVE_IDENTITY_NOT_INCLUDED_IN_THIS_RESEARCH_RUN"
    if type(item) is not dict or item.get("schema") != KEY_AUDIT:
        return "INVALID_NATIVE_KEY_AUDIT_RECEIPT"
    if (item.get("status") != "CLIENT_KEY_RECONCILIATION_BATCH" or
        item.get("clientOnly") is not True or
        not _false_flags(item,("authorizesOffer","authorizesTrade","authorizesAccept",
                               "currentMarketPriceAuthenticated","publisherEditionBound",
                               "serverCompletionProven"))):
        return "UNVERIFIED_OR_FORGED_CLIENT_IDENTITY"
    features=item.get("features")
    if type(features) is not dict:
        return "NATIVE_KEY_STATUS_MISSING"
    own=features.get("ownedKeyMapping")
    catalog=features.get("currentGameCatalog")
    if (type(own) is not dict or type(catalog) is not dict or
        own.get("status")!="HISTORICAL_KEY_CANDIDATES_MATCH_CLIENT_META" or
        catalog.get("status")!="HISTORICAL_REGISTRY_CLIENT_META_PARITY"):
        return "CLIENT_GAME_KEY_DRIFT_OR_UNKNOWN"
    for field in ("keysOutsideHistoricalRegistry","gameLabelDriftKeys",
                  "structuralMismatchKeys","ownedUnresolvedMetaKeys"):
        if own.get(field)!=0:
            return "CLIENT_GAME_KEY_DRIFT_OR_UNKNOWN"
    return "CLIENT_HISTORICAL_KEY_MAPPING_ONLY"

def _shadow(item):
    if item is None:
        return "STRUCTURAL_SHADOW_NOT_INCLUDED_IN_RESEARCH_RUN"
    if type(item) is not dict or item.get("schema") != SHADOW:
        return "INVALID_STRUCTURAL_SHADOW_RECEIPT"
    if (item.get("status")!="CLIENT_STRUCTURAL_SHADOW_REPORT" or
        item.get("clientOnly") is not True or
        not _false_flags(item,("authorizesOffer","authorizesTrade","authorizesAccept",
                               "verifiedCurrentMarketPrice","publisherEditionAuthenticated",
                               "serverCompletionProven"))):
        return "UNVERIFIED_STRUCTURAL_SHADOW_RECEIPT"
    f=item.get("features")
    if (type(f) is not dict or
        type(f.get("syntheticBilateralModels")) is not dict or
        f["syntheticBilateralModels"].get("status")!="PURE_SYNTHETIC_SCENARIOS_PASSED" or
        f["syntheticBilateralModels"].get("cases")!=10 or
        type(f.get("protectedTarget")) is not dict or
        f["protectedTarget"].get("mayOfferTarget") is not False):
        return "STRUCTURAL_SHADOW_TESTS_INCOMPLETE"
    return "CLIENT_STRUCTURAL_SHADOW_ONLY"

def _decision(item):
    if item is None:
        return "NO_FRESH_SEALED_HYPOTHETICAL_SCENARIO"
    if type(item) is not dict or item.get("schema")!=SEALED:
        return "INVALID_SEALED_DECISION_RECEIPT"
    if (item.get("status")!="SEALED_SOURCE_RESEARCH_ONLY" or
        item.get("sourceRowsPinnedToOriginalOperatorExport") is not True or
        item.get("operatorExportSha256")!=EXPECTED_ORIGINAL_SHA or
        item.get("mappedRowsSha256")!=EXPECTED_ROWS_SHA or
        item.get("clientSessionAuthenticated") is not False or
        item.get("currentGameItemIdentityAuthenticated") is not False or
        not _false_flags(item,("authorizesOffer","authorizesTrade","authorizesAccept",
                               "mayUseForStrategyLearning","mayReportProfit"))):
        return "REJECT_FAKE_SEALED_DECISION"
    mode=item.get("researchMode")
    if mode not in ("SCENARIO","ATTRACTIVENESS","MULTITRADE_GROWTH","COUNTERPARTY_OPTIONS"):
        return "UNRECOGNIZED_SEALED_RESEARCH_MODE"
    result=item.get("researchResult")
    if (type(result) is not dict or
        not _false_flags(result,("authorizesOffer","authorizesTrade",
                                 "authorizesAccept","mayUseForStrategyLearning"))):
        return "REJECT_MUTATED_STRATEGY_RESULT"
    return "SEALED_"+mode+"_HYPOTHETICAL_ONLY"

def _revision(item):
    if item is None:
        return "NO_FRESH_INVENTORY_OFFER_REVISION_PROOF"
    if type(item) is not dict or item.get("schema")!=REVISION:
        return "INVALID_REVISION_RECEIPT"
    if not _false_flags(item,("authorizesOffer","authorizesTrade","authorizesAccept",
                              "publisherEditionAuthenticated","currentGameInventoryProven",
                              "activeTradeSessionProven","currentOfferRevisionProven")):
        return "REJECT_REVISION_AUTHORITY_FORGERY"
    if item.get("status")=="INVALIDATED":
        return "RESEARCH_DECISION_INVALIDATED"
    if item.get("status") in ("RESEARCH_SNAPSHOT_ONLY","UNCHANGED_RESEARCH_ONLY"):
        return "CALLER_SUPPLIED_RESEARCH_REVISION_ONLY"
    return "UNVERIFIED_OR_STALE_REVISION_STATE"

def _risk(item):
    if type(item) is not dict or item.get("schema")!=POLICY:
        return "RISK_POLICY_MISSING_OR_INVALID"
    if (item.get("developmentPermitted") is not True or
        item.get("deploymentAuthorized") is not False or
        item.get("autonomousLossTradesAuthorized") is not False or
        item.get("separateExplicitDeploymentAuthorizationRequired") is not True):
        return "RISK_POLICY_CHANGED_REQUIRES_SEPARATE_AUTHORIZATION"
    budget=item.get("riskBudget")
    if (type(budget) is not dict or
        budget.get("approvalStatus")!="NOT_SPECIFIED_NOT_APPROVED" or
        any(budget.get(k) is not None for k in
            ("maxLossPerTrade","maxCumulativeLoss","maxLossFractionPerTrade",
             "maximumFrequency"))):
        return "RISK_BUDGET_NOT_APPROVED"
    return "LOSS_RESEARCH_ALLOWED_DEPLOYMENT_DENIED"

def assess(*, evaluated_at_utc, source_admission=None, page_parity=None,
           native_key_audit=None, structural_shadow=None, sealed_decision=None,
           revision=None, growth_policy=None, observed_outcomes=None):
    """Analyze already-derived receipts; the caller cannot provide live authority."""
    try:
        now=_time(evaluated_at_utc)
        if type(observed_outcomes) not in (list, type(None)):
            raise ValueError("OUTCOME_EVIDENCE_SHAPE_INVALID")
        if type(observed_outcomes) is list and len(observed_outcomes)>5000:
            raise ValueError("OUTCOME_EVIDENCE_LIMIT")
        outcome_count=0
        unknown=0
        if observed_outcomes is not None:
            for row in observed_outcomes:
                if type(row) is not dict or row.get("kind") not in ("UNKNOWN","DECLINED","CANCELED"):
                    # Completed records need separate server settlement provenance, not raw UI.
                    raise ValueError("UNVERIFIED_COMPLETED_TRADE_OR_OUTCOME_LABEL")
                unknown+=1
        state={
            "sourceAdmission":_source_stage121(source_admission),
            "independentWebsiteParity":_parity(page_parity),
            "nativeGameKeyEvidence":_game(native_key_audit),
            "structuralPlanning":_shadow(structural_shadow),
            "sealedResearchDecision":_decision(sealed_decision),
            "researchRevision":_revision(revision),
            "lossRiskPolicy":_risk(growth_policy),
            "settlementEvidence":"NO_INDEPENDENT_VERIFIED_COMPLETED_TRADES",
        }
        if state["lossRiskPolicy"]!="LOSS_RESEARCH_ALLOWED_DEPLOYMENT_DENIED":
            return _out("BLOCKED","RISK_POLICY_NOT_SAFE",state)
        if any(value.startswith(("REJECT","INVALID","RISK_BUDGET")) for value in state.values()):
            return _out("BLOCKED","ONE_OR_MORE_RESEARCH_RECEIPTS_MUTATED",state)
        if state["researchRevision"]=="RESEARCH_DECISION_INVALIDATED":
            return _out("INVALIDATED","SOURCE_INVENTORY_OR_OFFER_RESEARCH_REVISION_CHANGED",state)
        # The website parity and Stage121 source MAY support offline comparison,
        # NEVER qualify live valuation, offer ranking or automatic final Accept.
        ready=(state["sourceAdmission"]=="NEW_PUBLISHER_CANDIDATE_RESEARCH_ONLY" and
               state["independentWebsiteParity"]=="RESEARCH_189_PARITY_NOT_AUTHENTICATED_HTTPS" and
               state["nativeGameKeyEvidence"]=="CLIENT_HISTORICAL_KEY_MAPPING_ONLY" and
               state["structuralPlanning"]=="CLIENT_STRUCTURAL_SHADOW_ONLY" and
               state["sealedResearchDecision"].startswith("SEALED_") and
               state["researchRevision"]=="CALLER_SUPPLIED_RESEARCH_REVISION_ONLY")
        result=_out("OFFLINE_COHERENCE_RESEARCH_ONLY" if ready else
                    "INCOMPLETE_EVIDENCE_RESEARCH_ONLY",
                    "NO_AUTHENTICATED_SOURCE_AND_SERVER_SESSION_OR_SETTLEMENT",
                    state)
        result["syntheticStrategyReplaysAllowed"]=ready
        return result
    except (ValueError,TypeError,KeyError,OverflowError):
        return _out("BLOCKED","EVIDENCE_ARBITER_INPUT_INVALID")
