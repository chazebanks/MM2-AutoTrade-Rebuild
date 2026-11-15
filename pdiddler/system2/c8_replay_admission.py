"""System 2 C8: read-only cross-component replay admission gate.

This is an evidence compatibility check, NOT a trade planner or live execution
controller. Inputs are caller-supplied research receipts; they are not proof of
Roblox observations, Discord delivery, settlement or learning.
"""
from __future__ import annotations

SCHEMA = "gingerscope-system2-c8-replay-admission-v1"
REQUIRED = ("market", "inventory", "bilateral", "growth", "chat", "feedback")
DENIED = dict(readOnly=True, authorizesTrade=False, authorizesOffer=False,
              authorizesAccept=False, authorizesChat=False,
              maySendDiscordWebhook=False, mayReportProfit=False,
              mayUseForStrategyLearning=False, serverCompletionProven=False,
              verifiedTradeAcceptanceProbability=None)

def review(receipts, *, expected_context):
    def stop(reason):
        return dict(schema=SCHEMA, status="BLOCKED", reason=reason, **DENIED)
    if type(receipts) is not dict or type(expected_context) is not dict:
        return stop("C8_INPUT_NOT_MAPPING")
    if set(receipts) != set(REQUIRED):
        return stop("C8_MISSING_OR_EXTRA_COMPONENT")
    # The caller must supply a frozen, nonempty source/session identity.
    keys = ("sourceSha256", "jobId", "leaseId", "partnerUserId",
            "offerRevision", "inventoryCensusSha256")
    if set(expected_context) != set(keys):
        return stop("C8_CONTEXT_SHAPE_INVALID")
    for key in keys:
        v = expected_context[key]
        if key == "offerRevision":
            if type(v) is not int or v < 0:
                return stop("C8_REVISION_INVALID")
        elif key == "partnerUserId":
            if type(v) is not int or v <= 0:
                return stop("C8_PARTNER_INVALID")
        elif type(v) is not str or not v or len(v) > 128:
            return stop("C8_CONTEXT_ID_INVALID")
    for name in REQUIRED:
        item = receipts[name]
        if type(item) is not dict or type(item.get("context")) is not dict:
            return stop("C8_COMPONENT_CONTEXT_MISSING")
        if item["context"] != expected_context:
            return stop("C8_COMPONENT_CONTEXT_DRIFT_" + name.upper())
        # A successful offline component must never claim live authority.
        if item.get("readOnly") is not True:
            return stop("C8_COMPONENT_NOT_READONLY_" + name.upper())
        for flag in ("authorizesTrade", "authorizesOffer", "authorizesAccept",
                     "authorizesChat", "mayUseForStrategyLearning",
                     "mayReportProfit", "maySendDiscordWebhook"):
            if item.get(flag) is not False:
                return stop("C8_COMPONENT_AUTHORITY_LEAK_" + name.upper())
        if item.get("serverCompletionProven") is not False:
            return stop("C8_SETTLEMENT_CLAIM_" + name.upper())
        if type(item.get("status")) is not str or not item["status"]:
            return stop("C8_COMPONENT_STATUS_MISSING_" + name.upper())
        if item["status"] == "BLOCKED":
            return stop("C8_UPSTREAM_BLOCKED_" + name.upper())
    if receipts["feedback"].get("realResponseRewardLabelsForModel") != 0:
        return stop("C8_UNVERIFIED_FEEDBACK_LABELS")
    if receipts["feedback"].get("offerBundleFeaturesAvailableInV2") is not False:
        return stop("C8_V2_FEATURE_PROVENANCE_UNVERIFIED")
    if receipts["feedback"].get("knownTradeSettlements") != 0:
        return stop("C8_SETTLEMENT_NOT_INDEPENDENTLY_PROVEN")
    if receipts["chat"].get("personalReplyProven") is not False:
        return stop("C8_CHAT_RECIPIENT_UNVERIFIED")
    if receipts["growth"].get("goalTargetHypotheticallyReceived") is True:
        # Hypothetical acquisition is permitted, but never settlement.
        pass
    return dict(schema=SCHEMA, status="OFFLINE_C8_COMPONENT_CONTEXTS_ALIGNED",
                reason="REPLAY_SHAPE_ONLY_NO_NATIVE_OR_SERVER_PROOF",
                componentsReviewed=len(REQUIRED),
                featureLevelLearningEvidenceAvailable=False,
                liveSourceBindingProven=False, **DENIED)
