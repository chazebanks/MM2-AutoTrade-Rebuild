"""S2.7 strict Discord V2 event-envelope intake for the EXISTING private bot.

Source-only adapter: a private Discord bot may call review() on receipts it
actually collected. This module itself does NOT authenticate Discord transport,
read any channel, send any webhook, verify MM2 settlement, or update a learner.

No user names/IDs, raw item labels, account secrets or Discord IDs are returned.
V1 'MM2 Trade Completed' embeds are NOT V2 behavioral evidence.
"""
from __future__ import annotations

from collections import Counter
from datetime import datetime, timezone
from hashlib import sha256
import json
import re

SCHEMA = "gingerscope-discord-bot-v2-client-event-envelope-v1"
SOURCE = "PRIVATE_BOT_CLIENT_EVENT_CLAIM_NOT_SERVER_SETTLEMENT"
CLIENT_PROOF = "BOUND_CLIENT_OBSERVATION_UNVERIFIED_SERVER"
SNOWFLAKE = re.compile(r"[0-9]{17,20}\Z")
DIGEST = re.compile(r"[a-f0-9]{64}\Z")
ALLOWED = {
    "MAIN_REQUEST_PENDING", "PARTNER_REQUEST_ACCEPTED",
    "PARTNER_OFFER_REVISION", "MAIN_OFFER_REVISION",
    "PARTNER_DECLINED", "PARTNER_NO_RESPONSE_TIMEOUT",
    "PARTNER_CANCELLED", "MAIN_CANCELLED",
    "PARTNER_ACCEPT_INDICATOR", "MAIN_ACCEPT_INDICATOR",
    "CLIENT_WINDOW_CLOSED_UNKNOWN", "CLIENT_INVENTORY_DELTA_OBSERVED",
    "CHAT_DIRECT_CLIENT_ATTRIBUTED", "CHAT_AMBIGUOUS", "CHAT_OTHER_CONVERSATION",
}
CHATS = {x for x in ALLOWED if x.startswith("CHAT_")}
TERMINAL = {
    "PARTNER_DECLINED", "PARTNER_NO_RESPONSE_TIMEOUT",
    "PARTNER_CANCELLED", "MAIN_CANCELLED", "CLIENT_WINDOW_CLOSED_UNKNOWN",
}
KEYS = {
    "schema", "source", "scope", "channel_id", "message_id", "webhook_id",
    "recorded_at_utc", "event_id", "job_digest", "session_digest",
    "partner_digest", "lease_digest", "event_seq", "revision", "kind",
    "client_provenance",
}
DENY = {
    "privateBotNetworkDeliveryAuthenticated": False,
    "clientIdentityServerAuthenticated": False,
    "gameServerSettlementVerified": False,
    "historicalV1ClaimsUsedAsRewards": False,
    "realPlayerAcceptanceProbability": None,
    "mayUseForStrategyLearning": False,
    "mayReportProfit": False,
    "maySendDiscordWebhook": False,
    "authorizesOffer": False,
    "authorizesTrade": False,
    "authorizesAccept": False,
    "publicFinalAcceptAuthorized": False,
    "tradeOutcome": "UNKNOWN",
}
def _out(status, reason, **fields):
    return {"schema": "gingerscope-system2-private-discord-v2-intake-research-v1",
            "status": status, "reason": reason, **fields, **DENY}

def _error(code):
    return _out("BLOCKED", code)

def _utc(value):
    if type(value) is not str or len(value) > 40:
        raise ValueError("DISCORD_V2_TIMESTAMP_INVALID")
    try:
        dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
        if dt.tzinfo is None:
            raise ValueError
        return dt.astimezone(timezone.utc)
    except (ValueError, OverflowError):
        raise ValueError("DISCORD_V2_TIMESTAMP_INVALID") from None

def _canon(row):
    return json.dumps(row, sort_keys=True, separators=(",", ":"),
                      ensure_ascii=False, allow_nan=False)

def review(rows, *, expected_channel_id, expected_webhook_id):
    """Parse 1–1000 caller-supplied private-bot V2 envelopes with strict lineage.

    Distinguishes explicit partner decline, no response, partner cancel, changed
    offer and UNKNOWN closure. No receipt is itself Discord delivery proof.
    Duplicate identical Discord message ID is idempotent; mutation fails.
    No session may switch job/partner/lease, roll back revisions or invent seq.
    """
    try:
        if (type(rows) is not list or not 1 <= len(rows) <= 1000 or
            type(expected_channel_id) is not str or
            not SNOWFLAKE.fullmatch(expected_channel_id) or
            type(expected_webhook_id) is not str or
            not SNOWFLAKE.fullmatch(expected_webhook_id)):
            raise ValueError("PRIVATE_BOT_V2_INPUT_OR_EXPECTED_SOURCE_INVALID")
        unique = {}
        seen_events = set()
        sessions = {}
        counts = Counter()
        same_message_redeliveries = 0
        for row in rows:
            if type(row) is not dict or set(row) != KEYS or any(
                type(v) is bool for v in (row.get("event_seq"), row.get("revision"))
            ):
                raise ValueError("DISCORD_V2_FIELDS_NOT_EXACT")
            if (row["schema"] != SCHEMA or row["source"] != SOURCE or
                row["client_provenance"] != CLIENT_PROOF or
                row["scope"] not in ("MAIN_ALT_TEST","PUBLIC_CLIENT_OBSERVATION")
                or row["channel_id"] != expected_channel_id or
                row["webhook_id"] != expected_webhook_id or
                type(row["message_id"]) is not str or
                not SNOWFLAKE.fullmatch(row["message_id"])):
                raise ValueError("DISCORD_V2_CHANNEL_SOURCE_OR_SCOPE_INVALID")
            if (any(type(row[k]) is not str or not DIGEST.fullmatch(row[k])
                   for k in ("event_id","job_digest","session_digest",
                             "partner_digest","lease_digest")) or
                type(row["event_seq"]) is not int or not 1 <= row["event_seq"] <= 1000 or
                type(row["revision"]) is not int or not 0 <= row["revision"] <= 1000 or
                type(row["kind"]) is not str or row["kind"] not in ALLOWED):
                raise ValueError("DISCORD_V2_EVENT_BINDING_OR_KIND_INVALID")
            _utc(row["recorded_at_utc"])
            key = row["message_id"]
            canonical = _canon(row)
            if key in unique:
                if unique[key] != canonical:
                    raise ValueError("DISCORD_V2_MUTATED_DUPLICATE_RECEIPT")
                same_message_redeliveries += 1
                continue
            if row["event_id"] in seen_events:
                raise ValueError("DISCORD_V2_EVENT_REPLAYED_WITH_DIFFERENT_MESSAGE")
            seen_events.add(row["event_id"])
            unique[key] = canonical
            sid = row["session_digest"]
            identity = (row["job_digest"],row["partner_digest"],
                        row["lease_digest"],row["scope"])
            seq, revision, kind = row["event_seq"],row["revision"],row["kind"]
            if sid not in sessions:
                if len(sessions) >= 32:
                    raise ValueError("DISCORD_V2_TOO_MANY_SESSIONS")
                if (seq,revision,kind) != (1,0,"MAIN_REQUEST_PENDING"):
                    raise ValueError("DISCORD_V2_REQUEST_BASELINE_REQUIRED")
                sessions[sid] = {"identity":identity,"seq":1,"revision":0,
                                 "phase":"PENDING", "accepted":False}
                counts["REQUEST_PENDING"] += 1
                continue
            state = sessions[sid]
            if identity != state["identity"]:
                raise ValueError("DISCORD_V2_PARTNER_JOB_OR_LEASE_SWITCH")
            if state["phase"] == "TERMINAL":
                raise ValueError("DISCORD_V2_EVENT_AFTER_TERMINAL")
            if seq != state["seq"]+1:
                raise ValueError("DISCORD_V2_OUT_OF_ORDER_OR_GAP")
            state["seq"] = seq
            if kind in ("PARTNER_OFFER_REVISION","MAIN_OFFER_REVISION"):
                if state["phase"] != "IN_TRADE" or revision != state["revision"]+1:
                    raise ValueError("DISCORD_V2_UNBOUND_OFFER_REVISION")
                state["revision"] = revision
                state["accepted"] = False
                counts["REVISION"] += 1
            elif revision != state["revision"]:
                raise ValueError("DISCORD_V2_STALE_OR_FUTURE_REVISION")
            elif kind == "PARTNER_REQUEST_ACCEPTED":
                if state["phase"] != "PENDING":
                    raise ValueError("DISCORD_V2_ACCEPTED_REQUEST_OUT_OF_PHASE")
                state["phase"] = "IN_TRADE"
                counts["REQUEST_ACCEPTED_CLIENT_ONLY"] += 1
            elif kind == "MAIN_REQUEST_PENDING":
                raise ValueError("DISCORD_V2_DUPLICATE_PENDING")
            elif kind == "PARTNER_NO_RESPONSE_TIMEOUT":
                if state["phase"] != "PENDING":
                    raise ValueError("DISCORD_V2_TIMEOUT_NOT_PENDING")
                state["phase"] = "TERMINAL"
                counts["CENSORED_NO_RESPONSE"] += 1
            elif kind == "PARTNER_DECLINED":
                if state["phase"] != "PENDING":
                    raise ValueError("DISCORD_V2_DECLINE_AFTER_TRADE_MISCLASSIFIED")
                state["phase"] = "TERMINAL"
                counts["EXPLICIT_PARTNER_DECLINE_CLIENT"] += 1
            elif kind in ("PARTNER_CANCELLED","MAIN_CANCELLED",
                          "CLIENT_WINDOW_CLOSED_UNKNOWN"):
                if state["phase"] != "IN_TRADE":
                    raise ValueError("DISCORD_V2_CANCEL_OR_CLOSE_BEFORE_TRADE")
                state["phase"] = "TERMINAL"
                counts[kind] += 1
            elif kind in ("PARTNER_ACCEPT_INDICATOR","MAIN_ACCEPT_INDICATOR",
                          "CLIENT_INVENTORY_DELTA_OBSERVED"):
                if state["phase"] != "IN_TRADE":
                    raise ValueError("DISCORD_V2_ACCEPT_INDICATOR_OUT_OF_PHASE")
                counts["CLIENT_INDICATOR_NO_SETTLEMENT"] += 1
            elif kind in CHATS:
                counts[kind] += 1
            else:
                raise ValueError("DISCORD_V2_UNSUPPORTED_EVENT")
        ordered = sorted(unique.values())
        digest = sha256(("\n".join(ordered)).encode("utf-8")).hexdigest()
        num_test = sum(1 for s in sessions.values()
                       if s["identity"][3]=="MAIN_ALT_TEST")
        return _out(
            "PRIVATE_BOT_V2_ENVELOPE_SHAPE_REVIEW_ONLY",
            "VALIDATED_ATTRIBUTION_NOT_DISCORD_TRANSPORT_OR_GAME_SETTLEMENT",
            sourceEnvelopeShapeValid=True,
            rawSourceIdsOrPlayerNamesReturned=False,
            privateArchiveOrDiscordNetworkActuallyAccessed=False,
            messageClaimCount=len(unique),
            idempotentRedeliveries=same_message_redeliveries,
            distinctSessionCount=len(sessions),
            exactMainAltTestSessionsExcludedFromLearning=num_test,
            kindCounts=dict(sorted(counts.items())),
            canonicalClaimSetSha256=digest,
            realTrainingRowsAuthorized=0,
        )
    except (ValueError,TypeError,KeyError,OverflowError) as err:
        code=str(err) if str(err).startswith("DISCORD_V2_") or str(err).startswith("PRIVATE_BOT_V2_") else "DISCORD_V2_MALFORMED_INPUT"
        return _error(code)
