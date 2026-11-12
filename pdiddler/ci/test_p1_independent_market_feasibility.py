"""Offline structural-feasibility tests, NOT completed trade or market-price tests."""
import unittest
from pdiddler.intelligence_lab import p1_independent_market_feasibility as x


def e(event_id, given, received, mode="HYPOTHETICAL_ONLY"):
    def slots(d):
        return [{"key": k, "quantity": q} for k, q in d.items()]
    return {"eventId": event_id, "mode": mode,
            "given": slots(given), "received": slots(received)}


class IndependentMarketFeasibilityTests(unittest.TestCase):
    def deny(self, r):
        self.assertEqual(r["realVerifiedSettlementCount"], 0)
        self.assertIsNone(r["priceEstimates"])
        self.assertFalse(r["mayUseForLivePriceCalibration"])
        self.assertFalse(r["absoluteMarketScaleIdentifiable"])
        self.assertTrue(r["barterEqualityAssumptionUnproven"])
        self.assertFalse(r["mayAdvanceP2"])
        self.assertEqual(r["tradeOutcome"], "UNKNOWN")
        self.assertTrue(all(r[k] is False for k in x.DENIED))

    def test_actual_checkpoint_no_real_verified_settlements(self):
        r = x.empty_checkpoint()
        self.assertEqual(r["syntheticItemKeys"], 0)
        self.assertEqual(r["equalityConstraintRank"], 0)
        self.assertEqual(r["hypotheticalEventCount"], 0)
        self.assertEqual(r["unresolvedDegreesOfFreedomWithReference"], 0)
        self.deny(r)

    def test_single_pair_needs_arbitrary_relative_anchor(self):
        r = x.analyze([e("a", {"TEST_A": 1}, {"TEST_B": 1})])
        self.assertEqual(r["equalityConstraintRank"], 1)
        self.assertEqual(r["rankWithArbitraryUnitReference"], 2)
        self.assertEqual(r["structurallyIdentifiableSyntheticRelativeKeys"], ["TEST_A","TEST_B"])
        self.deny(r)

    def test_chain_connectivity_structurally_identifies_all_only_under_assumptions(self):
        trades = [e("1", {"TEST_A": 1}, {"TEST_B": 1}),
                  e("2", {"TEST_B": 1}, {"TEST_C": 1}),
                  e("3", {"TEST_C": 2}, {"TEST_D": 1})]
        r = x.analyze(trades)
        self.assertEqual(r["equalityConstraintRank"], 3)
        self.assertEqual(r["rankWithArbitraryUnitReference"], 4)
        self.assertEqual(r["unresolvedDegreesOfFreedomWithReference"], 0)
        self.assertEqual(r["structurallyIdentifiableSyntheticRelativeKeys"],
                         ["TEST_A","TEST_B","TEST_C","TEST_D"])
        self.deny(r)

    def test_disconnected_trade_cluster_cannot_be_identified(self):
        trades = [e("1", {"TEST_A": 1}, {"TEST_B": 1}),
                  e("2", {"TEST_C": 1}, {"TEST_D": 1})]
        r = x.analyze(trades)
        self.assertEqual(r["equalityConstraintRank"], 2)
        self.assertEqual(r["unresolvedDegreesOfFreedomWithReference"], 1)
        self.assertEqual(r["structurallyIdentifiableSyntheticRelativeKeys"], ["TEST_A","TEST_B"])
        self.assertEqual(r["underdeterminedSyntheticRelativeKeys"], ["TEST_C","TEST_D"])
        self.deny(r)

    def test_bundle_equality_does_not_identify_component_values(self):
        r = x.analyze([e("bundle", {"TEST_A": 2}, {"TEST_B": 1,"TEST_C": 1})])
        self.assertEqual(r["rankWithArbitraryUnitReference"], 2)
        self.assertEqual(r["unresolvedDegreesOfFreedomWithReference"], 1)
        self.assertEqual(r["structurallyIdentifiableSyntheticRelativeKeys"], ["TEST_A"])
        self.deny(r)

    def test_duplicate_synthetic_equation_adds_no_rank(self):
        rows = [e("first", {"TEST_A": 1}, {"TEST_B": 1}),
                e("repeat", {"TEST_A": 1}, {"TEST_B": 1})]
        r = x.analyze(rows)
        self.assertEqual(r["hypotheticalEventCount"], 2)
        self.assertEqual(r["equalityConstraintRank"], 1)
        self.deny(r)

    def test_no_information_from_equal_barter_sides(self):
        r = x.analyze([e("zero", {"TEST_A": 1}, {"TEST_A": 1})])
        self.assertEqual(r["equalityConstraintRank"], 0)
        self.assertEqual(r["rankWithArbitraryUnitReference"], 1)
        self.deny(r)

    def test_stack_quantity_unbounded_by_four_physical_slot_rule(self):
        r = x.analyze([e("stack", {"TEST_A": 20}, {"TEST_B": 2})])
        self.assertEqual(r["syntheticItemKeys"], 2)
        self.assertEqual(r["rankWithArbitraryUnitReference"], 2)
        self.deny(r)

    def test_four_distinct_physical_slots_allowed(self):
        r=x.analyze([e("four", {
            "TEST_A": 1, "TEST_B": 2, "TEST_C": 3, "TEST_D": 4},
            {"TEST_E": 1})])
        self.assertEqual(r["syntheticItemKeys"], 5)
        self.deny(r)

    def test_five_physical_slots_invalid_even_if_stacked_copies_valid(self):
        with self.assertRaisesRegex(x.FeasibilityInputError, "PHYSICAL_SLOT"):
            x.analyze([e("five", {f"TEST_{ch}":1 for ch in "ABCDE"},
                         {"TEST_F":1})])

    def test_user_game_weapon_keys_and_private_events_rejected(self):
        with self.assertRaisesRegex(x.FeasibilityInputError,"REAL_OR_INVALID_ITEM_ID"):
            x.analyze([e("real", {"Gingerscope":1}, {"TEST_A":1})])
        with self.assertRaisesRegex(x.FeasibilityInputError,"UNVERIFIED_OR_REAL"):
            x.analyze([e("real-event", {"TEST_A":1}, {"TEST_B":1}, mode="VERIFIED_SETTLED")])

    def test_observed_only_client_trade_cannot_enter_synthetic_research(self):
        with self.assertRaisesRegex(x.FeasibilityInputError,"UNVERIFIED_OR_REAL"):
            x.analyze([e("observed", {"TEST_A":1}, {"TEST_B":1}, mode="CLIENT_OBSERVED")])

    def test_duplicate_event_ids_invalid(self):
        with self.assertRaisesRegex(x.FeasibilityInputError, "DUPLICATE_OR_INVALID_EVENT"):
            x.analyze([e("same", {"TEST_A":1},{"TEST_B":1}),
                       e("same", {"TEST_B":1},{"TEST_C":1})])

    def test_extra_fields_player_identifiers_or_fabricated_outcome_rejected(self):
        row=e("one", {"TEST_A":1}, {"TEST_B":1})
        row["playerId"]="private"
        with self.assertRaisesRegex(x.FeasibilityInputError,"EVENT_SCHEMA"):
            x.analyze([row])
        row=e("two", {"TEST_A":1}, {"TEST_B":1})
        row["status"]="COMPLETED"
        with self.assertRaisesRegex(x.FeasibilityInputError,"EVENT_SCHEMA"):
            x.analyze([row])

    def test_unanchored_graph_reveals_no_identifiable_values(self):
        r=x.analyze([e("pair",{"TEST_B":1},{"TEST_C":1})],
                    reference_key="TEST_UNOBSERVED")
        self.assertFalse(r["referenceIncludedInSyntheticGraph"])
        self.assertEqual(r["structurallyIdentifiableSyntheticRelativeKeys"], [])
        self.deny(r)

    def test_invalid_synthetic_quantity_and_keys(self):
        for qty in (True, 0, -1, 2_000_000, "1"):
            with self.subTest(qty=qty):
                with self.assertRaisesRegex(x.FeasibilityInputError,"INVALID_STACK_QUANTITY"):
                    x.analyze([e("bad",{"TEST_A":qty},{"TEST_B":1})])
        with self.assertRaisesRegex(x.FeasibilityInputError,"DUPLICATE_PHYSICAL_SLOT_KEY"):
            row=e("baddupe",{"TEST_A":1},{"TEST_B":1})
            row["given"].append({"key":"TEST_A","quantity":2})
            x.analyze([row])

    def test_research_retains_zero_live_authorities_even_full_rank(self):
        rows=[e("a",{"TEST_A":1},{"TEST_B":1}),
              e("b",{"TEST_B":1},{"TEST_C":1})]
        r=x.analyze(rows)
        self.assertEqual(r["unresolvedDegreesOfFreedomWithReference"],0)
        self.deny(r)


if __name__ == "__main__":
    unittest.main()
