"""S2.7 source-aware Discord-bot -> private ledger -> strategy evidence bridge.

The user's Discord bot/webhooks are the intended feedback source, NOT a
separate invented independent learner. This module consumes the ACTUAL
historical private-ledger v1 format produced by
scripts/discord_private_history_import.py and strict SYNTHETIC future
Discord event fixtures. No Discord HTTP or bot token, no live player
identity, and NEVER save any archive to a public repo.

Historical "MM2 Trade Completed" embeds are webhook SELF-REPORTS, not
authenticated game settlement. They may describe *claimed* values but cannot
train actual profit, acceptance, retrade liquidity or trade-completion models.
Future rejected/timeout/offer-change messages require their own attributed
event evidence; v1 historical importer currently captures only completions.
"""
from __future__ import annotations

import json
import re
from collections import Counter

from scripts.discord_private_history_import import (
    SCHEMA as HISTORICAL_SCHEMA, APPROVED_CHANNEL,
)
from pdiddler.system2.counterparty_response_learning_lab import replay as replay_reactions

SCHEMA = "gingerscope-system2-discord-learning-evidence-bridge-v1"
WEBHOOK_FIXTURE_SCHEMA = "SYNTHETIC_DISCORD_FEEDBACK_EVENT_V2_DRAFT"
CLIENT_REACTION_SCHEMA = "SYNTHETIC_S2_RESPONSE_EVENT"
SNOWFLAKE = re.compile(r"[0-9]{17,20}\Z")
CLASSIFICATIONS = {
    "PARSED_UNVERIFIED_WEBHOOK_CLAIM",
    "TEST_ACCOUNT_EXCLUDED",
    "AMBIGUOUS_TRADE_EMBEDS",
    "UNKNOWN_EMBED_STRUCTURE",
    "UNKNOWN_TRADER_EXCLUDED",
    "INCOMPLETE_TRADE_CLAIM",
    "UNPARSEABLE_ITEM_BUNDLE",
    "UNPARSEABLE_VALUE_CLAIM",
    "INCONSISTENT_VALUE_CLAIM",
}
AUTHORIZED_V1 = {
    "schema", "source", "channel_id", "message_id",
    "source_webhook_id", "webhook_source_pinned",
    "discord_message_timestamp_utc", "classification",
    "server_settlement", "completed_trade_verified",
    "learning_eligible", "authorizes_trade", "authorizes_accept",
    "may_report_profit", "counterparty_category",
}
V1_CLAIM_EXTRA = {"claimed_trade"}
V1_QUARANTINE_EXTRA = {"recover_from_discord_by_message_id"}
DENIED = {
    "researchOnly": True,
    "privateArchiveRequired": True,
    "actualDiscordNetworkRead": False,
    "botTokenRead": False,
    "archiveContentsExported": False,
    "realPlayerIdsExported": False,
    "weaponNamesExported": False,
    "rawTradeMessageIdsExported": False,
    "historicalWebhookClaimsVerifiedAsSettlement": False,
    "independentServerTransactionAuthenticated": False,
    "verifiedCompletedTradesForLearning": 0,
    "attributedRealPartnerRefusalsForLearning": 0,
    "realRetradeFillEvidence": 0,
    "realAcceptanceProbability": None,
    "mayLearnProfitFromHistoricalSelfReports": False,
    "mayUpdateLiveTradingPolicy": False,
    "mayUseForStrategyLearning": False,
    "mayReportProfit": False,
    "maySendDiscordWebhook": False,
    "authorizesOffer": False,
    "authorizesTrade": False,
    "authorizesAccept": False,
    "publicAutoAcceptAuthorized": False,
    "mainAltAutoAcceptAuthorizedByThisAdapter": False,
    "serverCompletionProven": False,
    "tradeOutcome": "UNKNOWN",
}

def _out(status, reason, **fields):
    return {"schema": SCHEMA, "status": status, "reason": reason,
            **fields, **DENIED}

def _is_snowflake(value):
    return type(value) is str and SNOWFLAKE.fullmatch(value) is not None

def _receipt_error(record):
    if type(record) is not dict:
        return "HISTORICAL_ROW_NOT_OBJECT"
    keys = set(record)
    if not AUTHORIZED_V1.issubset(keys):
        return "HISTORICAL_REQUIRED_FIELDS_MISSING"
    if record.get("schema") != HISTORICAL_SCHEMA or (
        record.get("source") != "HISTORICAL_DISCORD_WEBHOOK_SELF_REPORT"
    ):
        return "HISTORICAL_IMPORT_SCHEMA_OR_SOURCE_INVALID"
    if record["channel_id"] != APPROVED_CHANNEL or not (
        _is_snowflake(record["message_id"]) and
        _is_snowflake(record["source_webhook_id"])
    ):
        return "HISTORICAL_CHANNEL_OR_MESSAGE_REFERENCE_INVALID"
    if type(record["webhook_source_pinned"]) is not bool:
        return "HISTORICAL_SOURCE_PIN_SHAPE_INVALID"
    if record.get("server_settlement") != "UNKNOWN" or any(
        record.get(f) is not False for f in (
            "completed_trade_verified", "learning_eligible",
            "authorizes_trade", "authorizes_accept", "may_report_profit",
        )
    ):
        return "HISTORICAL_UNVERIFIED_AUTHORITY_FORGERY"
    classification = record.get("classification")
    if classification not in CLASSIFICATIONS:
        return "HISTORICAL_CLASSIFICATION_UNKNOWN"
    if record.get("discord_message_timestamp_utc") is not None and (
        type(record["discord_message_timestamp_utc"]) is not str or
        len(record["discord_message_timestamp_utc"]) > 32
    ):
        return "HISTORICAL_TIMESTAMP_SHAPE_INVALID"
    if classification == "TEST_ACCOUNT_EXCLUDED":
        if keys != AUTHORIZED_V1 or record["counterparty_category"] != "TEST_ACCOUNT":
            return "TEST_ACCOUNT_DATA_MUST_NOT_REACH_LEARNER"
    elif classification == "PARSED_UNVERIFIED_WEBHOOK_CLAIM":
        if keys != AUTHORIZED_V1 | V1_CLAIM_EXTRA:
            return "HISTORICAL_PARSED_ROW_FIELDS_INVALID"
        if record["counterparty_category"] != "NON_TEST_TRADER_UNVERIFIED":
            return "HISTORICAL_TRADER_CLASSIFICATION_INVALID"
        claimed = record["claimed_trade"]
        if type(claimed) is not dict or set(claimed) != {
            "mode", "gave", "received", "listed_gave_at_notification",
            "listed_received_at_notification", "reported_listed_gain"
        }:
            return "HISTORICAL_UNVERIFIED_CLAIM_SHAPE_INVALID"
        # The old parser already performs listed-value arithmetic. We do NOT
        # reopen or use this alleged profit for strategy learning.
        if (type(claimed["gave"]) is not list or
            type(claimed["received"]) is not list):
            return "HISTORICAL_ITEM_LIST_SHAPE_INVALID"
    else:
        if keys != AUTHORIZED_V1 | V1_QUARANTINE_EXTRA or (
            record["counterparty_category"] != "UNKNOWN_OR_UNRECONCILED" or
            record["recover_from_discord_by_message_id"] is not True
        ):
            return "HISTORICAL_QUARANTINE_SHAPE_INVALID"
    return None

def review(archived_records, *, synthetic_future_webhook_events=None):
    """Validate the existing Discord bot private archive and future event design.

    Idempotency: duplicate identical Discord message receipts are counted
    once; changed same-ID content blocks the entire analysis. The only
    present source of real archive records is a PRIVATE repo; this function
    never fetches it itself or exposes identifiers/items.
    """
    try:
        if type(archived_records) is not list or not 1 <= len(archived_records) <= 1000:
            raise ValueError("PRIVATE_ARCHIVE_BATCH_REQUIRED")
        seen = {}
        counts = Counter()
        pinned = 0
        for record in archived_records:
            problem = _receipt_error(record)
            if problem is not None:
                raise ValueError(problem)
            key = record["message_id"]
            fingerprint = json.dumps(record, sort_keys=True, ensure_ascii=True,
                                     separators=(",",":"), allow_nan=False)
            if key in seen:
                if seen[key] != fingerprint:
                    raise ValueError("DUPLICATE_DISCORD_RECEIPT_MUTATED")
                counts["identical_message_redelivery"] += 1
                continue
            seen[key] = fingerprint
            classification = record["classification"]
            counts[classification] += 1
            pinned += int(record["webhook_source_pinned"])
        result = {
            "distinctArchivedWebhookMessages": len(seen),
            "identicalMessageRedeliveries": counts["identical_message_redelivery"],
            "historicalSelfReportedCompletedClaims":
                counts["PARSED_UNVERIFIED_WEBHOOK_CLAIM"],
            "excludedExactTestAccountReceipts": counts["TEST_ACCOUNT_EXCLUDED"],
            "quarantinedMalformedOrAmbiguousReceipts": sum(
                value for label,value in counts.items()
                if label not in {"PARSED_UNVERIFIED_WEBHOOK_CLAIM",
                                 "TEST_ACCOUNT_EXCLUDED", "identical_message_redelivery"}
            ),
            "locallyPinnedWebhookIdClaims": pinned,
            "allHistoricalClaimsRemainUnverified": True,
            "futureWebhookOutcomeEventsActuallyCaptured": 0,
            "syntheticFutureResponseEpisodesTested": 0,
            "actualDiscordRejectionEventPipelineImplemented": False,
        }
        # Optional future webhook V2 contract is a proposal tested with
        # SYNTHETIC events ONLY. The real existing Discord importer has
        # completed-trade reports, not attributable DECLINE denominators.
        if synthetic_future_webhook_events is not None:
            events = synthetic_future_webhook_events
            if type(events) is not list or not 1 <= len(events) <= 1000:
                raise ValueError("SYNTHETIC_DISCORD_EVENT_BATCH_REQUIRED")
            converted = []
            for rec in events:
                if (type(rec) is not dict or set(rec) != {
                    "schema", "kind", "episode", "seq", "revision", "scope"
                } or rec["schema"] != WEBHOOK_FIXTURE_SCHEMA or
                    rec["scope"] != "SYNTHETIC_DISCORD_BOT_TEST_ONLY"):
                    raise ValueError("FUTURE_DISCORD_EVENT_CONTRACT_INVALID")
                converted.append({
                    "schema": CLIENT_REACTION_SCHEMA,
                    "kind": rec["kind"],"episode": rec["episode"],
                    "seq":rec["seq"],"revision":rec["revision"],
                    "scope":"SYNTHETIC_MAIN_PARTNER_ONLY",
                })
            reactions = replay_reactions(converted)
            if reactions.get("status") != (
                "OFFLINE_DIFFERENT_BEHAVIOR_TRAJECTORIES_REPLAYED"
            ) or reactions.get("mayUseForStrategyLearning") is not False:
                raise ValueError("UNVERIFIED_RESPONSE_SEQUENCE_INVALID")
            result["syntheticFutureResponseEpisodesTested"] = reactions[
                "distinctSyntheticEpisodes"
            ]
            result["syntheticFutureReactionClasses"] = sorted(
                reactions["outcomeDistribution"]
            )
            result["futureWebhookOutcomeEventsActuallyCaptured"] = 0
        return _out(
            "DISCORD_ARCHIVE_TO_S2_EVIDENCE_RESEARCH_ONLY",
            "EXISTING_WEBHOOK_IS_REPORTING_CHANNEL_NOT_SERVER_PROOF",
            **result,
        )
    except (ValueError,TypeError,KeyError,AttributeError,OverflowError) as exc:
        code = str(exc)
        allowed = {
            "PRIVATE_ARCHIVE_BATCH_REQUIRED",
            "HISTORICAL_ROW_NOT_OBJECT",
            "HISTORICAL_REQUIRED_FIELDS_MISSING",
            "HISTORICAL_IMPORT_SCHEMA_OR_SOURCE_INVALID",
            "HISTORICAL_CHANNEL_OR_MESSAGE_REFERENCE_INVALID",
            "HISTORICAL_SOURCE_PIN_SHAPE_INVALID",
            "HISTORICAL_UNVERIFIED_AUTHORITY_FORGERY",
            "HISTORICAL_CLASSIFICATION_UNKNOWN",
            "HISTORICAL_TIMESTAMP_SHAPE_INVALID",
            "TEST_ACCOUNT_DATA_MUST_NOT_REACH_LEARNER",
            "HISTORICAL_PARSED_ROW_FIELDS_INVALID",
            "HISTORICAL_TRADER_CLASSIFICATION_INVALID",
            "HISTORICAL_UNVERIFIED_CLAIM_SHAPE_INVALID",
            "HISTORICAL_ITEM_LIST_SHAPE_INVALID",
            "HISTORICAL_QUARANTINE_SHAPE_INVALID",
            "DUPLICATE_DISCORD_RECEIPT_MUTATED",
            "SYNTHETIC_DISCORD_EVENT_BATCH_REQUIRED",
            "FUTURE_DISCORD_EVENT_CONTRACT_INVALID",
            "UNVERIFIED_RESPONSE_SEQUENCE_INVALID",
        }
        return _out("BLOCKED", code if code in allowed else
                    "ARCHIVE_OR_EVENT_EVIDENCE_INVALID")
