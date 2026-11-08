"""Adversarial offline 10-second bot-signal and safe server shortlist tests."""
import copy
import importlib.util
import random
import unittest
from pathlib import Path
ROOT=Path(__file__).parent
S=importlib.util.spec_from_file_location("server_research",ROOT/"future_server_intelligence.py")
M=importlib.util.module_from_spec(S)
S.loader.exec_module(M)

def bots(n=6):
    return [{"frameCount":12,"repeatedPathLoops":4,"animationClass":"DEFAULT_ONLY",
             "taskClass":"REPEATED_FARM"} for _ in range(n)]
def humans(n=6):
    return [{"frameCount":12,"repeatedPathLoops":0,"animationClass":"VARIED",
             "taskClass":"VARIED"} for _ in range(n)]
def servers():
    return [{"jobId":f"s{i}","playerCount":count,"maxPlayers":12,
             "behaviorClass":"UNKNOWN"} for i,count in enumerate([9,10,11,12,8])]

def safe(x):
    for k in ("authorizesTeleport","authorizesTrade","authorizesAccept",
              "botIdentityVerified","realPlayerIdentityVerified",
              "serverJoinabilityVerified","serverCompletionProven","mayReportProfit"):
        assert x[k] is False,(k,x)

class FutureServerIntelTests(unittest.TestCase):
    def test_synthetic_bot_heavy_and_human_like_not_person_identity(self):
        for players,expected in [(bots(),"BOT_HEAVY_SIGNAL_ONLY"),
                                 (humans(),"HUMAN_LIKE_SIGNAL_ONLY")]:
            x=M.classify_server(players,elapsed_ms=8000)
            self.assertEqual(x["status"],expected)
            safe(x)

    def test_voice_chat_absence_must_never_be_bot_evidence(self):
        players=humans()
        before=M.classify_server(players,elapsed_ms=9000)
        for p in players:
            p["voiceChatAvailable"]=False
        after=M.classify_server(players,elapsed_ms=9000)
        self.assertEqual(before,after)
        self.assertEqual(after["status"],"HUMAN_LIKE_SIGNAL_ONLY")

    def test_ten_second_budget_and_minimum_four_observed(self):
        for elapsed,expected in [(5000,"INCONCLUSIVE"),
                                 (10000,"BOT_HEAVY_SIGNAL_ONLY"),
                                 (10001,"INVALID"),(-1,"INVALID")]:
            x=M.classify_server(bots(),elapsed_ms=elapsed)
            self.assertEqual(x["status"],expected)
        self.assertEqual(M.classify_server(bots(3),elapsed_ms=9000)["status"],"INCONCLUSIVE")
        insufficient=bots()
        for p in insufficient[2:]:p["frameCount"]=2
        self.assertEqual(M.classify_server(insufficient,elapsed_ms=9000)["status"],"INCONCLUSIVE")

    def test_weaker_signal_does_not_mislabel_bot(self):
        p=bots()
        for row in p:
            row["taskClass"]="VARIED"
        self.assertEqual(M.classify_server(p,elapsed_ms=9000)["status"],"INCONCLUSIVE")
        mixed=bots(3)+humans(3)
        self.assertEqual(M.classify_server(mixed,elapsed_ms=9000)["status"],"HUMAN_LIKE_SIGNAL_ONLY")
        mixed=bots(3)+humans(2)+[{"frameCount":12,"repeatedPathLoops":2,
                                  "animationClass":"UNKNOWN","taskClass":"UNKNOWN"}]
        self.assertEqual(M.classify_server(mixed,elapsed_ms=9000)["status"],"INCONCLUSIVE")

    def test_shortlist_prefers_11_then_10_then_9_without_claiming_joinable(self):
        x=M.shortlist_servers(servers(),visited_ids=[],current_id="here",
            trade_active=False,in_combat=False,world_loading=False,
            supervisor_hop_eligible=True)
        self.assertEqual(x["status"],"SHORTLIST_ONLY")
        self.assertEqual([r["playersAtObservation"] for r in x["candidates"]],[11,10,9,8])
        self.assertTrue(x["candidates"][0]["nearFullJoinRisk"])
        self.assertFalse(x["candidates"][0]["verifiedJoinable"])
        safe(x)

    def test_never_rejoin_current_visited_or_bot_heavy(self):
        c=servers()
        c[0]["behaviorClass"]="BOT_HEAVY_SIGNAL_ONLY"
        x=M.shortlist_servers(c,visited_ids=["s1"],current_id="s2",
            trade_active=False,in_combat=False,world_loading=False,
            supervisor_hop_eligible=True)
        self.assertEqual([a["jobId"] for a in x["candidates"]],["s4"])

    def test_trade_combat_loading_unknown_flags_all_block(self):
        flags=("trade_active","in_combat","world_loading","supervisor_hop_eligible")
        base=dict(trade_active=False,in_combat=False,world_loading=False,
                  supervisor_hop_eligible=True)
        for key in flags:
            p=dict(base);p[key]=False if key=="supervisor_hop_eligible" else True
            out=M.shortlist_servers(servers(),visited_ids=[],current_id="here",**p)
            self.assertEqual(out["status"],"BLOCKED");safe(out)
            p[key]=None
            out=M.shortlist_servers(servers(),visited_ids=[],current_id="here",**p)
            self.assertEqual(out["status"],"BLOCKED");safe(out)

    def test_invalid_duplicate_servers_and_visit_history(self):
        cases=[
            (servers()+[copy.deepcopy(servers()[0])],[], "SERVER_CANDIDATE_MALFORMED"),
            (servers(),["s1","s1"],"VISIT_HISTORY_HAS_DUPLICATES"),
            (servers()+[{"jobId":"bad","playerCount":13,"maxPlayers":12}],[],
             "SERVER_CANDIDATE_MALFORMED"),
        ]
        for c,visited,reason in cases:
            x=M.shortlist_servers(c,visited_ids=visited,current_id="here",
                trade_active=False,in_combat=False,world_loading=False,
                supervisor_hop_eligible=True)
            self.assertEqual(x["reason"],reason);safe(x)

    def test_1000_adversarial_shapes_always_fail_closed(self):
        rng=random.Random(6073)
        for i in range(1000):
            p=bots()
            x=copy.deepcopy(p)
            v=i%8
            if v==0:x[0]["frameCount"]=True
            elif v==1:x[0]["repeatedPathLoops"]=-1
            elif v==2:x[0]["animationClass"]="BOTS_PROVEN"
            elif v==3:x[0]["taskClass"]="SERVER_SETTLED"
            elif v==4:x[0]=None
            elif v==5:x=x*3
            elif v==6:x[0]["frameCount"]=rng.randrange(251,999)
            elif v==7:x[0]["repeatedPathLoops"]=rng.randrange(51,999)
            out=M.classify_server(x,elapsed_ms=8500)
            self.assertEqual(out["status"],"INVALID",(i,out))
            safe(out)

    def test_pure_no_teleport_or_network_usage(self):
        s=(ROOT/"future_server_intelligence.py").read_text()
        for part in ("TeleportToPlaceInstance(", "TeleportAsync(", "FireServer(",
                     "HttpGet(", "requests.get(", "PostAsync(", "setclipboard("):
            self.assertNotIn(part,s)
if __name__=="__main__":
    unittest.main()
