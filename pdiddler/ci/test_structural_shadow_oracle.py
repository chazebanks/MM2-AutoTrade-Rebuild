"""Independent Python oracle for System2 structural shadow bundle accounting.

The actual Luau module AND actual native one-tap runner are executed separately
under Lune; this oracle checks integer/combinatorial reference facts and static
safety boundaries. Does NOT create actual MM2 trade instructions or prices.
"""
from __future__ import annotations
import itertools
from pathlib import Path
import random
import unittest

ROOT=Path(__file__).resolve().parents[2]
CORE=ROOT/"pdiddler/system2/native_structural_shadow_core.lua"
RUNNER=ROOT/"pdiddler/system2/SYSTEM2_STRUCTURAL_SHADOW_READONLY_NATIVE.lua"
TARGET="Gingerscope"

def reference_four_slot_copy_capacity(owned:dict[str,int]):
    non_target=sorted(
        (qty for key,qty in owned.items() if key!=TARGET and qty>0),
        reverse=True
    )
    return sum(non_target[:4])

def brute_force(owned):
    options=[(key,n) for key,n in owned.items() if key!=TARGET and n>0]
    result=0
    for width in range(1,min(len(options),4)+1):
        for subset in itertools.combinations(options,width):
            result=max(result,sum(q for _,q in subset))
    return result

class ShadowMathOracle(unittest.TestCase):
    def test_top_four_non_target_stacks_equals_exact_brute_force(self):
        rng=random.Random(417)
        for _ in range(900):
            owned={f"safe_{i}":rng.randrange(0,18)
                   for i in range(rng.randrange(0,11))}
            owned[TARGET]=rng.randrange(0,100)
            self.assertEqual(reference_four_slot_copy_capacity(owned),
                             brute_force(owned))
    def test_target_hard_exclusion_even_with_high_stack(self):
        self.assertEqual(reference_four_slot_copy_capacity(
            {"A":3,"B":1,"C":2,"D":1,TARGET:999999}),7)
    def test_four_slots_is_not_four_copies(self):
        self.assertEqual(reference_four_slot_copy_capacity(
            {"A":5,"B":4,"C":3,"D":2,"E":100}),112)
    def test_physical_slot_template_monotonicity(self):
        for count in range(0,40):
            statuses=[count>=width for width in range(1,5)]
            self.assertEqual(statuses,sorted(statuses,reverse=True))
    def test_native_read_only_audit_is_composed_not_reimplemented(self):
        s=RUNNER.read_text()
        self.assertIn("native_key_reconciliation_core.lua",s)
        self.assertIn("native_structural_shadow_core.lua",s)
        self.assertIn("stage83_public_slug_registry.lua",s)
        self.assertEqual(s.count("rf:InvokeServer()"),1)
        for unsafe in ("FireServer(","TeleportService","AcceptTrade(",
                       "DeclineTrade(","PostAsync(",":FireServer("):
            self.assertNotIn(unsafe,s)
    def test_pure_core_denies_all_live_authority(self):
        s=CORE.read_text()
        for value in (
            "verifiedCurrentMarketPrice=false",
            "publisherEditionAuthenticated=false",
            "approvedLossBudget=false",
            "authorizesOffer=false",
            "authorizesTrade=false",
            "authorizesAccept=false",
            "marketLiquidity=\"UNKNOWN\"",
            "sourcePricesExported=false",
            "Gingerscope",
        ):
            self.assertIn(value,s)
        self.assertNotIn("RBLXVALUE_API_KEY",s)
    def test_no_reinvented_source_prices_or_personal_inventory_export(self):
        s=CORE.read_text()+"\n"+RUNNER.read_text()
        for forbidden in ("Emberbow=650","Harvester=250",
                          "Gingerscope=16000","getgenv().OwnedInventory",
                          "getgenv().MainAccountPassword"):
            self.assertNotIn(forbidden,s)

if __name__=="__main__":
    unittest.main()
