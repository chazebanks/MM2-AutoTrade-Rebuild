"""OFFLINE MM2 bot-like-server signals and hop shortlist research.

No Roblox API, teleport, server HTTP, executor, player identification, or
automatic bot accusation. Unknown observations remain unknown, and
near-full candidate populations are NOT evidence the server can be joined.
"""
from __future__ import annotations

from math import ceil

SCHEMA = "gingerscope-future-server-research-v1"
MIN_FOOTAGE_MS = 6000
MAX_FOOTAGE_MS = 10000
MAX_SERVERS = 60
MAX_OBSERVED_PLAYERS = 12


def _base(status,reason):
    return {
        "schema":SCHEMA, "status":status, "reason":reason,
        "authorizesTeleport":False, "authorizesTrade":False,
        "authorizesAccept":False, "botIdentityVerified":False,
        "realPlayerIdentityVerified":False, "serverJoinabilityVerified":False,
        "serverCompletionProven":False, "mayReportProfit":False,
    }


def classify_server(observations: object, *, elapsed_ms: object) -> dict:
    """Infer weak behavior patterns, never a verified bot or person identity."""
    result=_base("INCONCLUSIVE","INSUFFICIENT_INDEPENDENT_BEHAVIOR_SAMPLES")
    result.update({"evaluatedPlayers":0,"botLikeVotes":0,"humanLikeVotes":0})
    if type(elapsed_ms) is not int or not 0<=elapsed_ms<=MAX_FOOTAGE_MS:
        result.update(status="INVALID",reason="OBSERVATION_WINDOW_INVALID_OR_EXPIRED")
        return result
    if not isinstance(observations,list) or len(observations)>MAX_OBSERVED_PLAYERS:
        result.update(status="INVALID",reason="PLAYER_OBSERVATIONS_INVALID")
        return result
    if len(observations)<4 or elapsed_ms<MIN_FOOTAGE_MS:
        return result
    for record in observations:
        if not isinstance(record,dict):
            result.update(status="INVALID",reason="PLAYER_OBSERVATIONS_INVALID")
            return result
        frame_count=record.get("frameCount")
        loops=record.get("repeatedPathLoops")
        animation=record.get("animationClass")
        task=record.get("taskClass")
        if (type(frame_count) is not int or not 0<=frame_count<=250 or
                type(loops) is not int or not 0<=loops<=50 or
                animation not in ("DEFAULT_ONLY","VARIED","UNKNOWN") or
                task not in ("REPEATED_FARM","VARIED","UNKNOWN")):
            result.update(status="INVALID",reason="UNTRUSTED_SAMPLE_SHAPE")
            return result
        if frame_count<6:  # unobserved players do not count toward votes
            continue
        result["evaluatedPlayers"]+=1
        if loops>=3 and animation=="DEFAULT_ONLY" and task=="REPEATED_FARM":
            result["botLikeVotes"]+=1
        if loops<=1 and animation=="VARIED" and task=="VARIED":
            result["humanLikeVotes"]+=1
    n=result["evaluatedPlayers"]
    if n<4:
        return result
    if result["botLikeVotes"]>=max(4,ceil(n*0.7)) and result["humanLikeVotes"]==0:
        result.update(status="BOT_HEAVY_SIGNAL_ONLY",
                      reason="MULTIPLE_REPEATED_BEHAVIOR_CLUES_NOT_ACCOUNT_PROOF")
    elif result["humanLikeVotes"]>=max(3,ceil(n*0.5)):
        result.update(status="HUMAN_LIKE_SIGNAL_ONLY",
                      reason="DIVERSE_INDEPENDENT_BEHAVIOR_NOT_ACCOUNT_PROOF")
    return result


def shortlist_servers(servers: object, *, visited_ids: object, current_id: object,
                      trade_active: object, in_combat: object,
                      world_loading: object, supervisor_hop_eligible: object,
                      max_results: int = 5) -> dict:
    """Candidate ordering only; actual joinability and hop mechanics external."""
    result=_base("BLOCKED","UNKNOWN_CONTEXT")
    result["candidates"]=[]
    if not all(type(x) is bool for x in
        (trade_active,in_combat,world_loading,supervisor_hop_eligible)):
        result["reason"]="UNVERIFIED_HOP_SAFETY_CONTEXT"
        return result
    if trade_active or in_combat or world_loading or not supervisor_hop_eligible:
        result["reason"]="HOP_NOT_SAFE_OR_NOT_AUTHORIZED_BY_SUPERVISOR"
        return result
    if (not isinstance(current_id,str) or not current_id or
            not isinstance(visited_ids,list) or
            any(not isinstance(x,str) or not x for x in visited_ids) or
            not isinstance(servers,list) or len(servers)>MAX_SERVERS or
            type(max_results) is not int or not 1<=max_results<=10):
        result["reason"]="INVALID_SERVER_OR_VISIT_DATA"
        return result
    if len(set(visited_ids))!=len(visited_ids):
        result["reason"]="VISIT_HISTORY_HAS_DUPLICATES"
        return result
    selected=[]
    seen=set()
    visited=set(visited_ids)|{current_id}
    for s in servers:
        if not isinstance(s,dict):
            result["reason"]="SERVER_CANDIDATE_MALFORMED"
            return result
        job=s.get("jobId")
        count=s.get("playerCount")
        cap=s.get("maxPlayers")
        cls=s.get("behaviorClass","UNKNOWN")
        if (not isinstance(job,str) or not 1<=len(job)<=160 or job in seen or
                type(count) is not int or type(cap) is not int or
                not 0<=count<=cap<=12 or cap<2 or
                cls not in ("UNKNOWN","INCONCLUSIVE","BOT_HEAVY_SIGNAL_ONLY","HUMAN_LIKE_SIGNAL_ONLY")):
            result["reason"]="SERVER_CANDIDATE_MALFORMED"
            return result
        seen.add(job)
        if job in visited or count>=cap or cls=="BOT_HEAVY_SIGNAL_ONLY":
            continue
        if cap==12 and count==11:
            band=0
        elif cap==12 and count==10:
            band=1
        elif cap==12 and count==9:
            band=2
        else:
            band=3
        confidence=0 if cls=="HUMAN_LIKE_SIGNAL_ONLY" else 1
        selected.append((band,confidence,-count,job,{
            "jobId":job,"playersAtObservation":count,"maxPlayers":cap,
            "behaviorClass":cls,
            "nearFullJoinRisk":count>=cap-1,
            "isLiveAvailable":False,
            "verifiedJoinable":False,
        }))
    selected.sort(key=lambda x:x[:4])
    result["status"]="SHORTLIST_ONLY" if selected else "NO_ELIGIBLE_CANDIDATES"
    result["reason"]="POPULATION_HEURISTIC_NOT_LIVE_AVAILABILITY"
    result["candidates"]=[x[4] for x in selected[:max_results]]
    return result
