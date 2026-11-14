"""Independent property oracle for exact ALT->MAIN consecutive manual trades.

No Roblox API and no user inventory. Distinguishes four physical slots
from arbitrarily stacked quantities, and never equates client delta with
server-authenticated settlement.
"""
from __future__ import annotations

from collections import Counter
from itertools import combinations
from pathlib import Path
import random
import unittest

ROOT=Path(__file__).resolve().parents[2]
CORE=ROOT/"pdiddler/supervised/main_alt_manual_multitrade_delta_core.lua"
NATIVE=ROOT/"pdiddler/supervised/MAIN_ALT_MANUAL_MULTITRADE_WITNESS_NATIVE.lua"

def accept_by_reference(before, after, entries):
    """Pure independent reference, for test fixtures ONLY; not trade authorization."""
    if not 1<=len(entries)<=4: return False
    seen_keys=set()
    seen_slots=set()
    delta=Counter()
    for slot,key,qty in entries:
        if slot not in range(1,5) or not isinstance(qty,int) or qty<1 or qty>10000:
            return False
        if key in seen_keys or slot in seen_slots:
            return False
        seen_keys.add(key)
        seen_slots.add(slot)
        delta[key]+=qty
    all_keys=set(before)|set(after)|set(delta)
    return all(after.get(k,0)-before.get(k,0)==delta.get(k,0) for k in all_keys)

class IndependentMultitradeOracleTests(unittest.TestCase):
    def test_1500_randomized_2_to_6_trade_sessions(self):
        rng=random.Random(209911)
        for _ in range(1500):
            own={"item_"+str(i):rng.randint(0,4) for i in range(8)}
            steps=rng.randint(2,6)
            for _ in range(steps):
                n=rng.randint(1,4)
                keys=rng.sample(list(own),n)
                entries=[(i+1,k,rng.randint(1,8)) for i,k in enumerate(keys)]
                after=dict(own)
                for _,key,qty in entries: after[key]+=qty
                self.assertTrue(accept_by_reference(own,after,entries))
                # Wrong quantity, stolen outgoing item, unrelated receipt and
                # duplicate physical slot must not be accepted.
                wrong=dict(after);wrong[keys[0]]-=1
                self.assertFalse(accept_by_reference(own,wrong,entries))
                extras=dict(after);extras["unexpected"] = 1
                self.assertFalse(accept_by_reference(own,extras,entries))
                if len(entries)>1:
                    duplicate=[(1,k,q) for _,k,q in entries]
                    self.assertFalse(accept_by_reference(own,after,duplicate))
                own=after
    def test_five_copies_not_fifth_physical_slot(self):
        self.assertTrue(accept_by_reference({},{"stack":5},[(1,"stack",5)]))
        self.assertFalse(accept_by_reference({},{"stack":5},[(5,"stack",5)]))
        self.assertFalse(accept_by_reference({},{"stack":5},[(1,"stack",5)]*5))
    def test_four_distinct_items_same_trade(self):
        offer=[(1,"A",2),(2,"B",1),(3,"C",3),(4,"D",4)]
        self.assertTrue(accept_by_reference({},{"A":2,"B":1,"C":3,"D":4},offer))
        self.assertFalse(accept_by_reference({},{"A":2,"B":1,"C":3,"D":5},offer))
    def test_sequential_duplicate_weapon_in_distinct_trades(self):
        own={}
        for count in range(1,11):
            nxt={"A":count}
            self.assertTrue(accept_by_reference(own,nxt,[(1,"A",1)]))
            own=nxt
    def test_no_automatic_accept_in_native_or_core(self):
        c=CORE.read_text();n=NATIVE.read_text()
        for block in (c,n):
            for forbidden in ("AcceptTrade:FireServer(", "OfferItem:FireServer(",
                              "SendMouseButtonEvent(", "VirtualInputManager",
                              "TeleportService", "PostAsync(", "firesignal("):
                self.assertNotIn(forbidden,block)
        self.assertIn("actualScriptAccepts=0",c)
        self.assertIn('serverCompletionProven=false',c)
        self.assertIn("TRADE_ROOT_LOST_OR_UNEXPECTED_CLOSURE",c)
        self.assertIn("ALТ_ACCEPT_MUST_BE_OBSERVED_FIRST".replace("Т","T"),c)
    def test_one_runtime_and_no_one_trade_spend_barrier(self):
        c=CORE.read_text();n=NATIVE.read_text()
        self.assertIn("READY_FOR_NEXT_MAIN_ALT_TRADE",c)
        self.assertIn('operatorScope="ALL_MAIN_ALT_TRADES_IN_THIS_JOB"',n)
        self.assertIn("if before.phase==\"READY\" then",n)
        self.assertNotIn("ONE_TRADE_ONLY",c+n)
        self.assertNotIn("onlyFirstTrade",c+n)

if __name__=="__main__":
    unittest.main()
