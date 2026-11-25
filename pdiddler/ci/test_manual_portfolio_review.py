"""Regression tests for the human-operated Gingerscope portfolio report."""
from copy import deepcopy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from pdiddler.system2 import manual_portfolio_review as manual


ROOT = Path(__file__).resolve().parents[2]
ARCHIVE = manual.DEFAULT_CATALOG.read_bytes()
AT = "2026-11-25T07:52:05Z"


def request(main=None, alt=None, *, shortlist=None, counterparty=None):
    data = {"accounts": {"main": main or {}, "alt": alt or {}}}
    if shortlist is not None:
        data["comparison"] = {"mainItemTypes": shortlist, "counterpartyStock": counterparty}
    return data


def report(data, *, at=AT, raw=ARCHIVE):
    return manual.analyze(raw, data, evaluated_at_utc=at)


class ManualPortfolioTests(unittest.TestCase):
    def test_unknown_is_not_zero_and_variant_does_not_alias(self):
        result = report(request({"godly:Fang": 2, "chroma:CFang": 1, "chroma:Fang": 4}))
        main = result["accounts"]["main"]
        self.assertEqual(main["known_copies"], 3)
        self.assertEqual(main["unpriced_copies"], 4)
        self.assertGreater(main["known_listed_value"], 20)
        self.assertIsNone(main["total_listed_value"])
        self.assertIsNone(result["combined"]["total_listed_value"])

    def test_priceless_outside_the_archive_remains_unpriced(self):
        result = report(request({"ancient:Niks_Scythe": 1}))
        main = result["accounts"]["main"]
        self.assertEqual(main["unpriced_copies"], 1)
        self.assertIsNone(main["total_listed_value"])
        self.assertIsNone(main["known_weighted_demand"])

    def test_inventory_wealth_can_clear_target_while_four_slots_cannot(self):
        result = report(request({"ancient:Gingerscope": 1, "ancient:Harvester": 70}))
        main = result["accounts"]["main"]
        self.assertEqual(main["known_listed_value"], 37700)
        self.assertEqual(main["four_slot_single_copy_listed_ceiling"], 310)
        self.assertEqual(main["four_slot_capped_stack_listed_ceiling"], 1240)
        self.assertEqual(main["gingerscope_copies"], 1)
        self.assertEqual(result["target"]["listed_value"], 16000)

    def test_purchase_capacity_uses_four_distinct_slots(self):
        result = report(request(
            {"ancient:Harvester": 4, "ancient:Icepiercer": 4, "ancient:Icebreaker": 4,
             "ancient:Elderwood_Scythe": 4, "godly:Fang": 4}
        ))["accounts"]["main"]
        self.assertEqual(result["four_slot_single_copy_listed_ceiling"], 630)
        self.assertEqual(result["four_slot_capped_stack_listed_ceiling"], 2520)
        self.assertEqual(result["four_slot_capped_stack_target_gap"], 13480)

    def test_account_transfer_preserves_combined_wealth_not_realized_profit(self):
        opening = report(request({"godly:Fang": 2}, {"godly:Boneblade": 1}))
        closing = report(request({"godly:Fang": 1}, {"godly:Fang": 1, "godly:Boneblade": 1}))
        self.assertEqual(opening["combined"]["known_listed_value"], 27)
        self.assertEqual(opening["combined"], closing["combined"])
        self.assertNotEqual(opening["accounts"]["main"], closing["accounts"]["main"])
        self.assertIsNone(closing["realized_growth"])

    def test_small_gain_and_more_than_four_total_copies_are_represented(self):
        result = report(request({"godly:Fang": 1}, shortlist=["godly:Fang"],
                                counterparty={"godly:Boneblade": 1, "godly:Orange_Seer": 9}))
        rows = result["comparison"]["alternatives"]
        matching = [row for row in rows if row["main_listed_delta"] == 5]
        self.assertTrue(matching)
        self.assertEqual(matching[0]["receive"], {"godly:Boneblade": 1, "godly:Orange_Seer": 4})
        self.assertEqual(matching[0]["partner_slots"], 2)
        self.assertEqual(matching[0]["partner_copies"], 5)
        self.assertEqual(matching[0]["counterparty_listed_delta"], -5)
        self.assertTrue(matching[0]["stack_behavior_unverified"])

    def test_give_never_pulls_from_alt_or_protected_asset(self):
        for accounts, key in [
            ({"main": {"ancient:Gingerscope": 1}, "alt": {}}, "ancient:Gingerscope"),
            ({"main": {}, "alt": {"godly:Boneblade": 2}}, "godly:Boneblade"),
        ]:
            with self.subTest(key=key), self.assertRaises(manual.RequestError):
                report({"accounts": accounts, "comparison": {
                    "mainItemTypes": [key], "counterpartyStock": {"godly:Fang": 1}
                }})

    def test_incoming_target_scenario_preserves_both_portfolios(self):
        result = report(request({"ancient:Travelers_Axe": 2, "ancient:Harvester": 11},
                                shortlist=["ancient:Travelers_Axe", "ancient:Harvester"],
                                counterparty={"ancient:Gingerscope": 1}))
        for row in result["comparison"]["alternatives"]:
            self.assertEqual(row["main_listed_delta"] + row["counterparty_listed_delta"], 0)
            self.assertEqual(row["main_listed_delta"], row["main_listed_value_after"] - 16610)
            self.assertEqual(row["counterparty_listed_delta"], row["counterparty_listed_value_after"] - 16000)
            self.assertTrue(row["includes_incoming_gingerscope"])
            self.assertEqual(row["main_gingerscope_copies_after"], 1)
            self.assertIsNone(row["acceptance_probability"])
        self.assertTrue(result["comparison"]["alternatives"])

    def test_no_listed_loss_and_no_same_item_both_sides(self):
        result = report(request({"godly:Fang": 1}, shortlist=["godly:Fang"],
                                counterparty={"godly:Fang": 1, "godly:Boneblade": 1}))
        self.assertEqual(result["comparison"]["alternatives"], [])
        self.assertGreater(result["comparison"]["listed_loss_pairs_excluded"], 0)
        self.assertGreater(result["comparison"]["same_item_pairs_excluded"], 0)

    def test_invalid_types_unknown_comparison_and_too_many_slots_fail(self):
        invalid = [
            request({"godly:Fang": True}),
            request({"godly:Fang": 0}),
            request({"godly:Fang": -1}),
            request({"godly:Fang": 100001}),
            request({"Fang": 1}),
            request({"godly:Fang": 1}, shortlist=["godly:Fang"], counterparty={"godly:fake": 1}),
            request({"godly:Fang": 1}, shortlist=["godly:Fang"] * 5, counterparty={"godly:Fang": 1}),
            request({"godly:Fang": 1}, shortlist=["godly:Fang", "godly:Fang"], counterparty={"godly:Fang": 1}),
        ]
        for data in invalid:
            with self.subTest(data=data), self.assertRaises(manual.RequestError):
                report(data)

    def test_tamper_expired_or_future_source_is_never_used(self):
        for raw, clock in ((ARCHIVE+b" ", AT), (ARCHIVE, "2026-11-25T12:10:00Z"),
                           (ARCHIVE, "2026-11-25T06:09:58Z")):
            with self.subTest(clock=clock), self.assertRaises(ValueError):
                report(request(), at=clock, raw=raw)

    def test_decision_is_deterministic_and_does_not_mutate_input(self):
        data = request({"godly:Fang": 1, "godly:Orange_Seer": 100000},
                       shortlist=["godly:Fang", "godly:Orange_Seer"],
                       counterparty={"godly:Boneblade": 2, "godly:Plasmabeam": 1})
        before = deepcopy(data)
        first = report(data)
        self.assertEqual(before, data)
        data["comparison"]["mainItemTypes"].reverse()
        self.assertEqual(first, report(data))

    def test_at_least_one_candidate_even_with_a_single_stock_combination(self):
        result = report(request({"godly:Boneblade": 1}, shortlist=["godly:Boneblade"],
                                counterparty={"godly:Fang": 1}))
        self.assertEqual(len(result["comparison"]["alternatives"]), 1)
        self.assertEqual(result["comparison"]["alternatives"][0]["main_listed_delta"], 3)

    def test_multiple_manual_growth_routes_reconcile_inventory(self):
        def step(give, receive):
            return {"give": {give: 1}, "receive": {receive: 1},
                    "counterpartyStock": {receive: 1}}

        data = request({"godly:Fang": 1, "ancient:Gingerscope": 1, "pet:Unknown": 1})
        data["growthPaths"] = [
            [step("godly:Fang", "godly:Plasmabeam"), step("godly:Plasmabeam", "godly:Green_Luger")],
            [step("godly:Fang", "godly:Green_Luger"), step("godly:Green_Luger", "ancient:Hallowscythe")],
            [step("godly:Fang", "godly:Plasmabeam"), step("godly:Plasmabeam", "godly:Boneblade")],
        ]
        routes = report(data)["growth_paths"]
        self.assertEqual([routes[0]["hypothetical_listed_growth"], routes[1]["hypothetical_listed_growth"]],
                         [13, 20])
        self.assertEqual(routes[1]["ending_account"]["four_slot_single_copy_listed_ceiling"], 30)
        self.assertEqual(routes[1]["ending_account"]["gingerscope_copies"], 1)
        self.assertIsNone(routes[1]["ending_account"]["total_listed_value"])
        self.assertEqual(routes[2]["status"], "BLOCKED_PATH")
        self.assertEqual(routes[2]["blocked_at_step"], 2)

    def test_corrupted_economic_crosscheck_fails_closed(self):
        from unittest.mock import patch

        data = request({"godly:Boneblade": 1}, shortlist=["godly:Boneblade"],
                       counterparty={"godly:Fang": 1})
        evaluate = manual.review

        def contradict(*args, **kwargs):
            result = evaluate(*args, **kwargs)
            result["hypotheticalAlternatives"][0]["opponentSupremeListedValueGain"] = 3
            return result

        with patch.object(manual, "review", side_effect=contradict), self.assertRaises(manual.RequestError):
            report(data)

    def test_single_copy_published_ranges_provide_bilateral_sensitivity(self):
        data = request({"ancient:Emberbow": 2}, shortlist=["ancient:Emberbow"],
                       counterparty={"ancient:Emberscythe": 2})
        result = report(data)
        self.assertEqual(result["source"]["published_range_row_count"], 17)
        first, *rest = result["comparison"]["alternatives"]
        self.assertEqual(first["published_range_deltas"], {
            "main_low": -50, "main_high": 50, "counterparty_low": -50, "counterparty_high": 50,
        })
        self.assertIsNone(rest[0]["published_range_deltas"])

    def test_missing_published_range_remains_unknown(self):
        data = request({"godly:Boneblade": 1}, shortlist=["godly:Boneblade"],
                       counterparty={"godly:Fang": 1})
        self.assertIsNone(report(data)["comparison"]["alternatives"][0]["published_range_deltas"])

    def test_changed_publisher_range_receipt_fails_closed(self):
        from unittest.mock import patch

        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "altered-parity.json"
            path.write_bytes(manual.PARITY_RECEIPT.read_bytes() + b" ")
            with patch.object(manual, "PARITY_RECEIPT", path), self.assertRaises(manual.RequestError):
                report(request())

    def run_cli(self, payload):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "manually-entered.json"
            path.write_text(payload)
            return subprocess.run(
                [sys.executable, "-m", "pdiddler.system2.manual_portfolio_review",
                 str(path), "--replay-at", AT],
                cwd=ROOT, capture_output=True, text=True, check=False
            )

    def test_cli_reads_json_and_identifies_historical_replay(self):
        result = self.run_cli(json.dumps(request({"godly:Fang": 2})))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["evaluation_clock"], "HISTORICAL_REPLAY")

    def test_cli_rejects_duplicate_json_fields(self):
        result = self.run_cli('{"accounts":{"main":{"godly:Fang":1,"godly:Fang":2},"alt":{}}}')
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, "")
        self.assertNotIn("godly:Fang", result.stderr)
