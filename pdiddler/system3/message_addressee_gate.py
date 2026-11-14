"""System 3: synthetic, fail-closed message addressee gate.

This does NOT read Roblox chat, send chat, or authorize trades. It models
the difference between an identified SPEAKER and a verified RECIPIENT.
A global-chat message from the active trade partner is NOT intrinsically
addressed to us. Textual @mentions are NOT authenticated user identities.

The eventual live integration must obtain player UserIds/channel ownership
from Roblox's permitted platform APIs. Under platform-integrated chat
raw message text can be unavailable; fail closed, never bypass restrictions.
"""
from __future__ import annotations
import re

SCHEMA = "gingerscope-system3-synthetic-addressee-gate-v1"
CONTEXT_KIND = "SYNTHETIC_ACTIVE_TRADE_CONTEXT"
MESSAGE_KIND = "SYNTHETIC_ACCESSIBLE_CHAT_MESSAGE"
MAX_OBSERVATION_LAG_MS = 60000
REPLY_CONTEXT_MS = 25000
OFFER_CONTEXT_MS = 15000
_USERNAME = re.compile(r"^[A-Za-z0-9_]{3,20}$")
_WHISPER = re.compile(r"^RBXWhisper:([1-9]\d*)_([1-9]\d*)$")

CONTEXT_FIELDS = {
    "kind", "localUserId", "localUsername", "partnerUserId",
    "jobId", "tradeLeaseId", "offerRevision", "activeTrade",
    "leaseStartedMs", "nowMs", "chatTextSupported",
    "lastOurMessageId", "lastOurMessageAtMs",
    "lastOurMessageWasToPartner", "lastOfferChangedAtMs",
    "competingConversationObserved", "otherUsernames",
    "seenMessageIds", "visibleOfferItemNames",
}
MESSAGE_FIELDS = {
    "kind", "senderUserId", "channelName", "text", "jobId",
    "tradeLeaseId", "offerRevision", "observedAtMs", "messageId",
    "inReplyToMessageId",
}


def _result(status, reason, **extra):
    return {
        "schema": SCHEMA,
        "status": status,
        "reason": reason,
        "speakabilityFromOfficialChannelVerified": False,
        "senderIdentityProvenByRealRobloxEvent": False,
        "recipientProvenByRealRobloxEvent": False,
        "tradeOutcome": "UNKNOWN",
        "mayAnalyzeHypotheticalIntent": status == "DIRECTED_RESEARCH_ONLY",
        "mayPrepareManualReplySuggestion": status in {
            "DIRECTED_RESEARCH_ONLY", "LIKELY_TRADE_CONTEXT_UNPROVEN"
        },
        "maySendChatAutomatically": False,
        "mayChangeOffer": False,
        "mayAcceptTrade": False,
        "mayLearnConfirmedPlayerPreferences": False,
        "mayRecordCompletedTrade": False,
        "mayReportProfit": False,
        **extra,
    }


def _uid(value):
    return type(value) is int and value > 0


def _positive_millis(value):
    return type(value) is int and value >= 0


def _mentioned(text, username):
    # Username is unique by platform account but visible text mentioning it
    # still does not establish that the name's owner sent the message.
    return re.search(
        r"(?<![A-Za-z0-9_])@?" + re.escape(username) + r"(?![A-Za-z0-9_])",
        text, re.IGNORECASE
    ) is not None


def _direct_username_address(text, username):
    # Explicit vocative / @mention, not mere third-person reference.
    username_escaped = re.escape(username)
    at = r"(?<![A-Za-z0-9_])@" + username_escaped + r"(?![A-Za-z0-9_])"
    initial = r"^\s*" + username_escaped + r"(?:\s*[:,!?]|\s+(?:can|could|will|do|would|what|why|hey|pls|please|add|offer)\b)"
    return bool(re.search(at, text, flags=re.IGNORECASE) or
                re.search(initial, text, flags=re.IGNORECASE))


def _trade_language(text, item_names):
    lowered = text.casefold()
    # Contextual evidence only; these patterns are deliberately NOT an
    # MM2 chat-understanding algorithm or verified psychological inference.
    if re.search(
        r"\b(add|offer|offers|trade|nty|underpay|overpay|op|up|"
        r"accept|decline|what for|what do you want|can u add|can you add)\b",
        lowered
    ):
        return True
    return any(
        len(item) >= 3 and _mentioned(text, item)
        for item in item_names
    )


def inspect(context, message):
    """Evaluate synthetic structured events; never infer addressee from text alone."""
    try:
        if (type(context) is not dict or type(message) is not dict
                or set(context) != CONTEXT_FIELDS
                or set(message) != MESSAGE_FIELDS
                or context["kind"] != CONTEXT_KIND
                or message["kind"] != MESSAGE_KIND):
            return _result("BLOCKED", "SOURCE_SCHEMA_OR_SYNTHETIC_MODE_INVALID")
        self_id, partner_id = context["localUserId"], context["partnerUserId"]
        if (not _uid(self_id) or not _uid(partner_id) or self_id == partner_id
                or type(context["localUsername"]) is not str
                or not _USERNAME.fullmatch(context["localUsername"])
                or type(context["jobId"]) is not str or not context["jobId"]
                or type(context["tradeLeaseId"]) is not str
                or not context["tradeLeaseId"]
                or type(context["offerRevision"]) is not int
                or context["offerRevision"] < 0
                or type(context["activeTrade"]) is not bool
                or type(context["chatTextSupported"]) is not bool
                or type(context["competingConversationObserved"]) is not bool
                or type(context["lastOurMessageWasToPartner"]) is not bool
                or not _positive_millis(context["leaseStartedMs"])
                or not _positive_millis(context["nowMs"])
                or context["leaseStartedMs"] > context["nowMs"]):
            return _result("BLOCKED", "CONTEXT_IDENTITY_OR_TIME_INVALID")
        if (type(context["otherUsernames"]) is not list
                or any(type(n) is not str or not _USERNAME.fullmatch(n)
                       for n in context["otherUsernames"])
                or type(context["seenMessageIds"]) is not list
                or any(type(n) is not str for n in context["seenMessageIds"])
                or type(context["visibleOfferItemNames"]) is not list
                or any(type(n) is not str or len(n) > 80
                       for n in context["visibleOfferItemNames"])):
            return _result("BLOCKED", "CONTEXT_ROSTER_OR_HISTORY_INVALID")
        for key in ("lastOurMessageAtMs", "lastOfferChangedAtMs"):
            if context[key] is not None and not _positive_millis(context[key]):
                return _result("BLOCKED", "CONTEXT_HISTORY_CLOCK_INVALID")
        if (context["lastOurMessageId"] is not None
                and type(context["lastOurMessageId"]) is not str):
            return _result("BLOCKED", "CONTEXT_HISTORY_ID_INVALID")
        if not context["activeTrade"]:
            return _result("NOT_FOR_ACTIVE_TRADE", "NO_ACTIVE_TRADE")
        if not context["chatTextSupported"]:
            return _result("TEXT_UNAVAILABLE", "PLATFORM_CHAT_TEXT_NOT_ACCESSIBLE")
        if (not _uid(message["senderUserId"])
                or type(message["messageId"]) is not str
                or not message["messageId"]
                or type(message["text"]) is not str
                or type(message["channelName"]) is not str
                or type(message["jobId"]) is not str
                or type(message["tradeLeaseId"]) is not str
                or type(message["offerRevision"]) is not int
                or not _positive_millis(message["observedAtMs"])
                or (message["inReplyToMessageId"] is not None
                    and type(message["inReplyToMessageId"]) is not str)):
            return _result("BLOCKED", "MESSAGE_METADATA_INVALID")
        if (message["jobId"] != context["jobId"]
                or message["tradeLeaseId"] != context["tradeLeaseId"]
                or message["offerRevision"] != context["offerRevision"]
                or message["observedAtMs"] < context["leaseStartedMs"]
                or message["observedAtMs"] > context["nowMs"]
                or context["nowMs"] - message["observedAtMs"] >
                   MAX_OBSERVATION_LAG_MS):
            return _result("STALE_OR_FOREIGN_CONTEXT", "JOB_LEASE_REVISION_OR_AGE_MISMATCH")
        if message["messageId"] in context["seenMessageIds"]:
            return _result("DUPLICATE_MESSAGE", "ALREADY_CONSUMED_MESSAGE_ID")
        if message["senderUserId"] != partner_id:
            return _result("NOT_FOR_ACTIVE_TRADE", "NOT_FROM_CURRENT_TRADE_PARTNER")
        text = message["text"].strip()
        if not text or len(text) > 500:
            return _result("TEXT_UNAVAILABLE", "EMPTY_FILTERED_OR_ABNORMAL_TEXT")
        if message["channelName"].startswith("RBXWhisper:"):
            match = _WHISPER.fullmatch(message["channelName"])
            if match is None:
                return _result("BLOCKED", "WHISPER_CHANNEL_INVALID")
            members = {int(match[1]), int(match[2])}
            if members != {self_id, partner_id}:
                return _result("NOT_FOR_ACTIVE_TRADE", "WHISPER_WITH_ANOTHER_RECIPIENT")
            return _result(
                "DIRECTED_RESEARCH_ONLY",
                "SYNTHETIC_EXACT_WHISPER_CHANNEL_BOTH_USER_IDS",
                addressEvidence=["WHISPER_PAIR", "ACTIVE_PARTNER", "TRADE_LEASE"],
            )
        if message["channelName"] != "RBXGeneral":
            return _result("AMBIGUOUS_RECIPIENT", "NON_DIRECT_CHANNEL_NOT_TRUSTED")
        other = [n for n in context["otherUsernames"]
                 if n.casefold() != context["localUsername"].casefold()
                 and _mentioned(text, n)]
        addressed = _direct_username_address(text, context["localUsername"])
        if other and addressed:
            return _result("AMBIGUOUS_RECIPIENT", "MULTIPLE_POSSIBLE_ADDRESSEES")
        if other:
            return _result("NOT_FOR_ACTIVE_TRADE", "EXPLICITLY_ADDRESSES_OTHER_PLAYER")
        if addressed:
            return _result(
                "DIRECTED_RESEARCH_ONLY",
                "SYNTHETIC_EXPLICIT_USERNAME_VOCATIVE",
                addressEvidence=["USERNAME_IN_PUBLIC_CHAT", "ACTIVE_PARTNER"],
            )
        if _mentioned(text, context["localUsername"]):
            return _result("AMBIGUOUS_RECIPIENT", "USERNAME_MENTIONED_NOT_ADDRESSED")
        if context["competingConversationObserved"]:
            return _result("AMBIGUOUS_RECIPIENT", "OTHER_CONVERSATION_COULD_BE_TARGET")
        # Text-only "yes", "add", "nty" is never a proven direct message.
        # A narrow observed reply sequence is enough for a MANUAL-SUGGESTION
        # cue, not for chat sending or an item/Accept action.
        last_id = context["lastOurMessageId"]
        last_ms = context["lastOurMessageAtMs"]
        reply = message["inReplyToMessageId"]
        if (context["lastOurMessageWasToPartner"] and last_id is not None
                and last_ms is not None and last_ms <= message["observedAtMs"]
                and message["observedAtMs"] - last_ms <= REPLY_CONTEXT_MS
                and reply == last_id and _trade_language(
                    text, context["visibleOfferItemNames"])):
            return _result(
                "LIKELY_TRADE_CONTEXT_UNPROVEN",
                "SYNTHETIC_REPLY_CONTEXT_NOT_PROVEN_DIRECT_CHANNEL",
                addressEvidence=["OWN_PRIOR_MESSAGE", "ACTIVE_PARTNER", "TRADE_TERMS"],
            )
        offer_ms = context["lastOfferChangedAtMs"]
        if (offer_ms is not None and offer_ms <= message["observedAtMs"]
                and message["observedAtMs"] - offer_ms <= OFFER_CONTEXT_MS
                and _trade_language(text, context["visibleOfferItemNames"])):
            return _result(
                "LIKELY_TRADE_CONTEXT_UNPROVEN",
                "SYNTHETIC_OFFER_CHANGE_CONTEXT_NOT_DIRECT_PROOF",
                addressEvidence=["RECENT_OFFER_CHANGE", "ACTIVE_PARTNER", "TRADE_TERMS"],
            )
        return _result("AMBIGUOUS_RECIPIENT", "GENERAL_CHAT_NO_RECIPIENT_PROOF")
    except (ValueError, TypeError, KeyError, OverflowError):
        return _result("BLOCKED", "UNEXPECTED_METADATA_OR_INPUT")
