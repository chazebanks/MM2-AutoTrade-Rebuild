"""S2.8: multi-axis offline strategy stress test using EXISTING S2.3–S2.5.

This composes real source-pinned research adapters and the new S2.7 synthetic
response replay, not a fake 'all passed means execute' trade planner.
A candidate with listed gain can fail buyer appeal, range, counterparty
willingness, source freshness, or settlement evidence. No probabilities,
ranking as a live offer, automatic Accept or learning from client data.
"""
from __future__ import annotations

from pdiddler.system2.attractiveness_evidence_lab import compare
from pdiddler.system2.multitrade_growth_replay import simulate
from pdiddler.system2.counterparty_candidate_explorer import explore
from pdiddler.system2.counterparty_response_learning_lab import replay

SCHEMA = "gingerscope-system2-multi-axis-strategy-stress-v1"
DENIED = {
    "offlineOnly": True,
    "productionDecisionEngineActive": False,
    "sourceCurrentPublisherAuthenticated": False,
    "counterpartyOwnershipProven": False,
    "counterpartyConsentProven": False,
    "empiricalRetradeLiquidityKnown": False,
    "acceptanceProbability": None,
    "realStrategyLearningEnabled": False,
    "mayUseForStrategyLearning": False,
    "marketPricesApprovedForExecution": False,
    "lossBudgetApproved": False,
    "authorizesOffer": False,
    "authorizesTrade": False,
    "authorizesAccept": False,
    "publicFinalAcceptAuthorized": False,
    "finalAcceptScope": "EXACT_MAIN_ALT_SUPERVISED_ONLY_SEPARATE_POLICY",
    "mayReportProfit": False,
    "maySendDiscordWebhook": False,
    "serverCompletionProven": False,
    "tradeOutcome": "UNKNOWN",
}
KNOWN_ATTRACTIVENESS = {
    "OFFLINE_RESEARCH_CANDIDATE_ONLY",
    "LOSS_NOT_AUTHORIZED", "PAPER_STACK_VALUE_UNCERTAIN",
    "INVALID_ALTERNATIVE",
}
KNOWN_PATH = {
    "OFFLINE_GROWTH_PATH_SIMULATED", "OFFLINE_GROWTH_PATH_STACK_UNCERTAIN",
    "BLOCKED", "BLOCKED_LOSS_POLICY",
}

def _out(status, reason, **data):
    return {"schema":SCHEMA,"status":status,"reason":reason,
            **data,**DENIED}

def evaluate_batch(mapped, shadow, alternatives, paths, counterparty,
                   events, *, evaluated_at_utc=None):
    """2–12 alternatives, 2–6 DIFFERENT paths, explicit partner and responses.

    All market input is the previously validated historical 189-key research
    export. Inputs remain synthetic/caller supplied, including market 'current'
    time and partner inventory. No raw items/partner IDs in the output.
    """
    try:
        if type(paths) is not list or not 2 <= len(paths) <= 6:
            raise ValueError("TWO_TO_SIX_DISTINCT_GROWTH_ROUTES_REQUIRED")
        alt = compare(mapped,shadow,alternatives,evaluated_at_utc=evaluated_at_utc)
        if (type(alt) is not dict or
            alt.get("status")!="OFFLINE_ATTRACTIVENESS_EVIDENCE_COMPARISON_ONLY" or
            alt.get("authorizesAccept") is not False or
            alt.get("authorizesTrade") is not False):
            raise ValueError("ATTRACTIVENESS_COMPARISON_NOT_ADMITTED")
        audited = alt.get("alternatives")
        if type(audited) is not list or not 2 <= len(audited) <= 12:
            raise ValueError("ATTRACTIVENESS_CANDIDATES_MISSING")
        attention = alt.get("researchAttentionIndices")
        if type(attention) is not list or any(type(i) is not int for i in attention):
            raise ValueError("ATTENTION_LIST_INVALID")
        rows=[]
        for item in audited:
            if (type(item) is not dict or
                item.get("status") not in KNOWN_ATTRACTIVENESS or
                item.get("mayUseForTrade") is not False):
                raise ValueError("ATTRACTIVENESS_RESULT_AUTHORITY_OR_STATUS")
            warnings=item.get("evidenceWarnings",[])
            if type(warnings) is not list or any(type(w) is not str for w in warnings):
                raise ValueError("ATTRACTIVENESS_WARNING_SHAPE_INVALID")
            rows.append({
                "index":item["candidateIndex"],"status":item["status"],
                "listedDelta":item.get("listedDelta"),
                "hypotheticalTargetReceived":item.get("hypotheticalTargetReceived") is True,
                "warnings":sorted(set(warnings)),
                "requiresVerifiedPartnerAppeal":True,
                "requiresObservedRetradeLiquidity":True,
                "executable":False,
            })
        tested_paths=[]
        seen=set()
        for i,path in enumerate(paths):
            if type(path) is not list:
                raise ValueError("PATH_IS_NOT_A_LIST")
            # Duplicated path is not a second strategic experiment.
            import json
            stamp=json.dumps(path,sort_keys=True,separators=(",",":"),allow_nan=False)
            if stamp in seen:
                raise ValueError("DUPLICATE_GROWTH_ROUTE_NOT_DISTINCT_EVIDENCE")
            seen.add(stamp)
            outcome=simulate(mapped,shadow,path,evaluated_at_utc=evaluated_at_utc)
            if (type(outcome) is not dict or
                outcome.get("status") not in KNOWN_PATH or
                outcome.get("authorizesTrade") is not False or
                outcome.get("authorizesAccept") is not False):
                raise ValueError("GROWTH_PATH_AUTHORITY_OR_STATUS_UNTRUSTED")
            pathstatus=outcome["status"]
            tested_paths.append({
                "index":i,"status":pathstatus,
                "hypotheticalSteps":outcome.get("simulatedSteps",0),
                "paperListedGrowth":outcome.get("hypotheticalListedValueGrowth"),
                "paperGapToTarget":outcome.get("endingHypotheticalGapToGingerscope"),
                "blockedAtStep":outcome.get("blockedAtStep"),
                "stackPriceUncertain":pathstatus=="OFFLINE_GROWTH_PATH_STACK_UNCERTAIN",
                "hypotheticalTargetReceived":outcome.get("goalTargetHypotheticallyReceived",False),
                "realCounterpartyFeasibilityKnown":False,
                "executed":False,
            })
        partner=explore(mapped,shadow,counterparty,evaluated_at_utc=evaluated_at_utc)
        if (type(partner) is not dict or
            partner.get("status")!="OFFLINE_COUNTERPARTY_OPTIONS_ENUMERATED" or
            partner.get("authorizesTrade") is not False or
            partner.get("counterpartyOwnsAnyItemProven") is not False or
            partner.get("counterpartyConsentProven") is not False):
            raise ValueError("SYNTHETIC_PARTNER_SCOPE_NOT_ADMITTED")
        # NEW S2.3–S2.4 research distinction: an attractive paper trade
        # whose RECEIVED items are absent from the caller's declared
        # synthetic partner shortlist is not even hypothetically
        # inventory-feasible. Never mistake a source-labelled demand score
        # or a candidate's profit for opponent inventory/consent.
        partner_scope=counterparty.get("counterparty")
        if type(partner_scope) is not dict or type(partner_scope.get("items")) is not list:
            raise ValueError("SYNTHETIC_PARTNER_SCOPE_NOT_ADMITTED")
        partner_counts={}
        for entry in partner_scope["items"]:
            if (type(entry) is not dict or set(entry)!={"rawGameKey","quantity"}
                or type(entry["rawGameKey"]) is not str
                or type(entry["quantity"]) is not int
                or entry["rawGameKey"] in partner_counts):
                raise ValueError("SYNTHETIC_PARTNER_SCOPE_NOT_ADMITTED")
            partner_counts[entry["rawGameKey"]]=entry["quantity"]
        for row in rows:
            index=row.get("index")
            if type(index) is not int or not 0 <= index < len(alternatives):
                raise ValueError("ATTRACTIVENESS_RESULT_AUTHORITY_OR_STATUS")
            candidate=alternatives[index]
            incoming=candidate.get("incomingSlots") if type(candidate) is dict else None
            if (row["status"]=="INVALID_ALTERNATIVE" or
                type(incoming) is not list or not incoming):
                row["syntheticPartnerIncomingCoverage"]="NOT_ASSESSED_INVALID_OR_EMPTY"
            else:
                received={}
                for item in incoming:
                    if (type(item) is not dict
                        or set(item)!={"rawGameKey","quantity"}
                        or type(item["rawGameKey"]) is not str
                        or type(item["quantity"]) is not int
                        or item["rawGameKey"] in received):
                        raise ValueError("ATTRACTIVENESS_RESULT_AUTHORITY_OR_STATUS")
                    received[item["rawGameKey"]]=item["quantity"]
                row["syntheticPartnerIncomingCoverage"]=(
                    "COVERED_BY_UNVERIFIED_SYNTHETIC_SHORTLIST"
                    if all(partner_counts.get(k,0)>=q for k,q in received.items())
                    else "NOT_IN_SYNTHETIC_PARTNER_SHORTLIST"
                )
            row["realPartnerOwnershipOrConsentProven"]=False
            row["actionableCandidate"]=False
        behavior=replay(events)
        if (behavior["status"]!="OFFLINE_DIFFERENT_BEHAVIOR_TRAJECTORIES_REPLAYED" or
            behavior["authorizesAccept"] is not False or
            behavior["mayUseForStrategyLearning"] is not False):
            raise ValueError("SYNTHETIC_REACTION_REPLAY_NOT_ADMITTED")
        # No winner selected: these are separate evidence axes with missing
        # acceptance, empirical resale and server settlement. A higher nominal
        # paper return is insufficient to rank counterparty offers.
        return _out(
            "OFFLINE_MULTIPLE_SYSTEM2_STRATEGY_FEATURES_REVIEWED",
            "PRICE_GAIN_NOT_COUNTERPARTY_CONSENT_OR_RETRADABLE_VALUE",
            distinctFeatureGroups=6,
            featureGroups=[
                "BILATERAL_VALUE_AND_RISK",
                "PUBLISHER_DEMAND_STABILITY_AND_CONCENTRATION",
                "MULTI_ROUTE_GINGERSCOPE_GROWTH",
                "BOUNDED_SYNTHETIC_COUNTERPARTY_OPTIONS",
                "REVISION_AWARE_CENSORED_PLAYER_RESPONSES",
                "ACTION_AND_SETTLEMENT_AUTHORITY_FIREWALL",
            ],
            alternatives=rows,
            researchAttentionIndices=attention,
            researchAttentionOrderIsNotAnOfferRanking=True,
            hypotheticalPaths=tested_paths,
            distinctGrowthRoutesCompared=len(tested_paths),
            riskBlockedPaths=sum(r["status"] in ("BLOCKED","BLOCKED_LOSS_POLICY")
                                 for r in tested_paths),
            untrustedStackPaths=sum(r["stackPriceUncertain"] for r in tested_paths),
            syntheticAlternativesNotInDeclaredPartnerShortlist=sum(
                row["syntheticPartnerIncomingCoverage"]==
                "NOT_IN_SYNTHETIC_PARTNER_SHORTLIST" for row in rows
            ),
            syntheticPartnerPairsConsidered=partner.get("totalHypotheticalPairsConsidered",0),
            partnerAcceptanceStillUnknown=True,
            playerResponseOutcomeDistribution=behavior["outcomeDistribution"],
            syntheticReactionEpisodes=behavior["distinctSyntheticEpisodes"],
            chatAmbiguousMessages=behavior["chatAmbiguousUnattributed"],
            verifiedRealOutcomeRowsForTraining=0,
            realTradeOfferRankingAvailable=False,
        )
    except (TypeError,ValueError,KeyError,AttributeError,OverflowError) as e:
        reason=str(e)
        # Don't copy unexpected caller data into a public diagnostic.
        if reason not in {
            "TWO_TO_SIX_DISTINCT_GROWTH_ROUTES_REQUIRED",
            "ATTRACTIVENESS_COMPARISON_NOT_ADMITTED",
            "ATTRACTIVENESS_CANDIDATES_MISSING", "ATTENTION_LIST_INVALID",
            "ATTRACTIVENESS_RESULT_AUTHORITY_OR_STATUS",
            "ATTRACTIVENESS_WARNING_SHAPE_INVALID",
            "PATH_IS_NOT_A_LIST","DUPLICATE_GROWTH_ROUTE_NOT_DISTINCT_EVIDENCE",
            "GROWTH_PATH_AUTHORITY_OR_STATUS_UNTRUSTED",
            "SYNTHETIC_PARTNER_SCOPE_NOT_ADMITTED",
            "SYNTHETIC_REACTION_REPLAY_NOT_ADMITTED",
        }:
            reason="UPSTREAM_RESEARCH_EVIDENCE_INVALID_OR_UNAVAILABLE"
        return _out("BLOCKED",reason)
