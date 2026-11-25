"""S2 C7 — strict client-response research evidence ledger from private Discord V2.

Actual bot deliveries may only be supplied by PRIVATE collector. This module
does not fetch Discord, accept HTTP payloads, learn player personalities,
authenticate MM2 settlement, or produce a trade/action/accuracy claim.

The existing V2 schema contains NO item/bundle features or independently
authenticated server transaction ID. Therefore: trainable strategy rows = 0.
Still valuable: exact per-episode attempted-request denominators, client
engagement-vs-decline-vs-censoring, origin/identity/revision audit, and a
partner-disjoint frozen research evaluation plan for future feature-bearing data.
"""
from __future__ import annotations

from collections import Counter
from datetime import datetime, timezone
from hashlib import sha256
import json
from typing import Any

from pdiddler.system2.discord_v2_event_intake import (
    review, SCHEMA as V2_SCHEMA, SOURCE, CLIENT_PROOF, KEYS,
)

SCHEMA="gingerscope-system2-real-v2-response-evidence-gate-v1"
TERMINAL={
 "PARTNER_DECLINED","PARTNER_NO_RESPONSE_TIMEOUT","PARTNER_CANCELLED",
 "MAIN_CANCELLED","CLIENT_WINDOW_CLOSED_UNKNOWN",
}
REVISION={"PARTNER_OFFER_REVISION","MAIN_OFFER_REVISION"}
CHATS={"CHAT_DIRECT_CLIENT_ATTRIBUTED","CHAT_AMBIGUOUS","CHAT_OTHER_CONVERSATION"}
CLIENT_INDICATORS={"PARTNER_ACCEPT_INDICATOR","MAIN_ACCEPT_INDICATOR",
                   "CLIENT_INVENTORY_DELTA_OBSERVED"}
EXPECTED_SCOPES={"MAIN_ALT_TEST","PUBLIC_CLIENT_OBSERVATION"}
DENIED={
 "readOnly":True,"serverTradeSettlementProven":False,
 "independentlyAuthenticatedClientIdentity":False,
 "discordTransportIsGameServerProof":False,
 "liveOfferFeatureBindingProven":False,
 "realCompletedTradesUsedForLearning":0,
 "verifiedRetradeLiquidity":0,
 "measuredTradeAcceptanceProbability":None,
 "learnedPartnerPersonality":False,
 "modelDeploymentAuthorized":False,
 "mayUseForStrategyLearning":False,
 "mayReportProfit":False,"maySendDiscordWebhook":False,
 "authorizesChat":False,"authorizesTrade":False,
 "authorizesOffer":False,"authorizesAccept":False,
 "tradeOutcome":"UNKNOWN",
}
def _out(status,reason,**fields):
    return {"schema":SCHEMA,"status":status,"reason":reason,
            **fields,**DENIED}

def _utc(v):
    if type(v) is not str or len(v)>40:
        raise ValueError("DISCORD_TIMESTAMP_INVALID")
    try:
        t=datetime.fromisoformat(v.replace("Z","+00:00"))
        if t.tzinfo is None:
            raise ValueError
        return t.astimezone(timezone.utc)
    except (ValueError, OverflowError):
        raise ValueError("DISCORD_TIMESTAMP_INVALID") from None

def _canonical(row):
    return json.dumps(row,sort_keys=True,separators=(",",":"),
                      ensure_ascii=True,allow_nan=False)

def _input_review(rows,channel,webhook):
    if type(rows) is not list or not 1<=len(rows)<=1000:
        raise ValueError("NO_PRIVATE_V2_ENVELOPES_YET")
    audit=review(rows,expected_channel_id=channel,expected_webhook_id=webhook)
    if audit.get("status")!="PRIVATE_BOT_V2_ENVELOPE_SHAPE_REVIEW_ONLY":
        raise ValueError("STRICT_V2_REVIEW_"+str(audit.get("reason","FAILED")))
    if (audit.get("realTrainingRowsAuthorized")!=0 or
        audit.get("mayUseForStrategyLearning") is not False):
        raise ValueError("FORGED_V2_LEARNING_PERMISSION")
    return audit

def compile_client_evidence(
    rows,*,expected_channel_id,expected_webhook_id,
    private_collector_origin=False,minimum_holdout_partners=4,
):
    """Aggregate validated V2 client episodes; never expose digest identifiers.

    private_collector_origin is a statement from caller, not remote attestation.
    Not allowed to promote it into server completion or live model deployment.
    The existing private collector validates webhook transport metadata before
    invoking this, but Discord delivery remains a client self-report of MM2.
    """
    try:
        if (type(private_collector_origin) is not bool or
            type(minimum_holdout_partners) is not int or
            not 2<=minimum_holdout_partners<=8):
            raise ValueError("PROVENANCE_OR_HOLDOUT_POLICY_INVALID")
        audit=_input_review(rows,expected_channel_id,expected_webhook_id)
        entries={}
        for row in rows:
            if (type(row) is not dict or set(row)!=KEYS or
                row.get("schema")!=V2_SCHEMA or row.get("source")!=SOURCE or
                row.get("client_provenance")!=CLIENT_PROOF):
                raise ValueError("V2_ENVELOPE_NOT_CANONICAL")
            key=row["message_id"]
            canonical=_canonical(row)
            if key in entries:
                if entries[key]!=canonical:
                    raise ValueError("MUTATED_DUPLICATE_MESSAGE")
                continue
            entries[key]=canonical
        ordered=[json.loads(x) for x in entries.values()]
        ordered.sort(key=lambda e:(e["session_digest"],e["event_seq"]))
        by_session={}
        for row in ordered:
            sid=row["session_digest"]
            arr=by_session.setdefault(sid,[])
            arr.append(row)
        if len(by_session)!=audit["distinctSessionCount"]:
            raise ValueError("V2_SESSION_REVIEW_DIVERGENCE")
        summaries=[]
        for seq in by_session.values():
            first=seq[0]
            if (first["kind"]!="MAIN_REQUEST_PENDING" or
                first["revision"]!=0 or first["event_seq"]!=1):
                raise ValueError("FIRST_REQUEST_NOT_BASELINE")
            stamp=None
            accepted=False
            pending=True
            indicator=False
            indicator_revision=None
            chat=Counter()
            revisions=0
            window_client_delta=False
            result="CENSORED_OPEN_REQUEST"
            for i,row in enumerate(seq):
                t=_utc(row["recorded_at_utc"])
                if stamp is not None and t<stamp:
                    raise ValueError("DISCORD_DELIVERY_TIME_ROLLBACK")
                stamp=t
                kind=row["kind"]
                if i==0:
                    continue
                if kind=="PARTNER_REQUEST_ACCEPTED":
                    accepted=True;pending=False;result="CENSORED_OPEN_TRADE"
                elif kind in REVISION:
                    revisions+=1;indicator=False;indicator_revision=None
                elif kind=="PARTNER_ACCEPT_INDICATOR":
                    indicator=True;indicator_revision=row["revision"]
                elif kind=="CLIENT_INVENTORY_DELTA_OBSERVED":
                    window_client_delta=True
                elif kind in CHATS:
                    chat[kind]+=1
                elif kind=="PARTNER_DECLINED":
                    result="CLIENT_EXPLICIT_REQUEST_DECLINED"
                elif kind=="PARTNER_NO_RESPONSE_TIMEOUT":
                    result="CENSORED_REQUEST_TIMEOUT"
                elif kind=="PARTNER_CANCELLED":
                    result="CENSORED_PARTNER_CANCELLED"
                elif kind=="MAIN_CANCELLED":
                    result="CENSORED_OUR_CANCELLED"
                elif kind=="CLIENT_WINDOW_CLOSED_UNKNOWN":
                    result="CENSORED_CLOSED_UNKNOWN"
                # MAIN_ACCEPT_INDICATOR is not proof of partner agreement.
            summaries.append({
                "partner":first["partner_digest"],
                "scope":first["scope"],
                "firstReceivedAt":_utc(first["recorded_at_utc"]),
                "lastReceivedAt":stamp,
                "requestAcceptedClientOnly":accepted,
                "result":result,
                "offerRevisionChanges":revisions,
                "partnerAcceptIndicatorSeenAtFinalRevision":
                   indicator and indicator_revision==seq[-1]["revision"],
                "clientInventoryDeltaSeen":window_client_delta,
                "directChatMessages":chat["CHAT_DIRECT_CLIENT_ATTRIBUTED"],
                "ambiguousChatMessages":chat["CHAT_AMBIGUOUS"],
                "otherConversations":chat["CHAT_OTHER_CONVERSATION"],
            })
        counts=Counter(x["result"] for x in summaries)
        real=[x for x in summaries if x["scope"]=="PUBLIC_CLIENT_OBSERVATION"]
        alt=[x for x in summaries if x["scope"]=="MAIN_ALT_TEST"]
        public_partners={x["partner"] for x in real}
        # Digests are not verified distinct real players: the native sender may
        # rotate its salt. This is only a prospective digest-level split.
        # Purge whole earlier groups with any episode crossing the holdout start.
        # Use delivery time, not a claim about server event chronology.
        first={}
        for x in real:
            first[x["partner"]]=min(x["firstReceivedAt"],
                first.get(x["partner"],x["firstReceivedAt"]))
        groups=sorted(first,key=lambda p:(first[p],p))
        need=max(minimum_holdout_partners,3)
        candidate_enough=len(groups)>=max(12,need*3)
        hold=set(groups[-need:]) if candidate_enough else set()
        prior=set(groups[:-need]) if candidate_enough else set()
        cutoff=min((first[p] for p in hold),default=None)
        last={}
        for x in real:
            last[x["partner"]]=max(x["lastReceivedAt"],
                                   last.get(x["partner"],x["lastReceivedAt"]))
        train={p for p in prior if last[p]<cutoff} if cutoff is not None else set()
        purged=prior-train
        enough=candidate_enough and len(train)>=max(12,need*3)-need
        disjoint=not(train & hold)
        temporal=bool(train and hold) and max(last[p] for p in train)<cutoff
        if not disjoint or (enough and not temporal):
            raise ValueError("PARTNER_HOLDOUT_OVERLAP")
        # Only caller-asserted delivery, not verified transport attestation.
        counts_all={x:counts[x] for x in sorted(counts)}
        observed_partner_indicators=sum(
            x["partnerAcceptIndicatorSeenAtFinalRevision"] for x in real
        )
        n_request_declined=sum(
            x["result"]=="CLIENT_EXPLICIT_REQUEST_DECLINED" for x in real
        )
        n_started=sum(x["requestAcceptedClientOnly"] for x in real)
        n_censored=len(real)-n_request_declined-n_started
        if n_censored<0:
            raise ValueError("INVALID_REQUEST_RESPONSE_DENOMINATOR")
        # Request accepted vs explicit decline vs censored is a CLIENT
        # request-response tabulation, not offer/trade completion likelihood.
        return _out(
            "PRIVATE_BOT_V2_RESPONSE_EPISODES_CLASSIFIED_RESEARCH_ONLY",
            "CLIENT_EVENT_DENOMINATORS_NOT_VERIFIED_ACCEPTANCE_OR_LEARNING",
            privateCollectorOriginClaim=private_collector_origin,
            archiveHasRealNetworkEvidenceAttestation=False,
            publicClientSessionClaims=len(real),
            excludedMainAltTestSessionClaims=len(alt),
            publicDistinctPartnerDigestsCount=len(public_partners),
            clientRequestAcceptedCount=n_started,
            explicitClientRequestDeclinedCount=n_request_declined,
            requestCensoredOrPendingCount=n_censored,
            clientTradePartnerIndicatorsFinalRevision=observed_partner_indicators,
            clientInventoryDeltaClaims=sum(x["clientInventoryDeltaSeen"] for x in real),
            knownTradeSettlements=0,
            confirmedTradeAcceptanceDenominator=0,
            chatDirectClientClaimCount=sum(x["directChatMessages"] for x in real),
            chatAmbiguousClientClaimCount=sum(x["ambiguousChatMessages"] for x in real),
            revisionInvalidationsCount=sum(x["offerRevisionChanges"] for x in real),
            allClientOutcomeCategoryCounts=counts_all,
            partnerDisjointHoldoutReady=enough,
            partnerDisjointTrainGroups=len(train),
            partnerDisjointHoldoutGroups=len(hold),
            temporalPurgedDigestGroups=len(purged),
            temporalDeliverySplitStrictlySeparated=temporal,
            chronologicalDigestHoldoutReady=enough and temporal,
            partnerDigestStableAcrossSessionsProven=False,
            distinctRealPlayerHoldoutProven=False,
            serverEventChronologyProven=False,
            realModelHoldoutReady=False,
            holdoutNotUsedForTraining=True,
            offerBundleFeaturesAvailableInV2=False,
            deployableLearnedModelAvailable=False,
            realResponseRewardLabelsForModel=0,
            transportMessagesDeduplicated=audit["messageClaimCount"],
            privateSourceClaimSetDigestSha256=audit["canonicalClaimSetSha256"],
            noRawUserIdsItemsOrSessionDigestsReturned=True,
        )
    except (ValueError,TypeError,KeyError,OverflowError,AttributeError) as e:
        code=str(e)
        if len(code)>110 or not (code.startswith((
                "DISCORD_", "PRIVATE_", "PROVENANCE_", "NO_PRIVATE_",
                "STRICT_V2_", "FORGED_", "V2_", "FIRST_", "MUTATED_",
                "PARTNER_", "INVALID_"))):
            code="MALFORMED_OR_UNVERIFIED_PRIVATE_V2_SOURCE"
        return _out("BLOCKED",code)
