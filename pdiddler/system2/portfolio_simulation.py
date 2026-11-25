"""Compare explicit offline strategy baselines over successive Supreme editions.

Each phase permits one independently evaluated hypothetical exchange. A stock
on the unavailable list can be considered by a baseline, but selecting it
ends that phase without an inventory change. Inputs supply all outcomes and
the edition for each phase. No occurrence, acceptance, or liquidity estimates
are inferred.
"""
from __future__ import annotations

from collections import Counter
from dataclasses import dataclass

from pdiddler.system2 import manual_portfolio_review as manual
from pdiddler.system2.portfolio_planner import CAUTION_LABELS, MAX_OPPORTUNITIES, TARGET_PUBLISHER_ID, plan
from pdiddler.system2.supreme_market_editions import MarketEdition, compare_editions, load_edition
from pdiddler.system2.supreme_only_strategy_research import utc

MAX_PHASES = 12
MAX_PAIRS_PER_PHASE = 4_096
DEFAULT_STRATEGIES = ("hold", "listed_growth", "purchasing_power", "listed_parity")
OBJECTIVES = {
    "hold": "Leave the starting holdings unchanged.",
    "listed_growth": "Select the largest non-loss listed gain within the bounded comparison.",
    "purchasing_power": "Select the largest positive four-slot purchasing power improvement.",
    "listed_parity": "Select the closest listed parity within the bounded non-loss comparison.",
}


@dataclass(frozen=True)
class _Phase:
    catalog: bytes
    clock: str
    edition: MarketEdition
    prices: dict
    stability: dict
    counterparties: list
    unavailable: frozenset


def _prepare_phases(phases):
    if type(phases) is not list or not 1 <= len(phases) <= MAX_PHASES:
        raise manual.RequestError(f"Supply one to {MAX_PHASES} scenario phases.")
    required = {"catalog", "evaluated_at_utc", "counterparties"}
    prepared = []
    for phase in phases:
        if (type(phase) is not dict or not required <= phase.keys()
                or phase.keys() - required - {"expected_sha256", "unavailable_indices"}):
            raise manual.RequestError("Each phase needs a catalog, replay clock, and hypothetical stock list.")
        raw, clock = phase["catalog"], phase["evaluated_at_utc"]
        if prepared and utc(clock) < utc(prepared[-1].clock):
            raise manual.RequestError("Scenario phase clocks must be chronological.")
        edition = load_edition(raw, evaluated_at_utc=clock, expected_sha256=phase.get("expected_sha256"))
        if prepared:
            compare_editions(prepared[-1].edition, edition)
        names = {manual._manual_key(row): key for key, row in edition.rows.items()}
        if len(names) != len(edition.rows):
            raise manual.RequestError("The publisher identities are ambiguous.")
        partners = phase["counterparties"]
        unavailable = phase.get("unavailable_indices", [])
        if type(partners) is not list or len(partners) > MAX_OPPORTUNITIES:
            raise manual.RequestError(f"Supply up to {MAX_OPPORTUNITIES} hypothetical stocks for a phase.")
        if (type(unavailable) is not list or any(type(i) is not int or not 0 <= i < len(partners) for i in unavailable)
                or len(set(unavailable)) != len(unavailable)):
            raise manual.RequestError("Unavailable opportunities need distinct indices in that phase's stock list.")
        for stock in partners:
            manual._stocks(stock, names)
            if not stock:
                raise manual.RequestError("Each declared opportunity needs supplied holdings.")
        prices = {name: edition.rows[key]["supremeListed"] for name, key in names.items()}
        stability = {name: edition.rows[key]["supremeStability"] for name, key in names.items()}
        prepared.append(_Phase(raw, clock, edition, prices, stability, partners, frozenset(unavailable)))
    return prepared


def _revalue(accounts, previous, current):
    common, coverage = 0, 0
    if previous is not None:
        for holdings in accounts.values():
            for item, quantity in holdings.items():
                before, after = previous.prices.get(item), current.prices.get(item)
                if before is not None and after is not None:
                    common += (after - before) * quantity
                elif before is not None:
                    coverage -= before * quantity
                elif after is not None:
                    coverage += after * quantity
    return {"common_priced_change": common, "price_coverage_change": coverage}


def _selection(strategy, alternatives):
    if strategy == "listed_growth":
        return max(alternatives, key=lambda row: row["main_listed_delta"], default=None)
    if strategy == "purchasing_power":
        improving = (row for row in alternatives if row["main_four_slot_capacity_change"] > 0)
        return max(improving, key=lambda row: row["main_four_slot_capacity_change"], default=None)
    return min(alternatives, key=lambda row: row["main_listed_delta"], default=None)


def _approach(strategy, accounts, phase):
    if not phase.counterparties:
        return "NO_SUPPLIED_OPPORTUNITIES", None, None
    if strategy == "hold":
        return "HOLD_BASELINE", None, None
    result = plan(phase.catalog, accounts["main"], phase.counterparties, edition=phase.edition,
                  evaluated_at_utc=phase.clock, max_steps=1, max_pairs=MAX_PAIRS_PER_PHASE)
    alternatives = result["alternatives"]
    search = result["search"]
    if not alternatives:
        status = "NO_CANDIDATE_IN_BOUNDED_SEARCH" if search["states_with_unexamined_pairs"] else "NO_FEASIBLE_CANDIDATE"
        return status, None, search
    candidate = _selection(strategy, alternatives)
    if candidate is None:
        return "BASELINE_PASSED", None, search
    if candidate["opportunity_index"] in phase.unavailable:
        return "SUPPLIED_OUTCOME_UNAVAILABLE", candidate, search
    return "APPLIED_HYPOTHETICAL_EXCHANGE", candidate, search


def _apply(main, candidate):
    if (candidate["disposition"] != "NON_LOSS_PAPER_COMPARISON" or candidate["main_listed_delta"] < 0
            or candidate["authorizes_trade"] or TARGET_PUBLISHER_ID in candidate["give"]
            or any(main.get(item, 0) < count for item, count in candidate["give"].items())):
        raise manual.RequestError("The simulated exchange fails portfolio safety checks.")
    result = Counter(main)
    result.subtract(candidate["give"])
    result.update(candidate["receive"])
    return dict(+result)


def _axes(report, accounts, phase, candidate, search, applied):
    by_account = report["accounts"]
    measures = {**by_account, "combined": report["combined"]}
    target_value = report["target"]["listed_value"]
    main_capacity = by_account["main"]["four_slot_single_copy_listed_ceiling"]
    source = phase.edition.provenance
    return {
        "listed_wealth": {name: {"known": row["known_listed_value"], "total": row["total_listed_value"],
                                 "unpriced_copies": row["unpriced_copies"]} for name, row in measures.items()},
        "purchasing_power": {name: row["four_slot_single_copy_listed_ceiling"] for name, row in by_account.items()},
        "market_quality": {name: {
            "known_weighted_demand": row["known_weighted_demand"],
            "known_concentration_bps": row["known_concentration_bps"],
            "known_item_diversity": sum(key in phase.prices for key in accounts[name]),
            "published_stability_labels": sorted({phase.stability[key] for key in accounts[name] if key in phase.stability}),
            "known_caution_listed_value": sum(phase.prices[key] * count for key, count in accounts[name].items()
                                              if phase.stability.get(key, "").casefold() in CAUTION_LABELS),
        } for name, row in by_account.items()},
        "target_progress": {
            "listed_target": target_value,
            "main_reported_protected_copies": accounts["main"].get(TARGET_PUBLISHER_ID, 0),
            "alt_reported_protected_copies": accounts["alt"].get(TARGET_PUBLISHER_ID, 0),
            "main_single_copy_capacity_gap": None if target_value is None else max(0, target_value - main_capacity),
        },
        "bilateral_attractiveness": None if candidate is None else {
            "hypothetical_exchange_applied": applied,
            "comparison": candidate,
        },
        "reliability": {"market_archive_sha256": phase.edition.identity, "evaluation_clock": phase.clock,
                        "market_publisher_edition": source["publisherUpdatedAt"], "market_expires_utc": source["expiresUtc"],
                        "supplied_opportunities": len(phase.counterparties), "search": search,
                        "protected_inventory_preserved": True, "game_settlement_established": False},
    }


def _trajectory(strategy, accounts, phases):
    accounts = {name: dict(holdings) for name, holdings in accounts.items()}
    timeline = []
    prior_phase = None
    prior_wealth = None
    for phase in phases:
        revaluation = _revalue(accounts, prior_phase, phase)
        before = manual.summarize_accounts(accounts, phase.edition.rows)
        before_value = before["combined"]["known_listed_value"]
        if prior_wealth is not None and before_value != prior_wealth + sum(revaluation.values()):
            raise manual.RequestError("The scenario market revaluation does not reconcile.")
        status, candidate, search = _approach(strategy, accounts, phase)
        applied = status == "APPLIED_HYPOTHETICAL_EXCHANGE"
        if applied:
            accounts["main"] = _apply(accounts["main"], candidate)
        after = manual.summarize_accounts(accounts, phase.edition.rows) if applied else before
        growth = candidate["main_listed_delta"] if applied else 0
        after_value = after["combined"]["known_listed_value"]
        if after_value - before_value != growth:
            raise manual.RequestError("The scenario exchange does not reconcile.")
        bounds = candidate["published_range_deltas"] if applied else None
        timeline.append({
            "opportunity_status": status,
            "axes": _axes(after, accounts, phase, candidate, search, applied),
            "trade_growth": growth, "market_revaluation": revaluation,
            "conditional_published_low_endpoint": bounds["main_low"] if bounds else None,
        })
        prior_phase, prior_wealth = phase, after_value

    applied_steps = sum(row["opportunity_status"] == "APPLIED_HYPOTHETICAL_EXCHANGE" for row in timeline)
    covered = [row["conditional_published_low_endpoint"] for row in timeline
               if row["conditional_published_low_endpoint"] is not None]
    return {
        "phases": timeline, "ending_accounts": accounts,
        "hypothetical_trade_growth": sum(row["trade_growth"] for row in timeline),
        "common_priced_market_revaluation": sum(row["market_revaluation"]["common_priced_change"] for row in timeline),
        "market_coverage_change": sum(row["market_revaluation"]["price_coverage_change"] for row in timeline),
        "applied_hypothetical_steps": applied_steps, "published_range_covered_steps": len(covered),
        "cumulative_published_low_endpoint": sum(covered) if len(covered) == applied_steps else None,
        "realized_growth": None,
    }


def compare_strategies(accounts, phases, *, strategy_names=DEFAULT_STRATEGIES):
    """Run each named baseline over the same ordered, explicit scenario inputs."""
    if (type(strategy_names) not in (list, tuple) or not strategy_names
            or any(type(name) is not str or name not in DEFAULT_STRATEGIES for name in strategy_names)
            or len(set(strategy_names)) != len(strategy_names)):
        raise manual.RequestError("Select distinct supported scenario baseline names.")
    prepared = _prepare_phases(phases)
    manual.summarize_accounts(accounts, prepared[0].edition.rows)
    return {
        "schema": "gingerscope-long-run-portfolio-simulation-v1", "mode": "HYPOTHETICAL_STRATEGY_REPLAY",
        "strategies": {name: _trajectory(name, accounts, prepared) for name in strategy_names},
        "baseline_objectives": {name: OBJECTIVES[name] for name in strategy_names},
        "max_pairs_per_strategy_phase": MAX_PAIRS_PER_PHASE,
        "applied_outcomes_are_explicit_scenario_assumptions": True,
        "acceptance_probability": None, "measured_retrade_liquidity": None,
        "realized_growth": None, "authorizes_trade": False, "eligible_for_learning": False,
    }
