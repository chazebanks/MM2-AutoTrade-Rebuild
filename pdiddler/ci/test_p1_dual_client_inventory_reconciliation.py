"""P1: synthetic bilateral inventory reconciliation; never completed trade proof."""
import copy
import unittest

from pdiddler.intelligence_lab import p1_dual_client_inventory_reconciliation as r


def rows(**items):
    return [{"key": key, "quantity": qty} for key, qty in items.items()]


def fixture():
    session = "TEST_SESSION_ONE"
    revision = 2
    return {
        "schema": r.SCHEMA,
        "mode": "HYPOTHETICAL_ONLY",
        "sessionToken": session,
        "offerRevision": revision,
        "offered": {
            "OURS": rows(TEST_A=2), "THEIRS": rows(TEST_B=1)},
        "witnesses": [
            {"side": "OURS", "source": "CLIENT_SNAPSHOT",
             "sessionToken": session, "offerRevision": revision,
             "beforeMs": 1000, "closeMs": 1800, "afterMs": 2500,
             "before": rows(TEST_A=3, TEST_C=5),
             "after": rows(TEST_A=1, TEST_B=1, TEST_C=5)},
            {"side": "THEIRS", "source": "CLIENT_SNAPSHOT",
             "sessionToken": session, "offerRevision": revision,
             "beforeMs": 10, "closeMs": 25, "afterMs": 30,
             "before": rows(TEST_B=2), "after": rows(TEST_B=1, TEST_A=2)}
        ]
    }


class DualClientReconciliationTests(unittest.TestCase):
    def assert_denied(self, out):
        self.assertFalse(out["serverCompletionProven"])
        self.assertFalse(out["serverTransactionIdAuthenticated"])
        self.assertFalse(out["observedTransferAttributedToTrade"])
        self.assertFalse(out["clientWitnessIndependenceProven"])
        self.assertFalse(out["mayUseForStrategyLearning"])
        self.assertFalse(out["mayRecordCompletedTrade"])
        self.assertFalse(out["mayUseForLivePriceCalibration"])
        self.assertFalse(out["mayAdvanceP2"])
        self.assertIsNone(out["marketPrices"])
        self.assertEqual(out["tradeOutcome"], "UNKNOWN")
        self.assertEqual(out["realVerifiedCompletedTrades"], 0)
        self.assertTrue(all(out[k] is False for k in r.FALSE_AUTHORITY))

    def test_matching_both_client_deltas_are_not_server_settlement(self):
        out = r.audit(fixture())
        self.assertEqual(out["status"], "CLIENT_BILATERAL_DELTAS_MATCH_SYNTHETIC")
        self.assertTrue(out["clientDeltaMatchesExpected"])
        self.assertEqual(out["unexpectedOrMissingDeltaCount"], 0)
        self.assert_denied(out)

    def test_separate_local_clocks_are_not_treated_as_shared_time(self):
        sample = fixture()
        self.assertNotEqual(sample["witnesses"][0]["closeMs"],
                            sample["witnesses"][1]["closeMs"])
        out = r.audit(sample)
        self.assertEqual(out["status"], "CLIENT_BILATERAL_DELTAS_MATCH_SYNTHETIC")
        self.assert_denied(out)

    def test_reordered_witnesses_are_equivalent(self):
        sample = fixture()
        sample["witnesses"].reverse()
        self.assertEqual(r.audit(sample)["status"], r.audit(fixture())["status"])

    def test_one_sided_uncompensated_offer_may_be_matched_not_proven(self):
        sample = fixture()
        sample["offered"]["THEIRS"] = []
        sample["witnesses"][0]["after"] = rows(TEST_A=1, TEST_C=5)
        sample["witnesses"][1]["after"] = rows(TEST_B=2, TEST_A=2)
        out = r.audit(sample)
        self.assertTrue(out["clientDeltaMatchesExpected"])
        self.assert_denied(out)

    def test_one_side_missing_weapon_delta_quarantined(self):
        sample = fixture()
        sample["witnesses"][1]["after"] = rows(TEST_B=1, TEST_A=1)
        out = r.audit(sample)
        self.assertEqual(out["status"], "QUARANTINED")
        self.assertEqual(out["reason"], "BILATERAL_CLIENT_DELTA_CONFLICT")
        self.assertEqual(out["unmatchedSyntheticKeysBySide"]["THEIRS"], ["TEST_A"])
        self.assert_denied(out)

    def test_additional_unrelated_inventory_change_quarantined(self):
        sample = fixture()
        sample["witnesses"][0]["after"] = rows(TEST_A=1, TEST_B=1, TEST_C=6)
        out = r.audit(sample)
        self.assertEqual(out["status"], "QUARANTINED")
        self.assertIn("TEST_C", out["unmatchedSyntheticKeysBySide"]["OURS"])
        self.assert_denied(out)

    def test_gui_close_only_no_snapshot_transfer_quarantined(self):
        sample = fixture()
        for w in sample["witnesses"]:
            w["after"] = copy.deepcopy(w["before"])
        out = r.audit(sample)
        self.assertEqual(out["status"], "QUARANTINED")
        self.assertFalse(out["clientDeltaMatchesExpected"])
        self.assert_denied(out)

    def test_equal_same_key_offer_has_no_observable_net_effect(self):
        sample = fixture()
        sample["offered"]["OURS"] = rows(TEST_A=1)
        sample["offered"]["THEIRS"] = rows(TEST_A=1)
        sample["witnesses"][0]["after"] = copy.deepcopy(sample["witnesses"][0]["before"])
        sample["witnesses"][1]["before"] = rows(TEST_A=4)
        sample["witnesses"][1]["after"] = rows(TEST_A=4)
        out = r.audit(sample)
        self.assertEqual(out["status"], "INCONCLUSIVE_NO_NET_EFFECT")
        self.assert_denied(out)

    def test_both_sides_same_item_unequal_stack_quantity(self):
        sample = fixture()
        sample["offered"]["OURS"] = rows(TEST_A=2)
        sample["offered"]["THEIRS"] = rows(TEST_A=1)
        sample["witnesses"][0]["after"] = rows(TEST_A=2, TEST_C=5)
        sample["witnesses"][1]["before"] = rows(TEST_A=4)
        sample["witnesses"][1]["after"] = rows(TEST_A=5)
        out = r.audit(sample)
        self.assertEqual(out["status"], "CLIENT_BILATERAL_DELTAS_MATCH_SYNTHETIC")
        self.assert_denied(out)

    def test_stacked_quantity_more_than_four_copies_is_allowed(self):
        sample = fixture()
        sample["offered"]["OURS"] = rows(TEST_A=20)
        sample["witnesses"][0]["before"] = rows(TEST_A=30, TEST_C=5)
        sample["witnesses"][0]["after"] = rows(TEST_A=10, TEST_B=1, TEST_C=5)
        sample["witnesses"][1]["after"] = rows(TEST_B=1, TEST_A=20)
        out = r.audit(sample)
        self.assertTrue(out["clientDeltaMatchesExpected"])
        self.assert_denied(out)

    def test_four_individual_physical_offer_slots_are_allowed(self):
        sample = fixture()
        sample["offered"]["OURS"] = rows(TEST_A=1, TEST_C=1, TEST_D=1, TEST_E=1)
        sample["witnesses"][0]["before"] = rows(TEST_A=3, TEST_C=5, TEST_D=1, TEST_E=1)
        sample["witnesses"][0]["after"] = rows(TEST_A=2, TEST_C=4, TEST_B=1)
        sample["witnesses"][1]["after"] = rows(
            TEST_B=1, TEST_A=1, TEST_C=1, TEST_D=1, TEST_E=1)
        out = r.audit(sample)
        self.assertTrue(out["clientDeltaMatchesExpected"])
        self.assert_denied(out)

    def test_five_physical_slots_rejected(self):
        sample = fixture()
        sample["offered"]["OURS"] = rows(
            TEST_A=1, TEST_C=1, TEST_D=1, TEST_E=1, TEST_F=1)
        with self.assertRaisesRegex(r.ReconcileInputError, "ITEM_LIST_INVALID"):
            r.audit(sample)

    def test_mismatched_session_token_rejected(self):
        sample = fixture()
        sample["witnesses"][1]["sessionToken"] = "TEST_SESSION_OTHER"
        with self.assertRaisesRegex(r.ReconcileInputError, "CROSS_SESSION"):
            r.audit(sample)

    def test_mismatched_revision_rejected_even_matching_numbers(self):
        sample = fixture()
        sample["witnesses"][1]["offerRevision"] = 1
        with self.assertRaisesRegex(r.ReconcileInputError, "STALE_OR_WRONG"):
            r.audit(sample)

    def test_postclose_readback_before_close_rejected(self):
        sample = fixture()
        sample["witnesses"][0]["afterMs"] = sample["witnesses"][0]["closeMs"]
        with self.assertRaisesRegex(r.ReconcileInputError, "PRE_CLOSE_POST_ORDER_INVALID"):
            r.audit(sample)

    def test_repeated_client_witness_on_one_side_rejected(self):
        sample = fixture()
        sample["witnesses"][1]["side"] = "OURS"
        with self.assertRaisesRegex(r.ReconcileInputError, "WITNESS_SIDE_DUPLICATE"):
            r.audit(sample)

    def test_missing_client_witness_rejected(self):
        sample = fixture()
        sample["witnesses"].pop()
        with self.assertRaisesRegex(r.ReconcileInputError, "WITNESS_COUNT_INVALID"):
            r.audit(sample)

    def test_gift_cannot_claim_server_settlement(self):
        sample = fixture()
        sample["witnesses"][0]["source"] = "SERVER_RECEIPT"
        with self.assertRaisesRegex(r.ReconcileInputError, "UNSUPPORTED_OR_FAKE_SERVER"):
            r.audit(sample)

    def test_private_ids_and_authority_injection_rejected(self):
        sample = fixture()
        sample["witnesses"][1]["robloxUserId"] = 1234
        with self.assertRaisesRegex(r.ReconcileInputError, "WITNESS_FIELDS_UNTRUSTED"):
            r.audit(sample)
        sample = fixture()
        sample["serverCompletionProven"] = True
        with self.assertRaisesRegex(r.ReconcileInputError, "SOURCE_FIELDS_UNTRUSTED"):
            r.audit(sample)

    def test_real_or_untrusted_weapon_id_rejected(self):
        sample = fixture()
        sample["offered"]["THEIRS"] = rows(Gingerscope=1)
        with self.assertRaisesRegex(r.ReconcileInputError, "REAL_OR_INVALID_ITEM_KEY"):
            r.audit(sample)

    def test_protected_gingerscope_outbound_rejected_even_test_label(self):
        sample = fixture()
        sample["offered"]["OURS"] = rows(TEST_GINGERSCOPE=1)
        with self.assertRaisesRegex(r.ReconcileInputError, "PROTECTED_GINGERSCOPE_OUTBOUND"):
            r.audit(sample)

    def test_malformed_quantities_and_duplicate_item_keys_rejected(self):
        for bad in (True, 0, -1, "1", 100_001):
            sample = fixture()
            sample["offered"]["OURS"][0]["quantity"] = bad
            with self.subTest(bad=bad):
                with self.assertRaisesRegex(r.ReconcileInputError, "ITEM_QUANTITY_INVALID"):
                    r.audit(sample)
        sample = fixture()
        sample["offered"]["OURS"].append({"key": "TEST_A", "quantity": 1})
        with self.assertRaisesRegex(r.ReconcileInputError, "DUPLICATE_ITEM_KEY"):
            r.audit(sample)

    def test_offer_exceeds_before_snapshot_rejected(self):
        sample = fixture()
        sample["offered"]["OURS"] = rows(TEST_A=4)
        with self.assertRaisesRegex(r.ReconcileInputError,
                                   "OFFER_EXCEEDS_BEFORE_SNAPSHOT"):
            r.audit(sample)

    def test_empty_offer_rejected(self):
        sample = fixture()
        sample["offered"] = {"OURS": [], "THEIRS": []}
        with self.assertRaisesRegex(r.ReconcileInputError, "EMPTY_OFFER"):
            r.audit(sample)

    def test_untrusted_real_evidence_mode_rejected(self):
        sample = fixture()
        sample["mode"] = "REAL_SETTLED_CLIENT"
        with self.assertRaisesRegex(r.ReconcileInputError, "REAL_EVIDENCE_NOT_AUTHORIZED"):
            r.audit(sample)

    def test_no_price_accepted_or_learning_even_synthetic_match(self):
        out = r.audit(fixture())
        self.assertEqual(out["realVerifiedCompletedTrades"], 0)
        self.assertIsNone(out["marketPrices"])
        self.assertFalse(out["mayRecordCompletedTrade"])
        self.assertFalse(out["mayUseForStrategyLearning"])
        self.assertFalse(out["authorizesAccept"])
        self.assert_denied(out)


if __name__ == "__main__":
    unittest.main()
