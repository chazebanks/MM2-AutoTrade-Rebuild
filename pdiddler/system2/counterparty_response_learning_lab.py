"""System 2 S2.7 research-only: correlate distinct response trajectories.

There is no learner of real player preferences yet. Every input MUST be
synthetic; a client Accept indicator is not a completed game transaction.
No real account/offer/item identifier, settled trade, target valuation,
probability or automated action is ingested, inferred or exported.
"""
from __future__ import annotations

SCHEMA = "gingerscope-system2-counterparty-response-replay-v1"
EVENT_SCHEMA = "SYNTHETIC_S2_RESPONSE_EVENT"
KINDS = frozenset({
    "MAIN_REQUEST_PENDING", "PARTNER_REQUEST_ACCEPTED",
    "PARTNER_OFFER_REVISION", "MAIN_OFFER_REVISION",
    "PARTNER_DECLINED", "PARTNER_NO_RESPONSE_TIMEOUT",
    "PARTNER_CANCELLED", "MAIN_CANCELLED",
    "PARTNER_ACCEPT_INDICATOR", "MAIN_ACCEPT_INDICATOR",
    "CLIENT_WINDOW_CLOSED_UNKNOWN", "CLIENT_INVENTORY_DELTA_OBSERVED",
    "CHAT_DIRECT_CLIENT_ATTRIBUTED", "CHAT_AMBIGUOUS", "CHAT_OTHER_CONVERSATION",
})
CHAT = frozenset({
    "CHAT_DIRECT_CLIENT_ATTRIBUTED", "CHAT_AMBIGUOUS", "CHAT_OTHER_CONVERSATION",
})
TERMINAL = frozenset({
    "PARTNER_DECLINED", "PARTNER_NO_RESPONSE_TIMEOUT",
    "PARTNER_CANCELLED", "MAIN_CANCELLED", "CLIENT_WINDOW_CLOSED_UNKNOWN",
})
OUTCOMES = {
    "PARTNER_DECLINED": "EXPLICIT_PARTNER_DECLINE",
    "PARTNER_NO_RESPONSE_TIMEOUT": "UNANSWERED_NOT_DECLINED",
    "PARTNER_CANCELLED": "PARTNER_CANCEL_RECORDED_NOT_DECLINE",
    "MAIN_CANCELLED": "MAIN_WITHDRAWAL_NOT_PARTNER_PREFERENCE",
    "CLIENT_WINDOW_CLOSED_UNKNOWN": "CLOSED_UNKNOWN_NO_SERVER_SETTLEMENT",
}
DENIED = {
    "simulationOnly": True, "liveTradeSessionBound": False,
    "observedRealPlayerBehavior": False,
    "realAccountIdsIngested": False, "realOffersIngested": False,
    "acceptanceProbability": None, "empiricalLiquidityProven": False,
    "learnedPartnerPersonality": False, "trainingUpdateAuthorized": False,
    "verifiedRealSettlements": 0, "serverCompletionProven": False,
    "tradeOutcome": "UNKNOWN", "mayReportProfit": False,
    "mayUseForStrategyLearning": False, "maySendDiscordWebhook": False,
    "authorizesOffer": False, "authorizesTrade": False,
    "authorizesAccept": False, "publicFinalAcceptAuthorized": False,
    "exactMainAltAutoAcceptAuthorizedByThisModule": False,
}

def _result(status, reason, **data):
    return {"schema": SCHEMA, "status": status, "reason": reason,
            **data, **DENIED}


def replay(events):
    """Inspect 1–1000 synthetic events across 1–32 DISTINCT mock episodes.

    Type and order matter. Acceptance can be invalidated by another revision.
    A client-delta note is never promoted to a completed trade or training row.
    """
    try:
        if type(events) is not list or not 1 <= len(events) <= 1000:
            raise ValueError("SYNTHETIC_EVENT_BATCH_LIMIT")
        episodes = {}
        last_order = {}
        for index, event in enumerate(events):
            if (type(event) is not dict or set(event) != {
                "schema", "episode", "seq", "kind", "revision", "scope"
            } or event["schema"] != EVENT_SCHEMA or
                event["scope"] != "SYNTHETIC_MAIN_PARTNER_ONLY"):
                raise ValueError("EVENT_FIELDS_OR_SYNTHETIC_SCOPE_INVALID")
            ep = event["episode"]
            seq = event["seq"]
            rev = event["revision"]
            kind = event["kind"]
            if (type(ep) is not int or not 1 <= ep <= 32 or
                type(seq) is not int or not 1 <= seq <= 1000 or
                type(rev) is not int or not 0 <= rev <= 1000 or
                type(kind) is not str or kind not in KINDS):
                raise ValueError("EVENT_EPISODE_SEQUENCE_OR_KIND_INVALID")
            if ep not in episodes:
                if len(episodes) >= 32:
                    raise ValueError("TOO_MANY_DISTINCT_TEST_EPISODES")
                if kind != "MAIN_REQUEST_PENDING" or seq != 1 or rev != 0:
                    raise ValueError("REQUEST_BASELINE_REQUIRED_PER_EPISODE")
                episodes[ep] = {
                    "rev": 0, "stage": "REQUEST_PENDING",
                    "partnerAccepted": False, "mainAccepted": False,
                    "everOffered": False, "everPartnerAccepted": False,
                    "changedRevisions": 0, "chatDirect": 0,
                    "chatAmbiguous": 0, "chatOther": 0,
                    "clientDeltas": 0, "outcome": "IN_PROGRESS_CENSORED"
                }
                last_order[ep] = 1
                continue
            entry = episodes[ep]
            if seq != last_order[ep] + 1:
                raise ValueError("REPLAY_DUPLICATE_GAP_OR_NONMONOTONIC_SEQUENCE")
            last_order[ep] = seq
            if entry["stage"] == "TERMINAL":
                raise ValueError("EVENT_AFTER_TERMINAL_RESULT")
            if rev < entry["rev"] or rev > entry["rev"] + 1:
                raise ValueError("OFFER_REVISION_ROLLBACK_OR_UNWITNESSED_JUMP")
            if kind in ("PARTNER_OFFER_REVISION", "MAIN_OFFER_REVISION"):
                if entry["stage"] != "IN_TRADE" or rev != entry["rev"] + 1:
                    raise ValueError("OFFER_CHANGE_WITHOUT_ACTIVE_TRADE_OR_NEW_REVISION")
                entry["rev"] = rev
                entry["partnerAccepted"] = False
                entry["mainAccepted"] = False
                entry["changedRevisions"] += 1
                entry["everOffered"] = True
            elif rev != entry["rev"]:
                raise ValueError("UNBOUND_EVENT_OFFER_REVISION")
            elif kind == "MAIN_REQUEST_PENDING":
                raise ValueError("DUPLICATE_REQUEST_WITHOUT_NEW_EPISODE")
            elif kind == "PARTNER_REQUEST_ACCEPTED":
                if entry["stage"] != "REQUEST_PENDING":
                    raise ValueError("REQUEST_ALREADY_ACCEPTED_OR_RESOLVED")
                entry["stage"] = "IN_TRADE"
            elif kind in CHAT:
                if kind == "CHAT_DIRECT_CLIENT_ATTRIBUTED":
                    entry["chatDirect"] += 1
                elif kind == "CHAT_AMBIGUOUS":
                    entry["chatAmbiguous"] += 1
                else:
                    entry["chatOther"] += 1
            elif kind in ("PARTNER_ACCEPT_INDICATOR", "MAIN_ACCEPT_INDICATOR"):
                if entry["stage"] != "IN_TRADE":
                    raise ValueError("ACCEPT_INDICATOR_WITHOUT_ACTIVE_TRADE")
                if kind == "PARTNER_ACCEPT_INDICATOR":
                    entry["partnerAccepted"] = True
                    entry["everPartnerAccepted"] = True
                else:
                    if not entry["partnerAccepted"]:
                        raise ValueError("MAIN_ACCEPT_WITHOUT_CURRENT_PARTNER_INDICATOR")
                    entry["mainAccepted"] = True
            elif kind == "CLIENT_INVENTORY_DELTA_OBSERVED":
                if entry["stage"] != "IN_TRADE":
                    raise ValueError("CLIENT_DELTA_NOT_BOUND_TO_ACTIVE_WINDOW")
                entry["clientDeltas"] += 1
            elif kind in TERMINAL:
                if kind == "PARTNER_NO_RESPONSE_TIMEOUT" and
                    entry["stage"] != "REQUEST_PENDING":
                    raise ValueError("NO_RESPONSE_TIMEOUT_AFTER_REQUEST_ACCEPTANCE")
                if kind == "CLIENT_WINDOW_CLOSED_UNKNOWN" and
                    entry["stage"] != "IN_TRADE":
                    raise ValueError("WINDOW_CLOSE_WITHOUT_OBSERVED_TRADE")
                entry["outcome"] = OUTCOMES[kind]
                entry["stage"] = "TERMINAL"
            else:
                raise ValueError("EVENT_UNRECOGNIZED")
        all_items = list(episodes.values())
        outcomes = {}
        for item in all_items:
            label = item["outcome"]
            outcomes[label] = outcomes.get(label, 0) + 1
        return _result(
            "OFFLINE_DIFFERENT_BEHAVIOR_TRAJECTORIES_REPLAYED",
            "SYNTHETIC_REACTIONS_ARE_NOT_VERIFIED_PREFERENCES",
            distinctSyntheticEpisodes=len(episodes),
            totalSyntheticEvents=len(events),
            outcomeDistribution=dict(sorted(outcomes.items())),
            currentRevisionAcceptanceIndicators=sum(
                v["partnerAccepted"] and v["mainAccepted"] for v in all_items
            ),
            everObservedPartnerAcceptanceIndicators=sum(
                v["everPartnerAccepted"] for v in all_items
            ),
            changedOfferRevisions=sum(v["changedRevisions"] for v in all_items),
            chatDirectClientAttributed=sum(v["chatDirect"] for v in all_items),
            chatAmbiguousUnattributed=sum(v["chatAmbiguous"] for v in all_items),
            chatOtherConversation=sum(v["chatOther"] for v in all_items),
            clientOnlyInventoryDeltaNotes=sum(v["clientDeltas"] for v in all_items),
            distinctCounterpartyIdentitiesVerified=0,
            realParticipantDispositionInferred=False,
            evidenceUsableForActualNegotiation=False,
        )
    except (TypeError, ValueError, KeyError, AttributeError, OverflowError) as error:
        # Never echo arbitrary source data or identities in reason strings.
        reason = str(error)
        if reason not in {
            "SYNTHETIC_EVENT_BATCH_LIMIT", "EVENT_FIELDS_OR_SYNTHETIC_SCOPE_INVALID",
            "EVENT_EPISODE_SEQUENCE_OR_KIND_INVALID",
            "TOO_MANY_DISTINCT_TEST_EPISODES",
            "REQUEST_BASELINE_REQUIRED_PER_EPISODE",
            "REPLAY_DUPLICATE_GAP_OR_NONMONOTONIC_SEQUENCE",
            "EVENT_AFTER_TERMINAL_RESULT", "OFFER_REVISION_ROLLBACK_OR_UNWITNESSED_JUMP",
            "OFFER_CHANGE_WITHOUT_ACTIVE_TRADE_OR_NEW_REVISION",
            "UNBOUND_EVENT_OFFER_REVISION", "DUPLICATE_REQUEST_WITHOUT_NEW_EPISODE",
            "REQUEST_ALREADY_ACCEPTED_OR_RESOLVED", "ACCEPT_INDICATOR_WITHOUT_ACTIVE_TRADE",
            "MAIN_ACCEPT_WITHOUT_CURRENT_PARTNER_INDICATOR",
            "CLIENT_DELTA_NOT_BOUND_TO_ACTIVE_WINDOW",
            "NO_RESPONSE_TIMEOUT_AFTER_REQUEST_ACCEPTANCE",
            "WINDOW_CLOSE_WITHOUT_OBSERVED_TRADE", "EVENT_UNRECOGNIZED"
        }:
            reason = "MALFORMED_REPLAY_DATA"
        return _result("BLOCKED", reason)
