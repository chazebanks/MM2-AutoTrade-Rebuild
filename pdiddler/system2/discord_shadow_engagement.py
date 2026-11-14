"""System 2 S2.7 shadow learner: existing Discord bot -> private ledger -> evidence.

Novel capability: a *sandbox* model changes its research attention after distinct
synthetic Discord-v2 event trajectories, with separate train/holdout episodes.
Real historical v1 webhook "completed" claims NEVER provide outcomes or rewards.
No source asserts real settlement, no usernames/game raw keys, no trade actions.
"""
from __future__ import annotations

from collections import defaultdict
import math

from pdiddler.system2.discord_learning_evidence_bridge import (
    review as review_private_ledger, WEBHOOK_FIXTURE_SCHEMA,
)
from pdiddler.system2.counterparty_response_learning_lab import KINDS

SCHEMA = "gingerscope-s2-discord-shadow-engagement-v1"
ALLOWED_LABELS = {"ENGAGED_CLIENT_INDICATOR_ONLY", "PARTNER_DECLINED_OBSERVED",
                  "CENSORED_NO_RESPONSE", "CENSORED_CANCEL_OR_UNKNOWN"}
ALLOWED_SPLITS = {"TRAIN", "HOLDOUT"}
STOP = {
    "simulationOnly": True,
    "realDiscordFeedbackConsumed": False,
    "realLearnerUpdated": False,
    "realPlayerIdentityIngested": False,
    "historicalDiscordCompletedClaimsTreatedAsTruth": False,
    "verifiedServerSettlements": 0,
    "currentMarketSourceVerified": False,
    "partnerAcceptanceProbability": None,
    "actualPartnerPreferenceInferred": False,
    "actualProfitProven": False,
    "authorizesOffer": False,
    "authorizesTrade": False,
    "authorizesAccept": False,
    "publicFinalAcceptAuthorized": False,
    "mainAltFinalAcceptAuthorizedByLearner": False,
    "mayUseForStrategyLearning": False,
    "mayReportProfit": False,
    "maySendDiscordWebhook": False,
    "tradeOutcome": "UNKNOWN",
}
REASONS = {
    "HISTORICAL_LEDGER_OR_DISCORD_EVENTS_BLOCKED",
    "SYNTHETIC_EPISODE_BINDINGS_INVALID",
    "SYNTHETIC_EPISODE_BINDINGS_NOT_UNIQUE",
    "SYNTHETIC_EPISODE_SET_MISMATCH",
    "NO_DISTINCT_TRAIN_AND_HOLDOUT_EPISODES",
    "SYNTHETIC_EVIDENCE_NO_INFORMATIVE_TRAIN_LABELS",
    "STRATEGY_EVIDENCE_NOT_ADMITTED",
    "STRATEGY_CANDIDATES_NOT_VALIDATED",
    "SYNTHETIC_CANDIDATE_NOT_IN_STRATEGY",
    "NO_SAFE_RESEARCH_CANDIDATES",
}
def _out(status, reason, **fields):
    return {"schema":SCHEMA,"status":status,"reason":reason,**fields,**STOP}

def _fail(reason):
    return _out("BLOCKED", reason if reason in REASONS else "SYNTHETIC_INPUT_INVALID")

def fit(archive_records, discord_events, synthetic_assignments):
    """Use source-checked Discord v1 and purely synthetic hypothetical v2.

    Synthetic assignments: {episode:int,candidateIndex:int,split:'TRAIN'|'HOLDOUT'}.
    NO usernames, item names, message IDs, weapon keys or counterpart IDs.
    A single response episode cannot be counted as multiple training examples.
    """
    proof=review_private_ledger(archive_records,
                                synthetic_future_webhook_events=discord_events)
    if (type(proof) is not dict or
        proof.get("status")!="DISCORD_ARCHIVE_TO_S2_EVIDENCE_RESEARCH_ONLY" or
        proof.get("authorizesAccept") is not False or
        proof.get("verifiedCompletedTradesForLearning") != 0 or
        proof.get("futureWebhookOutcomeEventsActuallyCaptured") != 0 or
        proof.get("mayUseForStrategyLearning") is not False):
        return _fail("HISTORICAL_LEDGER_OR_DISCORD_EVENTS_BLOCKED")
    if (type(synthetic_assignments) is not list or
        not 2<=len(synthetic_assignments)<=32):
        return _fail("SYNTHETIC_EPISODE_BINDINGS_INVALID")
    associations={}
    for binding in synthetic_assignments:
        if (type(binding) is not dict or set(binding)!=
                {"episode","candidateIndex","split"} or
            type(binding["episode"]) is not int or
            not 1<=binding["episode"]<=32 or
            type(binding["candidateIndex"]) is not int or
            not 0<=binding["candidateIndex"]<=11 or
            binding["split"] not in ALLOWED_SPLITS):
            return _fail("SYNTHETIC_EPISODE_BINDINGS_INVALID")
        if binding["episode"] in associations:
            return _fail("SYNTHETIC_EPISODE_BINDINGS_NOT_UNIQUE")
        associations[binding["episode"]]=binding
    if set(x["split"] for x in synthetic_assignments)!=ALLOWED_SPLITS:
        return _fail("NO_DISTINCT_TRAIN_AND_HOLDOUT_EPISODES")
    episodes={}
    if type(discord_events) is not list: return _fail("SYNTHETIC_EPISODE_SET_MISMATCH")
    for event in discord_events:
        if type(event) is not dict or type(event.get("episode")) is not int:
            return _fail("SYNTHETIC_EPISODE_SET_MISMATCH")
        ep=event["episode"]
        if ep not in episodes:
            episodes[ep]={"partnerIndicator":False, "final":None, "changed":0,
                          "requestAccepted":False, "lastRevision":0}
        row=episodes[ep]
        kind=event.get("kind")
        if kind in ("PARTNER_OFFER_REVISION","MAIN_OFFER_REVISION"):
            row["partnerIndicator"]=False
            row["changed"]+=1
        elif kind=="PARTNER_REQUEST_ACCEPTED":
            row["requestAccepted"]=True
        elif kind=="PARTNER_ACCEPT_INDICATOR":
            row["partnerIndicator"]=True
        elif kind=="PARTNER_DECLINED":
            row["final"]="PARTNER_DECLINED_OBSERVED"
        elif kind=="PARTNER_NO_RESPONSE_TIMEOUT":
            row["final"]="CENSORED_NO_RESPONSE"
        elif kind in ("PARTNER_CANCELLED","MAIN_CANCELLED"):
            row["final"]="CENSORED_CANCEL_OR_UNKNOWN"
        elif kind=="CLIENT_WINDOW_CLOSED_UNKNOWN":
            if row["partnerIndicator"] and row["requestAccepted"]:
                row["final"]="ENGAGED_CLIENT_INDICATOR_ONLY"
            else:
                row["final"]="CENSORED_CANCEL_OR_UNKNOWN"
    if set(associations)!=set(episodes):
        return _fail("SYNTHETIC_EPISODE_SET_MISMATCH")
    label_counts=defaultdict(int)
    candidate_counts=defaultdict(lambda:{"engaged":0,"declined":0,"censored":0})
    holdout_counts=defaultdict(lambda:{"engaged":0,"declined":0,"censored":0})
    changed=0
    for ep,binding in associations.items():
        row=episodes[ep]
        label=row["final"] or "CENSORED_CANCEL_OR_UNKNOWN"
        label_counts[label]+=1
        changed+=row["changed"]
        counts=(candidate_counts if binding["split"]=="TRAIN"
                else holdout_counts)[binding["candidateIndex"]]
        if label=="ENGAGED_CLIENT_INDICATOR_ONLY":
            counts["engaged"]+=1
        elif label=="PARTNER_DECLINED_OBSERVED":
            counts["declined"]+=1
        else:
            counts["censored"]+=1
    if sum(v["engaged"]+v["declined"] for v in candidate_counts.values())==0:
        return _fail("SYNTHETIC_EVIDENCE_NO_INFORMATIVE_TRAIN_LABELS")
    # Transparent Laplace smoothing for synthetic CLIENT ENGAGEMENT signal.
    # This is NOT an actual trade-acceptance probability, nor settlement.
    model={}
    for index in sorted(set(candidate_counts)|set(holdout_counts)):
        train=candidate_counts[index]
        hold=holdout_counts[index]
        n=train["engaged"]+train["declined"]
        frac=((train["engaged"]+1)/(n+2)) if n>0 else None
        model[index]={
            "candidateIndex":index,"syntheticEngagementProxyFraction":frac,
            "trainEngagementIndicators":train["engaged"],
            "trainPartnerDeclines":train["declined"],
            "trainCensored":train["censored"],
            "holdoutEngagementIndicators":hold["engaged"],
            "holdoutPartnerDeclines":hold["declined"],
            "holdoutCensored":hold["censored"],
            "realPartnerAcceptanceRate":None,
            "observedRealSettlements":0,
        }
    return _out("SYNTHETIC_DISCORD_SHADOW_FEEDBACK_FIT",
        "SHADOW_ENGAGEMENT_PROXY_NOT_TRADE_ACCEPTANCE",
        privateArchivedDiscordRowsReviewed=proof["distinctArchivedWebhookMessages"],
        historicalDiscordClaimCount=proof["historicalSelfReportedCompletedClaims"],
        testAltExcluded=proof["excludedExactTestAccountReceipts"],
        quarantinedDiscordRows=proof["quarantinedMalformedOrAmbiguousReceipts"],
        syntheticEpisodeCount=len(associations),
        trainEpisodes=sum(b["split"]=="TRAIN" for b in associations.values()),
        holdoutEpisodes=sum(b["split"]=="HOLDOUT" for b in associations.values()),
        changedOfferRevisions=changed,
        syntheticLabels=dict(sorted(label_counts.items())),
        syntheticCandidateModel=[model[k] for k in sorted(model)],
        holdoutClaimOfImprovedRealPerformance=False,
        trainingSource="SYNTHETIC_V2_DISCORD_BOT_EVENTS_ONLY",
    )

def reconsider(s2_strategy_receipt, shadow_feedback_receipt):
    """Reassess hypothetical research attention, never issue or rank live offers.

    Require an ORIGINAL S2.8 strategy review, protected target + loss/stack
    warnings still obeyed, and a source-checked synthetic feedback receipt.
    """
    strat=s2_strategy_receipt;feedback=shadow_feedback_receipt
    if (type(strat) is not dict or
        strat.get("status")!="OFFLINE_MULTIPLE_SYSTEM2_STRATEGY_FEATURES_REVIEWED" or
        strat.get("authorizesAccept") is not False or
        strat.get("authorizesTrade") is not False or
        strat.get("sourceCurrentPublisherAuthenticated") is not False or
        strat.get("partnerAcceptanceStillUnknown") is not True or
        strat.get("realTradeOfferRankingAvailable") is not False or
        type(feedback) is not dict or
        feedback.get("status")!="SYNTHETIC_DISCORD_SHADOW_FEEDBACK_FIT" or
        feedback.get("authorizesAccept") is not False or
        feedback.get("realLearnerUpdated") is not False):
        return _fail("STRATEGY_EVIDENCE_NOT_ADMITTED")
    choices=strat.get("alternatives")
    if type(choices) is not list or not 2<=len(choices)<=12:
        return _fail("STRATEGY_CANDIDATES_NOT_VALIDATED")
    allowed={}
    for i,record in enumerate(choices):
        if (type(record) is not dict or
            record.get("index") != i or
            record.get("executable") is not False or
            type(record.get("warnings")) is not list):
            return _fail("STRATEGY_CANDIDATES_NOT_VALIDATED")
        # Never promote known losing, ineligible or stack-uncertain outcomes.
        if (record.get("status")=="OFFLINE_RESEARCH_CANDIDATE_ONLY" and
            type(record.get("listedDelta")) in (int,float) and
            math.isfinite(record["listedDelta"]) and
            record["listedDelta"]>=0 and
            not record.get("hypotheticalTargetReceived",False) and
            all("STACK" not in w and "UNSAFE" not in w for w in record["warnings"]
                if type(w) is str)):
            allowed[i]=record
    if not allowed: return _fail("NO_SAFE_RESEARCH_CANDIDATES")
    model=feedback.get("syntheticCandidateModel")
    if type(model) is not list: return _fail("SYNTHETIC_CANDIDATE_NOT_IN_STRATEGY")
    research=[]
    for row in model:
        if (type(row) is not dict or type(row.get("candidateIndex")) is not int or
            row["candidateIndex"]<0 or row["candidateIndex"]>=len(choices) or
            row.get("realPartnerAcceptanceRate") is not None or
            row.get("observedRealSettlements")!=0):
            return _fail("SYNTHETIC_CANDIDATE_NOT_IN_STRATEGY")
        i=row["candidateIndex"]
        if i in allowed and row.get("syntheticEngagementProxyFraction") is not None:
            value=row["syntheticEngagementProxyFraction"]
            if type(value) not in (int,float) or not 0<=value<=1:
                return _fail("SYNTHETIC_CANDIDATE_NOT_IN_STRATEGY")
            research.append((i, value, row["trainEngagementIndicators"],
                             row["trainPartnerDeclines"],allowed[i]["listedDelta"]))
    research.sort(key=lambda x:(-x[1],-x[2],x[3],-x[4],x[0]))
    return _out("HYPOTHETICAL_RESEARCH_ATTENTION_RECONSIDERED",
        "CLIENT_ENGAGEMENT_PROXY_NOT_REAL_PARTNER_PREFERENCE",
        researchAttentionAfterSyntheticFeedback=[x[0] for x in research],
        hypotheticalTopResearchIndex=research[0][0] if research else None,
        noActionWhenFeedbackUnavailable=not bool(research),
        blockedOrUnratedHypotheticalAlternatives=len(choices)-len(research),
        actualExecutedOffers=0,
        confirmedRealPartnerPreferences=0,
        liveOfferSelectionAuthorized=False,
        targetItemNeverOutgoing=True,
    )
