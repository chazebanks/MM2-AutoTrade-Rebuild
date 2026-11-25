"""Review manually entered MM2 portfolios and hypothetical bundles with Supreme Values.

Input is a local JSON file. The two accounts use category:publisher-item-ID
keys and positive copy counts. An optional comparison uses a short list of
main-account items and separately supplied fictional counterparty stock.
Output is a paper comparison for human review. No game or Discord connection.
"""
from __future__ import annotations

import argparse
from collections import Counter
from dataclasses import dataclass
from datetime import datetime, timezone
from hashlib import sha256
from itertools import product
import json
from pathlib import Path
import re
import sys

from pdiddler.system2.supreme_only_strategy_research import (
    NOV25_CATALOG_BLOB_SHA, SOURCE, TARGET, SupremeOnlyBlocked, blob_sha,
    concentration, mean_demand, review,
    review_bilateral_batch, review_paths, source_rows, total,
)

DEFAULT_CATALOG = Path(__file__).with_name(
    "supreme_only_189_research_catalog_2026_11_25_publication_nov23.json"
)
PARITY_RECEIPT = DEFAULT_CATALOG.with_name("supreme_publisher_parity_2026_11_25.json")
PARITY_RECEIPT_BLOB = "32759e6f0d4e094b8871ae740e130c1912dcf5d8"
ITEM_ID = re.compile(r"[a-z]{1,20}:[A-Za-z0-9 _.'-]{1,120}\Z")
PHYSICAL_SLOTS = 4
COPIES_PER_SLOT_ASSUMPTION = 4
MAX_ACCOUNT_COPIES_PER_ITEM = 100_000
MAX_REQUEST_BYTES = 65_536


class RequestError(ValueError):
    """Invalid human-entered data. Error messages omit input identifiers."""


def _manual_key(row):
    return f"{row['category']}:{row['officialItemId']}"


def _publisher_ranges(catalog, provenance):
    if provenance["catalogGitBlob"] != NOV25_CATALOG_BLOB_SHA:
        return {}
    raw = PARITY_RECEIPT.read_bytes()
    if blob_sha(raw) != PARITY_RECEIPT_BLOB:
        raise RequestError("The publisher range receipt differs from its reviewed bytes.")
    receipt = json.loads(raw)
    if (receipt["publisherUpdatedAt"] != provenance["publisherUpdatedAt"]
            or receipt["archiveSha256"] != sha256(catalog).hexdigest()):
        raise RequestError("The publisher range receipt belongs to a different market archive.")
    return receipt["publishedRangesByPublisherItem"]


def _stocks(data, names):
    if type(data) is not dict or len(data) > 400:
        raise RequestError("Enter holdings as a JSON object with at most 400 item types.")
    known = Counter()
    unpriced = 0
    for item, quantity in data.items():
        if type(item) is not str or not ITEM_ID.fullmatch(item):
            raise RequestError("Use an exact category:publisher-item-ID for each item.")
        if type(quantity) is not int or not 1 <= quantity <= MAX_ACCOUNT_COPIES_PER_ITEM:
            raise RequestError("Enter positive integer copy counts up to 100000 per item.")
        if item in names:
            known[names[item]] = quantity
        else:
            unpriced += quantity
    return known, unpriced


def _wealth(holdings, unpriced, market):
    value = total(holdings, market)
    return {
        "known_copies": sum(holdings.values()),
        "unpriced_copies": unpriced,
        "known_listed_value": value,
        "total_listed_value": None if unpriced else value,
        "known_weighted_demand": round(mean_demand(holdings, market), 5) if holdings else None,
        "known_concentration_bps": concentration(holdings, market) if holdings else None,
        "gingerscope_copies": holdings.get(TARGET, 0),
    }


def _account_summary(holdings, unpriced, market):
    prices = [
        (market[key]["supremeListed"], copies)
        for key, copies in holdings.items()
        if not market[key]["outgoingGingerscopeProtected"]
    ]
    single_copy = sorted((price for price, _ in prices), reverse=True)
    capped_stack = sorted((
        price * min(copies, COPIES_PER_SLOT_ASSUMPTION) for price, copies in prices
    ), reverse=True)
    stacked_ceiling = sum(capped_stack[:PHYSICAL_SLOTS])
    target = market.get(TARGET)
    return {
        **_wealth(holdings, unpriced, market),
        "four_slot_single_copy_listed_ceiling": sum(single_copy[:PHYSICAL_SLOTS]),
        "four_slot_capped_stack_listed_ceiling": stacked_ceiling,
        "four_slot_capped_stack_target_gap": (
            max(0, target["supremeListed"] - stacked_ceiling) if target else None
        ),
    }


def _account_holdings(accounts, market):
    if type(accounts) is not dict or set(accounts) != {"main", "alt"}:
        raise RequestError("Provide separate main and alt holdings. Empty holdings are allowed.")
    names = {_manual_key(row): key for key, row in market.items()}
    if len(names) != len(market):
        raise RequestError("The publisher identities are ambiguous.")
    return names, _stocks(accounts["main"], names), _stocks(accounts["alt"], names)


def _portfolio(main, main_unpriced, alt, alt_unpriced, market):
    target = market.get(TARGET)
    return {
        "target": {
            "name": target["officialName"] if target else TARGET,
            "listed_value": target["supremeListed"] if target else None,
        },
        "accounts": {
            "main": _account_summary(main, main_unpriced, market),
            "alt": _account_summary(alt, alt_unpriced, market),
        },
        "combined": _wealth(main + alt, main_unpriced + alt_unpriced, market),
        "estimated_copies_per_slot_limit": COPIES_PER_SLOT_ASSUMPTION,
        "realized_growth": None,
        "measured_retrade_liquidity": None,
    }


def summarize_accounts(accounts, market):
    """Summarize local holdings using rows from one already validated edition."""
    _, (main, main_unpriced), (alt, alt_unpriced) = _account_holdings(accounts, market)
    return _portfolio(main, main_unpriced, alt, alt_unpriced, market)


@dataclass(frozen=True)
class Bundle:
    quantities: dict[str, int]
    value: int


def _bundles(stock, market):
    keys = sorted(stock)
    ranges = [
        range(min(stock[key], COPIES_PER_SLOT_ASSUMPTION) + 1) for key in keys
    ]
    for selection in product(*ranges):
        items = {key: qty for key, qty in zip(keys, selection) if qty}
        if items:
            yield Bundle(items, total(items, market))


def _select_examples(offers, requests, own, partner):
    # Compare all in-scope pairs. Retain the closest listed parity and the
    # largest listed gain for each shape and target combination.
    examples = {}
    counts = Counter()
    for give, receive in product(offers, requests):
        if give.quantities.keys() & receive.quantities.keys():
            counts["same_item_pairs_excluded"] += 1
            continue
        delta = receive.value - give.value
        if delta < 0:
            counts["listed_loss_pairs_excluded"] += 1
            continue
        if any(own.get(k, 0) + q > MAX_ACCOUNT_COPIES_PER_ITEM for k, q in receive.quantities.items()) or any(
            partner.get(k, 0) + q > MAX_ACCOUNT_COPIES_PER_ITEM for k, q in give.quantities.items()
        ):
            counts["account_overflow_pairs_excluded"] += 1
            continue
        counts["non_loss_pairs"] += 1
        difference = len(give.quantities) - len(receive.quantities)
        shape = "upgrade" if difference > 0 else "downgrade" if difference < 0 else "sidegrade"
        group = shape, TARGET in receive.quantities
        for purpose, cost in (("closest_to_listed_parity", delta), ("largest_listed_gain", -delta)):
            key = (*group, purpose)
            if key not in examples or cost < examples[key][0]:
                examples[key] = cost, give, receive

    unique = {}
    for (shape, _, purpose), (_, give, receive) in sorted(examples.items()):
        signature = (tuple(give.quantities.items()), tuple(receive.quantities.items()))
        if signature not in unique:
            unique[signature] = shape, [], give, receive
        unique[signature][1].append(purpose)
    return list(unique.values()), counts


def _slot_list(bundle, key_field):
    return [
        {key_field: key, "quantity": quantity} for key, quantity in bundle.quantities.items()
    ]


def _evaluate_examples(catalog, clock, own, partner, examples):
    if not examples:
        return []
    if len(examples) == 1:
        _, _, give, receive = examples[0]
        single = review(catalog, evaluated_at_utc=clock, owned=dict(own), alternatives=[{
            "kind": "HYPOTHETICAL_RESEARCH_ONLY", "valuationSource": SOURCE,
            "give": _slot_list(give, "rawGameKeyCandidate"),
            "receive": _slot_list(receive, "rawGameKeyCandidate"),
        }])
        entries = single.get("hypotheticalAlternatives")
    else:
        both = review_bilateral_batch(catalog, evaluated_at_utc=clock, request={
            "kind": "SYNTHETIC_BILATERAL_RESEARCH_ONLY",
            "valueSource": SOURCE,
            "ownHypotheticalStock": dict(own),
            "partnerHypotheticalStock": dict(partner),
            "routes": [{
                "give": _slot_list(give, "rawGameKey"),
                "receive": _slot_list(receive, "rawGameKey"),
                "partnerPreferenceScenario": "UNKNOWN",
                "interestKey": None,
            } for _, _, give, receive in examples],
        })
        entries = [row["economic"] for row in both.get("hypotheticalAlternatives", [])]
    if entries is None or len(entries) != len(examples):
        raise RequestError("The Supreme evaluators could not corroborate the paper comparisons.")
    return entries


def _after(stock, give, receive):
    updated = stock.copy()
    updated.subtract(give.quantities)
    updated.update(receive.quantities)
    return +updated


def _published_range_deltas(give, receive, market):
    # Use endpoints only when every item has a published range and is a
    # singleton. Missing ranges and stack quotes stay explicitly unknown.
    bundles = (give, receive)
    if any(q != 1 or market[k]["published_range"] is None
           for bundle in bundles for k, q in bundle.quantities.items()):
        return None
    offered, received = [
        (sum(market[k]["published_range"]["low"] for k in bundle.quantities),
         sum(market[k]["published_range"]["high"] for k in bundle.quantities))
        for bundle in bundles
    ]
    low = received[0] - offered[1]
    high = received[1] - offered[0]
    return {"main_low": low, "main_high": high, "counterparty_low": -high,
            "counterparty_high": -low}


def _paper_row(example, verified, own, own_unpriced, partner, market):
    shape, purposes, give, receive = example
    main_after = _after(own, give, receive)
    partner_after = _after(partner, receive, give)
    main_after_value = total(main_after, market)
    partner_after_value = total(partner_after, market)
    delta = receive.value - give.value
    if (verified["status"] != "SUPREME_PAPER_GAIN_RESEARCH_NOT_ACTIONABLE"
            or verified["supremeListedValueGain"] != delta
            or verified["opponentSupremeListedValueGain"] != -delta
            or main_after_value != verified["hypotheticalAfterSupremePortfolioValue"]
            or main_after_value - total(own, market) != delta
            or partner_after_value - total(partner, market) != -delta):
        raise RequestError("Inventory changes and bilateral listed amounts disagree.")
    main_summary = _account_summary(main_after, own_unpriced, market)
    return {
        "shape_by_physical_slots": shape,
        "why_shown": purposes,
        "give": {_manual_key(market[k]): q for k, q in give.quantities.items()},
        "receive": {_manual_key(market[k]): q for k, q in receive.quantities.items()},
        "main_slots": len(give.quantities),
        "partner_slots": len(receive.quantities),
        "main_copies": sum(give.quantities.values()),
        "partner_copies": sum(receive.quantities.values()),
        "includes_incoming_gingerscope": TARGET in receive.quantities,
        "main_gingerscope_copies_after": main_summary["gingerscope_copies"],
        "main_given_listed_value": give.value,
        "main_received_listed_value": receive.value,
        "main_listed_delta": delta,
        "counterparty_listed_delta": -delta,
        "published_range_deltas": _published_range_deltas(give, receive, market),
        "main_listed_value_after": main_summary["total_listed_value"],
        "main_known_listed_value_after": main_after_value,
        "counterparty_listed_value_after": partner_after_value,
        "main_published_demand_received": round(verified["incomingSupremeDemandOrdinal"], 5),
        "counterparty_published_demand_received": round(verified["outgoingSupremeDemandOrdinal"], 5),
        "main_published_stability_received": sorted({market[k]["supremeStability"] for k in receive.quantities}),
        "counterparty_published_stability_received": sorted({market[k]["supremeStability"] for k in give.quantities}),
        "main_known_concentration_after_bps": main_summary["known_concentration_bps"],
        "counterparty_concentration_after_bps": concentration(partner_after, market),
        "main_capped_four_slot_value_after": main_summary["four_slot_capped_stack_listed_ceiling"],
        "stack_behavior_unverified": any(q > 1 for bundle in (give, receive) for q in bundle.quantities.values()),
        "acceptance_probability": None,
    }


def _compare(comparison, own, own_unpriced, names, market, catalog, clock):
    if type(comparison) is not dict or set(comparison) != {"mainItemTypes", "counterpartyStock"}:
        raise RequestError("Supply mainItemTypes and fictional counterpartyStock for comparisons.")
    choices = comparison["mainItemTypes"]
    if (type(choices) is not list or not 1 <= len(choices) <= PHYSICAL_SLOTS
            or any(type(item) is not str for item in choices) or len(set(choices)) != len(choices)):
        raise RequestError("Select one to four distinct main-account item types.")
    keys = [names.get(item) for item in choices]
    if any(key not in own or key == TARGET for key in keys):
        raise RequestError("Select priced main-account holdings other than Gingerscope.")
    partner, unknown = _stocks(comparison["counterpartyStock"], names)
    if unknown or not 1 <= len(partner) <= PHYSICAL_SLOTS:
        raise RequestError("Enter one to four distinct priced item types for the fictional counterparty.")

    shortlist = {key: own[key] for key in keys}
    outgoing, incoming = list(_bundles(shortlist, market)), list(_bundles(partner, market))
    examples, counts = _select_examples(outgoing, incoming, own, partner)
    rows = _evaluate_examples(catalog, clock, own, partner, examples)
    return {
        "scope": "HYPOTHETICAL_SHORTLIST",
        "pairs_examined": len(outgoing) * len(incoming),
        "listed_loss_pairs_excluded": counts["listed_loss_pairs_excluded"],
        "same_item_pairs_excluded": counts["same_item_pairs_excluded"],
        "account_overflow_pairs_excluded": counts["account_overflow_pairs_excluded"],
        "non_loss_pairs": counts["non_loss_pairs"],
        "alternatives": [
            _paper_row(example, row, own, own_unpriced, partner, market)
            for example, row in zip(examples, rows)
        ],
    }


def _path_bundle(data, names):
    stock, unpriced = _stocks(data, names)
    if (unpriced or not 1 <= len(stock) <= PHYSICAL_SLOTS
            or any(q > COPIES_PER_SLOT_ASSUMPTION for q in stock.values())):
        raise RequestError("Each path bundle needs one to four priced slots with up to four copies per slot.")
    return stock


def _review_growth(data, main, unpriced, names, market, catalog, clock):
    if type(data) is not list or not 2 <= len(data) <= 12:
        raise RequestError("Enter two to twelve distinct growth paths.")
    paths, balances = [], []
    for path in data:
        if type(path) is not list or not 2 <= len(path) <= 8:
            raise RequestError("Each growth path needs two to eight hypothetical steps.")
        steps, changes = [], []
        for step in path:
            if type(step) is not dict or set(step) != {"give", "receive", "counterpartyStock"}:
                raise RequestError("Each step needs give, receive and fictional counterpartyStock.")
            give = _path_bundle(step["give"], names)
            receive = _path_bundle(step["receive"], names)
            partner, unknown = _stocks(step["counterpartyStock"], names)
            if unknown or not partner:
                raise RequestError("Use priced items for fictional counterparty stock in each step.")
            steps.append({
                "kind": "HYPOTHETICAL_RESEARCH_ONLY",
                "valuationSource": SOURCE,
                "give": [{"rawGameKeyCandidate": k, "quantity": q} for k, q in give.items()],
                "receive": [{"rawGameKeyCandidate": k, "quantity": q} for k, q in receive.items()],
                "partnerHypotheticalStock": dict(partner),
            })
            changes.append((give, receive))
        paths.append(steps)
        balances.append(changes)

    review_report = review_paths(catalog, owned=dict(main), paths=paths, evaluated_at_utc=clock)
    routes = review_report.get("hypotheticalRoutes", [])
    if len(routes) != len(paths):
        raise RequestError("The Supreme evaluator could not corroborate the growth paths.")
    output = []
    for route, changes in zip(routes, balances):
        if route["status"] == "BLOCKED_PATH":
            output.append({"status": "BLOCKED_PATH", "reason": route["reason"],
                           "blocked_at_step": route["blockedAtStep"]})
            continue
        if route["status"] != "PAPER_PATH_COMPARED_NOT_EXECUTABLE" or len(route["steps"]) != len(changes):
            raise RequestError("The growth path result does not match the input steps.")
        holdings = main.copy()
        for (give, receive), step in zip(changes, route["steps"]):
            delta = total(receive, market) - total(give, market)
            holdings.subtract(give)
            holdings.update(receive)
            if (min(holdings.values(), default=0) < 0
                    or step["ourListedDelta"] != delta or step["partnerListedDelta"] != -delta
                    or step["ourListedPortfolioAfter"] != total(holdings, market)):
                raise RequestError("A growth step disagrees with the portfolio replay.")
        if total(holdings, market) != route["endingHypotheticalListedValue"]:
            raise RequestError("The ending inventory disagrees with the replay ledger.")
        steps = [{
            "main_listed_delta": row["ourListedDelta"],
            "counterparty_listed_delta": row["partnerListedDelta"],
            "main_slots": row["outgoingPhysicalSlots"],
            "partner_slots": row["incomingPhysicalSlots"],
            "counterparty_published_demand_received": row["partnerReceivesPublishedDemand"],
            "main_published_demand_received": row["partnerGivesPublishedDemand"],
            "stack_behavior_unverified": (row["outgoingCopies"] > row["outgoingPhysicalSlots"]
                                          or row["incomingCopies"] > row["incomingPhysicalSlots"]),
        } for row in route["steps"]]
        output.append({
            "status": "HYPOTHETICAL_PATH_COMPARED",
            "hypothetical_listed_growth": route["hypotheticalListedGrowth"],
            "ending_account": _account_summary(+holdings, unpriced, market),
            "steps": steps,
        })
    return output


def analyze(catalog, request, *, evaluated_at_utc):
    """Analyze one manually entered state under one immutable source edition."""
    market, provenance = source_rows(catalog, evaluated_at_utc=evaluated_at_utc)
    ranges = _publisher_ranges(catalog, provenance)
    market = {
        key: {**row, "published_range": ranges.get(_manual_key(row))}
        for key, row in market.items()
    }
    if (type(request) is not dict or "accounts" not in request
            or set(request) - {"accounts", "comparison", "growthPaths"}):
        raise RequestError("Enter accounts and optionally comparison and growthPaths.")
    names, (main, main_unpriced), (alt, alt_unpriced) = _account_holdings(request["accounts"], market)
    result = {
        "mode": "MANUAL_PORTFOLIO_RESEARCH",
        "source": {**provenance, "published_range_row_count": len(ranges)},
        **_portfolio(main, main_unpriced, alt, alt_unpriced, market),
    }
    if "comparison" in request:
        result["comparison"] = _compare(
            request["comparison"], main, main_unpriced, names, market, catalog, evaluated_at_utc
        )
    if "growthPaths" in request:
        result["growth_paths"] = _review_growth(
            request["growthPaths"], main, main_unpriced, names, market, catalog, evaluated_at_utc
        )
    return result


def _unique_keys(pairs):
    record = dict(pairs)
    if len(record) != len(pairs):
        raise RequestError("A JSON object contains duplicate fields.")
    return record


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="Local file containing manually entered holdings")
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG)
    parser.add_argument("--replay-at", help="Timestamp with UTC offset for labeled historical review")
    args = parser.parse_args(argv)

    try:
        with args.input.open("rb") as file:
            raw = file.read(MAX_REQUEST_BYTES + 1)
        if len(raw) > MAX_REQUEST_BYTES:
            raise RequestError("Manual input is larger than 64 KiB.")
        request = json.loads(raw, object_pairs_hook=_unique_keys)
        clock = args.replay_at if args.replay_at is not None else datetime.now(timezone.utc).isoformat()
        result = analyze(args.catalog.read_bytes(), request, evaluated_at_utc=clock)
    except (RequestError, SupremeOnlyBlocked) as error:
        print(error, file=sys.stderr)
        return 2
    except (OSError, UnicodeError, ValueError, RecursionError):
        print("The manual input or the market archive could not be read.", file=sys.stderr)
        return 2

    result["evaluation_clock"] = "HISTORICAL_REPLAY" if args.replay_at is not None else "CURRENT_UTC"
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
