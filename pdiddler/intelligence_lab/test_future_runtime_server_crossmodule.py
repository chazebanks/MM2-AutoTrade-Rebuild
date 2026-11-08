"""Cross-PR PR107 pure Lua runtime-state -> PR108 Python server shortlist.

The supervisor's simulated state is checked BEFORE supplying the only
hop-suggestion flag to the classifier. Neither module can teleport, send
trade requests, infer player identity, or attest join availability.
"""
from __future__ import annotations
import importlib.util
from pathlib import Path
import random
import shutil
import subprocess
import unittest

ROOT=Path(__file__).resolve().parents[2]
PINNED={
    "pr107":"ff2f2750234ad91d4bed87f3d7e05f370373cbb0",
    "pr108":"4799138c580b36e891d892182e98427525af8a46",
}
def source(label,filename):
    root=ROOT/".offline_sources"/label
    full=root/"pdiddler"/"intelligence_lab"/filename
    if not full.is_file():
        raise AssertionError(f"pinned source not checked out: {full}")
    sha=subprocess.check_output(["git","-C",str(root),"rev-parse","HEAD"],
                                text=True).strip()
    if sha!=PINNED[label]:raise AssertionError(f"pinned {label} drift {sha}")
    return full

def load_server():
    path=source("pr108","future_server_intelligence.py")
    spec=importlib.util.spec_from_file_location("pinned_server_research",path)
    assert spec and spec.loader
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    return module

def candidates():
    return [
        {"jobId":"A11","playerCount":11,"maxPlayers":12,"behaviorClass":"HUMAN_LIKE_SIGNAL_ONLY"},
        {"jobId":"A10","playerCount":10,"maxPlayers":12,"behaviorClass":"UNKNOWN"},
        {"jobId":"A12FULL","playerCount":12,"maxPlayers":12,"behaviorClass":"UNKNOWN"},
        {"jobId":"BOT","playerCount":9,"maxPlayers":12,"behaviorClass":"BOT_HEAVY_SIGNAL_ONLY"},
        {"jobId":"VISITED","playerCount":8,"maxPlayers":12,"behaviorClass":"UNKNOWN"},
    ]
def no_authority(test,out):
    for name in ("authorizesTeleport","authorizesTrade","authorizesAccept",
                 "serverCompletionProven","serverJoinabilityVerified",
                 "realPlayerIdentityVerified","botIdentityVerified","mayReportProfit"):
        test.assertIs(out[name],False,(name,out))

class RuntimeToServerContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server=load_server()

    @unittest.skipUnless(shutil.which("lua5.4"),"CI installs real Lua 5.4")
    def test_real_lua_supervisor_and_python_server_do_not_hop_unsafely(self):
        runtime=source("pr107","future_runtime_supervisor.lua")
        path=ROOT/"pdiddler"/"intelligence_lab"/"test_future_hop_runtime_contract.lua"
        result=subprocess.run(["lua5.4",str(path),str(runtime)],
                              cwd=ROOT,text=True,capture_output=True,timeout=35)
        self.assertEqual(result.returncode,0,result.stdout+"\n"+result.stderr)
        lines=result.stdout.strip().splitlines()
        self.assertEqual(lines[-1],"GIN_FUTURE_HOP_SUPERVISOR_CASES_PASS")
        rows={}
        for line in lines[:-1]:
            name,phase,eligible,combat,trade,loading,epoch=line.split("|")
            self.assertNotIn(name,rows)
            rows[name]={"phase":phase,"eligible":eligible=="true",
                        "combat":combat=="true","trade":trade=="true",
                        "loading":loading=="true","epoch":int(epoch)}
        self.assertEqual(set(rows),{
            "HOP_READY","COMBAT_INTERRUPTED","COOLDOWN_NOT_FINISHED",
            "COOLDOWN_FINISHED","WORLD_RESET","STALE_HOP_IGNORED",
            "TRADE_ACTIVE","TRADE_CLOSED_UNKNOWN","ROTATION_READY_NOT_HOP_ELIGIBLE"})
        for name,r in rows.items():
            # The caller derives flags from its own supervisor, rather than
            # letting a server search response declare it is safe to hop.
            self.assertEqual(r["eligible"],r["phase"]=="HOP_ELIGIBLE")
            response=self.server.shortlist_servers(
                candidates(),visited_ids=["VISITED"],current_id="here",
                trade_active=r["trade"],in_combat=r["combat"],
                world_loading=r["loading"],supervisor_hop_eligible=r["eligible"])
            no_authority(self,response)
            if name in ("HOP_READY","COOLDOWN_FINISHED"):
                self.assertEqual(response["status"],"SHORTLIST_ONLY",(name,response))
                self.assertEqual([x["jobId"] for x in response["candidates"]],["A11","A10"])
                self.assertTrue(all(x["verifiedJoinable"] is False for x in response["candidates"]))
            else:
                self.assertEqual(response["status"],"BLOCKED",(name,response))
        self.assertGreater(rows["WORLD_RESET"]["epoch"],rows["HOP_READY"]["epoch"])
        self.assertEqual(rows["STALE_HOP_IGNORED"]["phase"],"WAIT_WORLD")

    def test_server_shortlist_never_trusts_unknown_flags_900_mutations(self):
        rng=random.Random(20261108)
        for i in range(900):
            keys=("trade_active","in_combat","world_loading","supervisor_hop_eligible")
            flags=dict(trade_active=False,in_combat=False,world_loading=False,
                       supervisor_hop_eligible=True)
            k=keys[i%4]
            flags[k]=None if i%2 else ("not-a-bool" if rng.random()<0.5 else 1)
            out=self.server.shortlist_servers(
                candidates(),visited_ids=["VISITED"],current_id="here",**flags)
            self.assertEqual(out["status"],"BLOCKED",(i,out))
            no_authority(self,out)

if __name__=="__main__":unittest.main()
