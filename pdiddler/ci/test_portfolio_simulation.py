"""Long-run strategy comparisons through verified editions and the planner."""
from copy import deepcopy
from hashlib import sha256
import unittest

from pdiddler.ci.test_supreme_market_editions import BASE_CAPTURE, NEXT_CAPTURE, archive
from pdiddler.system2.manual_portfolio_review import DEFAULT_CATALOG, RequestError
from pdiddler.system2.portfolio_simulation import compare_strategies


OLD = DEFAULT_CATALOG.read_bytes()
CLOCK = "2026-11-25T07:52:05Z"
AXES = {"listed_wealth", "purchasing_power", "market_quality", "target_progress",
        "bilateral_attractiveness", "reliability"}


def phase(counterparties=None, *, raw=OLD, clock=CLOCK, unavailable=()):
    return {"catalog": raw, "expected_sha256": sha256(raw).hexdigest(), "evaluated_at_utc": clock,
            "counterparties": counterparties or [], "unavailable_indices": list(unavailable)}


class PortfolioSimulationTests(unittest.TestCase):
    def test_market_gain_coverage_loss_and_trading_growth_are_distinct(self):
        holdings = {"main": {"godly:Bioblade": 2, "godly:RemovedWeapon": 1},
                    "alt": {"ancient:Gingerscope": 1}}
        phases = [phase(raw=archive(), clock=BASE_CAPTURE), phase(raw=archive(changed=True), clock=NEXT_CAPTURE)]
        strategy = compare_strategies(holdings, phases, strategy_names=("hold",))["strategies"]["hold"]
        self.assertEqual(strategy["hypothetical_trade_growth"], 0)
        self.assertEqual(strategy["common_priced_market_revaluation"], 32)
        self.assertEqual(strategy["market_coverage_change"], -13)
        self.assertIsNone(strategy["realized_growth"])
        self.assertEqual(strategy["phases"][1]["opportunity_status"], "NO_SUPPLIED_OPPORTUNITIES")
        row = strategy["phases"][1]["axes"]
        self.assertEqual(set(row), AXES)
        self.assertEqual(row["listed_wealth"]["combined"]["known"], 202)
        self.assertIsNone(row["listed_wealth"]["combined"]["total"])
        self.assertEqual(row["target_progress"]["alt_reported_protected_copies"], 1)

    def test_route_can_compound_small_gains_and_unavailable_opportunity_changes_no_holdings(self):
        holdings = {"main": {"godly:Fang": 1, "ancient:Gingerscope": 1}, "alt": {"godly:Heat": 2}}
        phases = [phase([{"godly:Gemstone": 1}]), phase([{"godly:Plasmabeam": 1}], unavailable=(0,)),
                  phase([{"godly:Plasmabeam": 1}]), phase([{"godly:Green_Luger": 1}])]
        original = deepcopy((holdings, phases))
        result = compare_strategies(holdings, phases, strategy_names=("hold", "listed_growth"))
        self.assertEqual((holdings, phases), original)
        self.assertEqual(result, compare_strategies(holdings, phases, strategy_names=("hold", "listed_growth")))
        growth = result["strategies"]["listed_growth"]
        self.assertEqual([phase["trade_growth"] for phase in growth["phases"]], [5, 0, 3, 5])
        self.assertEqual(growth["phases"][1]["opportunity_status"], "SUPPLIED_OUTCOME_UNAVAILABLE")
        self.assertEqual(growth["ending_accounts"], {
            "main": {"godly:Green_Luger": 1, "ancient:Gingerscope": 1}, "alt": holdings["alt"],
        })
        self.assertIsNone(growth["cumulative_published_low_endpoint"])
        self.assertFalse(result["authorizes_trade"])
        self.assertIsNone(result["acceptance_probability"])

    def test_published_downside_is_conditional_and_separate_from_no_loss_growth(self):
        holdings = {"main": {"ancient:Emberbow": 1}, "alt": {}}
        result = compare_strategies(holdings, [phase([{"ancient:Emberscythe": 1}])],
                                    strategy_names=("listed_parity",))
        strategy = result["strategies"]["listed_parity"]
        self.assertEqual(strategy["hypothetical_trade_growth"], 0)
        self.assertEqual(strategy["cumulative_published_low_endpoint"], -50)
        self.assertEqual(strategy["published_range_covered_steps"], 1)
        self.assertEqual(strategy["applied_hypothetical_steps"], 1)

    def test_no_opportunity_phase_exposes_adverse_market_without_a_hypothetical_trade(self):
        holdings = {"main": {"ancient:Gingerscope": 1}, "alt": {}}
        result = compare_strategies(holdings, [phase(), phase(raw=archive(), clock=BASE_CAPTURE)],
                                    strategy_names=("listed_growth",))
        growth = result["strategies"]["listed_growth"]
        self.assertEqual(growth["common_priced_market_revaluation"], -15_850)
        self.assertEqual(growth["hypothetical_trade_growth"], 0)
        self.assertEqual(growth["phases"][1]["axes"]["listed_wealth"]["main"]["total"], 150)
        self.assertEqual(growth["ending_accounts"], holdings)

    def test_competing_strategies_diverge_and_target_acquisition_allows_later_growth(self):
        holdings = {"main": {"godly:Boneblade": 1, "godly:Fang": 1}, "alt": {}}
        phases = [phase([{"ancient:Gingerscope": 1}, {"godly:Gemstone": 1}]),
                  phase([{"godly:Plasmabeam": 1}])]
        result = compare_strategies(holdings, phases, strategy_names=("listed_growth", "purchasing_power"))
        growth, power = (result["strategies"][key] for key in ("listed_growth", "purchasing_power"))
        self.assertEqual(growth["phases"][0]["axes"]["target_progress"]["main_reported_protected_copies"], 1)
        self.assertEqual(power["phases"][0]["axes"]["target_progress"]["main_reported_protected_copies"], 0)
        self.assertGreater(growth["phases"][1]["trade_growth"], 0)
        after = growth["phases"][1]["axes"]
        self.assertEqual(after["target_progress"]["main_reported_protected_copies"], 1)
        self.assertNotIn("ancient:Gingerscope", after["bilateral_attractiveness"]["comparison"]["give"])
        self.assertIn("Stable", after["market_quality"]["main"]["published_stability_labels"])

    def test_invalid_timeline_outcomes_and_policy_names_fail_before_returning_results(self):
        holdings = {"main": {"godly:Fang": 1}, "alt": {}}
        with self.assertRaises(RequestError):
            compare_strategies(holdings, [phase(), phase(clock="2026-11-25T07:51:00Z")])
        with self.assertRaises(RequestError):
            compare_strategies(holdings, [phase([{"godly:Gemstone": 1}], unavailable=(1,))])
        with self.assertRaises(RequestError):
            compare_strategies(holdings, [phase()], strategy_names=("auto_execute",))


if __name__ == "__main__":
    unittest.main()
