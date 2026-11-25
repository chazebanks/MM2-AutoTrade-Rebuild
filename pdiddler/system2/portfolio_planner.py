"""Generate bounded, reproducible paper trade alternatives and portfolio paths.

Each opportunity is an explicitly supplied hypothetical stock, usable once
per path. An unused opportunity or a calculated route never proves that a
trade is available. All quantities and capacity refer to one account.
"""
from __future__ import annotations

from collections import Counter
from collections.abc import Mapping
from dataclasses import dataclass
from hashlib import sha256
from itertools import combinations, islice, product
from math import gcd

from pdiddler.system2 import manual_portfolio_review as manual
from pdiddler.system2.supreme_market_editions import MarketEdition, load_edition
from pdiddler.system2.supreme_only_strategy_research import (
    SOURCE, TARGET, demand, review, total,
)

SCHEMA = "gingerscope-portfolio-planner-v1"
MAX_OPPORTUNITIES = 12
MAX_STEPS = 8
MAX_PAIRS = 100_000
MAX_BUNDLES_PER_SIDE = 1_024
FRONTIER_STATES = 16
MAX_ROUTES_PER_DEPTH = 12
CAUTION_LABELS = {"unsafe", "underpaid for", "decreasing", "fluctuating", "receding"}
TARGET_PUBLISHER_ID = "ancient:Gingerscope"


@dataclass(frozen=True)
class Context:
    clock: str
    edition: MarketEdition
    rows: Mapping
    provenance: dict
    names: dict
    demand_ordinals: dict
    caution_keys: frozenset

    @property
    def target_value(self):
        return self.rows.get(TARGET, {}).get("supremeListed")


def _context(catalog, clock, edition):
    if edition is None:
        edition = load_edition(catalog, evaluated_at_utc=clock)
    elif (not isinstance(edition, MarketEdition) or type(catalog) is not bytes
          or sha256(catalog).hexdigest() != edition.identity):
        raise manual.RequestError("The market edition does not match the supplied archive.")
    rows, provenance = edition.rows, edition.require_current(clock)
    names = {manual._manual_key(row): key for key, row in rows.items()}
    if len(names) != len(rows):
        raise manual.RequestError("The publisher identities are ambiguous.")
    return Context(clock, edition, rows, provenance, names,
                   {k: demand(row["supremeDemand"]) for k, row in rows.items()},
                   frozenset(k for k, row in rows.items() if row["supremeStability"].casefold() in CAUTION_LABELS))


def _integer(value, maximum, name):
    if type(value) is not int or not 1 <= value <= maximum:
        raise manual.RequestError(f"{name} must be an integer from 1 to {maximum}.")
    return value


def _key(stock):
    return tuple(sorted(stock.items()))


def _round_robin(iterators):
    active = list(iterators)
    while active:
        remaining = []
        for iterator in active:
            try:
                yield next(iterator)
            except StopIteration:
                continue
            remaining.append(iterator)
        active = remaining


def _bundle_stream(stock, order, rows, copies_per_slot, size):
    for keys in combinations(order, size):
        counts = [range(1, min(stock[key], copies_per_slot) + 1) for key in keys]
        for selection in product(*counts):
            quantities = dict(zip(keys, selection))
            yield manual.Bundle(quantities, total(quantities, rows))


def _bundles(stock, rows, copies_per_slot, limit):
    possibilities = [1] + [0] * manual.PHYSICAL_SLOTS
    for quantity in stock.values():
        for size in reversed(range(1, manual.PHYSICAL_SLOTS + 1)):
            possibilities[size] += possibilities[size - 1] * min(quantity, copies_per_slot)
    alphabetical = sorted(stock)
    by_price = sorted(alphabetical, key=lambda key: rows[key]["supremeListed"])
    by_demand = sorted(alphabetical, key=lambda key: demand(rows[key]["supremeDemand"]), reverse=True)
    target_first = [TARGET] if TARGET in stock else []
    order = tuple(dict.fromkeys(_round_robin(map(iter, (target_first, by_price, by_price[::-1], by_demand, alphabetical)))))
    # Reserve part of the bounded sample for covering individual types.
    # Visit the remaining slot-count strata in round-robin order.
    singles = (manual.Bundle({key: 1}, rows[key]["supremeListed"]) for key in order)
    first = tuple(islice(singles, max(1, limit // 2)))
    stacked_singles = (bundle for bundle in _bundle_stream(stock, order, rows, copies_per_slot, 1)
                       if next(iter(bundle.quantities.values())) > 1)
    others = (_bundle_stream(stock, order, rows, copies_per_slot, size)
              for size in range(2, manual.PHYSICAL_SLOTS + 1))
    remaining = islice(_round_robin((singles, *others, stacked_singles)), limit - len(first))
    return (*first, *remaining), sum(possibilities[1:])


def _pairs(outgoing, incoming):
    count = len(outgoing) * len(incoming)
    if not count:
        return
    # A coprime stride covers every pair exactly once. A truncated prefix
    # mixes both dimensions rather than sweeping through a single bundle.
    stride = max(1, len(incoming) + 1)
    while gcd(stride, count) != 1:
        stride += 1
    for index in range(count):
        i, j = divmod(index * stride % count, len(incoming))
        yield outgoing[i], incoming[j]


def _eligible_give(stock, context):
    return {key: qty for key, qty in stock.items()
            if key != TARGET and not context.rows[key]["outgoingGingerscopeProtected"]}


@dataclass(frozen=True)
class Unpriced:
    copies: int
    target_copies: int


def _parse_holdings(data, context):
    stock, unknown = manual._stocks(data, context.names)
    unpriced_target = data.get(TARGET_PUBLISHER_ID, 0) if TARGET_PUBLISHER_ID not in context.names else 0
    return stock, Unpriced(unknown, unpriced_target)


def _exclusion(give, receive, own, partner):
    if give.quantities.keys() & receive.quantities.keys():
        return "same_item_pairs_excluded"
    maximum = manual.MAX_ACCOUNT_COPIES_PER_ITEM
    if any(own.get(k, 0) + q > maximum for k, q in receive.quantities.items()) or any(
        partner.get(k, 0) + q > maximum for k, q in give.quantities.items()
    ):
        return "account_overflow_pairs_excluded"
    return None


def _portfolio(stock, unknown, context):
    value, capacity, demand_sum, risky_value, highest = 0, [], 0.0, 0, 0
    for key, quantity in stock.items():
        row = context.rows[key]
        listed = row["supremeListed"]
        position = listed * quantity
        value += position
        demand_sum += position * context.demand_ordinals[key]
        highest = max(highest, position)
        if key in context.caution_keys:
            risky_value += position
        if key != TARGET and not row["outgoingGingerscopeProtected"]:
            capacity.append(listed)
    ceiling = sum(sorted(capacity, reverse=True)[:manual.PHYSICAL_SLOTS])
    return {
        "known_copies": sum(stock.values()), "unpriced_copies": unknown.copies,
        "known_item_diversity": len(stock), "known_listed_value": value,
        "total_listed_value": None if unknown.copies else value,
        "known_weighted_demand": round(demand_sum / value, 5) if value else None,
        "known_concentration_bps": 10000 * highest // value if value else None,
        "known_published_caution_value": risky_value,
        "gingerscope_copies": stock.get(TARGET, 0) + unknown.target_copies,
        "unpriced_gingerscope_copies": unknown.target_copies,
        "four_slot_single_copy_listed_ceiling": ceiling,
        "four_slot_single_copy_target_gap": (None if context.target_value is None else
                                             max(0, context.target_value - ceiling)),
    }


@dataclass(frozen=True)
class Candidate:
    give: manual.Bundle
    receive: manual.Bundle
    opportunity: int
    own_before: Counter
    own_after: Counter
    portfolio: dict
    shape: str
    stacked: bool
    risk_delta: dict | None

    @property
    def delta(self):
        return self.receive.value - self.give.value

    @property
    def target(self):
        return TARGET in self.receive.quantities


def _candidate(give, receive, opportunity, own, after, unknown, context):
    slot_change = len(give.quantities) - len(receive.quantities)
    shape = "upgrade" if slot_change > 0 else "downgrade" if slot_change < 0 else "sidegrade"
    return Candidate(give, receive, opportunity, own, after, _portfolio(after, unknown, context), shape,
                     any(q > 1 for bundle in (give, receive) for q in bundle.quantities.values()),
                     manual._published_range_deltas(give, receive, context.rows))


def _evidence_metrics(candidate):
    """Unweighted measurements used to retain alternatives for deliberation."""
    summary = candidate.portfolio
    return {
        "counterparty_listed_parity": -abs(candidate.delta),
        "main_listed_growth": candidate.delta,
        "single_copy_purchasing_power": summary["four_slot_single_copy_listed_ceiling"],
        "known_published_demand": summary["known_weighted_demand"] or 0,
        "lower_known_concentration": -(summary["known_concentration_bps"] or 0),
        "lower_published_caution_exposure": -summary["known_published_caution_value"],
        "known_item_diversity": summary["known_item_diversity"],
        "less_slot_burden": -len(candidate.give.quantities) - len(candidate.receive.quantities),
        "less_copy_burden": -sum(candidate.give.quantities.values()) - sum(candidate.receive.quantities.values()),
    }


def _remember(shortlist, candidate):
    # Keeping distinct shapes, target acquisition, and stack assumptions
    # prevents a single nominal-gain metric from deleting those options.
    group = (candidate.opportunity, candidate.shape, candidate.target, candidate.stacked)
    for label, value in _evidence_metrics(candidate).items():
        rank = (label, *group)
        if rank not in shortlist or value > shortlist[rank][0]:
            shortlist[rank] = value, candidate


def _distinct_choices(shortlist):
    seen = set()
    for _, choice in shortlist.values():
        identity = (choice.opportunity, _key(choice.give.quantities), _key(choice.receive.quantities))
        if identity not in seen:
            seen.add(identity)
            yield choice


@dataclass(frozen=True)
class Node:
    holdings: Counter
    visited: frozenset
    used: frozenset
    steps: tuple[Candidate, ...]


def _extend(node, candidate):
    return Node(candidate.own_after, node.visited | {_key(candidate.own_after)},
                node.used | {candidate.opportunity}, (*node.steps, candidate))


def _frontier(nodes, limit):
    # Round-robin the unweighted objectives, starting with each feasible
    # alternative depth's target-acquisition branch when one exists.
    metrics = {}
    for node in nodes:
        measures = _evidence_metrics(node.steps[-1])
        net = sum(step.delta for step in node.steps)
        measures["main_listed_growth"] = net
        measures["counterparty_listed_parity"] = -abs(net)
        measures["less_slot_burden"] = -sum(len(step.give.quantities) + len(step.receive.quantities) for step in node.steps)
        measures["no_stack_assumptions"] = -sum(step.stacked for step in node.steps)
        metrics[id(node)] = measures
    orders = [sorted(nodes, key=lambda node: node.holdings[TARGET], reverse=True)]
    for label in metrics[id(nodes[0])]:
        orders.append(sorted(nodes, key=lambda node: metrics[id(node)][label], reverse=True))
    signatures, retained = set(), []
    for node in _round_robin(iter(order) for order in orders):
        identity = tuple((trade.opportunity, _key(trade.give.quantities), _key(trade.receive.quantities))
                         for trade in node.steps)
        if identity not in signatures:
            signatures.add(identity)
            retained.append(node)
            if len(retained) >= limit:
                break
    return retained


def _offer_metrics(candidates, partner, partner_unknown, own_unknown, context):
    """Check each retained proposal against the Supreme evaluator and both ledgers."""
    rows = context.rows
    out = []
    for candidate in candidates:
        give, receive = candidate.give, candidate.receive
        option = {"kind": "HYPOTHETICAL_RESEARCH_ONLY", "valuationSource": SOURCE,
                  "give": manual._slot_list(give, "rawGameKeyCandidate"),
                  "receive": manual._slot_list(receive, "rawGameKeyCandidate")}
        result = review(None, owned=dict(candidate.own_before), alternatives=[option],
                        evaluated_at_utc=context.clock, edition=context.edition)
        evidence = result.get("hypotheticalAlternatives", [])
        expected_status = ("BLOCKED_UNAPPROVED_SUPREME_LOSS" if candidate.delta < 0
                           else "SUPREME_PAPER_GAIN_RESEARCH_NOT_ACTIONABLE")
        partner_after = manual._after(partner, receive, give)
        main_after = candidate.portfolio
        main_summary_before = _portfolio(candidate.own_before, own_unknown, context)
        partner_summary_before = _portfolio(partner, partner_unknown, context)
        partner_summary = _portfolio(partner_after, partner_unknown, context)
        if (len(evidence) != 1 or evidence[0]["status"] != expected_status
                or result["source"] != context.provenance
                or evidence[0]["supremeListedValueGain"] != candidate.delta
                or evidence[0]["opponentSupremeListedValueGain"] != -candidate.delta
                or evidence[0]["hypotheticalAfterSupremePortfolioValue"] != main_after["known_listed_value"]
                or main_after["known_listed_value"] - main_summary_before["known_listed_value"] != candidate.delta
                or partner_summary["known_listed_value"] - partner_summary_before["known_listed_value"] != -candidate.delta
                or candidate.own_before + partner != candidate.own_after + partner_after):
            raise manual.RequestError("Independent Supreme calculations and both inventory ledgers disagree.")
        row = evidence[0]
        notes = list(row["warnings"])
        if candidate.stacked:
            notes.append("UNVERIFIED_STACK_LAYOUT_AND_LINEAR_PRICING_ASSUMPTION")
        if own_unknown.copies or partner_unknown.copies:
            notes.append("UNPRICED_ASSETS_EXCLUDED_FROM_WEALTH_AND_COMPARISONS")
        if candidate.risk_delta is None:
            notes.append("PUBLISHED_DOWNSIDE_RANGE_INCOMPLETE")
        elif candidate.risk_delta["main_low"] < 0:
            notes.append("PUBLISHED_RANGE_DOWNSIDE_POSSIBLE")
        if candidate.delta > 0:
            notes.append("COUNTERPARTY_PAPER_LISTED_LOSS_NEEDS_OTHER_MOTIVE")
        capacity_field = "four_slot_single_copy_listed_ceiling"
        main_capacity_delta = main_after[capacity_field] - main_summary_before[capacity_field]
        partner_capacity_delta = partner_summary[capacity_field] - partner_summary_before[capacity_field]
        if main_capacity_delta < 0:
            notes.append("PAPER_PURCHASING_POWER_DETERIORATION")
        if main_after["known_weighted_demand"] < main_summary_before["known_weighted_demand"]:
            notes.append("PAPER_PORTFOLIO_DEMAND_DETERIORATION")
        out.append({
            "disposition": ("LISTED_LOSS_RESEARCH_ONLY" if candidate.delta < 0 else
                            "STACK_ASSUMPTION_RESEARCH_ONLY" if candidate.stacked else "NON_LOSS_PAPER_COMPARISON"),
            "opportunity_index": candidate.opportunity,
            "shape_by_physical_slots": candidate.shape,
            "give": {manual._manual_key(rows[k]): q for k, q in give.quantities.items()},
            "receive": {manual._manual_key(rows[k]): q for k, q in receive.quantities.items()},
            "main_slots": len(give.quantities), "partner_slots": len(receive.quantities),
            "main_copies": sum(give.quantities.values()), "partner_copies": sum(receive.quantities.values()),
            "main_given_listed_value": give.value, "main_received_listed_value": receive.value,
            "main_listed_delta": candidate.delta, "counterparty_listed_delta": -candidate.delta,
            "main_four_slot_capacity_change": main_capacity_delta,
            "counterparty_four_slot_capacity_change": partner_capacity_delta,
            "includes_incoming_gingerscope": candidate.target,
            "main_published_demand_received": round(row["incomingSupremeDemandOrdinal"], 5),
            "counterparty_published_demand_received": round(row["outgoingSupremeDemandOrdinal"], 5),
            "main_published_stability_received": sorted({rows[k]["supremeStability"] for k in receive.quantities}),
            "counterparty_published_stability_received": sorted({rows[k]["supremeStability"] for k in give.quantities}),
            "published_range_deltas": candidate.risk_delta,
            "main_after": main_after, "counterparty_after": partner_summary,
            "before": main_summary_before, "counterparty_before": partner_summary_before,
            "warnings": notes, "stack_behavior_unverified": candidate.stacked,
            "acceptance_probability": None, "measured_retrade_liquidity": None,
            "authorizes_trade": False, "eligible_for_learning": False,
        })
    return out


def _pareto(alternatives):
    """Return the non-dominated single-copy alternatives within each opportunity."""
    points = {}
    for index, row in enumerate(alternatives):
        if row["disposition"] != "NON_LOSS_PAPER_COMPARISON":
            continue
        account = row["main_after"]
        counterparty = row["counterparty_after"]
        range_deltas = row["published_range_deltas"]
        group = (row["opportunity_index"], range_deltas is not None)
        measures = (
            row["main_listed_delta"], row["counterparty_listed_delta"],
            account["four_slot_single_copy_listed_ceiling"], account["gingerscope_copies"],
            account["known_weighted_demand"] or 0, -(account["known_concentration_bps"] or 0),
            -account["known_published_caution_value"], account["known_item_diversity"],
            row["main_published_demand_received"], row["counterparty_published_demand_received"],
            counterparty["four_slot_single_copy_listed_ceiling"], counterparty["known_weighted_demand"] or 0,
            -(counterparty["known_concentration_bps"] or 0), -counterparty["known_published_caution_value"],
            -row["main_slots"], -row["partner_slots"], -row["main_copies"], -row["partner_copies"],
        )
        if range_deltas is not None:
            measures += (range_deltas["main_low"], range_deltas["counterparty_low"])
        points.setdefault(group, []).append((index, measures))
    return sorted(index for group in points.values() for index, values in group if not any(
        peer != values and all(a >= b for a, b in zip(peer, values)) for _, peer in group
    ))


def evaluate_offer(catalog, main, counterparty, give, receive, *, evaluated_at_utc,
                   copies_per_slot=1, edition=None):
    """Compare one exact manual observation against two supplied stock bounds."""
    _integer(copies_per_slot, manual.COPIES_PER_SLOT_ASSUMPTION, "copies_per_slot")
    context = _context(catalog, evaluated_at_utc, edition)
    own, unknown = _parse_holdings(main, context)
    partner, partner_unknown = _parse_holdings(counterparty, context)
    outgoing, unknown_give = manual._stocks(give, context.names)
    incoming, unknown_receive = manual._stocks(receive, context.names)
    if (unknown_give or unknown_receive or not 1 <= len(outgoing) <= manual.PHYSICAL_SLOTS
            or not 1 <= len(incoming) <= manual.PHYSICAL_SLOTS
            or max((*outgoing.values(), *incoming.values())) > copies_per_slot):
        raise manual.RequestError("Each side needs one to four known physical slots within the copy assumption.")
    eligible = _eligible_give(own, context)
    if any(eligible.get(key, 0) < quantity for key, quantity in outgoing.items()) or any(
        partner[key] < quantity for key, quantity in incoming.items()
    ):
        raise manual.RequestError("The offer exceeds supplied eligible holdings or includes a protected asset.")
    give = manual.Bundle(outgoing, total(outgoing, context.rows))
    receive = manual.Bundle(incoming, total(incoming, context.rows))
    if _exclusion(give, receive, own, partner):
        raise manual.RequestError("The offer has ambiguous same-item slots or an impossible resulting balance.")
    after = manual._after(own, give, receive)
    candidate = _candidate(give, receive, 0, own, after, unknown, context)
    return {"schema": SCHEMA, "mode": "MANUAL_PAPER_OFFER_COMPARISON", "source": context.provenance,
            **_offer_metrics([candidate], partner, partner_unknown, unknown, context)[0]}


def plan(catalog, main, counterparties, *, evaluated_at_utc, max_steps=3, max_pairs=20_000,
         max_bundles_per_side=256, copies_per_slot=1, include_loss_research=False, edition=None):
    """Generate competing hypothetical paths within explicit search bounds."""
    _integer(max_steps, MAX_STEPS, "max_steps")
    _integer(max_pairs, MAX_PAIRS, "max_pairs")
    _integer(max_bundles_per_side, MAX_BUNDLES_PER_SIDE, "max_bundles_per_side")
    _integer(copies_per_slot, manual.COPIES_PER_SLOT_ASSUMPTION, "copies_per_slot")
    if type(include_loss_research) is not bool:
        raise manual.RequestError("include_loss_research must be a boolean.")
    if type(counterparties) is not list or not 1 <= len(counterparties) <= MAX_OPPORTUNITIES:
        raise manual.RequestError(f"Provide between 1 and {MAX_OPPORTUNITIES} hypothetical opportunities.")
    context = _context(catalog, evaluated_at_utc, edition)
    rows = context.rows
    own, unknown = _parse_holdings(main, context)
    partners = [_parse_holdings(stock, context) for stock in counterparties]
    if any(not stock and not unpriced.copies for stock, unpriced in partners):
        raise manual.RequestError("Each hypothetical opportunity requires supplied holdings.")
    limits = dict(max_steps=max_steps, max_pairs=max_pairs, max_bundles_per_side=max_bundles_per_side,
                  copies_per_slot=copies_per_slot, frontier_states=FRONTIER_STATES,
                  max_routes_per_depth=MAX_ROUTES_PER_DEPTH)
    counts = Counter({key: 0 for key in (
        "pairs_examined", "non_loss_pairs", "listed_loss_pairs_excluded", "cycles_excluded",
        "same_item_pairs_excluded", "account_overflow_pairs_excluded", "states_with_no_feasible_trade",
        "states_explored", "states_with_unexamined_pairs", "frontier_states_omitted",
        "routes_omitted_from_report", "feasible_pair_shortlist_omissions",
    )})
    incoming = [_bundles(stock, rows, copies_per_slot, max_bundles_per_side) for stock, _ in partners]
    bundle_cut = any(len(bundles) < count for bundles, count in incoming)
    pair_cut = False
    initial = Node(own, frozenset({_key(own)}), frozenset(), ())
    frontier = [initial]
    alternatives, loss_research, routes = [], {}, []
    depth_limit = min(max_steps, len(partners))

    for depth in range(depth_limit):
        if not frontier:
            break
        remaining_budget = max_pairs - counts["pairs_examined"]
        depth_budget = max(1, remaining_budget // (depth_limit - depth)) if remaining_budget else 0
        possible, streams, shortlists = [], [], [{} for _ in frontier]
        for index, node in enumerate(frontier):
            outgoing, full_count = _bundles(_eligible_give(node.holdings, context), rows,
                                            copies_per_slot, max_bundles_per_side)
            bundle_cut |= len(outgoing) < full_count
            available = sorted((i for i in range(len(partners)) if i not in node.used),
                               key=lambda i: TARGET not in partners[i][0])
            bounded = len(outgoing) * sum(len(incoming[i][0]) for i in available)
            full = full_count * sum(incoming[i][1] for i in available)
            possible.append((bounded, full))
            streams.append(_node_pairs(index, available, outgoing, incoming))

        examined_by_state, feasible_by_state = Counter(), Counter()
        for index, opportunity, give, receive in islice(_round_robin(streams), depth_budget):
            counts["pairs_examined"] += 1
            examined_by_state[index] += 1
            node = frontier[index]
            partner, _ = partners[opportunity]
            excluded = _exclusion(give, receive, node.holdings, partner)
            if excluded:
                counts[excluded] += 1
                continue
            is_loss = receive.value < give.value
            if is_loss:
                counts["listed_loss_pairs_excluded"] += 1
                if depth or not include_loss_research:
                    continue
            after = manual._after(node.holdings, give, receive)
            if _key(after) in node.visited:
                counts["cycles_excluded"] += 1
                continue
            candidate = _candidate(give, receive, opportunity, node.holdings, after, unknown, context)
            if is_loss:
                _remember(loss_research, candidate)
            else:
                counts["non_loss_pairs"] += 1
                feasible_by_state[index] += 1
                _remember(shortlists[index], candidate)

        next_nodes = []
        for i, options in enumerate(shortlists):
            bounded, full = possible[i]
            counts["states_explored"] += 1
            if examined_by_state[i] < bounded:
                pair_cut = True
            if examined_by_state[i] < full:
                counts["states_with_unexamined_pairs"] += 1
            elif not options:
                counts["states_with_no_feasible_trade"] += 1
            candidates = list(_distinct_choices(options))
            counts["feasible_pair_shortlist_omissions"] += feasible_by_state[i] - len(candidates)
            if depth == 0:
                alternatives.extend(candidates)
            next_nodes.extend(_extend(frontier[i], candidate) for candidate in candidates)

        if not next_nodes:
            break
        if depth > 0:
            selected = _frontier(next_nodes, MAX_ROUTES_PER_DEPTH)
            routes.extend(selected)
            counts["routes_omitted_from_report"] += len(next_nodes) - len(selected)
        if depth + 1 < depth_limit:
            frontier = _frontier(next_nodes, FRONTIER_STATES)
            counts["frontier_states_omitted"] += len(next_nodes) - len(frontier)

    verified = {}

    def checked(candidate):
        identity = (_key(candidate.own_before), candidate.opportunity,
                    _key(candidate.give.quantities), _key(candidate.receive.quantities))
        if identity not in verified:
            partner, partner_unknown = partners[candidate.opportunity]
            verified[identity] = _offer_metrics([candidate], partner, partner_unknown, unknown, context)[0]
        return verified[identity]

    opening = _portfolio(own, unknown, context)
    assessed = [checked(candidate) for candidate in alternatives]
    return {
        "schema": SCHEMA, "mode": "HYPOTHETICAL_PORTFOLIO_SEARCH", "source": context.provenance,
        "starting_account": opening, "target_listed_value": context.target_value,
        "search": {**limits, **counts, "bundle_budget_truncated": bundle_cut,
                   "pair_budget_truncated": pair_cut,
                   "effective_max_steps": depth_limit, "hypothetical_opportunity_count": len(partners),
                   "method": "STRATIFIED_BUNDLE_AND_PAIR_ENUMERATION_WITH_MULTI_OBJECTIVE_FRONTIER"},
        "alternatives": assessed,
        "listed_loss_research": [checked(candidate) for candidate in _distinct_choices(loss_research)],
        "routes": [_route(node, checked, opening) for node in routes],
        "arbitration": {"nondominated_alternative_indices": _pareto(assessed),
                        "index_base": 0, "preferred_alternative": None,
                        "reason": "COUNTERPARTY_PREFERENCES_AND_ROUTING_OUTCOMES_UNVERIFIED"},
        "acceptance_probability": None, "realized_growth": None,
        "measured_retrade_liquidity": None, "approved_loss_budget": None,
        "authorizes_trade": False, "eligible_for_learning": False,
    }


def _node_pairs(node_index, available, outgoing, incoming):
    def pairs(opportunity):
        for give, receive in _pairs(outgoing, incoming[opportunity][0]):
            yield node_index, opportunity, give, receive
    yield from _round_robin(pairs(opportunity) for opportunity in available)


def _route(node, checked, opening):
    steps = [checked(candidate) for candidate in node.steps]
    ranges = [step["published_range_deltas"] for step in steps]
    ending = steps[-1]["main_after"]
    capacity = "four_slot_single_copy_listed_ceiling"
    return {
        "status": "HYPOTHETICAL_ROUTE_COMPARED",
        "steps": steps, "ending_account": ending,
        "hypothetical_listed_growth": ending["known_listed_value"] - opening["known_listed_value"],
        "four_slot_single_copy_capacity_change": ending[capacity] - opening[capacity],
        "conditional_cumulative_published_low_endpoint": (
            sum(bounds["main_low"] for bounds in ranges) if all(ranges) else None),
        "stack_assumptions_required": any(step["stack_behavior_unverified"] for step in steps),
        "target_acquired_hypothetically": any(step["includes_incoming_gingerscope"] for step in steps),
        "realized_growth": None, "authorizes_trade": False,
    }
